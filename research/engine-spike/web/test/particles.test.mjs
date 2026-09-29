// Particle ring and hashing tests for the web spike (Node, on the TypeScript sources).
//   node --test research/engine-spike/web/test/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { makeScene, stateVector, baseVector, Terrain, TERRAIN_SEED } from '../../shared/sim-ref.mjs';
import { ParticleRing, spawnForTick, SPECS, P_CAP, P_FLOATS, KIND_CRATER, KIND_BIG, KIND_SPARK } from '../src/particles.ts';
import { sha256F64 } from '../src/hash.ts';

const golden = JSON.parse(readFileSync(new URL('../../shared/golden.json', import.meta.url), 'utf8'));
const nodeSha = v => createHash('sha256').update(Buffer.from(v.buffer, v.byteOffset, v.byteLength)).digest('hex');

test('SPEC particle table: counts, lives (in ticks), velocity ranges and sizes', () => {
  assert.deepEqual(SPECS[KIND_CRATER], { count: 150, lifeTicks: 120, vx: 300, vyLo: 150, vyHi: 700, size: 6 });
  assert.deepEqual(SPECS[KIND_BIG], { count: 3000, lifeTicks: 180, vx: 900, vyLo: 200, vyHi: 1400, size: 8 });
  assert.deepEqual(SPECS[KIND_SPARK], { count: 5, lifeTicks: 48, vx: 400, vyLo: 100, vyHi: 600, size: 4 });
});

test('worst scene: analytic live count equals a brute-force count and the shader discard test; the sim hash is unchanged', () => {
  const s = makeScene('worst'), ring = new ParticleRing();
  const batches = [];                     // [t0, count, kind]
  let liveSum = 0, liveN = 0, liveMax = 0, winMax = 0;
  for (let t = 1; t <= 1980; t++) {
    s.step();
    const before = ring.seq;
    spawnForTick(ring, s);
    // Brute force from the events this tick: 150 or 3000 per crater event, 5 per beam.
    let expect = 0;
    for (const e of s.events) { const k = e.kind === 1 ? KIND_BIG : KIND_CRATER; batches.push([t, SPECS[k].count, k]); expect += SPECS[k].count; }
    for (let i = 0; i < s.beams.length; i++) { batches.push([t, 5, KIND_SPARK]); expect += 5; }
    assert.equal(ring.seq - before, expect);
    let brute = 0;
    for (const [t0, n, k] of batches) if (t - t0 < SPECS[k].lifeTicks) brute += n;
    assert.equal(ring.live, brute, `tick ${t}`);
    const w = ring.window();
    winMax = Math.max(winMax, w.count);
    if (t % 97 === 0) {
      // The vertex shader's test, on the ring's own float32 data: alive while 0 <= now - t0 < life.
      let shaderLive = 0;
      for (let q = w.start; q < ring.seq; q++) {
        const o = (q % P_CAP) * P_FLOATS, age = t - ring.f32[o + 4];
        if (age >= 0 && age < ring.f32[o + 5]) shaderLive++;
      }
      assert.equal(shaderLive, ring.live, `shader count at tick ${t}`);
    }
    if (t > 180) { liveSum += ring.live; liveN++; liveMax = Math.max(liveMax, ring.live); }
    if (t === 600 || t === 1980) assert.equal(nodeSha(stateVector(s)), golden.worst[String(t)], `sim hash at ${t}`);
  }
  assert.equal(ring.overflow, 0);
  assert.ok(winMax <= P_CAP, `draw window ${winMax} fits the ring`);
  const avg = liveSum / liveN;
  assert.ok(avg > 22000 && avg < 26000, `live average ${avg} (SPEC: about 24k)`);
  console.log(`# worst ticks 181..1980: live avg ${avg.toFixed(0)}, max ${liveMax}, largest draw window ${winMax} of ${P_CAP}`);
});

test('presentation RNG is separate from the sim RNG (same seed, same particles; the sim never sees it)', () => {
  const a = new ParticleRing(), b = new ParticleRing();
  a.spawn(KIND_BIG, 0, 100, 5, 1); b.spawn(KIND_BIG, 0, 100, 5, 1);
  assert.deepEqual(Array.from(a.f32.subarray(0, 3000 * P_FLOATS)), Array.from(b.f32.subarray(0, 3000 * P_FLOATS)));
  for (let k = 0; k < 3000; k++) {
    const vx = a.f32[k * P_FLOATS + 2], vy = a.f32[k * P_FLOATS + 3];
    assert.ok(vx >= -900 && vx <= 900 && vy >= 200 && vy <= 1400);
  }
});

test('WebCrypto hash of little-endian float64 equals node:crypto and golden.json', async () => {
  const v = baseVector(new Terrain(TERRAIN_SEED));
  assert.equal(await sha256F64(v), nodeSha(v));
  assert.equal(await sha256F64(v), golden.terrainBase);
});
