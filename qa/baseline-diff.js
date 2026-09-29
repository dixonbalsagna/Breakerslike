#!/usr/bin/env node
// Baseline diff: runs the fixed seeded arms again and flags every metric that moved beyond its confidence interval
// compared with a saved baseline (default qa/baseline-p0.json).
//
//   node qa/baseline-diff.js                          all eight arms, same match count and seeds as the baseline (about a minute)
//   node qa/baseline-diff.js --arms=default,swap      only some arms
//   node qa/baseline-diff.js --matches=300            fewer matches (same first seeds); wider intervals, faster
//   node qa/baseline-diff.js --seed-shift=5000        fresh seeds, so the two samples are independent
//   node qa/baseline-diff.js --current=run.json       compare a saved run instead of running (see --save)
//   node qa/baseline-diff.js --save=qa/baseline-p1.json   also write the run in baseline format (a new baseline)
//   options: --baseline=file  --z=3.29  --all (also list 95% flags)  --fail (exit 1 on a strict flag)
//
// With the same seeds and an unchanged simulation each arm's digest is identical and nothing is compared. When the
// simulation changed the trajectories decorrelate, and each metric is compared with a z statistic on the difference:
//   z = (current - baseline) / sqrt(se_current^2 + se_baseline^2)
// Two tiers are reported. "moved" is outside the 95% interval (|z| > 1.96). "MOVED" is outside the 99.9% interval
// (|z| > 3.29), which survives the several hundred comparisons made per run; --fail keys on it.
const fs = require('fs');
const path = require('path');
const { PLAN, runArm, createHarness } = require('./lib/arms');

const args = process.argv.slice(2);
const val = (n, d) => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.slice(n.length + 3) : d; };
const flag = n => args.includes('--' + n);
const Z_LOOSE = 1.96, Z_STRICT = parseFloat(val('z', '3.29'));

// Compare two metric sets. Returns rows { name, base, cur, se0, se1, delta, z, note }. Pure; used by the tests.
function compareMetrics(base, cur) {
  const rows = [];
  for (const name of new Set([...Object.keys(base), ...Object.keys(cur)])) {
    const b = base[name], c = cur[name];
    const v0 = b ? b.v : 0, s0 = b ? b.se : 0, v1 = c ? c.v : 0, s1 = c ? c.se : 0;
    const se = Math.sqrt(s0 * s0 + s1 * s1), delta = v1 - v0;
    const z = se > 0 ? delta / se : (Math.abs(delta) > 1e-12 ? Infinity * Math.sign(delta) : 0);
    rows.push({ name, base: v0, cur: v1, se0: s0, se1: s1, delta, z, note: !b ? 'new' : !c ? 'gone' : '' });
  }
  return rows;
}

const fmt = (name, v) => (/^(win|launch|beam|melee|time|len\.over|civ\.over|hide\.matchesWith|timeouts|parry\.perMelee|chain\.perMelee|ambush\.perHide)/.test(name) && !/perMatch|meanLength/.test(name))
  ? (v * 100).toFixed(1) + '%' : Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(3);
const half = (name, se) => (/^(win|launch|beam|melee|time|len\.over|civ\.over|hide\.matchesWith|timeouts|parry\.perMelee|chain\.perMelee|ambush\.perHide)/.test(name) && !/perMatch|meanLength/.test(name))
  ? (1.96 * se * 100).toFixed(1) + '%' : (1.96 * se).toFixed(3);

function main() {
  const basePath = path.resolve(process.cwd(), val('baseline', path.join(__dirname, 'baseline-p0.json')));
  if (!fs.existsSync(basePath)) { console.error('baseline not found: ' + basePath); process.exit(2); }
  const base = JSON.parse(fs.readFileSync(basePath, 'utf8'));
  const armNames = val('arms', null) ? val('arms').split(',') : Object.keys(base.arms);
  for (const a of armNames) {
    if (!base.arms[a]) { console.error('arm not in baseline: ' + a); process.exit(2); }
    if (!base.arms[a].metrics) { console.error('the baseline has no per-metric data (schema 1). Regenerate it with: node qa/balance-report.js --matches=1000'); process.exit(2); }
  }
  const N = parseInt(val('matches', String(base.generatedWith.matches)), 10);
  const shift = parseInt(val('seed-shift', '0'), 10);

  let cur;
  if (val('current', null)) cur = JSON.parse(fs.readFileSync(path.resolve(process.cwd(), val('current')), 'utf8'));
  else {
    cur = { schema: 2, generatedWith: { node: process.version, matches: N, seedShift: shift }, arms: {} };
    const h = createHarness();
    for (const plan of PLAN.filter(p => armNames.includes(p.arm))) {
      const b = base.arms[plan.arm];
      if (b.base !== undefined && b.base !== plan.base) console.error(`note: ${plan.arm} seed block in the baseline (${b.base}) differs from qa/lib/arms.js (${plan.base}); using the baseline's`);
      cur.arms[plan.arm] = runArm(h, { ...plan, base: b.base !== undefined ? b.base : plan.base }, N, shift).agg;
    }
    if (val('save', null)) { fs.writeFileSync(path.resolve(process.cwd(), val('save')), JSON.stringify(cur, null, 1) + '\n'); console.log('saved ' + val('save')); }
  }

  console.log(`baseline ${path.relative(process.cwd(), basePath)} (Node ${base.generatedWith.node}, ${base.generatedWith.matches} matches per arm)   current: ${val('current', 'fresh run')} (Node ${cur.generatedWith.node}, ${N} matches per arm${shift ? ', seeds shifted by ' + shift : ''})`);
  console.log(`flags: "moved" = outside the 95% interval (|z| > ${Z_LOOSE}), "MOVED" = outside the ${Z_STRICT === 3.29 ? '99.9%' : 'stricter'} interval (|z| > ${Z_STRICT}); z uses both samples' standard errors\n`);

  let strict = 0, loose = 0, compared = 0, identical = 0;
  const flagged = [];
  for (const a of armNames) {
    const b = base.arms[a], c = cur.arms[a];
    if (!c) { console.log(`  ${a.padEnd(20)} not in the current run`); continue; }
    if (b.digest && c.digest && b.digest === c.digest && b.seeds && c.seeds && b.seeds.last === c.seeds.last) {
      identical++; console.log(`  ${a.padEnd(20)} digest ${c.digest} identical: same seeds, simulation unchanged for this arm`); continue;
    }
    const rows = compareMetrics(b.metrics, c.metrics);
    compared += rows.length;
    const s = rows.filter(r => Math.abs(r.z) > Z_STRICT), l = rows.filter(r => Math.abs(r.z) > Z_LOOSE);
    strict += s.length; loose += l.length;
    console.log(`  ${a.padEnd(20)} ${rows.length} metrics compared: ${s.length} MOVED, ${l.length - s.length} moved`);
    for (const r of l) flagged.push({ arm: a, ...r, tier: Math.abs(r.z) > Z_STRICT ? 'MOVED' : 'moved' });
  }

  const shown = flagged.filter(r => flag('all') || r.tier === 'MOVED').sort((x, y) => Math.abs(y.z) - Math.abs(x.z));
  if (shown.length) {
    console.log('');
    console.log(['arm'.padEnd(20), 'metric'.padEnd(28), 'baseline (95% ±)'.padStart(20), 'current (95% ±)'.padStart(20), 'change'.padStart(10), 'z'.padStart(7), 'flag'].join('  '));
    for (const r of shown) {
      const rel = r.base ? ((r.cur / r.base - 1) * 100).toFixed(0) + '%' : r.note || 'n/a';
      console.log([r.arm.padEnd(20), r.name.padEnd(28), `${fmt(r.name, r.base)} ±${half(r.name, r.se0)}`.padStart(20), `${fmt(r.name, r.cur)} ±${half(r.name, r.se1)}`.padStart(20), rel.padStart(10), (Number.isFinite(r.z) ? r.z.toFixed(1) : (r.z > 0 ? '+inf' : '-inf')).padStart(7), r.tier + (r.note ? ' (' + r.note + ')' : '')].join('  '));
    }
  }
  console.log('');
  if (!compared) console.log(`no metric compared: all ${identical} arm(s) are bit-identical to the baseline.`);
  else {
    console.log(`${strict} MOVED and ${loose - strict} moved of ${compared} comparisons. By chance alone about ${(compared * 0.05).toFixed(0)} would be "moved" and ${(compared * 0.001).toFixed(1)} "MOVED" if nothing had changed.`);
    if (!flag('all') && loose - strict > 0) console.log('Use --all to list the 95% flags as well.');
  }
  if (flag('fail') && strict) process.exit(1);
}

if (require.main === module) main();
module.exports = { compareMetrics };
