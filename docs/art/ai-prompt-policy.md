# AI-assisted art: prompt policy

Owner: Art Director. Version 0, 2026-09-29. A working policy for Orb, the EP and Legal to review. Not legal advice. Follows `docs/legal/licence-recommendation.md` section 8 (the rules for AI output), `originality-rules.md` and `asset-origins.md`.

Orb's answer: AI-generated assets are allowed (`docs/ep/vision.md`). This policy is how we use them without copying anything and without losing the records Legal needs.

## The rules in short

1. **No franchise names, ever, in any prompt.** No character names, series names, studio names, artist names, brand names, "in the style of" anything named, and no "not like X" (a negative prompt that names X still names it).
2. **No reference images.** No image-to-image input from any franchise, fan game or third-party source. No screenshots, no traced sketches. Lemming Ball Z and Lemming Ball Z 3d are off limits like any other franchise (`originality-rules.md`).
3. **Describe the design, not a resemblance.** Prompts say shape, material, palette, camera and purpose in plain words.
4. **Keep every prompt.** For every asset that ships, and for every asset that is sent to Legal, the full prompt, tool, model and date are saved in the repo.
5. **A human authors the characters.** Characters and signature designs need real human authorship: drawn, or heavily reworked, by a person. AI may explore. It does not finish (Legal 8.5.3).
6. **Nothing ships without an origin row and the checklist.** A row in `asset-origins.md` (Legal writes it) and Legal's originality checklist, item 4 above all.
7. **If an output looks like something, stop.** Do not refine it. See "When an output resembles something".

## What AI may be used for

| Asset class | AI allowed? | Condition |
|---|---|---|
| Concept exploration (thumbnails, mood, palette ideas) | Yes | Private working files. Nothing here ships, and nothing goes public. Prompts still follow the rules |
| Fighter and signature designs | Explore only | A person draws or heavily reworks the final. The prompt and the human changes are logged |
| Procedural generators and the art they output | Yes, this is the default | One origin row per generator, naming its files and seed rules. Generator code is reviewed as code |
| Icons, decals, wear-mask shapes, UI glyphs | Yes | Log per asset set. Human review of every output |
| Textures | Not needed | The look is untextured (`style-guide.md`) |
| 3D meshes from AI tools | Not yet | Needs a Legal review of the tool's terms first |
| Logo, title lettering and key art | No | Human-authored. Legal's marketing rule: no hero holding an orb aloft, no row of matching orbs |
| Environment concept and biome kits | Yes | Same as fighters: explore, then a person authors |
| Music, voice and sound | Out of scope | Audio's policy |

**Why not more.** The US Copyright Office's position (Legal 8.1) is that work made entirely by AI is not protected. Our licence would have nothing to grip on those parts, and anyone could copy them. Designs that carry the game's identity need a human hand. Under a consumer plan the infringement risk sits with us and not the vendor (Legal 8.2 and 8.3).

## Writing a prompt

**Do**
- Say what it is and what it is for: "a side-on character concept sheet, three postures, for a fighting game".
- Describe geometry and materials: "a tall narrow silhouette, a rigid pole on the back with six hanging rectangular plates, short jacket, bare forearms with wraps, dark boots".
- Give the palette as hex values from the art bible, and say how they are used ("body `#33264f`, gear `#d3cde3`, accent `#e0407f`").
- Give the look in generic craft words: "cel-shaded, flat colour, three tone bands, bold dark outline, faceted low-poly forms".
- Say the camera: "orthographic side view, neutral light grey background".
- State the constraints as positive rules ("hair short and dark, no upswept shapes"). Positive wording first.

**Don't**
- Name a franchise, a character, an episode, a studio, a director, an artist or a game, even to exclude it.
- Say "like", "in the style of", "inspired by" or "reminiscent of" anything named.
- Paste any text from the franchise or from a fan wiki.
- Use a model's "style presets" that are named after a work or an artist.
- Iterate toward a resemblance and then away from it. That produces a derivative.

**Allowed style words:** cel-shaded, flat colour, low-poly, faceted, bold outline, hard-edged shadows, choreographed key poses, flash-animation feel. "Anime energy-brawler" as a genre word is allowed in briefs (Orb's own README line uses it). Studios, series and creators are not.

## The record for each asset

Each AI-assisted asset gets a file `art/prompts/<asset-id>.md`, in the format below. `art/prompts/TEMPLATE.md` is the blank. Legal copies the key fields to a row in `asset-origins.md`.

```
asset id: ART-0001
date (UTC):
tool and model and version:
settings and seed (if any):
purpose:
prompt (verbatim, complete):
negative prompt (verbatim, complete; also franchise-free):
input images: none (or the path and its own origin row, human-made only)
outputs kept (paths):
outputs rejected (count; kept only if flagged):
what a human changed (drawn, reworked, selected, arranged):
originality checklist (silhouette, three flat colours, "what does this remind me of?"): pass or fail, and who checked
reverse-image search run (date, by whom, result):
Legal review (date, RL id):
disclosure category (Steam, itch.io): ships / store page / development aid only
```

For generator code, the record is the origin row plus the code header: the tool, the model, the date and the human direction. See `art/concepts/anti-hero/README.md`.

## Review before anything locks

1. **Originality checklist** (`originality-rules.md`): shrink to a silhouette, then to three flat colours, and ask "what does this remind me of?" If a specific character comes up, redo it. Answer in the record.
2. **Reverse-image search.** Before a design is locked, someone runs a reverse-image search on the outputs (Legal recommends who). AI output can resemble existing work even from a clean prompt.
3. **Human authorship check.** For characters and signatures: the record names what a person made or changed.
4. **Legal** answers GO, CONDITIONAL or NO-GO in `review-log.md`. A flagged design cannot lock or ship.

## When an output resembles something

If a result looks like a named character, a costume, a pose or a logo:
1. Stop. Do not refine it and do not "move away" from it.
2. Save the prompt and the output in a flagged folder and tell Legal through the EP.
3. Throw the output away.
4. Start again from a fresh description, in a different shape language (change the silhouette first, not the colours).
5. Log the incident in the record.

## Disclosure

- Steam asks for a description of AI used for content that ships or appears on the store page (Legal, section 7). Development aids only (code assistance) are exempt. We plan no live generation.
- itch.io has a generative-AI field.
- The README states AI assistance. Git history records code assistance through the `Co-Authored-By` lines.
- Each shipped AI-assisted asset is flagged in `asset-origins.md`, so the store answers can be filled in honestly at submission.

## Tools

| Tool | Status | Notes |
|---|---|---|
| Claude, through Claude Code (Pro plan, consumer terms) | In use | Writes generator code and concept sheets. Consumer terms give no vendor IP indemnity (Legal 8.2) |
| Any image or mesh generator | Not approved | Needs a Legal review of the terms (commercial use, output ownership) and a row before first use. Free tiers often bar commercial use |

## Open questions for Orb

1. **May AI-assisted concept art appear in public devlogs and the store page?** It is safest to show only human-authored finals.
2. **Who is the human author** of the four fighters' final designs: Orb, or a commissioned artist? Legal needs a name against each locked design.
3. **Are AI 3D mesh tools in scope at all?** The default here is no until Legal has read a tool's terms.
