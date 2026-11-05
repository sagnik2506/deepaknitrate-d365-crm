<#
.SYNOPSIS
  Audits the custom columns of one or many Dataverse tables, flags probable delete candidates,
  and lists every reference to those candidates. Read-only: only GET requests are made.

  Flags per column: test/junk-looking names, likely duplicates, no data, no dependencies,
  no references in an unpacked solution. Then, for every column that is not "KEEP", it lists
  each reference found (see Outputs).

.PARAMETER EnvUrl
  e.g. https://yourorg.crm.dynamics.com  (run against a sandbox copy of production)

.PARAMETER TenantId
.PARAMETER ClientId
.PARAMETER ClientSecret
  Azure AD (Entra ID) app registration credentials. The script requests its own bearer token with the
  client-credentials flow (scope = <EnvUrl>/.default) and renews it before it expires.
  Requirements: the app registration must also exist as an *Application user* in the environment
  (Power Platform admin center > Environment > Settings > Users > App users) with a security role that can
  read metadata and the tables (a read-only custom role is enough; this script only reads).
  If -ClientSecret is omitted the script uses the DATAVERSE_CLIENT_SECRET environment variable, and
  if that is not set either it prompts for the secret without echoing it. Avoid putting the secret
  in scripts, shell history or source control.

.PARAMETER Token
  Alternative to the three parameters above: a ready-made bearer token, e.g.:
    $token = az account get-access-token --resource https://yourorg.crm.dynamics.com --query accessToken -o tsv

.PARAMETER Table
  One or more table logical names, e.g. -Table abc_customerrequest,account

.PARAMETER TableListCsv
  Alternative to -Table: a CSV with a column named Table.

.PARAMETER UnpackedPath
  Optional but strongly recommended. Folder from `pac solution unpack`. Adds a whole-name search of
  forms, views, workflows, flows, web resources, etc.

.PARAMETER IncludeReferences
  Also (a) resolves platform dependencies to real component names (view name, form name, flow name...)
  and (b) searches the environment for references that are not in the solution: personal views,
  cloud flows and workflows, plugin step filter attributes, reports and JavaScript web resources.

.PARAMETER SkipDataCheck
  Skip the "does any record have a value" check (faster).

.OUTPUTS (in -OutDir)
  all-columns-audit.csv       one row per custom column with flags and SuggestedAction
  candidate-references.csv    one row per reference found for each non-KEEP column
  field-decision-sheet.csv    the non-KEEP columns pre-filled in the field decision template format

.EXAMPLE
  $env:DATAVERSE_CLIENT_SECRET = '<secret>'      # or let the script prompt for it
  .\Get-TableAttributeAudit.ps1 -EnvUrl https://yourorg.crm.dynamics.com `
      -TenantId <tenant-guid> -ClientId <app-guid> `
      -TableListCsv .\tables.csv -UnpackedPath .\unpacked -IncludeReferences

Limitations: solution-file matching is by column name, so a name shared by several tables can show
hits that belong to another table. Plugin source code, Power BI, Excel/Word templates, Power Pages and
external integrations are not searchable from here; the decision sheet marks them "CONFIRM WITH OWNER".
#>
param(
    [Parameter(Mandatory)] [string] $EnvUrl,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $Token,
    [switch] $UseAzCli,
    [string[]] $Table,
    [string] $TableListCsv,
    [string] $UnpackedPath,
    [switch] $IncludeReferences,
    [switch] $SkipDataCheck,
    [string] $OutDir = '.\audit-output',
    [string] $JunkPattern = '(^|[_\W])(test|tst|temp|tmp|junk|dummy|demo|sample|xxx|zzz?|old|backup|bkp|copy|unused|deprecated|delete|donotuse|dnu|poc)([_\W\d]|$)'
)

if ($TableListCsv) { $Table = @(Import-Csv $TableListCsv | ForEach-Object { $_.Table } | Where-Object { $_ }) }
# with "pwsh -File", -Table a,b arrives as one string; split a comma-separated list into separate values
if ($Table) { $Table = @($Table | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if (-not $Table) { throw "Pass -Table or -TableListCsv." }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$EnvUrl  = $EnvUrl.TrimEnd('/')
$api     = "$EnvUrl/api/data/v9.2"

# --- Authentication: client-credentials flow (app registration + application user), or a ready-made token ---
$script:tokenExpiry = [datetime]::MaxValue
function Get-AccessToken {
    if ($UseAzCli) {
        # reuse the signed-in Azure CLI session (run "az login --allow-no-subscriptions" yourself first)
        $t = (& az account get-access-token --resource $EnvUrl --query accessToken -o tsv 2>$null)
        if (-not $t) { throw "Could not get a token from the Azure CLI. Run: az login --allow-no-subscriptions   (sign in yourself), then rerun." }
        $script:tokenExpiry = (Get-Date).AddMinutes(40)
        return ([string]$t).Trim()
    }
    $secret = $ClientSecret
    if (-not $secret) { $secret = $env:DATAVERSE_CLIENT_SECRET }
    if (-not $secret) {
        $sec = Read-Host -Prompt "Client secret for $ClientId" -AsSecureString
        $secret = [System.Net.NetworkCredential]::new('', $sec).Password
    }
    $body = @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $secret; scope = "$EnvUrl/.default" }
    try {
        $r = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body -ContentType 'application/x-www-form-urlencoded'
    } catch {
        throw "Token request failed for client $ClientId in tenant $TenantId. Check the secret, the tenant, and that the app registration exists. ($($_.Exception.Message))"
    }
    $script:tokenExpiry = (Get-Date).AddSeconds([int]$r.expires_in - 300)     # renew 5 minutes early
    $r.access_token
}
function Update-Token {
    if ($script:useClientCreds -and (Get-Date) -ge $script:tokenExpiry) {
        $script:headers.Authorization = "Bearer $(Get-AccessToken)"
    }
}
$script:useClientCreds = [bool](($TenantId -and $ClientId) -or $UseAzCli)
if ($script:useClientCreds)  { Write-Host ("Requesting token (" + $(if ($UseAzCli) { 'Azure CLI session' } else { 'client ' + $ClientId }) + ") ..."); $Token = Get-AccessToken }
elseif (-not $Token)         { throw "Pass -UseAzCli (after az login), or -TenantId/-ClientId/-ClientSecret (or DATAVERSE_CLIENT_SECRET), or -Token." }
$script:headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Prefer = 'odata.maxpagesize=500' }
# GET with retry when the service throttles (429) or has a transient failure; stops with a clear message when the sign-in is rejected
function Invoke-Get([string] $url) {
    for ($try = 1; $try -le 6; $try++) {
        Update-Token
        try { return Invoke-RestMethod -Uri $url -Headers $script:headers -Method Get }
        catch {
            $code = $null; $resp = $_.Exception.Response
            if ($resp) { try { $code = [int]$resp.StatusCode } catch { } }
            if ((($code -eq 429) -or ($code -in 502, 503, 504)) -and ($try -lt 6)) {
                $wait = 30
                try { $ra = $resp.Headers['Retry-After']; if ($ra) { $wait = [int]@($ra)[0] } } catch { }
                Write-Host "   service busy ($code); waiting $wait s (attempt $try)..."
                Start-Sleep -Seconds $wait
            } elseif ($code -in 401, 403) { throw "The environment rejected the sign-in (HTTP $code). Run 'az account show': it must be the account that has access to $EnvUrl, in that tenant. Then run 'az logout' and 'az login --allow-no-subscriptions --tenant <tenant id>' and try again. If a WhoAmI call still fails, ask the environment admin to add the account with a read-only role." } else { throw }
        }
    }
}
function Get-AllPages([string] $url) {
    $rows = New-Object System.Collections.Generic.List[object]
    while ($url) { $r = Invoke-Get $url; foreach ($v in $r.value) { $rows.Add($v) }; $url = $r.'@odata.nextLink' }
    $rows
}

function Get-Label($a) { if ($a.DisplayName.UserLocalizedLabel) { $a.DisplayName.UserLocalizedLabel.Label } else { '' } }
function Normalize([string] $s) { ($s.ToLowerInvariant() -replace '[^a-z0-9]', '') }
function NormalizeLoose([string] $s) { $s.ToLowerInvariant() -replace '\b(copy|new|old|temp|tmp)\b', '' -replace '[^a-z0-9]', '' -replace '\d+$', '' }

function Get-PathCategory([string] $path) {
    $p = $path.ToLowerInvariant()
    if     ($p -match '\\formxml\\')                              { 'Form' }
    elseif ($p -match '\\savedqueries\\')                         { 'View' }
    elseif ($p -match '\\charts?\\|visualization')                { 'Chart' }
    elseif ($p -match '\\workflows\\')                            { 'Workflow/Flow' }
    elseif ($p -match '\\webresources\\')                         { 'WebResource/JS' }
    elseif ($p -match '\\pluginassemblies\\|sdkmessageprocessingsteps') { 'Plugin' }
    elseif ($p -match '\\reports\\')                              { 'Report' }
    elseif ($p -match '\\dashboards\\')                           { 'Dashboard' }
    elseif ($p -match '\\appmodules\\|\\canvasapps\\')            { 'App' }
    else                                                          { 'Other' }
}
function Get-DepCategory([int] $t) {
    switch ($t) {
        { $_ -in 24, 60 } { 'Form' }            26 { 'View' }          59 { 'Chart' }
        29 { 'Workflow/Flow' }                   61 { 'WebResource/JS' }
        { $_ -in 90, 91, 92, 93 } { 'Plugin' }   { $_ -in 31, 32 } { 'Report' }
        { $_ -in 70, 71 } { 'FieldSecurity' }    { $_ -in 3, 10, 46, 47 } { 'Relationship/Mapping' }
        { $_ -in 64, 66 } { 'Control' }          300 { 'CanvasApp' }
        default { "OtherType$t" }
    }
}
$resolveMap = @{ 26 = 'savedqueries'; 60 = 'systemforms'; 29 = 'workflows'; 61 = 'webresourceset'; 92 = 'sdkmessageprocessingsteps'; 31 = 'reports'; 59 = 'savedqueryvisualizations' }
$nameCache = @{}
function Resolve-Component([int] $type, [string] $id) {
    $key = "$type|$id"
    if ($nameCache.ContainsKey($key)) { return $nameCache[$key] }
    $name = '(not resolved)'
    if ($resolveMap.ContainsKey($type)) {
        try { $name = (Invoke-Get "$api/$($resolveMap[$type])($id)?`$select=name").name } catch { }
    }
    $nameCache[$key] = $name; $name
}

# ================= Phase 1: metadata, junk, duplicates, data, platform dependencies =================
$cols = New-Object System.Collections.Generic.List[object]
$g = 0
foreach ($t in $Table) {
    Write-Host "== $t"
    $ent   = Invoke-Get "$api/EntityDefinitions(LogicalName='$t')?`$select=EntitySetName,PrimaryIdAttribute"
    $attrs = (Invoke-Get "$api/EntityDefinitions(LogicalName='$t')/Attributes?`$select=MetadataId,LogicalName,AttributeType,IsCustomAttribute,IsPrimaryId,IsPrimaryName,AttributeOf,DisplayName,RequiredLevel").value
    $mine  = @($attrs | Where-Object { $_.IsCustomAttribute -and -not $_.IsPrimaryId -and -not $_.IsPrimaryName -and -not $_.AttributeOf })
    Write-Host "   $($attrs.Count) columns, $($mine.Count) custom to audit"

    # every money column has a platform-generated base-currency twin (<name>_base); it is not an independent candidate
    $nameSet = @{}; foreach ($a in $mine) { $nameSet[$a.LogicalName] = $true }
    $rows = foreach ($a in $mine) {
        $label = Get-Label $a
        $comp = ''
        if ($a.AttributeType -eq 'Money' -and $a.LogicalName.EndsWith('_base') -and $nameSet.ContainsKey($a.LogicalName.Substring(0, $a.LogicalName.Length - 5))) { $comp = $a.LogicalName.Substring(0, $a.LogicalName.Length - 5) }
        [pscustomobject]@{ Table = $t; Attr = $a; Label = $label; Strict = Normalize $label; Loose = NormalizeLoose $label
                           LoseLn = NormalizeLoose ($a.LogicalName -replace '^[a-z0-9]+_', ''); Dup = ''; Ent = $ent; Comp = $comp }
    }
    foreach ($spec in @(@('Strict', 'SAME-LABEL'), @('Loose', 'SIMILAR-LABEL'), @('LoseLn', 'SIMILAR-NAME'))) {
        foreach ($grp in ($rows | Where-Object { -not $_.Comp -and $_.($spec[0]) } | Group-Object { $_.($spec[0]) + '|' + $_.Attr.AttributeType } | Where-Object Count -gt 1)) {
            $g++; foreach ($r in $grp.Group) { if (-not $r.Dup) { $r.Dup = "$($spec[1])-$g" } }
        }
    }

    $n = 0
    foreach ($r in $rows) {
        $a = $r.Attr; $name = $a.LogicalName
        $n++; if ($n % 25 -eq 0) { Write-Host "   $n of $($rows.Count)" }
        if ($r.Comp) {
            $cols.Add([pscustomobject]@{ Table = $r.Table; LogicalName = $name; DisplayName = $r.Label; Type = $a.AttributeType; MetadataId = $a.MetadataId
                Required = ''; Junk = $false; Dup = ''; HasData = 'n/a'; DepCount = 'n/a'; DepItems = @(); Companion = $r.Comp })
            continue
        }
        $depItems = @()
        try {
            $dep = Invoke-Get "$api/RetrieveDependenciesForDelete(ObjectId=$($a.MetadataId),ComponentType=2)"
            $depItems = @(if ($dep.value) { $dep.value } elseif ($dep.EntityCollection) { $dep.EntityCollection } else { @() })
            $depCount = $depItems.Count
        } catch { $depCount = 'error' }

        $hasData = 'not checked'
        if (-not $SkipDataCheck) {
            $field = if ($a.AttributeType -in 'Lookup', 'Customer', 'Owner') { "_$($name)_value" } else { $name }
            try {
                $q = Invoke-Get "$api/$($r.Ent.EntitySetName)?`$select=$($r.Ent.PrimaryIdAttribute)&`$filter=$field ne null&`$top=1"
                $hasData = if (@($q.value).Count -gt 0) { 'yes' } else { 'no' }
            } catch { $hasData = 'unknown (type not filterable?)' }
        }
        $cols.Add([pscustomobject]@{
            Table = $r.Table; LogicalName = $name; DisplayName = $r.Label; Type = $a.AttributeType; MetadataId = $a.MetadataId
            Required = $a.RequiredLevel.Value; Junk = [bool](($name -match $JunkPattern) -or ($r.Label -match $JunkPattern))
            Dup = $r.Dup; HasData = $hasData; DepCount = $depCount; DepItems = $depItems; Companion = '' })
    }
}

# ================= Phase 2: one pass over the unpacked solution =================
$solRefs = @{}   # lower-case column name -> list of @{ File; Category; Count }
if ($UnpackedPath) {
    $root  = (Resolve-Path $UnpackedPath).Path
    $names = @{}; foreach ($c in $cols) { $names[$c.LogicalName.ToLowerInvariant()] = $true }
    $ext   = '.xml', '.json', '.js', '.html', '.htm', '.xaml', '.rdl', '.txt', '.resx', '.config'
    $files = Get-ChildItem -Path $root -Recurse -File | Where-Object { $ext -contains $_.Extension.ToLowerInvariant() }
    Write-Host "Scanning $($files.Count) solution files..."
    foreach ($file in $files) {
        if ($file.FullName -match '\\entities\\[^\\]+\\entity\.xml$') { continue }   # the column definitions themselves
        $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        $tally = @{}
        foreach ($m in [regex]::Matches($text.ToLowerInvariant(), '[a-z_][a-z0-9_]*')) {
            $v = $m.Value
            # lookups appear as _<column>_value in flows, Web API calls, FetchXML and scripts
            if ($v.Length -gt 7 -and $v.StartsWith('_') -and $v.EndsWith('_value')) { $v = $v.Substring(1, $v.Length - 7) }
            if ($names.ContainsKey($v)) { $tally[$v] = 1 + [int]$tally[$v] }     # whole-name match by construction
        }
        if ($tally.Count -eq 0) { continue }
        $rel = $file.FullName.Substring($root.Length).TrimStart('\'); $cat = Get-PathCategory $file.FullName
        foreach ($k in $tally.Keys) {
            if (-not $solRefs.ContainsKey($k)) { $solRefs[$k] = New-Object System.Collections.Generic.List[object] }
            $solRefs[$k].Add([pscustomobject]@{ File = $rel; Category = $cat; Count = $tally[$k] })
        }
    }
}

# ================= Phase 3: classify =================
$audit = foreach ($c in $cols) {
    $hits   = @(if ($UnpackedPath -and $solRefs.ContainsKey($c.LogicalName.ToLowerInvariant())) { $solRefs[$c.LogicalName.ToLowerInvariant()] })
    $noRefs = ($c.DepCount -eq 0) -and $UnpackedPath -and ($hits.Count -eq 0)
    $action =
        if     ($c.Companion) { "COMPANION (base-currency column of $($c.Companion); follows its parent)" }
        elseif ($c.Required -in 'SystemRequired', 'ApplicationRequired') { 'KEEP-REVIEW (required column)' }
        elseif ($noRefs -and $c.HasData -eq 'no')  { 'DELETE-CANDIDATE (no data, no references)' }
        elseif ($noRefs -and $c.HasData -eq 'yes') { 'REVIEW (has data, no references found; confirm with owner and integrations)' }
        elseif ($noRefs)                           { 'REVIEW (no references found; data not checked)' }
        elseif ($c.Dup)                            { 'REVIEW-DUPLICATE (pick a survivor and repoint references)' }
        elseif ($c.Junk)                           { 'REVIEW-JUNK-NAME' }
        else                                       { 'KEEP-FOR-NOW' }
    [pscustomobject][ordered]@{
        Table = $c.Table; LogicalName = $c.LogicalName; DisplayName = $c.DisplayName; Type = $c.Type
        JunkName = $c.Junk; DuplicateGroup = $c.Dup; HasData = $c.HasData
        PlatformDependencies = $c.DepCount
        SolutionFileHits = if ($UnpackedPath) { $hits.Count } else { 'not checked' }
        SuggestedAction = $action
    }
}

# save now, so a long or interrupted phase 4 does not lose the results so far
$audit | Sort-Object Table, DuplicateGroup, LogicalName | Export-Csv "$OutDir\all-columns-audit.csv" -NoTypeInformation -Encoding UTF8
Write-Host "Saved $OutDir\all-columns-audit.csv ($(@($audit).Count) columns). Phase 4 (references) follows."

# ================= Phase 4: every reference for the non-KEEP columns =================
$cand = @($audit | Where-Object { $_.SuggestedAction -notlike 'KEEP*' -and $_.SuggestedAction -notlike 'COMPANION*' })
Write-Host "`n$($cand.Count) non-KEEP columns; collecting references..."

$envData = @{}
if ($IncludeReferences -and $cand.Count -gt 0) {
    Write-Host "Reading personal views, flows/workflows, plugin steps, reports, JavaScript from the environment..."
    $envData.views   = Get-AllPages "$api/userqueries?`$select=name,fetchxml,layoutxml"
    $envData.flows   = Get-AllPages "$api/workflows?`$select=name,category,clientdata,xaml"
    $envData.steps   = Get-AllPages "$api/sdkmessageprocessingsteps?`$select=name,filteringattributes"
    $envData.reports = Get-AllPages "$api/reports?`$select=name,bodytext"
    $envData.scripts = Get-AllPages "$api/webresourceset?`$select=name,content&`$filter=webresourcetype eq 3"
    foreach ($s in $envData.scripts) {
        if ($s.content) { $s | Add-Member -NotePropertyName text -NotePropertyValue ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.content))) -Force }
    }
}
# read every environment item once and keep its set of identifiers; finding a column is then a lookup, not a rescan
function New-TokenIndex($items, [string[]] $props, $rx) {
    # one compiled pattern that matches only the candidate column names (also in the _<column>_value form used for lookups),
    # so large flow, workflow and script definitions are scanned once, in the regex engine, without building huge match lists
    $idx = New-Object System.Collections.Generic.List[object]
    foreach ($i in $items) {
        $set = New-Object 'System.Collections.Generic.HashSet[string]'
        foreach ($p in $props) {
            $t = [string]$i.$p; if (-not $t) { continue }
            foreach ($m in $rx.Matches($t)) { [void]$set.Add($m.Groups[1].Value.ToLowerInvariant()) }
        }
        if ($set.Count) { $idx.Add([pscustomobject]@{ Item = $i; Tokens = $set }) }
    }
    $idx
}
function Find-EnvHits($index, [string] $name) { $n = $name.ToLowerInvariant(); foreach ($e in $index) { if ($e.Tokens.Contains($n)) { $e.Item } } }
$idxViews = $idxFlows = $idxSteps = $idxReports = $idxScripts = @()
if ($IncludeReferences -and $cand.Count -gt 0) {
    Write-Host "Searching environment items for $($cand.Count) candidate columns (local step, no calls to the environment)..."
    $candNames = @($cand | ForEach-Object { [regex]::Escape($_.LogicalName.ToLowerInvariant()) } | Sort-Object { $_.Length } -Descending | Select-Object -Unique)
    $rx = New-Object System.Text.RegularExpressions.Regex(('(?<![A-Za-z0-9_])_?(' + ($candNames -join '|') + ')(?:_value)?(?![A-Za-z0-9_])'), 'IgnoreCase, Compiled')
    $sw2 = [Diagnostics.Stopwatch]::StartNew()
    $idxViews   = New-TokenIndex $envData.views   @('fetchxml', 'layoutxml') $rx
    $idxFlows   = New-TokenIndex $envData.flows   @('clientdata', 'xaml') $rx
    $idxSteps   = New-TokenIndex $envData.steps   @('filteringattributes') $rx
    $idxReports = New-TokenIndex $envData.reports @('bodytext') $rx
    $idxScripts = New-TokenIndex $envData.scripts @('text') $rx
    Write-Host "Items that mention a candidate column: views=$(@($idxViews).Count) flows/workflows=$(@($idxFlows).Count) plugin steps=$(@($idxSteps).Count) reports=$(@($idxReports).Count) scripts=$(@($idxScripts).Count)  ($([int]$sw2.Elapsed.TotalSeconds)s)"
}

$refs = New-Object System.Collections.Generic.List[object]
function Add-Ref($t, $col, $source, $category, $comp, $id, $detail) {
    $refs.Add([pscustomobject][ordered]@{ Table = $t; LogicalName = $col; Source = $source; Category = $category; Component = $comp; ComponentId = $id; Detail = $detail })
}
foreach ($a in $cand) {
    $c = $cols | Where-Object { $_.Table -eq $a.Table -and $_.LogicalName -eq $a.LogicalName } | Select-Object -First 1
    foreach ($d in $c.DepItems) {
        $type = [int]$d.dependentcomponenttype; $id = [string]$d.dependentcomponentobjectid
        $nm = if ($IncludeReferences) { Resolve-Component $type $id } else { '' }
        Add-Ref $a.Table $a.LogicalName 'PlatformDependency' (Get-DepCategory $type) $nm $id "componenttype=$type"
    }
    $k = $a.LogicalName.ToLowerInvariant()
    if ($solRefs.ContainsKey($k)) {
        foreach ($h in $solRefs[$k]) { Add-Ref $a.Table $a.LogicalName 'SolutionFile' $h.Category $h.File '' "$($h.Count) occurrence(s)" }
    }
    if ($IncludeReferences) {
        foreach ($i in (Find-EnvHits $idxViews   $a.LogicalName)) { Add-Ref $a.Table $a.LogicalName 'Environment' 'PersonalView' $i.name '' 'userquery' }
        foreach ($i in (Find-EnvHits $idxFlows   $a.LogicalName)) { Add-Ref $a.Table $a.LogicalName 'Environment' 'Workflow/Flow' $i.name '' "workflow category $($i.category)" }
        foreach ($i in (Find-EnvHits $idxSteps   $a.LogicalName)) { Add-Ref $a.Table $a.LogicalName 'Environment' 'Plugin' $i.name '' 'step filtering attributes' }
        foreach ($i in (Find-EnvHits $idxReports $a.LogicalName)) { Add-Ref $a.Table $a.LogicalName 'Environment' 'Report' $i.name '' 'report definition' }
        foreach ($i in (Find-EnvHits $idxScripts $a.LogicalName)) { Add-Ref $a.Table $a.LogicalName 'Environment' 'WebResource/JS' $i.name '' 'JavaScript' }
    }
}
$refs | Export-Csv "$OutDir\candidate-references.csv" -NoTypeInformation -Encoding UTF8

# a column that looked unreferenced but is used outside the solution must not stay a delete candidate
foreach ($a in $audit) {
    $n = @($refs | Where-Object { $_.Table -eq $a.Table -and $_.LogicalName -eq $a.LogicalName }).Count
    $a | Add-Member -NotePropertyName ReferencesFound -NotePropertyValue $n -Force
    if ($a.SuggestedAction -like 'DELETE-CANDIDATE*' -and $n -gt 0) {
        $a.SuggestedAction = 'REVIEW (referenced outside the solution; see candidate-references.csv)'
    }
}
$audit | Sort-Object Table, DuplicateGroup, LogicalName | Export-Csv "$OutDir\all-columns-audit.csv" -NoTypeInformation -Encoding UTF8

# ================= Phase 5: decision sheet (template format) =================
function YesNo($t, $col, [string[]] $cats) {
    if (-not $UnpackedPath -and -not $IncludeReferences) { return '' }
    if (@($refs | Where-Object { $_.Table -eq $t -and $_.LogicalName -eq $col -and $_.Category -in $cats }).Count -gt 0) { 'Yes' } else { 'No' }
}
$sheet = foreach ($a in $cand) {
    [pscustomobject][ordered]@{
        'Table' = $a.Table; 'Column logical name' = $a.LogicalName; 'Display name' = $a.DisplayName; 'Data type' = $a.Type; 'Max length' = ''
        'Total rows' = ''; 'Filled rows' = ''; 'Fill %' = ''; 'Distinct values' = ''; 'Last value written' = ''
        'Has any data' = $a.HasData
        'Used on forms'                  = YesNo $a.Table $a.LogicalName @('Form')
        'Used in views'                  = YesNo $a.Table $a.LogicalName @('View', 'Chart', 'PersonalView', 'Dashboard')
        'Used in workflows/flows'        = YesNo $a.Table $a.LogicalName @('Workflow/Flow')
        'Used in plugins/JS'             = YesNo $a.Table $a.LogicalName @('Plugin', 'WebResource/JS')
        'Used in reports/Power BI'       = (YesNo $a.Table $a.LogicalName @('Report')) + $(if ($IncludeReferences -or $UnpackedPath) { ' (Power BI: CONFIRM WITH OWNER)' })
        'Used by integration'            = 'CONFIRM WITH OWNER'
        'Business owner' = ''; 'Owner sign-off (Y/N)' = ''
        'Decision (Delete/Deprecate/Keep)' = ''
        'Phase' = ''; 'Dev done' = ''; 'Sandbox tested' = ''; 'Prod released' = ''
        'Notes' = "Proposed by script: $($a.SuggestedAction)" + $(if ($a.DuplicateGroup) { "; group $($a.DuplicateGroup)" })
    }
}
$sheet | Export-Csv "$OutDir\field-decision-sheet.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`nWrote to ${OutDir}:"
Write-Host "  all-columns-audit.csv ($(@($audit).Count) columns)"
Write-Host "  candidate-references.csv ($($refs.Count) references for $($cand.Count) columns)"
Write-Host "  field-decision-sheet.csv ($(@($sheet).Count) rows)"
$audit | Group-Object { ($_.SuggestedAction -split ' ')[0] } | ForEach-Object { Write-Host ("  {0,-20} {1}" -f $_.Name, $_.Count) }
Write-Host "These are leads, not verdicts. Plugin source code, Power BI, templates, Power Pages and integrations still need manual checks before any deletion."
