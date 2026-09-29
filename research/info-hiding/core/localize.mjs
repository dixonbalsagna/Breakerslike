// Terrain-matching localiser. DOM-free.
// Given the heights a viewport shows (one sample per COL units, left to right) with the viewport's world offset
// unknown, find the world x of the first sample by wrap-aware sum of squared differences against the planet's
// reference profile (world.skyline: ground plus landmark tops, one value per column), over all NC = 1200 offsets.
//
// Two passes keep it cheap enough to run every few ticks in a bot: a coarse pass scores every one of the 1200 offsets
// with about 48 of the samples, then the best local minima are rescored with every sample. A parabola through the
// three costs around the winner gives a sub-column estimate.
import { NC, COL, wrap } from './world.mjs';

// samples: array of heights (NaN = not visible). ref: Float64Array(NC).
// opts.mask: per-sample 0/1 (0 = not visible, e.g. fog, crop or off-screen).
// opts.zeroMean: compare shapes only (the view's vertical offset is unknown too). Default false.
// opts.candidates: local minima from the coarse pass to rescore (default 16). opts.minSamples (default 12).
// Returns null when too few samples are visible, else
//   {x, col, cost, second, ratio, confident, bias, used}
//   x: world x of samples[0]; cost: mean squared error at the best offset; second: the same for the best offset more
//   than `guard` columns away; ratio = cost / second (small = unambiguous); bias: ref minus samples at the match
//   (with zeroMean, the vertical offset of the view).
export function localize(samples, ref, opts = {}) {
  const m = samples.length, n = ref.length || NC;
  const mask = opts.mask || null;
  const zeroMean = !!opts.zeroMean;
  const idx = [];
  for (let k = 0; k < m; k++) if ((!mask || mask[k]) && Number.isFinite(samples[k])) idx.push(k);
  if (idx.length < (opts.minSamples ?? 12)) return null;
  const stride = opts.stride ?? Math.max(1, Math.floor(idx.length / 48));
  const coarse = idx.filter((_, j) => j % stride === 0);

  const cost = (off, set) => {
    let bias = 0;
    if (zeroMean) {
      let ss = 0, sr = 0;
      for (const k of set) { ss += samples[k]; sr += ref[(off + k) % n]; }
      bias = (sr - ss) / set.length;
    }
    let c = 0;
    for (const k of set) { const d = samples[k] + bias - ref[(off + k) % n]; c += d * d; }
    return c / set.length;
  };

  // Pass 1: every offset.
  const cc = new Float64Array(n);
  for (let off = 0; off < n; off++) cc[off] = cost(off, coarse);
  // Local minima of the coarse costs (circular, +-2 columns), best first.
  const minima = [];
  for (let off = 0; off < n; off++) {
    const v = cc[off];
    let isMin = true;
    for (let d = -2; d <= 2 && isMin; d++) if (d && cc[(off + d + n) % n] < v) isMin = false;
    if (isMin) minima.push(off);
  }
  minima.sort((a, b) => cc[a] - cc[b] || a - b);
  const K = Math.min(opts.candidates ?? 16, minima.length);

  // Pass 2: full cost around each candidate.
  const full = new Map();
  const fc = (off) => { off = ((off % n) + n) % n; if (!full.has(off)) full.set(off, cost(off, idx)); return full.get(off); };
  let best = -1, bestC = Infinity;
  for (let j = 0; j < K; j++) {
    for (let d = -stride; d <= stride; d++) { const off = (minima[j] + d + n) % n, c = fc(off); if (c < bestC || (c === bestC && off < best)) { bestC = c; best = off; } }
  }
  const guard = opts.guard ?? 6;
  let second = Infinity;
  for (const [off, c] of full) {
    let dd = Math.abs(off - best); if (dd > n / 2) dd = n - dd;
    if (dd > guard && c < second) second = c;
  }
  // Also rescore the best coarse minima that are far from the winner, so `second` is a fair runner-up.
  for (let j = 0; j < K; j++) {
    let dd = Math.abs(minima[j] - best); if (dd > n / 2) dd = n - dd;
    if (dd > guard) { const c = fc(minima[j]); if (c < second) second = c; }
  }
  // Sub-column refinement (parabola through best-1, best, best+1).
  const cm = fc(best - 1), cp = fc(best + 1), den = cm - 2 * bestC + cp;
  let delta = den > 0 ? 0.5 * (cm - cp) / den : 0;
  if (delta > 0.5) delta = 0.5; else if (delta < -0.5) delta = -0.5;

  let bias = 0;
  if (zeroMean) { let ss = 0, sr = 0; for (const k of idx) { ss += samples[k]; sr += ref[(best + k) % n]; } bias = (sr - ss) / idx.length; }
  const ratio = second > 0 ? bestC / second : (bestC > 0 ? 1 : 0);
  return {
    x: wrap((best + delta) * COL), col: best, cost: bestC, second, ratio,
    confident: ratio < (opts.maxRatio ?? 0.35), bias, used: idx.length,
  };
}

// Convenience: match against a World's skyline.
export function localizeInWorld(samples, world, opts) { return localize(samples, world.skyline, opts); }

// Reference implementation for tests: full cost at every offset, no coarse pass. Slow (NC x samples).
export function localizeExhaustive(samples, ref, opts = {}) {
  return localize(samples, ref, { ...opts, stride: 1, candidates: NC });
}
