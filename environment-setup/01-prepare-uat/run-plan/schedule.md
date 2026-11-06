# Schedule (two runs, times in IST)
| Run | Start | What runs | Environment | Pace | Time cap | Expected (measured on UAT) | Status |
|---|---|---|---|---|---|---|---|
| A | 8:00 PM | L1 existence + L2 membership (Get-SolutionMembership, Get-EnvComponentInventory) | production | 1 s per request | 45 min | about 10 to 15 minutes (570 requests) | Not started |
| B | 12:00 AM (next day) | L3 content: forms, views, web resources, then plugin assemblies and flows | production | 1.5 s per request | 90 min | about 5 to 10 minutes (about 200 requests, about 22 MB) | Not started |

The UAT side was run on 6 Nov 2026 before the production runs (membership, inventory, content hashes for all components).
Automatic checks before each run: stop file absent; start within 30 minutes; sign-in works; at most 10 system jobs running; no open solution import; for run B, run A Success.
Stop: create `STOP-PARITY.txt` in the working folder, or press Ctrl+C. Each script resumes from where it stopped.
Check before the night: the notice is sent, the windows are approved (`approvals.md`), UAT is frozen, this machine stays awake and signed in until about 1 AM.
