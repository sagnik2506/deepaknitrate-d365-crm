# Project summary to date (6 Nov 2026)

## The problem and the answer
Quote Product and Order Product are full (about 440 custom columns each), slow, and a new CR is due.
- **Build the CR on new tables** in its own solution (publisher `cr`), linked by lookup. Not blocked by anything.
- **Do not delete fields to make room.** Only about 16 columns are clean candidates, and a single delete is a release project (see below).
- **Speed comes from other things:** heavy forms, scripts, plugin steps and list-read plugins.

## What the analysis found
| Area | Finding |
|---|---|
| Columns | 877 audited. 16 clean candidates. 250 are hidden money `_base` twins |
| Forms | The DNL and DCTL forms carry about 106 enabled handlers each (about 47 OnLoad). Old copies (New Form, web view, deprecated) carry about 180 more |
| Scripts | `dnl` script: 184 KB, 21 synchronous requests, 9 on form open. `main.js` is the heaviest (265 enabled handlers) |
| Plugins | 35 custom steps on the two tables in production, 16 synchronous updates, 11 sharing `quantity` |
| Restrict Views | 19 of 20 steps enabled. Filters list reads by sales organisation and division. Several defects |
| Layers | 24 Active layers in production. Only 5 are real hand edits. The DNL and DCTL forms have none |
| Environments | UAT matches 87% of production's solutions, SIT 20%, preprod 42%, dev 23%. Authoring is split across dev, SIT and UAT |

## What was built
- Step 1 script (`web-resources/.../current/main_dnl.js`): 4 quote reads become 1; blocking requests on load go from 9 to 6. Tested locally only, not uploaded anywhere.
- Excel workbooks: layer decisions (with runbooks) and the solution sync matrix (five environments).
- Read-only PowerShell scripts for production checks, and this repository.

## Where things stand
- Nothing has been changed in any environment. All production work was read-only.
- Open items:
  - 5 production solutions with no unmanaged source, and `HotFixCommissionMasterTable` (60 components in production, 1 in UAT and SIT).
  - The calculated column `dg_remarksforshortclose` has a hand-edited formula.
  - The step 1 script still needs a UAT test.

## Why deleting a field is complex now
1. Patches cannot delete: a managed component is removed only by upgrading the owning solution.
2. A field has several owners: `dg_testfob` is in 5 solutions in dev, 7 in UAT, and has 3 managed layers in production.
3. Whole tables are carried by `DNL_Base_Entities`, whose source is not in dev.
4. Sources are scattered across three unmanaged environments (dev, SIT, UAT).
5. No environment can rehearse a managed upgrade (UAT is unmanaged, preprod is stale, dev is another lineage).
6. Hand edits (Active layers) hide solution changes.
7. Hidden uses (personal views, reports, Power BI, integrations) cannot be fully searched.
8. The delete is permanent (production holds about 54,800 quote lines).
9. The release train is busy (four patches in four days).
What would simplify it: one authoring environment with the source in git, one solution family, a managed UAT and refreshed preprod, and a pipeline.

## Next steps
1. Upload the step 1 script in UAT, run the test cases, then ship it as a patch.
2. Start the CR on new tables, using the DNL or DCTL form for the subgrid.
3. Take the sync gaps to the PWC and release team.
