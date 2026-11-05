# Verdict for each OnLoad function of dg_js/quoteProduct/main/dnl (production, enabled on the DNL and DCTL forms)

Source: Analysis\dnl-onload-functions.txt (the 35 functions extracted from the production copy, equal to UAT). Local read only.
Read in full: 29 of the 35. Scanned for server calls only (no call found): partialwon, exportquotechild, preventPricePerUnitRecalculation,
Onload, TradeDiscountShowHide, MakeFeildNonMandatoryDCTL. Verdicts marked (check) need confirmation with the business or the developers.

## A. No server call. Keep at load (they decide what the user sees, locks or must fill, using values already on the form)
EnableEffectiveto, avlquantity, ShowHideFormulaPricing, ppandfs, ppandfsDCTL, mandate, exworks (calls exworksDCTL), commissionforbi,
manageIncotermsVisibility, lockCommissionValue, freightpershipment, contributionmarginfinal, Incotermtouppercase,
incotermandincotermlocation, traderdiscoutlockunlock, partialwon*, exportquotechild*, preventPricePerUnitRecalculation*, Onload*,
TradeDiscountShowHide*, MakeFeildNonMandatoryDCTL* (* scanned only).
Later improvement (not about load time): the long show/hide lists (ShowHideFormulaPricing has about 100 controls per case) can become one table.

## B. Blocking (synchronous) server read on load: make asynchronous, and merge
| Function | What it reads | What it does with it | Verdict |
|---|---|---|---|
| OldQuoteProduct | quote: customer | stores it in a global, adds a lookup filter. Comment in code: "old quote not in use, need modification" | Confirm it is unused and remove (check) |
| UpdateQuoteProductSalesOrd | quote: effective-to, division, sales organisation | fills 3 empty fields | Can wait. Probably only needed for new lines (check) |
| ShowHideOnFSBI | quote: contract flag; price list: type (2nd call) | hides dg_voc for some cases | Can wait. Hide the field first, show when the answer arrives |
| filterPackagingTypeDnl | product: packaging type, purity | sets packaging type and purity on the line | Can wait. It overwrites packaging type on EVERY load, not only when empty (check with the business) |
| InterestaarteMandatory | price list: type (sync); default interest rate record (2 async calls) | sets "required"; defaults the interest-rate lookup | Can wait. Set the default from a cached id, not 2 requests each load |
| OnLoadQuoteStatus | quote: custom status | copies it into dg_quotestatus every load (marks the form changed) | Can wait. Better: store it on the server |
| onrevision | price list: type | decides which fields are editable (163 lines) | Keep the DECISION at load, but use the merged result; lock the fields first, unlock on the answer |
| commissionagentfilter | commissioning agents of the customer | filter on 3 lookups | Move to a lookup filter that runs only when the lookup is opened |

## C. Server read already asynchronous: keep, but merge so the same record is not read again
SubGridFilterExecution (competitor analysis rows), bidomestic (price list type), incotermlocation (sales area), PPcostingowner (price list type),
bipriceadder (price list type), populateindustrytype (sales area, about 4 calls).

## D. Requests per form open, before and after (approximate; some are conditional)
| Same record read | Functions | Requests now | After merging |
|---|---|---|---|
| The parent quote (customer, effective-to, division, sales organisation, contract flag, custom status) | OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI, OnLoadQuoteStatus | 4 (all blocking) | 1 |
| The price list (type) | ShowHideOnFSBI, InterestaarteMandatory, onrevision (blocking); bidomestic, PPcostingowner, bipriceadder | 6 | 1 |
| The sales area | incotermlocation, populateindustrytype (and FilterWarehouse when used) | 2 to 5 | 1 |
| The product | filterPackagingTypeDnl | 1 | 1 |
| Commissioning agents | commissionagentfilter | 1 (blocking) | 0 at load (on lookup open) |
| Default interest rate record | InterestaarteMandatory | 2 | 0 to 1 (cached) |
| Competitor analysis rows | SubGridFilterExecution | 1 | 1 |
| Total | | about 17 to 21, 9 of them blocking | about 6 to 7, none blocking |

## E. Cautions for the conversion
1. The code after each `req.send()` reads variables that the callback sets. That only works because the call is synchronous. Making it
   asynchronous means moving the code that uses the answer INTO the answer handler (or using promises). The flag cannot simply be flipped.
2. Implicit globals are used to pass values (`account`, `commissionagent`, `productid`, `quoteid`). Several functions overwrite each other's values.
   Pass the merged result explicitly.
3. Where an answer decides what is visible or locked, hide or lock by default and release when it arrives, to avoid a flash of the wrong state.
4. Compare the visible fields, the locked fields and the calculated totals on sample quotes (Domestic, Export, contract) before and after.
5. Two forms (DNL and DCTL) register the same functions, so each change must be tested on both.
