# Pose estimates for the rich moveset, and how Orb's review drops from about 35 hours to about 3

Status: proposed, 2026-10-02, answering Combat's `docs/combat/m0-rich.md` (the Anti-hero's first moveset, rich end: 38 key strikes, 31 energy strikes, 15 entries, 6 feints, a 16-piece grab family, 4 taunts, 3 beam answers, 3 pulse clashes, 3 finisher shapes, 8 specials, 8 signatures, 16 showcases) and the EP's brief that Orb wants the game 90% or more vibe-coded (ADR 0007: no human authorship required).

## 1. The pose estimates, re-done with what exists now

Since the estimate of 440 to 570 poses was made, the following exist: contact IK to the defender's body (a strike needs its contact pose, not a different pose per distance), computed hit reactions (no authored reaction per hit), blow weight scaling (a light and a heavy version of a strike are one pose set), per-fighter ragdoll shapes (tumbles, braces, crumples are not authored per move), the pose families with limb tags, and the inertialisation. A pose is now only needed where a move has a silhouette of its own.

| Piece | Count | Poses each before | Poses each now | Why | Total now |
| :--- | ---: | ---: | ---: | :--- | ---: |
| Key strikes | 38 | 2 to 3 | 0.7 | six families (jab, cross, hook, upper, kick, round) with limb and target tags cover most; a strike that is a new silhouette needs its contact pose only: the chamber and the follow-through are derived from it by the weight scaling | 27 |
| Energy strikes | 31 | 1 | 0.3 | hand, aura and effect changes on the shared poses | 10 |
| Entries | 15 | 2 | 1.3 | a start and an arrival; the flight between is the dash, burst and brake poses | 20 |
| Feints | 6 | 1 | 0 | the chambers of the strikes they feint, at reduced amplitude | 0 |
| Grab family | 16 | 3 | 2 | the grabber's reach and carry; the victim is a pinned ragdoll (section 3) | 32 |
| Taunts | 4 | 2 | 2 | emotes are all hand-shaped | 8 |
| Beam answers, pulse clashes | 6 | 2 | 2 | | 12 |
| Finishers | 3 | 10 | 6 | the victim is the ragdoll; the finisher poses are the winner's | 18 |
| Specials | 8 | 10 | 6 | a special is a phrase: stance change, a move, a finish; the move reuses a family | 48 |
| Signatures | 8 | 9 | 7 | the charge, the release and the pose after; the beam aim is computed | 56 |
| Showcases | 16 | 5 | 4 | the contact poses; the in-betweens are procedural | 64 |
| **Total** | | **440 to 570** | | | **about 295** |

So the estimate drops by about half, and the pose count is not the cost that matters: Orb's time is (section 2). At the confirmed 3 minutes a pose with a second look, 295 poses would still be about 15 hours, so review is not by pose at all.

## 2. Orb's review: from 30 to 36 hours to about 3

The principle: **machines do the first pass, Orb sees reels and exceptions, never single poses.** The confirmed review format (a contact sheet of 12 poses plus a motion reel per showcase) stays as the artefact Orb looks at, but only for what the checks cannot judge, which is taste.

1. **Automatic gates first** (headless, in the director's own session and in CI, no human):
   | Check | Exists | What it catches |
   | :--- | :--- | :--- |
   | `anim_check` | yes | gameplay hash unchanged, contact error under 0.02 rad, contact gap, NaN, no sim writes, replay equality at any frame rate, quality levels |
   | `limb_scan` | yes | an elbow or knee out of range, an arm straight back |
   | `pop_scan` | yes | a pose jump at a join |
   | `solve_bench` | yes | cost against the budget by layer |
   | silhouette distinctness | to build (one unit) | every pose rendered flat black at 80 px, pairwise overlap: flags two moves that read the same, and any pose too close to another fighter's |
   | Legal's stacking rule as a lint | to build (one unit) | each pose and cue carries its marks (crouch with fists at the sides, scream, flame aura, rubble ring, lightning, hair change, gold or white flash with a name shouted); a moment with more than two is flagged |
   | `_orig` and provenance record | partly (records exist) | every new pose has its origin line and a record |
   | contact sheets and reels | yes (`pose_sheet`, `anim_reel`, `ragdoll_lab`) | produced automatically per wave |
2. **A second reviewer that is not Orb**: the Art Director and Legal sessions read each wave's sheets and reel against a rubric (silhouette, readability at 40 px, originality, the stacking rule, personality fit) and send back fixes. Orb sees only what survives.
3. **Orb sees three things per wave**, about 25 minutes:
   - the wave's reel (8 minutes: every move of the wave in one reel, in context, on the fighter's own shape);
   - the exceptions sheet (10 minutes): only the poses a check or a reviewer flagged and the director could not settle, with the reason (the target is under 10% of the wave);
   - the decisions (5 minutes): three to five A/B pairs of GIFs where a taste call is open, answered by a letter.
4. **Six waves** (strikes, energy strikes and entries, grabs and taunts, beam answers and clashes, specials and signatures, finishers and showcases) is about 2.5 hours, plus a final showcase reel of about 30 minutes: **about 3 hours instead of 30 to 36.** Orb's notes are free text on the reel; the director turns them into changes and re-cuts only the affected moves.
5. **Guardrails set once at the start** (the one-time cost, in the 3 hours): three anchor choices per fighter that every later move is held to (the stance's weight, the speed of the snap, the hand shape), taken from the first reel.

What this needs built: the silhouette lint and the stacking lint (two units), an "exceptions" collector that gathers the flagged poses into one sheet (half a unit), and a wave reel script (the lab and the reel tool already do the parts). It does not need Orb to author anything.

The risk to watch: taste can drift in the poses no check flags. The mitigation is the final showcase reel and the anchors; if a wave's reel disappoints, only that wave is redone.

## 3. Combat's asks

| Ask | Answer |
| :--- | :--- |
| Effectors for elbow, knee, head, shoulder, tail | Elbow and knee: yes today, as pole targets in a pose's sketch (`pole_hand_*`, `pole_foot_*`), no new work. Head: the look-at effector exists (it follows the opponent); a head target for a move (look at a point) is a small addition. Shoulder: a clavicle hunch effector, about one unit. Tail: the rig has no tail bone; it needs a chain of extra bones on the rig (Art's cosmetics plan already allows the `x_` extras) and a spring chain, about one unit once Art adds the bones and a `tail_root` socket |
| Arm and leg target sockets | The contact solve already targets the defender's head, chest and gut. More points (back, shoulder, hip, thigh, foot, for grabs and trips) are a table in data, about one unit |
| A pinned ragdoll for throws | Yes: the victim's ragdoll loose with the root pinned to the grabber's hand socket, released on the throw. The sim owns the position, so it needs a `held` state on the victim (who holds him, which socket, the release tick) and the victim placed at the hand each tick; the animator then builds the pinned mode (about one unit) |
| A reaction-strength input | The reaction already scales by force (damage over 60). To let Combat set it per atom, add a `react` field (0 to 1.6) to the damage event, or `o.react` on the strike beat; until then force from damage is used |
| The broken side read from the sim | Yes please: a side per limb region in the wounds state (arms: left, right or none; legs likewise). Today the animator picks the side by a hash of the slot |

## 4. Status (2026-10-01)

The pipeline of section 2 is built: the silhouette lint, the stacking lint (with `data/anim/moments.json`), the pose lint, the exceptions collector, the wave reel and the A/B pair maker (`render/anim/tools/review.mjs`; details and the proof run on the 94 poses in pose-pipeline.md section 9.12). The effectors Combat asked for are in too: elbow and knee as aim-only strike limbs, head likewise, a clavicle hunch, and a socket table (`data/anim/sockets.json`) with a new `legs` region; `socket_check.gd` prints the reach envelope of each. The three sim-side asks (the `held` state, the `react` field, the broken side) stay with Simulation and Encounter for M0.
