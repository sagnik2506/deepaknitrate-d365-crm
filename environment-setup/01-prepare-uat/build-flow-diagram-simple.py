"""Draws the proposed flow (steps A to K of the baseline workbook) as a PNG. Offline."""
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 3300, 2640
FD = 'C:/Windows/Fonts/'
def font(name, size): return ImageFont.truetype(FD + name, size)
F_TITLE = font('calibrib.ttf', 68); F_SUB = font('calibri.ttf', 38)
F_H = font('calibrib.ttf', 44); F_STEP = font('calibrib.ttf', 32); F_T = font('calibri.ttf', 33); F_E = font('calibrib.ttf', 32); F_TAG = font('calibri.ttf', 29)
F_ROW = font('calibrib.ttf', 46); F_LBL = font('calibrib.ttf', 34); F_LEG = font('calibri.ttf', 32)

INK = (23, 36, 58); SLATE = (91, 112, 131); ORANGE = (232, 119, 46); TEAL = (31, 138, 138); NAVY = (23, 36, 58); GREEN = (23, 105, 110)
LIGHT = (242, 244, 247); WHITE = (255, 255, 255); RED = (192, 57, 43); GREY = (143, 163, 181)

img = Image.new('RGB', (W, H), WHITE)
d = ImageDraw.Draw(img)

def wrap(text, fnt, width):
    words = text.split(); lines = []; cur = ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if fnt.getlength(t) <= width: cur = t
        else:
            if cur: lines.append(cur)
            cur = w
    if cur: lines.append(cur)
    return lines

def box(x, y, w, h, colour, head, steps, desc, effort, tag):
    d.rounded_rectangle([x, y, x + w, y + h], radius=26, fill=LIGHT, outline=colour, width=5)
    d.rounded_rectangle([x, y, x + w, y + 92], radius=26, fill=colour)
    d.rectangle([x, y + 60, x + w, y + 92], fill=colour)
    d.text((x + 26, y + 20), head, font=F_H, fill=WHITE)
    yy = y + 118
    for line in wrap(desc, F_T, w - 52):
        d.text((x + 26, yy), line, font=F_T, fill=INK); yy += 42
    d.text((x + 26, y + h - 58), tag, font=F_TAG, fill=SLATE)

def arrow(x1, y1, x2, y2, colour=SLATE, width=9, dashed=False):
    import math
    if dashed:
        L = math.hypot(x2 - x1, y2 - y1); n = int(L // 36)
        for i in range(n):
            if i % 2 == 0:
                a = i / n; b = min((i + 1) / n, 1)
                d.line([x1 + (x2 - x1) * a, y1 + (y2 - y1) * a, x1 + (x2 - x1) * b, y1 + (y2 - y1) * b], fill=colour, width=width)
    else:
        d.line([x1, y1, x2, y2], fill=colour, width=width)
    ang = math.atan2(y2 - y1, x2 - x1); s = 34
    p1 = (x2, y2); p2 = (x2 - s * math.cos(ang - 0.42), y2 - s * math.sin(ang - 0.42)); p3 = (x2 - s * math.cos(ang + 0.42), y2 - s * math.sin(ang + 0.42))
    d.polygon([p1, p2, p3], fill=colour)

# ------------------------------------------------------------------ title
d.text((70, 40), 'Proposed flow: align a copy of UAT, build AMS and CR-DEV, test in a production clone', font=F_TITLE, fill=INK)
d.text((70, 135), 'UAT and production are only read; every change is made on UAT-ALIGN (a copy of UAT).', font=F_SUB, fill=SLATE)

BW, BH, GAP, X0 = 700, 440, 120, 70
col = lambda i: X0 + i * (BW + GAP)
rowy = [300, 860, 1420, 1980]
labels = ['1. Prepare and decide  (phases A to D)', '2. Change UAT-ALIGN  (phases E to H)', '3. Verify and hand over', '4. Production clone: install and test  (phase K, can start in parallel after approval)']
for i, t in enumerate(labels):
    d.text((70, rowy[i] - 56), t, font=F_ROW, fill=INK)

# ------------------------------------------------------------------ row 1
box(col(0), rowy[0], BW, BH, SLATE, 'A  Decide and prepare', '', 'Approvals, copy time agreed, git, tools, check production unchanged, create UAT-ALIGN (full copy of UAT).', '', 'Manual and semi-automatic')
box(col(1), rowy[0], BW, BH, SLATE, 'B  Back up and archive', '', 'UAT-ALIGN is the backup. Export every UAT solution, unpack, commit and tag in git.', '', 'Automatic')
box(col(2), rowy[0], BW, BH, SLATE, 'C  Triage UAT-only work', '', 'Release, hold or drop each unreleased script, plugin, form and app. Save the UAT versions in git.', '', 'Manual decisions')
box(col(3), rowy[0], BW, BH, SLATE, 'D  Gather the sources', '', 'Export the 31 missing solutions from dev, SIT, PREPROD, dev DNL. Check each. Copy components by API where no source.', '', 'Semi-automatic')
for i in range(3): arrow(col(i) + BW + 8, rowy[0] + BH // 2, col(i + 1) - 8, rowy[0] + BH // 2)
# ------------------------------------------------------------------ row 2 (right to left)
box(col(3), rowy[1], BW, BH, ORANGE, 'E  Import 31 solutions', '', 'In the order production received them: 3 base solutions, 17 ENT patches, LCAssembly, SIT family, Utility, DPL hotfix. Publish and verify.', '', 'Automatic')
box(col(2), rowy[1], BW, BH, ORANGE, 'F  Align the content', '', '43 scripts, 9 plugins, forms, views, flows, columns, option sets, variables and connections made equal to production.', '', 'Semi-automatic')
box(col(1), rowy[1], BW, BH, ORANGE, 'G  Remove UAT-only items', '', 'Only with a signed Drop decision. Dependency check first, then delete in order.', '', 'Manual')
box(col(0), rowy[1], BW, BH, ORANGE, 'H  Security', '', 'Business units equal to production, roles aligned, field security checked.', '', 'Semi-automatic')
arrow(col(3) + BW // 2, rowy[0] + BH + 8, col(3) + BW // 2, rowy[1] - 8)
for i in (3, 2, 1): arrow(col(i) - 8, rowy[1] + BH // 2, col(i - 1) + BW + 8, rowy[1] + BH // 2)
# ------------------------------------------------------------------ row 3
box(col(0), rowy[2], BW, BH, TEAL, 'I  Re-compare', '', 'Publish, then re-run the three comparison layers and the extra reads on UAT-ALIGN against production.', '', 'Automatic')
arrow(col(0) + BW - 70, rowy[1] + BH + 8, col(0) + BW - 70, rowy[2] - 8)
# decision diamond in column 1
cx, cy = col(1) + BW // 2, rowy[2] + BH // 2
d.polygon([(cx, rowy[2] + 6), (col(1) + BW - 6, cy), (cx, rowy[2] + BH - 6), (col(1) + 6, cy)], fill=WHITE, outline=TEAL, width=6)
for line, dy, f, c in (('Acceptance', -110, F_H, INK), ('criteria met?', -58, F_H, INK), ('Nothing missing,', 22, F_TAG, SLATE), ('nothing different', 60, F_TAG, SLATE)):
    tw = f.getlength(line); d.text((cx - tw / 2, cy + dy), line, font=f, fill=c)
arrow(col(0) + BW + 8, cy, col(1) + 12, cy)
box(col(2), rowy[2], BW, BH, TEAL, 'I  Test and sign off', '', 'Smoke test, Solution Checker, sign-off by dev lead and release owner. UAT-ALIGN becomes the baseline.', '', 'Semi-automatic and manual')
arrow(col(1) + BW - 6, cy, col(2) - 8, cy, TEAL)
d.text((col(1) + BW + 8, cy - 52), 'Yes', font=F_LBL, fill=TEAL)
box(col(3), rowy[2], BW, BH, NAVY, 'J  Create AMS and CR-DEV', '', 'Back up and tag the baseline. Minimal copy of UAT-ALIGN into AMS and CR-DEV. Make safe, agree ways of working.', '', 'Automatic and manual')
arrow(col(2) + BW + 8, cy, col(3) - 8, cy)
# No loop up to G
arrow(cx, rowy[2] + 6 - 2, cx, rowy[1] + BH + 8, RED, 8, dashed=True)
d.text((cx + 22, rowy[1] + BH + 34), 'No: fix, go back to F, G or H', font=F_LBL, fill=RED)
d.text((cx + 22, rowy[1] + BH + 78), 'and compare again', font=F_LBL, fill=RED)
# ------------------------------------------------------------------ row 4: production clone
box(col(0), rowy[3], BW, BH, GREEN, 'K  Approve, copy production', '', 'Written approval. Minimal copy of production (no business records) into PROD-CLONE, or refresh preprod.', '', 'Manual and automatic')
box(col(1), rowy[3], BW, BH, GREEN, 'K  Make safe, prove, seed', '', 'Flows and integrations off, test values set. Compare with production. Load synthetic test data.', '', 'Semi-automatic')
box(col(2), rowy[3], BW, BH, GREEN, 'Install and test', '', 'Import the managed package into PROD-CLONE exactly as for production. Smoke test and change tests. Fix in the authoring environment.', '', 'Automatic and semi-automatic')
box(col(3), rowy[3], BW, BH, GREEN, 'K  Promote and refresh', '', 'Same package to production through the release process, with approval. Refresh the clone before big tests. Decide the future of UAT.', '', 'Manual and automatic')
for i in range(3): arrow(col(i) + BW + 8, rowy[3] + BH // 2, col(i + 1) - 8, rowy[3] + BH // 2, GREEN)
arrow(col(2) + BW // 2, rowy[2] + BH + 8, col(2) + BW // 2, rowy[3] - 8, GREEN)
d.text((col(2) + BW // 2 + 22, rowy[2] + BH + 34), 'managed package', font=F_LBL, fill=GREEN)
# ------------------------------------------------------------------ legend
ly = 2500
d.text((70, ly - 8), 'Legend', font=F_ROW, fill=INK)
items = [(SLATE, 'Prepare and decide'), (ORANGE, 'Changes made on UAT-ALIGN'), (TEAL, 'Verify'), (NAVY, 'Hand over'), (GREEN, 'Production clone (test)')]
x = 370
for c, t in items:
    d.rounded_rectangle([x, ly + 2, x + 54, ly + 46], radius=8, fill=c)
    d.text((x + 70, ly + 4), t, font=F_LEG, fill=INK); x += 70 + int(F_LEG.getlength(t)) + 70
out = sys.argv[1]
img.save(out, dpi=(200, 200))
print('saved', out, img.size)
