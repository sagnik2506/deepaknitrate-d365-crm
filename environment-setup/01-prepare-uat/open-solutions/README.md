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
| HotFixCommissionMasterTable | **managed** 1.0.0.15, publisher pwc, 60 components | **none found.** PREPROD has the same managed 1.0.0.15 (60 components). UAT, SIT, deepakgroupdevdnl, deepakgroupdevdpl and deepakdevdeploy hold only a 1-component shell (one plugin assembly; 1.0.0.0, or 1.0.0.15 in the last two). Not in dev. | Managed package from pwc: get the unmanaged source from pwc, or import managed 1.0.0.15 if the new environments need it. Compare the 60 components with what UAT already holds and check production usage | | | Open |

The other 26 production solutions missing from UAT have an unmanaged copy in SIT (9) or dev (17): confirm each copy is complete before relying on it.

Correction: an earlier version of this note said the PREPROD copies were managed. They are unmanaged (read 2026-11-06).

## All environments in the tenant (read 2026-11-06, discovery service, read-only)
17 environments. Read: dev, deepakgroupdevdnl, UAT, SIT, PREPROD, PROD, plus 9 more. Not readable by the shared account (403): JSPAPPS, MIQA.NDS DNL's Environment.
None of the Crca6de, ENT_AutonumberingSetup, LCAssembly, OOBProcessesDeactivation or Utility solutions exists in the 9 additional environments. HotFixCommissionMasterTable exists as a 1-component shell in deepakgroupdevdpl and deepakdevdeploy.
Other environments seen (not part of this project as far as known): DPL CRM Dev, DPL CRM Prod, Deepak Phenolics, Microsoft 365, msdyn_viva, Deepak Group (default), DeepakProdClone_DeletionActivity_1.

## Environments known to the project
| Environment | URL |
|---|---|
| dev | https://deepakgroupdevcrm.crm8.dynamics.com |
| dev DNL (source of Utility) | https://deepakgroupdevdnl.crm8.dynamics.com |
| dev DPL | https://org1181c35f.crm8.dynamics.com |
| dev deploy | https://deepakdevdeploy.crm8.dynamics.com |
| UAT | https://deepakgroupuat.crm8.dynamics.com |
| SIT | https://orgb244b2a8.crm8.dynamics.com |
| PREPROD | https://deepakgrouppreprod.crm8.dynamics.com |
| PROD | https://deepakcrmprod.crm8.dynamics.com |
