<#
.SYNOPSIS
  F4: makes approved forms in UAT-ALIGN equal to the production form XML downloaded by Get-ProductionComponents.ps1.
.DESCRIPTION
  Only form ids listed in pipelines/config/approved-forms.json are changed (empty = nothing changes). Role ids inside the XML are translated from production role ids to the ids of the roles with the
  same name in UAT-ALIGN (roles must exist: align roles first, step H2); roles that do not exist are removed from the XML and reported. A form that is already equal after normalising (role ids, order, GUIDs)
  is left alone. A form that does not exist in UAT-ALIGN is reported, not created: it has to come with its solution. -DryRun lists what would change. Changed tables are published at the end.
  Writes only to the writable environment key (enforced).
#>
param([Parameter(Mandatory)][string]$SourceDir, [string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\forms-report.csv')
. "$PSScriptRoot\Common.ps1"
. "$PSScriptRoot\ContentTools.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-forms.json').approved | ForEach-Object { ([string]$_).ToLower() })
$prodRoles = @{}; foreach ($r in (Get-Content (Join-Path $SourceDir 'roles.json') -Raw | ConvertFrom-Json)) { $prodRoles[([string]$r.id).ToLower()] = [string]$r.name }
$targetRoles = @{}; foreach ($r in (Invoke-DvAll -Key $TargetKey -Path 'roles?$select=roleid,name&$filter=_parentroleid_value eq null')) { $targetRoles[[string]$r.name] = ([string]$r.roleid).ToLower() }
Write-Log "$($approved.Count) approved forms; $($prodRoles.Count) production roles; $($targetRoles.Count) roles in $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]; $entities = New-Object System.Collections.Generic.List[string]
foreach ($id in $approved) {
    $row = [ordered]@{ id = $id; name = ''; action = ''; note = '' }
    try {
        $file = Join-Path $SourceDir "forms\$id.xml"
        if (-not (Test-Path $file)) { throw 'no production form XML in the source folder (is the id in forms-views-candidates.json?)' }
        $prodXml = [IO.File]::ReadAllText($file)
        $missing = New-Object System.Collections.Generic.List[string]
        $newXml = Convert-FormRoleIds $prodXml $prodRoles $targetRoles $missing
        $cur = $null
        try { $cur = Invoke-Dv -Key $TargetKey -Path "systemforms($id)?`$select=name,formxml,objecttypecode" } catch { if ([int]$_.Exception.Response.StatusCode -ne 404) { throw } }
        if (-not $cur) { $row.action = 'missing in target'; $row.note = 'not created by this script: import it with its solution'; $report.Add([pscustomobject]$row); continue }
        $row.name = $cur.name
        if ((Get-EnvNormText 'Forms' $newXml) -eq (Get-EnvNormText 'Forms' $cur.formxml)) { $row.action = 'same'; $report.Add([pscustomobject]$row); continue }
        $row.action = 'update'
        if ($missing.Count) { $row.note = 'roles dropped: ' + (($missing | Select-Object -Unique) -join '; ') }
        if (-not $DryRun) { Invoke-Dv -Key $TargetKey -Path "systemforms($id)" -Method PATCH -Body @{ formxml = $newXml } | Out-Null; $entities.Add([string]$cur.objecttypecode) }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$id : $($row.note)" }
    $report.Add([pscustomobject]$row)
}
if (-not $DryRun) { Publish-Entities $TargetKey $entities }
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Group-Object action | ForEach-Object { Write-Log "$($_.Name): $($_.Count)" }
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
