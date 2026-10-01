# Review: poses

Machine pass over 94 poses: **0 errors, 0 for review, 36 notes.** Errors are fixed by the director before Orb sees anything; the rows under "For review" are what Orb sees (with the sheet); notes are logged and need nobody.

Match checks: 4,12345 for 3000 ticks: limb_scan clean, anim_check passed, 2907 checks.

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
| pose_lint | form.gather | left elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | form.gather | right elbow at 154 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | skid.front | left elbow at 173 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | cue.turn_read | right elbow at 158 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| pose_lint | cue.last_look | right elbow at 153 degrees | the runtime limb pass trims the fold to 150 degrees, so the pose shows less than authored; relax it if the full fold is meant |
| silhouette_lint | down.prone / skid.front | overlap 0.842 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | strike.kick.chamber / strike.round.chamber | overlap 0.842 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | stance.aggressive / strike.cross.chamber | overlap 0.832 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | move.step_f / strike.hook.chamber | overlap 0.828 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | strike.cross.chamber / strike.hook.chamber | overlap 0.82 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | def.parry_ready / strike.hook.chamber | overlap 0.817 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | hurt.hold / idle.winded | overlap 0.813 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | cue.last_look / emote.taunt | overlap 0.811 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | down.ko / skid.back | overlap 0.808 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| silhouette_lint | def.parry_ready / move.step_f | overlap 0.8 (across families) | two moves that read alike: change one silhouette (or add the pair to data/anim/lint_allow.json with a reason) |
| stacking_lint | brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| stacking_lint | cue.brace | mark 1: a crouch with fists at the sides | fine alone; never in a moment that also has a scream, a flame aura, rising rubble, lightning, hair or a gold flash |
| pop_scan | joins | 248 eased swings over 0.6 rad in 12000 fighter-frames, worst 2.67 rad (fighter 0: 2.67 rad on shin_l, (base) -> (base) [react launched], state launched ip true t 0.033) | none: the offset settles on its curve; raw/pop_scan.json lists the worst ticks |
