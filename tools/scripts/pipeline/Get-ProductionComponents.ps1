<#
.SYNOPSIS
  D7: read-only download of production components that differ or are missing in UAT (lists in pipelines/config). GET requests only. No business records are read.
.DESCRIPTION
  WebResources, PluginAssemblies : files (base64 content decoded).        Forms : form XML.        Views : fetch and layout XML.
  PluginSteps : the definition (message, table, stage, mode, rank, filtering attributes, configuration, images) of the steps that exist only in production.
  Roles : id and name of the production roles (needed to translate role ids inside form XML).
  Everything is saved under -OutDir with an index.json. One request at a time with a pause. Production is only read.
#>
param([Parameter(Mandatory)][string]$OutDir,
      [ValidateSet('WebResources', 'PluginAssemblies', 'Forms', 'Views', 'PluginSteps', 'Roles')][string[]]$Types = @('WebResources', 'PluginAssemblies', 'Forms', 'Views', 'PluginSteps', 'Roles'),
      [int]$DelayMs = 1500)
. "$PSScriptRoot\Common.ps1"
foreach ($d in 'webresources', 'plugins', 'forms', 'views', 'steps') { New-Item -ItemType Directory -Force (Join-Path $OutDir $d) | Out-Null }
$null = Invoke-Dv -Key PROD -Path 'WhoAmI' -DelayMs $DelayMs
$index = New-Object System.Collections.Generic.List[object]
function Save-Bytes([string]$Kind, [string]$Name, [string]$B64) {
    $file = ($Name -replace '[\\/:*?"<>|]', '__')
    $path = Join-Path (Join-Path $OutDir $Kind) $file
    $bytes = [Convert]::FromBase64String($B64)
    [IO.File]::WriteAllBytes($path, $bytes)
    $index.Add([pscustomobject]@{ kind = $Kind; name = $Name; file = "$Kind\$file"; bytes = $bytes.Length; sha256 = (Get-FileSha256 $path) })
}
function Save-Text([string]$Kind, [string]$Id, [string]$Name, [string]$Text, [string]$Ext) {
    $path = Join-Path (Join-Path $OutDir $Kind) "$Id.$Ext"
    [IO.File]::WriteAllText($path, $Text, (New-Object Text.UTF8Encoding($false)))
    $index.Add([pscustomobject]@{ kind = $Kind; id = $Id; name = $Name; file = "$Kind\$Id.$Ext"; bytes = $Text.Length; sha256 = (Get-FileSha256 $path) })
}
if ($Types -contains 'WebResources') {
    $names = @((Get-PipelineConfig 'web-resources-candidates.json').items | ForEach-Object { $_.name })
    Write-Log "$($names.Count) web resources to read"
    foreach ($n in $names) {
        $q = "webresourceset?`$select=name,content&`$filter=name eq '" + ($n -replace "'", "''") + "'"
        $r = @((Invoke-Dv -Key PROD -Path $q -DelayMs $DelayMs).value)
        if ($r.Count -eq 0 -or -not $r[0].content) { Add-AdoWarning "web resource not found in production: $n"; continue }
        Save-Bytes 'webresources' $n $r[0].content
    }
}
if ($Types -contains 'PluginAssemblies') {
    $names = @((Get-PipelineConfig 'plugin-assemblies.json').names)
    Write-Log "$($names.Count) plugin assemblies to read"
    foreach ($n in $names) {
        $q = "pluginassemblies?`$select=name,version,content&`$filter=name eq '" + ($n -replace "'", "''") + "'"
        $r = @((Invoke-Dv -Key PROD -Path $q -DelayMs $DelayMs).value)
        if ($r.Count -eq 0 -or -not $r[0].content) { Add-AdoWarning "plugin assembly not found in production: $n"; continue }
        Save-Bytes 'plugins' $n $r[0].content
    }
}
if ($Types -contains 'Forms') {
    $items = @((Get-PipelineConfig 'forms-views-candidates.json').items | Where-Object { $_.type -eq 'Form' })
    Write-Log "$($items.Count) forms to read"
    foreach ($i in $items) {
        $r = Invoke-Dv -Key PROD -Path "systemforms($($i.id))?`$select=name,formxml,objecttypecode" -DelayMs $DelayMs
        Save-Text 'forms' $i.id $r.name $r.formxml 'xml'
    }
}
if ($Types -contains 'Views') {
    $items = @((Get-PipelineConfig 'forms-views-candidates.json').items | Where-Object { $_.type -eq 'View' })
    Write-Log "$($items.Count) views to read"
    foreach ($i in $items) {
        $r = Invoke-Dv -Key PROD -Path "savedqueries($($i.id))?`$select=name,fetchxml,layoutxml,returnedtypecode,querytype" -DelayMs $DelayMs
        $json = [ordered]@{ name = $r.name; table = $r.returnedtypecode; queryType = $r.querytype; fetchxml = $r.fetchxml; layoutxml = $r.layoutxml } | ConvertTo-Json -Depth 3
        Save-Text 'views' $i.id $r.name $json 'json'
    }
}
if ($Types -contains 'PluginSteps') {
    $items = @((Get-PipelineConfig 'plugin-steps.json').items)
    Write-Log "$($items.Count) plugin steps to read"
    foreach ($i in $items) {
        $q = "sdkmessageprocessingsteps($($i.id))?`$select=name,description,stage,mode,rank,filteringattributes,supporteddeployment,asyncautodelete,configuration,statecode&`$expand=plugintypeid(`$select=typename),sdkmessageid(`$select=name),sdkmessagefilterid(`$select=primaryobjecttypecode)"
        $r = Invoke-Dv -Key PROD -Path $q -DelayMs $DelayMs
        $imgs = @((Invoke-Dv -Key PROD -Path "sdkmessageprocessingstepimages?`$select=name,entityalias,imagetype,attributes,messagepropertyname,description&`$filter=_sdkmessageprocessingstepid_value eq $($i.id)" -DelayMs $DelayMs).value)
        $o = [ordered]@{ id = $i.id; name = $r.name; description = $r.description; stage = $r.stage; mode = $r.mode; rank = $r.rank; filteringattributes = $r.filteringattributes; supporteddeployment = $r.supporteddeployment
            asyncautodelete = $r.asyncautodelete; configuration = $r.configuration; statecode = $r.statecode; pluginType = $r.plugintypeid.typename; message = $r.sdkmessageid.name
            entity = $(if ($r.sdkmessagefilterid) { $r.sdkmessagefilterid.primaryobjecttypecode } else { '' }); solutions = $i.solutions
            images = @($imgs | ForEach-Object { [ordered]@{ name = $_.name; entityalias = $_.entityalias; imagetype = $_.imagetype; attributes = $_.attributes; messagepropertyname = $_.messagepropertyname; description = $_.description } }) }
        Save-Text 'steps' $i.id $r.name ($o | ConvertTo-Json -Depth 5) 'json'
    }
}
if ($Types -contains 'Roles') {
    $roles = Invoke-DvAll -Key PROD -Path 'roles?$select=roleid,name&$filter=_parentroleid_value eq null' -DelayMs $DelayMs
    $roles | ForEach-Object { [ordered]@{ id = ([string]$_.roleid).ToLower(); name = $_.name } } | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $OutDir 'roles.json') -Encoding utf8
    Write-Log "$(@($roles).Count) production roles saved"
}
($index | ConvertTo-Json -Depth 4) | Set-Content (Join-Path $OutDir 'index.json') -Encoding utf8
Write-Log "saved $($index.Count) files"
