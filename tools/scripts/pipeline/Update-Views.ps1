<#
.SYNOPSIS
  F5: makes approved views in UAT-ALIGN equal to the production fetch and layout XML downloaded by Get-ProductionComponents.ps1.
.DESCRIPTION
  Only view ids listed in pipelines/config/approved-views.json are changed (empty = nothing changes). The table object type code in the layout XML differs between environments, so the code that
  UAT-ALIGN already uses is kept. A view that is already equal after normalising is left alone. A view that does not exist in UAT-ALIGN is reported, not created: it has to come with its solution.
  -DryRun lists what would change. Changed tables are published at the end. Writes only to the writable environment key (enforced).
#>
param([Parameter(Mandatory)][string]$SourceDir, [string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\views-report.csv')
. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\ContentTools.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-views.json').approved | ForEach-Object { ([string]$_).ToLower() })
Write-Log "$($approved.Count) approved views; target $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]; $entities = New-Object System.Collections.Generic.List[string]
foreach ($id in $approved) {
    $row = [ordered]@{ id = $id; name = ''; action = ''; note = '' }
    try {
        $file = Join-Path $SourceDir "views\$id.json"
        if (-not (Test-Path $file)) { throw 'no production view in the source folder (is the id in forms-views-candidates.json?)' }
        $prod = Get-Content $file -Raw | ConvertFrom-Json
        $cur = $null
        try { $cur = Invoke-Dv -Key $TargetKey -Path "savedqueries($id)?`$select=name,fetchxml,layoutxml,returnedtypecode" } catch { if ([int]$_.Exception.Response.StatusCode -ne 404) { throw } }
        if (-not $cur) { $row.action = 'missing in target'; $row.note = 'not created by this script: import it with its solution'; $report.Add([pscustomobject]$row); continue }
        $row.name = $cur.name
        $newLayout = Convert-ViewObjectCode ([string]$prod.layoutxml) ([string]$cur.layoutxml)
        $a = (Get-EnvNormText 'Views' ([string]$prod.fetchxml + "`n" + $newLayout)); $b = (Get-EnvNormText 'Views' ([string]$cur.fetchxml + "`n" + [string]$cur.layoutxml))
        if ($a -eq $b) { $row.action = 'same'; $report.Add([pscustomobject]$row); continue }
        $row.action = 'update'
        if (-not $DryRun) { Invoke-Dv -Key $TargetKey -Path "savedqueries($id)" -Method PATCH -Body @{ fetchxml = [string]$prod.fetchxml; layoutxml = $newLayout } | Out-Null; $entities.Add([string]$cur.returnedtypecode) }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$id : $($row.note)" }
    $report.Add([pscustomobject]$row)
}
if (-not $DryRun) { Publish-Entities $TargetKey $entities }
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Group-Object action | ForEach-Object { Write-Log "$($_.Name): $($_.Count)" }
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
