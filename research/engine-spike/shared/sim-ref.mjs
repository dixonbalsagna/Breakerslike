// Engine spike reference simulation. Throwaway spike code: nothing outside research/ may import it.
// Scope (EP ruling): terrain, wrap math and fighter motion, plus the craters and beam schedule the spike scenes need.
// The game's real sim core is Simulation & Engine's port under sim/; this file does not replace or mirror it.
//
// Portability contract. Every port (GDScript, C#) must reproduce this file bit for bit:
//  - All real numbers are IEEE-754 float64. Only + - * / Math.sqrt Math.floor Math.ceil, comparisons,
//    and % (fmod) are used. No Math.sin/cos/pow/exp/log: libm results differ between platforms.
//  - Evaluate every expression in the order written. Never reassociate, fuse (FMA) or constant-fold differently.
//  - Integer ops are 32-bit (mulberry32). Column indices are non-negative ints.
//  - Where JS mixes ints and floats, a port must convert to float64 before dividing (GDScript int/int truncates).

export const W = 9600, COL = 8, NC = 1200, HALF = 4800, TPS = 60, DT = 1 / 60;
export const TERRAIN_SEED = 4242;

// ------------------------------------------------------------------ wrap math (same formulas as the prototype)
export function wrap(x) { return ((x % W) + W) % W; }
export function sdx(a, b) { let d = (b - a) % W; if (d > HALF) d -= W; else if (d < -HALF) d += W; return d; }
export function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
// Triangle wave in [0, 1] over an integer tick count: 0 at n = 0, 1 at n = period/2.
export function tri(n, period) { const p = (n % period) / period; return p < 0.5 ? 2 * p : 2 - 2 * p; }

// ------------------------------------------------------------------ RNG: mulberry32, bit-identical to prototype/index.html
// GDScript has no 32-bit multiply; build imul from 16-bit halves: ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF
export class Rng {
  constructor(seed) { this.a = seed | 0; }
  u32() {
    const a = this.a = (this.a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return (t ^ (t >>> 14)) >>> 0;
  }
  next() { return this.u32() / 4294967296; }
  range(lo, hi) { return lo + (hi - lo) * this.next(); }
  state() { return this.a >>> 0; }
}

// ------------------------------------------------------------------ terrain
export const BIOME = { OCEAN: 0, PLAINS: 1, CITY: 2, VILLAGE: 3, FOREST: 4, DESERT: 5, MOUNTAINS: 6 };
export const BIOME_NAMES = ['ocean', 'plains', 'city', 'village', 'forest', 'desert', 'mountains'];
// Same segments as the prototype: [start x, end x, biome].
export const SEG = [[0, 1200, 0], [1200, 1800, 3], [1800, 2350, 1], [2350, 3850, 2], [3850, 4500, 3], [4500, 5500, 4],
  [5500, 6500, 5], [6500, 7600, 6], [7600, 8000, 3], [8000, 8300, 1], [8300, 9600, 0]];
export function biomeAt(x) { x = wrap(x); for (const s of SEG) if (x >= s[0] && x < s[1]) return s[2]; return BIOME.PLAINS; }

function lattice(rng, cells) { const v = new Float64Array(cells); for (let k = 0; k < cells; k++) v[k] = rng.next() * 2 - 1; return v; }
// Value noise over column index i (an int) with `per` columns per lattice cell. The lattice wraps (NC % per === 0).
function vnoise(v, i, per) {
  const c = i / per, k = Math.floor(c), f = c - k, s = f * f * (3 - 2 * f);
  const a = v[k % v.length], b = v[(k + 1) % v.length];
  return a + (b - a) * s;
}

export function genTerrain(seed) {
  const rng = new Rng(seed);
  const n1 = lattice(rng, 12), n2 = lattice(rng, 48), n3 = lattice(rng, 150), m1 = lattice(rng, 24);
  const t = new Float64Array(NC);
  for (let i = 0; i < NC; i++) {
    const x = i * COL, b = biomeAt(x);
    const n = 0.5 * vnoise(n1, i, 100) + 0.3 * vnoise(n2, i, 25) + 0.2 * vnoise(n3, i, 8);
    let h = 0;
    if (b === BIOME.OCEAN) h = -340 + n * 35;
    else if (b === BIOME.MOUNTAINS) {
      const k = clamp((x - 6500) / 1100, 0, 1), env = 4 * k * (1 - k);
      let r = vnoise(m1, i, 50); if (r < 0) r = -r;
      h = env * (330 + 560 * r * (0.55 + 0.45 * vnoise(n3, i, 8)));
    }
    else if (b === BIOME.DESERT) h = n * 28;
    else if (b === BIOME.PLAINS) h = n * 16;
    else if (b === BIOME.FOREST) h = 10 + n * 22;
    t[i] = h;
  }
  // Four passes of a 25-column box blur, as in the prototype. Sum k = -12..12 in that order, then divide.
  let a = t, bf = new Float64Array(NC);
  for (let p = 0; p < 4; p++) {
    for (let i = 0; i < NC; i++) { let s = 0; for (let k = -12; k <= 12; k++) s += a[(i + k + NC) % NC]; bf[i] = s / 25; }
    const tmp = a; a = bf; bf = tmp;
  }
  return a;
}

export const DEFORM_MIN = -260, SEA_BASE = -30;

export class Terrain {
  constructor(seed = TERRAIN_SEED) {
    this.base = genTerrain(seed);
    this.deform = new Float64Array(NC);
    this.version = 0;              // bumped on every change; renderers re-upload heights when it moves
  }
  height(i) { return this.base[i] + this.deform[i]; }
  isSea(i) { return this.base[i] < SEA_BASE; }
  groundY(x) {
    const c = wrap(x) / COL, i = Math.floor(c), f = c - i, j = (i + 1) % NC;
    const a = this.base[i] + this.deform[i], b = this.base[j] + this.deform[j];
    return a + (b - a) * f;
  }
  // Bowl crater with a (1 - u^2)^2 falloff, clamped so the planet never goes below DEFORM_MIN of deformation.
  crater(x, r, depth) {
    const c0 = Math.floor(wrap(x) / COL), n = Math.ceil(r / COL);
    for (let k = -n; k <= n; k++) {
      const i = (c0 + k + NC) % NC;
      let u = (k < 0 ? -k : k) * COL / r; if (u > 1) u = 1;
      const f = 1 - u * u;
      const v = this.deform[i] - depth * f * f;
      this.deform[i] = v < DEFORM_MIN ? DEFORM_MIN : v;
    }
    this.version++;
  }
}

// ------------------------------------------------------------------ fighters (kinematic boxes)
export class Fighter {
  constructor(x, y) { this.x = x; this.y = y; this.vx = 0; this.vy = 0; this.tvx = 0; this.tvy = 0; }
}

// ------------------------------------------------------------------ scenes
// Every scene exposes: tick, terrain, a, b, beams (array of {sx, sy, tx, ty, owner}), events (this tick only:
// {kind: 0 crater | 1 big crater, x, y, r}), step(), and the optional input hook setInput(ix, iy) for fighter a.

export const NBEAMS = 6;

// Worst case for the benchmark: six beams that never stop, 60 craters a second, a power-up crater every two seconds.
// The pair's centre flies east at 600 u/s (it crosses the seam every 16 s) while their separation swings 300..4600.
export class WorstScene {
  constructor(seed = 7) {
    this.name = 'worst';
    this.terrain = new Terrain();
    this.rng = new Rng(seed);
    this.tick = 0;
    this.a = new Fighter(0, 0); this.b = new Fighter(0, 0);
    this.beams = [];
    for (let i = 0; i < NBEAMS; i++) this.beams.push({ sx: 0, sy: 0, tx: 0, ty: 0, owner: i < 3 ? 0 : 1 });
    this.events = [];
    this.place(0);
    this.aimBeams(0);
  }
  place(n) {
    const c = wrap(2400 + 10 * n);
    const sep = 300 + 4300 * tri(n, 600);
    this.a.x = wrap(c - sep / 2); this.b.x = wrap(c + sep / 2);
    this.a.y = 150 + 750 * tri(n, 420); this.b.y = 150 + 750 * tri(n + 210, 420);
  }
  aimBeams(n) {
    for (let i = 0; i < NBEAMS; i++) {
      const src = i < 3 ? this.a : this.b, dir = i < 3 ? 1 : -1, bm = this.beams[i];
      bm.sx = src.x; bm.sy = src.y + 40;
      bm.tx = wrap(src.x + dir * (250 + 900 * tri(n + 37 * i, 180 + 30 * i)));
      bm.ty = this.terrain.groundY(bm.tx);
    }
  }
  step() {
    const n = ++this.tick;
    this.events.length = 0;
    this.place(n);
    this.aimBeams(n);
    for (let i = 0; i < NBEAMS; i++) {
      if (n % 6 !== i) continue;
      const bm = this.beams[i];
      const r = this.rng.range(40, 120), depth = this.rng.range(10, 30);
      this.terrain.crater(bm.tx, r, depth);
      bm.ty = this.terrain.groundY(bm.tx);
      this.events.push({ kind: 0, x: bm.tx, y: bm.ty, r });
    }
    if (n % 120 === 60) {
      const f = Math.floor(n / 120) % 2 === 0 ? this.a : this.b;
      this.terrain.crater(f.x, 300, 80);
      this.events.push({ kind: 1, x: f.x, y: this.terrain.groundY(f.x), r: 300 });
    }
  }
}

// Free flight for the demo: two boxes steer toward random velocities (seeded), cross the seam often, and a crater
// lands under one of them every half second. setInput() lets a human fly box a (deterministic per tick).
export class FlightScene {
  constructor(seed = 11) {
    this.name = 'flight';
    this.terrain = new Terrain();
    this.rng = new Rng(seed);
    this.tick = 0;
    this.a = new Fighter(9300, 400); this.b = new Fighter(250, 500);
    this.beams = [];
    this.events = [];
    this.ix = 0; this.iy = 0; this.human = false;
  }
  setInput(ix, iy) { this.human = true; this.ix = clamp(ix, -1, 1); this.iy = clamp(iy, -1, 1); }
  steer(f, idx, n) {
    if (n % 90 === idx * 45) { f.tvx = this.rng.range(-1800, 1800); f.tvy = this.rng.range(-300, 300); }
    if (idx === 0 && this.human) { f.tvx = this.ix * 1800; f.tvy = this.iy * 600; }
    f.vx = f.vx + (f.tvx - f.vx) * 0.05;
    f.vy = f.vy + (f.tvy - f.vy) * 0.05;
    f.x = wrap(f.x + f.vx * DT);
    let y = f.y + f.vy * DT;
    const g = this.terrain.groundY(f.x) + 30;
    if (y < g) { y = g; if (f.vy < 0) f.vy = 0; }
    if (y > 2400) { y = 2400; if (f.vy > 0) f.vy = 0; }
    f.y = y;
  }
  step() {
    const n = ++this.tick;
    this.events.length = 0;
    this.steer(this.a, 0, n);
    this.steer(this.b, 1, n);
    if (n % 30 === 0) {
      const f = this.rng.next() < 0.5 ? this.a : this.b;
      const r = this.rng.range(60, 160), depth = this.rng.range(20, 60);
      this.terrain.crater(f.x, r, depth);
      this.events.push({ kind: 0, x: f.x, y: this.terrain.groundY(f.x), r });
    }
  }
}

// Scripted paths for the seam and camera tests. Positions are closed-form in the tick count (no accumulated error).
//   sweep: boxes fly apart in opposite directions at 1500 u/s from x = 9000; separation runs 0..4800, the short
//          arc flips, and both cross the seam repeatedly.
//   chase: same direction across the seam at 1200 and 1320 u/s.
//   orbit: centre drifts east at 300 u/s; separation swings 4500..5100, so it hovers around half the planet.
//   climb: separation 100..4700 while the height difference swings 0..2000 (vertical framing).
export class ScriptScene {
  constructor(kind) {
    this.name = kind;
    this.kind = kind;
    this.terrain = new Terrain();
    this.tick = 0;
    this.a = new Fighter(0, 0); this.b = new Fighter(0, 0);
    this.beams = [];
    this.events = [];
    this.place(0);
  }
  place(n) {
    const a = this.a, b = this.b;
    if (this.kind === 'sweep') { a.x = wrap(9000 + 25 * n); b.x = wrap(9000 - 25 * n); a.y = 300; b.y = 500; }
    else if (this.kind === 'chase') { a.x = wrap(9100 + 20 * n); b.x = wrap(9300 + 22 * n); a.y = 400; b.y = 450; }
    else if (this.kind === 'orbit') {
      const c = wrap(9000 + 5 * n), s = 4500 + 600 * tri(n, 240);
      a.x = wrap(c - s / 2); b.x = wrap(c + s / 2); a.y = 300; b.y = 350;
    }
    else if (this.kind === 'climb') {
      const c = wrap(9400 + 8 * n), s = 100 + 4600 * tri(n, 900);
      a.x = wrap(c - s / 2); b.x = wrap(c + s / 2); a.y = 100; b.y = 100 + 2000 * tri(n, 300);
    }
    else throw new Error('unknown script ' + this.kind);
  }
  step() { const n = ++this.tick; this.events.length = 0; this.place(n); }
}

export function makeScene(name, seed) {
  if (name === 'worst') return new WorstScene(seed === undefined ? 7 : seed);
  if (name === 'flight') return new FlightScene(seed === undefined ? 11 : seed);
  return new ScriptScene(name);
}

// ------------------------------------------------------------------ state hash input
// The bytes hashed are the little-endian float64 values of this array, in this order.
// SHA-256 of those bytes, as lowercase hex, is the golden value.
export function stateVector(scene) {
  const t = scene.terrain, v = new Float64Array(NC + 10);
  v.set(t.deform, 0);
  const a = scene.a, b = scene.b;
  v[NC] = a.x; v[NC + 1] = a.y; v[NC + 2] = a.vx; v[NC + 3] = a.vy;
  v[NC + 4] = b.x; v[NC + 5] = b.y; v[NC + 6] = b.vx; v[NC + 7] = b.vy;
  v[NC + 8] = scene.rng ? scene.rng.state() : 0;
  v[NC + 9] = scene.tick;
  return v;
}
export function baseVector(terrain) { return Float64Array.from(terrain.base); }
