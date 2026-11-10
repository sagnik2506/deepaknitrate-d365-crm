# Pipelines: create and baseline UAT-ALIGN

Azure DevOps pipelines for the steps A5 to J3 of the baseline plan (`environment-setup/01-prepare-uat/UAT-Baseline-Plan-2026-11-09.xlsx`).
Scope: create the working copy of UAT (UAT-ALIGN), align it with production, verify it and baseline it. The production clone and the AMS and CR-DEV environments are not covered.

**Status: written and checked offline, not yet run in Azure DevOps.** The YAML parses, the PowerShell scripts parse, and the guard, acceptance gate, source check, content normalisation and
comparer were tested on saved data (see "What was tested"). Nothing has been run against an environment through these pipelines. Run them first on UAT-ALIGN only, with the dry-run options.

## Folder map

| Folder | What is in it |
|---|---|
| `pipelines/uat-align/` | The eight pipelines (YAML), numbered in the order they are used |
| `pipelines/templates/` | Shared steps: `setup.yml` (checkout, CLI, Python, Azure CLI sign-in), `pwsh.yml` (a PowerShell step with the service principal), `parity-read.yml` (the three comparison layers) |
| `pipelines/config/` | Data that drives the pipelines (JSON, generated from the workbook): environments, order of exports and imports, production baseline, acceptance criteria, approvals |
| `tools/scripts/pipeline/` | The PowerShell and Python scripts the pipelines call, and `make_pipeline_config.py` that regenerates the config from the workbook |
| `tools/scripts/parity/` | The read-only comparison scripts from the analysis (now with `-Normalise` on the hash script) |
| `solutions/uat-archive`, `solutions/uat-baseline` | Where the pipelines commit unpacked solutions |

## The pipelines

| # | File | Steps | What it does | Changes anything? |
|---|---|---|---|---|
| 00a | `00a-production-watch.yml` | A5 | Daily: compares production solutions with the baseline, fails if they changed | No (read-only) |
| 00b | `00b-environment-copy-and-backup.yml` | A6, B1 | Create UAT-ALIGN and copy UAT into it; backups; prove the copy; turn off cloud flows | Creates UAT-ALIGN (approval) |
| 01 | `01-archive-uat.yml` | B2, B3 | Export UAT solutions, unpack, commit and tag | No (reads UAT) |
| 02 | `02-collect-sources.yml` | D2, D3, D5, D7 | Export the 31 missing solutions from dev, SIT, PREPROD and dev DNL; check them against production; download production files | No (read-only) |
| 03 | `03-import-solutions.yml` | E1 to E6 | Import the 31 solutions in order, stop on failure, verify | UAT-ALIGN only (approval) |
| 04 | `04-align-content.yml` | F1, F2, F6, F9 | Re-import verified sources, web resources, workflow states, option set values; dry run by default | UAT-ALIGN only (approval) |
| 05 | `05-verify.yml` | I1 to I4 | Read production and UAT-ALIGN, compare, acceptance gate | Publish all (approval) |
| 06 | `06-baseline.yml` | J3 | After manual sign-off: export, unpack, tag the baseline | No (reads UAT-ALIGN) |

Order of use: 00a (keep it scheduled), 00b createAndCopy, 00b proveAndSafe, 00b backup (UAT-ALIGN-before-E3), 01, 02, 03, 00b backup (UAT-ALIGN-before-F), 04, 05 (repeat 04 and 05 until it passes), then 06.

## Not scripted yet (do by hand, or add scripts)
F3 plugin assemblies and steps, F4 forms, F5 views, F7 column properties, F8 tables, F10 apps and site maps, F11 other component types, F12 connection references and environment variables.
G (removals, kept manual on purpose), H business units and roles, I5 fix loop, I6 smoke test, I7 Solution Checker, I8 sign-off. The column property, business unit, role, other-type and option set value reads (B6 to B9) are not in
pipeline 05 yet, so the acceptance gate covers existence and content of the main types only (see `acceptance.json` and the note in `Invoke-Acceptance.ps1`).

## One-time setup
1. **Service principals** (Entra app registrations), never the shared support account:
   - `uat-align` : application user with System Administrator in UAT-ALIGN, and a read role in UAT, dev, SIT, PREPROD and dev DNL.
   - `prod-readonly` : a **read-only** role in production only.
   - an admin identity with a tenant-level Power Platform admin role, used only by pipeline 00b through a Power Platform service connection.
2. **Variable groups** (Library): `uat-align-secrets` and `prod-readonly-secrets`, each with `PP_TENANT_ID`, `PP_APP_ID` and `PP_CLIENT_SECRET` (secret, ideally linked to Key Vault).
   `uat-align-admin-settings` with `AdminServiceConnection` (the service connection name), `UatUrl`, `AlignUrl`.
3. **Environments** (Pipelines > Environments) with required approvers: `uat-align-admin`, `uat-align-write`.
4. **Install** the Power Platform Build Tools and the Azure DevOps task `ManualValidation`. Create one pipeline per YAML file. Restrict the service connections and variable groups to these pipelines.
5. **Fill in** `pipelines/config/environments.json` with the URL of UAT-ALIGN after it is created (key `ALIGN`).
6. **Agents:** the full exports and imports exceed the time limits of Microsoft-hosted agents. Use a self-hosted agent, or run in batches (parameter `only` in pipeline 01).

## Safety model
- Environment keys are read from `environments.json`. **Only `ALIGN` is writable.** The helper `Invoke-Dv` refuses any POST, PATCH or DELETE on any other key, and the scripts call `Assert-Writable` first. Production, UAT and the source environments are read only.
- Pipeline 00b has a guard that refuses a target that is not named `UAT-ALIGN` or whose URL equals a known environment. Delete and reset are not in any pipeline.
- Stages that change UAT-ALIGN run in an Azure DevOps Environment with approvals; pipeline 04 defaults to a dry run; web resources are changed only if their name is in `approved-web-resources.json` (empty by default).
- Production reads: one request at a time with a pause, GET only, no business records. 00a and the production reads use the read-only service principal.
- Secrets are passed as environment variables from variable groups. Do not put them in files or logs.

## Config files (pipelines/config)
`environments.json`, `production-baseline.json` (6 Nov 2026 snapshot), `export-order.json`, `import-order.json`, `acceptance.json`, `approved-web-resources.json` (empty), `web-resources-candidates.json`, `web-resources-solutions.json`,
`plugin-assemblies.json`, `option-values.json`, `flow-states.json`. They were generated from the workbook: `python tools/scripts/pipeline/make_pipeline_config.py` (it overwrites the files; keep the approvals).

## What was tested (offline, 10 Nov 2026)
- All YAML files parse; all PowerShell scripts parse; the Python scripts compile.
- The write guard refuses PATCH on PROD and DELETE on UAT; the target guard refuses the wrong name and the production URL.
- The acceptance gate gives FAIL on the real UAT-against-production data, with the numbers we know (for example 58 flows only in production, 43 web resources different).
- The source check (D5) compares component counts of a source with production.
- `-Normalise` on saved content gives the same split as the manual analysis: forms 44 equal and 115 different, views 140 and 247, flows 4 and 112.
- `compare_parity.py` uses the normalised hash when present and still works on old files.

## What was not tested
Any call to Azure DevOps, to the Build Tools admin tasks (their inputs are from the documentation, check them against your installed version), to `pac` with a service principal, to the Dataverse write calls (web resource update,
option set values, workflow state, publish), and the git push from a pipeline. Treat the first runs as trials on UAT-ALIGN, using the dry-run options.
