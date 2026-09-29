# Signature variants

Owner: Combat and Choreography. Status: P0 wave 1. This document holds the current signature variant table, what each context axis actually changes, and the gaps against pillar 7 ("signatures adapt"), with a proposed composition model to close them. The signature's atoms are defined in `move-grammar.md` (section 2.7) and its outcome rules in `exchange-templates.md` (section 2.9).

**Source.** `index.html:NNN` is a line of `prototype/index.html` at commit `7233c96`. Observed shares come from QA's baseline (`qa/baseline-p0.md`, section 6, default arm) unless marked otherwise.

**Pillar 7, and the done-when this document is measured against.** One signature move plays out differently by biome, altitude and the defender's stance. The charter adds collateral state as a key, and requires that a signature never plays the same way in two different contexts.

---

## 1. What a signature is today

Each fighter has one signature: KAI's Meridian Lance and VORR's Calamity Wave (`index.html:185-186`). Both are the same code (`planBeam`, `index.html:581-622`). The only per-fighter differences are the name on the banner and the beam's colour (the fighter's aura). In the clash score, the villain also adds `0.08·menace` (`index.html:625`).

A signature costs 45 ki (`index.html:395, 406`) and runs as:
1. a 0.8 s charge in which the attacker moves vertically to above the defender;
2. a beam fired down at the defender and 2,000 + 400·tier u beyond, carving where it passes low;
3. one of five outcomes chosen by the defender's state: CLASH, GUARD, DODGE, HIT or ESCAPE.

## 2. The current variant table

The variant is chosen once, from the biome under the defender at the moment the signature is requested (`index.html:583-584`). It is shown in the feed as `<signature> over <biome> (<VARIANT>) → <outcome>` (`index.html:591`).

| Biome | Planet share | Variant | What differs from a plain beam | Kind of difference | Share of beams (AI play) |
| :--- | ---: | :--- | :--- | :--- | ---: |
| ocean | 26% | HORIZON CLEAVE | nothing | name only | 69% |
| city | 16% | BOULEVARD RAZE | nothing | name only | 4% |
| village | 17% | BOULEVARD RAZE | nothing (same variant as city) | name only | 13% |
| plains | 9% | MERIDIAN SCAR | nothing | name only | 9% |
| forest | 10% | FIRESTORM | flame particles wherever the beam passes within 140 u of the ground (`index.html:655`) | cosmetic | 1% |
| desert | 10% | GLASS TRENCH | pale dust and two extra sparks at each carve sample (`index.html:650-651`) | cosmetic | 1% |
| mountains | 11% | RIDGE BORE | carve craters 9 + 2.2·tier deep instead of 5 + 2.2·tier (`index.html:649`) | mechanical (terrain) | 3% |

Splashes over the sea (`index.html:654`) come with any variant whose beam runs low over water, so they belong to the location, not to HORIZON CLEAVE. FIRESTORM's flames are particles only: trees along a beam are destroyed by the ordinary area damage (`index.html:302`), whatever the variant.

**What this means in play.**
- Six names cover seven biomes. Only one variant changes the world differently (RIDGE BORE), and two change only particles.
- In AI play, 95% of signatures are a variant that differs from a plain beam by name alone: HORIZON CLEAVE 69%, BOULEVARD RAZE 17%, MERIDIAN SCAR 9%. The 69% ocean share follows from where the AI fights (`qa/baseline-p0.md`, finding 3), not from the signature system.
- Legal has cleared all six names as working labels (review log RL-006 to RL-011). FIRESTORM is cleared as a label only and may be renamed by Narrative for consistency with the "place or material plus effect" pattern (RL-008).

## 3. What each context axis changes today

| Axis | Authored effect today | Emergent effect | Citation |
| :--- | :--- | :--- | :--- |
| Biome under the defender | picks the variant name; three variants add a cosmetic or terrain extra | none | `index.html:583-584, 649-655` |
| Biome along the path | none: the variant's extras apply to every carve sample, whatever the ground (CC-012) | the carve damages whatever it crosses: buildings, trees, terrain | `index.html:646-656` |
| Altitude (of the defender or attacker) | none | changes where the beam meets the ground. A low defender is carved under; for a high defender the carve lands far behind them, or nowhere | `index.html:595, 601-605, 648` |
| Defender stance | picks the outcome (section 1 of `exchange-templates.md`) | the beam's shape, path and carve are the same for every outcome except CLASH, where the winner's beam fires 1.6 s later from wherever the winner is | `index.html:586-590, 603-605, 629-634` |
| Collateral state (casualties, menace, anguish) | none, except menace in the clash score | none | `index.html:625` |
| Personality (hero, villain) | none: same code, different name and colour | none | `index.html:185-186, 581` |
| Power tier | continuous scaling, not a variant: width 24 + 9·tier, length + 400·tier, carve radius 20 + 7·tier, carve depth + 2.2·tier, area damage 110 + 75·tier, explosion radius 60 + 30·tier | bigger scars at higher tiers | `index.html:601, 643, 649, 653, 612` |

## 4. The variant matrix against pillar 7

Crossing the axes pillar 7 names gives 140 contexts: 7 biomes, 4 altitude bands (submerged, ground, low air, high air, as proposed in section 5.2) and 5 defender outcomes. How many different plays does the prototype have for those 140 contexts?
- **Mechanically distinct plays:** 10. RIDGE BORE or not, times the 5 outcomes.
- **Visually distinct plays:** 20. Four variant looks (plain, glass, fire, deep bore), times the 5 outcomes.
- **Altitude:** adds nothing authored.

So each play is shared by 7 contexts on average, and the whole ocean row, the whole plains row and the city and village rows play identically apart from the label.

Concrete failures of "never plays the same way in two contexts":
1. The same signature against a DEFENSIVE defender over the city and over a village: identical in every respect, name included.
2. Over the ocean, at the waterline and at 1,200 u up: the same beam, the same outcome rules, the same effect. Only the point where the carve meets the seabed differs.
3. Against an EVASIVE defender and an ESCAPE defender in the plains: the same charge and the same beam. DODGE and ESCAPE differ only in which way the defender teleports or bursts, and the beam's path is identical.
4. KAI's Meridian Lance and VORR's Calamity Wave in any context: identical except colour, name and the villain's small clash bonus. The hero's signature does not spare civilians and the villain's does not seek them, although the launch planner already expresses exactly that difference for launches (`index.html:371`).

## 5. Closing the gap

### 5.1 The composition model
The signature becomes a layered, data-driven special in the procedural move system: `procedural-moves.md`, section 4.3. There are five layers:
- L1 approach and charge;
- L2 path;
- L3 material response, with a tier-scaled "bite" budget, so the beam stops at the ground it strikes instead of razing underground and along other biomes (fixes CC-012);
- L4 outcome resolution;
- L5 follow-up.

Each layer is a small table keyed by ground material, altitude band, outcome, personality and tier. About two dozen authored rows cover every reachable biome × band × outcome cell, instead of one hand-made move per cell. The same model gives KAI's and VORR's signatures different temperaments in the same context:
- a carer narrows the bite and angles away from people;
- a villain widens it and aims at them.

QA's "never plays the same way in two contexts" test is the fingerprint test in `procedural-moves.md`, section 13 (T1 to T3).

### 5.2 Altitude bands
Height is measured from the local surface: `groundY` on land, sea level (0) over water. It is read once, when the signature is planned. The shares are approximate, from headless measurements of AI play made for this work.

| Band | Cut | Why here | Share of AI signatures today |
| :--- | :--- | :--- | ---: |
| Submerged | over the sea and y < −60 | the same test as submerged cover (`index.html:670`) | about 55% |
| Ground | under 140 above the surface | the ground-level power-up threshold (`index.html:697`) and SLAM DOWN's altitude test (`index.html:362`); the beam is inside its carve threshold here | about 33% |
| Low air | 140 to 600 | the beam passes over the defender and bites the ground several hundred units behind | about 10% |
| High air | 600 and above (a "sky" sub-band from about y 2,100, where the 2,400 cap on the rise leaves no room for a steep shot) | beams at today's geometry mostly never reach the ground, so the move has no weight | about 2% |

More than half of all AI signatures today strike a defender who is underwater. The composition model gives the submerged band its own approach (surface first, then fire) and its own material response, so this common case stops being the least interesting one.

### 5.3 Assessment: LANE SWEEP for villages (Narrative's proposal)
**Recommendation: adopt it, as a material entry rather than a rename.**
- Today villages and the city share BOULEVARD RAZE and play identically (section 4, failure 1), which pillar 7 does not allow.
- In the layered model, village ground (low timber houses along lanes, 17% of the planet) gets its own L3 response: a low, sweeping graze that flattens a row of houses along the lane, instead of the city's tower-tearing raze.
- Where the city response scars *upward*, through tall structures, the village response scars *along* the ground.

**Open for Game Design, through the EP:** the collateral numbers. Villages hold far fewer civilians per structure than the city (2 to 6 per house against tower populations), so a sweep should be tuned so that villages still read as a real cost to the hero's anguish.

The name is Narrative's working label, pending Legal's screening and Orb's pick.

### 5.4 Proposed renames (pending Legal and Orb)
From Narrative's glossary (`docs/narrative/glossary.md`, section 10). None is adopted here; the current names stay in the code and in these documents until Legal and Orb rule.

| Current | Proposed | Reason given |
| :--- | :--- | :--- |
| HORIZON CLEAVE | TIDE CLEAVE | "Horizon" is another company's brand (RL-006) |
| BOULEVARD RAZE (villages) | LANE SWEEP | see 5.3 |
| FIRESTORM | CANOPY BURN | breaks the "place or material plus effect" pattern (RL-008) |
| MERIDIAN SCAR | FURROW SCAR | "Meridian" leaves with the old working title |
