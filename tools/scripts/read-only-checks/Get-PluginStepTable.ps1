<#
.SYNOPSIS
  READ-ONLY table of plugin steps registered on Quote Product (quotedetail) and Order Product (salesorderdetail).
  Reads only the platform's registration tables. Sends only GET requests. No record data is read.
  Does not trigger any custom plugin.
.EXAMPLE
  pwsh -File .\Get-PluginStepTable.ps1 -EnvUrl https://deepakcrmprod.crm8.dynamics.com -Name PROD -DelayMs 1000
#>
param(
  [Parameter(Mandatory)][string]$EnvUrl,
  [Parameter(Mandatory)][string]$Name,
  [string[]]$Tables = @('quotedetail', 'salesorderdetail'),
  [int]$DelayMs = 500,
  [int]$MaxMinutes = 5,
  [string]$StopFile = '.\STOP-PLUGIN-TABLE.txt',
  [string]$OutDir = '.\plugin-steps'
)
$ErrorActionPreference = 'Stop'
$EnvUrl = $EnvUrl.TrimEnd('/'); $api = "$EnvUrl/api/data/v9.2"
$started = Get-Date; $script:n = 0
$tok = (az account get-access-token --resource $EnvUrl --query accessToken -o tsv 2>$null)
if (-not $tok) { throw "No token for $EnvUrl. Sign in with az login first." }
$h = @{ Authorization = "Bearer $tok"; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Accept = 'application/json'; Prefer = 'odata.maxpagesize=5000' }
function Get-Dv([string]$u) {
  if (Test-Path $StopFile) { throw "Stopped: $StopFile found." }
  if (((Get-Date) - $started).TotalMinutes -gt $MaxMinutes) { throw "Stopped: time limit of $MaxMinutes minutes." }
  for ($t = 1; $t -le 5; $t++) {
    try { $script:n++; $r = Invoke-RestMethod -Method Get -Uri $u -Headers $h; Start-Sleep -Milliseconds $DelayMs; return $r }
    catch {
      $c = 0; try { $c = [int]$_.Exception.Response.StatusCode } catch {}
      if ($c -eq 401 -or $c -eq 403) { throw "HTTP $c on $EnvUrl. No access with this account." }
      if ($c -eq 429 -and $t -lt 5) { $w = 30; try { $w = [int]$_.Exception.Response.Headers.GetValues('Retry-After')[0] } catch {}; Write-Host "  (service protection, waiting $w s)"; Start-Sleep -Seconds $w; continue }
      throw
    }
  }
}
$null = Get-Dv "$api/WhoAmI"
Write-Host "[$Name] signed in OK"
$codeToName = @{}
foreach ($t in $Tables) { $c = (Get-Dv "$api/EntityDefinitions(LogicalName='$t')?`$select=ObjectTypeCode").ObjectTypeCode; $codeToName[[string]$c] = $t }
$vals = ($codeToName.Keys | ForEach-Object { "<value>$_</value>" }) -join ''
$fx = "<fetch><entity name='sdkmessageprocessingstep'>" +
  "<attribute name='sdkmessageprocessingstepid'/><attribute name='name'/><attribute name='stage'/><attribute name='mode'/><attribute name='rank'/><attribute name='filteringattributes'/><attribute name='statecode'/><attribute name='impersonatinguserid'/>" +
  "<link-entity name='sdkmessagefilter' from='sdkmessagefilterid' to='sdkmessagefilterid' alias='f'><attribute name='primaryobjecttypecode'/><filter><condition attribute='primaryobjecttypecode' operator='in'>$vals</condition></filter></link-entity>" +
  "<link-entity name='sdkmessage' from='sdkmessageid' to='sdkmessageid' alias='m'><attribute name='name'/></link-entity>" +
  "<link-entity name='plugintype' from='plugintypeid' to='plugintypeid' alias='p'><attribute name='typename'/><attribute name='assemblyname'/></link-entity>" +
  "</entity></fetch>"
$steps = @(); $u = "$api/sdkmessageprocessingsteps?fetchXml=" + [uri]::EscapeDataString($fx)
while ($u) { $r = Get-Dv $u; $steps += $r.value; $u = $r.'@odata.nextLink' }
Write-Host "[$Name] steps on the two tables (all, including Microsoft's own): $($steps.Count)"
$stageName = @{ 10 = 'PreValidation'; 20 = 'PreOperation'; 40 = 'PostOperation'; 30 = 'MainOperation' }
$rows = foreach ($s in $steps) {
  $asm = $s.'p.assemblyname'
  $isMs = ($asm -match '^(Microsoft|Mscrm|msdyn|ActivityFeeds|ActivityAnalysis|Adx|Dynamics)') -or ($s.'p.typename' -match '^Microsoft\.')
  [pscustomobject]@{
    Environment = $Name; Table = $codeToName[[string]$s.'f.primaryobjecttypecode']; Message = $s.'m.name'
    Stage = $stageName[[int]$s.stage]; Mode = $(if ([int]$s.mode -eq 1) { 'Async' } else { 'Sync' })
    Rank = $s.rank; State = $(if ([int]$s.statecode -eq 0) { 'Enabled' } else { 'Disabled' })
    FilteringAttributes = $s.filteringattributes; FilterCount = $(if ($s.filteringattributes) { ($s.filteringattributes -split ',').Count } else { 0 })
    RunsOnEveryUpdate = $(if ($s.'m.name' -eq 'Update' -and -not $s.filteringattributes) { 'YES (empty filter)' } else { '' })
    Class = $s.'p.typename'; Assembly = $asm; IsMicrosoft = $isMs
    RunAs = $(if ($s._impersonatinguserid_value) { 'Named user' } else { 'Calling user' })
    StepName = $s.name; StepId = $s.sdkmessageprocessingstepid; Images = ''
  }
}
# images only for non-Microsoft steps
foreach ($r in ($rows | Where-Object { -not $_.IsMicrosoft })) {
  $im = (Get-Dv "$api/sdkmessageprocessingstepimages?`$select=name,imagetype,attributes,entityalias&`$filter=_sdkmessageprocessingstepid_value eq $($r.StepId)").value
  $r.Images = ($im | ForEach-Object { $t = @{ 0 = 'Pre'; 1 = 'Post'; 2 = 'Both' }[[int]$_.imagetype]; "$t image '$($_.name)': $(if ($_.attributes) { $_.attributes } else { 'all columns' })" }) -join ' | '
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$rows | Export-Csv "$OutDir\plugin-steps-$Name.csv" -NoTypeInformation
$mine = $rows | Where-Object { -not $_.IsMicrosoft }
Write-Host "[$Name] custom (non-Microsoft) steps: $($mine.Count) | Microsoft's own: $(@($rows | Where-Object IsMicrosoft).Count)"
$mine | Group-Object Table, Message, Stage, Mode | Sort-Object Name | ForEach-Object { Write-Host ("   {0}: {1}" -f $_.Name, $_.Count) }
Write-Host ("[$Name] custom steps that run on EVERY update (empty filter): {0}" -f @($mine | Where-Object RunsOnEveryUpdate).Count)
Write-Host ("[$Name] done: {0} read requests in {1} min. Nothing was changed." -f $script:n, [math]::Round(((Get-Date) - $started).TotalMinutes, 1))
