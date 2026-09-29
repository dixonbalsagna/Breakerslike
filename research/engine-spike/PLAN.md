# Engine spike: working plan (paused)

Status on 2026-09-29: DONE. See RESULT.md. What follows is the working history.
- Done: the reference sim, camera, goldens and tests in `shared/` (all pass); SPEC.md; tools/serve.mjs; the export templates, downloaded (1,281,349,702 bytes, SHA-512 matches SHA512-SUMS.txt) and installed in %APPDATA%\Godot\export_templates\4.7.2.stable\.
- Running: the build workflow (Godot sim, Godot render, web, C#, notes, each verified by an independent agent), then the info-hiding workflow.
- Next: the final timed runs on a quiet machine (tell the EP first so QA can hold its soaks), then RESULT.md.
- EP rulings: sim-ref stays limited to terrain, wrap math and fighter motion (no civilians); Simulation's core is plain JS ES modules under sim/.
- Orb typed `ultracode` in this session, so the work runs as workflows.

## To do after the workflows finish (the EP's amendment, received during the second usage-limit pause)
- **Workflow IDs.** Build: wf_97b8a875-4f2. Info-hiding: wf_0016e7a5-2be. If either died, resume with Workflow({scriptPath, resumeFromRunId}); journal.jsonl holds each agent's results.
- **Per-frame CSV.** Add a raw per-frame array (frameTimesMs) to both bench outputs (Godot and web). run-final.mjs then writes CSV to results/final/raw/.
- **Run metadata.** Record GPU, driver, rendering driver, vsync flags and power plan (powercfg /getactivescheme). Force the RTX for primary runs: Godot --gpu-index (find the index with --verbose), Chrome --force_high_performance_gpu, and check the adapter string. Keep the iGPU runs.
- **Load snapshot.** For each run, record CPU % and counts of node, Godot, chrome, msedge, dotnet and claude processes. Mark numbers provisional until the EP's quiet window. Rerun with one command: `node research/engine-spike/tools/run-final.mjs [--only X]`.
- **Dependencies.** Any dependency lives under research/ with its own package.json and lockfile. NEEDS FROM EP lists every one (name, version, licence, source): the export templates, the .NET Godot build if the C# agent downloaded it, and TypeScript if the web agent used npx.
- **RESULT.md.** Give the worst-case scene parameters: no tiers, about 24k particles, 60 small craters/s plus 1 big crater every 2 s, no structures, view width 1400 to 5300, the centre crossing the seam every 16 s.
- **Hiding scoring.** Run an extra pass on Camera's five criteria: fairness, readability, screen cost, netcode fit, accessibility. Fold in Camera's hiding-camera-options.md and UI & UX's HUD notes if the EP forwards them, then revise info-hiding/RESULT.md.
- **Before the final runs,** message the EP for the quiet window.

The original plan follows. Where it differs from SPEC.md, SPEC.md wins.

## Machine (checked)
- Ryzen 7 9800X3D (8 cores, 16 threads), RTX 5070 Ti, AMD Radeon iGPU (candidate min-spec proxy), 31 GB RAM, display 2560x1440 at 240 Hz, 1.6 TB free.
- Godot 4.7.2 console binary runs (`4.7.2.stable.official.ed1daf0bf`). No export templates installed yet.
- Chrome and Edge installed. Node 24.19 has `node:module` stripTypeScriptTypes, global WebSocket and crypto.subtle, so the web spike and the browser benchmark driver need no npm dependencies. .NET SDK 10.0.401.

## Downloads needed (official GitHub releases, verify against SHA512-SUMS.txt in the Godot install folder)
- `Godot_v4.7.2-stable_export_templates.tpz`, 1,281,349,702 bytes, github.com/godotengine/godot/releases/download/4.7.2-stable/. Needed for release desktop builds (fair GDScript timing) and the web export.
- `Godot_v4.7.2-stable_mono_win64.zip`, 116,582,061 bytes, same source. Only for the empirical check of C# web export.

## Design
- **Reference sim** `shared/sim-ref.mjs`, plain JS, written by me before any agent starts. It uses only + - * / sqrt floor and 32-bit integer ops, so ports can match it bit for bit. Contents:
  - mulberry32, identical to the prototype's. GDScript does imul with 16-bit halves.
  - Value-noise terrain on the prototype's biome segments.
  - Craters with a (1-u²)² falloff, clamped at -260.
  - 425 civilians that flee the fighters.
  - The worst-case script: 6 beams, 60 craters/s, a big crater every 2 s. The fighters' centre moves at 600 u/s and their separation follows a triangle wave between 300 and 4600.
  - SHA-256 state hashes at ticks 600, 1800 and 3600 saved to `shared/golden.json`. The GDScript and C# ports must match them.
- **Camera** (presentation layer, stepped at the fixed tick):
  - Tracks the pair's separation continuously with `d += sdx(d, raw)`.
  - Hysteresis: flips to the other arc when |d| > HALF + 400.
  - Smoothing K = 0.0631 per tick. View width clamped to [1400, 7200].
  - Floating origin: everything renders at `sdx(cam.x, x)`.
  - Tests: invariance to where the seam sits, per-tick pan under 3% of the view, both fighters in frame except during an arc flip (counted and reported).
- **Terrain rendering**: a static grid plus a 1200-texel height texture (texelFetch, REPEAT wrap, vertex displacement). The report includes the cost of each deformation update.
- **Particles** are presentation only, with fixed counts in both stacks:
  - 150 per crater, living 2.0 s
  - 3000 per big crater, 3.0 s
  - 5 sparks per beam per tick, 0.8 s
  - about 24k live at once
- **Benchmark protocol**:
  - 1920x1080, vsync off, no MSAA or shadows in the baseline.
  - 3 s warm-up, then 30 s measured. Report average, p50, p95 and p99.
  - 3 runs each; report the median.
  - The final runs happen one after another on an otherwise idle machine, never while agents are working.
  - Targets: Godot Forward+ desktop, Godot Compatibility desktop, Godot web export in Chrome, and the web stack in Chrome. Optional extra runs on the iGPU.
  - Each run also records the sim hash, to prove rendering never changes the sim.

## Split (Agent tool subagents, disjoint paths, no worktrees)
- G `godot/`: the GDScript project, headless determinism and seam tests, desktop and web exports.
- W `web/` and `tools/`: TypeScript plus WebGL2, `serve.mjs`, and `bench-browser.mjs` driving Chrome over CDP.
- R `csharp/` and `notes/`:
  - a .NET console port of the reference sim, for determinism and throughput
  - whether Godot C# can export to the web in 4.7, with evidence
  - export, tooling and art-pipeline notes, and what changes for 2D sprites or full 3D
- H `../info-hiding/`: split-screen, fog and picture-in-picture prototypes. Starts once G and W are underway.
- Me: this plan, SPEC.md, sim-ref.mjs and goldens, the final measurements, RESULT.md and the report to the EP.

## Open question for the EP
Which language is Simulation & Engine's engine-agnostic core written in? It decides whether the core runs natively in Godot (GDScript or C#) or must be ported, so it matters for ADR 0001.
