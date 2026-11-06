# L1 and L2 preliminary findings: UAT against production (6 Nov 2026)

Source: production run A (21:21 to 21:34 IST, 568 GET requests, 0 errors) against the UAT run of the same day, compared offline with `compare_parity.py`.
Preliminary: L3 (content) comes from run B. Nothing here has been compared at content level.

## Headline numbers
| Item | UAT | PROD | In both | Only in UAT | Only in PROD |
|---|---|---|---|---|---|
| Customer solutions | 250 | 281 | 250 | 0 | 31 |
| Tables | 243 | 241 | 237 | 6 | 4 |
| Columns | 6,443 | 6,377 | 6,368 | 75 | 9 |
| Forms | 305 | 273 | 252 | 53 | 21 |
| Views | 567 | 459 | 447 | 120 | 12 |
| Web resources | 277 | 286 | 277 | 0 | 9 |
| Plugin assemblies | 83 | 84 | 83 | 0 | 1 |
| Plugin steps | 289 | 307 | 289 | 0 | 18 |
| Flows and business rules | 261 | 319 | 261 | 0 | 58 |
| Roles | 114 | 116 | 114 | 0 | 2 |
| Global option sets | 170 | 170 | 170 | 0 | 0 |
| Model-driven apps | 7 | 7 | 7 | 0 | 0 |

Of the 250 solutions in both, 172 carry the same components and 78 differ (list in the comparer output, `parity-L2.md`).

## What explains the production-only components
Checked by looking at which production solutions carry each component.
| Type | Only in prod | Carried only by solutions missing from UAT |
|---|---|---|
| Tables | 4 | 4 |
| Forms | 21 | 21 |
| Web resources | 9 | 9 |
| Roles | 2 | 2 |
| Plugin assembly | 1 | 1 |
| Views | 12 | 11 |
| Plugin steps | 18 | 14 |
| Columns | 9 | 4 |
| Flows and business rules | 58 | 17 |

Main carriers: production patches of ENT_SchemaBaseSolution (0d602da3), ENT_ConfigBaseSolution (75265258), ENT_CodeBaseSolution (c4d6a361, 94c07e0e), ENT_SecurityRoleSolution (e43d9f7e).

## Findings
1. **UAT's copy of the ENT base solutions is incomplete.** About 41 production-only flows (mostly business rules for locking and show/hide) and 4 plugin steps sit in solutions that exist in UAT with fewer components (ENT_SchemaBaseSolution, ENT_ConfigBaseSolution). Importing the 31 missing solutions will not close this alone.
2. **Quote Product and Order Product differ in columns.** Only in production: quotedetail.dg_discountnote, quotedetail.dg_freight, salesorderdetail.dg_commission, salesorderdetail.dg_commissionvalue, salesorderdetail.dg_unitprice, salesorderdetail.dg_unitprice_base (the last two sit in DNL_Production_Deployment_Patch_153289be, which exists in UAT with different contents). Only in UAT: salesorderdetail.dg_noofdetentiondays, salesorderdetail.dg_pricereferenceregion.
   Effect: a UAT-based environment would show a different free-column count on these tables than production really has, and new CR columns could clash with production-only names. Fix before any column-limit result from the new environments is trusted.
3. **UAT carries extras production does not have:** 120 views, 53 forms, 75 columns, 6 tables (for example dg_alpanatestentity, dg_customexchangeratemaster, dg_soldtoparty) and portal web forms. Decide whether to clean these before or after the copy.
4. **Same in both:** global option sets and model-driven apps.

## Effect on D01 (UAT as base)
UAT remains usable, but not as is. Before the copy: import the 31 missing solutions (or accept each), bring the ENT base solutions up to production's contents, align the Quote Product and Order Product columns. Provisional rating: go with fixes. Final decision after L3 (run B).
