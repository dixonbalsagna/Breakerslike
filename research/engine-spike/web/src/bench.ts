// Bench mode (?bench=1&scene=worst[&warmup=180&measure=1800]). SPEC protocol:
//  - the sim runs in real time through the fixed-step accumulator; rendering is uncapped (the browser is launched with
//    vsync and the frame-rate limit disabled; the page cannot turn them off itself);
//  - frames whose sim tick (after that frame's steps) is <= warmup are warm-up;
//  - every frame whose tick is in (warmup, warmup + measure] is measured; its frame time is the interval from its own
//    start to the start of the next frame (consecutive frame starts);
//  - the sim never steps past warmup + measure; there the state is hashed and compared with golden.worst[tick].
//    A short smoke measure ends on a tick with no golden, so the sim alone (no render, no camera, no particles) is
//    stepped on to the next golden checkpoint (600, 1980 or 3600) and hashed there. simTickFinal says which.
// Sets window.__benchResult (SPEC schema plus frameTimesMs, gpu, driver and a few extras).
import { stateVector } from '../../shared/sim-ref.mjs';
import { FixedStepClock, stats, round } from './loop.ts';
import { sha256F64 } from './hash.ts';
import type { App } from './app.ts';
import type { Renderer } from './renderer.ts';
import { MAX_INFLIGHT } from './gl.ts';
import type { Hud } from './hud.ts';

export interface BenchParams { scene: string; warmup: number; measure: number }

const r3 = (v: number): number => round(v, 4);
function sub(samples: number[]): { avg: number; p95: number } {
  const s = stats(samples);
  return { avg: r3(s.avg), p95: r3(s.p95) };
}

// ANGLE's renderer string names its backend, e.g. "ANGLE (NVIDIA, NVIDIA GeForce RTX ... Direct3D11 vs_5_0 ps_5_0, D3D11)"
// or "ANGLE (Intel, Mesa Intel(R) UHD Graphics 620 (KBL GT2), OpenGL 4.6)". Not ANGLE (e.g. Firefox) -> null.
export function angleBackend(renderer: string): string | null {
  if (!/^ANGLE \(/.test(renderer || '')) return null;
  const m = /,\s*(D3D11on12|D3D11|D3D9|Vulkan|OpenGL ES|OpenGL|Metal|SwiftShader)[^,()]*\)\s*$/.exec(renderer);
  if (m) return m[1];
  for (const k of ['Metal', 'Vulkan', 'SwiftShader', 'D3D11', 'OpenGL']) if (renderer.includes(k)) return k;
  return 'unknown';
}

function nextFrame(): Promise<number> { return new Promise(res => requestAnimationFrame(res)); }

export function runBench(app: App, r: Renderer, hud: Hud, p: BenchParams): Promise<Record<string, unknown>> {
  const end = p.warmup + p.measure;
  app.load(p.scene);
  const clock = new FixedStepClock();
  const frameTimes: number[] = [], simMs: number[] = [], partMs: number[] = [], uploadMs: number[] = [];
  const uploadEach: number[] = [], live: number[] = [], drawn: number[] = [];
  // Per measured frame, index-aligned with frameTimes: CPU ms of the whole rAF callback, of r.draw() (GL command
  // submission) and of hud.frame().
  const workMs: number[] = [], drawMs: number[] = [], hudMs: number[] = [];
  let prevStart = -1, prevMeasured = false, maxSteps = 0;
  let sumSim = 0, sumPart = 0, sumUp = 0, ticksMeasured = 0;
  const info = r.info();

  return new Promise((resolve) => {
    const frame = (): void => {
      const now = performance.now();
      if (prevMeasured) frameTimes.push(now - prevStart);
      if (app.scene.tick >= end) { finish(); return; }
      const dt = prevStart < 0 ? 0 : now - prevStart;
      prevStart = now;
      let n = clock.advance(dt);
      if (app.scene.tick + n > end) n = end - app.scene.tick;
      if (n > maxSteps) maxSteps = n;
      app.resetFrameCounters();
      for (let i = 0; i < n; i++) app.tick(null, false);
      const measured = app.scene.tick > p.warmup;
      const up = r.syncHeights(app.scene.terrain);
      const t0 = performance.now();
      r.syncParticles(app.ring);
      const t1 = performance.now();
      const pu = t1 - t0;
      // This frame's interval will be frameTimes[frameTimes.length] (pushed at the next frame's start).
      r.draw(app.scene, app.cam, app.ring, { nowTick: app.scene.tick, showSeam: false, gpuTag: measured ? frameTimes.length : -1 });
      const t2 = performance.now();
      r.timer.poll();
      if (measured) {
        const upMs = up > 0 ? up : 0;
        if (app.ticksThisFrame > 0) { simMs.push(app.simMs); partMs.push(app.partMs + pu); uploadMs.push(upMs); }
        sumSim += app.simMs; sumPart += app.partMs + pu; sumUp += upMs; ticksMeasured += app.ticksThisFrame;
        if (up >= 0) uploadEach.push(up);
        live.push(app.ring.live);
        drawn.push(r.drawnParticles);
      }
      prevMeasured = measured;
      const t3 = performance.now();
      hud.frame(now, dt, { scene: app.scene.name, tick: app.scene.tick, live: app.ring.live, hash: 'pending', mode: 'bench' });
      const t4 = performance.now();
      if (measured) { drawMs.push(t2 - t1); hudMs.push(t4 - t3); workMs.push(t4 - now); }
      requestAnimationFrame(frame);
    };

    const finish = async (): Promise<void> => {
      const tickEnd = app.scene.tick;
      // Collect late GPU timer results (they arrive a few frames after the draw).
      const lateUntil = performance.now() + 2000;
      while (r.timer.inflight.length && performance.now() < lateUntil) { await nextFrame(); r.timer.poll(); }
      const gold = (app.golden ? (app.golden as Record<string, unknown>)[p.scene] : null) as Record<string, string> | null;
      let hashTick = tickEnd;
      if (gold && !gold[String(tickEnd)]) {
        const cps = Object.keys(gold).map(Number).filter(t => t >= tickEnd).sort((a, b) => a - b);
        if (cps.length) hashTick = cps[0];
      }
      while (app.scene.tick < hashTick) app.scene.step();          // sim only; nothing is drawn
      const simHash = await sha256F64(stateVector(app.scene));
      const goldenHash = gold && gold[String(hashTick)] ? gold[String(hashTick)] : '';
      const fs = stats(frameTimes);
      let elapsed = 0;
      for (const v of frameTimes) elapsed += v;
      // GPU samples of measured frames (tag = frame index), and the per-frame GPU ms where one was taken (else null).
      const gpuSamples: number[] = [], gpuByFrame: (number | null)[] = new Array(frameTimes.length).fill(null);
      r.timer.samples.forEach((v, i) => {
        const tag = r.timer.sampleTags[i];
        if (tag >= 0 && tag < frameTimes.length) { gpuSamples.push(v); gpuByFrame[tag] = v; }
      });
      // Long-frame breakdown: frames longer than 3x the median against the rest. For each group: the mean frame
      // interval, the mean CPU time of the page's own rAF callback (and of r.draw and hud.frame inside it), the time
      // outside the callback (interval minus callback: browser, compositor, GPU process or waiting on the GPU), and the
      // mean GPU time of the frames in the group that were GPU-timed.
      const longThreshold = 3 * stats(frameTimes).p50;
      const group = (isLong: boolean): Record<string, number> => {
        let n = 0, ft = 0, wk = 0, dr = 0, hu = 0, gN = 0, g = 0;
        for (let i = 0; i < frameTimes.length; i++) {
          if ((frameTimes[i] > longThreshold) !== isLong) continue;
          n++; ft += frameTimes[i]; wk += workMs[i] ?? 0; dr += drawMs[i] ?? 0; hu += hudMs[i] ?? 0;
          const gv = gpuByFrame[i]; if (gv !== null) { gN++; g += gv; }
        }
        const d = Math.max(1, n);
        return { frames: n, frameMsAvg: r3(ft / d), callbackCpuMsAvg: r3(wk / d), drawCpuMsAvg: r3(dr / d),
          hudCpuMsAvg: r3(hu / d), outsideCallbackMsAvg: r3((ft - wk) / d), gpuTimedFrames: gN,
          gpuMsAvg: gN ? r3(g / gN) : -1 };
      };
      const longFrames = { thresholdMs: r3(longThreshold), long: group(true), other: group(false) };
      const liveS = stats(live);
      const res: Record<string, unknown> = {
        stack: 'web',
        engineVersion: 'none (TypeScript + raw WebGL2, no libraries)',
        renderer: 'webgl2',
        build: 'web',
        browser: navigator.userAgent,
        gpu: info.renderer,
        driver: angleBackend(info.renderer),
        cpu: '',
        os: '',
        width: r.gl.drawingBufferWidth,
        height: r.gl.drawingBufferHeight,
        vsync: false,
        scene: p.scene,
        warmupTicks: p.warmup,
        measureTicks: p.measure,
        frames: frameTimes.length,
        elapsedMs: r3(elapsed),
        frameMs: { avg: r3(fs.avg), p50: r3(fs.p50), p95: r3(fs.p95), p99: r3(fs.p99), max: r3(fs.max) },
        fps: r3(frameTimes.length / (elapsed / 1000)),
        subMs: {
          sim: sub(simMs),
          upload: sub(uploadMs),
          particles: sub(partMs),
          gpu: info.timerQuery && gpuSamples.length ? sub(gpuSamples) : null,
        },
        particles: { liveAvg: Math.round(liveS.avg), liveMax: liveS.max },
        simTickFinal: hashTick,
        simHash,
        goldenHash,
        hashMatch: goldenHash !== '' && simHash === goldenHash,
        notes: '',
        frameTimesMs: frameTimes.map(v => r3(v)),
        // Extras (not in the SPEC schema)
        measureEndTick: tickEnd,
        subMsDefinition: 'sim, upload and particles: CPU ms per measured frame that ran at least one sim tick ' +
          '(stepFrames of them; at uncapped rates most frames run no tick). sim = scene.step + camera.step; upload = ' +
          'height texture fill + texSubImage2D; particles = spawning + ring bufferSubData. gpu: ' +
          'EXT_disjoint_timer_query_webgl2 TIME_ELAPSED over the whole draw, SAMPLED: only frames that began while fewer than ' +
          'gpuTimerMaxInflight queries were waiting are timed (gpuTimerSamples of frames; gpuTimerCoverage). cpuMs: CPU ms of ' +
          'the whole rAF callback, of r.draw (GL command submission) and of hud.frame, over every measured frame. ' +
          'longFrames: frames over 3x the median against the rest. performance.now() is ' +
          'coarsened to 5 us (with jitter) in a cross-origin-isolated page, so single values under ~0.01 ms are noise.',
        stepFrames: simMs.length,
        subMsAllFramesAvg: { sim: r3(sumSim / Math.max(1, frameTimes.length)), upload: r3(sumUp / Math.max(1, frameTimes.length)),
          particles: r3(sumPart / Math.max(1, frameTimes.length)) },
        simPerTickUs: r3(ticksMeasured ? (sumSim * 1000) / ticksMeasured : 0),
        ticksMeasured,
        uploadPerUpload: { ...sub(uploadEach), count: uploadEach.length },
        particlesDrawnAvg: Math.round(stats(drawn).avg),
        particlesSpawned: { crater: app.ring.spawnedByKind[0], big: app.ring.spawnedByKind[1], spark: app.ring.spawnedByKind[2] },
        particleRingOverflow: app.ring.overflow,
        maxStepsPerFrame: maxSteps,
        droppedBacklogMs: r3(clock.droppedMs),
        gpuTimerAvailable: info.timerQuery,
        gpuTimerSamples: gpuSamples.length,
        gpuTimerCoverage: r3(frameTimes.length ? gpuSamples.length / frameTimes.length : 0),
        gpuTimerMaxInflight: MAX_INFLIGHT,
        gpuTimerSkippedAllFrames: r.timer.skipped,
        cpuMs: { callback: sub(workMs), draw: sub(drawMs), hud: sub(hudMs),
          callbackP99: r3(stats(workMs).p99), callbackMax: r3(stats(workMs).max) },
        longFrames,
        gpuTimerDisjoints: r.timer.disjoints,
        crossOriginIsolated: (globalThis as { crossOriginIsolated?: boolean }).crossOriginIsolated === true,
        glVersion: info.version,
        glVendor: info.vendor,
        devicePixelRatio: devicePixelRatio,
      };
      const notes: string[] = [];
      if (hashTick !== tickEnd) notes.push(`measure ended at tick ${tickEnd}; sim stepped on (no render) to golden tick ${hashTick}`);
      if (!info.timerQuery) notes.push('EXT_disjoint_timer_query_webgl2 unavailable: subMs.gpu is null');
      else notes.push(`subMs.gpu is sampled: ${gpuSamples.length} of ${frameTimes.length} measured frames GPU-timed`);
      if (clock.droppedMs > 0) notes.push(`accumulator dropped ${r3(clock.droppedMs)} ms of backlog (frames longer than 8 ticks)`);
      res.notes = notes.join('; ');
      hud.now({ scene: app.scene.name, tick: app.scene.tick, live: app.ring.live,
        hash: `${res.hashMatch ? 'PASS' : 'FAIL'} @${hashTick}`, mode: 'bench done' });
      resolve(res);
    };

    requestAnimationFrame(frame);
  });
}
