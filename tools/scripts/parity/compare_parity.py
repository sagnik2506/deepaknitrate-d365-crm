"""Offline comparer for the parity scripts. Reads local CSV files only (no environment is called).
Usage: python compare_parity.py <dirA> <nameA> <dirB> <nameB> <outDir>
Each dir holds: Table.csv, Column.csv, Form.csv, View.csv, WebResource.csv, PluginAssembly.csv, PluginStep.csv, Workflow.csv, Role.csv,
OptionSet.csv, ModelApp.csv (inventory), membership.csv (L2) and hashes-<Type>.csv (L3). Missing files are skipped.
Writes parity-L1.md, parity-L2.md, parity-L3.md and summary.json into outDir."""
import csv, json, os, sys, collections

dirA, nameA, dirB, nameB, out = sys.argv[1:6]
os.makedirs(out, exist_ok=True)
# type -> key column (Name for types whose ids differ between environments, Id for the others)
KEY = {'Table': 'Name', 'Column': 'Name', 'Form': 'Id', 'View': 'Id', 'WebResource': 'Name', 'PluginAssembly': 'Name',
       'PluginStep': 'Id', 'Workflow': 'Id', 'Role': 'Name', 'OptionSet': 'Name', 'ModelApp': 'Name'}

def rows(d, f):
    p = os.path.join(d, f)
    if not os.path.exists(p): return None
    with open(p, encoding='utf-8-sig', newline='') as fh: return list(csv.DictReader(fh))

def keyed(d, t):
    r = rows(d, t + '.csv')
    if r is None: return None
    k = KEY[t]
    return {x[k].lower() if k == 'Id' else x[k]: x for x in r}

def lines(title, items, limit=150):
    o = ['', '### ' + title + ' (%d)' % len(items)]
    o += ['- ' + str(i) for i in sorted(items)[:limit]]
    if len(items) > limit: o.append('- ... %d more (see the CSV)' % (len(items) - limit))
    return o

summary = {'A': nameA, 'B': nameB, 'L1': {}, 'L2': {}, 'L3': {}}

# ---------------------------------------------------------------- L1
md = ['# L1: existence, %s against %s' % (nameA, nameB), '', 'Customer components by type. Tables and columns are matched by name (ids differ between environments).', '',
      '| Type | In %s | In %s | In both | Only in %s | Only in %s |' % (nameA, nameB, nameA, nameB), '|---|---|---|---|---|---|']
details = []
for t in KEY:
    a, b = keyed(dirA, t), keyed(dirB, t)
    if a is None or b is None: continue
    ka, kb = set(a), set(b)
    both, oa, ob = ka & kb, ka - kb, kb - ka
    summary['L1'][t] = dict(A=len(ka), B=len(kb), both=len(both), onlyA=len(oa), onlyB=len(ob))
    md.append('| %s | %d | %d | %d | %d | %d |' % (t, len(ka), len(kb), len(both), len(oa), len(ob)))
    nm = lambda src, k: (src[k].get('Name') or k)
    if oa: details += lines('%s only in %s' % (t, nameA), [nm(a, k) for k in oa])
    if ob: details += lines('%s only in %s' % (t, nameB), [nm(b, k) for k in ob])
open(os.path.join(out, 'parity-L1.md'), 'w', encoding='utf-8').write('\n'.join(md + details) + '\n')

# ---------------------------------------------------------------- L2
def member_keys(d):
    m = rows(d, 'membership.csv')
    if m is None: return None
    maps = {}
    for t in KEY:
        r = rows(d, t + '.csv')
        if r is not None: maps[t] = {x['Id'].lower(): x for x in r}
    res = collections.defaultdict(set); versions = {}
    for x in m:
        t = x['Type']; oid = x['ObjectId'].lower()
        if t in KEY and KEY[t] == 'Name' and t in maps and oid in maps[t]: key = '%s:%s' % (t, maps[t][oid]['Name'])
        else: key = '%s:%s' % (t, oid)
        res[x['Solution']].add(key); versions[x['Solution']] = x['Version']
    return res, versions
ma, mb = member_keys(dirA), member_keys(dirB)
if ma and mb:
    A, VA = ma; B, VB = mb
    md = ['# L2: solution membership, %s against %s' % (nameA, nameB), '', 'For each solution that exists in both: which components it carries in each environment.',
          'A table carried "with all components" does not list its columns, forms and views one by one; that is not a difference.', '']
    common = sorted(set(A) & set(B))
    onlyA, onlyB = sorted(set(A) - set(B)), sorted(set(B) - set(A))
    diff = [s for s in common if A[s] != B[s]]
    summary['L2'] = dict(solutions_A=len(A), solutions_B=len(B), common=len(common), identical=len(common) - len(diff), different=len(diff), onlyA=len(onlyA), onlyB=len(onlyB))
    md += ['| Item | Count |', '|---|---|', '| Solutions in %s | %d |' % (nameA, len(A)), '| Solutions in %s | %d |' % (nameB, len(B)), '| In both | %d |' % len(common),
           '| Same components in both | %d |' % (len(common) - len(diff)), '| Different components | %d |' % len(diff), '| Only in %s | %d |' % (nameA, len(onlyA)), '| Only in %s | %d |' % (nameB, len(onlyB)), '']
    if diff:
        md += ['## Solutions with different components', '', '| Solution | Version A | Version B | Only in %s | Only in %s |' % (nameA, nameB), '|---|---|---|---|---|']
        for s in diff: md.append('| %s | %s | %s | %d | %d |' % (s, VA[s], VB[s], len(A[s] - B[s]), len(B[s] - A[s])))
        for s in diff[:40]:
            md += lines('%s: only in %s' % (s, nameA), A[s] - B[s], 40) if A[s] - B[s] else []
            md += lines('%s: only in %s' % (s, nameB), B[s] - A[s], 40) if B[s] - A[s] else []
    if onlyA: md += lines('Solutions only in %s' % nameA, onlyA)
    if onlyB: md += lines('Solutions only in %s' % nameB, onlyB)
    open(os.path.join(out, 'parity-L2.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')

# ---------------------------------------------------------------- L3
md = ['# L3: content, %s against %s' % (nameA, nameB), '', 'Compared by a hash of the content (text normalised for line endings). Identical means the same fingerprint.', '',
      '| Type | In %s | In %s | Identical | Different | Only in %s | Only in %s |' % (nameA, nameB, nameA, nameB), '|---|---|---|---|---|---|---|']
details = []
for t, spec in (('Forms', 'Id'), ('Views', 'Id'), ('WebResources', 'Name'), ('PluginAssemblies', 'Name'), ('Workflows', 'Id')):
    ra, rb = rows(dirA, 'hashes-%s.csv' % t), rows(dirB, 'hashes-%s.csv' % t)
    if ra is None or rb is None: continue
    a = {(x[spec].lower() if spec == 'Id' else x[spec]): x for x in ra}; b = {(x[spec].lower() if spec == 'Id' else x[spec]): x for x in rb}
    both = set(a) & set(b); oa, ob = set(a) - set(b), set(b) - set(a)
    # when both sides carry ShaEnv (hashes taken with -Normalise) use it: it ignores ids and codes that always differ between environments
    sh = (lambda r: r['ShaEnv']) if (a and b and all('ShaEnv' in r for r in list(a.values())[:1] + list(b.values())[:1])) else (lambda r: r['ShaNorm'])
    same = [k for k in both if sh(a[k]) == sh(b[k])]; dif = [k for k in both if sh(a[k]) != sh(b[k])]
    summary['L3'][t] = dict(A=len(a), B=len(b), identical=len(same), different=len(dif), onlyA=len(oa), onlyB=len(ob))
    md.append('| %s | %d | %d | %d | %d | %d | %d |' % (t, len(a), len(b), len(same), len(dif), len(oa), len(ob)))
    if dif: details += lines('%s with different content' % t, ['%s (%s: %s bytes, %s: %s bytes)' % (a[k]['Name'], nameA, a[k]['Bytes'], nameB, b[k]['Bytes']) for k in dif])
    if oa: details += lines('%s only in %s' % (t, nameA), [a[k]['Name'] for k in oa])
    if ob: details += lines('%s only in %s' % (t, nameB), [b[k]['Name'] for k in ob])
open(os.path.join(out, 'parity-L3.md'), 'w', encoding='utf-8').write('\n'.join(md + details) + '\n')
json.dump(summary, open(os.path.join(out, 'summary.json'), 'w'), indent=1)
print(json.dumps(summary, indent=1))
