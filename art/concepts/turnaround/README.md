# Turnarounds

Concept art, working labels, pending Legal review. Read `docs/art/coil-turnaround.md` first.

| File | What it is |
|---|---|
| `coil-turnaround.svg` | The Anti-hero (the Coil): front, three-quarter right and left, back, the crouch, forms, wear, mask close-ups and a part list |
| `gen.mjs` | Writes the sheet using the figure kit and the fighter model |

Regenerate from the repo root (Node 18 or later, no packages): `node art/concepts/turnaround/gen.mjs`. Deterministic: no random numbers, no clock, no external fonts or images.

## Origin (proposed rows for `docs/legal/asset-origins.md`; Legal writes the log)

Prompt record: `art/prompts/ART-0006-coil-turnaround.md`.

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status |
|---|---|---|---|---|---|---|---|
| ART-0006-GEN | `art/concepts/turnaround/gen.mjs`, and the extended `art/concepts/anti-hero/kit.mjs` | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0006-coil-turnaround.md` | Orb decides | proposed |
| ART-0006-COIL | `art/concepts/turnaround/coil-turnaround.svg` | turnaround sheet | procedural (output of ART-0006-GEN) | as above | as above | Orb decides | proposed |

The SVG carries a one-line origin comment. The generator carries the same header.
