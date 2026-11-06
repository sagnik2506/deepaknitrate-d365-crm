# Readiness report: can UAT be the base for the AMS and CR-DEV environments?
Date: 6 Nov 2026. Evidence: read-only comparison of UAT and production (GET only, no business records), plus checks on the other environments. Status: draft for decision.

## 1. Answer
**No-go for UAT as it stands.** UAT is not a faithful copy of production. It is ahead of production on some scripts and plugins, behind it on others, and different on many forms, views, flows, business units and roles. The recommendation is to create both environments from a **minimal copy of production** (configuration and schema, no business records), subject to approval, and keep UAT as the test environment.

## 2. Evidence
### What matches
- Column definitions: 6,368 columns in both, only 22 differ in a property (type never differs).
- Global option sets (170 names, 13 of 901 values differ), model-driven apps (7), field security profiles (30), email templates (49 of 50).
- 74 of 83 shared plugin assemblies and 234 of 277 shared web resources are identical. The Quote Product scripts dg_js_quoteProduct_main_dnl and main.js are identical.
- Quote Product and Order Product custom column counts are close (quotedetail UAT 531, PROD 534; salesorderdetail UAT 505, PROD 506).

### What does not match
| Area | Finding |
|---|---|
| Solutions | 31 production solutions are not in UAT (26 with a copy in SIT or dev, 5 found in PREPROD or the dev DNL environment). HotFixCommissionMasterTable is a managed pwc package with 60 components and no editable copy anywhere. Of 250 shared solutions, 78 carry different components. UAT's copies of ENT_SchemaBaseSolution and ENT_ConfigBaseSolution are incomplete. |
| Scripts | 43 of 277 shared web resources differ: 15 only by a debugger line, 12 where UAT is ahead (new functions), 16 mixed. 9 web resources exist only in production. |
| Plugins | 9 of 83 shared assemblies differ (7 modified later in UAT, including UpdateFields_Opp_Quote). 1 assembly and 18 plugin steps only in production. |
| Forms and views | 115 of 159 flagged forms and 247 of 387 flagged views differ in real content after removing environment ids. Mostly layout, labels and controls, a few in fields and handlers (8 forms have fields only in UAT, 5 only in production). Quote Product and Order Product: 8 forms differ, 2 with field or handler changes. |
| Flows and business rules | 58 only in production, 112 of 116 shared flagged ones differ, 61 with a different active or draft state. |
| Business units | UAT 32, production 33, only 9 names match. The Restrict Views plugin filters by unit names, so it cannot be tested in UAT as it stands. |
| Roles | 313 root roles in both, 34 only in UAT, 2 only in production, 68 with different privileges. |
| Configuration | 11 environment variables have values in production and none in UAT. Production has 119 connection references with a connection set, UAT 21. UAT has 4 canvas apps, 1 connector and 12 duplicate rules production lacks. |
| Columns | Only in production: quotedetail.dg_discountnote, quotedetail.dg_freight, salesorderdetail.dg_commission, dg_commissionvalue, dg_unitprice, dg_unitprice_base. Money precision on salesorderdetail.dg_commissioncurrency differs (UAT 4, production 2). |

### Why the UAT-ahead items matter
UAT holds changes that were never released (for example dg_JS/quote/main.js has 6 functions production lacks). A base taken from UAT would carry them into AMS, which must reflect what is live, and would give a wrong column count for the CR on Quote Product and Order Product.

## 3. Options
| Option | What it means | Effort (rough, to be validated) | Risk |
|---|---|---|---|
| A. UAT as base, aligned to production | Import the missing solutions, reset ENT base solutions, replace differing scripts, plugins, forms, views and flows with production versions, rebuild business units and roles | 4 to 8 weeks of effort, several release cycles | High: rebuilds production by hand, easy to leave drift, unreleased UAT work must be set aside first |
| B. Minimal copy of production for both (recommended) | Copy production without business records into two new environments, then set variables, connections and access | About 3 to 5 working days including checks | Medium: needs approval; managed solutions cannot be edited; integrations and email flows must be kept from firing |
| C. Hybrid: production copy for AMS, UAT for CR-DEV | AMS mirrors live, CR-DEV stays in UAT | 3 to 5 days plus the alignment work for CR-DEV | High for CR-DEV: wrong column counts and business units, so CR results would not hold in production |

## 4. Recommendation
Option B, with these conditions:
1. Written approval that a minimal copy of production (no business records) is acceptable, and confirmation from the platform admin of what a minimal copy carries (users, business units, solutions, settings) before the copy.
2. Before the copy, confirm which production solutions are managed and which are unmanaged, because only unmanaged ones can be edited in the new environments. For managed ones (for example Utility, HotFixCommissionMasterTable) get the unmanaged source (Utility: deepakgroupdevdnl; HotFixCommissionMasterTable: pwc).
3. Triage UAT's unreleased work first (12 scripts and 7 plugins where UAT is ahead, 4 canvas apps, 12 duplicate rules): decide to release, hold or drop each, and keep a copy in source control so nothing is lost.
4. After the copy: set the 11 environment variables, set connections, keep integration and email flows off, remove test access, and check integrations do not point at live systems.

## 5. Fix list (independent of the option)
| # | Item | Notes |
|---|---|---|
| 1 | Active debugger statements in 33 of 43 compared production scripts | Hygiene fix through the AMS environment |
| 2 | 5 open solutions: Crca6de, ENT_AutonumberingSetup, OOBProcessesDeactivation (PREPROD), LCAssembly (PREPROD is one version behind: 1.0.0.1 against 1.0.0.2), Utility (deepakgroupdevdnl) | Compare contents, name an owner |
| 3 | HotFixCommissionMasterTable (pwc, managed, 60 components) | Ask pwc for the source or import managed 1.0.0.15 |
| 4 | 26 solutions missing from UAT | Decide per solution: accept, import or rebuild |
| 4b | 78 shared solutions with different components: about 7 have real differences (ENT_SchemaBaseSolution, ENT_ConfigBaseSolution and its patch 621d4865, DNL_Base_Entities, DNL_FEB_2025, DCTL_Entities_Solution, HotFixCommissionMasterTable), 3 differ only in grouping, and the rest are id noise | See section 9 |
| 5 | dg_Order/shortclose uses dg_reasonforshortclose in UAT and dg_reasonforshortclosing in production; dg_createorderlineinsap returns true in UAT, false in production; dg_cancel remarks check differs | Check which is correct |
| 6 | msdyn_CSIntelligence import stuck since 13 Oct 2026 in production | Not ours, ask an admin to look |
| 7 | Business units, roles, connection references | Not part of a solution; set up per environment |

## 6. Effort and risk register (Task 1, Solution Synchronisation Analysis)
| Area | Effort | Risk if skipped |
|---|---|---|
| Approval and platform admin steps for the copy | 1 day | Copy blocked |
| Copy production (2 environments), verify | 1 day | Low |
| Post-copy configuration (variables, connections, access, integrations off) | 1 to 2 days | Flows and scripts misbehave; integrations may fire |
| Triage UAT unreleased work and archive it | 2 to 3 days | Lost or accidentally released changes |
| Sources for the 5 open solutions and HotFix | 1 to 2 days plus pwc response time | Cannot edit those solutions |
| Align UAT to production afterwards (so UAT can test what AMS builds) | 2 to 4 weeks, can be phased | UAT results do not reflect production |

## 7. Not checked
Local option sets on columns; component types not listed in B8 (such as reports, charts, process stages, ribbons); the nature of the 235 views with differences other than columns and filters; the metadata components inside the 78 shared solutions (columns, relationships and similar), whose ids differ per environment and cannot be matched by name from the saved data; layering of production beyond the 24 Quote Product and Order Product components checked earlier; whether plugin binaries differ in logic (only version and dates compared); capacity, API entitlement and the admin center health score. Task 2 (Currency Field Assessment) needs a production usage run of the money fields and finance and integration input on who reads the _base columns.

## 8. Decisions needed
1. Is a minimal copy of production acceptable (configuration and schema, no business records)?
2. Option B, A or C?
3. Who owns the triage of UAT's unreleased work?
4. Who approaches pwc for the HotFixCommissionMasterTable source?

## 9. The 78 shared solutions with different components (classified 6 Nov 2026)
Method: components were matched by id for types whose ids are the same in both environments (forms, views, flows and business rules, plugin steps, web resources) and by name where the name was available. Application modules, site maps, option sets, roles and plugin assemblies have different ids in each environment even when the name is the same, so they show up as one missing and one extra with the same count; this is noise, not a real difference.
- About 70 of the 78 differ only through that id noise (for example the DNL_Production_Deployment_Patch_* and ProductionDeployment_Patch_* solutions: one app module or site map each).
- About 7 have real differences in components that can be matched:
  - ENT_SchemaBaseSolution: 39 flows and business rules missing from UAT; UAT has 39 forms and 37 views that production does not.
  - ENT_ConfigBaseSolution and its patch 621d4865: 4 plugin steps and 1 plugin assembly missing from UAT.
  - DNL_Base_Entities: UAT has 79 views and 14 forms that production does not.
  - DNL_FEB_2025 (5 views) and DCTL_Entities_Solution (5 views): UAT extras.
  - HotFixCommissionMasterTable: 2 flows, 1 view and 2 apps missing from UAT.
- 3 differ only in grouping (DNL_Production_Deployment_Patch_7278da41, _7fb05e4f, _a873f0a6): the component exists in both environments, in a different solution.
- Not resolvable from the saved data: columns, relationships and other metadata inside the large solutions (DNL_Base_Entities, ENT_SchemaBaseSolution, Production_Deployment_JUNE2026). Their ids differ per environment, so these large counts are mostly noise but could hide real differences. The component-level comparison by name (section 2) is the reliable view for columns.
