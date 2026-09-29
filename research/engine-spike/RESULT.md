# Engine spike: result (ADR 0001)

Research & Prototyping, 2026-09-29. The question: should the real build use Godot 4.7.2 or the web stack? Orb's criteria come from docs/ep/vision.md:
- **Platforms:** Windows, Linux, macOS, browser, Steam Deck and mobile.
- **Minimum hardware:** old laptops.
- **Look:** 2.5D side-on, cel-shaded low-poly, with procedurally generated assets.
- **Online:** after launch.

## Recommendation
**Godot 4.7 with GDScript, and no C#.**
- The browser is a first-class export target through the Compatibility renderer.
- Simulation's JS core in `sim/` stays the parity oracle while it is ported to GDScript under the golden-hash contract proven here.

## The two answers ADR 0001 depends on
1. **Can Godot 4.7 C# export to the web? No, and this was tested, not taken from the docs.**
   - The official .NET editor (4.7.2, SHA-512 verified) refuses the export: "Exporting to Web is currently not supported in Godot 4 when using C#/.NET."
   - The official .NET export templates (1,202,598,411 bytes, SHA-512 verified) ship **no web template at all**. The standard templates ship eight.
   - C# on Android and iOS is labelled "experimental" by the editor itself. The Android template is pinned to net9.0.
   - With the browser and mobile on Orb's list, C# is out. Evidence: `notes/csharp.md`.
2. **What does a GDScript sim tick cost on the old-laptop stand-in, in the release build?**
   - Measured, for the spike's worst-case sim (terrain, craters, beams, two fighters), release build, integrated Radeon:
     - **0.020 ms per tick** inside the running game (p95 0.025 ms);
     - 0.0066 ms headless;
     - 0.037 ms as GDScript compiled to wasm in Chrome.
   - GDScript is **18 times slower than V8** here (6.60 µs against 0.37 µs; .NET 10 takes 0.61 µs).
   - **Projection for the real sim** (not a measurement):
     - Simulation's JS core costs 2.9 µs per tick in Node, so GDScript would take about 52 µs on this CPU.
     - Old laptop CPUs are 2.6 to 3.9 times slower single-threaded. PassMark rates the 9800X3D at 4,420, the i5-7200U at 1,728 and the i3-5005U at 1,128.
     - That gives **about 0.13 to 0.20 ms per tick on desktop, and 0.25 to 0.38 ms in a browser**: 1 to 2% of a 60 Hz frame.
     - Rollback after launch, re-simulating about 8 ticks a frame, would cost about 1 to 3 ms. Fine, but it is the budget to watch.

## Evidence
Frame times for the worst-case scene at 1920x1080 with vsync off. Each row is the median of 3 runs; each run is 30 s of sim after a 3 s warm-up. Every run's GPU string was checked. Background CPU load before each run was 4 to 11%, in the EP's quiet window. The budget is 16.7 ms.

| Build | RTX 5070 Ti: avg / p95 ms | Integrated Radeon (2 CUs): avg / p95 ms |
|---|---|---|
| Godot release, Forward+ (Vulkan) | 0.19 / 0.28 | 2.81 / 3.80 |
| Godot release, Mobile renderer (Vulkan) | 0.16 / 0.25 | 2.11 / 2.57 |
| Godot release, Compatibility (OpenGL) | 0.25 / 0.35 | not selectable by CLI |
| Godot web export, Chrome (WebGL2) | 0.79 / 0.93 | 3.09 / 3.46 |
| Web stack (TS + raw WebGL2), Chrome | 0.38 / 1.20 | 1.06 / 2.00 |

- **Every option passes** with at least 4x headroom on the integrated GPU. The web stack is the lightest in a browser.
- **Determinism.** One reference sim reproduces **bit for bit**, across 16 golden hashes including an input-replay stream, in:
  - JS (Node, Chrome, Edge);
  - GDScript (editor, release, and wasm in Chrome);
  - .NET 10.

  Every timed run re-hashed tick 1980 against the golden. Rendering at 300 to 6,000 fps never changed the sim, so the fixed step holds. The contract: float64 only; + - * / sqrt floor fmod; our own 32-bit RNG; no engine vectors, which are float32 in official Godot builds.
- **Seam and camera.** Both builds render camera-relative (floating origin). The seam tests pass: the screen is identical wherever the seam sits (difference ≤ 8e-15), and no fighter jumps. Both fighters stay framed at every separation, except for a ≈0.5 s pan when the pair passes half a planet apart and the framed arc flips. That pan is a design call for Camera.
- **Other measurements:**
  - Deformation upload costs about 0.025 ms per tick in GDScript and about 0.02 ms on the web. Collision and query costs were not measured.
  - Particles are about 24k live in every run.
  - Download: the Godot web build is 39.5 MB of wasm (10.1 MB gzipped) plus an 88 KB pck; the Windows exe is 109 MB. The web stack runtime is 88 KB (33.5 KB gzipped).
- **Screenshots and data:**
  - Screenshots are in `results/screens/`.
  - Raw per-frame CSVs are in `results/final/raw/` (32 MB); the summary is in `results/final/summary.md`.
  - Rerun everything with `node research/engine-spike/tools/run-final.mjs [--only <config>]`.

## Why Godot over the web stack
- **Platforms.** One Godot project exports natively to Windows, Linux (Steam Deck), macOS, Android, iOS and the web; the templates are installed. Only the Windows and web builds were exported here. The web stack needs a wrapper per platform (Electron or Tauri on desktop, Capacitor or a PWA on mobile), and its mobile performance is unmeasured.
- **Tooling.** The editor, animation state machines and retargeting, particles, visual shaders, the import pipeline and the profiler are built in. On the web each of these is ours to build (`notes/pipeline.md` §6).
- **What Godot costs:**
  - a larger browser download (10 MB against 34 KB);
  - about 3 times the frame time in a browser on the iGPU (still well inside budget);
  - porting the JS core to GDScript. The spike showed the port is mechanical and checkable by goldens.
- **What would flip the decision:**
  - If Orb drops mobile and values the tiny browser build and one language (JS) over built-in tooling, the web stack wins.
  - If rollback becomes a launch requirement and GDScript misses its budget, move the sim to a C++ GDExtension, which exports to the web with the "dlink" template.
- **Presentation.**
  - 2D sprites would narrow the gap (PixiJS is strong).
  - Full 3D would favour Godot, but it conflicts with the browser and old laptops in either engine.
  - 2.5D is the sweet spot: one renderer (Compatibility / WebGL2) covers the browser and the minimum spec.

## Worst-case scene parameters (to map onto Performance's canonical scene)
- **Present:** 2 fighters; 6 beams firing continuously; 60 craters/s (radius 40 to 120, depth 10 to 30) plus a power-up crater (radius 300, depth 80) every 2 s; about 24k live particles.
- **Absent:** power tiers, structures, civilians.
- **Camera:** view width 1,400 to 5,300 units (the fighters are 300 to 4,600 apart). The pair's centre moves at 600 u/s, so the seam passes through the view every 16 s.
- **Rendering:** no MSAA, shadows or glow. Glow plus shadows was run once, as smoke only.

## Risks
- The numbers come from a fast desktop. The integrated GPU stands in for the graphics side only. No real old laptop, phone or Steam Deck was tested.
- The real-sim GDScript cost is a projection.
- Godot web runs only the Compatibility renderer and is single-threaded by default.
- Consoles are closed ports in either stack.
- Spike code stays in `research/`; nothing is promoted.

## Draft wording for ADR 0001, Decision
> We build Meridian in **Godot 4.7 with GDScript**. The shipped game uses no C#: Godot 4.7 cannot export C# projects to the web (the editor refuses, and the .NET export templates contain no web runtime), and the browser is a required platform. The Compatibility renderer is the baseline, so one render path covers the browser and old laptops. Desktop may add Forward+ or Mobile as optional quality tiers. The simulation stays engine-agnostic in its rules: float64 scalars only, + − * / sqrt floor fmod, our own trig and RNG, and no engine vector types in sim state. It is ported from the JS core in `sim/`, which remains the parity oracle, and the port must match its golden hashes before the JS core is retired. We revisit this if rollback becomes a launch requirement and the GDScript tick misses its budget; the fallback is a C++ GDExtension sim core.
