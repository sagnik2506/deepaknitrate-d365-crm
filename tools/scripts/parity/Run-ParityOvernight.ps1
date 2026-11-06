<#
.SYNOPSIS
  Runs the parity scripts as two timed runs with automatic checks. READ-ONLY (GET only; no business records; configuration content fingerprinted only).
.DESCRIPTION
  Run A (at -StartA, IST): Get-SolutionMembership.ps1, then Get-EnvComponentInventory.ps1.
  Run B (at -StartB, IST): Get-ComponentContentHashes.ps1 for forms, views, web resources, then plugin assemblies and workflows.
  Before each run it checks (any failure means the run is SKIPPED and the reason is logged):
    - the stop file is absent
    - the start time has not passed by more than -LateStartMinutes
    - the sign-in works
    - no more than -MaxJobsRunning system jobs are running, and no solution import started in the last 6 hours is still open
    - for run B: run A wrote status "Success" with the expected counts
  After each run it verifies the output (files, counts, errors, throttling) and writes status-A.json / status-B.json.
  Production (a URL containing deepakcrmprod) is REFUSED unless -Armed is given.
  -Quick limits every script to a few items for a rehearsal. -SimulateFailureA marks run A as failed after it ends (rehearsal of the gate).
  Stop at any time: create the stop file. The current request ends, the run is recorded as Stopped, and run B will not start.
#>
param(
  [Parameter(Mandatory)][string]$TargetUrl, [Parameter(Mandatory)][string]$TargetName, [Parameter(Mandatory)][string]$OutDir,
  [Parameter(Mandatory)][string]$StartA, [Parameter(Mandatory)][string]$StartB,          # 'yyyy-MM-dd HH:mm' in IST
  [int]$WindowAMinutes = 45, [int]$WindowBMinutes = 90, [int]$LateStartMinutes = 30,
  [int]$DelayMsA = 1000, [int]$DelayMsB = 1500, [int]$MaxJobsRunning = 10,
  [string]$StopFile = 'C:\DeepakNitrate\EnvSetup\STOP-PARITY.txt', [string]$SolutionNamesFile,
  [string]$LogDir = 'C:\DeepakNitrate\EnvSetup\logs\parity',
  [switch]$Armed, [switch]$Quick, [switch]$SimulateFailureA
)
$ErrorActionPreference = 'Stop'
$scripts = $PSScriptRoot
. "$scripts\ParityCommon.ps1"
$tz = [TimeZoneInfo]::FindSystemTimeZoneById('India Standard Time')
function To-Utc([string]$ist) { return [TimeZoneInfo]::ConvertTimeToUtc([datetime]::ParseExact($ist, 'yyyy-MM-dd HH:mm', $null), $tz) }
New-Item -ItemType Directory -Force $OutDir, $LogDir | Out-Null
$logFile = Join-Path $LogDir ("overnight-{0}-{1}.log" -f $TargetName, (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss'))
function Log([string]$m) {
  $u = (Get-Date).ToUniversalTime(); $i = [TimeZoneInfo]::ConvertTimeFromUtc($u, $tz)
  $line = "{0}Z / {1} IST  {2}" -f $u.ToString('HH:mm:ss'), $i.ToString('HH:mm:ss'), $m
  Add-Content -Path $logFile -Value $line; Write-Host $line
}
if ($TargetUrl -match 'deepakcrmprod' -and -not $Armed) { throw 'REFUSED: this is production. Run again with -Armed only after the notice is sent and the windows are approved.' }
$startA = To-Utc $StartA; $startB = To-Utc $StartB
Log ("Runner started. Target {0} ({1}). Run A at {2} IST, run B at {3} IST. Quick={4}. Armed={5}. Log {6}" -f $TargetName, $TargetUrl, $StartA, $StartB, $Quick, $Armed, $logFile)

Initialize-Parity -EnvUrl $TargetUrl -Name "$TargetName-gates" -DelayMs 300 -MaxMinutes 100000 -StopFile $StopFile

function Write-Status([string]$run, [string]$status, [string]$reason, [hashtable]$extra) {
  $o = [ordered]@{ Run = $run; Status = $status; Reason = $reason; Target = $TargetName; WrittenUtc = (Get-Date).ToUniversalTime().ToString('o') }
  if ($extra) { foreach ($k in $extra.Keys) { $o[$k] = $extra[$k] } }
  ($o | ConvertTo-Json -Depth 5) | Set-Content (Join-Path $OutDir "status-$run.json") -Encoding utf8
}
function Wait-Until([datetime]$utc, [string]$what) {
  $last = Get-Date
  while ((Get-Date).ToUniversalTime() -lt $utc) {
    if (Test-Path $StopFile) { return $false }
    if (((Get-Date) - $last).TotalMinutes -ge 10) { Log ("waiting for $what ... {0} minutes to go" -f [math]::Round(($utc - (Get-Date).ToUniversalTime()).TotalMinutes)); $last = Get-Date }
    Start-Sleep -Seconds 15
  }
  return $true
}
function Test-Gates([datetime]$startUtc, [string]$statusA) {
  $fails = New-Object System.Collections.Generic.List[string]
  if (Test-Path $StopFile) { $fails.Add('stop file present') }
  if ((Get-Date).ToUniversalTime() -gt $startUtc.AddMinutes($LateStartMinutes)) { $fails.Add("outside the agreed window (more than $LateStartMinutes minutes after the start time)") }
  try { $null = Get-Dv 'WhoAmI' } catch { $fails.Add("sign-in check failed: $($_.Exception.Message)") }
  try {
    $j = Get-Dv "asyncoperations?`$select=name&`$filter=statecode eq 2&`$top=50"
    $running = @($j.value | Where-Object { $_.name -notmatch 'Event Expander' }).Count
    if ($running -gt $MaxJobsRunning) { $fails.Add("$running system jobs are running (limit $MaxJobsRunning)") }
    Log "gate: system jobs running = $running (limit $MaxJobsRunning)"
  } catch { $fails.Add("system job check failed: $($_.Exception.Message)") }
  try {
    $since = (Get-Date).ToUniversalTime().AddHours(-6).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $ij = Get-Dv "importjobs?`$select=solutionname&`$filter=completedon eq null and startedon ge $since&`$top=5"
    if (@($ij.value).Count -gt 0) { $fails.Add('a solution import started in the last 6 hours is still open') }
  } catch { Log "gate: import job check skipped ($($_.Exception.Message))" }
  if ($statusA) {
    if (-not (Test-Path $statusA)) { $fails.Add('run A status file is missing') }
    else { $s = Get-Content $statusA -Raw | ConvertFrom-Json; if ($s.Status -ne 'Success') { $fails.Add("run A status is $($s.Status) ($($s.Reason))") } }
  }
  return , $fails.ToArray()
}
function Invoke-Child([string]$script, [string[]]$arguments) {
  $a = @('-NoProfile', '-File', "$scripts\$script") + $arguments
  Log ("start: $script " + ($arguments -join ' '))
  & pwsh @a *>> $logFile
  $code = $LASTEXITCODE
  Log ("end: $script exit code $code")
  return $code
}
function Count-Throttle([string]$sinceMarker) { return @(Select-String -Path $logFile -Pattern 'service protection' -ErrorAction SilentlyContinue).Count }

# =============================================================================== RUN A
$dirA = Join-Path $OutDir 'night1-existence-membership'; New-Item -ItemType Directory -Force $dirA | Out-Null
Log '--- waiting for run A'
if (-not (Wait-Until $startA 'run A')) { Log 'STOP FILE found while waiting. Nothing was run.'; Write-Status 'A' 'Stopped' 'stop file found before the start' $null; Write-Status 'B' 'Skipped' 'run A did not run' $null; exit 2 }
$fails = Test-Gates $startA $null
if ($fails.Count -gt 0) { Log ("RUN A SKIPPED: " + ($fails -join '; ')); Write-Status 'A' 'Skipped' ($fails -join '; ') $null; Write-Status 'B' 'Skipped' 'run A did not run' $null; exit 3 }
Log 'gates passed: starting run A (membership, then inventory)'
$namesArg = @(); $namesFile = $SolutionNamesFile
if ($SolutionNamesFile -and $Quick) { $namesFile = Join-Path $dirA 'names-quick.txt'; Get-Content $SolutionNamesFile | Select-Object -First 8 | Set-Content $namesFile }
if ($namesFile) { $namesArg = @('-SolutionNamesFile', $namesFile) }
$startedA = Get-Date
$c1 = Invoke-Child 'Get-SolutionMembership.ps1' (@('-EnvUrl', $TargetUrl, '-Name', $TargetName, '-OutDir', $dirA, '-DelayMs', $DelayMsA, '-MaxMinutes', $WindowAMinutes, '-StopFile', $StopFile, '-Fresh') + $namesArg)
$c2 = 0
if ($c1 -eq 0 -and -not (Test-Path $StopFile)) {
  $invArgs = @('-EnvUrl', $TargetUrl, '-Name', $TargetName, '-MembershipCsv', (Join-Path $dirA 'membership.csv'), '-OutDir', $dirA, '-DelayMs', $DelayMsA, '-MaxMinutes', $WindowAMinutes, '-StopFile', $StopFile)
  if ($Quick) { $invArgs += @('-MaxTables', 10) }
  $c2 = Invoke-Child 'Get-EnvComponentInventory.ps1' $invArgs
}
# ---- verify run A
$problems = New-Object System.Collections.Generic.List[string]
if (Test-Path $StopFile) { $problems.Add('stopped by the stop file') }
if ($c1 -ne 0) { $problems.Add("membership script exit code $c1") }
if ($c2 -ne 0) { $problems.Add("inventory script exit code $c2") }
$counts = @{}
foreach ($t in 'Table', 'Column', 'Form', 'View', 'WebResource', 'PluginAssembly', 'PluginStep', 'Workflow', 'Role', 'OptionSet') {
  $f = Join-Path $dirA "$t.csv"; $counts[$t] = if (Test-Path $f) { @(Import-Csv $f).Count } else { -1 }
}
$memRows = if (Test-Path (Join-Path $dirA 'membership.csv')) { @(Import-Csv (Join-Path $dirA 'membership.csv')).Count } else { 0 }
$counts['MembershipRows'] = $memRows
if ($memRows -le 0) { $problems.Add('membership.csv has no rows') }
$min = @{ Table = 120; Form = 150; View = 280; WebResource = 130; PluginAssembly = 40; Workflow = 130 }   # about half of what UAT showed
foreach ($t in 'Table', 'Column', 'Form', 'View', 'WebResource', 'PluginAssembly', 'PluginStep', 'Workflow', 'Role', 'OptionSet') { if ($counts[$t] -lt 0) { $problems.Add("$t.csv missing") } }
if (-not $Quick) { foreach ($t in $min.Keys) { if ($counts[$t] -lt $min[$t]) { $problems.Add("$t count $($counts[$t]) is below the expected minimum $($min[$t])") } } }
$thr = Count-Throttle ''
if ($thr -gt 10) { $problems.Add("$thr service-protection waits (more than 10)") }
if ($SimulateFailureA) { $problems.Add('SIMULATED failure (rehearsal)') }
$endedA = Get-Date
$extraA = @{ Counts = $counts; Minutes = [math]::Round(($endedA - $startedA).TotalMinutes, 1); ThrottleWaits = $thr }
if ($problems.Count -eq 0) { Write-Status 'A' 'Success' 'all checks passed' $extraA; Log ("RUN A: SUCCESS in {0} minutes. Counts: {1}" -f $extraA.Minutes, (($counts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')) }
else { $st = if (Test-Path $StopFile) { 'Stopped' } else { 'Failed' }; Write-Status 'A' $st ($problems -join '; ') $extraA; Log ("RUN A: " + $st.ToUpper() + " - " + ($problems -join '; ')) }

# =============================================================================== RUN B
$dirB = Join-Path $OutDir 'night2-3-content'; New-Item -ItemType Directory -Force $dirB | Out-Null
Log '--- waiting for run B'
if (-not (Wait-Until $startB 'run B')) { Log 'STOP FILE found while waiting. Run B did not run.'; Write-Status 'B' 'Stopped' 'stop file found before the start' $null; exit 2 }
$fails = Test-Gates $startB (Join-Path $OutDir 'status-A.json')
if ($fails.Count -gt 0) { Log ("RUN B SKIPPED: " + ($fails -join '; ')); Write-Status 'B' 'Skipped' ($fails -join '; ') $null; exit 3 }
Log 'gates passed: starting run B (content hashes)'
$startedB = Get-Date
$memCsv = Join-Path $dirA 'membership.csv'
$common = @('-EnvUrl', $TargetUrl, '-Name', $TargetName, '-MembershipCsv', $memCsv, '-OutDir', $dirB, '-DelayMs', $DelayMsB, '-MaxMinutes', $WindowBMinutes, '-StopFile', $StopFile)
if ($Quick) { $common += @('-MaxItems', 5) }
$b1 = Invoke-Child 'Get-ComponentContentHashes.ps1' ($common + @('-Types', 'Forms,Views,WebResources'))
$b2 = 0
if ($b1 -eq 0 -and -not (Test-Path $StopFile)) { $b2 = Invoke-Child 'Get-ComponentContentHashes.ps1' ($common + @('-Types', 'PluginAssemblies,Workflows')) }
$problems = New-Object System.Collections.Generic.List[string]
if (Test-Path $StopFile) { $problems.Add('stopped by the stop file') }
if ($b1 -ne 0) { $problems.Add("content script (forms, views, web resources) exit code $b1") }
if ($b2 -ne 0) { $problems.Add("content script (plugins, flows) exit code $b2") }
$hc = @{}
$mem = Import-Csv $memCsv
foreach ($pair in @(@('Forms', '60'), @('Views', '26'), @('WebResources', '61'), @('PluginAssemblies', '91'), @('Workflows', '29'))) {
  $f = Join-Path $dirB ("hashes-{0}.csv" -f $pair[0]); $want = @($mem | Where-Object { $_.TypeCode -eq $pair[1] } | Select-Object -ExpandProperty ObjectId -Unique).Count
  if (Test-Path $f) { $rows = @(Import-Csv $f); $nf = @($rows | Where-Object { $_.Name -eq '(not found)' }).Count } else { $rows = @(); $nf = 0 }
  $hc[$pair[0]] = "$($rows.Count) of $want (not found: $nf)"
  if (-not $Quick -and $want -gt 0 -and $rows.Count -lt [math]::Floor($want * 0.98)) { $problems.Add("$($pair[0]): only $($rows.Count) of $want hashed") }
  if ($Quick -and $rows.Count -eq 0 -and $want -gt 0) { $problems.Add("$($pair[0]): nothing hashed") }
}
if ((Count-Throttle '') -gt 20) { $problems.Add('too many service-protection waits') }
$extraB = @{ Hashed = $hc; Minutes = [math]::Round(((Get-Date) - $startedB).TotalMinutes, 1) }
if ($problems.Count -eq 0) { Write-Status 'B' 'Success' 'all checks passed' $extraB; Log ("RUN B: SUCCESS in {0} minutes. {1}" -f $extraB.Minutes, (($hc.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; ')) }
else { $st = if (Test-Path $StopFile) { 'Stopped' } else { 'Failed' }; Write-Status 'B' $st ($problems -join '; ') $extraB; Log ("RUN B: " + $st.ToUpper() + " - " + ($problems -join '; ')) }
Log ("Runner finished. Gate requests: {0}. Nothing was changed in the environment. No business records were read." -f $script:P.Requests)
