# Shared helpers for the parity scripts. Dot-source it:  . "$PSScriptRoot\ParityCommon.ps1"
# SAFETY: GET requests only. No record data is read. Pause after every request. 429 is retried with the wait the server asks for.
# A stop file or a time limit ends the run. Nothing is created, changed or deleted in any environment.
$ErrorActionPreference = 'Stop'
$script:P = @{}

function Initialize-Parity {
  param([Parameter(Mandatory)][string]$EnvUrl, [string]$Name = 'ENV', [int]$DelayMs = 1000, [int]$MaxMinutes = 60, [string]$StopFile = '.\STOP-PARITY.txt')
  $EnvUrl = $EnvUrl.TrimEnd('/')
  $script:P = @{ Url = $EnvUrl; Api = "$EnvUrl/api/data/v9.2"; Delay = $DelayMs; Max = $MaxMinutes; Stop = $StopFile; Name = $Name; Started = Get-Date; Requests = 0; Errors = 0; H = $null; Renewed = $false }
  Set-ParityToken
  $null = Get-Dv 'WhoAmI'
  Write-Host "[$Name] signed in OK ($EnvUrl)"
}
function Set-ParityToken {
  $tok = (az account get-access-token --resource $script:P.Url --query accessToken -o tsv 2>$null)
  if (-not $tok) { throw "No token for $($script:P.Url). Sign in first: az login (use an account that has access)." }
  $script:P.H = @{ Authorization = "Bearer $tok"; 'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0'; Accept = 'application/json'; Prefer = 'odata.maxpagesize=5000' }
}
function Test-Keep {
  if (Test-Path $script:P.Stop) { throw "Stopped: $($script:P.Stop) found." }
  if (((Get-Date) - $script:P.Started).TotalMinutes -gt $script:P.Max) { throw "Stopped: time limit of $($script:P.Max) minutes reached." }
}
function Get-Dv([string]$Path) {
  Test-Keep
  $url = if ($Path -like 'http*') { $Path } else { "$($script:P.Api)/$Path" }
  for ($t = 1; $t -le 5; $t++) {
    try { $script:P.Requests++; $r = Invoke-RestMethod -Method Get -Uri $url -Headers $script:P.H; Start-Sleep -Milliseconds $script:P.Delay; return $r }
    catch {
      $code = 0; try { $code = [int]$_.Exception.Response.StatusCode } catch { }
      if ($code -eq 401 -and -not $script:P.Renewed) { $script:P.Renewed = $true; Set-ParityToken; $script:P.Renewed = $false; continue }
      if ($code -eq 401 -or $code -eq 403) { throw "HTTP $code on $($script:P.Url). No access with this account. Stopping." }
      if ($code -eq 429 -and $t -lt 5) { $w = 30; try { $w = [int]$_.Exception.Response.Headers.GetValues('Retry-After')[0] } catch { }; Write-Host "  (service protection, waiting $w s)"; Start-Sleep -Seconds $w; continue }
      if ($code -ge 500 -and $t -lt 3) { Start-Sleep -Seconds 5; continue }
      $script:P.Errors++; throw
    }
  }
}
function Get-DvAll([string]$Path) {
  $o = New-Object System.Collections.Generic.List[object]; $u = $Path
  while ($u) { $r = Get-Dv $u; foreach ($x in $r.value) { $o.Add($x) }; $u = $r.'@odata.nextLink' }
  return , $o.ToArray()
}
# Customer solutions = visible, publisher not Microsoft / Adxstudio / MBS, not Default / Active / Basic
function Get-CustomerSolutions([string[]]$OnlyNames) {
  $s = Get-DvAll "solutions?`$select=solutionid,uniquename,friendlyname,version,ismanaged,isvisible,_parentsolutionid_value&`$expand=publisherid(`$select=uniquename)&`$filter=isvisible eq true"
  $s = @($s | Where-Object { $_.publisherid.uniquename -notmatch '^(microsoft|adxstudio|mbs$)' -and $_.uniquename -notin @('Default', 'Active', 'Basic') })
  if ($OnlyNames) { $set = @{}; $OnlyNames | ForEach-Object { $set[$_] = 1 }; $s = @($s | Where-Object { $set.ContainsKey($_.uniquename) }) }
  return $s
}
function Get-Sha([byte[]]$Bytes) { $sha = [Security.Cryptography.SHA256]::Create(); return ((($sha.ComputeHash($Bytes)) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16) }
function Get-ShaText([string]$Text) { if ($null -eq $Text) { return '' }; $n = ($Text -replace "`r`n", "`n" -replace '^﻿', '').TrimEnd(); return Get-Sha ([Text.Encoding]::UTF8.GetBytes($n)) }
function Write-ParitySummary([string]$What) {
  $mins = [math]::Round(((Get-Date) - $script:P.Started).TotalMinutes, 1)
  Write-Host ("[{0}] {1}: {2} read requests, {3} errors, {4} minutes. Nothing was changed in the environment. No record data was read." -f $script:P.Name, $What, $script:P.Requests, $script:P.Errors, $mins)
}
$script:TypeNames = @{ 1 = 'Table'; 2 = 'Column'; 9 = 'OptionSet'; 10 = 'Relationship'; 20 = 'Role'; 26 = 'View'; 29 = 'Workflow'; 60 = 'Form'; 61 = 'WebResource'; 62 = 'SiteMap'; 80 = 'ModelApp'; 91 = 'PluginAssembly'; 92 = 'PluginStep' }
