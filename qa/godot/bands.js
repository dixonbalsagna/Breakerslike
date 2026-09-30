// Band checks for the GDScript sim: docs/design/balance-targets.md turned into pass/fail rows over QA records
// (qa/godot/records.gd). Pure functions over records; no Godot here. Statuses:
//   PASS / FAIL   measured against a band from balance-targets.md
//   INFO          measured, no band (context for a nearby row)
//   PENDING       needs something the sim does not have yet (a slice, an event, a probe); the row says what
// Pass rule for a rate (balance-targets "How to measure"): the point estimate is inside the band AND the 95% interval
// lies inside the band widened by 2 points each side. For a mean or a median, the point estimate is inside the band.
const S = require('../../prototype/tools/stats');
const { SEG } = require('../../prototype/tools/match-runner');

const PLANET = {};                                                  // share of the planet's circumference per biome
for (const [a, b, name] of SEG) PLANET[name] = (PLANET[name] || 0) + (b - a) / 9600;
const sum = S.sum, mean = S.mean;
const total = o => sum(Object.values(o));
const melee = r => total(r.melee);
const median = a => { const s = a.slice().sort((x, y) => x - y); return S.quantile(s, 0.5); };
const q = (a, p) => S.quantile(a.slice().sort((x, y) => x - y), p);

const fmt = { pct: v => (v * 100).toFixed(1) + '%', num: v => (Math.abs(v) >= 100 ? v.toFixed(0) : v.toFixed(2)), s: v => v.toFixed(1) + ' s', pts: v => (v >= 0 ? '+' : '') + (v * 100).toFixed(1) + ' pts' };
const bandText = (lo, hi, f) => (lo === -Infinity ? `at most ${f(hi)}` : hi === Infinity ? `at least ${f(lo)}` : `${f(lo)} to ${f(hi)}`);

class Rows {
  constructor() { this.rows = []; }
  add(r) { this.rows.push(r); return this; }
  // A rate with a Wilson or clustered interval: value in band and interval inside the band widened by 2 points.
  rate(id, ref, what, { v, ci, lo = -Infinity, hi = Infinity, unit = 'pct', note = '' }) {
    const f = fmt[unit], w = unit === 'pct' || unit === 'pts' ? 0.02 : 0;
    const okPoint = v >= lo && v <= hi, okCi = ci ? ci[0] >= lo - w && ci[1] <= hi + w : true;
    return this.add({ id, ref, what, status: okPoint && okCi ? 'PASS' : 'FAIL', value: f(v) + (ci ? ` [${f(ci[0])}, ${f(ci[1])}]` : ''), band: bandText(lo, hi, f), note: note || (okPoint && !okCi ? 'point inside the band, interval outside the widened band' : '') });
  }
  // A mean or median: point estimate only.
  point(id, ref, what, { v, lo = -Infinity, hi = Infinity, unit = 'num', note = '' }) {
    if (!Number.isFinite(v)) return this.pending(id, ref, what, 'no data');
    const f = fmt[unit];
    return this.add({ id, ref, what, status: v >= lo && v <= hi ? 'PASS' : 'FAIL', value: f(v), band: bandText(lo, hi, f), note });
  }
  info(id, ref, what, value, note = '') { return this.add({ id, ref, what, status: 'INFO', value, band: '', note }); }
  pending(id, ref, what, needs) { return this.add({ id, ref, what, status: 'PENDING', value: '', band: '', note: needs }); }
}

const wl = (k, n) => S.wilson(k, n);
const decided = recs => recs.filter(r => !r.timeout);
const p1Wins = recs => decided(recs).filter(r => r.winner === 0).length;

// KAI's win rate over both slots (default: KAI in P1, swap: KAI in P2).
function kaiRate(A) {
  const d = decided(A.default), s = decided(A.swap);
  const k = d.filter(r => r.winner === 0).length + s.filter(r => r.winner === 1).length, n = d.length + s.length;
  return { v: k / n, ci: wl(k, n), k, n };
}
// Slot and spawn effects in a mirror, from the arm and its -flip: P1 win = 0.5 + slot +- spawn.
function mirrorEffects(A, arm) {
  const a = A[arm], b = A[arm + '-flip'];
  const pa = p1Wins(a) / decided(a).length, pb = p1Wins(b) / decided(b).length;
  const va = pa * (1 - pa) / decided(a).length, vb = pb * (1 - pb) / decided(b).length, se = Math.sqrt(va + vb) / 2;
  return { slot: (pa + pb) / 2 - 0.5, spawn: (pa - pb) / 2, se };
}

// Event types that share a prefix with a future hazard family but are not it: hazard_telegraph is a warning the director sends today.
const IGNORED = new Set(['hazard_telegraph']);
// hasEvent: does any record carry an fx event of this type? A trailing * matches a prefix.
function hasEvent(A, pattern) {
  const pre = pattern.endsWith('*') ? pattern.slice(0, -1) : null;
  for (const recs of Object.values(A)) for (const r of recs) for (const t of Object.keys(r.fxCounts || {})) if (pre !== null ? t.startsWith(pre) && !IGNORED.has(t) : t === pattern) return true;
  return false;
}

const SCALES = {
  testbed: { len: { mean: [40, 70], p90: 100 }, tier3: 0.70, tier4: 0.25, civ: [25, 50], worst: 65, civ90: 0.07, bleed: 40, structRow1: [20, 40] },
  game: { len: { median: [360, 480], p10: 300, p90: 600 }, tier3: 0.70, tier4: 0.60, civ: [45, 75], worst: 85, civ90: 0.10, bleed: 4, structRow1: [40, 75] },
};

function evaluate(A, { scale = 'testbed', cap = 18000 } = {}) {
  const R = new Rows(), sc = SCALES[scale];
  const arms = Object.keys(A), D = A.default, have = (...n) => n.every(x => A[x] && A[x].length);
  const capSec = cap / 60;

  // ---- 1. win rate
  if (have('default', 'swap')) {
    const k = kaiRate(A);
    R.rate('1.kai', '§1', 'KAI win rate, averaged over both slots (1v1 pairing)', { v: k.v, ci: k.ci, lo: 0.45, hi: 0.55, note: `${k.k} of ${k.n} decided matches` });
    R.rate('9.kai42', '§9', 'KAI at least 42% (the placeholder-balance target from slice S0)', { v: k.v, ci: k.ci, lo: 0.42, hi: 1, note: 'the 45 to 55% band applies to the real roster' });
  } else R.pending('1.kai', '§1', 'KAI win rate over both slots', 'needs arms default and swap');
  for (const m of ['mirror-villain', 'mirror-hero']) {
    if (have(m, m + '-flip')) {
      const e = mirrorEffects(A, m);
      R.rate(`1.${m}.slot`, '§1', `${m}: slot effect within ±3 points`, { v: e.slot, ci: [e.slot - 1.96 * e.se, e.slot + 1.96 * e.se], lo: -0.03, hi: 0.03, unit: 'pts' });
      R.rate(`1.${m}.spawn`, '§1', `${m}: spawn-side effect within ±3 points`, { v: e.spawn, ci: [e.spawn - 1.96 * e.se, e.spawn + 1.96 * e.se], lo: -0.03, hi: 0.03, unit: 'pts' });
    } else R.pending(`1.${m}`, '§1', `${m} slot and spawn effects`, `needs arms ${m} and ${m}-flip`);
  }

  // ---- 2. match length
  if (D) {
    const lens = D.map(r => r.koAt), to = D.filter(r => r.timeout).length / D.length;
    if (scale === 'testbed') {
      R.point('2.len.mean', '§2', 'Match length to the KO, mean (P2 testbed)', { v: mean(lens), lo: sc.len.mean[0], hi: sc.len.mean[1], unit: 's' });
      R.point('2.len.p90', '§2', 'Match length, 90th percentile', { v: q(lens, 0.9), hi: sc.len.p90, unit: 's' });
    } else {
      R.point('2.len.median', '§2', 'Match length median (game, 1v1)', { v: median(lens), lo: sc.len.median[0], hi: sc.len.median[1], unit: 's' });
      R.point('2.len.p10', '§2', 'Match length, 10th percentile', { v: q(lens, 0.1), lo: sc.len.p10, unit: 's' });
      R.point('2.len.p90', '§2', 'Match length, 90th percentile', { v: q(lens, 0.9), hi: sc.len.p90, unit: 's' });
    }
    R.rate('2.timeouts', '§2', `Timeouts at the ${capSec} s cap`, { v: to, ci: wl(D.filter(r => r.timeout).length, D.length), hi: 0.01 });
  }

  // ---- 3. escalation
  if (D) {
    const t = n => D.filter(r => Math.max(...r.maxTier) >= n);
    R.rate('3.tier3', '§3', 'A fighter reaches tier 3 before the KO', { v: t(3).length / D.length, ci: wl(t(3).length, D.length), lo: sc.tier3 });
    R.rate('3.tier4', '§3', 'A fighter reaches tier 4 before the KO', { v: t(4).length / D.length, ci: wl(t(4).length, D.length), lo: sc.tier4 });
    R.pending('3.transform', '§3', 'First transformation timing; the last 60 s has a clash or finisher', 'game scale: needs transformations (roster) and finishers (S2)');
  }

  // ---- 4. collateral
  if (D) {
    R.point('4.civ.mean', '§4', 'Civilians lost at the KO, mean, default arm', { v: mean(D.map(r => r.civPct)), lo: sc.civ[0], hi: sc.civ[1], unit: 'num', note: '%' });
    const armMeans = arms.filter(a => !a.endsWith('-flip')).map(a => [a, mean(A[a].map(r => r.civPct))]);
    const worst = armMeans.reduce((x, y) => (y[1] > x[1] ? y : x));
    R.point('4.civ.worst', '§4', `Worst pairing's mean civilians lost (${worst[0]})`, { v: worst[1], hi: sc.worst, unit: 'num', note: '%' });
    for (const a of arms.filter(a => !a.endsWith('-flip'))) {
      const c = A[a].filter(r => r.civPct >= 90).length;
      R.rate(`4.civ90.${a}`, '§4', `Matches losing 90% or more of civilians (${a})`, { v: c / A[a].length, ci: wl(c, A[a].length), hi: sc.civ90 });
    }
    const bleed = recs => sum(recs.map(r => r.lowCas / r.pop0)) / (sum(recs.map(r => r.lowSec)) / 60) * 100;   // % of the population per minute, pooled over matches
    R.point('4.bleed', '§4', 'Low-tier bleed: civilians lost per minute while both fighters are at tier 2 or below, % of population (default arm)', { v: bleed(D), hi: sc.bleed, unit: 'num', note: `${(sum(D.map(r => r.lowSec)) / 60 / D.length).toFixed(1)} min at low tier per match; includes every source the sim has` });
    const row1 = D.map(r => (r.rows && r.rows['1'] ? r.rows['1'].lost / r.rows['1'].n : NaN));
    R.point('4.struct.row1', '§4', 'Structures lost at the KO, mean share of row-1 (front-row) structures', { v: mean(row1) * 100, lo: sc.structRow1[0], hi: sc.structRow1[1], unit: 'num', note: '%' });
    const rowKeys = new Set(D.flatMap(r => Object.keys(r.rows || {})));
    if (rowKeys.size > 1) {
      const all = D.map(r => sum(Object.values(r.rows).map(x => x.lost)) / sum(Object.values(r.rows).map(x => x.n)));
      R.info('4.struct.all', '§4', 'Structures lost, all rows (watch metric, not a gate)', (mean(all) * 100).toFixed(1) + '%', `rows ${[...rowKeys].sort().join(', ')}`);
      for (const k of [...rowKeys].sort()) R.info(`4.struct.row${k}`, '§4', `Structures lost, row ${k}`, (mean(D.map(r => (r.rows[k] ? r.rows[k].lost / r.rows[k].n : NaN)).filter(Number.isFinite)) * 100).toFixed(1) + '%');
    } else R.pending('4.struct.rows', '§4', 'Structures lost split by row, all-rows watch metric', 'the sim has one row of buildings (docs/world/buildings-in-depth.md); the split appears once buildings carry a row');
    R.pending('4.cyborg', '§4', 'Civilians left at 4:00: at least 25% alive in at least 80% of matches', 'game scale: needs 7-minute matches (Wounds S2)');
  }

  // ---- 4b. casualty ramp and ceiling (measured today as the share of matches that would break them; tested once World builds them)
  if (D && D[0].casTimeline) {
    const BUDGET = [0, 0.02, 0.04, 0.08, 0.15], CEIL = [0, 0.10, 0.30, 0.60, 0.90];
    const viol = recs => {
      let roll = 0, ceil = 0;
      for (const r of recs) {
        const tl = r.casTimeline; let rv = false, cv = false, maxTier = 1;
        for (let i = 0; i < tl.length; i++) {
          maxTier = Math.max(maxTier, tl[i][2]);
          const j = tl.findIndex(x => x[0] >= tl[i][0] - 60), back = j >= 0 && tl[i][0] >= 60 ? tl[j][1] : 0;
          if (tl[i][1] - back > BUDGET[tl[i][2]] + 1e-9) rv = true;
          if (tl[i][1] > CEIL[maxTier] + 1e-9) cv = true;
        }
        if (rv) roll++; if (cv) ceil++;
      }
      return { roll: roll / recs.length, ceil: ceil / recs.length };
    };
    const v = viol(D);
    R.info('4b.rolling', '§4b', 'Matches with a 60 s window over the tier budget (2%, 4%, 8%, 15%): what the ramp will have to change (default arm)', fmt.pct(v.roll), 'the rolling-window test is pending the ramp World is building (skeleton C1)');
    R.info('4b.ceiling', '§4b', 'Matches over the cumulative ceiling (10%, 30%, 60%, 90% by highest tier so far) (default arm)', fmt.pct(v.ceil), 'the ceiling test is pending the cap World is building (skeleton C2)');
    const cb = [1, 2, 3, 4].map(t => sum(D.map(r => r.casByTier[t] / r.pop0)));
    const ct = sum(cb);
    R.info('4b.split', '§4b', 'Per-tier split of casualties by the higher tier when they happened (default arm)', [1, 2, 3, 4].map((t, i) => `tier ${t} ${(cb[i] / ct * 100).toFixed(0)}%`).join(', '), 'skeleton C3 bands it once the ramp exists');
  }

  // ---- 5. launch variety and 5b brunts
  for (const a of arms.filter(x => !x.endsWith('-flip'))) {
    const recs = A[a], names = [...new Set(recs.flatMap(r => Object.keys(r.launches)))];
    const shares = names.map(n => [n, S.clusterShare(recs, r => r.launches[n] || 0, r => total(r.launches))]).sort((x, y) => y[1].p - x[1].p);
    if (!shares.length) continue;
    const top = shares[0];
    R.rate(`5.cap.${a}`, '§5', `No launch type above 40% (${a}): largest is ${top[0]}`, { v: top[1].p, ci: [top[1].ci[0], top[1].ci[1]], hi: 0.40, note: 'match-clustered upper bound must be at most 42%' });
    R.add({ id: `5.cap.${a}.upper`, ref: '§5', what: `Largest launch type's clustered upper bound at most 42% (${a})`, status: top[1].ci[1] <= 0.42 ? 'PASS' : 'FAIL', value: fmt.pct(top[1].ci[1]), band: 'at most 42.0%', note: '' });
  }
  if (D) {
    const names = [...new Set(D.flatMap(r => Object.keys(r.launches)))];
    const n5 = names.filter(n => S.clusterShare(D, r => r.launches[n] || 0, r => total(r.launches)).p >= 0.05).length;
    R.point('5.floor', '§5', 'At least 4 launch types at or above 5% (default arm)', { v: n5, lo: 4, unit: 'num' });
    const isBrunt = n => /BUILDING|BRUNT/.test(n);
    const brunt = r => sum(Object.entries(r.launches).filter(([n]) => isBrunt(n)).map(([, v]) => v));
    const bs = S.clusterShare(D, brunt, r => total(r.launches));
    R.rate('5b.share', '§5b', 'Share of all planner launches that are building brunts', { v: bs.p, ci: bs.ci, lo: 0.08, hi: 0.20 });
    const perMin = recs => sum(recs.map(brunt)) / (sum(recs.map(r => r.koAt)) / 60);   // brunts per minute of match, pooled
    R.point('5b.perMin', '§5b', 'Brunts per minute (default arm)', { v: perMin(D), lo: 0.1, hi: 0.35 });
    if (have('mirror-villain')) R.add({ id: '5b.villain>default', ref: '§5b', what: 'Villain mirror has more brunts per minute than the default arm', status: perMin(A['mirror-villain']) > perMin(D) ? 'PASS' : 'FAIL', value: `${perMin(A['mirror-villain']).toFixed(2)} vs ${perMin(D).toFixed(2)}`, band: 'greater', note: '' });
    if (have('mirror-hero')) R.point('5b.hero', '§5b', 'Hero mirror: brunts per minute at most 0.15', { v: perMin(A['mirror-hero']), hi: 0.15 });
    if (hasEvent(A, 'launch_plan')) {
      const plans = D.flatMap(r => (r.events || []).filter(e => e.type === 'launch_plan' && /BUILDING|BRUNT/.test(e.text || '')));
      const picked = plans.filter(e => /BUILDING|BRUNT/.test(e.chosen || '')).length;
      R.rate('5b.reach', '§5b', 'Launches that pick a building, out of those with a building candidate in reach (35 to 60% pooled)', { v: picked / plans.length, ci: wl(picked, plans.length), lo: 0.35, hi: 0.60, note: `${plans.length} plans with a candidate; from launch_plan events` });
    } else R.pending('5b.reach', '§5b', 'Launches that pick a building, out of those with a candidate in reach (35 to 60%)', 'needs launch_plan events');
    R.pending('5b.chains', '§5b', 'Chains among brunts, chain lengths, the per-tier casualty budget for one chain (hard test), the launcher tier cap (hard test)', 'needs brunt-chain events (World, buildings-in-depth §4b); skeleton in qa/godot/pending-tests.js');
  }

  // ---- 5c. knockback slides (ground impacts): a slide ends in a `slide` event, a slam digs an impact crater
  if (D && hasEvent(A, 'slide')) {
    const sl = S.clusterShare(D, r => r.slides.length, r => r.slides.length + r.impactCraters);
    R.rate('5c.share', '§5c', 'Ground contacts that slide rather than slam (slams stay at 15% or more)', { v: sl.p, ci: sl.ci, lo: 0.60, hi: 0.85 });
    // the per-match band is retired (it scaled with match length); the band is per minute, and per launch
    R.point('5c.perMin', '§5c', 'Slides per minute (default arm)', { v: sum(D.map(r => r.slides.length)) / (sum(D.map(r => r.koAt)) / 60), lo: 1.5, hi: 4, unit: 'num' });
    const sPerL = S.clusterShare(D, r => r.slides.length, r => total(r.launches));
    R.rate('5c.perLaunch', '§5c', 'Launches that end in a slide (35 to 70% of all launches)', { v: sPerL.p, ci: sPerL.ci, lo: 0.35, hi: 0.70 });
    R.info('5c.detail', '§5c', 'Slides: mean length and trench width; slams (impact craters) per match; water skims per match', `${mean(D.flatMap(r => r.slides.map(x => x.len))).toFixed(0)} units, ${mean(D.flatMap(r => r.slides.map(x => x.w))).toFixed(1)} wide; ${mean(D.map(r => r.impactCraters)).toFixed(1)} slams; ${mean(D.map(r => r.skims)).toFixed(1)} skims`, 'paved starts: ' + (D.flatMap(r => r.slides).filter(x => x.variant === 'paved').length / Math.max(1, D.flatMap(r => r.slides).length) * 100).toFixed(0) + '%');
    R.pending('5c.budget', '§5c', 'Casualties from one slide at most 2% (tier 2 or below), 5% (tier 3), 10% (tier 4); 0 in open country; the planner declines launches over budget (hard tests)', 'needs casualties attributed per slide (a slide event with the population lost, or the predicted slide of the planner) and the predicted-vs-actual landing test from Encounter');
  } else if (D) R.pending('5c.slides', '§5c', 'Knockback slide bands', 'no slide events in this sim (World SC slide)');

  // ---- 6. location and signature variety
  for (const a of arms.filter(x => !x.endsWith('-flip'))) {
    const secs = {}; for (const r of A[a]) for (const [b, v] of Object.entries(r.fightSec)) secs[b] = (secs[b] || 0) + v;
    const tot = total(secs), top = Object.entries(secs).sort((x, y) => y[1] - x[1])[0];
    R.point(`6.time.${a}`, '§6', `No biome holds more than 40% of fight time (${a}): largest is ${top[0]}`, { v: top[1] / tot, hi: 0.40, unit: 'pct' });
    if (a === 'default') {
      const low = Object.keys(PLANET).filter(b => (secs[b] || 0) / tot < Math.min(PLANET[b] / 2, 0.03));
      R.add({ id: '6.time.floor', ref: '§6', what: 'Every biome holds at least half its planet share or 3% of fight time, whichever is lower (default arm)', status: low.length ? 'FAIL' : 'PASS', value: Object.keys(PLANET).map(b => `${b} ${((secs[b] || 0) / tot * 100).toFixed(1)}%`).join(', '), band: 'see rule', note: low.length ? 'below the floor: ' + low.join(', ') : '' });
    }
  }
  if (D) {
    const vars = {}; let nb = 0; for (const r of D) for (const b of r.beams) { vars[b.variant] = (vars[b.variant] || 0) + 1; nb++; }
    const top = Object.entries(vars).sort((x, y) => y[1] - x[1])[0] || ['none', 0];
    R.point('6.variant.cap', '§6', `No beam variant above 40% of beams: largest is ${top[0]}`, { v: top[1] / nb, hi: 0.40, unit: 'pct' });
    const allVariants = ['HORIZON CLEAVE', 'BOULEVARD RAZE', 'FIRESTORM', 'RIDGE BORE', 'GLASS TRENCH', 'MERIDIAN SCAR'];
    const missing = allVariants.filter(v => (vars[v] || 0) / nb < 0.03);
    R.add({ id: '6.variant.floor', ref: '§6', what: 'Every beam variant at least 3% of beams (one planet)', status: missing.length ? 'FAIL' : 'PASS', value: allVariants.map(v => `${v} ${(((vars[v] || 0) / nb) * 100).toFixed(1)}%`).join(', '), band: 'at least 3.0% each', note: missing.length ? 'below the floor: ' + missing.join(', ') + '. The bands are meant to hold over 20 seeded planets; QA has one planet' : '' });
    R.pending('6.planets', '§6', 'Location and variant bands over a fixed set of at least 20 seeded planets', 'the sim has one planet (W1: variable circumference / procedural planets)');
  }

  // ---- 7. stance balance (the parts measurable from AI matches)
  if (D) {
    const m = sum(D.map(melee));
    R.point('7.parry', '§7', 'Parries per 100 melee exchanges', { v: sum(D.map(r => sum(r.parries))) / m * 100, lo: 5, hi: 15 });
    R.point('7.chain', '§7', 'Chains per 100 melee exchanges', { v: sum(D.map(r => r.chains.length)) / m * 100, lo: 15, hi: 35 });
    const slip = sum(D.map(r => r.melee['PURSUIT — TARGET SLIPS AWAY'] || 0)), caught = sum(D.map(r => r.melee['PURSUIT — CAUGHT'] || 0));
    R.rate('7.slip', '§7', 'Pursuit slip rate (escape gamble)', { v: slip / (slip + caught), ci: wl(slip, slip + caught), lo: 0.35, hi: 0.65 });
    const esc = D.flatMap(r => r.beams.filter(b => b.ds === 'ESCAPE'));
    R.rate('7.beamEscape', '§7', 'Beam escape rate against an ESCAPE defender', { v: esc.filter(b => b.out === 'ESCAPE').length / esc.length, ci: wl(esc.filter(b => b.out === 'ESCAPE').length, esc.length), lo: 0.20, hi: 0.50 });
    R.pending('7.probe', '§7', 'Fixed-stance round robin: no forced stance above 55%, each stance below 45% against some other', 'needs the stance probe of stance-matrix.md §6 (two role-neutral fighters, one stance forced): not in the sim yet');
  }

  // ---- 8. story beats
  if (D) {
    R.info('8.hides', '§8', 'Hides and ambushes', 'retired', 'hiding is removed from the base game and kept for a future stealth fighter (balance-targets §8); the rows return with that fighter (canHide)');
    R.point('8.clash', '§8', 'Beam clashes and struggles per match (CLASH outcomes)', { v: mean(D.map(r => r.beams.filter(b => b.out === 'CLASH').length)), lo: 2, hi: 8 });
    // lock breaks through line of sight (spec-wounds 1c): an episode for fighter X runs from the first `searching` (kind lock) aimed at X after X was last found, to X's next `found`
    if (hasEvent(A, 'found')) {
      const eps = [], gapsBetween = [], perMatch = [];
      for (const r of D) {
        let n = 0; const lastFound = {}, start = {};
        for (const e of (r.events || [])) {
          if (e.type === 'searching' && e.kind !== 'sweep' && start[e.target] === undefined) start[e.target] = e.t;   // kind lock only: sweeps are AI hunt points, not lock loss
          if (e.type === 'found' && start[e.actor] !== undefined) { eps.push(e.t - start[e.actor]); if (lastFound[e.actor] !== undefined) gapsBetween.push(start[e.actor] - lastFound[e.actor]); lastFound[e.actor] = e.t; delete start[e.actor]; n++; }
        }
        perMatch.push(n);
      }
      R.point('8.lock.perMatch', '§1c', 'Lock breaks per match (1 to 4)', { v: mean(perMatch), lo: 1, hi: 4, unit: 'num' });
      if (eps.length) {
        R.point('8.lock.median', '§1c', 'Median lock-break length (2 to 3 s)', { v: median(eps), lo: 2, hi: 3, unit: 's' });
        R.add({ id: '8.lock.max', ref: '§1c', what: 'No lock break longer than 4 s (hard test)', status: Math.max(...eps) <= 4.05 ? 'PASS' : 'FAIL', value: `longest ${Math.max(...eps).toFixed(2)} s over ${eps.length} breaks`, band: 'at most 4 s', note: 'episodes are read from searching and found events; a hunt sweep with no lock loss can lengthen one' });
        R.add({ id: '8.lock.gap', ref: '§1c', what: 'Never within 6 s of the same fighters last one (hard test)', status: gapsBetween.length && Math.min(...gapsBetween) < 5.95 ? 'FAIL' : 'PASS', value: gapsBetween.length ? `shortest gap ${Math.min(...gapsBetween).toFixed(2)} s over ${gapsBetween.length}` : 'no repeat breaks', band: 'at least 6 s', note: '' });
      } else R.pending('8.lock.length', '§1c', 'Lock-break length and spacing', 'no complete lock break (searching then found) in these matches');
      const ll = mean(D.map(r => (r.events || []).filter(e => e.type === 'lock_lost').length));
      R.info('8.lock.attempts', '§1c', 'Attacks refused for lost lock (lock_lost) per match', ll.toFixed(2));
    } else R.pending('8.lock', '§1c', 'Lock breaks through line of sight: 1 to 4 a match, median 2 to 3 s, at most 4 s, never within 6 s of the last', 'needs the found and searching events (S2)');
    // the brink chapter and crippling moment (Game Design, spec-wounds 1b; values set by the brink-chapter tuning)
    if (hasEvent(A, 'brink_enter') && hasEvent(A, 'ko')) {
      const evs = (r, t) => (r.events || []).filter(e => e.type === t);
      const b2k = D.map(r => { const b = evs(r, 'brink_enter')[0], k = evs(r, 'ko')[0]; return b && k ? k.t - b.t : null; }).filter(x => x !== null);
      R.point('8.brink2ko', '§8', 'Brink to KO, median (45 to 90 s)', { v: median(b2k), lo: 45, hi: 90, unit: 's' });
      const fb = D.map(r => { const b = evs(r, 'brink_enter')[0]; return b ? b.t : null; }).filter(x => x !== null);
      R.point('8.firstBrink', '§8', 'First brink, median (4:30 to 7:00)', { v: median(fb), lo: 270, hi: 420, unit: 's' });
      const cont = D.flatMap(r => evs(r, 'finisher_contest'));
      if (cont.length) R.rate('8.survival', '§8', 'Finisher survival rate (25 to 40%)', { v: cont.filter(e => e.survived).length / cont.length, ci: wl(cont.filter(e => e.survived).length, cont.length), lo: 0.25, hi: 0.40 });
      R.point('8.rallies', '§8', 'Rallies per match (0.3 to 0.7)', { v: mean(D.map(r => evs(r, 'rally').length)), lo: 0.3, hi: 0.7, unit: 'num' });
      R.point('8.regionBreaks', '§8', 'Region breaks per match (1.5 to 2.5)', { v: mean(D.map(r => evs(r, 'region_broken').length)), lo: 1.5, hi: 2.5, unit: 'num' });
      const lb = D.flatMap(r => evs(r, 'limb_break'));
      R.point('8.limbBreaks', '§8', 'Limb breaks per match (0.3 to 0.5)', { v: lb.length / D.length, lo: 0.3, hi: 0.5, unit: 'num' });
      if (lb.length) { const ar = lb.filter(e => e.region === 'arms').length / lb.length; R.point('8.limbArms', '§8', 'Arms share of limb breaks (35 to 65%; legs is the rest)', { v: ar, lo: 0.35, hi: 0.65, unit: 'pct' }); }
    }
    if (D.some(r => r.batteredIn > 0)) {
      const bin = sum(D.map(r => r.batteredIn)), bre = sum(D.map(r => r.breathWear));
      R.point('8.breath', '§8', 'Second breath: battered wear recovered through it, as a share of all battered wear taken (at most 25%)', { v: bre / bin, hi: 0.25, unit: 'pct', note: bre === 0 ? 'no breathWear in these records (sim before S4?)' : '' });
    } else R.pending('8.breath', '§8', 'Second breath: battered wear recovered through it is at most 25% of all battered wear taken', 'needs breathWear (S4) in the sim');
    // the damage rate that the wear constant k scales: damage to the eventual loser per minute (balance-targets §10, §12). k_new = k_old x (rate before / rate after).
    const dec = D.filter(r => !r.timeout && r.winner >= 0 && r.dmgVictim);
    if (dec.length) R.info('k.rate', '§10 k', 'Damage per minute to the loser (input to the k retune: k_new = k_old x rate before / rate after)', (sum(dec.map(r => r.dmgVictim[1 - r.winner])) / (sum(dec.map(r => r.koAt)) / 60)).toFixed(1), 'volleys and beam-clash chip count once Encounter Q4 lands, so k absorbs them; median length target 6 to 8 min, p10 at least 5:00, timeouts at most 1%');
    if (hasEvent(A, 'blitz')) {
      const mins = sum(D.map(r => r.koAt)) / 60, bl = sum(D.map(r => (r.events || []).filter(e => e.type === 'blitz').length));
      R.point('8.blitz', '§8', 'Blitzes per minute (2 to 6 in Tense and Frenzied acts; measured over the whole match until the act is in the records)', { v: bl / mins, lo: 2, hi: 6, unit: 'num', note: 'the band is for Tense and Frenzied only; a whole-match rate below 2 can still pass there' });
    } else R.pending('8.blitz', '§8', 'Blitz rate: 2 to 6 a minute in Tense and Frenzied acts', 'needs a `blitz` fx event and the act (mood) per event (Encounter Q4)');
    R.pending('8.comebacks', '§8', 'Comebacks 15 to 35% of matches; lead changes median at least 2', 'needs the brink and region stages (Wounds S1, S2)');
    R.add(hasEvent(A, 'region_broken') ? { id: '8.breaks', ref: '§8', what: 'Region breaks per match, median (game: 4 to 6)', status: 'INFO', value: String(median(D.map(r => r.events.filter(e => e.type === 'region_broken').length))), band: '4 to 6 at game scale', note: 'see the pending-tests skeleton W3' } : { id: '8.breaks', ref: '§8', what: 'Region breaks before the finisher (4 to 6), finishers preceded by a brink call-out (100%)', status: 'PENDING', value: '', band: '', note: 'needs Wounds S1 and S2 events' });
  }

  // ---- 10. tempo (measured from the event stream and the feed)
  if (D) {
    const mins = sum(D.map(r => r.koAt)) / 60;
    const ex = sum(D.map(r => melee(r) + r.beams.length));
    R.point('10.exPerMin', '§10', 'Exchanges started per minute', { v: ex / mins, lo: 8, hi: 12 });
    const lens = D.flatMap(r => r.exLens), gaps = D.flatMap(r => r.exGaps);
    R.point('10.exLen', '§10', 'Exchange length, request to release, median', { v: median(lens), lo: 2.5, hi: 4.0, unit: 's', note: 'set pieces 3 to 8 s are not separated out' });
    R.point('10.gap', '§10', 'Breathing room, release to the next request, median', { v: median(gaps), lo: 1.5, hi: 4.0, unit: 's' });
    const noLong = D.filter(r => !r.exGaps.some(g => g > 10)).length;
    R.rate('10.gap10', '§10', 'Matches with no gap over 10 s', { v: noLong / D.length, ci: wl(noLong, D.length), lo: 0.95 });
    R.point('10.launchPerMin', '§10', 'Launches per minute', { v: sum(D.map(r => total(r.launches))) / mins, lo: 4, hi: 6 });
    const fl = D.flatMap(r => r.flights);
    const haul = D[0].longHaul || 1500;                                 // 1,500 x TRAV_LAUNCH since the world scale (SC): 9,000 units = 120 fighter heights
    R.point('10.longHaul', '§10', `Launches with at least ${haul.toLocaleString('en-US')} units of horizontal travel (1,500 x the launch traversal factor)`, { v: fl.filter(f => f.travel >= haul).length / fl.length, lo: 0.30, unit: 'pct' });
    R.point('10.newBiome', '§10', 'Launches that land in a different biome', { v: fl.filter(f => f.newBiome).length / fl.length, lo: 0.25, unit: 'pct' });
    R.point('10.underwater', '§10', 'Fight time underwater (both fighters)', { v: sum(D.map(r => r.underSec)) / sum(D.map(r => total(r.fightSec))), hi: 0.10, unit: 'pct' });
    R.pending('10.rest', '§10', 'Strike spacing, wind-up width, hit-stop floors, gap-close flight', 'read from data and atoms, not from a batch: Combat and Controls own them (needs the event log of the composer)');
  }

  // ---- 11. living destruction
  const LD = 'no hazard events in the sim yet (living destruction LD1 to LD3, docs/design/living-destruction-numbers.md)';
  if (D) {
    R.point('11.bleed', '§11', 'Low-tier bleed with every living-destruction source included (same measure as §4)', { v: sum(D.map(r => r.lowCas / r.pop0)) / (sum(D.map(r => r.lowSec)) / 60) * 100, hi: scale === 'game' ? 4 : 40, unit: 'num', note: '% of population per minute' });
    for (const [id, what] of [['fires', 'Spreading fires: 0.5 to 3 in matches with 5% of fight time in forest or villages'], ['forest', 'Forest burnt at the end among tier-3 matches: 15 to 60% of trees'], ['clouds', 'Cover-capable clouds 3 to 10'], ['slides', 'Real slides 0.5 to 2; at most 1 peak collapse'], ['quakes', 'Quakes in 30 to 70% of tier-4 matches, at most 2; rifts at most 1'], ['lava', 'Lava events 1 to 3 in tier-4 matches'], ['wear', 'Hazard share of all wear at most 15%']]) R.pending(`11.${id}`, '§11', what, LD);
  }
  return R.rows;
}

module.exports = { evaluate, hasEvent, kaiRate, mirrorEffects, median, q, fmt, SCALES, PLANET };
