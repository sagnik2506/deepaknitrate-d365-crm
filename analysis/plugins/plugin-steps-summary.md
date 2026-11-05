# Plugin steps on Quote Product (quotedetail) and Order Product (salesorderdetail)

Read-only run, 5 Nov 2026. Registration data only (no plugin code, no run times). Files: plugin-steps-DEV/UAT/PROD.csv
(all steps, incl. Microsoft's own) and plugin-steps-*-custom.csv (your steps, with the table filled in).

| Environment | Custom steps | quotedetail | salesorderdetail | Microsoft's own |
|---|---|---|---|---|
| Dev (deepakgroupdevcrm) | 9 | 7 | 2 | 66 |
| UAT | 37 | 30 | 7 | 63 |
| Production | 35 | 29 | 6 | 64 |

Dev holds far fewer steps than UAT and production: dev is NOT a faithful copy of what runs in production.

## Production, enabled steps (10 more are disabled)

| Table | Message | Stage | Mode | Enabled steps |
|---|---|---|---|---|
| quotedetail | Create | PostOperation | Async | 1 |
| quotedetail | Create | PostOperation | Sync | 3 |
| quotedetail | Create | PreOperation | Sync | 1 |
| quotedetail | Update | PreOperation | Sync | 5 |
| quotedetail | Update | PostOperation | Sync | 9 |
| quotedetail | Update | PostOperation | Async | 1 |
| salesorderdetail | Create | PostOperation | Sync | 1 |
| salesorderdetail | Update | PostOperation | Sync | 2 |
| salesorderdetail | Update | PostOperation | Async | 1 |
| salesorderdetail | RetrieveMultiple | PreOperation | Sync | 1 (Restrict_Views.OrderProductView) |

- Enabled synchronous Update steps (they run while the user waits on every matching save): 16 (14 on quotedetail, 2 on salesorderdetail).
- The Restrict_Views step for quotedetail (RetrieveMultiple) is DISABLED in production; the order one is enabled.
- No custom step has an empty Update filter (none runs on every update), but several have very large filters:
  DNL_Quote.OnUpdateQuoteDetails 58 columns (disabled), DNL_Quote.UpdateQuotedetailDnl 50, DNL_Quote.OnUpdateSalesContracrt 38 (disabled),
  DCTLDevelopment QuoteLinePreOpUpdateDomestic 36, QuoteExport.SalesContractExportDNL 34, DNL_Quote.SalesContractDomesticDNL 34,
  DCTLDevelopment QuoteLinePreOpUpdateExport 33, QuoteExport.QuoteLineItemPreOpUpdate 29, OrderSchedule.QuoteLineItemPreOpUpdate 29 (disabled).
- `quantity` is in the filter of 11 enabled Update steps, so changing one quantity runs up to 11 steps. Other heavily shared columns:
  dg_warehouse (12 filter lists), dg_packaging (8), dg_contributionmargin, dg_othercharges, dg_incoterms, dg_statusline,
  dg_pershipmentqtymt, dg_commissionvaluepermt (7 each).
- 29 of 35 steps carry a pre or post image. 16 steps run as a named user (impersonation), which affects who the step "is" when it saves.
- 14 assemblies. Largest: DNL Quote (9 steps), DCTLDevelopment (4), QuoteExport (4), OrderSchedule (3), UpdateFields_Opp_Quote (3).
- Similar names suggest the same logic exists in several assemblies for different divisions:
  QuoteLinePreOpUpdateDomestic / QuoteLinePreOpUpdateExport (DCTL), QuoteLineItemPreOpUpdate (QuoteExport),
  QuoteLineItemPreOpUpdate (OrderSchedule, disabled), SalesContractDomesticDNL / SalesContractExportDNL.
  Whether they calculate the same values must be checked in the code.

## Caution
This is how the steps are registered, not what the code does. The source of each assembly and the plugin trace log in dev
(or a copy of production) are needed for run times and logic.
