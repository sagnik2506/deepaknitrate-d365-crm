<#
.SYNOPSIS
  Read-only inventory of hand-made changes in a Dataverse environment (Phase 1 and a proposed Phase 2
  classification of the "unmanaged layer" clean-up). Only GET requests are made; nothing is changed.

  List A  managed components that carry an unmanaged "Active" layer (someone edited them directly)
  List B  components that exist only because someone created them directly in the environment
          (not part of any managed solution)

  Then it proposes Keep / Discard-candidate / Review for each item. The proposal is a lead for the
  human review, never a decision.

.NOTES
  PRODUCTION VERSION (hardened). Safe defaults, all read-only:
    * No record data is read. The "does a column hold a value" query is OFF (-IncludeDataCheck turns it on).
    * The environment-wide listing of unmanaged plugin steps, web resources and flows is OFF (-IncludeEnvironmentWide turns it on).
    * Pauses -DelayMs (default 300) between requests, and stops after -MaxMinutes (default 30).
    * Stops cleanly at the next request if the file given by -StopFile exists (default .\STOP-LAYER-RUN.txt).
    * Platform-generated companion columns (rollup _date/_state, money _base twins, name columns) are skipped.
    * Only the tables you pass with -Table are inspected.
  Nothing is created, changed or deleted in the environment.

.PARAMETER EnvUrl
  e.g. https://yourorg.crm.dynamics.com. Run it against a FULL COPY of production (sandbox), or against
  production off-hours with a read-only application user. Large tables mean many calls; the script
  retries when the service throttles (HTTP 429) and can resume with -Resume.

.PARAMETER TenantId / ClientId / ClientSecret / Token
  Same as Get-TableAttributeAudit.ps1: client-credentials flow (secret from -ClientSecret, else
  $env:DATAVERSE_CLIENT_SECRET, else a hidden prompt) or a ready-made -Token. The application user needs a
  read-only role with read access to metadata, forms, views, charts, workflows, web resources and plugin
  steps, plus whatever grants read access to the component layer table.

.PARAMETER Table
.PARAMETER TableListCsv
  Tables to inspect (logical names; CSV with a column named Table).

.PARAMETER SolutionName
  Alternative: unique name(s) of your managed solution(s); their tables are inspected.

.PARAMETER Prefix
  Your publisher prefix, e.g. abc_ . Used to limit the web resources checked for layers.

.PARAMETER ActiveLayerName
  Name of the unmanaged layer as the component layer table reports it. Default 'Active'.
  Check layer-names-seen.csv after the first run and adjust if needed.

.PARAMETER IncludeLayerDetail
  Also asks for the layer's change description (msdyn_changes) to spot Active layers that change nothing.
  If the column is not available in your environment the script falls back automatically.

.PARAMETER IncludeSystemColumns
  Also check layers on out-of-the-box columns (thousands of calls). Default: custom columns only.

.PARAMETER Resume
  Skip components already written to active-layers.csv by an earlier, interrupted run.

.OUTPUTS (in -OutDir)
  solutions.csv               every visible solution: managed or not, version, publisher
  production-only.csv         List B
  active-layers.csv           List A (one row per managed component that has an Active layer)
  layer-names-seen.csv        every layer name returned, with counts (use it to verify -ActiveLayerName)
  classification-proposal.csv A and B together, with ProposedClass, Reason and blank decision columns

.EXAMPLE
  $env:DATAVERSE_CLIENT_SECRET = '<secret>'
  .\Get-ActiveLayerInventory.ps1 -EnvUrl https://yourorg.crm.dynamics.com -TenantId <tenant> -ClientId <app> `
      -TableListCsv .\tables.csv -Prefix abc_ -IncludeLayerDetail

Not covered: plugin assemblies, site maps, model-driven app definitions, security roles, canvas apps, personal
flows and business-process flows' stage layout. Treat the result as strong evidence, not a complete proof.
The component layer table is a virtual table; its behaviour should be confirmed with one real run first.
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
    [string[]] $SolutionName,
    [string] $Prefix,
    [string] $ActiveLayerName = 'Active',
    [switch] $IncludeLayerDetail,
    [switch] $IncludeSystemColumns,
    [switch] $Resume,
    [int] $DelayMs = 300,
    [int] $MaxMinutes = 30,
    [string] $StopFile = '.\STOP-LAYER-RUN.txt',
    [switch] $IncludeEnvironmentWide,
    [switch] $IncludeDataCheck,
    [string] $OutDir = '.\layer-inventory'
)

# with "pwsh -File", -Param a,b arrives as one string; split a comma-separated list into separate values
if ($Table) { $Table = @($Table | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ($SolutionName) { $SolutionName = @($SolutionName | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$EnvUrl = $EnvUrl.TrimEnd('/')
$api    = "$EnvUrl/api/data/v9.2"
$script:started = Get-Date; $script:requests = 0; $script:stopped = $false
function Assert-KeepGoing {
    if (Test-Path -LiteralPath $StopFile) { $script:stopped = $true; throw "Stopped: the stop file ($StopFile) was found." }
    if (((Get-Date) - $script:started).TotalMinutes -gt $MaxMinutes) { $script:stopped = $true; throw "Stopped: the time limit of $MaxMinutes minutes was reached." }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------------- authentication (same pattern as the audit script) ----------------
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
    $script:tokenExpiry = (Get-Date).AddSeconds([int]$r.expires_in - 300)
    $r.access_token
}
function Update-Token {
    if ($script:useClientCreds -and (Get-Date) -ge $script:tokenExpiry) { $script:headers.Authorization = "Bearer $(Get-AccessToken)" }
}
$script:useClientCreds = [bool](($TenantId -and $ClientId) -or $UseAzCli)
if ($script:useClientCreds)  { Write-Host ("Requesting token (" + $(if ($UseAzCli) { 'Azure CLI session' } else { 'client ' + $ClientId }) + ") ..."); $Token = Get-AccessToken }
elseif (-not $Token)         { throw "Pass -UseAzCli (after az login), or -TenantId/-ClientId/-ClientSecret (or DATAVERSE_CLIENT_SECRET), or -Token." }
$script:headers = @{
    Authorization = "Bearer $Token"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'
    Prefer = 'odata.maxpagesize=500,odata.include-annotations="OData.Community.Display.V1.FormattedValue"'
}

# GET with retry when the service throttles (429) or has a transient failure
function Invoke-Get([string] $url) {
    Assert-KeepGoing
    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    for ($try = 1; $try -le 6; $try++) {
        Update-Token
        $script:requests++
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
$fmt = 'OData.Community.Display.V1.FormattedValue'
function Fv($o, [string] $prop) { $v = $o."$prop@$fmt"; if ($v) { $v } else { '' } }

# ---------------- what to inspect ----------------
if ($TableListCsv) { $Table = @(Import-Csv $TableListCsv | ForEach-Object { $_.Table } | Where-Object { $_ }) }

Write-Host "Reading solutions..."
$sols = Get-AllPages "$api/solutions?`$select=solutionid,uniquename,friendlyname,ismanaged,version,isvisible&`$filter=isvisible eq true"
$sols | ForEach-Object {
    [pscustomobject]@{ UniqueName = $_.uniquename; FriendlyName = $_.friendlyname; Managed = $_.ismanaged; Version = $_.version; Publisher = (Fv $_ '_publisherid_value') }
} | Export-Csv "$OutDir\solutions.csv" -NoTypeInformation -Encoding UTF8
$unmanagedSols = @($sols | Where-Object { -not $_.ismanaged -and $_.uniquename -ne 'Default' })
if ($unmanagedSols.Count) { Write-Host "NOTE: unmanaged solutions present: $(($unmanagedSols.uniquename) -join ', ') - their components also count as unmanaged." }

if ($SolutionName) {
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($sn in $SolutionName) {
        $s = $sols | Where-Object uniquename -eq $sn | Select-Object -First 1
        if (-not $s) { Write-Warning "Solution $sn not found"; continue }
        foreach ($c in (Get-AllPages "$api/solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $($s.solutionid) and componenttype eq 1")) {
            try { $found.Add((Invoke-Get "$api/EntityDefinitions($($c.objectid))?`$select=LogicalName").LogicalName) } catch { }
        }
    }
    $Table = @($Table) + @($found) | Where-Object { $_ } | Select-Object -Unique
}
if (-not $Table) { throw "Pass -Table, -TableListCsv or -SolutionName." }
Write-Host "Inspecting $(@($Table).Count) table(s)."

# ---------------- collect components ----------------
$managed  = New-Object System.Collections.Generic.List[object]    # candidates for List A
$prodOnly = New-Object System.Collections.Generic.List[object]    # List B
function New-Comp($table, $type, $solComp, $id, $name, $o, $extra) {
    [pscustomobject]@{
        Table = $table; Type = $type; SolComp = $solComp; Id = ([string]$id).Trim('{}').ToLowerInvariant(); Name = $name; Extra = $extra
        CreatedOn = $o.createdon; CreatedBy = (Fv $o '_createdby_value'); ModifiedOn = $o.modifiedon; ModifiedBy = (Fv $o '_modifiedby_value')
        State = if ($null -ne $o.statecode) { $o.statecode } else { '' }
    }
}
function Sort-Comp($c, [bool] $isManaged) { if ($isManaged) { $managed.Add($c) } else { $prodOnly.Add($c) } }
$empty = [pscustomobject]@{ createdon = ''; modifiedon = '' }

$tableMeta = @{}
foreach ($t in $Table) {
    Write-Host "== $t"
    try {
        $ent = Invoke-Get "$api/EntityDefinitions(LogicalName='$t')?`$select=MetadataId,LogicalName,IsManaged,EntitySetName,PrimaryIdAttribute"
    } catch { if ($script:stopped) { throw }; Write-Warning "  cannot read $t : $($_.Exception.Message)"; continue }
    $tableMeta[$t] = $ent
    Sort-Comp (New-Comp $t 'Table' 'Entity' $ent.MetadataId $t $empty '') ([bool]$ent.IsManaged)

    $attrs = (Invoke-Get "$api/EntityDefinitions(LogicalName='$t')/Attributes?`$select=MetadataId,LogicalName,AttributeType,IsCustomAttribute,IsManaged,IsPrimaryId,IsPrimaryName,AttributeOf").value
    $nameSet = @{}; foreach ($x in $attrs) { $nameSet[$x.LogicalName] = $true }
    foreach ($a in $attrs) {
        if ($a.AttributeOf -or $a.IsPrimaryId) { continue }
        # platform-generated companions follow their parent column: rollup _date/_state and money _base twins
        if ($a.LogicalName -match '_(date|state)$' -and $nameSet.ContainsKey(($a.LogicalName -replace '_(date|state)$', ''))) { continue }
        if ($a.AttributeType -eq 'Money' -and $a.LogicalName.EndsWith('_base') -and $nameSet.ContainsKey($a.LogicalName.Substring(0, $a.LogicalName.Length - 5))) { continue }
        if ($a.IsCustomAttribute -and -not $a.IsManaged) { Sort-Comp (New-Comp $t 'Column' 'Attribute' $a.MetadataId $a.LogicalName $empty $a.AttributeType) $false }
        elseif ($a.IsManaged -and ($a.IsCustomAttribute -or $IncludeSystemColumns)) { Sort-Comp (New-Comp $t 'Column' 'Attribute' $a.MetadataId $a.LogicalName $empty $a.AttributeType) $true }
    }
    foreach ($f in (Get-AllPages "$api/systemforms?`$select=formid,name,type,ismanaged&`$filter=objecttypecode eq '$t'")) {
        Sort-Comp (New-Comp $t 'Form' 'SystemForm' $f.formid $f.name $f '') ([bool]$f.ismanaged)
    }
    foreach ($v in (Get-AllPages "$api/savedqueries?`$select=savedqueryid,name,ismanaged,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=returnedtypecode eq '$t'")) {
        Sort-Comp (New-Comp $t 'View' 'SavedQuery' $v.savedqueryid $v.name $v '') ([bool]$v.ismanaged)
    }
    foreach ($c in (Get-AllPages "$api/savedqueryvisualizations?`$select=savedqueryvisualizationid,name,ismanaged,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=primaryentitytypecode eq '$t'")) {
        Sort-Comp (New-Comp $t 'Chart' 'SavedQueryVisualization' $c.savedqueryvisualizationid $c.name $c '') ([bool]$c.ismanaged)
    }
    foreach ($w in (Get-AllPages "$api/workflows?`$select=workflowid,name,category,statecode,ismanaged,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=primaryentity eq '$t' and type eq 1 and ismanaged eq true")) {
        Sort-Comp (New-Comp $t 'Workflow' 'Workflow' $w.workflowid $w.name $w "category $($w.category)") $true
    }
}

# environment-wide components that only exist because someone created them directly
Write-Host "== environment-wide (workflows/flows, web resources, plugin steps)"
if ($IncludeEnvironmentWide) {
foreach ($w in (Get-AllPages "$api/workflows?`$select=workflowid,name,category,statecode,primaryentity,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=ismanaged eq false and type eq 1")) {
    $prodOnly.Add((New-Comp $w.primaryentity 'Workflow/Flow' 'Workflow' $w.workflowid $w.name $w "category $($w.category)"))
}
} else { Write-Host "Skipping the environment-wide listing of unmanaged flows, web resources and plugin steps (default). Use -IncludeEnvironmentWide to turn it on." }
if ($IncludeEnvironmentWide) {
foreach ($w in (Get-AllPages "$api/webresourceset?`$select=webresourceid,name,ismanaged,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=ismanaged eq false")) {
    $prodOnly.Add((New-Comp '' 'WebResource' 'WebResource' $w.webresourceid $w.name $w ''))
}
}
if ($Prefix) {
    foreach ($w in (Get-AllPages "$api/webresourceset?`$select=webresourceid,name,ismanaged,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=ismanaged eq true and startswith(name,'$Prefix')")) {
        $managed.Add((New-Comp '' 'WebResource' 'WebResource' $w.webresourceid $w.name $w ''))
    }
}
if ($IncludeEnvironmentWide) {
foreach ($s in (Get-AllPages "$api/sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid,name,statecode,createdon,modifiedon,_createdby_value,_modifiedby_value&`$filter=ismanaged eq false")) {
    $prodOnly.Add((New-Comp '' 'PluginStep' 'SdkMessageProcessingStep' $s.sdkmessageprocessingstepid $s.name $s ''))
}
}
Write-Host "Components to check for layers: $($managed.Count); created directly in the environment: $($prodOnly.Count)"

# ---------------- List A: layers per managed component ----------------
$layerCsv = "$OutDir\active-layers.csv"
$done = @{}
$listA = New-Object System.Collections.Generic.List[object]
if ($Resume -and (Test-Path $layerCsv)) { Import-Csv $layerCsv | ForEach-Object { $done[$_.ComponentId] = $true; $listA.Add($_) } }
elseif (Test-Path $layerCsv) { Remove-Item $layerCsv }
$seen = @{}
$detail = [bool]$IncludeLayerDetail
$errShown = $false
$i = 0
foreach ($c in $managed) {
    $i++
    if ($done.ContainsKey($c.Id)) { continue }
    if ($i % 25 -eq 0) { Write-Progress -Activity "Reading component layers" -Status "$i of $($managed.Count)" -PercentComplete (100 * $i / [math]::Max(1, $managed.Count)) }
    $sel = 'msdyn_solutionname,msdyn_order,msdyn_overwritetime' + $(if ($detail) { ',msdyn_changes' })
    $url = "$api/msdyn_componentlayers?`$filter=msdyn_componentid eq '$($c.Id)' and msdyn_solutioncomponentname eq '$($c.SolComp)'&`$select=$sel"
    try { $layers = @((Invoke-Get $url).value) }
    catch {
        if ($script:stopped) { Write-Warning $_.Exception.Message; break }
        if ($detail) { Write-Warning "Layer detail column not available; continuing without it. ($($_.Exception.Message))"; $detail = $false
            try { $layers = @((Invoke-Get ($url -replace ',msdyn_changes', '')).value) } catch { $layers = $null } }
        else { $layers = $null }
        if ($null -eq $layers) {
            if (-not $errShown) { Write-Warning "Layer query failed for $($c.Type) $($c.Name): $($_.Exception.Message)"; $errShown = $true }
            $listA.Add([pscustomobject]@{ Table = $c.Table; Type = $c.Type; Name = $c.Name; ComponentId = $c.Id; Layers = ''; ActiveLayerTime = ''; ActiveChange = 'LAYER-QUERY-ERROR' })
            continue
        }
    }
    foreach ($l in $layers) { $seen[$l.msdyn_solutionname] = 1 + [int]$seen[$l.msdyn_solutionname] }
    $ordered = @($layers | Sort-Object { [int]$_.msdyn_order } -Descending)
    $active  = $ordered | Where-Object { $_.msdyn_solutionname -eq $ActiveLayerName } | Select-Object -First 1
    if ($active) {
        $chg = 'not requested'
        if ($detail) {
            $raw = [string]$active.msdyn_changes
            $chg = if (-not $raw -or $raw.Trim() -in '[]', '{}', 'null') { 'NO-VISIBLE-CHANGE' } else { 'CHANGES' }
        }
        $row = [pscustomobject]@{ Table = $c.Table; Type = $c.Type; Name = $c.Name; ComponentId = $c.Id
            Layers = (($ordered | ForEach-Object { $_.msdyn_solutionname }) -join ' > '); ActiveLayerTime = $active.msdyn_overwritetime; ActiveChange = $chg }
        $listA.Add($row); $row | Export-Csv $layerCsv -NoTypeInformation -Encoding UTF8 -Append
    }
}
Write-Progress -Activity "Reading component layers" -Completed
if ($Resume -and $done.Count) { Write-Host "Resumed: $($done.Count) components were already in active-layers.csv." }
$seen.GetEnumerator() | Sort-Object Name | ForEach-Object { [pscustomobject]@{ LayerName = $_.Name; Components = $_.Value } } |
    Export-Csv "$OutDir\layer-names-seen.csv" -NoTypeInformation -Encoding UTF8

# ---------------- List B: facts for production-only items ----------------
$listB = foreach ($c in $prodOnly) {
    $hasData = ''; $deps = ''
    if ($c.Type -eq 'Column' -and $tableMeta.ContainsKey($c.Table)) {
        $ent = $tableMeta[$c.Table]
        $field = if ($c.Extra -in 'Lookup', 'Customer', 'Owner') { "_$($c.Name)_value" } else { $c.Name }
        if ($IncludeDataCheck) {
            try { $q = Invoke-Get "$api/$($ent.EntitySetName)?`$select=$($ent.PrimaryIdAttribute)&`$filter=$field ne null&`$top=1"; $hasData = if (@($q.value).Count) { 'yes' } else { 'no' } }
            catch { if ($script:stopped) { throw }; $hasData = 'unknown' }
        } else { $hasData = 'not checked (no record data is read)' }
        try {
            $d = Invoke-Get "$api/RetrieveDependenciesForDelete(ObjectId=$($c.Id),ComponentType=2)"
            $deps = @(if ($d.value) { $d.value } elseif ($d.EntityCollection) { $d.EntityCollection } else { @() }).Count
        } catch { $deps = 'error' }
    }
    [pscustomobject][ordered]@{ Table = $c.Table; Type = $c.Type; Name = $c.Name; ComponentId = $c.Id; ColumnType = $c.Extra
        CreatedOn = $c.CreatedOn; CreatedBy = $c.CreatedBy; ModifiedOn = $c.ModifiedOn; ModifiedBy = $c.ModifiedBy; HasData = $hasData; Dependencies = $deps; State = $c.State }
}
$listB | Export-Csv "$OutDir\production-only.csv" -NoTypeInformation -Encoding UTF8

# ---------------- proposed classification (a lead for the review, not a decision) ----------------
$optionTypes = 'Picklist', 'MultiSelectPicklist', 'State', 'Status'
$proposal = New-Object System.Collections.Generic.List[object]
foreach ($b in $listB) {
    if ($b.Type -eq 'Column') {
        if ($b.HasData -eq 'no' -and $b.Dependencies -eq 0) { $cls = 'DISCARD-CANDIDATE'; $why = 'created directly; no data and no dependencies' }
        elseif ($b.HasData -eq 'yes') { $cls = 'KEEP'; $why = 'created directly; holds data' }
        else { $cls = 'KEEP'; $why = "created directly; dependencies=$($b.Dependencies), data=$($b.HasData)" }
        $risk = if ($b.ColumnType -in $optionTypes) { 'Option set: confirm values before any change' } else { '' }
    } elseif ($b.Type -in 'Workflow/Flow', 'Workflow' -and "$($b.State)" -eq '0') {
        $cls = 'REVIEW'; $why = 'created directly; draft/inactive'; $risk = ''
    } else { $cls = 'KEEP'; $why = 'created directly; confirm owner and purpose'; $risk = '' }
    $proposal.Add([pscustomobject][ordered]@{ List = 'B'; Table = $b.Table; Type = $b.Type; Name = $b.Name; ComponentId = $b.ComponentId
        Layers = ''; CreatedBy = $b.CreatedBy; ModifiedOn = $b.ModifiedOn; ModifiedBy = $b.ModifiedBy; Risk = $risk
        ProposedClass = $cls; Reason = $why; FinalDecision = ''; Reviewer = ''; Notes = '' })
}
foreach ($a in $listA) {
    $colType = ($managed | Where-Object { $_.Id -eq $a.ComponentId } | Select-Object -First 1).Extra
    $risk = if ($colType -in $optionTypes) { 'Option set: removing the layer can drop values/labels added here' } else { '' }
    $cls = switch ($a.ActiveChange) {
        'NO-VISIBLE-CHANGE'  { 'DISCARD-CANDIDATE'; break }
        'CHANGES'            { 'KEEP'; break }
        'LAYER-QUERY-ERROR'  { 'REVIEW'; break }
        default              { 'REVIEW' }
    }
    $why = switch ($a.ActiveChange) {
        'NO-VISIBLE-CHANGE' { 'Active layer reports no change from the managed layer' }
        'CHANGES'           { 'Active layer changes the managed definition; compare in Solution Layers > Changes' }
        'LAYER-QUERY-ERROR' { 'layer query failed; check manually' }
        default             { 'Active layer exists; detail not requested (use -IncludeLayerDetail or compare manually)' }
    }
    $proposal.Add([pscustomobject][ordered]@{ List = 'A'; Table = $a.Table; Type = $a.Type; Name = $a.Name; ComponentId = $a.ComponentId
        Layers = $a.Layers; CreatedBy = ''; ModifiedOn = $a.ActiveLayerTime; ModifiedBy = ''; Risk = $risk
        ProposedClass = $cls; Reason = $why; FinalDecision = ''; Reviewer = ''; Notes = '' })
}
$proposal | Export-Csv "$OutDir\classification-proposal.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`nWrote to ${OutDir}:"
Write-Host "  solutions.csv ($($sols.Count) solutions)"
Write-Host "  active-layers.csv   - List A: $($listA.Count) managed components with an '$ActiveLayerName' layer"
Write-Host "  production-only.csv - List B: $(@($listB).Count) components created directly"
Write-Host "  layer-names-seen.csv (check that '$ActiveLayerName' is how your environment names the unmanaged layer)"
Write-Host "  classification-proposal.csv"
$proposal | Group-Object ProposedClass | ForEach-Object { Write-Host ("    {0,-18} {1}" -f $_.Name, $_.Count) }
if ($seen.Count -eq 0 -and $managed.Count -gt 0) { Write-Warning "No layers were returned for any component. The layer table may need different permissions or filter values in your environment." }
Write-Host "These are leads for human review. Nothing was changed in the environment."

# ---------------- run summary ----------------
Write-Host ""
Write-Host ("Requests made: {0}; elapsed: {1:N1} minutes; delay between requests: {2} ms." -f $script:requests, ((Get-Date) - $script:started).TotalMinutes, $DelayMs)
if ($script:stopped) { Write-Warning "THE RUN WAS STOPPED EARLY. The results are partial. Run again with -Resume to continue." }
Write-Host "Nothing was created, changed or deleted in the environment. No record data was read."
