<#
.SYNOPSIS
  Offline test of the pipeline scripts that change UAT-ALIGN, against a local mock of the Dataverse Web API (mock_dataverse.py). No environment is called.
  Checks the paths, bodies and headers the scripts send, the dry run behaviour and the write guard. Run from anywhere: pwsh -File tools/scripts/pipeline/tests/Test-PipelineScripts.ps1
.DESCRIPTION
  The mock is not Dataverse. A pass means the scripts do what they say against a stand-in; it does not prove that Dataverse accepts the calls. Trial runs on UAT-ALIGN are still needed.
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot; $pl = Split-Path $here -Parent; $repo = (Resolve-Path (Join-Path $pl '..\..\..')).Path
$T = Join-Path ([IO.Path]::GetTempPath()) ('pipetest-' + [guid]::NewGuid().ToString('N').Substring(0, 8)); New-Item -ItemType Directory -Force $T | Out-Null
$port = 8765 + (Get-Random -Maximum 200)
$results = New-Object System.Collections.Generic.List[object]
function Check([string]$Name, [bool]$Ok, [string]$Detail = '') { $results.Add([pscustomobject]@{ Test = $Name; Result = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail }) }
function WriteJson($obj, $path) { New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null; ($obj | ConvertTo-Json -Depth 20) | Set-Content $path -Encoding utf8 }

# ---------------------------------------------------------------- config dir (copy of the real one, with approvals filled in for the test)
$cfg = Join-Path $T 'config'; Copy-Item (Join-Path $repo 'pipelines\config') $cfg -Recurse
WriteJson @{ approved = @('10000000-0000-0000-0000-00000000f001', '10000000-0000-0000-0000-00000000f002', '10000000-0000-0000-0000-00000000f099') } "$cfg\approved-forms.json"
WriteJson @{ approved = @('20000000-0000-0000-0000-00000000a001', '20000000-0000-0000-0000-00000000a002') } "$cfg\approved-views.json"
WriteJson @{ approved = @('dg_test.js', @{ name = 'dg_new.js'; solution = 'SolX' }) } "$cfg\approved-web-resources.json"
WriteJson @{ approved = @('MyAsm') } "$cfg\approved-plugin-assemblies.json"
WriteJson @{ approved = @('30000000-0000-0000-0000-00000000b001') } "$cfg\approved-plugin-steps.json"
WriteJson @{ approved = @('dg_t.dg_col') } "$cfg\approved-column-properties.json"
WriteJson @{ items = @(@{ table = 'dg_t'; column = 'dg_col'; property = 'MaxLength'; uatValue = '10'; prodValue = '20' }) } "$cfg\column-properties.json"
WriteJson @{ items = @(@{ optionSet = 'dg_set'; value = 2; uatLabel = ''; prodLabel = 'Two'; status = 'Only in PROD' }, @{ optionSet = 'dg_set'; value = 9; uatLabel = 'Nine'; prodLabel = ''; status = 'Only in UAT' }) } "$cfg\option-values.json"
WriteJson @{ items = @(@{ id = '40000000-0000-0000-0000-00000000c001'; name = 'rule'; table = 'quote'; uatState = 0; prodState = 1 }, @{ id = '40000000-0000-0000-0000-00000000c002'; name = 'cloud'; table = 'quote'; uatState = 0; prodState = 1 }) } "$cfg\flow-states.json"

# ---------------------------------------------------------------- source folder (what Get-ProductionComponents.ps1 would have saved)
$src = Join-Path $T 'prod-components'
WriteJson @(@{ id = 'aaaaaaaa-0000-0000-0000-000000000001'; name = 'Sales Manager' }, @{ id = 'aaaaaaaa-0000-0000-0000-000000000002'; name = 'Ghost Role' }) "$src\roles.json"
New-Item -ItemType Directory -Force "$src\forms", "$src\views", "$src\webresources", "$src\plugins", "$src\steps" | Out-Null
$f1 = '<form><DisplayConditions FallbackForm="false" Order="3"><Role Id="{aaaaaaaa-0000-0000-0000-000000000001}" /><Role Id="{aaaaaaaa-0000-0000-0000-000000000002}" /></DisplayConditions><control datafieldname="dg_new" id="{11111111-1111-1111-1111-111111111111}"/></form>'
$f2 = '<form><DisplayConditions FallbackForm="false" Order="9"><Role Id="{aaaaaaaa-0000-0000-0000-000000000001}" /></DisplayConditions><control datafieldname="dg_a" id="{22222222-2222-2222-2222-222222222222}"/></form>'
[IO.File]::WriteAllText("$src\forms\10000000-0000-0000-0000-00000000f001.xml", $f1); [IO.File]::WriteAllText("$src\forms\10000000-0000-0000-0000-00000000f002.xml", $f2)
[IO.File]::WriteAllText("$src\forms\10000000-0000-0000-0000-00000000f099.xml", $f2)
WriteJson @{ name = 'v1'; table = 'account'; fetchxml = '<fetch a="1"/>'; layoutxml = '<grid object="999"><row/></grid>' } "$src\views\20000000-0000-0000-0000-00000000a001.json"
WriteJson @{ name = 'v2'; table = 'account'; fetchxml = '<fetch b="1"/>'; layoutxml = '<grid object="999"><row/></grid>' } "$src\views\20000000-0000-0000-0000-00000000a002.json"
[IO.File]::WriteAllBytes("$src\webresources\dg_test.js", [Text.Encoding]::UTF8.GetBytes('new content')); [IO.File]::WriteAllBytes("$src\webresources\dg_new.js", [Text.Encoding]::UTF8.GetBytes('brand new'))
[IO.File]::WriteAllBytes("$src\plugins\MyAsm", [byte[]](1, 2, 3, 4))
WriteJson @(@{ kind = 'webresources'; name = 'dg_test.js'; file = 'webresources\dg_test.js' }, @{ kind = 'webresources'; name = 'dg_new.js'; file = 'webresources\dg_new.js' }, @{ kind = 'plugins'; name = 'MyAsm'; file = 'plugins\MyAsm' }) "$src\index.json"
WriteJson @{ id = '30000000-0000-0000-0000-00000000b001'; name = 'My.Plugin: Update of quote'; description = 'd'; stage = 40; mode = 0; rank = 1; filteringattributes = 'a,b'; supporteddeployment = 0; asyncautodelete = $false; configuration = 'cfg'; statecode = 1
    pluginType = 'My.Plugin'; message = 'Update'; entity = 'quote'; solutions = 'SolY; SolZ'; images = @(@{ name = 'pre'; entityalias = 'pre'; imagetype = 0; attributes = 'a'; messagepropertyname = 'Target'; description = '' }) } "$src\steps\30000000-0000-0000-0000-00000000b001.json"

# ---------------------------------------------------------------- mock state
$state = @{
    roles = @{ r1 = @{ roleid = 'bbbbbbbb-0000-0000-0000-000000000001'; name = 'Sales Manager'; _parentroleid_value = $null } }
    systemforms = @{ '10000000-0000-0000-0000-00000000f001' = @{ name = 'f1'; objecttypecode = 'quote'; formxml = '<form><DisplayConditions FallbackForm="false" Order="5"><Role Id="{bbbbbbbb-0000-0000-0000-000000000001}" /></DisplayConditions></form>' }
                     '10000000-0000-0000-0000-00000000f002' = @{ name = 'f2'; objecttypecode = 'quote'; formxml = '<form><DisplayConditions FallbackForm="false" Order="1"><Role Id="{bbbbbbbb-0000-0000-0000-000000000001}" /></DisplayConditions><control datafieldname="dg_a" id="{99999999-9999-9999-9999-999999999999}"/></form>' } }
    savedqueries = @{ '20000000-0000-0000-0000-00000000a001' = @{ name = 'v1'; returnedtypecode = 'account'; fetchxml = '<fetch a="0"/>'; layoutxml = '<grid object="123"><row/></grid>' }
                      '20000000-0000-0000-0000-00000000a002' = @{ name = 'v2'; returnedtypecode = 'account'; fetchxml = '<fetch b="1"/>'; layoutxml = '<grid object="123"><row/></grid>' } }
    webresourceset = @{ wr1 = @{ webresourceid = 'wr1'; name = 'dg_test.js'; content = 'b2xk' } }
    pluginassemblies = @{ pa1 = @{ pluginassemblyid = 'pa1'; name = 'MyAsm'; version = '1.0.0.0'; content = 'old' } }
    attributes = @{ 'dg_t.dg_col' = @{ '@odata.context' = 'x'; '@odata.type' = '#Microsoft.Dynamics.CRM.StringAttributeMetadata'; LogicalName = 'dg_col'; MaxLength = 10; RequiredLevel = @{ Value = 'None' } } }
    optionsets = @{ dg_set = @{ Name = 'dg_set'; Options = @(@{ Value = 1 }, @{ Value = 9 }) } }
    workflows = @{ '40000000-0000-0000-0000-00000000c001' = @{ name = 'rule'; category = 2; statecode = 0 }; '40000000-0000-0000-0000-00000000c002' = @{ name = 'cloud'; category = 5; statecode = 0 } }
    plugintypes = @{ pt = @{ plugintypeid = 'pt1'; typename = 'My.Plugin' } }; sdkmessages = @{ m = @{ sdkmessageid = 'm1'; name = 'Update' } }; sdkmessagefilters = @{ f = @{ sdkmessagefilterid = 'f1'; primaryobjecttypecode = 'quote' } }; sdkmessageprocessingsteps = @{}
}
WriteJson $state "$T\state.json"
$logFile = "$T\log.json"
$mock = Start-Process python -ArgumentList @("`"$here\mock_dataverse.py`"", $port, "`"$T\state.json`"", "`"$logFile`"") -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 2
$env:PP_CONFIG_DIR = $cfg; $env:PP_URL_ALIGN = "http://127.0.0.1:$port"; $env:PP_URL_PROD = "http://127.0.0.1:$port"; $env:PP_LOGIN_BASE = "http://127.0.0.1:$port"
$env:PP_TENANT_ID = 'tenant'; $env:PP_APP_ID = 'app'; $env:PP_CLIENT_SECRET = 'secret'
function Run([string]$Script, [string[]]$ScriptArgs) { $o = & pwsh -NoProfile -File (Join-Path $pl $Script) @ScriptArgs *>&1; $rc = $LASTEXITCODE; if ($rc -ne 0) { Write-Host "--- $Script exit $rc"; Write-Host ($o | Out-String) }; return $rc }
function ReadLog { if (Test-Path $logFile) { return @(Get-Content $logFile -Raw | ConvertFrom-Json) } else { return @() } }
try {
    # ---------------- forms
    $rc = Run 'Update-Forms.ps1' @('-SourceDir', $src, '-DryRun', '-ReportFile', "$T\forms-dry.csv")
    Check 'forms dry run exits 0 and writes nothing' ($rc -eq 0 -and (@(ReadLog | Where-Object { $_.method -eq 'PATCH' }).Count -eq 0))
    $d = Import-Csv "$T\forms-dry.csv"
    Check 'forms dry run: f001 update, f002 same, f099 missing' (($d | Where-Object { $_.id -like '*f001' }).action -eq 'update' -and ($d | Where-Object { $_.id -like '*f002' }).action -eq 'same' -and ($d | Where-Object { $_.id -like '*f099' }).action -eq 'missing in target')
    $rc = Run 'Update-Forms.ps1' @('-SourceDir', $src, '-ReportFile', "$T\forms.csv")
    $p = @(ReadLog | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*systemforms*' })
    Check 'forms: one PATCH (only the form that differs)' ($rc -eq 0 -and $p.Count -eq 1)
    if ($p.Count -eq 1) {
        $x = [string]$p[0].body.formxml
        Check 'forms: role id translated by role name' ($x -like '*bbbbbbbb-0000-0000-0000-000000000001*' -and $x -notlike '*aaaaaaaa-0000-0000-0000-000000000001*')
        Check 'forms: unknown role dropped and reported' ($x -notlike '*aaaaaaaa-0000-0000-0000-000000000002*' -and ((Import-Csv "$T\forms.csv" | Where-Object { $_.id -like '*f001' }).note -like '*Ghost Role*'))
    }
    Check 'forms: tables published' (@(ReadLog | Where-Object { $_.path -like '*PublishXml' }).Count -ge 1)
    # ---------------- views
    $rc = Run 'Update-Views.ps1' @('-SourceDir', $src, '-ReportFile', "$T\views.csv")
    $p = @(ReadLog | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*savedqueries*' })
    Check 'views: one PATCH (a002 differs only by object code and is left alone)' ($rc -eq 0 -and $p.Count -eq 1)
    if ($p.Count -eq 1) { Check 'views: target object type code kept' ([string]$p[0].body.layoutxml -like '*object="123"*' -and [string]$p[0].body.layoutxml -notlike '*999*') }
    # ---------------- web resources
    $rc = Run 'Update-WebResources.ps1' @('-SourceDir', $src, '-ReportFile', "$T\wr.csv")
    $log = ReadLog
    Check 'web resources: existing one updated by PATCH' ($rc -eq 0 -and @($log | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*webresourceset(wr1)' }).Count -eq 1)
    $po = @($log | Where-Object { $_.method -eq 'POST' -and $_.path -like '*webresourceset' })
    Check 'web resources: missing one created in the named solution as type 3 (JS)' ($po.Count -eq 1 -and $po[0].headers.'MSCRM.SolutionUniqueName' -eq 'SolX' -and [int]$po[0].body.webresourcetype -eq 3)
    Check 'web resources: published' (@($log | Where-Object { $_.path -like '*PublishXml' }).Count -ge 1)
    # ---------------- plugin assembly
    $rc = Run 'Update-PluginAssemblies.ps1' @('-SourceDir', $src, '-ReportFile', "$T\pa.csv")
    Check 'plugin assembly: content updated by PATCH' ($rc -eq 0 -and @(ReadLog | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*pluginassemblies(pa1)' }).Count -eq 1)
    # ---------------- plugin step
    $rc = Run 'Register-PluginSteps.ps1' @('-SourceDir', $src, '-ReportFile', "$T\steps.csv")
    $log = ReadLog; $ps = @($log | Where-Object { $_.method -eq 'POST' -and $_.path -like '*sdkmessageprocessingsteps' })
    Check 'plugin step: created with binds, stage, mode and solution header' ($rc -eq 0 -and $ps.Count -eq 1 -and $ps[0].body.'eventhandler_plugintype@odata.bind' -eq '/plugintypes(pt1)' -and $ps[0].body.'sdkmessagefilterid@odata.bind' -eq '/sdkmessagefilters(f1)' -and [int]$ps[0].body.stage -eq 40 -and $ps[0].headers.'MSCRM.SolutionUniqueName' -eq 'SolY')
    Check 'plugin step: image created and disabled step switched off' (@($log | Where-Object { $_.method -eq 'POST' -and $_.path -like '*sdkmessageprocessingstepimages' }).Count -eq 1 -and @($log | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*sdkmessageprocessingsteps(new-step-id)' }).Count -eq 1)
    # ---------------- column properties
    $rc = Run 'Set-ColumnProperties.ps1' @('-ReportFile', "$T\cols.csv")
    $pu = @(ReadLog | Where-Object { $_.method -eq 'PUT' })
    Check 'column: PUT with the production max length, merge labels header, no @odata.context' ($rc -eq 0 -and $pu.Count -eq 1 -and [int]$pu[0].body.MaxLength -eq 20 -and $pu[0].headers.'MSCRM.MergeLabels' -eq 'true' -and -not ($pu[0].body.PSObject.Properties.Name -contains '@odata.context'))
    # ---------------- option set values
    $rc = Run 'Set-OptionSetValues.ps1' @('-ReportFile', "$T\os.csv")
    $log = ReadLog
    Check 'option set: value 2 added, value 9 kept without -AllowRemove' ($rc -eq 0 -and @($log | Where-Object { $_.path -like '*InsertOptionValue' }).Count -eq 1 -and @($log | Where-Object { $_.path -like '*DeleteOptionValue' }).Count -eq 0)
    $rc = Run 'Set-OptionSetValues.ps1' @('-AllowRemove', '-ReportFile', "$T\os2.csv")
    Check 'option set: value 9 removed with -AllowRemove' (@(ReadLog | Where-Object { $_.path -like '*DeleteOptionValue' }).Count -eq 1)
    # ---------------- flow states
    $rc = Run 'Set-FlowStates.ps1' @('-ReportFile', "$T\fs.csv")
    $pf = @(ReadLog | Where-Object { $_.method -eq 'PATCH' -and $_.path -like '*workflows*' })
    Check 'flow states: business rule activated, cloud flow skipped' ($rc -eq 0 -and $pf.Count -eq 1 -and $pf[0].path -like '*c001*' -and [int]$pf[0].body.statecode -eq 1)
    # ---------------- guard: a non-writable key can never be written
    $env:PP_URL_UAT = "http://127.0.0.1:$port"
    $r = & pwsh -NoProfile -Command ". '$pl\Common.ps1'; try { Invoke-Dv -Key UAT -Path 'systemforms(x)' -Method PATCH -Body @{a=1} } catch { 'blocked: ' + `$_.Exception.Message }" 2>&1
    Check 'guard: PATCH on UAT is refused before any call' (($r -join ' ') -like '*REFUSED*')
} finally {
    if ($mock -and -not $mock.HasExited) { Stop-Process -Id $mock.Id -Force }
}
$results | Format-Table -AutoSize | Out-String | Write-Host
$fail = @($results | Where-Object { $_.Result -eq 'FAIL' }).Count
Write-Host "tests: $($results.Count), failed: $fail"
if ($fail) { exit 1 }
