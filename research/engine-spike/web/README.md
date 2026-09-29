# Engine spike: web stack (TypeScript + raw WebGL2, no libraries)

Throwaway spike code for ADR 0001 (Godot 4.7.2 or the web stack). Nothing outside `research/` may import it.
Contract: `../SPEC.md`. This folder is the web build; `../tools/bench-browser.mjs` is its browser driver (also used for
the Godot web export).

The key design point: **the sim and camera are not ported.** The browser imports `shared/sim-ref.mjs` and
`shared/camera-ref.mjs` unchanged, the same files Node runs in `shared/test-ref.mjs`. That is the path where the
plain-JS sim core becomes the production core.

## How to run

All commands are run from the repo root. Nothing needs installing. Node 24 and Chrome or Edge are enough.

| What | Command |
|---|---|
| Build (src/*.ts to dist/*.js, about 40 ms) | `node research/engine-spike/web/build.mjs` |
| Serve (COOP/COEP, needed for the bench's 5 µs timer; see Export notes) | `node research/engine-spike/tools/serve.mjs --port 8631` |
| Demo | open `http://127.0.0.1:8631/web/index.html` (`?scene=worst` etc. picks the start scene) |
| Node unit tests (render math, particles, loop, hashing) | `node --test "research/engine-spike/web/test/*.test.mjs"` |
| Reference checks in the browser | `node research/engine-spike/tools/bench-browser.mjs --url "http://127.0.0.1:8631/web/index.html?test=1" --wait-for __testResult --out <json> [--browser edge]` |
| Bench (SPEC protocol) | `node research/engine-spike/tools/bench-browser.mjs --url "http://127.0.0.1:8631/web/index.html?bench=1&scene=worst" --out <json> --flag --force_high_performance_gpu` |
| Short smoke bench | add `&measure=300` to the URL (the sim then steps on to the next golden tick, 600, for the hash) |
| iGPU (minimum-spec stand-in) | `--flag --force_low_power_gpu` instead |
| Screenshot | `... --url "http://127.0.0.1:8631/web/index.html?shot=1&scene=flight" --wait-for __shotResult --shot results/screens/web-flight.png --out <json>` (`&at=<tick>` to override; `&camx=<x>` moves the camera for the shot only; `&seam=0` hides the seam marker) |
| Demo smoke (headed, real time, until tick 610) | `... --url "http://127.0.0.1:8631/web/index.html?scene=worst" --wait-for __demoReady --out <json>` |
| Optional type check (dev only; see Dependencies) | from a temp directory: `npx -y -p typescript@7.0.2 tsc --noEmit --strict --target es2022 --module esnext --moduleResolution bundler --allowImportingTsExtensions --allowJs --checkJs false --lib es2022,dom,dom.iterable --skipLibCheck <repo>/research/engine-spike/web/src/*.ts` |

Demo keys: 1 to 6 pick `flight`, `worst`, `sweep`, `chase`, `orbit` or `climb`. Arrows or WASD fly box a in `flight`,
C craters under box a, H toggles the HUD and M toggles the magenta seam marker (a tick above world x = 0). A gamepad
with the standard mapping also works: left stick or d-pad to fly, A to crater. The gamepad has not been tested, because
no pad was available.

`bench-browser.mjs` options: `--url --out [--browser chrome|edge] [--width 1920 --height 1080] [--timeout 240]
[--shot <png>] [--wait-for __benchResult] [--flag <browser flag>]... [--browser-path <exe>]`. It exits 0 on a result,
and 1 on an error, a timeout, `hashMatch: false` or `pass: false`. It still writes the JSON when the result is a
failure.

## What passed (outputs from 2026-09-29, this machine)

- **Build, with no dependencies:** `build: 15 files, 76897 bytes -> ...\web\dist in 35 ms`. Node 24 also prints
  `ExperimentalWarning: stripTypeScriptTypes is an experimental feature`, which is expected.
- **Node unit tests:** `node --test "research/engine-spike/web/test/*.test.mjs"` gives `tests 14, pass 14, fail 0`. The
  worst-scene test prints `live avg 23940, max 25440, largest draw window 38250 of 65536` for ticks 181 to 1980.
- **Reference checks in the browser (`?test=1`):** `checks: all passed (22 checks)` in both **Chrome/154.0.8037.58**
  and **Edg/154.0.4258.37**. All 16 golden hashes (terrainBase, worst, flight and flight-input at their checkpoints, and
  camera for all six scenes) equal `shared/golden.json`, for example `worst@1980 19a92e5cae133e41...` and
  `camera.sweep@3600 fd570acbd7b083d8...`. All six camera seam tests pass, and their metrics match Node's to every
  printed digit (sweep: flips 19, maxScreenJump 0.01796, maxSeamOffsetDiff 5.107e-15). Saved to
  `results/smoke/web-test-chrome.json` and `web-test-edge.json` (re-run after the fixes below). The run takes about
  70 ms in the page.
- **The driver always closes the browser.** After each run, `bench-browser.mjs` finds every browser process whose
  command line contains the run's temporary profile path, sends `Browser.close`, waits, force-kills (`taskkill /T /F`)
  whatever is left, and deletes the profile.
  - A first version parsed the process list with `split(/s+/)` (the letter s, not whitespace), so it always counted 1
    and its force-kill fallback would have run `taskkill /PID NaN`. The independent verifier found this. It is fixed
    (`split(/\s+/)`, keeping only positive integers), and the driver now warns if the process query itself fails.
  - After the fix, the logs report the real counts: 9 to 10 Chrome processes and 14 to 15 Edge processes per run.
  - The fallback was tested once with a throwaway copy of the driver (in the session scratchpad, not the repo) that
    skips `Browser.close`. Edge `?test=1` gave `browser processes on the temp profile before close: 13`, then
    `force-killing 15 browser process(es)`, then `browser closed; temp profile removed`. A separate CIM query
    afterwards found no browser process on any `spike-cdp-*` profile, and no profile folder was left in `%TEMP%`.
- **Bench:** SPEC-schema JSON with `hashMatch: true` in every run. The full-length run hashed at tick 1980 itself. In
  every run the canvas is 1920x1080 at DPR 1, `crossOriginIsolated` is true, and the unmasked GPU string and
  `frameTimesMs` are recorded. See Smoke numbers.
- **Demo in real time:** `--wait-for __demoReady` gives `worst 610 sim@600 PASS` and `flight 610 sim@600 PASS` (the
  HUD's own live hash check).
- **Screenshots, each viewed after capture:**

| File | What to look for |
|---|---|
| `results/screens/web-flight.png` | Tick 2185: the seam at render x -345 (magenta tick), the camera low over the ocean. The ocean floor through translucent water, the water's top and front faces, crater particles under water, both boxes. The floor and water run straight through the seam with no gap, step or pop. |
| `results/screens/web-worst.png` | Tick 1200 (SPEC): six beams (cyan-white and orange-white cores with glows), impact flares, about 22k particles, both boxes. At tick 1200 the pair is at its minimum separation, so the view is at its narrowest (1421) and the ground sits just below the frame. In `worst` the camera height is always about 565, because the two height waves are half a period apart. The Godot build uses the same camera, so it frames this shot the same way. |
| `results/screens/web-worst-wide.png` | Extra, tick 1500 (separation 4600, view 5195): beams hitting cratered, scorched ground; ember particles at the impacts; water only over the original sea columns; the seam in view. |
| `results/screens/web-sweep.png` | Tick 96: the boxes exactly 4800 apart (half the planet) at the view edges. Mountains, village, plains and ocean biome colours; translucent water with a visible front face; the seam at render x 600 inside the ocean with no discontinuity. |

- **Driver genericity:** the Godot web build's session used this driver against its own export
  (`results/smoke/godot-web-chrome.json`: `stack godot, build web, hashMatch true`, `frameTimesMs` present). So the
  Godot web export works with it unchanged.
- **Type check:** `tsc 7.0.2 --strict --noEmit` exits 0 after one fix, a union type in `checks.ts`. It was re-run
  after the bench changes below and still exits 0.

## Architecture

```
index.html            canvas + HUD <pre>, an import map (test mode only, below), loads dist/main.js
build.mjs             node:module stripTypeScriptTypes (strip mode, positions kept) + ".ts" -> ".js" specifiers
src/main.ts           query-string modes: demo | ?bench=1 | ?test=1 | ?shot=1; sizing; the demo frame loop
src/app.ts            App: scene + camera + particle ring; tick(): input -> scene.step() -> camera.step() -> spawns
src/bench.ts          SPEC bench protocol -> window.__benchResult
src/checks.ts         the reference checks in the browser -> window.__testResult
src/renderer.ts       WebGL2: sky, terrain, boxes, water, beams and flares, particles (reads state, never writes)
src/shaders.ts        the six GLSL ES 3.00 programs
src/particles.ts      stateless GPU ring buffer, SPEC counts, analytic live counts, presentation RNG
src/math.ts           pure render math (grid anchoring, projection, wrap helpers), unit-tested in Node
src/loop.ts           fixed-step accumulator (60 Hz, at most 8 steps per frame) + SPEC percentile stats
src/input.ts          keyboard + Gamepad API -> intent, sampled once per tick
src/hud.ts, gl.ts, hash.ts, types.ts, node-shim.ts
test/*.test.mjs       node:test on the .ts sources directly (Node 24 strips types natively)
```

- **Layers.** The sim (`sim-ref.mjs`) knows nothing about rendering. The camera (`camera-ref.mjs`) is stepped once per
  tick, after the sim. The renderer reads `scene`, `cam` and the particle ring once per animation frame and writes
  none of them. Input is sampled per tick, before `scene.step()`, which is the same rule the flight-input replay
  golden uses.
- **Loop.** `requestAnimationFrame`, uncapped when the browser is started with `--disable-gpu-vsync
  --disable-frame-rate-limit`. Real time feeds `FixedStepClock` (16.667 ms steps, at most 8 per frame; any backlog
  beyond that is dropped and counted). There is no interpolation, so the renderer draws the state of the last tick.
- **Camera and floating origin.** Eye at render (0, cam.y, cam.distance()), looking along -z, vertical FOV 40° at
  16:9. The camera never rotates, so view-projection is a translation times a perspective matrix, written out directly
  in `math.viewProj`. Every object is placed at `sdx(cam.x, worldX)`. Beams are drawn from `sdx(cam.x, sx)` along
  their own short arc `sdx(sx, tx)`, so a beam never splits at the seam. Particles are the one exception on the CPU
  side: they store a world spawn x, and the vertex shader converts it to camera-relative
  (`x - camX + vx*t`, then wrapped into [-4800, 4800)) before anything else happens. The float32 error of that is
  under 0.01 units (unit test).
- **Terrain.** One static grid of 1100 columns, 4 vertices each: top back (z -400), top front (z +120), face top and
  face bottom (y -700). `gridAnchor(cam.x)` gives `col0` and a render x offset, the only two numbers that change per
  frame. Heights come from an R32F 1200x1 texture read with `texelFetch` at `(col0 + i) % 1200`, with no filtering.
  When `terrain.version` moves, the height texture (base + deform) is re-filled and re-uploaded with `texSubImage2D`,
  and the CPU side of that is timed. The colour comes from a static RGBA8 biome texture (alpha = sea flag). It is
  darkened by scorch (`base - height`), lit by one directional light plus ambient, and snow-capped above about 700.
  Normals come from the neighbouring texels. The front face is shaded as a soil-to-rock cross-section.
- **Water.** The same grid and vertex shader in water mode: the top at y 0 over z -400..120, and a front face from 0
  down to the terrain. It is discarded where the sea flag (base < -30) is off, and alpha-blended with no depth writes.
- **Sky.** A full-screen triangle with a gradient over the view ray's elevation, using the same three colours and
  falloff as the Godot build's `sky.gdshader`, so both stacks look alike.
- **Boxes.** One instanced unit cube: 40x60x40, `#3d8fdc` and `#a52a2a`.
- **Beams and flares.** Instanced quads in the z = 0 plane, additive: a 44-unit glow and a 14-unit core per beam with
  soft end caps, plus an impact flare of radius 60. Owner 0 is cyan-white and owner 1 orange-white. One draw call.
- **Particles.** A stateless GPU ring of 65,536 slots at 32 bytes each (x, y, vx, vy, spawn tick, life ticks, size,
  RGBA8), written once at spawn from a seeded presentation RNG (`Rng(20260928)`, never the sim's). Only the new range
  is uploaded each frame (`bufferSubData`, one or two ranges). The vertex shader computes the ballistic motion
  (gravity -900) from the age in ticks and collapses dead particles out of the clip volume. Only the window from the
  oldest live batch to the head is drawn, as one or two instanced draws. Counts follow SPEC exactly (150 / 3000 /
  5 per beam per tick; lives of 120 / 180 / 48 ticks). The live count is analytic: batches of one kind expire in spawn
  order, so a FIFO per kind gives the exact number. A unit test checks it against a brute-force count and against the
  shader's own discard test over 1980 worst-scene ticks.
- **Modes.** `?bench=1` and `?shot=1` fix the canvas at 1920x1080 CSS px (the driver sets DPR 1). The demo
  letterboxes to 16:9 at the window's DPR. `?test=1` imports `checks.ts` dynamically.
- **Test-mode reuse of `shared/test-ref.mjs`.** It is imported unchanged for `CHECKPOINTS`, `scriptedInput`,
  `CAMERA_SCENES` and `CAMERA_TICKS`. It imports `node:crypto`, `node:fs`, `node:url` and `node:path` at top level
  and reads `process.argv`, so `index.html` has an import map that points those four specifiers to `dist/node-shim.js`
  (stubs that throw if called), and `main.ts` defines `globalThis.process = { argv: [] }` first. `goldens()` and
  `cameraTest()` are not exported, so `checks.ts` mirrors their bodies line for line, with the hash call async because
  WebCrypto has no sync digest.
- **GPU choice.** The context uses `powerPreference: 'default'`, so the browser flags alone decide the adapter (EP
  amendment b).

### Bench output
The SPEC schema, plus:
- `frameTimesMs` (every measured frame, in order);
- `gpu` (unmasked `WEBGL_debug_renderer_info` renderer);
- `driver` (the ANGLE backend, for example `D3D11`, or null);
- extras: `measureEndTick`, `stepFrames`, `subMsAllFramesAvg`, `simPerTickUs`, `uploadPerUpload`, `particlesDrawnAvg`,
  `particlesSpawned`, `particleRingOverflow`, `maxStepsPerFrame`, `droppedBacklogMs`, `crossOriginIsolated`;
- GPU timer coverage: `gpuTimerSamples` (GPU-timed measured frames), `gpuTimerCoverage` (that divided by `frames`),
  `gpuTimerMaxInflight` and `gpuTimerSkippedAllFrames`;
- `cpuMs`: CPU ms of the page's whole `requestAnimationFrame` callback, of `r.draw()` (the GL command submission) and
  of `hud.frame()`, over every measured frame (avg and p95, plus the callback's p99 and max);
- `longFrames`: frames longer than 3x the median against the rest. For each group it gives the mean frame interval,
  the callback, draw and HUD CPU time, the time outside the callback (interval minus callback), and the mean GPU time
  of the GPU-timed frames in that group.

The driver adds `browser` (from `/json/version`), `userAgent`, `gpuRendererUnmasked`, `browserGpuDevices` (CDP
`SystemInfo.getInfo`: every adapter with its driver version), `canvas` (backing and CSS size, DPR), and `benchDriver`
(flags, URL, wall time, page warnings). It also fills `cpu` and `os` from Node.

**Frame interval convention.** A frame is measured when its sim tick, after that frame's steps, is in (warmup,
warmup + measure]. Its time is the interval from its own start to the next frame's start. The sim never steps past
warmup + measure.

**Sub-timings.** `subMs.sim`, `upload` and `particles` are CPU ms per measured frame that ran at least one tick. At
2,700 fps most frames run none, and a p95 over all frames would read 0.

`subMs.gpu` is `EXT_disjoint_timer_query_webgl2` `TIME_ELAPSED` over a frame's whole draw. It is null if the extension
is missing; it was available in Chrome and Edge 154 here.
- **It is a sample, not a per-frame figure by construction.** Query results arrive late, and a frame is timed only
  when fewer than `gpuTimerMaxInflight` queries are waiting. Read `gpuTimerSamples` next to `frames`, or
  `gpuTimerCoverage`; the bench `notes` also state it.
- With the first cap of 64 queries in flight, only about 9% of measured frames were timed (the verifier counted 1,246
  of 13,578 in a short run; the earlier full-length run timed 7,382 of 80,682). The cap is now 1,024, and every
  measured frame was timed in all four smoke runs below (coverage 1.0, no skips).
- The GPU averages went up after that change: 0.119 ms became 0.197 ms in the full-length run. The earlier 9% sample
  was therefore not representative. It is also possible that 1,024 queries in flight add some cost of their own.
  Neither effect was separated.

## Smoke numbers (SMOKE: harness checks only, not results)

All four runs were re-taken on 2026-09-29 with the fixed driver and the bench changes above (every measured frame
GPU-timed, CPU callback timing added). Other sessions may have been active on the machine; earlier runs overlapped the
Godot web session's browser runs. These runs show that the harness works and what it records, not the performance of
the stack. The Research director's final runs (`tools/run-final.mjs`, quiet machine) are the numbers that count.
Worst scene, 1920x1080 at DPR 1, `crossOriginIsolated` true, vsync and frame-rate limit off.

| Run (file in results/smoke/) | Browser | GPU | measured ticks | frames | avg ms | p50 | p95 | p99 | fps | GPU ms avg (p95), sampled | GPU-timed frames | callback CPU ms avg (p95) | live avg | hash |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| web-chrome-worst-fulllength | Chrome 154 | RTX 5070 Ti (D3D11) | 1800 | 77,712 | 0.386 | 0.180 | 1.210 | 1.370 | 2592 | 0.197 (0.986) | 77,712 (100%) | 0.259 (1.120) | 23,915 | @1980 ok |
| web-chrome-worst-short | Chrome 154 | RTX 5070 Ti (D3D11) | 300 | 13,196 | 0.378 | 0.185 | 1.275 | 1.470 | 2648 | 0.188 (1.009) | 13,196 (100%) | 0.254 (1.185) | 24,203 | @600 ok |
| web-edge-worst-short | Edge 154 | RTX 5070 Ti (D3D11) | 300 | 14,415 | 0.346 | 0.160 | 1.145 | 1.330 | 2891 | 0.181 (0.897) | 14,415 (100%) | 0.224 (1.060) | 24,236 | @600 ok |
| web-chrome-igpu-worst-short | Chrome 154 | AMD Radeon iGPU (D3D11) | 300 | 4,173 | 1.195 | 1.130 | 2.165 | 2.630 | 837 | 0.945 (1.217) | 4,173 (100%) | 1.030 (1.950) | 24,256 | @600 ok |

`longFrames` (frames over 3x the median) from the same files:

| Run | long threshold | long frames | long: frame / callback CPU / of which `r.draw()` / outside callback / GPU (ms) | other frames | other: frame / callback CPU / of which `r.draw()` / outside callback / GPU (ms) |
|---|---|---|---|---|---|
| Chrome RTX, full | 0.54 | 17,450 (22%) | 1.153 / 0.972 / 0.961 / 0.181 / 0.224 | 60,262 | 0.164 / 0.053 / 0.048 / 0.111 / 0.190 |
| Chrome RTX, short | 0.555 | 2,582 (20%) | 1.225 / 1.045 / 1.035 / 0.180 / 0.217 | 10,614 | 0.172 / 0.061 / 0.055 / 0.111 / 0.181 |
| Edge RTX, short | 0.48 | 3,232 (22%) | 1.045 / 0.873 / 0.861 / 0.172 / 0.187 | 11,183 | 0.144 / 0.037 / 0.032 / 0.107 / 0.179 |
| Chrome iGPU, short | 3.39 | 6 | 6.604 / 1.858 / 1.849 / 4.747 / 0.917 | 4,167 | 1.187 / 1.028 / 1.015 / 0.159 / 0.945 |

Observations:
- **The frame-time distribution is bimodal on the RTX, and the long frames are spent inside `r.draw()`.** p50 is about
  0.18 ms and p95 about 1.2 ms. About a fifth of frames are long. On those frames the page's own callback takes about
  1 ms of CPU, almost all of it inside `r.draw()`, which only issues GL calls. The time outside the callback barely
  changes (0.18 against 0.11 ms), and the GPU time of the same frames is only a little higher (0.22 against 0.19 ms).
  - An earlier version of this README said the long frames came from the browser's frame pipeline, "not from this
    code". That claim was not supported (the draw call's CPU time was not measured then), and the measurement above
    contradicts its wording: the time is spent in this page's GL calls.
  - **Hypothesis, not established:** the main thread blocks inside WebGL calls on Chrome's back-pressure (the command
    buffer to the GPU process, or the limit on frames in flight), rather than doing CPU work of its own. Most of those
    GL calls only record commands. A Chrome performance trace (DevTools Performance panel or `chrome://tracing`) would
    confirm or refute this; it was not taken.
  - The final runs should read the per-frame CSV rather than the average alone.
- **On the iGPU the page is GPU-bound.** The GPU time (0.94 ms) is most of the frame time (1.19 ms). The callback's
  CPU time (1.03 ms, again almost all in `r.draw()`) tracks the GPU time, which fits the main thread waiting on a busy
  GPU. The likely cost is overdraw from about 24k additive particle quads and the 44-unit beam glows at 1080p. That
  split was not measured per pass. Long frames are rare there (6 of 4,173).
- **`simPerTickUs` reads 6 to 8 µs in the browser against 0.36 µs in Node's simbench on the same code.** Both run on
  V8. The likely cause is the 5 µs `performance.now()` granularity plus the timer calls themselves, not the sim. Use
  Node's simbench for sim cost.
- **`--force_low_power_gpu` really does move Chrome onto the Radeon.** The unmasked renderer changes, and
  `browserGpuDevices` lists all three adapters with their driver versions.

## Determinism notes

- **Same bytes.** Node 24.19 (V8), Chrome 154 (V8) and Edge 154 (V8) produce identical SHA-256 hashes for every
  golden, and identical camera metrics. The code is the same: the browser imports the unchanged `.mjs` files.
- **Why it holds.** The sim uses only `+ - * /`, `Math.sqrt`, `Math.floor`, `Math.ceil`, `%` and `Math.imul`.
  ECMAScript specifies these exactly (IEEE-754 double, correctly rounded), so any conforming engine must agree. That
  includes SpiderMonkey and JavaScriptCore, but they were not tested; see gaps.
- **The Math.* caveat.** `Math.sin`, `cos`, `tan`, `exp`, `log`, `pow` (and `**`), `atan2`, `hypot` and friends are
  "implementation-approximated" in the spec. They can differ between engines, and between versions of one engine.
  The sim must never use them, and the production sim needs a lint rule for that. The renderer uses `Math.hypot` and
  `Math.round`, but only for presentation.
- **Sim and presentation are separate.**
  - Heights go to the GPU as float32, and particles use float32 attributes. Neither is ever read back.
  - Particles use their own seeded RNG, so they cannot perturb the sim. A unit test re-checks the sim hash at 600 and
    1980 while spawning.
  - The bench hashes at the end of the run, with rendering on, and matches the golden. So rendering does not change
    the sim.
- **Replay.** Input is applied only between ticks, and the flight-input golden, a scripted input stream, passes in the
  browser. The demo's human input or C craters mark the goldens as not applicable in the HUD.
- **Frame-rate independence.** Particle motion is computed from integer tick ages, so presentation is identical at
  any frame rate. Nothing is interpolated.

## Export and packaging notes (from doing it)

- **Static hosting.**
  - What gets deployed: `index.html`, `dist/*.js` and the shared sim modules. The runtime payload is 16 files, 85 KB
    raw, 32.6 KB gzipped (without the test-only `checks.js` and `node-shim.js`).
  - No bundler is used. The deploy must keep `web/` and `shared/` as siblings, because dist imports
    `../../shared/*.mjs`. A production build would copy or bundle those files.
  - ES modules do not load from `file://` in Chrome, so the page has to be served.
  - WebCrypto `subtle` needs a secure context (https or localhost), but only for the bench and test hashing.
- **COOP/COEP.**
  - This build needs neither: no `SharedArrayBuffer`, no threads.
  - With them (`serve.mjs`), `crossOriginIsolated` is true and `performance.now()` has 5 µs granularity instead of
    about 100 µs. That matters only for the bench.
  - Not tested: whether `EXT_disjoint_timer_query_webgl2` is still exposed without isolation.
  - On a normal static host (GitHub Pages, itch.io), COOP/COEP headers are not always settable. That is a real
    constraint for threaded Godot web exports, but not for this stack.
- **Uncapped frame rate is a benchmarking artefact.** Browsers present at display refresh unless started with
  `--disable-gpu-vsync --disable-frame-rate-limit`, which a player will not do. A shipped web game runs at display
  refresh.
- **Desktop and Steam Deck.** Nothing here was built as a desktop app. The options, not tried:
  - Electron (Chromium + Node, about 100 MB or more per platform, MIT; the same V8 means the same determinism, and it
    runs on Linux and Steam Deck);
  - Tauri (the system webview: WebView2 on Windows, WKWebView on macOS, WebKitGTK on Linux, where WebGL2 quality and
    performance vary and the JS engines differ, so the hash goldens would need re-checking);
  - NW.js.
  Steam integration (achievements, overlay, input) needs a native bridge such as steamworks bindings in Electron:
  more third-party code for the licence register.
- **Mobile.** A WebView wrapper (Capacitor or Cordova) or a PWA. Android WebView (Chromium) and iOS WKWebView both
  support WebGL2, but iOS uses JavaScriptCore, so determinism needs its own check there. Not tried.
- **Input.** The Gamepad API works in Chromium, and on Steam Deck Steam Input presents a standard pad. Keyboard and
  gamepad share one intent path here.

## Tooling and art-pipeline observations

What had to be hand-written, which an engine gives for free:
- **Shaders.** Six GLSL ES 3.00 programs (240 lines), kept as strings. There is no editor, no hot reload and no
  include system, and errors appear only at runtime (`gl.ts` prints readable compile logs). Lighting, snow, scorch,
  the front face and water were all written by hand. Godot has a material system, lights, and glow and shadow toggles
  (SPEC's optional "production look" is one checkbox there, and weeks of work here).
- **The particle system.** About 130 lines: ring allocation, upload ranges, analytic live counts, and the ballistic
  vertex shader. Godot has `GPUParticles3D`, although for exact SPEC counts the Godot build also wrote its own shader.
- **The loop.** A fixed-step accumulator (30 lines), percentiles, and the GPU timer queries. Godot has
  `_physics_process` with a fixed tick rate and a maximum number of steps.
- **Math.** No matrix library. The camera never rotates, so view-projection is written out directly. Anything that
  rotates (a 3D camera, skinned characters) needs a math library (for example gl-matrix, MIT) or one written in-house.
- **Assets, which is the big gap for Orb's cel-shaded low-poly style with procedural and AI-generated assets.** There
  is no glTF loader, no skeletal animation, no toon or outline shader, no texture compression (KTX2/Basis), no audio,
  no UI or font system (the HUD is a DOM `<pre>`) and no scene editor.
  - Realistically, the web stack would adopt three.js or Babylon.js (both third-party, each needing a licence-register
    row), which gives up the "no engine" premise but keeps plain JS.
  - Godot imports glTF and Blender files directly, has `AnimationPlayer` and `AnimationTree`, toon-style shading, and
    an editor that modders and artists can use.
  - Procedural planets work equally in both: they are code plus a texture upload.
- **What was pleasant.**
  - One language for the sim, the tests, the tools and the client: Node runs the same `.mjs` sim and even the `.ts`
    render math (`node --test` on the sources).
  - The build is 36 lines with zero dependencies, and a rebuild and refresh takes under a second.
  - Chrome DevTools (performance profiler, memory, WebGL errors) is excellent.
  - The bench driver is 250 lines of plain Node using CDP.
- **What was annoying.**
  - `stripTypeScriptTypes` only erases, so there is no type check without `tsc`. Only erasable TypeScript is allowed
    (no enums or namespaces).
  - TS types for the plain-JS sim come from inference with `allowJs`, and a union type needed one cast.
  - Browser GPU selection and vsync are controlled by browser flags, not by the app.
  - Edge's `msedge.exe` hands off to a new process, so the driver tracks the browser by its profile path instead of
    the launcher PID.
- **Modding.** Plain JS modules are trivially inspectable and replaceable, and a mod loader is a dynamic `import()`.
  Sandboxing mods (so they cannot reach the network or storage) is the hard part in both stacks.

## Dependencies

- **Runtime and build:** none. Node 24's `node:module`, WebSocket, fetch and crypto; Chrome and Edge. These are
  already on the licence register. There is no `package.json` and no `node_modules` in the repo.
- **Dev only, optional, not in the repo:** TypeScript 7.0.2, used once to type-check.
  - Source: registry.npmjs.org, fetched by `npx -y -p typescript@7.0.2` into the npm cache
    (`%LOCALAPPDATA%\npm-cache\_npx\d08dbff2f92d3e31`, 31 MB), outside the repo.
  - Packages actually installed, both Apache-2.0:
    - `typescript@7.0.2`, integrity
      `sha512-8FYau96o3NKOhbjKi/qNvG/W5jhzxkbdm5sj9AbZ/5T5sWqn3hJgLfGx27sRKZWTvyzCP8dLRBTf5tBTSRVUNA==`;
    - `@typescript/typescript-win32-x64@7.0.2` (the native compiler), integrity
      `sha512-0BQ3HkAHHlKLSp1qRvf3SUhGpGsDuhB/jgFw75guyqbxJqEaS0Cw/VFO8i2nHglJUzQCRtMMR/IBAKE3ETMC4g==`.
  - npm verified both integrities on install.
  - If the project adopts TypeScript, it needs a licence-register row and, under EP amendment (c), a `package.json`
    and lockfile inside `research/` (or the production tree).

## Known gaps (honest list)

1. **Only Chromium was tested (V8 in both).** Firefox is not installed here. Safari needs macOS. SpiderMonkey and
   JavaScriptCore should agree by the spec, but that is unverified. `bench-browser.mjs` drives Chromium only (CDP).
2. **No desktop, mobile or Steam Deck package was built.** The notes above are informed guesses, not measurements.
3. **Input was never exercised by automation.** Keyboard, the C crater and the gamepad path were not driven by a test
   (the demo smoke runs without input), and the gamepad was not tested at all.
4. **The smoke numbers came from a busy machine.** They are harness checks only, and some ran at the same time as the
   Godot web session's browser runs.
5. **Timing limits.**
   - Timer granularity is 5 µs, so the sub-ms CPU splits are coarse.
   - The GPU timer covers only this page's GL commands, not the browser compositor.
   - `subMs.gpu` is a sample: every frame was timed in these runs, but that is not guaranteed if query results lag
     more than 1,024 frames. Check `gpuTimerCoverage`.
   - Why `r.draw()` sometimes blocks for about 1 ms on the RTX is a hypothesis (see Observations); no browser trace
     was taken.
   - The driver polls the page with a cheap `typeof` check every 500 ms during a run.
6. **`checks.ts` mirrors two functions from `test-ref.mjs`,** because they are not exported. If `test-ref.mjs` gains
   another `node:` import, the import map needs a matching entry.
7. **Visual limits.**
   - Particles fall through the terrain (SPEC: no collision), so some show below the slab.
   - The water edge is a hard cut halfway between a sea column and a land column.
   - Additive effects wash out against the bright sky; the Godot build uses the same sky.
   - The HUD in screenshots reads `0 fps` (a single frame).
8. **`frameTimesMs` makes the full-length JSON about 800 KB.** `run-final.mjs` moves the array to CSV.
9. **The driver's process clean-up was broken until the verifier's round.** Runs taken before the fix closed
   correctly only because `Browser.close` succeeded every time. The force-kill path has been tested once, with Edge
   only.

## Suggestions for the Research director

These are not changes I made; `shared/` and `SPEC.md` are read-only for this build.
- Export `goldens(hashFn)` and `cameraTest()` from `test-ref.mjs`, and move its `node:` imports inside the main block.
  Browsers and other ports could then run the exact checks with no mirrored code and no import map.
- SPEC's `worst@1200` screenshot always lands at the tightest framing, with the ground out of frame. Tick 1500 (my
  extra `web-worst-wide.png`) shows beams hitting the ground.
- For the final comparison, read the per-frame CSVs. The web stack's p50 and p95 differ by about 7x on the RTX.
  About a fifth of frames block for about 1 ms inside the page's WebGL calls, probably on browser back-pressure (a
  hypothesis; see Observations). A Chrome trace during one final run would settle it.
- `bench-browser.mjs` has changed, but Godot web smoke runs taken with the old driver are still valid as data. The fix
  touched only the clean-up path after the result was saved. Whether those runs left a browser behind can be checked
  by looking for leftover `spike-cdp-*` folders in `%TEMP%`; none were present after this round's runs.
