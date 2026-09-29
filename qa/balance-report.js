#!/usr/bin/env node
// Balance report generator.   node qa/balance-report.js [--matches=1000] [--unseeded=1000] [--out=qa/baseline-p0.md] [--json=qa/baseline-p0.json] [--print]
// Runs the four slot arms with fixed seed blocks, renders the tables and rewrites the text between the
// <!-- BEGIN GENERATED --> and <!-- END GENERATED --> markers of --out (text outside the markers is hand-written and kept).
// Everything in the generated block is reproducible from the seeds. The unseeded check (--unseeded=N) is the only
// clock-seeded part and is labelled as such.
const fs = require('fs');
const path = require('path');
const { createHarness, runMatch, Hasher } = require('../prototype/tools/match-runner');
const S = require('../prototype/tools/stats');

const args = process.argv.slice(2);
const val = (n, d) => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.split('=')[1] : d; };
const N = parseInt(val('matches', '1000'), 10);
const NU = parseInt(val('unseeded', '0'), 10);
const OUT = path.resolve(process.cwd(), val('out', path.join(__dirname, 'baseline-p0.md')));
const JSON_OUT = path.resolve(process.cwd(), val('json', path.join(__dirname, 'baseline-p0.json')));

// ---- targets (sources noted). Win-rate band: qa-balance charter. Launch cap: encounter-systems charter.
const T = { winLo: 0.45, winHi: 0.55, launchCap: 0.40, slotWarn: 0.025 };
// Share of the planet's circumference per biome, from SEG in prototype/index.html (9600 units around).
const WORLD_SHARE = { ocean: 2500 / 9600, village: 1650 / 9600, plains: 850 / 9600, city: 1500 / 9600, forest: 1000 / 9600, desert: 1000 / 9600, mountains: 1100 / 9600 };

const ARMS = [
  { arm: 'default', base: 100001, label: 'KAI in P1, VORR in P2 (as shipped)' },
  { arm: 'swap', base: 200001, label: 'VORR in P1, KAI in P2' },
  { arm: 'mirror-villain', base: 300001, label: 'VORR-A in P1, VORR-B in P2' },
  { arm: 'mirror-hero', base: 400001, label: 'KAI-A in P1, KAI-B in P2' },
];

// Same four with the spawn sides exchanged, to separate the slot (P1 or P2) from the side of the map a fighter starts on.
const FLIPS = [
  { arm: 'default-flip', base: 500001, label: 'KAI in P1 starting east, VORR in P2 starting west' },
  { arm: 'swap-flip', base: 600001, label: 'VORR in P1 starting east, KAI in P2 starting west' },
  { arm: 'mirror-villain-flip', base: 700001, label: 'VORR-A in P1 starting east, VORR-B in P2 starting west' },
  { arm: 'mirror-hero-flip', base: 800001, label: 'KAI-A in P1 starting east, KAI-B in P2 starting west' },
];
const ALL = [...ARMS, ...FLIPS];

const h = createHarness();
const runs = {};
for (const a of ALL) {
  const recs = [], dg = new Hasher();
  for (let i = 0; i < N; i++) { const r = runMatch(h, a.base + i, { arm: a.arm }); if (r.nan) { console.error('NaN', r.nan, 'seed', r.seed); process.exit(1); } recs.push(r); dg.str(r.hash); }
  const agg = S.aggregate(recs); agg.digest = dg.hex(); agg.base = a.base; agg.label = a.label;
  runs[a.arm] = { recs, agg };
}
const D = runs['default'].agg;

// ---- formatting helpers
const p = (v, d = 1) => (v * 100).toFixed(d) + '%';
const pci = ([lo, hi]) => `${p(lo)} to ${p(hi)}`;
const f1 = v => v.toFixed(1);
const table = (head, rows) => ['| ' + head.join(' | ') + ' |', '| ' + head.map((_, i) => (i ? '---:' : ':---')).join(' | ') + ' |', ...rows.map(r => '| ' + r.join(' | ') + ' |')].join('\n');
const bar = (n, max, w = 28) => '█'.repeat(Math.round(n / max * w));
const verdictWin = (rate, ci) => (rate < T.winLo || rate > T.winHi ? '**FAIL**' : ci[0] < T.winLo || ci[1] > T.winHi ? 'watch' : 'pass');

const out = [];
const w = s => out.push(s);

// ---- 1. runs
w('### 1. Runs');
w(table(['Arm', 'Slots', 'Seeds', 'Matches', 'Decided', 'Timeouts', 'Batch digest'],
  ALL.map(a => { const g = runs[a.arm].agg; return [a.arm, a.label, `${g.seeds.first}..${g.seeds.last}`, N, g.decided, g.timeouts, '`' + g.digest + '`']; })));
w('');
w(`Reproduce any row: \`node prototype/tools/sim-stats.js ${N} <first seed> --arm=<arm>\` prints the same digest. Full command for this report: \`node qa/balance-report.js --matches=${N}${NU ? ' --unseeded=' + NU : ''}\`. Node ${process.version}.`);

// ---- 2. win rates and slot vs character bias
const dflt = runs['default'].agg, swap = runs['swap'].agg, mv = runs['mirror-villain'].agg, mh = runs['mirror-hero'].agg;
const kaiWinsDefault = dflt.slotWins[0], kaiWinsSwap = swap.slotWins[1];
const kaiK = kaiWinsDefault + kaiWinsSwap, kaiN = dflt.decided + swap.decided;
const kaiRate = kaiK / kaiN, kaiCi = S.wilson(kaiK, kaiN);
const pb = dflt.slotRate[0].rate, ps = swap.slotRate[0].rate;
const vb = pb * (1 - pb) / dflt.decided, vs = ps * (1 - ps) / swap.decided;
const slotEff = (pb + ps) / 2 - 0.5, slotSe = Math.sqrt(vb + vs) / 2;
const charEff = (pb - ps) / 2, charSe = slotSe;                    // KAI's edge over VORR with slot bias cancelled
w('');
w('### 2. Win rate, with slot bias separated from character bias');
w('Intervals are Wilson 95% and use decided matches only (timeouts excluded).');
w('');
w(table(['Arm', 'P1 wins', 'P1 win rate', '95% CI', 'In 45 to 55%?'],
  ARMS.map(a => { const g = runs[a.arm].agg, r = g.slotRate[0]; return [a.arm + ' (' + g.names[0] + ' in P1)', `${r.k} of ${g.decided}`, p(r.rate), pci(r.ci), verdictWin(r.rate, r.ci)]; })));
w('');
w(table(['Measure', 'Value', '95% CI', 'Reading'], [
  ['**KAI win rate, averaged over both slots**', p(kaiRate), pci(kaiCi), verdictWin(kaiRate, kaiCi) + '  (character balance; slot bias cancels out)'],
  ['**VORR win rate, averaged over both slots**', p(1 - kaiRate), pci([1 - kaiCi[1], 1 - kaiCi[0]]), ''],
  ['P1 slot and west spawn together, both characters averaged (inseparable in these two arms, see 2b)', (slotEff >= 0 ? '+' : '') + p(slotEff), `${p(slotEff - 1.96 * slotSe)} to ${p(slotEff + 1.96 * slotSe)}`, Math.abs(slotEff) > T.slotWarn && Math.abs(slotEff) > 1.96 * slotSe ? 'significant slot bias' : 'not significant'],
  ['Character effect: KAI edge over VORR', (charEff >= 0 ? '+' : '') + p(charEff), `${p(charEff - 1.96 * charSe)} to ${p(charEff + 1.96 * charSe)}`, Math.abs(charEff) > 1.96 * charSe ? 'significant character bias' : 'not significant'],
  ['Mirror, villain vs villain: P1 win rate', p(mv.slotRate[0].rate), pci(mv.slotRate[0].ci), 'pure slot test (identical fighters, identical role)'],
  ['Mirror, hero vs hero: P1 win rate', p(mh.slotRate[0].rate), pci(mh.slotRate[0].ci), 'slot test, but see the anguish note in the findings'],
]));
w('');
w('Model for the two shipped arms: P(KAI wins from P1) = 0.5 + character + slot, and P(VORR wins from P1) = 0.5 - character + slot. Averaging the two arms gives the slot term; half their difference gives the character term.');

// ---- 2b. factor separation with the spawn-flipped arms
{
  const g = a => runs[a].agg, P1 = a => g(a).slotRate[0].rate, V = a => P1(a) * (1 - P1(a)) / g(a).decided;
  const yA = P1('default'), yB = 1 - P1('swap'), yC = P1('default-flip'), yD = 1 - P1('swap-flip');
  const se4 = Math.sqrt(V('default') + V('swap') + V('default-flip') + V('swap-flip')) / 4;
  const mixed = { c: (yA + yB + yC + yD) / 4 - 0.5, s: (yA - yB + yC - yD) / 4, w: (yA - yB - yC + yD) / 4, se: se4 };
  const mir = (n, f) => ({ s: (P1(n) + P1(f)) / 2 - 0.5, w: (P1(n) - P1(f)) / 2, se: Math.sqrt(V(n) + V(f)) / 2 });
  const mvv = mir('mirror-villain', 'mirror-villain-flip'), mhh = mir('mirror-hero', 'mirror-hero-flip');
  const cell = (e, se) => `${e >= 0 ? '+' : ''}${p(e)} (${e - 1.96 * se >= 0 || e + 1.96 * se <= 0 ? '**' : ''}${p(e - 1.96 * se)} to ${p(e + 1.96 * se)}${e - 1.96 * se >= 0 || e + 1.96 * se <= 0 ? '**' : ''})`;
  w('');
  w('### 2b. Three factors separated: character, slot, and spawn side');
  w('Each arm is repeated with the spawn points exchanged: in the shipped arms P1 starts at x = 2150 (plains, west of the city) and P2 at x = 2900 (inside the city); in the -flip arms P1 starts at 2900 and P2 at 2150. Effects are percentage points of win probability; bold means the 95% interval excludes zero.');
  w('');
  w(table(['Factor', 'KAI vs VORR (4 arms)', 'VORR vs VORR (2 arms)', 'KAI vs KAI (2 arms)'], [
    ['Character: KAI over VORR', cell(mixed.c, mixed.se), 'n/a', 'n/a'],
    ['Slot: P1 over P2, spawn held fixed', cell(mixed.s, mixed.se), cell(mvv.s, mvv.se), cell(mhh.s, mhh.se)],
    ['Spawn: west (x = 2150) over east (x = 2900), slot held fixed', cell(mixed.w, mixed.se), cell(mvv.w, mvv.se), cell(mhh.w, mhh.se)],
  ]));
  w('');
  w(table(['Arm', 'P1 win rate', '95% CI'], FLIPS.map(a => [a.arm, p(g(a.arm).slotRate[0].rate), pci(g(a.arm).slotRate[0].ci)])));
  w('');
  w('Additive model: P(P1 wins) = 0.5 + slot + spawn (+ character when the fighters differ). In the villain mirror there is no character term, so the two arms give slot and spawn directly.');
}

// ---- 3. match length
w('');
w('### 3. Match length (sim-seconds from start to KO; older tools also counted a 3.0 s KO tail)');
w(table(['Arm', 'Mean', 'SD', 'Min', 'p10', 'Median', 'p90', 'Max'],
  ARMS.map(a => { const l = runs[a.arm].agg.len; return [a.arm, f1(l.mean) + ' ±' + f1(1.96 * l.sd / Math.sqrt(N)), f1(l.sd), f1(l.min), f1(l.p10), f1(l.p50), f1(l.p90), f1(l.max)]; })));
w('');
const mx = Math.max(...D.lenHist.map(b => b.n));
w('Distribution, default arm (10 s bins):');
w('```');
D.lenHist.forEach((b, i) => { const last = i === D.lenHist.length - 1; w(`${String(b.lo).padStart(3)}${last ? '+   ' : '-' + String(b.hi).padEnd(3)} s ${String(b.n).padStart(4)} ${bar(b.n, mx)}`); });
w('```');

// ---- 4. collateral
w('');
w('### 4. Collateral');
w(table(['Arm', 'Civilians lost, mean', 'p10', 'Median', 'p90', 'Max', `Structures lost, mean (of ${D.nStructs})`, 'p10', 'p90', 'Craters, mean'],
  ARMS.map(a => { const g = runs[a.arm].agg; return [a.arm, f1(g.civPct.mean) + '% ±' + f1(1.96 * g.civPct.sd / Math.sqrt(N)), f1(g.civPct.p10) + '%', f1(g.civPct.p50) + '%', f1(g.civPct.p90) + '%', f1(g.civPct.max) + '%', f1(g.structs.mean), f1(g.structs.p10), f1(g.structs.p90), f1(g.craters.mean)]; })));
w(`Population at start: ${D.pop0} civilians in ${D.nStructs} structures. Matches that lose at least 90% of the civilians: ${ARMS.map(a => a.arm + ' ' + p(runs[a.arm].agg.civ90, 0)).join(', ')}.`);

// ---- 5. launches
w('');
w(`### 5. Launch types (share of all launches; flag above ${p(T.launchCap, 0)})`);
const names = [...new Set(ARMS.flatMap(a => Object.keys(runs[a.arm].agg.launches.counts)))].sort((a, b) => (D.launches.counts[b] || 0) - (D.launches.counts[a] || 0));
const flagged = [];
w(table(['Launch', ...ARMS.map(a => a.arm), 'Flag'], [
  ...names.map(n => {
    const cells = ARMS.map(a => { const g = runs[a.arm].agg.launches; return p((g.counts[n] || 0) / g.total); });
    const over = ARMS.filter(a => { const g = runs[a.arm].agg.launches; return (g.counts[n] || 0) / g.total > T.launchCap; }).map(a => a.arm);
    if (over.length) flagged.push(n + ' in ' + over.join(', '));
    return [n, ...cells, over.length ? '**OVER ' + p(T.launchCap, 0) + '** (' + over.length + ' arm' + (over.length > 1 ? 's' : '') + ')' : ''];
  }),
  ['launches counted', ...ARMS.map(a => String(runs[a.arm].agg.launches.total)), ''],
]));
const slam = D.launches.counts['SLAM DOWN'] / D.launches.total;
const slamC = S.clusterShare(runs['default'].recs, r => r.launches['SLAM DOWN'] || 0, r => S.sum(Object.values(r.launches)));
w('');
w(`SLAM DOWN, default arm: ${p(slam)} of ${D.launches.total} launches (95% CI ${pci(slamC.ci)}, clustered by match).`);

// ---- 6. beams
w('');
w('### 6. Signature beams by biome (biome under the defender when the beam is planned)');
const oceanC = S.clusterShare(runs['default'].recs, r => r.beams.filter(b => b.bio === 'ocean').length, r => r.beams.length);
const bios = Object.keys(WORLD_SHARE).sort((a, b) => (D.beams.bio[b] || 0) - (D.beams.bio[a] || 0));
w(table(['Biome', 'Share of planet', ...ARMS.map(a => a.arm), 'Default arm vs planet share'],
  bios.map(b => [b, p(WORLD_SHARE[b], 0), ...ARMS.map(a => { const g = runs[a.arm].agg.beams; return p((g.bio[b] || 0) / g.total); }), (D.beams.share[b] || 0) / WORLD_SHARE[b] >= 1.5 ? '**' + ((D.beams.share[b] || 0) / WORLD_SHARE[b]).toFixed(1) + 'x**' : ((D.beams.share[b] || 0) / WORLD_SHARE[b]).toFixed(1) + 'x'])));
w('');
w(`Beams per match: ${ARMS.map(a => a.arm + ' ' + runs[a.arm].agg.beams.perMatch.toFixed(2)).join(', ')}. Ocean share of beams, default arm: ${p(D.beams.share.ocean)} (95% CI ${pci(oceanC.ci)}, clustered by match).`);
w('');
w('Where the fighters actually are (share of fight time, both fighters, until KO or the cap), for comparison with the beam table:');
w(table(['Biome', 'Share of planet', ...ARMS.map(a => a.arm)], bios.map(b => [b, p(WORLD_SHARE[b], 0), ...ARMS.map(a => p(runs[a.arm].agg.biomeTime[b] || 0))])));
w('');
const outs = ['HIT', 'GUARD', 'DODGE', 'ESCAPE', 'CLASH'];
w(table(['Beam outcome (default arm)', ...outs], [['count', ...outs.map(o => String(D.beams.outcome[o] || 0))], ['share', ...outs.map(o => p((D.beams.outcome[o] || 0) / D.beams.total))]]));
w('');
w('Beam variants, default arm: ' + Object.entries(D.beams.variant).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${p(v / D.beams.total, 0)}`).join(', ') + '.');

// ---- 7. director coverage
w('');
w('### 7. Director coverage, default arm');
const AS = ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE'], DS = ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'CHARGING'];
const cnt = {}, byDef = {};
for (const [k, v] of Object.entries(D.matrix)) {
  const m = /^(\w+)>(\w+) (light|heavy|sig) (.+)$/.exec(k);
  cnt[m[1] + '>' + m[2]] = (cnt[m[1] + '>' + m[2]] || 0) + v;
  const dk = m[2] + ' ' + m[3]; byDef[dk] = byDef[dk] || {}; byDef[dk][m[4]] = (byDef[dk][m[4]] || 0) + v;
}
w('Exchanges by attacker stance (rows, read from the fighter when the attack is requested) and defender state (columns):');
w('');
w(table(['Attacker vs defender', ...DS], AS.map(a => [a, ...DS.map(d => String(cnt[a + '>' + d] || 0))])));
w('');
w('Outcomes the director produced for each defender state and attack kind (share of that cell). The P2 exit criterion asks for at least two authored outcomes per stance pairing.');
w('');
const cellText = (d, k) => { const o = byDef[d + ' ' + k]; if (!o) return '(none)'; const t = S.sum(Object.values(o)); return Object.entries(o).sort((x, y) => y[1] - x[1]).map(([n, v]) => `${n} ${p(v / t, 0)}`).join('; ') + ` [${Object.keys(o).length}]`; };
w(table(['Defender state', 'Light attack', 'Heavy attack', 'Signature'], DS.map(d => [d, cellText(d, 'light'), cellText(d, 'heavy'), cellText(d, 'sig')])));
w('');
w('The bracketed number is how many distinct outcomes were seen. Light attacks that end in a defender counter are counted under their base outcome.');
w('');
w(table(['Melee outcome (default arm)', 'Count', 'Share'], Object.entries(D.melee.counts).sort((a, b) => b[1] - a[1]).map(([k, v]) => [k, String(v), p(v / D.melee.total)])));

// ---- 8. parry chain hide ambush
w('');
w('### 8. Parry, chain, hide and ambush rates');
const rr = a => runs[a].agg;
w(table(['Rate', ...ARMS.map(a => a.arm)], [
  ['Melee exchanges per match', ...ARMS.map(a => (rr(a.arm).melee.total / N).toFixed(1))],
  ['Parries per match', ...ARMS.map(a => rr(a.arm).parry.perMatch.toFixed(2))],
  ['Parries per 100 melee exchanges', ...ARMS.map(a => (rr(a.arm).parry.perMelee * 100).toFixed(1))],
  ['Chains per match (2+ linked hits)', ...ARMS.map(a => rr(a.arm).chain.perMatch.toFixed(2))],
  ['Chains per 100 melee exchanges', ...ARMS.map(a => (rr(a.arm).chain.perMelee * 100).toFixed(1))],
  ['Mean chain length', ...ARMS.map(a => rr(a.arm).chain.meanLen.toFixed(2))],
  ['Hides per match', ...ARMS.map(a => rr(a.arm).hide.perMatch.toFixed(2))],
  ['Matches with at least one hide', ...ARMS.map(a => p(rr(a.arm).hide.matchesWithHide, 0))],
  ['Hidden seconds per match (P1 / P2)', ...ARMS.map(a => rr(a.arm).hide.hiddenSecPerMatch.map(f1).join(' / '))],
  ['"Found" events per match', ...ARMS.map(a => (rr(a.arm).hide.found / N).toFixed(2))],
  ['Ambush attacks per match', ...ARMS.map(a => rr(a.arm).attacks.ambushPerMatch.toFixed(3))],
  ['Ambush attacks per hide', ...ARMS.map(a => rr(a.arm).hide.ambushPerHide.toFixed(3))],
  ['Parries by P1 / P2 (total)', ...ARMS.map(a => rr(a.arm).parry.bySlot.join(' / '))],
  ['Highest tier reached, mean (P1 / P2)', ...ARMS.map(a => rr(a.arm).tiers.map(f1).join(' / '))],
]));
w('');
const cl = D.chain.lenHist; w('Chain length histogram, default arm: ' + Object.keys(cl).sort((a, b) => a - b).map(k => `x${k}: ${cl[k]}`).join(', ') + '.');

// ---- 9. stance share
w('');
w('### 9. Where winners and losers spend their time, default arm (share of match time by stance)');
w(table(['', ...AS], [['Winners', ...D.stanceShare.winners.map(v => p(v))], ['Losers', ...D.stanceShare.losers.map(v => p(v))]]));

// ---- 10. seam
w('');
w('### 10. Seam exposure');
w(table(['Arm', 'Matches where a fighter crossed the seam', 'Crossings per match', 'Largest single-step move (units)'],
  ARMS.map(a => { const g = rr(a.arm); return [a.arm, p(g.seam.matchesWithCrossing / N, 0), (g.seam.crossings / N).toFixed(1), f1(g.seam.maxDisp)]; })));

// ---- 11. unseeded equivalence
let unseeded = null;
if (NU > 0) {
  const hu = createHarness(), recs = [];
  for (let i = 0; i < NU; i++) recs.push(runMatch(hu, undefined, { keepCarryover: true }));   // as the old sim-stats ran: clock seeds, one long-lived instance
  const g = S.aggregate(recs); unseeded = g;
  const R = runs['default'].recs, len = r => r.koAt;
  const z = [
    ['P1 (KAI) win rate', p(g.slotRate[0].rate), p(dflt.slotRate[0].rate), S.twoPropZ(g.slotWins[0], g.decided, dflt.slotWins[0], dflt.decided)],
    ['Length to KO, mean (s)', f1(g.len.mean), f1(dflt.len.mean), S.welchZ(recs.map(len), R.map(len))],
    ['Civilians lost, mean (%)', f1(g.civPct.mean), f1(dflt.civPct.mean), S.welchZ(recs.map(r => r.civPct), R.map(r => r.civPct))],
    ['Structures lost, mean', f1(g.structs.mean), f1(dflt.structs.mean), S.welchZ(recs.map(r => r.structs), R.map(r => r.structs))],
    ['SLAM DOWN share of launches', p(g.launches.counts['SLAM DOWN'] / g.launches.total), p(slam), S.twoPropZ(g.launches.counts['SLAM DOWN'], g.launches.total, D.launches.counts['SLAM DOWN'], D.launches.total)],
    ['Ocean share of beams', p(g.beams.share.ocean), p(D.beams.share.ocean), S.twoPropZ(g.beams.bio.ocean, g.beams.total, D.beams.bio.ocean, D.beams.total)],
    ['Parries per match', g.parry.perMatch.toFixed(2), D.parry.perMatch.toFixed(2), S.welchZ(recs.map(r => r.parries[0] + r.parries[1]), R.map(r => r.parries[0] + r.parries[1]))],
    ['Hides per match', g.hide.perMatch.toFixed(2), D.hide.perMatch.toFixed(2), S.welchZ(recs.map(r => r.hides[0] + r.hides[1]), R.map(r => r.hides[0] + r.hides[1]))],
  ];
  w('');
  w(`### 11. Unseeded batch against the seeded baseline (clock-seeded, ${NU} matches, not reproducible)`);
  w(`Run as the old tool ran: one long-lived instance, no seed, no carry-over reset. The comparison is against the seeded default arm. |z| below 3 counts as matching (eight tests, so about a 2% chance of a false alarm).`);
  w('');
  w(table(['Measure', 'Unseeded', 'Seeded default', 'z', 'Matches?'], z.map(r => [r[0], r[1], r[2], r[3].toFixed(2), Math.abs(r[3]) < 3 ? 'yes' : '**NO**'])));
  w('');
  w(`Unseeded launches: ${Object.entries(g.launches.counts).sort((a, b) => b[1] - a[1]).map(([k, v]) => `${k} ${p(v / g.launches.total, 0)}`).join(', ')}.`);
  w('Bit-for-bit check (run once, not part of the suite because it needs the old file from git): the original `prototype/index.html` from commit 111b1a1 with the clock forced to S, against the edited file called as `newMatch(S)`, gave the same result hash for 200 of 200 odd seeds S.');
}

// ---- assemble file
const generated = out.join('\n');
const BEGIN = '<!-- BEGIN GENERATED -->', END = '<!-- END GENERATED -->';
if (args.includes('--print')) console.log(generated);
else {
  let doc = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : null;
  if (doc && doc.includes(BEGIN) && doc.includes(END)) doc = doc.slice(0, doc.indexOf(BEGIN) + BEGIN.length) + '\n' + generated + '\n' + doc.slice(doc.indexOf(END));
  else doc = (doc ? doc + '\n\n' : '# Balance report\n\n') + BEGIN + '\n' + generated + '\n' + END + '\n';
  fs.writeFileSync(OUT, doc);
  console.log('wrote ' + path.relative(process.cwd(), OUT));
}
const slim = a => { const g = { ...runs[a].agg }; return g; };
const json = { generatedWith: { node: process.version, matches: N, unseeded: NU }, arms: Object.fromEntries(ALL.map(a => [a.arm, slim(a.arm)])), unseeded: unseeded || undefined };
fs.writeFileSync(JSON_OUT, JSON.stringify(json, null, 1) + '\n');
console.log('wrote ' + path.relative(process.cwd(), JSON_OUT));
