# Parity scripts (planned; written and tested on UAT before any production run)
| Script | Night | Does |
|---|---|---|
| Get-EnvComponentInventory.ps1 | 1 | L1: customer components by type, by name |
| Get-SolutionMembership.ps1 | 1 | L2: component list of each solution, ids turned into names, flag for whole-table carriers |
| Get-ComponentContentHashes.ps1 | 2 and 3 | L3: content hashes of forms, views, web resources, plugin assemblies, flows, workflows |
Common rules: GET only; no record data; pause between requests (parameter); stop file; time limit; retry on 429; resume from a checkpoint file; output to a local folder outside git; a summary printed at the end (requests, time, errors).
Run on UAT first, then production, as laid out in `environment-setup/01-prepare-uat/run-plan/schedule.md`.
