<#
.SYNOPSIS
  Imports solutions into UAT-ALIGN in the order of pipelines/config/import-order.json (steps E1 to E6 and F1).
.DESCRIPTION
  -Part 1 : the 31 missing solutions in production install order.   -Part 2 : solutions already in UAT-ALIGN that can be re-imported from a verified source (overwrite).
  Before each import the zip is checked (exists, version equals the version to import, unmanaged). Entries with no source, blocked entries and HotFixCommissionMasterTable are skipped
  and listed. One solution at a time; the first failure stops the run (use -ContinueOnError to go on). -DryRun only runs the checks.
  Only the writable environment key (ALIGN) can be the target; this is enforced.
#>
param([Parameter(Mandatory)][ValidateSet('1', '2')][string]$Part, [Parameter(Mandatory)][string]$ZipRoot, [string]$TargetKey = 'ALIGN', [string]$SettingsDir = '', [string[]]$Only = @(),
      [int]$MaxWaitMinutes = 120, [switch]$DryRun, [switch]$ContinueOnError, [string]$ResultFile = '.\import-results.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$items = @((Get-PipelineConfig 'import-order.json').items | Where-Object { [string]$_.part -eq $Part } | Sort-Object { [int]$_.seq })
if ($Only.Count) { $items = @($items | Where-Object { $Only -contains $_.solution }) }
Write-Log "$($items.Count) entries in part $Part; target $TargetKey; dry run: $DryRun"
if (-not $DryRun) { Connect-Pac $TargetKey }
$results = New-Object System.Collections.Generic.List[object]
$failed = $false
foreach ($i in $items) {
    $row = [ordered]@{ seq = $i.seq; solution = $i.solution; version = $i.versionToImport; source = $i.source; result = ''; note = '' }
    if ($i.special -or $i.noSource -or $i.blocked -or -not $i.source) {
        $row.result = 'skipped'; $row.note = if ($i.special) { 'special handling (managed package from pwc)' } elseif ($i.blocked) { 'blocked: newer version already in UAT-ALIGN' } else { 'no matching unmanaged source: use the component copy' }
        $results.Add([pscustomobject]$row); continue
    }
    $zip = Join-Path $ZipRoot "$($i.source)\$($i.solution)_$($i.sourceVersion).zip"
    try {
        if (-not (Test-Path $zip)) { throw "zip not found: $zip" }
        $info = Get-ZipSolutionInfo $zip
        if ($info.Version -ne $i.versionToImport) { throw "zip version $($info.Version) is not the version to import $($i.versionToImport)" }
        if ($info.Managed -ne '0') { throw 'zip is managed; this stage imports unmanaged zips' }
        if ($DryRun) { $row.result = 'checked'; $results.Add([pscustomobject]$row); continue }
        $args = @('solution', 'import', '--path', $zip, '--async', '--force-overwrite', '--publish-changes', '--max-async-wait-time', $MaxWaitMinutes)
        if ($SettingsDir) { $sf = Join-Path $SettingsDir "$($i.solution).json"; if (Test-Path $sf) { $args += @('--settings-file', $sf) } }
        Write-Log "import #$($i.seq) $($i.solution) $($i.versionToImport)"
        & pac @args | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "pac solution import failed (exit $LASTEXITCODE)" }
        $row.result = 'imported'
    } catch {
        $row.result = 'failed'; $row.note = $_.Exception.Message; $failed = $true
        Add-AdoError "#$($i.seq) $($i.solution): $($row.note)"
    }
    $results.Add([pscustomobject]$row)
    if ($failed -and -not $ContinueOnError) { break }
}
$results | Export-Csv $ResultFile -NoTypeInformation -Encoding utf8
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($failed) { exit 1 }
