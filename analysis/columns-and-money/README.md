# Column analysis and money-field workbooks (4 Nov 2026)

| File | What it is |
|---|---|
| `Analysis-Evidence-2026-11-04.xlsx` | The evidence behind the column cleanup analysis: 877 audited columns (Class, duplicate groups, references in forms, views, plugin filters, scripts), candidates, duplicates, forms, views, plugin steps, layers, environments and the currency mix. Start with the "How to use" sheet |
| `Money-Fields-Decimal-Candidates-2026-11-04.xlsx` | The 250 money (Currency) fields of Quote Product and Order Product, with a tentative class, risk score, decision columns, conversion steps and consequences |

## Read this first
- These workbooks were built on 4 Nov 2026 from UAT (customizations), dev (data presence) and preprod (layers). They predate the production checks.
- The **Layers** sheet in Analysis-Evidence still says production is pending. Production has since been checked: see `analysis/solutions-and-layers/layer-check-production-2026-11-05.md`.
- The **Environments** and **Currency** sheets refer to an earlier dev environment (deepakgroupdevdnl). The current dev is deepakgroupdevcrm and holds fewer steps and older scripts: see `analysis/environment-sync/`.
- The conclusion we reached since then: deleting columns is not worth it on its own (see `analysis/status/project-summary-2026-11-06.md`). Treat the Class column as leads for review, not decisions.
- Contents: column and component names, counts and aggregate record counts by currency only. No individual records, no personal details.
