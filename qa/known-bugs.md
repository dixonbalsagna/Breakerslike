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

## Godot game bugs (found in play)

Separate from the prototype register above (and from its test). IDs are `GB-nnn`.

### GB-001: F9 pressed twice leaves the game grey (split screen re-attach)

**Reported by:** Orb, playing the Godot game, 2026-09-30 (screenshot: the diagonal split divider still draws, both halves flat grey, action carries on underneath, pause menu works).
**Verdict:** confirmed by reading the code; not yet reproduced in Godot.
**Cause.** `render/core/main.gd` (F9) calls `split_view.detach()` then, on the next press, `split_view.attach(self)`. `detach()` leaves pane 0 inside its old SubViewport, but `attach()` has no re-entry guard beyond `_attached`: it calls `main.move_pane0()` again (`remove_child(pane)` on a node that is no longer main's child, then `add_child` on a node that already has a parent, so both fail and the new SubViewport is empty) and `main.make_pane()` again (a third pane is appended to `panes`). The compositor then masks two empty viewports: flat grey with the divider. Owner of the fix: Camera (`render/camera/split_view.gd`), with Rendering for `move_pane0` / `make_pane`.
**Suggested fix.** Make `attach()` re-use `viewports` when they exist (set `main.compositor = self`, `_attached = true`, restore the update modes) instead of creating new panes; or make F9 toggle only the mask and keep the panes.
**Effect.** Any session where F9 is pressed an even number of times after the first press (detach, attach) ends grey for good; restart is the only way out. Not a sim bug: determinism and the baseline are unaffected.
**Test to add once fixed.** A Godot scene test: attach, detach, attach, then assert `panes.size() == 2` and that pane 0's parent is `viewports[0]`.

### GB-002: A pale vertical "aura" in the far sky when flying high (tier 3 and 4 sky reaction) (reopened 2026-10-02, fixed again 632f6c9)

**Reported by:** Orb, playing the Godot game, 2026-10-02 (two screenshots: a soft blue-white column near the horizon, off to one side of the fighter, with vertical streaks; it moves with the fighters; both fighters at tier 4).
**Verdict:** not a rendering fault: it is the designed sky reaction (`docs/design/rule-of-cool.md` feature 12), which reads as a smear.
**Cause.** From tier 3 `render/core/pane_world.gd` `_sky_react` gives `render/shaders/sky.gdshader` the direction to each fighter and a strength (half at tier 3, full at tier 4). The shader clears the clouds in a tall opening above him (taller than wide, lifted to the horizon, radius `RenderLook.SKY_REACT_R` 0.2) and pales the sky inside it toward his aura colour, with the edge lit in his colour. Because it is anchored to the fighter's direction it slides across the sky as he or the camera moves, and from a high camera the opening sits against the horizon glow with nothing to explain it: a pale blurred pillar. In the screenshots both fighters are at tier 4 and the column is near the far one (the P2 marker is off screen right).
**Not QA's to change** (Rendering, Camera and VFX own the look; Game Design the feature). Options for them: shrink or soften the opening (`SKY_REACT_R`, the strength curve), show it only while the fighter is on screen, give it a visible cause (a ring or the cloud edge lit more than the pale fill), or put it behind the reduced-motion `sky_calm` option and a settings toggle.
**Effect.** Looks like a bug to a first-time player; no effect on the sim or the baselines.
**Status: fixed in 8fd6aba** (Rendering): the sky reaction is a cloud gap with a lit edge, no pale fill, and only for a fighter on screen. Not re-verified by QA in play.
**Reopened 2026-10-02 (Orb, two screenshots on the live web build, both fighters tier 4).** The cloud gap with a lit edge still reads as a big glowing texture over each fighter in the clouds at high altitude (top right in the first shot, top left in the second), and as the fighter moves left and right the clouds shimmer. So the fix removed the pale pillar but not the complaint: a gap and lit rim that follow a fighter's direction across the sky are the problem, not the fill. Not verified in the current source (`render/shaders/sky.gdshader` at 8fd6aba still lights the clouds' edge round the gap, `tint` and `rim`); Orb's build may or may not include 8fd6aba. Options for the owners: drop the reaction (the feature is rule-of-cool 12 and was never in Orb's pitch list), make it a still, world-anchored effect that does not track a fighter (a fixed cloud parting that does not move with him), or fade it out above a height where it only shows as a patch; if it stays, put it behind a setting and `sky_calm`. Status: open, with Rendering and Game Design.
**Fixed again in 632f6c9** (Rendering, per the EP's status line): the sky reaction is off by default, plain clouds at every tier, and a cloud shimmer above 4,800 units is fixed. Not yet seen by Orb; QA has not re-verified in play.

### Open observations from Orb's two-player playtest (2026-10-02; direction in `docs/ep/vision.md`, last section)

Reported through the EP. QA has not reproduced or measured these; each has an owner. IDs follow GB-002.

| ID | Observation | Owner | Status |
| :--- | :--- | :--- | :--- |
| GB-003 | The split-screen camera jolts when a player is knocked away. | Camera | open, with Camera |
| GB-004 | A ranged attack press locks both fighters during the fly-in. Raised as a design question, not a fault. | Game Design | open, design call |
| GB-005 | Mountain tumbles gain too much momentum from a glancing bounce. | World | open, with World |
| GB-006 | A launched fighter flies at speed feet first, laid out along the flight line (Orb, 2026-10-02, a screenshot of VORR on the live web build: body horizontal, legs leading, a bright speed streak behind). Looks silly in motion | Animation (the `launch` body profile and spin, `anim_fighter.gd`), with Rendering (the pivot's rotation from `f.rot` and the pose) | **fixed in cce8a59** (a launched body flies head first once its spin dies; Animation's `lead_scan` guards it); not re-verified by QA in play |
| GB-007 | Levitating rocks stay fixed round a fast-moving tier 3 or 4 fighter: a few stay locked in a field round a standing fighter, and a fighter who crosses the screen quickly drags the rocks round his head along with him in the same relative position (Orb, 2026-10-02, a screenshot on the live web build). Expected: rocks float only while he is near the ground and still; in fast flight they should be left behind or gone | VFX / Rendering (`render/vfx/rocks.gd`: pieces are a function of the fighter's position and the clock, eased out over 0.5 s once he leaves the state) | open; QA has not reproduced it. By the header's own rule they should not show for a fast mover, so the likely cause is the 0.5 s ease-out running while he is already moving fast: a few pieces ride along; a shorter fade (or leaving the pieces in world space as he leaves) would fix it |

QA has no band for any of the three yet. For GB-005 the harness already counts bounces per bounced journey and journeys longer than 4,000 units (`5c.bounces`, `5c.long`); a per-journey momentum or speed-gain row would need a field from World's journey events. For GB-003 a camera-motion metric would need Camera's rig output; ask the EP when a band is wanted.

### GB-008: A launch (or a charge) clears a lock-broken fighter's flag without telling anyone

**Found by QA, 2026-10-03** while chasing a hard-test failure (`8.lock.max`: longest lock break 21.88 s over 747 breaks, c1714b5 default arm seed 46).
**Cause.** Lock breaks are `hidden` in the ESCAPE stance (`sim/core/hiding.gd`, `_lockBreak`); `regainLock` emits `found`, sets `lockBackT` (the 6 s no-rebreak guard) and clears the flag, within 4 s at most. Two other places clear the flag directly: `sim/director/launch.gd:316` (`tgt.hidden = false` when the lock-broken fighter is launched) and `sim/core/fighter.gd:319` (`f.hidden = false` when a hidden fighter starts charging). Neither calls `regainLock`, so no `found` event is emitted, `lockBackT` stays unset (the 6 s guard is skipped) and the harness' episode stays open until that fighter's next `found`. Probe on the c1714b5 export, seed 46 default arm: both fighters broke lock on the same tick (525.35 s, tick 34043); fighter 1 was launched at 526.88 s (tick 34138), 1.53 s into the break; the next `found` for fighter 1 came at 547.23 s. The real lock break lasted 1.53 s. Same chain for mirror-villain seed 181 (128 s) and seed 319 (49 s). On a56187a: swap seeds 350 (45.8 s) and 97 (16.1 s), mirror-villain seed 109 (209.8 s).
**Effect.** Event stream only: no `found` after a launch, and the 6 s rebreak spacing is not applied after a launch-ended break (the gap row passes anyway, 6.90 s). The default-arm row `8.lock.max` passes or fails by chance (a56187a baseline 4.02 s; two scratch variants showed 41.82 s and 20.77 s). QA now also reads all four arms (`8.lock.max.all`: 4 of 2,544 breaks over 4 s on a56187a).
**Fix, for Simulation or the Director's owner (two lines):** in both places call `SimHiding.regainLock(S, f)` when `f.hidden` is true, instead of clearing the flag. `8.lock.max.all` then passes with no harness change.
**Status: open, with Simulation.**

### GB-009: A brink fighter cannot be finished by a player who only fires bolts at range

**Found by QA, 2026-10-03** in the energy plan on a56187a (E3, E4, E5 of `qa/timing-edge.js`). A timed blaster (`tapper:energy=1`, a bolt about every 24 ticks) against a timed melee player: 40 of 40 matches reach the 900 s cap (E4, E5), and a probe of four matches with and without the stick-up on heavies does the same. In the traced match the melee player reached the brink at 222.7 s (`brink_enter`, `last_stand_ready`, `last_stand_end` expired at 242.7 s) and then flew off; the blaster hit it about 2,100 times a match (72,000 damage) and no finisher ever started, because bolts do not open one.
**Not the same as** the "bolt-only cannot finish" finding of the energy baseline: E1 (a bolt-only masher against a melee masher) finishes 40 of 40, because the melee masher closes in and ends up in a finisher; E2 (against the medium AI) wins 57.5%, above its 20 to 40% band.
**Question for Game Design / Combat:** should a brink fighter be finishable by blasts alone (a last blast at the brink, a charged shot, a signature)? If not, the E4/E5 script needs to close in for the finisher, and QA will add a `chase` option to the scripted players; the band for E5 (40 to 60%) cannot be measured until one of the two happens.
**Status: open, design call.**

---

## Not checked yet

Combat's CC-007 to CC-013 and Game Design's other notes were not in this brief. CC-009 (a dodge parry window that can never parry) and CC-010 (signature never parries) would be quick to confirm. Add entries here as KB-007 onward and add a matching check to `qa/tests/known-bugs.test.js`; the last check in that file fails until you do.
