<#
.SYNOPSIS
  D7: read-only download of production web resources and plugin assemblies that differ or are missing in UAT (lists in pipelines/config). GET requests only.
.DESCRIPTION
  Saves each file under -OutDir (webresources, plugins) with an index.json (name, file, bytes, SHA-256). One request at a time with a pause.
  No business records are read. Production is only read.
#>
param([Parameter(Mandatory)][string]$OutDir, [ValidateSet('WebResources', 'PluginAssemblies')][string[]]$Types = @('WebResources', 'PluginAssemblies'), [int]$DelayMs = 1500)
. "$PSScriptRoot\Common.ps1"
New-Item -ItemType Directory -Force "$OutDir\webresources", "$OutDir\plugins" | Out-Null
$null = Invoke-Dv -Key PROD -Path 'WhoAmI' -DelayMs $DelayMs
$index = New-Object System.Collections.Generic.List[object]
function Save-Bytes([string]$Kind, [string]$Name, [string]$B64) {
    $file = ($Name -replace '[\\/:*?"<>|]', '__')
    $path = Join-Path "$OutDir\$Kind" $file
    $bytes = [Convert]::FromBase64String($B64)
    [IO.File]::WriteAllBytes($path, $bytes)
    $index.Add([pscustomobject]@{ kind = $Kind; name = $Name; file = "$Kind\$file"; bytes = $bytes.Length; sha256 = (Get-FileSha256 $path) })
}
if ($Types -contains 'WebResources') {
    $names = @((Get-PipelineConfig 'web-resources-candidates.json').items | ForEach-Object { $_.name })
    Write-Log "$($names.Count) web resources to read"
    foreach ($n in $names) {
        $q = "webresourceset?`$select=name,content&`$filter=name eq '" + ($n -replace "'", "''") + "'"
        $r = (Invoke-Dv -Key PROD -Path $q -DelayMs $DelayMs).value
        if (@($r).Count -eq 0 -or -not $r[0].content) { Add-AdoWarning "web resource not found in production: $n"; continue }
        Save-Bytes 'webresources' $n $r[0].content
    }
}
if ($Types -contains 'PluginAssemblies') {
    $names = @((Get-PipelineConfig 'plugin-assemblies.json').names)
    Write-Log "$($names.Count) plugin assemblies to read"
    foreach ($n in $names) {
        $q = "pluginassemblies?`$select=name,version,content&`$filter=name eq '" + ($n -replace "'", "''") + "'"
        $r = (Invoke-Dv -Key PROD -Path $q -DelayMs $DelayMs).value
        if (@($r).Count -eq 0 -or -not $r[0].content) { Add-AdoWarning "plugin assembly not found in production: $n"; continue }
        Save-Bytes 'plugins' $n $r[0].content
    }
}
($index | ConvertTo-Json -Depth 4) | Set-Content "$OutDir\index.json" -Encoding utf8
Write-Log "saved $($index.Count) files"
