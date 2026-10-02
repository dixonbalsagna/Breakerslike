# Record: last-stand poses (data/anim/waves/laststand1.*)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | 15 poses and 5 pose sequences for the last stand's body cue: a steadying beat in the shape of each of the four fighters (circles, the crouched wedge, wedges and sweeps, squares), the slump of an expired window and a held resolve, authored as sketches in render/anim/tools/waves/laststand1.mjs and generated into JSON by render/anim/tools/wave_gen.mjs |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JavaScript objects and generating JSON. No image, motion or mesh generator was used. |
| Brief (the prompt) | The EP's brief (docs/architecture/last-stand.md, docs/architecture/fx-events.md): a body cue per fighter for last_stand_ready and last_stand_end; franchise-free; open hands, no clenched fists at the sides, no crossed arms, no scream or aura (a pose, not an effect: the stacking rule) |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
