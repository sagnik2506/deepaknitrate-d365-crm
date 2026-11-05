# PowerShell and SQL tools

All scripts that read an environment use the Dataverse Web API with **GET requests only**. They create, change and delete nothing.
They contain **no secrets**. The only secret-like text is the placeholder `'<secret>'` in help examples.

## Sign-in (never put a password or secret in a command or a file)
Preferred: `az login --allow-no-subscriptions --tenant <tenant-id>`, then run the script with `-UseAzCli`.
Alternatives in the older scripts: `-TenantId/-ClientId` plus the secret from the environment variable `DATAVERSE_CLIENT_SECRET` or a hidden prompt, or `-Token`.

## read-only-checks/ (written for the production checks; pause between requests, stop file, time limit, 429 retry)
| Script | Purpose |
|---|---|
| `Check-ColumnInProduction.ps1` | One column: solutions that carry it, platform dependencies, layers, usage counts, row count (number only), solution list |
| `Compare-SolutionComponents.ps1` | Compares one solution between two environments by component and by name, and shows who installed it |
| `Get-PluginStepTable.ps1` | Plugin steps on Quote Product and Order Product (registration only) |
| `Get-ActiveLayerInventory.ps1` | Hardened layer check (Active/unmanaged layers) for chosen tables. Throttled and resumable |
| `README-column-check.txt`, `README-layer-check.txt` | How to run, stop and read the results |

## analysis/ (earlier, broader analysis)
`Invoke-SolutionAnalysis.ps1` (offline, reads an unpacked solution), `Get-TableAttributeAudit.ps1`, `Get-MoneyFieldUsage.ps1`,
`Get-CurrencyGateCheck.ps1`, `Get-TableColumnCounts.ps1`, `Get-DataverseUsage.ps1`, `Search-FieldUsage.ps1`.

## ../sql/
`field-usage-analysis.sql` and `production-data-check-candidates.sql`: count-only checks, run against the TDS (SQL) endpoint after approval.

## Rules
1. Run against production only after hours, with a pause of at least 1 second between requests (`-DelayMs 1000`).
2. Do not commit the output folders (`column-check-results`, `layer-results`, `compare-results`) or any CSV. `.gitignore` blocks them.
3. Scripts that read record counts do so as numbers only. Do not export record data.
4. `pwsh -File` passes comma lists as one string; the scripts split them, but quote them if in doubt.
