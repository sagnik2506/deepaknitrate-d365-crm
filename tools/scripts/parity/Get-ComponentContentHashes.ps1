<#
.SYNOPSIS
  L3: content hashes of the customer components in one environment. READ-ONLY (GET only; no business records; configuration content fingerprinted only).
.DESCRIPTION
  Reads the CONTENT of forms (form XML), views (fetch and layout XML), web resources, plugin assemblies and workflows/flows for the
  components named in membership.csv, and writes Type, Id, Name, Bytes and two hashes (raw and normalised for text) to hashes-<Type>.csv.
  Resumes: ids already in the output file are skipped. Use -MaxItems for a small test.
.EXAMPLE
  .\Get-ComponentContentHashes.ps1 -EnvUrl https://<env>.crm8.dynamics.com -Name UAT -MembershipCsv <dir>\membership.csv -OutDir <dir> -Types Forms,Views,WebResources -DelayMs 200
#>
param(
  [Parameter(Mandatory)][string]$EnvUrl, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$MembershipCsv,
  [string]$OutDir = '.\parity-out', [string[]]$Types = @('Forms', 'Views', 'WebResources', 'PluginAssemblies', 'Workflows'),
  [int]$DelayMs = 1000, [int]$MaxMinutes = 60, [string]$StopFile = '.\STOP-PARITY.txt', [int]$MaxItems = 0
)
. "$PSScriptRoot\ParityCommon.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
Initialize-Parity -EnvUrl $EnvUrl -Name $Name -DelayMs $DelayMs -MaxMinutes $MaxMinutes -StopFile $StopFile
$Types = @($Types | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$mem = Import-Csv $MembershipCsv
# type name -> (type code, entity set, id attribute, name attribute, content attributes, chunk size, kind of content)
$spec = @{
  Forms            = @{ Code = '60'; Set = 'systemforms';   Id = 'formid';          Name = 'name'; Content = 'formxml';            Chunk = 5;  Kind = 'text' }
  Views            = @{ Code = '26'; Set = 'savedqueries';  Id = 'savedqueryid';    Name = 'name'; Content = 'fetchxml,layoutxml'; Chunk = 15; Kind = 'text' }
  WebResources     = @{ Code = '61'; Set = 'webresourceset'; Id = 'webresourceid';  Name = 'name'; Content = 'content';           Chunk = 8;  Kind = 'base64' }
  PluginAssemblies = @{ Code = '91'; Set = 'pluginassemblies'; Id = 'pluginassemblyid'; Name = 'name'; Content = 'content';        Chunk = 2;  Kind = 'base64' }
  Workflows        = @{ Code = '29'; Set = 'workflows';     Id = 'workflowid';      Name = 'name'; Content = 'clientdata,xaml';    Chunk = 8;  Kind = 'text' }
}
foreach ($t in $Types) {
  if (-not $spec.ContainsKey($t)) { Write-Host "unknown type $t (use: $($spec.Keys -join ', '))"; continue }
  $s = $spec[$t]; $out = "$OutDir\hashes-$t.csv"
  $all = @($mem | Where-Object { $_.TypeCode -eq $s.Code } | Select-Object -ExpandProperty ObjectId -Unique | ForEach-Object { $_.ToLower() })
  $done = @{}; if (Test-Path $out) { Import-Csv $out | ForEach-Object { $done[$_.Id.ToLower()] = 1 } }
  $todo = @($all | Where-Object { -not $done.ContainsKey($_) }); if ($MaxItems -gt 0) { $todo = @($todo | Select-Object -First $MaxItems) }
  Write-Host "[$Name] $t : $($all.Count) components, $($done.Count) already done, $($todo.Count) to read"
  $nDone = 0
  for ($i = 0; $i -lt $todo.Count; $i += $s.Chunk) {
    $chunk = @($todo[$i..([math]::Min($i + $s.Chunk, $todo.Count) - 1)])
    $flt = ($chunk | ForEach-Object { "$($s.Id) eq $_" }) -join ' or '
    $sel = "$($s.Id),$($s.Name),$($s.Content)"
    $rows = (Get-Dv "$($s.Set)?`$select=$sel&`$filter=$flt").value
    $out2 = foreach ($r in $rows) {
      if ($s.Kind -eq 'base64') {
        $b64 = $r.content; if ($b64) { $b = [Convert]::FromBase64String($b64); $raw = Get-Sha $b; $norm = Get-ShaText ([Text.Encoding]::UTF8.GetString($b)); $len = $b.Length } else { $raw = ''; $norm = ''; $len = 0 }
      } else {
        $txt = ($s.Content -split ',' | ForEach-Object { [string]$r.$_ }) -join "`n"
        $b = [Text.Encoding]::UTF8.GetBytes($txt); $len = $b.Length; $raw = Get-Sha $b; $norm = Get-ShaText $txt
      }
      [pscustomobject]@{ Type = $t; Id = $r.($s.Id); Name = $r.($s.Name); Bytes = $len; Sha = $raw; ShaNorm = $norm }
    }
    if ($out2) { $out2 | Export-Csv $out -NoTypeInformation -Append }
    # ids that came back empty (deleted since listing) are still marked done by a zero-length row
    $got = @($rows | ForEach-Object { $_.($s.Id).ToLower() }); $miss = @($chunk | Where-Object { $got -notcontains $_ })
    if ($miss) { $miss | ForEach-Object { [pscustomobject]@{ Type = $t; Id = $_; Name = '(not found)'; Bytes = 0; Sha = ''; ShaNorm = '' } } | Export-Csv $out -NoTypeInformation -Append }
    $nDone += $chunk.Count; if (($nDone % 100) -lt $s.Chunk) { Write-Host "  [$Name] $t : $nDone of $($todo.Count)" }
  }
}
Write-ParitySummary 'content hashes done'
