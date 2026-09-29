// Presentation particles: a stateless GPU ring buffer. The CPU writes each particle once, at spawn
// (position, velocity, spawn tick, life, size, colour); the vertex shader computes the ballistic motion from the age
// and discards dead particles. Nothing is ever read back or simulated per frame on the CPU.
// Live counts are tracked analytically from spawn batches: every batch of one kind has the same life, so each kind's
// batches expire in spawn order and a FIFO per kind gives the exact live count and the oldest live slot.
// Spawning uses its own seeded presentation RNG, never the sim RNG, so particles can never change the sim.
import { Rng, TPS } from '../../shared/sim-ref.mjs';

export const P_CAP = 65536;             // ring slots: more than 3 s of worst-case spawns (about 12.3k/s plus bursts)
export const P_STRIDE = 32;             // bytes per particle: x y vx vy (4 f32), t0 life size (3 f32), rgba8
export const P_FLOATS = P_STRIDE / 4;
export const PRESENTATION_SEED = 20260928;
export const GRAVITY = 900;             // u/s^2, downwards

export const KIND_CRATER = 0, KIND_BIG = 1, KIND_SPARK = 2;

export interface ParticleSpec { count: number; lifeTicks: number; vx: number; vyLo: number; vyHi: number; size: number }
// SPEC table. Life is stored in ticks (2.0 s, 3.0 s, 0.8 s at 60 Hz) so the CPU live test and the shader's discard
// test compare the same exact integers.
export const SPECS: ParticleSpec[] = [
  { count: 150, lifeTicks: Math.round(2.0 * TPS), vx: 300, vyLo: 150, vyHi: 700, size: 6 },
  { count: 3000, lifeTicks: Math.round(3.0 * TPS), vx: 900, vyLo: 200, vyHi: 1400, size: 8 },
  { count: 5, lifeTicks: Math.round(0.8 * TPS), vx: 400, vyLo: 100, vyHi: 600, size: 4 },
];

// Additive colours (two end points per kind; each particle mixes between them).
const COLOURS: number[][][] = [
  [[255, 150, 60], [255, 205, 120]],        // crater: embers and dust glow
  [[255, 235, 170], [255, 120, 40]],        // big crater: white-hot to orange
  [[150, 235, 255], [220, 250, 255]],       // spark, owner 0: cyan-white
];
const SPARK_1: number[][] = [[255, 170, 70], [255, 235, 190]];   // spark, owner 1: orange-white

interface Batch { start: number; count: number; t0: number }

class Fifo {
  items: Batch[] = [];
  head: number = 0;
  push(b: Batch): void { this.items.push(b); }
  front(): Batch | undefined { return this.head < this.items.length ? this.items[this.head] : undefined; }
  shift(): void {
    this.head++;
    if (this.head > 1024 && this.head * 2 > this.items.length) { this.items = this.items.slice(this.head); this.head = 0; }
  }
  clear(): void { this.items = []; this.head = 0; }
}

export class ParticleRing {
  buf: ArrayBuffer = new ArrayBuffer(P_CAP * P_STRIDE);
  f32: Float32Array = new Float32Array(this.buf);
  u8: Uint8Array = new Uint8Array(this.buf);
  seq: number = 0;            // particles spawned so far (monotonic); slot = seq % P_CAP
  uploaded: number = 0;       // particles [0, uploaded) are already on the GPU
  live: number = 0;
  overflow: number = 0;       // times a live particle's slot was reused (must stay 0)
  spawnedByKind: number[] = [0, 0, 0];
  rng: Rng;
  fifos: Fifo[] = [new Fifo(), new Fifo(), new Fifo()];

  constructor(seed: number = PRESENTATION_SEED) { this.rng = new Rng(seed); }

  reset(seed: number = PRESENTATION_SEED): void {
    this.rng = new Rng(seed);
    this.seq = 0; this.uploaded = 0; this.live = 0; this.overflow = 0; this.spawnedByKind = [0, 0, 0];
    for (const f of this.fifos) f.clear();
  }

  // Spawn one SPEC batch at world (x, y) on the given tick.
  spawn(kind: number, owner: number, x: number, y: number, tick: number): void {
    const sp = SPECS[kind], rng = this.rng, f = this.f32, u = this.u8;
    const cols = kind === KIND_SPARK && owner === 1 ? SPARK_1 : COLOURS[kind];
    const c0 = cols[0], c1 = cols[1];
    const start = this.seq;
    for (let k = 0; k < sp.count; k++) {
      const slot = (this.seq + k) % P_CAP, o = slot * P_FLOATS, ob = slot * P_STRIDE + 28;
      f[o] = x;
      f[o + 1] = y;
      f[o + 2] = rng.range(-sp.vx, sp.vx);
      f[o + 3] = rng.range(sp.vyLo, sp.vyHi);
      f[o + 4] = tick;
      f[o + 5] = sp.lifeTicks;
      f[o + 6] = sp.size;
      const m = rng.next();
      u[ob] = c0[0] + (c1[0] - c0[0]) * m;
      u[ob + 1] = c0[1] + (c1[1] - c0[1]) * m;
      u[ob + 2] = c0[2] + (c1[2] - c0[2]) * m;
      u[ob + 3] = 255;
    }
    this.seq += sp.count;
    this.live += sp.count;
    this.spawnedByKind[kind] += sp.count;
    this.fifos[kind].push({ start, count: sp.count, t0: tick });
  }

  // Drop batches whose age (in ticks) has reached their life. Same test as the shader: alive while now - t0 < life.
  expire(nowTick: number): void {
    for (let k = 0; k < 3; k++) {
      const q = this.fifos[k], life = SPECS[k].lifeTicks;
      for (let b = q.front(); b && nowTick - b.t0 >= life; b = q.front()) { this.live -= b.count; q.shift(); }
    }
    const w = this.window();
    if (w.count > P_CAP) this.overflow++;
  }

  // The range of spawn sequence numbers that can hold live particles: from the oldest live batch to the head.
  // The renderer draws only this window (one or two instanced draws); dead ones inside it are discarded in the shader.
  window(): { start: number; count: number } {
    let start = this.seq;
    for (const q of this.fifos) { const b = q.front(); if (b && b.start < start) start = b.start; }
    return { start, count: this.seq - start };
  }
}

// Minimal read-only view of a scene for spawning (see types.ts SceneView).
interface SpawnSource {
  tick: number;
  events: { kind: number; x: number; y: number; r: number }[];
  beams: { tx: number; ty: number; owner: number }[];
}

// Called once after every sim tick: one SPEC batch per crater event (kind 0: 150, kind 1: 3000) and 5 sparks per beam
// at its impact point. Then expire batches that died this tick. Reads the scene only.
export function spawnForTick(ring: ParticleRing, s: SpawnSource): void {
  const t = s.tick;
  for (const e of s.events) ring.spawn(e.kind === 1 ? KIND_BIG : KIND_CRATER, 0, e.x, e.y, t);
  for (const bm of s.beams) ring.spawn(KIND_SPARK, bm.owner, bm.tx, bm.ty, t);
  ring.expire(t);
}
