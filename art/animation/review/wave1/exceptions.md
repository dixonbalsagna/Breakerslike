# Review: wave1

Machine pass over 117 poses (w1.): **0 errors, 1 for review, 79 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match). Strike lab: 34 strikes measured at their own distances: 34 reach, 32 clear of the defender (clip 3.5 u or less).

Sheet of the flagged poses: exceptions-sheet.png

## For review (what Orb sees)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| strike_lab | body_ram | a part that is not the striking limb passes 6.4 u into the defender (head into neck) at 34 u | pull the body back in the pose (less lunge or lean) or lengthen the distance |

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | w1.jab.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.jab.contact | foot_r target [-8, 3, 9] is 5.0 units out of reach (the limb is clamped to [-4.6, 6.2, 8.5]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.jab.follow | left elbow at 165 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.cross.contact | foot_r target [-6, 3, 9] is 4.3 units out of reach (the limb is clamped to [-3.1, 5.6, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.hook.contact | foot_r target [-6, 3, 9] is 3.6 units out of reach (the limb is clamped to [-3.6, 5.2, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.hook.follow | left elbow at 170 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.backfist.contact | foot_r target [-6, 3, 9] is 3.2 units out of reach (the limb is clamped to [-4.0, 5.0, 8.7]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.backfist.follow | left elbow at 170 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.palm_heel.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.palm_heel.contact | foot_r target [-8, 3, 9] is 5.0 units out of reach (the limb is clamped to [-4.6, 6.2, 8.5]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.palm_heel.follow | left elbow at 165 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.spear_hand.chamber | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.spear_hand.follow | left elbow at 171 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.uppercut.contact | foot_r target [-6, 3, 9] is 4.0 units out of reach (the limb is clamped to [-3.5, 5.6, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.uppercut.contact | left elbow at 156 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.uppercut~b.contact | hand_r target [50, 84, 8] is 4.6 units out of reach (the limb is clamped to [46.2, 81.3, 8.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.uppercut~b.contact | foot_r target [-6, 3, 9] is 2.9 units out of reach (the limb is clamped to [-4.3, 4.9, 8.7]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.uppercut~b.contact | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.hammer.chamber | hand_r target [4, 92, 9] is 1.0 units out of reach (the limb is clamped to [3.6, 91.1, 9.0]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.hammer.follow | left elbow at 167 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.overhand.contact | foot_r target [-6, 3, 9] is 2.2 units out of reach (the limb is clamped to [-4.5, 4.0, 8.8]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.overhand.follow | left elbow at 170 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.chamber | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.contact | foot_r target [-6, 3, 9] is 3.7 units out of reach (the limb is clamped to [-3.5, 5.2, 8.6]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.haymaker.contact | left elbow at 161 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.haymaker.follow | left elbow at 170 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.short_elbow.follow | right elbow at 162 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.rising_elbow.contact | foot_r target [-6, 3, 9] is 1.8 units out of reach (the limb is clamped to [-5.4, 4.1, 8.8]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.spinning_elbow.follow | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.dropping_elbow.follow | right elbow at 156 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.twin_spear.chamber | left elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.twin_spear.chamber | right elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.twin_spear.contact | foot_r target [-6, 3, 9] is 2.2 units out of reach (the limb is clamped to [-4.5, 4.1, 8.8]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.double_palm.chamber | left elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.double_palm.chamber | right elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.double_palm.contact | foot_r target [-6, 3, 9] is 2.4 units out of reach (the limb is clamped to [-4.5, 4.3, 8.7]) | accept the clamped end (`fix-reach`) |
| pose_lint | w1.double_palm~b.chamber | left elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.double_palm~b.chamber | right elbow at 169 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w1.double_palm~b.contact | foot_r target [-6, 3, 9] is 2.4 units out of reach (the limb is clamped to [-4.5, 4.3, 8.7]) | accept the clamped end (`fix-reach`) |
| | | ... and 39 more notes (summary.json) | |
