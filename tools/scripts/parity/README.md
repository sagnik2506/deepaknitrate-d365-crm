# Parity scripts (tested on UAT)
Read-only comparison of the customer components of two environments. GET requests only; no business records read (configuration content is read, only fingerprints saved); pause after every request; stop file; time limit; token renewal; retry on 429.

| Script | Run | Does |
|---|---|---|
| `ParityCommon.ps1` | (helper) | Shared requests, pacing, stop and time limits, hashing |
| `Get-SolutionMembership.ps1` | A | L2: component list of each customer solution (`membership.csv`) |
| `Get-EnvComponentInventory.ps1` | A | L1: names of customer tables, columns (prefixes dg_ and cr_), forms, views, web resources, plugin assemblies and steps, flows, roles, option sets, apps |
| `Get-ComponentContentHashes.ps1` | B | L3: content fingerprints of forms, views, web resources, plugin assemblies, flows (resumable) |
| `Run-ParityOvernight.ps1` | A and B | Runs the above as two timed runs with automatic checks and status files |
| `compare_parity.py` | after | Offline comparer of two result folders: parity-L1/L2/L3 reports |

## Tested on UAT (6 Nov 2026)
- Membership: 252 requests in 1.9 minutes. Inventory: 286 requests in 2.9 minutes. Content hashes, all components: 194 requests in 2.1 minutes, about 22 MB read.
- Comparer: UAT against itself identical; UAT against an altered copy found every planted difference.
- Runner rehearsal, four tests: normal run (A and B succeed); forced failure of A (B skipped); stop file during A (A and B stopped, no hashes written); start time more than 30 minutes late (both skipped).
- Two bugs found and fixed during testing: a table filter that was too broad, and a variable clash with the shared state.

## The runner and its automatic checks
Before each run: stop file absent; start time not more than 30 minutes past; sign-in works; at most 10 system jobs running; no solution import open from the last 6 hours; for run B, run A wrote status Success with sensible counts. A failed check means the run is skipped and the reason is logged.
Production (a URL containing deepakcrmprod) is REFUSED unless `-Armed` is given.

Arm it (only after the notice is sent, the windows are approved and UAT is frozen), times in IST:
`pwsh -File Run-ParityOvernight.ps1 -TargetUrl https://<production>.crm8.dynamics.com -TargetName PROD -OutDir <local data folder> -StartA "2026-11-06 20:00" -StartB "2026-11-07 00:00" -Armed`
Stop at any time: create the stop file (default `C:\DeepakNitrate\EnvSetup\STOP-PARITY.txt`).
Results and status files go to the local folder, never to git.
