# Review: wave1

Machine pass over 120 poses (w1.): **0 errors, 13 for review, 78 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match). Strike lab: 34 strikes measured at their own distances: 34 reach, 28 clear of the defender (clip 3.5 u or less).

Sheet of the flagged poses: exceptions-sheet.png

## For review (what Orb sees)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | w1.hook.contact | hand_r target [54, 72, 12] is 8.0 units out of reach (the limb is clamped to [62.0, 72.0, 12.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.haymaker.chamber | hand_r target [-8, 60, 26] is 6.0 units out of reach (the limb is clamped to [-2.0, 60.0, 26.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.twin_spear.chamber | hand_r target [4, 50, 6] is 6.0 units out of reach (the limb is clamped to [10.0, 50.0, 6.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.twin_spear.chamber | hand_l target [4, 50, -6] is 6.0 units out of reach (the limb is clamped to [10.0, 50.0, -6.0]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.snap_round.chamber | foot_r target [12, 40, 10] is 9.7 units out of reach (the limb is clamped to [14.4, 30.6, 10.8]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.snap_round.follow | foot_r target [14, 38, 8] is 10.4 units out of reach (the limb is clamped to [5.1, 33.3, 5.6]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.roundhouse.chamber | foot_r target [4, 44, 20] is 10.4 units out of reach (the limb is clamped to [12.9, 40.0, 16.5]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.roundhouse~b.chamber | foot_r target [4, 44, 20] is 10.4 units out of reach (the limb is clamped to [12.9, 40.0, 16.5]) | shorten the target or accept the clamped end (`fix-reach`) |
| pose_lint | w1.stomp.chamber | foot_r target [16, 48, 8] is 5.3 units out of reach (the limb is clamped to [19.2, 43.8, 8.6]) | shorten the target or accept the clamped end (`fix-reach`) |
| strike_lab | dropping_elbow | a part that is not the striking limb passes 8.3 u into the defender (neck into head) at 38 u | pull the body back in the pose (less lunge or lean) or lengthen the distance |
| strike_lab | cross_arm_ram | a part that is not the striking limb passes 7.8 u into the defender (neck into head) at 38 u | pull the body back in the pose (less lunge or lean) or lengthen the distance |
| strike_lab | rising_knee | a part that is not the striking limb passes 8.7 u into the defender (spine_2 into head) at 32 u | pull the body back in the pose (less lunge or lean) or lengthen the distance |
| strike_lab | driving_knee | a part that is not the striking limb passes 8.5 u into the defender (spine_2 into head) at 28 u | pull the body back in the pose (less lunge or lean) or lengthen the distance |

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | w1.jab.chamber | hand_r target [14, 60, 11] is 1.1 units out of reach (the limb is clamped to [15.0, 60.1, 11.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.jab.chamber | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.jab.contact | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.jab.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross.chamber | hand_r target [4, 58, 13] is 1.0 units out of reach (the limb is clamped to [4.2, 57.7, 13.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.cross.chamber | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.hook.contact | left elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.hook.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.backfist.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.backfist~g.chamber | hand_r target [4, 58, 13] is 1.0 units out of reach (the limb is clamped to [4.2, 57.7, 13.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.backfist~g.chamber | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.backfist~g.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.palm_heel.chamber | hand_r target [14, 60, 11] is 1.1 units out of reach (the limb is clamped to [15.0, 60.1, 11.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.palm_heel.chamber | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.palm_heel.contact | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.palm_heel.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.spear_hand.chamber | hand_r target [4, 58, 13] is 1.0 units out of reach (the limb is clamped to [4.2, 57.7, 13.9]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.spear_hand.chamber | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.spear_hand.follow | hand_l target [17, 56, -5] is 2.0 units out of reach (the limb is clamped to [18.5, 55.6, -4.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.spear_hand.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.uppercut.contact | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.uppercut~b.contact | hand_r target [50, 84, 8] is 4.6 units out of reach (the limb is clamped to [46.2, 81.3, 8.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.uppercut~b.contact | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.hammer.chamber | hand_r target [4, 92, 9] is 1.0 units out of reach (the limb is clamped to [3.6, 91.1, 9.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.hammer.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.overhand.chamber | hand_r target [2, 62, 22] is 2.0 units out of reach (the limb is clamped to [4.0, 62.0, 22.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.overhand.contact | hand_r target [52, 76, 10] is 4.0 units out of reach (the limb is clamped to [56.0, 76.0, 10.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.overhand.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.chamber | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.contact | left elbow at 156 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.short_elbow.follow | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.spinning_elbow.follow | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.dropping_elbow.follow | right elbow at 156 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.double_hammer.chamber | hand_r target [6, 98, 8] is 4.7 units out of reach (the limb is clamped to [5.0, 93.4, 8.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.double_hammer.chamber | hand_l target [6, 98, -8] is 4.7 units out of reach (the limb is clamped to [5.0, 93.4, -8.2]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.cross_arm_ram.chamber | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross_arm_ram.chamber | right elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross_arm_ram.follow | left elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross_arm_ram.follow | right elbow at 160 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| | | ... and 38 more notes (summary.json) | |
