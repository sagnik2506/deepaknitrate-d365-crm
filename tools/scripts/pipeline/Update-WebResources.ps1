<#
.SYNOPSIS
  F2: makes approved web resources in UAT-ALIGN equal to the production files downloaded by Get-ProductionComponents.ps1.
.DESCRIPTION
  Only names listed in pipelines/config/approved-web-resources.json are changed (empty list = nothing changes). Each entry is a name, or { "name": ..., "solution": ... } for a web resource that does
  not exist in UAT-ALIGN yet (it is created and added to that solution). -DryRun lists what would change. Changed items are published at the end.
  Writes only to the writable environment key (enforced).
#>
param([Parameter(Mandatory)][string]$SourceDir, [string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\webresources-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-web-resources.json').approved)
$solMap = Get-PipelineConfig 'web-resources-solutions.json'
$index = @{}; foreach ($x in (Get-Content (Join-Path $SourceDir 'index.json') -Raw | ConvertFrom-Json)) { if ($x.kind -eq 'webresources') { $index[$x.name] = $x } }
$types = @{ '.html' = 1; '.htm' = 1; '.css' = 2; '.js' = 3; '.xml' = 4; '.png' = 5; '.jpg' = 6; '.jpeg' = 6; '.gif' = 7; '.xap' = 8; '.xsl' = 9; '.xslt' = 9; '.ico' = 10; '.svg' = 11; '.resx' = 12 }
Write-Log "$($approved.Count) approved web resources; target $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]; $toPublish = New-Object System.Collections.Generic.List[string]
foreach ($a in $approved) {
    $name = if ($a -is [string]) { $a } else { [string]$a.name }
    $solution = if ($a -isnot [string] -and $a.solution) { [string]$a.solution } elseif ($solMap.items.PSObject.Properties.Name -contains $name) { ([string]$solMap.items.$name -split ';')[0].Trim() } else { '' }
    $row = [ordered]@{ name = $name; action = ''; note = '' }
    try {
        if (-not $index.ContainsKey($name)) { throw 'no production file in the source folder' }
        $src = $index[$name]; $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SourceDir $src.file)))
        $q = "webresourceset?`$select=webresourceid,name,content&`$filter=name eq '" + ($name -replace "'", "''") + "'"
        $cur = @((Invoke-Dv -Key $TargetKey -Path $q).value)
        if ($cur.Count -gt 0) {
            if ($cur[0].content -eq $b64) { $row.action = 'same'; $report.Add([pscustomobject]$row); continue }
            $row.action = 'update'
            if (-not $DryRun) { Invoke-Dv -Key $TargetKey -Path "webresourceset($($cur[0].webresourceid))" -Method PATCH -Body @{ content = $b64 } | Out-Null; $toPublish.Add([string]$cur[0].webresourceid) }
        } else {
            $row.action = 'create'
            if (-not $solution) { throw 'does not exist in UAT-ALIGN and no solution is given (add "solution" to the approved entry)' }
            $ext = [IO.Path]::GetExtension($name).ToLower(); if (-not $types.ContainsKey($ext)) { throw "unknown file type $ext" }
            if (-not $DryRun) {
                $created = Invoke-Dv -Key $TargetKey -Path 'webresourceset' -Method POST -Body @{ name = $name; displayname = $name; webresourcetype = $types[$ext]; content = $b64 } -ExtraHeaders @{ 'MSCRM.SolutionUniqueName' = $solution; Prefer = 'return=representation' }
                $toPublish.Add([string]$created.webresourceid)
            }
        }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$name : $($row.note)" }
    $report.Add([pscustomobject]$row)
}
if ($toPublish.Count -gt 0) {
    $xml = '<importexportxml><webresources>' + (($toPublish | ForEach-Object { "<webresource>{$_}</webresource>" }) -join '') + '</webresources></importexportxml>'
    Invoke-Dv -Key $TargetKey -Path 'PublishXml' -Method POST -Body @{ ParameterXml = $xml } | Out-Null
    Write-Log "published $($toPublish.Count) web resources"
}
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Format-Table -AutoSize | Out-String | Write-Host
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
