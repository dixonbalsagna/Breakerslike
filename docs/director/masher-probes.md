# The masher: why QA's probe and mine disagree

Owner: Encounter Systems Director. Date: 2026-10-02. Measured on a clean copy of HEAD `24b9326` (step 3 live). No sim edits.

**The disagreement.** Against the medium AI, QA's masher (`qa/godot/masher.gd`) wins 0 of 40. Mine (the probe behind `control-scheme-plan.md`, "Step 3 as built") won 33 of 80. Game Design's band is 35 to 50%.

**The answer: transformations.** QA's masher presses light and nothing else, so it never takes a ready form and fights the whole match at tier 1. Mine also sent the transform input the tick a form was ready. The AI takes every form at once and ends a match at tier 3.7 on average. Nothing else matters.

## What each probe sends

| | QA's `masher.gd` | My probe |
| :--- | :--- | :--- |
| Attack | `light` as a fresh edge every 8 live ticks; a press that falls in hit-stop is kept for the next live tick | `light` as a fresh edge every 8 calls; a press that falls in hit-stop is lost |
| Movement | none | holds toward the opponent beyond 130 u |
| **Transform** | **never** | **`transform` whenever a form is ready** |
| Slot | alternates by seed (or `--slot`) | slot 0 |
| AI level | `DirAI.level`, set through the loaded script | `DirAI.level`, set directly |

The level is in force in both: QA's perfect-block rates differ by level as they should (5.9, 10.0 and 15.2 per 100), and its run at `--level=medium` is not reading hard.

## The test

40 matches each against the medium AI, seeds 1 to 40. Rows A to D are my probe with one thing changed at a time.

| Run | Moves | Takes forms | Wins | Tier at the end, masher / AI |
| :--- | :--- | :--- | ---: | ---: |
| A: my probe as it was | yes | yes | 19 of 40 | 3.60 / 3.67 |
| B | yes | **no** | 2 of 40 | 1.00 / 3.67 |
| C | **no** | yes | 23 of 40 | 3.75 / 3.83 |
| D: no movement, no forms, QA's press timing | no | no | 0 of 40 | 1.00 / 3.75 |
| QA's masher, slot 0 | no | no | 0 of 40 | |
| QA's masher, slot 1 | no | no | 0 of 40 | |

Movement, the press timing and the slot change nothing that shows. Taking forms is worth about 20 wins in 40.

The masher without forms still deals nearly as much raw damage as the AI (about 7,000 a match against 7,700). It loses because a tier-1 fighter takes a tier-3 fighter's blows.

## Which probe is the real player?

Both are faithful to what they script. They answer different questions.

- **QA's is the literal one-button player.** A beginner who only ever presses attack never transforms, because transforming is its own input: both triggers held for 0.5 s, or the ready icon on touch (`control-rules.md` §3). No layout takes a form for the player, and the Simple layouts' assists don't include it.
- **Mine is a masher who has learned one more input.** That is the player the band's numbers were written for, I think: the band text says "pressing light every 8 ticks", but 35 to 50% against the medium AI can't be met by a fighter who stays at tier 1 for seven minutes.

So the band needs its masher defined, and that is Game Design's call, not a probe fix.

## What I recommend

1. **Game Design rules what the band's masher does about forms.** Two honest options:
   - *The masher takes forms.* The band stands as it is, and QA's probe sends `transform` when `act.formReady` is set (one line). This is "mashing with the one prompt the game shows you".
   - *A beginner should not have to.* Then the Simple layouts need an assist that takes a ready form for the player at the next exchange boundary (an `autoForm` assist beside `autoBurst`; Controls' and Simulation's lines, and the director's placeholder transform already runs between exchanges). The pure one-button masher then rises with the AI and QA's probe needs no change beyond setting the assist.
2. **QA reports both rows** until that is ruled: the pure masher and the masher with forms. With forms, on this build: easy 20 of 20, medium 41 to 48%, hard 10%.
3. **Nothing in step 3 is too harsh for the masher with forms.** For the pure masher no AI tuning helps: it is a tier gap. I would not weaken the medium AI to let a tier-1 fighter win 35%.

For Orb's "mashing is fine for beginners": today a beginner who never transforms beats the easy AI three times in four and never beats the medium AI. If that is not what Orb wants, option two (the assist) is the fix.

## The limb breaks (QA's other row)

QA reads 0.62 limb breaks a match (band 0.3 to 0.5) with arms only 21.7% of them (band 35 to 65). 40 AI matches before and after step 3:

| Per match | Before step 3 | Step 3 |
| :--- | ---: | ---: |
| Damage from heavies | 4,868 | **7,709** |
| Damage from lights | 7,434 | 5,013 |
| Heavy damage to the legs | 1,835 | 3,344 |
| Light damage to the arms | 2,773 | 1,778 |
| Guard wear on the arms | 1,079 | 1,143 |
| Arms, share of limb breaks | 55% | 26% |

**Why.** Heavies wear the legs and the core, and lights the head and the arms. Step 3 made the AI's best openings heavies:
- the punish after a blocked string is a heavy at medium and hard (`punishHeavy` 1);
- the reversal starts a heavy;
- the riposte to a heavy or an ender is a heavy that launches (5 of the 19 breaks I counted came in a RIPOSTE, all legs);
- against a rival found guarding twice, 60% of its attacks are heavies (`breakGuard`).

Lights fell with it: TRADE BLOWS dropped from 12% to 7% of exchanges.

**The lever is data** (`data/director/ai.json`, mine): `punishHeavy` at 0.5 and `breakGuard` nearer the old 0.375 would move damage back to lights and the arms. It also moves the masher's win rate, so it wants one re-measure of both. A small slice when the slot is free; QA or Game Design should say which way they want it.
