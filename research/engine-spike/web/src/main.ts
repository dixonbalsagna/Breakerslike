// Entry point. Modes from the query string:
//   (none)                        demo; ?scene=<name> picks the start scene (default flight)
//   ?bench=1&scene=worst[&warmup=180&measure=1800]    sets window.__benchResult
//   ?test=1                       golden-hash and camera checks in the browser, sets window.__testResult
//   ?shot=1&scene=<name>&at=<tick>[&camx=<x>][&seam=0]  renders one frame at that tick, sets window.__shotResult
// Any failure sets window.__spikeError (tools/bench-browser.mjs stops on it).
import { sdx, wrap } from '../../shared/sim-ref.mjs';
import { App, loadGolden, SCENES } from './app.ts';
import type { Golden } from './app.ts';
import { Renderer } from './renderer.ts';
import { Hud } from './hud.ts';
import { Input } from './input.ts';
import { FixedStepClock } from './loop.ts';
import { runBench } from './bench.ts';

const q = new URLSearchParams(location.search);
const num = (k: string, d: number): number => { const v = q.get(k); return v === null || v === '' ? d : Number(v); };
const on = (k: string): boolean => q.get(k) === '1' || q.get(k) === 'true';
const G = window as unknown as Record<string, unknown>;

// Screenshot defaults (SPEC): flight with the seam in view (tick 2185: camera at x = 345, the seam at render x -345
// in a 2386-wide view, camera low enough to show the ocean, a crater 25 ticks old), worst at tick 1200, sweep with the
// boxes half the planet apart (tick 96: 4800 apart).
const SHOT_AT: Record<string, number> = { flight: 2185, worst: 1200, sweep: 96, chase: 120, orbit: 120, climb: 300 };

function nextFrame(): Promise<number> { return new Promise(res => requestAnimationFrame(res)); }

function sizeFixed(c: HTMLCanvasElement, w: number, h: number): void {
  c.width = w; c.height = h;
  c.style.width = w + 'px'; c.style.height = h + 'px';
}

function sizeToWindow(c: HTMLCanvasElement): void {
  const dpr = window.devicePixelRatio || 1;
  let w = window.innerWidth, h = Math.round(w * 9 / 16);
  if (h > window.innerHeight) { h = window.innerHeight; w = Math.round(h * 16 / 9); }
  c.style.width = w + 'px'; c.style.height = h + 'px';
  c.width = Math.round(w * dpr); c.height = Math.round(h * dpr);
}

async function main(): Promise<void> {
  const mode = on('test') ? 'test' : on('bench') ? 'bench' : on('shot') ? 'shot' : 'demo';
  const sceneName = q.get('scene') || (mode === 'bench' ? 'worst' : 'flight');
  if (!SCENES.includes(sceneName)) throw new Error('unknown scene ' + sceneName);
  const canvas = document.getElementById('c') as HTMLCanvasElement;
  const hudEl = document.getElementById('hud') as HTMLElement;
  const hud = new Hud(hudEl);
  document.body.dataset.mode = mode;

  let golden: Golden | null = null;
  try { golden = await loadGolden(); } catch (e) { if (mode !== 'demo') throw e; }

  if (mode === 'test') {
    hudEl.textContent = 'running reference checks in the browser...';
    (globalThis as unknown as { process?: unknown }).process ??= { argv: [] };   // read by test-ref.mjs at import
    const { runChecks } = await import('./checks.ts');
    const res = await runChecks(golden as Golden);
    const lines = (res.goldens as { label: string; pass: boolean }[]).map(l => `${l.pass ? 'PASS' : 'FAIL'} ${l.label}`);
    for (const c of res.camera as { scene: string; pass: boolean; flips: number }[]) lines.push(`${c.pass ? 'PASS' : 'FAIL'} camera ${c.scene} (flips ${c.flips})`);
    hudEl.textContent = lines.join('\n') + `\n${res.pass ? 'all checks passed' : res.failed + ' failure(s)'} in ${res.durationMs} ms`;
    G.__testResult = res;
    return;
  }

  if (mode === 'demo') sizeToWindow(canvas); else sizeFixed(canvas, num('w', 1920), num('h', 1080));
  const app = new App(golden);
  app.load(sceneName);
  const r = new Renderer(canvas, app.scene.terrain.base, mode === 'shot');

  if (mode === 'bench') {
    const res = await runBench(app, r, hud, { scene: sceneName, warmup: num('warmup', 180), measure: num('measure', 1800) });
    G.__benchResult = res;
    return;
  }

  if (mode === 'shot') {
    const at = num('at', SHOT_AT[sceneName] ?? 120);
    for (let t = 0; t < at; t++) app.tick(null, false);
    const camx = q.get('camx');
    if (camx !== null && camx !== '') app.cam.x = wrap(Number(camx));   // presentation-only override for the shot
    await nextFrame();
    r.syncHeights(app.scene.terrain);
    r.syncParticles(app.ring);
    r.draw(app.scene, app.cam, app.ring, { nowTick: app.scene.tick, showSeam: q.get('seam') !== '0', gpuTag: -1 });
    const seam = sdx(app.cam.x, 0), half = app.cam.viewW / 2;
    hud.now({ scene: sceneName, tick: app.scene.tick, live: app.ring.live, hash: 'n/a (screenshot)', mode: 'shot',
      extra: `cam x ${app.cam.x.toFixed(1)}  view ${app.cam.viewW.toFixed(0)}  seam at render x ${seam.toFixed(1)} (magenta tick)` });
    await nextFrame(); await nextFrame();
    G.__shotResult = {
      scene: sceneName, tick: app.scene.tick, camX: app.cam.x, camY: app.cam.y, viewW: app.cam.viewW,
      seamRenderX: seam, seamInView: seam > -half && seam < half,
      aRenderX: sdx(app.cam.x, app.scene.a.x), bRenderX: sdx(app.cam.x, app.scene.b.x),
      liveParticles: app.ring.live, beams: app.scene.beams.length, gpu: r.info().renderer,
      width: canvas.width, height: canvas.height,
    };
    return;
  }

  // ---- demo
  const input = new Input();
  input.attach(window);
  window.addEventListener('resize', () => sizeToWindow(canvas));
  const clock = new FixedStepClock();
  let prev = -1, showSeam = true, craterPending = false;
  const frame = (): void => {
    const now = performance.now(), dt = prev < 0 ? 0 : now - prev;
    prev = now;
    for (const code of input.drainPresses()) {
      if (/^Digit[1-6]$/.test(code)) { app.load(SCENES[Number(code.slice(5)) - 1]); clock.acc = 0; input.touched = false; }
      else if (code === 'KeyH') hud.toggle();
      else if (code === 'KeyM') showSeam = !showSeam;
      else if (code === 'KeyC') craterPending = true;
    }
    const n = clock.advance(dt);
    app.resetFrameCounters();
    for (let i = 0; i < n; i++) { app.tick(input.intent(), craterPending); craterPending = false; }
    r.syncHeights(app.scene.terrain);
    r.syncParticles(app.ring);
    r.draw(app.scene, app.cam, app.ring, { nowTick: app.scene.tick, showSeam, gpuTag: -1 });
    r.timer.poll();
    hud.frame(now, dt, { scene: app.scene.name, tick: app.scene.tick, live: app.ring.live, hash: app.hashStatus, mode: 'demo',
      extra: (r.timer.available ? `gpu ${r.timer.lastMs.toFixed(2)} ms  ` : '') +
        '1-6 scene, arrows/WASD fly (flight), C crater, H hud, M seam marker' });
    // For automated smoke runs of the demo (tools/bench-browser.mjs --wait-for __demoReady): published once the demo
    // has run past the first golden checkpoint (tick 600) in real time, with the HUD's own hash verdict.
    if (G.__demoReady === undefined && app.scene.tick >= 610) {
      G.__demoReady = { scene: app.scene.name, tick: app.scene.tick, hashStatus: app.hashStatus, hudFps: Math.round(hud.fps),
        live: app.ring.live, droppedBacklogMs: clock.droppedMs, gpu: r.info().renderer };
    }
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? (e.stack || e.message) : String(e);
  G.__spikeError = msg;
  const el = document.getElementById('hud');
  if (el) { el.style.display = ''; el.textContent = 'ERROR\n' + msg; }
  console.error(e);
});
