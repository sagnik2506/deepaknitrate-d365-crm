PRODUCTION - unmanaged layer check (Quote Product and Order Product only)
Prepared 4 November 2026. NOT RUN YET. You run it manually, after 8 PM.

WHAT IT DOES
  Finds components of the two tables that carry an unmanaged ("Active") layer on top of a managed one:
  columns, forms, views, charts, business rules and the scripts (web resources) with your prefix.
  It also lists components created directly (not in a managed solution) for the two tables.

WHAT IT DOES NOT DO (safe defaults)
  - It reads NO record data. The "does a column hold a value" query is off.
  - It does NOT list unmanaged plugin steps, flows and web resources for the whole environment (off).
  - It creates, changes and deletes nothing. Only read requests.
  - It skips platform-generated columns (rollup _date/_state, money _base twins, name columns).
  - It pauses 300 ms between requests and stops by itself after 30 minutes.

BEFORE YOU START
  1. Tell the production owner. Run off-hours, one run at a time.
  2. Sign in yourself with an account that can read the production environment:
       az login --allow-no-subscriptions --tenant <tenant id>
       az account show
  3. Check the connection (should return a UserId):
       $t = az account get-access-token --resource https://<production>.crm8.dynamics.com --query accessToken -o tsv
       Invoke-RestMethod -Uri https://<production>.crm8.dynamics.com/api/data/v9.2/WhoAmI -Headers @{Authorization="Bearer $t"}
     A 401 or 403 means the account has no access: ask the environment admin for a read-only role.

RUN IT (from this folder, in PowerShell)
  pwsh -File .\Get-ActiveLayerInventory.ps1 -EnvUrl https://<production>.crm8.dynamics.com -UseAzCli -Table quotedetail,salesorderdetail -Prefix dg_ -IncludeLayerDetail -OutDir .\layer-results

  Expected: about 700 to 1,000 requests, roughly 10 to 15 minutes.

STOP IT AT ANY TIME (for example if someone reports slowness)
  Create the stop file in this folder. The script stops cleanly at its next request and keeps what it found:
       New-Item .\STOP-LAYER-RUN.txt
  To continue later: delete the stop file and run the same command with -Resume added.

AFTER THE RUN (folder .\layer-results)
  active-layers.csv            THE ANSWER: managed components that carry an Active layer (Table, Type, Name, Layers, ActiveChange)
  layer-names-seen.csv         Layer names found. "Active" should be in the list.
  production-only.csv          Components of the two tables created directly (data column says "not checked": no data is read)
  classification-proposal.csv  Proposed keep / discard / review for each item. A lead, not a decision.
  solutions.csv                Solutions installed (managed or unmanaged, version).
  At the end the script prints the request count and whether the run was stopped early.

HOW TO READ THE RESULT
  - Each row of active-layers.csv is a component with a hand edit on top. In the maker portal open it, then
    Advanced, See solution layers, and check the Changes view to see what was edited. Capture the edit before any release.
  - ActiveChange = CHANGES means the layer really changes the managed definition. NO-VISIBLE-CHANGE means it adds nothing.
  - Compare with the preprod result: Quote product DG (two forms), Quote Product web view, Quote product_DG (deprecated),
    New Form, Information, and the script dg_CustomActivateQuote.
  - LAYER-QUERY-ERROR rows mean the layer could not be read for that item: check it by hand.

OPTIONAL SWITCHES (leave off in production unless the owner agrees)
  -IncludeEnvironmentWide   also lists every unmanaged plugin step, web resource and flow (heavy)
  -IncludeDataCheck         also checks whether directly created columns hold a value (reads data)
  -DelayMs 500              pause longer between requests
  -MaxMinutes 45            allow a longer run

FILES
  Get-ActiveLayerInventory.ps1   the hardened script
  _tests\                        the mock test harness and the script that produced this version (no environment is contacted)

TESTED ON SAMPLE DATA ONLY (mock): no data queries, no environment-wide queries, companions skipped, the stop file stops the run before and during the checks.
Not yet run against a real environment in this hardened form.
