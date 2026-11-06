# UAT-only re-test of the corrected inventory script (read-only). Logs to logs\parity\uat-inventory-retest.log
Set-Location C:\DeepakNitrate\EnvSetup
$s = 'C:\DeepakNitrate\Repo\deepaknitrate-d365-crm\tools\scripts\parity'
$d = 'C:\DeepakNitrate\EnvSetup\data\parity\night1-existence-membership\UAT'
$log = 'C:\DeepakNitrate\EnvSetup\logs\parity\uat-inventory-retest.log'
Set-Content $log ("started (UTC) " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))
Get-ChildItem $d -Filter *.csv | Where-Object { $_.Name -notmatch '^(membership|solutions|hashes-)' } | Remove-Item -Force
pwsh -NoProfile -File "$s\Get-EnvComponentInventory.ps1" -EnvUrl https://deepakgroupuat.crm8.dynamics.com -Name UAT -MembershipCsv "$d\membership.csv" -OutDir $d -DelayMs 200 -MaxMinutes 20 *>> $log
$env:PYTHONPATH = 'C:\Users\sagni\AppData\Local\Temp\docxbuild\py'
python -I "$s\compare_parity.py" $d UAT $d UAT 'C:\DeepakNitrate\EnvSetup\data\parity\compare-test\self2' *>> $log
("finished (UTC) " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) | Add-Content $log
