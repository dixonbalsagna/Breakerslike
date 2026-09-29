# Blank variations

Concept art for Orb to choose from. Working labels, pending Legal review. Read `docs/art/blank-variations.md` first.

| File | What it is |
|---|---|
| `blank-comparison.svg` | The five variations side by side, with the Protagonist through five emotions |
| `blank-1-seam.svg`, `blank-2-porcelain.svg`, `blank-3-marked.svg`, `blank-4-inked.svg`, `blank-5-aura.svg` | One sheet per variation: four fighters, 40 px and 12 px reads, expression strips with close-ups, and a greybox mock-up |
| `gen.mjs` | Applies a variation to the four fighters (`art/concepts/directions/fighters.mjs`) and writes the sheets |

Regenerate from the repo root (Node 18 or later, no packages): `node art/concepts/blank/gen.mjs`. Deterministic: no random numbers, no clock, no external fonts. The greybox mock-up embeds `docs/rendering/img/civilians-after.png` by relative path (the repo's own render, not a copy), so open the SVGs from this folder in a browser. Figures are drawn in a three-quarter view (32 degrees) using the yaw in `art/concepts/anti-hero/kit.mjs`.

## Origin (proposed rows for `docs/legal/asset-origins.md`; Legal writes the log)

Prompt record: `art/prompts/ART-0004-blank-variations.md`.

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status |
|---|---|---|---|---|---|---|---|
| ART-0004-GEN | `art/concepts/blank/gen.mjs`, and the extended `art/concepts/anti-hero/kit.mjs` and `art/concepts/directions/fighters.mjs` | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0004-blank-variations.md` | Orb decides | proposed |
| ART-0004-CMP | `art/concepts/blank/blank-comparison.svg` | concept sheet | procedural (output of ART-0004-GEN) | as above | as above | Orb decides | proposed |
| ART-0004-V1 to V5 | `art/concepts/blank/blank-1-seam.svg` to `blank-5-aura.svg` | concept sheets | procedural | as above | as above | Orb decides | proposed |

The mock-up sheets reference `docs/rendering/img/civilians-after.png`, a render of the project's own greybox, already in the repo.
Every SVG carries a one-line origin comment. The generator files carry the same header.
