# UAT test cases for STEP 1 (dg_js/quoteProduct/main/dnl)

Run every case on BOTH forms: Quote product_DG_DNL and Quote product_DG_DCTL. Hard refresh (Ctrl+F5) after uploading the file.
Compare with the behaviour BEFORE the change (record it first from the unchanged UAT form). UAT holds no quote records, so create test data first
(a customer, a product, a price list, a sales area, a quote). Fill in Result and Tester.

## A. Before you start (baseline, unchanged file)
| # | Step | Record |
|---|---|---|
| A1 | Open a quote line with F12, Network tab, filter "quotes(" | Number of requests to quotes(...): expected 4 |
| A2 | Time from opening the line to a usable form, 3 runs, take the middle | seconds |
| A3 | Note the visible and locked fields, the sales organisation, division, effective-to and status | screenshots |

## B. Functional cases
| # | Case | Expected (same as before the change) | Result | Tester |
|---|---|---|---|---|
| B1 | Open an existing line of a non-contract quote, division 30, price list type 140110001 | Same visible fields; dg_voc as before; no values changed | | |
| B2 | Open an existing line of a contract quote (contract flag = contract) | Same visible fields | | |
| B3 | Create a NEW line (sales organisation, division, effective-to empty) | The three fields are filled from the quote, as before | | |
| B4 | New line on a quote with NO effective-to date | Same value as before (1 Jan 1970 is a known existing behaviour) | | |
| B5 | Line whose status differs from the quote status | Status refreshed to the quote status, as before | | |
| B6 | Line with an empty status | Status filled from the quote, as before | | |
| B7 | Division 40, then 50, 95 and 20 lines | Same visible and locked fields as before | | |
| B8 | Open the old-quote lookup (dg_oldquoteproduct) | Filtered to the same customer and product as before | | |
| B9 | Change a pricing field and save | Totals identical to the cent | | |
| B10 | Save, let the form refresh, check the status again | Shows the new quote status (no stale value) | | |
| B11 | Browser offline (F12, Network, Offline), open a line | Same behaviour as before (an error as today) | | |
| B12 | Open a line, check the console (F12) | No NEW errors compared with before | | |

## C. Performance (changed file)
| # | Step | Expected |
|---|---|---|
| C1 | Repeat A1 | Requests to quotes(...): 1 instead of 4 |
| C2 | Repeat A2 | Same or faster. Record the difference |
| C3 | Count blocking requests in the Network tab | 9 become 6 across the whole load |

## D. Sign-off
| Item | Name | Date |
|---|---|---|
| Business tester | | |
| Developer | | |
| Release owner | | |
Pass when every B case matches the old behaviour, C1 shows 1 request, and there are no new console errors.
