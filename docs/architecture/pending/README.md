# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot (`docs/` is hidden from Godot). It holds slices that are built and proven in a scratch copy and wait for the sim slot.

What is asked of the core and not yet built is listed in `core-backlog.md`.

## Shots, the second round: buildings, wild deflects, the spray, mines

Design and proofs: `docs/architecture/shots.md` sections 13 to 18. Proven on 2c91129 (after Encounter's slice 7); applied to 7c300a2 it gives the same files byte for byte.

| File | What it is |
| :--- | :--- |
| `shots2.py` | The slice, in four parts. `python docs/architecture/pending/shots2.py . <part>` from the repo root. Every edit is anchored on the text it replaces and stops if the text has moved |
| `shots2_schema.cjs` | Tools' side: the new keys in `tools/schemas/fight-shots.schema.json`, and one self-test case in `tools/fixtures/cases.json`. `node docs/architecture/pending/shots2_schema.cjs .` Needs Tools' grant |

**It edits:** `sim/core/shots.gd`, `state.gd`, `fx.gd`, `hash.gd`, `view/fx.gd`, `tools/parity.gd`, `data/fight/shots.json`, and the two Tools files. One line of Encounter's in `shots.gd` changes (the let-pass branch, `shots.md` section 15).

**The parts, in order.**

| Part | What it does | The proof to repeat |
| :--- | :--- | :--- |
| `code`, with the schema script | All four pieces, with `structures` and `deflect.scatter` off in the data. Nothing lays a mine or passes a spread | Parity passes but for the fight data hash. Regenerate: `golden_cmp.py` shows every checkpoint equal, light and full |
| `hash` | The ten new shot fields and the two new events join the hash | Regenerate: light digests and tick counts identical |
| `scatter` | `deflect.scatter` on: a deflect sends the shot wild | A behaviour change: regenerate. 7 of 9 golden matches move. Best with Encounter's lines for 15.2 (the free approach, the feed text) |
| `structures` | `structures` on: straight and lobbed shots stop at buildings | A behaviour change: regenerate. **Only in World's window,** with its body in `SimShots.hitStructure` |

`code` and `hash` can be one commit with one regeneration. `scatter` and `structures` are separate decisions. The 100-match figures for each are in `shots.md` section 18.

**Gates, each from the repo root:** `--import` is not needed (no new class). Then `golden.gd`, `parity.gd -- --no-bench` (it has the new check "shots: buildings, wild deflects, the spray, mines"), `render/tools/determinism.gd`, `sim/director/tools/loader_check.gd -- 50 1`, `npm test --prefix sim`, `node tools/validate.js` and `--self-test`.

Delete both files and this section once the parts are applied.
