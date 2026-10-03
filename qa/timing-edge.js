#!/usr/bin/env node
// The timing-edge matchups (docs/qa/timing-edge-plan.md): scripted players (qa/godot/players.gd) against each other, A in
// slot 0 on odd seeds and slot 1 on even ones, one Godot process per matchup, at most 3 at a time (the machine rule: each
// shows as two Windows processes). Prints a table of win rates (Wilson 95% intervals), damage per exchange, launches earned,
// turn-taking and how the presses read, with Game Design's bands (docs/design/agency-pass.md, "What QA measures").
//   node qa/timing-edge.js [--matches=40] [--jobs=3] [--plan=core|sweep|energy|all] [--seed=1] [--md=file] [--json=file]
// Until the agency pass is built the sim has no timing rules, so every row should read about 50%: that is the baseline this
// reports today, and the same command measures the edge once the rules land.
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { godot, ROOT } = require('./godot/godot');
const S = require('../prototype/tools/stats');

const args = process.argv.slice(2), val = (k, d) => { const a = args.find(x => x.startsWith('--' + k + '=')); return a ? a.slice(k.length + 3) : d; };
const N = parseInt(val('matches', '40'), 10), JOBS = Math.min(3, parseInt(val('jobs', '3'), 10)), PLAN = val('plan', 'core'), BASE = parseInt(val('seed', '1'), 10);

// Styles (agency-pass section 2): blur = a mash, power = a hold, combo = taps. "Timed" variants follow Game Design's thresholds.
const F = ':forms=1:stick=1';   // every scripted player takes its forms: a tier-1 fighter never wins (docs/director/masher-probes.md)
const P = {
  masher: 'masher' + F,                                   // blur, untimed: a press every 8 ticks
  timedMash: 'tapper:win=3:acc=80:mix=L' + F,             // blur, timed: a steady mash within 3 ticks of the beat, 80% of beats
  holder: 'holder' + F,                                   // power, untimed
  timedHold: 'holder:timed=1:acc=80:win=6' + F,           // power, timed: released within 6 ticks of the flash, 80% of beats
  styleOnly: 'tapper:acc=0:mix=LLH' + F,                  // combo, style-only: a sensible mix, never on the beat
  timed: 'tapper:acc=80:win=4:mix=LLH' + F,               // combo, timed: taps within 4 ticks of a blow, 80% of beats
  timedFull: 'tapper:acc=100:win=4:mix=LLH' + F,
  ai: 'ai:level=medium',
};
// The blaster's cadence matters: a barrage needs four clean bolts inside 90 ticks (interrupts.json blast.barrage), and a tap of the
// heavy is a charged shot at 0.6 strength (only a full charge knocks back). The earlier blaster (a press every 24 ticks, mix LLH)
// fired two bolts in 72 ticks, so no decisive shot ever came, a brink fighter was never finished and E4 and E5 ran to the cap
// (GB-009; a56187a: 40 of 40 at 900 s). This one fires about every 14 ticks (mix LLLH: three bolts, a tap, three bolts).
const BLAST = ':energy=1:idle=14:acc=80:win=4:mix=LLLH' + F;
const ENERGY = [
  ['E1', 'masher:energy=1' + F, P.masher, 'a bolt-only player (energy held, a bolt every 8 ticks) against a melee masher: must finish at least 95% (agency pass 16; the win share is reported, see the decided count)', null, null],
  ['E2', 'masher:energy=1' + F, P.ai, 'a bolt-only player against the medium AI (agency pass 16: 20 to 40%)', 20, 40],
  ['E3', 'tapper' + BLAST, P.ai, 'a mixed blaster (a bolt about every 14 ticks, a tapped heavy now and then) against the medium AI (starting band 25 to 45%, Game Design to confirm)', 25, 45],
  ['E4', 'tapper' + BLAST, P.timed, 'a mixed blaster against a timed melee player: must finish at least 95% before the cap (win share reported)', null, null, 95],
  ['E5', 'tapper' + BLAST, P.timed, 'a blast-heavy timed script against a rush-heavy timed script (agency pass 15.6: 40 to 60%; and finishes at least 95%)', 40, 60, 95],
];
const acc = a => `tapper:acc=${a}:win=4:mix=LLH${F}`;

// id, A, B, what, band for A's win share (lo, hi in percent; null: reported only), and optionally the least share of matches that must end in a KO before the cap (percent)
const CORE = [
  ['T1', P.timed, P.masher, 'timed (80% of beats) against a masher', 72, 82],
  ['T2', P.timed, P.styleOnly, 'timed against a style-only player (same mix, never on the beat)', 62, 70],
  ['T3', P.styleOnly, P.masher, 'style-only against a masher', 55, 62],
  ['T4', P.timed, P.timed, 'mirror: both timed (all else equal)', 45, 55],
  ['T5', P.styleOnly, P.styleOnly, 'mirror: both style-only', 45, 55],
  ['T6', P.timedMash, P.masher, 'timed mash (within 3 ticks) against a plain mash', 62, 82],
  ['T7', P.timedHold, P.holder, 'timed hold (released within 6 ticks of the flash) against a plain hold', 62, 82],
  ['T8', P.timed, P.ai, 'timed against the medium AI (agency pass 14: 70 to 90%)', 70, 90],
  ['T10', P.timed, 'ai:level=hard', 'timed against the hard AI (agency pass 14)', 40, 60],
  ['T9', P.masher, P.ai, 'masher against the medium AI (control-rules 6: 35 to 50%)', 35, 50],
];
const SWEEP = [0, 20, 40, 60, 80, 100].flatMap(a => [
  ['A' + a + 'm', acc(a), P.masher, `accuracy ${a}% against a masher`, null, null],
  ['A' + a + 's', acc(a), P.styleOnly, `accuracy ${a}% against a style-only player`, null, null],
]);
const MATCHUPS = PLAN === 'core' ? CORE : PLAN === 'sweep' ? SWEEP : PLAN === 'energy' ? ENERGY : [...CORE, ...SWEEP, ...ENERGY];

function run(m) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found'));
  return new Promise((resolve, reject) => {
    const p = spawn(g.exe, ['--headless', '--path', ROOT, '--script', 'res://qa/godot/players.gd', '--', String(N), String(BASE), `--a=${m[1]}`, `--b=${m[2]}`], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', d => { out += d; }); p.stderr.on('data', d => { out += d; });
    p.on('error', reject);
    p.on('close', code => {
      const line = out.split('\n').find(l => l.startsWith('{') && l.includes('"players"'));
      if (code !== 0 || !line) return reject(new Error('players.gd failed for ' + m[0] + ' (exit ' + code + ')\n' + out.slice(0, 1200)));
      resolve({ id: m[0], what: m[3], lo: m[4], hi: m[5], finMin: m[6] == null ? null : m[6], ...JSON.parse(line) });
    });
  });
}

async function pool(items, n, fn) {
  const res = new Array(items.length); let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => { while (i < items.length) { const k = i++; res[k] = await fn(items[k]); } }));
  return res;
}

(async () => {
  const t0 = Date.now();
  const results = await pool(MATCHUPS, JOBS, run);
  const lines = [];
  const pct = v => (v * 100).toFixed(1) + '%';
  lines.push(`Timing-edge matchups: ${N} matches each from seed ${BASE}, ${((Date.now() - t0) / 1000).toFixed(0)} s on ${JOBS} jobs. A is the first-named player.`);
  lines.push('');
  lines.push('| ID | Matchup | A wins | 95% interval | Band | Finished | Verdict | Damage per exchange A / B | Launches earned A / B | Turn-taking | A on-beat | A blur locks |');
  lines.push('| :--- | :--- | ---: | :--- | :--- | ---: | :--- | :--- | :--- | ---: | ---: | ---: |');
  for (const r of results) {
    const dec = r.aWins + r.bWins, w = dec ? r.aWins / dec : NaN, ci = dec ? S.wilson(r.aWins, dec) : [NaN, NaN];
    const band = r.lo === null ? '' : `${r.lo} to ${r.hi}%`;
    const fin = (r.aWins + r.bWins) / r.n * 100, finOk = r.finMin == null || fin >= r.finMin;
    let verdict = r.lo === null ? 'reported' : (w * 100 >= r.lo && w * 100 <= r.hi ? (ci[0] * 100 >= r.lo - 2 && ci[1] * 100 <= r.hi + 2 ? 'PASS' : 'in band, interval wide') : 'FAIL');
    if (r.finMin != null) verdict = finOk ? (verdict === 'reported' ? 'PASS' : verdict) : 'FAIL (finish)';
    const [a, b] = r.stats;
    lines.push(`| ${r.id} | ${r.what} | ${pct(w)} (${r.aWins} of ${dec}) | ${pct(ci[0])} to ${pct(ci[1])} | ${band}${r.finMin != null ? ' and finish at least ' + r.finMin + '%' : ''} | ${fin.toFixed(0)}% | ${verdict} | ${a.damagePerExchange} / ${b.damagePerExchange} | ${a.launchesEarnedPerMatch} / ${b.launchesEarnedPerMatch} | ${pct(r.alternationShare)} | ${pct(a.onBeatShare)} | ${a.blurLocked} of ${a.blurStrings} |`);
  }
  console.log(lines.join('\n'));
  const md = val('md', null), js = val('json', null);
  if (md) fs.writeFileSync(path.resolve(md), lines.join('\n') + '\n');
  if (js) fs.writeFileSync(path.resolve(js), JSON.stringify(results, null, 1));
})().catch(e => { console.error(e.message); process.exit(1); });
