// The web spike's core loop pieces. The sim and camera are NOT ported: they are shared/sim-ref.mjs and
// shared/camera-ref.mjs, imported unchanged (the same files Node runs in shared/test-ref.mjs).
// Order inside one 60 Hz tick: input -> scene.step() -> camera.step() -> particle spawns (presentation, own RNG).
// The renderer runs once per animation frame and only reads scene, camera and ring.
import { makeScene, stateVector } from '../../shared/sim-ref.mjs';
import { Camera, cameraVector } from '../../shared/camera-ref.mjs';
import { ParticleRing, spawnForTick, KIND_CRATER } from './particles.ts';
import { sha256F64 } from './hash.ts';
import type { SceneView, CameraView } from './types.ts';
import type { Intent } from './input.ts';

export const SCENES = ['flight', 'worst', 'sweep', 'chase', 'orbit', 'climb'];

export interface Golden {
  worst: Record<string, string>;
  flight: Record<string, string>;
  camera: Record<string, { ticks: number; hash: string; flips: number }>;
  [k: string]: unknown;
}

export async function loadGolden(): Promise<Golden> {
  const r = await fetch(new URL('../../shared/golden.json', import.meta.url));
  if (!r.ok) throw new Error('golden.json: HTTP ' + r.status);
  return r.json();
}

export class App {
  scene!: SceneView;
  cam!: CameraView;
  ring: ParticleRing = new ParticleRing();
  golden: Golden | null;
  manual: boolean = false;          // a human changed the sim (flew box a or made a crater): goldens no longer apply
  hashStatus: string = '';
  hashFails: number = 0;
  // Per-frame CPU accumulators (ms), reset by the frame loop.
  simMs: number = 0;
  partMs: number = 0;
  ticksThisFrame: number = 0;

  constructor(golden: Golden | null) { this.golden = golden; }

  load(name: string): void {
    this.scene = makeScene(name) as SceneView;
    const cam = new Camera() as CameraView;
    cam.reset(this.scene.a, this.scene.b);
    this.cam = cam;
    this.ring.reset();
    this.manual = false;
    this.hashStatus = 'no checkpoint yet';
    this.hashFails = 0;
  }

  resetFrameCounters(): void { this.simMs = 0; this.partMs = 0; this.ticksThisFrame = 0; }

  // One fixed 60 Hz tick. `intent` flies box a in flight; `crater` is the demo's C key (flight only).
  tick(intent: Intent | null, crater: boolean): void {
    const s = this.scene;
    const t0 = performance.now();
    let manualCrater: { x: number; y: number; r: number } | null = null;
    if (s.name === 'flight' && intent && intent.active && s.setInput) { s.setInput(intent.ix, intent.iy); this.manual = true; }
    if (s.name === 'flight' && crater) {
      const x = s.a.x;
      s.terrain.crater(x, 140, 50);
      manualCrater = { x, y: 0, r: 140 };
      this.manual = true;
    }
    s.step();
    this.cam.step(s.a, s.b);
    const t1 = performance.now();
    if (manualCrater) {
      manualCrater.y = (s.terrain as unknown as { groundY(x: number): number }).groundY(manualCrater.x);
      this.ring.spawn(KIND_CRATER, 0, manualCrater.x, manualCrater.y, s.tick);
    }
    spawnForTick(this.ring, s);
    const t2 = performance.now();
    this.simMs += t1 - t0;
    this.partMs += t2 - t1;
    this.ticksThisFrame++;
    this.checkpoint();
  }

  // HUD hash status: at each golden checkpoint of the current scene, hash asynchronously and compare.
  private checkpoint(): void {
    const g = this.golden, s = this.scene;
    if (!g) return;
    const tk = String(s.tick);
    const simGold = (g as Record<string, unknown>)[s.name] as Record<string, string> | undefined;
    const jobs: [string, Float64Array, string][] = [];
    if (simGold && simGold[tk]) jobs.push([`sim@${tk}`, stateVector(s), simGold[tk]]);
    const cg = g.camera[s.name];
    if (cg && cg.ticks === s.tick) jobs.push([`cam@${tk}`, cameraVector(this.cam), cg.hash]);
    if (!jobs.length) return;
    if (this.manual) { this.hashStatus = `n/a at ${tk} (human input changed the sim)`; return; }
    const scene = s;
    Promise.all(jobs.map(([label, v, want]) => sha256F64(v).then(h => [label, h === want] as [string, boolean])))
      .then(res => {
        if (this.scene !== scene) return;
        this.hashFails += res.filter(r => !r[1]).length;
        this.hashStatus = res.map(r => `${r[0]} ${r[1] ? 'PASS' : 'FAIL'}`).join(', ');
      });
  }
}

