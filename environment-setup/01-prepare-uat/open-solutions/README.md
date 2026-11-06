# Open solutions
Updated 2026-11-06. Sources found by reading names, versions and dates only (read-only). Contents have NOT been compared with production yet.
Lead: notes from a developer who worked on the project earlier (treated as a lead, then checked in each environment).

| Solution | Production | Editable source found | Seen in that source | Open point | Owner | Decision | Status |
|---|---|---|---|---|---|---|---|
| Crca6de | unmanaged 1.0.0.0 | PREPROD (unmanaged) | 1.0.0.0, same install date | Compare contents | | | Source found, to verify |
| ENT_AutonumberingSetup | unmanaged 1.0.0.0 | PREPROD (unmanaged) | 1.0.0.0, same install date | Compare contents | | | Source found, to verify |
| OOBProcessesDeactivation | unmanaged 1.0.0.0 | PREPROD (unmanaged) | 1.0.0.0, same install date | Compare contents | | | Source found, to verify |
| LCAssembly | unmanaged 1.0.0.2 | PREPROD (unmanaged) | **1.0.0.1 (one version behind)** | Decide: update PREPROD copy or export 1.0.0.2 from production | | | Open |
| Utility | **managed** 1.0.0.0, publisher pwc | deepakgroupdevdnl (unmanaged) | 1.0.0.0, installed 2026-04-02 (same date as production) | Compare contents; decide if UAT-based environments need it (not in dev, UAT, SIT or PREPROD) | | | Source found, to verify |
| HotFixCommissionMasterTable | 60 components | UAT and SIT list 1 | | Owner decision | | | Open |

The other 26 production solutions missing from UAT have an unmanaged copy in SIT (9) or dev (17): confirm each copy is complete before relying on it.

Correction: an earlier version of this note said the PREPROD copies were managed. They are unmanaged (read 2026-11-06).

## Environments known to the project
| Environment | URL |
|---|---|
| dev | https://deepakgroupdevcrm.crm8.dynamics.com |
| dev DNL (source of Utility) | https://deepakgroupdevdnl.crm8.dynamics.com |
| UAT | https://deepakgroupuat.crm8.dynamics.com |
| SIT | https://orgb244b2a8.crm8.dynamics.com |
| PREPROD | https://deepakgrouppreprod.crm8.dynamics.com |
| PROD | https://deepakcrmprod.crm8.dynamics.com |
