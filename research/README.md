# Research and prototyping

Owner: Research & Prototyping director. Spikes are fast, throwaway experiments that answer one risky question each. Each spike folder ends with a one-page `RESULT.md` that gives a recommendation and its evidence.

## Rules for spike code
- Spike code is throwaway. Nothing outside `research/` imports it, and none of it is promoted to production without review (charter anti-goal). If an idea is worth keeping, the owning director re-implements it in their own paths.
- Spikes follow the project rules: deterministic sim (fixed step, seeded RNG), sim separate from rendering, original visuals, and no third-party code or assets without a licence-register row.
- Build outputs are gitignored (see each spike's `.gitignore`).

## Spikes

| Spike | Question | Status |
|---|---|---|
| [engine-spike](engine-spike/) | Godot 4.7.2 or the web stack for the real build (ADR 0001)? | Done 2026-09-29: [RESULT.md](engine-spike/RESULT.md) |
| [info-hiding](info-hiding/) | How can hiding work when both players share one screen: split-screen, fog of war or picture-in-picture? | **Parked** 2026-09-29 (lean-team directive, ADR 0005). See "Where info-hiding stopped" below. |

### Where info-hiding stopped
- **Plan.** The spike ran as workflow `wf_0016e7a5-2be`, which a usage limit cut short before any agent finished. The plan was:
  - a shared testbed in `info-hiding/core/`;
  - three prototypes: `split/`, `fog/` (variants still, creep and sense) and `pip/` (variants local, dimlocal and radar);
  - a seeded leak benchmark comparing an honest hunter with one that peeks at the hider's part of the screen, using a terrain-matching localiser to find a hider from a glimpse of their surroundings;
  - a judge panel.
- **On disk.** Partial, untested core modules only: `core/world.mjs`, `sim.mjs`, `camera.mjs`, `localize.mjs`. None of the three presentation modes was built.
- **To restart.** Resume the workflow from its journal once the director roster allows. Before resuming, update the scoring to the EP's amendment, which uses Camera's five criteria: fairness, readability, screen cost, netcode fit under rollback (both clients hold full state), and accessibility. Fold in Camera's hiding-camera-options.md and UI & UX's HUD notes if they exist by then.
- **Early observations** (not yet evidence):
  - Today's prototype leaks the hider completely: the hidden fighter is drawn at 22% opacity, and the minimap shows a "?" at its exact position.
  - Online after launch (Orb) removes the shared-screen problem for online play, since each client draws only its own view. The open question is local couch play.

## Open unknowns
This list should shrink every phase. Each item names the spike or owner expected to close it.

| # | Unknown | Closed by | Status |
|---|---|---|---|
| U1 | Engine: Godot 4 or the web stack | engine-spike, then ADR 0001 (Orb confirms) | Answered: Godot 4.7 with GDScript (engine-spike/RESULT.md); waiting for ADR 0001 |
| U2 | Can the worst-case effects scene hold 60 fps, and on what hardware? | engine-spike (frame times, including an integrated-GPU stand-in for minimum spec) | Answered for the spike's scene: at most 3.8 ms p95 on a 2-CU iGPU in every stack. Open for real old laptops and phones |
| U3 | Can a camera frame both fighters at any separation with no pop at the seam? | engine-spike (reference camera plus seam tests) | Answered: yes, except for a ≈0.5 s pan when the fighters pass half the planet apart (design call for Camera) |
| U4 | Can the sim be bit-identical across runtimes (JS, GDScript, C#, desktop, web)? | engine-spike (golden hashes) | Answered: yes, under the portability contract (JS, GDScript on desktop and wasm, .NET). Not checked on ARM or Apple |
| U5 | Can Godot C# export to the web in 4.7? | engine-spike/notes/csharp.md | Answered: no (tested; the .NET export templates contain no web template) |
| U6 | How does hiding work on one screen? | info-hiding | Open |
| U7 | Deformation cost at planet scale (heightfield updates, collision) | engine-spike (upload cost); deeper work later | Partly answered: height upload costs about 0.02 ms per tick. Collision and queries are still open |
| U8 | Rollback with a procedural director: re-simulation cost and hidden-information leaks | Later spike (P2), with Netcode | Not started. Projected GDScript re-simulation cost: 1 to 3 ms a frame on an old laptop (engine-spike RESULT) |
| U11 | Real GDScript tick cost for the full sim (4 fighters, minions, director) | Simulation's GDScript port, measured on a real old laptop | New |
| U9 | Presentation: 2D sprites, 2.5D or full 3D | Orb, with Art; engine-spike covers what each choice changes | Answered by Orb: 2.5D side-on (docs/ep/vision.md) |
| U10 | Planet-scale rendering: zoomed-out planet view, curvature, level of detail | Later spike (P1), with Camera and Performance | Not started |
