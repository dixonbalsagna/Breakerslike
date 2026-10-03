# Refine: the Cyborg first, then the other three

Concept art, working labels, pending Legal review. Orb's art direction (2026-10-02): masks and broken masks are for one future character, not the game's house style; the unmasked faces and the current silhouettes are the base to refine, and the Cyborg comes first because he reads as the most generic of the four. Regenerate from the repo root: `node art/concepts/refine/gen.mjs` (deterministic, no packages). Prompt record: `art/prompts/ART-0013-refine-faces-silhouettes.md`.

| Sheet | What it shows | The question it asks Orb |
|---|---|---|
| `cyborg-directions.svg` | Why the Cyborg reads as generic (silhouette, face, palette, motif, story), then six directions, each with the silhouette at fight size (colour, then flat black at 120 and 40 px), the face at cut-in size (neutral and hurt), a line on what makes it his own, and what Legal should screen. 1 Stepper, 2 Stack and 5 Prosthetic keep him recognisably the same fighter; 3 Furnace is a heavier cousin; 4 Frame and 6 Sprinter are bolder | Is he a heavy brawler, a person in a machine, or something quicker and stranger? Which one hook do you want to see on screen at 40 px, and do you want to combine two? |
| `protagonist-refine.svg` | His unmasked face today and refined (neutral, hurt, a laugh), and the silhouette with two options (a long swept tuft, big round fists) | Is this still the face you liked, is the forelock too much, and which option is more him? |
| `anti-hero-refine.svg` | His unmasked face today and refined (neutral, hurt, contempt), and the silhouette with two options (a longer tail with coat blades, a swept shoulder blade) | Is he colder and sharper in the right way, and which option adds more to the silhouette? |
| `empress-refine.svg` | Her unmasked face today and refined (neutral, hurt, a cold smile), and the silhouette with two options (a wide mantle, a crown and train) | Does the cheek chevron help or crowd the face, and which option reads as more regal? |
| `anti-hero-glasses.svg` | Orb's decision: the rival is the resident scary shiny glasses character. Six frame shapes drawn to Legal's rules (cut hex, blade lenses, chamfer plates, shard, slash cut, kite) at 200, 72, 24 and 12 px and in profile at fight size; the best two (blade lenses as the lead, cut hex second) in three lens states (clear, glare, glint); his gesture; where the glare fires (0.4 s at most); and the damage stages and glasses knocked off | Which frame? Should the glare hide his eyes completely or leave a faint shape? Are the glasses always on, or only for the taunt and finisher? |

Files: `glasses.mjs` and `gen-glasses.mjs` (the glasses), `faces.mjs` (the faces; the Cyborg's six and the refined three), `figures.mjs` (the silhouette variants for the figure kit), `gen.mjs` (the sheets).

The mask work is parked: see the note at the top of `docs/art/closeup-directions.md`.

Origin (proposed rows for `docs/legal/asset-origins.md`): ART-0013-GEN is `art/concepts/refine/faces.mjs`, `figures.mjs` and `gen.mjs` (procedural generators, AI-assisted, Claude Art Director session with human direction from Orb via the EP, Claude Code claude-sonnet-5-5, 2026-10-02); each SVG is a procedural output of them. Licence: Orb decides. Status: proposed.
