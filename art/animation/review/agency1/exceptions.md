# Review: agency1

Machine pass over 12 poses (ag.): **0 errors, 0 for review, 4 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match). Strike lab: 0 strikes measured at their own distances: 0 reach, 0 clear of the defender (clip 3.5 u or less).

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | ag.taunt.shrug | hand_r target [16, 46, 34] is 1.6 units out of reach (the limb is clamped to [15.3, 46.8, 32.8]) | accept the clamped end (`fix-reach`) |
| pose_lint | ag.hold.charge_light | hand_l target [2, 46, -6] is 1.3 units out of reach (the limb is clamped to [2.3, 44.9, -6.6]) | accept the clamped end (`fix-reach`) |
| stacking_lint | brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| stacking_lint | cue.brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
