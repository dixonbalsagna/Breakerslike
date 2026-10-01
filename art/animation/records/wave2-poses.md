# Record: wave 2 entry poses (data/anim/waves/wave2.*)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | 62 poses and 20 entry sequences of the Anti-hero's wave 2 entries: 45 poses for the 15 entries and 17 for five B versions, authored by hand as sketches in render/anim/tools/waves/wave2.mjs and generated into JSON by render/anim/tools/wave_gen.mjs; several are tuned from poses already in poses.json (stance.aggressive, move.step_f, move.step_b, approach.launch, move.ascend, move.sprint, stance.air) |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JavaScript objects and generating JSON. No image, motion or mesh generator was used. |
| Brief (the prompt) | Combat's parked specs: docs/combat/pending/wave2-entries.md and entries.antihero.wave2.json (a look line per entry, path, ticks, new and derived poses, favoured strikes), with Legal's conditions (docs/legal/rule-of-cool-screen.md, wave 2) built in as `_legal` rules the pose lint checks |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
| Screen | The Legal lines that are geometry are machine-checked on every pose; the effects lines (no afterimage that hides him on the spiral, no scream or ground crack on the crouches) are VFX's and stay Legal's screen |
