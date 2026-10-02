# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot (`docs/` is hidden from Godot). It holds slices that are built and proven in a scratch copy and wait for the sim slot. Each script edits files by exact text and stops if a line it expects has changed, so on a later HEAD it either applies cleanly or says which line moved.

## Shots (energy blasts in flight), and the agency pass's small core lines

Designs: `docs/architecture/shots.md` (section 10 for the small lines). Built and proven on a `git archive` of 541f7de, and re-run whole on b8ea622 with the agency lines (2026-10-02). Run from the repo root; `golden.gd` regenerates, `parity.gd` checks, `python sim/core/tools/golden_cmp.py <old golden.json> <new golden.json>` compares light digests.

| Step | Command | Result on b8ea622 |
| :--- | :--- | :--- |
| 1 | `python docs/architecture/pending/shots.py . code` (copies `shots.gd` to `sim/core/`), then `python docs/architecture/pending/agency.py . code`, import | parity passes on the untouched goldens (9 matches, 180,540 ticks), with the new checks "shots" and "agency lines" |
| 2 | `shots.py . hash`, then `agency.py . hash`, regenerate | light digests and tick counts identical |
| 3 | `node docs/architecture/pending/shots_schema.cjs` | the validator: 0 errors; self-test 2,337 of 2,337 |

Also green in the scratch copy after step 3: parity on the new goldens and determinism. One golden file comes out, changed in its full-state checkpoints only.

**The agency lines** (all neutral: nothing sends the events or writes the fields yet): the events `knockback {victim, attacker, kind, amount, dur, n, x, y, z}`, `exchange_end {actor, kind}`, `flow {actor, n}` and `embed {actor, x, y, z, depth, r, energy, dur, n}`; `ActState.flow` with `SimAct.setFlow(S, f, n)` (it sends `flow` on a change); `Fighter.embedT` (ticks) and `embedCool` (a match time, far in the past at the start); `autoCharge` in `SimAct.ASSISTS`.

**Lines outside `sim/core`:** Tools' files through `shots_schema.cjs` (`tools/schemas/fight-shots.schema.json`, a rule in `map.json`, the fixture `tools/fixtures/virtual/data/fight/shots.json`, five cases in `cases.json`): granted by the EP for the slot. The new data file is `data/fight/shots.json`.

**After it lands:** World applies the embed on the two fields and the event; Encounter fills `SimShots.hitFighter` and calls `SimShots.fire` (slice 3a), and sends `knockback`, `exchange_end` and the flow.
