"""Builds the full list of items that exist only in UAT (not in production) from saved read-only data. Offline."""
import csv, re, sys
csv.field_size_limit(10**9)
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
P = 'C:/DeepakNitrate/EnvSetup/data/'
L1 = open(P + 'parity/compare-UAT-vs-PROD-final/parity-L1.md', encoding='utf-8').read()
def section(title):
    m = re.search(r'### ' + re.escape(title) + r' \(\d+\)\n(.*?)(?=\n### |\Z)', L1, re.S)
    return [l[2:].strip() for l in m.group(1).splitlines() if l.startswith('- ')]
def rows(path): return list(csv.DictReader(open(path, encoding='utf-8-sig')))
def only(kind, key='Name'):
    u = {(r['Type'], r[key]): r for r in rows(P + 'b8b9/other-types-UAT.csv') if r['Type'] == kind}
    p = {(r['Type'], r[key]) for r in rows(P + 'b8b9/other-types-PROD.csv') if r['Type'] == kind}
    return sorted((k[1], u[k]['Detail']) for k in u if k not in p)
roles_u = {r['Role']: r for r in rows(P + 'b6b7/roleprivileges-UAT.csv')}
roles_p = {r['Role'] for r in rows(P + 'b6b7/roleprivileges-PROD.csv')}
ou = {(r['OptionSet'], r['Value']): r['Label'] for r in rows(P + 'b8b9/optionset-values-UAT.csv')}
op = {(r['OptionSet'], r['Value']) for r in rows(P + 'b8b9/optionset-values-PROD.csv')}
sheets = [
 ('Tables', ['Table'], [[x] for x in section('Table only in UAT')]),
 ('Columns', ['Table.column'], [[x] for x in section('Column only in UAT')]),
 ('Forms', ['Form name'], [[x] for x in section('Form only in UAT')]),
 ('Views', ['View name'], [[x] for x in section('View only in UAT')]),
 ('Canvas apps', ['Name', 'Detail'], [list(x) for x in only('CanvasApp')]),
 ('Custom connectors', ['Name', 'Detail'], [list(x) for x in only('Connector')]),
 ('Connection references', ['Name', 'Detail'], [list(x) for x in only('ConnectionReference')]),
 ('Duplicate rules', ['Name', 'Detail'], [list(x) for x in only('DuplicateRule')]),
 ('Environment variables', ['Name', 'Detail'], [list(x) for x in only('EnvVariable')]),
 ('Custom relationships', ['Name', 'Detail'], [list(x) for x in only('Relationship')]),
 ('Site maps', ['Name', 'Detail'], [list(x) for x in only('SiteMap')]),
 ('Security roles', ['Role', 'Managed'], [[r, roles_u[r]['Managed']] for r in sorted(roles_u) if r not in roles_p]),
 ('Option set values', ['Option set', 'Value', 'Label'], [[k[0], k[1], ou[k]] for k in sorted(ou) if k not in op]),
]
wb = Workbook(); ws = wb.active; ws.title = 'ReadMe'
ws['A1'] = 'Items that exist only in UAT (not in production)'; ws['A1'].font = Font(bold=True, size=14)
ws['A2'] = 'Source: saved read-only data from 6 Nov 2026 (parity L1 comparison, other-types and role reads). Nothing was run to build this list. These are the candidates for phase G (remove from UAT-ALIGN). Nothing is removed without a signed Drop decision from phase C.'
ws['A2'].alignment = Alignment(wrap_text=True, vertical='top'); ws.column_dimensions['A'].width = 34; ws.column_dimensions['B'].width = 10; ws.merge_cells('A2:F2'); ws.row_dimensions[2].height = 60
ws.append([]); ws.append(['Type', 'Count']);
for c in ws[4]: c.font = Font(bold=True)
YEL = PatternFill('solid', fgColor='FFF2CC'); HDR = PatternFill('solid', fgColor='17243A')
for name, hdr, data in sheets:
    ws.append([name, len(data)])
    w = wb.create_sheet(name)
    w.append(hdr + ['Decision (Release / Hold / Drop)', 'Decided by', 'Date', 'Notes'])
    for i, c in enumerate(w[1]):
        c.font = Font(bold=True, color='FFFFFF'); c.fill = HDR if i < len(hdr) else PatternFill('solid', fgColor='7F6000')
    for r in data:
        w.append(r + ['', '', '', ''])
        for c in w[w.max_row][len(hdr):]: c.fill = YEL
    for i in range(len(hdr)): w.column_dimensions[chr(65 + i)].width = 60 if i == 0 else 40
    for i in range(len(hdr), len(hdr) + 4): w.column_dimensions[chr(65 + i)].width = 28
    w.freeze_panes = 'A2'; w.auto_filter.ref = w.dimensions
wb.save(sys.argv[1]); print({n: len(d) for n, h, d in sheets})
