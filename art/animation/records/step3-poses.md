# Record: step 3 cue poses (data/anim/waves/step3.*)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | 29 poses and 9 pose sequences for Encounter's step 3 cue events (perfect block, stagger of the blocked attacker, reversal, the countered attacker, dodge-cancel, burst, the shoved fighter, the absorbed burster, the absorber), 23 authored plus 6 for three B versions, authored as sketches in render/anim/tools/waves/step3.mjs and generated into JSON by render/anim/tools/wave_gen.mjs |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JavaScript objects and generating JSON. No image, motion or mesh generator was used. |
| Brief (the prompt) | The EP's brief after Encounter's step 3: the events perfect_block, reversal, dodge_cancel, burst and burst_absorbed and the stagger state (docs/director/control-scheme-plan.md "Step 3 as built"), franchise-free, hands open throughout, no crossed-arms hold, no clasped fists |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
