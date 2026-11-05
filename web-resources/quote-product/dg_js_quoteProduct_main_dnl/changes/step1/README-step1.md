# STEP 1: shared quote read for dg_js/quoteProduct/main/dnl

Status: DRAFT for UAT. Not uploaded anywhere. Written and tested locally only (syntax check plus a harness with fake data).

## Files
| File | What it is |
|---|---|
| dg_js_quoteProduct_main_dnl.STEP1.js | The new full file to upload to the web resource in UAT (186,086 bytes, sha256 starts 22d5185b2ecf86c7) |
| dg_js_quoteProduct_main_dnl.ORIGINAL-v1.0.0.34.js | Untouched copy of production = UAT (184,264 bytes, sha256 starts 31a31837f15ca8e6). Use it to restore |
| step1.diff | Unified diff, original against step 1 (103 lines removed, 105 added; all inside the STEP1-CHANGE markers) |
| harness\run-harness.js and harness-results.txt | Local old-versus-new test with fake data. Re-run with: node run-harness.js <original> <step1> |
| _build\build_step1.py | How the file was built. It checks that nothing outside the markers changed |

## What changed (search the file for STEP1-CHANGE)
1. New function `dnlGetQuoteData(quoteId, forceRefresh)` (after the 3 global variables at the top): one shared read of the parent quote
   with the 6 columns the four functions need.
2. Four functions use it instead of making their own request, and only that block inside each function changed:
   OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI (the quote read only), OnLoadQuoteStatus.
3. A header comment explaining all of this.
Function names, parameters, order and form registrations are unchanged, so NO form has to change and the patch holds only this web resource.

## Result
- Blocking requests to the same quote on every form open: 4 become 1 (3 round trips saved).
- The read is still synchronous on purpose (see the header of the file): UpdateQuoteProductSalesOrd is the first OnLoad handler and about 49
  handlers after it read dg_division and dg_salesorganization; ShowHideOnFSBI runs before ShowHideFormulaPricing and ppandfs, which also show or hide dg_voc.
- Blocking requests on load across the whole script: 9 become 6. The three price list reads (ShowHideOnFSBI, InterestaarteMandatory, onrevision),
  the product read (filterPackagingTypeDnl) and the commission agent read (commissionagentfilter) are untouched (later steps).

## Harness results (local, fake data): 13 identical, 1 expected difference, 0 unexpected
Identical effects and identical globals (account, productid, quoteid) in: common case, contract quote, new line, new line with no effective-to,
status differs, status empty, divisions 30, 40 and 20, failed read (HTTP 500), network error, empty quote lookup, empty product lookup,
two loads in a row with a changed quote status (refresh after save).
Expected difference (S14): a form where UpdateQuoteProductSalesOrd is NOT registered could show the previous quote status for up to 10 seconds
(DNL_QUOTE_CACHE_TTL_MS). On the DNL and DCTL forms the first handler always forces a fresh read, so this does not apply.
Request counts in the common case: 5 blocking requests become 2 (1 shared quote read plus the unchanged price list read).

## Existing behaviours the file deliberately keeps (flag them to the business)
1. When the quote has no effective-to date, an empty dg_effectivetodnl is set to 1 Jan 1970 (new Date(null)).
2. If the quote read fails, OnLoadQuoteStatus writes an empty value over a non-empty dg_quotestatus.
3. The code throws a TypeError when the quote or product lookup is empty, exactly as today.
4. filterPackagingTypeDnl (not changed) overwrites the packaging type on every load.

## What the harness cannot prove
It simulates the form. It does not run in a browser, does not use the real server, and does not cover the other 45 OnLoad handlers.
The UAT tests in test-cases-step1.md are the real proof.

## Deployment (summary; full plan in the chat)
1. Back up the UAT web resource (the ORIGINAL file here is identical to it). Tell UAT users.
2. Upload STEP1.js over the web resource dg_js/quoteProduct/main/dnl in UAT, save, publish, hard refresh (Ctrl+F5).
3. Run test-cases-step1.md and the performance comparison. Get a business tester's sign-off.
4. Only then create the patch (next version after v1.0.0.36 of ProductionDeployment), add ONLY this web resource, export managed.
5. Import to production in the agreed window, verify the file hash, smoke test, keep the ORIGINAL file for rollback (delete the patch).
