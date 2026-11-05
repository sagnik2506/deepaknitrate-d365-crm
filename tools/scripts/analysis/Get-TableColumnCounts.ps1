<#
.SYNOPSIS
  Ranks the tables of a Dataverse environment by number of columns, so you can pick the "heavily loaded"
  ones from data. Read-only: only GET requests are made.

  Per table: total columns, custom columns, custom columns created directly in the environment (not in a
  managed solution), custom lookups, counts by data type, the sum of text-column maximum lengths, and
  optionally the record count. Also writes tables-top.csv, ready to feed to the audit script.

.PARAMETER EnvUrl
  e.g. https://yourorg.crm.dynamics.com

.PARAMETER TenantId / ClientId / ClientSecret / Token
  Same as the other scripts: client-credentials flow (secret from -ClientSecret, else
  $env:DATAVERSE_CLIENT_SECRET, else a hidden prompt) or a ready-made -Token. A read-only role is enough.

.PARAMETER CustomTablesOnly
  Skip out-of-the-box tables that you did not extend. Faster, but misses account/contact/etc. Prefer the
  default (all tables) unless the run is too slow.

.PARAMETER IncludeTable
  With -CustomTablesOnly: out-of-the-box tables to include anyway, e.g. account,contact,incident.

.PARAMETER IncludeRecordCount
  Adds an approximate record count per table (the platform's cached count, which can be up to a day old).

.PARAMETER TopN
  How many tables go into tables-top.csv (default 5).

.OUTPUTS (in -OutDir)
  table-column-counts.csv   every table, ranked by custom column count
  tables-top.csv            the top N tables; header 'Table'; use as -TableListCsv for the audit scripts

.EXAMPLE
  $env:DATAVERSE_CLIENT_SECRET = '<secret>'
  .\Get-TableColumnCounts.ps1 -EnvUrl https://yourorg.crm.dynamics.com -TenantId <tenant> -ClientId <app> -IncludeRecordCount -TopN 5

Notes: the sum of text-column lengths and the type counts are raw facts to help you judge. They are not a
calculation of the SQL row-size limit, which has its own rules (check the current Microsoft table-limit
documentation). Companion columns that the platform creates for lookups and option sets (names, yomi names)
are excluded from the custom column count.
#>
param(
    [Parameter(Mandatory)] [string] $EnvUrl,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $Token,
    [switch] $UseAzCli,
    [switch] $CustomTablesOnly,
    [string[]] $IncludeTable,
    [switch] $IncludeRecordCount,
    [int] $TopN = 5,
    [string] $OutDir = '.\table-counts'
)

# with "pwsh -File", -Param a,b arrives as one string; split a comma-separated list into separate values
if ($IncludeTable) { $IncludeTable = @($IncludeTable | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$EnvUrl = $EnvUrl.TrimEnd('/')
$api    = "$EnvUrl/api/data/v9.2"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------------- authentication (same pattern as the other scripts) ----------------
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
$script:headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0' }

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

# ---------------- tables ----------------
Write-Host "Reading table list..."
$ents = @((Invoke-Get "$api/EntityDefinitions?`$select=LogicalName,SchemaName,IsCustomEntity,IsManaged,IsPrivate,IsIntersect").value |
    Where-Object { -not $_.IsPrivate -and -not $_.IsIntersect })
Write-Host "$($ents.Count) tables."
if ($CustomTablesOnly) {
    $keep = @($IncludeTable | ForEach-Object { $_.ToLowerInvariant() })
    $ents = @($ents | Where-Object { $_.IsCustomEntity -or ($keep -contains $_.LogicalName) })
    Write-Host "Custom tables (plus any -IncludeTable): $($ents.Count)."
}

# approximate record counts, in batches
$counts = @{}
if ($IncludeRecordCount) {
    Write-Host "Reading approximate record counts..."
    $names = @($ents | ForEach-Object { $_.LogicalName })
    for ($i = 0; $i -lt $names.Count; $i += 50) {
        $batch = $names[$i..([math]::Min($i + 49, $names.Count - 1))]
        $json  = [uri]::EscapeDataString(('[' + (($batch | ForEach-Object { '"' + $_ + '"' }) -join ',') + ']'))
        try {
            $r = Invoke-Get "$api/RetrieveTotalRecordCount(EntityNames=@p1)?@p1=$json"
            $k = @($r.EntityRecordCountCollection.Keys); $v = @($r.EntityRecordCountCollection.Values)
            for ($j = 0; $j -lt $k.Count; $j++) { $counts[$k[$j]] = $v[$j] }
        } catch { Write-Warning "Record count unavailable for a batch: $($_.Exception.Message)"; break }
    }
}

# ---------------- columns per table ----------------
$rows = New-Object System.Collections.Generic.List[object]
$n = 0
foreach ($e in $ents) {
    $n++
    if ($n % 20 -eq 0) { Write-Progress -Activity "Counting columns" -Status "$n of $($ents.Count)" -PercentComplete (100 * $n / $ents.Count) }
    try {
        $attrs = @((Invoke-Get "$api/EntityDefinitions(LogicalName='$($e.LogicalName)')/Attributes?`$select=LogicalName,AttributeType,IsCustomAttribute,IsManaged,AttributeOf").value)
    } catch { Write-Warning "Skipping $($e.LogicalName): $($_.Exception.Message)"; continue }

    $real   = @($attrs | Where-Object { -not $_.AttributeOf })           # drops companion *name / *yominame columns
    $custom = @($real  | Where-Object { $_.IsCustomAttribute })
    $strLen = $null
    if ($custom.Count -gt 0) {
        try {
            $s = (Invoke-Get "$api/EntityDefinitions(LogicalName='$($e.LogicalName)')/Attributes/Microsoft.Dynamics.CRM.StringAttributeMetadata?`$select=LogicalName,MaxLength,IsCustomAttribute").value
            $strLen = (@($s | Where-Object { $_.IsCustomAttribute }) | Measure-Object -Property MaxLength -Sum).Sum
        } catch { $strLen = $null }
    }
    $rows.Add([pscustomobject][ordered]@{
        Table                 = $e.LogicalName
        Custom                = [bool]$e.IsCustomEntity
        TotalColumns          = $real.Count
        CustomColumns         = $custom.Count
        CreatedDirectly       = @($custom | Where-Object { -not $_.IsManaged }).Count     # custom column not in a managed solution
        CustomLookups         = @($custom | Where-Object { $_.AttributeType -in 'Lookup', 'Customer', 'Owner' }).Count
        CustomText            = @($custom | Where-Object { $_.AttributeType -in 'String', 'Memo' }).Count
        CustomOptionSets      = @($custom | Where-Object { $_.AttributeType -in 'Picklist', 'MultiSelectPicklist', 'Status', 'State' }).Count
        CustomNumberDateBool  = @($custom | Where-Object { $_.AttributeType -in 'Integer', 'BigInt', 'Decimal', 'Double', 'Money', 'DateTime', 'Boolean' }).Count
        CustomTextMaxLenSum   = $strLen
        ApproxRecords         = if ($counts.ContainsKey($e.LogicalName)) { $counts[$e.LogicalName] } else { '' }
    })
}
Write-Progress -Activity "Counting columns" -Completed

$ranked = $rows | Sort-Object CustomColumns, TotalColumns -Descending
$ranked | Export-Csv "$OutDir\table-column-counts.csv" -NoTypeInformation -Encoding UTF8
$ranked | Select-Object -First $TopN | ForEach-Object { [pscustomobject]@{ Table = $_.Table } } | Export-Csv "$OutDir\tables-top.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`nTop 15 by custom columns:"
$ranked | Select-Object -First 15 | Format-Table Table, TotalColumns, CustomColumns, CreatedDirectly, CustomLookups, CustomTextMaxLenSum, ApproxRecords -AutoSize | Out-Host
Write-Host "Wrote $OutDir\table-column-counts.csv and $OutDir\tables-top.csv (top $TopN, ready for -TableListCsv)."
Write-Host "Review tables-top.csv before using it: also consider tables with slow forms and tables the business reports as slow."
