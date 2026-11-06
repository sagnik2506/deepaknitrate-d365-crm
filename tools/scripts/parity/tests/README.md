# Test runners for the parity scripts (UAT only)
Used on 6 Nov 2026 to prove the parity scripts and the overnight runner before any production run. All target UAT; none touches production.

| File | Purpose |
|---|---|
| `run-uat-test.ps1` | First test: inventory, a small content-hash sample, and the comparer against itself and against a deliberately altered copy |
| `run-uat-inventory-retest.ps1` | Re-test of the inventory script after the table-filter and variable-clash fixes |
| `run-uat-full-hashes.ps1` | Full content hashes of all UAT customer components (resumable) |
| `run-rehearsal.ps1` | Four-test rehearsal of Run-ParityOvernight.ps1: normal run, forced failure of A, stop file during A, late start |

## Notes
- Paths are specific to the machine used (C:\DeepakNitrate\EnvSetup and the local repo). Edit them before reuse.
- The environment URL inside is UAT's. Output goes to the local working folder, never to git.
- The rehearsal driver quotes the start times when it starts the runner (a space in the value would otherwise split the argument).
- Results are summarised in `environment-setup/01-prepare-uat/run-plan/rehearsal-results.md`.
