# Shared helpers for the UAT-ALIGN pipelines. PowerShell 7.
# Secrets come from environment variables set by the pipeline: PP_TENANT_ID, PP_APP_ID, PP_CLIENT_SECRET (service principal). Never put them in files.
# SAFETY: every Dataverse call that is not a GET is refused unless the target environment key is listed in writableEnvironments (pipelines/config/environments.json).
Set-StrictMode -Version Latest
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$script:Tokens = @{}

function Get-PipelineConfig([string]$Name) {
    $p = Join-Path $script:RepoRoot "pipelines\config\$Name"
    if (-not (Test-Path $p)) { throw "Config file not found: $p" }
    return (Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-EnvUrl([string]$Key) {
    $cfg = Get-PipelineConfig 'environments.json'
    $u = $cfg.$Key
    if (-not $u -or $u -match '<') { throw "The URL for environment '$Key' is not set in pipelines/config/environments.json" }
    return ([string]$u).TrimEnd('/')
}

function Assert-Writable([string]$Key) {
    $cfg = Get-PipelineConfig 'environments.json'
    if ($cfg.writableEnvironments -notcontains $Key) { throw "REFUSED: '$Key' is not a writable environment. Writable: $($cfg.writableEnvironments -join ', ')" }
}

function Write-Log([string]$Message) { Write-Host ("{0}  {1}" -f (Get-Date).ToUniversalTime().ToString('HH:mm:ss'), $Message) }
function Add-AdoWarning([string]$Message) { Write-Host "##vso[task.logissue type=warning]$Message" }
function Add-AdoError([string]$Message) { Write-Host "##vso[task.logissue type=error]$Message" }

function Get-DvToken([string]$Key) {
    $now = [datetime]::UtcNow
    if ($script:Tokens.ContainsKey($Key) -and $script:Tokens[$Key].Expires -gt $now.AddMinutes(5)) { return $script:Tokens[$Key].Token }
    foreach ($v in 'PP_TENANT_ID', 'PP_APP_ID', 'PP_CLIENT_SECRET') { if (-not (Test-Path "Env:$v")) { throw "Environment variable $v is not set" } }
    $url = Get-EnvUrl $Key
    $body = @{ client_id = $env:PP_APP_ID; client_secret = $env:PP_CLIENT_SECRET; scope = "$url/.default"; grant_type = 'client_credentials' }
    $r = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($env:PP_TENANT_ID)/oauth2/v2.0/token" -Body $body -ContentType 'application/x-www-form-urlencoded'
    $script:Tokens[$Key] = @{ Token = $r.access_token; Expires = $now.AddSeconds([int]$r.expires_in) }
    return $r.access_token
}

# One Dataverse Web API call with pacing, retry on 429 and 5xx, token renewal on 401. Non-GET calls are only allowed on writable environments.
function Invoke-Dv {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Path, [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')][string]$Method = 'GET',
          $Body = $null, [int]$DelayMs = 500, [hashtable]$ExtraHeaders = @{})
    if ($Method -ne 'GET') { Assert-Writable $Key }
    $uri = if ($Path -like 'http*') { $Path } else { (Get-EnvUrl $Key) + '/api/data/v9.2/' + $Path }
    for ($i = 1; $i -le 6; $i++) {
        try {
            $h = @{ Authorization = "Bearer $(Get-DvToken $Key)"; Accept = 'application/json'; 'OData-Version' = '4.0' } + $ExtraHeaders
            $p = @{ Method = $Method; Uri = $uri; Headers = $h }
            if ($null -ne $Body) { $p.Body = ($Body | ConvertTo-Json -Depth 20 -Compress); $p.ContentType = 'application/json; charset=utf-8' }
            $r = Invoke-RestMethod @p
            Start-Sleep -Milliseconds $DelayMs
            return $r
        } catch {
            $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
            if ($code -eq 429) { $wait = 30; try { $wait = [int]$_.Exception.Response.Headers.RetryAfter.Delta.TotalSeconds } catch {}; Write-Log "429, waiting $wait s"; Start-Sleep -Seconds ([math]::Max($wait, 5)); continue }
            if ($code -eq 401) { $script:Tokens.Remove($Key) | Out-Null; continue }
            if ($code -ge 500 -and $i -lt 6) { Start-Sleep -Seconds (5 * $i); continue }
            throw
        }
    }
    throw "Gave up after 6 attempts: $Method $uri"
}

function Invoke-DvAll([string]$Key, [string]$Path, [int]$DelayMs = 500) {
    $all = New-Object System.Collections.Generic.List[object]
    $r = Invoke-Dv -Key $Key -Path $Path -DelayMs $DelayMs
    foreach ($x in $r.value) { $all.Add($x) }
    while ($r.PSObject.Properties.Name -contains '@odata.nextLink' -and $r.'@odata.nextLink') {
        $r = Invoke-Dv -Key $Key -Path $r.'@odata.nextLink' -DelayMs $DelayMs
        foreach ($x in $r.value) { $all.Add($x) }
    }
    return $all
}

# Sign the Power Platform CLI in to one environment with the service principal.
function Connect-Pac([string]$Key) {
    $url = Get-EnvUrl $Key
    foreach ($v in 'PP_TENANT_ID', 'PP_APP_ID', 'PP_CLIENT_SECRET') { if (-not (Test-Path "Env:$v")) { throw "Environment variable $v is not set" } }
    & pac auth delete --name $Key 2>&1 | Out-Null
    & pac auth create --name $Key --applicationId $env:PP_APP_ID --clientSecret $env:PP_CLIENT_SECRET --tenant $env:PP_TENANT_ID --environment $url | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "pac auth create failed for $Key" }
    & pac auth select --name $Key | Out-Null
    Write-Log "pac signed in to $Key ($url)"
}

# Version, managed flag and unique name inside a solution zip.
function Get-ZipSolutionInfo([string]$Zip) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $e = $z.Entries | Where-Object { $_.FullName -eq 'solution.xml' } | Select-Object -First 1
        if (-not $e) { throw "solution.xml not found in $Zip" }
        $sr = New-Object IO.StreamReader($e.Open()); $xml = [xml]$sr.ReadToEnd(); $sr.Dispose()
        $m = $xml.ImportExportXml.SolutionManifest
        return [pscustomobject]@{ UniqueName = [string]$m.UniqueName; Version = [string]$m.Version; Managed = [string]$m.Managed }
    } finally { $z.Dispose() }
}

function Get-FileSha256([string]$Path) { return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLower() }

# Customer solutions of an environment (not Microsoft publishers, not the default solutions).
function Get-CustomerSolutionList([string]$Key) {
    $rows = Invoke-DvAll -Key $Key -Path 'solutions?$select=uniquename,friendlyname,version,ismanaged,installedon,modifiedon,isvisible&$expand=publisherid($select=uniquename)&$filter=isvisible eq true'
    return @($rows | Where-Object { $_.uniquename -notin 'Default', 'Active', 'Basic' -and ([string]$_.publisherid.uniquename) -notmatch '^(microsoft|adxstudio|mbs$)' })
}
