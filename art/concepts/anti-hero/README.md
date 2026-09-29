# Anti-hero concept sheets

Concept art for Orb to choose from. Working labels, pending Legal review. Read `docs/art/anti-hero-concepts.md` first.

| File | What it is |
|---|---|
| `overview.svg` | All three silhouettes side by side (proud and act dropped) |
| `a-column.svg`, `b-bell.svg`, `c-standard.svg` | One sheet per silhouette: three postures, the wear progression, the form ladder (F1 to F6), palette, the three-colour test, the colour-vision test and the backdrop test |
| `silhouette-test.svg` | The flat-black silhouette test at true size, with a bystander. **View at 100% zoom** |
| `round2-overview.svg` | Round 2: five silhouettes (four new and the Standard revised), each with a colour thumbnail, forms and wear |
| `round2-silhouettes.svg` | The round-2 flat-black test at true size. **View at 100% zoom** |
| `kit.mjs` | The figure kit: a side-on skeleton with a per-figure build, faceted limbs, the head and face, wear decals |
| `concepts.mjs` | The round-1 garment models and palettes |
| `concepts2.mjs` | The round-2 garment models and palettes |
| `gen.mjs` | Writes the round-1 SVGs and prints the palette-versus-backdrop contrast table |
| `round2.mjs` | Writes the round-2 SVGs (`node round2.mjs contrast` prints the value checks) |

## Regenerate

Node 18 or later, no packages. From the repo root:

```bash
node art/concepts/anti-hero/gen.mjs
node art/concepts/anti-hero/gen.mjs contrast
node art/concepts/anti-hero/round2.mjs
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

Round 2 (prompt record `art/prompts/ART-0002-anti-hero-round2.md`):

| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| ART-0002-GEN | `art/concepts/anti-hero/round2.mjs`, `concepts2.mjs`, and the extended `kit.mjs` | procedural generator (code) | AI-assisted, procedural | Claude (Art Director session), human direction from Orb via the EP | Claude Code, claude-sonnet-5-5, 2026-09-29, `art/prompts/ART-0002-anti-hero-round2.md` | Orb decides | proposed | No seed: deterministic and non-random. No input images |
| ART-0002-OVERVIEW | `art/concepts/anti-hero/round2-overview.svg` | concept sheet | procedural (output of ART-0002-GEN) | as above | as above | Orb decides | proposed | |
| ART-0002-SIL | `art/concepts/anti-hero/round2-silhouettes.svg` | test sheet | procedural (output of ART-0002-GEN) | as above | as above | Orb decides | proposed | |

Every SVG carries a one-line origin comment. The generator files carry the same header.
