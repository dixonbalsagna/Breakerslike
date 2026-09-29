# Balance targets

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

The measurable bands the game must meet. Each is written so QA's harness (`qa/`, `prototype/tools/`) can check it with a pass or fail. QA owns the measurement and the release bar. Game Design owns the bands. The owner named in the last column of each table owns the fix.

**Sources.**
- "QA §n" is a section of `qa/baseline-p0.md` (8,000 seeded AI-against-AI matches of the prototype at commit `7233c96`).
- `index.html:L123` is a line of that prototype.
- Orb's answers are in `docs/ep/vision.md`.

**Two scales.**
- The prototype is the P2 testbed. It has two placeholder fighters and 55-second matches. It is measured against the "P2 testbed" bands.
- The real game has four fighters, transformations and 5-to-7-minute matches. It is measured against the "game" bands from P3 on.
- Where a band differs by scale, both are given.

## How to measure

- **Arms and seeds.** Use QA's arms (default, swap, mirrors, and each with the spawns flipped; QA §1) with fixed seed bases, so every number reproduces.
- **Pairings.** A 1v1 pairing is measured over both slot orders, at least 1,000 matches each. That cancels the slot effect (QA §2b).
- **Pass rule for a rate.** The point estimate is inside the band, and the 95% interval (Wilson for win rates, match-clustered for shares of events) lies inside the band widened by 2 points on each side.
- **Pass rule for a mean.** The point estimate is inside the band. A percentile band is read from the same batch.
- **Timeout cap.** The match cap moves from 300 s to 900 s for game-scale batches. Today's 300 s cap would time out every 7-minute match (QA §3; `qa/tests/soak.test.js`).

## Summary

| # | Target | Band | Prototype today | Status | Fix owner |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Win rate per 1v1 pairing | 45 to 55% | VORR 58.2%, KAI 41.8% (QA §2) | Fails | Game Design (rules), Encounter Systems (AI) |
| 2 | Match length | Game: median 6:00 to 8:00 to the KO | Mean 55.4 s (QA §3) | Not yet applicable | Game Design, Combat, QA |
| 3 | Escalation checkpoints | See section 3 | 47% of matches reach tier 3 | Fails the P2 testbed band | Game Design |
| 4 | Collateral | See section 4 | 38.7% of civilians per 55 s match (QA §4) | The mean passes the P2 testbed band; per-tier bleed is not yet measured | World (mechanisms), Game Design |
| 5 | Launch variety | No launch type above 40% | SLAM DOWN 46.4% (QA §5) | Fails | Encounter Systems |
| 6 | Location and signature variety | No biome above 40% of fight time; no variant above 40% of beams | Ocean 64.6% of fight time; HORIZON CLEAVE 69% (QA §6) | Fails | Encounter Systems, World |
| 7 | Stance balance | No forced stance above 55% | Not yet measured; DEFENSIVE at risk (`stance-matrix.md` §4) | Unknown | QA (probe), Game Design |
| 8 | Story beats | See section 8 | Ambush 0.061 per match (QA §8) | Fails | Encounter Systems, Game Design |
| 9 | Pacing (tempo) | 8 to 12 exchanges per minute; exchanges of 2.5 to 4 s; 1.5 to 4 s of breathing room | About 21 exchanges per minute, each about 1 s | Fails ("too fast", Orb) | Combat, Encounter Systems |

---

## 1. Win rate

- **1v1.** Every pairing, mirrors included, wins 45 to 55%. It is averaged over both slots, at equal AI skill.
- **Mirrors.** The slot effect and the spawn effect are each within ±3 points. QA measured the villain mirror's west-spawn effect at +4.1 points (QA §2b), which fails this. Versus spawns come from fair pairs (`modes.md`).
- **2v2.** Every team composition wins 45 to 55% against each other composition, over both sides.
- **Free-for-all (four fighters).** Each fighter's share of wins is 20 to 30%.

## 2. Match length

| Scale | Band |
| :--- | :--- |
| P2 testbed (prototype) | Mean 40 to 70 s to the KO; p90 at most 100 s; timeouts at most 1% at the 300 s cap. This keeps QA's provisional band for the prototype |
| Game (P3 on), 1v1 | Median 6:00 to 8:00 to the KO; p10 at least 5:00; p90 at most 10:00; timeouts at most 1% at 15:00 |
| Game, 2v2 and free-for-all | Median 6:00 to 9:00 |

**Why.** Orb set 5 minutes or more, felt as a season finale of about 7 minutes (`docs/ep/vision.md`). QA's 40 to 70 s band is superseded for the game. It stays only as a guard on the prototype testbed, so that P2 stance work is not distorted by a change of length. How the length is built is in `economy.md` §7: longer choreographed exchanges, region breaks as chapters (`damage-model.md`), set pieces and gated transformations, at the tempo in §10. HP sponges are not the answer.

## 3. Escalation checkpoints

| Checkpoint | P2 testbed band | Game band | Prototype today |
| :--- | :--- | :--- | :--- |
| A fighter reaches tier 3 before the KO | At least 70% of matches | Every fighter reaches a form of tier 3 or higher in at least 70% of matches | 47% of matches (Game Design check on QA's default and swap seeds, 2,000 matches) |
| A fighter reaches tier 4 before the KO | At least 25% of matches | A top form is reached in at least 60% of matches | 7% of matches (same check) |
| First transformation | none | Median 1:00 to 2:30; before 3:00 in at least 90% of matches | none |
| The last 60 s before the KO | none | At least one beam clash or finisher in at least 70% of matches | none |
| Time with no exchange | none | No gap over 10 s in at least 95% of matches | Not measured |

## 4. Collateral

Numbers a QA test can check. "Civilians" is the share of the starting population lost; "structures" is the share of starting structures lost. Relocated fights count only up to the moment of relocation (`systems-sketch.md` §4).

| Measure | P2 testbed band | Game band (1v1, all pairings) | Prototype today (QA §4, default arm) |
| :--- | :--- | :--- | :--- |
| Civilians lost at the KO, mean | 25 to 50% | 45 to 75% | 38.7% |
| Worst pairing's mean | at most 65% | at most 85% | 64.2% (villain mirror) |
| Matches losing 90% or more of civilians | at most 7% | at most 10% | 5% |
| Low-tier bleed: while both fighters are at tier 2 or below, civilians lost per minute | at most 40% of the population per minute (a guard against P2 work making it worse) | at most 4% of the population per minute | About 42% per minute over the whole match. Per-tier rates are not yet split out |
| Civilians left at 4:00 (so the Cyborg's track can finish) | none | At least 25% alive in at least 80% of matches | none |
| Structures lost at the KO, mean | 20 to 40% (10 to 19 of 47) | 40 to 75% | 30% (14.1 of 47) |

**Mechanisms.** World is proposing tier-scaled caps and a casualty ramp to meet the game bands. Game Design sets only the bands. The low-tier bleed band is the measurable form of the P3 exit criterion "no fight destroys the planet at low tiers". QA needs a per-tier split of casualties to check it. That is requested through the EP.

## 5. Launch variety

- **Cap.** In every QA arm, no launch type is above **40%** of all launches. The match-clustered 95% upper bound must be at most 42%.
- **Floor.** At least **4** launch types are each at or above **5%** in the default arm.
- **Today.** SLAM DOWN is 46.4% (95% CI 45.6 to 47.2), and only three types are above 5% (QA §5).
- **Owner.** Encounter Systems owns the fix. QA re-tests any proposal.

## 6. Location and signature variety

- **Fight time.** No biome holds more than **40%** of fight time in any 1v1 arm. Every biome holds at least half of its share of the planet or 3% of fight time, whichever is lower.
- **Signature variants.** No variant is above **40%** of beams. Every variant is at least **3%** of beams, pooled over the planet set used for testing.
- **Today.** The ocean holds 64.6% of fight time on 26% of the planet. HORIZON CLEAVE is 69% of beams; FIRESTORM and GLASS TRENCH are 1% each (QA §6).
- **Procedural planets.** These bands are measured over a fixed set of at least 20 seeded planets, not one.

## 7. Stance balance

Measured with the fixed-stance probe in `stance-matrix.md` §6. It uses two identical, role-neutral fighters and forces one fighter's stance at a uniform attack cadence.

- No forced stance wins more than **55%** against the standard stance mix.
- Every stance loses at below **45%** to at least one other forced stance in the round robin.
- **The escape gamble:**
  - The pursuit slip rate is **35 to 65%** (today 50%, QA §7).
  - The beam escape rate against ESCAPE is **20 to 50%** (today 28%, QA §7).
- **Parries:** 5 to 15 per 100 melee exchanges (today 9.1, QA §8).
- **Chains:** 15 to 35 per 100 melee exchanges (today 23.8, QA §8).
- **Not a dominance test:** time spent per stance by winners and losers (QA §9), because the AI picks its stance from HP (`index.html:L815`).

## 8. Story beats (per game-scale match, 1v1)

| Beat | Band | Prototype today (per 55 s match, QA §8) |
| :--- | :--- | :--- |
| Hides | At least 1.5 per match; at least one hide in at least 60% of matches | 0.63; 38% of matches |
| Ambush attacks | At least 0.5 per match | 0.061 |
| Comebacks: the winner was on the brink at some point, or rallied (`damage-model.md` §5) | 15 to 35% of matches | Not measurable yet. The prototype has no brink |
| Region breaks before the finisher (1v1) | 4 to 6 per match | none |
| Finishers preceded by a brink call-out | 100% | none |
| Lead changes: which fighter has more region stages lost flips | Median at least 2 | Not measured |
| Beam clashes and struggles | 2 to 8 per match | Beams 3.65 per match, 40% of them clashes (QA §6) |
| Chains | 15 to 35 per 100 melee exchanges | 23.8 |

## 9. The prototype's balance gap (the KAI gap)

**The finding.** VORR wins 58.2% and KAI 41.8% (95% CI 39.7 to 44.0). The character effect is −8.5 points for KAI, with slot and spawn not significant (QA §2, §2b).

**The diagnosis**, from the rules and QA's data. The EP dropped new ablation batches, because both fighters are placeholders for Orb's four.
1. **Menace snowballs and never decays.** Every casualty the villain causes adds four permanent buffs (`index.html:L272`, `L322`, `L625`, `L759`):
   - up to +25% damage;
   - up to +3 ki/s of regen;
   - up to +8 on the clash roll;
   - power +0.09 per casualty, which speeds its tiers and every tier term on the outcome rolls.
2. **Anguish is small and short-lived.** Its only effect is a regen cut of up to 2.5 ki/s, and it decays at 0.6/s (`L759-760`). The hero's one advantage, the comeback bonus, only works when the hero is already losing (`L322`).
3. **VORR moves at ×0.95** (`L186`). This probably slows VORR slightly, which would favour the hero, and is not a cause of the gap.
4. **Some of the gap is AI and director behaviour, not rules.** The hero AI dashes away from populated ground and flees to cover (`L823-824`, `L836-840`), and the launch planner's personality term steers the villain toward buildings (`L371`). QA's villain mirror loses 64% of civilians against 32% in the hero mirror (QA §4). Encounter Systems owns those levers.

**Options for closing it.** For the prototype, if P2 needs balanced placeholders; the principles carry to the roster:
- **Menace decays when not fed** (for example 0.3 to 0.6 per second), so the villain must keep the fight near people.
- **A lower menace damage cap:** +10 to +15% instead of +25%.
- **Composure for the hero:** a damage bonus while the hero's anguish is low, which collateral takes away. The hero is rewarded for protecting, and never for letting people die.
- **Not recommended: "fury"** (anguish adds damage). A single check before the lean-team directive, on QA's default and swap seeds (2,000 matches), put KAI at 50.5% [48.4, 52.7] with fury at +50% per 100 anguish. That closes the gap, but it rewards the hero for letting collateral happen. It fails pillar 5.

**What carries to the roster** (`economy.md` §4):
- every ego meter decays or is spent;
- every ego meter is visible;
- no fighter gets permanent, stacking buffs from one source;
- each fighter's meter has about the same expected value across a match, checked by band 1.

## 10. Pacing: why the greybox reads too fast, and the target tempo

Orb played the Godot greybox and found it too fast (`docs/ep/vision.md`, questionnaire 3). The greybox runs the prototype's sim, bit-identical (commit `26479d5`), so the cause is in the sim's numbers, not in the renderer.

**Why it reads too fast** (default arm, QA §3, §5, §8; code at `7233c96`):
- **Exchanges are short and back to back.**
  - About 21 exchanges start per minute: 16.0 melee and 3.65 beams per 55.4 s match.
  - A melee exchange lasts the rush (0.18 to 0.65 s, `L420`) plus 0.3 to 1.0 s of beats (`L438-506`).
  - Strikes land 0.16 to 0.20 s apart (`L478`, `L498`), and the default hit-stop is 0.05 s (`L334`).
  - The director waits only 0.22 s before the next exchange (`L565`).
  - An AGGRESSIVE AI attacks every 0.35 to 1.0 s (`L844`).
  - There is no breathing room: no taunts, no repositioning, no read.
- **The planet feels small.** Any gap closes in at most 0.65 s, so half the planet (4,800 units) is crossed at about 7,400 units per second (`L420`). A dash loops the whole planet in about 9 s (`L770-772`).
- **Launches are frequent and mostly vertical.**
  - About 15.6 launches a minute.
  - 80% are SLAM DOWN or UPPERCUT (QA §5), so fighters bounce in place.
  - Only 4.7% are SMASH ACROSS, the one launch that crosses the map.
- **Fights sink into the ocean.** The ocean holds 64.6% of fight time on 26% of the planet (QA §6). Four causes stack:
  - The hero AI flees population toward the western ocean (`L823-824`).
  - ESCAPE's cover-seeking dives below −110 in the ocean (`L837-839`).
  - SLAM DOWN scores +12 over water (`L362`).
  - A launched fighter who hits water stops dead within about a second (`L726`).

**Target tempo** (game scale; QA measures it from the event stream):

| Measure | Target | Greybox today |
| :--- | :--- | :--- |
| Exchanges started per minute | 8 to 12 | About 21 |
| Exchange length, request to release, median | 2.5 to 4.0 s. Set pieces (beam struggles, break launches, transformations, finishers) 3 to 8 s | About 0.5 to 1.9 s |
| Spacing of strikes inside a melee exchange | 0.25 to 0.40 s | 0.16 to 0.20 s |
| Readable wind-up before a parryable strike | 0.20 to 0.30 s (Controls owns the width) | 0.10 s (0.33 s on HEAVY CLASH — WON) |
| Hit-stop floor by impact class | Light at least 0.07 s; heavy at least 0.12 s; region break or finisher at least 0.30 s | 0.05 s default; 0.08 to 0.16 s on big hits |
| Breathing room, release to the next request, median | 1.5 to 4.0 s; no gap over 10 s | Under about 1.8 s; director cooldown 0.22 s |
| Launches per minute | 4 to 6 | About 15.6 |
| Long launches: at least 1,500 units of horizontal travel before landing | At least 30% of launches; every region-break launch is long | About 5% (SMASH ACROSS) |
| Launches that land in a different biome from their start | At least 25% | Not measured |
| Gap close over 2,500 units | A visible pursuit flight of 0.8 to 2.0 s. Blink-strikes stay a Protagonist trait, with the ripple tell | 0.65 s at most |
| Fight time underwater | At most 10% (the ocean-share cap in §6 also applies) | Not measured; 64.6% of time over the ocean |

**What Combat should change:**
- Exchanges of 6 to 10 beats at the spacing above, with readable wind-ups. This is the "choreographed, seamless" look, and it halves the damage rate by itself.
- A pursuit-flight atom for long gap closes.
- A break-launch-and-chase set piece: the attacker follows the launched fighter across the map, with a camera follow.
- Finisher templates per fighter and form tier (`damage-model.md` §5).

**What Encounter Systems should change:**
- **Director cooldown:** 0.8 to 1.5 s, scaled by the size of the last exchange (today 0.22 s).
- **AI cadence:**
  - AGGRESSIVE: about 1.2 to 2.5 s, with the other stances scaled to match (today 0.35 to 1.0 s).
  - Fill the downtime with taunts, barks, repositioning and charging.
- **Launch planner:**
  - add a distance term and a new-biome term;
  - make every break launch long;
  - cut SLAM DOWN's ocean and city bonuses (`L362`), and cap vertical launches.
- **Location:**
  - the hero's lure goes to empty land and rotates among desert, plains and mountains, not the nearest ocean;
  - ESCAPE's cover-seeking weighs forest and ridge as well as water;
  - underwater is a hiding state, not a place to fight.

**For World and Simulation, through the EP.** A launched fighter who hits water should skim and splash rather than stop dead (`L726`). Orb also asked for simple fluid behaviour. **For Camera:** a planet-scale read and the launch follow (Orb's greybox notes).
