# First plugin target: the 11 enabled Update steps that list `quantity`

Source: production registration data, read-only, 5 Nov 2026. This describes how the steps are REGISTERED.
Statements marked (hypothesis) must be confirmed by reading the code or the trace log.

## 1. The 11 steps (production)

| # | Table | Stage | Class | Rank | Filter cols | Runs as | Image |
|---|---|---|---|---|---|---|---|
| 1 | quotedetail | PreOperation | DCTLDevelopment.QuoteProduct.QuoteLinePreOpUpdateDomestic | 1 | 36 | Named user | Pre, all columns |
| 2 | quotedetail | PreOperation | DCTLDevelopment.QuoteProduct.QuoteLinePreOpUpdateExport | 1 | 33 | Named user | Pre, all columns |
| 3 | quotedetail | PreOperation | QuoteExport.QuoteLineItemPreOpUpdate | 1 | 29 | Named user | Pre, all columns |
| 4 | quotedetail | PreOperation | QuoteExport.SalesContractExportDNL | 1 | 34 | Named user | Pre, all columns |
| 5 | quotedetail | PreOperation | DNL_Quote.SalesContractDomesticDNL | 2 | 34 | Named user | Pre, all columns |
| 6 | quotedetail | PostOperation | DNL_Quote.UpdateQuotedetailDnl | 1 | 50 | Named user | Pre, all columns |
| 7 | quotedetail | PostOperation | UpdateFields_Opp_Quote.Update_QuoteDetail | 1 | 25 | Calling user | Pre, all columns |
| 8 | quotedetail | PostOperation | DNL_Quote.QuantityUpdateSalesContractQP | 1 | 1 | Calling user | Pre, all columns |
| 9 | quotedetail | PostOperation | ForSCTypeOfQuotes.UpdateSC | 1 | 1 | Named user | Pre, all columns |
| 10 | salesorderdetail | PostOperation | ForSCTypeOfQuotes.OrderLineQtyValidation | 1 | 1 | Calling user | Pre, all columns |
| 11 | salesorderdetail | PostOperation | ToleranceCheck.ToleranceCheck | 1 | 1 | Calling user | Pre, quantity only |

All 11 are synchronous. Changing the quantity of ONE quote line wakes up to 9 steps (5 before the save, 4 after);
one order line wakes 2.

## 2. What the registration already tells us

- **Overlapping filters.** Step 6 (UpdateQuotedetailDnl, 50 cols) and step 1 (QuoteLinePreOpUpdateDomestic, 36 cols) share 34 columns.
  Step 2 (QuoteLinePreOpUpdateExport, 33 cols) and step 3 (QuoteLineItemPreOpUpdate, 29 cols) share 28 columns.
- **Most shared columns (in how many of the 11 filters):** quantity 11; dg_warehouse, dg_commissionvaluepermt, dg_pershipmentqtymt,
  dg_commissionvalue, dg_commissionorvalue 6 each; dg_contributionmargin, dg_packaging, dg_contributionmarginpercentage 5 each;
  dg_othercharges, dg_incoterms, dg_freightcharges, dg_packagingcharges, dg_secondarypackagingcharges, dg_benchmarkpricedomestic and others 4.
- **Same family, different assemblies:** Domestic and Export variants appear in DCTLDevelopment, QuoteExport and DNL_Quote.
- **All-column pre-images on 10 of 11 steps.** Each image copies the whole record, even when a step needs a few columns.
- **Large filters mean the step is woken by almost any pricing change**, but may need only a few columns.
- **Rank:** step 5 runs second (rank 2) among the pre-operation steps, so it may depend on what the rank-1 steps set.
- **UAT is ahead of production** by one step: DNL_Quote.UpdateSalesContractQuantity exists in UAT only. Production is not in sync with UAT.

## 3. Hypotheses to confirm in the code

1. Steps 1 to 5 (pre-operation) calculate charges, margins and commission for Domestic and Export lines. Several may calculate the same values
   (1 vs 6, 2 vs 3). If so, only one should write each column.
2. Step 6 (post-operation, 50 cols) and step 7 (post-operation, 25 cols) probably update the same record again after the save.
   A second Update triggers all the steps again (a chain). Check each for `service.Update` on the same table.
3. Steps 8, 9, 10 and 11 (quantity only) are likely contract-quantity updates and validations. They could be one handler,
   and the validation could run before the save (pre-operation) instead of after.
4. Named-user steps may run as a service user so the update can bypass the caller's permissions. Confirm which user and why.

## 4. What the developers should check, step by step

For EACH of the 11 classes, fill one line:

| Question | Answer |
|---|---|
| Which columns does the code actually read? | |
| Which columns does it write, and on which records (the same line, the quote, the contract)? | |
| Does it call Update on the record that triggered it? (a second write) | |
| Does it retrieve the whole record or a few columns? | |
| Does it use the pre-image? Which columns? | |
| Does it check Depth to stop loops? | |
| Does it write a column that another step also writes? Which? | |
| Is the logic still used (a division, or a feature) or dead? | |
| Does it need to run synchronously, or can it be async? | |

## 5. Measure before changing anything (UAT or a production copy; dev holds too few steps)

1. Turn on plugin trace logging (Settings, Administration, System Settings, Customization, Plugin and custom workflow tracing = All).
2. Pick 3 typical quote lines (Domestic, Export, and one with a sales contract). Change only the quantity, save, and note the time.
3. Open the Plugin Trace Log. For the save, sort by Correlation Id and note for each step: duration, depth, message, stage.
4. Fill the table:

| Step | Duration (ms) | Depth | Wrote the same record again? | Notes |
|---|---|---|---|---|

5. Repeat after each change. Turn the log off afterwards.

## 6. Safe order of change (one change per release, compare totals to the cent each time)

1. Narrow filters only where the code needs far fewer columns (step 6 and steps 1 to 5 are the best candidates).
2. Change all-column pre-images to the columns that are read.
3. Remove a second Update on the same record by setting the value in a pre-operation step.
4. Merge steps that calculate the same values (1 with 6, 2 with 3 are the first to review).
5. Move non-urgent work (emails, secondary updates, contract quantity updates) to async.
6. Retire the 10 disabled steps in a later release.
For each change: disable the old step instead of deleting, test Domestic, Export and contract lines, compare dg totals before and after,
keep the old step for one release as the rollback.

## 7. Risks
- A narrower filter that omits a column the code reads can stop a calculation. Test the full set of pricing columns.
- Steps 5 and others depend on rank and on earlier steps' writes. Do not reorder without reading the code.
- Production differs from UAT by at least one step: confirm which version is correct before merging anything.
- Named-user steps carry permissions. Keep the same user when merging.
