<#
.SYNOPSIS
  F6: sets the active or draft state of business rules and classic workflows in UAT-ALIGN to the production state (pipelines/config/flow-states.json).
  Cloud flows (category 5) are skipped unless -IncludeCloudFlows: they need connections first (step J7) and must not be switched on before the safety checks.
  -DryRun lists what would change. Writes only to the writable environment key (enforced).
#>
param([string]$TargetKey = 'ALIGN', [switch]$DryRun, [switch]$IncludeCloudFlows, [string]$ReportFile = '.\flowstate-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$items = @((Get-PipelineConfig 'flow-states.json').items)
$report = New-Object System.Collections.Generic.List[object]
foreach ($i in $items) {
    $row = [ordered]@{ name = $i.name; id = $i.id; wantState = $i.prodState; category = ''; action = ''; note = '' }
    try {
        $w = Invoke-Dv -Key $TargetKey -Path "workflows($($i.id))?`$select=name,category,statecode"
        $row.category = [string]$w.category
        if ([int]$w.category -eq 5 -and -not $IncludeCloudFlows) { $row.action = 'skipped (cloud flow)' }
        elseif ([int]$w.statecode -eq [int]$i.prodState) { $row.action = 'already equal' }
        else {
            $row.action = if ($i.prodState -eq 1) { 'activate' } else { 'set to draft' }
            if (-not $DryRun) {
                $body = if ($i.prodState -eq 1) { @{ statecode = 1; statuscode = 2 } } else { @{ statecode = 0; statuscode = 1 } }
                Invoke-Dv -Key $TargetKey -Path "workflows($($i.id))" -Method PATCH -Body $body | Out-Null
            }
        }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$($i.name): $($row.note)" }
    $report.Add([pscustomobject]$row)
}
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Group-Object action | ForEach-Object { Write-Log "$($_.Name): $($_.Count)" }
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
