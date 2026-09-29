// Reference checks for the engine spike: golden hashes, camera seam tests and the sim throughput benchmark.
//   node research/engine-spike/shared/test-ref.mjs            verify against golden.json (exit 1 on any failure)
//   node research/engine-spike/shared/test-ref.mjs --update   rewrite golden.json from this reference
//   node research/engine-spike/shared/test-ref.mjs --bench    also time the sim (simbench), JSON to stdout
// Every port (GDScript, C#) runs the same checks and must print the same hashes.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { W, HALF, NC, makeScene, stateVector, baseVector, Terrain, wrap, tri, genTerrain, TERRAIN_SEED } from './sim-ref.mjs';
import { Camera, cameraVector } from './camera-ref.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const GOLDEN = join(here, 'golden.json');
const args = new Set(process.argv.slice(2));
const sha = f64 => createHash('sha256').update(Buffer.from(f64.buffer, f64.byteOffset, f64.byteLength)).digest('hex');

// ------------------------------------------------------------------ golden hashes
export const CHECKPOINTS = {
  worst: [600, 1980, 3600],
  flight: [600, 1800, 3600],
  'flight-input': [600, 1800, 3600],   // replay test: box a is flown by a scripted input stream
};
// Input stream for the replay golden: called before every step with the tick about to run.
export function scriptedInput(n) { return [tri(n, 240) * 2 - 1, tri(n + 50, 150) * 2 - 1]; }
export const CAMERA_SCENES = ['sweep', 'chase', 'orbit', 'climb', 'flight', 'worst'];
export const CAMERA_TICKS = 3600;

function goldens() {
  const out = { note: 'SHA-256 of little-endian float64 vectors; see sim-ref.mjs stateVector/baseVector and camera-ref.mjs cameraVector.' };
  out.terrainBase = sha(baseVector(new Terrain(TERRAIN_SEED)));
  for (const [name, ticks] of Object.entries(CHECKPOINTS)) {
    const input = name === 'flight-input';
    const s = makeScene(input ? 'flight' : name), rec = {};
    let t = 0;
    for (const tk of ticks) {
      while (t < tk) { if (input) { const [ix, iy] = scriptedInput(t + 1); s.setInput(ix, iy); } s.step(); t++; }
      rec[tk] = sha(stateVector(s));
    }
    out[name] = rec;
  }
  out.camera = {};
  for (const name of CAMERA_SCENES) {
    const s = makeScene(name), cam = new Camera();
    cam.reset(s.a, s.b);
    for (let i = 0; i < CAMERA_TICKS; i++) { s.step(); cam.step(s.a, s.b); }
    out.camera[name] = { ticks: CAMERA_TICKS, hash: sha(cameraVector(cam)), flips: cam.flips };
  }
  return out;
}

// ------------------------------------------------------------------ camera seam tests
// For every scripted scene: (1) both boxes stay in frame except while the camera pans through an arc flip;
// (2) no box jumps on screen by more than JUMP of the screen width in one tick; (3) shifting the whole scene by any
// offset (so the seam sits somewhere else) changes nothing on screen: the seam is invisible.
const JUMP = 0.05, OFFSETS = [0.5, 1234.5, HALF, W - 0.25, 7777.77];
function cameraTest(name, ticks = CAMERA_TICKS) {
  const s = makeScene(name), cams = [new Camera(), ...OFFSETS.map(() => new Camera())];
  const shifted = off => [{ x: wrap(s.a.x + off), y: s.a.y }, { x: wrap(s.b.x + off), y: s.b.y }];
  const feed = (fn) => { fn(cams[0], s.a, s.b); OFFSETS.forEach((off, k) => { const [a, b] = shifted(off); fn(cams[k + 1], a, b); }); };
  feed((c, a, b) => c.reset(a, b));
  let prev = null, maxJump = 0, outNormal = 0, outFlip = 0, flipTicks = 0, maxInv = 0, seamCross = 0;
  let pa = s.a.x, pb = s.b.x;
  for (let i = 0; i < ticks; i++) {
    s.step();
    if (Math.abs(s.a.x - pa) > HALF) seamCross++; if (Math.abs(s.b.x - pb) > HALF) seamCross++;
    pa = s.a.x; pb = s.b.x;
    feed((c, a, b) => c.step(a, b));
    const c = cams[0];
    const sc = [c.screenX(s.a.x), c.screenY(s.a.y), c.screenX(s.b.x), c.screenY(s.b.y)];
    const out = sc.some(v => v < 0 || v > 1);
    if (c.flipping) flipTicks++;
    if (out) { if (c.flipping) outFlip++; else outNormal++; }
    if (prev && !c.flipping) for (let k = 0; k < 4; k += 2) maxJump = Math.max(maxJump, Math.abs(sc[k] - prev[k]));
    prev = sc;
    OFFSETS.forEach((off, k) => {
      const ck = cams[k + 1], [a, b] = shifted(off);
      const sk = [ck.screenX(a.x), ck.screenY(a.y), ck.screenX(b.x), ck.screenY(b.y)];
      for (let j = 0; j < 4; j++) maxInv = Math.max(maxInv, Math.abs(sk[j] - sc[j]));
      maxInv = Math.max(maxInv, Math.abs(ck.viewW - c.viewW) / c.viewW);
      if (ck.flips !== c.flips) maxInv = Infinity;
    });
  }
  const r = { scene: name, ticks, seamCrossings: seamCross, flips: cams[0].flips, flipTicks, outOfFrameTicks: outNormal,
    outOfFrameDuringFlip: outFlip, maxScreenJump: +maxJump.toFixed(5), maxSeamOffsetDiff: maxInv };
  r.pass = outNormal === 0 && maxJump < JUMP && maxInv < 1e-6;
  return r;
}

// ------------------------------------------------------------------ sim throughput (simbench)
function simbench(reps = 5, ticks = 3600) {
  const now = () => Number(process.hrtime.bigint()) / 1e6;
  const gen = [], run = [];
  for (let r = 0; r < reps; r++) { const t0 = now(); genTerrain(TERRAIN_SEED); gen.push(now() - t0); }
  for (let r = 0; r < reps; r++) {
    const s = makeScene('worst'); const t0 = now();
    for (let i = 0; i < ticks; i++) s.step();
    run.push((now() - t0) / ticks);
  }
  const med = a => [...a].sort((x, y) => x - y)[a.length >> 1];
  return { stack: 'node ' + process.version, reps, ticks, terrainGenMs: +med(gen).toFixed(3), worstTickUs: +(med(run) * 1000).toFixed(3) };
}

// ------------------------------------------------------------------ main
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const g = goldens();
  let fail = 0;
  if (args.has('--update') || !existsSync(GOLDEN)) {
    writeFileSync(GOLDEN, JSON.stringify(g, null, 2) + '\n');
    console.log('golden.json written');
  } else {
    const want = JSON.parse(readFileSync(GOLDEN, 'utf8'));
    const cmp = (label, a, b) => { const ok = a === b; if (!ok) fail++; console.log(`${ok ? 'PASS' : 'FAIL'} ${label} ${a}${ok ? '' : ' expected ' + b}`); };
    cmp('terrainBase', g.terrainBase, want.terrainBase);
    for (const n of Object.keys(CHECKPOINTS)) for (const t of CHECKPOINTS[n]) cmp(`${n}@${t}`, g[n][t], want[n][t]);
    for (const n of CAMERA_SCENES) cmp(`camera.${n}@${CAMERA_TICKS}`, g.camera[n].hash, want.camera[n].hash);
  }
  for (const n of CAMERA_SCENES) {
    const r = cameraTest(n);
    if (!r.pass) fail++;
    console.log(`${r.pass ? 'PASS' : 'FAIL'} camera ${JSON.stringify(r)}`);
  }
  if (args.has('--bench')) console.log('SIMBENCH ' + JSON.stringify(simbench()));
  if (fail) { console.log(fail + ' failure(s)'); process.exit(1); }
  console.log('all reference checks passed');
}
