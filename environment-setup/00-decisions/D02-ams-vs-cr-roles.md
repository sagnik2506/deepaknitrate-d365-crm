# D02: Roles of AMS and CR-DEV
Status: Proposed
## Proposal
- AMS is the only environment that changes EXISTING components (forms, scripts, plugins, columns). Its changes ship as patches of the ProductionDeployment family.
- CR-DEV builds the NEW tables and logic in its own solution (publisher cr). Changes to old forms (for example the subgrid) are handed to AMS to ship.
- AMS hotfixes are imported into CR-DEV regularly (forward merge), so CR work sits on top of what is live.
## Open points
Who owns each component (see 04-ways-of-working/ownership-matrix.md). What happens when a CR change must touch an old form urgently.
