<#
.SYNOPSIS
  Searches an unpacked Dataverse solution for references to a list of columns and
  writes a "where used" matrix (hit counts per component category).

.PARAMETER UnpackedPath
  Folder produced by: pac solution unpack --zipfile Base.zip --folder .\unpacked --packagetype Unmanaged

.PARAMETER FieldListCsv
  CSV with a header row and a column named LogicalName (optionally Table). One row per candidate column.

.PARAMETER OutCsv
  Where to write the matrix.

.EXAMPLE
  .\Search-FieldUsage.ps1 -UnpackedPath .\unpacked -FieldListCsv .\fields.csv -OutCsv .\usage-matrix.csv
#>
param(
    [Parameter(Mandatory)] [string] $UnpackedPath,
    [Parameter(Mandatory)] [string] $FieldListCsv,
    [string] $OutCsv = '.\usage-matrix.csv'
)

$fields = Import-Csv $FieldListCsv
if (-not ($fields | Get-Member -Name LogicalName)) { throw "FieldListCsv needs a LogicalName column." }

function Get-Category([string] $path) {
    $p = $path.ToLowerInvariant()
    if     ($p -match '\\entities\\[^\\]+\\entity\.xml$') { 'Definition' }   # the column's own metadata
    elseif ($p -match '\\formxml\\')                      { 'Forms' }
    elseif ($p -match '\\savedqueries\\')                 { 'Views' }
    elseif ($p -match '\\charts?\\|visualization')        { 'Charts' }
    elseif ($p -match '\\workflows\\')                    { 'WorkflowsAndFlows' }
    elseif ($p -match '\\webresources\\')                 { 'WebResources' }
    elseif ($p -match '\\pluginassemblies\\|sdkmessageprocessingsteps') { 'Plugins' }
    elseif ($p -match '\\reports\\')                      { 'Reports' }
    elseif ($p -match '\\dashboards\\')                   { 'Dashboards' }
    elseif ($p -match '\\appmodules\\|\\canvasapps\\')    { 'Apps' }
    else                                                  { 'Other' }
}

$categories = 'Forms','Views','Charts','WorkflowsAndFlows','WebResources','Plugins','Reports','Dashboards','Apps','Other'
$counts = @{}          # field -> category -> hits
$files  = @{}          # field -> list of "category: relative path"
foreach ($f in $fields) {
    $counts[$f.LogicalName] = @{}; $files[$f.LogicalName] = New-Object System.Collections.Generic.List[string]
    foreach ($c in $categories) { $counts[$f.LogicalName][$c] = 0 }
}

$root = (Resolve-Path $UnpackedPath).Path
$textExt = '.xml','.json','.js','.html','.htm','.xaml','.rdl','.txt','.resx','.config'
$all = Get-ChildItem -Path $root -Recurse -File | Where-Object { $textExt -contains $_.Extension.ToLowerInvariant() }
Write-Host "Scanning $($all.Count) files for $($fields.Count) fields..."

foreach ($file in $all) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($text)) { continue }
    $text = $text.ToLowerInvariant()
    $cat = Get-Category $file.FullName
    $rel = $file.FullName.Substring($root.Length).TrimStart('\')
    foreach ($f in $fields) {
        $name = $f.LogicalName.ToLowerInvariant()
        # whole-name match so abc_field1 does not hit abc_field10
        $n = ([regex]::Matches($text, "(?<![a-z0-9_])_?$([regex]::Escape($name))(?:_value)?(?![a-z0-9_])")).Count
        if ($n -gt 0) {
            $counts[$f.LogicalName][$cat] += $n
            if ($cat -ne 'Definition') { $files[$f.LogicalName].Add("${cat}: $rel") }
        }
    }
}

$result = foreach ($f in $fields) {
    $row = [ordered]@{ Table = $f.Table; LogicalName = $f.LogicalName }
    $total = 0
    foreach ($c in $categories) { $row[$c] = $counts[$f.LogicalName][$c]; $total += $counts[$f.LogicalName][$c] }
    $row['TotalReferencesExclDefinition'] = $total
    $row['Files'] = ($files[$f.LogicalName] | Select-Object -Unique) -join ' | '
    [pscustomobject]$row
}
$result | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "Wrote $OutCsv"
Write-Host "Fields with zero references in the solution: $(@($result | Where-Object TotalReferencesExclDefinition -eq 0).Count) of $($result.Count)"
Write-Host "Reminder: this covers the solution only. Also run Get-DataverseUsage.ps1 and check integrations, Power BI and plugin source."
