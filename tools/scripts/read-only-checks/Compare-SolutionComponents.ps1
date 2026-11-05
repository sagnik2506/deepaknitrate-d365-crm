<#
.SYNOPSIS
  READ-ONLY comparison of one solution's components between two environments, plus who installed it.
  Only GET requests. No record data is read.

.EXAMPLE
  pwsh -File .\Compare-SolutionComponents.ps1 -EnvA https://deepakgroupuat.crm8.dynamics.com -NameA UAT `
       -EnvB https://deepakcrmprod.crm8.dynamics.com -NameB PROD -Solution DNL_Base_Entities -DelayMsB 1000
#>
param(
  [Parameter(Mandatory)][string]$EnvA, [string]$NameA = 'A',
  [Parameter(Mandatory)][string]$EnvB, [string]$NameB = 'B',
  [string]$Solution = 'DNL_Base_Entities',
  [int]$DelayMsA = 200, [int]$DelayMsB = 1000,
  [switch]$ResolveNames,
  [switch]$ByName,
  [int]$MaxMinutes = 10,
  [string]$StopFile = '.\STOP-COMPARE.txt',
  [string]$OutDir = '.\compare-results'
)
$ErrorActionPreference = 'Stop'
$started = Get-Date
$script:req = @{}
$types = @{ 1 = 'Table'; 2 = 'Column'; 9 = 'OptionSet'; 10 = 'Relationship'; 14 = 'EntityKey'; 20 = 'Role'; 26 = 'View'; 29 = 'Workflow/Flow'; 59 = 'Chart'; 60 = 'Form'; 61 = 'WebResource'; 62 = 'SiteMap'; 70 = 'FieldSecurityProfile'; 91 = 'PluginAssembly'; 92 = 'PluginStep' }
$report = New-Object System.Collections.Generic.List[string]
function Say([string]$t) { Write-Host $t; $report.Add($t) }

function New-Ctx([string]$url, [int]$delay, [string]$name) {
  $url = $url.TrimEnd('/')
  $tok = (az account get-access-token --resource $url --query accessToken -o tsv 2>$null)
  if (-not $tok) { throw "No token for $url. Sign in with az login first." }
  $script:req[$name] = 0
  @{ Url = $url; Api = "$url/api/data/v9.2"; Delay = $delay; Name = $name
     H = @{ Authorization = "Bearer $tok"; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Accept = 'application/json'; Prefer = 'odata.maxpagesize=5000' } }
}
function Get-Dv($ctx, [string]$path) {
  if (Test-Path $StopFile) { throw "Stopped: $StopFile found." }
  if (((Get-Date) - $started).TotalMinutes -gt $MaxMinutes) { throw "Stopped: time limit of $MaxMinutes minutes reached." }
  $url = if ($path -like 'http*') { $path } else { "$($ctx.Api)/$path" }
  for ($try = 1; $try -le 5; $try++) {
    try {
      $script:req[$ctx.Name]++
      $r = Invoke-RestMethod -Method Get -Uri $url -Headers $ctx.H
      Start-Sleep -Milliseconds $ctx.Delay
      return $r
    } catch {
      $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch {}
      if ($code -eq 401 -or $code -eq 403) { throw "HTTP $code on $($ctx.Url). No access with this account. Stopping." }
      if ($code -eq 429 -and $try -lt 5) { $w = 30; try { $w = [int]$_.Exception.Response.Headers.GetValues('Retry-After')[0] } catch {}; Say "  (service protection on $($ctx.Name), waiting $w s)"; Start-Sleep -Seconds $w; continue }
      throw
    }
  }
}
function Get-All($ctx, [string]$path) { $o = @(); $u = $path; while ($u) { $r = Get-Dv $ctx $u; $o += $r.value; $u = $r.'@odata.nextLink' }; $o }

function Read-Solution($ctx) {
  $s = (Get-Dv $ctx "solutions?`$select=solutionid,uniquename,version,ismanaged,installedon,createdon,modifiedon,_createdby_value,_modifiedby_value,_publisherid_value&`$filter=uniquename eq '$Solution'").value
  if (-not $s) { throw "Solution $Solution not found in $($ctx.Name)." }
  $s = $s[0]
  $who = { param($id) if (-not $id) { return '(unknown)' }; try { (Get-Dv $ctx "systemusers($id)?`$select=fullname,domainname") | ForEach-Object { "$($_.fullname) <$($_.domainname)>" } } catch { '(not readable)' } }
  $created = & $who $s._createdby_value
  $modified = if ($s._modifiedby_value -eq $s._createdby_value) { 'same as creator' } else { & $who $s._modifiedby_value }
  $comps = Get-All $ctx "solutioncomponents?`$select=componenttype,objectid,rootcomponentbehavior&`$filter=_solutionid_value eq $($s.solutionid)"
  @{ Sol = $s; Created = $created; Modified = $modified; Comps = $comps }
}

Say "Read-only comparison of solution '$Solution': $NameA vs $NameB"
Say "Started $($started.ToString('yyyy-MM-dd HH:mm:ss'))"
$A = New-Ctx $EnvA $DelayMsA $NameA
$B = New-Ctx $EnvB $DelayMsB $NameB
$ra = Read-Solution $A
$rb = Read-Solution $B

Say ''; Say '=== WHO INSTALLED IT ==='
foreach ($x in @(@($NameA, $ra), @($NameB, $rb))) {
  $s = $x[1].Sol
  Say ("{0}: v{1} | managed={2} | created {3} | installed {4} | modified {5}" -f $x[0], $s.version, $s.ismanaged, $s.createdon, $s.installedon, $s.modifiedon)
  Say ("      created/installed by: {0}" -f $x[1].Created)
  Say ("      last modified by:     {0}" -f $x[1].Modified)
}

Say ''; Say '=== COMPONENT COUNTS AND DIFFERENCE ==='
$ka = @{}; foreach ($c in $ra.Comps) { $ka["$($c.componenttype)|$($c.objectid)"] = $c }
$kb = @{}; foreach ($c in $rb.Comps) { $kb["$($c.componenttype)|$($c.objectid)"] = $c }
$onlyA = $ka.Keys | Where-Object { -not $kb.ContainsKey($_) }
$onlyB = $kb.Keys | Where-Object { -not $ka.ContainsKey($_) }
$both = $ka.Keys | Where-Object { $kb.ContainsKey($_) }
Say ("Total components: {0}={1}, {2}={3}; in both={4}; only in {0}={5}; only in {2}={6}" -f $NameA, $ra.Comps.Count, $NameB, $rb.Comps.Count, @($both).Count, @($onlyA).Count, @($onlyB).Count)
$typeName = { param($k) $t = [int]($k.Split('|')[0]); if ($types.ContainsKey($t)) { $types[$t] } else { "type $t" } }
$allTypes = @($ka.Keys + $kb.Keys | ForEach-Object { & $typeName $_ } | Sort-Object -Unique)
$sum = foreach ($t in $allTypes) {
  [pscustomobject]@{ Type = $t
    "In$NameA" = @($ka.Keys | Where-Object { (& $typeName $_) -eq $t }).Count
    "In$NameB" = @($kb.Keys | Where-Object { (& $typeName $_) -eq $t }).Count
    Both = @($both | Where-Object { (& $typeName $_) -eq $t }).Count
    "Only$NameA" = @($onlyA | Where-Object { (& $typeName $_) -eq $t }).Count
    "Only$NameB" = @($onlyB | Where-Object { (& $typeName $_) -eq $t }).Count }
}
$sum | Format-Table -AutoSize | Out-String -Width 200 | ForEach-Object { Say $_ }

# behaviour of the two tables in each environment
foreach ($t in 'quotedetail', 'salesorderdetail') {
  foreach ($ctx in @($A, $B)) {
    $m = (Get-Dv $ctx "EntityDefinitions(LogicalName='$t')?`$select=MetadataId").MetadataId
    $r = if ($ctx.Name -eq $NameA) { $ra } else { $rb }
    $c = $r.Comps | Where-Object { $_.componenttype -eq 1 -and $_.objectid -eq $m }
    Say ("{0}: {1} in {2} -> behavior {3} (0 = all columns carried)" -f $ctx.Name, $t, $Solution, $(if ($c) { $c.rootcomponentbehavior } else { 'not in solution' }))
  }
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$diff = @()
foreach ($k in $onlyA) { $diff += [pscustomobject]@{ Side = "Only in $NameA"; Type = (& $typeName $k); ObjectId = $k.Split('|')[1]; Name = '' } }
foreach ($k in $onlyB) { $diff += [pscustomobject]@{ Side = "Only in $NameB"; Type = (& $typeName $k); ObjectId = $k.Split('|')[1]; Name = '' } }

if ($ResolveNames) {
  Say ''; Say '=== NAMES OF DIFFERING ITEMS (tables and columns) ==='
  foreach ($pair in @(@($A, "Only in $($A.Name)"), @($B, "Only in $($B.Name)"))) {
    $ctx = $pair[0]; $side = $pair[1]
    $mine = $diff | Where-Object { $_.Side -eq $side }
    if (-not $mine) { continue }
    $ents = (Get-Dv $ctx "EntityDefinitions?`$select=MetadataId,LogicalName").value
    $emap = @{}; foreach ($e in $ents) { $emap[$e.MetadataId] = $e.LogicalName }
    foreach ($d in ($mine | Where-Object { $_.Type -eq 'Table' })) { if ($emap.ContainsKey($d.ObjectId)) { $d.Name = $emap[$d.ObjectId] } }
    $needCols = $mine | Where-Object { $_.Type -eq 'Column' }
    if ($needCols) {
      $want = @{}; foreach ($d in $needCols) { $want[$d.ObjectId] = $d }
      $solTables = $ctx.Name -eq $NameA; $comps = if ($solTables) { $ra.Comps } else { $rb.Comps }
      $tblNames = $comps | Where-Object { $_.componenttype -eq 1 } | ForEach-Object { $emap[$_.objectid] } | Where-Object { $_ }
      foreach ($tn in $tblNames) {
        if ($want.Count -eq 0) { break }
        $at = (Get-Dv $ctx "EntityDefinitions(LogicalName='$tn')/Attributes?`$select=MetadataId,LogicalName").value
        foreach ($x in $at) { if ($want.ContainsKey($x.MetadataId)) { $want[$x.MetadataId].Name = "$tn.$($x.LogicalName)"; $want.Remove($x.MetadataId) } }
      }
    }
  }
  foreach ($grp in ($diff | Where-Object { $_.Name } | Group-Object Side, Type)) {
    Say ("{0} - {1}: {2}" -f $grp.Group[0].Side, $grp.Group[0].Type, $grp.Count)
    $grp.Group | Select-Object -First 40 | ForEach-Object { Say "      $($_.Name)" }
    if ($grp.Count -gt 40) { Say "      ... (full list in the CSV)" }
  }
}
if ($ByName) {
  Say ''; Say '=== COMPARISON BY NAME (tables and columns that the solution lists) ==='
  Say '(Internal IDs differ between these environments, so tables and columns are matched by their names.)'
  $sets = @{}
  foreach ($pair in @(@($A, $ra), @($B, $rb))) {
    $ctx = $pair[0]; $r = $pair[1]
    $ents = (Get-Dv $ctx "EntityDefinitions?`$select=MetadataId,LogicalName").value
    $emap = @{}; foreach ($e in $ents) { $emap[$e.MetadataId] = $e.LogicalName }
    $tbl = @($r.Comps | Where-Object { $_.componenttype -eq 1 } | ForEach-Object { $emap[$_.objectid] } | Where-Object { $_ } | Sort-Object -Unique)
    $colIds = @{}; foreach ($c in ($r.Comps | Where-Object { $_.componenttype -eq 2 })) { $colIds[$c.objectid] = 1 }
    $cols = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($tn in $tbl) {
      $i++
      $at = (Get-Dv $ctx "EntityDefinitions(LogicalName='$tn')/Attributes?`$select=MetadataId,LogicalName").value
      foreach ($x in $at) { if ($colIds.ContainsKey($x.MetadataId)) { $cols.Add("$tn.$($x.LogicalName)") } }
      if ($i % 30 -eq 0) { Write-Host "  $($ctx.Name): $i of $($tbl.Count) tables read" }
    }
    $sets[$ctx.Name] = @{ Tables = $tbl; Cols = @($cols | Sort-Object -Unique); ColCount = $colIds.Count }
    Say ("{0}: {1} tables named; {2} listed columns resolved to names (of {3} column components)" -f $ctx.Name, $tbl.Count, $sets[$ctx.Name].Cols.Count, $colIds.Count)
  }
  $ta = $sets[$NameA].Tables; $tb = $sets[$NameB].Tables
  $tOnlyA = @($ta | Where-Object { $tb -notcontains $_ }); $tOnlyB = @($tb | Where-Object { $ta -notcontains $_ })
  Say ("Tables: in both={0}; only in {1}={2}; only in {3}={4}" -f @($ta | Where-Object { $tb -contains $_ }).Count, $NameA, $tOnlyA.Count, $NameB, $tOnlyB.Count)
  if ($tOnlyA) { Say "   only in ${NameA}: $($tOnlyA -join ', ')" }
  if ($tOnlyB) { Say "   only in ${NameB}: $($tOnlyB -join ', ')" }
  $ca = $sets[$NameA].Cols; $cb = $sets[$NameB].Cols
  $hb = @{}; foreach ($x in $cb) { $hb[$x] = 1 }; $ha = @{}; foreach ($x in $ca) { $ha[$x] = 1 }
  $cOnlyA = @($ca | Where-Object { -not $hb.ContainsKey($_) }); $cOnlyB = @($cb | Where-Object { -not $ha.ContainsKey($_) })
  Say ("Columns: in both={0}; only in {1}={2}; only in {3}={4}" -f @($ca | Where-Object { $hb.ContainsKey($_) }).Count, $NameA, $cOnlyA.Count, $NameB, $cOnlyB.Count)
  Say "Only-in-$NameA columns by table (top 15):"
  $cOnlyA | Group-Object { $_.Split('.')[0] } | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { Say ("      {0}: {1}" -f $_.Name, $_.Count) }
  Say "Only-in-$NameB columns by table (top 15):"
  $cOnlyB | Group-Object { $_.Split('.')[0] } | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { Say ("      {0}: {1}" -f $_.Name, $_.Count) }
  foreach ($t in 'quotedetail', 'salesorderdetail') {
    Say ("{0}: listed columns in {1}={2}, in {3}={4}; only in {1}={5}; only in {3}={6}" -f $t, $NameA, @($ca | Where-Object { $_ -like "$t.*" }).Count, $NameB, @($cb | Where-Object { $_ -like "$t.*" }).Count, @($cOnlyA | Where-Object { $_ -like "$t.*" }).Count, @($cOnlyB | Where-Object { $_ -like "$t.*" }).Count)
  }
  Say ("dg_testfob listed by name: {0}={1}, {2}={3}" -f $NameA, [bool]($ha.ContainsKey('quotedetail.dg_testfob')), $NameB, [bool]($hb.ContainsKey('quotedetail.dg_testfob')))
  $nameDiff = @(); $tOnlyA | % { $nameDiff += [pscustomobject]@{ Side = "Only in $NameA"; Kind = 'Table'; Name = $_ } }; $tOnlyB | % { $nameDiff += [pscustomobject]@{ Side = "Only in $NameB"; Kind = 'Table'; Name = $_ } }
  $cOnlyA | % { $nameDiff += [pscustomobject]@{ Side = "Only in $NameA"; Kind = 'Column'; Name = $_ } }; $cOnlyB | % { $nameDiff += [pscustomobject]@{ Side = "Only in $NameB"; Kind = 'Column'; Name = $_ } }
  New-Item -ItemType Directory -Force $OutDir | Out-Null
  $nameDiff | Export-Csv "$OutDir\differences-by-name.csv" -NoTypeInformation
}
$diff | Export-Csv "$OutDir\component-differences.csv" -NoTypeInformation
$sum | Export-Csv "$OutDir\component-summary.csv" -NoTypeInformation
$mins = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
Say ''; Say ("Done in {0} minutes. Read requests: {1}={2}, {3}={4}. Nothing was changed." -f $mins, $NameA, $script:req[$NameA], $NameB, $script:req[$NameB])
$report | Out-File "$OutDir\compare-report.txt" -Encoding utf8
Write-Host "Saved in $OutDir"

