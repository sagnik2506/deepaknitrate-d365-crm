<#
.SYNOPSIS
  F7: sets the production value of column properties that differ in UAT-ALIGN (pipelines/config/column-properties.json): maximum length, money precision and precision source, required level.
.DESCRIPTION
  Only columns listed as "table.column" in pipelines/config/approved-column-properties.json are changed (empty = nothing changes). The script reads the column definition, changes the property and writes the
  definition back (PUT with merge labels), then publishes the table. The platform may refuse a change (for example a decrease of a text length); that is reported as failed and the column is left as it was.
  UAT-ALIGN holds no business records, so these changes are safe to try there. -DryRun lists what would change. Writes only to the writable environment key (enforced).
#>
param([string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\column-properties-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-column-properties.json').approved)
$items = @((Get-PipelineConfig 'column-properties.json').items | Where-Object { $approved -contains "$($_.table).$($_.column)" })
Write-Log "$($items.Count) property changes for $($approved.Count) approved columns; target $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]; $entities = New-Object System.Collections.Generic.List[string]
foreach ($g in ($items | Group-Object { "$($_.table).$($_.column)" })) {
    $t = $g.Group[0].table; $c = $g.Group[0].column
    $row = [ordered]@{ column = $g.Name; changes = (($g.Group | ForEach-Object { "$($_.property): $($_.uatValue) -> $($_.prodValue)" }) -join '; '); action = ''; note = '' }
    try {
        $path = "EntityDefinitions(LogicalName='$t')/Attributes(LogicalName='$c')"
        $attr = Invoke-Dv -Key $TargetKey -Path $path
        $todo = New-Object System.Collections.Generic.List[string]
        foreach ($p in $g.Group) {
            switch ($p.property) {
                'MaxLength' { if ([string]$attr.MaxLength -ne [string]$p.prodValue) { $attr.MaxLength = [int]$p.prodValue; $todo.Add('MaxLength') } }
                'Precision' { if ([string]$attr.Precision -ne [string]$p.prodValue) { $attr.Precision = [int]$p.prodValue; $todo.Add('Precision') } }
                'PrecisionSource' { if ([string]$attr.PrecisionSource -ne [string]$p.prodValue) { $attr.PrecisionSource = [int]$p.prodValue; $todo.Add('PrecisionSource') } }
                'Required' { if ([string]$attr.RequiredLevel.Value -ne [string]$p.prodValue) { $attr.RequiredLevel.Value = [string]$p.prodValue; $todo.Add('RequiredLevel') } }
                default { $row.note += "property $($p.property) is not handled; " }
            }
        }
        if ($todo.Count -eq 0) { $row.action = 'already equal'; $report.Add([pscustomobject]$row); continue }
        $row.action = 'update'
        if (-not $DryRun) {
            $body = $attr | Select-Object * -ExcludeProperty '@odata.context'
            Invoke-Dv -Key $TargetKey -Path $path -Method PUT -Body $body -ExtraHeaders @{ 'MSCRM.MergeLabels' = 'true' } | Out-Null
            $entities.Add($t)
        }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$($g.Name): $($row.note)" }
    $report.Add([pscustomobject]$row)
}
if (-not $DryRun) { Publish-Entities $TargetKey $entities }
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Group-Object action | ForEach-Object { Write-Log "$($_.Name): $($_.Count)" }
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
