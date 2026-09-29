# Engine spike: build spec (the contract every spike build follows)

Owner: Research & Prototyping. Question: Godot 4.7.2 or the web stack for the real build (ADR 0001). Spike code is throwaway, stays in `research/`, and nothing outside `research/` may import it.

## Rules
- No git commands that change state. Only read-only git (status, diff, log).
- Write only to the paths your task owns (see Layout). Everything else is read-only, and `prototype/index.html` is QA's.
- No new third-party code or assets. Godot, Node, .NET and Chrome/Edge are already on the licence register. Name anything else before using it and do not add it to the repo (licence-register rule 1).
- Everything visual is original: boxes, simple shapes and plain colours (docs/legal/originality-rules.md).
- Keep sim and rendering separate:
  - The sim steps at a fixed 60 Hz (accumulator, at most 8 steps per frame) and knows nothing about rendering.
  - The renderer reads sim state and never writes it.
  - The camera is presentation: it is stepped once per sim tick, after the sim.
- Downloads come only from official sources, with checksums verified. Keep them outside the repo, and put scratch files in the session scratchpad or the OS temp directory.

## Layout
```
research/engine-spike/
  SPEC.md, PLAN.md, RESULT.md         Research director
  shared/                             reference sim, camera, goldens, tests (Research director; read-only for builds)
  tools/serve.mjs                     static server with COOP/COEP (Research director)
  tools/bench-browser.mjs             Chrome/Edge driver over CDP (web build)
  godot/                              Godot 4.7.2 project (godot builds)
  web/                                TypeScript + WebGL2 build (web build)
  csharp/                             .NET 10 console port (C# build)
  notes/                              written evidence (notes and C# builds)
  results/smoke/, results/final/, results/screens/   benchmark JSON and screenshots
```

## Shared reference (source of truth)
- `shared/sim-ref.mjs`: wrap math, mulberry32, terrain generation, craters, fighters and the scenes. Read its header, the portability contract. A port must reproduce it bit for bit:
  - float64 everywhere, with only + - * / sqrt floor ceil fmod;
  - expressions evaluated in the written order;
  - 32-bit integer RNG.
- `shared/camera-ref.mjs`: the camera, including the continuous arc, the hysteresis flip, the capped pan and the floating origin.
- `shared/golden.json`: SHA-256 of little-endian float64 state vectors. It holds `terrainBase`, `worst@600/1980/3600`, `flight@600/1800/3600`, `flight-input@600/1800/3600` (box a flown by `scriptedInput(n)` before each step) and `camera.<scene>` after 3600 ticks.
- `shared/test-ref.mjs`: the checks every port repeats. Run it with `node research/engine-spike/shared/test-ref.mjs [--bench]`. It checks:
  - the goldens;
  - camera framing: both boxes in frame except during a flip pan;
  - no box jumps more than 5% of the screen width in one tick;
  - the screen is identical wherever the seam sits (scene shifted by 0.5, 1234.5, 4800, 9599.75, 7777.77);
  - simbench: median µs per worst-scene tick over 3600 ticks × 5 runs, plus the time to generate the terrain.

## Scenes (names are fixed; hotkeys 1 to 6 in each demo)
1 `flight` (the default in the demo): two boxes fly freely, a crater every 0.5 s, arrow keys or WASD fly box a (setInput), C craters under box a.
2 `worst`: the benchmark scene.
3 `sweep`, 4 `chase`, 5 `orbit`, 6 `climb`: the scripted camera and seam paths.

## Presentation: 2.5D, side-on
- **Units.** World units match the sim, with y up. The gameplay plane is z = 0.
- **Camera.**
  - Perspective, vertical FOV 40°, 16:9. It looks along -z at the z = 0 plane.
  - Camera distance is `camera.distance()` (view width `viewW` at z = 0). Height is `camera.y`.
  - Render in camera-relative space (floating origin): object render x = `sdx(cam.x, worldX)`, and the camera sits at render x = 0. Never place anything at a raw world x.
- **Terrain.**
  - A static grid of 1100 columns, 8 units apart, centred on the camera. Its heights come from a 1200 × 1 float texture (base + deform), read with texelFetch at column `(col0 + i) mod 1200`, with no filtering. Re-upload the texture when `terrain.version` changes.
  - The top surface runs in depth from z = -400 to z = +120, flat along z. A front face at z = +120 runs down to y = -700.
  - Colour comes from the biome (a static 1200-texel colour texture), darkened where deform < 0 (scorch). Normals come from neighbouring texels.
  - A different technique is allowed if you measure it and report why (for example, rebuilding meshes).
- **Water.** A translucent surface at y = 0 over columns where `base < -30`, over the same depth span.
- **Sky.** A vertical gradient. One directional light plus ambient. No shadows, MSAA or post effects in the baseline. Godot may also measure a "production look" variant (glow and shadows) as a separate run.
- **Fighters.** Boxes 40 wide, 60 tall and 40 deep, centred at (x, y, 0). Box a is blue `#3d8fdc`, box b red `#a52a2a`.
- **Beams.** From (sx, sy) to (tx, ty) at z = 0: a 14-unit core and a 44-unit glow, additive, with an impact flare of radius 60. Owner 0 is cyan-white and owner 1 orange-white.
- **Particles.** Presentation only, spawned from `scene.events` and the beams with a seeded presentation RNG (never the sim RNG). Motion is ballistic (gravity -900 u/s², no collision). All are additive billboards. The counts are fixed so both stacks draw the same load:

  | Source | Count | Life | Velocity range (vx, vy) | Size |
  |---|---|---|---|---|
  | crater event (kind 0) | 150 | 2.0 s | vx ±300, vy 150..700 | 6 |
  | big crater (kind 1) | 3000 | 3.0 s | vx ±900, vy 200..1400 | 8 |
  | each beam, each tick, at (tx, ty) | 5 | 0.8 s | vx ±400, vy 100..600 | 4 |

  In `worst` that is about 24k live particles. Report live counts (tracked from spawn times).
- **HUD.** Small text: fps, frame ms, scene, tick, live particles, sim hash status. H toggles it.

## Bench mode
- **Start.**
  - Godot: `Godot_v4.7.2-stable_win64.exe --path research/engine-spike/godot --resolution 1920x1080 [--rendering-method forward_plus|gl_compatibility] -- --bench --scene worst --out <abs.json>`. Exported builds take the same user arguments.
  - Web and Godot web: URL query `?bench=1&scene=worst`. The page sets `window.__benchResult = <object>` when done.
- **Protocol.**
  - The sim runs real time (accumulator) and rendering is uncapped: vsync off, no fps cap.
  - Frames rendered while sim tick ≤ 180 are warm-up.
  - Measure every frame while 180 < tick ≤ 1980, which is 30 s of sim time. Frame time is the interval between consecutive frame starts.
  - At tick 1980, hash the state and compare it with `golden.worst["1980"]`.
- **Stats.** Sort the frame times: pN = sorted[ceil(N/100 × n) − 1]. Report avg, p50, p95, p99 and max in ms, and fps = frames / elapsed seconds.
- **Output JSON** (both stacks):
```json
{ "stack": "godot|web", "engineVersion": "", "renderer": "forward_plus|gl_compatibility|webgl2", "build": "editor|release|web",
  "browser": null, "gpu": "", "cpu": "", "os": "", "width": 1920, "height": 1080, "vsync": false,
  "scene": "worst", "warmupTicks": 180, "measureTicks": 1800, "frames": 0, "elapsedMs": 0,
  "frameMs": {"avg": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0}, "fps": 0,
  "subMs": {"sim": {"avg": 0, "p95": 0}, "upload": {"avg": 0, "p95": 0}, "particles": {"avg": 0, "p95": 0}, "gpu": null},
  "particles": {"liveAvg": 0, "liveMax": 0}, "simTickFinal": 1980, "simHash": "", "goldenHash": "", "hashMatch": true, "notes": "" }
```
- **Where results go.** Smoke runs go to `results/smoke/` (a few seconds is enough). The final timed runs happen later, one after another, on a quiet machine, run by the Research director, into `results/final/`. Do not produce "final" numbers during builds.
- **Screenshots** (`--screenshot <png>` / `?shot=1`, saved to `results/screens/<stack>-<scene>.png`), each at 1920x1080:
  - `flight` with the seam in view: set the camera near x = 0;
  - `worst` at tick 1200;
  - `sweep` while the boxes are about half the planet apart.

## Every build's README.md
How to run (demo, tests, bench, screenshots), what passed (with the output), how each feature was built, the determinism notes (float behaviour, replay, what was verified), export notes, tooling and art-pipeline observations, and known gaps.
