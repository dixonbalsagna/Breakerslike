# ADR 0006: The GDScript sim is the source of truth; the JS core is frozen

Status: accepted by the EP, 2026-09-29. Drafted by Simulation & Engine. It follows ADR 0005 (token discipline) and builds on ADR 0001.

## Context
- ADR 0001 chose Godot 4.7 with GDScript. The sim was ported from the JS reference core under a golden-hash contract, and the two became bit-identical: math, RNG, world generation, 17 AI matches, 2 human-input replays and the cosmetic event stream.
- Orb has asked for big gameplay changes: no health meters, procedural movesets, craters instead of canyons, and simple water flow.
- Under the twin rule, every change would have to be written twice (JS and GDScript) and the goldens regenerated from JS. On a Pro plan with no budget (ADR 0005), that doubles the cost of every gameplay change for no gain in the shipped game.

## Decision
- **The GDScript sim is the source of truth.** Gameplay changes land in `sim/**/*.gd` only.
- **The goldens come from GDScript.**
  - `tools/golden.gd` writes `sim/core/test/golden.json`.
  - `tools/parity.gd` checks it on every push (CI, Linux) and locally (Windows).
  - Both use the same recipes (`tools/golden_recipes.gd`).
  - The golden file changes only in the same commit as an intended behaviour change, with the reason in the commit message.
- **The JS core is frozen** at commit 9ac1ea9 as the prototype-parity record:
  - It stays tick-exact with the prototype (`fxRng: 'shared'`, `math: 'native'`).
  - Its own frozen golden record (`sim/core/test/frozen/golden-js.json`) is kept as a one-time proof: the GDScript sim reproduced it exactly when the JS core was frozen.
  - `npm test --prefix sim` keeps checking that the frozen core is unchanged. It is a guard, not a gate on gameplay.
  - The JS-against-GDScript comparison stops being a live gate.
- **QA and balance move off Node.** `tools/batch.gd` runs seeded AI-vs-AI batches on the GDScript sim with sim-stats-style summaries and JSON output. On the same 100 seeds its statistics matched QA's JS aggregator exactly.
- **The GDScript determinism rules stay binding** (determinism.md section 0): float64 scalars, restricted operations, `SimDetMath` and `SimRng`, the JS-exact helpers, no long float literals (linted), qualified built-in names, explicit stable ordering.

## Consequences
- Each gameplay change is written once. The GDScript sim's own history is the only record of how behaviour evolves after 9ac1ea9.
- The prototype and the frozen JS core drift from the game from the first gameplay change on. The prototype remains QA's legacy baseline (`node qa/run-all.js`) until QA moves its baselines to `batch.gd`.
- **Speed.** The GDScript batch runner plays about 350 matches per minute on the development desktop, against about 5,000 for the JS core. A 1000-match balance run takes about 3 minutes instead of about 12 seconds. That is acceptable for QA's baselines; for large sweeps, several Godot processes can run in parallel.
- **Cross-platform determinism** now rests on the GDScript sim alone. Windows (local) and Linux (CI) check the same golden file. The web build and macOS/ARM are not yet checked in CI; add them before those platforms ship.
- **What stays.** fx-events.md, the replay format and the tick contract are unchanged. `sim/core/view/fx.gd` remains the reference cosmetic consumer and is part of the goldens until Rendering replaces it.

## Revisit if
- A second implementation is needed again: a native GDExtension sim for rollback (ADR 0001's fallback), or a web-only build. The golden file is then the contract that implementation must reproduce.
