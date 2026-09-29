# Known bugs in the prototype

Owner: QA and Balance. Subject: `prototype/index.html` at commit `7233c96`, pinned until the port proves parity. Nothing here is fixed in the prototype; each entry says whether the report is true, how to reproduce it, and what it does to the baseline (`baseline-p0.md`). `Line` numbers are at that commit.

Reports come from Combat and Choreography (their IDs `CC-nnn` are in `docs/combat/move-grammar.md`, section 5) and Game Design, forwarded by the EP. All six are **confirmed**, two of them broader than the one-line reports (KB-004, KB-006).

| ID | Bug | Reported by | Verdict | Touches | Effect on the baseline |
| :--- | :--- | :--- | :--- | :--- | :--- |
| KB-001 | Signature vs an ESCAPE defender hits less as the attacker's tier rises | Combat (CC-004), Game Design | confirmed | beam outcomes | none measurable: mean tier gap is 0.01 |
| KB-002 | The 1.35x damage against a charging defender never applies | Combat (CC-003) | confirmed | damage | 0.5% of damage; none measurable |
| KB-003 | A parried exchange still gives the attacker a chain window | Combat (CC-001) | confirmed | chain rate, ki | 13% of reported chains are phantom; chain rate 3.82 is really 3.32 a match |
| KB-004 | The chain strike ignores the defender's stance, not only after GUARD HOLDS | Combat (CC-002) | confirmed, broader | damage, DEFENSIVE | 18.5% of all damage; 76.5 HP a match through a guard |
| KB-005 | A dodged signature freezes the defender 300 units up for 0.87 s | Combat (CC-005) | confirmed | feel | 0.40 s a match, 0.7% of match time |
| KB-006 | The rush flies through terrain, and through standing buildings | Combat (CC-006) | confirmed, broader | feel, collision | 15% of rushes clip terrain, 6.7% pass through a building |

**Checks.** `qa/tests/known-bugs.test.js` has one check per bug asserting that it is still present. It passes today. When a behaviour changes it fails with "KB-00x appears fixed", and the fix is to set the verdict below to `fixed` (with the commit), then turn the check into a regression test for the corrected behaviour. A last check keeps this register and the test file in step.

**Reproduce and measure.**

```
node qa/known-bugs-repro.js [KB-003 ...]   what each scenario observes today
node qa/tests/known-bugs.test.js           the pass/fail checks
node qa/known-bugs-scan.js                 effect sizes on the baseline (default arm, seeds 100001..101000), writes qa/known-bugs-effects.json
node qa/known-bugs-whatif.js               the baseline with each bug patched in a scratch copy, writes qa/known-bugs-whatif.json
```

The scan and the scenarios use a scratch copy of the prototype with no-op hooks (`qa/lib/instrument.js`). It plays out bit-for-bit like the real file: its 1,000-match digest is `70142afa31be898c`, the baseline's.

## What fixing them would do

`known-bugs-whatif.js` patches one bug at a time in a scratch copy (the obvious one-line change) and re-runs the baseline's 1,000 default-arm matches. It is an indication of importance, not a fix proposal. One thousand matches resolve about 3 points on win rate, so smaller shifts are invisible.

| Patch | Win rate P1 (baseline 42.3%) | Match length (55.4 s) | Civilians lost (38.7%) | Chain rate (3.82 a match) | Metrics beyond the 99.9% interval |
| :--- | :--- | :--- | :--- | :--- | :--- |
| KB-001 sign fixed | 42.1% | 55.4 s | 38.7% | 3.81 | none |
| KB-002 1.35x applied | 42.2% | 55.3 s | 38.7% | 3.81 | none |
| KB-003 no window after a parry | 43.3% | 55.3 s | 39.9% | 3.44 | chain per match, chain per melee exchange |
| KB-004 chain respects stance | 40.4% (z -0.9) | 57.1 s (z 1.9) | 38.9% | 3.97 | none |
| KB-006 rush stays above ground | 42.2% | 55.4 s | 38.7% | 3.83 | none |

None of the six moves win rate, length or collateral beyond sampling noise. KB-003 changes only the chain metrics. KB-004 leans toward longer matches (+1.7 s, z 1.9) and a lower KAI win rate (z -0.9), neither significant at this sample size. KB-005 has no obvious one-line fix; its cost is the dead time given in its entry.

---

## KB-001: Signature vs an ESCAPE defender hits less as the attacker's tier rises

**Reported by:** Combat (CC-004); Game Design found it independently.
**Verdict:** confirmed. It is a sign error.
**Line:** 589, in `planBeam`.

**Expected.** A higher-tier attacker should be more likely to catch an escaping defender. The rest of the code agrees: the melee pursuit (`pEsc = 0.5 + 0.07*(D.tier - A.tier)`, line 441) and the beam dodge (`0.55 - 0.06*(A.tier - D.tier)`, line 588) both move against the defender as the attacker's tier rises.

**Actual.** `rng() < clamp(0.5 - 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)` decides HIT, so every tier of attacker lead lowers the hit chance by 5 points. At a 3-tier lead the beam hits 35% of the time (at 1,000 units); trailing by 3 tiers it hits 65%.

**Repro.** Scripted, 500 seeded trials per row (seeds 1 to 500). Start a match, take both fighters off AI, put the attacker (P1) at x = 2500 and the defender (P2) at x = 3500 with y = 60, set the defender's stance to ESCAPE, set tiers by setting `tier` and `power` (0, 26, 51, 76 for tiers 1 to 4), give the attacker 100 ki, wait out the director's 0.6 s cool-down, press the signature key (R), read the feed line `KAI SIG vs ESCAPE` for `→ HIT` or `→ ESCAPE`. `node qa/known-bugs-repro.js KB-001` gives HIT 36.4% (tier 4 vs 1), about 51% (2 vs 2) and 65.8% (1 vs 4). The formula predicts 35%, 50% and 65%.

**Effect on the baseline.** ESCAPE defenders receive 504 of 3,648 beams (0.50 a match, 13.8% of beams). The mean tier gap in those exchanges is 0.01 and only 13% of them have any gap at all, so the hit probability is off by 1.3 points on average and the errors cancel: 74.1% as coded against 74.1% with the sign corrected. No baseline metric moves (whatif: none of 60). It will matter once fighters differ in how fast they gain power (P4), because as coded the tier leader is the one who misses, an accidental rubber band. Beam outcome shares in section 6 are unaffected today.

**Check:** `KB-001 present` in `tests/known-bugs.test.js` (hit rate at a 3-tier lead is at least 15 points below the rate at a 3-tier deficit, and both match the coded formula).

## KB-002: The 1.35x damage against a charging defender never applies

**Reported by:** Combat (CC-003).
**Verdict:** confirmed, for two independent reasons.
**Lines:** 326 (`hit`), 411 (`requestAttack`), 436 to 437 (CHARGE INTERRUPT).

**Expected.** Hitting a defender who is charging ki deals 1.35x damage (`if (D.state === 'charging') sm = 1.35`).

**Actual.** (1) `requestAttack` sets the defender's state to `locked` (remembering `charging` only in `dPrev`) before any strike lands, so `D.state === 'charging'` is false when `hit()` runs. (2) Every path that meets a charging defender passes `ignoreStance: true` (CHARGE INTERRUPT, the beam hit, chain strikes), which skips the whole block anyway. The intended punish survives only as CHARGE INTERRUPT's built-in base x 1.4.

**Repro.** Take both fighters off AI, attacker (P1) at x = 2500, defender (P2) at x = 3400, y = 60, both tier 1 and at full HP. Hold the defender's charge key (`;`) for 2 steps, wait out the 0.6 s cool-down, tap the attacker's light key (F). Right after the request the defender's state is `locked` and `dPrev` is `charging`. The first HP loss is **36.40**, which is 26 x 1.4 with no 1.35 (with it, 49.14). Repeat with the signature key (R): the first HP loss is **230**, again with no multiplier. `node qa/known-bugs-repro.js KB-002`.

**Effect on the baseline.** 118 hits in 1,000 matches land on a charging defender (0.12 a match, 0.5% of the damage dealt). The multiplier would add 3.9 HP a match, split between both fighters. Hits where the defender's state read `charging`: 0 of 43,573. CHARGE INTERRUPT is 0.4% of melee exchanges (section 7). No metric moves.

**Check:** `KB-002 present`.

## KB-003: A parried exchange still gives the attacker a chain window

**Reported by:** Combat (CC-001); the EP added that QA's harness counts it.
**Verdict:** confirmed, including the harness point.
**Lines:** 526 (parry sets `ex.cancel`), 544 (`openWindow`), 572 to 574 (`dirUpdate`), 548 to 555 (`chain`).

**Expected.** A parry cancels the rest of the exchange, including the chance to chain.

**Actual.** `strike` and `launchBeat` check `ex.cancel`, but the `WIN` beat calls `openWindow`, which does not, and `dirUpdate` then honours an attack press. `chain()` runs: combo goes up, the attacker pays 6 ki, the "N HIT CHAIN" banner shows and the attacker rushes, but its strike and launch return early, so no damage is dealt. The exchange ends with the feed line `CHAIN xN ended`, which is what QA's parser counts as a chain. Up to four phantom links can stack on one parry.

**Repro.** Seed 1. Attacker (P1) x = 2500, defender (P2) x = 3400 in DEFENSIVE stance, both at y = 60. Wait 0.6 s and tap the attacker's light key (F). When the exchange's `windowStart` is set (the wind-up), tap the defender's light key (`,`): the feed shows `VORR PARRIES`. Step until the exchange offers a window (`ex.ext`), tap F again. Observed: banner `2 HIT CHAIN`, attacker ki down by 6, defender HP unchanged, feed `CHAIN x2 ended`, `ex.cancel` still true. `node qa/known-bugs-repro.js KB-003`.

**Effect on the baseline.** Of 3,817 chain events in 1,000 matches, 499 (13.1%) follow a parry: 0.50 a match. There were 720 phantom links, which waste 4.3 ki a match. Distorted metrics in `baseline-p0.md` section 8: chains per match 3.82 is really **3.32**; chains per 100 melee exchanges 23.8 is really **20.7**; the chain-length histogram and mean (2.41) include the phantoms (real 2.40, phantom 2.44). With the window closed (whatif) chains fall to 3.44 a match, and nothing else moves significantly.

**Check:** `KB-003 present`.

## KB-004: The chain strike ignores the defender's stance, not only after GUARD HOLDS

**Reported by:** Combat (CC-002).
**Verdict:** confirmed, and broader than reported: every chain strike ignores stance, whatever the defender chose.
**Lines:** 476 to 480 (GUARD HOLDS ends on `WIN` at line 480), 554 (`ignoreStance: true`).

**Expected.** A guard that "holds" reduces later strikes in the same exchange, as it reduces the first three.

**Actual.** After the three guarded hits (each 26 x 0.38 = 9.88) the exchange ends on a chain window. The chain strike is `52 + combo x 7` with `ignoreStance: true`, so it lands at full value, and it also skips the guard's ki drain, then launches. Against DEFENSIVE it deals 2.6 times what the guard would allow. The same flag also removes the +12% against AGGRESSIVE and the +25% against ESCAPE, so the chain is about 11% and 20% too weak there.

**Repro.** Seed 1. Attacker (P1) x = 2500, defender (P2) x = 3400 in DEFENSIVE stance with 60 ki, attacker at full HP and tier 1. Tap F after the cool-down; the feed reads `PRESSURE — GUARD HOLDS` with no counter (seeds where the defender counters are skipped by the scenario). Record the defender's HP after each hit: three drops of **9.88**. When the exchange opens its window tap F again: the next drop is **73.92** (66 x 1.12 combo bonus), 7.5 times a guarded hit, followed by a launch. `node qa/known-bugs-repro.js KB-004`.

**Effect on the baseline.** 4,659 chain strikes in 1,000 matches (4.7 a match) are 18.5% of all attack damage dealt (2,254 HP a match, both fighters). By defender stance: AGGRESSIVE 1,592 (mean 88 HP), DEFENSIVE 1,367 (90 HP), EVASIVE 1,174 (88 HP), ESCAPE 526 (96 HP). The DEFENSIVE chains put **76.5 HP a match** through a guard that should have reduced them (3.4% of all attack damage); the AGGRESSIVE and ESCAPE chains are 16.9 and 12.6 HP a match too weak; net +47 HP a match of extra damage. This bears on the baseline finding that aggression wins (section 9): a DEFENSIVE stance whose guard is bypassed by a press of the attack key is weaker than designed. Whatif: respecting stance moves KAI's win rate from 42.3% to 40.4% and match length from 55.4 to 57.1 s, both within noise.

**Check:** `KB-004 present`.

## KB-005: A dodged signature freezes the defender 300 units up for 0.87 s

**Reported by:** Combat (CC-005).
**Verdict:** confirmed as behaviour. Whether it is a bug or an unfinished dodge is Combat's call.
**Lines:** 616 (the DODGE beat), 620 (the exchange's closing beat).

**Expected.** A dodge is a movement: the defender leaves the beam's line and is free to act.

**Actual.** At the dodge beat the defender teleports up by exactly 300 units (`D.y += 300; D.vx = 0; D.vy = 0`) in one step, is still `locked` from the exchange start, and stays motionless until the exchange's closing beat at 1.7 s. The attacker is locked for the same time, and no other attack can be requested.

**Repro.** Seed 4. Attacker (P1) x = 2500, defender (P2) x = 3400 in EVASIVE stance, y = 60, attacker at 100 ki. Wait 0.6 s and tap the signature key (R). The feed reads `... → DODGE`. Watch the defender's `y`: at 0.82 s it rises by 300 in one step, then its position and velocity do not change for 52 steps (0.87 s) until the exchange ends at 1.70 s. `node qa/known-bugs-repro.js KB-005`.

**Effect on the baseline.** 457 of 3,648 beams are dodged (12.5%, 0.46 a match). That is 0.40 s a match with a frozen defender, 0.7% of match time. Beam outcome shares (section 6) are correct; the cost is dead time and how it reads.

**Check:** `KB-005 present`.

## KB-006: The rush flies through terrain, and through standing buildings

**Reported by:** Combat (CC-006), for terrain.
**Verdict:** confirmed, and broader than reported: buildings too.
**Lines:** `stepRush`, 745 to 751 (unclamped step at 751, final clamp at 748).

**Expected.** A rush follows the ground and stops at buildings, or goes over them.

**Actual.** `stepRush` interpolates straight from the current position to the target, `f.y += (ty - f.y)*k`, with no terrain or building test. Only the last frame is clamped (`Math.max(ty, groundY(tx))`).

**Repro.** Seed 5, attacker (P1) and defender (P2) at y = 60, attacker light attack. Mountains: attacker at x = 6200, defender at x = 7800, a 1,600 unit rush across the range: 25 of 36 rush steps are below the ground, up to 547 units inside it. City: attacker at x = 2100, defender at x = 4000: 25 of 38 steps are inside standing towers, up to 473 units deep. Control on flat plains (x 1500 to 1900): 0. The check uses the scratch copy's `groundY`. `node qa/known-bugs-repro.js KB-006`.

**Effect on the baseline.** 25 rushes a match. 3,700 of 25,051 (14.8%) spend time below the ground; most are shallow clips of crater rims (1,528 are deeper than 20 units, 191 deeper than 100, 23 deeper than 300, deepest 639). Together that is 0.40 s a match. 1,682 (6.7%) pass through a standing building, 0.10 s a match. Nothing in the baseline metrics depends on it (whatif on the terrain part: none), but it is visible on screen and would matter to the Camera and VFX directors.

**Check:** `KB-006 present`.

---

## Not checked yet

Combat's CC-007 to CC-013 and Game Design's other notes were not in this brief. CC-009 (a dodge parry window that can never parry) and CC-010 (signature never parries) would be quick to confirm. Add entries here as KB-007 onward and add a matching check to `qa/tests/known-bugs.test.js`; the last check in that file fails until you do.
