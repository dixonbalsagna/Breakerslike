# Godot 4.7.2 spike build (ADR 0001)

Throwaway research code. Nothing outside `research/` may import it. It is the Godot half of the engine spike in
`../SPEC.md`: a 2.5D side-on renderer over the shared reference sim, with a demo, a bench mode, a screenshot mode, a
sim-only benchmark, and Windows and Web exports.

Two agents wrote this folder:
- **Sim port:** `sim/`, `view/camera.gd` and `tests/`, by the sim-port agent. They have their own notes in the file headers.
- **Application:** everything else here, by the render agent. This README covers the application and how to run everything.

All numbers below are **smoke** runs, taken with short windows on a machine shared with other sessions. They only
check the harness. They are not results. The Research director runs the final timed runs (`../tools/run-final.mjs`).

## How to run

```
set G=C:\Users\itsha\AppData\Local\Programs\Godot\4.7.2
set P=<repo>\research\engine-spike\godot
```
Use `Godot_v4.7.2-stable_win64_console.exe` when you want stdout in a terminal. The GUI exe behaves the same but
Windows does not attach its output to the console. Every mode that is not the demo quits by itself.

| What | Command |
|---|---|
| Import (first run, or after file changes) | `%G%\Godot_v4.7.2-stable_win64_console.exe --headless --path %P% --import` |
| Demo (scene 1, flight) | `%G%\Godot_v4.7.2-stable_win64.exe --path %P%` |
| Demo, self-driving check | `... --path %P% -- --cycle 2 --quit-after-sec 12.5` (cycles scenes 1 to 6, prints one `DEMO` line per scene) |
| Demo, injected hotkeys | `... --path %P% -- --inject-keys 2,3,4,5,6,1,H,H,D,C --quit-after-sec 12.5` (real key events through `Input.parse_input_event`) |
| Sim tests (sim port) | `%G%\..._console.exe --headless --path %P% -s res://tests/run_tests.gd [-- --bench]` |
| Bench | `%G%\Godot_v4.7.2-stable_win64.exe --path %P% --resolution 1920x1080 [--rendering-method forward_plus\|gl_compatibility\|mobile] [--rendering-driver vulkan\|d3d12] [--gpu-index 0\|1] -- --bench --scene worst --out <abs.json> [--warmup 180] [--measure 1800] [--look production]` |
| Screenshot | `... --path %P% --resolution 1920x1080 -- --screenshot <abs.png> --scene flight\|worst\|sweep\|... [--at <tick>]` |
| Sim-only bench | `... --headless --path %P% -- --simbench --out <abs.json> [--reps 5] [--ticks 3600]` (release: `build\win\spike.exe --headless -- --simbench --out <abs.json>`) |
| Export Windows | `%G%\..._console.exe --headless --path %P% --export-release "Windows Desktop" %P%\build\win\spike.exe` |
| Export Web | `%G%\..._console.exe --headless --path %P% --export-release "Web" %P%\build\web\index.html` |
| Release bench | `%P%\build\win\spike.exe --resolution 1920x1080 --gpu-index 0 -- --bench --scene worst --out <abs.json>` (all the same user args) |
| Web | `node research/engine-spike/tools/serve.mjs --port 8632`, then `http://localhost:8632/godot/build/web/index.html` with `?bench=1&scene=worst[&warmup=180&measure=1800]` (sets `window.__benchResult`) or `?shot=1&scene=flight[&at=410]` (sets `window.__shotResult`). The driver is `node research/engine-spike/tools/bench-browser.mjs --url <url> --out <json> --flag --force_high_performance_gpu` (add `--wait-for __shotResult --shot <png>` for a screenshot). |

Demo keys: `1` to `6` switch scene (flight, worst, sweep, chase, orbit, climb). `H` toggles the HUD. In flight,
WASD or the arrow keys fly box a (the first key press hands it to the player, as `setInput` does) and `C` makes a crater
under box a. `Esc` quits.

GPU choice is left to the command line: `--gpu-index 0` is the RTX 5070 Ti and `--gpu-index 1` is the AMD iGPU,
for both Vulkan and D3D12. Browsers take `--force_high_performance_gpu` or `--force_low_power_gpu`. The code never
picks an adapter. OpenGL (Compatibility) ignores `--gpu-index` and uses whatever adapter the driver gives it: the RTX
here.

## What passed (output from this session)

- **Import.** `--headless --import` exits 0, with zero `SCRIPT ERROR`, `ERROR:` or `WARNING:` lines.
- **Sim port tests.** `-s res://tests/run_tests.gd` exits 0 with 22 `PASS` lines (16 goldens and 6 camera tests). They still pass with the application in the project.
- **Bench.** Every run reports `hashMatch: true` against `worst@1980` (`19a92e5c...9f1dac`). That covers Forward+ (Vulkan and D3D12), Mobile and Compatibility, the editor and release builds, the RTX and the iGPU, and the Web build in Chrome on both GPUs. The logs have no `ERROR` or `SCRIPT ERROR` lines. For example:
  ```
  BENCH renderer=forward_plus driver=vulkan gpu=NVIDIA GeForce RTX 5070 Ti frames=25769 avg=0.194ms p95=0.303ms p99=0.438ms fps=5154 gpu={ "avg": 0.1354, "p95": 0.14 } live_avg=24220 hash=19a92e5c...9f1dac match=true   (release exe)
  BENCH renderer=gl_compatibility driver=opengl3 gpu=NVIDIA GeForce RTX 5070 Ti frames=19956 avg=0.251ms ... match=true                         (release exe)
  [bench-browser] frames 6165  avg 0.811 ms  p95 0.955  p99 1.1  fps 1233.0715  hashMatch true                                               (Web, Chrome 154, RTX via ANGLE D3D11)
  ```
- **Simbench.** Release exe, headless: `SIMBENCH {"build":"release",...,"stack":"godot 4.7.2-stable (official) gdscript template release","terrainGenMs":3.119,"ticks":3600,"worstTickUs":6.72}`.
- **Demo.** Windowed, with `--cycle 2 --quit-after-sec 12.5`, it prints one `DEMO scene=... frames=... live_max=...` line for each of the six scenes and exits 0. The `--inject-keys` run confirmed each hotkey:
  - `1` to `6` each loaded the right scene.
  - `H` hid the HUD and pressing it again showed it.
  - `D` flew box a across the seam: a.x went from 9300 to 1159.
  - `C` added one crater burst: live_max went from 600 to 750.
- **Screenshots.** `../results/screens/godot-flight.png`, `godot-worst.png` and `godot-sweep.png` are all 1920x1080. I checked each one by eye (details under Screenshots).

## Architecture

```
main.tscn      Main (Node3D, main.gd)
                 WorldEnvironment (sky shader, ambient colour, no reflections, linear tonemap, no glow)
                 Sun (DirectionalLight3D, no shadows)          Camera (Camera3D, vertical FOV 40, near 20, far 12000)
                 View (render/world_view.gd): Terrain, Water (MeshInstance3D), Beams (MultiMeshInstance3D), BoxA, BoxB
                 Particles (MultiMeshInstance3D, render/particles.gd)
                 HUD (CanvasLayer, render/hud.gd): Label, seam marker
main.gd        argument parsing (user args or the web query), fixed-step loop, demo, bench, screenshot, simbench
bench/bench.gd frame recorder and SPEC statistics
render/*.gdshader  terrain, water, sky, beam, particles
```

The scene file holds everything static: environment, light, camera, boxes, materials and the HUD. Code builds the
procedural parts: the grid meshes, the textures and the MultiMeshes.

- **Layers.** The sim (`sim/`) knows nothing about rendering. `main.gd` steps it. The camera (`view/camera.gd`) steps once per sim tick, after the sim. The renderer scripts only read `scene` and `cam`. Demo input is a player-layer action applied at a tick boundary before `step()`: `set_input`, and the `C` crater, which calls `terrain.crater` because SPEC asks for it. Only `main.gd` does this, never a render script. Any input sets `input_used`, and after that the demo stops comparing goldens.
- **Fixed step.** `_process` reads `Time.get_ticks_usec()` at the start of each frame and adds the frame's duration to an accumulator. It runs at most 8 steps of 1/60 s. Any backlog beyond that is dropped and counted, split into warm-up and measured ticks. Physics and `_physics_process` are not used.
- **Floating origin.** The Camera3D always sits at render x = 0, at height `cam.y` and distance `cam.distance()`, looking along -z. Positions are computed in float64 on the CPU as `sdx(cam.x, worldX)` and only then handed to Godot's float32 transforms:
  - boxes;
  - beam sources, with each beam's target following the shortest arc from its source;
  - the terrain grid offset (`x_off`).

  Particles pass `cam_x` to the shader, which wraps each vertex to [-4800, 4800). Nothing is ever placed at a raw world x.
- **Terrain** (`render/terrain.gdshader`). One static `ArrayMesh` of 1100 columns with 4 vertices per column line: top back (z = -400), top front (z = +120), face top, and face bottom (y = -700). The UV carries (grid column, kind), and the vertex shader places every vertex.
  - Heights come from a 1200x1 `FORMAT_RF` `ImageTexture` (base + deform, float32), read with `texelFetch` at `(col0 + i) mod 1200`.
  - `col0` and `x_off` are the only per-tick uniforms.
  - Colour is a static 1200-texel RGBA8 biome texture with 32-unit stripes, so column continuity is visible, darkened by scorch where deform < 0. High ground gets a little snow.
  - Normals come from neighbouring texels.
  - The texture is re-uploaded when `terrain.version` changes: a GDScript loop fills a `PackedFloat32Array`, then `Image.set_data` and `ImageTexture.update`. That time is measured as `upload`.
  - `mesh.custom_aabb` stops the displaced grid being culled.
- **Water** (`render/water.gdshader`). The same grid with 6 vertices per column: back face, surface at y = 0, and front face down to the sea floor. It is translucent and unshaded, and fragments over columns where base >= -30 are discarded. The index buffer is ordered by face kind, not by column. The first version was ordered by column and blended back faces over front faces on the half of the screen right of the camera, which showed as a comb artefact. Ordering by face kind fixed it.
- **Sky.** A sky shader draws a vertical gradient from `EYEDIR.y`. There is one directional light plus ambient, and no shadows, MSAA or post effects in the baseline. `--look production` turns on glow and directional shadows as a separate run.
- **Boxes.** `BoxMesh` 40x60x40 with StandardMaterial3D, `#3d8fdc` and `#a52a2a`.
- **Beams** (`render/beam.gdshader`). One `MultiMesh` of 18 unit quads in the z = 0 plane, three per beam: glow (44 wide), core (14 wide) and impact flare (radius 60). Additive and unshaded. `INSTANCE_CUSTOM` carries the mode and colour: cyan-white for owner 0, orange-white for owner 1. It takes one draw call.
- **Particles** (`render/particles.gd`, `particles.gdshader`). One `MultiMesh` of 29,800 quads, drawn in one call with a stateless ballistic vertex shader.
  - A spawn writes one texel (x, y, spawn tick, ±seed) into a 451x1 RGBA32F burst texture. The texture holds a ring buffer of slots per source: 128 crater slots of 150, 3 big-crater slots of 3000, and 320 spark slots of 5.
  - Each particle's velocity comes from a hash of (burst seed, particle index), inside the SPEC's ranges. Position = origin + v·t − 450·t². Age is presentation time (tick plus the accumulator fraction).
  - Seeds come from a `RandomNumberGenerator` with a fixed seed (20260929), reset on scene load. The sim RNG is never used.
  - Live counts are exact and analytic, from spawn ticks and each source's fixed life. The capacity covers the worst scene exactly (120 of 128, 2 of 3, 288 of 320), and `overwrites` (a live burst replaced) stayed at 0 in every run.
  - Smoke live counts in `worst`: average about 24,200, maximum 25,440 (120×150 + 2×3000 + 288×5).
  - **Why this approach:**
    - It hits the SPEC counts exactly and deterministically.
    - It costs no per-particle CPU work: about 0.013 ms per sim tick for spawns and upload.
    - It is one draw call.
    - The same shader runs unchanged on Forward+, Mobile, Compatibility and WebGL2.
  - **Not tried:** pooled one-shot `GPUParticles3D`. That would have been about 450 nodes (one per live burst), each moved every tick for the floating origin, and it would have needed a custom process shader to get the uniform box velocity distribution. `emit_particle` would have been 3000 calls for each big crater. Only one approach was built, so there is no second measurement.
- **HUD.** A Label shows fps, frame ms, scene, tick, live particles, hash status, camera and adapter. Its text is laid out at 4 Hz. A yellow tick at the top of the screen marks world x = 0 when it is in view. `H` toggles the HUD.
- **Bench** (`main.gd` `_bench_*` and `bench/bench.gd`).
  - Vsync is turned off with `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`, plus `Engine.max_fps = 0` (the project also sets vsync_mode=0 and max_fps=0).
  - A frame is measured when its tick after stepping satisfies warmup < tick ≤ warmup + measure. Its time runs from its start to the next frame's start. The first frame past the window closes the run.
  - pN = sorted[ceil(N/100·n) − 1], computed in the same float order as the JS.
  - GPU ms comes from `RenderingServer.viewport_set_measure_render_time` / `viewport_get_measured_render_time_gpu`.
  - The state is hashed at tick 1980. If a short smoke window ends earlier, the sim is fast-forwarded (not rendered, not timed) to 1980 and the notes say so.
  - The JSON follows SPEC, plus:
    - `frameTimesMs` (every measured frame, in order);
    - `gpu` (`RenderingServer.get_video_adapter_name()`; the unmasked `WEBGL_debug_renderer_info` string on the web);
    - `driver` (the rendering driver plus `OS.get_video_adapter_driver_info()`; the ANGLE backend on the web);
    - `renderingDriver`, `look`, `droppedTicksMeasured`;
    - `subMsStepFrames`: sim, upload and particle ms over only the frames that ran at least one sim step. At thousands of fps most frames run none, so the SPEC `subMs` averages are tiny and their p95 is often 0.
  - On the web the result goes to `window.__benchResult` through `JavaScriptBridge.eval`. The query string is read the same way.

## Smoke measurements (not results)

`worst` scene, 1920x1080, vsync off, warm-up 180 ticks, **measure 300 ticks (5 s)**, one run each, other sessions
active. The JSON files are in `../results/smoke/godot-*.json`. The step columns are ms per frame that ran a sim step:
sim `step()`, height upload, and particle spawn + upload.

| Run | Build | Renderer / driver | GPU | avg ms | p95 | p99 | fps | GPU ms | sim / upload / particles ms (step frames) | hash |
|---|---|---|---|---|---|---|---|---|---|---|
| editor-forward_plus | editor | forward_plus / vulkan | RTX 5070 Ti | 0.201 | 0.302 | 0.435 | 4980 | 0.137 | 0.021 / 0.029 / 0.012 | true |
| editor-forward_plus-d3d12 | editor | forward_plus / d3d12 | RTX 5070 Ti | 0.307 | 0.415 | 0.547 | 3256 | 0.098 | 0.022 / 0.029 / 0.013 | true |
| editor-gl_compatibility | editor | gl_compatibility / opengl3 | RTX 5070 Ti | 0.257 | 0.365 | 0.550 | 3899 | 0.097 | 0.021 / 0.041 / 0.017 | true |
| editor-mobile | editor | mobile / vulkan | RTX 5070 Ti | 0.170 | 0.263 | 0.388 | 5885 | 0.051 | 0.021 / 0.029 / 0.013 | true |
| editor-forward_plus-production | editor | forward_plus / vulkan, glow + shadows | RTX 5070 Ti | 0.316 | 0.466 | 0.581 | 3162 | 0.282 | 0.023 / 0.030 / 0.013 | true |
| release-forward_plus | release | forward_plus / vulkan | RTX 5070 Ti | 0.194 | 0.303 | 0.438 | 5154 | 0.135 | 0.019 / 0.024 / 0.012 | true |
| release-gl_compatibility | release | gl_compatibility / opengl3 | RTX 5070 Ti | 0.251 | 0.355 | 0.564 | 3992 | 0.096 | 0.018 / 0.038 / 0.016 | true |
| editor-forward_plus-igpu | editor | forward_plus / vulkan | AMD Radeon iGPU | 3.715 | 3.993 | 4.062 | 269 | 3.019 | 0.028 / 0.035 / 0.017 | true |
| editor-mobile-igpu | editor | mobile / vulkan | AMD Radeon iGPU | 2.333 | 2.756 | 2.839 | 429 | 1.674 | 0.023 / 0.030 / 0.014 | true |
| release-mobile-igpu | release | mobile / vulkan | AMD Radeon iGPU | 2.364 | 2.773 | 2.856 | 423 | 1.692 | 0.021 / 0.026 / 0.013 | true |
| web-chrome | web | gl_compatibility (WebGL2) / ANGLE D3D11 | RTX 5070 Ti | 0.811 | 0.955 | 1.100 | 1233 | null | 0.040 / 0.052 / 0.027 | true |
| web-chrome-igpu | web | gl_compatibility (WebGL2) / ANGLE D3D11 | AMD Radeon iGPU | 3.788 | 5.060 | 6.145 | 264 | null | 0.059 / 0.063 / 0.039 | true |

Sim only, headless, 3600 worst ticks × 5 (`--simbench`):
- **Release template:** 6.72 µs per tick, terrain generation 3.12 ms.
- **Editor (debug):** about 8.9 µs per tick (a 600-tick check in this session), terrain generation 4.3 ms. The director's quiet-machine editor figure is 9.11 µs, in `../results/final/summary.md`.
- **Node reference:** 0.38 to 0.44 µs, so GDScript is roughly 15 to 20 times slower on this sim.

At about 0.02 ms per tick, that is still far below the 16.7 ms frame budget.

What the smoke numbers suggest (to be confirmed by the final runs):
- On the RTX, every renderer is CPU- and present-bound at 3000 to 6000 fps, so the ordering between renderers means little.
- On the iGPU, the Mobile renderer is about 1.6 times faster than Forward+ (2.3 ms against 3.7 ms per frame).
- The Web build on the iGPU is close to desktop Forward+ (3.8 ms average), but its p99 is higher (6.1 ms).
- The GPU times Godot reports look low next to the frame times on the RTX. They come with a few frames of latency and cover only Godot's render passes, so treat them as indicative.
- WebGL2 returns no GPU timer data (`gpu: null`).

## Determinism notes

- **What decides the state.** The sim advances only in `_sim_tick()`, one fixed 1/60 s step at a time. Frame timing decides how many steps run in a frame, never what a step does. The camera is a separate deterministic presentation state, also stepped per tick.
- **The hash does not depend on frame rate.** `worst@1980` matched the golden in every run on this page, at frame rates from about 260 to about 5900 fps, with anywhere from 0 to 8 steps per frame:
  - Forward+ on Vulkan and D3D12, Mobile, and Compatibility;
  - the editor (debug) and release templates;
  - the Web build (wasm32 in Chrome);
  - the RTX and the iGPU;
  - runs that fast-forwarded after a short window.

  The editor demo also printed `HASH worst@600 ... MATCH` (in screenshot mode).
- **Float behaviour.** The sim port keeps float64 throughout. GDScript `float` is 64-bit in the standard single-precision engine build, and `PackedFloat64Array` holds the state. The byte-exact result on wasm32 confirms no platform-dependent maths slipped in. Rendering is float32 by design: the height texture, the transforms, and the shader particle positions. It is computed camera-relative, so magnitudes stay under about 4800 and the precision is about 0.0005 units.
- **Replay.** The sim port's `flight-input` goldens cover scripted input replay (`tests/run_tests.gd`). The demo applies human input only at tick boundaries, so a log of (tick, ix, iy, crater) would replay exactly. No recorder was built.
- **Presentation randomness.** It is seeded and reset per scene, but the per-particle hash runs on the GPU in float32. Particles are the same from run to run on one GPU, but they are not required to be bit-identical across GPUs, and that was not checked.

## Export notes

- **Presets** (`export_presets.cfg`). `Windows Desktop`: release, x86_64, pck beside the exe, console wrapper always (`spike.console.exe`), no rcedit resource editing. `Web`: release, `variant/thread_support=false` (the nothreads template), no GDExtension support, VRAM compression for desktop only. `godot/build/.gdignore` keeps the editor from importing the build output.
- **Headless export works.** `--headless --export-release "<preset>" <abs path>` exits 0 with no warnings.
- **Windows sizes:**
  - `spike.exe` 109,268,480 bytes (the official release template, unmodified);
  - `spike.console.exe` 188,928;
  - `spike.pck` 87,584.
- **Web sizes:**
  - `index.wasm` 39,514,754 bytes (10,084,297 with `gzip -9`);
  - `index.pck` 87,584 (72,302 gzipped);
  - `index.js` 279,815 (68,400 gzipped);
  - `index.html` 5,451;
  - icons and audio worklets about 50 KB in total.

  The first load is dominated by the roughly 10 MB compressed engine wasm. The whole game content is under 90 KB.
- **Web renderer.** The web build must use Compatibility (WebGL2). The project sets `rendering_method.web="gl_compatibility"`, and the export uses it: the run reports `renderer=gl_compatibility`, and the adapter is `ANGLE (..., D3D11)`. Every shader here compiled and rendered on WebGL2 with no changes: `texelFetch` on RF and RGBA32F textures, `uint` hashing, `INSTANCE_ID`, `INSTANCE_CUSTOM` and `skip_vertex_transform`. The web screenshot (`../results/screens/godot-web-flight.png`) matches the desktop one. What is missing on the web:
  - GPU timing;
  - vsync control, which the page cannot set (the browser flags decide it, so the JSON reports `vsync: null`);
  - `golden.json`, which is not shipped, so only the embedded `worst@1980` is checked.
- **Threads.** The nothreads build needs no SharedArrayBuffer. It would run on plain static hosting, though it was served here with COOP/COEP anyway. A threaded web build was not tried.
- **Templates.** Linux, macOS, Android and iOS templates are installed but were not exported or run. Mobile exports need platform SDKs, which are not set up here.

## Tooling and art-pipeline observations (from building this)

- **Scene format.**
  - `main.tscn` was written by hand as text, with ext_resources, sub_resources (Environment, Sky, ShaderMaterials, BoxMeshes, StandardMaterial3D) and nodes, and it loaded on the first try.
  - The format is diffable and reviewable, which matters for a modding scene and for AI-assisted editing.
  - Godot 4.7 writes `.uid` sidecar files for every script and shader on import. They have to be committed with the files.
  - The `load_steps` header is only a hint.
- **Shader language.** GLSL-like, with Godot built-ins (`INSTANCE_ID`, `INSTANCE_CUSTOM`, `EYEDIR`, `render_mode blend_add`, `skip_vertex_transform`). One source ran unchanged on Vulkan, D3D12, OpenGL 3.3 and WebGL2. The pitfalls:
  - Vertex-displaced meshes need `custom_aabb`, or they get culled.
  - Translucent draw order within one mesh follows the index buffer (the water fix above).
  - Godot's front faces are clockwise.

  A cel-shaded look would be a custom `light()` function in the same language. That was not built here.
- **Editor.** The editor GUI was never opened. Everything was done from the CLI:
  - `--headless --import`;
  - `--export-release`;
  - `-s` scripts;
  - user args after `--`;
  - `--rendering-method`, `--rendering-driver`, `--gpu-index`, `--resolution`, `--disable-vsync`, `--max-fps`.

  Headless covers import, export, tests and simbench.
- **What the CLI could not do.**
  - It cannot render headless: the headless display driver has no renderer. Screenshots and benches therefore open a real window for a few seconds.
  - OpenGL cannot be pinned to a GPU with `--gpu-index`.
  - The GUI exe does not print to a terminal on Windows. The console exe, or the exported `spike.console.exe`, does.
- **GDScript.** It is quick to write and was error-free here once parsed. It is about 15 to 20 times slower than JS on the sim, which is fine at this scale.
  - Typed arrays, `PackedFloat64Array` and `HashingContext` covered everything the sim needed.
  - `JavaScriptBridge` made the web hooks a few lines.
- **Procedural content.** `ArrayMesh`, `MultiMesh` and `ImageTexture.update` were all that the terrain, particles and beams needed. The 1200-texel height upload costs about 0.025 to 0.04 ms per tick in GDScript, including the loop.
- **Not tested.** Nothing here tested glTF import of low-poly or AI-generated assets, animation, gamepads or C#.

## Dependencies

None added. The work used only the official Godot 4.7.2 standard build and its official 4.7.2 export templates, which
were already installed and checksum-verified and are on the licence register. Node and Chrome were used only through
the spike's own tools (`serve.mjs`, `bench-browser.mjs`). There are no npm packages, downloads or assets.

## Screenshots

`../results/screens/`:
- **`godot-flight.png`: flight at tick 410, Forward+.**
  - The camera is 565 units from the seam, and the yellow tick at 64% of the width marks x = 0.
  - The ocean floor, craters, the water and the stripes run through x = 0 with no gap or step.
  - Both boxes and two crater bursts (600 live particles) are visible.
  - Tick 410 was picked by scanning the reference sim and camera for a frame with the seam and the ground in view.
- **`godot-worst.png`: worst at tick 1200.**
  - All six beams, both boxes and about 22,400 live particles are visible.
  - The ground is not in frame. The reference camera frames the boxes (y about 364 and 686), so its view bottom (about y = 165) is above the ground (y about 0 to 30 there), and the beams run off the bottom edge to their impacts.
  - This is the shared camera's framing, not a render fault.
- **`godot-sweep.png`: sweep at tick 96.** The boxes are 4800 apart, one at each edge. The seam is in view, and the mountains, biomes, water and front face are visible.
- **Extra checks, not required by SPEC:**
  - `godot-flight-gl_compatibility.png` (Compatibility renderer);
  - `godot-worst-mobile-igpu.png` (Mobile renderer on the iGPU);
  - `godot-web-flight.png` (Web build in Chrome).

  All three match the Forward+ images.

## Known gaps

- Boxes and the camera are drawn at the latest tick with no interpolation, so at high frame rates they move in 60 Hz steps. Particles use sub-tick time.
- GPU time is Godot's own per-viewport measurement: indicative only, and null on WebGL2.
- Only one particle technique was built (see above).
- Compatibility on the iGPU was not measured, because OpenGL cannot be pinned. The Web iGPU run covers WebGL2 on the iGPU.
- Only the Windows and Web exports were built and run. Linux (and Steam Deck), macOS, Android and iOS were not.
- Godot C# was not tested in this folder: this is the standard, non-.NET build. Whether C# can export to web and mobile in 4.7 has to come from the notes or the C# work.
- Hotkeys were checked with injected key events, not by a person. There is no gamepad input.
- The production look (glow and shadows) was only smoked once.
- The web export does not ship `golden.json`. It checks only the embedded `worst@1980`, so the web HUD shows `n/a` for the flight goldens.
- All numbers are smoke from a shared machine. The final timed runs are the director's.
