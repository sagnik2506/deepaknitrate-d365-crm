READ-ONLY COLUMN CHECK FOR PRODUCTION  (Check-ColumnInProduction.ps1)

WHAT IT DOES (three checks, nothing else)
  1. Column, solutions, dependencies, layers and usage counts for ONE column (dg_testfob on quotedetail)
  2. Count of rows that hold a value in the column (a number only, no record data)
  3. Solution list and component counts for ENT_SchemaBaseSolution (and patches) and the DNL_Base_* solutions

WHAT IT NEVER DOES
  - It sends only GET requests. It cannot create, change or delete anything.
  - It does not read record contents. It does not scan script web resources.

BEFORE YOU RUN
  - Run it after hours (after 8 PM as planned).
  - Sign in yourself:  az login --allow-no-subscriptions --tenant <tenant-id>
    Use an account that already has access to production. If you get HTTP 401/403, the account or tenant is wrong.

RUN (from this folder)
  pwsh -File .\Check-ColumnInProduction.ps1 -EnvUrl https://deepakcrmprod.crm8.dynamics.com -UseAzCli -Column dg_testfob -Table quotedetail

EXPECTED
  About 80 read requests (about 1 minute on UAT; allow up to 3 minutes in production).
  A pause of 300 ms follows each request. A 429 is retried after the wait the server asks for.
  Time limit 10 minutes (-MaxMinutes).

STOP AT ANY TIME
  Create an empty file named STOP-COLUMN-CHECK.txt in this folder, or press Ctrl+C.

OUTPUT (folder .\column-check-results)
  column-check-report.txt   the full text report
  solutions.csv             solutions, versions, managed flag, component counts

HOW TO READ THE RESULT
  - Platform dependencies = 0 and every usage count = 0: nothing in the platform blocks removing the column.
  - Rows with a value = 0: no data to lose in production.
  - Layers: more than the Active layer means managed layers carry the column. Every one of them
    must drop it before the column is removed.
  - Solutions that contain the column: all of them must stop carrying it.
  - A solution that "holds table(s) ... behavior 0" carries every column of that table.
  - "Approximate total rows" comes from platform statistics and can be slightly out of date.

TESTED ON UAT (not production): 78 read requests, 61 seconds, no errors.

