# Fight economy

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

The resources a fight runs on: HP, ki, power and tiers, the fighters' ego meters (the prototype's menace and anguish), hiding, recovery and ambush, and how collateral scales with tier. For each resource this page gives the prototype's constants, the decisions they create for a player, the levers that tune them and the QA metrics that show a lever working. It closes with how a match should escalate across the 5-to-7-minute length Orb set.

**Sources.**
- `index.html:L123` is a line of `prototype/index.html` at commit `7233c96`.
- "QA §n" is a section of `qa/baseline-p0.md`.
- Orb's answers are in `docs/ep/vision.md`.
- The per-fighter systems are sketched in `systems-sketch.md`.
- The prototype's two fighters are placeholders for Orb's four. Their numbers are the testbed, not the final design.

**Principles.**
- Every resource must create a decision a player can see.
- Every meter must be visible (charter anti-goal: nothing that only works if you read the wiki).
- Every fighter's ego meter ties them to the world in a different way (pillar 5).

---

## 1. HP

| Constant | Value | Where |
| :--- | :--- | :--- |
| Max HP | 1,600 for both fighters | `L185-186` |
| Regen | None, except while hidden: +40 HP/s, capped at max | `L762` |
| KO | HP at 0 ends the match and launches the loser | `L318`, `L339-347` |
| Comeback | Damage dealt ×(1 + 0.5·(1 − hp/max)²): up to ×1.5 at 0 HP. It goes to every fighter whose role is not "villain" | `L322` |

**Decisions it creates.** Trade HP for position; go to ground and recover, or keep up pressure.

**Levers and metrics.** Max HP sets the match length (QA §3). Hidden healing sets the value of hiding (hides per match and hidden seconds, QA §8).

**For the real game: no HP bar.** Orb ruled out health meters (questionnaire 3).
- **The replacement** is `damage-model.md`: wear on body regions, region breaks as chapters, and a brink state. A match ends only through a fighter-specific finisher.
- **HP segments are superseded.** They were proposed earlier on this page; region breaks now do their job. A break launches the broken fighter far, and each break is a chapter.
- **Hiding** mends battered wear, but not a broken region.
- **The comeback bonus** survives as the desperation of a fighter on the brink, shown through the aura. Narrative's "Resolve" is that cue.

## 2. Ki

| Constant | Value | Where |
| :--- | :--- | :--- |
| Start, cap | 60, 100 | `L201`, `L761` |
| Regen | 5/s while free, locked or down (not while launched) | `L758`, `L761` |
| Hidden bonus | +25/s | `L758` |
| Charging | +30/s (and power +9/s), in the open | `L783` |
| From hits | The attacker gains 4% of the damage it deals | `L330` |
| From a parry | +8 | `L529` |
| Heavy | Costs 4. With less than 4 ki the heavy becomes a light | `L396`, `L405` |
| Signature | Costs 45 (needs 45) | `L395`, `L406` |
| Chain link | Costs 6 (needs 6) | `L550`, `L574` |
| Attacking a hidden target | −2 and a 0.5 s cooldown ("lock lost") | `L397-401` |
| Target slips away | The attacker loses 3 | `L447` |
| Beam clash | The defender pays 40 (needs 40 in AGGRESSIVE) | `L586`, `L603` |
| DEFENSIVE guard | The defender loses 8% of the damage it takes | `L329` |
| GUARD BREAK | The defender loses 25 | `L485` |

**Decisions it creates:**
- Fire a signature now for 45, or hold 40 in AGGRESSIVE to answer the opponent's beam with a clash.
- Extend a chain at 6 per link (each link adds 12% damage, `L323`), or reset.
- Charge in the open (fast ki and power, but a CHARGE INTERRUPT risk), or regen slowly.
- Keep enough ki in DEFENSIVE to afford the guard drain and, under the P2 rules, to BRACE a heavy (`stance-matrix.md`, R3).

**Levers:**
- The signature cost and regen set beams per match (3.65, QA §6).
- The chain cost sets chains per match (3.82, QA §8).
- The clash threshold sets the clash share of beams (40.4%, QA §6).
- The P2 missed-parry cost (5 ki, `stance-matrix.md` R5) sets parries per 100 melee exchanges (9.1, QA §8).

## 3. Power, tiers and transformations

| Constant | Value | Where |
| :--- | :--- | :--- |
| Power | 0 to 100. It never falls | `L755` and others |
| Tier | 1 + one step at each of 25, 50 and 75 power | `L756` |
| Passive gain | +0.45/s (25 power takes 56 s) | `L755` |
| Charging | +9/s | `L783` |
| From hits | The defender gains 1.0% of the damage taken; the attacker 0.6% of the damage dealt | `L331` |
| Villain casualties | +0.09 per casualty | `L272` |
| Per-tier effects | Damage +9% (`L321`); speed +10% (`L770`); launch force +16% (`L378`); beam length +400 (`L601`); beam width +9 (`L643`); blast radius +30 (`L612`); camera zooms out 6% (`L874`); +0.07 to +0.10 on most outcome rolls (`L441`, `L458`, `L495`, `L502`, `L588`, `L625`) | as listed |
| Tier-up near the ground | Craters the ground and damages the area; in the air it does neither | `L697-701` |

**What tiers do today.** A check of tier reach on QA's seeds (default and swap arms, seeds 100001 to 101000 and 200001 to 201000, 2,000 matches) found:
- Every match reaches tier 2.
- 47% of matches reach tier 3, and 7% reach tier 4.
- Matches that top out at tier 2 average 46 s; at tier 3, 60 s; at tier 4, 103 s.

In a 55-second match, escalation usually stops halfway. QA §8 gives a mean highest tier of 2.3 to 2.5 per fighter.

**Decisions it creates:**
- Charge to rise faster, at the risk of an interrupt.
- Power up in the air to avoid scarring the ground, or on the ground where the crater may feed your ego meter.
- Take hits: a fighter on the receiving end gains more power than the one dealing it, which is a built-in escalation for the underdog.

**For the real game: transformations drive the tier.**
- Orb's fighters escalate through per-fighter transformation tracks, each with its own trigger (`systems-sketch.md`, "Transformations").
- The shared scale stays tiers 1 to 4. Each form maps to a tier, and the tier sets collateral scaling and the tier terms on outcome rolls.
- Forms add moves and change numbers. They never change the stance grammar (`stance-matrix.md`).
- Power becomes each fighter's track progress rather than one shared clock.
- The passive gain survives as a floor. No fighter can go 3 minutes without progress.

**Levers:**
- The trigger thresholds on each track, and the passive floor.
- The number of forms per tier.

**Metrics.** The escalation checkpoints in `balance-targets.md`: the minute of the first transformation, and the share of matches in which a fighter reaches its top form.

## 4. Ego meters: how each fighter relates to the world

### 4.1 The prototype's placeholders

| | Menace (villain) | Anguish (hero) |
| :--- | :--- | :--- |
| Gain | +0.9 per casualty the villain causes (`L272`) | +0.5 per casualty the villain causes, +0.9 per casualty the hero causes (`L274`) |
| Decay | **None.** Menace only ever rises | −0.6/s (`L760`) |
| Effect | Damage up to +25% (`L322`); ki regen up to +3/s (`L759`); up to +8 on the beam-clash roll (`L625`); power +0.09 per casualty (`L272`) | Ki regen down by up to 2.5/s, never below 1/s (`L759`) |
| AI and director | The launch planner seeks populated ground (care −0.8, `L371`) | The planner avoids it (care +1.0, `L371`); the AI lures fights away from population (`L823-824`) |

**The lesson for the roster.** Menace gives four permanent buffs that snowball, and it never decays. Anguish gives one penalty that fades within seconds. That imbalance is the main rules-side reason the villain wins 58.2% (QA §2; `balance-targets.md`, "The prototype's balance gap").

Every ego meter in the roster follows three rules:
1. It has a cost or a decay.
2. It is visible on the HUD.
3. Across a match, its expected effect is close to that of every other fighter's meter.

### 4.2 The four fighters (proposals; systems in `systems-sketch.md`)

| Fighter | Ego meter (working name) | Fills when | Drains or costs | What it does | Relation to collateral |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Protagonist | **Respect** (Legal's suggested framing) | The opponent commits fully: transforms, fires a finisher, clashes at full ki, or keeps fighting below 25% HP | It is spent to unlock the next step on a transformation track | Advances his parallel tracks | He causes a lot of collateral through his fixation on the fight. His answer is to move the fight somewhere empty (keystone relocation) |
| Anti-hero | **Pride** | He dominates: wins clashes, lands long barrages, finishes by hand | It drains when he is humbled (parried, guard-broken, or a region broken). Accepting Tandem help spends all of it | Damage and form triggers; forms raise it further | Indifferent. He wrecks things to make a point |
| Tyrant | **Wrath** | His minions fall and he takes damage | Each stage change spends a share of it | Triggers his many-stage transformation chain | Indifferent, and cruel for show |
| Cyborg | **Hunger** | He consumes civilians and collects sandwiches | Consuming is a vulnerable beat, like charging | Each civilian adds a small multiplicative bonus; thresholds trigger molts | He feeds on the population directly. This is menace made literal |

Orb decides the exact triggers (`open-questions.md`). The rules above hold whatever the triggers are.

### 4.3 Rulings on Narrative's proposals (`docs/narrative/fighter-sketches.md`, sections 4b and 5)

- **Interpose: accepted, as a DEFENSIVE outcome, not a button.**
  - When a protector fighter holds DEFENSIVE and a signature or launch would cross populated ground behind it, the director composes INTERPOSE: the fighter takes the hit at guard strength, and the collateral behind it is cancelled.
  - The player's decision is holding DEFENSIVE near people, so the director never overrides intent.
  - Scheduled for P3, with collateral. It is also DEFENSIVE's second outcome against a signature for protectors (`stance-matrix.md`, R3).
- **Resolve: accepted, as presentation.** It is the visible cue for the comeback bonus (voice, aura, animation). No new rule.
- **Savour: accepted, folded into the Cyborg.** Consuming is the Cyborg's feeding beat. It is vulnerable like a charge, and it turns collateral into power. For other fighters, a meter with a cost does the same job.
- **Foretell: accepted, as a bark only.** It plays during the signature's existing 0.8 s charge beat (`L598`), with no added delay.
- **hesitation_near_pop: rejected.** It makes a fighter worse exactly where players want to shine (pillar tie-break 1). It would also widen the hero's gap. It is allowed as idle animation only, never as timing.
- **Narrative's three questions:**
  - *Is anguish only a cost?* Yes. A meter that pressures a fighter stays a pressure. The reward for protecting is a positive state that collateral takes away (a composure bonus), never a bonus for letting people die.
  - *Should menace cost something?* Yes. Every ego meter decays or is spent (rule 1 above).
  - *Is Interpose automatic?* No. The player decides by holding DEFENSIVE near people.

## 5. Hiding, recovery and ambush

| Constant | Value | Where |
| :--- | :--- | :--- |
| To start hiding | ESCAPE stance, free, in cover, more than 170 units from the opponent, not charging or dashing, speed under 260 | `L683` |
| Cover | Submerged: ocean, 60 or more below sea level, over deep ground. Canopy: forest, low, within 120 of a tree. Ridge: mountains, within 40 of the ground | `L668-674` |
| Time to hide | 0.9 s | `L686` |
| While hidden | +40 HP/s and +25 ki/s; attackers lose their lock-on (−2 ki and a 0.5 s cooldown) | `L758`, `L762`, `L397-401` |
| Found | The opponent comes within 240 when you break cover | `L687` |
| Ambush | After more than 1.8 s hidden, the next attack within 2.5 s of leaving cover, or an attack straight from cover (1 s window), deals ×1.5 damage (`L324`). It also always reads an evader, always catches a fleeing target, and cannot be clashed or dodged by a signature | `L402-403`, `L687`, `L441`, `L458`, `L586-588` |

**How it plays.** Hiding is a lock-on denial, not true concealment. On a shared 2.5D screen (Orb's presentation choice), both players see the hidden fighter drawn faded. QA §8 measures it:
- 0.63 hides per match, and 38% of matches have at least one;
- 2 to 3 hidden seconds per fighter;
- 0.061 ambush attacks per match, about one hide in ten.

**Decisions it creates.**
- For the hider: break off and heal, but ESCAPE takes ×1.25 damage on the way to cover. Then choose when to spring the ambush.
- For the hunter: search, or wait at a distance. Attacking blind wastes ki.

**For the real game.**
- A 7-minute match should see several hides, and ambushes should land. The bands are in `balance-targets.md`, "Story beats".
- The rule-side levers:
  - the 1.8 s arming time;
  - the 2.5 s window;
  - the ×1.5 multiplier;
  - hidden recovery, which mends battered wear but not a broken region (`damage-model.md`).
- Most of the rarity of ambushes is AI behaviour: the AI never attacks from ESCAPE (`L841`). That is Encounter Systems' to change.
- The P2 hit-and-run perk for ESCAPE attackers gives hiding a direct payoff (`stance-matrix.md`, R2).

## 6. Collateral and how it scales with tier

| Source | Area damage | Crater | Where |
| :--- | :--- | :--- | :--- |
| Beam impact (HIT, GUARD, clash win) | 130 + 110·tier over radius 1.8·r, where r = 60 + 30·tier (the clash winner uses 70 + 32·tier) | radius 0.9·r, depth 18 + 8·tier | `L304-310`, `L612`, `L637` |
| Beam path, sampled every 36 units | 110 + 75·tier, radius 26 + 8·tier | radius 20 + 7·tier, depth 5 + 2.2·tier (RIDGE BORE 9 + 2.2·tier) | `L646-656` |
| Clash shockwave | 110 + 80·tier over 160 + 40·tier | radius 60 + 16·tier, near the ground | `L515-517` |
| Launch impact above speed 350 | speed·(0.22 + 0.12·tier) over 1.7·r | r = 28 + 0.05·speed + 12·tier, depth ≤ 90 | `L706-714` |
| Launched body through a building | speed·(0.55 + 0.25·tier) to that building | none | `L733` |
| Tier-up within 140 of the ground | 90 + 100·tier over 130 + 60·tier | radius 60 + 28·tier, depth 12 + 7·tier | `L697-701` |
| Casualties | A share of a building's population proportional to damage (×1.3), and everyone left when it falls | none | `L279-285` |

From tier 1 to tier 4, per-event damage roughly doubles:
- beam impact: 240 to 570;
- beam path: 185 to 410;
- tier-up blast: 290 at tier 2 to 490 at tier 4.

The shipped matchup loses 38.7% of 425 civilians and 14.1 of 47 structures per 55-second match (QA §4). One match in twenty loses 90% or more.

**Decisions it creates.**
- Where to fight, which ties to each fighter's ego meter.
- Where to power up.
- Which launch to take: the planner scores populated ground by personality (`L371`).

**For the real game.**
- The match is 7 times longer, so today's rates would empty any planet. World is proposing tier-scaled collateral caps and a casualty ramp as the mechanisms.
- The targets they must meet are in `balance-targets.md`, "Collateral". Low tiers bleed slowly; the climax is where the world breaks.
- The Cyborg needs living civilians to progress, so the targets include a floor as well as a ceiling.
- Relocation takes the fight off the populated planet, and ends collateral there.

## 7. Escalation across a 5-to-7-minute match

Orb wants a match to feel like the finale of a season-long rivalry: 5 minutes or more, ideally about 7. The prototype's 55-second match is the P2 testbed. It is not the target. Length comes from structure, not from HP sponges.

| Act | Time (7-min target) | What happens | Collateral |
| :--- | :--- | :--- | :--- |
| 1. The meeting | 0:00 to 1:30 | Base forms, tier 1. Openers, barks, feeling out. The Tyrant's minions fight while he watches. The Protagonist starts gathering keystones | Light and local |
| 2. The escalation | 1:30 to 4:00 | First transformations, tier 2. The first region breaks and throws the fight across the planet. The Cyborg feeds and molts. Beam clashes begin | Rising; settlements hit |
| 3. The turn | 4:00 to 6:00 | Top forms, tier 3. Tandem help offered to the Anti-hero. Relocation, if the Protagonist holds every keystone. Comebacks from hiding | Heavy, the planet visibly scarred |
| 4. The finale | 6:00 on | Final forms, tier 4. Finishers and the biggest clashes. The KO | The world breaks, or the fight has left it |

**How the length is built.** Starting values for the P3 sim; QA tunes them against `balance-targets.md`:
- **Longer, choreographed exchanges.** Two to three times more beats per exchange (Combat). That fits Orb's "choreographed, seamless" and halves the damage per second on its own.
- **Region breaks.** Four to six per 1v1 before the brink and the finisher (`damage-model.md`), at the tempo in `balance-targets.md` §10.
- **Set pieces.** Transformations, beam struggles, relocation, minions and the backup-drive chase carry the story with little HP change. Target about 25 to 35% of match time.
- **Tier gating by track.** Tier 3 and 4 forms need their track triggers, not only time.

**What to avoid:**
- A stall. Every stretch of more than 10 s with no exchange is dead air (`balance-targets.md`).
- A fighter who cannot progress. Every track has a time floor.
- Transformations that heal to full. They would make the finale unending.
