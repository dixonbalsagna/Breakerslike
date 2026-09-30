# Design docs

Owner: Game Design. These pages define what the game is and why it is fun, and every other director builds on them. Start with Orb's vision (`docs/ep/vision.md`), then the pillars.

| Page | What it answers |
| :--- | :--- |
| [pillars.md](pillars.md) | The seven pillars: what each means in play, how we test it, what breaks it, and where the prototype stands |
| [stance-matrix.md](stance-matrix.md) | What each stance is for, what beats it and what it costs. Intended outcomes per pairing, P2 gaps, dominance risks, and the P2 stance rules |
| [economy.md](economy.md) | HP, ki, tiers and transformations, ego meters, hiding and ambush, collateral scaling, and how a 5-to-7-minute match escalates |
| [balance-targets.md](balance-targets.md) | The bands QA checks: win rate, length, escalation, collateral, variety, stance balance, story beats. Also the prototype's balance-gap diagnosis |
| [living-destruction-numbers.md](living-destruction-numbers.md) | Numbers for fire, smoke and dust cover, landslides, quakes, rifts and lava: tier ladders, rates, hazard wear, frequencies, and the readability and collateral rules |
| [moveset-rules.md](moveset-rules.md) | Specials, signatures, world-changing abilities, hidden weapons, one transformation mechanic per fighter, and style shifts (questionnaire 6) |
| [tutorial.md](tutorial.md) | The How-to-play card and the guided first match: beats that teach reads, never timing |
| [modes.md](modes.md) | Modes with stable ids, the 1.0 scope, and the rules for each mode |
| [damage-model.md](damage-model.md) | No health bars: body-region wear, brink and finisher, how each fighter takes damage, and how the player reads it |
| [spec-wounds.md](spec-wounds.md) | **The binding Wounds spec**: rules, Rally, the per-fighter damage profile and readout, sim data, and acceptance tests. Input for Combat and Encounter Systems |
| [pitches.md](pitches.md) | Pitches for Orb: the wear readout, a Rally per fighter, downtime ideas, and fragments under Legal's conditions |
| [systems-sketch.md](systems-sketch.md) | Transformations, minions, fusion (deferred; Tandem), keystone relocation, civilian consumption, procedural planets |
| [future-stealth-fighter.md](future-stealth-fighter.md) | The hiding kit as it was (recovery, ambush, found and searching, the hunter's view), kept for a future stealth fighter |
| [open-questions.md](open-questions.md) | The questions for Orb, with options and recommendations, and the decisions Game Design made |
| [prototype-bugs.md](prototype-bugs.md) | Prototype defects that matter to design, with the intent each one breaks. They are not fixed until the port proves parity |

**Conventions**
- **Code.** `index.html:L123` is a line of `prototype/index.html` at commit `7233c96`.
- **QA.** "QA §n" is a section of `qa/baseline-p0.md`.
- **Names.**
  - Stances are AGGRESSIVE, DEFENSIVE, EVASIVE and ESCAPE. CHARGING is a state, not a stance.
  - Attack kinds are light, heavy and signature.
  - "Ki" is the internal name for the energy resource (Legal RL-015).
- **Placeholders.** The prototype's KAI and VORR stand in for Orb's four fighters. KAI will not ship (Legal RL-002).
- **Pending picks.** Signature replacements follow Legal's first option, marked "pending Orb's pick" (`docs/legal/fighter-concepts-review.md`).
