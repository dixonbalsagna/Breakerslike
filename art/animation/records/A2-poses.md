# Record: A2 defence and clash poses (data/anim/poses.json)

Origin record in the form docs/legal/animation-data-rule.md (RL-038) asks for; the human-authorship requirement was dropped by ADR 0007, the provenance record stays.

| Field | Value |
| :--- | :--- |
| Asset | Twenty-eight poses (the overhaul adds skid.back, skid.front, skip.water and getup.push: lying skids with an arm dragging, a water skip, the push-up stage of a get-up); earlier: twenty-four poses (the fifth pass adds wound.arm_limp, wound.leg_favour and wound.sag, the battle-damage layers); the fourth pass: the fourth pass (2026-10-01) adds move.step_f, move.step_b, move.sprint and the transformation placeholders form.gather, form.break, form.settle (sheets art/animation/a2-vocab3-sheet.png, a2-form-sheet.png) on top of fifteen from the earlier passes, making twenty-one: Second pass: def.parry_ready, def.parry, react.rebuff, def.slip, def.blink_in, def.guard_break, def.guard_hit, clash.push, emote.victory. Third pass (2026-10-01): idle.relaxed, idle.winded, stance.air, move.ascend, move.descend, down.ko (sheet art/animation/a2-vocab2-sheet.png) |
| Date | 2026-10-01 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JSON by hand. No image, motion or mesh generator was used. |
| Brief (the prompt) | Franchise-free, from the exchange beats the sim already runs (wind, slip, dodge, guardBreak, clashWave) and the damage event's guard kind: a defender's read, sweep, slip, blink landing, broken guard and guarded hit; the parried attacker's turn-off; both fighters' clash push; a winner's raised fist. |
| Inputs | None from outside the repository. No reference footage or images. Each pose carries an `_orig` line. |
| What a human changed | Nothing yet; Orb has not reviewed them. |
| Showcase poses | None. emote.victory is the one sensitive family (a raised fist): one arm up, chin lifted, no both-fists scream, no flexing (RL-038). |
| Originality check | Contact sheet art/animation/a2-vocab-sheet.png, flat-colour silhouettes: nothing reads as a known character's signature stance; the parry is an open-palm sweep across the body, the guard break arms up and apart. |
| Status | Proposed. Locks when Orb has reviewed it. |
