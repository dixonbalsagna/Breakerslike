# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot (`docs/` is hidden from Godot). It holds slices that are built and proven in a scratch copy and wait for the sim slot. Each script edits files by exact text and stops if a line it expects has changed.

## Shots: Game Design's first numbers, and a let-pass shot flying on

Built and proven on a `git archive` of 7acf512 (2026-10-02). Run from the repo root.

| Step | Command | Result on 7acf512 |
| :--- | :--- | :--- |
| 1 | `python docs/architecture/pending/shots_numbers.py .` | data only: the kinds in `data/fight/shots.json` (bolt, shard, arc, charged, lob) with Game Design's speeds and trade powers (`agency-pass.md` section 11, item 6b). The validator: 0 errors, no schema change |
| 2 | `python docs/architecture/pending/shots_release.py .` | code, neutral: `SimShots.release`, a seeking shot that is not stopped flies on as a straight shot (ruling 6a), and `Shot.passed` |
| 3 | `golden.gd`, then `parity.gd` | the light digests, tick counts and full-state checkpoints are all identical to before (no match has a shot); only the fight data hash in the goldens changes. Parity passes with the longer "shots" check |

**Why step 2 is with a data change.** Game Design ruled that a shot which is dodged or loses its target carries on as a straight shot and can hit the ground. The code as landed did the opposite: a seeking shot whose hit was let pass stayed on its target and met him again every tick. Nothing fires a shot yet, so no match changes; Encounter's 3a needs it right.
