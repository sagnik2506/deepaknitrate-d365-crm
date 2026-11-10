<#
.SYNOPSIS
  F3 (part 1): updates approved plugin assemblies in UAT-ALIGN with the production DLL downloaded by Get-ProductionComponents.ps1.
.DESCRIPTION
  Only names listed in pipelines/config/approved-plugin-assemblies.json are changed (empty = nothing changes). The assembly must already exist in UAT-ALIGN; one that is missing is reported and must be
  registered with the Plugin Registration Tool (it also registers the plugin types). An update changes behaviour at once: run it while UAT-ALIGN is frozen. The platform refuses a DLL whose identity
  (name, version, public key token) does not fit the registered assembly; that is reported as failed. -DryRun lists what would change. Writes only to the writable environment key (enforced).
#>
param([Parameter(Mandatory)][string]$SourceDir, [string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\plugin-assemblies-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-plugin-assemblies.json').approved)
$index = @{}; foreach ($x in (Get-Content (Join-Path $SourceDir 'index.json') -Raw | ConvertFrom-Json)) { if ($x.kind -eq 'plugins') { $index[$x.name] = $x } }
Write-Log "$($approved.Count) approved assemblies; target $TargetKey; dry run: $DryRun"
$report = New-Object System.Collections.Generic.List[object]
foreach ($name in $approved) {
    $row = [ordered]@{ name = $name; action = ''; versionBefore = ''; versionAfter = ''; note = '' }
    try {
        if (-not $index.ContainsKey($name)) { throw 'no production DLL in the source folder' }
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $SourceDir $index[$name].file)))
        $q = "pluginassemblies?`$select=pluginassemblyid,name,version,content&`$filter=name eq '" + ($name -replace "'", "''") + "'"
        $cur = @((Invoke-Dv -Key $TargetKey -Path $q).value)
        if ($cur.Count -eq 0) { $row.action = 'missing in target'; $row.note = 'register it with the Plugin Registration Tool'; $report.Add([pscustomobject]$row); continue }
        $row.versionBefore = [string]$cur[0].version
        if ($cur[0].content -eq $b64) { $row.action = 'same'; $report.Add([pscustomobject]$row); continue }
        $row.action = 'update'
        if (-not $DryRun) {
            Invoke-Dv -Key $TargetKey -Path "pluginassemblies($($cur[0].pluginassemblyid))" -Method PATCH -Body @{ content = $b64 } | Out-Null
            $row.versionAfter = [string](Invoke-Dv -Key $TargetKey -Path "pluginassemblies($($cur[0].pluginassemblyid))?`$select=version").version
        }
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$name : $($row.note)" }
    $report.Add([pscustomobject]$row)
}
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Format-Table -AutoSize | Out-String | Write-Host
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
