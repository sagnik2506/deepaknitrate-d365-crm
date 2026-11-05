-- Field fill-rate analysis for Dataverse / Dynamics 365 CE
-- Run via the Dataverse TDS endpoint (SQL Server Management Studio or XrmToolBox "SQL 4 CDS").
-- TDS must be enabled in the environment (Power Platform admin center > Settings > Features).
-- Run against a SANDBOX COPY of production, not production itself.

-- 1) List custom columns of one table (replace 'account' with the table logical name)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'account'
  AND COLUMN_NAME LIKE 'new[_]%'      -- change to your publisher prefix
ORDER BY COLUMN_NAME;

-- 2) Fill rate: COUNT(col) counts only non-null values. Add one line per candidate column.
SELECT
    COUNT(*)              AS total_rows,
    COUNT(new_field1)     AS new_field1_filled,
    COUNT(new_field2)     AS new_field2_filled,
    COUNT(new_field3)     AS new_field3_filled
FROM account;

-- 3) Last time a value was written (shows whether the field is still in use)
SELECT MAX(modifiedon) AS last_modified_with_value
FROM account
WHERE new_field1 IS NOT NULL;

-- Notes
-- * Text fields can hold '' or default values; also check COUNT(DISTINCT col) and
--   whether a single default value accounts for ~100% of rows. Both mean "effectively unused".
-- * Option sets/booleans with a default will always be non-null; use the distinct count instead.
-- * Fill rate is only one signal. Also check dependencies, integrations, reports, Power BI,
--   flows and audit history before approving deletion.

-- FetchXML alternative (limit: aggregate queries fail above 50,000 rows in the web API)
-- <fetch aggregate="true">
--   <entity name="account">
--     <attribute name="accountid"  alias="total"  aggregate="count" />
--     <attribute name="new_field1" alias="filled" aggregate="count" />
--   </entity>
-- </fetch>
