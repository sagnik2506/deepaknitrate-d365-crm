"""Regenerates the pipeline config files in pipelines/config from the baseline workbook (and, optionally, the production solution list). Offline only.
Run from the repo root:  python tools/scripts/pipeline/make_pipeline_config.py [--prod-solutions-csv <path>]
Warning: it overwrites the config files, including approved-web-resources.json. Do not run it after the team has filled in approvals unless you copy them back."""
import json, csv, re, os, sys, collections
from openpyxl import load_workbook
import argparse
ap = argparse.ArgumentParser(); ap.add_argument('--workbook', default='environment-setup/01-prepare-uat/UAT-Baseline-Plan-2026-11-09.xlsx'); ap.add_argument('--prod-solutions-csv', default='', help='solutions.csv written by Get-SolutionMembership.ps1 on production; needed only to rebuild production-baseline.json')
args = ap.parse_args()
OUT = 'pipelines/config'
os.makedirs(OUT, exist_ok=True)
wb = load_workbook(args.workbook, data_only=True)
def rows(name):
    ws = wb[name]; h = [c.value for c in ws[1]]
    return [dict(zip(h, r)) for r in ws.iter_rows(min_row=2, values_only=True) if any(v is not None for v in r)]
def dump(name, obj):
    with open(os.path.join(OUT, name), 'w', encoding='utf-8') as f: json.dump(obj, f, indent=2, ensure_ascii=False); f.write('\n')
    print('wrote', name)

# ---------------------------------------------------------------- environments (URLs; UAT-ALIGN is filled in after it is created)
dump('environments.json', {
    '_comment': 'Environment keys used by the pipelines. ALIGN is the working copy of UAT: set its URL after you create it. Only keys in writableEnvironments can ever be changed by a pipeline.',
    'UAT': 'https://deepakgroupuat.crm8.dynamics.com', 'ALIGN': '<set after UAT-ALIGN is created>',
    'DEV': 'https://deepakgroupdevcrm.crm8.dynamics.com', 'SIT': 'https://orgb244b2a8.crm8.dynamics.com', 'PREPROD': 'https://deepakgrouppreprod.crm8.dynamics.com',
    'DEVDNL': 'https://deepakgroupdevdnl.crm8.dynamics.com', 'PROD': 'https://deepakcrmprod.crm8.dynamics.com',
    'alignEnvironmentName': 'UAT-ALIGN', 'writableEnvironments': ['ALIGN'], 'readOnlyEnvironments': ['UAT', 'DEV', 'SIT', 'PREPROD', 'DEVDNL', 'PROD']})

# ---------------------------------------------------------------- production baseline (A5)
if args.prod_solutions_csv:
    ps = list(csv.DictReader(open(args.prod_solutions_csv, encoding='utf-8-sig')))
    dump('production-baseline.json', {'_comment': 'Production customer solutions as read on 6 Nov 2026 (run A). The production watch compares against this file. Update it by hand after reviewing a change.',
        'readOn': '2026-11-06', 'solutions': [{'name': r['uniquename'], 'version': r['version'], 'managed': r['ismanaged'] == 'True'} for r in sorted(ps, key=lambda r: r['uniquename'])]})
else:
    print('production-baseline.json not rewritten (no --prod-solutions-csv)')

# ---------------------------------------------------------------- export order
exp = []
for r in rows('Export-Order'):
    part = r['Part'][0]
    src = r['Export from']
    exp.append({'part': part, 'seq': r['Seq'], 'solution': r['Solution'], 'kind': r['Kind'], 'parent': r['Parent (base)'] or '', 'source': None if src == 'none' else src,
                'versionNeeded': r['Version to export (production)'], 'versionAtSource': r['Version at source'] or '', 'sourceManaged': r['Source managed'] or '', 'importPosition': r['Import position'] or None})
dump('export-order.json', {'_comment': 'From the Export-Order sheet. Part A: archive UAT. Part B: the 31 missing solutions from other systems. Part C: solutions with differences where a matching unmanaged source exists.', 'items': exp})

# ---------------------------------------------------------------- import order
imp = []
for r in rows('Import-Order'):
    part = int(r['Part'][0])
    s = r['Source (export from)'] or ''
    m = re.match(r'(\w+) ([\d.]+) \((\w+)\)', s)
    src = m.group(1) if m else None; sv = m.group(2) if m else ''
    imp.append({'part': part, 'seq': r['Seq'], 'solution': r['Solution'], 'kind': r['Kind'], 'versionToImport': r['Version to import (production)'], 'source': src, 'sourceVersion': sv,
                'special': r['Solution'] == 'HotFixCommissionMasterTable', 'blocked': 'BLOCKED' in str(r['Checks before the import'] or ''), 'noSource': s == 'NO MATCHING SOURCE' or s.startswith('pwc')})
dump('import-order.json', {'_comment': 'From the Import-Order sheet. Part 1: the 31 missing solutions in the order production received them. Part 2: solutions already in UAT-ALIGN that can be re-imported from a verified source. Entries with noSource or special are skipped by the import script.', 'items': imp})

# ---------------------------------------------------------------- candidates for the scripted content steps (nothing is changed until a name is in the approved lists)
sc = rows('Scripts')
dump('web-resources-candidates.json', {'_comment': 'Web resources that differ or are missing (Scripts sheet). Copy a name into approved-web-resources.json to let the F2 stage change it.',
    'items': [{'name': r['Web resource'], 'in': r['In'], 'class': r['Class'], 'suggested': r['Suggested decision']} for r in sc]})
dump('approved-web-resources.json', {'_comment': 'Names the team approved after triage (step C2): "Use production" items. Empty means the F2 stage changes nothing. For web resources missing in UAT-ALIGN add "solution" so the new resource is added to the right solution.', 'approved': []})
gaps = {r['Component']: r['Carried by solutions'] for r in rows('Gaps') if r['Type'] == 'WebResource' and r['Side'] == 'Only in PROD'}
dump('web-resources-solutions.json', {'_comment': 'Solution that carries each web resource that is only in production (Gaps sheet).', 'items': gaps})
pl = [r['Name'] for r in rows('Plugins') if r['Kind'] == 'Assembly']
dump('plugin-assemblies.json', {'_comment': 'Plugin assemblies that differ or are only in production (Plugins sheet). Read-only download in the sources pipeline.', 'names': pl})

ov = [{'optionSet': r['Option set'], 'value': int(r['Value']), 'uatLabel': r['UAT label'] or '', 'prodLabel': r['PROD label'] or '', 'status': r['Status']} for r in rows('OptionSets')]
dump('option-values.json', {'_comment': 'From the OptionSets sheet. The F9 stage adds Only in PROD values. Values Only in UAT are removed only when the stage is run with the remove option and a signed Drop decision.', 'items': ov})

fs = []
for r in rows('Forms-Views-Flows'):
    if r['Type'] != 'Workflow': continue
    m = re.search(r'state UAT (\d), PROD (\d)', r['Difference detail'] or '')
    if m: fs.append({'id': r['Id'], 'name': r['Name'], 'table': r['Table'], 'uatState': int(m.group(1)), 'prodState': int(m.group(2))})
dump('flow-states.json', {'_comment': 'Flows and business rules whose active or draft state differs (Forms-Views-Flows sheet). State 0 = draft, 1 = activated. The F6 stage sets the production state for business rules and classic workflows; cloud flows are skipped unless asked.', 'items': fs})

dump('acceptance.json', {'_comment': 'Acceptance criteria of step I4, applied to the comparison of UAT-ALIGN against production. Edit approvedExtrasOnlyInAlign after the triage (C2) to allow components that exist only in UAT-ALIGN.',
    'onlyInProductionMustBeZero': ['Table', 'Column', 'Form', 'View', 'WebResource', 'PluginAssembly', 'PluginStep', 'Workflow', 'Role'],
    'differentContentMustBeZero': ['Forms', 'Views', 'WebResources', 'PluginAssemblies', 'Workflows'],
    'approvedExtrasOnlyInAlign': {'Table': 0, 'Column': 0, 'Form': 0, 'View': 0, 'WebResource': 0, 'PluginAssembly': 0, 'PluginStep': 0, 'Workflow': 0, 'Role': 0}})
