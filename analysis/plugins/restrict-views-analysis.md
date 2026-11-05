# Analysis of the "Restrict Views" plugin source (read from the zip; nothing was built or run)

Source: C:\DeepakNitrate\Restrict Views.zip, extracted to C:\DeepakNitrate\Analysis-RestrictViews\extracted (read only).
Project: .NET Framework 4.6.2 class library, Microsoft.CrmSdk.CoreAssemblies 9.0.2.12, signed (RestrictViews.snk), Debug build in bin\Debug.
20 plugin classes, one per table. Reviewed in full: quoteproductview.cs; read in part: OrderProductView.cs; patterns counted across all 20.
The others were checked by pattern search and by size, not read line by line. The Debug DLL in the zip is not proven to be the one in production.

## 1. What the plugin does

It runs on RetrieveMultiple (every list read: views, subgrids, lookups, Advanced Find, Web API lists), PreOperation, synchronous.
It rewrites the query so a user only sees rows for their SALES ORGANISATION and DIVISION.

1. Reads the user's `dg_salesorganizationmulti` (a multi-choice on the user record).
2. Depending on the values (1000, 2000, 3000) it adds `dg_salesorganization` (orders use `dg_salesorgan`) conditions to the query:
   - one org: 2000 means "not 1000 and not 3000"; 1000 or 3000 means "equals that org"
   - two orgs: (1000,3000) means "in (1000,3000)"; (2000,3000) means "not 1000"
3. For 1000 and 3000 it also reads the user's teams (non-access teams) and takes the NAME of each team's business unit.
   The unit names map to a division code added as `dg_division in (...)`:
   BI=30, F&S=40, PP=50, EC=95, Solvent=20 (and, for some combinations, Phenolix=10 and By-product=80 always).
4. Child tables (order product, invoice product, price list items, approvals) filter through the parent: they add an INNER JOIN to the
   parent record (for example `salesorder`) and filter on the parent's sales organisation.
5. Tables covered (20 classes): quote, quote product, order, order product, invoice, invoice product, opportunity, lead, price list,
   price list items, sales contract, order schedule, credit limit, and the approval tables (order, order schedule, credit limit,
   price list, sales contract, commission master, master).

So the rule is NOT "own or team records". It is based on field values (sales organisation, division) and on the NAMES of
business units. Security roles and business units alone cannot reproduce it.

## 2. Cost per list read

- up to 3 extra server calls, all synchronous, before the user's query runs: (a) convert a QueryExpression to FetchXML,
  (b) read the user's sales organisation, (c) read the user's teams and business units. No caching.
- child tables also gain an inner join to the parent on every list read.
- The same work repeats for every view, subgrid and lookup on a form.
- 20 near-identical classes (about 41 KB for the simple ones and 80 KB for the approval and child ones), copy-pasted.
- In production the Order Product step is enabled and the Quote Product step is disabled (from the registration check).
  The state of the other 18 steps in production has not been read.

## 3. Defects and risks found

| # | Finding | Where | Effect |
|---|---|---|---|
| 1 | The restriction is added to the first `//entity/filter` whatever its type. If the view's own filter is `or`, the new conditions are ORed in | quoteproductview.cs lines 71 to 97 and the same block in every branch | The restriction is bypassed and extra rows are returned |
| 2 | No restriction at all for users with no sales organisation, 3 organisations, or a pair other than (1000,3000) and (2000,3000), for example (1000,2000). The code simply does nothing | lines 60 to 65 and 328 to 451 | Those users see everything on that table (a gap, if the rule is meant as security) |
| 3 | If a user's teams match none of the known business unit names, the division list is empty and the query gets `dg_division in ()` with no values | lines 294 to 321 | Likely a query error, so the list fails for that user |
| 4 | Business unit NAMES drive access (bi, f&s, pp, ec, solvent) | lines 155 to 166 and others | Renaming or moving a business unit silently changes who sees what. The production unit "Solvent" under DPL is one of these names |
| 5 | Hard-coded values: sales organisations 1000, 2000, 3000; divisions 10, 20, 30, 40, 50, 80, 95; `phenolix = true` and `byproduct = true` fixed for the 2000+3000 case | lines 501 to 502, 540 to 547 | Any change needs a code release |
| 6 | Only list reads are restricted. Opening a record by its id or link (Retrieve) is not | by design (RetrieveMultiple only) | It is a view filter, not security |
| 7 | Catch-all rethrows the raw exception text to the user; the full modified FetchXML is written to the trace log | lines 100, 221, 572 to 575 | Users see technical errors; trace logs grow and hold query text |
| 8 | Field names differ by table: `dg_salesorganization` on quote and others, `dg_salesorgan` on orders | OrderProductView.cs | Easy to get wrong when adding a table |
| 9 | 20 copies of the same logic | all files | A fix has to be made 20 times; the copies can drift apart |

## 4. How to improve it (keeping the rule)

1. One shared base class with the rule written once, and a small table or configuration for: sales organisation codes, division codes,
   and the business-unit-to-division mapping, instead of hard-coded names and numbers.
2. Cache the user's sales organisation and division list in memory per user for 5 to 15 minutes. This removes 2 of the 3 extra calls
   on almost every read.
3. Skip the work when it is not needed: system and integration users, single-record queries, queries on other tables, and queries that
   are already restricted.
4. Wrap the original filter instead of appending to it: put the user's original filter and the new restriction under one new `and` filter.
   This fixes defect 1.
5. Decide, with the business, what the gaps in defect 2 and 3 should do (no access, or everything), and code it on purpose.
6. For child tables, consider a copy of the sales organisation and division on the child row, so no join to the parent is needed.
   That is a data change and needs its own review.
7. Remove the FetchXML trace, return a clear message, and register the step only on the messages and tables that need it.

## 5. Could native security replace it?

Not directly, because the rule depends on field values (sales organisation, division) and on business unit names.
Options, from smaller to larger change:
- Keep the plugin, fixed and cached (section 4). Recommended first.
- Model sales organisation x division as business units or owner teams, move record ownership to them, and give roles Read = Business Unit.
  This gives real security (it also covers opening a record by id) but needs a data and ownership migration and agreement from the business.
- Keep a field-based rule only where views are the only concern, and enforce real access in the business unit model.

## 5b. Which steps are enabled in production (read-only check, 5 Nov 2026)

Assembly "Restrict Views" v1.0.0.0, sandbox isolation, created 7 Oct 2025, last modified 27 Oct 2026. 20 steps, all RetrieveMultiple,
PreOperation, Synchronous. **19 enabled, 1 disabled.**

- Disabled: `quotedetail` (Restrict_Views.quoteproductview), last modified 29 Jan 2026 05:46, the day after the main rollout.
- Enabled: dg_commissionmasterapproval, dg_creditlimitapproval, dg_creditmanagement, dg_masterersapprovals, dg_orderapproval,
  dg_orderschedule, dg_orderscheduleapprovals, dg_pricelistapprovals, dg_salescontract, dg_salescontractapproval, invoice,
  invoicedetail, lead, opportunity, pricelevel, productpricelevel, quote, salesorder, salesorderdetail.
- Most steps were last modified on 28 Jan 2026 (rollout). dg_orderapproval, salesorder and salesorderdetail were modified on 3 Feb 2026.
- Inference (to confirm with the team): the Quote Product step was disabled one day after go-live, so something about it probably failed or was
  too slow. Quote Product list reads are therefore NOT restricted today while the Quote header and the Order Product list are.
File: plugin-steps\restrict-views-steps-PROD.csv

## 6. Open questions
- Is the rule a security requirement or only a convenience filter? (defect 6 matters if it is security)
- What should happen to users with no sales organisation, or with a combination the code ignores?
- Which of the 20 steps are enabled in production? (only order product and quote product were read)
- Is the Debug DLL in the zip the same code as the assembly registered in production?
- Who owns the user's `dg_salesorganizationmulti` values and the team and business unit naming?
