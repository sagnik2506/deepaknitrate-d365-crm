<#
.SYNOPSIS
  I4: acceptance gate. Reads summary.json written by tools/scripts/parity/compare_parity.py (UAT-ALIGN as side A, production as side B) and applies pipelines/config/acceptance.json.
  Fails (exit 1) when anything exists only in production, when something exists only in UAT-ALIGN beyond the approved count, or when content differs. Does not touch any environment.
#>
param([Parameter(Mandatory)][string]$SummaryFile, [string]$ReportFile = '.\acceptance-report.md')
. "$PSScriptRoot\Common.ps1"
$s = Get-Content $SummaryFile -Raw | ConvertFrom-Json
$cfg = Get-PipelineConfig 'acceptance.json'
$fail = New-Object System.Collections.Generic.List[string]; $lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Acceptance report (step I4)'); $lines.Add(''); $lines.Add('| Check | Result | Value |'); $lines.Add('|---|---|---|')
foreach ($t in $cfg.onlyInProductionMustBeZero) {
    $v = $s.L1.$t; if ($null -eq $v) { continue }
    $ok = ([int]$v.onlyB -eq 0); if (-not $ok) { $fail.Add("$t only in production: $($v.onlyB)") }
    $lines.Add("| $t only in production = 0 | $(if ($ok) { 'PASS' } else { 'FAIL' }) | $($v.onlyB) |")
    $allowed = [int]$cfg.approvedExtrasOnlyInAlign.$t
    $ok2 = ([int]$v.onlyA -le $allowed); if (-not $ok2) { $fail.Add("$t only in UAT-ALIGN: $($v.onlyA) (approved $allowed)") }
    $lines.Add("| $t only in UAT-ALIGN <= $allowed | $(if ($ok2) { 'PASS' } else { 'FAIL' }) | $($v.onlyA) |")
}
foreach ($t in $cfg.differentContentMustBeZero) {
    $v = $s.L3.$t; if ($null -eq $v) { $fail.Add("$t content comparison is missing"); $lines.Add("| $t content differences = 0 | FAIL | no data |"); continue }
    $ok = ([int]$v.different -eq 0); if (-not $ok) { $fail.Add("$t content differs: $($v.different)") }
    $lines.Add("| $t content differences = 0 | $(if ($ok) { 'PASS' } else { 'FAIL' }) | $($v.different) |")
}
$lines.Add(''); $lines.Add($(if ($fail.Count) { "**Result: FAIL** ($($fail.Count) checks)" } else { '**Result: PASS**' }))
$lines.Add(''); $lines.Add('Not covered by this gate: component types matched by id only, plugin step secure configuration, role privileges, business units and the smoke tests (steps I6 to I8).')
$lines | Set-Content $ReportFile -Encoding utf8; $lines | Out-Host
if ($fail.Count) { $fail | ForEach-Object { Add-AdoError $_ }; exit 1 }
