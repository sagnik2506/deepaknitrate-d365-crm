# First-pass review of dg_js/quoteProduct/main/dnl (the 184 KB script)

File: Analysis\dnl-layer-compare\layer24-ProductionDeployment_Patch_23c258e6.js. Identical (same hash 31a31837f15c) to the live production
file and the UAT copy. Read locally; nothing was run. This is a registration and text-pattern review, not a line-by-line code read.
Detail: dnl-functions.csv (one row per function with pattern counts).

## 1. Shape of the file
- 184,264 bytes, 2,936 lines, 110 function blocks. About 80 are real functions; the rest are inner callbacks
  (`req.onreadystatechange` x21, `success` x8).
- Calls go to the modern endpoint (/api/data/v9.2). No deprecated OData v2 (OrganizationData.svc), no XrmServiceToolkit or SDK.SOAP in this file.
- 23 functions use XMLHttpRequest (44 text hits) and 16 uses of Xrm.WebApi.
- CORRECTION (recount): **21 of the 23 XMLHttpRequest calls are SYNCHRONOUS** (`open(..., false)`); only 2 are asynchronous. My first pass counted 1 because the
  search pattern missed calls whose URL contains parentheses. Synchronous calls freeze the form until the server answers.
  Functions with a synchronous call (line of the first): CAalertonsave x2 (2673), ShowHideOnFSBI x2 (500), populatelatestCA x2 (2587),
  NotifyCOnotuse x2 (113), setDescription (398), RefreshFormOnApprovalDnl (1116), populatecontainertype (2506), onrevision (2155),
  OnLoadQuoteStatus (1792), OldQuoteProduct (12), InterestaarteMandatory (1454), FilterWarehouse (1374), filterPackagingTypeDnl (598),
  DisableApprovalStatusDnl (318), commissionagentfilter (2047), UpdateQuoteProductSalesOrd (179), UpdateQuoteProductSalesOrgDPL (2781).
- Of these, **9 synchronous calls sit in 8 functions that are registered on form load** in production: commissionagentfilter, filterPackagingTypeDnl,
  InterestaarteMandatory, OldQuoteProduct, OnLoadQuoteStatus, onrevision, ShowHideOnFSBI (2), UpdateQuoteProductSalesOrd.
  Several use older endpoint versions (v9.1 and v9.2 are both seen).
- Xrm.Page (deprecated) in 8 functions (13 references), for example OldQuoteProduct, oldquote.
- 9 alert/confirm calls. 25 mentions of `debugger`, all inside comments (none active).
- Duplicate function names: `req.onreadystatechange` (21), `success` (8), `setFieldVisibility` (2). The last definition wins for any global name.
  setFieldVisibility is defined twice, so only the second copy runs.

## 2. How it is wired (from the form registrations in the earlier UAT export; confirm on current forms)
- 124 registrations of this library: 55 enabled on Quote product_DG_DNL, 58 on Quote product_DG_DCTL, 1 on Quote product DG.
- 57 distinct functions are registered. Most OnLoad functions are registered twice (once per form).
- OnLoad runs about 36 distinct functions. Many do their own web request on load: OnLoadQuoteStatus, onrevision, InterestaarteMandatory,
  FilterWarehouse, ShowHideOnFSBI, populateindustrytype, commissionagentfilter (synchronous) and others. That is up to about 20 separate requests while
  the form opens.
- OnSave: alertoncommissionandtradepercentage, DisableApprovalStatusDnl, OrderCancel, OnSave.
- OnChange: dg_incoterms has 11 handlers, productid 6, dg_contributionmarginorvalue2 6, dg_commissionorvalue2 6.
- 3 registered functions are NOT defined in the current file: `domesticppfs`, `QuoteProductEffectiveToDate`, `updatefreight`.
  A handler pointing to a missing function raises a script error in the browser console. Check the live forms.
- 26 top-level functions are defined but not registered on these forms. They may be dead code, or called from other scripts and forms.

## 3. The heaviest functions
| Function | Lines | Note |
|---|---|---|
| req.onreadystatechange (line 2161) | 141 | large callback, inside onrevision area |
| ShowHideBasedOnIncoterms | 123 | long show/hide by incoterm |
| ShowHideFormulaPricingDCTL | 116 | DCTL copy of ShowHideFormulaPricing (70 lines) |
| fetchAndSet | 86 | uses Xrm.WebApi |
| PPcostingowner | 81 | |
| manageIncotermsVisibility | 68 | 6 functions deal with incoterms |
| ShowHideOnBasisOfIncoterm | 62 | |
| exworksDCTL (50) and exworks | | DCTL and DNL pair |
| ppandfsDCTL (46) and ppandfs | | DCTL and DNL pair |

By theme (function counts): commission 15, show/hide visibility 14, incoterm 6, costing/PP 6, filter/lookup 5, revision/quote status 4, lock 3, warehouse 2.

## 4. What looks improvable (to confirm in the code)
1. One shared helper for web requests instead of 21 copies of the same XMLHttpRequest boilerplate, using Xrm.WebApi.retrieveMultipleRecords.
2. Batch the OnLoad lookups into one or two requests, and run non-essential ones after the form is shown.
3. Replace the 21 synchronous calls (9 of them on load) with asynchronous ones, starting with the 8 OnLoad functions listed in section 1.
   Where several functions read the same parent record (for example the quote's custom status and contract flag), read it once.
   Lookup filters (commissionagentfilter, FilterWarehouse) can move to a PreSearch handler that runs only when the user opens the lookup.
4. Replace the long ShowHide functions with a small table (field list per incoterm and per division) that one function reads.
5. Merge the DNL and DCTL pairs (ShowHideFormulaPricing and ShowHideFormulaPricingDCTL, exworks and exworksDCTL, ppandfs and ppandfsDCTL), driven by the form or a parameter.
6. Register one OnChange function for the incoterm fields in place of 11 separate handlers, and one OnLoad that calls the others in order.
7. Remove Xrm.Page, the alert/confirm pop-ups and the unused functions, and fix the 3 missing function names.
8. Keep a regression list of the calculated and visible-field results per form (DNL and DCTL) and compare before and after.

## 5. Limits
- Not read line by line. The logic of each function, and what each does with the data, is still unknown.
- The handler list comes from the earlier export, which did not contain the current script. Confirm the registrations on the live forms (a read of the production forms).
- No run times measured. A browser performance trace of a form open would show which requests take the longest.
