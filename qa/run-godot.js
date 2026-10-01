#!/usr/bin/env node
// QA on the GDScript sim (ADR 0006): plays seeded AI-vs-AI batches in headless Godot, checks the bands in
// docs/design/balance-targets.md, runs the acceptance-test skeletons, and re-tests slice S0. From the repo root:
//   node qa/run-godot.js                     400 matches per arm, all eight arms, 20 or so minutes on 6 jobs
//   node qa/run-godot.js --quick             100 matches, arms default and swap only (about 30 s)
//   options: --matches=N  --jobs=N  --arms=default,swap,...  --scale=testbed|game  --capsec=900  --seed=1
//            --save-records=file / --load-records=file (keep the records, re-evaluate later without replaying)  --feel=N (matches for the dynamic-feel probe, 0 skips)  --fail (exit 1 on any FAIL, bands included)  --md=docs/qa/baseline-g0.md  --json=file  --only=bands|tests|s0
// Exit code: 0 unless the run itself broke (no Godot, NaN, a fighter outside the world, a non-deterministic seed) or a
// hard test failed (soft tuning tests such as W3 and W5 only report). Band FAILs are the point of a baseline, so they exit 1 only with --fail.
// Needs Godot 4.7 ($GODOT, PATH, or the Windows install folder). The Node prototype suite is separate: node qa/run-all.js.
const fs = require('fs');
const path = require('path');
const { findGodot, runRecords } = require('./godot/godot');
const { evaluate } = require('./godot/bands');
const { runTests } = require('./godot/pending-tests');
const S = require('../prototype/tools/stats');

const args = process.argv.slice(2);
const val = (n, d) => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.slice(n.length + 3) : d; };
const flag = n => args.includes('--' + n);
const quick = flag('quick');
const N = parseInt(val('matches', quick ? '100' : '400'), 10);
const JOBS = parseInt(val('jobs', String(Math.max(1, Math.min(6, require('os').cpus().length - 1)))), 10);
let SCALE = val('scale', 'auto');                          // auto: game scale once the sim has finishers (S2), testbed before
const CAP = parseFloat(val('capsec', '900'));            // sim seconds: 15:00 (the S4 ruling). It counts S.T, so hit-stop ticks do not eat the budget as the old 43,200-tick cap did
const BASE = parseInt(val('seed', '1'), 10);
const ARMS = (val('arms', quick ? 'default,swap' : 'default,swap,mirror-villain,mirror-hero,default-flip,swap-flip,mirror-villain-flip,mirror-hero-flip')).split(',');
const ONLY = val('only', null);
const MASHER = parseInt(val('masher', '40'), 10);          // matches per level for the scripted masher (0 skips it)
const LEVELRUNS = parseInt(val('levelruns', '100'), 10);     // default-arm matches at the easy and hard AI levels for the perfect-block rates (0 skips them)
const FEEL = parseInt(val('feel', '40'), 10);            // matches for Combat's dynamic-feel probe (0 skips it)
const ROOT = path.join(__dirname, '..');

async function main() {
  const g = findGodot();
  if (!g) { console.error('Godot 4.7 not found. Set GODOT to the console executable (see docs/tools/README.md).'); process.exit(2); }
  const sim = simInfo();
  console.log(`Meridian QA on the GDScript sim   Godot ${g.version}   ${N} matches per arm, seeds ${BASE}..${BASE + N - 1}   scale ${SCALE}   ${JOBS} jobs`);
  console.log(`sim: ${sim}\n`);

  const A = {}, t0 = Date.now();
  const load = val('load-records', null);          // re-evaluate saved records without replaying (after a band change)
  if (load) Object.assign(A, JSON.parse(fs.readFileSync(path.resolve(load), 'utf8')));
  else for (const arm of ARMS) A[arm] = await runRecords({ arm, base: BASE, count: N, jobs: JOBS, capSec: CAP });
  if (val('save-records', null)) fs.writeFileSync(path.resolve(val('save-records')), JSON.stringify(A));
  if (SCALE === 'auto') SCALE = require('./godot/bands').hasEvent(A, 'finisher_start') ? 'game' : 'testbed';
  const bad = Object.values(A).flat().filter(r => r.bad);
  if (bad.length) { for (const r of bad.slice(0, 5)) console.log(`FAIL  seed ${r.seed} (${r.arm}): ${r.bad}`); process.exit(1); }
  const digests = Object.fromEntries(ARMS.map(a => [a, digest(A[a])]));
  console.log(`\nran ${ARMS.length * N} matches in ${((Date.now() - t0) / 1000).toFixed(0)} s. Digests: ${ARMS.map(a => a + ' ' + digests[a]).join(', ')}\n`);

  const result = { godot: g.version, sim, matches: N, seedBase: BASE, scale: SCALE, cap: CAP, digests };
  let hardFail = false;

  if (!ONLY || ONLY === 'bands') {
    const rows = evaluate(A, { scale: SCALE, cap: CAP });
    if (FEEL > 0) {
      try { const feel = require('./godot/feel'); rows.push(...feel.feelRows(await feel.runFeel({ matches: FEEL, base: BASE }), FEEL)); } catch (e) { console.log('feel probe skipped: ' + String(e.message).split(String.fromCharCode(10))[0]); }
    }
    if (LEVELRUNS > 0 && !load) {
      try { const { levelRows } = require('./godot/bands'); const byLevel = {}; for (const lv of ['easy', 'hard']) byLevel[lv] = await runRecords({ arm: 'default', base: BASE, count: LEVELRUNS, jobs: JOBS, capSec: CAP, level: lv }); rows.push(...levelRows(byLevel)); } catch (e) { console.log('level runs skipped: ' + String(e.message).split(String.fromCharCode(10))[0]); }
    }
    if (MASHER > 0 && !load) {
      try { const m = require('./godot/masher'); rows.push(...m.masherRows(await m.runMasher({ n: MASHER, base: BASE }))); } catch (e) { console.log('masher skipped: ' + String(e.message).split(String.fromCharCode(10))[0]); }
    }
    result.bands = rows; printBands(rows);
  }
  const ctx = { A, runRecords: o => runRecords({ jobs: JOBS, capSec: CAP, ...o }) };
  if (!ONLY || ONLY === 'tests') {
    const tests = await runTests(ctx);
    result.tests = tests; printTests(tests);
    if (tests.some(t => t.status === 'FAIL' && !t.soft)) hardFail = true;
  }
  if (!ONLY || ONLY === 's0') {
    const s0 = s0Retest(A); result.s0 = s0; printS0(s0);
  }
  const fails = (result.bands || []).filter(r => r.status === 'FAIL').length;
  const summary = `bands: ${(result.bands || []).filter(r => r.status === 'PASS').length} pass, ${fails} fail, ${(result.bands || []).filter(r => r.status === 'PENDING').length} pending; tests: ${(result.tests || []).filter(t => t.status === 'PASS').length} pass, ${(result.tests || []).filter(t => t.status === 'FAIL').length} fail, ${(result.tests || []).filter(t => t.status === 'PENDING').length} pending`;
  console.log('\n' + summary);
  if (val('json', null)) fs.writeFileSync(path.resolve(val('json')), JSON.stringify(result, null, 1) + '\n');
  if (val('md', null)) fs.writeFileSync(path.resolve(val('md')), toMarkdown(result));
  process.exit(hardFail || (flag('fail') && fails) ? 1 : 0);
}

// What the sim is: the commit, whether slices are in the working tree (S0 is detected from its constants).
function simInfo() {
  const { spawnSync } = require('child_process');
  const git = (...a) => (spawnSync('git', a, { cwd: ROOT, encoding: 'utf8' }).stdout || '').trim();
  const alt = process.env.QA_GODOT_ROOT ? path.resolve(process.env.QA_GODOT_ROOT) : null;   // a clean export of a commit, for comparisons
  const dirty = alt ? 0 : git('status', '--short', '--', 'sim').split('\n').filter(Boolean).length;
  const src = f => { try { return fs.readFileSync(path.join(alt || ROOT, f), 'utf8'); } catch (e) { return ''; } };
  const s0 = /MENACE_DECAY/.test(src('sim/core/fighter.gd')) || /"decay"/.test(src('data/fighters/VORR/meters.json')), s1 = fs.existsSync(path.join(alt || ROOT, 'sim/core/wounds.gd'));   // S0: menace decay, in code (before D1b) or in the meters data (after)
  return `${alt ? 'clean export of ' + (process.env.QA_SIM_COMMIT ? 'commit ' + process.env.QA_SIM_COMMIT : 'an unlabelled commit (set QA_SIM_COMMIT; the working tree HEAD is not the export)') : 'commit ' + (git('rev-parse', '--short', 'HEAD') || '?') + (dirty ? ` + ${dirty} uncommitted sim file(s)` : '')}; slices in the tree: S0 ${s0 ? 'yes' : 'no'}, S1 ${s1 ? 'yes' : 'no'}`;
}
function digest(recs) { const h = new (require('../prototype/tools/match-runner').Hasher)(); for (const r of recs) h.str(r.hash); return h.hex(); }

const pad = (s, n) => String(s).padEnd(n);
function printBands(rows) {
  console.log('BANDS (docs/design/balance-targets.md)');
  const w = Math.min(96, Math.max(...rows.map(r => r.what.length)));
  for (const r of rows) console.log(`  ${pad(r.status, 7)} ${pad(r.ref, 5)} ${pad(r.what.length > w ? r.what.slice(0, w - 1) + '…' : r.what, w)}  ${r.value}${r.band ? '   (band: ' + r.band + ')' : ''}${r.note ? '   ' + r.note : ''}`);
}
function printTests(tests) {
  console.log('\nACCEPTANCE TESTS (Wounds spec §5, hard tests §5b and §11)');
  for (const t of tests) console.log(`  ${pad(t.status, 7)} ${pad(t.id, 3)} ${pad(t.spec, 18)} ${t.title.length > 90 ? t.title.slice(0, 89) + '…' : t.title}\n            ${t.detail}`);
}

// Slice S0 re-test (wounds-plan.md): KAI at 42% or better on at least 400 matches per arm, both slots, and the §10 pacing rows still pass.
function s0Retest(A) {
  if (!A.default || !A.swap) return { status: 'PENDING', note: 'needs arms default and swap' };
  const k = require('./godot/bands').kaiRate(A), per = { P1: A.default.filter(r => !r.timeout && r.winner === 0).length / A.default.filter(r => !r.timeout).length, P2: A.swap.filter(r => !r.timeout && r.winner === 1).length / A.swap.filter(r => !r.timeout).length };
  const rows = evaluate(A, { scale: SCALE, cap: CAP }), pacing = rows.filter(r => r.ref === '§10' && r.status !== 'PENDING' && r.status !== 'INFO');
  const enough = Math.min(A.default.length, A.swap.length) >= 400, low = k.ci[1] < 0.42;
  const menace = mean2(A.default.map(r => r.menace[1]));
  const status = !enough ? 'INCONCLUSIVE' : k.v >= 0.42 ? 'PASS' : 'FAIL';
  return { status, kai: k.v, ci: k.ci, kaiAsP1: per.P1, kaiAsP2: per.P2, matchesPerArm: Math.min(A.default.length, A.swap.length), pacingPass: pacing.filter(r => r.status === 'PASS').length, pacingFail: pacing.filter(r => r.status === 'FAIL').map(r => r.id), meanFinalVorrMenace: menace, sure: enough ? (low ? 'the whole interval is below 42%' : k.ci[0] >= 0.42 ? 'the whole interval is at or above 42%' : 'the interval straddles 42%') : 'fewer than 400 matches per arm' };
}
const mean2 = a => a.reduce((x, y) => x + y, 0) / a.length;
function printS0(s) {
  console.log('\nSLICE S0 RE-TEST (KAI at 42% or better; at least 400 matches per arm, both slots)');
  if (!s.kai) { console.log('  ' + s.status + ' ' + s.note); return; }
  console.log(`  ${s.status}  KAI ${(s.kai * 100).toFixed(1)}% [${(s.ci[0] * 100).toFixed(1)}, ${(s.ci[1] * 100).toFixed(1)}] over both slots (${(s.kaiAsP1 * 100).toFixed(1)}% from P1, ${(s.kaiAsP2 * 100).toFixed(1)}% from P2), ${s.matchesPerArm} matches per arm: ${s.sure}`);
  console.log(`  pacing rows (§10): ${s.pacingPass} pass${s.pacingFail.length ? ', FAIL: ' + s.pacingFail.join(', ') : ''}; VORR's mean menace at the KO ${s.meanFinalVorrMenace.toFixed(1)}`);
}

function toMarkdown(r) {
  const L = [];
  L.push('# Baseline on the GDScript sim\n');
  L.push(`Generated by \`node qa/run-godot.js --matches=${r.matches}${r.scale !== 'testbed' ? ' --scale=' + r.scale : ''}\`. Godot ${r.godot}; ${r.sim}. Seeds ${r.seedBase}..${r.seedBase + r.matches - 1} in every arm; cap ${r.cap} sim-seconds (S.T). Every number reproduces from the seeds: the digests are below.\n`);
  L.push('| Arm | Digest |\n| :--- | :--- |\n' + Object.entries(r.digests).map(([a, d]) => `| ${a} | \`${d}\` |`).join('\n') + '\n');
  if (r.s0) L.push(`## Slice S0 re-test\n\n${r.s0.status}: ${r.s0.kai ? `KAI ${(r.s0.kai * 100).toFixed(1)}% [${(r.s0.ci[0] * 100).toFixed(1)}, ${(r.s0.ci[1] * 100).toFixed(1)}] over both slots (${(r.s0.kaiAsP1 * 100).toFixed(1)}% from P1, ${(r.s0.kaiAsP2 * 100).toFixed(1)}% from P2), ${r.s0.matchesPerArm} matches per arm; ${r.s0.sure}. Pacing rows passing: ${r.s0.pacingPass}${r.s0.pacingFail.length ? '; failing: ' + r.s0.pacingFail.join(', ') : ''}.` : r.s0.note}\n`);
  if (r.bands) {
    L.push('## Bands (`docs/design/balance-targets.md`)\n');
    L.push('| Status | § | Measure | Value | Band | Note |\n| :--- | :--- | :--- | :--- | :--- | :--- |');
    for (const b of r.bands) L.push(`| ${b.status === 'FAIL' ? '**FAIL**' : b.status} | ${b.ref} | ${b.what} | ${b.value} | ${b.band} | ${b.note} |`);
    L.push('');
  }
  if (r.tests) {
    L.push('## Acceptance tests\n');
    L.push('| Status | ID | Spec | Test | Detail |\n| :--- | :--- | :--- | :--- | :--- |');
    for (const t of r.tests) L.push(`| ${t.status === 'FAIL' ? '**FAIL**' : t.status} | ${t.id} | ${t.spec} | ${t.title} | ${t.detail} |`);
    L.push('');
  }
  return L.join('\n');
}

main().catch(e => { console.error(e.stack || e.message); process.exit(2); });
