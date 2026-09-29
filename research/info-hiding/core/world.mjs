// Hiding testbed: the world. DOM-free.
// Terrain, biomes, wrap math and the RNG come from the engine spike reference (imported read-only), so this planet has
// the same segments as the prototype. On top of it: the cover rules, a few static landmarks so the terrain is
// recognisable, and a per-column skyline (ground plus landmark tops) that a viewport shows and a localiser can match.
import {
  W, HALF, NC, COL, TPS, DT, SEA_BASE, TERRAIN_SEED, wrap, sdx, clamp, Rng, Terrain, biomeAt, BIOME, BIOME_NAMES, SEG,
} from '../../engine-spike/shared/sim-ref.mjs';

export { W, HALF, NC, COL, TPS, DT, SEA_BASE, TERRAIN_SEED, wrap, sdx, clamp, Rng, Terrain, biomeAt, BIOME, BIOME_NAMES, SEG };

// ------------------------------------------------------------------ cover (prototype coverAt)
// ocean: submerged, y < -60 over ground below -100. forest: under the canopy, y < ground + 70. mountains: along a
// ridge, y < ground + 40. The prototype also needs a live tree within 120 units in the forest; trees here are
// indestructible and dense (16 to 40 apart), so that check always passes inside the forest and is left out.
export const COVER_RULES = Object.freeze({ oceanMaxY: -60, oceanMaxGround: -100, canopyAbove: 70, ridgeAbove: 40 });
export const COVER_KINDS = Object.freeze({ [BIOME.OCEAN]: 'submerged', [BIOME.FOREST]: 'canopy', [BIOME.MOUNTAINS]: 'ridge' });

export function coverAt(f, terrain) {
  const g = terrain.groundY(f.x), b = biomeAt(f.x);
  if (b === BIOME.OCEAN && f.y < COVER_RULES.oceanMaxY && g < COVER_RULES.oceanMaxGround) return 'submerged';
  if (b === BIOME.FOREST && f.y < g + COVER_RULES.canopyAbove) return 'canopy';
  if (b === BIOME.MOUNTAINS && f.y < g + COVER_RULES.ridgeAbove) return 'ridge';
  return null;
}

// Which cover a fighter could use at column x at a suitable height (null if none), and that height.
export function coverKindAtX(x, terrain) {
  const b = biomeAt(x);
  if (b === BIOME.OCEAN) return terrain.groundY(x) < COVER_RULES.oceanMaxGround ? 'submerged' : null;
  if (b === BIOME.FOREST) return 'canopy';
  if (b === BIOME.MOUNTAINS) return 'ridge';
  return null;
}
export function coverY(kind, x, terrain) {
  const g = terrain.groundY(x);
  if (kind === 'submerged') return Math.max(g + 25, -200);   // always below -60 where the ground is below -100
  if (kind === 'canopy') return g + 25;
  if (kind === 'ridge') return g + 12;
  return g + 200;
}

// Prototype nearestCover: biome-level scan in 100-unit steps, +x first.
export function nearestCover(x) {
  for (let off = 0; off <= 4000; off += 100) {
    for (const s of (off ? [1, -1] : [1])) {
      const b = biomeAt(x + s * off);
      if (b === BIOME.OCEAN || b === BIOME.FOREST || b === BIOME.MOUNTAINS) return { off: s * off, b };
    }
  }
  return null;
}

// ------------------------------------------------------------------ landmarks (plain shapes)
// Houses in the three villages, towers in the city, trees in the forest. Same rows as the prototype's genWorld, own RNG.
export const LANDMARK_SEED = 9001;
function genLandmarks(terrain) {
  const r = new Rng(LANDMARK_SEED), R = (a, b) => r.range(a, b), out = [];
  const row = (x0, x1, kind) => {
    let x = x0;
    while (x < x1) {
      if (kind === 'tower') {
        const w = R(30, 64), cx = x + w / 2, mid = 1 - Math.abs((cx - 3100) / 760);
        out.push({ kind, x: cx, w, h: R(120, 280) + Math.max(0, mid) * R(80, 380) });
        x += w + R(4, 16);
      } else {
        const w = R(28, 50), h = R(36, 72);
        out.push({ kind: 'house', x: x + w / 2, w, h });
        x += w + R(16, 70);
      }
    }
  };
  row(1260, 1760, 'house'); row(2370, 3830, 'tower'); row(3880, 4480, 'house'); row(7640, 7960, 'house');
  for (let x = 4530; x < 5470; x += R(16, 40)) out.push({ kind: 'tree', x, w: 24, h: R(46, 110) });
  for (const lm of out) { lm.x = wrap(lm.x); lm.gy = terrain.groundY(lm.x); lm.seed = r.next(); }
  return out;
}
// Half-width of a landmark's silhouette (house roofs overhang the walls).
function lmReach(lm) { return lm.kind === 'house' ? lm.w * 0.6 : lm.w / 2; }
export const ROOF_H = 16;
// Top of one landmark's silhouette at world x, or -Infinity where it does not cover x.
export function landmarkTop(lm, x) {
  const d = Math.abs(sdx(lm.x, x)), reach = lmReach(lm);
  if (d > reach) return -Infinity;
  if (lm.kind === 'tree') return lm.gy + lm.h * (1 - d / reach);
  if (lm.kind === 'house') return lm.gy + lm.h + ROOF_H * (1 - d / reach);
  return lm.gy + lm.h;
}

// ------------------------------------------------------------------ world
export class World {
  constructor(seed = TERRAIN_SEED) {
    this.terrain = new Terrain(seed);
    this.landmarks = genLandmarks(this.terrain);
    // Column buckets so skylineAt(x) only tests nearby landmarks.
    this.buckets = Array.from({ length: NC }, () => []);
    this.landmarks.forEach((lm, k) => {
      const reach = lmReach(lm), c0 = Math.floor(wrap(lm.x - reach) / COL), n = Math.ceil((2 * reach) / COL) + 1;
      for (let j = 0; j <= n; j++) this.buckets[(c0 + j) % NC].push(k);
    });
    // Reference silhouette per column (x = i * COL), what a viewport shows of the planet's outline.
    this.skyline = new Float64Array(NC);
    for (let i = 0; i < NC; i++) this.skyline[i] = this.skylineAt(i * COL);
  }
  groundY(x) { return this.terrain.groundY(x); }
  biomeAt(x) { return biomeAt(x); }
  seaAt(x) { return this.terrain.isSea(Math.floor(wrap(x) / COL)); }
  coverAt(f) { return coverAt(f, this.terrain); }
  coverKindAtX(x) { return coverKindAtX(x, this.terrain); }
  coverY(kind, x) { return coverY(kind, x, this.terrain); }
  // Highest point drawn at world x: the ground or a landmark on it.
  skylineAt(x) {
    x = wrap(x);
    let top = this.terrain.groundY(x);
    for (const k of this.buckets[Math.floor(x / COL) % NC]) { const t = landmarkTop(this.landmarks[k], x); if (t > top) top = t; }
    return top;
  }
  // A point inside cover near x: scans outward in COL steps (dir +1 or -1 only, or 0 for both, nearer first) for a
  // column whose neighbours within `margin` are the same kind of cover. Returns {x, y, kind, off} or null.
  coverSpot(x, { dir = 0, minOff = 0, maxOff = HALF, margin = 48, kind = null } = {}) {
    const ok = (cx) => {
      const k = this.coverKindAtX(cx);
      if (!k || (kind && k !== kind)) return null;
      for (let m = -margin; m <= margin; m += COL) if (this.coverKindAtX(cx + m) !== k) return null;
      return k;
    };
    for (let off = minOff; off <= maxOff; off += COL) {
      for (const s of (dir ? [dir] : off ? [1, -1] : [1])) {
        const cx = wrap(x + s * off), k = ok(cx);
        if (k) return { x: cx, y: this.coverY(k, cx), kind: k, off: s * off };
      }
    }
    return null;
  }
  // How far one can travel from x in direction dir (up to maxDist) while staying over cover of `kind`, keeping margin.
  coverRun(x, dir, maxDist, kind, margin = 48) {
    let d = 0;
    for (let s = COL; s <= maxDist + margin; s += COL) {
      if (this.coverKindAtX(x + dir * s) !== kind) return Math.max(0, d - margin);
      d = s;
    }
    return Math.min(maxDist, d);
  }
}

// One shared instance is enough: nothing in the testbed deforms the terrain.
let shared = null;
export function sharedWorld() { return shared || (shared = new World()); }
