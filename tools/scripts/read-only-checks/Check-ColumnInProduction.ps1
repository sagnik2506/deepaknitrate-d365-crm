<#
.SYNOPSIS
  READ-ONLY check of one column in one environment. Intended for production.
  Runs exactly three checks and nothing else:
    1. Solution, dependency and usage checks for one column
    2. Count of rows that hold a value in that column (count only, no row data)
    3. Solution list and component counts (ENT_SchemaBaseSolution family and DNL_Base_* family)

  SAFETY
    - Only HTTP GET requests are sent. Nothing is created, changed or deleted.
    - No record data is read: the row check returns a number only.
    - A pause (DelayMs) is added after every request. 429 (service protection) is retried with the wait the server asks for.
    - 401/403 stops the run at once with a clear message.
    - Create a file named STOP-COLUMN-CHECK.txt in the working folder to stop the run after the current request.
    - Hard time limit: MaxMinutes (default 10).

.EXAMPLE
  pwsh -File .\Check-ColumnInProduction.ps1 -EnvUrl https://<production>.crm8.dynamics.com -UseAzCli -Column dg_testfob -Table quotedetail
#>
param(
  [Parameter(Mandatory)][string]$EnvUrl,
  [string]$Column = 'dg_testfob',
  [string]$Table = 'quotedetail',
  [string[]]$SolutionPrefixes = @('ENT_SchemaBaseSolution', 'DNL_Base'),
  [switch]$UseAzCli,
  [int]$DelayMs = 300,
  [int]$MaxMinutes = 10,
  [string]$StopFile = '.\STOP-COLUMN-CHECK.txt',
  [string]$OutDir = '.\column-check-results'
)
$ErrorActionPreference = 'Stop'
$EnvUrl = $EnvUrl.TrimEnd('/')
$api = "$EnvUrl/api/data/v9.2"
$started = Get-Date
$script:requests = 0
$report = New-Object System.Collections.Generic.List[string]
function Say([string]$t) { Write-Host $t; $report.Add($t) }

if (-not $UseAzCli) { throw 'Use -UseAzCli (sign in first with: az login --allow-no-subscriptions --tenant <tenant id>).' }
$tok = (az account get-access-token --resource $EnvUrl --query accessToken -o tsv 2>$null)
if (-not $tok) { throw "No token for $EnvUrl. Run az login with an account that has access, then retry." }
$hdr = @{ Authorization = "Bearer $tok"; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Accept = 'application/json'; Prefer = 'odata.maxpagesize=5000' }

function Assert-KeepGoing {
  if (Test-Path $StopFile) { throw "Stopped: $StopFile found." }
  if (((Get-Date) - $started).TotalMinutes -gt $MaxMinutes) { throw "Stopped: time limit of $MaxMinutes minutes reached." }
}
function Get-Dv([string]$url) {
  Assert-KeepGoing
  for ($try = 1; $try -le 5; $try++) {
    try {
      $script:requests++
      $r = Invoke-RestMethod -Method Get -Uri $url -Headers $hdr
      Start-Sleep -Milliseconds $DelayMs
      return $r
    } catch {
      $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
      if ($code -eq 401 -or $code -eq 403) { throw "HTTP $code. This account has no access to $EnvUrl (or the wrong tenant). Stopping." }
      if ($code -eq 429 -and $try -lt 5) { $wait = 30; try { $wait = [int]$_.Exception.Response.Headers.GetValues('Retry-After')[0] } catch {}; Say "  (service protection, waiting $wait s)"; Start-Sleep -Seconds $wait; continue }
      throw
    }
  }
}
function Get-All([string]$url) { $o = @(); while ($url) { $r = Get-Dv $url; $o += $r.value; $url = $r.'@odata.nextLink' }; $o }
function Try-Do([string]$label, [scriptblock]$sb) { try { & $sb } catch { Say "  $label : check failed ($($_.Exception.Message))" } }

New-Item -ItemType Directory -Force $OutDir | Out-Null
Say "Read-only check of '$Column' on '$Table'"
Say "Environment: $EnvUrl    Started: $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
$who = Get-Dv "$api/WhoAmI"; Say "Signed in OK (WhoAmI worked). Org id: $($who.OrganizationId)"

# =========================================================== 1. Column, solutions, dependencies, usage
Say ''; Say '=== 1. COLUMN, SOLUTIONS, DEPENDENCIES AND USAGE ==='
$a = $null
try { $a = Get-Dv "$api/EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$Column')?`$select=MetadataId,LogicalName,SchemaName,AttributeType,IsManaged,IsCustomizable,SourceType,RequiredLevel,CreatedOn" } catch { Say "Column '$Column' NOT found on '$Table' in this environment ($($_.Exception.Message))" }
if ($a) {
  $src = @{ 0 = 'simple'; 1 = 'calculated'; 2 = 'rollup' }[[int]$a.SourceType]
  Say "Column: type $($a.AttributeType) | source $src | managed=$($a.IsManaged) | required=$($a.RequiredLevel.Value) | created $($a.CreatedOn)"
  $mid = $a.MetadataId
  Say 'Solutions that contain the column:'
  Try-Do 'solutions' {
    $sc = Get-All "$api/solutioncomponents?`$select=_solutionid_value&`$filter=objectid eq $mid"
    if (-not $sc) { Say '   (none listed)' }
    foreach ($c in $sc) { $s = Get-Dv "$api/solutions($($c._solutionid_value))?`$select=uniquename,version,ismanaged"; Say ("   {0}  v{1}  managed={2}" -f $s.uniquename, $s.version, $s.ismanaged) }
  }
  Try-Do 'dependencies' {
    $d = Get-Dv "$api/RetrieveDependenciesForDelete(ObjectId=$mid,ComponentType=2)"
    Say "Platform dependencies that would block a delete: $($d.value.Count)"
    $d.value | ForEach-Object { Say "   dependent component type $($_.dependentcomponenttype), id $($_.dependentcomponentobjectid)" }
  }
  Try-Do 'layers' {
    $L = Get-All "$api/msdyn_componentlayers?`$select=msdyn_solutionname,msdyn_order&`$filter=msdyn_componentid eq '$mid' and msdyn_solutioncomponentname eq 'Attribute'"
    Say ("Layers on the column (1 = bottom): " + (($L | Sort-Object msdyn_order | ForEach-Object { "$($_.msdyn_order)=$($_.msdyn_solutionname)" }) -join ' | '))
  }
  Say 'Usage (number of components that mention the column):'
  $checks = @(
    @('Forms on this table',        "systemforms?`$select=name&`$filter=objecttypecode eq '$Table' and contains(formxml,'$Column')"),
    @('System views',               "savedqueries?`$select=name&`$filter=contains(fetchxml,'$Column') or contains(layoutxml,'$Column')"),
    @('Personal views',             "userqueries?`$select=name&`$filter=contains(fetchxml,'$Column') or contains(layoutxml,'$Column')"),
    @('Plugin step filters',        "sdkmessageprocessingsteps?`$select=name&`$filter=contains(filteringattributes,'$Column')"),
    @('Flows / workflows / rules',  "workflows?`$select=name&`$filter=contains(clientdata,'$Column') or contains(xaml,'$Column')"),
    @('Charts',                     "savedqueryvisualizations?`$select=name&`$filter=contains(datadescription,'$Column') or contains(presentationdescription,'$Column')"),
    @('Field mappings',             "attributemaps?`$select=attributemapid&`$filter=sourceattributename eq '$Column' or targetattributename eq '$Column'"))
  foreach ($ch in $checks) {
    Try-Do $ch[0] { $r = Get-All "$api/$($ch[1])"; Say ("   {0}: {1}" -f $ch[0], $r.Count); $r | Select-Object -First 5 | ForEach-Object { if ($_.name) { Say "        $($_.name)" } } }
  }
  Say '   (Script web resources are not scanned here: it reads thousands of files. Do that in dev.)'
}

# =========================================================== 2. Count of rows with a value
Say ''; Say '=== 2. ROWS THAT HOLD A VALUE (count only) ==='
$entSet = (Get-Dv "$api/EntityDefinitions(LogicalName='$Table')?`$select=EntitySetName").EntitySetName
$fx = "<fetch aggregate='true'><entity name='$Table'><attribute name='${Table}id' aggregate='count' alias='n'/><filter><condition attribute='$Column' operator='not-null'/></filter></entity></fetch>"
$counted = $false
try {
  $r = Get-Dv ("$api/$entSet" + "?fetchXml=" + [uri]::EscapeDataString($fx))
  Say "Rows with a value in '$Column': $($r.value[0].n)"; $counted = $true
} catch { Say "  (aggregate count not available: $($_.Exception.Message))" }
if (-not $counted) {
  Try-Do 'count' {
    $r = Get-Dv "$api/$entSet`?`$select=${Table}id&`$filter=$Column ne null&`$count=true&`$top=1"
    $n = $r.'@odata.count'; if ($n -ge 5000) { $n = '5000 or more (the API caps its count at 5000)' }
    Say "Rows with a value in '$Column': $n"
  }
}
Try-Do 'total' {
  $t = Get-Dv "$api/RetrieveTotalRecordCount(EntityNames=['$Table'])"
  Say ("Approximate total rows in '$Table' (platform statistics): " + $t.EntityRecordCountCollection.Values[0])
}

# =========================================================== 3. Solution list and component counts
Say ''; Say '=== 3. SOLUTIONS AND COMPONENT COUNTS ==='
$types = @{ 1 = 'Table'; 2 = 'Column'; 9 = 'OptionSet'; 10 = 'Relationship'; 20 = 'Role'; 26 = 'View'; 29 = 'Workflow/Flow'; 59 = 'Chart'; 60 = 'Form'; 61 = 'WebResource'; 62 = 'SiteMap'; 80 = 'ModelApp'; 91 = 'PluginAssembly'; 92 = 'PluginStep'; 300 = 'CanvasApp' }
$flt = ($SolutionPrefixes | ForEach-Object { "startswith(uniquename,'$_')" }) -join ' or '
$sols = Get-All "$api/solutions?`$select=solutionid,uniquename,friendlyname,version,ismanaged,installedon,modifiedon,_parentsolutionid_value&`$filter=$flt"
Say "Solutions found: $($sols.Count)"
$tblIds = @{}
foreach ($t in 'quotedetail', 'salesorderdetail') { try { $tblIds[(Get-Dv "$api/EntityDefinitions(LogicalName='$t')?`$select=MetadataId").MetadataId] = $t } catch {} }
$rows = foreach ($s in ($sols | Sort-Object uniquename, { [version]$_.version })) {
  $c = Get-All "$api/solutioncomponents?`$select=componenttype,objectid,rootcomponentbehavior&`$filter=_solutionid_value eq $($s.solutionid)"
  $g = ($c | Group-Object componenttype | ForEach-Object { "$($types[[int]$_.Name] ?? $_.Name)=$($_.Count)" }) -join ', '
  $has = ($c | Where-Object { $_.componenttype -eq 1 -and $tblIds.ContainsKey($_.objectid) } | ForEach-Object { "$($tblIds[$_.objectid]) (behavior $($_.rootcomponentbehavior))" }) -join '; '
  Say ("{0} | v{1} | managed={2} | patch={3} | installed {4}" -f $s.uniquename, $s.version, $s.ismanaged, [bool]$s._parentsolutionid_value, $s.installedon)
  Say ("      {0} components: {1}" -f $c.Count, $g)
  if ($has) { Say "      holds table(s): $has   [behavior 0 = all columns, forms and views are carried]" }
  [pscustomobject]@{ Solution = $s.uniquename; Version = $s.version; Managed = $s.ismanaged; IsPatch = [bool]$s._parentsolutionid_value; Installed = $s.installedon; Components = $c.Count; Breakdown = $g; HoldsTables = $has }
}
$rows | Export-Csv "$OutDir\solutions.csv" -NoTypeInformation

# =========================================================== end
$mins = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
Say ''; Say "Done. $($script:requests) read requests in $mins minutes. Nothing was changed."
$report | Out-File "$OutDir\column-check-report.txt" -Encoding utf8
Write-Host "Results saved in $OutDir (column-check-report.txt, solutions.csv)"
