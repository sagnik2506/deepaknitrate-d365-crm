<#
.SYNOPSIS
  L1: names of the customer components in one environment, by type. READ-ONLY (GET only; no business records; configuration content fingerprinted only).
.DESCRIPTION
  Uses membership.csv (from Get-SolutionMembership.ps1) to know which components belong to customer solutions, then reads the
  NAMES of those components (lists only, no content). Tables and columns are matched by name later because their internal ids
  differ between environments. Writes one CSV per type into -OutDir.
.EXAMPLE
  .\Get-EnvComponentInventory.ps1 -EnvUrl https://<env>.crm8.dynamics.com -Name UAT -MembershipCsv <dir>\membership.csv -OutDir <dir> -DelayMs 200
#>
param(
  [Parameter(Mandatory)][string]$EnvUrl, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$MembershipCsv,
  [string]$OutDir = '.\parity-out', [int]$DelayMs = 1000, [int]$MaxMinutes = 60, [string]$StopFile = '.\STOP-PARITY.txt', [int]$MaxTables = 0, [string]$CustomerPrefixRegex = '^(dg_|cr_)'
)
. "$PSScriptRoot\ParityCommon.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
Initialize-Parity -EnvUrl $EnvUrl -Name $Name -DelayMs $DelayMs -MaxMinutes $MaxMinutes -StopFile $StopFile
$mem = Import-Csv $MembershipCsv
$ids = @{}   # type -> hashtable of object id -> number of solutions
foreach ($m in $mem) { $k = [string]$m.TypeCode; if (-not $ids.ContainsKey($k)) { $ids[$k] = @{} }; $ids[$k][$m.ObjectId.ToLower()] = 1 + [int]$ids[$k][$m.ObjectId.ToLower()] }
function Has([string]$type, [string]$id) { return ($ids.ContainsKey($type) -and $ids[$type].ContainsKey($id.ToLower())) }
$counts = [ordered]@{}

# ---- tables
$ents = Get-DvAll "EntityDefinitions?`$select=MetadataId,LogicalName,SchemaName,IsCustomEntity,ObjectTypeCode"
$tables = @($ents | Where-Object { (Has '1' $_.MetadataId) -or ($_.LogicalName -match $CustomerPrefixRegex) })
$tables | ForEach-Object { [pscustomobject]@{ Id = $_.MetadataId; Name = $_.LogicalName; IsCustom = $_.IsCustomEntity; Solutions = $(if ($ids.ContainsKey('1')) { [int]$ids['1'][$_.MetadataId.ToLower()] } else { 0 }) } } | Export-Csv "$OutDir\Table.csv" -NoTypeInformation
$counts['Table'] = $tables.Count
Write-Host "[$Name] tables kept: $($tables.Count) of $($ents.Count)"

# ---- columns (custom columns on those tables)
$colFile = "$OutDir\Column.csv"; Remove-Item $colFile -ErrorAction SilentlyContinue
$n = 0; $colCount = 0
foreach ($t in $tables) {
  $n++; if ($MaxTables -gt 0 -and $n -gt $MaxTables) { break }
  $a = Get-DvAll "EntityDefinitions(LogicalName='$($t.LogicalName)')/Attributes?`$select=MetadataId,LogicalName,AttributeType,IsCustomAttribute,AttributeOf,SourceType"
  $custom = @($a | Where-Object { $_.IsCustomAttribute -and $_.LogicalName -match $CustomerPrefixRegex })
  if ($custom) { $custom | ForEach-Object { [pscustomobject]@{ Id = $_.MetadataId; Name = "$($t.LogicalName).$($_.LogicalName)"; Table = $t.LogicalName; Column = $_.LogicalName; Type = $_.AttributeType; SourceType = $_.SourceType; AttributeOf = $_.AttributeOf } } | Export-Csv $colFile -NoTypeInformation -Append; $colCount += $custom.Count }
  if ($n % 25 -eq 0) { Write-Host "  [$Name] columns: $n of $($tables.Count) tables read" }
}
$counts['Column'] = $colCount

# ---- forms
$f = Get-DvAll "systemforms?`$select=formid,name,objecttypecode,type,formactivationstate"
$k = @($f | Where-Object { Has '60' $_.formid }); $counts['Form'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.formid; Name = $_.name; Table = $_.objecttypecode; FormType = $_.type; State = $_.formactivationstate; Solutions = $ids['60'][$_.formid.ToLower()] } } | Export-Csv "$OutDir\Form.csv" -NoTypeInformation
# ---- views
$v = Get-DvAll "savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype,statecode"
$k = @($v | Where-Object { Has '26' $_.savedqueryid }); $counts['View'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.savedqueryid; Name = $_.name; Table = $_.returnedtypecode; QueryType = $_.querytype; State = $_.statecode; Solutions = $ids['26'][$_.savedqueryid.ToLower()] } } | Export-Csv "$OutDir\View.csv" -NoTypeInformation
# ---- web resources
$w = Get-DvAll "webresourceset?`$select=webresourceid,name,webresourcetype"
$k = @($w | Where-Object { Has '61' $_.webresourceid }); $counts['WebResource'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.webresourceid; Name = $_.name; WebType = $_.webresourcetype; Solutions = $ids['61'][$_.webresourceid.ToLower()] } } | Export-Csv "$OutDir\WebResource.csv" -NoTypeInformation
# ---- plugin assemblies and steps
$pa = Get-DvAll "pluginassemblies?`$select=pluginassemblyid,name,version,isolationmode"
$k = @($pa | Where-Object { Has '91' $_.pluginassemblyid }); $counts['PluginAssembly'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.pluginassemblyid; Name = $_.name; Version = $_.version; Isolation = $_.isolationmode; Solutions = $ids['91'][$_.pluginassemblyid.ToLower()] } } | Export-Csv "$OutDir\PluginAssembly.csv" -NoTypeInformation
$s = Get-DvAll "sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid,name,stage,mode,statecode,filteringattributes"
$k = @($s | Where-Object { Has '92' $_.sdkmessageprocessingstepid }); $counts['PluginStep'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.sdkmessageprocessingstepid; Name = $_.name; Stage = $_.stage; Mode = $_.mode; State = $_.statecode; FilterCount = $(if ($_.filteringattributes) { ($_.filteringattributes -split ',').Count } else { 0 }) } } | Export-Csv "$OutDir\PluginStep.csv" -NoTypeInformation
# ---- workflows, flows and business rules
$wf = Get-DvAll "workflows?`$select=workflowid,name,category,statecode,primaryentity,type"
$k = @($wf | Where-Object { Has '29' $_.workflowid }); $counts['Workflow'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.workflowid; Name = $_.name; Category = $_.category; State = $_.statecode; Table = $_.primaryentity; Solutions = $ids['29'][$_.workflowid.ToLower()] } } | Export-Csv "$OutDir\Workflow.csv" -NoTypeInformation
# ---- roles (names; one row per role copy, compare by name)
$r = Get-DvAll "roles?`$select=roleid,name,_parentrootroleid_value,ismanaged"
$k = @($r | Where-Object { Has '20' $_.roleid }); $counts['Role'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.roleid; Name = $_.name; Managed = $_.ismanaged } } | Export-Csv "$OutDir\Role.csv" -NoTypeInformation
# ---- global option sets
$o = (Get-Dv "GlobalOptionSetDefinitions?`$select=Name,MetadataId").value
$k = @($o | Where-Object { Has '9' $_.MetadataId }); $counts['OptionSet'] = $k.Count
$k | ForEach-Object { [pscustomobject]@{ Id = $_.MetadataId; Name = $_.Name } } | Export-Csv "$OutDir\OptionSet.csv" -NoTypeInformation
# ---- model-driven apps
try { $am = Get-DvAll "appmodules?`$select=appmoduleid,uniquename,name"; $k = @($am | Where-Object { Has '80' $_.appmoduleid }); $counts['ModelApp'] = $k.Count
  $k | ForEach-Object { [pscustomobject]@{ Id = $_.appmoduleid; Name = $_.uniquename; Display = $_.name } } | Export-Csv "$OutDir\ModelApp.csv" -NoTypeInformation } catch { Write-Host "  [$Name] apps not read: $($_.Exception.Message)" }

$counts.GetEnumerator() | ForEach-Object { Write-Host ("   {0}: {1}" -f $_.Key, $_.Value) }
($counts | ConvertTo-Json) | Set-Content "$OutDir\inventory-summary.json" -Encoding utf8
Write-ParitySummary 'inventory done'
