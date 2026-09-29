# ADR 0001: Engine choice

Status: accepted. Recommended by the EP; confirmed by Orb on 2026-09-29.

## Context
The prototype is a single-file JavaScript canvas game. The real game needs:
- a wrapped, deformable planet
- a deterministic simulation for replays, with rollback online later
- four fighters with transformations
- heavy visual effects

Orb's answers (docs/ep/vision.md) set the platforms: Windows, Linux, macOS, the browser, Steam Deck and mobile, down to old laptops. They also set the presentation (2.5D side-on, cel-shaded low-poly, procedural assets) and put online play after launch. The project is free and open source.

## Options
1. **Godot 4.7** (MIT licence), with the sim in GDScript or C#.
2. **Stay on the web stack** (TypeScript with WebGL).
3. **Unity or Unreal.** Ruled out: neither is an open engine, and both carry licence costs for a free open-source project.

## Evidence
The evidence comes from research/engine-spike/RESULT.md, docs/architecture/determinism.md and sim/.
- **C# can't reach the browser.** Godot 4.7 cannot export C# to the web: the .NET editor refuses, and the official .NET export templates contain no web runtime (tested). C# on Android and iOS is experimental.
- **Rendering has headroom.** Every option holds 60 fps by a margin of 4x or more on the integrated GPU. p95 frame times: Godot Mobile renderer 2.6 ms, Godot web 3.5 ms, web stack 2.0 ms. There is no pop at the wrap seam.
- **Determinism holds.** A reference sim is bit-identical across JavaScript, GDScript (desktop and wasm) and .NET on 16 golden hashes.
- **GDScript is slower, but within budget.** It runs about 18 times slower than V8. The projected real-sim tick on an old-laptop CPU is about 0.13 to 0.20 ms, which fits comfortably at 60 Hz without rollback. This is a projection; it hasn't been measured on a real old laptop yet.
- **The web stack is the lightest option in a browser,** but it loses on Orb's platform list (mobile, desktop, Steam Deck) and on built-in tooling.

## Decision
We build in **Godot 4.7 with GDScript**. The shipped game uses no C#, because the browser is a required platform.
- **Rendering.** The Compatibility renderer is the baseline, so one render path covers the browser and old laptops. Desktop may add Forward+ or Mobile as optional quality tiers.
- **Simulation rules.** The sim stays engine-agnostic: float64 scalars only; only + − * / sqrt floor fmod; our own trig and RNG; no engine vector types in sim state.
- **Porting.** The GDScript sim is ported from the JS core in sim/. That core remains the parity oracle, and the port must match its golden hashes before the JS core is retired.

## Consequences
- The next step is a GDScript port of sim/ under the golden-hash contract, with the tick measured on real minimum-spec hardware.
- The Rendering and Technical Art director opens with the port, to build the greybox 2.5D renderer.
- The Godot web download is about 10 MB gzipped.

## Revisit if
- Rollback becomes a launch requirement and the GDScript tick misses its budget (roughly 1 to 3 ms per frame to re-simulate). The fallback is a C++ GDExtension sim core, which can export to the web.
- Orb drops mobile and prefers the lighter browser build and a single language. The web stack would then win.
