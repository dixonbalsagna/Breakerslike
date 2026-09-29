// Statistics helpers and batch aggregation for match records produced by match-runner.js.
// Node built-ins only. Pure functions, no randomness.

const sum = a => a.reduce((x, y) => x + y, 0);
const mean = a => (a.length ? sum(a) / a.length : NaN);
const sd = a => { if (a.length < 2) return 0; const m = mean(a); return Math.sqrt(sum(a.map(v => (v - m) ** 2)) / (a.length - 1)); };
function quantile(sorted, q) {
  if (!sorted.length) return NaN;
  const p = (sorted.length - 1) * q, i = Math.floor(p), f = p - i;
  return i + 1 < sorted.length ? sorted[i] * (1 - f) + sorted[i + 1] * f : sorted[i];
}
// Wilson score interval for a proportion k/n (z = 1.96 gives 95%).
function wilson(k, n, z = 1.96) {
  if (!n) return [NaN, NaN];
  const p = k / n, d = 1 + z * z / n, c = p + z * z / (2 * n), r = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n));
  return [(c - r) / d, (c + r) / d];
}
// Two-proportion z statistic (pooled). |z| > 1.96 is significant at 5%.
function twoPropZ(k1, n1, k2, n2) {
  const p = (k1 + k2) / (n1 + n2), se = Math.sqrt(p * (1 - p) * (1 / n1 + 1 / n2));
  return se ? (k1 / n1 - k2 / n2) / se : 0;
}
// Welch z for a difference of means (large samples).
function welchZ(a, b) {
  const se = Math.sqrt(sd(a) ** 2 / a.length + sd(b) ** 2 / b.length);
  return se ? (mean(a) - mean(b)) / se : 0;
}
function hist(vals, lo, hi, step) {
  const bins = []; for (let x = lo; x < hi; x += step) bins.push({ lo: x, hi: x + step, n: 0 });
  for (const v of vals) { const i = Math.min(bins.length - 1, Math.max(0, Math.floor((v - lo) / step))); bins[i].n++; }
  return bins;
}
const tally = (obj, k, n = 1) => { obj[k] = (obj[k] || 0) + n; };
const dist = a => { const s = a.slice().sort((x, y) => x - y); return { mean: mean(a), sd: sd(a), min: s[0], p10: quantile(s, 0.1), p25: quantile(s, 0.25), p50: quantile(s, 0.5), p75: quantile(s, 0.75), p90: quantile(s, 0.9), max: s[s.length - 1] }; };

// Aggregate a list of match records. Slot 0 is P1, slot 1 is P2.
function aggregate(recs) {
  const n = recs.length, out = { n };
  out.seeds = { first: recs[0].seed, last: recs[n - 1].seed };
  out.arm = recs[0].arm; out.names = recs[0].names;
  const slotWins = [0, 0], timeouts = recs.filter(r => r.timeout).length;
  for (const r of recs) if (r.winner >= 0) slotWins[r.winner]++;
  const decided = n - timeouts;
  out.decided = decided; out.timeouts = timeouts;
  out.slotWins = slotWins;
  out.slotRate = slotWins.map(k => ({ k, rate: decided ? k / decided : NaN, ci: wilson(k, decided) }));
  // length: sim-seconds to KO (the old tools reported KO time + 3 s tail)
  const lens = recs.map(r => r.koAt);
  out.len = dist(lens);
  out.lenHist = hist(lens, 0, 150, 10);
  out.lenWithTail = mean(recs.map(r => r.len));
  out.civPct = dist(recs.map(r => r.civPct * 100));
  out.civ90 = recs.filter(r => r.civPct >= 0.9).length / n;                 // share of matches that wipe out 90%+ of the population
  out.structs = dist(recs.map(r => r.structs));
  out.nStructs = recs[0].nStructs; out.pop0 = recs[0].pop0;
  out.craters = dist(recs.map(r => r.craters));
  // launches
  const launches = {}; for (const r of recs) for (const [k, v] of Object.entries(r.launches)) tally(launches, k, v);
  const nl = sum(Object.values(launches));
  out.launches = { total: nl, counts: launches, share: Object.fromEntries(Object.entries(launches).map(([k, v]) => [k, v / nl])) };
  // beams
  const bio = {}, variant = {}, outc = {}, bioOut = {}, bySlot = [0, 0];
  let ambBeams = 0;
  for (const r of recs) for (const b of r.beams) { tally(bio, b.bio); tally(variant, b.variant); tally(outc, b.out); tally(bioOut, b.bio + ' ' + b.out); bySlot[b.by]++; if (b.amb) ambBeams++; }
  const nb = sum(Object.values(bio));
  out.beams = { total: nb, perMatch: nb / n, bio, variant, outcome: outc, bioOut, bySlot, share: Object.fromEntries(Object.entries(bio).map(([k, v]) => [k, v / nb])) };
  // melee outcomes
  const melee = {}; for (const r of recs) for (const [k, v] of Object.entries(r.melee)) tally(melee, k, v);
  const nm = sum(Object.values(melee));
  out.melee = { total: nm, counts: melee };
  // attacks / parry / chain / hide / ambush
  const atk = { light: 0, heavy: 0, sig: 0 }; for (const r of recs) for (const k of Object.keys(atk)) atk[k] += r.attacks[k];
  const nAtk = sum(Object.values(atk));
  const parries = sum(recs.map(r => sum(r.parries)));
  const chains = recs.flatMap(r => r.chains);
  const chainLen = {}; for (const c of chains) tally(chainLen, c);
  const hides = sum(recs.map(r => sum(r.hides)));
  const ambush = sum(recs.map(r => r.ambush));
  out.attacks = { total: nAtk, ...atk, ambush, ambushPerMatch: ambush / n, ambushShare: ambush / nAtk, meleeExchanges: nm };
  out.parry = { total: parries, perMatch: parries / n, perMelee: parries / nm, bySlot: [sum(recs.map(r => r.parries[0])), sum(recs.map(r => r.parries[1]))] };
  out.chain = { total: chains.length, perMatch: chains.length / n, perMelee: chains.length / nm, meanLen: mean(chains), lenHist: chainLen, counters: sum(recs.map(r => r.counters)) };
  out.hide = {
    total: hides, perMatch: hides / n, matchesWithHide: recs.filter(r => sum(r.hides) > 0).length / n,
    found: sum(recs.map(r => r.found)), hiddenSecPerMatch: [mean(recs.map(r => r.hiddenSec[0])), mean(recs.map(r => r.hiddenSec[1]))],
    ambushPerHide: hides ? ambush / hides : NaN,
  };
  out.tiers = [0, 1].map(s => mean(recs.map(r => r.tierUps[s])));
  // stance time share for winners vs losers (decided matches only)
  const share = which => { const t = [0, 0, 0, 0]; let tot = 0; for (const r of recs) { if (r.winner < 0) continue; const s = which === 'w' ? r.winner : 1 - r.winner; r.stanceSec[s].forEach((v, i) => { t[i] += v; tot += v; }); } return t.map(v => v / tot); };
  out.stanceShare = { winners: share('w'), losers: share('l') };
  // director coverage matrix
  const matrix = {}; for (const r of recs) for (const [k, v] of Object.entries(r.atkMatrix)) tally(matrix, k, v);
  out.matrix = matrix;
  // where the fighters spend their time (both fighters, sim-seconds)
  const bs = {}; let bt = 0; for (const r of recs) for (const [k, v] of Object.entries(r.biomeSec)) { tally(bs, k, v); bt += v; }
  out.biomeTime = Object.fromEntries(Object.entries(bs).map(([k, v]) => [k, v / bt]));
  out.seam = { matchesWithCrossing: recs.filter(r => r.seamCrossings > 0).length, crossings: sum(recs.map(r => r.seamCrossings)), maxDisp: Math.max(...recs.map(r => r.maxDisp)) };
  out.nan = recs.filter(r => r.nan).length;
  return out;
}

// Share k/n pooled over matches, with a match-clustered standard error (events within a match are not independent,
// so a plain binomial interval on pooled counts is too narrow). Returns { p, se, ci }.
function clusterShare(recs, kFn, nFn) {
  let K = 0, Nn = 0; for (const r of recs) { K += kFn(r); Nn += nFn(r); }
  const p = K / Nn, m = recs.length;
  let ss = 0; for (const r of recs) ss += (kFn(r) - p * nFn(r)) ** 2;
  const se = Math.sqrt(m / (m - 1) * ss) / Nn;
  return { p, se, ci: [p - 1.96 * se, p + 1.96 * se] };
}
const pct = (v, d = 1) => (v * 100).toFixed(d) + '%';
module.exports = { sum, mean, sd, quantile, wilson, twoPropZ, welchZ, clusterShare, hist, dist, aggregate, pct, tally };
