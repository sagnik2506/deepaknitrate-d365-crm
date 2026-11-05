'use strict';
// Local test harness for STEP 1. It never calls any environment.
// It loads the ORIGINAL file and the STEP1 file into separate sandboxes, runs the four changed functions in the registration order of the
// DNL form (UpdateQuoteProductSalesOrd, OldQuoteProduct, ShowHideOnFSBI, OnLoadQuoteStatus) against FAKE form values and FAKE server
// answers, and compares what each version did (field changes, requests). Usage: node run-harness.js <original.js> <step1.js>
const fs = require('fs');
const vm = require('vm');

const [ORIGINAL, STEP1] = process.argv.slice(2);
if (!ORIGINAL || !STEP1) { console.log('usage: node run-harness.js <original.js> <step1.js>'); process.exit(2); }

const GUID = (n) => '{' + String(n).repeat(8).slice(0, 8) + '-0000-0000-0000-000000000000}';
const fmt = (v) => v instanceof Date ? (isNaN(v) ? 'Invalid Date' : v.toISOString()) : JSON.stringify(v);

function makeWorld(sc) {
  const world = { log: [], requests: [], consoleLines: [], values: JSON.parse(JSON.stringify(sc.form)), data: JSON.parse(JSON.stringify(sc.data)), sc };
  world.respond = (url) => {
    if (sc.throwOnSend) { throw new Error('NetworkError (simulated)'); }
    if (sc.failStatus) { return { status: sc.failStatus, body: '{"error":"simulated failure"}' }; }
    const sel = ((url.match(/\$select=([^&]+)/) || [])[1] || '').split(',');
    let src = null;
    if (/\/quotes\(/.test(url)) { src = world.data.quote; }
    else if (/\/pricelevels\(/.test(url)) { src = world.data.pricelevel; }
    else if (/\/products\(/.test(url)) { src = world.data.product; }
    else { return { status: 404, body: '{}' }; }
    const out = { };
    sel.forEach((f) => { if (f in src) { out[f] = src[f]; } });   // the fake server only returns the columns that were asked for
    return { status: 200, body: JSON.stringify(out) };
  };
  return world;
}

function makeSandbox(world) {
  class XHR {
    constructor() { this.readyState = 0; this.status = 0; }
    open(m, u, async) { this.url = u; world.requests.push(u.replace('https://example.crm', '') + (async === false ? '   [sync]' : '   [async]')); }
    setRequestHeader() { }
    send() {
      const r = world.respond(this.url);
      this.status = r.status; this.responseText = r.body; this.response = r.body; this.readyState = 4;
      if (typeof this.onreadystatechange === 'function') { this.onreadystatechange.call(this); }   // browsers fire this during a sync send
    }
  }
  const attrs = {}, ctrls = {};
  const form = {
    getAttribute: (n) => attrs[n] || (attrs[n] = {
      getValue: () => (n in world.values ? world.values[n] : null),
      setValue: (v) => { world.log.push('attr ' + n + '.setValue(' + fmt(v) + ')'); world.values[n] = v; },
      setRequiredLevel: (l) => world.log.push('attr ' + n + '.setRequiredLevel(' + l + ')'),
    }),
    getControl: (n) => ctrls[n] || (ctrls[n] = {
      setVisible: (v) => world.log.push('ctrl ' + n + '.setVisible(' + v + ')'),
      setDisabled: (v) => world.log.push('ctrl ' + n + '.setDisabled(' + v + ')'),
      addPreSearch: (f) => world.log.push('ctrl ' + n + '.addPreSearch(' + (f && f.name) + ')'),
    }),
  };
  world.executionContext = { getFormContext: () => form };
  return {
    XMLHttpRequest: XHR, console: { log: (...a) => world.consoleLines.push(a.join(' ')) }, Date, JSON, Math, parseInt,
    Xrm: { Utility: { getGlobalContext: () => ({ getClientUrl: () => 'https://example.crm' }) }, Page: {} },
  };
}

function runSequence(file, sc) {
  const world = makeWorld(sc);
  const ctx = vm.createContext(makeSandbox(world));
  vm.runInContext(fs.readFileSync(file, 'utf8'), ctx, { filename: file, timeout: 5000 });
  const order = sc.order || ['UpdateQuoteProductSalesOrd', 'OldQuoteProduct', 'ShowHideOnFSBI', 'OnLoadQuoteStatus'];
  const result = { perFunction: {}, requests: [], globals: {} };
  const loads = sc.loads || 1;
  for (let l = 0; l < loads; l++) {
    if (sc.between && l > 0) { sc.between(world); }
    order.forEach((fn) => {
      const startLog = world.log.length;
      let err = null;
      try { ctx.__ec = world.executionContext; vm.runInContext(fn + '(__ec)', ctx, { timeout: 5000 }); }
      catch (e) { err = (e && e.name ? e.name : 'Error') + ': ' + (e && e.message ? e.message : e); }
      const key = (loads > 1 ? 'load' + (l + 1) + ' ' : '') + fn;
      result.perFunction[key] = { effects: world.log.slice(startLog), error: err };
    });
  }
  result.requests = world.requests.slice();
  ['account', 'productid', 'quoteid'].forEach((g) => { try { result.globals[g] = vm.runInContext('typeof ' + g + ' === "undefined" ? undefined : ' + g, ctx); } catch (e) { result.globals[g] = 'n/a'; } });
  return result;
}

// ---------------------------------------------------------------------------------------------- scenarios
const baseForm = () => ({
  quoteid: [{ id: GUID(1), name: 'Q-1', entityType: 'quote' }], productid: [{ id: GUID(2), name: 'P', entityType: 'product' }],
  dg_pricelist: [{ id: GUID(3), name: 'PL', entityType: 'pricelevel' }], dg_division: 30, dg_salesorganization: 1000,
  dg_effectivetodnl: new Date('2026-12-31T00:00:00Z'), dg_quotestatus: 5,
});
const baseData = () => ({
  quote: { quoteid: '11111111', _customerid_value: 'cust-0001', effectiveto: '2026-12-31T00:00:00Z', dg_division: 30, dg_salesoragnizationsingle: 1000, dg_isitacontract: 140110001, dg_customstatus: 5 },
  pricelevel: { dg_pricelisttype: 140110001 }, product: {},
});
const S = [];
const add = (name, mod, note) => { const sc = { name, form: baseForm(), data: baseData(), note }; mod(sc); S.push(sc); };

add('S1 existing line, non-contract, division 30, price list type 140110001 (the common case)', () => { });
add('S2 existing line, contract quote (dg_isitacontract = 140110000)', (s) => { s.data.quote.dg_isitacontract = 140110000; });
add('S3 new line: sales organisation, division and effective-to are empty', (s) => { delete s.form.dg_salesorganization; delete s.form.dg_division; delete s.form.dg_effectivetodnl; });
add('S4 new line, quote has NO effective-to date (existing behaviour: 1 Jan 1970 is written)', (s) => { delete s.form.dg_salesorganization; delete s.form.dg_division; delete s.form.dg_effectivetodnl; s.data.quote.effectiveto = null; });
add('S5 quote status on the line differs from the quote (3 versus 5)', (s) => { s.form.dg_quotestatus = 3; });
add('S6 quote status on the line is empty', (s) => { delete s.form.dg_quotestatus; });
add('S7 division 40, non-contract, price list type 140110001', (s) => { s.form.dg_division = 40; s.data.quote.dg_division = 40; });
add('S8 division 20 (solvent), non-contract', (s) => { s.form.dg_division = 20; s.data.quote.dg_division = 20; });
add('S9 the server answers 500 for the quote (read fails)', (s) => { s.failStatus = 500; });
add('S10 network error on send (exception)', (s) => { s.throwOnSend = true; }, 'both versions let the error escape to the form, as in production today');
add('S11 quote lookup is empty', (s) => { s.form.quoteid = null; }, 'both versions fail the same way (TypeError), as in production today');
add('S12 product lookup is empty', (s) => { s.form.productid = null; }, 'both versions fail the same way (TypeError), as in production today');
add('S13 two loads in a row; the quote status changes between them (refresh after save)', (s) => { s.loads = 2; s.between = (w) => { w.data.quote.dg_customstatus = 7; }; });
add('S14 only OnLoadQuoteStatus runs twice within 10 s, quote status changes between (form without the first handler)', (s) => {
  s.order = ['OnLoadQuoteStatus']; s.loads = 2; s.between = (w) => { w.data.quote.dg_customstatus = 9; };
}, 'EXPECTED DIFFERENCE: STEP1 may show the previous value for up to DNL_QUOTE_CACHE_TTL_MS when the first handler is not registered');

// ---------------------------------------------------------------------------------------------- run and compare
const lines = [];
const out = (t) => { console.log(t); lines.push(t); };
let same = 0, diff = 0, expectedDiff = 0;
out('STEP 1 HARNESS  (fake data, no environment is called)');
out('original: ' + ORIGINAL); out('step1   : ' + STEP1); out('');
S.forEach((sc) => {
  const a = runSequence(ORIGINAL, sc); const b = runSequence(STEP1, sc);
  const diffs = [];
  Object.keys(a.perFunction).forEach((k) => {
    const x = JSON.stringify(a.perFunction[k]); const y = JSON.stringify(b.perFunction[k]);
    if (x !== y) { diffs.push(k + '\n      original: ' + x + '\n      step1   : ' + y); }
  });
  ['account', 'productid', 'quoteid'].forEach((g) => { if (fmt(a.globals[g]) !== fmt(b.globals[g])) { diffs.push('global ' + g + ': original ' + fmt(a.globals[g]) + ' / step1 ' + fmt(b.globals[g])); } });
  const expected = /EXPECTED DIFFERENCE/.test(sc.note || '');
  const verdict = diffs.length === 0 ? 'SAME' : (expected ? 'DIFFERENT (expected)' : 'DIFFERENT  <<< CHECK');
  if (diffs.length === 0) { same++; } else if (expected) { expectedDiff++; } else { diff++; }
  const syncOld = a.requests.filter((r) => /\[sync\]/.test(r)).length, syncNew = b.requests.filter((r) => /\[sync\]/.test(r)).length;
  out(verdict.padEnd(22) + sc.name);
  out('      requests: original ' + a.requests.length + ' (' + syncOld + ' sync)  ->  step1 ' + b.requests.length + ' (' + syncNew + ' sync)');
  if (sc.note) { out('      note: ' + sc.note); }
  diffs.forEach((d) => out('      DIFF ' + d));
  if (sc.name.startsWith('S1 ')) {
    out('      original requests:'); a.requests.forEach((r) => out('         ' + r));
    out('      step1 requests:'); b.requests.forEach((r) => out('         ' + r));
    out('      effects (original):'); Object.keys(a.perFunction).forEach((k) => out('         ' + k + ': ' + (a.perFunction[k].effects.join('; ') || '(none)') + (a.perFunction[k].error ? '  ERROR ' + a.perFunction[k].error : '')));
  }
  out('');
});
out('SUMMARY: identical ' + same + ', expected differences ' + expectedDiff + ', UNEXPECTED differences ' + diff);
fs.writeFileSync(require('path').join(__dirname, 'harness-results.txt'), lines.join('\n'), 'utf8');
process.exit(diff === 0 ? 0 : 1);
