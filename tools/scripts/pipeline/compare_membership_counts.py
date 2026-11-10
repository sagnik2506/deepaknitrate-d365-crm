"""D5 check: compares how many components of each type a solution carries in a source environment and in production. Offline, reads two membership.csv files.
Usage: python compare_membership_counts.py <source membership.csv> <production membership.csv> <report.md> [names.txt]
Exit code 1 if any solution has a different count of components of any type. Ids differ between environments, so only counts per type are compared."""
import csv, sys, collections
src, prod, out = sys.argv[1:4]
names = None
if len(sys.argv) > 4: names = {l.strip() for l in open(sys.argv[4], encoding='utf-8') if l.strip()}
def counts(path):
    c = collections.defaultdict(collections.Counter); v = {}
    with open(path, encoding='utf-8-sig', newline='') as f:
        for r in csv.DictReader(f): c[r['Solution']][r['Type']] += 1; v[r['Solution']] = r['Version']
    return c, v
a, va = counts(src); b, vb = counts(prod)
sols = sorted((set(a) if names is None else names & set(a)))
lines = ['# Source check (step D5)', '', '| Solution | Source version | Production version | Result | Difference |', '|---|---|---|---|---|']
bad = 0
for s in sols:
    if s not in b: lines.append('| %s | %s | - | FAIL | not in production membership |' % (s, va.get(s))); bad += 1; continue
    diff = {t: (a[s][t], b[s][t]) for t in set(a[s]) | set(b[s]) if a[s][t] != b[s][t]}
    ok = (not diff) and va.get(s) == vb.get(s)
    if not ok: bad += 1
    lines.append('| %s | %s | %s | %s | %s |' % (s, va.get(s), vb.get(s), 'PASS' if ok else 'FAIL', ', '.join('%s %d vs %d' % (t, x, y) for t, (x, y) in sorted(diff.items())) or ('version differs' if va.get(s) != vb.get(s) else '')))
lines += ['', '**%d of %d solutions fail**' % (bad, len(sols)) if bad else '**All %d solutions match production counts**' % len(sols)]
open(out, 'w', encoding='utf-8').write('\n'.join(lines) + '\n'); print('\n'.join(lines[-1:]))
sys.exit(1 if bad else 0)
