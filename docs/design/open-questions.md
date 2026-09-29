# Open design questions for Orb

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

Design decisions that are Orb's to make. Each has options, Game Design's recommendation, and the default the team follows until Orb answers. The EP takes them to Orb one at a time. Orb asked for plenty of questions, so they are grouped by topic and numbered for quick answers.

**Sources.**
- Orb's answers to questionnaire 1 are in `docs/ep/vision.md`.
- Questions about each new system are in `systems-sketch.md`, and are counted at the end.
- Decisions inside Game Design's remit (rules, numbers, win conditions, the mode list) are not listed as questions. They are summarised at the end so Orb can overrule any of them.

## Already answered (questionnaire 1)

These are recorded here and closed:
- **Tone:** all four tones at once.
- **Casualties:** kept.
- **Stances and the director:** kept.
- **Modes at 1.0:** local 1v1, versus AI, arcade or survival, a training sandbox, and 2v2 or free-for-all. Online comes after launch.
- **Match length:** 5 minutes or more, felt as about 7.
- **Roster at 1.0:** four fighters.
- **Planets:** procedural.
- **Presentation:** 2.5D side-on.
- **Progression:** not asked yet (G9).

---

## A. The match

**G1. How does a 7-minute match end?**
- A. The first KO, with HP in segments. Each break starts a new chapter (`economy.md` §1).
- B. Rounds, best of three, on a persistent planet.
- C. A single HP bar, with longer exchanges only.

Recommendation: **A.** It gives chapters without resets, and the season-finale arc runs unbroken. *Default: A.*

**G2. Must the last segment end with a finisher?**
- A. Yes. When the last segment is low, the next decisive exchange becomes a finisher exchange: the Protagonist's energy finisher, the Anti-hero's hand-to-hand finish, and so on. It still carries clash and escape odds.
- B. No. Any hit can KO.

Recommendation: **A.** Every match ends on a climax, and Orb's fighter notes already describe finishers. *Default: B* until Combat has finisher templates.

**G3. Where do the one-liners come from?**
- A. Barks triggered by events during play, with no pause (Narrative).
- B. Short pauses for a line at chapter breaks and transformations.
- C. Both.

Recommendation: **C.** Short pauses only at set pieces, never mid-exchange. *Default: A.*

**G4. Should the camera ever take control for a cinematic?** For example at a transformation, a relocation or a finisher.
- A. Yes, for at most 3 s, never during an open window.
- B. Never.

Recommendation: **A** (Camera's anti-goal: no cinematic without cause). *Default: A.*

## B. Fighters and identity

**G5. Pillar 5 for four fighters.** The prototype's hero is pressured by collateral and its villain feeds on it. Should every fighter have a distinct relationship to the world? The sketch in `economy.md` §4.2:
- the Protagonist wrecks by fixation and relocates to protect;
- the Anti-hero is indifferent;
- the Tyrant is cruel for show;
- the Cyborg feeds on people.

Recommendation: **yes**, with a visible ego meter for each (Respect, Pride, Wrath, Hunger). *Default: yes.*

**G6. How often do transformations happen?** For example, the first form around 1:00 to 2:30 and the top form in the last third, so the four acts read the same for every fighter.

Recommendation: **yes, with a time floor on every track** (`balance-targets.md` §3). *Default: yes.*

**G7. Is it all right for the roster to be asymmetric?** Each fighter would be strong in different phases:
- the Tyrant early, through his minions;
- the Protagonist late, after relocation;
- the Cyborg near people.

The overall win rate would still be held at 45 to 55%.

Recommendation: **yes.** This is how the rivalry reads. *Default: yes.*

**G8. The same fighter twice.** Can both sides pick the same fighter in 1v1, or on one team in `team-2v2`? This matters most for the Tyrant's minions and for Tandem.

Recommendation: **yes in 1v1** (the mirror rival in arcade); **no duplicates within a team**. *Default: the same.*

**G9. Progression and unlocks.**
- A. Everything unlocked from the start.
- B. Cosmetic unlocks.
- C. Gameplay unlocks.

Recommendation: **A** for a free, open-source, versus-first game. *Default: A.*

## C. Modes (ids in `modes.md`)

**G10. Arcade or survival first?**

Recommendation: **`arcade` first, with `survival` as its rule set.** It uses the rivalry and one-liners, and survival costs only rules. *Default: that.*

**G11. 2v2 or free-for-all first?**

Recommendation: **`team-2v2`.** Tandem and the Unison line work best with a teammate, and the camera frames two groups more easily than four. *Default: that.*

**G12. In `team-2v2`, can a KO'd teammate be revived?**
- A. No. The fighter is out.
- B. Yes, with a risky beat close to the fallen teammate.

Recommendation: **A** at 1.0. *Default: A.*

**G13. How many local players at once?** Four people on one screen and one keyboard is hard; gamepads help.

Recommendation: **up to four with gamepads, two on one keyboard.** *Default: that.*

## D. Tone boundaries

**G14. How graphic is the violence?** Orb asked for mature violence with a humorous voice. Where is the line?
- A. Impact, craters and collapse; no blood or gore. Casualties are counted, not shown.
- B. Stylised injuries on fighters only.
- C. Explicit.

Recommendation: **A.** It keeps "mature" in scale and stakes, suits the old-laptop art style, and keeps store ratings simple. *Default: A.*

**G15. How is the Cyborg's feeding shown?** (`systems-sketch.md` §5, question 1)

Recommendation: **a comic cut or a stylised on-screen gag**, never lingering. *Default: that.*

## E. Per-system questions

**G16 onward.** `systems-sketch.md` lists 24 questions, four per system:
- transformations;
- minions;
- fusion (deferred; Tandem in its place);
- relocation (keystones);
- civilian consumption;
- procedural planets.

Each has a recommendation there. The most urgent, because they shape P2 and P3:
- **Transformations Q1:** can a fighter be hit while transforming?
- **Minions Q1:** what does a human playing the Tyrant control?
- **Fusion Q1:** Tandem, the Unison line, or both?
- **Legal's replacement picks** for every signature (`docs/legal/fighter-concepts-review.md`, "Orb decides"). The docs use Legal's first option as the working default.
- **Relocation Q2:** is relocation a win condition or only the way to the Protagonist's final form?

---

## Decisions Game Design made (Orb may overrule any of them)

- **Balance bands** (`balance-targets.md`):
  - win rate 45 to 55% in every pairing and team composition;
  - game length: a median of 6 to 8 minutes;
  - escalation checkpoints;
  - numeric collateral bands, including a low-tier bleed cap and a floor of civilians left alive;
  - launch cap 40%;
  - variety caps of 40%;
  - stance and story-beat bands.
- **Stance rules for P2** (`stance-matrix.md` §5):
  - attacking drops your guard;
  - every stance has an attacking profile;
  - every cell gets a second outcome decided by a state the player can see;
  - the defender earns the counter against a light;
  - a missed parry costs ki;
  - chains follow the exchange's result;
  - a tier advantage always helps its owner.
- **Economy** (`economy.md`):
  - HP segments;
  - transformations drive the tier;
  - every ego meter decays or is spent and is visible;
  - rulings on Narrative's Interpose (accepted, as a DEFENSIVE outcome), Resolve (accepted, as presentation), Savour (folded into the Cyborg's feeding), Foretell (accepted, as a bark in the existing charge beat) and hesitation near population (rejected).
- **Modes** (`modes.md`): stable ids, 1.0 scope, `arcade` and `team-2v2` first, and the CUT-IN rule for multi-fighter exchanges.
- **Originality: Legal's replacements are the working defaults, pending Orb's pick:**
  - keystones, not a set of seven and no wish;
  - Tandem in place of fusion;
  - Runaway and Push stages;
  - the "revised" tyrant;
  - a surveyor line and a cable whip;
  - Takeout, the backup drive and the hatch chip;
  - no hair-colour change as a power cue.
