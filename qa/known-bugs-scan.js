#!/usr/bin/env node
// Effect sizes of the confirmed prototype bugs on the baseline: node qa/known-bugs-scan.js [--matches=1000] [--print]
// Replays the baseline's default arm (seeds 100001..) on an instrumented scratch copy of the prototype (qa/lib/instrument.js)
// and counts what each bug touches. The instrumented copy plays out bit-for-bit like the real file; the digest printed
// at the end is compared with qa/baseline-p0.json to prove it. Writes qa/known-bugs-effects.json unless --print is given.
const fs = require('fs');
const path = require('path');
const { instrumentedHarness } = require('./lib/instrument');
const { PLAN, runArm } = require('./lib/arms');
const { sdx } = require('../prototype/tools/match-runner');
const S = require('../prototype/tools/stats');

const args = process.argv.slice(2);
const val = (n, d) => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.split('=')[1] : d; };
const N = parseInt(val('matches', '1000'), 10);
const OUT = path.join(__dirname, 'known-bugs-effects.json');
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const STANCE_MUL = [1.12, 0.38, 1.0, 1.25];                           // hit() multiplier by defender stance (bypassed by chain strikes)

const h = instrumentedHarness(), wf = h.wf;
const X = {
  beams: [], hits: [], chainLinks: 0, phantomLinks: 0, phantomEx: new Set(), realEx: new Set(),
  rushSteps: 0, rushBelow: 0, rushBuilding: 0, rushSeen: new WeakSet(), rushes: 0, rushDepth: new Map(), rushesBelow: 0, rushBuildingSeen: new WeakSet(), rushesBuilding: 0, maxDepth: 0,
};
let cur = null;
global.__beamProbe = ex => { X.beams.push({ ex, aTier: ex.A.tier, dTier: ex.D.tier, dist: Math.abs(sdx(ex.A.x, ex.D.x)), ds: ex.D.dPrev === 'charging' ? 4 : ex.D.stance, ambush: ex.A.ambush }); };
global.__hitProbe = (ex, A, D, dmg, o) => {
  o = o || {};
  cur = { D, dState: D.state, dStance: D.stance, charging: D.dPrev === 'charging', chain: !!(o.big && o.stop === 0.08 && o.noParry && o.ignoreStance), ignore: !!o.ignoreStance, dd: null };
};
global.__hurtProbe = (f, amt) => { if (cur && f === cur.D && cur.dd === null) { cur.dd = amt; X.hits.push(cur); cur = null; } };
global.__chainProbe = ex => { X.chainLinks++; if (ex.cancel) { X.phantomLinks++; X.phantomEx.add(ex); } else X.realEx.add(ex); };
global.__rushProbe = (f, dt, ground) => {
  X.rushSteps++;
  const r = f.rush, depth = ground - f.y;
  if (!X.rushSeen.has(r)) { X.rushSeen.add(r); X.rushes++; }
  if (depth > 1) { X.rushBelow++; if (depth > X.maxDepth) X.maxDepth = depth; if (depth > (X.rushDepth.get(r) || 0)) X.rushDepth.set(r, depth); }
  for (const b of wf.buildings()) {
    if (!b.alive || Math.abs(sdx(f.x, b.x)) >= b.w / 2) continue;
    const gy = wf.groundY(b.x);
    if (f.y < gy + wf.curH(b) && f.y > gy - 10) { X.rushBuilding++; if (!X.rushBuildingSeen.has(r)) { X.rushBuildingSeen.add(r); X.rushesBuilding++; } break; }
  }
};

const plan = PLAN.find(p => p.arm === 'default');
const { agg } = runArm(h, plan, N);
const baseline = JSON.parse(fs.readFileSync(path.join(__dirname, 'baseline-p0.json'), 'utf8'));
const bd = baseline.arms.default;
const neutral = N === baseline.generatedWith.matches ? agg.digest === bd.digest : null;

// ---- KB-001: beams against an ESCAPE defender
const esc = X.beams.filter(b => b.ds === 3);
const pAct = b => clamp(0.5 - 0.05 * (b.aTier - b.dTier) + (b.dist < 500 ? 0.3 : 0), 0.15, 0.9);
const pFix = b => clamp(0.5 + 0.05 * (b.aTier - b.dTier) + (b.dist < 500 ? 0.3 : 0), 0.15, 0.9);
const outcome = b => (/→ (\w+)$/.exec(b.ex.tag) || [])[1];
const kb1 = {
  beams: X.beams.length, vsEscape: esc.length, perMatch: esc.length / N, shareOfBeams: esc.length / X.beams.length,
  meanTierGap: S.mean(esc.map(b => b.aTier - b.dTier)), hitRate: esc.filter(b => outcome(b) === 'HIT').length / esc.length,
  meanPActual: S.mean(esc.map(pAct)), meanPCorrect: S.mean(esc.map(pFix)),
  hitsPerMatchShift: esc.length * (S.mean(esc.map(pFix)) - S.mean(esc.map(pAct))) / N,
  meanAbsShift: S.mean(esc.map(b => Math.abs(pFix(b) - pAct(b)))), beamsWithTierGap: esc.filter(b => b.aTier !== b.dTier).length / esc.length,
};
// ---- KB-002: hits on a charging defender
const totalDmg = S.sum(X.hits.map(x => x.dd));
const chg = X.hits.filter(x => x.charging);
const kb2 = {
  hits: X.hits.length, hitsOnChargingDefender: chg.length, perMatch: chg.length / N, hitsWhereStateWasCharging: X.hits.filter(x => x.dState === 'charging').length,
  hitsThatBypassStance: chg.filter(x => x.ignore).length, damage: S.sum(chg.map(x => x.dd)), shareOfAllDamage: S.sum(chg.map(x => x.dd)) / totalDmg,
  missingDamagePerMatch: 0.35 * S.sum(chg.map(x => x.dd)) / N,
};
// ---- KB-003: chain links after a parry
const chainEvents = X.phantomEx.size + X.realEx.size;
const recsMelee = () => [bd.metrics['melee.perMatch'].v * N];
const kb3 = {
  chainLinks: X.chainLinks, phantomLinks: X.phantomLinks, phantomLinkShare: X.phantomLinks / X.chainLinks,
  chainEvents, phantomEvents: X.phantomEx.size, phantomEventShare: X.phantomEx.size / chainEvents, phantomEventsPerMatch: X.phantomEx.size / N,
  chainEventsPerMatchReported: chainEvents / N, chainEventsPerMatchReal: X.realEx.size / N, kiWastedPerMatch: 6 * X.phantomLinks / N,
  parriesPerMatch: bd.metrics['parry.perMatch'].v,
  meanLengthReal: S.mean([...X.realEx].map(e => e.combo)), meanLengthPhantom: S.mean([...X.phantomEx].map(e => e.combo)),
  chainPerMeleeReported: chainEvents / S.sum(recsMelee()), chainPerMeleeReal: X.realEx.size / S.sum(recsMelee()),
};
// ---- KB-004: chain strikes ignore the defender's stance
const cs = X.hits.filter(x => x.chain);
const byStance = [0, 1, 2, 3].map(s => { const c = cs.filter(x => x.dStance === s); return { stance: s, n: c.length, meanDmg: c.length ? S.mean(c.map(x => x.dd)) : 0, factorBypassed: STANCE_MUL[s], dmgDifferencePerMatch: S.sum(c.map(x => x.dd * (STANCE_MUL[s] - 1))) / N }; });
const kb4 = { chainStrikes: cs.length, perMatch: cs.length / N, shareOfAllDamage: S.sum(cs.map(x => x.dd)) / totalDmg, byStance, guardedExtraDamagePerMatch: -byStance[1].dmgDifferencePerMatch, totalDamagePerMatch: totalDmg / N };
// ---- KB-005: dodged signatures
const dodged = X.beams.filter(b => outcome(b) === 'DODGE');
const kb5 = { dodgedBeams: dodged.length, perMatch: dodged.length / N, shareOfBeams: dodged.length / X.beams.length, frozenSecondsPerMatch: dodged.length * 0.8667 / N, shareOfMatchTime: dodged.length * 0.8667 / N / agg.len.mean };
// ---- KB-006: rushes through terrain and buildings
const kb6 = {
  rushes: X.rushes, rushesPerMatch: X.rushes / N, rushSteps: X.rushSteps, stepsInsideTerrain: X.rushBelow, shareOfRushStepsInsideTerrain: X.rushBelow / X.rushSteps,
  rushesInsideTerrain: X.rushDepth.size, shareOfRushes: X.rushDepth.size / X.rushes, deepest: X.maxDepth,
  rushesDeeperThan20: [...X.rushDepth.values()].filter(d => d > 20).length, rushesDeeperThan100: [...X.rushDepth.values()].filter(d => d > 100).length, rushesDeeperThan300: [...X.rushDepth.values()].filter(d => d > 300).length,
  stepsInsideBuildings: X.rushBuilding, shareOfRushStepsInsideBuildings: X.rushBuilding / X.rushSteps, rushesInsideBuildings: X.rushesBuilding, shareOfRushesThroughBuildings: X.rushesBuilding / X.rushes,
  secondsInsideTerrainPerMatch: X.rushBelow / 60 / N, secondsInsideBuildingsPerMatch: X.rushBuilding / 60 / N,
};

const out = { matches: N, arm: 'default', seeds: `${plan.base}..${plan.base + N - 1}`, digest: agg.digest, digestMatchesBaseline: neutral, kb1, kb2, kb3, kb4, kb5, kb6 };
const pc = (v, d = 1) => (v * 100).toFixed(d) + '%', f2 = v => v.toFixed(2);
console.log(`known-bugs scan: default arm, ${N} matches, seeds ${out.seeds}, instrumented copy digest ${agg.digest}${neutral === null ? '' : neutral ? ' (identical to the baseline: the instrumentation changes nothing)' : ' (DIFFERS from the baseline: instrumentation is not neutral!)'}`);
console.log(`KB-001  ${kb1.vsEscape} of ${kb1.beams} beams (${pc(kb1.shareOfBeams)}) hit an ESCAPE defender, ${f2(kb1.perMatch)} a match; mean tier gap ${f2(kb1.meanTierGap)} (${pc(kb1.beamsWithTierGap, 0)} of them with any gap, HIT probability off by ${pc(kb1.meanAbsShift)} on average, cancelling out); HIT rate ${pc(kb1.hitRate)}; mean HIT probability ${pc(kb1.meanPActual)} as coded vs ${pc(kb1.meanPCorrect)} with the sign corrected (${f2(kb1.hitsPerMatchShift)} more hits a match)`);
console.log(`KB-002  ${kb2.hitsOnChargingDefender} hits on a charging defender (${f2(kb2.perMatch)} a match, ${pc(kb2.shareOfAllDamage, 2)} of damage dealt); hits where the defender's state read "charging": ${kb2.hitsWhereStateWasCharging}; all ${kb2.hitsThatBypassStance} also bypass stance modifiers; the 1.35x would add ${f2(kb2.missingDamagePerMatch)} HP a match`);
console.log(`KB-003  ${kb3.phantomEvents} of ${kb3.chainEvents} reported chains (${pc(kb3.phantomEventShare)}) follow a parry: ${f2(kb3.phantomEventsPerMatch)} a match of ${f2(kb3.chainEventsPerMatchReported)}; ${kb3.phantomLinks} phantom links waste ${f2(kb3.kiWastedPerMatch)} ki a match; real chains ${f2(kb3.chainEventsPerMatchReal)} a match (${pc(kb3.chainPerMeleeReal)} of melee exchanges instead of ${pc(kb3.chainPerMeleeReported)}); mean chain length ${f2(kb3.meanLengthReal)} real vs ${f2(kb3.meanLengthPhantom)} phantom`);
console.log(`KB-004  ${kb4.chainStrikes} chain strikes (${f2(kb4.perMatch)} a match, ${pc(kb4.shareOfAllDamage)} of damage dealt); by defender stance: ${byStance.map(b => `${['AGG', 'DEF', 'EVA', 'ESC'][b.stance]} ${b.n} (x${b.factorBypassed} bypassed)`).join(', ')}; ${f2(kb4.guardedExtraDamagePerMatch)} HP a match lands through a guard`);
console.log(`KB-005  ${kb5.dodgedBeams} dodged beams (${f2(kb5.perMatch)} a match, ${pc(kb5.shareOfBeams)} of beams): ${f2(kb5.frozenSecondsPerMatch)} s a match with the defender frozen, ${pc(kb5.shareOfMatchTime, 2)} of match time`);
console.log(`KB-006  ${kb6.rushes} rushes (${f2(kb6.rushesPerMatch)} a match): ${kb6.rushesInsideTerrain} (${pc(kb6.shareOfRushes)}) spend time inside terrain (${kb6.rushesDeeperThan20} deeper than 20 units, ${kb6.rushesDeeperThan100} deeper than 100, ${kb6.rushesDeeperThan300} deeper than 300), deepest ${kb6.deepest.toFixed(0)} units; ${kb6.rushesInsideBuildings} (${pc(kb6.shareOfRushesThroughBuildings)}) pass through a standing building`);
if (!args.includes('--print')) { fs.writeFileSync(OUT, JSON.stringify(out, null, 1) + '\n'); console.log('wrote ' + path.relative(process.cwd(), OUT)); }
