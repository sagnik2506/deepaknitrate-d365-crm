<#
.SYNOPSIS
  F3 (part 2): registers approved plugin steps in UAT-ALIGN with the definition read from production (Get-ProductionComponents.ps1 -Types PluginSteps).
.DESCRIPTION
  Only ids listed in pipelines/config/approved-plugin-steps.json are registered (empty = nothing). For each step the script finds, in UAT-ALIGN, the plugin type (by type name), the message and the
  message filter (message + table), creates the step with the production stage, mode, rank, filtering attributes, deployment and unsecure configuration, adds its images, and disables it when it is disabled
  in production. The step is added to the solution that carries it in production (first solution named in the candidate list). A step whose name already exists is skipped.
  NOT covered: SECURE configuration (it cannot be read from production: ask the owner and set it by hand). The plugin assembly must be in UAT-ALIGN first (Update-PluginAssemblies.ps1 or the Plugin Registration Tool).
  -DryRun resolves everything and lists what it would create. Writes only to the writable environment key (enforced).
#>
param([Parameter(Mandatory)][string]$SourceDir, [string]$TargetKey = 'ALIGN', [switch]$DryRun, [string]$ReportFile = '.\plugin-steps-report.csv')
. "$PSScriptRoot\Common.ps1"
Assert-Writable $TargetKey
$approved = @((Get-PipelineConfig 'approved-plugin-steps.json').approved | ForEach-Object { ([string]$_).ToLower() })
Write-Log "$($approved.Count) approved steps; target $TargetKey; dry run: $DryRun"
function Esc([string]$s) { return ($s -replace "'", "''") }
$report = New-Object System.Collections.Generic.List[object]
foreach ($id in $approved) {
    $row = [ordered]@{ id = $id; name = ''; action = ''; note = '' }
    try {
        $file = Join-Path $SourceDir "steps\$id.json"
        if (-not (Test-Path $file)) { throw 'no production step definition in the source folder (is the id in plugin-steps.json?)' }
        $s = Get-Content $file -Raw | ConvertFrom-Json
        $row.name = $s.name
        $exists = @((Invoke-Dv -Key $TargetKey -Path ("sdkmessageprocessingsteps?`$select=sdkmessageprocessingstepid&`$filter=name eq '" + (Esc $s.name) + "'")).value)
        if ($exists.Count -gt 0) { $row.action = 'already exists'; $report.Add([pscustomobject]$row); continue }
        $pt = @((Invoke-Dv -Key $TargetKey -Path ("plugintypes?`$select=plugintypeid&`$filter=typename eq '" + (Esc $s.pluginType) + "'")).value)
        if ($pt.Count -eq 0) { throw "plugin type '$($s.pluginType)' not found in the target (register the assembly first)" }
        $msg = @((Invoke-Dv -Key $TargetKey -Path ("sdkmessages?`$select=sdkmessageid&`$filter=name eq '" + (Esc $s.message) + "'")).value)
        if ($msg.Count -eq 0) { throw "message '$($s.message)' not found in the target" }
        $filterId = $null
        if ($s.entity -and $s.entity -ne 'none') {
            $f = @((Invoke-Dv -Key $TargetKey -Path ("sdkmessagefilters?`$select=sdkmessagefilterid&`$filter=_sdkmessageid_value eq $($msg[0].sdkmessageid) and primaryobjecttypecode eq '" + (Esc $s.entity) + "'")).value)
            if ($f.Count -eq 0) { throw "message filter for '$($s.message)' on '$($s.entity)' not found in the target" }
            $filterId = $f[0].sdkmessagefilterid
        }
        $row.action = 'create'
        if ($DryRun) { $report.Add([pscustomobject]$row); continue }
        $body = [ordered]@{ name = $s.name; description = $s.description; stage = [int]$s.stage; mode = [int]$s.mode; rank = [int]$s.rank; supporteddeployment = [int]$s.supporteddeployment; asyncautodelete = [bool]$s.asyncautodelete
            'eventhandler_plugintype@odata.bind' = "/plugintypes($($pt[0].plugintypeid))"; 'sdkmessageid@odata.bind' = "/sdkmessages($($msg[0].sdkmessageid))" }
        if ($s.filteringattributes) { $body.filteringattributes = $s.filteringattributes }
        if ($s.configuration) { $body.configuration = $s.configuration }
        if ($filterId) { $body['sdkmessagefilterid@odata.bind'] = "/sdkmessagefilters($filterId)" }
        $hdr = @{ Prefer = 'return=representation' }
        $sol = ([string]$s.solutions -split ';')[0].Trim(); if ($sol) { $hdr['MSCRM.SolutionUniqueName'] = $sol }
        $created = Invoke-Dv -Key $TargetKey -Path 'sdkmessageprocessingsteps' -Method POST -Body $body -ExtraHeaders $hdr
        foreach ($img in @($s.images)) {
            $ib = [ordered]@{ name = $img.name; entityalias = $img.entityalias; imagetype = [int]$img.imagetype; messagepropertyname = $img.messagepropertyname; 'sdkmessageprocessingstepid@odata.bind' = "/sdkmessageprocessingsteps($($created.sdkmessageprocessingstepid))" }
            if ($img.attributes) { $ib.attributes = $img.attributes }
            Invoke-Dv -Key $TargetKey -Path 'sdkmessageprocessingstepimages' -Method POST -Body $ib | Out-Null
        }
        if ([int]$s.statecode -eq 1) { Invoke-Dv -Key $TargetKey -Path "sdkmessageprocessingsteps($($created.sdkmessageprocessingstepid))" -Method PATCH -Body @{ statecode = 1; statuscode = 2 } | Out-Null }
        $row.note = 'secure configuration (if any) must be set by hand'
    } catch { $row.action = 'failed'; $row.note = $_.Exception.Message; Add-AdoError "$id : $($row.note)" }
    $report.Add([pscustomobject]$row)
}
$report | Export-Csv $ReportFile -NoTypeInformation -Encoding utf8
$report | Group-Object action | ForEach-Object { Write-Log "$($_.Name): $($_.Count)" }
if (@($report | Where-Object { $_.action -eq 'failed' }).Count) { exit 1 }
