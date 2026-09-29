# Art: index

Owner: Art Director. 2026-09-29. Art owns `art/` and `docs/art/`.

| File | What it is | Status |
|---|---|---|
| `style-guide.md` | The look: faceted cel, scale and readability, palette and value rules, outline, what Rendering needs, wear and damage on bodies, biome palettes | v0 draft |
| `anti-hero-concepts.md` | Round 1: three Anti-hero silhouettes (A, B, C), the silhouette test, a recommendation. Orb picked none | v0, pending Legal review |
| `anti-hero-round2.md` | Round 2: five silhouettes (D, E, F, G and C revised), forms without a pole, the test, a recommendation, three questions for Orb | v0, pending Legal review, Orb decides |
| `directions.md` | Four character art directions (Blank, Ink, Toy, Poster), each drawing all four fighters, with a comparison and a recommendation | v0, pending Legal review, Orb decides |
| `blank-variations.md` | Round 3: five variations of Blank (Seam, Porcelain, Marked, Inked, Aura) in three-quarter view, with expression answers and a greybox mock-up | v0, pending Legal review, Orb decides |
| `marked-aura.md` | Round 4: Marked plus Aura as one style: mask tone per fighter, the aura's states and rules against the HUD crown, four staged moments in the greybox scene | v0, pending Legal review, Orb decides |
| `ai-prompt-policy.md` | How AI-assisted art is made, recorded and reviewed | v0 draft, for Legal and Orb to review |
| `../../art/concepts/anti-hero/` | The SVG sheets and the deterministic generator that writes them | v0 |
| `../../art/prompts/` | Prompt records (`TEMPLATE.md`, `ART-0001` to `ART-0005`) | v0 |

**Superseded.** The wave-1 art brief (three whole-game directions, `docs/art-bible/`) is replaced by Orb's answers: 2.5D side-on, cel-shaded plus low-poly. Nothing under `docs/art-bible/` was written. The parts that still fit are in the style guide: biome look notes and destruction states (section 8), the silhouette test (3.1) and the palette rules (3).

**Decisions still owed by Orb** (ranked in `anti-hero-concepts.md`, section 9)
1. The Anti-hero's silhouette (round 2 recommends D, the Duelist, with a coiled low posture; see `anti-hero-round2.md` for the three questions).
2. Shed Regalia: deferred by Orb.
3. The Anti-hero's face, age and build.
4. Cape: decided, none. Narrative's Empress line will change once his look is picked.
5. How graphic the wounds are on screen by default, and whether civilians visibly die.
6. The number of forms (six now).
7. The hue lanes for the four fighters.
8. Whether AI-assisted concept art may appear in devlogs and the store page, and who is the human author of the final fighter designs (`ai-prompt-policy.md`).

**Folder note.** `art/concepts/.gdignore` keeps Godot from importing concept art into the game project. It also keeps concept SVGs out of exports.
