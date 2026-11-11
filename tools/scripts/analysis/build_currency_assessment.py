"""Builds the Currency Field Assessment workbook (Task 2) and fills it from the production run. Offline: reads the 4 Nov candidates workbook and CSV files; calls no environment.

Build the empty workbook (before the production run):
  python tools/scripts/analysis/build_currency_assessment.py build --out analysis/columns-and-money/Currency-Field-Assessment-2026-11-11.xlsx
Fill it from the production run (once, right after the run, before people edit it):
  python tools/scripts/analysis/build_currency_assessment.py fill --workbook <that file> --usage <money-usage-full.csv> --gate-fields <currency-gate-fields.csv> --gate-summary <currency-gate-summary.csv>
Then recalculate in Excel. Nothing here contains individual records: the gate check saves only counts."""
import argparse, csv, sys, datetime
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter as L
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import FormulaRule

FONT = 'Arial'
f_n = Font(name=FONT, size=10); f_b = Font(name=FONT, size=10, bold=True); f_h = Font(name=FONT, size=10, bold=True, color='FFFFFF'); f_t = Font(name=FONT, size=16, bold=True, color='1F3864')
f_h2 = Font(name=FONT, size=12, bold=True, color='1F3864'); f_s = Font(name=FONT, size=10, color='595959')
NAVY = PatternFill('solid', fgColor='1F3864'); TEAL = PatternFill('solid', fgColor='1F8A8A'); AMB = PatternFill('solid', fgColor='C55A11'); YEL = PatternFill('solid', fgColor='FFF2CC'); GREY = PatternFill('solid', fgColor='F2F2F2')
thin = Side(style='thin', color='BFBFBF'); BOR = Border(left=thin, right=thin, top=thin, bottom=thin)
wrap = Alignment(wrap_text=True, vertical='top')
CLASSES = ['Likely decimal', 'Convertible - lower risk', 'Convertible - needs code change', 'Keep as currency', 'Remove - do not convert']
TABLES = {'Quote Product': 'quotedetail', 'Order Product': 'salesorderdetail'}

# column layout of the Fields sheet: (key, header, width, group)
COLS = [('table', 'Table', 16, 'id'), ('name', 'Logical name', 34, 'id'), ('disp', 'Display name', 30, 'id'), ('cat', 'Category', 24, 'id'), ('oldclass', 'Class on 4 Nov', 26, 'earlier'), ('oldwave', 'Wave on 4 Nov', 10, 'earlier'),
        ('o_forms', 'Forms', 7, 'earlier'), ('o_views', 'Views and charts', 8, 'earlier'), ('o_rules', 'Rules and workflows', 9, 'earlier'), ('o_steps', 'Plugin steps', 8, 'earlier'), ('o_reports', 'Reports', 8, 'earlier'),
        ('o_flows', 'Flows', 7, 'earlier'), ('o_scripts', 'Scripts', 8, 'earlier'), ('o_maps', 'Mappings', 8, 'earlier'), ('o_twin', 'Base twin used (4 Nov)', 10, 'earlier'), ('o_conv', 'Conversion seen (dev sample)', 14, 'earlier'),
        ('p_forms', 'Forms', 7, 'prod'), ('p_views', 'Views', 7, 'prod'), ('p_charts', 'Charts', 7, 'prod'), ('p_rules', 'Rules and workflows', 9, 'prod'), ('p_stepdeps', 'Plugin step dependencies', 10, 'prod'),
        ('p_reports', 'Reports', 8, 'prod'), ('p_maps', 'Mappings', 8, 'prod'), ('p_steps', 'Plugin steps by filter', 9, 'prod'), ('p_flows', 'Flows', 7, 'prod'), ('p_scripts', 'Scripts', 8, 'prod'), ('p_pviews', 'Personal views', 8, 'prod'),
        ('t_total', 'Twin dependencies', 9, 'prod'), ('t_steps', 'Twin plugin steps', 9, 'prod'), ('t_reports', 'Twin reports', 8, 'prod'), ('t_flows', 'Twin flows', 8, 'prod'), ('t_scripts', 'Twin scripts', 8, 'prod'), ('t_pviews', 'Twin in personal views (information only)', 11, 'prod'),
        ('p_twin', 'Base twin used in production (excluding personal views)', 13, 'calc'), ('p_twinpv', 'Twin only in personal views', 10, 'calc'),
        ('s_n', 'Sample records with a value', 10, 'prod'), ('s_eq', 'Base equals amount', 9, 'prod'), ('s_div', 'Base = amount / rate', 9, 'prod'), ('s_mul', 'Base = amount x rate', 9, 'prod'), ('s_oth', 'Base differs (other)', 9, 'prod'),
        ('p_conv', 'Conversion seen in production sample', 16, 'calc'),
        ('chg', 'Changed since 4 Nov', 14, 'calc'), ('ans', 'Check 3: does anyone read the _base column?', 18, 'input'),
        ('score', 'Risk score', 8, 'calc'), ('level', 'Risk level', 9, 'calc'), ('sugg', 'Suggested class (rule)', 30, 'calc'),
        ('final', 'Final class', 28, 'input'), ('dec', 'Decision', 18, 'input'), ('owner', 'Owner', 14, 'input'), ('notes', 'Notes', 36, 'input')]
CI = {k: i + 1 for i, (k, *_r) in enumerate(COLS)}
LET = {k: L(i) for k, i in CI.items()}


def style_header(ws, row, ncols, fill=NAVY):
    for c in range(1, ncols + 1):
        x = ws.cell(row=row, column=c); x.font = f_h; x.fill = fill; x.alignment = Alignment(wrap_text=True, vertical='center'); x.border = BOR


def build(out, candidates, dev_dir):
    src = load_workbook(candidates, data_only=False)
    wb = Workbook(); wb.remove(wb.active)
    # ------------------------------------------------------------------ Fields
    wsF = wb.create_sheet('Fields')
    wsF['A1'] = 'Money fields of Quote Product and Order Product'; wsF['A1'].font = f_t
    wsF['A2'] = 'Grey = earlier results (4 Nov, from the UAT audit and dev). Teal = production run (filled by the script). Orange = calculated. Yellow = for you to fill in. Filter the header row.'; wsF['A2'].font = f_s
    groups = {'id': ('Field', NAVY), 'earlier': ('Earlier results (4 Nov 2026, UAT audit and dev)', PatternFill('solid', fgColor='7F7F7F')), 'prod': ('Production run', TEAL), 'calc': ('Calculated', AMB), 'input': ('Review and decision', PatternFill('solid', fgColor='BF8F00'))}
    start = 1
    for i, (k, h, w, g) in enumerate(COLS, 1):
        if i == len(COLS) or COLS[i][3] != g:
            ws_cell = wsF.cell(row=3, column=start, value=groups[g][0]); ws_cell.font = f_h; ws_cell.fill = groups[g][1]
            for c in range(start, i + 1): wsF.cell(row=3, column=c).fill = groups[g][1]
            start = i + 1
    for i, (k, h, w, g) in enumerate(COLS, 1):
        wsF.cell(row=4, column=i, value=h); wsF.column_dimensions[L(i)].width = w
    style_header(wsF, 4, len(COLS)); wsF.row_dimensions[4].height = 58
    r = 5; n_before = r
    for sheet, table in TABLES.items():
        ws = src[sheet]
        for row in ws.iter_rows(min_row=5, values_only=True):
            if not row[1]: continue
            vals = {'table': table, 'name': row[1], 'disp': row[2], 'cat': row[3], 'oldclass': row[4], 'oldwave': row[5], 'o_forms': row[9], 'o_views': row[10], 'o_rules': row[11], 'o_steps': row[12], 'o_reports': row[13],
                    'o_flows': row[14], 'o_scripts': row[15], 'o_maps': row[16], 'o_twin': row[18], 'o_conv': row[17]}
            for k, v in vals.items(): wsF.cell(row=r, column=CI[k], value=v)
            g = lambda k: f'{LET[k]}{r}'
            wsF.cell(row=r, column=CI['p_twin'], value=f'=IF({g("p_forms")}="","",IF({g("t_total")}+{g("t_steps")}+{g("t_reports")}+{g("t_flows")}+{g("t_scripts")}>0,"Yes","No"))')
            wsF.cell(row=r, column=CI['p_twinpv'], value=f'=IF({g("p_forms")}="","",IF(AND({g("p_twin")}="No",{g("t_pviews")}>0),"Yes","No"))')
            wsF.cell(row=r, column=CI['p_conv'], value=f'=IF({g("s_n")}="","",IF({g("s_n")}=0,"No sample data",IF({g("s_eq")}={g("s_n")},"No conversion",IF({g("s_oth")}>0,"Unexplained","Conversion active"))))')
            wsF.cell(row=r, column=CI['chg'], value=f'=IF({g("p_twin")}="","",IF({g("p_twin")}<>IF({g("o_twin")}="Yes","Yes","No"),"Twin use changed",IF(ABS({g("p_steps")}-{g("o_steps")})+ABS({g("p_flows")}-{g("o_flows")})+ABS({g("p_reports")}-{g("o_reports")})>0,"Counts changed","")))')
            wsF.cell(row=r, column=CI['score'], value=f'=IF({g("p_forms")}="","",3*(({g("p_stepdeps")}+{g("p_steps")})>0)+2*({g("p_reports")}>0)+2*({g("p_flows")}>0)+2*({g("p_maps")}>0)+({g("p_rules")}>0)+IF({g("p_scripts")}>=10,2,IF({g("p_scripts")}>=1,1,0))+2*({g("p_conv")}="Conversion active"))')
            wsF.cell(row=r, column=CI['level'], value=f'=IF({g("score")}="","",IF({g("score")}>=6,"High",IF({g("score")}>=3,"Medium","Low")))')
            wsF.cell(row=r, column=CI['sugg'], value=f'=IF({g("ans")}="","Keep as currency until check 3 is answered",IF({g("ans")}<>"Does not read _base","Keep as currency",IF({g("p_twin")}="Yes","Keep as currency",{g("oldclass")})))')
            for c in range(1, len(COLS) + 1):
                x = wsF.cell(row=r, column=c); x.font = f_n; x.border = BOR; x.alignment = Alignment(vertical='top', wrap_text=(CI['dec'] <= c or c in (CI['sugg'], CI['cat'], CI['disp'])))
                grp = COLS[c - 1][3]
                if grp == 'input': x.fill = YEL
            r += 1
    last = r - 1
    wsF.freeze_panes = wsF.cell(row=5, column=4); wsF.auto_filter.ref = f'A4:{L(len(COLS))}{last}'
    dv = DataValidation(type='list', formula1='"Reads _base,Does not read _base,Unknown,Not asked"', allow_blank=True); wsF.add_data_validation(dv); dv.add(f'{LET["ans"]}5:{LET["ans"]}{last}')
    dv2 = DataValidation(type='list', formula1='"' + ','.join(CLASSES) + '"', allow_blank=True); wsF.add_data_validation(dv2); dv2.add(f'{LET["final"]}5:{LET["final"]}{last}')
    dv3 = DataValidation(type='list', formula1='"Approve for wave,Hold,Reject,Needs data check"', allow_blank=True); wsF.add_data_validation(dv3); dv3.add(f'{LET["dec"]}5:{LET["dec"]}{last}')
    for text, colour in (('High', 'F8CBAD'), ('Medium', 'FFE699'), ('Low', 'C6E0B4')):
        wsF.conditional_formatting.add(f'{LET["level"]}5:{LET["level"]}{last}', FormulaRule(formula=[f'{LET["level"]}5="{text}"'], fill=PatternFill('solid', bgColor=colour, fgColor=colour)))
    wsF.conditional_formatting.add(f'{LET["chg"]}5:{LET["chg"]}{last}', FormulaRule(formula=[f'{LET["chg"]}5<>""'], fill=PatternFill('solid', bgColor='F8CBAD', fgColor='F8CBAD')))
    FR = lambda k: f'Fields!${LET[k]}$5:${LET[k]}${last}'

    # ------------------------------------------------------------------ Summary
    ws = wb.create_sheet('Summary', 0); ws.sheet_view.showGridLines = False
    ws['A1'] = 'Currency Field Assessment: summary'; ws['A1'].font = f_t
    ws['A2'] = 'All counts are formulas over the Fields sheet and update as you fill it in.'; ws['A2'].font = f_s
    ws['A4'] = 'Progress'; ws['A4'].font = f_h2
    prog = [('Money fields', f'=COUNTA({FR("name")})'), ('Fields loaded from the production run', f'=COUNT({FR("p_forms")})'), ('Fields with a production sample result', f'=COUNT({FR("s_n")})'),
            ('Check 3 answered (reads or does not read)', f'=COUNTIF({FR("ans")},"Reads _base")+COUNTIF({FR("ans")},"Does not read _base")'), ('Fields with a decision', f'=COUNTA({FR("dec")})')]
    for i, (k, f) in enumerate(prog, 5): ws.cell(row=i, column=1, value=k).font = f_n; c = ws.cell(row=i, column=2, value=f); c.font = f_b
    r0 = 5 + len(prog) + 1
    ws.cell(row=r0, column=1, value='Suggested class (rule) by table').font = f_h2
    ws.cell(row=r0 + 1, column=1, value='Class'); ws.cell(row=r0 + 1, column=2, value='quotedetail'); ws.cell(row=r0 + 1, column=3, value='salesorderdetail'); ws.cell(row=r0 + 1, column=4, value='Total'); style_header(ws, r0 + 1, 4)
    sugg_labels = ['Keep as currency until check 3 is answered', 'Keep as currency'] + [c for c in CLASSES if c != 'Keep as currency']
    for i, lab in enumerate(sugg_labels, r0 + 2):
        ws.cell(row=i, column=1, value=lab).font = f_n
        for j, t in enumerate(('quotedetail', 'salesorderdetail'), 2):
            ws.cell(row=i, column=j, value=f'=COUNTIFS({FR("table")},"{t}",{FR("sugg")},$A{i})').font = f_n
        ws.cell(row=i, column=4, value=f'=B{i}+C{i}').font = f_b
    r1 = r0 + 2 + len(sugg_labels) + 1
    ws.cell(row=r1, column=1, value='Final class (your decision) by table').font = f_h2
    ws.cell(row=r1 + 1, column=1, value='Class'); ws.cell(row=r1 + 1, column=2, value='quotedetail'); ws.cell(row=r1 + 1, column=3, value='salesorderdetail'); ws.cell(row=r1 + 1, column=4, value='Total'); style_header(ws, r1 + 1, 4)
    for i, lab in enumerate(CLASSES, r1 + 2):
        ws.cell(row=i, column=1, value=lab).font = f_n
        for j, t in enumerate(('quotedetail', 'salesorderdetail'), 2): ws.cell(row=i, column=j, value=f'=COUNTIFS({FR("table")},"{t}",{FR("final")},$A{i})').font = f_n
        ws.cell(row=i, column=4, value=f'=B{i}+C{i}').font = f_b
    r2 = r1 + 2 + len(CLASSES) + 1
    ws.cell(row=r2, column=1, value='Risk level (production counts)').font = f_h2
    for i, lab in enumerate(('High', 'Medium', 'Low'), r2 + 1):
        ws.cell(row=i, column=1, value=lab).font = f_n; ws.cell(row=i, column=2, value=f'=COUNTIF({FR("level")},"{lab}")').font = f_b
    r3 = r2 + 5
    ws.cell(row=r3, column=1, value='Changes since 4 Nov').font = f_h2
    ws.cell(row=r3 + 1, column=1, value='Base twin used in production').font = f_n; ws.cell(row=r3 + 1, column=2, value=f'=COUNTIF({FR("p_twin")},"Yes")').font = f_b
    ws.cell(row=r3 + 2, column=1, value='Conversion active in the production sample').font = f_n; ws.cell(row=r3 + 2, column=2, value=f'=COUNTIF({FR("p_conv")},"Conversion active")').font = f_b
    ws.cell(row=r3 + 3, column=1, value='Fields flagged as changed since 4 Nov').font = f_n; ws.cell(row=r3 + 3, column=2, value=f'=COUNTIF({FR("chg")},"?*")').font = f_b
    ws.column_dimensions['A'].width = 52
    for c in 'BCD': ws.column_dimensions[c].width = 18

    # ------------------------------------------------------------------ ReadMe
    wsR = wb.create_sheet('ReadMe', 0); wsR.sheet_view.showGridLines = False
    lines = [('Currency Field Assessment (Task 2)', f_t),
             ('Which money (currency) fields of Quote Product and Order Product can safely become decimal for the CR, based on how they are used in PRODUCTION and on who reads their base-currency (_base) twins.', f_n),
             ('Built 11 Nov 2026. Starting list: the 250 money fields of analysis/columns-and-money/Money-Fields-Decimal-Candidates-2026-11-04.xlsx (UAT audit, dev data). The production run replaces those counts.', f_s), ('', f_n),
             ('How to use', f_h2),
             ('1. Run the production reads (Production-Run-Log sheet lists them), then fill the production columns with: python tools/scripts/analysis/build_currency_assessment.py fill ...', f_n),
             ('2. Fields sheet: teal columns come from production. "Changed since 4 Nov" flags fields whose twin use or dependency counts moved. Risk score and level are calculated.', f_n),
             ('   A base twin counts as used when a platform dependency, plugin step filter, report, flow or script mentions it. Appearing in a personal view is shown separately: a single personal view that lists many columns would otherwise make every twin look used.', f_n),
             ('3. Questions sheet: send the questions to finance, reporting and integration owners. Put each answer into "Check 3" on the Fields sheet (or per group of fields).', f_n),
             ('4. Rule used for the suggested class: a field stays "Keep as currency" until check 3 is answered "Does not read _base" and its twin is not used in production. Not answered means yes, somebody reads it.', f_n),
             ('5. Choose the Final class and a Decision (yellow cells). Summary counts update.', f_n), ('', f_n),
             ('What the production run reads', f_h2),
             ('Get-MoneyFieldUsage.ps1: configuration and metadata only (platform dependencies and mentions in plugin filters, reports, flows, personal views and scripts). No records.', f_n),
             ('Get-CurrencyGateCheck.ps1 check 1: counts of records by currency and exchange rate (aggregate counts).', f_n),
             ('Get-CurrencyGateCheck.ps1 check 2: reads a SAMPLE of records (first 500 per table by primary key) in memory to compare each money field with its _base value. APPROVED BY THE OWNER on 11 Nov 2026. Only counts per field are saved (equal, divided by rate, times rate, other). No individual value is written to any file.', f_b), ('', f_n),
             ('Limits', f_h2),
             ('A sample of 500 records is not proof: fields with no foreign-currency rows in the sample may show "No conversion". Confirm with the full counts and with check 3.', f_n),
             ('The full count in check 1 is limited to 50,000 records by the platform. If it fails the script says so.', f_n),
             ('Usage counts show platform dependencies and name mentions. They cannot see Power BI, finance spreadsheets or external interfaces: that is what the Questions sheet is for.', f_n),
             ('Nothing here is approved until the Decision column says so. Money cannot be converted in place: each conversion needs a new decimal column, a data copy, repointing and a deprecation period (see the 4 Nov workbook, sheets Conversion Steps and Consequences).', f_n)]
    for i, (t, f) in enumerate(lines, 1):
        c = wsR.cell(row=i, column=1, value=t); c.font = f; c.alignment = Alignment(wrap_text=True, vertical='top')
    wsR.column_dimensions['A'].width = 150

    # ------------------------------------------------------------------ Currency-Check
    wsC = wb.create_sheet('Currency-Check')
    wsC['A1'] = 'Currency gate: production result next to the dev result (3 Nov)'; wsC['A1'].font = f_t
    wsC['A3'] = 'Gate'; wsC['B3'] = 'Production result'; wsC['C3'] = 'Production status'; wsC['D3'] = 'Dev result (3 Nov)'; wsC['E3'] = 'Dev status'; style_header(wsC, 3, 5)
    gates = [('1. Are records in several currencies?', 'Dev: 5 currencies on both tables; about 15% of Quote Product lines and 14% of Order Product lines are not INR.', 'Met: multi-currency'),
             ('2. Does the platform convert them?', 'Dev sample: base = amount / rate for 1,119 comparisons, no unexplained differences.', 'Met: conversion active'),
             ('3. Does nobody read the _base columns?', 'Dev: not answerable from data. See the Questions sheet.', 'OPEN: unanswered')]
    for i, (a, b, c) in enumerate(gates, 4):
        wsC.cell(row=i, column=1, value=a); wsC.cell(row=i, column=4, value=b); wsC.cell(row=i, column=5, value=c)
        wsC.cell(row=i, column=2).fill = YEL; wsC.cell(row=i, column=3).fill = YEL
        for cc in range(1, 6): wsC.cell(row=i, column=cc).font = f_n; wsC.cell(row=i, column=cc).alignment = wrap; wsC.cell(row=i, column=cc).border = BOR
    for col, w in zip('ABCDE', (42, 50, 26, 60, 24)): wsC.column_dimensions[col].width = w
    wsC['A9'] = 'Production run (filled from currency-gate-summary.csv)'; wsC['A9'].font = f_h2
    for i, h in enumerate(('Table', 'Check', 'Value', 'Records'), 1): wsC.cell(row=10, column=i, value=h)
    style_header(wsC, 10, 4, TEAL)
    wsC['G9'] = 'Dev run on 3 Nov (reference, from currency-gate-summary.csv)'; wsC['G9'].font = f_h2
    for i, h in enumerate(('Table', 'Check', 'Value', 'Records'), 7): wsC.cell(row=10, column=i, value=h)
    style_header(wsC, 10, 4, PatternFill('solid', fgColor='7F7F7F'));
    for c in range(7, 11): wsC.cell(row=10, column=c).font = f_h; wsC.cell(row=10, column=c).fill = PatternFill('solid', fgColor='7F7F7F')
    for c in range(1, 5): wsC.cell(row=10, column=c).fill = TEAL
    try:
        dev = list(csv.DictReader(open(dev_dir + '/currency-gate-summary.csv', encoding='utf-8-sig')))
        for i, d in enumerate(dev, 11):
            for j, k in enumerate(('Table', 'Check', 'Value', 'Records'), 7): c = wsC.cell(row=i, column=j, value=(int(d[k]) if (k == 'Records' and d[k].isdigit()) else d[k])); c.font = f_n
    except Exception as e: print('dev reference not loaded:', e)
    for col, w in zip('FGHIJ', (3, 20, 44, 14, 12)): wsC.column_dimensions[col].width = w

    # ------------------------------------------------------------------ Usage-Detail
    wsU = wb.create_sheet('Usage-Detail')
    wsU['A1'] = 'Where each field and its twin is used (production). Filled from money-usage-full.csv: counts and names of plugin steps, reports, flows, personal views and scripts.'; wsU['A1'].font = f_s
    for i, h in enumerate(USAGE_HEADERS, 1): wsU.cell(row=3, column=i, value=h); wsU.column_dimensions[L(i)].width = 18 if i > 4 else 28
    style_header(wsU, 3, len(USAGE_HEADERS), TEAL); wsU.freeze_panes = 'C4'

    # ------------------------------------------------------------------ Questions
    wsQ = wb.create_sheet('Questions')
    wsQ['A1'] = 'Check 3: who reads the base-currency (_base) columns?'; wsQ['A1'].font = f_t
    wsQ['A2'] = 'Only the owners can answer these. Not answered means yes, somebody reads it, so the field stays as currency.'; wsQ['A2'].font = f_s
    hdr = ['#', 'Audience', 'Question', 'Why it matters', 'Owner (name)', 'Asked on', 'Answer', 'Answered on', 'Applies to']
    for i, h in enumerate(hdr, 1): wsQ.cell(row=4, column=i, value=h)
    style_header(wsQ, 4, len(hdr))
    qs = [('Finance', 'Do any finance reports, spreadsheets or reconciliations use the base-currency amount (the _base column or the "(Base)" field) of quote or order lines?', 'A conversion removes the automatic base-currency value for foreign-currency lines.', 'All fields'),
          ('Finance', 'Which amounts must be shown and totalled in INR across currencies (for example order value, freight, commission)?', 'Decides which fields must stay as currency.', 'Key amounts'),
          ('Reporting / Power BI', 'Do any Power BI reports, dashboards, charts or Excel exports read the _base columns of Quote Product or Order Product?', 'Reports are not visible from the platform dependencies.', 'All fields'),
          ('Reporting / Power BI', 'Do any reports sum amounts across currencies using the base value?', 'Summing decimals without a currency gives wrong totals for foreign lines.', 'All fields'),
          ('Integration (SAP)', 'Does the CRM to SAP or SAP to CRM interface read or write the _base columns, or only the transaction-currency amounts?', 'Mappings and flows need to change if base values are used.', 'Integrated fields'),
          ('Integration (SAP)', 'Which of the money fields are sent to SAP, and in which currency?', 'These fields cannot change type without changing the interface.', 'Integrated fields'),
          ('Sales operations', 'Which fields are entered by users as an amount in the customer currency and must keep the currency symbol and formatting?', 'A decimal field loses the currency symbol and automatic formatting.', 'Key amounts'),
          ('Product owner', 'Which fields are really rates, factors, tolerances or norms stored as money by mistake (for example freight tolerance, RM norm)?', 'These are the safest to convert first (wave 1).', 'Likely decimal'),
          ('Dev lead', 'Do the exchange rate and currency fields on the quote and order lines stay in use after the CR?', 'If foreign-currency lines stay, platform conversion stays relevant.', 'All fields'),
          ('Platform admin', 'Is the base currency of the production organisation INR, and which currencies are active?', 'Confirms the production gate result.', 'All fields')]
    for i, (a, q, w, ap) in enumerate(qs, 5):
        for j, v in enumerate((i - 4, a, q, w, '', '', '', '', ap), 1):
            c = wsQ.cell(row=i, column=j, value=v); c.font = f_n; c.alignment = wrap; c.border = BOR
        for j in (5, 6, 7, 8): wsQ.cell(row=i, column=j).fill = YEL
    for col, w in zip('ABCDEFGHI', (5, 20, 70, 50, 18, 12, 40, 12, 18)): wsQ.column_dimensions[col].width = w

    # ------------------------------------------------------------------ Production-Run-Log
    wsL = wb.create_sheet('Production-Run-Log')
    wsL['A1'] = 'Production run log (audit trail)'; wsL['A1'].font = f_t
    wsL['A2'] = 'Planned start: 11 Nov 2026, 20:15 IST, on the owner\'s go. Everything is GET only. Check 2 reads a sample of records and saves only counts; approved by the owner on 11 Nov 2026.'; wsL['A2'].font = f_s
    hdr = ['#', 'What', 'Script', 'Reads', 'Planned (IST)', 'Started (IST)', 'Finished (IST)', 'Health check before', 'Requests / duration', 'Output files', 'Result', 'Checked by']
    for i, h in enumerate(hdr, 1): wsL.cell(row=4, column=i, value=h)
    style_header(wsL, 4, len(hdr))
    plan = [('Health check', 'Production health check (read only)', 'Sign-in, system jobs, imports, failed jobs', '20:15'),
            ('Dependencies and usage of the money fields', 'Get-MoneyFieldUsage.ps1', 'Metadata and dependencies; no records', '20:15'),
            ('Currency gate: check 1 and check 2', 'Get-CurrencyGateCheck.ps1', 'Counts by currency and rate; sample of records compared in memory, counts saved', '20:15')]
    for i, (a, b, c, d) in enumerate(plan, 5):
        for j, v in enumerate((i - 4, a, b, c, d), 1): x = wsL.cell(row=i, column=j, value=v); x.font = f_n; x.alignment = wrap; x.border = BOR
        for j in range(6, 13): wsL.cell(row=i, column=j).fill = YEL; wsL.cell(row=i, column=j).border = BOR
    for col, w in zip('ABCDEFGHIJKL', (4, 36, 30, 46, 12, 14, 14, 26, 20, 30, 24, 14)): wsL.column_dimensions[col].width = w

    # ------------------------------------------------------------------ Decisions
    wsD = wb.create_sheet('Decisions')
    wsD['A1'] = 'Decisions by wave'; wsD['A1'].font = f_t
    wsD['A2'] = 'One row per wave once the Fields sheet is reviewed. A wave is approved by the business owner, finance owner and release owner.'; wsD['A2'].font = f_s
    hdr = ['Wave', 'Classes included', 'Fields approved (formula)', 'Approved by (business owner)', 'Finance owner', 'Release owner', 'Date', 'Conditions', 'Notes']
    for i, h in enumerate(hdr, 1): wsD.cell(row=4, column=i, value=h)
    style_header(wsD, 4, len(hdr))
    waves = [('Wave 1', 'Likely decimal'), ('Wave 2', 'Convertible - lower risk'), ('Wave 3', 'Convertible - needs code change'), ('Hold', 'Keep as currency')]
    for i, (w, cl) in enumerate(waves, 5):
        for j, v in enumerate((w, cl, f'=COUNTIFS({FR("final")},"{cl}",{FR("dec")},"Approve for wave")'), 1): x = wsD.cell(row=i, column=j, value=v); x.font = f_n; x.border = BOR
        for j in range(4, 10): wsD.cell(row=i, column=j).fill = YEL; wsD.cell(row=i, column=j).border = BOR
    for col, w in zip('ABCDEFGHI', (10, 34, 18, 24, 18, 18, 12, 40, 36)): wsD.column_dimensions[col].width = w

    order = ['ReadMe', 'Summary', 'Fields', 'Currency-Check', 'Usage-Detail', 'Questions', 'Production-Run-Log', 'Decisions']
    wb._sheets = [wb[n] for n in order]
    wb.save(out); print('saved', out, 'fields:', last - n_before + 1)


USAGE_HEADERS = ["Table", "LogicalName", "DisplayName", "TwinName", "FieldDepsTotal", "FieldForms", "FieldViews", "FieldCharts", "FieldWorkflowsOrRules", "FieldPluginStepDeps", "FieldReports", "FieldMappings", "FieldSecurityProfiles", "FieldWebResources",
                 "FieldOtherDeps", "TwinDepsTotal", "TwinForms", "TwinViews", "TwinCharts", "TwinWorkflowsOrRules", "TwinPluginStepDeps", "TwinReports", "TwinMappings", "TwinOtherDeps", "FieldPluginSteps", "FieldPluginStepsNames", "TwinPluginSteps",
                 "TwinPluginStepsNames", "FieldReportsNames", "TwinReportsNames", "FieldFlows", "FieldFlowsNames", "TwinFlows", "TwinFlowsNames", "FieldPersonalViews", "FieldPersonalViewsNames", "TwinPersonalViews", "TwinPersonalViewsNames", "FieldScripts",
                 "FieldScriptsNames", "TwinScripts", "TwinScriptsNames"]


def num(v):
    try: return int(float(v))
    except Exception: return v


def fill(path, usage, gate_fields, gate_summary):
    wb = load_workbook(path); wsF = wb['Fields']
    rows = {}
    for r in range(5, wsF.max_row + 1):
        if wsF.cell(row=r, column=CI['name']).value: rows[(wsF.cell(row=r, column=CI['table']).value, wsF.cell(row=r, column=CI['name']).value)] = r
    U = list(csv.DictReader(open(usage, encoding='utf-8-sig'))); loaded = 0
    for u in U:
        r = rows.get((u['Table'], u['LogicalName']))
        if not r: continue
        m = {'p_forms': u['FieldForms'], 'p_views': u['FieldViews'], 'p_charts': u['FieldCharts'], 'p_rules': u['FieldWorkflowsOrRules'], 'p_stepdeps': u['FieldPluginStepDeps'], 'p_reports': u['FieldReports'], 'p_maps': u['FieldMappings'],
             'p_steps': u['FieldPluginSteps'], 'p_flows': u['FieldFlows'], 'p_scripts': u['FieldScripts'], 'p_pviews': u['FieldPersonalViews'], 't_total': u['TwinDepsTotal'], 't_steps': u['TwinPluginSteps'], 't_reports': u['TwinReports'] if 'TwinReports' in u else 0,
             't_flows': u['TwinFlows'], 't_scripts': u['TwinScripts'], 't_pviews': u['TwinPersonalViews']}
        for k, v in m.items(): wsF.cell(row=r, column=CI[k], value=num(v or 0)); loaded += 1
    new = [u for u in U if (u['Table'], u['LogicalName']) not in rows]
    # usage detail
    wsU = wb['Usage-Detail']
    for i, u in enumerate(U, 4):
        for j, h in enumerate(USAGE_HEADERS, 1): c = wsU.cell(row=i, column=j, value=num(u.get(h, ''))); c.font = f_n
    G = list(csv.DictReader(open(gate_fields, encoding='utf-8-sig')))
    for g in G:
        r = rows.get((g['Table'], g['LogicalName']))
        if not r: continue
        for k, h in (('s_n', 'SampleRecordsWithValue'), ('s_eq', 'BaseEqualsAmount'), ('s_div', 'BaseEqualsAmountDividedByRate'), ('s_mul', 'BaseEqualsAmountTimesRate'), ('s_oth', 'BaseOther')): wsF.cell(row=r, column=CI[k], value=num(g[h]))
    wsC = wb['Currency-Check']
    for i, d in enumerate(csv.DictReader(open(gate_summary, encoding='utf-8-sig')), 11):
        for j, k in enumerate(('Table', 'Check', 'Value', 'Records'), 1): c = wsC.cell(row=i, column=j, value=(int(d[k]) if (k == 'Records' and d[k].isdigit()) else d[k])); c.font = f_n
    wb.save(path); print('filled', path, '| usage rows:', len(U), '| gate rows:', len(G), '| usage rows not matched to a field:', len(new))


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest='cmd', required=True)
    b = sub.add_parser('build'); b.add_argument('--out', required=True); b.add_argument('--candidates', default='analysis/columns-and-money/Money-Fields-Decimal-Candidates-2026-11-04.xlsx'); b.add_argument('--dev-dir', default='C:/DeepakNitrate/currency-gate')
    f = sub.add_parser('fill'); f.add_argument('--workbook', required=True); f.add_argument('--usage', required=True); f.add_argument('--gate-fields', required=True); f.add_argument('--gate-summary', required=True)
    a = ap.parse_args()
    if a.cmd == 'build': build(a.out, a.candidates, a.dev_dir)
    else: fill(a.workbook, a.usage, a.gate_fields, a.gate_summary)
