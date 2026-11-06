# UAT-only test of the parity scripts (read-only). Runs in the background and logs to logs\parity\uat-test.log
Set-Location C:\DeepakNitrate\EnvSetup
$s = 'C:\DeepakNitrate\Repo\deepaknitrate-d365-crm\tools\scripts\parity'
$u = 'https://deepakgroupuat.crm8.dynamics.com'
$d = 'C:\DeepakNitrate\EnvSetup\data\parity\night1-existence-membership\UAT'
$log = 'C:\DeepakNitrate\EnvSetup\logs\parity\uat-test.log'
function Log($t) { ("{0}  {1}" -f (Get-Date).ToUniversalTime().ToString('HH:mm:ss'), $t) | Tee-Object -FilePath $log -Append }
Set-Content $log ("UAT test started (UTC) " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))
Log '--- step 1: inventory'
pwsh -NoProfile -File "$s\Get-EnvComponentInventory.ps1" -EnvUrl $u -Name UAT -MembershipCsv "$d\membership.csv" -OutDir $d -DelayMs 200 -MaxMinutes 30 *>> $log
Log '--- step 2: content hashes, small sample (15 per type)'
pwsh -NoProfile -File "$s\Get-ComponentContentHashes.ps1" -EnvUrl $u -Name UAT -MembershipCsv "$d\membership.csv" -OutDir $d -DelayMs 200 -MaxMinutes 20 -MaxItems 15 *>> $log
Log '--- step 3: comparer, UAT against itself (everything must be identical)'
$env:PYTHONPATH = 'C:\Users\sagni\AppData\Local\Temp\docxbuild\py'
python -I "$s\compare_parity.py" $d UAT $d UAT 'C:\DeepakNitrate\EnvSetup\data\parity\compare-test\self' *>> $log
Log '--- step 4: comparer, UAT against an altered copy (differences must be found)'
$alt = 'C:\DeepakNitrate\EnvSetup\data\parity\compare-test\altered-copy'
Remove-Item $alt -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item $d $alt -Recurse
$f = Import-Csv "$alt\Form.csv"; $f | Select-Object -Skip 3 | Export-Csv "$alt\Form.csv" -NoTypeInformation          # 3 forms removed
$c = Import-Csv "$alt\Column.csv"; $c | Select-Object -Skip 5 | Export-Csv "$alt\Column.csv" -NoTypeInformation      # 5 columns removed
if (Test-Path "$alt\hashes-WebResources.csv") { $h = Import-Csv "$alt\hashes-WebResources.csv"; if ($h.Count -gt 2) { $h[0].ShaNorm = 'altered00000000'; $h[1].ShaNorm = 'altered11111111' }; $h | Export-Csv "$alt\hashes-WebResources.csv" -NoTypeInformation }   # 2 hashes changed
$m = Import-Csv "$alt\membership.csv"; $m | Select-Object -Skip 10 | Export-Csv "$alt\membership.csv" -NoTypeInformation                                  # 10 membership rows removed
python -I "$s\compare_parity.py" $d UAT $alt ALTERED 'C:\DeepakNitrate\EnvSetup\data\parity\compare-test\altered' *>> $log
Log '--- finished'
