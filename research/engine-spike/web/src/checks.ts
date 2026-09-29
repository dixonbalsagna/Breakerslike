// ?test=1: the reference checks of shared/test-ref.mjs, run IN THE BROWSER against the same unchanged sim-ref.mjs and
// camera-ref.mjs, hashed with WebCrypto. Passing proves the browser's JS engine produces the same float64 bits as Node.
//
// Reuse: test-ref.mjs is imported unchanged for its exported pieces (CHECKPOINTS, scriptedInput, CAMERA_SCENES,
// CAMERA_TICKS). It imports node:crypto, node:fs, node:url and node:path at top level and reads process.argv, so
// index.html maps those specifiers to dist/node-shim.js with an import map and main.ts defines a minimal
// globalThis.process before importing this module. Its goldens() and cameraTest() are not exported, so their bodies
// are mirrored below line for line (only the hash call is async here: WebCrypto has no synchronous digest).
import { W, HALF, makeScene, stateVector, baseVector, Terrain, wrap, TERRAIN_SEED } from '../../shared/sim-ref.mjs';
import { Camera, cameraVector } from '../../shared/camera-ref.mjs';
import { CHECKPOINTS, scriptedInput, CAMERA_SCENES, CAMERA_TICKS } from '../../shared/test-ref.mjs';
import { sha256F64 } from './hash.ts';
import type { Golden } from './app.ts';

interface Pos { x: number; y: number }
interface Flyable { setInput(ix: number, iy: number): void }
interface Cam {
  x: number; y: number; viewW: number; flips: number; flipping: boolean;
  reset(a: Pos, b: Pos): void; step(a: Pos, b: Pos): void; screenX(x: number): number; screenY(y: number): number;
}

// ------------------------------------------------------------------ golden hashes (mirror of goldens())
async function goldens(): Promise<Record<string, unknown>> {
  const out: Record<string, unknown> = {};
  out.terrainBase = await sha256F64(baseVector(new Terrain(TERRAIN_SEED)));
  for (const [name, ticks] of Object.entries(CHECKPOINTS as Record<string, number[]>)) {
    const input = name === 'flight-input';
    const s = makeScene(input ? 'flight' : name), rec: Record<string, string> = {};
    let t = 0;
    for (const tk of ticks) {
      while (t < tk) { if (input) { const [ix, iy] = scriptedInput(t + 1); (s as Flyable).setInput(ix, iy); } s.step(); t++; }
      rec[tk] = await sha256F64(stateVector(s));
    }
    out[name] = rec;
  }
  const cams: Record<string, { ticks: number; hash: string; flips: number }> = {};
  for (const name of CAMERA_SCENES as string[]) {
    const s = makeScene(name), cam = new Camera();
    cam.reset(s.a, s.b);
    for (let i = 0; i < CAMERA_TICKS; i++) { s.step(); cam.step(s.a, s.b); }
    cams[name] = { ticks: CAMERA_TICKS, hash: await sha256F64(cameraVector(cam)), flips: cam.flips };
  }
  out.camera = cams;
  return out;
}

// ------------------------------------------------------------------ camera seam tests (mirror of cameraTest())
const JUMP = 0.05, OFFSETS = [0.5, 1234.5, HALF, W - 0.25, 7777.77];
function cameraTest(name: string, ticks: number = CAMERA_TICKS): Record<string, unknown> {
  const s = makeScene(name), cams: Cam[] = [new Camera(), ...OFFSETS.map(() => new Camera())];
  const shifted = (off: number): Pos[] => [{ x: wrap(s.a.x + off), y: s.a.y }, { x: wrap(s.b.x + off), y: s.b.y }];
  const feed = (fn: (c: Cam, a: Pos, b: Pos) => void): void => {
    fn(cams[0], s.a, s.b); OFFSETS.forEach((off, k) => { const [a, b] = shifted(off); fn(cams[k + 1], a, b); });
  };
  feed((c, a, b) => c.reset(a, b));
  let prev: number[] | null = null, maxJump = 0, outNormal = 0, outFlip = 0, flipTicks = 0, maxInv = 0, seamCross = 0;
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
  const r: Record<string, unknown> = { scene: name, ticks, seamCrossings: seamCross, flips: cams[0].flips, flipTicks,
    outOfFrameTicks: outNormal, outOfFrameDuringFlip: outFlip, maxScreenJump: +maxJump.toFixed(5), maxSeamOffsetDiff: maxInv };
  r.pass = outNormal === 0 && maxJump < JUMP && maxInv < 1e-6;
  return r;
}

export interface CheckLine { label: string; got: string; want: string; pass: boolean }

export async function runChecks(want: Golden): Promise<Record<string, unknown>> {
  const t0 = performance.now();
  const g = await goldens();
  const lines: CheckLine[] = [];
  const cmp = (label: string, got: string, exp: string): void => { lines.push({ label, got, want: exp, pass: got === exp }); };
  const wantAny = want as unknown as Record<string, Record<string, string>>;
  cmp('terrainBase', g.terrainBase as string, want.terrainBase as string);
  for (const n of Object.keys(CHECKPOINTS as Record<string, number[]>)) {
    for (const t of (CHECKPOINTS as Record<string, number[]>)[n]) cmp(`${n}@${t}`, (g[n] as Record<string, string>)[t], wantAny[n][t]);
  }
  const gc = g.camera as Record<string, { hash: string }>;
  for (const n of CAMERA_SCENES as string[]) cmp(`camera.${n}@${CAMERA_TICKS}`, gc[n].hash, want.camera[n].hash);
  const camera = (CAMERA_SCENES as string[]).map(n => cameraTest(n));
  const failed = lines.filter(l => !l.pass).length + camera.filter(c => !c.pass).length;
  return {
    pass: failed === 0,
    failed,
    total: lines.length + camera.length,
    goldens: lines,
    camera,
    userAgent: navigator.userAgent,
    durationMs: Math.round(performance.now() - t0),
  };
}
