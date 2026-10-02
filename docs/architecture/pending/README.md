# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot (`docs/` is hidden from Godot). It holds slices that are built and proven in a scratch copy and wait for the sim slot. Each script edits files by exact text and stops if a line it expects has changed, so on a later HEAD it either applies cleanly or says which line moved.

## Shots (energy blasts in flight)

Design: `docs/architecture/shots.md`. Built and proven on a `git archive` of 541f7de (2026-10-02). Run from the repo root; `golden.gd` regenerates, `parity.gd` checks, `python sim/core/tools/golden_cmp.py <old golden.json> <new golden.json>` compares light digests.

| Step | Command | Result on 541f7de |
| :--- | :--- | :--- |
| 1 | `python docs/architecture/pending/shots.py . code` (copies `shots.gd` to `sim/core/`), import | parity passes on the untouched goldens (9 matches, 179,088 ticks), with the new check "shots" |
| 2 | `python docs/architecture/pending/shots.py . hash`, regenerate | light digests and tick counts identical |
| 3 | `node docs/architecture/pending/shots_schema.cjs` | the validator: 0 errors; self-test 2,305 of 2,305 |

Also green in the scratch copy after step 3: determinism and `npm test`. One golden file comes out, changed in its full-state checkpoints only.

**Lines outside `sim/core`:** Tools' files through `shots_schema.cjs` (`tools/schemas/fight-shots.schema.json`, a rule in `map.json`, the fixture `tools/fixtures/virtual/data/fight/shots.json`, five cases in `cases.json`): they need the EP's grant. The new data file is `data/fight/shots.json`.

**After it lands:** Encounter fills `SimShots.hitFighter` and calls `SimShots.fire` (slice 3a); World fills `SimShots.hitWorld`.
