# Record: A1 pose set (data/anim/poses.json)

Origin record for AI-assisted animation data, in the form docs/legal/animation-data-rule.md (RL-038) asks for. Legal writes the matching row in `asset-origins.md`.

| Field | Value |
| :--- | :--- |
| Asset | The A1 composed-library poses (stances, movement, flight, guard, down, slide, strikes, reactions, beam, charge, taunt, and the 15 cue poses) and their key sets, profiles and cue map |
| Date | 2026-09-30 |
| Tool and model | Claude Code, model claude-sonnet-5-5 (Animation Director session), writing pose sketches as JSON by hand. No image, motion or mesh generator was used. |
| Brief (the prompt) | Franchise-free, from docs/animation/pose-pipeline.md: "a fighter's key poses on a 27-bone humanoid rig, in sketch form (torso lean, twist, head turn, hand and foot targets in model space), for a side-on fighting game: stances, dash and retreat, a launch tumble, guard, down and get-up, a slide brake, six strikes (jab, cross, hook, uppercut, front kick, roundhouse) as chamber, contact and follow-through, hit reactions, a beam charge and release, an original power charge, a taunt". No franchise names, footage, screenshots or "in the style of" anything named. The 15 cue poses translate Combat's cue names and the placeholder numbers in render/core/look.gd (CUE_POSES) into mannequin poses. |
| Inputs | None from outside the repository. No reference footage or images. |
| What a human changed | Nothing yet. This is the composed (generic) library; a person has not reworked it. A human pass, with what the person changed written here, is needed before it locks. |
| Showcase poses | None in this set. beam.charge, beam.fire, charge.hold and emote.taunt are the sensitive families of pose-pipeline.md section 3.7; each carries an `_orig` line and follows Legal's screen (RL-038). A named human author is still needed before any specials, signatures, finishers, transformations or taunts are locked. |
| Originality check (silhouette, three flat colours, "what does this remind me of?") | Run on the pose sheet for the sensitive poses by the authoring session: charge is a fist to the breastbone with a bowed head; beam is a closed fist along the shoulder line with the rear forearm braced under the elbow; taunt is a head tilt and a dismissive backhand. None reminded the author of a specific character. A human check is still to do. |
| Status | Proposed. Cannot lock until the human pass is recorded. |
