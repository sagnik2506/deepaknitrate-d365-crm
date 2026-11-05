<#
.SYNOPSIS
  Read-only checks against a Dataverse environment for references to candidate columns that
  are NOT in the solution file: dependencies, personal views, flows/workflows, plugin step
  filters, reports, JavaScript web resources.

.PARAMETER EnvUrl
  Environment URL, e.g. https://yourorg.crm.dynamics.com   (use a sandbox copy of production)

.PARAMETER TenantId
.PARAMETER ClientId
.PARAMETER ClientSecret
  Entra ID app registration; the script requests and renews its own token. The app must also be an
  Application user in the environment with a read-only role. Secret: -ClientSecret, else the
  DATAVERSE_CLIENT_SECRET environment variable, else a hidden prompt.

.PARAMETER Token
  Alternative: a ready-made bearer token, e.g.
    $token = az account get-access-token --resource https://yourorg.crm.dynamics.com --query accessToken -o tsv

.PARAMETER FieldListCsv
  CSV with columns Table and LogicalName (table logical name and column logical name).

.EXAMPLE
  .\Get-DataverseUsage.ps1 -EnvUrl https://yourorg.crm.dynamics.com -TenantId <tenant> -ClientId <app> -FieldListCsv .\fields.csv -OutCsv .\env-usage.csv

Only GET requests are made. Nothing is changed in the environment.
#>
param(
    [Parameter(Mandatory)] [string] $EnvUrl,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $Token,
    [switch] $UseAzCli,
    [Parameter(Mandatory)] [string] $FieldListCsv,
    [string] $OutCsv = '.\env-usage.csv'
)

$EnvUrl  = $EnvUrl.TrimEnd('/')
$api     = "$EnvUrl/api/data/v9.2"

# Authentication: client-credentials (TenantId + ClientId + secret) or a ready-made -Token.
# The secret comes from -ClientSecret, else $env:DATAVERSE_CLIENT_SECRET, else a hidden prompt.
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
    if ($script:useClientCreds -and (Get-Date) -ge $script:tokenExpiry) {
        $script:headers.Authorization = "Bearer $(Get-AccessToken)"
    }
}
$script:useClientCreds = [bool](($TenantId -and $ClientId) -or $UseAzCli)
if ($script:useClientCreds)  { Write-Host ("Requesting token (" + $(if ($UseAzCli) { 'Azure CLI session' } else { 'client ' + $ClientId }) + ") ..."); $Token = Get-AccessToken }
elseif (-not $Token)         { throw "Pass -UseAzCli (after az login), or -TenantId/-ClientId/-ClientSecret (or DATAVERSE_CLIENT_SECRET), or -Token." }
$script:headers = @{
    Authorization      = "Bearer $Token"
    Accept             = 'application/json'
    'OData-MaxVersion' = '4.0'
    'OData-Version'    = '4.0'
    Prefer             = 'odata.maxpagesize=500'
}

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
    while ($url) {
        $r = Invoke-Get $url
        foreach ($v in $r.value) { $rows.Add($v) }
        $url = $r.'@odata.nextLink'
    }
    $rows
}

$fields = Import-Csv $FieldListCsv
if (-not ($fields | Get-Member -Name Table) -or -not ($fields | Get-Member -Name LogicalName)) {
    throw "FieldListCsv needs Table and LogicalName columns."
}

# --- Pull the searchable text once, then search it per field in memory ---
Write-Host "Reading personal views (userquery)..."
$personalViews = Get-AllPages "$api/userqueries?`$select=name,fetchxml,layoutxml"

Write-Host "Reading flows and workflows..."
$workflows = Get-AllPages "$api/workflows?`$select=name,category,clientdata,xaml&`$filter=statecode eq 1 or statecode eq 0"

Write-Host "Reading plugin step registrations..."
$steps = Get-AllPages "$api/sdkmessageprocessingsteps?`$select=name,filteringattributes"

Write-Host "Reading reports..."
$reports = Get-AllPages "$api/reports?`$select=name,bodytext"

Write-Host "Reading JavaScript web resources..."
$scripts = Get-AllPages "$api/webresourceset?`$select=name,content&`$filter=webresourcetype eq 3"
foreach ($s in $scripts) {
    if ($s.content) { $s | Add-Member -NotePropertyName text -NotePropertyValue ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s.content))) -Force }
}

function Find-Hits($items, [string[]] $textProps, [string] $name) {
    $pat = "(?<![a-z0-9_])_?$([regex]::Escape($name))(?:_value)?(?![a-z0-9_])"   # also matches _<column>_value (lookups)
    $hits = foreach ($i in $items) {
        foreach ($p in $textProps) {
            if ($i.$p -and ([string]$i.$p).ToLowerInvariant() -match $pat) { $i.name; break }
        }
    }
    @($hits | Select-Object -Unique)
}

$out = foreach ($f in $fields) {
    $col = $f.LogicalName.ToLowerInvariant()
    Write-Host "Checking $($f.Table).$($f.LogicalName)"

    # Dependencies the platform knows about (same data as "Show dependencies")
    $depCount = ''; $depDetail = ''
    try {
        $meta = Invoke-Get "$api/EntityDefinitions(LogicalName='$($f.Table)')/Attributes(LogicalName='$($f.LogicalName)')?`$select=MetadataId"
        $dep  = Invoke-Get "$api/RetrieveDependenciesForDelete(ObjectId=$($meta.MetadataId),ComponentType=2)"
        # the response is a plain collection of dependency rows; accept either JSON shape
        $items = if ($dep.value) { $dep.value } elseif ($dep.EntityCollection) { $dep.EntityCollection } else { @() }
        $depCount  = @($items).Count
        $depDetail = (@($items) | ForEach-Object {
            "type=$($_.dependentcomponenttype);id=$($_.dependentcomponentobjectid)"
        }) -join ' | '
    } catch { $depCount = 'error'; $depDetail = $_.Exception.Message }

    [pscustomobject]@{
        Table                = $f.Table
        LogicalName          = $f.LogicalName
        PlatformDependencies = $depCount
        PlatformDetail       = $depDetail
        PersonalViews        = (Find-Hits $personalViews 'fetchxml','layoutxml' $col) -join ' | '
        FlowsAndWorkflows    = (Find-Hits $workflows     'clientdata','xaml'   $col) -join ' | '
        PluginStepFilters    = (Find-Hits $steps         'filteringattributes' $col) -join ' | '
        Reports              = (Find-Hits $reports       'bodytext'            $col) -join ' | '
        JavaScript           = (Find-Hits $scripts       'text'                $col) -join ' | '
    }
}

$out | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8
Write-Host "Wrote $OutCsv"
Write-Host "Not covered here: plugin/custom-activity source code, Power BI, Excel/Word templates, Power Pages, external integrations. Ask the owners."
