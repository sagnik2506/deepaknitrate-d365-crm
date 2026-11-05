# deepaknitrate-d365-crm

Customizations, analysis and tooling for the Deepak Nitrate Dynamics 365 CE (Dataverse) implementation. **Private repository.**

## What goes where
| Folder | Content |
|---|---|
| `web-resources/` | Client scripts (JavaScript web resources). One folder per web resource, with `original/` (the untouched copy taken from production), `current/` (the version being worked on) and `changes/` (diff, notes, test cases for each change) |
| `plugins/` | Plugin source code. Now holds `restrict-views/` (source only: no binaries, no signing key) |
| `analysis/` | Written findings (markdown only): plugins, scripts and forms, solutions and layers |
| `tools/` | Local helpers: read-only PowerShell checks (`tools/scripts/`), SQL (`tools/sql/`), the old-versus-new test harness and the build script for a change. See `tools/scripts/README.md` |

## Rules for this repository
1. **No data.** Never commit CSV exports, record data, user lists, tokens, passwords or client secrets. `.gitignore` blocks common cases. Excel files are allowed only for reviewed decision workbooks (component names and counts, no record data), for example `analysis/solutions-and-layers/Production-Layer-Decisions.xlsx`.
2. **No personal details.** Do not put names or email addresses of people in notes.
3. **Files are stored exactly as written** (`.gitattributes` turns line-ending conversion off) so a committed file keeps the same hash as the file in production.
4. **Each change is its own commit** (for example "Step 2: shared price list read") and has a `changes/<step>/` folder with the diff, a README and test cases.
5. **Nothing here is deployed by git.** Releases go through the normal solution patch process (UAT first, then production).

## Current state
| Web resource | Change | Status |
|---|---|---|
| `dg_js/quoteProduct/main/dnl` | Step 1: one shared quote read instead of four | Draft for UAT. Not deployed |

Base for every web resource: the production copy, which equals UAT at the time it was taken. The hash is recorded in each web resource folder.
