# Web resource: dg_js/quoteProduct/main/dnl

D365 web resource name (use this when uploading): `dg_js/quoteProduct/main/dnl`. Used by the Quote product_DG_DNL and Quote product_DG_DCTL forms.

## Versions
| File | What it is | Size | sha256 starts |
|---|---|---|---|
| `original/main_dnl.v1.0.0.34.js` | Production copy = UAT copy, from layer `ProductionDeployment_Patch_23c258e6` (v1.0.0.34) | 184,264 bytes | `31a31837f15c` |
| `current/main_dnl.js` | Step 1 (draft for UAT). Every change is marked `STEP1-CHANGE` | 186,086 bytes | `22d5185b2ecf` |

## Changes
| Step | Folder | Summary |
|---|---|---|
| 1 | `changes/step1/` | One shared (synchronous) read of the parent quote instead of four. Blocking requests on load: 9 to 6. No form change needed |

## Notes on file names in `changes/step1/`
The step 1 notes and the diff were written before this repository existed, so they use the old file names:
`dg_js_quoteProduct_main_dnl.ORIGINAL-v1.0.0.34.js` is now `original/main_dnl.v1.0.0.34.js`, and
`dg_js_quoteProduct_main_dnl.STEP1.js` is now `current/main_dnl.js`.
`tools/build/build_step1.py` and `tools/harness/run-harness.js` keep their original machine-specific paths (C:\DeepakNitrate\Production\Analysis).
To re-run the harness here: `node tools/harness/run-harness.js web-resources/quote-product/dg_js_quoteProduct_main_dnl/original/main_dnl.v1.0.0.34.js web-resources/quote-product/dg_js_quoteProduct_main_dnl/current/main_dnl.js`

## Rule
Compare `original/` with `current/` before every upload. Upload the whole file, never fragments.
