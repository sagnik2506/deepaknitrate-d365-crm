<#
.SYNOPSIS
  Read-only check of how each custom MONEY column of one or more tables, and its base-currency twin (<name>_base),
  is used in a Dataverse environment. Only GET requests are made.

  For every money field it records:
    * platform dependencies of the field and of its twin, by component type (forms, views, charts, workflows and
      business rules, plugin steps, reports, other)
    * environment items that mention the field or its twin by name: plugin step filters, reports, flows and workflows,
      personal views and JavaScript web resources

  The result tells you whether the twin (the converted base-currency value) is used anywhere, which is the key
  question before changing a currency column to decimal.

.PARAMETER EnvUrl
  e.g. https://yourorg.crm8.dynamics.com

.PARAMETER UseAzCli
  Reuse the Azure CLI session (sign in yourself first: az login --allow-no-subscriptions).
  Alternatives: -TenantId/-ClientId/-ClientSecret (client credentials) or -Token.

.EXAMPLE
  .\Get-MoneyFieldUsage.ps1 -EnvUrl https://yourorg.crm8.dynamics.com -UseAzCli -Table quotedetail,salesorderdetail
#>
param(
    [Parameter(Mandatory)] [string] $EnvUrl,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $Token,
    [switch] $UseAzCli,
    [string[]] $Table = @('quotedetail', 'salesorderdetail'),
    [string] $OutDir = '.\money-usage'
)

# with "pwsh -File", -Param a,b arrives as one string; split a comma-separated list into separate values
if ($Table) { $Table = @($Table | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$EnvUrl = $EnvUrl.TrimEnd('/')
$api    = "$EnvUrl/api/data/v9.2"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------------- authentication (same pattern as the other scripts) ----------------
$script:tokenExpiry = [datetime]::MaxValue
function Get-AccessToken {
    if ($UseAzCli) {
        $t = (& az account get-access-token --resource $EnvUrl --query accessToken -o tsv 2>$null)
        if (-not $t) { throw "Could not get a token from the Azure CLI. Run: az login --allow-no-subscriptions   (sign in yourself), then rerun." }
        $script:tokenExpiry = (Get-Date).AddMinutes(40)
        return ([string]$t).Trim()
    }
    $secret = $ClientSecret
    if (-not $secret) { $secret = $env:DATAVERSE_CLIENT_SECRET }
    if (-not $secret) { $sec = Read-Host -Prompt "Client secret for $ClientId" -AsSecureString; $secret = [System.Net.NetworkCredential]::new('', $sec).Password }
    $body = @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $secret; scope = "$EnvUrl/.default" }
    try { $r = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body -ContentType 'application/x-www-form-urlencoded' }
    catch { throw "Token request failed for client $ClientId in tenant $TenantId. ($($_.Exception.Message))" }
    $script:tokenExpiry = (Get-Date).AddSeconds([int]$r.expires_in - 300)
    $r.access_token
}
function Update-Token { if ($script:useClientCreds -and (Get-Date) -ge $script:tokenExpiry) { $script:headers.Authorization = "Bearer $(Get-AccessToken)" } }
$script:useClientCreds = [bool](($TenantId -and $ClientId) -or $UseAzCli)
if ($script:useClientCreds) { $Token = Get-AccessToken } elseif (-not $Token) { throw "Pass -UseAzCli (after az login), or -TenantId/-ClientId/-ClientSecret, or -Token." }
$script:headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Prefer = 'odata.maxpagesize=500' }

function Invoke-Get([string] $url) {
    for ($try = 1; $try -le 6; $try++) {
        Update-Token
        try { return Invoke-RestMethod -Uri $url -Headers $script:headers -Method Get }
        catch {
            $code = $null; $resp = $_.Exception.Response
            if ($resp) { try { $code = [int]$resp.StatusCode } catch { } }
            if ((($code -eq 429) -or ($code -in 502, 503, 504)) -and ($try -lt 6)) {
                $wait = 30; try { $ra = $resp.Headers['Retry-After']; if ($ra) { $wait = [int]@($ra)[0] } } catch { }
                Write-Host "   service busy ($code); waiting $wait s"; Start-Sleep -Seconds $wait
            } elseif ($code -in 401, 403) { throw "The environment rejected the sign-in (HTTP $code). Run 'az account show': it must be the account that has access to $EnvUrl, in that tenant. Then run 'az logout' and 'az login --allow-no-subscriptions --tenant <tenant id>' and try again. If a WhoAmI call still fails, ask the environment admin to add the account with a read-only role." } else { throw }
        }
    }
}
function Get-AllPages([string] $url) {
    $rows = New-Object System.Collections.Generic.List[object]
    while ($url) { $r = Invoke-Get $url; foreach ($v in $r.value) { $rows.Add($v) }; $url = $r.'@odata.nextLink' }
    $rows
}
function Get-DepCategory([int] $t) {
    switch ($t) {
        { $_ -in 24, 60 } { 'Form' }  26 { 'View' }  59 { 'Chart' }  29 { 'WorkflowOrRule' }  61 { 'WebResource' }
        { $_ -in 90, 91, 92, 93 } { 'PluginStep' }  { $_ -in 31, 32 } { 'Report' }
        { $_ -in 3, 10, 46, 47 } { 'RelationshipOrMapping' }  { $_ -in 70, 71 } { 'FieldSecurity' }
        default { 'Other' }
    }
}
function Get-DepCounts($metadataId) {
    $c = @{ Form = 0; View = 0; Chart = 0; WorkflowOrRule = 0; PluginStep = 0; Report = 0; RelationshipOrMapping = 0; FieldSecurity = 0; WebResource = 0; Other = 0 }
    try {
        $dep = Invoke-Get "$api/RetrieveDependenciesForDelete(ObjectId=$metadataId,ComponentType=2)"
        $items = @(if ($dep.value) { $dep.value } elseif ($dep.EntityCollection) { $dep.EntityCollection } else { @() })
        foreach ($d in $items) { $c[(Get-DepCategory ([int]$d.dependentcomponenttype))]++ }
        $c['Total'] = $items.Count
    } catch { $c['Total'] = -1 }
    $c
}

# ---------------- 1. money fields, their twins, platform dependencies ----------------
$fields = New-Object System.Collections.Generic.List[object]
foreach ($t in $Table) {
    Write-Host "== $t"
    $attrs = @((Invoke-Get "$api/EntityDefinitions(LogicalName='$t')/Attributes?`$select=MetadataId,LogicalName,AttributeType,IsCustomAttribute,DisplayName").value | Where-Object { $_.IsCustomAttribute })
    $byName = @{}; foreach ($a in $attrs) { $byName[$a.LogicalName] = $a }
    $money = @($attrs | Where-Object { $_.AttributeType -eq 'Money' -and -not ($_.LogicalName.EndsWith('_base') -and $byName.ContainsKey($_.LogicalName.Substring(0, $_.LogicalName.Length - 5))) })
    Write-Host "   $($money.Count) money fields"
    $n = 0
    foreach ($m in $money) {
        $n++; if ($n % 25 -eq 0) { Write-Host "   $n of $($money.Count)" }
        $twin = $byName["$($m.LogicalName)_base"]
        $pc = Get-DepCounts $m.MetadataId
        $tc = if ($twin) { Get-DepCounts $twin.MetadataId } else { @{ Total = -2 } }
        $label = if ($m.DisplayName.UserLocalizedLabel) { $m.DisplayName.UserLocalizedLabel.Label } else { '' }
        $fields.Add([pscustomobject][ordered]@{
            Table = $t; LogicalName = $m.LogicalName; DisplayName = $label; TwinName = $(if ($twin) { $twin.LogicalName } else { '' })
            FieldDepsTotal = $pc.Total; FieldForms = $pc.Form; FieldViews = $pc.View; FieldCharts = $pc.Chart; FieldWorkflowsOrRules = $pc.WorkflowOrRule
            FieldPluginStepDeps = $pc.PluginStep; FieldReportDeps = $pc.Report; FieldMappings = $pc.RelationshipOrMapping; FieldSecurityProfiles = $pc.FieldSecurity
            FieldWebResources = $pc.WebResource; FieldOtherDeps = $pc.Other
            TwinDepsTotal = $tc.Total; TwinForms = $tc.Form; TwinViews = $tc.View; TwinCharts = $tc.Chart; TwinWorkflowsOrRules = $tc.WorkflowOrRule
            TwinPluginStepDeps = $tc.PluginStep; TwinReportDeps = $tc.Report; TwinMappings = $tc.RelationshipOrMapping; TwinOtherDeps = ($tc.Other + $tc.FieldSecurity + $tc.WebResource)
        })
    }
}
$fields | Export-Csv "$OutDir\money-usage-dependencies.csv" -NoTypeInformation -Encoding UTF8
Write-Host "Saved $OutDir\money-usage-dependencies.csv ($($fields.Count) fields). Reading environment items next."

# ---------------- 2. environment items that mention the field or its twin by name ----------------
$names = New-Object System.Collections.Generic.List[string]
foreach ($f in $fields) { $names.Add($f.LogicalName.ToLowerInvariant()); if ($f.TwinName) { $names.Add($f.TwinName.ToLowerInvariant()) } }
$alt = @($names | Select-Object -Unique | ForEach-Object { [regex]::Escape($_) } | Sort-Object { $_.Length } -Descending) -join '|'
$rx  = New-Object System.Text.RegularExpressions.Regex(('(?<![A-Za-z0-9_])_?(' + $alt + ')(?:_value)?(?![A-Za-z0-9_])'), 'IgnoreCase, Compiled')

$sources = @(
    @{ Name = 'PluginSteps'; Url = "$api/sdkmessageprocessingsteps?`$select=name,filteringattributes";               Props = @('filteringattributes') },
    @{ Name = 'Reports';     Url = "$api/reports?`$select=name,bodytext";                                             Props = @('bodytext') },
    @{ Name = 'Flows';       Url = "$api/workflows?`$select=name,category,clientdata,xaml";                          Props = @('clientdata', 'xaml') },
    @{ Name = 'PersonalViews'; Url = "$api/userqueries?`$select=name,fetchxml,layoutxml";                           Props = @('fetchxml', 'layoutxml') },
    @{ Name = 'Scripts';     Url = "$api/webresourceset?`$select=name,content&`$filter=webresourcetype eq 3";         Props = @('text') }
)
$hits = @{}   # source -> name -> HashSet of item names
foreach ($s in $sources) {
    Write-Host "Reading $($s.Name)..."
    $items = Get-AllPages $s.Url
    if ($s.Name -eq 'Scripts') { foreach ($i in $items) { if ($i.content) { $i | Add-Member -NotePropertyName text -NotePropertyValue ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($i.content))) -Force } } }
    $map = @{}
    foreach ($i in $items) {
        foreach ($p in $s.Props) {
            $t = [string]$i.$p; if (-not $t) { continue }
            foreach ($m in $rx.Matches($t)) {
                $k = $m.Groups[1].Value.ToLowerInvariant()
                if (-not $map.ContainsKey($k)) { $map[$k] = New-Object 'System.Collections.Generic.HashSet[string]' }
                [void]$map[$k].Add([string]$i.name)
            }
        }
    }
    $hits[$s.Name] = $map
    Write-Host "   $(@($items).Count) items read; $($map.Count) distinct field names mentioned"
}
function Hit($src, $name) {
    if (-not $name) { return @{ Count = 0; Names = '' } }
    $k = $name.ToLowerInvariant()
    if ($hits[$src].ContainsKey($k)) { $set = @($hits[$src][$k]); @{ Count = $set.Count; Names = (($set | Select-Object -First 4) -join ' | ') } } else { @{ Count = 0; Names = '' } }
}
$out = foreach ($f in $fields) {
    $row = [ordered]@{}
    foreach ($p in $f.PSObject.Properties) { $row[$p.Name] = $p.Value }
    foreach ($s in 'PluginSteps', 'Reports', 'Flows', 'PersonalViews', 'Scripts') {
        $h = Hit $s $f.LogicalName; $row["Field$s"] = $h.Count; $row["Field${s}Names"] = $h.Names
        $h2 = Hit $s $f.TwinName;  $row["Twin$s"] = $h2.Count;  $row["Twin${s}Names"] = $h2.Names
    }
    [pscustomobject]$row
}
$out | Export-Csv "$OutDir\money-usage-full.csv" -NoTypeInformation -Encoding UTF8
Write-Host "`nWrote $OutDir\money-usage-full.csv ($(@($out).Count) money fields)."
$tw = @($out | Where-Object { [int]$_.TwinDepsTotal -gt 0 -or [int]$_.TwinPluginSteps -gt 0 -or [int]$_.TwinReports -gt 0 -or [int]$_.TwinFlows -gt 0 -or [int]$_.TwinScripts -gt 0 -or [int]$_.TwinPersonalViews -gt 0 })
Write-Host "Money fields whose base-currency twin is used somewhere: $($tw.Count) of $(@($out).Count)"
