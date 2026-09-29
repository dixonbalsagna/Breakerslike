#!/usr/bin/env node
// What the baseline would look like with each confirmed bug patched: node qa/known-bugs-whatif.js [--matches=1000] [--only=KB-003,KB-004]
// Each patch is the obvious one-line change applied to a SCRATCH COPY of the prototype (never to prototype/index.html), run on the
// baseline's default-arm seeds and compared with qa/baseline-p0.json using the baseline-diff maths. This is an indication of how much
// each bug matters, not a fix proposal: the port decides how to fix them. Nothing here changes the prototype or the baseline.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createHarness, PLAN, runArm } = require('./lib/arms');
const { compareMetrics } = require('./baseline-diff');

const args = process.argv.slice(2);
const val = (n, d) => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.split('=')[1] : d; };
const N = parseInt(val('matches', '1000'), 10);
const only = val('only', null) ? val('only').split(',') : null;
const SRC = fs.readFileSync(path.join(__dirname, '..', 'prototype', 'index.html'), 'utf8');
const base = JSON.parse(fs.readFileSync(path.join(__dirname, 'baseline-p0.json'), 'utf8')).arms.default;
const plan = PLAN.find(p => p.arm === 'default');

const PATCHES = [
  { id: 'KB-001', what: 'signature vs ESCAPE: HIT chance rises with the attacker\'s tier lead', edits: [['0.5 - 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)) ? \'HIT\' : \'ESCAPE\'', '0.5 + 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)) ? \'HIT\' : \'ESCAPE\'']] },
  { id: 'KB-002', what: '1.35x applies to a charging defender (stance bypass removed from CHARGE INTERRUPT, state read from dPrev)', edits: [["if (D.state === 'charging') sm = 1.35;", "if (D.state === 'charging' || D.dPrev === 'charging') sm = 1.35;"], ['S(t, A, D, base*1.4, {noParry:true, ignoreStance:true, big:true});', 'S(t, A, D, base*1.4, {noParry:true, big:true});']] },
  { id: 'KB-003', what: 'a parried exchange opens no chain window', edits: [['function openWindow(ex){', 'function openWindow(ex){ if (ex.cancel) return;']] },
  { id: 'KB-004', what: 'the chain strike respects the defender\'s stance', edits: [['{noParry:true, ignoreStance:true, big:true, stop:0.08}', '{noParry:true, big:true, stop:0.08}']] },
  { id: 'KB-006', what: 'the rush never dips below the ground (buildings still ignored)', edits: [['f.x = wrap(f.x + sdx(f.x, tx)*k); f.y += (ty - f.y)*k;', 'f.x = wrap(f.x + sdx(f.x, tx)*k); f.y = Math.max(f.y + (ty - f.y)*k, groundY(f.x));']] },
];
const HEAD = ['win.p1', 'len.mean', 'civ.mean', 'structs.mean', 'chain.perMatch', 'parry.perMatch', 'launch.SLAM DOWN', 'beam.biome.ocean', 'hide.perMatch'];
const pct = (n, v) => (/^(win|launch|beam)/.test(n) ? (v * 100).toFixed(1) + '%' : v.toFixed(2));

const out = { matches: N, seeds: `${plan.base}..${plan.base + N - 1}`, patches: {} };
for (const p of PATCHES) {
  if (only && !only.includes(p.id)) continue;
  let html = SRC;
  for (const [from, to] of p.edits) { if (!html.includes(from)) throw new Error(`${p.id}: patch target not found in prototype/index.html:\n${from}`); html = html.replace(from, () => to); }
  const file = path.join(os.tmpdir(), `meridian-whatif-${p.id}-${process.pid}.html`); fs.writeFileSync(file, html);
  const { agg } = runArm(createHarness({ html: file }), plan, N); fs.unlinkSync(file);
  const rows = compareMetrics(base.metrics, agg.metrics);
  const flagged = rows.filter(r => Math.abs(r.z) > 3.29).sort((a, b) => Math.abs(b.z) - Math.abs(a.z));
  out.patches[p.id] = { what: p.what, digest: agg.digest, identicalToBaseline: agg.digest === base.digest, headline: Object.fromEntries(HEAD.map(n => { const r = rows.find(x => x.name === n); return [n, r ? { baseline: r.base, patched: r.cur, z: r.z } : null]; })), moved: flagged.map(r => ({ name: r.name, baseline: r.base, patched: r.cur, z: +r.z.toFixed(1) })), compared: rows.length };
  console.log(`\n${p.id}  ${p.what}   (${agg.digest === base.digest ? 'identical to baseline' : agg.digest})`);
  console.log('  ' + HEAD.map(n => { const r = rows.find(x => x.name === n); return r ? `${n} ${pct(n, r.base)} -> ${pct(n, r.cur)} (z ${r.z.toFixed(1)})` : ''; }).filter(Boolean).join('\n  '));
  console.log(`  ${flagged.length} of ${rows.length} metrics moved beyond the 99.9% interval` + (flagged.length ? ': ' + flagged.slice(0, 8).map(r => `${r.name} ${pct(r.name, r.base)} -> ${pct(r.name, r.cur)}`).join('; ') : ''));
}
if (!only) fs.writeFileSync(path.join(__dirname, 'known-bugs-whatif.json'), JSON.stringify(out, null, 1) + '\n');
