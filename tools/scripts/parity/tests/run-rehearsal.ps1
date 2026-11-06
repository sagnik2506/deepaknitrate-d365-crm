# REHEARSAL of Run-ParityOvernight.ps1 against UAT (never production). Four tests; results in logs\parity\rehearsal-summary.txt
Set-Location C:\DeepakNitrate\EnvSetup
$r = 'C:\DeepakNitrate\Repo\deepaknitrate-d365-crm\tools\scripts\parity\Run-ParityOvernight.ps1'
$uat = 'https://deepakgroupuat.crm8.dynamics.com'
$names = 'C:\DeepakNitrate\EnvSetup\data\parity\prod-customer-solutions.txt'
$stop = 'C:\DeepakNitrate\EnvSetup\STOP-PARITY.txt'
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$base = "C:\DeepakNitrate\EnvSetup\data\parity\rehearsal\$stamp"
$sum = "C:\DeepakNitrate\EnvSetup\logs\parity\rehearsal-summary-$stamp.txt"
$tz = [TimeZoneInfo]::FindSystemTimeZoneById('India Standard Time')
function Ist([int]$addMin) { [TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime().AddMinutes($addMin), $tz).ToString('yyyy-MM-dd HH:mm') }
function S($m) { Add-Content $sum ("{0}  {1}" -f (Get-Date).ToUniversalTime().ToString('HH:mm:ss'), $m) }
function Show($dir) { foreach ($x in 'A', 'B') { $f = "$dir\status-$x.json"; if (Test-Path $f) { $j = Get-Content $f -Raw | ConvertFrom-Json; S ("   run $x : {0} ({1})" -f $j.Status, $j.Reason) } else { S "   run $x : no status file" } } }
function Q([string]$v) { return ('"' + $v + '"') }
function DropStop { if (Test-Path $stop) { [System.IO.File]::Delete($stop) } }
DropStop
New-Item -ItemType Directory -Force $base | Out-Null
Set-Content $sum 'REHEARSAL (UAT only)'
S 'T1 normal run: expect A Success, B Success'
S 'T2 forced failure of A: expect A Failed, B Skipped (B must NOT start)'
$a = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-File', $r, '-TargetUrl', $uat, '-TargetName', 'UAT-T1', '-OutDir', "$base\t1", '-StartA', (Q (Ist 1)), '-StartB', (Q (Ist 4)), '-Quick', '-SolutionNamesFile', $names, '-DelayMsA', 200, '-DelayMsB', 200)
$b = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-File', $r, '-TargetUrl', $uat, '-TargetName', 'UAT-T2', '-OutDir', "$base\t2", '-StartA', (Q (Ist 1)), '-StartB', (Q (Ist 4)), '-Quick', '-SimulateFailureA', '-SolutionNamesFile', $names, '-DelayMsA', 200, '-DelayMsB', 200)
$a.WaitForExit(); $b.WaitForExit()
S 'T1 result:'; Show "$base\t1"
S 'T2 result:'; Show "$base\t2"
S 'T3 stop file while A runs: expect A Stopped, B Stopped or Skipped (B must NOT hash anything)'
$c = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-File', $r, '-TargetUrl', $uat, '-TargetName', 'UAT-T3', '-OutDir', "$base\t3", '-StartA', (Q (Ist 1)), '-StartB', (Q (Ist 4)), '-Quick', '-SolutionNamesFile', $names, '-DelayMsA', 1500, '-DelayMsB', 200)
Start-Sleep -Seconds 95
New-Item $stop -ItemType File -Force | Out-Null
$c.WaitForExit()
DropStop
S 'T3 result:'; Show "$base\t3"
S ("   hash files written by T3 run B: " + @(Get-ChildItem "$base\t3\night2-3-content" -Filter 'hashes-*.csv' -ErrorAction SilentlyContinue).Count)
S 'T4 late start (60 minutes after the time): expect A Skipped (outside the window), B Skipped'
$d = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-File', $r, '-TargetUrl', $uat, '-TargetName', 'UAT-T4', '-OutDir', "$base\t4", '-StartA', (Q (Ist -60)), '-StartB', (Q (Ist -58)), '-Quick', '-SolutionNamesFile', $names, '-DelayMsA', 200, '-DelayMsB', 200)
$d.WaitForExit()
S 'T4 result:'; Show "$base\t4"
S 'REHEARSAL FINISHED'
