# UAT ONLY. Full content hashes of the customer components (read-only). Resumes from the sample already written.
Set-Location C:\DeepakNitrate\EnvSetup
$s = 'C:\DeepakNitrate\Repo\deepaknitrate-d365-crm\tools\scripts\parity'
$d = 'C:\DeepakNitrate\EnvSetup\data\parity\night1-existence-membership\UAT'
$log = 'C:\DeepakNitrate\EnvSetup\logs\parity\uat-full-hashes.log'
Set-Content $log ("UAT full content hashes started (UTC) " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))
pwsh -NoProfile -File "$s\Get-ComponentContentHashes.ps1" -EnvUrl https://deepakgroupuat.crm8.dynamics.com -Name UAT -MembershipCsv "$d\membership.csv" -OutDir $d -DelayMs 200 -MaxMinutes 40 *>> $log
("finished (UTC) " + (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) | Add-Content $log
