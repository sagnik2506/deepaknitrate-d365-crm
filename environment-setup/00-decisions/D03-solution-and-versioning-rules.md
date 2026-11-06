# D03: Solution structure and version numbers
Status: Proposed
## Proposal
- AMS: patches of the newest base of the ProductionDeployment family. One person creates the next version number; check production for the highest installed version first.
- CR-DEV: its own solution(s) and publisher (cr). New tables only. Export managed.
- Authoring environments are unmanaged. Packages that move to preprod and production are managed, built once.
- Every export is unpacked into the solutions folder of this repository and committed.
## Open points
Which base the patches belong to (the family currently has 36 patches under ProductionDeployment). Whether to start a new clean family later (see analysis/environment-sync/).
