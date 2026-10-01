# Set pieces: the entrance, the staredown, the winner in the wreckage (plan, not built)

Status: proposed, 2026-10-01. Rule-of-cool features 7 and 8 (`docs/design/rule-of-cool.md` §3). Render only. Nothing here is built; the build waits for the sim events listed under each. Every pose gets an `_orig` line and a Legal silhouette check (RL-038): the crater landing must not copy any one famous hero landing, and the staredown must not be a duel-movie pose.

## 1. The crater-landing entrance

The match intro, before the clock starts, once per fighter, skippable. The sim's part is small (Camera, World and Animation own it): the entrance crater is real, on open ground, with no collateral.

| Beat | What the body does | Length | Pose |
| :--- | :--- | :--- | :--- |
| Drop | falls in from above, head and arms ahead, legs trailing | until the landing tick | move.descend (exists) |
| Land | on the ground-contact tick: a deep compression, one knee and one hand to the ground, head down, the other arm back for balance | 0.35 s | entrance.land (new) |
| Hold | still, breathing, the dust falling | 0.4 s | the same, with the breathing from the wear layer (fresh at the start) |
| Rise | slowly up through a half-crouch into the match stance, the head lifting last | 0.5 s | entrance.rise (new), then stance.aggressive |

- New poses: entrance.land, entrance.rise (2). The landing is keyed to World's `land` event (docs/world/ground-contact.md), so the crater and the pose land on the same frame. Inertialisation is off for the land snap, like the transformation's break.
- The two fighters land on different ticks (the rival a beat after the first). Each uses its own landing event.
- Skip: any press ends the intro and both go straight to stance.aggressive (inertialised), so a skip does not pop.
- Needs from the sim, in the order of the intro: an `intro_start` event with each fighter's landing tick and spot (the crater is real, so World's crater call and the `land` event carry it), and `intro_end` when the clock starts. Until they exist, a test tool can fake them.

## 2. The staredown

Both fighters in place, facing, a few seconds, then the clock starts.

| Beat | What the body does | Length | Pose |
| :--- | :--- | :--- | :--- |
| Set | upright, weight even, arms loose, chin level, eyes on the rival | 2.5 s | stare.set (new) |
| Tension | the hands rise a little, the weight comes forward, the breathing deepens | 1.5 s | stare.tense (new), eased in |
| Start | on the clock's first tick, snap into stance.aggressive | 3 ticks | stance.aggressive (exists), inertialised |

- New poses: stare.set, stare.tense (2). The breathing is the wear layer's (a fresh fighter breathes slowly), the weight shifts are the idle drift. No taunt gestures, no pointing.
- Facing is the visual facing rule (toward the opponent), already built.
- Needs from the sim: the `intro_stare` window (a duration) and `fight_start`. The camera cut is Camera's.

## 3. The winner in the wreckage

Beyond emote.victory (a raised fist, built): the winner stands still in what the fight made.

| Beat | What the body does | Length |
| :--- | :--- | :--- |
| Stand | the body stops: arms slack, the chest heaving with his real wear, a broken arm still hanging (the wear layers keep running) | 1.0 s, from 0.8 s after the KO |
| Survey | the head turns slowly across the scars: a sweep of about 70 degrees each way, the shoulders still | 2.5 s |
| Hold | one still frame for the camera to pull back over; then emote.victory if the personality wants it (the hero does not, the villain does) | open-ended |

- New poses: win.stand, win.survey (2). The survey is the head and neck yaw animated in code, not a pose per angle.
- Personality picks the end: that is data (a per-fighter key in the fighter's own animation record), not code.
- Needs: the KO event's winner slot (already in `S.game.ko`), and from World a read-only query for the nearest scar (a crater centre or ruined structure) so the head looks at something real. Without it the head sweeps a fixed arc.

## Cost and review

| | Poses | Review |
| :--- | ---: | :--- |
| Entrance | 2 | one contact sheet of 6 (with the existing descend and stances) plus one reel |
| Staredown | 2 | one reel |
| Winner | 2 | one reel |
| Total | 6 | about 0.5 reviewer-hour: one sheet and three short reels (the confirmed review format, pose-pipeline §6.5) |

Build order once the events exist: the winner first (it needs no new sim event, only the optional scar query), then the staredown, then the entrance (it needs `land` and the intro events).
