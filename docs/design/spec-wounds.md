# Spec: Wounds (damage model, Variant A)

Owner: Game Design. Status: spec for P2 and P3, the input for Combat and Encounter Systems. **Scope: 1v1.** 2v2 rules are deferred (Orb). Date: 2026-09-29.

**Sources.**
- `damage-model.md`: the rationale behind this spec.
- `pitches.md`: the options Orb picked from.
- Orb's rulings in `docs/ep/vision.md`.
- Narrative's round 2 in `docs/narrative/pitches-q3.md`.

Numbers are **starting values**, which QA tunes against `balance-targets.md` (§2, §8, §10). Mechanics survive a re-skin; names are working names.

## 1. Core rules

> **Questionnaire 5** (`balance-targets.md` §13) changes several rules below. The brink is now the **core broken**, and limbs break only in a crippling moment (interim, pitch A). Trailing-fighter help applies. Each completed transformation starts a 15 s surge. At 11:00 a time-cap story event takes over. Where §13 and this spec differ, §13 wins until this spec is rewritten.

| Rule | Spec |
| :--- | :--- |
| **Regions** | Head, core, arms and legs, for every fighter. The Empress (formerly the Tyrant) adds a fifth, the **bladed mantle**, which never counts toward the brink |
| **Wear** | 0 to 100 per region, stored as fixed-point. A hit adds `wear = damage × k` to the region the director picks. `damage` is today's `hit()` value with all its multipliers (`index.html:L319-338`). k = **0.045** after the brink-chapter slice (§1b). History: 0.06 at S2, 0.065 at S3b, 0.06 by the S4 ruling, 0.034 after the dynamic slice, 0.038 as the interim value with the stricter brink, and 0.041 at D1b. It is set by the length target. QA tunes it within 0.05 to 0.07 (§1b) |
| **Stages** | Fresh below 30; bruised 30 to 59; battered 60 to 89; broken at 90 or more |
| **Stage penalties** | *Head:* battered narrows the parry window by 20% and adds a 0.2 s stagger after heavies; broken dazes for 0.4 s after each exchange lost and gives −0.08 on defence rolls. *Core:* battered cuts ki regen by 30%; broken puts the fighter on the brink, and his transformation fills stop filling (§8). *Arms:* battered raises the DEFENSIVE multiplier from 0.38 to 0.55; broken cuts heavies and signatures to ×0.8 and removes BRACE. *Legs:* battered sets speed ×0.85 and −0.10 on the ESCAPE slip chance; broken removes the dash and doubles the time needed to break lock through line of sight (1.8 s) |
| **Recovery** | Out of exchanges, a region below 60 fades 1 wear per second (0.25 from S2, §1b). A battered region fades 1 per second, down to 59, after 4 s without an exchange ("second breath", §1c). Broken regions never fade (only a Rally mends them). Hidden recovery is removed with hiding |
| **Region choice** | Each atom lists the regions it may hit, with weights. The director multiplies each weight by (1 + wear/50), or (1 + wear/30) from S2 (§1b), which is "go for the wound", then draws with the seeded sim RNG. Attack kind sets the family: lights go to the head and arms, heavies to the core and legs, guard hits to the arms, and beams and impacts spread |
| **Brink** | The core breaks, or any two of head, arms and legs break. The Cyborg is the exception (§3) |
| **Decisive exchange** | One that ends with the loser launched, a heavy or beam clash won, or a GUARD BREAK. A launch counts however it lands: slam, knockback slide, water skip, brunt or chain (`docs/world/knockback-slide.md`). A **NONE** outcome (a shove with no launch after a winning template) is **not** decisive, unless the exchange also meets one of the other clauses. An attack that stops a fill (charging, stoking, Press) is a CHARGE INTERRUPT and launches, so it counts. Transformation cinematics themselves are never interrupted (§8) |
| **Finisher** | When the opponent of a fighter on the brink wins a decisive exchange **while that fighter is open** (the set-up rule, §1b "The brink chapter"), their **fighter-specific finisher** replaces the normal ending. The exchange that causes the brink never starts one. The fighter on the brink survives it on a contest roll: 30% base, −10 points for each Rally that fighter has used, and −10 points per minute past 8:00, with a floor of 0. **The last-ditch struggle is resolved by state** (questionnaire 4: no timing presses). It stays a visible beat: three pulses that reveal the outcome step by step, "holding" or "slipping". Survival is **23% base** (15% before the D1b ruling, §1b), plus a **stance read** against the finisher's telegraphed kind, where each fighter's finisher kind is shown in its wind-up: +15 for DEFENSIVE against a launch finisher, EVASIVE against a melee finisher, or AGGRESSIVE with 40 ki or more against a beam finisher (a counter-clash); +5 for any other stance. Then +5 at 50 ki or more, plus the fighter's own state: the Protagonist +5 at Simmering or +10 at Boiling; Pride at 50 or more for the Anti-hero +10; any guard standing for the Empress +5; the hatch closed for the Cyborg +10. Then the tilts: −10 per Rally, and −10 per minute past 8:00. QA band: average survival 25 to 40% |
| **The end** | A KO happens only through a finisher. Stray damage never ends a match |
| **Breaks are chapters** | A break is a 1 to 2 s set piece: a camera break shot, a bark, then a **break launch**. The break launch is long (at least 1,500 units horizontally) and chosen by the planner's distance and new-biome terms (`balance-targets.md` §10) |

### 1b. Tuning note for Encounter (KO by finisher, S2)

**What QA's S1 baseline shows** (`docs/qa/baseline-g0.md`). With k = 0.08, HP still ends matches at about 108 s and no region ever breaks. The probe found 61 fresh, 76 bruised and 1 battered, and damage spread evenly: arms 31%, head 26%, legs 22%, core 21%.
- *The cause.* Wear comes in at about 0.3 per second per region: 1,600 damage in about 108 s, times 0.08, over four regions. Bruised wear fades at up to 0.5 per second: 1 per second, out of exchanges about half the time. So regions plateau below battered.
- *The fix.* Longer matches alone won't help. The numbers must change.

**Starting values for S2** (they replace the §1 values above):
- k = **0.20** as proposed; S2 measured **0.06** instead (see "S2 result" below);
- bruised fade **0.25** per second (battered regions recover only through second breath, §1c);
- the director's focus weight is **(1 + wear/30)**, so damage concentrates and regions break.

The arithmetic: the most-worn region nets about 0.6 to 0.9 wear per second. That gives a first break at around 1:30 to 2:30, and a brink at around 4:30 to 7:00 once Rallies and the finisher contest are added.

**Order of levers**, one at a time. Re-measure after each:
1. **k.** Set by match length: a median of 6:00 to 8:00, and the first brink at 4:30 to 7:00. The first-break band follows from it (§5, test 3) (§5, test 3).
2. **Recovery rates.** If regions stall at bruised, lower the fade before raising k again.
3. **The focus weight.** If breaks are rare but wear is high, sharpen it. The §5 spread test (no region above 45% of all wear) is the limit.
4. **Stage penalties.** They make a losing fighter lose faster. Tune them last, for feel, because they shorten the tail.
5. **The finisher contest** (30% base survival). It sets the tail after the brink: p90 at most 10:00, p99 at most 12:00.

**Sequencing.** The world rescale lands first, and it changes travel time and so the exchange rate. Re-baseline the damage rate after the rescale, before touching k. Measure time to first break and time to brink, not only match length.

**After the spaced profile** (`docs/combat/s3b-loader-note.md`): exchanges lengthen to about 2.5 to 2.9 s, which slows wear. QA re-tunes k (up, within 0.06 to 0.09) against the same length targets once Encounter switches profiles.

**S2 result and rulings** (commit `69c4a2f`, `docs/director/wounds-s2.md`).
- *The result:* median 6:01, p90 8:15, first brink 5:51, no timeouts, finisher-contest survival 28%.
- *My estimate was wrong.* The §1b arithmetic assumed a slower exchange rate. At 0.20, matches lasted 90 s.
- *Ruling 1: k = 0.06 is confirmed as the value tuned to length.* The targets QA tunes toward are a median of 6:00 to 8:00 and a first brink at 4:30 to 7:00. After Rally lands (S4), which adds time, re-tune within 0.05 to 0.07 to keep the median near 6:30 to 7:00.
- *Ruling 2: the comeback term is accepted.* The damage bonus reads **closeness to the brink**, `vitality`: 1 minus the higher of core wear or the second-most-worn limb, over the broken threshold. The bonus is `×(1 + 0.5·(1 − vitality)²)`. It peaks at ×1.5 on the brink, which is the "desperation" of `damage-model.md` §5. The AI's reads of wounds use the same value.
- *Ruling 3: the chapter bands move.* Breaks aren't the only chapters. Transformations, break launches, set pieces and the landscape carry chapters too.
  - First break: a median of 2:30 to 4:00 (today 3:45).
  - Breaks per 1v1: 2 to 4 before Rally, and 3 to 5 once Rally lands (today 2). *Retired by the core-only brink; the band is now 1.5 to 2.5 (`balance-targets.md` §8).*
  - *If the chapters feel thin* after S4, the experiment is a stricter brink: core, or **three** limbs broken, with k × 1.4. That gives an earlier first break and more breaks at the same length. QA runs it; Game Design decides.
- *Collateral.* Six-minute matches raise collateral: 51% overall, and the villain mirror about 92%, which is over the worst-pairing and 90%-loss bands. World's ramp and cap land with B1 (`balance-targets.md` §4b) and are expected to bring both back into band.

**Final k after the dynamic slice** (QA; the damage rate rose from 905 to 1,693 a minute).
- **k = 0.034:** median 6:51, p10 5:05, p90 9:00, timeouts 0.3%, KAI 47.9%, civilians 30%. Every length, balance and collateral band passes.
- *Rallies* at 0.27 a match are inside the contest-gated band (0.2 to 0.5, §2).
- *Breaks* at 2.6 a match are under the 3-to-5 band, and k cannot fix that. The separate lever is the **stricter brink** from the S2 ruling: the core broken, or **three** limbs broken. Then re-tune k upward (starting around 0.045) to hold the median.
- *Accept it* if breaks reach 3 to 5 with the length and timeout bands intact, and a playtest check finds a fighter with two broken limbs still fun to play. Otherwise keep the two-limb brink and re-base breaks to 2 to 4.

**The stricter brink, measured** (core, or three limbs broken; QA, 800 matches per k).
- *Breaks* are 3.6 a match at every k, so the band is met and the stricter brink is adopted, pending Orb's playtest of a fighter with two broken limbs.
- *The spread* is wide: p10 is about 0.65 of the median and p90 about 1.3. So k alone can't land both tails.
- *Ruling, conditional on QA's 0.037 run:* if 0.037 gives p10 of 4:45 or more and timeouts of 1% or less, it is the interim k. Then narrow the spread with two levers, rather than leaning on k:
  1. **act-1 wear damping:** wear ×0.85 while the act index is 1, which slows the fastest brinks and lifts p10;
  2. **the overtime ramp** (the S4 ruling), tuned to pull in p90.
  The target stays p10 at least 5:00 after those levers.
- *KAI at about 43%* is acceptable for the placeholder testbed (the floor there is 42%, `balance-targets.md` §9), but not for the roster, which must sit at 45 to 55%. It is re-checked after the spread levers.
- *Result:* k 0.037 missed on timeouts (1.6%). **k 0.038 is the interim value** with the stricter brink: p10 4:47, timeouts 0.4%, median 7:22, KAI 42.9%.
- *Next slice* (Simulation, after D1a): act-1 damping ×0.85, plus the overtime ramp. QA tests two ramp candidates:
  - **A:** starts at **8:00**; k × (1 + 0.25 × minutes past 8:00);
  - **B:** starts at **8:30**; k × (1 + 0.40 × minutes past 8:30).
  Both are linear and capped at ×3.
- *Pick* the candidate that gives timeouts of 1% or less and p90 of 10:00 or less, with the median unmoved. The p10 target (5:00 or more) comes from the damping.

- **D1b result and rulings** (QA, 3,200 matches, 2026-09-30).
  - *Passes:* KAI 45.5% (43.6% as P1, 47.4% as P2), length, and region breaks at 1.69.
  - *Misses:* the first brink at 7:24; arms at 68% of limb breaks; Rallies at 0.23.
  - **k = 0.041 is confirmed.** It brings the first brink to 6:37 and holds length (median 6:47, p10 5:07, p90 8:23), with KAI and breaks unchanged.
  - **The post-brink phase must be longer.** With the first brink at 6:37 and the median end at 6:47, the brink is over almost as soon as it starts. The brink is the climax: the call-out, finisher attempts, struggles, Rallies and comebacks all live there. New band: **a median of 45 to 90 s from a fighter's first brink to the KO.**
  - **The Rally lever is finisher survival.** The struggle's base survival rises from 15% to **23%**, and the average-survival band moves from 20 to 35% to **25 to 40%**. It is symmetric, and it lengthens the post-brink phase with the same change. A lower Spite threshold was not picked, because it helps one side only and risks the KAI result. The tilts stay (−10 per Rally, −10 per minute past 8:00), so the tail stays bounded. If Rallies are still under 0.3 or the post-brink median is under 45 s, the next step is a base of 27%, with the average capped at 40%. The S4 ruling found 40 to 50% indecisive.
  - **Arm skew:** the ×1.5 leg weighting is applied (`balance-targets.md` §13).

- **The brink chapter** (balance slice `6be4c3a`; a 100-match probe). Brink to KO had a median of 4 s, because the exchange that breaks the core is usually decisive and starts the finisher at once. **The ruling is the set-up rule,** which includes "no finisher from the exchange that caused the brink". Encounter gates it in the director.
  1. **The exchange that causes the brink never starts a finisher.** It ends on the brink call-out.
  2. **The set-up.** The rival must first win one decisive exchange against the fighter on the brink. That **opens** them: a visible stagger and a dropped guard. The rival's finisher kind shows in its wind-up, so the fighter on the brink can pick the stance that reads it.
  3. **The finisher** starts on the next decisive exchange the rival wins while the opening holds.
  4. **The opening closes** when the fighter on the brink wins a decisive exchange (the same moment that fires Spite), survives a finisher, or Rallies. The rival then needs a new set-up.
  5. **The time-cap event** (11:00) overrides this rule: every decisive exchange there is a finisher.
  6. **Data:** `brinkSetups` = 1, the number of set-up wins needed.
     - If brink to KO is still under a median of 45 s, set it to 2.
     - If it goes over 90 s, lower the struggle's base survival back toward 19%.
     - If the match median passes 7:30, raise k (up to 0.045) so the first brink comes earlier. The first-brink band of 4:30 to 7:00 holds.
  - *Why this option:* it turns the brink into two readable steps, the opening and then the finisher. The fighter on the brink gets a real turn: a stance read, Spite, the Encore, a Reboot or a last stoke. A timed grace period would be dead air, and removing only the brink-causing finisher would add a single exchange.
- **Arm skew, second step** (arms at 70%, because legs are rarely battered at exchange start): **`guardWearSplit` 0.5 / 0.5**, keeping the ×1.5 leg weighting. If arms are still over 65%, try 0.4 / 0.6, where the braced guard sinks into the stance.
- **Values in force** (QA; every band hit at once, using the authorised fallbacks; Simulation applies them):
  - **k = 0.045**;
  - `brinkSetups` = **2**;
  - `guardWearSplit` **0.4 / 0.6** (arms / legs), keeping the ×1.5 leg weighting;
  - crippling moment: **base 0.048**, with tierAhead, lateBonus and the DEFENSIVE modifier at **±0.03** each. It was scaled down because the wider leg split raised limb breaks;
  - the struggle's base survival stays at 23%.

  *Measured:* brink to KO 48 s; median 6:56; first brink 5:52; Rallies 0.37; survival 35%; limb breaks 0.47 a match (57% arms, 43% legs); KAI 50%. Brink to KO sits near the bottom of its 45 to 90 s band, so any change that speeds up decisive exchanges needs a re-check of it.
  *Tails* (QA, 800 matches): p10 5:07, p90 9:05, timeouts 0.3%. In the four-arm run only the villain mirror misses, with p10 at 4:55. **Signed off at k 0.045.** The miss is 5 s on one placeholder arm, driven by menace damage, and the roster replaces those meters. Re-check it on the roster; k 0.044 is the known fix (about +10 s on p10).

### 1c. Lock-on and line of sight (hiding is removed)

Orb removed hiding from the base game and kept it for a future stealth-specialist fighter (`docs/ep/vision.md`; `future-stealth-fighter.md` holds the kit as it was). What remains is **line of sight**: smoke, dust, rubble and terrain can break lock-on for a moment. There is no recovery bonus, no ambush and no concealment on screen.

| Rule | Spec |
| :--- | :--- |
| **Breaking lock** | A fighter in the **ESCAPE** stance breaks the opponent's lock after 0.9 s without line of sight between them. Line of sight is blocked by: a cloud that can block (the target at least 30 units inside it); a rubble heap at least 1 bh high with the target low behind it; unburnt forest canopy with the target low beneath it; or terrain (a heightfield line test, such as a ridge between them). Other stances never break lock, because they are engaging. |
| **While lock is lost** | The opponent cannot start an exchange on that fighter. An attempt costs 2 ki and a 0.5 s cooldown, as today. The fighter's side shows the Searching flash. |
| **Regaining lock** | Lock comes back, with the Found flash, when **any** of these happens: line of sight returns; the hunter comes within 240 units (120 inside a cloud); the target attacks; or **4 s** pass. Lock loss never lasts more than 4 s. |
| **No chaining** | After lock is regained, the same fighter cannot break it again for **6 s**. |
| **What it is for** | Breathing room and repositioning, never healing. ESCAPE stays a gamble (pillar 3): the pursuit and beam-escape odds are unchanged, it still takes ×1.25 damage, and a chaser who closes the distance, or waits out the 4 s, gets the lock back. |
| **Flashes** | Found and Searching stay. Primed, the ambush window, is held for the future fighter. Art: please drop Primed from the base set. |

**Recovery without hiding.** This replaces the old hidden fade (battered fading 3 per second while hidden). Without a replacement, battered regions would stay battered for the rest of a 6-to-8-minute fight, and comebacks would come only from Rally.
- **Second breath.** After **4 s** with no exchange involving that fighter, a battered region fades 1 wear per second, down to 59, where it becomes bruised.
- It shows through the posture channel (a visible breath) and needs no UI.
- The opponent denies it simply by attacking, since every attack closes the gap. Breaking lock through ESCAPE, or a long break launch, is how a fighter earns it.
- Broken regions still mend only through Rally.
- *Tuning.* Second breath is weaker than the old hidden fade. If S2 matches run short, lower k first (§1b).

## 2. Rally (approved per fighter, with looser limits)

**Shared rule.** A Rally takes a fighter off the brink and mends one broken region to **battered**, at 89 wear, one good hit from breaking again.

| Fighter | Rally | Trigger while on the brink |
| :--- | :--- | :--- |
| Protagonist | **Second Wind** | Survive the rival's finisher contest roll. His next track step is then free |
| Anti-hero | **Spite** | Win a decisive exchange by hand (melee, no signature) with help refused. His arms mend first, and his next finisher must be by hand |
| Empress | **Encore** (Orb's pick) | Her three fallen guard return once, fresh, for a short, harder brawl (§3). She withdraws out of reach while a 15 s mend gauge fills, which it does only while a guard member stands. If the opponent beats all three first, there is no mend. The Encore lasts at most 16.5 s, once per match |
| Cyborg | **Reboot** | Dock the loose backup drive, or finish a Press within reach of civilians. It mends one chip stage, and regrowth doubles for 5 s |

**How a Rally triggers.** There is no Rally button. Each Rally fires automatically when its condition completes:
- Second Wind: on surviving the finisher contest.
- Spite: on a decisive exchange won by hand.
- Reboot: when the dock or the Press completes.

The one exception is the Empress's **Encore**, which is a choice to spend. The player calls it with an input inside 3 s of entering the brink (Controls maps it as a contextual prompt), and the AI decides for itself.

**Limits after Orb's "looser" ruling:**
- **Dropped:** the once-per-match cap and the final-act lock. Instead, each region can be rallied **once**, so a fighter has at most 4 Rallies. The Empress's Encore is stopped by beating all three guard members before the mend gauge fills (§3).
- **Softened:** the cooldown goes from 30 s to **15 s** after leaving the brink.
- **Kept:** the mended region returns battered.

**S4 rulings** (commit `c153c34`). Rally fires 0.24 times per match. The ceiling is contest survival (31 in 100 matches); the misses were 4 brinks too deep for one mend, 2 with every broken region already rallied, and 1 on cooldown.
1. **The deep-brink rule stays.** No Rally unless one mend takes the fighter off the brink. A fighter that far gone has earned the finisher, and it affected only 4 in 100 matches.
2. **The band moves; contest survival does not.** The 0.5 to 2.0 band predates the finisher-gated trigger. Raising survival to 40 to 50% would make finishers indecisive and lengthen a tail that already times out.
   - Contest-gated Rallies (Second Wind, and the placeholders): 0.2 to 0.5 per match.
   - The roster's other Rallies (Spite, Encore, Reboot) are not gated by the contest and add to that when they land. The combined roster band is 0.3 to 1.0 per match.
   - Struggle scoring is unchanged (base 15%, up to +30 from the struggle; average survival 20 to 35%).
   - The comeback band in `balance-targets.md` §8 (15 to 35% of matches) stays as the real test of "last-ditch".
3. **Timeouts (2%) and the short tail (p10 at 4:34).** Two levers, applied together:
   - lower k one step, from the live **0.065** (S3b, `WEAR_PER_DAMAGE` 390) to **0.06**, which raises p10 and the median;
   - add an **overtime ramp**: after 9:00, k rises by 25% per minute, and the contest tilt (−10 points per minute past 8:00) continues. The fight intensifies until it ends.
   - Targets: timeouts at most 1% at the 15:00 cap, p10 at least 5:00, median 6:00 to 8:00. QA verifies them.

**Why a finale still can't loop:**
1. Each Rally spends something finite: a region's one Rally, a refit, the drive or nearby civilians, the rival's finisher attempt, or refused help.
2. The mended region sits one hit from breaking again.
3. The finisher contest tilts 10 points against the fighter for every Rally and every minute past 8:00. The tilt lowers survival but need not reach 0: at today's base of 23% with the stance and state bonuses, a fighter can still survive after a third Rally. **Survival is 0 only in the time-cap event from 11:00,** which the sim enforces (M1b ruling).

## 3. Per-fighter damage, and how the readout shows it

Orb picked **the aura crown with wound cards, plus the silhouette, varied per fighter**:
- **The aura crown** has four arcs, one per region. An arc flickers when battered and gaps when broken.
- **Wound cards** are 1.5 s picture-in-picture callouts, such as `ARMS: BROKEN`.
- **The silhouette** is a small body figure with pattern and tint per stage. It is on by default in `training` and as the accessibility default.

| Fighter | How damage is handled | How the readout shows it |
| :--- | :--- | :--- |
| **Protagonist**: Rolls with it | 25% of each incoming hit's wear spreads evenly over his other regions. His power stage is the **heat track** (below): big temporary boosts paid for in internal core wear | *Crown:* all arcs thin together as wear spreads, rather than one gapping early, and the core arc shimmers with heat. *Cards:* heat stage changes, internal core stages, the boil-over, and `SECOND WIND`. The stage names are Narrative's. *Silhouette:* an even wash, with the core filling from inside as internal wear builds |
| **Anti-hero**: Proud front | While Pride is at half or above, battered penalties do not apply. When Pride falls below half, every withheld penalty lands at once. **Humbled** and **Drop the Act** turn Pride into power (below). Each shame stack also darkens a notch on his crown, and Drop the Act fires its own card together with `FACADE CRACKS` | *Crown and cards:* while Pride holds, his crown stays whole and battered cards are **withheld**. Only broken cards show, and body decals still show the damage. When Pride breaks, every withheld card fires at once as `FACADE CRACKS`, and the crown drops to its true state. *Silhouette:* shows only the hairline "front" until the crack. Opponents read his visible Pride meter to predict it |
| **Empress** (formerly the Tyrant): Refit, with the paperwork below | Only her real revisions (9 to 11) mend, one stage of her most-worn region each, shrinking each time. Her full-power form (12) mends nothing. Her joke revisions (1 to 8) mend nothing. The **bladed mantle** is region 5: breaking it removes her mantle attacks and slows her next revision. Her guard of honour are single-region bodies, taken out by one break | *Silhouette:* each registered revision **reprints** it with the new revision number and a patch mark on the mended region. *Crown:* a fifth arc runs along the mantle's hem. *Cards:* ordinary wound cards only, such as `MANTLE: TORN`. There is no paperwork UI (Orb). *Aura:* her processing gauge shows as a build-up, the same way as every fighter's. The paperwork shows in her lines and in in-world clues (Narrative) |
| **Cyborg**: Regrowth and the Rail chip | Flesh regions regrow at 8 wear per second out of exchanges and never count toward the brink. The **Rail chip** moves on a seeded schedule, about every 4 s, between four stations: head, chest, back and hip. A heavy, a GUARD BREAK, a signature hit or an interrupted **Press** opens the hatch at the chip's station for 1.5 s. While it is open, the director weights that station's region by ×3, and a hit there damages the chip. Chip stages are scratched, cracked and split, and a split chip means the brink. Chip damage never regrows | *Crown:* flesh arcs visibly crawl back after damage, so the transient state reads. *Silhouette:* shows the rail, the chip's current station and its stage marks, which are the only persistent state. *Cards:* chip events only, such as `HATCH OPEN: HIP` and `CHIP: CRACKED` |

**Fighter mechanics that touch wear:**
- **The heat track (the Protagonist's power stage).** Orb: "his blood goes from heated to simmering to boiling, causing internal damage that adds up but gives big temporary boosts." Narrative names it and Legal screens the look (no red for the Protagonist); this section defines the mechanics only.

  **Heat.** A hidden value from 0 to 100, read through the readout below.
  - *Stoking.* He raises heat by holding a stoke input while free: +25 per second. Controls assigns the input; the default proposal is a variant of the charge input. Stoking gives no ki. It is exposed exactly like charging, so an attack on him is a CHARGE INTERRUPT (`index.html:L435-438`).
  - *Respect sparks.* When his rival commits fully (the Respect trigger in `economy.md` §4.2), he gains +10 heat, even without stoking.
  - *Cooling.* −4 per second while he is not stoking.

  **Stages, with temporary boosts.** Each boost lasts only while he is in the stage. A stage exits 5 below its floor, to prevent flicker.

  | Stage | Enters at | Damage | Speed | Outcome rolls | Internal wear to the core |
  | :--- | :--- | :--- | :--- | :--- | :--- |
  | Heated | 25 | +10% | +5% | none | 1 per second |
  | Simmering | 55 | +25% | +15% | +0.05 | 3 per second |
  | Boiling | 85 | +45% | +25% | +0.10, and launch force +20% | 6 per second |

  **Internal damage.** Heat adds wear to the core as its own *internal* part.
  - Internal wear never fades (not even through second breath), and it does not spread through Rolls with it.
  - It does not feed Respect.
  - It counts fully toward the core's stages. An internally broken core puts him on the brink like any other broken core.
  - Heat therefore spends his future. A full climb and 6 s boil that ends in a boil-over costs about 55 internal wear, so two of them break his core with no help from his rival.

  **Limits and boiling over.**
  - Boiling lasts at most 6 s. If heat reaches 100, or Boiling reaches 6 s, he **boils over**:
    - a burst like a clash shockwave knocks the rival back, and causes collateral scaled by tier;
    - then he vents: heat drops to 0, the core takes 15 internal wear in one lump, he staggers for 1.0 s, and he cannot climb above Heated for 45 s.
  - A boil-over is not a decisive exchange, so it can never start a finisher.
  - A Respect spark while he is boiling can push him over. A rival who transforms at the right moment forces the boil-over, and that is counterplay.
  - Stopping stoking before 100 is the safe exit. Cooling out of Boiling from 90 down to 80 takes 2.5 s, and the Boiling wear rate applies until he is out.

  **Rally and finishers.**
  - **No finisher can start while he is Boiling.** The bill lands first, which is the same rule the region-loan version used.
  - Heated and Simmering finishers are allowed.
  - On the brink he may stoke. Heat adds to his finisher-contest survival roll: +5 at Simmering, +10 at Boiling (the §1 Finisher row, the only place this is counted). It stacks with the tilts in §2. It is a defiant gamble.
  - **Second Wind** mends the core to battered if internal wear broke it, but leaves the internal wear at 89. It also sets heat to Heated with no internal wear for 5 s. His next track step is still free.

  **Readout** (the Protagonist's row above):
  - the core arc shimmers and thickens by stage;
  - the silhouette fills the core from the inside with a distinct "internal" pattern, separate from surface wear;
  - wound cards announce each stage change, each internal core stage, and the boil-over;
  - audio adds a heartbeat and a rising boil. The colour is Narrative's and Art's call, and not red.
- **The region loan (the previous Overcommit), kept in case Orb reverts.**
  - *Mechanics:* the direction held at activation picked one region to spend: arms for damage, legs for speed, core for toughness.
  - *Rungs:* Committed was +15% at 4 self-wear per second; Overcommitted +30% on two regions at 6 per second; Overdrawn +50% on three regions for at most 4 s at 8 per second, then each spent region dropped a stage and a 45 s lockout followed.
  - *Rules:* no finisher could start while Overdrawn. Self-wear did not spread and did not feed Respect.
  - *QA bands:* Overdrawn users won 40 to 60%, with at most 1.5 uses per match.
- **The Anti-hero's pride-for-power kit** (Orb, round 4: he leans toward Drop the Act in 1v1, and Humbled). All names are placeholders.
  - **Humbled (forced, always on).**
    - *Stacks.* Each humbling he suffers gives a stack of shame, up to 3. A humbling is being parried, taking a GUARD BREAK, or having a region broken.
    - *While stacks are held:* each stack gives +8% damage and +0.03 on outcome rolls.
    - *Release.* The next decisive exchange he wins spends all his stacks in a burst: +15% damage per stack on that exchange, then the stacks clear.
    - *Cost.* Each humbling also costs 15 Pride, so humblings push him toward the facade crack.
    - Humbled suits the AI and new players, because there is nothing to decide.
  - **Drop the Act (by choice, 1v1, once per match).**
    - *When.* Available after 2:00 while his Pride is 50 or more, so he still has a front to drop.
    - *How.* The conditions are the fill. When he triggers it, a 1.5 s cinematic plays and is respected, like a transformation (§8).
    - *Effect.* His Pride goes to 0 and the facade cracks at once: every withheld penalty lands, and the crown and cards show his true state. For the rest of the match he is **unrestrained**:
      - +30% damage and +15% speed;
      - +0.08 on outcome rolls;
      - a chain limit of 6 instead of 5.
    - *Cost.* Pride can never rebuild above 49 this match, so the Proud front is gone for good and his real wear shows and counts.
  - **Interactions.**
    - Both keep Spite, because neither involves help. Humbled stacks make Spite easier to earn on the brink, because rage feeds the comeback.
    - After Drop the Act, Humbled still stacks. Its Pride cost no longer matters, and its burst still does.
    - *Swallow It* (hold to drain Pride into a proportional surge, interruptible) is kept as the fallback if Orb drops either.
  - **Earlier rulings stand:** *Take a Knee* keeps Spite. *Hat in Hand* and *Full Circle* forfeit Spite for the match, because they accept help.
  - **The Heavy Crown, with On the Chin** (Orb's pick, 2026-10-01: hybrid 1 of `pitches.md` §7b). Every number is a proposal for data. The mechanic is built after his first moveset (questionnaire 8).
    - **Three forms,** like a typical fighter: Regalia at Pride 60, Sovereign at 80 and Apex at 95. This folds the five-form ladder in `moveset-rules.md` §9.2 and §10.3.
    - **Pride.**
      - *Gains:* an exchange won +3; a perfect block +5; a completed taunt +6; a string of three or more +8; and absorbed damage (below).
      - *Losses:* a humbling costs 15, and the crash below 50 takes a form away, as before. Under ADR 0008 a humbling is being perfect-blocked, guard-broken, thrown or crippled.
    - **The Heavy Crown.** Above Pride 50 he loses 4% damage per 10 Pride, so he is at −18% just before Apex. That is his weak middle.
    - **Apex** ends the debuff for the rest of the match and gives **+36% damage**, plus 3% for each completed absorb, up to **+45%**. A typical fighter's top form is +27%, so this is the largest swing in the roster: 54 to 63 points in one moment.
    - **Take it on the chin** (working name). He plants his feet and lets the opponent hit him.
      - *The prompt:* his Pride is 60 or more, he is free and not guarding, he is not on the brink or opened up, and the move is off cooldown. The context icon gains a "hold" mark.
      - *The input:* hold the context button for 12 ticks. A tap still does the usual context action (`control-rules.md` §4). The stance lasts while held, for 4 s at most.
      - *What it absorbs:* up to 3 ordinary hits, or 1 signature, which ends it.
      - *The reduction:* ordinary attacks hurt 17% less (Orb's figure; the tuning range is 15 to 25%), and a signature hurts 70% less. Nothing launches, staggers or moves him.
      - *Against his body:* only the reduced damage becomes wear. It lands on the head and the core, half each.
      - *Toward his ego:* the move's full damage counts, at +1 Pride per 12 damage. That is about +2 for a light, +5 for a heavy and +20 for a signature. A completed absorb (3 hits, or a signature) is what adds the 3% to Apex.
      - *What he gives up:* movement, guard, dodge, attacks and the burst. Releasing early ends it with 20 ticks of recovery.
      - *Cooldown:* 25 s from the end of the stance.
      - *A signature absorbed* is a set piece: a 1.5 s pause, a camera push and a line of bravado. It is the short version in the pause budget (§8b) and draws on the bank. When the bank can't cover it, it plays live with a camera cut.
      - *Absorbed hits are not decisive exchanges.* They can't launch him, can't roll a crippling moment and can't set up a finisher.
    - **The opponent's counterplay.**
      - *Throw him:* a grab or tackle beats the stance at full damage and humbles him.
      - *Don't attack:* he gains nothing, the cooldown starts, and the opponent has up to 4 s to charge untouched.
      - *Hit him anyway* when ahead on wear, because every hit goes to his head and core.
    - **The AI.**
      - *As the rival,* it uses the stance when its core is below battered and it isn't within 15 Pride of a crash. It answers a signature tell on 20%, 45% or 70% of chances (easy, medium, hard), and otherwise uses it when the opponent has a string queued.
      - *As the opponent,* easy attacks into the stance, medium charges and hard throws him.
    - **With the rest of his kit.** The Proud front hides the wear he absorbs. Humbled is unchanged. Drop the Act ends the Heavy Crown and gives up Apex for unrestrained power now. His revealed signature still arrives at Apex (`moveset-rules.md` §10.3).
    - **QA bands** (when it is built):
      - every pairing 45 to 55%; he wins under 45% of the matches that end before Apex and over 60% of those that reach it;
      - Apex is reached in 30 to 50% of his matches;
      - completed absorbs: 1 to 3 a match, and a signature absorbed in 20 to 40% of his matches;
      - he is thrown out of the stance in 15 to 35% of its uses.
  - **Narrative's round-4 options B1 to B4** stay as notes until Orb picks: Shed Regalia, Credit Where Due, The Code, Loss of Face (`docs/narrative/pitches-q3.md`, Round 4 §2). Each would plug into the same Pride and Proud-front rules.
  - **QA bands**, per Anti-hero match:
    - he wins 45 to 55% of each pairing;
    - in 1v1, the AI drops the act in 40 to 80% of matches, at a median of 3:00 to 6:00;
    - matches where he drops the act are won 45 to 60% of the time;
    - Humbled bursts fire 1 to 3 times per match;
    - the facade cracks in 60 to 90% of matches.
- **The Empress's paperwork** (Orb's direction). It is revised for the respected-transformation rule (§8) and for Orb's ruling: **no visible paperwork**. There are no stamp cards, no forms on screen, and no `REJECTED` or `REGISTERED` text. The paperwork lives only in her lines and in in-world clues (Narrative). The rules are plain gauges. Names are placeholders.
  - **Joke revisions, 1 to 8.** Wrath fills, and each fires automatically as a respected cinematic of under 1 s. They mend nothing. Tiers: 1 for revisions 1 to 3, 2 for revisions 4 to 8.
  - **Real revisions, 9 to 12.**
    - *The fill.* When Wrath reaches a real revision's threshold, a **processing gauge** fills over 8 s while she keeps fighting. It is read in-world, with no text:
      - her sigh of dread when it starts;
      - **one protocol gesture at each third**, from a remaining guard member or from her own body when none are left; the third gesture means approved;
      - the pained aide's posture worsening with each revision (Narrative, `docs/narrative/pitches-q3.md` §11).
      The usual aura build-up that every fighter has stays as the backup cue.
    - *Stopping it.* If the opponent wins a decisive exchange against her while it fills, the gauge resets to empty and starts again. There is no other penalty.
    - *When it completes,* the revision's cinematic (2 to 3 s) plays and is respected. The refit applies on revisions 9 to 11. Tiers: 3 for revisions 9 and 10, 4 for revisions 11 and 12.
    - *State.* The processing gauge only.
  - **Guard of honour.** Each tag-in is a fixed 1 s salute, during which the incoming guard can't be hit. It counts as downtime, and there is at most one tag-in per 5 s.
  - **The fold.** Her gauges work everywhere, the fold included.
  - **Her comeback: Encore** (Orb's pick; binding). A straightforward brawl through her guard, with no damage transfer and no paperwork UI.
    - *Fallen guards leave.* A guard member who falls in the goon phase leaves the field. The Encore brings all three back **once**, fresh from the barracks.
    - *Trigger.* She calls it within 3 s of entering the brink. It never starts during her opponent's finisher, and it is available once per match, in any arena, the fold included.
    - *Entrance.* A 1.5 s respected set piece: all three arrive together and salute in formation.
    - *While they stand.* She withdraws out of reach: lock-on goes to the guard, who are always in reach (pillar 3). She snipes support shots and taunts, as in the goon phase.
    - *The mend gauge.* It fills over **15 s**, and only while at least one guard member stands. It reads through her body straightening, with no text.
    - *If the gauge completes,* one broken region mends to battered and she leaves the brink. Any guard still standing salute and withdraw, and she steps back in.
    - *If all three fall first,* there is no mend. She is still on the brink and in reach at once.
    - *Hard cap.* The Encore ends when the gauge completes or the last guard falls, whichever comes first. The whole Encore lasts at most **16.5 s**.
    - *Rally rules.* It counts as her Rally for the finisher tilt (§2).
    - **Not the same fight twice.**

      | | Act 1 goon phase | Encore |
      | :--- | :--- | :--- |
      | Pace | One at a time, each tag-in a 1 s salute | All three at once in formation, rotating after every exchange with no salute |
      | Formation | One fights while the others taunt | One engages while the other two support: the marksman fires covering volleys (a ranged poke about every 3 s that adds wear but starts no exchange), and the speedster flanks to cut off escape routes |
      | Strength | Full durability | Faster (+15% speed) and harder hitting (+20% damage), but each falls to **one decisive exchange** won against them |
      | Length | Most of act 1 (1:00 to 2:00) | At most 16.5 s |
      | Look and sound | Parade order | A distinct encore formation and call (Narrative and Art) |

    - **Tuning note.** At the current tempo (2.5 to 4 s exchanges, 0.8 to 1.5 s cooldowns) and a 60% chance of winning each exchange against a guard, beating all three takes about 20 s at the median. So a 15 s gauge will likely complete more often than the band allows. The first levers, in order:
      1. A shorter gauge (12 s).
      2. Covering volleys only while two or more guard stand.
      3. A minimum cooldown (0.8 s) after every Encore exchange.
      Starting values: a 15 s gauge and one-exchange guards. QA tunes against the bands below.
    - **Options not picked (notes):**
      - The reserve (one guard member held back in the goon phase makes a last stand).
      - Reinforcements (a single fresh recruit).
      - The captain (a two-region mini-boss).
  - **Gestures.** Her protocol gestures come from a remaining guard member, or from her own body when none are left (Orb). Fallen guards leave the match.
  - **QA bands**, per Empress match:
    - she wins 45 to 55% of each pairing;
    - she reaches revision 12 in 30 to 60% of matches;
    - 20 to 50% of real-revision gauges are reset at least once;
    - median fill time is 8 to 16 s per real revision;
    - no fight gap exceeds 10 s (`balance-targets.md` §8);
    - **Encore:**
      - she calls it in 60 to 90% of the matches where she reaches the brink with it available (AI);
      - the mend completes in 40 to 60% of Encores;
      - Encores last a median of 8 to 13 s and never more than 16.5 s;
      - she wins 45 to 60% of matches in which the Encore completed, so the comeback is not a lock;
      - the act 1 goon phase still fills 1:00 to 2:00.
- **Press (the Cyborg's food).** A **hold** input: the charge input held near people (Controls). His plates clamp shut around nearby civilians; this is slow and interruptible, like a charge. An interrupt pops the hatch at the chip's current station, which rewards the punish.
  - *Collateral rules* (`balance-targets.md` §4b):
    - Press is exempt from the rolling casualty budget and never triggers evacuation.
    - It counts toward the ceiling and every collateral band.
    - Only people still present can be Pressed; evacuees are safe.
  - *Hunger thresholds, as shares of the starting population* (normalised, so every planet is equivalent):
    - first molt after 4% consumed;
    - second molt after a further 4% (sandwiches from Press).
    Both fit under the tier-1 and tier-2 ceilings (10% and 30%).
  - *Check against his matchups.* The present-population floor at 4:00 (at least 25%) is his guarantee. If QA sees it fail against collateral-heavy opponents, the first lever is a shorter evacuation radius (World's `EVAC_R`). The thresholds are the second.

## 4. What the sim needs (Simulation, Tools)

- **Per-fighter data:**
  - regions and thresholds;
  - penalty keys;
  - recovery rates;
  - the damage profile: spread, pride mask, refit table, regrowth, chip rail;
  - Rally rule;
  - finisher template ids per form tier.
- **Per-atom data:** region weights, wear multiplier, impact class, and whether it opens the hatch.
- **Per-fighter state:** wear per region, stage, brink flag, Rallied regions, hatch timer, chip station and stage, commit rung, Pride mask.
- **Events** into the fx stream (commit `9ac1ea9`): `region_stage`, `region_broken`, `brink_enter`, `brink_exit`, `rally`, `hatch_open`, `chip_stage`, `heat_stage`, `boil_over`, `facade_crack`, `shame_stack`, `drop_act`, `revision_reprint`, `revision_fill_reset`, `encore_start`, `guard_fall`, `encore_end`, `finisher_start`, `finisher_contest`, `ko`, plus the fold events in §7.
- **Rendering and randomness.** Render reads state and events and never writes them. Region draws use the sim RNG only.

## 5. Acceptance tests

**QA harness** (seeded batches, 1,000 or more matches per arm, measured from events):
1. **Determinism.** The same seed and inputs give an identical event hash across runs and ports (JS and GDScript).
2. **No KO without a finisher.** 100% of KOs follow the loser's `brink_enter` and a `finisher_start`. There are no KOs from stray damage.
3. **Length and chapters.** Region breaks per 1v1: 1.5 to 2.5 under the core-only brink (`balance-targets.md` §8). Median time to first brink 4:30 to 7:00. Match length median 6:00 to 8:00, p90 at most 10:00, p99 at most 12:00 (`balance-targets.md` §2).
4. **No loops.**
   - Rallies per match average 0.2 to 0.5 for contest-gated Rallies, or 0.3 to 1.0 with the roster's other Rallies (S4 ruling, §2).
   - No fighter rallies the same region twice.
   - The finisher survival chance is 0 from 11:00, in the time-cap event (a hard test: the sim enforces it). Before that, the tilts of −10 per Rally and −10 per minute past 8:00 apply, with no requirement to reach 0. Loops are bounded by one Rally per region and by the event.
5. **Spread.** No region takes more than 45% of all wear across a batch. Each of head, arms and legs is the first region broken in at least 10% of matches.
6. **Profiles.**
   - The Cyborg's chip takes 0 damage while the hatch is closed.
   - The Anti-hero's battered penalties are inactive while Pride is at half or above, and all apply within one tick of the facade crack.
   - Refit mends shrink with each revision.
   - No finisher starts while the Protagonist is Boiling, and no boil-over is ever counted as a decisive exchange.
   - The Protagonist's internal core wear never decreases, except through Second Wind.
7. **Balance.** Every pairing wins 45 to 55%. The pacing bands in `balance-targets.md` §10 still pass. **Heat-track bands**, per Protagonist match:
   - he reaches Boiling in 40 to 80% of matches;
   - Boiling fills at most 5% of match time;
   - boil-overs average at most 0.5 per match;
   - matches with a boil-over are won 35 to 55% of the time, so the gamble is real;
   - internal wear causes 10 to 35% of his brinks, so it matters without dominating.

**Playtest and review:**

8. After one match, 80% of new players say correctly who was closer to losing at the midpoint.
9. 90% can name the region most recently broken on their opponent.
10. At the widest zoom, the crown's arcs and stages can be told apart in a screenshot review, including in a colour-blind simulation (Art, Accessibility).
11. With the silhouette on, a new player predicts the Anti-hero's facade crack after a humbling, and the Cyborg's open hatch, in a scripted `training` scenario.

## 6. Hand-offs (routed by the EP)

- **Combat:**
  - region weights per atom;
  - break-launch and chase set pieces;
  - finisher templates per fighter and form tier;
  - the heat-track stoking and boil-over beats, and the Swallow It beats;
  - the Press interrupt.
- **Encounter Systems:**
  - region choice (go for the wound) and the decisive-exchange rule;
  - the finisher contest;
  - the AI's use of Rally, the heat track, Swallow It and Press.
- **Simulation:** state, data and events in §4, with fixed-point wear.
- **UI and UX:** the crown, the cards and the silhouette, per fighter.
- **Animation, VFX, Audio, Camera:** the channels in `damage-model.md` §3.
- **Narrative:** card text and barks.
- **QA:** tests 1 to 7.

## 7. The fold: fragments and the proving ground (the Protagonist)

Orb (round 4): **space folds inward** toward the Protagonist and the planet vanishes around them, for an in-world reason. Narrative's fiction and storyboard are in `docs/narrative/pitches-q3.md`, Round 4 §3.
- **The fiction.** The fragments are the planet's bare bone. Held close, they let him draw that lifeless ground over the fight.
- **Legal's rules apply** (`docs/legal/q3-screen.md` §a):
  - no fixed count;
  - no search, no sensor and no wish;
  - only the fighters speak or appear;
  - no column of light and no darkening sky.

This section is binding and replaces the relocation rules in `systems-sketch.md` §4 and `pitches.md` §4. Names are placeholders.

| Rule | Spec |
| :--- | :--- |
| **Fragments** | Shed by planet damage (region-break launches, beam hits, ground tier-ups, clash shockwaves) as irregular pieces whose mass runs from 1 to 5, drawn with a seed. Anyone can grab one for a charge surge. Only the Protagonist can **hold** them, and they orbit his body |
| **Threshold** | A total held mass of **12** (starting value). Any mix of sizes works, and there is never a count to complete. As his mass nears 12, the orbit tightens and hums. At 12 the ring closes: the tell |
| **Time floor** | **Kept at 4:00.** No fold before it. It protects act 1 and 2 pacing, and gives the Cyborg his populated planet for at least the first half of the match |
| **Folding** | Gathering fragments is the fill; the rival stops it by knocking fragments loose (see Fragility). Once the ring has closed and the floor has passed, he triggers the fold. The lead-in (his line, the rival's reply) and the fold, up to 6 s in all, are a **respected cinematic**. The rival waits and may charge. The 1.5 s interruptible hold is dropped: the fold is a relocation, not a transformation, but it follows the same fill-then-respect rule (§8), which removes a special case |
| **Who comes** | In 1v1, both fighters, always, so the rival is never out of range (pillar 3). 2v2 rules are **deferred** (Orb: focus on 1v1 for now) |
| **The proving ground** | A small wrapped planetoid, about a third of the planet's circumference, of barren craterable stone. No civilians, no structures and no cover |
| **What the proving ground changes** | No casualties, so no collateral-fed gain: the prototype's menace and anguish stop. **The denial is the Protagonist's intended counter to the Cyborg**, softened by one relief valve:
- the Cyborg keeps his Hunger;
- he may **Press a loose fragment** lying on the ground. That gives him half the Hunger of a civilian, and destroys the fragment, which feeds the unfold.

His best play is to break the fold, and that is the matchup's story. The backup drive stays on the planet. There are no line-of-sight blockers except craters and rubble the fight makes. Ego meters, forms, wear and heat carry over unchanged. The Protagonist's **final form unlocks** here, and only here |
| **Fragility** | While folded, the fragments still orbit him. A heavy, a GUARD BREAK, a signature hit or a region break on him knocks one loose, with a seeded pick weighted to the largest. It lands on the barren ground, and anyone can grab it: the rival gets a surge and denies the mass. Each loss makes the horizon **flicker**: a `FOLD FLICKERS` card, and the planet's edge ghosts back in |
| **Unfolding** | If his held mass stays below 12 for **3 s**, the planet returns. In those 3 s he can grab back mass and hold the fold, a scramble set piece. On the unfold, everyone returns to where they left. His final form ends and he drops to his previous form, keeping his promise. He cannot fold again for **60 s** |
| **Finishers** | These work normally in the proving ground, which is the natural stage for the finale. A finisher that starts during the unfold countdown completes before the planet returns |
| **Events** | `fragment_shed`, `fragment_grab`, `fragment_lost`, `ring_closed`, `fold_start`, `fold_flicker`, `unfold` |

**QA bands**, per Protagonist match:
- a fold happens in 30 to 60% of matches;
- no fold before 4:00 (0 cases);
- median fold time 4:30 to 6:30;
- 20 to 50% of folds collapse back to the planet, so fragility matters without dominating;
- 50 to 80% of matches with a fold end in the proving ground;
- no casualties are recorded while folded (0 cases);
- the Protagonist still wins 45 to 55% of each pairing;
- against the Cyborg specifically: the Cyborg wins 40 to 55% of the matches that include a fold, and 30 to 60% of folds collapse.

**Settled or deferred:**
- The rival's reply varies by matchup and stakes (Narrative's matchup matrix).
- Who the fold takes in 2v2 is **deferred** with all 2v2 rules. The recommendation on record is everyone.

## 8. Transformations are respected (Orb's global rule)

Orb: "with few exceptions, transformations should be cinematic and uninterruptible. The gauge or some mechanic must fill or otherwise complete, which can be stopped, but once the transformation happens it should be respected." This replaces questionnaire 3's "long transformations can be interrupted" wherever it appears in these docs.

**Every transformation has two phases.** When a fill completes, **the player chooses when to take the transformation** (questionnaire 4), and the AI chooses for itself. The Empress's joke revisions stay automatic.
1. **A fill** (a gauge, a condition, or an action), which the opponent can stop.
2. **A cinematic**, which the opponent cannot interrupt. Since questionnaire 10 it pauses the sim for both players, within a budget (§8b).

The ready tell, the Transform input (hold 0.5 s) and the look of each form are in `moveset-rules.md` §10.

| Fighter | Fill (can be stopped) | How the opponent stops it | Respected cinematic |
| :--- | :--- | :--- | :--- |
| Protagonist, track forms | Respect fills when the rival commits fully | By not committing: the rival controls the fuel | Each track step, 2 to 3 s |
| Protagonist, final form | The fold: held fragment mass | Knock fragments loose, before the fold and after it | The reveal in the proving ground, up to 4 s |
| Protagonist, heat track | Stoking (+25 heat per second) | CHARGE INTERRUPT on the stoke | None. Heat stages are power states, not transformations |
| Anti-hero, forms | Pride thresholds | Humble him (parry, GUARD BREAK, break a region), which drains Pride | Each form, 2 to 3 s |
| Anti-hero, Drop the Act | The conditions (after 2:00, Pride at 50 or more) | Drain his Pride below 50 first | 1.5 s |
| Empress, revisions | Wrath, then an 8 s processing gauge for real revisions, read through her sigh and three protocol gestures, from her remaining guard or her own body (no text) | A decisive exchange won against her while it fills resets the gauge | Under 1 s for joke revisions, 2 to 3 s for real ones |
| Cyborg, molts | Hunger, from Press and sandwiches | Interrupt Press; keep him from people | Each molt, 2 to 3 s |
| Cyborg, final form | Catching the backup drive | Chase him off it, and cut off the drive | Docking, 2 to 3 s |

**Exceptions: none for transformations.** Everything that can still be interrupted is a fill, not a transformation:
- charging;
- stoking;
- Press;
- Swallow It;
- the Empress's processing gauge;
- the Encore's mend gauge (stopped by beating her guard).

Heat stages, Humbled bursts and boil-overs are power states with no cinematic. The fold is a relocation, and it now follows the same rule (§7).

**Guard rails:**
- A respected cinematic never starts while the opponent's finisher is running.
- Cinematics don't mend or heal. The exceptions are the Empress's refit and an approved Rally.
- A fighter on the brink may still transform. The form's power arrives, but the fighter stays on the brink.
- Everything pauses during a pausing set piece, including the director cooldown (§8b). The wait is short by budget.
- Caps: 3 s for a form, 6 s for the fold, 4 s for a final-form reveal.

**QA bands:**
- pauses total at most 2.5 s per minute of match (§8b; it was "cinematics take at most 10% of match time");
- no cinematic starts during a finisher (0 cases);
- no cinematic runs longer than 6 s;
- the "no gap over 10 s" band counts a cinematic as action, not as dead air.

### 8b. Pausing set pieces and the transformation pace (Orb, questionnaire 10)

**Only three things pause the fight for both players:** a transformation, a world-changing ability, and the planet giving way at 11:00.
- During a pause the sim stops: the match clock, every cooldown and both fighters. So the rival no longer charges or stokes during a cinematic, which replaces that rule above.
- **Everything else runs live, with a camera cut:** finishers, the KO, the crippling moment, the start of a beam struggle, a revealed signature, smash chains and a landmark's fall. They keep their beats, but the sim keeps running.

**The pause budget: about 2 s a minute.** A bank starts at 3 s, gains 2 s for each minute of match time, and holds at most 6 s. Each pausing set piece has three versions with the same gameplay effect:

| Version | Length | It plays when |
| :--- | :--- | :--- |
| **Full** | 3 s. A final-form reveal may take up to 4 s | It is that fighter's first set piece of its kind, the bank covers it, and 20 s have passed since the last pause |
| **Short** | 1.5 s | It is a repeat (a fighter's later forms), or the full version's conditions fail. It needs 1.5 s in the bank and 8 s since the last pause |
| **Live** | 0.8 s, with no pause | Otherwise. It is the existing power-up burst with a camera cut: the rival is pushed back, and the transformer can't be interrupted |

- A set piece is never refused or delayed. Only its version changes.
- The planet giving way always pauses, for 4 s, outside the budget.
- If two requests land on the same tick, the lower slot plays first and the other follows the table.
- *QA band:* pauses total at most 2.5 s per minute of match (a hard test). This replaces "cinematics take at most 10% of match time".

**The transformation pace: about three per fighter, the first around 1:30.** Orb confirmed that three per fighter is right for a typical fighter (2026-10-01).

**The count is per-fighter data.** Each fighter's list of transformations sits in their data, with a kind for each: a pausing step, or a live one.
- *A typical fighter* has three pausing steps. The Anti-hero's Pride ladder folds to three (`pitches.md` §7).
- *The Empress is the outlier,* and her count is her identity: twelve revisions. Her eight joke revisions are always live, under 1 s, and never draw on the bank. Her four real revisions are pausing steps: the first plays full, the middle two play short, and Final Approved plays full, up to 4 s, when the bank covers it.
- *The budget copes without a special rule.* Her four pausing steps ask for at most 10 s against a typical fighter's 6 to 8.5 s. When the bank runs low, her later revisions drop to the short or live version like anyone's. She transforms more often than anyone, and pauses the fight barely more.

| Step | Target (median, per fighter) |
| :--- | :--- |
| First | 1:15 to 1:45 |
| Second | 2:45 to 3:45 |
| Third | 4:30 to 5:30, before the first brink (5:52 at G0) |

**The placeholder ladder** (`data/fighters/*/ladder.json`):
- *Thresholds:* 30, 65 and 100 (they were 25, 50 and 75).
- *`fillPerSec`:* 0.05 (it was 0.45).
- *Power from fighting* is unchanged: +0.006 per damage dealt and +0.010 per damage taken, about 13 a minute at G0's damage rate.
- *Charging must become data.* Today it adds +9 power a second, hard-coded in `sim/core/fighter.gd`, which fills a whole step in about 4 s. It becomes `chargePerSec` **0.5** (Simulation's line). Without that change the data retune can't hold the pace.
- *The check:* 3 a minute from the fill, 13 from fighting and about 4 from charging make 20 a minute: 30 at 1:30, 65 at 3:15 and 100 at 5:00.
- *Against the budget:* six transformations a match are two full (6 s) and four short (6 s), so 12 s. The bank gives 3 s plus 14 s over seven minutes, which leaves about 5 s for world changes.

**How it sits with the acts** (§9). The act index becomes `1 + the larger of (form steps, wound beats) + region breaks`, capped at 4.
- *Form steps* are the most ladder steps any one fighter has taken, from 0 to 3.
- *Wound beats* are the three in §9, from 0 to 3.
- Taking the larger track, not the sum, lands the acts with the transformations: act 2 at about 1:30, act 3 at about 3:15 and act 4 at about 5:00. The wound track keeps the acts moving if nobody transforms. The act timing targets in §9 are unchanged.

**Knock-on.** Slower tiers mean less damage and less collateral early. QA re-baselines after the change: k for length, civilians lost (if the mean falls under 25%, the re-base to 15 to 40% in `balance-targets.md` §4b applies), and the per-tier structure bands in §15 there.

## 9. Invisible acts and the fight's mood (Orb, questionnaire 4)

**Invisible acts.** The director escalates chapter by chapter, with no act UI.
- The act index is `1 + the larger of (form steps, wound beats) + region breaks`, capped at 4 (questionnaire 10, §8b). Form steps are the most ladder steps any one fighter has taken. Before that ruling it was `1 + act beats`, with these beats (M1 retune, 2026-09-30):
  - every region break and every transformation, from both fighters, as before;
  - three wound beats, **each counted once per match**, the first time either fighter reaches it: the first limb reaching battered, the first core reaching bruised, and the first core reaching battered.

  Each wound beat is a visible stage change on the body, and the first battered limb is also the crippling warning. Counting them once per match keeps both fighters from racing the acts to 4 by 3:00. Simulation moves the beat list into `data/fight/mood.json` (`actBeats`), so later tuning is data only.
- Each act raises the director's strike cadence by 10%, and makes blitzes (short multi-strike flurries), long launches, beam struggles, teleport clashes and collateral set pieces more likely, within every tier cap in `balance-targets.md`.
- Each act also cues a music layer (Audio), a camera stance (Camera) and bark density (Narrative).
- The player reads acts through sound, camera and voice, never through a counter.

**The fight's mood.** A director value from 0 to 100, which the player shapes only indirectly.
- *What raises it* (events add points, and the value is clamped from 0 to 100; Encounter's Q4 plan, question 3):
  - a strike landed: +1.5, or **+3.5** for a heavy (it was +2.5: a heavy should move the room);
  - a chain link: +3;
  - a parry: +4;
  - a heavy or beam clash: +8;
  - a signature beam landing (HIT or GUARD, not a clash): **+6**, its own value, between a heavy and a clash, because a landed signature is a set-piece moment;
  - a region break: +12;
  - a launch through a building: +6, or +10 for a chain;
  - **a landmark falling: +10**, once for each landmark, on top of any launch or casualty impulse. It is a set-piece moment the whole planet sees (districts plan, `building_fall.landmark`). Ordinary buildings falling stay covered by the launch and casualty impulses;
  - a transformation cinematic: +10;
  - the start of a finisher: +15;
  - a taunt or banter line: +3;
  - casualties: +0.5 each, normalised, and at most +8 per event;
  - both fighters in AGGRESSIVE: +1 per second.
- *What lowers it:*
  - a decay of **−4 per second** (it was −6) toward an **act floor** of **0, 10, 25 and 40** for acts 1 to 4 (it was 0, 10, 20 and 30). Act 4 can never fall below Tense, and later acts never fall all the way back to calm;
  - an extra −4 per second while both fighters hold DEFENSIVE or ESCAPE.
- *Three bands (working names):*
  - **Calm**, below 30: crowds watch from a distance, the director uses its normal cadence, and inner thoughts are about patience ("Only a little longer...").
  - **Tense**, 30 to 70: crowds retreat, the director blitzes more (+25% blitz chance), and the release-to-request gap moves to the short end (0.6 s).
  - **Frenzied**, above 70: crowds flee in panic, blitzes and teleport clashes are at their most frequent, and boasts and threats dominate the barks.
- *Bands, hysteresis and aggression* (Simulation's M1 plan, `docs/architecture/mood-style.md`; the data belongs in their files, and these are the values):
  - *Thresholds:* Calm below 30, Tense 30 to 70, Frenzied above 70. The mood must stay across a threshold for a **3 s dwell** before the band changes, with no further hysteresis.
  - *Aggression,* in permille: **1000 + 100 × (act − 1) + band bonus**, where the band bonus is 0 for Calm, 250 for Tense and 500 for Frenzied. The maximum is 1,800, at act 4 and Frenzied. It scales the director's strike cadence and blitz chance.
  - *Scope:* **one match-wide scalar**, because mood belongs to the whole fight. Each fighter's own difference comes from stance cadence (`stance-matrix.md` R9) and personality data, and multiplies with it.
- *Style labels* (turtle, rusher, runner, charger, sniper and mixer): Narrative's thresholds, holds, hysteresis and QA bands (`docs/narrative/style-thresholds.md`) are **signed off by Game Design**. One clarification from questionnaire 4: an "attack" in the sniper and mixer measures is an exchange the fighter's director started, counted by its weight at the start, not a button press.
- *The players' styles feed the voice* (Orb): holding DEFENSIVE surfaces patience thoughts, and an opponent who turns EVASIVE under pressure prompts boasts. Narrative writes the lines, keyed to stance history and mood.
- *QA bands:*
  - Frenzied at most 25% of match time;
  - Calm at least 15% of match time (the fight breathes);
  - blitzes 2 to 6 a minute in Tense and Frenzied.
- **M1 retune** (M1 `4123f3a` measured Calm 87.5%, Tense 12.4% and Frenzied 0.1%, with act 2 at 5:15, act 3 at 5:54 and act 4 at 6:18). The −6 decay outpaced the impulses, and the only early beats were cores reaching battered. The values above are the ruling, and the targets are:
  - *band shares over the match:* Calm 30 to 55%, Tense 35 to 60%, Frenzied 5 to 20%;
  - *by act:* Calm at least 60% of act 1; Frenzied at least 15% of act 4, which is the climax;
  - *act timing (medians):* act 2 at 1:30 to 2:30, act 3 at 2:30 to 4:00, act 4 at 4:30 to 5:45. Act 4 arrives before the first brink in at least 80% of matches, so the brink chapter plays in the top act.
  - *Tuning, data only:* decay first, as a whole number from 3 to 5 per second, then the floors. If no decay value lands the shares, because linear decay is knife-edged, Simulation adds a proportional term as a small code change: decay = 2 + 0.08 × (mood − floor) per second. It settles about 25 points above each act's floor at today's impulse rate: Calm in act 1, and Tense from act 2.
