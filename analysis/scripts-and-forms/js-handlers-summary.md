# Which script file has the most form handlers (Quote Product and Order Product forms)

Source: form XML of the 19 forms in the UAT solution export (C:\DeepakNitrate\UAT\cleanup-unpacked). Local read, no environment touched.
Detail: form-handlers-UAT.csv (every handler: form, event, field, library, function, enabled).

Totals: 935 handler registrations (581 enabled, 354 disabled). Disabled handlers do not run.
Events: onchange 652, onload 231, onsave 50, tabstatechange 2.

## Handlers per script library (all forms; enabled in brackets)

| Library (file) | Registrations | Enabled |
|---|---|---|
| dg_JS/quoteproduct/main.js (WebResources\dg_js\quoteProduct\main.js) | 570 | 265 |
| dg_js/quoteProduct/main/dnl | 124 | 114 |
| dg_orderproduct/main.js | 62 | 46 |
| dg_addCustomViewToFreightMasterLookup | 49 | 43 |
| dg_js/orderproductmain_DNL | 48 | 44 |
| dg_Availablequantity | 26 | 20 |

## The heaviest file: dg_JS/quoteproduct/main.js

- 161,886 bytes, 2,922 lines, about 171 functions, 76 distinct functions registered.
- 570 registrations over 6 forms: 483 OnChange, 56 OnLoad, 31 OnSave (enabled: 194 OnChange, 44 OnLoad, 27 OnSave).
- 59 fields have OnChange handlers. Most-loaded fields: dg_warehouse 23, dg_freightamount 23, dg_cashdiscount 20, and 18 each on
  dg_priceexcludingdiscount, dg_warehousepremium, dg_quotepaymentterms, dg_freightcharges, dg_priceafterdiscount, dg_packagingservices, dg_packaging.
- Functions registered most (enabled): systemPrice 32, calculateExportTotalLineAmount 19, calculatePriceExcludingDiscount 15,
  domesticNetrealizationBenchmarkPriceandDeltaP 12, calTax 12, allCalculations 11, setOrderDealDate 10, rebookesfromfilter 9.
- OnLoad functions registered include getActiveTab, hidePricing, setPriceOverride, rebookesfromfilter, calTax, unlockPayemnetTerm,
  hidePhenolSplitButton, getPricelistType, fetchPaymentDays, getInterestAmount and many one-off functions.
- Patterns found in the file by text search (approximate): Xrm.WebApi 32, XMLHttpRequest 22, Xrm.Page 19, retrieveMultiple 13,
  alert( 5; no XrmServiceToolkit or SDK.SOAP calls inside it (those libraries are loaded separately). Some XMLHttpRequest calls may be synchronous
  (about 21 matches of the "false)" pattern, rough): these must be read in the code.

## Heaviest forms (enabled handlers)

| Form | Total | OnLoad | OnSave | OnChange |
|---|---|---|---|---|
| Quote product_DG_DNL | 107 | 46 | 12 | 49 |
| Quote product_DG_DCTL | 105 | 47 | 9 | 49 |
| New Form (Quote Product) | 94 | 5 | 6 | 83 |
| Quote Product web view | 88 | 8 | 9 | 71 |
| Quote product DG | 52 | 23 | 6 | 23 |
| Order Product_DG_DCTL / _DNL | 36 each | 21 | 0 | 14 |

The "48 OnLoad handlers" figure quoted earlier counted disabled handlers too. Enabled OnLoad is 46 to 47 on the DNL and DCTL forms.

## What to do with it
1. The same functions are registered on many fields: replace them with one function per form (see Part 3 of the guide) so each form
   registers about 3 handlers (OnLoad, OnSave, one OnChange for the pricing fields).
2. Remove the 354 disabled registrations (and the "New Form", "(deprecated)" and "web view" copies after the usual hide-then-delete cycle).
3. Start with dg_JS/quoteproduct/main.js and the DNL and DCTL main forms, then the DNL file (dg_js/quoteProduct/main/dnl, 124 registrations).
4. Check synchronous XMLHttpRequest calls and Xrm.Page use first (19 and about 21 matches).
5. Not covered: the Order form and other tables' forms (for example dg_order\main.js is 179 KB) were not part of this export.
