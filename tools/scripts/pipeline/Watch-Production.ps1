<#
.SYNOPSIS
  A5: read-only check that production has not changed since the baseline (pipelines/config/production-baseline.json). GET requests only.
.DESCRIPTION
  Reads the production customer solutions (name, version, managed), compares them with the baseline, looks for solution imports in the last -LookbackHours,
  and checks that the environment is quiet (system jobs). Writes watch-report.md and watch-report.json. With -FailOnChange the exit code is 1 when anything changed.
  Load: about 6 requests, one at a time with pauses.
#>
param([string]$OutDir = '.\watch-out', [int]$LookbackHours = 26, [switch]$FailOnChange)
. "$PSScriptRoot\Common.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$base = Get-PipelineConfig 'production-baseline.json'
$null = Invoke-Dv -Key PROD -Path 'WhoAmI' -DelayMs 1000
Write-Log 'signed in to production (read only)'
$running = @((Invoke-Dv -Key PROD -Path 'asyncoperations?$select=name&$filter=statecode eq 2&$top=50' -DelayMs 1000).value).Count
$since = (Get-Date).ToUniversalTime().AddHours(-$LookbackHours).ToString('yyyy-MM-ddTHH:mm:ssZ')
$imports = @((Invoke-Dv -Key PROD -Path "importjobs?`$select=solutionname,startedon,completedon&`$filter=startedon ge $since&`$top=20" -DelayMs 1000).value)
$now = Get-CustomerSolutionList 'PROD'
$bm = @{}; foreach ($s in $base.solutions) { $bm[$s.name] = $s }
$nm = @{}; foreach ($s in $now) { $nm[$s.uniquename] = $s }
$added = @($nm.Keys | Where-Object { -not $bm.ContainsKey($_) } | Sort-Object)
$removed = @($bm.Keys | Where-Object { -not $nm.ContainsKey($_) } | Sort-Object)
$changed = @($nm.Keys | Where-Object { $bm.ContainsKey($_) -and $bm[$_].version -ne $nm[$_].version } | Sort-Object)
$managedChanged = @($nm.Keys | Where-Object { $bm.ContainsKey($_) -and [bool]$bm[$_].managed -ne [bool]$nm[$_].ismanaged } | Sort-Object)
$changedAny = ($added.Count + $removed.Count + $changed.Count + $managedChanged.Count + $imports.Count) -gt 0
$report = [ordered]@{ checkedUtc = (Get-Date).ToUniversalTime().ToString('o'); baselineReadOn = $base.readOn; solutionsNow = $now.Count; solutionsBaseline = $base.solutions.Count
    systemJobsRunning = $running; importsInLast = "$LookbackHours h"; imports = @($imports | ForEach-Object { "$($_.solutionname) started $($_.startedon)" })
    added = $added; removed = $removed; versionChanged = @($changed | ForEach-Object { "$_ : $($bm[$_].version) -> $($nm[$_].version)" }); managedFlagChanged = $managedChanged; changed = $changedAny }
($report | ConvertTo-Json -Depth 5) | Set-Content "$OutDir\watch-report.json" -Encoding utf8
$md = @("# Production watch", "", "Checked (UTC): $($report.checkedUtc). Baseline read on: $($base.readOn).", "", "| Item | Value |", "|---|---|",
    "| Customer solutions now / baseline | $($now.Count) / $($base.solutions.Count) |", "| System jobs running | $running |", "| Solution imports in the last $LookbackHours h | $($imports.Count) |",
    "| New solutions | $($added.Count) |", "| Removed solutions | $($removed.Count) |", "| Version changes | $($changed.Count) |", "| Managed flag changes | $($managedChanged.Count) |", "")
foreach ($sec in @(@('New solutions', $added), @('Removed solutions', $removed), @('Version changes', $report.versionChanged), @('Imports', $report.imports))) { if (@($sec[1]).Count) { $md += "## $($sec[0])"; $md += @($sec[1] | ForEach-Object { "- $_" }); $md += '' } }
if (-not $changedAny) { $md += 'No change since the baseline.' }
$md | Set-Content "$OutDir\watch-report.md" -Encoding utf8
$md | Out-Host
if ($running -gt 10) { Add-AdoWarning "Production has $running system jobs running (limit 10). Do not start reads against production now." }
if ($changedAny) {
    Add-AdoWarning "Production changed since $($base.readOn): $($added.Count) new, $($removed.Count) removed, $($changed.Count) version changes, $($imports.Count) imports. Review before continuing and update production-baseline.json."
    if ($FailOnChange) { exit 1 }
}
Write-Log 'production watch done'
