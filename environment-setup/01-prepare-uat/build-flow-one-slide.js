// One slide, native PowerPoint shapes only (no pictures): the proposed flow, without timelines and step numbers.
const pptxgen = require('pptxgenjs');
const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5 in
const s = pres.addSlide();
s.background = { color: 'FFFFFF' };

const INK = '17243A', SLATE = '5B7083', ORANGE = 'E8772E', TEAL = '1F8A8A', NAVY = '17243A', GREEN = '17696E', LIGHT = 'F2F4F7', RED = 'C0392B';
const FONT = 'Calibri';
const BW = 2.85, BH = 1.05, GAP = 0.45, X0 = 0.29;
const colX = i => X0 + i * (BW + GAP);
const rowY = [1.28, 2.78, 4.28, 5.78];
const HEAD = 0.3;

s.addText('Proposed flow: align a copy of UAT, build AMS and CR-DEV, test in a production clone', { x: 0.29, y: 0.12, w: 12.7, h: 0.5, fontFace: FONT, fontSize: 24, bold: true, color: INK, margin: 0 });
s.addText('UAT and production are only read; every change is made on UAT-ALIGN (a copy of UAT).', { x: 0.29, y: 0.62, w: 12.7, h: 0.3, fontFace: FONT, fontSize: 12, color: SLATE, margin: 0 });

const labels = ['1. Prepare and decide  (phases A to D)', '2. Change UAT-ALIGN  (phases E to H)', '3. Verify and hand over', '4. Production clone: install and test  (phase K, can start in parallel after approval)'];
labels.forEach((t, i) => s.addText(t, { x: 0.29, y: rowY[i] - 0.33, w: 7.5, h: 0.3, fontFace: FONT, fontSize: 13, bold: true, color: INK, margin: 0 }));

function box(x, y, colour, head, desc, tag) {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: BW, h: BH, fill: { color: LIGHT }, line: { color: colour, width: 1.75 }, rectRadius: 0.08 });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w: BW, h: HEAD, fill: { color: colour }, line: { color: colour, width: 1.75 }, rectRadius: 0.08 });
  s.addShape(pres.shapes.RECTANGLE, { x: x + 0.01, y: y + HEAD / 2, w: BW - 0.02, h: HEAD / 2, fill: { color: colour }, line: { color: colour, width: 0 } });
  s.addText(head, { x: x + 0.08, y, w: BW - 0.16, h: HEAD, fontFace: FONT, fontSize: 12.5, bold: true, color: 'FFFFFF', valign: 'middle', margin: 0 });
  s.addText(desc, { x: x + 0.08, y: y + HEAD + 0.03, w: BW - 0.16, h: BH - HEAD - 0.27, fontFace: FONT, fontSize: 9.5, color: INK, valign: 'top', margin: 0 });
  s.addText(tag, { x: x + 0.08, y: y + BH - 0.24, w: BW - 0.16, h: 0.2, fontFace: FONT, fontSize: 8.5, color: SLATE, valign: 'middle', margin: 0 });
}
// arrows: straight lines with an arrowhead. flipH/flipV give the direction.
function arrow(x1, y1, x2, y2, colour = SLATE, dashed = false) {
  const o = { x: Math.min(x1, x2), y: Math.min(y1, y2), w: Math.abs(x2 - x1), h: Math.abs(y2 - y1), line: { color: colour, width: 2.25, endArrowType: 'triangle', dashType: dashed ? 'dash' : 'solid' } };
  if (x2 < x1) o.flipH = true;
  if (y2 < y1) o.flipV = true;
  s.addShape(pres.shapes.LINE, o);
}

// row 1
box(colX(0), rowY[0], SLATE, 'A  Decide and prepare', 'Approvals, copy time agreed, git, tools, check production unchanged, create UAT-ALIGN (full copy of UAT).', 'Manual and semi-automatic');
box(colX(1), rowY[0], SLATE, 'B  Back up and archive', 'UAT-ALIGN is the backup. Export every UAT solution, unpack, commit and tag in git.', 'Automatic');
box(colX(2), rowY[0], SLATE, 'C  Triage UAT-only work', 'Release, hold or drop each unreleased script, plugin, form and app. Save the UAT versions in git.', 'Manual decisions');
box(colX(3), rowY[0], SLATE, 'D  Gather the sources', 'Export the 31 missing solutions from dev, SIT, PREPROD, dev DNL. Check each. Copy components by API where no source.', 'Semi-automatic');
for (let i = 0; i < 3; i++) arrow(colX(i) + BW + 0.03, rowY[0] + BH / 2, colX(i + 1) - 0.03, rowY[0] + BH / 2);

// row 2 (right to left)
box(colX(3), rowY[1], ORANGE, 'E  Import 31 solutions', 'In the order production received them: 3 base solutions, 17 ENT patches, LCAssembly, SIT family, Utility, DPL hotfix. Publish and verify.', 'Automatic');
box(colX(2), rowY[1], ORANGE, 'F  Align the content', '43 scripts, 9 plugins, forms, views, flows, columns, option sets, variables and connections made equal to production.', 'Semi-automatic');
box(colX(1), rowY[1], ORANGE, 'G  Remove UAT-only items', 'Only with a signed Drop decision. Dependency check first, then delete in order.', 'Manual');
box(colX(0), rowY[1], ORANGE, 'H  Security', 'Business units equal to production, roles aligned, field security checked.', 'Semi-automatic');
arrow(colX(3) + BW / 2, rowY[0] + BH + 0.03, colX(3) + BW / 2, rowY[1] - 0.03);
for (const i of [3, 2, 1]) arrow(colX(i) - 0.03, rowY[1] + BH / 2, colX(i - 1) + BW + 0.03, rowY[1] + BH / 2);

// row 3
box(colX(0), rowY[2], TEAL, 'I  Re-compare', 'Publish, then re-run the three comparison layers and the extra reads on UAT-ALIGN against production.', 'Automatic');
arrow(colX(0) + BW - 0.3, rowY[1] + BH + 0.03, colX(0) + BW - 0.3, rowY[2] - 0.03);
const cy = rowY[2] + BH / 2;
s.addShape(pres.shapes.DIAMOND, { x: colX(1), y: rowY[2] - 0.02, w: BW, h: BH + 0.04, fill: { color: 'FFFFFF' }, line: { color: TEAL, width: 2 } });
s.addText([{ text: 'Acceptance', options: { breakLine: true, bold: true, fontSize: 12.5, color: INK } }, { text: 'criteria met?', options: { breakLine: true, bold: true, fontSize: 12.5, color: INK } }, { text: 'Nothing missing,', options: { breakLine: true, fontSize: 8, color: SLATE } }, { text: 'nothing different', options: { fontSize: 8, color: SLATE } }],
  { x: colX(1) + 0.55, y: rowY[2] + 0.05, w: BW - 1.1, h: BH - 0.1, fontFace: FONT, align: 'center', valign: 'middle', margin: 0 });
arrow(colX(0) + BW + 0.03, cy, colX(1) + 0.03, cy);
box(colX(2), rowY[2], TEAL, 'I  Test and sign off', 'Smoke test, Solution Checker, sign-off by dev lead and release owner. UAT-ALIGN becomes the baseline.', 'Semi-automatic and manual');
arrow(colX(1) + BW - 0.03, cy, colX(2) - 0.03, cy, TEAL);
s.addText('Yes', { x: colX(1) + BW + 0.02, y: cy - 0.3, w: 0.4, h: 0.25, fontFace: FONT, fontSize: 11, bold: true, color: TEAL, margin: 0 });
box(colX(3), rowY[2], NAVY, 'J  Create AMS and CR-DEV', 'Back up and tag the baseline. Minimal copy of UAT-ALIGN into AMS and CR-DEV. Make safe, agree ways of working.', 'Automatic and manual');
arrow(colX(2) + BW + 0.03, cy, colX(3) - 0.03, cy);
// "No" loop back to the changes
const cxm = colX(1) + BW / 2;
arrow(cxm, rowY[2], cxm, rowY[1] + BH + 0.03, RED, true);
s.addText('No: fix, go back to F, G or H and compare again', { x: cxm + 0.1, y: rowY[2] - 0.33, w: 3.4, h: 0.3, fontFace: FONT, fontSize: 11, bold: true, color: RED, margin: 0 });

// row 4
box(colX(0), rowY[3], GREEN, 'K  Approve, copy production', 'Written approval. Minimal copy of production (no business records) into PROD-CLONE, or refresh preprod.', 'Manual and automatic');
box(colX(1), rowY[3], GREEN, 'K  Make safe, prove, seed', 'Flows and integrations off, test values set. Compare with production. Load synthetic test data.', 'Semi-automatic');
box(colX(2), rowY[3], GREEN, 'Install and test', 'Import the managed package into PROD-CLONE exactly as for production. Smoke test and change tests. Fix in the authoring environment.', 'Automatic and semi-automatic');
box(colX(3), rowY[3], GREEN, 'K  Promote and refresh', 'Same package to production through the release process, with approval. Refresh the clone before big tests. Decide the future of UAT.', 'Manual and automatic');
for (let i = 0; i < 3; i++) arrow(colX(i) + BW + 0.03, rowY[3] + BH / 2, colX(i + 1) - 0.03, rowY[3] + BH / 2, GREEN);
arrow(colX(2) + BW / 2, rowY[2] + BH + 0.03, colX(2) + BW / 2, rowY[3] - 0.03, GREEN);
s.addText('managed package', { x: colX(2) + BW / 2 + 0.1, y: rowY[3] - 0.33, w: 2, h: 0.3, fontFace: FONT, fontSize: 11, bold: true, color: GREEN, margin: 0 });

// legend
const ly = 7.02;
s.addText('Legend', { x: 0.29, y: ly - 0.02, w: 0.9, h: 0.3, fontFace: FONT, fontSize: 13, bold: true, color: INK, margin: 0 });
let lx = 1.3;
[[SLATE, 'Prepare and decide'], [ORANGE, 'Changes made on UAT-ALIGN'], [TEAL, 'Verify'], [NAVY, 'Hand over'], [GREEN, 'Production clone (test)']].forEach(([c, t]) => {
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: lx, y: ly + 0.03, w: 0.3, h: 0.2, fill: { color: c }, line: { color: c, width: 0 }, rectRadius: 0.04 });
  s.addText(t, { x: lx + 0.38, y: ly - 0.02, w: 2.4, h: 0.3, fontFace: FONT, fontSize: 11, color: INK, margin: 0 });
  lx += 0.38 + t.length * 0.085 + 0.45;
});
pres.writeFile({ fileName: process.argv[2] }).then(f => console.log('saved', f));
