# Review: poses-first-run

Machine pass over 94 poses: **0 errors, 16 for review, 47 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match).

Sheet of the flagged poses: exceptions-sheet.png

## For review (what Orb sees)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | down.getup | hand_r target [16, 3, 12] is 8.5 units out of reach (the limb is clamped to [16.7, 11.5, 11.6]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | slide.brake | hand_r target [-6, 4, 16] is 17.4 units out of reach (the limb is clamped to [-0.6, 20.4, 13.8]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | slide.brake | hand_l target [-2, 6, -14] is 14.2 units out of reach (the limb is clamped to [1.5, 19.7, -12.7]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | def.guard_break | hand_r target [10, 84, 18] is 10.0 units out of reach (the limb is clamped to [2.6, 77.6, 16.1]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | emote.victory | hand_r target [14, 98, 10] is 7.7 units out of reach (the limb is clamped to [10.7, 91.0, 10.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.descend | hand_r target [30, 92, 6] is 6.6 units out of reach (the limb is clamped to [27.7, 85.9, 6.7]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.sprint | hand_r target [-14, 44, 12] is 7.9 units out of reach (the limb is clamped to [-6.1, 44.5, 11.6]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.sprint | hand_l target [-16, 42, -12] is 10.1 units out of reach (the limb is clamped to [-6.0, 43.1, -11.5]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | skid.back | hand_r target [18, 4, 14] is 16.2 units out of reach (the limb is clamped to [1.9, 5.0, 12.6]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | skid.front | hand_r target [-12, 5, 14] is 8.2 units out of reach (the limb is clamped to [-3.8, 5.2, 13.2]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.burst | hand_l target [-10, 46, -10] is 6.2 units out of reach (the limb is clamped to [-3.8, 45.8, -10.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.brake | hand_r target [34, 56, 16] is 22.9 units out of reach (the limb is clamped to [11.3, 54.9, 13.5]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.brake | hand_l target [30, 52, -14] is 18.7 units out of reach (the limb is clamped to [11.4, 52.5, -12.5]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | move.brake | foot_l target [26, 3, -7] is 6.4 units out of reach (the limb is clamped to [21.1, 6.6, -6.7]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | cue.overextend | hand_l target [-24, 36, -14] is 20.2 units out of reach (the limb is clamped to [-5.8, 44.8, -12.4]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | cue.pursue | hand_l target [-26, 42, -12] is 13.6 units out of reach (the limb is clamped to [-13.1, 46.3, -11.4]) | shorten the target or accept the clamped end (`fix-reach`) |

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | charge.hold | right elbow at 154 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | down.prone | left elbow at 173 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | down.prone | right elbow at 167 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | hurt.hold | right elbow at 155 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.jab.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.jab.contact | foot_r target [-8, 3, 9] is 5.0 units out of reach (the limb is clamped to [-4.6, 6.2, 8.5]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.jab.follow | left elbow at 165 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.cross.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.cross.contact | foot_r target [-6, 3, 9] is 4.3 units out of reach (the limb is clamped to [-3.1, 5.6, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.cross.follow | left elbow at 171 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.hook.contact | foot_r target [-6, 3, 9] is 3.6 units out of reach (the limb is clamped to [-3.6, 5.2, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.hook.follow | left elbow at 170 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.upper.contact | hand_r target [55, 78, 8] is 2.0 units out of reach (the limb is clamped to [53.3, 76.9, 8.1]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.upper.contact | foot_r target [-6, 3, 9] is 4.0 units out of reach (the limb is clamped to [-3.5, 5.6, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.upper.contact | left elbow at 156 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.upper.follow | hand_r target [38, 88, 8] is 4.8 units out of reach (the limb is clamped to [34.8, 84.5, 8.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | strike.kick.contact | left elbow at 163 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | strike.round.follow | right elbow at 152 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | def.slip | hand_l target [16, 46, -8] is 2.4 units out of reach (the limb is clamped to [13.7, 46.6, -8.1]) | accept the clamped end (`fix-reach`) |
| pose_lint | def.guard_break | hand_l target [4, 80, -16] is 4.7 units out of reach (the limb is clamped to [0.6, 77.0, -15.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | move.descend | hand_l target [28, 90, -4] is 4.3 units out of reach (the limb is clamped to [26.6, 85.9, -4.7]) | accept the clamped end (`fix-reach`) |
| pose_lint | move.sprint | foot_l target [-36, 24, -5] is 2.0 units out of reach (the limb is clamped to [-34.1, 24.6, -5.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | form.gather | left elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | form.gather | right elbow at 154 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | skid.front | left elbow at 173 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | move.burst | hand_r target [-8, 48, 12] is 4.4 units out of reach (the limb is clamped to [-3.6, 47.6, 11.8]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.turn_read | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | cue.guard_set | foot_r target [-8, 3, 8] is 1.3 units out of reach (the limb is clamped to [-7.4, 3.7, 7.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.last_look | right elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | cue.breaks_hold | hand_r target [26, 64, 14] is 3.1 units out of reach (the limb is clamped to [22.9, 64.0, 13.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.holds_on | foot_r target [-8, 3, 8] is 1.6 units out of reach (the limb is clamped to [-7.7, 4.0, 7.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.holds_on | foot_l target [8, 3, -7] is 1.5 units out of reach (the limb is clamped to [7.7, 3.9, -6.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.catch | foot_r target [-8, 3, 8] is 1.3 units out of reach (the limb is clamped to [-7.4, 3.7, 7.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.reset | hand_r target [22, 34, 12] is 1.6 units out of reach (the limb is clamped to [20.9, 35.2, 11.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | cue.reset | hand_l target [-20, 30, -12] is 3.5 units out of reach (the limb is clamped to [-18.0, 32.8, -11.8]) | accept the clamped end (`fix-reach`) |
| silhouette_lint | down.prone / skid.front | overlap 0.844 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | strike.kick.chamber / strike.round.chamber | overlap 0.842 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | stance.aggressive / strike.cross.chamber | overlap 0.832 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | move.step_f / strike.hook.chamber | overlap 0.828 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | strike.cross.chamber / strike.hook.chamber | overlap 0.82 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| | | ... and 7 more notes (summary.json) | |
