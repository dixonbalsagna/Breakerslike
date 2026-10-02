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
| Civilians lost at the KO, mean | 25 to 50% | **12 to 30%** (re-based for the slower ladder, §21; it was 25 to 50% after evacuation, and 45 to 75% before) | 38.7% |
| Worst pairing's mean | at most 65% | at most 55% (§21; it was 70%) | 64.2% (villain mirror) |
| Matches losing 90% or more of civilians | at most 7% | at most 5% (re-set, §4b) | 5% |
| Low-tier bleed: while both fighters are at tier 2 or below, civilians lost per minute | at most 40% of the population per minute (a guard against P2 work making it worse) | at most 4% of the population per minute | About 42% per minute over the whole match. Per-tier rates are not yet split out |
| Civilians left at 4:00 (so the Cyborg's track can finish) | none | At least 25% alive in at least 80% of matches | none |
| Structures lost at the KO, mean: a **share of row-1 (front-row) structures**. Row 1 is today's 47 buildings, unchanged by buildings in depth (`docs/world/buildings-in-depth.md`) | 20 to 40% of row 1 | **25 to 50% of row 1** (§21; it was 40 to 75%) | 30% (14.1 of 47) |
| Structures lost at the KO, all rows (about 110): a watch metric, not a gate | 10 to 35% | 15 to 40% (§21; it was 25 to 60%) | Not yet measured |

**Mechanisms.** World is proposing tier-scaled caps and a casualty ramp to meet the game bands. Game Design sets only the bands. The low-tier bleed band is the measurable form of the P3 exit criterion "no fight destroys the planet at low tiers". QA needs a per-tier split of casualties to check it. That is requested through the EP. Structures have their own tier gate for beams, with per-tier bands, in §15.

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

**Expected result.** Over a 7-minute arc (acts at tiers 1 to 2, then 2, 3 and 4), the budgets add up to about 45 to 50% lost at the KO, plus set-piece borrowing. That was the lower half of the old game band (45 to 75%). *Superseded:* with evacuation the band is 25 to 50% (§4b), and G0 measured 29%. The Cyborg floor (at least 25% alive at 4:00) holds, because by 4:00 the ceiling is 30% at tier 2 or 60% at tier 3.

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

- **Cap.** In every QA arm, no launch type is above **45%** of all launches, and the match-clustered 95% upper bound must be at most 47%. It was 40% and 42% until the M1b re-banding (§18).
- **Floor.** At least **4** launch types are each at or above **5%** in the default arm.
- **Today.** SLAM DOWN is 46.4% (95% CI 45.6 to 47.2), and only three types are above 5% (QA §5).
- **Owner.** Encounter Systems owns the fix. QA re-tests any proposal.

### 5b. Building brunts (the director picks one building to take a launch)

Orb wants the director to "often" choose one building to take the brunt of a launch, with no incidental collisions. The mechanism is World's and Encounter's (`docs/world/buildings-in-depth.md` §4). These are the bands:

| Measure | Band | Notes |
| :--- | :--- | :--- |
| Launches that pick a building, out of those with a candidate in reach | 35 to 60% pooled | By personality: fighters who feed on collateral 40 to 60%; the protector 20 to 35%. Today that is the villain and the hero |
| Share of all planner launches that are brunts | **4 to 10%** (§18; it was 8 to 20%) | This moves with fight time spent in settlements (Encounter's location work) |
| Brunts per minute (all arms) | **Retired for the testbed** (§18): use the game-scale row below, and the mirror rows wait for the roster. It was: default arm 0.1 to 0.35 per minute. Villain mirror above the default; **hero mirror at most 0.15 per minute** (S3b: 0.81 in 7:06, about 0.11 per minute, which passes). 0 in matches that never come near a settlement |
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
  - the mean-at-KO band (25 to 50%, §4b);
  - the band for matches losing 90% or more (at most 10% of matches);
  - the Cyborg floor: at least 25% of civilians alive at 4:00 in at least 80% of matches.
  If QA sees the floor fail, the first lever is the tier-3 budget.
- *Always:* chains count toward every collateral band and fall under World's ramp and caps.

### 5c. Knockback slides (ground impacts)

This is Orb's trope: a fighter who hits the ground skids to a stop in one trench. *Since 2026-10-01 Orb also wants bounces, tumbles and flights off a crater's lip; §20 extends these rules.* The design is World's (`docs/world/knockback-slide.md`). Game Design confirms the physics as World wrote it:
- a slam (a crater) when at least **94%** of the velocity is vertical, otherwise a slide. It was 85% until §19;
- braking of `v' = v - (1200 + 1.2 v) dt`, about 2.5 bh from 900 units per second and about 15 bh from 2,500;
- a trench half-width of `14 + 6√E`, and a depth of at most 0.5 bh;
- damage split as 30% at touch-down and 70% over the speed lost, with the total unchanged;
- a 0.35 s recovery;
- water skipping as before.

Under Wounds, the fighter's slide damage is wear from an impact source (legs and core) and counts normally, because the rival caused the launch.

| Measure | Band |
| :--- | :--- |
| Ground contacts that slide rather than slam | **Retired at G0** (§14): the landing mix per launch below replaces it. Slams stay at 15% or more of launches, so craters still read (pillar 4) |
| Slides per match | **Retired.** It was written for about 100 s matches, and at 6 to 8 minutes the count scales with length (S3b ruling) |
| Slides per minute, game scale | **Retired at G0** (§14): it was derived from the old 4 to 6 launches a minute |
| **How launches end** | By how the journey ends (§20, the second landing ruling): skids or tumbles to a halt 40 to 60% and the largest class; wall 5 to 15%; slam 8 to 18%; caught in the air 15 to 30%; water 2 to 10%; brunt 4 to 10%. Bounces are an event rate: 20 to 40% of launches (§23) |
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
| Region breaks before the finisher (1v1), under the core-only brink | **1.5 to 2.5 a match:** limb breaks 0.3 to 0.5 (§13), plus brinks (the final brink, re-brinks after Rallies and the rare double brink). The old 2 to 4 and 3 to 5 bands are retired. The first-break timing gate is retired too: the first brink at a median of 4:30 to 7:00 (`spec-wounds.md` §5) covers timing | 1.7 (QA's crippling tune on `580c5a0`) |
| Finishers preceded by a brink call-out | 100% | none |
| Lead changes: which fighter has more region stages lost flips | Median at least 2 | Not measured |
| Signatures fired | 2 to 5 per match, median 3: the 120 s cooldown (§13), plus the last stand's free signature (`spec-wounds.md` §1b). It was 2 to 4 | Not measured at G0 |
| Beam clashes | **Re-based at G0:** 30 to 60% of signatures fired end in a CLASH. The old 2 to 8 per match predates the cooldown | 10.2 per match at G0, with no cooldown in the sim |
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

**QA's trace and the ruling** (2026-09-30; 800 matches, default and swap seeds).
- *The finding.* The gap comes from the hero and villain package, not the slot: swapping the whole package flips it (KAI 59.4%). It opens in act 1. KAI suffers the first break in 63% of matches and wins only 12% of those. VORR wins the quick matches and KAI the long ones.
- *The ruling: adopt QA's combined package for the placeholders.* It puts KAI at **43.6%**, over the 42% testbed floor, with length unchanged.
  1. **Planner care 0 for both fighters.** This is the launch planner's personality term, worth +3.8. On the testbed the personality lives in the lure and the meters instead. For the roster, care returns as a per-fighter data value, and its expected value counts in that fighter's balance.
  2. **Menace damage cap +5%**, down from +15%.
  3. **Menace regen of 0.01 × menace** ki per second, so at most +1. This mirrors the anguish ruling (§13).
- *Kept, because removing them costs KAI:*
  - VORR's ×0.95 speed (−2.9 without it);
  - the hero's lure (−4.1 without it);
  - menace decay and the composure bonus, unchanged;
  - the anguish regen penalty at 0.01 (§13). It has no balance effect, which is what that ruling intended.
- *Targets.*
  - **Testbed:** KAI at least 42% on QA's default and swap set, re-measured once D1b wires the meters' data effects. No further placeholder levers.
  - **Roster:** every pairing 45 to 55% (§1, §13). The trace confirms the lesson below: the gap opens in act 1, so each fighter's meter needs comparable expected value from the first minute.

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
| Exchanges started per minute | **15 to 26** (§22; it was 15 to 24). This follows from the dynamic targets below and replaces 8 to 12 | About 21 in the prototype |
| Melee idle share inside exchanges (time with no visible strike, move or reaction) | **At most 15%** (Combat's dynamic-feel §3) | 42.5% (the prototype had 22%) |
| Still stretch inside an exchange | Median at most 0.25 s, p90 at most 0.5 s. The first strike lands within 0.6 s of the request, **measured only for exchanges that start within 2,500 units**; longer gaps are pursuit flights of 0.8 to 2.0 s by design (G0 re-base) | See `docs/combat/dynamic-feel.md` |
| Readable wind-up before a parryable strike | 0.20 to 0.30 s (Controls owns the width) | 0.10 s (0.33 s on HEAVY CLASH — WON) |
| Hit-stop floor by impact class | Light at least 0.07 s; heavy at least 0.12 s; region break or finisher at least 0.30 s | 0.05 s default; 0.08 to 0.16 s on big hits |
| Release to the next request | **At most 1.0 s** (the prototype had 0.75 s). Visible strikes: **at least 80 a minute**. Standoff p90 at most 0.6 s. No gap over 10 s | 2.7 s |
| Launches | **Re-based at G0:** 40 to 65% of exchanges started end in a launch. The old 4 to 6 a minute came from the 8 to 12 exchange tempo, and Orb asked for more launches across the map | 10.65 a minute, 60% of 17.6 exchanges (G0) |
| Long launches: at least 1,500 units of horizontal travel before landing | At least 30% of launches; every region-break launch is long | About 5% (SMASH ACROSS) |
| Launches that land in a different biome from their start | At least 25% | Not measured |
| Gap close over 2,500 units | A visible pursuit flight of 0.8 to 2.0 s. Blink-strikes were a Protagonist trait; all teleporting is on hold (Orb, 2026-10-01; `control-rules.md` §11) | 0.65 s at most |
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
| **Crippling moment, as built** (`580c5a0`) | The head spills into the core and never breaks: only arms and legs can be crippled. The limb must **already be battered when the exchange starts** (not by the same blow), so there is always a visible warning. The breaker gets a meter surge: +10 power for the placeholders, and +10 to the fighter's ego meter for the roster. Broken legs make the DEFENSIVE multiplier ×0.8 (0.38 becomes 0.30), and guard fatigue still starts from the new value.<br>**Tuned values (QA, adopted):** base 0.08, with tierAhead, lateBonus and the DEFENSIVE modifier at ±0.05 each, gave 0.44 limb breaks a match. **In force now:** base 0.048 with ±0.03 each, scaled down for the 0.4 / 0.6 guard split, which gives 0.47 (57% arms, 43% legs).<br>**Arm skew:** arms take 85% of limb breaks, because the guard puts its wear on them. The lever is to **spread guard wear**. A guard is braced through the whole body, so guard wear splits 60% to the arms and 40% to the legs (data: `guardWearSplit`). This fixes the cause and keeps the warning rule, since a leg must still be battered first. Weighting the pick toward legs alone can't break legs that are rarely battered. *Fallback,* only if arms still take more than 65% after the split: weight the crippling pick ×1.5 toward legs when both are eligible. **Applied at D1b** (arms at 68%). If arms are still over 65%, the next step is ×2.0 | Limb breaks 0.3 to 0.5 a match (0.44 at the tuned values). Arms and legs each take 35 to 65% of limb breaks, with length still in band |
| **D1b rulings** (QA, 3,200 matches) | k = **0.041** confirmed. The finisher struggle's base survival rises from 15% to **23%**, which is the Rally lever and also lengthens the post-brink phase. The ×1.5 leg weighting is applied. **Brink chapter (after `6be4c3a`):** the set-up rule. There is no finisher from the exchange that caused the brink, and one decisive win opens the fighter on the brink before a finisher can start (`brinkSetups` = 1). **In force** (QA hit every band): k 0.045, `brinkSetups` 2, `guardWearSplit` 0.4 / 0.6, crippling base 0.048 ±0.03. Measured: brink to KO 48 s, median 6:56, first brink 5:52, Rallies 0.37, survival 35%, limb breaks 0.47 (57/43), KAI 50%. Details in `spec-wounds.md` §1b | First brink at a median of 4:30 to 7:00. **New: a median of 45 to 90 s from a fighter's first brink to the KO.** Rallies 0.3 to 0.7. Average survival 25 to 40%. Arms and legs each take 35 to 65% of limb breaks. KAI at least 42% (placeholders) |
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

## 14. G0 baseline triage (QA `docs/qa/baseline-g0.md`, 2026-09-30)

Every brink-chapter band passes. The 24 failing rows sort into three groups.

**A. Stale in QA's harness: re-base the harness, no game change** (QA)

| Row | G0 | What to change |
| :--- | :--- | :--- |
| §4 civilians lost at the KO | 29% against 45 to 75% | The band has been **25 to 50%** since evacuation (§4b). 29% passes |
| §10 exchanges started per minute | 17.6 against 8 to 12 | The band is **15 to 24** (§10). Passes |
| §10 exchange length, request to release | 1.7 s against 2.5 to 4.0 s | **Retired** by Orb's dynamic feel (§10). Retire the row |
| §10 breathing room, release to request | 0.9 s against 1.5 to 4.0 s | **Retired.** It is replaced by "at most 1.0 s", which passes at 0.93 s |
| §10 launches per minute | 10.65 against 4 to 6 | **Re-based:** 40 to 65% of exchanges end in a launch. 60% passes |
| §10 feel, request to first strike | 0.72 s against at most 0.6 s | **Re-measure** on exchanges that start within 2,500 units; longer ones are pursuit flights by design. If it still misses, Q4's attack clock (A) trims the first strike's lead-in (Encounter, with Combat) |
| §5c ground contacts that slide (59%), slides per minute (9.4), and launches ending in a slide (88%) | Three rows | **Re-based** into one landing mix per launch (§5c). G0 is about 88% slide, and the fix is in groups B and C |
| §8 INFO row, region breaks "4 to 6" | 2 | **Retire.** The band is 1.5 to 2.5 (§8), which passes at 2.04 |

**B. Fixed by World's B2 or Q4** (re-measure after they land)

| Row | G0 | Why it follows |
| :--- | :--- | :--- |
| §5b brunt share of launches | 1.3% against 8 to 20% | **B2** (the brunt) puts BUILDING SMASH candidates in every row and aims at the director's chosen building |
| §5b launches picking a building when one is in reach | 18.4% against 35 to 60% | **B2**, the same. The personality split still applies: collateral-feeders 40 to 60%, the protector 20 to 35% |
| §5 SMASH ACROSS at 44% (eight rows, four arms) | Cap 40%, bound 42% | **B2**: brunts take launch share from SMASH ACROSS. If it is still over after B2, Encounter raises the planner's variety penalty on the most-used type (data) |
| Landing mix: slides at about 88% of launches | 45 to 75% | Partly **B2** (brunts end launches in buildings) and partly the ocean fix in group C (skims). If slides are still over 75%, World raises the slam share of steep impacts |
| §8 beam clashes, 10.2 a match | Re-based: 30 to 60% of signatures | **The 120 s signature cooldown** (§13) is not in the sim. Encounter adds it in Q4 as data, and QA adds the "signatures fired, 2 to 4" row. Q4's clash-by-state rule (B) then sets the share |

**C. Fix now**

| Row | G0 | Who and what |
| :--- | :--- | :--- |
| §6 biome floors: ocean 0.5%, plains 0.4%, city 2.1% | Floor: half the planet share, or 3% | **Encounter** (AI location, data). The lure now runs to forest, desert and mountains only. Put ocean and plains back in the lure rotation, and add a biome-variety term to the AI's location choice: a penalty on a biome's excess over its planet share, like the launch variety penalty. The villain's pull toward settlements lifts the city. Water time stays under the §10 cap of 10% underwater |
| §6 beam variants: HORIZON CLEAVE 0.5%, MERIDIAN SCAR 0.5% | At least 3% each | **Follows the biome fix** (the ocean and plains variants). No separate change |
| §1c lock breaks, 0.85 a match at 0.7 s | 1 to 4 a match, 2 to 3 s | **Waits for living destruction** (LD1 to LD3: smoke, dust and fire clouds). Today only terrain breaks lock, briefly. Re-measure after LD. If it is still short then, re-base the length to 1 to 3 s |

**After World's D1 (districts)** the planet has about 300 to 400 buildings (196 today), and pop0 is about 1,800 whole people, about four per building. Every collateral band is a share, and every per-casualty gain is normalised by `425 / pop0`, so no band number changes. QA re-checks §4 after D1 and re-defines row 1 in the structures rows (today's 47 front-row buildings) from the new layout.

## 15. Beams and structures: the tier gate (2026-10-01)

**The gap** (World's trace, seed 4). A tier-1 signature beam levelled 26 buildings in 6 ticks, 5.5 s into the match. Each beam sample does 110 + 75 × power to structures within about 210 units, and a house has 108 to 216 hp. Casualties were capped by the collateral window, but structures had no tier gate. That breaks pillar 4 and the P3 exit rule that no fight destroys the planet at low tiers.

**The ruling has two layers.** The factor sets how hard a beam bites, and the cap is the guarantee. A factor alone can't promise the result, because a long beam adds up many samples.

| Tier | Structure damage factor (`ladder.json`) | Buildings one beam may level, as a share of all structures | Overshoot past the target |
| ---: | ---: | :--- | :--- |
| 1 | ×0.25 | At most 1% (2 of today's 196) | 600 × WS, about 3% of the planet |
| 2 | ×0.5 | At most 3% (6) | 1,200 × WS, about 6% |
| 3 | ×1.0 | At most 8% (16) | 2,400 × WS, about 12.5% |
| 4 | ×1.5 | At most 20% (39) | 4,000 × WS, about 21% |

1. **The factor** is World's suggestion, adopted. It multiplies the structure damage of every beam and energy blast, by the firing fighter's tier. A tier-1 beam wounds houses and doesn't level them.
2. **The cap.** Past its cap, a beam leaves each further building standing at 25% hp, scorched and burning, so the path still reads. The cap is a share, so it scales when districts raise the building count (§14, D1).
3. **Length scales too.** Today the overshoot is (2,000 + 400 × tier) × WS, which is almost flat: 12.5% of the planet at tier 1. The new overshoot is in the table. The beam's travel **to** its target is never shortened (pillar 3), and the 4,200 × WS total cap stays.
4. **Nothing else changes.** The beam's damage to the fighter, terrain carving by power, and the casualty window are as they were. Launches, slides and brunts keep their own budgets (§5b, §5c).

**QA bands** (all sources, measured by the higher fighter's tier at the time):

| Measure | Band |
| :--- | :--- |
| Buildings levelled by one beam | At most the cap for its tier (a hard test) |
| Buildings a tier-1 beam touches that are left standing | At least 70% |
| Structures levelled per minute at tier 1 | At most 2% of all structures |
| Structures levelled per minute at tier 2 | At most 4% |
| Structures levelled per minute at tier 3 | 3 to 10% |
| Structures levelled per minute at tier 4 | 6 to 20% |
| Escalation | Each tier's mean rate is at least 1.5 times the tier below it, so destructiveness keeps scaling (Orb) |
| Before any fighter reaches tier 3 | No match has lost more than 10% of its structures (a hard test) |
| Structures lost at the KO (§4) | Unchanged: 40 to 75% of row 1, and 25 to 60% of all rows as a watch metric. Re-check after the change, because early losses fall and the tier-4 factor rises |

**If the per-minute bands fail from other sources** (slides, brunts, power-up craters), World adds a rolling structure budget on the collateral window, like the casualty ramp in §4b. It isn't needed for the beam fix.

Encounter implements the factor, the cap and the overshoot in `beam.gd` with its step 2. The factor and the cap are data.

## 16. Fight lanes and depth (ADR 0009): Game Design's confirmations (2026-10-01)

Encounter's rules are in `docs/director/fight-lanes-director.md`. Three are confirmed here.

1. **A rush ploughs through a building in its way,** as a brunt paid from the collateral budget. A protector (care above 0) arcs over a roof within 6 bh instead, at no ki cost.
   - *One condition:* a plough obeys the chain limits in §5b. It crosses at most the rusher's tier cap of buildings (2 at tiers 1 and 2, 3 at tier 3, 4 at tier 4) and stays inside the casualty budget for one chain. Past either limit, any fighter arcs over the rest.
   - On the testbed both placeholders have care 0 (§9), so both plough, and KAI's anguish pays for it.
2. **Exchanges may be fought inside a block row** after a targeted smash. A fighter left in a block row steps out to the nearest street when next free. Collateral inside the row counts as usual.
3. **The deviation sizes:** 0.3 to 1.0 bh for a shove, 0.3 to 1.2 bh for vertical launches, and 0.6 to 2.5 bh for long launches and throws, skewed small and leaning back toward the lane's centre near an edge. They are texture only: a small deviation never leaves the lane, so it never changes an outcome, damage or collateral.

## 17. Questionnaire 10 notes (2026-10-01)

**Harbour and industrial districts** (numbers for World's `worker_share` and `vehicle_share`, `docs/world/districts-plan.md`). They have few civilians, mostly workers who evacuate fast, so they are the places to fight without collateral.

| Field | Harbour | Industrial | For comparison, downtown |
| :--- | ---: | ---: | ---: |
| `pop_density` | 0.2 | 0.15 | 1.0 |
| People per building | 0 to 3 | 0 to 3 | By footprint |
| `worker_share` | 0.8 | 0.9 | 0 |
| `vehicle_share` | 0.3 | 0.4 | World's value |

- Workers leave at the fast rate: a quarter of the usual flight time.
- They start when a beam, a blast or a brunt reaches the district, or when the fight comes within 10 bh of it.
- *QA band:* a fight in a harbour or industrial district loses at most 10% of that district's people. The hero's lure reads these districts as empty ground.

**The low-end target.** 30 frames a second with reduced effects is acceptable on old laptops and phones (Orb).
- The sim stays at 60 ticks a second on every device, so no band here changes.
- Reduced effects never remove a cue: the tells, the ready cues, the wound readout and the hazard warnings stay.
- At 30 frames an 8-tick perfect-block window is four drawn frames. If input is read once per drawn frame there, the early tolerance gains 2 ticks, as it does on touch (`control-rules.md` §1). Controls decides how input is sampled.

**Set pieces and the transformation pace** are in `spec-wounds.md` §8b. **The upgrade draft** is `upgrade-plan.md`. **Blitzes** are `control-rules.md` §11, and the bounce table there extends §12's blitz numbers.

## 18. Re-banding after B2 and the location slice (QA's M1b set, 2026-10-01)

QA's final M1b set passes every mood, style and wound row (`docs/qa/tuning-m1b.md`). These rows moved, and are re-based.

| Row | M1b | Ruling |
| :--- | :--- | :--- |
| Brunts per minute | 0.49 against 0.10 to 0.35 | **Use the game-scale band, 0.3 to 1.0** (§5b), and retire the testbed row. Orb wanted more building smashes, and 0.49 passes |
| Brunts as a share of launches | 5.0% against 8 to 20% | **4 to 10%.** The old share assumed 4 to 6 launches a minute. At today's 10 or so, 4 to 10% is the same 0.4 to 1.0 a minute |
| Hero mirror brunts | 0.45 a minute against at most 0.15 | **Retired on the testbed,** with the villain-mirror row. Both placeholders run at planner care 0 (§9), so the mirrors can't differ. The personality rows return with the roster's per-fighter care |
| SMASH ACROSS | 40.8% against a 40% cap | **The cap moves to 45%,** with the clustered bound at 47%. Orb asked for more launches across the map, and the floor of four types at 5% or more still protects variety |
| How launches end | Slide 81% and slam 63% overlap; water 13% against 3 to 10% | **One landing class per launch** (below) |
| Finisher survival above 0 after a third Rally, or after 11:00 | A few seeds | **Both.** The spec relaxes for the third Rally, and the sim enforces 0 from 11:00 (`spec-wounds.md` §2 and §5) |

**One landing class per launch.** A launch is classed by the first thing that ends its flight, so the classes add up to 100%:
- **brunt:** it hits a building first;
- **water:** its first contact is water, as a skim or a splash;
- **slide:** its first ground contact carries on for 2 bh or more;
- **slam:** its first ground contact stops within 2 bh.

| Class | Band |
| :--- | :--- |
| Slide | 45 to 70% |
| Slam | 15 to 35% |
| Water | 5 to 15% |
| Brunt | 4 to 10% |

This replaces the "How launches end" row in §5c. **§19 replaces the table above** and adds a fifth class. The water band rises because the location slice put fights back over the sea, which is what the §6 floors asked for.

## 19. Landings: slides stay the majority (2026-10-01)

**What QA measured** with one class per launch (HEAD after `69d9be7`): slide 24.7%, slam 54.0%, water 3.6%, brunt 3.8%, and 13.9% with no ground contact because the follow-up caught the victim in the air. The old 81% slide figure counted slides after a slam's hop. Launches are slam-first today: the angles are steep, and a contact slams when 85% of its velocity is vertical.

**The ruling: don't re-band to fit.** Orb asked for landings "weighted towards skidding to a halt", so slides stay the majority and the game changes to get there.

**A fifth class: caught in the air.** The follow-up reaches the victim before any contact. It is its own class, because it is the ping-pong and the air catch Orb wants.

| Class | Band (share of all launches) |
| :--- | :--- |
| Slide | **40 to 60%**, and at least 65% of ground landings (slides plus slams) |
| Slam | 12 to 25%, so craters still read (pillar 4) |
| Caught in the air | 10 to 25% |
| Water | 5 to 15% |
| Brunt | 4 to 10% |

This replaces the table in §18. *§20 replaces it in turn, adding a bounce class.*

**How to get there,** in this order, re-measuring after each step:
1. **The slam threshold** (World, one value): a contact slams only when **94%** of its velocity is vertical, up from 85%. That is steeper than about 70 degrees, against 58 today. Impacts between the two keep enough sideways speed to skid 2 bh or more, so they become slides.
2. **SLAM DOWN becomes a drive** (Encounter, launch vectors): by default it sends the rival down and forward at 40 to 55 degrees below level, which ploughs into a slide. The straight-down slam is kept for three cases: a break or finisher launch, a rival directly below, and the planner's crater set piece from tier 3.
3. **The planner's vector mix** (Encounter, data): if slides are still under 40%, raise the weight of shallow launches, and give UPPERCUT more forward carry so its fall lands shallower.

Slams keep their floor, because Orb also asked for craters with rims and ejecta. The intent is that a slam is an event and a slide is the norm.

Encounter implements steps 2 and 3 with the variety work. World changes the threshold.

**SLAM DOWN's angle and the CRATER SLAM gates** (Combat's `docs/combat/launch-vectors.md`). The split into two vectors is confirmed: SLAM DOWN is the drive, and the straight-down slam is its own gated vector, working label CRATER SLAM.
- *The angle rule is amended.* Combat proposed 40 degrees within 2 bh of the ground, rising to 55 at 12 bh. Under §20 a contact between 30 and 70 degrees is a bounce, so every drive would bounce and slides would stay a minority. The drive is **25 degrees within 2 bh of the ground, rising evenly to 50 at 12 bh and above**, with no draw. A low drive then skids at once, and a high one bounces and then skids.
- *The gates are confirmed,* with two limits added. "Directly below" means the rival is within 1 bh sideways and at least 3 bh lower. The crater set piece needs tier 3 and comes at most once every 30 s per fighter. Break and finisher launches may always use it.
- The slam band stays 8 to 15% of launches (§20).
- *The label:* the drive is called **DRIVE DOWN**, Narrative's proposal, pending Legal's search. "Slam" now means only the straight-down event, CRATER SLAM. Older sections and the data still say SLAM DOWN until Combat and Encounter rename it.

## 20. Knocked about: how a launched fighter crosses the ground (Orb, 2026-10-01)

Orb wants fighters to be ragdolled: to skid, tumble and bounce over the course of a fight, the way they already skip across the ocean. A fighter who skids up a crater's side should fly off the lip, not ride down the inside. These are the rules for World and Encounter. Every number is a proposal for data, in the sim's normalised speed units (today a ground hit under 350 is no impact, and 2,000 is a hard one).

**The rule Orb approved.** A skidding or tumbling fighter leaves the ground whenever the terrain curves away beneath him faster than gravity pulls him down. He keeps the speed and direction he had. It applies to crater rims, ridges, rubble heaps and cliff edges, and it replaces today's cliff rule (a drop steeper than 1.0). There is no speed threshold to tune: a slow fighter simply follows the ground over the rim.

### The states

| State | He enters it when | While in it | He leaves it when |
| :--- | :--- | :--- | :--- |
| **Airborne** | He is launched, flies off a lip, or rebounds from a bounce or a skip | Ballistic flight, as today | He touches ground or water |
| **Skid** | Ground contact shallower than **40** degrees, at a speed over 900 (30 before the ruling at the end of this section) | Today's slide: braking of 1,200 + 1.2 v, and a trench. The surface scales the braking: ×0.8 on paving and rock, ×1.3 on sand and soil | His speed falls under 600 (tumble); the ground curves away (airborne); or a rise steeper than 0.8 stops him with a stop-impact, as today |
| **Bounce** | Contact between **40** and 70 degrees, at a speed over 900, with a bounce left | He rebounds, keeping 80% of his speed along the ground and 45% of his vertical speed. The second bounce keeps 35% and the third 25% | At once: he is airborne again |
| **Slam** | Contact steeper than 70 degrees (§19) | A crater. One small hop at a speed of 2,000 or more, as today | He is down |
| **Tumble** | Any contact or skid at a speed of 350 to 900; any contact on rubble; or a 40 to 70 degree contact with no bounce left and too little speed to skid | He rolls, with 0.7 of the skid's braking (§23; it was double), for 1.2 s at most | He stops (down), recovers early (below), or the ground curves away (airborne) |
| **Skip** | On water, as today: a speed over 500 and shallower than about 31 degrees | Up to 6 skips, each keeping 85% of the speed along the water | He sinks with a splash |
| **Down** | He stops | Recovery of 0.35 s after a skid or a tumble, or 0.75 s after a slam | He is free |

- A 40 to 70 degree contact over 900 with no bounce left is a skid: he digs in.
- **Bounces allowed,** by the launcher's tier: 1 at tier 1, 2 at tier 2, and 3 at tiers 3 and 4.
- **Bounds on one journey** (hard tests): at most 8 contacts of all kinds, and at most 4 s from the first contact to the stop. Past either, he tumbles to a stop.
- Everything is decided by speed, angle and surface. There is no random draw, so the journey is deterministic and the planner can predict it.

### Wear

- **A journey never costs more than one impact.** Today a slide pays 30% of its impact wear at touch-down and 70% over the speed it loses. The same budget now covers the whole journey: each bounce and the tumble pay for the speed they take off, and a flight off a lip costs nothing.
- So a tumble does wear, but only its share of that budget. The wear is impact wear to the legs and core, as today.
- The collateral rules are unchanged. Each contact does its area damage, the slide budgets by tier apply (§5c), and the planner declines a launch whose predicted journey, lips and bounces included, would go over budget.

### Recovering early (the tech)

- **A dodge tap** recovers him: he flips to his feet with no recovery time, and the rest of the journey's wear isn't paid.
- **When it works:** a fresh dodge tap from 4 ticks before a bounce's contact to 8 ticks after it (10 on touch), or at any time in a tumble (Controls' window, `docs/controls/tech-and-pulse-input.md`). A press that misses the window costs nothing.
- **When it doesn't:** in a skid over 900 (he must shed speed first), in a slam, on water, and on a break or finisher launch, which are set pieces.
- **Cost:** 15 ki, and it shares the dodge-cancel's 3 s cooldown (`control-rules.md` §2).
- The AI recovers on 20%, 50% or 80% of chances (easy, medium, hard).

### The landing bands (replaced by "The landing ruling after World's build", at the end of this section)

A launch is still classed by its first contact. A bounce is a new class. A flight off a lip happens after a skid has started, so that launch stays a **slide**; lips are counted as their own event.

| Class | Band (share of all launches) |
| :--- | :--- |
| Slide | 40 to 55%, and still the largest class |
| Bounce | 8 to 15% |
| Slam | 8 to 15% |
| Caught in the air | 10 to 25% |
| Water | 2 to 10% (§21; it was 5 to 15%) |
| Brunt | 4 to 10% |

| Event | Band |
| :--- | :--- |
| Bounces per bounced launch | A mean of 1.3 to 2.2 |
| Flights off a lip | 0.3 to 1.5 a minute once craters have rims. They rise through the match, because craters accumulate |
| Journeys with a tumble that is seen (at least 18 ticks; §23) | 30 to 60% of ground journeys |
| Early recoveries | 20 to 40% of the chances, at medium AI |

### What keeps it from looking silly at low power

- **Physics does most of it.** Tier-1 launches are slower, so they rarely reach bounce speed or clear a lip.
- **The bounce cap** is 1 at tier 1.
- **Bounces lose height fast** (45%, 35%, 25%), so he never trampolines.
- **Every contact has weight:** a mark on the ground, dust or debris, a hit-stop, and shake scaled by speed.
- **A tumble is short** (1.2 s at most) and ends in a hard stop, not a long floppy roll. Animation keeps the body braced, not limp.
- **Nothing happens under a speed of 350:** he lands.

### Answers to World's plan (`docs/world/ground-contact.md`)

World's plan is accepted, including these points: contact angles are measured against the surface and not the horizontal; the tumble is a mode of the skid; and the leave test keeps its small tolerance (`LEAVE_CLEAR`, about 1.5 units).

| World's question | Ruling |
| :--- | :--- |
| **A trench dug in paving** | It becomes **soil** for braking. Broken ground stops a skid sooner (×1.3), so streets get slower as they are wrecked, and the cracks show why |
| **The rim** | The slope limit of **0.6** is confirmed, so a rim is always a ramp and never trips the 0.8 wall-stop. Inside that limit, **make the lip wider and taller** so it reads: lip width 0.5 R (today 0.3 R) and a crest of up to 0.5 of the depth, as long as the inner slope stays at 0.6 or less and the rim and apron hold no more than the bowl's volume. If that can't hold, fall back to World's cap of 0.33 of the depth. Rendering may strengthen the rim's shading, but never its shape |
| **Heaps** | A slope of at most **0.6** is confirmed, with the wider spill |
| **The highlands** | Flank slopes of 0.35 to 0.6, never steeper, with a crest tight enough to launch a fast skid |
| **Spin** | World's formula at a bounce is accepted. It halves every 0.5 s in the air. It is capped at 3 turns a second, or 1.5 at tier 1, so he never pinwheels |
| **The tumble's look** | No trench. One scuff and one dust puff per contact with the ground, at most 3 a second. He rolls about once per 2.5 bh travelled |
| **How wear splits** | The journey's budget is the single-impact wear at its first contact speed. A slam pays all of it at once. Otherwise the first contact pays **30%** at touch-down, whatever its kind, and the other **70%** is paid in proportion to the speed each contact or stretch of braking removes. A flight off a lip pays nothing. If the journey ends early (an early recovery, or a catch in the air), the unpaid part is forgiven |
| **The leave direction** | **Normalised,** World's default. At a speed of 2,000 off a 0.6 ramp he rises about 9 bh, which reads well. The raw tangent would throw him hundreds of bh up. If playtests find the leave too flat, a "lip lift" factor of at most 2 on the vertical rate is the lever, as data |
| **Tier and personality** | By tier only: the bounce count (1, 2, 3, 3). The physics is the same for every fighter. Personality stays in where launches are aimed |

**Two consequences to expect.**
- Today's slow slide, from a speed of 350 down to 60, becomes a tumble. Slides at low power get shorter, with fewer and shorter trenches. That is intended: it is the "rolls to a hard stop" look.
- For the landing classes, a first contact that is a skid or a tumble counts as a **slide**, and a slam is a first contact that makes a crater. This replaces the 2 bh distance test in §18.


### The landing ruling after World's build (2026-10-02)

**What World measured** with the ground-contact model on, by first contact (`docs/world/ground-contact.md` §8 and §9): skid and tumble 24%, bounce 36%, slam 21%, caught in the air 16%, water 3%. The 30 to 70 degree landings that the old model called slides are now bounces. This was measured before Encounter's landing slice (`93d5e0d`), which makes the drive shallower and should move it toward skids.

**The ruling does both things, lightly.** Orb's two wishes are that landings are weighted toward skidding to a halt, and that fighters visibly skid, tumble and bounce over the course of a fight. A bounce that ends in a skid serves both.

1. **The bounce boundary moves to 40 degrees.** A contact under 40 degrees skids, and 40 to 70 bounces. With the drive at 25 to 50 degrees by altitude (§19), a low drive now skids at once and only a high one bounces.
2. **Launches are classed by how the journey ends,** not by its first contact. A journey that bounces and then skids or tumbles to a halt counts toward the skidding majority.

| The journey ends | Band (share of all launches) |
| :--- | :--- |
| **Skidding or tumbling to a halt,** with or without bounces first | **55 to 75%** |
| In a slam (a crater) | 8 to 18% |
| Caught in the air | 10 to 25% |
| In water | 2 to 10% |
| In a brunt | 4 to 10% |

3. **Bounces are an event rate.**

| Event | Band |
| :--- | :--- |
| Launches with at least one bounce | **15 to 30%** of launches. Orb wants to see them, but not on most landings |
| Bounces per bounced journey | A mean of 1.3 to 2.2, unchanged (World measured 1.5) |
| First contacts | Skids are at least as common as bounces |
| Journeys ending in a tumble, flights off a lip, early recoveries | Unchanged from the tables above |

**What World re-measures on top of `93d5e0d`:**
- the five ending classes;
- the share of launches with a bounce, at boundaries of 30, 40 and 45 degrees. 40 is the default. Take 45 if 40 leaves bounced launches over 30%;
- bounces per bounced journey;
- journey time and distance (mean and 90th percentile), and how often the 4 s or 8-contact bound is hit;
- flights off a lip per minute;
- the wear paid per journey against the single-impact budget, and the collateral per journey;
- how often the journey carries him off screen, for Camera.

### Second landing ruling, after World's re-measure (2026-10-02)

World re-measured on Encounter's landing slice at the 40 degree boundary (`docs/world/ground-contact.md` §10). The bounce share now passes (27.9%). Four rows needed a ruling.

1. **Wall stops are their own class.** A launch that ends embedded in a slope steeper than 0.8 is what MOUNTAINSIDE is for, and it reads differently from a skid to a halt. It is 17% today. It will fall when the highland flanks soften to 0.6 (the answers table above), so its band is 5 to 15%.
2. **Slams are Encounter's to bring down; the caught band widens.**
   - *Slam* is 25% against 8 to 18%, and the band stays. The lever is the planner's mix: give UPPERCUT more forward carry so its fall lands under 70 degrees, and hold CRATER SLAM to its gates (§19).
   - *Caught in the air* is 27% against 10 to 25%. Orb wants the ping-pong rally, so the band becomes 15 to 30%.
3. **Bounces per bounced journey:** the band's floor drops to 1.2, so 1.28 passes. The vertical keep stays at 45%, 35% and 25%. Higher arcs would lengthen journeys that already leave the frame one time in six.
4. **Flights off the terrain:** the band widens, because Orb asked for them. It counts only flights that are seen, which means at least 10 ticks in the air.

**The ending classes now** (this replaces the table in the first landing ruling):

| The journey ends | Measured | Band (share of all launches) |
| :--- | ---: | :--- |
| **Skidding or tumbling to a halt,** with or without bounces first | 29% | **40 to 60%, and the largest class.** Among journeys that end on the ground (halt, wall or slam) it is at least 55% |
| Against a wall (a slope steeper than 0.8) | 17% | 5 to 15% |
| In a slam | 25% | 8 to 18% |
| Caught in the air | 27% | 15 to 30% |
| In water | 3% | 2 to 10% |
| In a brunt | Not in World's run | 4 to 10% |

| Event | Measured | Band |
| :--- | ---: | :--- |
| Launches with at least one bounce | 27.9% | 15 to 30% (20 to 40% since §23) |
| Bounces per bounced journey | 1.28 | 1.2 to 2.0 |
| Flights off a crater's lip, seen | 1.75 a minute | 0.5 to 2.5 a minute |
| Flights off any terrain (lips, crests, cliffs and heaps), seen | 4.7 a minute | 1.5 to 5 a minute |
| Journeys that reach the 4 s or 8-contact bound | 5.1% | At most 8% |
| Ground journeys longer than 4,000 units, **measured from the first ground contact to the stop** (World's measure) | About 17% | At most 20%. Camera's chase rule covers them. This is not the whole launch: from the launch tick, flight included, Camera measures 38 to 57% over 4,000 units, and long launches are wanted (§10: at least 30% travel 9,000 units) |

**One check for World and Simulation.** The mean wear per journey is 0.32 of the single-impact budget. A journey that skids to a halt should pay 80 to 100% of it, because all its speed is lost on the ground. If halted journeys pay much less, the split needs a look. Either way the impact wear per launch has changed, so QA re-tunes k after the model lands.

### Clarifications after World switched ground contact on (2026-10-02)

World's numbers with the model on in the tree are in `docs/world/ground-contact.md` §14. Three points are settled here.

1. **"Halted" does not include wall stops.** The two are separate classes, so the number World should hit is the one without walls.

| Class | Measured | Band |
| :--- | ---: | :--- |
| Halted (a skid or tumble to a stop) | 30.2% | 40 to 60% |
| Halted as a share of ground endings (halt, wall and slam) | 42.2% | At least 55% |
| Wall | 13.7% | 5 to 15%: passes |

   Halted is still short. The gap is the slam share, which is the next point.
2. **Slams at 25.4% still wait for Encounter's UPPERCUT lever** (more forward carry, so the fall lands under 70 degrees), with CRATER SLAM held to its gates. That is still the plan, and the 8 to 18% band stays. Those launches should move into halts and bounces.
3. **A journey's wear is capped at 1.0 of the single-impact budget,** as a hard test. World measured a mean of 0.91, which is right, but 22% of journeys went over, with slams at 1.1. A slam pays the whole budget at once, so its hop must cost nothing more.
4. **The same cap holds for collateral.** A journey's area damage to structures and people stays within what its first impact would have done alone: each later contact's damage scales with the speed that contact removes. Later contacts were levelling structures, which took structures lost from 47 to 82 of 196. The planner still declines a journey whose prediction goes over the tier's budget.

World tunes to these before any push, and match length should come back to within about 3% of the model-off length. If it doesn't, QA re-tunes k.

## 21. Rulings after the Q10 retune (QA's `docs/qa/retune-q10.md`, 2026-10-02)

QA's recommended data set is accepted: k 0.052, the mood and location values, and the two placeholder `dmgMul` values. It gives matches of 7:36, KAI at 48.5%, and 73 bands passing. Five fail, and three items were deferred from Encounter's 2a.

### Collateral at the KO: re-band the totals, and fix the top tiers in code

**What happened.** Civilians lost fell to 16.3% and front-row structures to 27.8%. The slower ladder is Orb's choice, and it leaves about 2:20 at tier 4 where there used to be 4:30. No data lever reached the old bands without spending the hero's avoidance or the length band.

**The ruling has two halves.**

1. **The totals are re-based,** because they follow from the time spent at each tier. The old numbers were set when tier 4 came at 2:00.

| Measure | Old band | New band |
| :--- | :--- | :--- |
| Civilians lost at the KO, mean | 25 to 50% | **12 to 30%** |
| Worst pairing's mean | At most 70% | At most 55% |
| Front-row structures lost at the KO, mean | 40 to 75% | **25 to 50%** |
| All rows (a watch metric) | 25 to 60% | 15 to 40% |

2. **The per-tier rates are not re-based.** They are the pillar-4 test: damage escalates with tier. After 2a, structures levelled per minute were 1.2 to 3.0% at tier 3 and 3.4% at tier 4, against bands of 3 to 10% and 6 to 20% (§15). The top tiers are too gentle, and no data lever moves them, because the fight is rarely inside a town. **World adds a code-side lever: high-tier impacts reach further.**
   - The area in which impacts, power-ups, clashes and blasts damage **structures** grows by tier: ×1.0 at tiers 1 and 2, **×1.6 at tier 3** and **×2.8 at tier 4**. The factors are data, and they scale the whole blast, falloff included: scaling only the outer radius barely moved the rates.
   - *Measured by World* over 40 matches (`docs/world/structure-reach.md`): ×1.6 puts tier 3's front row at 3.90% a minute. ×2.4 left tier 4 at 5.83%, just under its band, so the EP set the start at ×2.8, which is about 6.5% a minute and about 43% of the front row at the KO. QA tunes the tier-4 factor.
   - An optional per-event cap in the extended ring exists as data and is off by default.
   - Casualties are unchanged. They stay under the collateral window and its ramp (§4b), and by tier 3 most of a threatened district has already fled.
   - Tiers 1 and 2 are untouched, so the low-tier rules hold: at most 2% and 4% a minute, and no more than 10% lost before tier 3.

**Against the pillars.**
- *Power has weight, and it escalates:* a tier-4 fight near a town now wrecks its edge without needing to be inside it.
- *No fight destroys the planet at low tiers:* nothing changes below tier 3.
- *The hero is pressured by collateral:* he keeps his lure. At tier 4 leading the fight away is no longer enough by itself to save a town's edge, which is the pressure the pillar asks for.

**Expected result:** with the tier rates in band, front-row structures at the KO land at about 43% (World's measurement at ×1.6 and ×2.8). QA re-measures, and the new totals above are the gate.

### The other failing rows

| Row | Measured | Ruling |
| :--- | :--- | :--- |
| Water landings | 3.0% against 5 to 15% | **Re-based to 2 to 10%.** The 13% behind the old band came from the event-order misread that QA has now fixed. It rises again with World's ocean-and-islands layout, and is revisited then |
| MERIDIAN SCAR | 2.3% against a 3% floor, in one run | **The floor is 2% on a single planet,** and stays 3% pooled over the set of 20 planets, where §6 says it should be measured |
| Lock breaks | Still under band | Unchanged: it waits for living destruction (§14) |

### The three items deferred from 2a

| Item | Ruling |
| :--- | :--- |
| Structures per minute under band at tiers 3 and 4 | Covered above by World's reach lever. The bands stay |
| Matches at 8:31 | Resolved by the retune (7:36) |
| A light masher beats the AI 100 times in 100 | **The bands stand** (`control-rules.md` §6): at least 60% against the easy AI, 35 to 50% against medium and at most 15% against the perfect-block script. The fix is Encounter's. The AI must use the new defences at its difficulty: guard a repeated string, perfect-block enders at the R5 rates, punish a fully blocked string, and throw a fighter who only guards. The staleness rule (+2 ticks of wind-up per repeat) must also be in. QA then re-tests each difficulty |

### Still to come

Encounter's 2b, the landing slice and the contact slice are built but not committed, and KAI reads 57 to 59% in the contact probe on the un-retuned base. QA re-centres with the placeholder `dmgMul` values after those land. No band moves for it.

## 22. Rulings on the step-3 baseline (QA's `docs/qa/baseline-step3.md`, 2026-10-02)

KAI is at 52.6% and the median is 7:10, with 72 bands passing and 14 failing. Perfect blocks per 100 exchanges are 5.9, 10.0 and 15.2 for the easy, medium and hard AI, all inside their bands.

| Row | Measured | Ruling |
| :--- | :--- | :--- |
| **Limb breaks** | 0.62 a match against 0.3 to 0.5, with arms only 21.7% of them against 35 to 65% | **The bands stay; the data moves.** Step 3 made guarding real, so the legs now take more guard wear, and the leg weighting that was added to lift legs is now pushing the wrong way. In order: `cripple.legWeight` from 1.8 back to **1.0**; then `guardWearSplit` back to 0.5 / 0.5 if arms are still under 35%; then scale `cripple.base` down by about a fifth, to bring the rate to about 0.45. QA's wound-spread retune can replace these if it reaches both bands |
| **Exchanges started** | 24.6 a minute against 15 to 24 | **The band widens to 15 to 26.** Perfect blocks and bursts end exchanges sooner, which is the agency Orb asked for. Encounter does not slow it. The other feel bands in §10 still have to pass |
| **Speed lines** | Heavies land 12.3 a minute and launches 11.8, so the streak would ride on about 25 hits a minute | **A cap: one streak per exchange,** on its launch if it has one, otherwise on its last landed heavy, and never on a hit that gets a panel. That is about 17 a minute. The panel rule is unchanged |
| **Frenzied mood** | 3.7%, and 8.1% of act 4 | No ruling. It waits for the form impulse in Simulation's next slice |
| **The masher** | QA reads 0 of 40 against the medium AI, and Encounter reads 41% | The band of 35 to 50% stands while the two probes are reconciled |

## 23. Rulings on the contact baseline (QA's `docs/qa/baseline-contact.md` on `bc857b4`, 2026-10-02)

### The light masher against the medium AI

**Measured:** a masher who takes forms wins 60% (24 of 40) against the medium AI, against a band of 35 to 50%. It was 41 to 48% before ground contact. Against the easy AI it wins 100%, and against the hard AI 5%, which both pass.

**The band stays.** It is the measure of "fine for beginners, beatable by experts": the default opponent shouldn't lose to mashing more often than not. The sample is 40 matches, so QA first repeats it at 200.

**Find the cause before pulling a lever.** QA runs the masher with ground contact off, and with it on, and counts the masher's ping-pongs and air catches per match. The suspect is the follow-up after a launch: a masher who holds toward presses during every launch flight, so he starts a ping-pong every time without meaning to.

**The levers, in order:**

| # | Lever | Owner | When |
| ---: | :--- | :--- | :--- |
| 1 | **A ping-pong needs a fresh press.** It doesn't start if the attacker pressed attack in the 20 ticks before the launch connected. This is the same lockout the perfect block and the clash pulses use, and a masher pressing every 8 ticks never passes it | Encounter (a rule in `control-rules.md` §11) | If the masher's ping-pongs are the cause |
| 2 | **The medium AI uses its outs.** It recovers early on 50% of chances (§20), and it bursts or perfect-blocks a ping-pong's return blow at its difficulty's rates | Encounter (AI) | If the AI is being juggled without answering |
| 3 | The placeholder `dmgMul` pair | QA | Only to re-centre KAI afterwards. It is not a fix for the masher |

**A masher who never transforms** wins 75% against the easy AI and 7.5% against the medium AI. The bands are for a masher who takes forms. The easy band (at least 60%) also applies to the masher without forms, and passes. There is no band for him against the medium or hard AI: a player who never transforms fights at tier 1, and losing there is fair.

### Tumbles and bounces

**Measured:** 2.5% of journeys end in a tumble, against 30 to 60%, and 35.6% of launches have a bounce, against 15 to 30%. Halted (45.1%), slam (17.0%), caught in the air (19.8%) and bounces per bounced journey (1.32) all pass, and skids are the commonest first contact.

**The tumble band was measuring the wrong thing, and the tumble itself is too short to see.**
- `journey_end` says `tumble` only when a journey is cut off mid-roll. A tumble that rolls to a stop ends as `stop`, so it wasn't counted.
- With double braking a tumble lasts 0.13 to 0.3 s (World's note). Orb wants to see fighters tumble, and nobody can see that.

**The rulings:**
1. **A tumble rolls further.** Its braking is **×0.7 of the skid's**, where it was ×2. A rolling body loses speed more slowly than a sliding one, so this is also the truer physics. It gives a roll of about 0.5 s over 2 to 4 bh. The 1.2 s cap stays, and so does the hard stop at the end.
2. **The band is "journeys with a tumble that is seen".** A journey counts when it has a `tumble_end` whose roll lasted at least **18 ticks**. World adds the roll's length in ticks to `tumble_end` as `dur`. The share is taken over journeys that travel along the ground, which are those whose `journey_end` is `stop`, `tumble`, `recover` or `capped`.
   - **Band: 30 to 60%** of those journeys.
3. **The bounce band widens to 20 to 40%** of launches. Orb asked to see bounces, and every class around it passes with bounces at 35.6%: skids are still the majority and the commonest first contact.

**What QA and World act on:**
- World: `tumble.brakeMul` 0.7, and `dur` on `tumble_end`.
- QA: the tumble row reads `tumble_end.dur` of 18 or more, over ground journeys; the bounce row's band is 20 to 40%.
- QA re-checks journey length after the change. A longer tumble lengthens journeys a little: the bounds of at most 8% capped and at most 20% over 4,000 units still apply.
