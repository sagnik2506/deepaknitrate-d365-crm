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
