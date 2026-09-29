# P0 wave 1 brief: accessibility-localization

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): this is your first brief. It covers the accessibility checklist, an assist-mode review of the prototype's timing windows and HUD, and the localization plan.

GOAL: Give every later director a concrete accessibility checklist, a list of assist-mode needs grounded in the prototype's real numbers, and a localization plan that keeps all text out of code, without waiting on Orb's answers.

CONTEXT (read first):
- CLAUDE.md (design pillars, prototype controls, code map) and docs/directors/accessibility-localization.md.
- prototype/index.html, read-only for you. Lines after 216 moved down by one tonight, so anchor on function names.
  - Parry: wind() (424) sets ex.windowStart. strike() (521, check at 525) parries if the defender pressed light or heavy (control(), 853: lastAtkT = T) at any time from windowStart until a strike without noParry lands.
  - The parry window is about 0.10 s (6 frames) in TRADE BLOWS, PRESSURE and GUARD BREAK, and about 0.33 s (20 frames) in HEAVY CLASH — WON. It is absent in the dodge templates, the other clash outcomes, pursuit and charge interrupt, even though some of those still open it. Verify from the code.
  - Chain: openWindow() (544) sets ex.ext = {start:T, until:T + 0.6}, 36 frames. dirUpdate() (574) chains if lastAtkT >= ext.start, up to 5 links at 6 ki each.
  - Parry and chain are the assist targets.
- Visual-only or colour-only information:
  - banner() text (PARRY cyan #9fe0ff, chain gold #ffd45a) and ring() flashes;
  - cam.shake: render() uses Math.random() at 1147, a cosmetic RNG; note it for the EP because of QA-002;
  - the HUD in the draw code (bars, TIER, MENACE and ANGUISH, CIVILIANS LOST) and the 10 to 12 px canvas fillText sizes.
  All strings are hardcoded in JS, and the prototype has no audio.
- Legal files:
  - docs/legal/licence-register.md LR-004: no font is bundled; register any font first; SIL OFL 1.1 is accepted;
  - originality-rules.md: our own HUD and type;
  - review-log.md RL-002 (KAI is NO-GO for ship) and RL-015 ('ki' is a grey zone);
  - name-screening.md stage 4: native checks of names in 8 languages, which you can offer through the EP.
- qa/baseline-p0.md: matches average 55 s. Golden hashes are pinned, so you must not touch the sim.
- Tonight Controls owns window widths, UI & UX owns HUD cues, Art owns palettes and VFX proposes colour lanes. You set the requirements they must meet, through the EP. Your outputs feed UI & UX, Controls, Audio, Narrative and Encounter Systems.

YOU OWN: docs/accessibility/ and localization/. Nothing outside them.

ACCEPTANCE CRITERIA:
1. docs/accessibility/checklist.md is an original checklist in your own words, drawn from recognised game-accessibility practice. Group it as motor, vision, hearing, cognitive and photosensitivity, plus a short section on visual-only information. Each item is testable, tagged by gate (P2, P3 or P5) and by owner director, and has a pass/fail column. Do not paste text from any published guideline; cite sources by name only.
2. docs/accessibility/assist-review.md:
   - covers the parry and chain windows and the HUD, citing the functions and constants above;
   - proposes assist values in whole 60 Hz ticks (for example a parry window widened to X and a chain window to Y, with a cap);
   - classifies every option. Presentation options must not change sim state or golden hashes. Gameplay assists change outcomes, so they must be deterministic: recorded in the match settings, the replay header and the input stream, so seed plus settings plus inputs reproduce the match, and they never change the sim clock. Whether gameplay assists are allowed in online or ranked play is 'Orb decides', with Game Design;
   - lists each visual-only cue and the audio or text alternative Audio will need.
3. The same file lists at least 6 accessibility options, each with a default: remapping, hold/toggle, the assist windows, colour-blind-safe palettes, shake and flash reduction, subtitles or captions, and text scale. Colour-blind needs are requirements Art's palette must meet: contrast, and hue separation for the four stances, the tiers and the six beams. Mark any option that hinges on presentation or platform 'Orb decides', with trade-offs.
4. docs/accessibility/localization-plan.md defines a string-table format with key naming, plurals, placeholders and a context note for translators. Offer at least 2 format options (for example JSON against gettext PO) with trade-offs, and note the dependency on the engine choice (ADR 0001). Give text-expansion budgets by language group, font-coverage needs (Latin, CJK, Cyrillic, with RTL optional) and a rule for keeping text out of code, with a lint-check idea. Include a language shortlist marked 'Orb decides'.
5. localization/en.json, or the format you recommend (provisional until ADR 0001), holds seed English strings for every string currently hardcoded in prototype/index.html: banners, HUD, feed, controls, beam and move names, fighter names and titles. Keys are stable and role-based (for example fighter.hero.name, not kai.name). A README explains keys, placeholders and plurals, and flags the placeholder values: KAI (RL-002, NO-GO for ship), the 'KI' strings (RL-015) and the game name. Do not edit the prototype.
6. The plan includes an accessibility-audit procedure for each gate, and a list of questions for the EP and Orb, including the inputs you need from Narrative and UI & UX.

CONSTRAINTS: No git state changes. Everything must be original. Use no franchise terms in the sample strings, and use names only from the current placeholders, flagged as above. Presentation options never change sim outcomes or hashes, and gameplay assists change them only through recorded settings. Do not bundle fonts or libraries.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage.

## Since this brief was drafted

From Narrative:
1. Native-meaning checks are needed for the hero shortlist:
- Welsh: Wyn, Havren
- Italian: Orlo
- Scots: Solan
- Hungarian: "Ilyen" means "such"

2. The hero speaks in the future tense and the villain in the past tense (docs/narrative/fighter-sketches.md). That device may not translate, so assess it early.

3. Review glossary naming rules 6 and 7 (docs/narrative/glossary.md): no puns or idioms in mechanical terms, and HUD labels of 12 characters or fewer.
