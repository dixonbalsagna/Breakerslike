# Record: the opening's poses (data/anim/waves/intro1.*)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | 11 poses and 3 pose sequences for the opening: the head-first fall, the landing crouch (compress, hold, rise), the staredown set and its tension, and one small beat each for two fighters (the Anti-hero straightens a cuff, the Protagonist rolls his shoulders), authored as sketches in render/anim/tools/waves/intro1.mjs and generated into JSON by render/anim/tools/wave_gen.mjs |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JavaScript objects and generating JSON. No image, motion or mesh generator was used. |
| Brief (the prompt) | The EP's brief for the opening (docs/architecture/intro-phase.md, docs/camera/rule-of-cool-shots.md row 7) and Legal's lines: no cape, no wind-blown silhouette reveal; a landing crouch that reads from the low angle and rises into the stance with the hands open and no fist to the ground with the head bowed; a staredown that is not a duel pose |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
