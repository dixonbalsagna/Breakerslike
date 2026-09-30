# Animation data: the origin rule and the pose screen

Owner: Legal and IP Compliance. 2026-09-30. **Updated 2026-09-30 for ADR 0007:** no human author is required for any content class, including showcase poses. Sections below are marked where the human-author points no longer apply. Answers Animation's question about `docs/animation/pose-pipeline.md` (sections 3.7 and 6.6) and `docs/art/ai-prompt-policy.md`. A screen, not legal advice.

## Does the AI prompt policy cover animation data?

In spirit, yes. In letter, no. The policy's table lists art classes (concepts, designs, generators, icons, meshes, logos) and does not name poses, key sets or motion. Poses and key sets are content, the same as art, so the same rules apply.

## Is Animation's plan compliant?

Mostly. Section 6.6 already follows the policy's shape: showcase poses posed or reworked by a person, the generic library allowed to start as text from a Claude session, a record for each AI-assisted file. Gaps to close:

1. ~~The named human.~~ **No longer required (ADR 0007).** Showcase poses no longer wait on a named human. Claude sessions may author them and Orb reviews and steers.
2. ~~"A later human pass" must be recorded.~~ **Optional (ADR 0007).** If Orb or another person changed or selected something, the record may say so. It is not a gate.
3. **The session's brief is the prompt.** A Claude session writing pose JSON must not be briefed with franchise names, footage, screenshots or "in the style of" anything named. Keep the brief in the record.
4. **Origin rows.** Each pose set needs a row in `asset-origins.md` (Legal writes it), not only a file in `art/animation/records/`.
5. **Blender add-on licence.** Blender's Python add-ons are generally treated as needing a GPL-compatible licence. Our exporter add-on and template may therefore need their own licence header instead of the repo's default. Check Blender's licence FAQ, and give the add-on its own register row. (The `.blend` template is content.)

## The minimum rule

1. Animation data (poses, key sets, motion data) is content. It follows the AI prompt policy and `asset-origins.md`.
2. Every AI-assisted pose set has a record: the brief (franchise-free), tool, model and date. What a human changed is noted if anything. A set-level record is fine.
3. Showcase poses (specials, signatures, finishers, transformations, taunts) may be authored by Claude sessions. No named human is required (ADR 0007). Orb reviews and steers.
4. Sensitive pose families carry an `_orig` line and pass the originality checklist.
5. Reference footage: none from any franchise or game. Self-shot reference is private, with consent, never shipped, and its origin recorded.

## Screen of the original poses (section 3.7)

| Pose family | Verdict | Note |
|---|---|---|
| Power charge | **GO** | One fist to the breastbone, head bowed, no orb. Do not add both fists clenched at the sides with the head thrown back and a scream. |
| Beam release | **CONDITIONAL** | One arm out, palm forward, the other hand gripping the wrist is a well-known anime beam stance, and it appears in the franchise. Change one part: fire from a fist or forearm instead of the palm, or brace the elbow or forearm from below instead of the wrist. |
| Teleport step | **GO** | No hand to the head. The flat hip-line sweep is original. |
| Transformation rise | **GO** | Kneel with a fist on the ground, then rise head last. A generic hero beat. No arms-at-sides scream. |
| Taunt | **GO** | Head tilt and a dismissive backhand. No beckoning fingers. |
| Finisher launch | **GO** | A lunge into an upward two-handed strike. No arms held overhead. |

Logged as RL-038. The beam release stays open until Animation changes it.
