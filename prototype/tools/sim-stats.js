// AI-vs-AI batch runner.
// Usage: node prototype/tools/sim-stats.js [matches=60] [baseSeed] [--arm=default|swap|mirror-villain|mirror-hero|<arm>-flip] [--json]
//   With a baseSeed, match i uses seed baseSeed+i and the output is identical on every run (no timing or clock in it).
//   Without a baseSeed the prototype seeds itself from the clock, as it always did (not reproducible).
//   --arm picks who sits in which slot (slot-bias vs character-bias tests). --json prints the full aggregate.
const { createHarness, runMatch, Hasher, ARMS } = require('./match-runner');
const { aggregate, pct } = require('./stats');

const args = process.argv.slice(2);
const flags = Object.fromEntries(args.filter(a => a.startsWith('--')).map(a => { const [k, v] = a.slice(2).split('='); return [k, v === undefined ? true : v]; }));
const pos = args.filter(a => !a.startsWith('--'));
const N = parseInt(pos[0] || '60', 10);
const baseSeed = pos[1] !== undefined ? parseInt(pos[1], 10) : undefined;
const arm = flags.arm || 'default';
if (!Number.isInteger(N) || N < 1 || (pos[1] !== undefined && !Number.isInteger(baseSeed)) || !ARMS[arm]) {
  console.error('usage: node prototype/tools/sim-stats.js [matches=60] [baseSeed] [--arm=' + Object.keys(ARMS).join('|') + '] [--json]');
  process.exit(2);
}

const h = createHarness();
const recs = [], batch = new Hasher();
for (let i = 0; i < N; i++) {
  const r = runMatch(h, baseSeed === undefined ? undefined : baseSeed + i, { arm });
  if (r.nan) { console.error('NaN in', r.nan.fighter, r.nan.key, 'at', r.nan.t.toFixed(2), 'seed', r.seed); process.exit(1); }
  recs.push(r); batch.str(r.hash);
}
const a = aggregate(recs);
a.digest = batch.hex();

if (flags.json) { console.log(JSON.stringify({ args: { matches: N, baseSeed: baseSeed === undefined ? null : baseSeed, arm }, ...a }, null, 1)); process.exit(0); }

const seedText = baseSeed === undefined ? 'unseeded (clock)' : `${baseSeed}..${baseSeed + N - 1}`;
console.log(`matches ${N}   arm ${arm}   seeds ${seedText}   digest ${a.digest}`);
const wins = {}; a.names.forEach((nm, i) => { wins[nm] = a.slotWins[i]; }); if (a.timeouts) wins.timeout = a.timeouts;
console.log(`wins ${JSON.stringify(wins)}   P1 ${pct(a.slotRate[0].rate)} [${pct(a.slotRate[0].ci[0])}, ${pct(a.slotRate[0].ci[1])}]  (${a.names[0]} in P1)`);
console.log(`length to KO avg ${a.len.mean.toFixed(1)}s  p10 ${a.len.p10.toFixed(1)}  p50 ${a.len.p50.toFixed(1)}  p90 ${a.len.p90.toFixed(1)}  min ${a.len.min.toFixed(1)}  max ${a.len.max.toFixed(1)}   (+3.0s KO tail = ${a.lenWithTail.toFixed(1)}s, the figure older runs printed)`);
console.log(`collateral avg ${a.civPct.mean.toFixed(0)}% of civilians   ${a.structs.mean.toFixed(1)} of ${a.nStructs} structures   craters ${a.craters.mean.toFixed(0)}`);
console.log(`launches ${a.launches.total}:  ` + Object.entries(a.launches.counts).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${k} ${pct(v / a.launches.total, 0)}`).join('  '));
console.log(`beams ${a.beams.total} (${a.beams.perMatch.toFixed(1)}/match) by biome:  ` + Object.entries(a.beams.bio).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${k} ${pct(v / a.beams.total, 0)}`).join('  '));
console.log(`parry ${a.parry.perMatch.toFixed(2)}/match   chains ${a.chain.perMatch.toFixed(2)}/match   hides ${a.hide.perMatch.toFixed(2)}/match (${pct(a.hide.matchesWithHide, 0)} of matches)   ambush attacks ${a.attacks.ambushPerMatch.toFixed(2)}/match`);
console.log(`seam: ${a.seam.matchesWithCrossing} of ${N} matches crossed the seam   max per-step move ${a.seam.maxDisp.toFixed(1)} units`);
console.log('director decisions (count):');
const t = { ...Object.fromEntries(Object.entries(a.launches.counts).map(([k, v]) => ['LAUNCH: ' + k, v])), ...a.melee.counts };
for (const b of Object.keys(a.beams.bioOut)) { /* per-biome beam counts are in --json */ }
const beamVariants = Object.entries(a.beams.variant).map(([k, v]) => ['beam ' + k, v]);
[...Object.entries(t), ...beamVariants, ['PARRIES', a.parry.total], ['goes to ground', a.hide.total], ['found', a.hide.found]]
  .sort((x, y) => y[1] - x[1]).forEach(([k, v]) => console.log('  ' + String(v).padStart(5) + '  ' + k));
