<#
.SYNOPSIS
  Read-only data checks for the "currency gate" before converting money fields to decimal. Only GET requests are made.

  Check 1  Which currencies do the records use, and which exchange rates do they carry? (whole table, via FetchXML counts)
  Check 2  Is the platform conversion actually doing anything? For a sample of records, compares each money field with its
           base-currency twin: equal (no conversion), equal to amount / rate, equal to amount * rate, or something else.
  Also     Lists the organisation's base currency and the currencies defined.

  Check 3 (who reads the _base columns) cannot be answered from data: see currency-gate-questionnaire.md.

.PARAMETER EnvUrl
  e.g. https://yourorg.crm8.dynamics.com. Use a sandbox copy of production for production-like data.

.PARAMETER UseAzCli
  Reuse the Azure CLI session (sign in yourself first: az login --allow-no-subscriptions).
  Alternatives: -TenantId/-ClientId/-ClientSecret or -Token.

.PARAMETER SampleSize
  Records sampled per table for check 2 (default 500, ordered by the table's primary key so every chunk sees the same records).

.EXAMPLE
  .\Get-CurrencyGateCheck.ps1 -EnvUrl https://yourorg.crm8.dynamics.com -UseAzCli -Table quotedetail,salesorderdetail

Notes: the count in check 1 uses a FetchXML aggregate, which the platform limits to 50,000 records; if it fails the script says so
and uses the sample instead. For very large tables use the SQL in currency-gate-checks.sql through the TDS endpoint, off-hours.
A sample is not proof: if the sample shows only one currency, confirm with the full count.
#>
param(
    [Parameter(Mandatory)] [string] $EnvUrl,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $Token,
    [switch] $UseAzCli,
    [string[]] $Table = @('quotedetail', 'salesorderdetail'),
    [int] $SampleSize = 500,
    [string] $OutDir = '.\currency-gate'
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
$script:headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json'; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Prefer = 'odata.maxpagesize=5000' }

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

# ---------------- organisation and currencies ----------------
Write-Host "Reading currencies..."
$curName = @{}
$curRows = @((Invoke-Get "$api/transactioncurrencies?`$select=transactioncurrencyid,isocurrencycode,currencyname,exchangerate,statecode").value)
foreach ($c in $curRows) { $curName[[string]$c.transactioncurrencyid] = "$($c.isocurrencycode)" }
$baseId = ''; try { $baseId = [string](Invoke-Get "$api/organizations?`$select=_basecurrencyid_value").value[0]._basecurrencyid_value } catch { }
$baseCode = if ($baseId -and $curName.ContainsKey($baseId)) { $curName[$baseId] } else { 'unknown' }
Write-Host "Base currency: $baseCode. Currencies defined: $($curRows.Count)"
$curRows | ForEach-Object { [pscustomobject]@{ Code = $_.isocurrencycode; Name = $_.currencyname; ExchangeRateToBase = $_.exchangerate; Active = ($_.statecode -eq 0); IsBase = ([string]$_.transactioncurrencyid -eq $baseId) } } |
    Export-Csv "$OutDir\currencies-defined.csv" -NoTypeInformation -Encoding UTF8

$summary = New-Object System.Collections.Generic.List[object]
$fieldRows = New-Object System.Collections.Generic.List[object]

foreach ($t in $Table) {
    Write-Host "== $t"
    $ent = Invoke-Get "$api/EntityDefinitions(LogicalName='$t')?`$select=EntitySetName,PrimaryIdAttribute"
    $set = $ent.EntitySetName; $pk = $ent.PrimaryIdAttribute

    # ---- check 1: currencies and exchange rates across all records ----
    $total = ''; $byCur = @(); $byRate = @(); $fullOk = $true
    try {
        $fx1 = [uri]::EscapeDataString("<fetch aggregate='true'><entity name='$t'><attribute name='$pk' alias='n' aggregate='count'/><attribute name='transactioncurrencyid' alias='cur' groupby='true'/></entity></fetch>")
        $byCur = @((Invoke-Get "$api/$set`?fetchXml=$fx1").value)
        $fx2 = [uri]::EscapeDataString("<fetch aggregate='true'><entity name='$t'><attribute name='$pk' alias='n' aggregate='count'/><attribute name='exchangerate' alias='rate' groupby='true'/></entity></fetch>")
        $byRate = @((Invoke-Get "$api/$set`?fetchXml=$fx2").value)
        $total = ($byCur | Measure-Object -Property n -Sum).Sum
    } catch { $fullOk = $false; Write-Warning "Full counts failed for $t (the aggregate limit is 50,000 records): $($_.Exception.Message). Using the sample only." }
    if ($fullOk) {
        Write-Host "   records: $total"
        foreach ($r in $byCur) { $cid = [string]$r.cur; $code = if ($cid -and $curName.ContainsKey($cid)) { $curName[$cid] } elseif ($cid) { $cid } else { '(no currency)' }
            Write-Host "   currency $code : $($r.n)"
            $summary.Add([pscustomobject][ordered]@{ Table = $t; Check = 'Records by currency'; Value = $code; Records = $r.n }) }
        foreach ($r in $byRate) { Write-Host "   exchange rate $($r.rate) : $($r.n)"
            $summary.Add([pscustomobject][ordered]@{ Table = $t; Check = 'Records by exchange rate'; Value = [string]$r.rate; Records = $r.n }) }
    }

    # ---- money fields and twins ----
    $attrs = @((Invoke-Get "$api/EntityDefinitions(LogicalName='$t')/Attributes?`$select=LogicalName,AttributeType,IsCustomAttribute").value | Where-Object { $_.IsCustomAttribute })
    $byName = @{}; foreach ($a in $attrs) { $byName[$a.LogicalName] = $a }
    $money = @($attrs | Where-Object { $_.AttributeType -eq 'Money' -and -not ($_.LogicalName.EndsWith('_base') -and $byName.ContainsKey($_.LogicalName.Substring(0, $_.LogicalName.Length - 5))) } | Where-Object { $byName.ContainsKey("$($_.LogicalName)_base") })
    Write-Host "   $($money.Count) money fields with a twin; sampling $SampleSize records..."

    # ---- check 2: sample records, compare field with twin ----
    $stats = @{}; foreach ($m in $money) { $stats[$m.LogicalName] = @{ Tested = 0; Equal = 0; Div = 0; Mul = 0; Other = 0 } }
    $chunkSize = 20
    for ($i = 0; $i -lt $money.Count; $i += $chunkSize) {
        $chunk = @($money[$i..([math]::Min($i + $chunkSize - 1, $money.Count - 1))])
        $cols = @($pk, 'exchangerate', '_transactioncurrencyid_value') + @($chunk | ForEach-Object { $_.LogicalName; "$($_.LogicalName)_base" })
        $rows = @((Invoke-Get "$api/$set`?`$select=$($cols -join ',')&`$orderby=$pk&`$top=$SampleSize").value)
        foreach ($row in $rows) {
            $rate = [double]$row.exchangerate
            foreach ($m in $chunk) {
                $v = $row.($m.LogicalName); $bv = $row.("$($m.LogicalName)_base")
                if ($null -eq $v -or $null -eq $bv -or [double]$v -eq 0) { continue }
                $amt = [double]$v; $base = [double]$bv; $tol = 0.01 + 0.00001 * [math]::Abs($amt)
                $s = $stats[$m.LogicalName]; $s.Tested++
                if ([math]::Abs($base - $amt) -le $tol)                              { $s.Equal++ }
                elseif ($rate -ne 0 -and [math]::Abs($base - $amt / $rate) -le $tol) { $s.Div++ }
                elseif ([math]::Abs($base - $amt * $rate) -le $tol)                  { $s.Mul++ }
                else                                                                 { $s.Other++ }
            }
        }
    }
    foreach ($m in $money) {
        $s = $stats[$m.LogicalName]
        $verdict = if ($s.Tested -eq 0) { 'No sample data' } elseif ($s.Equal -eq $s.Tested) { 'No conversion in sample (base equals amount)' } elseif ($s.Other -gt 0) { 'Base differs in an unexplained way' } else { 'Platform conversion active in sample' }
        $fieldRows.Add([pscustomobject][ordered]@{ Table = $t; LogicalName = $m.LogicalName; SampleRecordsWithValue = $s.Tested; BaseEqualsAmount = $s.Equal
            BaseEqualsAmountDividedByRate = $s.Div; BaseEqualsAmountTimesRate = $s.Mul; BaseOther = $s.Other; Verdict = $verdict })
    }
    $tested = @($fieldRows | Where-Object { $_.Table -eq $t -and $_.SampleRecordsWithValue -gt 0 })
    $none   = @($tested | Where-Object { $_.Verdict -like 'No conversion*' }).Count
    $active = @($tested | Where-Object { $_.Verdict -like 'Platform conversion*' }).Count
    $odd    = @($tested | Where-Object { $_.Verdict -like 'Base differs*' }).Count
    Write-Host "   fields with sample data: $($tested.Count); no conversion: $none; conversion active: $active; unexplained: $odd"
    $summary.Add([pscustomobject][ordered]@{ Table = $t; Check = 'Sample: fields with no conversion'; Value = "$none of $($tested.Count)"; Records = '' })
    $summary.Add([pscustomobject][ordered]@{ Table = $t; Check = 'Sample: fields with platform conversion active'; Value = "$active of $($tested.Count)"; Records = '' })
    $summary.Add([pscustomobject][ordered]@{ Table = $t; Check = 'Sample: fields with unexplained difference'; Value = "$odd of $($tested.Count)"; Records = '' })
}
$summary | Export-Csv "$OutDir\currency-gate-summary.csv" -NoTypeInformation -Encoding UTF8
$fieldRows | Export-Csv "$OutDir\currency-gate-fields.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`nWrote $OutDir\currency-gate-summary.csv, currency-gate-fields.csv and currencies-defined.csv."
Write-Host "How to read it: one currency, rate 1 and 'no conversion' on every field means platform conversion is not doing anything (gate check 1 and 2 pass)."
Write-Host "Several currencies with 'conversion active' means the platform converts; then check 3 (who reads the _base columns) decides."
Write-Host "A sample is not proof. Confirm with the full counts, and answer check 3 with currency-gate-questionnaire.md."
