# Fighter identity text (for `data/fighters/<id>/fighter.json`)

Owner: Narrative and Fighter Identity. Version 1, 2026-09-29. Follows `docs/architecture/d1-roster-data.md` (section 3): the `identity` object carries Narrative's text. **Every name, title and tagline here is a placeholder. Orb names things later.** Lines are original and unsearched.

**How to use it.** Simulation can copy each `identity` block into that fighter's `fighter.json`, next to Art's colours (`col`, `aura`, `hair`), which I have left out. The four existing keys (`name`, `title`, `role`, `sigName`) keep **today's prototype values** for KAI and VORR, so tests and the finisher data still match. The new keys are `tagline`, `blurb`, `voice_device`, `voice_bible`, `pronoun` and `placeholder`.

| Key | Meaning |
|---|---|
| `name`, `title`, `role`, `sigName` | As in D1. For the four real fighters these are placeholders. |
| `tagline` | One short line for the select screen and load screen. |
| `blurb` | Two sentences for the select screen. |
| `voice_device` | An id for the fighter's speech device (see the table below). |
| `voice_bible` | The path to the voice bible. |
| `pronoun` | `he` or `she`, for captions and UI text. |
| `placeholder` | `true` while Orb has not named the fighter. |

**Voice-device ids.**

| Id | Device |
|---|---|
| `future_tense` | Promises in the future tense (the Protagonist). |
| `past_tense_rank` | Speaks about his opponent in the past tense and ranks him; present tense when the facade cracks (the Anti-hero). |
| `royal_we_revision` | A royal "we" that slips to "I", revision numbers, "petitioner" (the Empress). |
| `service_script` | Customer-service politeness over hunger (the Cyborg). |
| `past_tense_elegy` | Speaks in the past tense about places still standing (VORR, the prototype villain). |

## The real fighters (all placeholders)

Their roster ids follow D1's upper-case convention. The data ids are placeholders too.

```json
{ "id": "PROTAGONIST",
  "identity": {
    "name": "PROTAGONIST", "title": "Martial Artist", "role": "hero", "sigName": "Keeper's Lance",
    "tagline": "He'll fix it after the fight.",
    "blurb": "An earnest martial artist who loves a real fight and promises to rebuild afterwards. His blood runs from warm to boiling, and it costs him.",
    "voice_device": "future_tense", "voice_bible": "docs/narrative/voices/protagonist.md",
    "pronoun": "he", "placeholder": true } }
```

```json
{ "id": "ANTIHERO",
  "identity": {
    "name": "ANTI-HERO", "title": "The Rival", "role": "rival", "sigName": "The Barrage",
    "tagline": "You were adequate.",
    "blurb": "A brooding rival whose pride outranks his justice. He ranks everyone beneath him, and swallows that pride only when he has to. It shows.",
    "voice_device": "past_tense_rank", "voice_bible": "docs/narrative/voices/anti-hero.md",
    "pronoun": "he", "placeholder": true } }
```

```json
{ "id": "EMPRESS",
  "identity": {
    "name": "EMPRESS", "title": "Galactic Empress", "role": "villain", "sigName": "Decree Line",
    "tagline": "Please retain your copy.",
    "blurb": "A galactic empress who watches from behind her guard of honour. Every change of form costs her a mountain of paperwork, and she will tell you about it.",
    "voice_device": "royal_we_revision", "voice_bible": "docs/narrative/voices/empress.md",
    "pronoun": "she", "placeholder": true } }
```

```json
{ "id": "CYBORG",
  "identity": {
    "name": "CYBORG", "title": "Demon Cyborg", "role": "villain", "sigName": "Portal Blitz",
    "tagline": "The restaurant is now open.",
    "blurb": "A polite machine with a bottomless appetite. He eats the crowd, molts into new forms, and will ask to speak to your manager.",
    "voice_device": "service_script", "voice_bible": "docs/narrative/voices/cyborg.md",
    "pronoun": "he", "placeholder": true } }
```

## The prototype fighters (legacy placeholders)

These keep today's values for `name`, `title`, `role` and `sigName`.

```json
{ "id": "KAI",
  "identity": {
    "name": "KAI", "title": "Meridian Warden", "role": "hero", "sigName": "Meridian Lance",
    "tagline": "He keeps the fight away from the people.",
    "blurb": "The prototype hero. Pulled between the fight and the people underneath it, and his anguish rises with every loss.",
    "voice_device": "future_tense", "voice_bible": "docs/narrative/fighter-sketches.md",
    "pronoun": "he", "placeholder": true } }
```

```json
{ "id": "VORR",
  "identity": {
    "name": "VORR", "title": "Calamity Sovereign", "role": "villain", "sigName": "Calamity Wave",
    "tagline": "It was a lovely harbour.",
    "blurb": "The prototype villain. He feeds on collateral, and speaks of things that still stand as if they were already gone.",
    "voice_device": "past_tense_elegy", "voice_bible": "docs/narrative/fighter-sketches.md",
    "pronoun": "he", "placeholder": true } }
```

## Notes

- **KAI's and VORR's names are legal flags** (review-log RL-002 and RL-003). They are kept only because the tests and the finisher data still match them. When Orb names the fighters, only these text values change.
- **Proposed replacements, for when Orb agrees** (from `glossary.md`): KAI's title "the Warden" and signature "Keeper's Lance"; VORR's title "the Last Witness" and signature "Last Look". I have not put them in the blocks above, so the prototype's values do not shift under Simulation.
- **Role values.** D1 shows `hero` and `villain` today. I used `rival` for the Anti-hero, since he is neither. If the code only allows two, `villain` is the safe fallback.
- **Length.** Taglines fit on one line (about 40 characters). Blurbs are two sentences (about 150 characters), so the select screen can show them at a readable size.
- **Pronouns.** Three fighters are he and the Empress is she, per Orb.
