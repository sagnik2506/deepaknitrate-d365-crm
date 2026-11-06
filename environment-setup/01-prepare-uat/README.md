# Phase 1: Prepare UAT
Output: a go/no-go on UAT as the base, and the baseline in git.

## Steps
1. Freeze UAT (date, who agreed) - `freeze-record.md`.
2. Component-level comparison of UAT against production (tables, columns, forms, views, web resources, plugins, flows, roles) - `parity-uat-vs-prod/`. Level 1 (names, versions) first, then Level 2 (content hashes) on the parts that matter: Quote and Order Product forms and views, dg_ web resources, plugin assemblies.
3. Review the UAT-only (1,057) and SIT-only (105) work - `uat-only-review/`.
4. Close the open gaps - `open-solutions/`.
5. Record the baseline: export the solutions unmanaged, unpack them into `../../solutions/baseline-uat-freeze/`, commit and tag (baseline-uat-freeze-<date>).
6. Decide go/no-go - `go-no-go.md`.

## Rules
Read-only on production, paced (about 1 second per request), after hours, with a stop file and a time limit. Tell the owner of the shared support account first.
