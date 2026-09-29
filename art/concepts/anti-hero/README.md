# Anti-hero concept sheets

Concept art for Orb to choose from. Working labels, pending Legal review. Read `docs/art/anti-hero-concepts.md` first.

| File | What it is |
|---|---|
| `overview.svg` | All three silhouettes side by side (proud and act dropped) |
| `a-column.svg`, `b-bell.svg`, `c-standard.svg` | One sheet per silhouette: three postures, the wear progression, the form ladder (F1 to F6), palette, the three-colour test, the colour-vision test and the backdrop test |
| `silhouette-test.svg` | The flat-black silhouette test at true size, with a bystander. **View at 100% zoom** |
| `kit.mjs` | The figure kit: a side-on skeleton, faceted limbs, the head and face, wear decals |
| `concepts.mjs` | The three garment models and their palettes |
| `gen.mjs` | Writes the SVGs and prints the palette-versus-backdrop contrast table |

## Regenerate

Node 18 or later, no packages. From the repo root:

```bash
node art/concepts/anti-hero/gen.mjs
node art/concepts/anti-hero/gen.mjs contrast
```

The generator is deterministic: no random numbers, no clock, no external images or fonts. The same code writes the same bytes. Text in the sheets uses the viewer's default sans-serif; nothing is bundled.

## Origin (proposed rows for `docs/legal/asset-origins.md`; Legal writes the log)

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| ART-0001-GEN | `art/concepts/anti-hero/kit.mjs`, `concepts.mjs`, `gen.mjs` | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0001-anti-hero-concepts.md` | Orb decides | proposed | No seed: deterministic and non-random. No input images |
| ART-0001-OVERVIEW | `art/concepts/anti-hero/overview.svg` | concept sheet | procedural (output of ART-0001-GEN) | as above | as above | Orb decides | proposed | |
| ART-0001-A | `art/concepts/anti-hero/a-column.svg` | concept sheet | procedural (output of ART-0001-GEN) | as above | as above | Orb decides | proposed | |
| ART-0001-B | `art/concepts/anti-hero/b-bell.svg` | concept sheet | procedural (output of ART-0001-GEN) | as above | as above | Orb decides | proposed | |
| ART-0001-C | `art/concepts/anti-hero/c-standard.svg` | concept sheet | procedural (output of ART-0001-GEN) | as above | as above | Orb decides | proposed | |
| ART-0001-SIL | `art/concepts/anti-hero/silhouette-test.svg` | test sheet | procedural (output of ART-0001-GEN) | as above | as above | Orb decides | proposed | |

Every SVG carries a one-line origin comment. The generator files carry the same header.
