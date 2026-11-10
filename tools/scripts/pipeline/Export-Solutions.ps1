<#
.SYNOPSIS
  Exports solutions (unmanaged) listed in pipelines/config/export-order.json, grouped by source environment, and checks each zip.
.DESCRIPTION
  -Part A : every solution of UAT (archive, step B2).   -Part B : the 31 missing solutions from the systems that hold them (step D2/D3).
  -Part C : solutions with differences where a matching unmanaged source exists (step D6).
  -Discover -Source <key> : ignore the list and export every customer solution of that environment (baseline export, step J3).
  Each zip is checked: solution.xml version equals the version needed (parts B and C). A manifest.csv (name, source, version, SHA-256, ok) is written to -OutDir.
  Exports only read the source environment. Exit code 1 if any export failed or a version does not match.
#>
param([ValidateSet('A', 'B', 'C')][string]$Part = 'A', [Parameter(Mandatory)][string]$OutDir, [string[]]$Only = @(), [switch]$Discover, [string]$Source = 'UAT', [switch]$Managed)
. "$PSScriptRoot\Common.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$items = @()
if ($Discover) {
    Write-Log "Discovering customer solutions in $Source"
    $items = @(Get-CustomerSolutionList $Source | ForEach-Object { [pscustomobject]@{ part = 'X'; seq = 0; solution = $_.uniquename; source = $Source; versionNeeded = $_.version } })
} else {
    $items = @((Get-PipelineConfig 'export-order.json').items | Where-Object { $_.part -eq $Part })
    if ($Only.Count) { $items = @($items | Where-Object { $Only -contains $_.solution }) }
}
Write-Log "$($items.Count) solutions to export"
$manifest = New-Object System.Collections.Generic.List[object]
$noSource = @($items | Where-Object { -not $_.source })
foreach ($n in $noSource) { $manifest.Add([pscustomobject]@{ part = $n.part; solution = $n.solution; source = ''; expected = $n.versionNeeded; zipVersion = ''; sha256 = ''; ok = $false; note = 'No matching unmanaged source: use the component copy (D7)' }) }
foreach ($g in ($items | Where-Object { $_.source } | Group-Object source)) {
    Connect-Pac $g.Name
    foreach ($i in ($g.Group | Sort-Object { [int]$_.seq })) {
        $zip = Join-Path $OutDir "$($g.Name)\$($i.solution)_$($i.versionNeeded).zip"
        New-Item -ItemType Directory -Force (Split-Path $zip) | Out-Null
        $row = [ordered]@{ part = $i.part; solution = $i.solution; source = $g.Name; expected = $i.versionNeeded; zipVersion = ''; sha256 = ''; ok = $false; note = '' }
        try {
            Write-Log "export $($i.solution) from $($g.Name)"
            if ($Managed) { & pac solution export --name $i.solution --path $zip --managed --overwrite | Out-Host } else { & pac solution export --name $i.solution --path $zip --overwrite | Out-Host }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zip)) { throw "pac solution export failed (exit $LASTEXITCODE)" }
            $info = Get-ZipSolutionInfo $zip
            $row.zipVersion = $info.Version; $row.sha256 = Get-FileSha256 $zip
            $row.ok = ($Discover -or $Part -eq 'A' -or $info.Version -eq $i.versionNeeded)
            if (-not $row.ok) { $row.note = "version in zip $($info.Version) is not the version needed $($i.versionNeeded)" }
        } catch { $row.note = $_.Exception.Message }
        if (-not $row.ok) { Add-AdoWarning "$($i.solution): $($row.note)" }
        $manifest.Add([pscustomobject]$row)
    }
}
$manifest | Export-Csv (Join-Path $OutDir 'manifest.csv') -NoTypeInformation -Encoding utf8
$bad = @($manifest | Where-Object { -not $_.ok })
Write-Log ("exported {0} of {1}; problems: {2}" -f (@($manifest | Where-Object { $_.ok }).Count), $manifest.Count, $bad.Count)
if ($bad.Count) { exit 1 }
