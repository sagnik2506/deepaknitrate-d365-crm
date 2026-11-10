<#
.SYNOPSIS
  Guard for the environment pipeline: refuses to continue unless the target is the agreed working copy and is not UAT, production or any other known environment.
#>
param([Parameter(Mandatory)][string]$TargetName, [string]$TargetUrl = '')
. "$PSScriptRoot\Common.ps1"
$cfg = Get-PipelineConfig 'environments.json'
if ($TargetName -ne $cfg.alignEnvironmentName) { Add-AdoError "REFUSED: target name '$TargetName' is not '$($cfg.alignEnvironmentName)'."; exit 1 }
if ($TargetUrl) {
    $t = $TargetUrl.TrimEnd('/').ToLower()
    foreach ($k in 'UAT', 'DEV', 'SIT', 'PREPROD', 'DEVDNL', 'PROD') {
        if ($t -eq ([string]$cfg.$k).TrimEnd('/').ToLower()) { Add-AdoError "REFUSED: target URL equals the $k environment."; exit 1 }
    }
}
Write-Log "Guard passed: target '$TargetName' $TargetUrl"
