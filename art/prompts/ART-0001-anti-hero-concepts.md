# Prompt record: ART-0001, the Anti-hero concept sheets and generator

Rules: `docs/art/ai-prompt-policy.md`. This is the record for the generator code and the SVG sheets in `art/concepts/anti-hero/`.

- asset id: ART-0001
- date (UTC): 2026-09-29
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. The generator is deterministic and uses no random numbers
- purpose: three concept silhouettes for the Anti-hero, a silhouette test and a palette test, for Orb to choose from
- input images: none. No reference image of any kind was used. The only images viewed were this generator's own renders, to check them. Every shape is a polygon written in code
- outputs kept: `art/concepts/anti-hero/overview.svg`, `a-column.svg`, `b-bell.svg`, `c-standard.svg`, `silhouette-test.svg`, and the generator files `kit.mjs`, `concepts.mjs`, `gen.mjs`
- outputs rejected: none kept. Earlier passes of the same files were overwritten
- what a human changed: nothing yet. The human direction is Orb's answers in `docs/ep/vision.md`, relayed by the EP. **Orb has not yet authored or approved a design.** Under Legal 8.5.3 the final Anti-hero must be drawn or heavily reworked by a person before it locks
- originality checklist: recorded in `docs/art/anti-hero-concepts.md` section 6, pending Legal review
- reverse-image search: not yet run
- Legal review: pending
- disclosure category: development aid until Orb picks a design. If one is built into the game, it ships (Steam: AI-assisted art)

## Prompt (the brief, verbatim, as relayed by the EP on 2026-09-29)

> Brief: set the game's look and design the first real fighter, the Anti-hero. This replaces your wave-1 brief; fold in what still fits.
> Background: the title is Orb Combat EX (Meridian is the team codename). The live greybox is at dixonbalsagna.github.io/orb-combat-ex/play/. Orb's answers: cel-shaded plus low-poly (Art to pitch), procedural assets, and AI-generated assets allowed. The world is going life-size (docs/world/scale.md): civilians as tall as fighters, towers 13-30 fighter-heights, skyscrapers 60-150. The tone is mature, graphic, funny and sincere; the feel reference is brutal, readable, choreographed flash-animation fights.
> Read first: docs/ep/vision.md (all of it); docs/legal/originality-rules.md, fighter-concepts-review.md and q3-screen.md (the Anti-hero conditions: no shoulder-pad armour with white gloves and boots, no flame-shaped hair, no hair-colour change, regalia is a fresh design, Drop the Act and Humbled shown with posture and expression, no gold or red glow); docs/narrative/voices/anti-hero.md and matchups.md; docs/design/spec-wounds.md (his Proud front, how wear shows, the four regions).
> You own: art/ and docs/art/.
> Deliverables:
> 1. docs/art/style-guide.md, v0: the cel and low-poly approach, palette rules (three-colour silhouette test), line and outline, how wear and damage read on bodies (regions: head, core, arms, legs, and the aura crown), scale and readability at gameplay zoom, the biome palettes, and what Rendering needs (shader features, outline, ramp).
> 2. The Anti-hero concept: 3 distinct silhouettes as SVG in art/concepts/anti-hero/, each with palette, regalia (which breaks piece by piece under Shed Regalia if Orb later picks it), posture states (proud, humbled, act dropped) and a wear progression. Recommend one.
> 3. An AI-art prompt policy in docs/art/ if we use generated assets: never franchise names, characters or images; keep the prompts (Legal's section 8).
> No workflows. Legal screens your pick afterwards. The standard report, short, with the file list.

## Negative prompt

None.
