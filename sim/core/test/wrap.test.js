// Wrapped-planet math: the random streams, wrap and sdx (shortest arc across the seam at every separation), motion
// across the seam, terrain and craters across the seam, and the camera following the short way round.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRng, next, range } from '../rng.js';
import { wrap, sdx } from '../wrap.js';
import { W, HALF, COL, NC, DT } from '../constants.js';
import { createSim, newMatch } from '../sim.js';
import { groundY, crater } from '../../world/terrain.js';
import { biomeAt } from '../../world/biomes.js';
import { createCamera, camStep } from '../view/camera.js';
import { NATIVE } from '../detmath.js';

// The prototype's generator and R(), verbatim.
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

test('rng: next and range reproduce the prototype mulberry32 and R()', () => {
  for (const seed of [0, 1, 7, 4242, 2 ** 31 - 1, 2 ** 31, 2 ** 32 - 1, (4242423 & 0xffffff) | 1, (987654321 & 0xffffff) | 1]) {
    const p = mulberry32(seed), r = createRng(seed), p2 = mulberry32(seed), r2 = createRng(seed);
    for (let i = 0; i < 20000; i++) assert.ok(Object.is(p(), next(r)), `seed ${seed} draw ${i}`);
    for (let i = 0; i < 2000; i++) { const a = -300 + i, b = a + 17.25; assert.ok(Object.is(a + (b - a) * p2(), range(r2, a, b))); }
  }
});

test('wrap: always in [0, W), periodic, idempotent up to rounding', () => {
  const xs = [0, -0, 1e-13, -1e-13, -1e-300, 0.5, -0.5, W - 1e-9, W, -W, W + 0.25, 3 * W + 7, -5 * W - 7, 1e12 + 0.5, -1e12 - 0.5, HALF, -HALF];
  for (let i = -3000; i <= 3000; i++) xs.push(i * 7.3, i * 17);
  for (const x of xs) {
    const w = wrap(x);
    assert.ok(w >= 0 && w < W, `wrap(${x}) = ${w}`);
    assert.ok(Math.abs(wrap(w) - w) < 1e-9, `idempotent at ${x}`);
    if (Number.isInteger(x)) assert.ok(wrap(w) === w, `integers wrap exactly (${x})`);
  }
  for (let x = -20000; x <= 20000; x += 13) for (const k of [-3, -1, 1, 2, 5]) assert.equal(wrap(x + k * W), wrap(x), `period at ${x} + ${k}W`);
});

// Precision quirk every engine port must copy: wrap adds W before the second %, so a non-integer x that is already in
// [0, W) can come back changed in its last bits. A conditional wrap (x < 0 ? x + W : x) would give different bits and
// break parity, so ports must use exactly ((x % W) + W) % W.
test('wrap: the exact formula, including its last-bit rounding on in-range values', () => {
  assert.equal(wrap(6797.300000000001), 6797.300000000003);
  assert.equal(wrap(6797.300000000001), ((6797.300000000001 % W) + W) % W);
  for (let x = -30000; x < 30000; x += 0.37) assert.ok(Object.is(wrap(x), ((x % W) + W) % W));
});

// Brute-force shortest arc: among b - a + kW, the one with the smallest magnitude; ties at exactly HALF resolve as sdx does.
function brute(a, b) {
  let best = null;
  for (let k = -3; k <= 3; k++) { const d = b - a + k * W; if (best === null || Math.abs(d) < Math.abs(best)) best = d; }
  return best;
}

test('sdx: in [-HALF, HALF], equals the brute-force shortest arc, antisymmetric except at exactly HALF', () => {
  for (let a = 0; a < W; a += 37.5) for (let b = 0; b < W; b += 41.25) {
    const d = sdx(a, b);
    assert.ok(d >= -HALF && d <= HALF, `sdx(${a}, ${b}) = ${d}`);
    if (Math.abs(d) !== HALF) { assert.ok(d === brute(a, b), `sdx(${a}, ${b})`); assert.ok(sdx(b, a) === -d, `antisymmetry at ${a}, ${b}`); }
  }
  // Tie rule: exactly half a planet apart, sdx keeps the sign of (b - a) % W, so it is +HALF one way and -HALF the other.
  assert.equal(sdx(0, HALF), HALF); assert.equal(sdx(HALF, 0), -HALF);
  assert.equal(sdx(100, 100 + HALF), HALF); assert.equal(sdx(100 + HALF, 100), -HALF);
});

test('shortest arc across the seam at every separation', () => {
  // Integer and dyadic anchors: every integer separation d in [-HALF, HALF] must come back exactly.
  for (const a of [0, 1, 7, 8, 0.5, 0.25, W - 0.5, W - 1, W - 8, W - 0.125, HALF - 1, HALF, HALF + 0.5]) {
    for (let d = -HALF; d <= HALF; d++) {
      const b = wrap(a + d);
      const got = sdx(a, b);
      if (Math.abs(d) === HALF) { assert.equal(Math.abs(got), HALF, `a ${a} d ${d}`); continue; }
      assert.equal(got, d, `a ${a} d ${d}: sdx ${got}`);
      assert.equal(wrap(a + got), b, `a ${a} d ${d}: wrap(a + sdx) != b`);
    }
  }
  // Non-dyadic anchors: within 1e-9 (float rounding in a + d).
  for (const a of [0.1, 1 / 3, W - 0.1, W - 1 / 3, 4799.7]) for (let d = -HALF + 1; d < HALF; d += 0.7) {
    const got = sdx(a, wrap(a + d));
    assert.ok(Math.abs(got - d) < 1e-9, `a ${a} d ${d}: ${got}`);
  }
});

test('motion across the seam: every step moves exactly v*DT the short way', () => {
  for (const v of [30, -30, 430, -430, 1032, -1032, 3000, -3000]) {
    let x = v > 0 ? W - 50 : 50, crossings = 0;
    for (let i = 0; i < 20 * 60; i++) {
      const px = x; x = wrap(x + v * DT);
      assert.ok(x >= 0 && x < W);
      assert.ok(Math.abs(sdx(px, x) - v * DT) < 1e-9, `v ${v} step ${i}`);
      if (Math.abs(x - px) > HALF) crossings++;
    }
    const expect = Math.floor((Math.abs(v) * 20 + 50) / W) + (Math.abs(v) * 20 >= 50 ? 1 : 0);
    assert.ok(crossings >= 1 && Math.abs(crossings - expect) <= 1, `v ${v}: ${crossings} crossings, expected about ${expect}`);
  }
});

test('terrain is continuous across the seam, and a crater on the seam is symmetric', () => {
  const S = createSim(); newMatch(S, 1);
  let seamStep = 0, maxStep = 0;
  for (let x = W - 400; x < W + 400; x += COL) {
    const d = Math.abs(groundY(S, x + COL) - groundY(S, x));
    if (wrap(x) === W - COL) seamStep = d; else maxStep = Math.max(maxStep, d);
  }
  assert.ok(seamStep <= Math.max(2 * maxStep, 1), `seam step ${seamStep} vs ${maxStep} nearby`);
  assert.equal(groundY(S, W), groundY(S, 0)); assert.equal(groundY(S, -COL), groundY(S, W - COL));
  crater(S, 0, 120, 40, null);
  assert.ok(S.deform[0] < -30, 'crater did not dig at the seam');
  for (let k = 1; k < 20; k++) assert.equal(S.deform[k], S.deform[NC - k], `column ±${k}`);
  assert.equal(biomeAt(-1), biomeAt(W - 1)); assert.equal(biomeAt(W), biomeAt(0)); assert.equal(biomeAt(-W - 1), biomeAt(W - 1));
});

test('camera follows the short way across the seam and never jumps', () => {
  for (const [ax, bx] of [[W - 200, 150], [150, W - 200], [W - 10, 10], [4700, 4900]]) {
    const S = { m: NATIVE, fighters: [{ x: ax, y: 60, tier: 1 }, { x: bx, y: 80, tier: 1 }] };
    const cam = createCamera(); cam.x = wrap(ax + 900);
    let px = cam.x;
    for (let i = 0; i < 600; i++) {
      camStep(cam, S, DT, 1200, 700);
      assert.ok(Number.isFinite(cam.x + cam.y + cam.z) && cam.x >= 0 && cam.x < W);
      assert.ok(Math.abs(sdx(px, cam.x)) < 0.1 * HALF, 'camera jumped'); px = cam.x;
    }
    const mid = wrap(ax + sdx(ax, bx) / 2);
    assert.ok(Math.abs(sdx(cam.x, mid)) < 5, `camera ended ${sdx(cam.x, mid)} from the pair's midpoint`);
  }
});
