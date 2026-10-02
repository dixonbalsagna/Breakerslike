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
  game: { len: { median: [360, 480], p10: 300, p90: 600 }, tier3: 0.70, tier4: 0.60, civ: [12, 30], worst: 55, civ90: 0.10, bleed: 4, structRow1: [25, 50] },
};

function evaluate(A, { scale = 'testbed', cap = 900 } = {}) {   // cap is the match cap in sim seconds
  const R = new Rows(), sc = SCALES[scale];
  const arms = Object.keys(A), D = A.default, have = (...n) => n.every(x => A[x] && A[x].length);
  const capSec = cap;

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
      R.info('4.struct.all', '§4', 'Structures lost, all rows (watch metric, not a gate; §21 band 15 to 40%)', (mean(all) * 100).toFixed(1) + '%', `rows ${[...rowKeys].sort().join(', ')}`);
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
    R.rate(`5.cap.${a}`, '§5', `No launch type above 45% (${a}): largest is ${top[0]}`, { v: top[1].p, ci: [top[1].ci[0], top[1].ci[1]], hi: 0.45, note: 'match-clustered upper bound must be at most 47% (M1b re-banding, balance-targets 18)' });
    R.add({ id: `5.cap.${a}.upper`, ref: '§5', what: `Largest launch type's clustered upper bound at most 47% (${a})`, status: top[1].ci[1] <= 0.47 ? 'PASS' : 'FAIL', value: fmt.pct(top[1].ci[1]), band: 'at most 47.0%', note: '' });
  }
  if (D) {
    const names = [...new Set(D.flatMap(r => Object.keys(r.launches)))];
    const n5 = names.filter(n => S.clusterShare(D, r => r.launches[n] || 0, r => total(r.launches)).p >= 0.05).length;
    R.point('5.floor', '§5', 'At least 4 launch types at or above 5% (default arm)', { v: n5, lo: 4, unit: 'num' });
    const isBrunt = n => /BUILDING|BRUNT/.test(n);
    const brunt = r => sum(Object.entries(r.launches).filter(([n]) => isBrunt(n)).map(([, v]) => v));
    const bs = S.clusterShare(D, brunt, r => total(r.launches));
    R.rate('5b.share', '§5b', 'Share of all planner launches that are building brunts (4 to 10%; re-based at M1b)', { v: bs.p, ci: bs.ci, lo: 0.04, hi: 0.10 });
    const perMin = recs => sum(recs.map(brunt)) / (sum(recs.map(r => r.koAt)) / 60);   // brunts per minute of match, pooled
    R.point('5b.perMin', '§5b', 'Brunts per minute (0.3 to 1.0, game-scale band; re-based at M1b)', { v: perMin(D), lo: 0.3, hi: 1.0 });
    // M1b re-banding (balance-targets 18): both placeholders run at planner care 0, so the mirror brunt rows are retired on the testbed; they return with the roster's per-fighter care
    R.info('5b.mirrors', '§5b', 'Villain and hero mirror brunt rows', 'retired', 'retired on the testbed (balance-targets 18); measured per minute: villain mirror ' + (have('mirror-villain') ? perMin(A['mirror-villain']).toFixed(2) : 'n/a') + ', hero mirror ' + (have('mirror-hero') ? perMin(A['mirror-hero']).toFixed(2) : 'n/a'));
    if (hasEvent(A, 'launch_plan')) {
      const plans = D.flatMap(r => (r.events || []).filter(e => e.type === 'launch_plan' && /BUILDING|BRUNT/.test(e.text || '')));
      const picked = plans.filter(e => /BUILDING|BRUNT/.test(e.chosen || '')).length;
      R.rate('5b.reach', '§5b', 'Launches that pick a building, out of those with a building candidate in reach (35 to 60% pooled)', { v: picked / plans.length, ci: wl(picked, plans.length), lo: 0.35, hi: 0.60, note: `${plans.length} plans with a candidate; from launch_plan events` });
    } else R.pending('5b.reach', '§5b', 'Launches that pick a building, out of those with a candidate in reach (35 to 60%)', 'needs launch_plan events');
    R.pending('5b.chains', '§5b', 'Chains among brunts, chain lengths, the per-tier casualty budget for one chain (hard test), the launcher tier cap (hard test)', 'needs brunt-chain events (World, buildings-in-depth §4b); skeleton in qa/godot/pending-tests.js');
  }

  // ---- 5c. knockback slides (ground impacts): a slide ends in a `slide` event, a slam digs an impact crater
  if (D && hasEvent(A, 'slide')) {
    // G0 triage (balance-targets 14): how launches end, per launch. Brunts (8 to 20%) are row 5b.share.
    const mixOf = (name, kFn, lo, hi, den) => { const c = S.clusterShare(D, kFn, den || (r => total(r.launches))); R.rate('5c.mix.' + name.split(' ')[0], '§5c', 'How launches end: ' + name + ' (per launch)', { v: c.p, ci: c.ci, lo, hi }); };
    if (D.every(r => r.landings)) {
      // balance-targets 19 and 20: one landing class per planner launch, by first contact: brunt (a building first), water (a skim or splash), bounce (G5), caught in the air (the follow-up reached the victim before any contact),
      // then the ground, by the first contact's kind (docs/director/landing-mix.md): a slide of any length is a slide, even one that ends against a rise; a crater at first contact is a slam; a landing at 350 or slower is a stop. Records take it from the slide state until World's `land` events (G5) name the kind directly.
      const g6 = hasEvent(A, 'journey_end'), g5 = g6 || hasEvent(A, 'bounce') || hasEvent(A, 'land') || hasEvent(A, 'left_ground') || hasEvent(A, 'tumble_end');
      const L = r => sum(Object.values(r.landings)), shortPl = r => (g5 ? (r.slideShortPl || 0) : 0);
      const slideC = r => r.landings.slide + shortPl(r), slamC = r => r.landings.slam - shortPl(r);
      const how = g5 ? 'World events name the kind' : 'the slide state at first contact';
      if (!g5) {
        mixOf(`slide (the first contact starts a slide, any length, ${how}; 40 to 60%)`, slideC, 0.40, 0.60, L);
        mixOf('slam (a crater at the first contact; 12 to 25%)', slamC, 0.12, 0.25, L);
        const gs = S.clusterShare(D, slideC, r => slideC(r) + slamC(r));
        R.rate('5c.slideOfGround', '§5c', 'Slides as a share of ground landings (slides plus slams; at least 65%)', { v: gs.p, ci: gs.ci, lo: 0.65, hi: 1 });
        mixOf('caught in the air (the follow-up before any contact; 10 to 25%)', r => r.landings.caught, 0.10, 0.25, L);
      } else {
        // balance-targets 20 (second landing ruling, 2026-10-02): a launch is classed by how its journey ends (World's journey_end); a bounce that ends in a skid, a tumble or a halt counts toward the halted class
        if (g6) {
          mixOf('halted: the journey ends skidding or tumbling to a stop, with or without bounces first (40 to 60%, the largest class)', slideC, 0.40, 0.60, L);
          mixOf('against a wall (a slope steeper than 0.8; 5 to 15%)', r => r.landings.wall || 0, 0.05, 0.15, L);
          mixOf('slam: the journey ends in a crater (8 to 18%)', slamC, 0.08, 0.18, L);
          mixOf('caught in the air (the follow-up before the journey ends; 15 to 30%)', r => r.landings.caught, 0.15, 0.30, L);
          { const gr = S.clusterShare(D, slideC, r => slideC(r) + (r.landings.wall || 0) + slamC(r)); R.rate('5c.haltOfGround', '§5c', 'Halted as a share of journeys that end on the ground (halt, wall or slam; at least 55%)', { v: gr.p, ci: gr.ci, lo: 0.55, hi: 1 }); }
          { const classes = ['halt', 'wall', 'slam', 'caught', 'water', 'brunt'], sh = k => sum(D.map(k === 'halt' ? slideC : k === 'slam' ? slamC : r => r.landings[k] || 0)) / Math.max(1, sum(D.map(L)));
            R.add({ id: '5c.largest', ref: '§5c', what: 'Halted is the largest class (balance-targets 20)', status: classes.every(k => k === 'halt' || sh(k) < sh('halt')) ? 'PASS' : 'FAIL', value: classes.map(k => `${k} ${fmt.pct(sh(k))}`).join(', '), band: 'halted largest', note: '' }); }
        } else {
        mixOf('halt: the journey ends skidding or tumbling to a stop, with or without bounces first (55 to 75%)', slideC, 0.55, 0.75, L);
        mixOf('slam: the journey ends in a crater (8 to 18%)', slamC, 0.08, 0.18, L);
        mixOf('caught in the air (the follow-up before the journey ends; 10 to 25%)', r => r.landings.caught, 0.10, 0.25, L);
        }
        { const c = S.clusterShare(D, r => r.journeys.anyBounce || 0, L); R.rate('5c.bounced', '§5c', 'Launches with at least one bounce (20 to 40%, balance-targets 23; the boundary is 40 degrees)', { v: c.p, ci: c.ci, lo: 0.20, hi: 0.40 }); }
        { const fc = k => sum(D.map(r => (r.firstContact || {})[k] || 0)); R.add({ id: '5c.firstContacts', ref: '§5c', what: 'First contacts: skids at least as common as bounces', status: fc('slide') >= fc('bounce') ? 'PASS' : 'FAIL', value: `skid or tumble ${fc('slide')}, bounce ${fc('bounce')}, slam ${fc('slam')}, stop ${fc('stop')}`, band: 'skids at least bounces', note: '' }); }
      }
      mixOf('water (skim or splash first; 2 to 10%, re-based at §21)', r => r.landings.water, 0.02, 0.10, L);
      mixOf('brunt (a building first; 4 to 10%)', r => r.landings.brunt, 0.04, 0.10, L);
      R.info('5c.other', '§5c', 'Planner launches with no contact and not caught (KO, the cap, launched again first), share of launches', fmt.pct(sum(D.map(r => r.landings.other)) / Math.max(1, sum(D.map(L)))), 'a class of its own so the classes add up to 100%');
      R.info('5c.stop', '§5c', 'Planner launches that landed at a stop (a contact under 350, no skid or tumble), share of launches', fmt.pct(sum(D.map(r => r.landings.stop || 0)) / Math.max(1, sum(D.map(L)))), 'a class of its own; not banded');
      if (D.every(r => r.landingsAll)) { const LA = r => sum(Object.values(r.landingsAll)); const t = k => sum(D.map(r => r.landingsAll[k])) / Math.max(1, sum(D.map(LA))); R.info('5c.all', '§5c', 'Landing mix over every launch event, beam and finisher launches included (not banded)', `slide ${fmt.pct(t('slide'))}, slam ${fmt.pct(t('slam'))}, caught ${fmt.pct(t('caught'))}, bounce ${fmt.pct(t('bounce'))}, water ${fmt.pct(t('water'))}, brunt ${fmt.pct(t('brunt'))}, none ${fmt.pct(t('other'))}`, ''); }
      // balance-targets 20 and docs/world/ground-contact.md section 4: `left_ground {actor, cause}` (a flight off a rim, crest, heap, cliff or ridge when the cause is not `bounce`), `bounce {actor, n, surface}` (a water skim also emits one, with surface water), `land {actor, kind}`, `tumble_end {actor, how}`; the early-recovery events (`tech_offer`, `tech`) are not fixed yet, so those names are my assumption
      const J = f => sum(D.map(r => r.journeys[f])), minutes = sum(D.map(r => r.koAt)) / 60;
      if (g6) {
        const seen = (r, causes) => causes.reduce((a, k) => a + ((r.liftsSeen || {})[k] || 0), 0), allC = ['lip', 'crest', 'heap', 'cliff', 'ridge'];
        R.point('5c.lip', '§5c', 'Flights off a crater lip a minute, seen (in the air at least 10 ticks; 0.5 to 2.5)', { v: sum(D.map(r => seen(r, ['lip']))) / minutes, lo: 0.5, hi: 2.5, unit: 'num' });
        R.point('5c.terrain', '§5c', 'Flights off any terrain a minute, seen (lips, crests, cliffs, heaps; 1.5 to 5)', { v: sum(D.map(r => seen(r, allC))) / minutes, lo: 1.5, hi: 5, unit: 'num' });
        if (J('jn') > 0) {
          R.point('5c.capped', '§5c', 'Journeys that reach the 4 s or 8-contact bound (at most 8%)', { v: J('capped') / J('jn'), hi: 0.08, unit: 'pct' });
          R.point('5c.long', '§5c', 'Journeys longer than 4,000 units (at most 20%; Camera chase rule covers them)', { v: J('long') / J('jn'), hi: 0.20, unit: 'pct' });
        }
      } else if (hasEvent(A, 'left_ground')) R.point('5c.lip', '§5c', 'Flights off a lip a minute (left_ground, cause other than bounce; 0.3 to 1.5; they rise through the match)', { v: sum(D.map(r => r.lips || 0)) / minutes, lo: 0.3, hi: 1.5, unit: 'num' });
      else R.pending('5c.lip', '§5c', 'Flights off a lip a minute (0.3 to 1.5)', 'switches on with World G5 (a `left_ground` event per flight off a rim, ridge, heap or cliff)');
      if (g6 && J('jbounced') > 0) R.point('5c.bounces', '§5c', 'Bounces per bounced journey, mean (1.2 to 2.0)', { v: J('jbounces') / J('jbounced'), lo: 1.2, hi: 2.0, unit: 'num' });
      else if (hasEvent(A, 'bounce') && J('bounced') > 0) R.point('5c.bounces', '§5c', 'Bounces per bounced launch, mean (1.3 to 2.2)', { v: J('bounces') / J('bounced'), lo: 1.3, hi: 2.2, unit: 'num' });
      else R.pending('5c.bounces', '§5c', 'Bounces per bounced launch, mean (1.3 to 2.2)', 'switches on with World G5 (a `bounce` event per bounce)');
      if (g6) {
        // balance-targets 23: journeys with a tumble that is seen (tumble_end.dur of 18 ticks or more) as a share of journeys ending stop, tumble, recover or capped; pending until World adds the field
        if (D.some(r => r.journeys.durSeen) && J('halted') > 0) R.rate('5c.tumble', '§5c', 'Halted journeys with a tumble that is seen (tumble_end of 18 ticks or more; 30 to 60%)', { v: J('tumbleSeen') / J('halted'), ci: wl(J('tumbleSeen'), J('halted')), lo: 0.30, hi: 0.60 });
        else R.pending('5c.tumble', '§5c', 'Halted journeys with a tumble that is seen (tumble_end of 18 ticks or more; 30 to 60%)', 'switches on when World adds tumble_end.dur (a roll of 18 ticks or more is seen)');
      }
      else if (hasEvent(A, 'tumble_end') && J('n') > 0) R.rate('5c.tumble', '§5c', 'Journeys that end in a tumble (a tumble_end that stops him or he recovers from; 30 to 60%)', { v: J('tumbled') / J('n'), ci: wl(J('tumbled'), J('n')), lo: 0.30, hi: 0.60 });
      else R.pending('5c.tumble', '§5c', 'Journeys that end in a tumble (30 to 60%)', 'switches on with World G5 (a `tumble_end` event with how stop, recover or air)');
      if (hasEvent(A, 'tech_offer') && hasEvent(A, 'tech')) { const o = sum(D.map(r => r.fxCounts.tech_offer || 0)), k = sum(D.map(r => r.fxCounts.tech || 0)); R.rate('5c.tech', '§5c', 'Early recoveries as a share of the chances, medium AI (20 to 40%)', { v: k / o, ci: wl(k, o), lo: 0.20, hi: 0.40 }); }
      else R.pending('5c.tech', '§5c', 'Early recoveries as a share of the chances, medium AI (20 to 40%)', 'switches on with World G5 (`tech_offer` when the chance opens, `tech` when taken)');
    } else {
      mixOf('slide (overlapping count: records without landings)', r => r.slides.length, 0.40, 0.60);
      mixOf('slam (impact crater, overlapping count)', r => r.impactCraters, 0.12, 0.25);
      mixOf('water skim or splash (overlapping count)', r => r.skims, 0.05, 0.15);
    }
    R.info('5c.detail', '§5c', 'Slides: mean length and trench width; slams per match; water skims per match', `${mean(D.flatMap(r => r.slides.map(x => x.len))).toFixed(0)} units, ${mean(D.flatMap(r => r.slides.map(x => x.w))).toFixed(1)} wide; ${mean(D.map(r => r.impactCraters)).toFixed(1)} slams; ${mean(D.map(r => r.skims)).toFixed(1)} skims`);
    R.pending('5c.budget', '§5c', 'Casualties from one slide at most 2% (tier 2 or below), 5% (tier 3), 10% (tier 4); 0 in open country; the planner declines launches over budget (hard tests)', 'needs casualties attributed per slide (a slide event with the population lost, or the predicted slide of the planner) and the predicted-vs-actual landing test from Encounter');
  } else if (D) R.pending('5c.slides', '§5c', 'Knockback slide bands', 'no slide events in this sim (World SC slide)');

  // Game Design's pitch measures (balance-targets 21): heavy blows that landed and heavy clashes won, per minute of match, both fighters pooled and per arm
  if (D && D.every(r => r.heavyLanded)) {
    for (const a of arms.filter(x => !x.endsWith('-flip'))) {
      const recs = A[a], min = sum(recs.map(r => r.koAt)) / 60;
      R.info(`10.heavy.${a}`, '§10', `Heavies landed and heavy clashes won per minute of match, both fighters (${a}; Game Design's estimates about 6 and 1.5)`, `${(sum(recs.map(r => r.heavyLanded[0] + r.heavyLanded[1])) / min).toFixed(2)} and ${(sum(recs.map(r => r.heavyClashWins[0] + r.heavyClashWins[1])) / min).toFixed(2)}`, `per fighter ${recs[0].names[0]}/${recs[0].names[1]}: ${(sum(recs.map(r => r.heavyLanded[0])) / min).toFixed(2)}/${(sum(recs.map(r => r.heavyLanded[1])) / min).toFixed(2)} landed; ${(sum(recs.map(r => r.heavyClashWins[0])) / min).toFixed(2)}/${(sum(recs.map(r => r.heavyClashWins[1])) / min).toFixed(2)} clash wins (slot order)`);
    }
  }

  // Reach (Encounter's contact slice, 2026-10-02): every damaging melee strike lands within 68 units, and a height difference beyond 68 only on sloped ground
  { const all = arms.flatMap(a => A[a]).filter(r => r.reach);
    if (all.length) {
      const n = sum(all.map(r => r.reach.n)), far = sum(all.map(r => r.reach.far)), tall = sum(all.map(r => r.reach.tall)), flat = sum(all.map(r => r.reach.tallFlat)), maxD = Math.max(...all.map(r => r.reach.maxD)), maxDy = Math.max(...all.map(r => r.reach.maxDy));
      R.add({ id: '10.reach', ref: '§10', what: 'Damaging melee strikes within 68 units of horizontal reach (hard test, 100%)', status: far === 0 ? 'PASS' : 'FAIL', value: `${far} of ${n} strikes beyond 68 units; longest ${maxD.toFixed(1)}`, band: '100% within 68', note: 'lights, heavies and guarded hits, at the damage event, every arm' });
      R.add({ id: '10.reach.height', ref: '§10', what: 'A height difference beyond 68 units only on sloped ground (hard test)', status: flat === 0 ? 'PASS' : 'FAIL', value: `${tall} strikes with more than 68 units of height difference, ${flat} of them on flat ground; largest ${maxDy.toFixed(1)}`, band: 'none on flat ground (slope at most 0.15)', note: 'the slope is read over 80 units at the victim' + (flat ? '; cases (arm:seed, tick): ' + arms.flatMap(a2 => A[a2].filter(r => (r.reachFlat || []).length).map(r => a2 + ':' + r.seed + ' tick ' + r.reachFlat[0].tick + ' attacker ' + r.reachFlat[0].attState + ' at ' + r.reachFlat[0].attY + ' over ground ' + r.reachFlat[0].attGround + ', victim ' + r.reachFlat[0].vicState + ' at ' + r.reachFlat[0].vicY + ' over ground ' + r.reachFlat[0].vicGround)).slice(0, 6).join('; ') : '') });
    } else R.pending('10.reach', '§10', 'Damaging melee strikes within 68 units of reach', 'records without the reach tally');
  }

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
    const floorOf = v => (v === 'MERIDIAN SCAR' ? 0.02 : 0.03), missing = allVariants.filter(v => (vars[v] || 0) / nb < floorOf(v));
    R.add({ id: '6.variant.floor', ref: '§6', what: 'Every beam variant at least 3% of beams (one planet; MERIDIAN SCAR at least 2%, §21)', status: missing.length ? 'FAIL' : 'PASS', value: allVariants.map(v => `${v} ${(((vars[v] || 0) / nb) * 100).toFixed(1)}%`).join(', '), band: 'at least 3.0% each (SCAR 2.0%)', note: missing.length ? 'below the floor: ' + missing.join(', ') + '. The bands are meant to hold over 20 seeded planets; QA has one planet' : '' });
    R.pending('6.planets', '§6', 'Location and variant bands over a fixed set of at least 20 seeded planets', 'the sim has one planet (W1: variable circumference / procedural planets)');
  }

  // ---- 7. stance balance (the parts measurable from AI matches)
  if (D) {
    const m = sum(D.map(melee));
    if (D.every(r => r.cues) && sum(D.map(r => r.cues.perfect_block || 0)) > 0) R.info('7.parry', '§7', 'Parries per 100 melee exchanges', 'retired', 'the parry window was replaced by the perfect block in step 3 (ADR 0008); the perfect-block rows below carry the band. Measured parries: ' + (sum(D.map(r => sum(r.parries))) / m * 100).toFixed(2));
    else R.point('7.parry', '§7', 'Parries per 100 melee exchanges', { v: sum(D.map(r => sum(r.parries))) / m * 100, lo: 5, hi: 15 });
    // control-rules 6 / moveset-rules 11: perfect blocks per 100 melee exchanges by AI level (the main run is the data's level, medium)
    if (D.every(r => r.cues)) R.point('7.pb.medium', '§7', 'Perfect blocks per 100 melee exchanges, medium AI (5 to 15)', { v: sum(D.map(r => r.cues.perfect_block || 0)) / m * 100, lo: 5, hi: 15, unit: 'num' });
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
    const sigsPer = D.map(r => r.beams.length);
    if (hasEvent(A, 'signature_ready') || hasEvent(A, 'signature_cooldown')) R.point('8.sigs', '§13', 'Signatures fired per match, median (2 to 4, median 3; the 120 s cooldown)', { v: median(sigsPer), lo: 2, hi: 4, unit: 'num' });
    else R.add({ id: '8.sigs', ref: '§13', what: 'Signatures fired per match (2 to 4, median 3)', status: 'PENDING', value: 'today ' + median(sigsPer).toFixed(1) + ' (median)', band: '2 to 4', note: 'pending Q4: the 120 s signature cooldown is not in the sim yet' });
    const cs = S.clusterShare(D, r => r.beams.filter(b => b.out === 'CLASH').length, r => r.beams.length);
    R.rate('8.clash', '§8', 'Beam clashes: share of signatures fired that end in a CLASH (30 to 60%; re-based at G0)', { v: cs.p, ci: cs.ci, lo: 0.30, hi: 0.60 });
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
  }

  // ---- mood (spec-wounds 9) and style labels (style-thresholds 7), read from the M1 events mood_band, act_change and style_label
  if (D && hasEvent(A, 'mood_band')) {
    const tot = { calm: 0, tense: 0, frenzied: 0 }, byAct = [null, 1, 2, 3, 4].map(a => (a ? { calm: 0, tense: 0, frenzied: 0 } : null)), starts = { 2: [], 3: [], 4: [] };
    let before = 0, withBrink = 0;
    for (const r of D) {
      let band = 'calm', act = 1, t0 = 0; const st = {};
      const adv = t => { const dt = t - t0; if (dt > 0) { tot[band] += dt; byAct[act][band] += dt; } t0 = Math.max(t0, t); };
      for (const e of (r.events || [])) {
        if (e.type === 'mood_band') { adv(e.t); band = e.kind; }
        else if (e.type === 'act_change') { adv(e.t); act = e.n; if (st[act] === undefined) st[act] = e.t; }
      }
      adv(r.koAt);
      for (const a of [2, 3, 4]) if (st[a] !== undefined) starts[a].push(st[a]);
      const b = (r.events || []).find(e => e.type === 'brink_enter');
      if (b) { withBrink++; if (st[4] !== undefined && st[4] < b.t) before++; }
    }
    const T = sum(Object.values(tot)), sh = (o, k) => o[k] / Math.max(1e-9, sum(Object.values(o)));
    R.point('mood.calm', '§9', 'Mood: Calm share of match time (30 to 55%)', { v: tot.calm / T, lo: 0.30, hi: 0.55, unit: 'pct' });
    R.point('mood.tense', '§9', 'Mood: Tense share of match time (35 to 60%)', { v: tot.tense / T, lo: 0.35, hi: 0.60, unit: 'pct' });
    R.point('mood.frenzied', '§9', 'Mood: Frenzied share of match time (5 to 20%)', { v: tot.frenzied / T, lo: 0.05, hi: 0.20, unit: 'pct' });
    R.point('mood.calmAct1', '§9', 'Calm share of act 1 (at least 60%)', { v: sh(byAct[1], 'calm'), lo: 0.60, unit: 'pct' });
    R.point('mood.frenziedAct4', '§9', 'Frenzied share of act 4, the climax (at least 15%)', { v: sh(byAct[4], 'frenzied'), lo: 0.15, unit: 'pct' });
    R.point('mood.act2', '§9', 'Act 2 starts at, median (1:30 to 2:30)', { v: median(starts[2]), lo: 90, hi: 150, unit: 's' });
    R.point('mood.act3', '§9', 'Act 3 starts at, median (2:30 to 4:00)', { v: median(starts[3]), lo: 150, hi: 240, unit: 's' });
    R.point('mood.act4', '§9', 'Act 4 starts at, median (4:30 to 5:45)', { v: median(starts[4]), lo: 270, hi: 345, unit: 's' });
    R.rate('mood.act4beforeBrink', '§9', 'Act 4 arrives before the first brink (at least 80% of matches with a brink)', { v: before / Math.max(1, withBrink), ci: wl(before, Math.max(1, withBrink)), lo: 0.80 });
  } else if (D) R.pending('mood', '§9', 'Mood and act rows: Calm 30 to 55%, Tense 35 to 60%, Frenzied 5 to 20%; Calm at least 60% of act 1; Frenzied at least 15% of act 4; acts 2, 3, 4 at 1:30 to 2:30, 2:30 to 4:00, 4:30 to 5:45; act 4 before the first brink in at least 80%', 'needs the M1 events mood_band and act_change in the sim');
  if (D && hasEvent(A, 'style_label')) {
    const entries = [], evsN = [], held = [], unl = [];
    for (const r of D) {
      for (const who of [0, 1]) {
        const es = (r.events || []).filter(e => e.type === 'style_label' && e.actor === who);
        entries.push(es.filter(e => e.kind).length); evsN.push(es.length);
        let cur = null, lab = 0;
        for (const e of es) { if (cur !== null) { held.push(e.t - cur); lab += e.t - cur; } cur = e.kind ? e.t : null; }
        if (cur !== null) lab += Math.max(0, r.koAt - cur);
        unl.push(1 - lab / Math.max(1, r.koAt));
      }
    }
    R.point('style.entries', '§9 style', 'Style label entries per fighter per match, median (at most 3; AI play)', { v: median(entries), hi: 3, unit: 'num' });
    R.point('style.events', '§9 style', 'Style label events per fighter per match, entries and endings, median (at most 5)', { v: median(evsN), hi: 5, unit: 'num' });
    if (held.length) R.point('style.shortest', '§9 style', 'Shortest label held (at least 12 s; a label cut off by the KO is not counted)', { v: Math.min(...held), lo: 12, unit: 's' });
    R.point('style.unlabelled', '§9 style', 'Unlabelled share of match time, mean (at most 40%)', { v: mean(unl), hi: 0.40, unit: 'pct' });
  } else if (D) R.pending('style', '§9 style', 'Style label rows: entries at most 3, events at most 5, shortest label at least 12 s, unlabelled at most 40% (AI play)', 'needs the M1 style_label event in the sim');

  // ---- 10. tempo (measured from the event stream and the feed)
  if (D) {
    const mins = sum(D.map(r => r.koAt)) / 60;
    const ex = sum(D.map(r => melee(r) + r.beams.length));
    R.point('10.exPerMin', '§10', 'Exchanges started per minute (15 to 26, widened at §22)', { v: ex / mins, lo: 15, hi: 26 });
    const lens = D.flatMap(r => r.exLens), gaps = D.flatMap(r => r.exGaps);
    R.info('10.exLen', '§10', 'Exchange length, request to release, median', 'retired', 'retired by the dynamic feel (G0 triage); the feel rows replace it. Measured: ' + median(lens).toFixed(2) + ' s');
    R.info('10.gap', '§10', 'Breathing room, release to the next request, median', 'retired', 'replaced by the feel row release to next request at most 1.0 s. Measured: ' + median(gaps).toFixed(2) + ' s');
    const noLong = D.filter(r => !r.exGaps.some(g => g > 10)).length;
    R.rate('10.gap10', '§10', 'Matches with no gap over 10 s', { v: noLong / D.length, ci: wl(noLong, D.length), lo: 0.95 });
    { const ls = S.clusterShare(D, r => total(r.launches), r => melee(r) + r.beams.length); R.rate('10.launchShare', '§10', 'Exchanges that end in a launch (40 to 65%; replaces launches per minute)', { v: ls.p, ci: ls.ci, lo: 0.40, hi: 0.65 }); }
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

// Perfect blocks per 100 melee exchanges at the easy and hard AI levels (control-rules 6: easy 3 to 8, hard 12 to 20), from default-arm records played at that level.
function levelRows(byLevel) {
  const BAND = { easy: [3, 8], hard: [12, 20] }, rows = [];
  for (const [level, recs] of Object.entries(byLevel)) {
    const m = recs.reduce((a, r) => a + Object.values(r.melee).reduce((x, y) => x + y, 0), 0), pb = recs.reduce((a, r) => a + ((r.cues || {}).perfect_block || 0), 0), [lo, hi] = BAND[level], v = m ? pb / m * 100 : NaN;
    rows.push({ id: '7.pb.' + level, ref: '§7', what: `Perfect blocks per 100 melee exchanges, ${level} AI (${lo} to ${hi})`, status: Number.isFinite(v) ? (v >= lo && v <= hi ? 'PASS' : 'FAIL') : 'PENDING', value: Number.isFinite(v) ? v.toFixed(2) : 'no data', band: `${lo} to ${hi}`, note: `${recs.length} default-arm matches at ${level}; point estimate` });
  }
  return rows;
}

module.exports = { levelRows, evaluate, hasEvent, kaiRate, mirrorEffects, median, q, fmt, SCALES, PLANET };
