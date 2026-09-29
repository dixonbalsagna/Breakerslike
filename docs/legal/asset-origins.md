# Asset origins

Owner: Legal and IP Compliance. The single origin log for every shipped asset (art, audio, music, data content, fonts, text). Not legal advice.

**Rules.**
- No asset merges without a row here. Only Legal writes the log.
- Art, Audio and Narrative send proposed rows in their reports to the EP. Legal adds them after review.
- Procedural assets (made by code) get one row per generator, naming the generator file and its seed rules.
- AI-assisted assets record the tool, model, date and where the prompt is kept. Prompts never name franchises or characters.

**Status vocabulary:** proposed, under review, GO, CONDITIONAL, NO-GO, shipped, withdrawn.

**Entry template**

| Asset ID | Path | Type | Origin (human-made, procedural, AI-assisted, third-party, public domain) | Author or source | If AI: tool, model, date, prompt location | Licence (SPDX) | Status | Legal review (date, RL id) | Notes |
|---|---|---|---|---|---|---|---|---|---|

**Log**

**Logged 2026-09-29 (proposed by Art, Audio and UI through the EP).** All are AI-assisted (Claude Code, claude-sonnet-5-5) with Orb's direction through the EP. **No human author yet** (`licence-recommendation.md` 8.5.3): in US law, output with no human authorship may have no copyright, so nothing here should be treated as protected, and the licence column follows Orb's decision. Concept art is not shipped. Status: logged, not shipped.

| Asset ID | Path | Type | Origin | Prompt record | Status |
|---|---|---|---|---|---|
| ART-0001 (GEN, OVERVIEW, A, B, C, SIL) | `art/concepts/anti-hero/` generators and sheets | procedural generator and concept sheets | AI-assisted, procedural | `art/prompts/ART-0001-anti-hero-concepts.md` | logged, concept only |
| ART-0002 (GEN, OVERVIEW, SIL) | `art/concepts/anti-hero/` round 2 | as above | as above | `ART-0002-anti-hero-round2.md` | logged, concept only |
| ART-0003 (GEN, CMP, D1 to D4) | `art/concepts/directions/` | as above | as above | `ART-0003-character-directions.md` | logged, concept only |
| ART-0004 (GEN, CMP, V1 to V5) | `art/concepts/blank/` | as above | as above | `ART-0004-blank-variations.md` | logged, concept only |
| ART-0005 (GEN, S1 to S4, DATA) | `art/concepts/marked-aura/` | as above | as above | `ART-0005-marked-aura.md` | logged, concept only. Style screen in `q3-screen.md` |
| ART-0007-SHARED | `art/concepts/shared/marks.mjs` | shared module (code): sigils, dome mask, palettes | AI-assisted, procedural | `art/prompts/ART-0007-legal-conditions.md` | logged, concept only |
| ART-0007-S5 | `art/concepts/marked-aura/ma-5-legal-checks.svg` | checks sheet (output of ART-0005-GEN) | AI-assisted, procedural | `art/prompts/ART-0007-legal-conditions.md` | logged, concept only. Uses generic drawings of the patterns to avoid |
| ART-0006 (GEN, COIL) | `art/concepts/turnaround/` | turnaround sheet | as above | `ART-0006-coil-turnaround.md` | logged, concept only |
| AUD-GEN-001 | `audio/synth/impact_synth.gd`, `dsp.gd`, `data/impacts.json` | audio generator (code and recipes) | procedural, code written with AI assistance | none (no audio model, no audio input) | logged |
| AUD-GEN-002 | `audio/synth/grunt_synth.gd`, `data/grunts.json` | audio generator | procedural. Vowel formants are published averages (Peterson and Barney, 1952): facts, not a recording | none | logged |
| AUD-GEN-003 | `audio/synth/music_sketch.gd`, `data/sketch_*.json` | music sketch generator | procedural. Not in `audio/README.md`'s table: mapped from its text, **Audio to confirm** | none | logged, to confirm |
| AUD-PREV-001 | `audio/preview/*.wav` (sounds) | derived audio | procedural, output of GEN-001 and 002 | none | logged (not a source) |
| AUD-PREV-002 | `audio/preview/sketch-*.wav` | derived audio | procedural, output of GEN-003. **Audio to confirm** | none | logged (not a source) |

**AI audio tools.** Orb allows AI-generated audio once Legal clears the specific tool's terms. **None is named yet, and none is cleared.** Before any tool is used, Audio names it and Legal reads: commercial use and output ownership, free-tier limits, rules on training and opt-out, voice-cloning and likeness limits, and prohibited uses. Legal adds a register row. In-repo procedural synthesis needs no tool row. Third-party sample libraries (for example the CC0 orchestral samples Audio mentions for the brass sketch) need a register row and a licence check before use.


| Asset ID | Path | Type | Origin | Author or source | If AI | Licence | Status | Review | Notes |
|---|---|---|---|---|---|---|---|---|---|
| EXAMPLE-000 (fake, delete when real rows exist) | art/example/tree.svg | art | AI-assisted | Example Person | ExampleTool, model-x, 2000-01-01, prompts/example-000.txt | CC-BY-4.0 | proposed | none | Not a real asset |
