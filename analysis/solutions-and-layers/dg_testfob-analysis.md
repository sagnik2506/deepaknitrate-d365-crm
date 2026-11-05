# Analysis: removing dg_testfob from Quote Product (quotedetail)

Prepared 5 November 2026. Everything here comes from READ-ONLY checks of dev, UAT, preprod and (section 0) production.
Nothing has been changed in any environment.

## 0. Production result (read-only run on 5 Nov 2026, 19:07, 37 requests in 1.6 minutes, no throttling)

| Check | Production |
|---|---|
| Column | Text, calculated, **managed**, created 30 Oct 2023 |
| Layers (bottom to top) | 1 ENT_SchemaBaseSolution, 2 ENT_SchemaBaseSolution_Patch_aaf85fee, 3 DNL_Base_Entities. **No Active layer.** Same as preprod |
| Solution listed as containing it | ENT_SchemaBaseSolution_Patch_aaf85fee v1.8.51.0 (managed) |
| Platform dependencies | 0 |
| Forms, system views, plugin filters, flows/workflows/rules, charts, mappings | 0 |
| **Personal views that mention it** | **1: "QP Field1"** (owner not read; needs a look) |
| Rows with a value | **0** (of about 54,794 quote product rows, platform estimate) |
| ENT_SchemaBaseSolution | v1.8.0.0 managed + 11 patches: 1.8.1, 7, 8, 13, 14, 17, 18, 19, 47, 50, 51 (identical list to preprod) |
| DNL_Base_Entities | v1.0.0.0 managed, 2,037 components (identical count to preprod), carries quotedetail and salesorderdetail whole |

What it means: production matches preprod exactly for this column, so a preprod rehearsal is representative.
The only new item is the personal view "QP Field1". A personal view does not block the delete, but it would break.
Ask its owner, and decide whether to remove the column from it first.
Full text: column-check-results\column-check-report.txt and solutions.csv in the parent folder.

Environments used
- Dev: https://deepakgroupdevcrm.crm8.dynamics.com
- UAT: https://deepakgroupuat.crm8.dynamics.com
- Preprod: https://deepakgrouppreprod.crm8.dynamics.com
- Production (pending): https://deepakcrmprod.crm8.dynamics.com

## 0b. DNL_Base_Entities: UAT vs production, and who installed it (read-only, 5 Nov 2026)

Who: created and installed by **a PWC consultant** (name and email left out of this repository), on **28 Jan 2025**, in both UAT
(06:18, unmanaged; last modified 14:53) and production (17:10, managed). Publisher "pwc", prefix dg.
Preprod shows the identical install time to the second (17:10:07), which suggests preprod was created as a copy of
production. UAT is almost certainly the environment where DNL_Base_Entities was authored and exported as managed.

Internal IDs of the tables and columns DIFFER between UAT and production (only 25 of 120 tables match by ID), so the
comparison is by NAME. Forms (149), views (206), flows (15) and security profiles (5) match by ID.

| By name | Result |
|---|---|
| Tables | 120 in both. 3 only in UAT: msdyn_recurringsalesaction, msdyn_recurringsalesactionv2, msdyn_saruninstance |
| Listed columns | 1,122 in both. **463 only in UAT**, **1 only in production** |
| Where the 463 UAT-only columns are | contact 233, invoice 83, dg_competitoranalysis 22, msdyn_segment 19, dg_bankmasterdnl 17, dg_batchnumber 16, uom 13, others small |
| Quote Product / Order Product | 0 listed columns on either side. Both tables are carried WHOLE (behavior 0), so an export carries every column that exists on them in UAT |
| Forms / views only in UAT | 14 forms, 81 views (nothing is only in production) |
| The 1 column only in production | dg_samplerequest.dg_ordertype (Choice). In production it has 6 layers: HotFixCommissionMasterTable, DNL_Base_Entities, DNL_Production_Deployment_Patch_556d165d, DNL_Production_Deployment_Patch_e6b73950, ProductionDeployment_Patch_a56bbcf4, ProductionDeployment_Patch_24df1d26. Other solutions carry it too, so dropping it from DNL_Base_Entities would not delete it, but it must be checked |

What it means for "rebuild the source from UAT" (option 1)
1. Evidence supports it: the same person built both, UAT is the likely source, and an earlier import of this same
   solution into production worked even though the internal IDs differ.
2. Do NOT export UAT as it stands. It would add 463 columns, 3 tables, 14 forms and 81 views that production does not have.
3. Trim first (option 2): remove from the UAT solution (remove, never delete) the 3 tables, the 463 columns and the extra
   forms and views; confirm dg_samplerequest.dg_ordertype stays listed; then remove dg_testfob handling (the column is
   carried by the whole tables, so it is removed by deleting the column in UAT itself); raise the version to 1.0.1.0.
4. Because the tables are carried whole, deleting the column in UAT is what removes it from the new version.
5. Also: production has other solution families (DNL_Production_Deployment_Patch_*, ProductionDeployment_Patch_*,
   HotFixCommissionMasterTable). Check them before any column removal.
6. Relationships (555 vs 387) and global option sets (30 vs 30) were not compared by name yet.
Note: the files in compare-results from the first run compare by internal ID and are misleading; use the figures above.

## 1. The column

| Item | Value |
|---|---|
| Table / column | quotedetail / dg_testfob, label "test fob" |
| Type | Text (4000), not required |
| Source | Calculated column (formula could not be read through the API: read it in the maker portal) |
| Related column | dg_fobprice (Currency) is separate |

## 2. Usage results

| Check | Dev | UAT | Preprod | Production |
|---|---|---|---|---|
| Platform dependencies (delete check) | 0 | 0 | 0 | pending |
| Forms, system views, personal views | 0 | 0 | 0 | pending |
| Plugin step filters | 0 | 0 | 0 | pending |
| Flows, workflows, business rules, charts, mappings | 0 | 0 | 0 | pending |
| Script web resources (10,795 scanned) | 0 | not scanned | not scanned | not scanned |
| Rows with a value | 0 of 2,867 | 0 of 0 | 0 of 0 | pending |

## 3. Who carries the column (this decides the removal route)

| Environment | Managed | Solutions / layers |
|---|---|---|
| Dev | No | 5 solutions: ENT_SchemaBaseSolution_Patch_aaf85fee (1.8.51.0), EntitiesSolution, DivDevelopments, SalesModuleEntities_Patch_d85e817d, SalesModuleEntities_Patch_84e9719f |
| UAT | No | 7 solutions (all unmanaged): the dev ones except the ENT patch, plus DNL_Development, DNLDeveelop, Crf7680. Layers: Active only |
| Preprod | Yes | Layers (bottom to top): ENT_SchemaBaseSolution, ENT_SchemaBaseSolution_Patch_aaf85fee, DNL_Base_Entities |
| Production | ? | Pending: expected to mirror preprod |

## 4. Solution family findings

- ENT_SchemaBaseSolution (dev): v1.8.0.0 base + 51 patches (1.8.1.0 to 1.8.51.0), 1,625 base components.
  Patches 1.8.47.0 (948 columns), 1.8.51.0 (315 columns), 1.8.49.0 (111) and 1.8.48.0 (73) are the big ones.
  Patch 1.8.46.0 is empty. Many patches hold 1 to 2 components.
- In the ENT family all 189 real custom columns of quotedetail are present. 43 real custom columns of salesorderdetail
  (e.g. dg_accepteddos, dg_deliveryorders, dg_city, dg_country, dg_crmorderid, dg_discountmt) are NOT in it.
- UAT carries ENT_SchemaBaseSolution v1.8.0.0 + 46 patches (unmanaged). Preprod carries it managed with 11 patches
  (1.8.1, 7, 8, 13, 14, 17, 18, 19, 47, 50, 51).
- DNL_Base_* (6 solutions: Entities, Apps, CloudFlows, Plugins, SecurityRoles, WebResources) exist in UAT (unmanaged)
  and preprod (managed), imported 28 Jan 2025, publisher pwc (prefix dg). **They do not exist in dev.**
  DNL_Base_Entities carries quotedetail and salesorderdetail as WHOLE tables (include all columns), so it carries
  dg_testfob. It has 2,766 components in UAT and 2,037 in preprod.

## 5. What this means

1. A patch cannot delete a column. Removal needs an UPGRADE of every managed solution that carries the column.
2. In preprod (and probably production) the column has three managed layers. Upgrading ENT_SchemaBaseSolution alone
   leaves it in place, because DNL_Base_Entities still carries it.
3. DNL_Base_Entities has no source in dev. The team that built it must issue a new version without the column.
4. UAT is unmanaged: deleting the column there is a plain delete and does not rehearse the managed upgrade.
   Preprod is the rehearsal environment.
5. Two solution families overlap on the same tables. This will repeat for every column removal. Decide on one model.

## 6. Process (not started; do not run until the production check is read)

Phase 1, confirm (no changes)
1. Read the column's formula in dev. Ask the owner whether "test fob" is used.
2. Find the owner and source environment of DNL_Base_* (DNL team).
3. Decide whether the extra UAT solutions (DNL_Development, DNLDeveelop, Crf7680, EntitiesSolution, DivDevelopments,
   SalesModuleEntities patches) are still needed.
4. Run Check-ColumnInProduction.ps1 in production (read-only). See README-column-check.txt.

Phase 2, change in dev
5. Back up: export ENT_SchemaBaseSolution and its patches.
6. Clone ENT_SchemaBaseSolution to roll the 51 patches into one version (for example 1.9.0.0).
7. Delete dg_testfob in dev. Fix any dependency the delete lists.
8. DNL team: new version of DNL_Base_Entities without the column.
9. Run Solution Checker. Open Quote Product forms.

Phase 3, ship
10. Export both solutions as managed.
11. Preprod: Stage for upgrade, then Apply upgrade. Confirm the column is gone from all three layers. Record timings.
12. Production: same, in a change window, after a full backup. Applying the upgrade deletes the column AND its values.
13. UAT: delete directly or import the same upgrade.

Estimates for production (planning only; measure in preprod first)
- Read-only check script: about 1 to 3 minutes, negligible impact.
- Upgrade import of the base: 20 to 60 minutes; DNL_Base_Entities: 30 to 90 minutes; apply upgrade: 10 to 40 minutes.
  Window of 2 to 4 hours, after hours. Highest impact during apply (table metadata change, cached forms rebuilt).

## 7. Open items
- Formula of dg_testfob (maker portal).
- Owner confirmation that "test fob" is unused.
- Source of DNL_Base_* and one-family decision.
- Production check result (pending).
- Reports, Power BI and integrations could not be searched.
- Active layers on Quote Product forms in production (Part 5 of the guide).

## 8. Files in this folder
- Analysis\dev-solution-check\solution-components.csv (every component of the base and its 51 patches, dev)
- Analysis\dev-solution-check\two-tables-columns-by-solution.csv (quotedetail and salesorderdetail columns by solution, dev)
- Analysis\uat-security-check\ (UAT business units, roles and Read depth on Quote and Order;
  note: bu-users-roles.csv is incomplete, it is missing the root business unit row. 817 of 829 UAT users sit in the root unit.)
- Analysis\uat-test-run-of-script\ (the script's test run against UAT, not production)
