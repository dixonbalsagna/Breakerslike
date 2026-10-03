# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot (`docs/` is hidden from Godot). It holds slices that are built and proven in a scratch copy and wait for the sim slot.

Nothing is pending as a script. Shots, the second round, was applied on cf0466f with both of its switches off (`docs/architecture/shots.md` sections 13 to 18), and `shots2.py` and `shots2_schema.cjs` are deleted.

**What is left of it is two data flips,** each a behaviour change with one golden regeneration, in `data/fight/shots.json`:

| Flip | When | Proven in scratch on 2c91129 |
| :--- | :--- | :--- |
| `"structures": false` to `true` | In World's window, with World's `WorldBlast.shotBuilding` as the body of `SimShots.hitStructure` (one line in `sim/core/shots.gd`, by grant) | 4 of 9 golden matches move; parity and determinism pass |
| `"scatter": false` (under `deflect`) to `true` | With Encounter's lines for agency-pass 15.2 (the free approach, the context deflect, the feed text), after QA's measuring | 7 of 9 golden matches move; parity, determinism and the loader check pass |

The 100-match figures for each are in `shots.md` section 18.

**Next core commit, from Game Design's section 17** (code; the data values are already in): the mine's fuse by cause (8 ticks for a body, 0 for a shot), `chainR` held at 3 bh at every tier instead of growing with `tierR`, the wild flight at 0.8 of the shot's own speed (in place of `deflect.speed`), and `arcPer` split into near 0.15 and far 0.35. About 15 lines, Tools' schema for the new keys, neutral while `scatter` is off and nothing lays a mine.

What is asked of the core and not yet built is listed in `core-backlog.md`.
