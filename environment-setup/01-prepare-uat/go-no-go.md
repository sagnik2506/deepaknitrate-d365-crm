# Go / no-go: UAT as the base
Proposed criteria (agree them before looking at the results):
| # | Criterion | Result | Met? |
|---|---|---|---|
| 1 | No production component is missing from UAT (or each missing one is accepted or rebuilt) | 31 solutions missing; 58 flows, 21 forms, 9 web resources, 4 tables, 18 plugin steps only in production | No |
| 2 | Every UAT-only item is reviewed (carry, leave behind, or archive) | 120 views, 53 forms, 75 columns, 6 tables, 4 canvas apps, 12 duplicate rules, 114 connection references only in UAT; not reviewed | No |
| 3 | The 5 production solutions with no unmanaged source have an owner and a plan | Sources found (PREPROD, deepakgroupdevdnl); no owner or plan yet | Partly |
| 4 | HotFixCommissionMasterTable decided (60 components needed or not) | Managed pwc package, no editable copy found | No |
| 5 | Content of the Quote and Order Product forms, scripts and plugins in UAT equals production (Level 2) | 8 forms differ; dg_JS/quote/main.js and UpdateFields_Opp_Quote differ | No |
| 6 | Baseline exported, unpacked and committed with a tag | Not started | No |
Result 6 Nov 2026: NO-GO for UAT as it stands (see readiness-report-2026-11-06.md). Decision: pending approval.   Approved by: <roles>
