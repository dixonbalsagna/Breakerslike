# Review: wave2

Machine pass over 62 poses (w2.): **0 errors, 1 for review, 23 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match). Strike lab: 15 entries measured against the strikes they favour (the mean limb turn from the arrival to the wind-up).

Sheet of the flagged poses: exceptions-sheet.png

## For review (what Orb sees)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| entry_lab | arc_dive | the arrival is far from the wind-up of axe_kick (1.73 rad) | an arrival pose closer to those wind-ups, or let the join (inertialised) carry it |

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | w2.dash.start | left elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.skid.run | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.skid.arrive | left knee at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.skid~b.run | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.skid~b.arrive | left knee at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.coil_spring.start | right knee at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.coil_spring.travel | left elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.coil_spring.travel | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.coil_spring.arrive | left elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.coil_spring.arrive | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.pivot.travel | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.pivot.arrive | right elbow at 161 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.plant_coil.arrive | right elbow at 159 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.plant_coil~b.travel | hand_l target [17, 10, -8] is 3.2 units out of reach (the limb is clamped to [16.3, 13.1, -8.1]) | accept the clamped end (`fix-reach`) |
| pose_lint | w2.plant_coil~b.arrive | right elbow at 164 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | w2.lane_step.travel | right elbow at 155 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| stacking_lint | brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| stacking_lint | cue.brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| entry_lab | arc_dive | a long join into hammer (1.48 rad), stomp (1.43 rad), double_hammer (1.5 rad) | none needed unless the reel shows a jump |
| entry_lab | skid | a long join into spear_hand (1.49 rad), rising_knee (1.34 rad) | none needed unless the reel shows a jump |
| entry_lab | spiral | a long join into spinning_heel (1.35 rad) | none needed unless the reel shows a jump |
| entry_lab | pivot | a long join into spinning_heel (1.45 rad) | none needed unless the reel shows a jump |
| entry_lab | plant_coil | a long join into headbutt (1.39 rad) | none needed unless the reel shows a jump |
