# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot. It holds slices that are built and proven in a scratch copy and wait for the sim slot. Each script edits files by exact text and stops if a line it expects has changed, so it is safe to run on a later HEAD: it either applies cleanly or says which line moved.

## L0 and L2 (fight lanes, `docs/architecture/fight-lanes.md`)

Built and proven on a `git archive` of 5fe078a (2026-10-02). All of it is in my files (`sim/core`); no other owner's file is touched.

| Step | Run from the repo root | Then | Result on 5fe078a |
| :--- | :--- | :--- | :--- |
| 1 | `python docs/architecture/pending/l0_a.py .` | import; `parity.gd` | passes on the untouched goldens: 9 matches, 177,656 ticks identical (the code is neutral) |
| 2 | `python docs/architecture/pending/l0_b.py . state` | `golden.gd`; `python docs/architecture/pending/golden_cmp.py <old golden.json> sim/core/test/golden.json` | every light digest and tick count identical; only the full-state checkpoints move (the new fields are hashed) |
| 3 | `python docs/architecture/pending/l0_b.py . events` | `golden.gd`; `parity.gd` | L0's goldens. The light digest folds the events, which now carry `z`, so it moves here by design |
| 4 | `python docs/architecture/pending/l2.py .` | `parity.gd` | passes on L0's goldens untouched (L2 is neutral), with the new check "depth in the core" |

Also green in the scratch copy after step 4: determinism, the seam sweep, `npm test` (5 stages), the validator, the touch test and the loader check.

**What L0 adds:** `S.depthOn` (from the setup's `"depth"`; the director's data switch joins at L4), `SimConst.Z_FRONT` and `Z_BACK` (until World's lane table), `Fighter.zT` and `zWay`, `Rush.pz`, `Exchange.z`, `Beam.oz` and `zs`, `Slide.z0` and `z1`, `z` on fifteen positioned events (the emitters that take a position take `z` last, 0 by default; the ones that take a fighter read his), and `ux`, `uy`, `n` on `launch`.

**What L2 adds, only when `S.depthOn`:** `SimFighter.stepDepth` (a free fighter eases to `zT`; in an exchange his home is `ex.z`; a flight's end is the new home; the band clamps), and the rush homing in depth.

**Left for other slices** (they need another owner's file): `groundY(S, x, z)` (World, with the terrain rows); the waypoint for unaimed flights (`WorldBrunt.stepZ` reading `zWay`, World's L3); `launch_depth` for every launch (Encounter's L4); World's data hash in the replay header (when World has a `dataHash()`).
