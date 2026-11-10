<#
.SYNOPSIS
  A6 step 7: makes the freshly copied UAT-ALIGN safe. Turns off every active cloud flow so nothing runs against live systems. -DryRun only lists them.
  Writes only to the writable environment key (enforced). Mailboxes, queues and connections are checked by hand (see the Steps sheet, step A6).
#>
param([string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\safemode-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$flows = Invoke-DvAll -Key $TargetKey -Path 'workflows?$select=workflowid,name,statecode&$filter=category eq 5 and statecode eq 1'
Write-Log "$($flows.Count) active cloud flows in $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]
foreach ($f in $flows) {
    $row = [ordered]@{ name = $f.name; id = $f.workflowid; action = if ($DryRun) { 'would turn off' } else { 'turned off' }; note = '' }
    if (-not $DryRun) { try { Invoke-Dv -Key $TargetKey -Path "workflows($($f.workflowid))" -Method PATCH -Body @{ statecode = 0; statuscode = 1 } | Out-Null } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$($f.name): $($row.note)" } }
    $report.Add([pscustomobject]$row)
}
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
