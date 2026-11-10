# Environment setup: two authoring environments from UAT

Goal: create two environments from a minimal copy of UAT (no records), one for **AMS** (maintenance changes to what is live) and one for **CR-DEV** (new CR development), and make them the authoring environments going forward.

## Phases and status
| Phase | Folder | What it delivers | Status |
|---|---|---|---|
| 1 | `01-prepare-uat/` | UAT frozen, compared with production, gaps closed, go/no-go, baseline in git | Not started |
| 2 | `02-create-environments/` | The two environments created from the same UAT snapshot, access restricted | Not started |
| 3 | `03-make-usable/` | Integrations off, users and roles, test data, smoke tests passed | Not started |
| 4 | `04-ways-of-working/` | Ownership, forward merge, versioning, source control, release path agreed | Not started |

Update the Status column as work moves (Not started, In progress, Done, Blocked) and tag the repo at each milestone.

## Folders
- `00-decisions/` one short note per decision (use `templates/decision-template.md`).
- `templates/` decision note, change record, checklist.
- `01-` to `04-` the phase folders.
- `../solutions/` the unpacked solutions: the UAT baseline, then AMS and CR.

## Rules
1. Raw data (CSV, exports, logs, screenshots) stays in the local working folder `C:\DeepakNitrate\EnvSetup\`, never in git.
2. No secrets, no personal details. Use `<placeholder>` for tenant ids and accounts.
3. Each phase ends with a checklist ticked and a short note saying done or not done.
4. Nothing here changes production. Production access stays read-only until a release is approved.

## Background (already done)
- Solution comparison across dev, UAT, SIT, preprod and production: `analysis/environment-sync/`.
- Layers in production: `analysis/solutions-and-layers/`.
- Status: `analysis/status/project-summary-2026-11-06.md`.

## Automation
Azure DevOps pipelines for creating and baselining the working copy of UAT (UAT-ALIGN): see `pipelines/README.md`.
