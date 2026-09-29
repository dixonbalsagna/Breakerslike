# Open design questions for Orb

Owner: Game Design. Status: updated after questionnaire 3. Date: 2026-09-29.

Design decisions that are Orb's to make. Each has options, Game Design's recommendation, and the default the team follows until Orb answers. The EP takes them to Orb. Orb's answers so far are in `docs/ep/vision.md`. Decisions inside Game Design's own remit are summarised at the end so Orb can overrule any of them.

## The N questions: where they stand

- **N1. Damage model.** Answered: Variant A, Wounds (`damage-model.md`).
- **N2. The wear readout.** Orb asked for pitches. Five readouts are in `pitches.md` §1. The recommendation is the in-world aura crown plus wound cards by default, glyphs as a toggle, and the silhouette in `training` and for accessibility. **Orb picks.**
- **N3. Rally.** Orb asked for one rule per fighter. The pitches are in `pitches.md` §2: Second Wind, Spite, Emergency revision and Reboot, with five limits so finales don't loop. **Orb picks.**
- **N4. Downtime.** Answered: the player fills it, with set pieces and quick verbal exchanges. Eight ideas are in `pitches.md` §3, and the first four are recommended for the first playable. **Orb picks.**
- **N5. Orbs.** Replaced by Legal's screen. There is no fixed count: fragments are shed by planet damage and contested, and the fold unlocks on the total mass held (`pitches.md` §4). Two small questions for Orb remain there: a time floor for the fold, and what a rival's grab gives.

## Still open from earlier

- **G10.** Arcade or survival first. Recommendation: `arcade`, with `survival` as its rule set.
- **G13.** Local players at once. Recommendation: up to four with gamepads, two on one keyboard.
- **G14.** How graphic the violence is. Recommendation: impact, craters and collapse; no gore; casualties counted, not shown.
- **G15 and the Cyborg's food.** Orb asked for a pitch. Takeout, in `systems-sketch.md` §5, is the pitch. How graphic consuming is follows G14.
- **Multiplier stage.** Orb asked for a replacement pitch: see `systems-sketch.md` §1. Push, a state that trades health for speed, is the working pitch. Under `damage-model.md` it spends wear rather than HP.
- **Fusion.** Orb wants a true merge with an original trigger and look. Legal screens it; design follows Legal's review.
- **Per-system questions** in `systems-sketch.md` that questionnaire 3 did not answer:
  - Relocation Q2: a win condition, or only the path to the final form?
  - Consumption Q2 to Q4.
  - Planets Q3: can players share seeds?

## Answered and closed (questionnaires 1 and 3)

| Question | Orb's answer | Where it now lives |
| :--- | :--- | :--- |
| G1. How a match ends | No health meters. Location-based damage, handled differently per fighter | `damage-model.md` |
| G2. Must it end on a finisher? | Always, fighter-specific | `damage-model.md` §5 |
| G3. One-liners | Barks during play and short pauses at set pieces | Narrative |
| G4. Cinematics | Yes; longer than 3 s is fine | Camera |
| G5. Ego meters | Yes, visible: Respect, Pride, Wrath, Hunger | `economy.md` §4.2 |
| G6. Transform timing | Per fighter | `systems-sketch.md` §1 |
| G7. Asymmetric roster | Yes, with win rates still 45 to 55% | `balance-targets.md` §1 |
| G8. Mirror matches | Yes in 1v1; not on the same team | `modes.md` |
| G9. Unlocks | Everything unlocked from the start | `modes.md` |
| G11. 2v2 or free-for-all | 2v2: revive and bigger planets were answered for it | `modes.md`, `team-2v2` |
| G12. 2v2 revive | Yes, with a risky beat next to the fallen teammate | `modes.md` |
| Hit while transforming | Long transformations can be interrupted; the Tyrant's quick revisions are safe | `damage-model.md` §5 |
| Form duration | Permanent, except drain states | `systems-sketch.md` §1 |
| Teleport tell | A ripple in the air | `systems-sketch.md` §1 |
| Tyrant's appendage | Keep a tail, redesigned | `systems-sketch.md` §2 |
| Tyrant's forms | The numbered "revision" joke | `systems-sketch.md` §1 |
| Human Tyrant during the goon phase | Snipes support shots and taunts | `systems-sketch.md` §2 |
| Goons | Three: bruiser, marksman, speedster | `systems-sketch.md` §2 |
| Cyborg's companion | A backup drive he catches and docks | `systems-sketch.md` §5 |
| Planets | Earth-like and alien biomes; day, night and weather; bigger for 2v2 | `systems-sketch.md` §6 |
| Greybox pace | Too fast | `balance-targets.md` §10 |
| Earlier: tone, casualties, stances, modes, online, length, roster, planets, presentation | Questionnaire 1 | `docs/ep/vision.md` |

## Decisions Game Design made (Orb may overrule any of them)

- **Damage model** (`damage-model.md`):
  - four regions with wear stages;
  - "the director goes for the wound";
  - brink after the core breaks or any two regions break, and a KO only by finisher;
  - one damage profile per fighter: Rolls with it, Proud front, Refit, and Regrowth and the hatch;
  - region breaks as chapter launches.
- **Pacing targets** (`balance-targets.md` §10):
  - 8 to 12 exchanges a minute, each 2.5 to 4 s;
  - 1.5 to 4 s of breathing room;
  - 4 to 6 launches a minute, at least 30% of them long;
  - at most 10% of fight time underwater.
- **Balance bands, stance rules for P2, economy rules and modes** as recorded in `balance-targets.md`, `stance-matrix.md`, `economy.md` and `modes.md`.
- **Originality.** Where Orb has not picked yet, Legal's replacements are the working defaults (`docs/legal/fighter-concepts-review.md`).
