# L3 preliminary findings: content of UAT against production (6 Nov 2026)

Source: production run B (21:43 to 21:50 IST, 206 GET requests, 0 errors, 1,421 components fingerprinted, 0 not found) against the UAT hashes of the same day. Hash = sha256 of the content, text normalised for line endings and BOM. Preliminary: direction of each difference (which side is newer) is not yet known.

| Type | In UAT | In PROD | Identical | Different | Only in UAT | Only in PROD |
|---|---|---|---|---|---|---|
| Forms | 305 | 273 | 93 | 159 | 53 | 21 |
| Views | 567 | 459 | 60 | 387 | 120 | 12 |
| Web resources | 277 | 286 | 234 | 43 | 0 | 9 |
| Plugin assemblies | 83 | 84 | 74 | 9 | 0 | 1 |
| Flows and business rules | 261 | 319 | 145 | 116 | 0 | 58 |

## Points
1. Scripts: 43 shared web resources differ, including dg_JS/quote/main.js (84,287 bytes in UAT, 72,367 in PROD), dg_JS/salescontract/main.js, dg_SalescontractDNL, dg_OrderSchedulequickcreate, dg_js_sendQuoteProductforDomesticReport, dg_QuoteProduct/main/dpl. The Quote Product scripts checked earlier (dg_js_quoteProduct_main_dnl, main.js) are identical.
2. Plugins: 9 shared assemblies differ: UpdateFields_Opp_Quote (205,312 vs 193,024 bytes; holds the Quote Product update steps), DN.SourceCodePluginAssemply, DNL_Project, DO Cancellation, DiscountDuplicate, Lead Duplication, MultiOrderline_Integration_CRMtoSAP_DCTL, Multi_OrderLine_Creation, Quote_Opp_StatusUpdate.
3. Forms and views are probably over-counted: many forms differ with identical byte sizes and 387 of 447 shared views differ. Suspected cause: generated ids or ordering. To verify on a sample before using these counts.
4. Earlier statement "forms and web resources matched" was too broad. Only the specific scripts checked matched.

## Effect on D01
UAT is not a faithful copy of production code. Rating moves from "go with fixes" to "decision needed". Options: (1) keep UAT and align the differing scripts and plugins with production; (2) create the environments from a minimal copy of production (no business data, but copies configuration; needs approval); (3) hybrid: production-based for AMS, UAT-based for CR-DEV. Next: verify the forms and views noise, find the direction of each script and plugin difference.

## Sample check (6 Nov 2026, 22:0x IST; read-only, 11 items from each of UAT and production, saved locally only)
- Forms (4 sampled, 159 flagged): the only differences are environment-specific security role ids inside display conditions and the display order number. Noise, not real changes.
- Views (3 sampled, 387 flagged): the only difference is the table object type code in the grid element (for example 10841 against 11121). Noise.
  Effect: the forms and views counts above are heavily over-stated. A normalised re-hash (roles ids, order numbers and object type codes stripped) is needed to get the real numbers.
- Scripts (4 sampled, direction found):
  - dg_JS/quote/main.js: UAT has 252 extra lines and 6 functions production lacks (HideTab, ShowTab, ShowTabDNL, ShowTabOnAdmin, LockUnlockFormquote, MSMEindicator); production has 25 lines UAT lacks. UAT is ahead.
  - dg_JS/salescontract/main.js: UAT has 99 extra lines and the function AMSFeilds. UAT is ahead.
  - dg_QuoteProduct/main/dpl: UAT has 38 extra lines and the function setDescriptionDPL. UAT is ahead.
  - dg_cancel: mixed. Production has a remarks-empty check and a debugger line; UAT sets dg_orderschedulecancelflag and has the check removed. Different versions, not a simple ahead or behind.
- Meaning: UAT holds undeployed (or never released) script changes. Taking UAT as the base would carry those into both new environments, so AMS would no longer reflect what is live.

## Full content check of everything that differed (6 Nov 2026, about 22:15 to 22:18 IST; read-only; content saved locally only)
All 714 flagged items were read from both environments (159 forms, 387 views, 116 flows and business rules, 43 scripts, 9 plugin assemblies). Forms and views compared after stripping security role ids, display order numbers and table object type codes. Flows compared after masking all GUIDs.

| Type | Flagged | Noise only | Real difference |
|---|---|---|---|
| Forms | 159 | 44 | 115 (UAT larger 100, PROD larger 11, same size 4) |
| Views | 387 | 140 | 247 (UAT larger 58, PROD larger 179, same size 10) |
| Flows and business rules | 116 | 4 | 112 (UAT larger 55, PROD larger 31, same size 26); 61 have a different active or draft state |

Real form and view differences are still many, so the forms and views are not equal. The nature of those differences (added fields, tabs, columns) has not been read yet.

### Scripts (43 differ)
- Only a debugger line differs: 15. Production has an active `debugger;` statement in 33 of the 43 scripts; UAT has these commented out.
- UAT ahead (new functions or lines, production has nothing extra): 12. Examples: dg_JS/quote/main.js (HideTab, ShowTab, LockUnlockFormquote, MSMEindicator), dg_JS/salescontract/main.js (AMSFeilds), dg_SalescontractDNL (LockFieldsOnSC), dg_SampleRequestDNL (4 functions), dg_PricelistItemJS_DNL_Enddate, dg_QuoteProduct/main/dpl.
- Mixed or other real differences: 28 in total with the above. Behaviour differences seen: dg_createorderlineinsap returns true in UAT and false in production; dg_Order/shortclose uses attribute names dg_reasonforshortclose and dg_remarksforshortclose in UAT but dg_reasonforshortclosing and dg_remarksforshortclosing in production (check which attribute exists in each environment); dg_cancel has a remarks-empty check in production that UAT lacks.

### Plugin assemblies (9 differ; version is 1.0.0.0 in both, so version does not tell which is newer)
UAT was modified later than production for 7 of 9 (for example UpdateFields_Opp_Quote: UAT 16 Feb 2026, production 18 Dec 2025; DNL_Project: UAT 27 Feb 2026, production 28 Jan 2026). MultiOrderline_Integration_CRMtoSAP_DCTL has the same size and was modified the same day in both. Treated as: UAT likely ahead, to be confirmed against source control.

## Conclusion so far
UAT is a mix: ahead of production on several scripts and plugins, behind it on others, and different on many forms, views and flows. It is not a faithful copy of production. Using UAT as is for AMS would not reflect what is live.
