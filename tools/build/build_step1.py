"""Builds the STEP 1 version of dg_js/quoteProduct/main/dnl from the production copy.
Only touches: (a) a header comment, (b) a new shared reader after line 3, (c) the quote request block inside 4 functions.
Every other line is left exactly as it was. The script verifies this at the end.
Read-only on the original. Does not call any environment."""
import difflib, hashlib, os, re, sys

ROOT = r'C:\DeepakNitrate\Production\Analysis'
SRC = os.path.join(ROOT, 'dnl-layer-compare', 'layer24-ProductionDeployment_Patch_23c258e6.js')
OUT = os.path.join(ROOT, 'step1')
NEW = os.path.join(OUT, 'dg_js_quoteProduct_main_dnl.STEP1.js')
ORIG = os.path.join(OUT, 'dg_js_quoteProduct_main_dnl.ORIGINAL-v1.0.0.34.js')
DIFF = os.path.join(OUT, 'step1.diff')

raw = open(SRC, 'rb').read()
print('source bytes', len(raw), 'sha256', hashlib.sha256(raw).hexdigest()[:12])
bom = raw.startswith(b'\xef\xbb\xbf')
text = raw.decode('utf-8-sig')
nl = '\r\n' if '\r\n' in text else '\n'
lines = text.splitlines(keepends=True)
print('lines', len(lines), 'newline', repr(nl), 'bom', bom)
open(ORIG, 'wb').write(raw)

def fn_range(name):
    start = next(i for i, l in enumerate(lines) if re.match(r'^function\s+' + re.escape(name) + r'\s*\(', l))
    end = next((i for i in range(start + 1, len(lines)) if re.match(r'^function\s', lines[i])), len(lines))
    return start, end

def req_block(name, which=0):
    s, e = fn_range(name)
    reqs = [i for i in range(s, e) if re.match(r'^\s*var req = new XMLHttpRequest\(\);', lines[i])]
    r = reqs[which]
    send = next(i for i in range(r, e) if re.match(r'^\s*req\.send\(\);', lines[i]))
    indent = re.match(r'^(\s*)', lines[r]).group(1)
    return r, send, indent

def block(indent, text_lines):
    return [indent + t + nl if t else nl for t in text_lines]

edits = []  # (first_idx, last_idx, replacement_lines)

# ---- 1. OldQuoteProduct
r, s, ind = req_block('OldQuoteProduct')
edits.append((r, s, block(ind, [
    '// STEP1-CHANGE-START',
    '// ORIGINAL (v1.0.0.34 lines %d-%d): a synchronous XMLHttpRequest to quotes(<id>)?$select=_customerid_value,' % (r + 1, s + 1),
    '//   whose callback stored the customer id in the global variable "account".',
    '// NOW: the customer id comes from the shared quote read (dnlGetQuoteData). Same global variable, same value.',
    '// NOTE: the original code is kept above and below this block unchanged (including the TypeError it throws when',
    '//   "quoteid" or "productid" is empty). Behaviour is meant to be identical.',
    'var quoteData = dnlGetQuoteData(quoteprodid);',
    'if (quoteData) {',
    '    account = quoteData["_customerid_value"];',
    '}',
    '// STEP1-CHANGE-END',
])))

# ---- 2. UpdateQuoteProductSalesOrd (first handler on the DNL and DCTL forms)
r, s, ind = req_block('UpdateQuoteProductSalesOrd')
edits.append((r, s, block(ind, [
    '// STEP1-CHANGE-START',
    '// ORIGINAL (v1.0.0.34 lines %d-%d): a synchronous XMLHttpRequest to' % (r + 1, s + 1),
    '//   quotes(<id>)?$select=effectiveto,dg_division,dg_salesoragnizationsingle, whose callback set "division", "date" and "salesorg".',
    '// NOW: same three values from the shared quote read. This is the FIRST OnLoad handler on both the DNL and DCTL forms, so it asks for a',
    '//   FRESH read (second argument true) and the other three functions reuse it (one request instead of four).',
    '// WHY IT IS STILL SYNCHRONOUS: about 49 handlers run after this one and read dg_division / dg_salesorganization.',
    '//   If these fields were filled later (asynchronously) those handlers would see empty values on new lines.',
    '// The code below this block (setting the 3 fields when empty) is the ORIGINAL code and is unchanged, including',
    '//   new Date(null) = 1 Jan 1970 when the quote has no effective-to date (existing behaviour, flagged for the business).',
    'var quoteData = dnlGetQuoteData(quoteid, true);',
    'if (quoteData) {',
    '    division = quoteData["dg_division"];',
    '    date = quoteData["effectiveto"];',
    '    salesorg = quoteData["dg_salesoragnizationsingle"];',
    '}',
    '// STEP1-CHANGE-END',
])))

# ---- 3. ShowHideOnFSBI: only the FIRST request (the quote). The price list request below it is unchanged (step 2).
r, s, ind = req_block('ShowHideOnFSBI', 0)
edits.append((r, s, block(ind, [
    '// STEP1-CHANGE-START',
    '// ORIGINAL (v1.0.0.34 lines %d-%d): a synchronous XMLHttpRequest to quotes(<id>)?$select=dg_isitacontract,' % (r + 1, s + 1),
    '//   whose callback set the variable "contract".',
    '// NOW: "contract" comes from the shared quote read. The SECOND request in this function (price list type) is NOT changed in step 1.',
    '// ORDER NOTE: this handler runs BEFORE ShowHideFormulaPricing and ppandfs/ppandfsDCTL, which also show/hide dg_voc.',
    '//   That is why the read stays synchronous: an asynchronous version would hide dg_voc AFTER those handlers and could change the result.',
    'var quoteData = dnlGetQuoteData(quoteid);',
    'if (quoteData) {',
    '    contract = quoteData["dg_isitacontract"];',
    '}',
    '// STEP1-CHANGE-END',
])))

# ---- 4. OnLoadQuoteStatus
r, s, ind = req_block('OnLoadQuoteStatus')
edits.append((r, s, block(ind, [
    '// STEP1-CHANGE-START',
    '// ORIGINAL (v1.0.0.34 lines %d-%d): a synchronous XMLHttpRequest to quotes(<id>)?$select=dg_customstatus,' % (r + 1, s + 1),
    '//   whose callback set the variable "status".',
    '// NOW: "status" comes from the shared quote read. The code below (copying it into dg_quotestatus) is the ORIGINAL and is unchanged,',
    '//   including: if the read fails, "status" stays null and a non-empty dg_quotestatus is overwritten with null (existing behaviour, flagged).',
    'var quoteData = dnlGetQuoteData(quoteId);',
    'if (quoteData) {',
    '    status = quoteData["dg_customstatus"];',
    '}',
    '// STEP1-CHANGE-END',
])))

# ---- apply the function edits from the bottom up so earlier indexes stay valid
new = list(lines)
for first, last, repl in sorted(edits, key=lambda e: e[0], reverse=True):
    new[first:last + 1] = repl

# ---- shared reader, inserted after the 3 global variables (original line 3)
assert lines[2].startswith('var oldQuote'), 'unexpected line 3: ' + lines[2]
loader = block('', [
    '',
    '// STEP1-CHANGE-START  (NEW CODE: shared reader for the parent quote)',
    '// Before step 1, four OnLoad functions (OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI, OnLoadQuoteStatus) each made their own',
    '// SYNCHRONOUS request to the same quote. They now share ONE request. It is still synchronous (see the notes inside each function).',
    '//  - dnlGetQuoteData(quoteId)        returns the cached quote data if it is for the same quote and younger than DNL_QUOTE_CACHE_TTL_MS',
    '//  - dnlGetQuoteData(quoteId, true)  always reads fresh (used by UpdateQuoteProductSalesOrd, the first handler of every load)',
    '// Returns null when the read fails. A failed read is never cached.',
    '// The cache is also protected by the time limit, so a later form refresh or a form without the first handler never sees old data.',
    'var DNL_QUOTE_CACHE_TTL_MS = 10000;',
    'var DNL_QUOTE_SELECT = "_customerid_value,effectiveto,dg_division,dg_salesoragnizationsingle,dg_isitacontract,dg_customstatus";',
    'var _dnlQuoteCache = { id: null, ts: 0, data: null };',
    'function dnlGetQuoteData(quoteId, forceRefresh) {',
    '    var now = new Date().getTime();',
    '    if (!forceRefresh && _dnlQuoteCache.data && _dnlQuoteCache.id === quoteId && (now - _dnlQuoteCache.ts) < DNL_QUOTE_CACHE_TTL_MS) {',
    '        return _dnlQuoteCache.data;',
    '    }',
    '    var data = null;',
    '    // No try/catch on purpose: like the original code, a network error is NOT swallowed here (it escapes to the form as before).',
    '    var req = new XMLHttpRequest();',
    '    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotes(" + quoteId + ")?$select=" + DNL_QUOTE_SELECT, false);',
    '    req.setRequestHeader("OData-MaxVersion", "4.0");',
    '    req.setRequestHeader("OData-Version", "4.0");',
    '    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");',
    '    req.setRequestHeader("Accept", "application/json");',
    '    req.send();',
    '    if (req.status === 200) {',
    '        data = JSON.parse(req.responseText);',
    '    } else {',
    '        console.log(req.responseText);   // the original logged the response text the same way',
    '    }',
    '    _dnlQuoteCache = data ? { id: quoteId, ts: now, data: data } : { id: null, ts: 0, data: null };',
    '    return data;',
    '}',
    '// STEP1-CHANGE-END',
    '',
])
new[3:3] = loader

# ---- header
header = block('', [
    '/* =====================================================================================================',
    '   STEP 1 REFACTOR (DRAFT FOR UAT) of dg_js/quoteProduct/main/dnl',
    '   Base file : production = UAT copy, 184,264 bytes, sha256 starts 31a31837f15c',
    '               (layer ProductionDeployment_Patch_23c258e6 v1.0.0.34). Untouched copy: *.ORIGINAL-v1.0.0.34.js',
    '   Search for "STEP1-CHANGE" to find every change. Everything else is the original, line for line.',
    '',
    '   WHAT CHANGED',
    '   1. NEW dnlGetQuoteData(): one shared (synchronous) read of the parent quote with the 6 columns the four functions need.',
    '   2. OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI, OnLoadQuoteStatus use it instead of making one request each.',
    '   RESULT: 4 blocking requests to the same quote become 1 (3 round trips saved on every form open).',
    '',
    '   WHAT DID NOT CHANGE',
    '   - Function names, parameters and the form registrations (no form has to be changed or shipped with this file).',
    '   - The order in which the effects happen (all work is still done in the same place, in the same order).',
    '   - The price list request inside ShowHideOnFSBI and all other requests in the file (planned for later steps).',
    '',
    '   WHY THE READ IS NOT ASYNCHRONOUS YET',
    '   On the DNL and DCTL forms UpdateQuoteProductSalesOrd is the FIRST OnLoad handler and about 49 handlers run after it, many of them',
    '   reading dg_division and dg_salesorganization. ShowHideOnFSBI runs before ShowHideFormulaPricing and ppandfs, which also show/hide',
    '   dg_voc. Making these reads asynchronous would change the order of effects. A safe asynchronous design needs one OnLoad',
    '   entry point that runs the functions in order (a form change), which is a later step.',
    '   ===================================================================================================== */',
])
new[0:0] = header

out_text = ''.join(new)
data = out_text.encode('utf-8')
if bom:
    data = b'\xef\xbb\xbf' + data
open(NEW, 'wb').write(data)
print('new file bytes', len(data), 'lines', len(new))

# ---- verification: every changed region is inside our markers; all other original lines are identical and in order
new_lines = out_text.splitlines(keepends=True)
sm = difflib.SequenceMatcher(None, lines, new_lines, autojunk=False)
removed_total = 0; added_total = 0; outside = 0
for tag, a1, a2, b1, b2 in sm.get_opcodes():
    if tag == 'equal':
        continue
    removed_total += (a2 - a1); added_total += (b2 - b1)
    seg = ''.join(new_lines[b1:b2])
    if 'STEP1-CHANGE' not in seg and 'STEP 1 REFACTOR' not in seg and tag != 'delete':
        outside += 1
    print('  %-8s original lines %d-%d  ->  new lines %d-%d' % (tag, a1 + 1, a2, b1 + 1, b2))
print('original lines removed:', removed_total, ' new lines added:', added_total, ' changes outside the markers:', outside)
open(DIFF, 'w', encoding='utf-8', newline='\n').write(''.join(difflib.unified_diff(
    lines, new_lines, fromfile='ORIGINAL v1.0.0.34 (production = UAT)', tofile='STEP1', n=3)))
print('diff written', DIFF)
