# Character art directions

Concept art for Orb to choose from. Working labels, pending Legal review. Read `docs/art/directions.md` first.

| File | What it is |
|---|---|
| `directions-comparison.svg` | The four directions side by side, four fighters each |
| `dir-1-blank.svg`, `dir-2-ink.svg`, `dir-3-toy.svg`, `dir-4-poster.svg` | One sheet per direction: showcase, silhouette, civilian, 40 px and 12 px, and a posture strip |
| `fighters.mjs` | The four fighters and the guard of honour, with their palettes |
| `gen.mjs` | Applies a style to the fighters and writes the sheets |

Regenerate from the repo root (Node 18 or later, no packages): `node art/concepts/directions/gen.mjs`. It is deterministic: no random numbers, no clock, no external images or fonts. It uses the figure kit in `art/concepts/anti-hero/kit.mjs`. Open the SVGs in a browser.

## Origin (proposed rows for `docs/legal/asset-origins.md`; Legal writes the log)

Prompt record: `art/prompts/ART-0003-character-directions.md`.

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status |
|---|---|---|---|---|---|---|---|
| ART-0003-GEN | `art/concepts/directions/gen.mjs`, `fighters.mjs`, and the extended `art/concepts/anti-hero/kit.mjs` | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0003-character-directions.md` | Orb decides | proposed |
| ART-0003-CMP | `art/concepts/directions/directions-comparison.svg` | concept sheet | procedural (output of ART-0003-GEN) | as above | as above | Orb decides | proposed |
| ART-0003-D1 | `art/concepts/directions/dir-1-blank.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |
| ART-0003-D2 | `art/concepts/directions/dir-2-ink.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |
| ART-0003-D3 | `art/concepts/directions/dir-3-toy.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |
| ART-0003-D4 | `art/concepts/directions/dir-4-poster.svg` | concept sheet | procedural | as above | as above | Orb decides | proposed |

Every SVG carries a one-line origin comment. The generator files carry the same header.
