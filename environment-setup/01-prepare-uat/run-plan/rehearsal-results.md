# Rehearsal of the runner on UAT (6 Nov 2026)
| Test | Expected | Result |
|---|---|---|
| T1 normal run | A Success, then B Success | Passed (A 1.3 min, B 0.2 min in quick mode) |
| T2 forced failure of A | A Failed, B Skipped | Passed (B skipped: run A status is Failed) |
| T3 stop file while A runs | A Stopped, B does nothing | Passed (A Stopped, B Stopped, no hash files written) |
| T4 start time 60 minutes late | A and B Skipped | Passed (reason: outside the agreed window) |
First attempt failed because the test driver did not quote the start times; fixed, rerun passed. Production guard verified: the runner refuses a production URL without -Armed.
