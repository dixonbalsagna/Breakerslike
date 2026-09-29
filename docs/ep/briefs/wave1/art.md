# P0 wave 1 brief: art

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): produce three original art directions, a bible skeleton, biome look notes and SVG concept sheets. Leave 2D, 2.5D or 3D, and the style, as 'Orb decides' options.

GOAL: Give Orb three concrete, legally clean visual directions for the game, each shown to read at the widest zoom, so the presentation and style decision can be made without further art work.

CONTEXT (read first):
- docs/directors/art.md (charter), CLAUDE.md (pillars, biome order), docs/legal/originality-rules.md and review-log.md RL-014.
  - The hero must not have golden hair. The prototype used '#ffd54a'; QA changed it to '#22c7a9' tonight. Neither is a design.
  - Grey-zone defaults apply: no hair-colour transformations (show tiers with aura, silhouette, markings or eyes), no 'power level' readouts, original poses, no franchise nods.
  - Not allowed: spiky upswept hair with an orange and blue uniform, a tail, a pale horned emperor.
- prototype/index.html, read only. Lines after 216 moved down by one tonight.
  - SEG and BCOL (lines 118 and 119) define eleven segments and seven biome types: ocean 0-1200 and 8300-9600, harbour village 1200-1800, plains 1800-2350 and 8000-8300, city 2350-3850, outskirts village 3850-4500, forest 4500-5500, desert 5500-6500, mountains 6500-7600, far village 7600-8000.
  - camStep clamps the zoom cam.z to 0.06 to 1.15, so a roughly 90-unit fighter is about 5 px at the widest zoom.
  - ROSTER holds KAI (hero, blue) and VORR (villain, red). drawFighter shows tiers 1 to 4 by aura radius.
  - genWorld sets towers 120 to 660 units tall and houses 36 to 72. curH shrinks a structure to 30% of its height as it is damaged, then to 9 units when dead. crater deforms the ground, and tierUp cracks it.
- qa/baseline-p0.md: 69.4% of beams land over the ocean, and the fighters spend 64.6% of their time there, so the ocean and sky must look great. The city and forest are rarely seen.
- Tonight, in parallel and invisible to you:
  - Camera sets the lowest zoom it will allow and may raise the 0.06 floor.
  - Animation writes rig options.
  - VFX, UI & UX and Accessibility propose colour uses for tiers, stances and beams. You own the palette, so give each direction semantic colour roles they can map to.
  The EP forwards everything.
- Legal is creating docs/legal/asset-origins.md tonight as the single origin log, replacing licence-register.md Part B. Concept sheets count as assets. Do not edit docs/legal/.
- Orb's answers on presentation, style, AI-generated assets and budget are pending. Nothing blocks you.

YOU OWN: art/concepts/ and docs/art-bible/ only. art/animation/ belongs to Animation and art/vfx/ to VFX. Nothing else.

ACCEPTANCE CRITERIA:
1. docs/art-bible/directions.md holds three distinct directions. Each covers:
   - presentation fit (2D, 2.5D, 3D);
   - palette (hex values) with semantic roles: hero, villain, tier 1 to 4 aura, the four stances, beam, collateral or danger, UI accent;
   - silhouette rules, proportions and material language;
   - readability at cam.z 0.06;
   - destruction states for house, tower and crater;
   - originality notes.
   No hero palette repeats the prototype's gold hair on blue.
2. Silhouette test per direction: an SVG in art/concepts/ with hero and villain in flat black at 5 px and 40 px tall, at tier 1 and tier 4. View it rendered, for example in the Browser pane, and record in directions.md: pass or fail, the shape feature (not colour) that tells them apart, and your answer to originality-rules checklist item 4. Mark each result 'pending Legal review'.
3. A trade-off table across the three directions (cost, readability, Godot fit, animation load, risk), with the recommendation clearly marked 'Orb decides'.
4. docs/art-bible/README.md skeleton: section headings, status per section (open, draft, locked) and the list of decisions still owed by Orb.
5. docs/art-bible/biomes.md gives look notes for the seven biome types, with the three villages told apart. Cover palette, silhouette, materials, cover cues (ocean depth, forest canopy and mountain ridge are hiding places) and damage states. Add a night or dusk note.
6. Optional: up to 5 more hand-written SVGs in art/concepts/ (palette strips, fighter silhouettes). Use no external images. Each SVG has a one-line origin comment. For every SVG, put a proposed origin row in your report under NEEDS FROM EP for Legal: asset id, path, type, origin, author or tool, date, and licence placeholder 'Orb decides'. The EP commits the SVGs after Legal has recorded them.
7. End with a ranked list of questions for Orb.

CONSTRAINTS: No git state changes. Everything original: no franchise reference images and no franchise words in notes. No asset production beyond concept sheets. Fonts are not to be bundled. Art must never require changes to sim state.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

1. The hero's hair is now teal #22c7a9. That's QA's placeholder, not a design choice. The hero's gender and pronouns are pending Orb; Narrative writes they/them for now.

2. Narrative proposes names you can use in your biome notes, pending Legal and Orb:
- A tier ladder: Tremor, Quake, Upheaval, Cataclysm (docs/narrative/glossary.md).
- Place names (docs/narrative/places.md): the planet Everhold, the sea Longwater, and the city Bellgate, which holds 83% of the civilians.

3. Orb's style and presentation answers are due soon, and I'll forward them. Until then, keep the three directions as options.
