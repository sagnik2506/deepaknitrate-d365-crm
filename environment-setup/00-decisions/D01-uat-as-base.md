# D01: UAT as the base for both new environments
Status: Proposed        Owner: <release/tech lead>      Agreed with: <business owner, release owner>

## Context
UAT holds 244 of the 281 production customer solutions at the same version (87%), is unmanaged (so it can author) and has no records. It also holds 1,057 solutions production does not, and 31 production solutions are not in UAT (26 have a copy in SIT or dev, 5 have no unmanaged source). See analysis/environment-sync/.

## Options
1. Minimal copy of UAT into both environments (after the component check and clean-up).
2. Minimal copy of production for AMS (managed, mirrors live, harder to author) and UAT for CR-DEV.
3. Keep working in UAT, SIT and dev as today.

## Decision
<to be filled after Phase 1: go / no-go>

## Consequences
Both environments inherit UAT as it is at the freeze date, including unreleased work. Phase 1 must review it first.
