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
| 8 | Story beats | See section 8 | Hide and ambush bands retired (hiding removed) | Not yet measured | Encounter Systems, Game Design |
| 9 | Pacing (tempo) | Orb's dynamic feel: melee idle at most 15%; at least 80 strikes a minute; release to the next request at most 1.0 s (§10, adopted from Combat) | Melee idle 42.5%; release-to-request gap 2.7 s (`docs/combat/dynamic-feel.md`) | Fails (Orb: "slower than the prototype") | Combat, Encounter Systems |

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
| Civilians lost at the KO, mean | 25 to 50% | **25 to 50%** (re-set after evacuation; it was 45 to 75%, §4b) | 38.7% |
| Worst pairing's mean | at most 65% | at most 70% (re-set, §4b) | 64.2% (villain mirror) |
| Matches losing 90% or more of civilians | at most 7% | at most 5% (re-set, §4b) | 5% |
| Low-tier bleed: while both fighters are at tier 2 or below, civilians lost per minute | at most 40% of the population per minute (a guard against P2 work making it worse) | at most 4% of the population per minute | About 42% per minute over the whole match. Per-tier rates are not yet split out |
| Civilians left at 4:00 (so the Cyborg's track can finish) | none | At least 25% alive in at least 80% of matches | none |
| Structures lost at the KO, mean: a **share of row-1 (front-row) structures**. Row 1 is today's 47 buildings, unchanged by buildings in depth (`docs/world/buildings-in-depth.md`) | 20 to 40% of row 1 | 40 to 75% of row 1 | 30% (14.1 of 47) |
| Structures lost at the KO, all rows (about 110): a watch metric, not a gate | 10 to 35% | 25 to 60% | Not yet measured |

**Mechanisms.** World is proposing tier-scaled caps and a casualty ramp to meet the game bands. Game Design sets only the bands. The low-tier bleed band is the measurable form of the P3 exit criterion "no fight destroys the planet at low tiers". QA needs a per-tier split of casualties to check it. That is requested through the EP.

### 4b. The collateral cap and the casualty ramp (numbers for World's wave 1)

**Why now.** After the scale window (`docs/world/scale.md` §6):
- villain-mirror collateral is 61.0%, and 10.5% of matches lose 90% or more, which fails the testbed's 7%;
- the default arm's low-tier bleed is 19.9% of the population per minute, against a game band of 4%.

World builds the mechanism; these are its numbers. The cap and the ramp apply to **every** casualty source: blows, beams, launches, slides, brunts, chains, fire, landslides, quakes and lava.

**1. The ramp: a rolling casualty budget by tier.** The limit is on casualties per rolling 60 s, set by the higher fighter's tier:

| Tier | Budget per 60 s (share of the starting population) |
| :--- | :--- |
| 1 | 2% |
| 2 | 4% (this is the game's low-tier bleed band) |
| 3 | 8% |
| 4 | 15% |

- *Over budget.* Casualties that would go over the budget don't happen: the people got away. It shows diegetically as evacuation, with crowds fleeing the district (World and Narrative). Structures still take their damage.
- *Set pieces can borrow.* At tier 3 and above, a single set-piece event (a chain, a slide, a landslide, a quake) may borrow up to its own per-event budget (§5b, §5c, `living-destruction-numbers.md`). The window then refills before anything else can overdraw it. This keeps the spectacle while the average rate holds.
- *No borrowing at tier 1 or 2,* so the low-tier bleed is firm.

**2. The cap: a ceiling on cumulative losses by tier.** The share of the starting population lost can never exceed:

| Highest tier reached so far | Ceiling |
| :--- | :--- |
| 1 | 10% |
| 2 | 30% |
| 3 | 60% |
| 4 | 90% |

At the ceiling, the rest are sheltered and survive. This is the P3 exit criterion "no fight destroys the planet at low tiers" as a hard rule. Losing 90% or more is only possible at tier 4, and the band (at most 10% of game matches, §4 table) checks how often a match gets there.

**Expected result.** Over a 7-minute arc (acts at tiers 1 to 2, then 2, 3 and 4), the budgets add up to about 45 to 50% lost at the KO, plus set-piece borrowing. That is the lower half of the game band (45 to 75%). The Cyborg floor (at least 25% alive at 4:00) holds, because by 4:00 the ceiling is 30% at tier 2 or 60% at tier 3.

**Testbed bands.** Short testbed matches (about 108 s today) will fall below the testbed mean band (25 to 50%) once the ramp lands. At that point the testbed's mean-at-KO band retires, and the per-minute ramp and ceiling tests replace it. The share of matches losing 90% or more, and the worst-pairing band, stay.

**The Cyborg and evacuation** (World's `docs/world/collateral-caps.md`: evacuees never return).
- *Press is exempt from the rolling budget* and never triggers district evacuation. It is his own mechanic, and its rate is already limited by a slow, interruptible beat.
- *Press still counts* toward the cumulative ceiling and every §4 band, as casualties.
- *Only people still present can be Pressed:* those in buildings and streets. Evacuees in flight are safe.
- *The floor is redefined:* at least 25% of the starting population still **present** (alive and not evacuated) at 4:00, in at least 80% of matches with the Cyborg.
- *His thresholds are population shares that fit under the ceilings* (spec-wounds §3).

**Result and rulings after World's collateral window** (commit `3612ebc`, `docs/world/collateral-caps.md` §10).
- *The result:* civilians lost fell from 56% to 17% (default arm 13%, villain mirror 14%). No match lost 90% or more, and the low-tier bleed is 2.1% a minute.
- *Why it's low:* the early fight at the city's edge runs over budget, so about 105 would-be deaths a match evacuate. After that the fight is mostly elsewhere, and budget use is 18%.
- *The balance knock-on:* KAI rose from 47% to 67%, because menace feeds less.
- The rulings below apply now. Tuning waits until after Encounter's dynamic slice, which adds strikes and collateral.

1. **Budgets stay.** Tiers 1 and 2 keep 2% and 4% a minute: the low-tier bleed is the promise that "no fight destroys the planet at low tiers". Tiers 3 and 4 are not binding (18% use), so raising them would change nothing.
2. **Relocation goes on** (`RELOCATE = true`). Evacuees shelter in the nearest standing building 3,000 to 12,000 units away, so the population is conserved. The next fight there still has people to endanger (and the Cyborg to feed on), and fleeing reads as rescue, not vanishing.
3. **The opening moves off the city.** The spawn pairs in `modes.md` start on open ground about one settlement's distance from the nearest town, so tier-1 and tier-2 fights don't burn the population as evacuation before the stakes rise (World and Encounter).
4. **The civilian band is re-set for the game.** Mean civilians lost at the KO: **25 to 50%** (it was 45 to 75%, set before evacuation existed). Worst pairing at most 70%; 90% or more in at most 5% of matches. The structure band is unchanged, so large-scale destruction still reads through buildings and terrain.
5. **Menace feeds on fear as well as deaths.** The villain gains menace from evacuees at **half** the per-casualty rate (+0.45 per evacuee, normalised). The villain feeds on devastation and terror, so a fight that clears a district still feeds him. Anguish gains nothing from evacuees, because people getting out is the hero's relief.
6. **Composure goes off** (+10% becomes 0). It was added to offset the old uncapped menace, and it now overshoots.
7. **Target after the dynamic slice:** KAI inside 45 to 55%. If he is still high, raise menace's evacuee share (up to the full rate) before touching the budgets.

**After World's fixes and the dynamic slice** (commit `da5fb09`): civilians lost average about 17% (hero mirror 13%, villain mirror 16%), and no match reaches 90%.
- *Ruling:* the tier-1 and tier-2 budgets **stay**, because the low-tier promise is not a tuning lever.
- *Wait for QA's k retune first.* Longer matches spend more time at tiers 3 and 4, where the budgets have room.
- *If the mean is still under 25% after the retune,* re-base the civilian band to **15 to 40%**. The low number comes from the mechanisms working as intended (evacuation, relocation, fights opening on open ground), and destruction still reads through structures and terrain.
- *Before any budget change,* first ask Encounter to strengthen the villain's pull toward settlements at tiers 3 and 4, within the personality-weighted targeting Orb set.

**3. Per-casualty weights are normalised by population.**
- *Why.* Procedural planets have different populations (379 on seed 1 now, 425 before), so meters must read the *share* lost, not the headcount.
- *The rule.* Each per-casualty gain is multiplied by `425 / pop0`:
  - menace +0.9 per casualty at 425 people, which is +3.83 per 1% of the population;
  - anguish +0.5 per casualty, or +0.9 if the hero caused it (+2.13 or +3.83 per 1%);
  - the roster's collateral-fed meters, including the Cyborg's per-civilian Hunger bonus and his molt thresholds.
- *Result.* This reverses the 11% shift from the rescale, and keeps every planet equivalent.


## 5. Launch variety

- **Cap.** In every QA arm, no launch type is above **40%** of all launches. The match-clustered 95% upper bound must be at most 42%.
- **Floor.** At least **4** launch types are each at or above **5%** in the default arm.
- **Today.** SLAM DOWN is 46.4% (95% CI 45.6 to 47.2), and only three types are above 5% (QA §5).
- **Owner.** Encounter Systems owns the fix. QA re-tests any proposal.

### 5b. Building brunts (the director picks one building to take a launch)

Orb wants the director to "often" choose one building to take the brunt of a launch, with no incidental collisions. The mechanism is World's and Encounter's (`docs/world/buildings-in-depth.md` §4). These are the bands:

| Measure | Band | Notes |
| :--- | :--- | :--- |
| Launches that pick a building, out of those with a candidate in reach | 35 to 60% pooled | By personality: fighters who feed on collateral 40 to 60%; the protector 20 to 35%. Today that is the villain and the hero |
| Share of all planner launches that are brunts | 8 to 20% | This moves with fight time spent in settlements (Encounter's location work) |
| Brunts per minute (all arms) | Default arm 0.1 to 0.35 per minute. Villain mirror above the default; **hero mirror at most 0.15 per minute** (S3b: 0.81 in 7:06, about 0.11 per minute, which passes). 0 in matches that never come near a settlement |
| Brunts per minute, game scale | 0.3 to 1.0 | About 2 to 7 in a 7-minute match. A region-break launch may end in a brunt, at the same personality rates |
| **S3b ruling** | The default share of 7.9% sits at the 8% floor and is within noise. **Do not raise `CARE_W`**: it would add collateral at a time when civilians lost are already 56%. Re-check the share after World's ramp and cap and Encounter's location work |
| Launch cap | Unchanged | No launch type above 40% (§5). Brunts help the "four types at 5% or more" floor |

**How brunts feed the ego meters.** There is no special rule; the standing casualty rule applies:
- A brunt's casualties are credited to the fighter who launched, as today (`launchBy`). They feed the villain's menace and the hero's anguish per casualty (+0.5 if the villain caused them, +0.9 if the hero did).
- One occupied tower collapsing (about 13 people) is already a visible spike: +6.5 anguish, or +11.7 if the hero caused it. The feed and a bark make it legible.
- **No extra anguish multiplier** for brunts (Orb decided). Menace is placeholder-only and now decays with a lower cap (§9), and the roster's meters replace both.

**The collateral ramp covers brunts.** Brunt casualties and structure losses count toward every band in §4, including the low-tier bleed cap. They fall under World's tier-scaled caps and casualty ramp like any other source, and brunts are never exempt.

**Orb's calls on World's open questions:**
- *Rooftop cover:* none.
- *Targeting:* personality plus drama, weighted toward personality. The villain's row-depth bonus (he prefers the dramatic far tower) stays as his tell, inside the band above.
- *Chains:* an impact can carry a fighter through several buildings in one launch. The design is World's (`docs/world/buildings-in-depth.md` §4b); the band follows.

**Chains** (Game Design's call, within the collateral bands):

| Measure | Band |
| :--- | :--- |
| Chains among brunts | 15 to 35% pooled. Villain side 25 to 45%, hero side 0 to 10% |
| Length among chains | 2 in 55 to 75%; 3 in 20 to 35%; 4 or more in at most 10%. Never above the launcher's tier cap: 2 at tiers 1 and 2, 3 at tier 3, 4 at tier 4, and 5 only for a scripted finisher (a hard test) |
| Chains per match, P2 testbed | Default arm 0.1 to 0.6; villain mirror above the default; hero mirror at most 0.1 |
| Casualty budget for one chain, as a share of the starting population | **4% at tier 2 or below** (World proposed 8%), 12% at tier 3, 20% at tier 4. The planner drops any chain over budget (a hard test) |
| The fighter's own damage from one chain | Its wear can never by itself take a region past battered. This replaces World's 12% of max HP, because Wounds has no HP. Encounter and Simulation set the exact wear cap |

**Checked against the collateral bands:**
- *At tier 2 or below,* one chain must fit inside the game-scale low-tier bleed cap of 4% of the population per minute (§4). World's 8% would break that cap with a single event, so the budget is set to 4%.
- *At tiers 3 and 4* the low-tier cap does not apply. Chains there are bounded by:
  - the mean-at-KO band (45 to 75%);
  - the band for matches losing 90% or more (at most 10% of matches);
  - the Cyborg floor: at least 25% of civilians alive at 4:00 in at least 80% of matches.
  If QA sees the floor fail, the first lever is the tier-3 budget.
- *Always:* chains count toward every collateral band and fall under World's ramp and caps.

### 5c. Knockback slides (ground impacts)

This is Orb's trope: a fighter who hits the ground skids to a stop in one trench, rather than bouncing. The design is World's (`docs/world/knockback-slide.md`). Game Design confirms the physics as World wrote it:
- a slam (a crater) when at least 85% of the velocity is vertical, otherwise a slide;
- braking of `v' = v - (1200 + 1.2 v) dt`, about 2.5 bh from 900 units per second and about 15 bh from 2,500;
- a trench half-width of `14 + 6√E`, and a depth of at most 0.5 bh;
- damage split as 30% at touch-down and 70% over the speed lost, with the total unchanged;
- a 0.35 s recovery;
- water skipping as before.

Under Wounds, the fighter's slide damage is wear from an impact source (legs and core) and counts normally, because the rival caused the launch.

| Measure | Band |
| :--- | :--- |
| Ground contacts that slide rather than slam | 60 to 85%. Slams stay at 15% or more, so craters still read (pillar 4) |
| Slides per match | **Retired.** It was written for about 100 s matches, and at 6 to 8 minutes the count scales with length (S3b ruling) |
| Slides per minute, game scale | 1.5 to 4, which is §10's 4 to 6 launches a minute times the share that lands on ground times the 60 to 85% slide share. Also measured per launch: 35 to 70% of all launches end in a slide |
| Casualties from one slide, as a share of the starting population | Tier 2 or below at most 2%; tier 3 at most 5%; tier 4 at most 10% (a demolition line). 0 in open country. The planner reads the predicted slide and declines any launch whose slide would go over budget (a hard test, as for chains) |
| Low-tier bleed (§4) | Still at most 4% of the population per minute, with slides included |

Slides are a collateral source, counted toward every §4 band and under World's ramp and caps, never exempt. Casualties are credited to the launcher by the standing rule.

**As built** (scale window `de1bb05`), confirmed:
- friction of 1,200 + 1.2 v;
- trenches at half world scale: a half-width of (14 + 6√E) × 4, and a depth of up to 152 units (about 2 bh);
- wear applied in batches, with the total unchanged and deterministic.

One rule follows from the depth: **slide trenches never count as cover**, even though they are deeper than the 1.5 bh bowl rule (`living-destruction-numbers.md` §3). Only crater bowls and rubble heaps do. Otherwise every slide would make a hiding spot and inflate the hide bands. Slide wear is caused by the rival, so it can break a region, unlike hazard wear.

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
| Hides and ambushes | **Retired.** Hiding is removed from the base game and kept for a future stealth fighter (`future-stealth-fighter.md`) | Retired |
| Lock breaks through line of sight (`spec-wounds.md` §1c) | 1 to 4 per match; median length 2 to 3 s; never more than 4 s (a hard test); never within 6 s of the same fighter's last one (a hard test) | Not measured |
| Second breath | Battered wear recovered through second breath is at most 25% of all battered wear taken | Not measured |
| Comebacks: the winner was on the brink at some point, or rallied (`damage-model.md` §5) | 15 to 35% of matches | Not measurable yet. The prototype has no brink |
| Region breaks before the finisher (1v1) | 2 to 4 per match before Rally (S2); 3 to 5 once Rally lands (S4); first break at a median of 2:30 to 4:00 | S2: 2 breaks; first break 3:45 (`docs/director/wounds-s2.md`) |
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

**Update after Encounter's tempo pass** (`docs/director/tempo-and-location.md`, commit `71e7d32`). Fights moved from sea to land, and KAI fell from 42.2% to 34.9%, because the villain now earns menace on land. Encounter's ablations put about −4 points on the AI location changes, about −3 on the planner, and about +1 on tempo.
- **Wounds does not fix this.** Menace still multiplies damage, which is now wear, and adds to the clash roll that decides decisive exchanges.
- **The roster will.** Menace and anguish are placeholders; the four fighters' meters replace them (`economy.md` §4.2).
- **But the P2 testbed should not run skewed.** A 35/65 placeholder matchup distorts AI and director tuning. So for the placeholders, apply two rule changes, which QA re-tests. Both follow the roster principle "every meter decays or is spent" (GD-B10):
  1. **Menace decays** at 0.4 per second after 4 s without a new villain-caused casualty.
  2. **Lower the menace damage cap** from +25% to +15% (`index.html:L322` equivalent in `sim/core/damage`).
- **Testbed target:** KAI back to at least 42%, its level before the tempo pass. The 45 to 55% band applies to the real roster. The neutral-mirror stance probe is unaffected either way.
- **If QA's re-test falls short**, add the hero's composure bonus: +10% damage while anguish is under 10. It rewards the hero for keeping the fight on empty land, which the new AI now does.

**Result (S0, commit `a46cd90`).**
- The two menace rules alone moved KAI only from 35.5% to 35.7%.
- Adding the composure fallback (+10% damage while anguish is under 10) brought KAI to **40.8%** [37.4, 44.2] over 800 matches.
- The lever is weak: +30% reaches only 43.9%.
- The EP ruled to keep +10%, because the roster meters replace the placeholders. The testbed runs at about 41% for KAI until then.
- The lesson for the roster: collateral-fed buffs outweigh small calm-state bonuses, so each fighter's meter needs comparable expected value from the start (see below).

**Anguish with more than one protector** (the rule for QA-003 and GD-B09; World implements it in its window).
- Every fighter whose profile has a pressured-by-collateral meter (anguish today) gains it from **every** casualty. This is set by the fighter's data, not by the role name "hero".
- The gain is +0.5 per casualty caused by anyone else, or +0.9 per casualty the fighter caused itself, both normalised by `425 / pop0`.
- In a hero mirror, each hero takes +0.9 for its own collateral and +0.5 for its rival's.
- The same data-driven rule covers the comeback term and the lure (GD-B09).

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
| Exchanges started per minute | 15 to 24. This follows from the dynamic targets below and replaces 8 to 12 | About 21 in the prototype |
| Melee idle share inside exchanges (time with no visible strike, move or reaction) | **At most 15%** (Combat's dynamic-feel §3) | 42.5% (the prototype had 22%) |
| Still stretch inside an exchange | Median at most 0.25 s, p90 at most 0.5 s. The first strike lands within 0.6 s of the request | See `docs/combat/dynamic-feel.md` |
| Readable wind-up before a parryable strike | 0.20 to 0.30 s (Controls owns the width) | 0.10 s (0.33 s on HEAVY CLASH — WON) |
| Hit-stop floor by impact class | Light at least 0.07 s; heavy at least 0.12 s; region break or finisher at least 0.30 s | 0.05 s default; 0.08 to 0.16 s on big hits |
| Release to the next request | **At most 1.0 s** (the prototype had 0.75 s). Visible strikes: **at least 80 a minute**. Standoff p90 at most 0.6 s. No gap over 10 s | 2.7 s |
| Launches per minute | 4 to 6 | About 15.6 |
| Long launches: at least 1,500 units of horizontal travel before landing | At least 30% of launches; every region-break launch is long | About 5% (SMASH ACROSS) |
| Launches that land in a different biome from their start | At least 25% | Not measured |
| Gap close over 2,500 units | A visible pursuit flight of 0.8 to 2.0 s. Blink-strikes stay a Protagonist trait, with the ripple tell | 0.65 s at most |
| Fight time underwater | At most 10% (the ocean-share cap in §6 also applies) | Not measured; 64.6% of time over the ocean |

**Orb's feel overrides this section** (playtest, `docs/ep/vision.md`): "combat now feels slower than the prototype". The dynamic targets above replace the earlier exchange-length (2.5 to 4 s), spacing and breathing-room (1.5 to 4 s) bands. The readable wind-up and hit-stop floors stay.
- *Downtime.* The player-driven ideas (`pitches.md` §3) now live in the long gaps the fight makes itself: break launches and their chases, lock breaks, set pieces and transformation cinematics. They no longer sit between every exchange.
- *Second breath* (`spec-wounds.md` §1c) fires mainly after those same moments, which is the intent.

**The k re-band for the faster rate** (after Encounter's dynamic slice):
- Match length stays 6 to 8 minutes, reached through wear and the overtime ramp, never through dead time.
- More strikes a minute means more damage a minute. So QA measures damage per minute to the loser before and after the slice, and sets `k_new = k_old × (damage rate before ÷ damage rate after)`.
- Expected: the rate roughly doubles, so k drops from 0.06 to about 0.03. Then fine-tune within ±0.005 against the median, p10 at least 5:00, and timeouts at most 1%.
- The first-break, brink and Rally bands are unchanged. Smaller wear per strike gives smoother wound progress, which is good for the readout.

**Collateral.** More strikes also mean more collateral. World's ramp and cap (§4b) bound the rate per minute and the total, so the per-minute budgets hold whatever the strike count.

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
  - underwater is a place to pass through, not a place to fight (hiding is removed).

**For World and Simulation, through the EP.** A launched fighter who hits water should skim and splash rather than stop dead (`L726`). Orb also asked for simple fluid behaviour. **Ground impacts** (Orb, after playing the craters build): these should mostly become a knockback slide, a braking skid that cuts one deep trench and throws up dust, rather than bounces. Water skipping stays. World is building it with the rescale. **For Camera:** a planet-scale read and the launch follow (Orb's greybox notes).

## 11. Living destruction

Orb's picks from World's pitch (`docs/world/living-destruction.md`):
- fire, plus smoke and dust cover, with cover made and taken (LD1);
- landslides (LD2);
- lava, quakes and rifts, at tier 4 (LD3).

The full set of numbers is in `living-destruction-numbers.md`: the tier ladders, ignition and spread, cloud life and cover strength, slide triggers and damage, quake stress, lava onset, and hazard wear by region. The bands QA checks, at game scale per 1v1 match:

| Band | Value |
| :--- | :--- |
| Spreading fires (tier 2 and up) | 0.5 to 3, in matches with at least 5% of fight time in forest or villages |
| Forest burnt by the end, among matches that reach tier 3 | 15 to 60% of the trees |
| Clouds that block sight | 3 to 10 |
| Real slides | 0.5 to 2, in matches with at least 10% of fight time in mountains; at most 1 peak collapse |
| Quakes | In 30 to 70% of matches that reach tier 4; at most 2. Rifts at most 1 |
| Lava events | 1 to 3, in matches that reach tier 4 |
| Hazard share of all wear | At most 15% |
| Hazard alone breaking a region | Never (a hard test: hazard wear stops at 89) |
| Casualties at tier 1 from these effects | 0 (a hard test) |
| Low-tier bleed (§4) | Still at most 4% of the population per minute, with every living-destruction source included |
| Readability | At most 3 active hazard fronts in the camera's framing (a hard test); fighters always drawn above clouds; no hazard starts during a finisher or a respected cinematic |
| Lock breaks | The line-of-sight rows in §8. Clouds, rubble, canopy and terrain block sight (`living-destruction-numbers.md` §3) |

**Attribution and collateral.**
- Every effect is credited to the fighter whose event started it, and knock-on effects keep that cause.
- Casualties feed menace and anguish through the standing per-casualty rule, and the roster's meters later.
- All living-destruction casualties and structure losses count toward every §4 band and fall under World's caps and ramp. They are never exempt.

## 12. Combat variety numbers (for `data/combat/styles.json`)

These are Game Design's values for the suggestions Combat marked in its variety pass (`docs/combat/variety-pass.md`, commit `872d879`). Combat copies them into `styles.json`.

| Item | Value | Why |
| :--- | :--- | :--- |
| Volley opener | 3 blasts at **4** damage each (12 in all; suggested 5 each) | The approach is not the exchange. Stance multipliers apply, and ki gain is the normal 4% |
| Contemptuous poke (volley-only exchange) | 3 blasts at 4 each | About half a light, so the Anti-hero's barrage is flavour and pressure, not a damage race |
| Barrage (PRESSURE as blasts) | Confirmed: two blasts per strike, splitting that strike's damage | No change to damage |
| Beam-clash **split** | Chip damage **40** to each fighter, ignoring stance | Confirmed |
| Beam-clash **mutual blast** | Chip damage **60** to each fighter, ignoring stance, and launched apart at 1,400 | Confirmed |
| Beam-clash **deflect** | The loser pays **20 ki**, is pushed back 700, and takes no damage | Confirmed. A deflect into a settlement is a set piece under the collateral budgets (§4b) |
| chainP by stance and mood | AGGRESSIVE 0.50, 0.60, 0.75 (Calm, Tense, Frenzied); DEFENSIVE 0.20, 0.30, 0.40; EVASIVE 0.25, 0.35, 0.45; ESCAPE 0 | Slightly below the suggestion, to hold the chain band (15 to 35 per 100 melee exchanges) |
| chainP modifiers | −0.15 per link already landed. Heat, for fighters with the heat track only: +0.05 Heated, +0.10 Simmering, +0.20 Boiling (`stance-matrix.md` R9). **Cap 0.80** (suggested 0.95). 0 under 6 ki | This replaces the suggested "+0.1 at Boiling" |
| Blitz chance (first window, Tense or Frenzied) | Tense 0.25, Frenzied 0.50, **+0.05 per act above 1** (suggested +0.10), **cap 0.60** | Target 2 to 6 blitzes a minute in Tense and Frenzied (§9) |

**Match length.** Volleys and chip damage add wear. They count in the damage rate QA measures for the k retune after Encounter's dynamic slice (§10), so k absorbs them and the median stays 6 to 8 minutes.

## 13. Questionnaire 5 rulings (Orb, 2026-09-30)

These rulings are binding for QA's tuning. Where they touch other docs, those docs point here.

| Topic | Ruling | Band QA tunes to |
| :--- | :--- | :--- |
| **Brink** | **Orb picked A**, "the crippling moment" (`pitches.md` §5). Limbs stop at battered, and a limb breaks only in a crippling moment. The brink is the core broken, and limb wear past battered spills into the core | Limb breaks 0.3 to 0.5 a match, at most 1 per fighter; the brink once a match plus any re-brinks after Rallies; length 6:00 to 8:00 |
| **Match length** | Unchanged | Median 6:00 to 8:00, p10 at least 5:00, p90 at most 10:00 |
| **Even overall, situational** | Each fighter should have ground where they win: terrain and tier swing it | Every pairing 45 to 55% overall. Within each pairing, each fighter wins at least 58% in at least one context (a biome class or a tier band at the KO) and at most 42% in another |
| **Comebacks common** | This replaces the S4 "rare, earned" stance. **Trailing-fighter help:** the fighter with more region stages lost gets +5 on the finisher contest, +10% ki regen and +5 on the director's parry chance, while behind by 2 or more stages | Comeback wins (the winner was on the brink, or trailed by 2 or more stages) in 30 to 45% of matches. Rallies 0.3 to 0.7 a match |
| **DEFENSIVE punished over time** | **Guard fatigue.** After 3 s of continuous DEFENSIVE, the guard multiplier worsens from 0.38 by +0.05 per second, up to 0.80, and the guard's ki drain doubles after 6 s. The patience rewards (R4's counter and the clean parry at 2 s) sit in the 2 to 4 s sweet spot | Median continuous DEFENSIVE hold 2 to 5 s; holds over 10 s in under 5% of DEFENSIVE time |
| **Escape by terrain and distance** | The pursuit slip chance is 0.5, then: +0.10 beyond 1,500 units and +0.20 beyond 4,000; **+0.10 near sight blockers** (forest, mountains, smoke, skyline); **−0.10 over open ground** (plains, desert, the sea surface); ±0.07 per tier. It is clamped at 0.05 and 0.88 | Slip rate 35 to 65% overall, with covered and open terrain at least 15 points apart |
| **2 to 4 signatures a match, each an event** | A **120 s signature cooldown per fighter** after one fires. The cost stays 45 ki. The director stages each as a set piece: a wide shot and the clash-shape pool | 2 to 4 signatures fired per match (median 3) |
| **Transformations are a big swing** | Each completed transformation starts a **15 s surge**: +20% damage and +10 mood for the transformer, and the director makes the opponent's next exchange a read (a telegraphed attack) | In the 15 s after a transformation, the transformer wins at least 60% of decisive exchanges, and the opponent changes stance within 5 s in at least 70% of cases |
| **Adaptive AI** | The AI adapts its *decisions*, never its numbers: read accuracy (predicting the player's stance) drifts within ±15% of its difficulty, toward keeping the match close, based on the standing in the match and the player's last 3 results | In AI matches, 40 to 60% are close finishes (the loser was within 1 stage of the brink) |
| **What decides who wins** | Stance reads, energy management and transformation timing | In the neutral-mirror probe, a good policy beats a naive one by at least 10 points on each of the three. Positioning alone moves it at most 10 points |
| **Surprise, 6 out of 10** | The director's random terms are sized so that the state-favoured fighter wins most decisive exchanges, but not all | Upsets (the fighter the state favours loses the exchange) in 30 to 40% of decisive exchanges |
| **Anguish, 3 out of 10** | Mostly emotional. The regen penalty drops from 0.025 × anguish to **0.01 × anguish** (at most −1 ki per second), with no other mechanical effect. Anguish mainly drives voice and posture | None beyond the win-rate bands |

### The time-cap story event

- *Rule:* at **11:00** a story event starts and lasts up to 60 s. Both fighters are on the brink, Rallies are off, and every decisive exchange is a finisher. Play still decides most of these endings.
- *If nothing decides it in 60 s,* the event picks the winner by one of the rules below. Narrative's options are in `docs/narrative/time-cap-endings.md`, and Orb picks:

| Narrative's option | Winner rule |
| :--- | :--- |
| **A. The crust gives way** (the surviving plate decides) | **Higher vitality wins** (less core and limb wear), and the weaker fighter falls with the plate. Ties go to the higher tier, then the most damage dealt in the event |
| **B. A watch force hauls one fighter out** | **Less collateral caused wins** (casualties plus structures, normalised). Ties go to higher vitality |
| **C. The evacuated crowd returns and rings them** | **Fewer casualties caused wins.** Ties go to higher vitality |

- **Orb picked A** (the crust): higher vitality wins. It is decided by the fight itself. B and C would always hand time-cap endings to the protectors over the fighters who feed on collateral. Time-cap endings stay under 1% of matches.
