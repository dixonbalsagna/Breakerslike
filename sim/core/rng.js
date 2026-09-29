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
