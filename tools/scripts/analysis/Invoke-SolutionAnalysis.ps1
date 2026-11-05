<#
.SYNOPSIS
  OFFLINE analysis of an unpacked Dataverse solution (`pac solution unpack`). No connection to any
  environment is made and nothing is changed; it only reads files and writes CSVs.

  Phase 1 activities, done from the files alone:
    1.1  rank tables by column count               -> tables-ranked.csv, tables-top.csv
    1.2  completeness check of the extracted solution -> completeness.csv, component-counts.csv
    1.3  column audit with references               -> column-audit.csv, column-references.csv, field-decision-sheet.csv
    1.4  hand-edit / production-only detection      -> diff-vs-baseline.csv   (needs -BaselinePath)
    1.5  static complexity scorecard                -> form-complexity.csv, view-complexity.csv, plugin-steps.csv, workflows.csv
    1.6  manual-check matrix and integration hints  -> manual-check-matrix.csv, integration-hints.csv

.PARAMETER SolutionPath
  Folder from: pac solution unpack --zipfile Project.zip --folder .\unpacked --packagetype Unmanaged
  Best source: an unmanaged export built in a SANDBOX COPY OF PRODUCTION, so it reflects what production holds.

.PARAMETER BaselinePath
  Optional. An unpacked export of the version you last DEPLOYED to production (for example the release
  artifact in Git). Differences between the two folders point to hand edits or production-only items.

.PARAMETER Prefix
  Your publisher prefix, e.g. abc_ . Helps recognise custom columns.

.PARAMETER Table / AuditAllTables / AlsoInclude / TopN
  By default the top N tables by custom column count are audited. -Table audits the named tables;
  -AuditAllTables audits every table; -AlsoInclude adds tables the business calls slow.

WHAT AN OFFLINE RUN CANNOT KNOW (do these against the sandbox copy with the other scripts):
  * whether a column holds data                  -> Get-TableAttributeAudit.ps1 (HasData)
  * platform dependencies, personal views, flows or plugin steps that are not in this solution
                                                  -> Get-TableAttributeAudit.ps1 -IncludeReferences
  * real layers (Active layer)                    -> Get-ActiveLayerInventory.ps1
  * real timings (form load, save)                -> browser/Performance tools; the scorecard here is a
                                                     static proxy based on form, view and plugin design
  * record counts
A reference search by column NAME can attribute a hit to the wrong table when two tables share a column name.
The folder layout and XML shapes below follow `pac solution unpack` as I know them; if a count looks wrong,
check completeness.csv first and tell me what your folder looks like.

.EXAMPLE
  .\Invoke-SolutionAnalysis.ps1 -SolutionPath .\unpacked -BaselinePath .\release-1.4-unpacked -Prefix abc_ -AlsoInclude abc_application
#>
param(
    [Parameter(Mandatory)] [string] $SolutionPath,
    [string]   $BaselinePath,
    [string]   $Prefix,
    [string[]] $Table,
    [switch]   $AuditAllTables,
    [string[]] $AlsoInclude,
    [int]      $TopN = 5,
    [int]      $FormFieldWarn = 100,
    [int]      $FormTabWarn = 8,
    [int]      $SubgridWarn = 4,
    [int]      $ViewColumnWarn = 12,
    [int]      $ViewLinkWarn = 3,
    [string]   $OutDir = '.\solution-analysis',
    [string]   $JunkPattern = '(^|[_\W])(test|tst|temp|tmp|junk|dummy|demo|sample|xxx|zzz?|old|backup|bkp|copy|unused|deprecated|delete|donotuse|dnu|poc)([_\W\d]|$)'
)

# with "pwsh -File", -Param a,b arrives as one string; split a comma-separated list into separate values
if ($Table) { $Table = @($Table | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ($AlsoInclude) { $AlsoInclude = @($AlsoInclude | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$root = (Resolve-Path $SolutionPath).Path
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$sha = [System.Security.Cryptography.SHA256]::Create()

# ---------------------------------------------------------------- helpers
function Read-Xml([string] $path) {
    try { $d = New-Object System.Xml.XmlDocument; $d.PreserveWhitespace = $false; $d.LoadXml((Get-Content -LiteralPath $path -Raw -Encoding UTF8)); $d } catch { $null }
}
function ChildText($node, [string] $name) {
    if (-not $node) { return '' }
    $c = $node.SelectSingleNode($name); if ($c) { [string]$c.InnerText } else { '' }
}
function AttrOrChild($node, [string] $name) {
    if (-not $node) { return '' }
    $a = $node.GetAttribute($name); if ($a) { return $a }
    ChildText $node $name
}
function Hash([string] $text) { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))) }
function Rel([string] $full, [string] $base) { $full.Substring($base.Length).TrimStart('\', '/') }
function Get-Category([string] $rel) {
    $p = '\' + $rel.ToLowerInvariant().Replace('/', '\')
    if     ($p -match '\\entities\\[^\\]+\\entity\.xml$')   { 'Definition' }
    elseif ($p -match '\\formxml\\')                        { 'Form' }
    elseif ($p -match '\\savedqueries\\')                   { 'View' }
    elseif ($p -match '\\(charts|visualizations)\\')        { 'Chart' }
    elseif ($p -match '\\workflows\\')                      { 'Workflow/Flow' }
    elseif ($p -match '\\webresources\\')                   { 'WebResource/JS' }
    elseif ($p -match '\\(pluginassemblies|sdkmessageprocessingsteps)\\') { 'Plugin' }
    elseif ($p -match '\\reports\\')                        { 'Report' }
    elseif ($p -match '\\dashboards\\')                     { 'Dashboard' }
    elseif ($p -match '\\(appmodules|appmodulesitemaps|canvasapps)\\') { 'App' }
    elseif ($p -match '\\(roles|fieldsecurityprofiles)\\')  { 'Security' }
    elseif ($p -match '\\relationships\\')                  { 'Relationship' }
    else                                                    { 'Other' }
}
function Table-Of([string] $rel) { if ($rel -match '(?i)^entities[\\/]([^\\/]+)[\\/]') { $matches[1].ToLowerInvariant() } else { '' } }

$allFiles = @(Get-ChildItem -Path $root -Recurse -File)
Write-Host "Reading $($allFiles.Count) files from $root"

# ---------------------------------------------------------------- 1.2 completeness
$completeness = New-Object System.Collections.Generic.List[object]
function Chk($check, $status, $detail) { $completeness.Add([pscustomobject]@{ Check = $check; Status = $status; Detail = $detail }) }

$solXml = Read-Xml (Join-Path $root 'Other\Solution.xml')
if ($solXml) {
    $m = ChildText $solXml.DocumentElement 'SolutionManifest/Managed'
    Chk 'Solution.xml readable' 'OK' "UniqueName=$(ChildText $solXml.DocumentElement 'SolutionManifest/UniqueName'); Version=$(ChildText $solXml.DocumentElement 'SolutionManifest/Version')"
    Chk 'Unmanaged export' $(if ($m -eq '0') { 'OK' } else { 'WARNING' }) "Managed flag = '$m' (0 = unmanaged). An unmanaged export is needed to see the current definitions."
    $px = ChildText $solXml.DocumentElement 'SolutionManifest/Publisher/CustomizationPrefix'
    if ($px -and -not $Prefix) { $Prefix = "$px`_"; Chk 'Publisher prefix' 'INFO' "Using prefix '$Prefix' from Solution.xml" }
} else { Chk 'Solution.xml readable' 'WARNING' 'Other\Solution.xml not found or unreadable; is this the unpacked folder root?' }

$entFiles = @($allFiles | Where-Object { (Rel $_.FullName $root) -match '(?i)^entities[\\/][^\\/]+[\\/]entity\.xml$' })
Chk 'Tables found' $(if ($entFiles.Count) { 'OK' } else { 'ERROR' }) "$($entFiles.Count) Entity.xml file(s)"

$byCat = $allFiles | Group-Object { Get-Category (Rel $_.FullName $root) } | Sort-Object Name
$byCat | ForEach-Object { [pscustomobject]@{ Category = $_.Name; Files = $_.Count } } | Export-Csv "$OutDir\component-counts.csv" -NoTypeInformation -Encoding UTF8
foreach ($want in 'Form', 'View', 'Workflow/Flow', 'WebResource/JS', 'Plugin', 'Dashboard', 'App', 'Security', 'Report') {
    $n = @($byCat | Where-Object Name -eq $want).Count
    $cnt = if ($n) { ($byCat | Where-Object Name -eq $want).Count } else { 0 }
    Chk "Contains $want" $(if ($n) { 'OK' } else { 'CHECK' }) $(if ($n) { "$cnt file(s)" } else { "none found - fine if the project has none; otherwise ask the team to add them to the solution" })
}
$hasAsm   = @($allFiles | Where-Object { (Rel $_.FullName $root) -match '(?i)^pluginassemblies[\\/]' }).Count
$hasSteps = @($allFiles | Where-Object { (Rel $_.FullName $root) -match '(?i)^sdkmessageprocessingsteps[\\/]' }).Count
if ($hasAsm -and -not $hasSteps) { Chk 'Plugin steps' 'WARNING' 'Plugin assemblies are in the solution but no step registrations are. Stage, sync/async mode and filtering attributes cannot be checked offline; run Get-TableAttributeAudit.ps1 -IncludeReferences against the sandbox, and search the plugin source code.' }

# ---------------------------------------------------------------- tables and columns (1.1)
$cols = New-Object System.Collections.Generic.List[object]
$tables = @{}
foreach ($f in $entFiles) {
    $rel = Rel $f.FullName $root
    $tname = (Table-Of $rel)
    $doc = Read-Xml $f.FullName
    if (-not $doc) { Chk "Parse $rel" 'ERROR' 'XML could not be read'; continue }
    $attrNodes = @($doc.SelectNodes('//attributes/attribute'))
    $tables[$tname] = [pscustomobject]@{ Name = $tname; Doc = $doc; Rel = $rel; Total = 0; Custom = 0; Lookups = 0; Text = 0; OptionSets = 0; Other = 0; MaxLenSum = 0; Forms = 0; Views = 0; Steps = 0; Workflows = 0 }
    foreach ($a in $attrNodes) {
        $ln = (ChildText $a 'LogicalName'); if (-not $ln) { $ln = (ChildText $a 'Name') }; if (-not $ln) { $ln = $a.GetAttribute('PhysicalName') }
        $ln = $ln.ToLowerInvariant(); if (-not $ln) { continue }
        $type = (ChildText $a 'Type').ToLowerInvariant()
        if ($type -eq 'primarykey' -or (ChildText $a 'AttributeOf')) { continue }
        $isCustom = ((ChildText $a 'IsCustomField') -eq '1') -or ($Prefix -and $ln.StartsWith($Prefix.ToLowerInvariant()))
        $label = ''
        $dn = $a.SelectSingleNode("displaynames/displayname[@languagecode='1033']"); if (-not $dn) { $dn = $a.SelectSingleNode('displaynames/displayname') }
        if ($dn) { $label = $dn.GetAttribute('description') }
        $len = 0; [void][int]::TryParse((ChildText $a 'MaxLength'), [ref]$len); if (-not $len) { [void][int]::TryParse((ChildText $a 'Length'), [ref]$len) }
        $cols.Add([pscustomobject]@{ Table = $tname; Name = $ln; Label = $label; Type = $type; Custom = $isCustom; Required = (ChildText $a 'RequiredLevel').ToLowerInvariant(); Len = $len; Node = $a })
        $t = $tables[$tname]; $t.Total++
        if ($isCustom) {
            $t.Custom++
            if ($type -in 'lookup', 'owner', 'customer') { $t.Lookups++ }
            elseif ($type -in 'nvarchar', 'ntext', 'varchar') { $t.Text++; $t.MaxLenSum += $len }
            elseif ($type -in 'picklist', 'state', 'status', 'multiselectpicklist') { $t.OptionSets++ }
            else { $t.Other++ }
        }
    }
}
# every money column has a platform-generated base-currency twin (<name>_base); it cannot be deleted on its own
$byKey = @{}; foreach ($c in $cols) { $byKey["$($c.Table)|$($c.Name)"] = $c }
foreach ($c in $cols) {
    $c | Add-Member -NotePropertyName Companion -NotePropertyValue '' -Force
    if ($c.Type -eq 'money' -and $c.Name.EndsWith('_base')) {
        $p = $c.Name.Substring(0, $c.Name.Length - 5)
        if ($byKey.ContainsKey("$($c.Table)|$p")) { $c.Companion = $p }
    }
}
foreach ($f in $allFiles) {
    $rel = Rel $f.FullName $root; $t = Table-Of $rel; if (-not $t -or -not $tables.ContainsKey($t)) { continue }
    switch (Get-Category $rel) { 'Form' { $tables[$t].Forms++ } 'View' { $tables[$t].Views++ } }
}
$ranked = @($tables.Values | Sort-Object Custom, Total -Descending)
$ranked | ForEach-Object {
    $tn = $_.Name
    $comp  = @($cols | Where-Object { $_.Table -eq $tn -and $_.Companion }).Count
    $money = @($cols | Where-Object { $_.Table -eq $tn -and $_.Custom -and $_.Type -eq 'money' -and -not $_.Companion }).Count
    [pscustomobject][ordered]@{ Table = $_.Name; TotalColumns = $_.Total; CustomColumns = $_.Custom; BaseCurrencyCompanions = $comp; CustomColumnsExclCompanions = ($_.Custom - $comp)
        CustomMoney = $money; CustomLookups = $_.Lookups; CustomText = $_.Text; CustomOptionSets = $_.OptionSets; CustomOtherTypes = $_.Other
        CustomTextMaxLenSum = $_.MaxLenSum; FormFiles = $_.Forms; ViewFiles = $_.Views } } |
    Export-Csv "$OutDir\tables-ranked.csv" -NoTypeInformation -Encoding UTF8
$topNames = @($ranked | Select-Object -First $TopN | ForEach-Object { $_.Name }) + @($AlsoInclude | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }) | Select-Object -Unique
$topNames | ForEach-Object { [pscustomobject]@{ Table = $_ } } | Export-Csv "$OutDir\tables-top.csv" -NoTypeInformation -Encoding UTF8
$auditTables = if ($AuditAllTables) { @($tables.Keys) } elseif ($Table) { @($Table | ForEach-Object { $_.ToLowerInvariant() }) } else { @($topNames) }
Chk 'Columns parsed' $(if ($cols.Count) { 'OK' } else { 'ERROR' }) "$($cols.Count) columns across $($tables.Count) tables ($(@($cols | Where-Object Custom).Count) custom)"

# lookups/relationships that point at custom tables missing from the solution
$missing = @{}
foreach ($f in @($allFiles | Where-Object { (Get-Category (Rel $_.FullName $root)) -eq 'Relationship' })) {
    $d = Read-Xml $f.FullName; if (-not $d) { continue }
    foreach ($n in @($d.SelectNodes('//*[local-name()="ReferencedEntityName" or local-name()="ReferencingEntityName"]'))) {
        $nm = ([string]$n.InnerText).ToLowerInvariant()
        if ($nm -and $Prefix -and $nm.StartsWith($Prefix.ToLowerInvariant()) -and -not $tables.ContainsKey($nm)) { $missing[$nm] = $true }
    }
}
Chk 'Related custom tables present' $(if ($missing.Count) { 'WARNING' } else { 'OK' }) $(if ($missing.Count) { "Referenced by relationships but not in the solution: $($missing.Keys -join ', ')" } else { 'All related custom tables are in the solution' })

# ---------------------------------------------------------------- 1.3 references (one pass)
$custom = @($cols | Where-Object Custom)
$tablesOfName = @{}    # column name -> tables that have a custom column of that name
foreach ($c in $custom) { if (-not $tablesOfName.ContainsKey($c.Name)) { $tablesOfName[$c.Name] = New-Object System.Collections.Generic.List[string] }; $tablesOfName[$c.Name].Add($c.Table) }
$refs = @{}    # "table|name" -> list of @{ Rel; Category; Count; Table; Attribution }
$searchExt = '.xml', '.json', '.js', '.html', '.htm', '.xaml', '.rdl', '.txt', '.resx', '.config'
$scopeCache = @{}
# which table a file belongs to: files under Entities\<t>\ belong to t; workflows/business rules carry PrimaryEntity in their .data.xml
function Get-FileScope([string] $rel, [string] $full) {
    $t = Table-Of $rel; if ($t) { return $t }
    if ($rel -match '(?i)^workflows[\\/]') {
        $dataFile = ($full -replace '\.data\.xml$', '') + '.data.xml'
        if ($scopeCache.ContainsKey($dataFile)) { return $scopeCache[$dataFile] }
        $pe = ''; if (Test-Path -LiteralPath $dataFile) { $d = Read-Xml $dataFile; if ($d) { $pe = (AttrOrChild $d.DocumentElement 'PrimaryEntity').ToLowerInvariant() } }
        if ($pe -eq 'none') { $pe = '' }
        $scopeCache[$dataFile] = $pe; return $pe
    }
    ''
}
Write-Host "Searching references for $($tablesOfName.Count) distinct custom column names..."
foreach ($f in $allFiles) {
    if ($searchExt -notcontains $f.Extension.ToLowerInvariant()) { continue }
    $rel = Rel $f.FullName $root; $cat = Get-Category $rel
    $text = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    if ($cat -eq 'Definition') { $text = [regex]::Replace($text, '(?s)<attributes>.*?</attributes>', '') }   # a column's own definition is not a reference
    $tally = @{}
    foreach ($m in [regex]::Matches($text.ToLowerInvariant(), '[a-z_][a-z0-9_]*')) {
        $v = $m.Value
        if ($v.Length -gt 7 -and $v.StartsWith('_') -and $v.EndsWith('_value')) { $v = $v.Substring(1, $v.Length - 7) }   # lookups appear as _col_value
        if ($tablesOfName.ContainsKey($v)) { $tally[$v] = 1 + [int]$tally[$v] }
    }
    if ($tally.Count -eq 0) { continue }
    $scope = Get-FileScope $rel $f.FullName
    foreach ($k in $tally.Keys) {
        $owners = @($tablesOfName[$k] | Select-Object -Unique)
        foreach ($tb in $owners) {
            # Scoped: the file belongs to this table. Unscoped: web resource etc., could be either table. OtherTable: file belongs to another table.
            $attr = if (-not $scope) { if ($owners.Count -gt 1) { "Unscoped (name shared by $($owners.Count) tables)" } else { 'Scoped' } }
                    elseif ($scope -eq $tb) { 'Scoped' } else { 'OtherTable' }
            if ($attr -eq 'OtherTable' -and $owners -contains $scope) { continue }   # the file's own table has its own column of this name
            $key = "$tb|$k"
            if (-not $refs.ContainsKey($key)) { $refs[$key] = New-Object System.Collections.Generic.List[object] }
            $refs[$key].Add([pscustomobject]@{ Rel = $rel; Category = $cat; Count = $tally[$k]; Table = $scope; Attribution = $attr })
        }
    }
}

# duplicate groups per table
$g = 0; $dup = @{}
function Norm([string] $s) { $s.ToLowerInvariant() -replace '[^a-z0-9]', '' }
function NormLoose([string] $s) { $s.ToLowerInvariant() -replace '\b(copy|new|old|temp|tmp)\b', '' -replace '[^a-z0-9]', '' -replace '\d+$', '' }
foreach ($t in $auditTables) {
    $mine = @($custom | Where-Object { $_.Table -eq $t -and -not $_.Companion })
    foreach ($spec in @(@('Strict', 'SAME-LABEL'), @('Loose', 'SIMILAR-LABEL'), @('LoseLn', 'SIMILAR-NAME'))) {
        $mode = $spec[0]
        $keyed = $mine | ForEach-Object {
            $item = $_      # inside a switch, $_ is the switch value, not the pipeline item
            $k = if ($mode -eq 'Strict') { Norm $item.Label } elseif ($mode -eq 'Loose') { NormLoose $item.Label } else { NormLoose ($item.Name -replace '^[a-z0-9]+_', '') }
            [pscustomobject]@{ C = $item; K = $k }
        } | Where-Object K
        foreach ($grp in ($keyed | Group-Object { $_.K + '|' + $_.C.Type } | Where-Object Count -gt 1)) {
            $g++; foreach ($r in $grp.Group) { $key = "$t|$($r.C.Name)"; if (-not $dup.ContainsKey($key)) { $dup[$key] = "$($spec[1])-$g" } }
        }
    }
}

$audit = New-Object System.Collections.Generic.List[object]
$refRows = New-Object System.Collections.Generic.List[object]
foreach ($c in ($custom | Where-Object { $auditTables -contains $_.Table })) {
    $rkey = "$($c.Table)|$($c.Name)"
    $hits = if ($refs.ContainsKey($rkey)) { $refs[$rkey].ToArray() } else { @() }
    $junk = [bool](($c.Name -match $JunkPattern) -or ($c.Label -match $JunkPattern))
    $dg = $dup[$rkey]
    $total = ($hits | Measure-Object -Property Count -Sum).Sum; if (-not $total) { $total = 0 }
    $unsure = @($hits | Where-Object { $_.Attribution -ne 'Scoped' }).Count
    $action =
        if     ($c.Companion) { "COMPANION (base-currency column of $($c.Companion); not deleted on its own, follows its parent)" }
        elseif ($c.Required -in 'systemrequired', 'applicationrequired', 'required') { 'KEEP-REVIEW (required column)' }
        elseif ($hits.Count -eq 0) { 'REVIEW-NO-REFERENCES (offline: data not checked; confirm no data in the sandbox)' }
        elseif ($dg)               { 'REVIEW-DUPLICATE (pick a survivor and repoint references)' }
        elseif ($junk)             { 'REVIEW-JUNK-NAME' }
        else                       { 'KEEP-FOR-NOW' }
    $row = [ordered]@{ Table = $c.Table; LogicalName = $c.Name; DisplayName = $c.Label; Type = $c.Type; JunkName = $junk; DuplicateGroup = $dg
        HasData = 'n/a offline'; PlatformDependencies = 'n/a offline'; ReferenceCount = $total; FilesWithReferences = $hits.Count
        UnscopedOrOtherTableHits = $unsure; NameSharedWithTables = (@($tablesOfName[$c.Name] | Select-Object -Unique) -join ',') }
    foreach ($cat in 'Form', 'View', 'Chart', 'Workflow/Flow', 'WebResource/JS', 'Plugin', 'Report', 'Dashboard', 'App', 'Relationship', 'Definition', 'Other') {
        $row["In$($cat -replace '[^A-Za-z]','')"] = (@($hits | Where-Object Category -eq $cat) | Measure-Object -Property Count -Sum).Sum
    }
    $row['SuggestedAction'] = $action
    $audit.Add([pscustomobject]$row)
    foreach ($h in $hits) { $refRows.Add([pscustomobject][ordered]@{ Table = $c.Table; LogicalName = $c.Name; Category = $h.Category; File = $h.Rel; Occurrences = $h.Count; FileBelongsToTable = $h.Table; Attribution = $h.Attribution }) }
}
$audit | Sort-Object Table, DuplicateGroup, LogicalName | Export-Csv "$OutDir\column-audit.csv" -NoTypeInformation -Encoding UTF8
$refRows | Export-Csv "$OutDir\column-references.csv" -NoTypeInformation -Encoding UTF8

$cand = @($audit | Where-Object { $_.SuggestedAction -notlike 'KEEP*' -and $_.SuggestedAction -notlike 'COMPANION*' })
function Used($t, $col, [string[]] $cats) { if (@($refRows | Where-Object { $_.Table -eq $t -and $_.LogicalName -eq $col -and $_.Category -in $cats }).Count) { 'Yes' } else { 'No' } }
$cand | ForEach-Object {
    [pscustomobject][ordered]@{
        'Table' = $_.Table; 'Column logical name' = $_.LogicalName; 'Display name' = $_.DisplayName; 'Data type' = $_.Type; 'Max length' = ''
        'Total rows' = ''; 'Filled rows' = ''; 'Fill %' = ''; 'Distinct values' = ''; 'Last value written' = ''; 'Has any data' = 'CHECK IN SANDBOX (Get-TableAttributeAudit.ps1)'
        'Used on forms' = Used $_.Table $_.LogicalName @('Form'); 'Used in views' = Used $_.Table $_.LogicalName @('View', 'Chart', 'Dashboard')
        'Used in workflows/flows' = Used $_.Table $_.LogicalName @('Workflow/Flow'); 'Used in plugins/JS' = Used $_.Table $_.LogicalName @('Plugin', 'WebResource/JS')
        'Used in reports/Power BI' = (Used $_.Table $_.LogicalName @('Report')) + ' (Power BI: CONFIRM WITH OWNER)'
        'Used by integration' = 'CONFIRM WITH OWNER'; 'Business owner' = ''; 'Owner sign-off (Y/N)' = ''; 'Decision (Delete/Deprecate/Keep)' = ''
        'Phase' = ''; 'Dev done' = ''; 'Sandbox tested' = ''; 'Prod released' = ''
        'Notes' = "Proposed offline: $($_.SuggestedAction)" + $(if ($_.DuplicateGroup) { "; group $($_.DuplicateGroup)" })
    } } | Export-Csv "$OutDir\field-decision-sheet.csv" -NoTypeInformation -Encoding UTF8

# ---------------------------------------------------------------- 1.4 diff against baseline
$diff = New-Object System.Collections.Generic.List[object]
if ($BaselinePath) {
    $broot = (Resolve-Path $BaselinePath).Path
    $bfiles = @(Get-ChildItem -Path $broot -Recurse -File)
    Write-Host "Comparing with baseline ($($bfiles.Count) files)..."
    function Norm-Content([string] $path) {
        if ($path -match '(?i)\.(dll|png|jpg|jpeg|gif|ico|zip|msapp|xap|woff2?|ttf|svg)$') { return 'BIN:' + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8; if (-not $raw) { return '' }
        if ($path -match '(?i)\.(xml|xaml)$') {
            $d = Read-Xml $path
            if ($d) {
                foreach ($n in @($d.SelectNodes('//*[local-name()="Version" or local-name()="IntroducedVersion" or local-name()="SolutionPackageVersion" or local-name()="ModifiedOn" or local-name()="CreatedOn" or local-name()="modifiedon" or local-name()="createdon"]'))) { [void]$n.ParentNode.RemoveChild($n) }
                $raw = $d.OuterXml
            }
        }
        ($raw -replace '\s+', ' ').Trim()
    }
    function Attr-Map($doc) {
        $m = @{}
        foreach ($a in @($doc.SelectNodes('//attributes/attribute'))) {
            $ln = (ChildText $a 'LogicalName'); if (-not $ln) { $ln = (ChildText $a 'Name') }; if (-not $ln) { $ln = $a.GetAttribute('PhysicalName') }
            $c = $a.CloneNode($true)
            foreach ($n in @($c.SelectNodes('.//*[local-name()="IntroducedVersion" or local-name()="Version"]'))) { [void]$n.ParentNode.RemoveChild($n) }
            $m[$ln.ToLowerInvariant()] = Hash (($c.OuterXml -replace '\s+', ' '))
        }
        $m
    }
    $skip = '(?i)^other[\\/]solution\.xml$'
    $curMap = @{}; foreach ($f in $allFiles)  { $r = Rel $f.FullName $root;  if ($r -notmatch $skip) { $curMap[$r.ToLowerInvariant()]  = $f.FullName } }
    $baseMap = @{}; foreach ($f in $bfiles)   { $r = Rel $f.FullName $broot; if ($r -notmatch $skip) { $baseMap[$r.ToLowerInvariant()] = $f.FullName } }
    foreach ($k in $curMap.Keys) {
        $cat = Get-Category $k; $tb = Table-Of $k
        if (-not $baseMap.ContainsKey($k)) { $diff.Add([pscustomobject]@{ Status = 'ONLY-IN-CURRENT'; Category = $cat; Table = $tb; Component = $k; Detail = 'Not in baseline: created directly, or added after the baseline version' }); continue }
        if ($cat -eq 'Definition') {
            $cd = Read-Xml $curMap[$k]; $bd = Read-Xml $baseMap[$k]
            if ($cd -and $bd) {
                $cm = Attr-Map $cd; $bm = Attr-Map $bd
                foreach ($a in $cm.Keys) {
                    if (-not $bm.ContainsKey($a)) { $diff.Add([pscustomobject]@{ Status = 'ONLY-IN-CURRENT'; Category = 'Column'; Table = $tb; Component = $a; Detail = 'Column not in baseline' }) }
                    elseif ($bm[$a] -ne $cm[$a]) { $diff.Add([pscustomobject]@{ Status = 'CHANGED'; Category = 'Column'; Table = $tb; Component = $a; Detail = 'Column definition differs (label, length, options, required level...)' }) }
                }
                foreach ($a in $bm.Keys) { if (-not $cm.ContainsKey($a)) { $diff.Add([pscustomobject]@{ Status = 'ONLY-IN-BASELINE'; Category = 'Column'; Table = $tb; Component = $a; Detail = 'Column missing in current' }) } }
                $strip = { param($d) ([regex]::Replace($d.OuterXml, '(?s)<attributes>.*?</attributes>', '') -replace '\s+', ' ') }
                if ((Hash (& $strip $cd)) -ne (Hash (& $strip $bd))) { $diff.Add([pscustomobject]@{ Status = 'CHANGED'; Category = 'Table settings'; Table = $tb; Component = $k; Detail = 'Table-level settings, keys or ribbon differ' }) }
            }
            continue
        }
        if ((Hash (Norm-Content $curMap[$k])) -ne (Hash (Norm-Content $baseMap[$k]))) {
            $diff.Add([pscustomobject]@{ Status = 'CHANGED'; Category = $cat; Table = $tb; Component = $k; Detail = 'Content differs from baseline (possible hand edit)' })
        }
    }
    foreach ($k in $baseMap.Keys) { if (-not $curMap.ContainsKey($k)) { $diff.Add([pscustomobject]@{ Status = 'ONLY-IN-BASELINE'; Category = (Get-Category $k); Table = (Table-Of $k); Component = $k; Detail = 'In baseline but missing from current' }) } }
    $diff | Sort-Object Status, Category, Table, Component | Export-Csv "$OutDir\diff-vs-baseline.csv" -NoTypeInformation -Encoding UTF8
    Chk 'Baseline comparison' 'INFO' "$($diff.Count) difference(s). Direction matters: use the version deployed to production as baseline, otherwise differences may be newer dev work."
} else { Chk 'Baseline comparison' 'SKIPPED' 'No -BaselinePath given; hand-edit detection needs a baseline (or use Get-ActiveLayerInventory.ps1 against the environment)' }

# ---------------------------------------------------------------- 1.5 static complexity scorecard
$gridClass = '{e7a81278-8635-4d9e-8d4d-59480b391c5b}'; $quickViewClass = '{5c5600e0-1d6e-4205-a272-be80da87fd42}'
$formRows = New-Object System.Collections.Generic.List[object]
foreach ($f in @($allFiles | Where-Object { (Get-Category (Rel $_.FullName $root)) -eq 'Form' -and $_.Extension -eq '.xml' })) {
    $rel = Rel $f.FullName $root; $d = Read-Xml $f.FullName; if (-not $d) { continue }
    $ctl = @($d.SelectNodes('//control')); $fields = @($ctl | Where-Object { $_.GetAttribute('datafieldname') } | ForEach-Object { $_.GetAttribute('datafieldname') } | Select-Object -Unique)
    $sub = @($ctl | Where-Object { $_.GetAttribute('classid').ToLowerInvariant() -eq $gridClass }).Count
    $qv  = @($ctl | Where-Object { $_.GetAttribute('classid').ToLowerInvariant() -eq $quickViewClass }).Count
    $tabs = @($d.SelectNodes('//tab')).Count; $secs = @($d.SelectNodes('//section')).Count
    $onload = @($d.SelectNodes('//event[@name="onload"]/Handlers/Handler')).Count; $onsave = @($d.SelectNodes('//event[@name="onsave"]/Handlers/Handler')).Count
    $ln = $d.SelectSingleNode('//LocalizedName'); $nm = if ($ln) { $ln.GetAttribute('description') } else { [IO.Path]::GetFileNameWithoutExtension($f.Name) }
    $flags = @()
    if ($fields.Count -gt $FormFieldWarn) { $flags += "many fields ($($fields.Count))" }
    if ($tabs -gt $FormTabWarn) { $flags += "many tabs ($tabs)" }
    if ($sub -gt $SubgridWarn) { $flags += "many subgrids ($sub)" }
    if ($onload -gt 3) { $flags += "many OnLoad handlers ($onload)" }
    $formRows.Add([pscustomobject][ordered]@{ Table = (Table-Of $rel); Form = $nm; Kind = $(if ($rel -match '(?i)[\\/]formxml[\\/]([^\\/]+)[\\/]') { $matches[1] } else { '' }); Fields = $fields.Count; Tabs = $tabs; Sections = $secs
        Subgrids = $sub; QuickViews = $qv; OnLoadHandlers = $onload; OnSaveHandlers = $onsave; Flags = ($flags -join '; '); File = $rel })
}
$formRows | Sort-Object Fields -Descending | Export-Csv "$OutDir\form-complexity.csv" -NoTypeInformation -Encoding UTF8

$viewRows = New-Object System.Collections.Generic.List[object]
foreach ($f in @($allFiles | Where-Object { (Get-Category (Rel $_.FullName $root)) -eq 'View' -and $_.Extension -eq '.xml' })) {
    $rel = Rel $f.FullName $root; $d = Read-Xml $f.FullName; if (-not $d) { continue }
    $cells = @($d.SelectNodes('//cell')).Count; $links = @($d.SelectNodes('//link-entity')).Count; $allAttr = @($d.SelectNodes('//all-attributes')).Count
    $filters = @($d.SelectNodes('//fetch//filter')).Count
    $ln = $d.SelectSingleNode('//LocalizedName'); $nm = if ($ln) { $ln.GetAttribute('description') } else { [IO.Path]::GetFileNameWithoutExtension($f.Name) }
    $flags = @()
    if ($cells -gt $ViewColumnWarn) { $flags += "many columns ($cells)" }
    if ($links -gt $ViewLinkWarn) { $flags += "many joins ($links)" }
    if ($allAttr) { $flags += 'retrieves all attributes' }
    if (-not $filters) { $flags += 'no filter' }
    $viewRows.Add([pscustomobject][ordered]@{ Table = (Table-Of $rel); View = $nm; Columns = $cells; Joins = $links; AllAttributes = [bool]$allAttr; HasFilter = [bool]$filters; Flags = ($flags -join '; '); File = $rel })
}
$viewRows | Sort-Object Columns -Descending | Export-Csv "$OutDir\view-complexity.csv" -NoTypeInformation -Encoding UTF8

$stepRows = New-Object System.Collections.Generic.List[object]
foreach ($f in @($allFiles | Where-Object { $_.Extension -eq '.xml' -and (Rel $_.FullName $root) -match '(?i)^sdkmessageprocessingsteps[\\/]' })) {
    $d = Read-Xml $f.FullName; if (-not $d) { continue }
    $n = $d.DocumentElement; $name = AttrOrChild $n 'Name'; $stage = AttrOrChild $n 'Stage'; $mode = AttrOrChild $n 'Mode'; $fa = AttrOrChild $n 'FilteringAttributes'
    $flags = @()
    if ($mode -eq '0' -and $stage -in '20', '40' -and -not $fa -and $name -match '(?i)update') { $flags += 'synchronous Update step without filtering attributes' }
    if ($mode -eq '0' -and $stage -in '20', '40') { $flags += 'synchronous' }
    $stepRows.Add([pscustomobject][ordered]@{ Step = $name; Stage = $stage; Mode = $(if ($mode -eq '0') { 'Synchronous' } elseif ($mode -eq '1') { 'Asynchronous' } else { $mode }); FilteringAttributes = $fa; Flags = ($flags -join '; '); File = (Rel $f.FullName $root) })
}
$stepRows | Export-Csv "$OutDir\plugin-steps.csv" -NoTypeInformation -Encoding UTF8

$wfRows = New-Object System.Collections.Generic.List[object]
$catName = @{ '0' = 'Workflow'; '1' = 'Dialog'; '2' = 'Business rule'; '3' = 'Action'; '4' = 'Business process flow'; '5' = 'Cloud flow'; '6' = 'Desktop flow' }
foreach ($f in @($allFiles | Where-Object { $_.Name -match '(?i)\.(xaml|json)\.data\.xml$' -and (Rel $_.FullName $root) -match '(?i)^workflows[\\/]' })) {
    $d = Read-Xml $f.FullName; if (-not $d) { continue }
    $n = $d.DocumentElement; $c = AttrOrChild $n 'Category'; $mode = AttrOrChild $n 'Mode'; $state = AttrOrChild $n 'StateCode'
    $pe = AttrOrChild $n 'PrimaryEntity'
    $flowFile = $f.FullName -replace '\.data\.xml$', ''
    $conn = ''
    if (Test-Path -LiteralPath $flowFile) { $t = Get-Content -LiteralPath $flowFile -Raw -ErrorAction SilentlyContinue; if ($t) { $conn = (([regex]::Matches($t, 'shared_[a-z0-9]+') | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', ') } }
    $flags = @(); if ($c -in '0' -and $mode -eq '1') { $flags += 'real-time (synchronous) workflow' }; if ($state -eq '0') { $flags += 'draft/inactive' }
    $wfRows.Add([pscustomobject][ordered]@{ Name = (AttrOrChild $n 'Name'); Kind = $(if ($catName.ContainsKey($c)) { $catName[$c] } else { $c }); PrimaryEntity = $pe
        Mode = $(if ($mode -eq '1') { 'Real-time' } elseif ($mode -eq '0') { 'Background' } else { $mode }); State = $(if ($state -eq '1') { 'Activated' } elseif ($state -eq '0') { 'Draft' } else { $state }); Connectors = $conn; Flags = ($flags -join '; ') })
}
$wfRows | Export-Csv "$OutDir\workflows.csv" -NoTypeInformation -Encoding UTF8

# ---------------------------------------------------------------- 1.6 manual checks and integration hints
$hints = New-Object System.Collections.Generic.List[object]
function Hint($type, $name, $detail) { $hints.Add([pscustomobject]@{ Type = $type; Name = $name; Detail = $detail }) }
foreach ($d in @(Get-ChildItem -Path (Join-Path $root 'PluginAssemblies') -Directory -ErrorAction SilentlyContinue)) { Hint 'Plugin assembly' $d.Name 'Source code is NOT in the solution: find the repository and search it for the column names' }
foreach ($d in @('ServiceEndpoints', 'CanvasApps', 'Reports', 'Templates', 'EnvironmentVariableDefinitions', 'ConnectionReferences', 'AppModules')) {
    foreach ($x in @(Get-ChildItem -Path (Join-Path $root $d) -ErrorAction SilentlyContinue)) { Hint $d $x.Name 'Present in the solution: confirm which columns it uses' }
}
$custXml = Join-Path $root 'Other\Customizations.xml'
if (Test-Path $custXml) { $ct = Get-Content -LiteralPath $custXml -Raw; foreach ($m in [regex]::Matches($ct, 'connectionreferencelogicalname="([^"]+)"')) { Hint 'Connection reference' $m.Groups[1].Value 'External connection used by flows or apps' } }
foreach ($w in $wfRows) { if ($w.Connectors) { Hint 'Flow connectors' $w.Name $w.Connectors } }
$hosts = @{}
foreach ($f in @($allFiles | Where-Object { (Get-Category (Rel $_.FullName $root)) -eq 'WebResource/JS' -and $_.Extension -in '.js', '.html', '.htm' })) {
    $t = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue; if (-not $t) { continue }
    foreach ($m in [regex]::Matches($t, 'https?://([a-zA-Z0-9.\-]+)')) { $h = $m.Groups[1].Value.ToLowerInvariant(); if (-not $hosts.ContainsKey($h)) { $hosts[$h] = $f.Name } }
}
foreach ($h in $hosts.Keys) { Hint 'External host in script' $h "first seen in $($hosts[$h])" }
$hints | Export-Csv "$OutDir\integration-hints.csv" -NoTypeInformation -Encoding UTF8

$pluginNote = "$(@($hints | Where-Object Type -eq 'Plugin assembly').Count) plugin assembly(ies) in the solution"
$cand | ForEach-Object {
    [pscustomobject][ordered]@{ Table = $_.Table; LogicalName = $_.LogicalName; SuggestedAction = $_.SuggestedAction
        'Plugin / custom code source' = "TO CONFIRM ($pluginNote)"; 'Power BI / datasets' = 'TO CONFIRM'; 'External integrations (middleware, SQL, APIs)' = 'TO CONFIRM'
        'Word/Excel/email templates' = 'TO CONFIRM'; 'Personal flows (My flows) and flows outside the solution' = 'TO CONFIRM'; 'Canvas apps / Power Pages' = 'TO CONFIRM'
        'Data present (sandbox check)' = 'TO CONFIRM'; Owner = ''; 'Checked by' = ''; 'Date' = ''; 'Result' = '' } } |
    Export-Csv "$OutDir\manual-check-matrix.csv" -NoTypeInformation -Encoding UTF8

$completeness | Export-Csv "$OutDir\completeness.csv" -NoTypeInformation -Encoding UTF8

# ---------------------------------------------------------------- summary
Write-Host "`n=== Completeness ==="
$completeness | Format-Table Check, Status, Detail -AutoSize -Wrap | Out-Host
Write-Host "=== Top tables by custom columns ==="
$ranked | Select-Object -First 10 | Format-Table @{n = 'Table'; e = { $_.Name } }, Total, Custom, Lookups, MaxLenSum, Forms, Views -AutoSize | Out-Host
Write-Host "Audited tables: $($auditTables -join ', ')"
$audit | Group-Object { ($_.SuggestedAction -split ' ')[0] } | ForEach-Object { Write-Host ("  {0,-24} {1}" -f $_.Name, $_.Count) }
Write-Host "Flagged forms: $(@($formRows | Where-Object Flags).Count) of $($formRows.Count); flagged views: $(@($viewRows | Where-Object Flags).Count) of $($viewRows.Count); flagged plugin steps: $(@($stepRows | Where-Object Flags).Count) of $($stepRows.Count)"
Write-Host "`nOutputs are in ${OutDir}. This was an offline analysis: data presence, platform dependencies, real layers and real timings still need the environment-based scripts."
