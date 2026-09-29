# P0 wave 1 brief: performance-platform

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): this is your first brief. Set the performance budgets, measure the prototype's sim cost, define the canonical worst-case scene, and give the EP a profiling method to judge Research's engine spike.

GOAL: Publish a first docs/perf/budgets.md backed by a measured headless tick cost, one canonical worst-case scene, a reusable profiling method and hardware tiers, so every director has numbers to build against.

CONTEXT (read first):
- CLAUDE.md (architecture, prototype code map) and your charter docs/directors/performance-platform.md.
- prototype/index.html, read only. Lines after 216 moved down by one tonight.
  - Fixed step DT = 1/60. World W = 9600, COL = 8, NC = 1200 columns (Float32Array base and deform).
  - crater() deforms columns, with a floor of -260. The particle cap is parts.length > 2400 inside P() (236).
  - step() (881) calls control, stepFighter, dirUpdate, beamStep, stepParts and the clash spark. camStep sets zoom.
  - Draw functions: render, drawTerrain, drawParts, drawBeams, drawWater.
  - There are 47 structures and 425 civilians.
- prototype/tools/headless.js load() exposes window.__wf and stubs the canvas. match-runner.js runMatch(h, seed, {arm, setup}) stages scenarios, and sim-stats.js is the batch runner. Use them read-only and never edit prototype/. Tools may install @napi-rs/canvas tonight, after which headless.js creates a real canvas. The runner never calls render(), so step timing should not change, but record whether the package was installed.
- qa/baseline-p0.md: matches average 55.4 s to KO (p90 77 s). The AI fights mostly over the ocean, so the baseline underrepresents the city and the worst case.
- Research is already running its engine spike tonight: Godot 4.7.2 and a web build, frame times as avg and p95 at 1080p, and a worst-case effects scene of its own. Your method arrives after its first numbers, so it must work both as a review template for those numbers and as the spec for a re-measure.
- VFX is writing per-effect particle budgets tonight that must fit inside your particle row.
- About twenty other sessions share this machine tonight (QA's 1000-match soak, Simulation's parity runs, Research's Godot spike). Timing taken now is contaminated, so record the load and treat your numbers as provisional. The EP will schedule a quiet re-run.
- docs/legal/originality-rules.md (no franchise material).
- Machine: Windows 11, Ryzen 7 9800X3D (8 cores, 16 threads), 31 GB RAM, NVIDIA RTX 5070 Ti plus AMD integrated Radeon. Confirm and record the GPU and VRAM yourself. This is a high-end machine, so do not derive minimum hardware from it.
- Dependencies, all routed through me: Simulation's port in sim/ (re-measure when it lands), Research's spike, VFX and World budgets.

YOU OWN: docs/perf/ only, including docs/perf/tools/ for any measuring script. Nothing outside it.

ACCEPTANCE CRITERIA:
1. docs/perf/budgets.md has one table with a row each for sim tick, draw calls, particles, terrain deformation, and memory (CPU RAM and VRAM). Each row gives a target, a hard limit, an owner and a measurement method, and provisional numbers are marked.
2. The canonical worst-case scene, which VFX and Research will reference: both fighters at tier 4, full collateral, a beam clash in the city (x 2350 to 3850), zoomed out, particles at the cap. Reproduce it from a seed plus a scripted setup through runMatch's setup hook, in a docs/perf/tools/ script, and give the exact command and the tick at which the clash peaks.
3. Measure the headless sim tick with a docs/perf/tools/ script, timing outside the sim with no sim RNG use and hashes unchanged.
   - Report mean, p50, p99 and max ms per step() over at least 200 seeded matches, and separately for beam-clash ticks and full-particle ticks.
   - State the Node version, the seeds, whether @napi-rs/canvas was installed, and the concurrent machine load at the time (count of other node and Godot processes, and CPU use).
   - Compare the result with the 16.6 ms frame budget. The script reruns with one command.
4. State how the prototype's particle cap, crater floor and 1200-column heightfield map to budget rows, and what the budgets imply for a larger, real-engine world, including level of detail for zoomed-out planet views.
5. A profiling method that works two ways:
   - as a review template for Research's reported avg and p95 frame times, saying what they can and cannot show;
   - as the re-measure spec: scene (your worst case), warm-up, sample counts, metrics (frame time p50/p95/p99, draw calls, VRAM, GC or allocation), which GPU (discrete or integrated, and how to force it), vsync and power settings, tools, and a pass or fail template.
6. Minimum and target hardware as options, marked 'Orb decides' where Orb's platform answer is pending. Include PC-only, PC plus handheld, and web variants, with the trade-off of each.
7. A proposed build-gate rule with a regression threshold, how it would run alongside node qa/run-all.js, and a note on timing noise on shared CI runners. This is a proposal only, since QA and Tools own the wiring.

CONSTRAINTS: No git state changes. Do not optimise before profiling. Keep the sim deterministic and separate from rendering: timing code must not change sim state or hashes. Everything stays original.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

Research reports this machine has a Ryzen 7 9800X3D, an RTX 5070 Ti and an integrated Radeon. Research is running Godot and web builds tonight. Ask me for the quiet window; I'm coordinating it for you, Research and QA.
