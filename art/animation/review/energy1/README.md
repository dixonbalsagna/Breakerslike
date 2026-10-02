# energy1: the energy direction as parked poses (docs/design/agency-pass.md section 15)

Nothing fires these yet. The wave (`render/anim/tools/waves/energy1.mjs`, prefix `en`: 3 sequences, 8 poses, generated to `data/anim/waves/energy1.*.json`) is loaded only with `--waves` (the tools), never in a live match. Legal: RL-060 to RL-062 (`docs/legal/agency-pass-screen.md`).

1. **The sheet** `energy1-sheet.png`: the eight poses, near and far side.
2. **Three GIFs**, each played by `agency_lab.gd --waves` (the sequence started by hand on tick 10): `swat.gif`, `mine.gif`, `spray.gif` (four bolts, six ticks apart).

- **swat** (15.2, the shot knocked wild): the near forearm held out low with the elbow tucked at the ribs, then swung up through the line of the shot about the elbow in one chop, the hips turning with it, the fist closed. The plate meets the shot. No open palm held out, no backhand flick (the wrist stays locked), nothing said.
- **mine** (15.5, energy held plus the context button): one hand reaches low and ahead and sets the plate down, the head bowed over it, the knees giving a little; the other hand is open at shoulder height for balance. Hands far apart (one low, one high), never cupped, never at a hip, nothing raised overhead, no sphere forming between the palms; the hands are open, so it is not the fists-at-the-sides crouch.
- **spray** (15.4, rapid bolts in a cone): one lead arm out level with the loose clawed hand along the line, the rear hand thrown wide for balance, the feet planted wide. A bolt's beat is 6 ticks (the sim's fastest cadence): the arm kicks up and the shoulder rocks back for 2, then settles for 4; a run of bolts replays it. The settle pose is the firing stance. Not both palms pumping, no open-mouth scream (the head stays down along the arm), no pointing finger.

Machine pass: `pose_lint` 0 findings (reach, joint range, Legal's `_legal` lists), `silhouette_lint` 0 pairs, `stacking_lint` unchanged, `joint_scan --strict` 0 past a limit (poses, sequences and live). For Orb, when the cues land: whether the swat reads as a forearm and not a reach, and whether the mine's low reach says "setting something down".
