# Record: ground-contact poses (data/anim/waves/ground1.*)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | 16 poses and 5 pose sequences for World's ground-contact events: the bounce (fold and rebound), the launch off a lip, the tech flip (tuck, spin, open, land), the braced tumble (held), and a quick and a slow get-up, authored as sketches in render/anim/tools/waves/ground1.mjs and generated into JSON by render/anim/tools/wave_gen.mjs; two phases are tuned from getup.push and stance.aggressive |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JavaScript objects and generating JSON. No image, motion or mesh generator was used. |
| Brief (the prompt) | The EP's brief ahead of World's ground-contact switch-on (docs/world/ground-contact.md section 4): braced tumble, bounce, lip launch, tech flip, quick and slow get-ups; franchise-free, hands open |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
