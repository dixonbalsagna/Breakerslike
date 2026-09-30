# Marked plus flashes

Concept art for Orb to choose from. Working labels, pending Legal review. Read `docs/art/marked-aura.md` first.

| File | What it is |
|---|---|
| `ma-1-style.svg` | The style: four fighters, mask tones, 40 px and 12 px reads, expression strips with head close-ups |
| `ma-2-flashes.svg` | The sixteen head flashes in the four shape families, with the table of moments, timing, priority and sound pairing |
| `ma-3-staging.svg` | Four staged moments in the greybox scene (face-off, clash, transformation, hurt or brink) with the blocking rules |
| `ma-4-flash-rules.svg` | A flash in time, priority and arbitration, the flash against the HUD crown, and the round-tipped Legal fallback |
| `ma-5-legal-checks.svg` | The checks Legal asked Art to run: masks in three flat colours and as silhouettes, sigils beside the generic patterns to avoid, the flashes beside the two patterns to avoid, the dome, the Coil's chest |
| `ma-6-flash-pitch.svg` | The flash-set pitch for Orb: six candidate additions, three cuts or merges, a recommendation |
| `../../../data/art/flashes.json` | The canonical data (timing, priority, layouts, glyphs) for Rendering, UI and Audio. Written by `gen.mjs` |
| `../shared/marks.mjs` | Shared sigils, mask shapes, palettes and helpers, used here and by the turnarounds |
| `gen.mjs` | Writes the six sheets and the data, using the figure kit and the four fighters |

Regenerate from the repo root (Node 18 or later, no packages): `node art/concepts/marked-aura/gen.mjs`. Deterministic: no random numbers, no clock, no external fonts. The staging sheet embeds the repo's own renders in `docs/rendering/img` by relative path, so open the SVGs from this folder in a browser. Figures are three-quarter (32 degrees).

## Origin (proposed rows for `docs/legal/asset-origins.md`; Legal writes the log)

Prompt records: `art/prompts/ART-0005-marked-aura.md`, `art/prompts/ART-0007-legal-conditions.md`.

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status |
|---|---|---|---|---|---|---|---|
| ART-0005-GEN | `art/concepts/marked-aura/gen.mjs` (uses `art/concepts/anti-hero/kit.mjs` and `art/concepts/directions/fighters.mjs`) | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0005-marked-aura.md` | Orb decides | proposed |
| ART-0005-S1 | `art/concepts/marked-aura/ma-1-style.svg` | concept sheet | procedural (output of ART-0005-GEN) | as above | as above | Orb decides | proposed |
| ART-0005-S2 | `art/concepts/marked-aura/ma-2-flashes.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |
| ART-0005-S4 | `art/concepts/marked-aura/ma-4-flash-rules.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |
| ART-0007-SHARED | `art/concepts/shared/marks.mjs` | shared module (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0007-legal-conditions.md` | Orb decides | proposed |
| ART-0007-S5 | `art/concepts/marked-aura/ma-5-legal-checks.svg` | checks sheet | procedural (output of ART-0005-GEN) | as above | as above | Orb decides | proposed |
| ART-0007-S6 | `art/concepts/marked-aura/ma-6-flash-pitch.svg` | pitch sheet | procedural (output of ART-0005-GEN) | as above | as above | Orb decides | proposed |
| ART-0005-DATA | `data/art/flashes.json` | data | procedural (output of ART-0005-GEN) | as above | as above | Orb decides | proposed |
| ART-0005-S3 | `art/concepts/marked-aura/ma-3-staging.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |

The staging sheet references `docs/rendering/img/civilians-after.png`, `craters-after.png` and `world-high-after.png`, renders of the project's own greybox already in the repo.
Every SVG carries a one-line origin comment. The generator carries the same header.
