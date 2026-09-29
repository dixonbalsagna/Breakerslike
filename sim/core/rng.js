// Seeded random streams: mulberry32, bit-identical to the prototype's, with the state held in a plain object {a}
// so a stream can be serialised, copied and restored. Nothing in the simulation may use Math.random.
export function createRng(seed) { return { a: seed }; }

// Next number in [0, 1). The body is the prototype's mulberry32 step with the closure variable moved into r.a.
export function next(r) {
  let a = r.a | 0;
  a = a + 0x6D2B79F5 | 0;
  r.a = a;
  let t = Math.imul(a ^ a >>> 15, 1 | a);
  t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
  return ((t ^ t >>> 14) >>> 0) / 4294967296;
}

// Uniform in [a, b): the prototype's R(a, b), with the same arithmetic.
export function range(r, a, b) { return a + (b - a) * next(r); }

// Seed of a cosmetic stream (the canonical RNG rule, overview.md section 3): fmix32(matchSeed ^ fnv1a32(id)), with
// FNV-1a over the id's UTF-16 code units and fmix32 the MurmurHash3 finaliser. Integer ops only, so every language
// derives the same seed. Ids: 'vfx.spark', 'vfx.debris', 'vfx.dust', 'vfx.splash', 'vfx.fire', 'vfx.charge',
// 'vfx.water', 'camera', 'audio'.
export function deriveSeed(seed, id) {
  let h = 0x811c9dc5;
  for (let i = 0; i < id.length; i++) { h ^= id.charCodeAt(i); h = Math.imul(h, 0x01000193); }
  let x = (seed ^ h) >>> 0;
  x ^= x >>> 16; x = Math.imul(x, 0x85ebca6b); x ^= x >>> 13; x = Math.imul(x, 0xc2b2ae35); x ^= x >>> 16;
  return x >>> 0;
}
