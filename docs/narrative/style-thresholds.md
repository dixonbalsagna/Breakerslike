# Style labels: thresholds, hold times and the mixer

Owner: Narrative and Fighter Identity. Version 1, 2026-09-30. Answers Simulation's plan (`docs/architecture/mood-style.md`, section 5 and section 8's request). The data draft is `style.draft.json` (the shape of `data/fight/style.json`). Game Design owns the final numbers and Tools owns the schema. Names are placeholders.

**What the labels are for.** They key the dialogue director's style-reactive lines (`dialogue-director.md` section 8.2, `skeletons-protagonist-v-anti-hero.md` section 3) and the fight director's reaction. A label that flickers would make a fighter think "Only a little longer..." and boast three seconds later, so the design is built to be **stable**.

**Hider is dropped** (hiding is removed), so there are six labels plus a style shift: `turtle`, `rusher`, `runner`, `charger`, `sniper`, `mixer`.

## 1. The thresholds and hold times

Evaluated at 1 Hz on the 60-second window. Integer cross-multiplication, so "share above 55 percent" is `100 * part > 55 * whole`. `stanceTotal` is the sum of the four stance tick counts, and the attack total is light plus heavy plus signature.

| Label | Measure | Enter when | Hold to enter | Leave when |
|---|---|---|---|---|
| `turtle` | Defensive share of stance time | above 55% | 45 s | below 45% for 5 s |
| `rusher` | Aggressive share | above 60% | 20 s | below 50% for 5 s |
| `runner` | Evasive plus escape share | above 50% | 20 s | below 40% for 5 s |
| `charger` | Charge time as a share of stance time | above 20% | 15 s | below 12% for 5 s |
| `sniper` | Signatures as a share of attacks, with at least 4 attacks in the window | 35% or more | 20 s | below 25% for 5 s |
| `mixer` | see section 2 | see section 2 | 30 s | any other label enters, or the largest stance share exceeds 50% for 5 s |

The gap between the enter and leave thresholds (10 percentage points, and 8 for the charger) is the hysteresis. The hold-to-enter time stops a brief spike from labelling anyone. The leave time stops a brief dip from unlabelling them.

## 2. The mixer's definition

A **mixer** is a fighter who uses many stances and a spread of attacks, with no dominant habit. On the window:

1. **No dominant stance:** the largest stance share is at most 40%.
2. **A real spread:** at least three stances each have a share of 15% or more.
3. **A spread of attack kinds:** at least 6 attacks in the window, and no attack kind (light, heavy or signature) above 70% of them.
4. **Hold:** all three for 30 s to enter.

It leaves when **any other label enters**, or when the largest stance share goes above 50% for 5 s (the fighter has settled into a habit). This replaces the plan's "none of the above and no stance above 40%", which would have labelled a fighter with three stances at 34%, 33% and 33% as a mixer but also one who spent 40% in one stance and 60% split with a single attack kind. The new definition makes the mixer a real variety, not a leftover.

## 3. Stability rules added

| Rule | Value | Why |
|---|---|---|
| `minWindowFillS` | 30 s | The window is too thin before 30 s, and shares swing wildly. No label is evaluated until then. |
| `shift.minGapS` | 20 s | A style shift event fires at most once per 20 s per fighter. The dialogue director gets a stable signal, and does not chatter. |
| `shift.refractoryAfterLeaveS` | 10 s | After a label ends, it cannot be re-entered for 10 s, so borderline play does not bounce. |
| `startUnlabelled` | true | A new match starts with no label, as the plan says. |
| Priority | turtle, runner, rusher, charger, sniper, mixer | If two qualify, the earlier wins. Turtle is first because a long guard is the strongest signal. |

## 4. How the labels behave in a match

| Label | Typical entry time in a match | What the fighter says (from the skeleton set) |
|---|---|---|
| `turtle` | After about 1:45 of constant guard | *Only a little longer...* |
| `rusher` | After about 1:20 of pressure | A boast about training |
| `runner` | After about 1:20 of retreating | A thought about escape |
| `charger` | After about 1:15 of charging | *Almost there...* |
| `sniper` | After about 1:20 of signatures | A watch-this boast |
| `mixer` | After about 1:30 of varied play | No style line; the fighter is unpredictable, and the other fighter's thought says so: *I can't read him.* |

The entry times follow from the hold times plus the time the window needs to fill. A typical match is 7 to 8 minutes, so a fighter can pick up two or three labels over a match.

## 5. QA bands (suggested)

| Band | Value |
|---|---|
| Label changes per match (median) | at most 4 |
| The shortest a label is held | at least 10 s |
| Unlabelled share of the match | at most 40% |
| Every label reached at least once across a batch | yes |
| A forced-vector test for hysteresis and dwell | Simulation's, as the plan says |

## 6. Differences from Simulation's section 5

- **Kept:** every enter threshold, hold time and leave threshold for turtle, rusher, runner, charger and sniper. I checked them against the dialogue lines and they are sound.
- **Changed:** the mixer's definition (section 2).
- **Added:** `minWindowFillS`, `shift.minGapS` and `shift.refractoryAfterLeaveS` (section 3), a minimum for the sniper's sample, and the QA bands.
- **Removed:** `hider` (hiding is removed).
