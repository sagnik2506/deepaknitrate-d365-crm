# Production layer check: Quote Product and Order Product (5 Nov 2026)

## How it was run
| Item | Value |
|---|---|
| Environment | production (read-only) |
| Script | tools/scripts/read-only-checks/Get-ActiveLayerInventory.ps1 (hardened), tables quotedetail and salesorderdetail, prefix dg_ |
| Window (UTC) | 18:25:55 to 18:45:53 on 5 Nov 2026 (20.0 minutes) |
| Requests | 1,015 plus 24 follow-up reads of the Active layers' change lists |
| Pace | 800 ms between requests; no throttling, no errors |
| Before the run | No heavy jobs were running (one platform job, 29 jobs in the last hour, all succeeded) |
| Effect | Nothing was created, changed or deleted. No record data was read. Raw result files stay outside the repository |

## Result
- Components checked for layers: **1,001**. Created directly in production (no managed layer at all): **0**.
- Components with an Active (unmanaged) layer: **24** (17 web resources, 6 Quote Product forms, 1 Order Product column).
- **5 are real edits** (content, form definition or column definition), **15 are technical only** (a file reference), **4 need a closer look**.
- Unmanaged solutions present in production: Crca6de, OOBProcessesDeactivation, ENT_AutonumberingSetup, LCAssembly (their components also count as unmanaged).

## Quote Product forms
| Form | Active layer | Meaning |
|---|---|---|
| Quote product_DG_DNL | **none** | Safe target for the CR subgrid and for trimming |
| Quote product_DG_DCTL | **none** | Safe target for the CR subgrid and for trimming |
| Quote product DG (two forms with this name) | yes, real formxml edits | Managed changes will not show until handled |
| New Form, Quote Product web view, Quote product_DG (deprecated) | yes, change list not readable | Retire candidates. Capture before removing |
| Information | yes, form metadata | Standard form; check |

## Other findings
- **Order Product column dg_remarksforshortclose** has an Active layer that changes max length and the calculated-column formula. A real edit.
- **Web resources:** only 2 hold real content edits in the Active layer (dg_js/ordermain_DNL, dg_PriceListForm). The other 15 carry only a file reference. This includes dg_js/quoteProduct/main/dnl (the step 1 target), which confirms the earlier finding that its Active layer does not block a patch.

## What this means for the plan
1. **The CR subgrid and the step 1 script are not blocked.** Use the DNL or DCTL form for the subgrid. The script patch lands above the content layer.
2. **Trimming forms:** DNL and DCTL can be trimmed through a managed patch. The old forms (the two "Quote product DG", New Form, web view, deprecated) need their Active layer handled first, or should simply be retired.
3. **Handle only what you touch.** Before removing an Active layer, capture its content, compare it with the managed layer below, and keep what is needed.
4. Review the real edits: the two Quote product DG forms, dg_remarksforshortclose, dg_js/ordermain_DNL and dg_PriceListForm.

## Limits
This covers the two tables' components and the web resources they reference. Other tables, flows and plugin steps were not included. For three forms the change list could not be read, so their reading is a judgement. The full table is in the components file.
