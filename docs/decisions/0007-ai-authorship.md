# ADR 0007: AI-authored content, and where a human hand is required

Status: accepted, 2026-09-30. Decided by Orb.

## Context

The art AI policy (docs/art/ai-prompt-policy.md) and the animation data rule (docs/legal/animation-data-rule.md, RL-038) required a named human to author or materially rework characters, signature designs and showcase poses. The reason was copyright: the US Copyright Office's position is that work made entirely by AI is not protected. Applied to animation, the rule costed out at hundreds of human hours per fighter.

Orb's position: the game is meant to be 90% or more vibe-coded. Orb is not worried about others copying the work, and was close to releasing it fully free and open source. What matters is enough protection to sell and market it on Steam or a comparable store. Orb's concern was liability, not ownership.

## Decision

1. A human author is no longer required for any content class. Directors (Claude sessions) may author poses, showcase moves, signature designs and character art. Orb reviews and steers.
2. We accept that purely AI-made parts may not be protected by copyright. Protection and marketing rest on the trademark for the title and logo, on Orb's own human contributions (direction, selection and arrangement, rewrites such as the voice lab), and on the game as a whole.
3. What stays mandatory, because it guards against liability rather than ownership:
   - the originality rules and Legal's screens (no franchise names, designs, catchphrases or lookalikes; AI briefs stay franchise-free);
   - provenance records for AI-assisted assets (tool, model, date, brief), which also feed the store's AI-content disclosure;
   - third-party licence checks for every asset, font, sound and library;
   - Legal review before any store page.

## Consequences

- Animation's pose budget drops to review time and usage. Showcase poses no longer wait on a named human.
- Legal updates the art AI policy and the animation data rule to match.
- Missing human authorship creates no liability. Liability comes from infringing someone else's work, so the originality screens matter more, not less.
