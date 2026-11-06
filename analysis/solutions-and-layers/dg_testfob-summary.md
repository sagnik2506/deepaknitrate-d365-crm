# dg_testfob summary (6 Nov 2026)

Short version of `dg_testfob-analysis.md`.

## What it is
A text column ("test fob", up to 4,000 characters) on Quote Product, created in April 2023 in dev. It is a calculated column, but its formula could not be read through the API. It is not required.

## What was checked
| Check | Dev | UAT | Preprod | Production |
|---|---|---|---|---|
| Platform dependencies (the delete check) | 0 | 0 | 0 | 0 |
| Forms, system views | 0 | 0 | 0 | 0 |
| Plugin step filters | 0 | 0 | 0 | 0 |
| Flows, workflows, business rules, charts, mappings | 0 | 0 | 0 | 0 |
| Script web resources | 0 (10,795 scanned) | not scanned | not scanned | not scanned |
| Rows with a value | 0 of 2,867 | 0 of 0 | 0 of 0 | 0 of about 54,800 |
| Personal views mentioning it | 0 | 0 | 0 | 1 ("QP Field1") |

Nothing technical uses it and no data would be lost, but production has one personal view that references it.

## Who carries it
| Environment | Managed | Where |
|---|---|---|
| Dev | No | 5 solutions: a patch of `ENT_SchemaBaseSolution` (v1.8.51.0), `EntitiesSolution`, `DivDevelopments`, two `SalesModuleEntities` patches |
| UAT | No | 7 solutions, including `DNL_Development`, `DNLDeveelop`, `Crf7680`. Layer: Active only |
| Preprod | Yes | 3 layers: base, patch v1.8.51.0, then `DNL_Base_Entities` on top |
| Production | Yes | Same 3 layers as preprod. No Active layer |

## Why removing it is hard
- A patch cannot delete it. Removal needs an upgrade of every managed solution that carries it.
- `DNL_Base_Entities` carries Quote Product as a whole table, so it holds this column too. Upgrading `ENT_SchemaBaseSolution` alone would leave it in place.
- `DNL_Base_Entities` has no source in dev. It was built in UAT on 28 Jan 2025, so a new version would have to come from UAT, trimmed to match production (UAT holds 463 extra columns and 3 extra tables).
- Production needs a backup and a change window. Applying the upgrade deletes the column permanently.

## Verdict
- Technically safe to remove: no uses, no data, no Active layer.
- Not worth removing on its own: it frees one slot out of about 440 and needs a managed upgrade of two solution families.
- If done, use it as the pilot for the process and batch it with other removals.

## Still open
1. Read its calculated formula in the maker portal, and ask the owner whether "test fob" is used.
2. Check the personal view "QP Field1" and its owner.
3. Find the source of `DNL_Base_Entities` (UAT is the likely one).
