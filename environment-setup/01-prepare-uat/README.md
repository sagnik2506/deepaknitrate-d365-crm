# Phase 1: Prepare UAT
Output: a go/no-go on UAT as the base, and the baseline in git.

## Steps
1. Freeze UAT (date, who agreed) - `freeze-record.md`.
2. Plan and approve the production reads - `run-plan/`.
3. Compare UAT with production in three layers (below).
4. Review the UAT-only (1,057) and SIT-only (105) work - `uat-only-review/`.
5. Close the open gaps - `open-solutions/`.
6. Record the baseline: export the solutions unmanaged, unpack them into `../../solutions/baseline-uat-freeze/`, commit and tag (baseline-uat-freeze-<date>).
7. Decide go/no-go - `go-no-go.md`.

## The three comparison layers
| Layer | Question | Folder | Night | Status |
|---|---|---|---|---|
| L1 existence | Does production have any customer component UAT lacks? | `L1-existence/` | 1 | Not started |
| L2 solution membership | Which solution carries which component, in UAT and in production? | `L2-solution-membership/` | 1 | Not started |
| L3 content (forms, views, web resources) | Is each component identical, not just present? | `L3-content/` | 2 | Not started |
| L3 content (plugin assemblies, flows, workflows, roles) | Same | `L3-content/` | 3 | Not started |

## Rules
Read-only on production, paced (about 1 to 1.5 seconds per request), after hours, with a stop file and a time limit, spread over several nights with resume. Tell the owner of the shared support account first. Scripts: `../../tools/scripts/parity/`. Raw output stays in `C:\DeepakNitrate\EnvSetup\data\parity\` (never in git).
