-- Production data check for the columns flagged as clean delete candidates or needing review
-- WHY: the dev audit found these columns empty or unreferenced in dev. Dev usually holds less data than production,
--      so confirm in production (or a full sandbox copy of it) before anything is deprecated or removed.
-- WHERE: Dataverse TDS (SQL) endpoint, for example SSMS or XrmToolBox "SQL 4 CDS", against a sandbox copy of production, off-hours.
-- READ-ONLY. Generated from the dev audit of 3 November 2026.

-- ============================ quotedetail ============================
-- 1. Clean delete candidates: how many rows hold a value, and the last time one was written. Expect 0 and NULL.
SELECT 'dg_competititorname' AS column_name, COUNT(dg_competititorname) AS rows_with_value, MAX(CASE WHEN dg_competititorname IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM quotedetail
UNION ALL
SELECT 'dg_competitorpaymentterm' AS column_name, COUNT(dg_competitorpaymentterm) AS rows_with_value, MAX(CASE WHEN dg_competitorpaymentterm IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM quotedetail
UNION ALL
SELECT 'dg_testfob' AS column_name, COUNT(dg_testfob) AS rows_with_value, MAX(CASE WHEN dg_testfob IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM quotedetail;

-- 2. Columns with data in dev and no references found: how many rows hold a value in production.
SELECT 'dg_mainquantity' AS column_name, COUNT(dg_mainquantity) AS rows_with_value, MAX(CASE WHEN dg_mainquantity IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM quotedetail;

-- 3. Yes/No (Two Options) columns: a default value makes 'has data' always true, so look at the values instead.
--    If a column is 100% one value (for example always 0), nobody is using it.
SELECT 'dg_cashdiscount2' AS column_name, dg_cashdiscount2 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_cashdiscount2;
SELECT 'dg_dealerdiscount' AS column_name, dg_dealerdiscount AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_dealerdiscount;
SELECT 'dg_destinationcharge' AS column_name, dg_destinationcharge AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_destinationcharge;
SELECT 'dg_discount1' AS column_name, dg_discount1 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_discount1;
SELECT 'dg_dutyforeignport1' AS column_name, dg_dutyforeignport1 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_dutyforeignport1;
SELECT 'dg_fobprice1' AS column_name, dg_fobprice1 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_fobprice1;
SELECT 'dg_freight2' AS column_name, dg_freight2 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_freight2;
SELECT 'dg_oceanfreight' AS column_name, dg_oceanfreight AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_oceanfreight;
SELECT 'dg_ordershortcloseflag' AS column_name, dg_ordershortcloseflag AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_ordershortcloseflag;
SELECT 'dg_paymenttermdiscount2' AS column_name, dg_paymenttermdiscount2 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_paymenttermdiscount2;
SELECT 'dg_specialdiscount2' AS column_name, dg_specialdiscount2 AS value, COUNT(*) AS rows_ FROM quotedetail GROUP BY dg_specialdiscount2;

-- ============================ salesorderdetail ============================
-- 1. Clean delete candidates: how many rows hold a value, and the last time one was written. Expect 0 and NULL.
SELECT 'dg_benchmarkpricesalescontract' AS column_name, COUNT(dg_benchmarkpricesalescontract) AS rows_with_value, MAX(CASE WHEN dg_benchmarkpricesalescontract IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_commissionchargesvalue' AS column_name, COUNT(dg_commissionchargesvalue) AS rows_with_value, MAX(CASE WHEN dg_commissionchargesvalue IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_demmeragecharges' AS column_name, COUNT(dg_demmeragecharges) AS rows_with_value, MAX(CASE WHEN dg_demmeragecharges IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_sapsalesorderlinecode' AS column_name, COUNT(dg_sapsalesorderlinecode) AS rows_with_value, MAX(CASE WHEN dg_sapsalesorderlinecode IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_seafreightexport' AS column_name, COUNT(dg_seafreightexport) AS rows_with_value, MAX(CASE WHEN dg_seafreightexport IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_secondarypackagingchargespermt' AS column_name, COUNT(dg_secondarypackagingchargespermt) AS rows_with_value, MAX(CASE WHEN dg_secondarypackagingchargespermt IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_specialdiscountinsco' AS column_name, COUNT(dg_specialdiscountinsco) AS rows_with_value, MAX(CASE WHEN dg_specialdiscountinsco IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_tradediscountvalue' AS column_name, COUNT(dg_tradediscountvalue) AS rows_with_value, MAX(CASE WHEN dg_tradediscountvalue IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'new_benchmarksalescontract' AS column_name, COUNT(new_benchmarksalescontract) AS rows_with_value, MAX(CASE WHEN new_benchmarksalescontract IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_commissioncharges' AS column_name, COUNT(dg_commissioncharges) AS rows_with_value, MAX(CASE WHEN dg_commissioncharges IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_oldorderrevisionflag' AS column_name, COUNT(dg_oldorderrevisionflag) AS rows_with_value, MAX(CASE WHEN dg_oldorderrevisionflag IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_orderrevisionflag' AS column_name, COUNT(dg_orderrevisionflag) AS rows_with_value, MAX(CASE WHEN dg_orderrevisionflag IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail
UNION ALL
SELECT 'dg_rmnorm' AS column_name, COUNT(dg_rmnorm) AS rows_with_value, MAX(CASE WHEN dg_rmnorm IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail;

-- 2. Columns with data in dev and no references found: how many rows hold a value in production.
SELECT 'dg_deltapsalescontract' AS column_name, COUNT(dg_deltapsalescontract) AS rows_with_value, MAX(CASE WHEN dg_deltapsalescontract IS NOT NULL THEN modifiedon END) AS last_modified_with_value FROM salesorderdetail;

-- How to read the results
-- * rows_with_value = 0 in production as well as dev: the column is a safe candidate to deprecate (hide, rename zz_, observe, then delete).
-- * rows_with_value > 0: somebody has stored data. Keep the column and ask the owner before any change.
-- * last_modified_with_value shows how recently a value was written; an old date means the column is probably abandoned.
-- * A zero here is not enough on its own: also check plugin source code, reports, Power BI and integrations (see the guide).

