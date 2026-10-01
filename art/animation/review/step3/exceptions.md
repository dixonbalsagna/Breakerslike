# Review: step3

Machine pass over 29 poses (s3.): **0 errors, 0 for review, 9 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: not run (--no-match).

## Notes (logged, no action needed)

| Source | Subject | Finding | Suggested action |
| :--- | :--- | :--- | :--- |
| pose_lint | s3.burst.gather | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | s3.burst.gather | right elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | s3.burst~b.gather | left elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | s3.burst~b.gather | right elbow at 157 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | s3.shoved.shove | hand_l target [16, 64, -13] is 2.1 units out of reach (the limb is clamped to [13.9, 63.8, -12.8]) | accept the clamped end (`fix-reach`) |
| silhouette_lint | s3.stagger_bait.straighten / s3.stagger_blocked.regain | overlap 0.828 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | s3.stagger_bait.straighten / s3.stagger_blocked~b.regain | overlap 0.828 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| stacking_lint | brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| stacking_lint | cue.brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
