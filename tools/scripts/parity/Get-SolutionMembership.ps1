<#
.SYNOPSIS
  L2: which components does each customer solution carry? READ-ONLY (GET only, no record data).
.DESCRIPTION
  For every customer solution (or only those named in -SolutionNamesFile) reads the solution's component list
  (type, object id, root component behaviour) and writes membership.csv. Resumes from a checkpoint.
  rootcomponentbehavior 0 means a table is carried with ALL its columns, forms and views (they are not listed one by one).
.EXAMPLE
  .\Get-SolutionMembership.ps1 -EnvUrl https://<env>.crm8.dynamics.com -Name UAT -SolutionNamesFile .\prod-customer-solutions.txt -OutDir C:\DeepakNitrate\EnvSetup\data\parity\night1-existence-membership\UAT -DelayMs 200
#>
param(
  [Parameter(Mandatory)][string]$EnvUrl, [Parameter(Mandatory)][string]$Name,
  [string]$SolutionNamesFile, [string]$OutDir = '.\parity-out', [int]$DelayMs = 1000, [int]$MaxMinutes = 60,
  [string]$StopFile = '.\STOP-PARITY.txt', [switch]$Fresh
)
. "$PSScriptRoot\ParityCommon.ps1"
New-Item -ItemType Directory -Force $OutDir | Out-Null
Initialize-Parity -EnvUrl $EnvUrl -Name $Name -DelayMs $DelayMs -MaxMinutes $MaxMinutes -StopFile $StopFile
$only = if ($SolutionNamesFile) { @(Get-Content $SolutionNamesFile | Where-Object { $_.Trim() }) } else { $null }
$sols = Get-CustomerSolutions $only
Write-Host "[$Name] customer solutions to read: $($sols.Count)"
$sols | Select-Object uniquename, friendlyname, version, ismanaged, @{n = 'IsPatch'; e = { [bool]$_._parentsolutionid_value } } | Export-Csv "$OutDir\solutions.csv" -NoTypeInformation
$memFile = "$OutDir\membership.csv"; $doneFile = "$OutDir\done-solutions.txt"
if ($Fresh) { Remove-Item $memFile, $doneFile -ErrorAction SilentlyContinue }
$done = @{}; if (Test-Path $doneFile) { Get-Content $doneFile | ForEach-Object { $done[$_] = 1 } }
$i = 0
foreach ($s in $sols) {
  $i++
  if ($done.ContainsKey($s.uniquename)) { continue }
  $c = Get-DvAll "solutioncomponents?`$select=componenttype,objectid,rootcomponentbehavior&`$filter=_solutionid_value eq $($s.solutionid)"
  $rows = foreach ($x in $c) { [pscustomobject]@{ Solution = $s.uniquename; Version = $s.version; Managed = $s.ismanaged; TypeCode = $x.componenttype; Type = $(if ($script:TypeNames.ContainsKey([int]$x.componenttype)) { $script:TypeNames[[int]$x.componenttype] } else { "type$($x.componenttype)" }); ObjectId = $x.objectid; Behavior = $x.rootcomponentbehavior } }
  if ($rows) { $rows | Export-Csv $memFile -NoTypeInformation -Append }
  Add-Content $doneFile $s.uniquename
  if ($i % 25 -eq 0) { Write-Host "  [$Name] $i of $($sols.Count) solutions read" }
}
$all = if (Test-Path $memFile) { Import-Csv $memFile } else { @() }
Write-Host "[$Name] membership rows: $(@($all).Count) over $(@($all | Select-Object -ExpandProperty Solution -Unique).Count) solutions"
$all | Group-Object Type | Sort-Object Count -Descending | ForEach-Object { Write-Host ("   {0}: {1}" -f $_.Name, $_.Count) }
Write-ParitySummary 'membership done'
