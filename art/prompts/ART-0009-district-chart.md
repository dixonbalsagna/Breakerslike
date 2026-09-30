# Prompt record: ART-0009, the district and landmark silhouette chart

Rules: `docs/art/ai-prompt-policy.md`. Record for `art/concepts/world/gen.mjs` and `docs/art/district-shapes.svg`.

- asset id: ART-0009
- date (UTC): 2026-09-30
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. Deterministic (a string-seeded generator, no Math.random)
- purpose: the silhouette chart of the 20 building shapes, the eight district looks and the five landmarks, for World, Rendering and Orb
- input images: none. No reference image of any kind was used. It reads `data/biomes/settlements.json` for heights and widths
- outputs kept: the chart and the generator
- outputs rejected: none kept
- originality checklist: `docs/art/district-looks.md`. Legal cleared the five landmarks (RL-040) with conditions, which are noted on the chart
- reverse-image search: not yet run
- Legal review: landmarks cleared (RL-040)
- disclosure category: development aid

## Prompt (the brief, as relayed by the EP on 2026-09-30)

> Review the closed `shapes` list in settlements.json; give each district look a short visual brief; one original design idea per landmark. Then: draw the one-sheet silhouette chart of the 20 shapes, the looks and the 5 landmarks, as an SVG in docs/art/.

## Negative prompt

None. No franchise names, no franchise images, no real landmark.
