// Unit tests for the web spike's pure render math, run on the TypeScript sources directly (Node 24 strips types).
//   node --test research/engine-spike/web/test/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { W, HALF, NC, COL, sdx, wrap, makeScene } from '../../shared/sim-ref.mjs';
import { Camera, CAM } from '../../shared/camera-ref.mjs';
import * as M from '../src/math.ts';
import { FixedStepClock, stats, STEP_MS } from '../src/loop.ts';
import { angleBackend } from '../src/bench.ts';

const CAM_XS = [0, 0.5, 4, 7.99, 8, 1234.5, 4800, 7777.77, 9592.01, 9596, 9599.75, 9599.999];

test('grid anchoring: every vertex column reads the texel of the world column it is drawn at', () => {
  for (const camX of CAM_XS) {
    const a = M.gridAnchor(camX);
    assert.ok(Number.isInteger(a.col0) && a.col0 >= 0 && a.col0 < NC, `col0 ${a.col0}`);
    for (let i = 0; i < M.GRID_COLS; i++) {
      const worldX = M.gridColumn(a, i) * COL, renderX = M.gridX(a, i);
      assert.ok(Math.abs(sdx(camX + renderX, worldX)) < 1e-9, `camX ${camX} i ${i}: render ${renderX} vs column ${worldX}`);
    }
  }
});

test('grid anchoring: the 1100-column grid covers the widest view at the back of the terrain', () => {
  const dist = M.cameraDistance(CAM.MAX_VIEW);
  const halfBack = (dist - M.Z_BACK) * CAM.TAN_HALF_HFOV;       // z = -400 is further from the eye than z = 0
  for (const camX of CAM_XS) {
    const a = M.gridAnchor(camX);
    assert.ok(M.gridX(a, 0) <= -halfBack, `left edge ${M.gridX(a, 0)} > ${-halfBack}`);
    assert.ok(M.gridX(a, M.GRID_COLS - 1) >= halfBack, `right edge ${M.gridX(a, M.GRID_COLS - 1)} < ${halfBack}`);
  }
  assert.ok(M.GRID_COLS * COL < W, 'grid never wraps onto itself');
});

test('grid anchoring: a terrain column moves smoothly through the seam (no pop)', () => {
  // Camera crosses x = 0 in 0.25-unit steps; track the render x of the columns at world x = 0 and x = 9592.
  for (const colX of [0, 9592, 8]) {
    let prev = null;
    for (let k = 0; k <= 160; k++) {
      const camX = wrap(9580 + 0.25 * k);
      const a = M.gridAnchor(camX), i = (colX / COL - a.col0 + NC) % NC;
      assert.ok(i >= 0 && i < M.GRID_COLS, 'column in the grid');
      const rx = M.gridX(a, i);
      assert.ok(Math.abs(rx - sdx(camX, colX)) < 1e-9);
      if (prev !== null) assert.ok(Math.abs(rx - (prev - 0.25)) < 1e-9, `jump at camX ${camX}: ${prev} -> ${rx}`);
      prev = rx;
    }
  }
});

test('projection: the perspective matrix puts z = 0 points where camera-ref screenX/screenY say, in every scene', () => {
  const vp = new Float64Array(16);
  let worst = 0;
  for (const name of ['sweep', 'chase', 'orbit', 'climb', 'flight', 'worst']) {
    const s = makeScene(name), cam = new Camera();
    cam.reset(s.a, s.b);
    for (let t = 0; t < 3600; t++) {
      s.step(); cam.step(s.a, s.b);
      const dist = cam.distance(), { near, far } = M.clipPlanes(dist);
      M.viewProj(vp, cam.y, dist, near, far);
      for (const f of [s.a, s.b]) {
        const [px, py] = M.projectScreen(vp, sdx(cam.x, f.x), f.y, 0);
        worst = Math.max(worst, Math.abs(px - cam.screenX(f.x)), Math.abs(py - cam.screenY(f.y)));
      }
    }
  }
  assert.ok(worst < 1e-9, `max screen difference ${worst}`);
});

test('projection: clip planes contain the terrain slab (z -400..+120) at every view width', () => {
  for (const vw of [CAM.MIN_VIEW, 3000, CAM.MAX_VIEW]) {
    const d = M.cameraDistance(vw), { near, far } = M.clipPlanes(d);
    assert.ok(near < d - M.Z_FRONT && far > d - M.Z_BACK, `view ${vw}: near ${near} far ${far}`);
  }
});

test('particles: shader x wrap equals the short arc from the camera, and float32 keeps it within 0.01 units', () => {
  const f = Math.fround;
  let rng = 12345;
  const rnd = () => { rng = (Math.imul(rng, 1103515245) + 12345) >>> 0; return rng / 4294967296; };
  let worst32 = 0;
  for (let k = 0; k < 20000; k++) {
    const spawnX = rnd() * W, camX = rnd() * W, vx = (rnd() * 2 - 1) * 900, age = Math.floor(rnd() * 180) / 60;
    const r = M.particleRelX(spawnX, camX, vx, age);
    assert.ok(r >= -HALF && r < HALF);
    const ref = sdx(camX, wrap(spawnX + vx * age));
    if (Math.abs(Math.abs(ref) - HALF) > 1e-6) assert.ok(Math.abs(r - ref) < 1e-6, `${r} vs ${ref}`);
    // The same formula in float32, as the vertex shader evaluates it.
    let x = f(f(f(spawnX) - f(camX)) + f(f(vx) * f(age)));
    x = f(x - f(9600 * Math.floor(f(f(x + 4800) / 9600))));
    if (Math.abs(Math.abs(ref) - HALF) > 0.1) worst32 = Math.max(worst32, Math.abs(x - ref));
  }
  assert.ok(worst32 < 0.01, `float32 error ${worst32}`);
});

test('beams: a beam across the seam or the camera antipode is drawn along its own short arc, in one piece', () => {
  const cases = [[9590, 30], [30, 9590], [4790, 4810], [100, 1000], [9000, 600]];
  for (const [sx, tx] of cases) for (const camX of CAM_XS) {
    const [x0, x1] = M.beamRenderX(camX, sx, tx);
    assert.ok(Math.abs(x0 - sdx(camX, sx)) < 1e-9);
    assert.ok(Math.abs((x1 - x0) - sdx(sx, tx)) < 1e-9, `beam ${sx}->${tx} cam ${camX}: ${x0} -> ${x1}`);
  }
  assert.ok(Math.abs(M.seamRenderX(9599) - 1) < 1e-9 && Math.abs(M.seamRenderX(1) + 1) < 1e-9);
});

test('fixed step: 60 Hz from any frame rate, at most 8 steps per frame, backlog dropped', () => {
  for (const hz of [30, 60, 144, 240, 1000, 2750]) {
    const c = new FixedStepClock();
    let ticks = 0;
    for (let k = 0; k < hz * 10; k++) { const n = c.advance(1000 / hz); assert.ok(n <= 8); ticks += n; }
    assert.ok(Math.abs(ticks - 600) <= 1, `${hz} Hz: ${ticks} ticks in 10 s`);
  }
  const c = new FixedStepClock();
  assert.equal(c.advance(1000), 8);
  assert.ok(c.acc < STEP_MS && Math.abs(c.droppedMs + c.acc + 8 * STEP_MS - 1000) < 1e-9);
  assert.equal(c.advance(0), 0);
  assert.equal(c.advance(-5), 0);
});

test('stats: SPEC percentiles pN = sorted[ceil(N/100 * n) - 1]', () => {
  const s = stats(Array.from({ length: 100 }, (_, i) => 100 - i));
  assert.deepEqual([s.avg, s.p50, s.p95, s.p99, s.max, s.n], [50.5, 50, 95, 99, 100, 100]);
  const t = stats([3, 1, 2]);
  assert.deepEqual([t.p50, t.p95, t.max], [2, 3, 3]);
});

test('bench: ANGLE backend parsed from the unmasked renderer string', () => {
  assert.equal(angleBackend('ANGLE (NVIDIA, NVIDIA GeForce RTX 5070 Ti (0x00002C05) Direct3D11 vs_5_0 ps_5_0, D3D11)'), 'D3D11');
  assert.equal(angleBackend('ANGLE (AMD, AMD Radeon(TM) Graphics (0x000013C0) Direct3D11 vs_5_0 ps_5_0, D3D11)'), 'D3D11');
  assert.equal(angleBackend('ANGLE (Apple, ANGLE Metal Renderer: Apple M2, Unspecified Version)'), 'Metal');
  assert.equal(angleBackend('ANGLE (Intel, Mesa Intel(R) UHD Graphics 620 (KBL GT2), OpenGL 4.6)'), 'OpenGL');
  assert.equal(angleBackend('ANGLE (NVIDIA, Vulkan 1.3.280 (NVIDIA GeForce RTX 5070 Ti (0x00002C05)), NVIDIA)'), 'Vulkan');
  assert.equal(angleBackend('Mesa Intel(R) UHD Graphics 620'), null);
});
