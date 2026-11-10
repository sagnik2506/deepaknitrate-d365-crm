<#
.SYNOPSIS
  F9: adds the global option set values that exist only in production (pipelines/config/option-values.json) to UAT-ALIGN. Removes values that exist only in UAT only with -AllowRemove.
  -DryRun lists what would change. Writes only to the writable environment key (enforced).
#>
param([string]$TargetKey = 'ALIGN', [switch]$DryRun, [switch]$AllowRemove, [string]$ReportFile = '.\optionset-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$items = @((Get-PipelineConfig 'option-values.json').items)
$report = New-Object System.Collections.Generic.List[object]; $changed = $false
foreach ($i in $items) {
    $row = [ordered]@{ optionSet = $i.optionSet; value = $i.value; status = $i.status; action = ''; note = '' }
    try {
        $def = Invoke-Dv -Key $TargetKey -Path "GlobalOptionSetDefinitions(Name='$($i.optionSet)')"
        $exists = @($def.Options | Where-Object { [int]$_.Value -eq [int]$i.value }).Count -gt 0
        if ($i.status -eq 'Only in PROD') {
            if ($exists) { $row.action = 'already there' }
            else {
                $row.action = 'add'
                if (-not $DryRun) {
                    $body = @{ OptionSetName = $i.optionSet; Value = [int]$i.value; Label = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $i.prodLabel; LanguageCode = 1033 }) } }
                    Invoke-Dv -Key $TargetKey -Path 'InsertOptionValue' -Method POST -Body $body | Out-Null; $changed = $true
                }
            }
        } elseif ($i.status -eq 'Only in UAT') {
            if (-not $exists) { $row.action = 'already gone' }
            elseif (-not $AllowRemove) { $row.action = 'kept (needs -AllowRemove and a signed Drop decision)' }
            else { $row.action = 'remove'; if (-not $DryRun) { Invoke-Dv -Key $TargetKey -Path 'DeleteOptionValue' -Method POST -Body @{ OptionSetName = $i.optionSet; Value = [int]$i.value } | Out-Null; $changed = $true } }
        } else { $row.action = 'label differs: not changed by this script' }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$($i.optionSet) $($i.value): $($row.note)" }
    $report.Add([pscustomobject]$row)
}
if ($changed) { Invoke-Dv -Key $TargetKey -Path 'PublishAllXml' -Method POST -Body @{} | Out-Null; Write-Log 'published all customizations' }
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Format-Table -AutoSize | Out-String | Write-Host
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
