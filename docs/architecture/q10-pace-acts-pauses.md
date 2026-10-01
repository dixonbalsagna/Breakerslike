# Q10 slice: the transformation pace, the act rule and pausing set pieces

Owner: Simulation and Engine. Status: plan, docs only (2026-10-01), for my window after Encounter's step 2. It builds Game Design's questionnaire-10 rulings (`docs/design/spec-wounds.md` sections 8, 8b and 9). Six parts land in one slice with one golden regeneration (the first four from the brief, the last two added by the EP on 2026-10-01).

## 1. Charging becomes data

- **Today:** `sim/core/fighter.gd` adds `9.0 * dt` power while charging. The fill (`fillPerSec`) and the thresholds are already in `data/fighters/<id>/ladder.json`.
- **Change:** a new key `chargePerSec` in `ladder.json`, read into `LadderDef.charge`, used in place of the 9.0.
- **Values (Game Design):** `chargePerSec` 0.5, `thresholds` 30, 65 and 100, `fillPerSec` 0.05, for both fighters.
- **Wired-number check:** a forced probe for `chargePerSec` beside the one for `fillPerSec`.
- **Schema:** `fighter-ladder.schema.json` gains `chargePerSec` (Tools, same commit).

## 2. The act rule

- **Today:** `SimMood.act(S)` is `min(max, 1 + beats)`, where `beats` counts every region break and the three once-per-match wound beats. Nothing calls the form beat, so transformations do not move the act yet.
- **New rule:** `act = min(max, 1 + larger of (form steps, wound beats) + region breaks)`.
  - *Form steps:* the most ladder steps any one fighter has taken, `tier - 1`, from 0 to 3. It is read from the fighters, so it needs no new state.
  - *Wound beats:* the count of bits in `onceMask` (exists), from 0 to 3.
  - *Region breaks:* `beats` keeps counting them and nothing else.
- **State and hash:** no new field. `beats` changes meaning (breaks only). `act_change` keeps its `cause`; a form step reports `form`, through a call from `SimFighter.tierUp` into `SimMood`.
- **Data:** `mood.json`'s `actBeats.every` becomes `["regionBreak"]`, and a new key `actBeats.formSteps: true` switches the form track on. With it false and `form` absent, the rule is today's. Tools' `fight-mood.schema.json` takes the key in the same commit.
- `SimMood.act(S)` stays the one source of truth. Whatever reads the act (the act-1 damping, the crippling moment's late bonus, the mood floors, aggression) follows without change.

## 3. Pausing set pieces

**A pause is a match rule in the sim:** integer ticks, hashed, the same for both players and in a replay.

### How I would build it

A new module `sim/core/pause.gd` (`SimPause`) and a state record `S.pause`. `SimCore.step` checks it first, before the hit-stop:

```
S.tick += 1
if S.pause.left > 0:            # a pausing set piece is running
    S.pause.left -= 1
    S.pause.total += 1
    tickMark(frozen)            # as a hit-stop tick: no input consumed, S.T does not advance
    if S.pause.left == 0: emit pause_end
    return false
if S.dirS.stop > 0: ...         # the hit-stop, as today
```

- A paused tick is a frozen tick, exactly like a hit-stop tick: the match clock (`S.T`), every cooldown, both fighters, the director, the water and the mood all stop, because none of them runs. A hit-stop that was running resumes after the pause.
- The recorder and the replay need no change: they already step through frozen ticks.
- The 11:00 event, the overtime ramp and the batch's time cap read `S.T`, so they do not count paused time.

**State (`S.pause`, all integers, all hashed):** `left` (ticks left), `kind`, `version`, `actor`, `bank` (ticks), `acc` (the bank's accrual remainder), `sinceEnd` (live ticks since the last pause ended), `seen` (a bit per slot and kind: its first set piece has played), `total` (ticks paused this match, for QA's band).

**The bank.** It starts at 3 s (180 ticks). Each live tick adds `gainPerMin` to `acc`; every 3,600 in `acc` adds one tick to the bank, up to 6 s. That is exact in integers for any gain.

**One entry point:** `SimPause.request(S, kind, slot, final = false) -> Dictionary` returns `{version, ticks}` and starts the pause when the version pauses. The caller applies the gameplay effect itself, on the same tick, whatever the version.

| Version | Length | Chosen when |
| :--- | :--- | :--- |
| Full | 3 s (a final-form reveal: up to 4 s, `final`) | The slot's first set piece of this kind, the bank covers it, and 20 s of live time since the last pause |
| Short | 1.5 s | Otherwise, if the bank holds 1.5 s and 8 s have passed since the last pause |
| Live | 0.8 s, no pause | Otherwise. Nothing is spent; the caller plays today's uninterruptible burst |

- A request is never refused: only the version changes.
- The time-cap kind always pauses for 4 s and spends nothing from the bank.
- Two requests on one tick: the director calls in slot order, so the lower slot gets the pause and the second finds 0 s since the last pause and plays live.
- **Data:** `data/fight/pause.json` (bank start, gain, cap; each version's length, bank need and gap; the time-cap length), with a schema from Tools and its hash in the replay header.
- **Events:** `pause_start {kind, actor, version, dur}` and `pause_end {kind}`. `transform` gains `version`, and its `dur` is the version's length.

### What the others must call or read

- **Encounter** (`sim/director/exchange.gd`, its file):
  - in `_transforms`, call `SimPause.request(S, SimPause.TRANSFORM, slot)` where it uses the fixed 0.8 s hold today. On full or short the pause is the cinematic; on live it keeps today's hold. The tier-up, the push-back and the `transform` event happen on the request tick in every version;
  - at the 11:00 event, call `SimPause.request(S, SimPause.TIMECAP, -1)`;
  - both of those calls are granted to me for this slice, and Encounter reviews. The two survival lines of section 4b are in the same file; I take the EP's brief as their grant and will confirm it when the window opens;
  - keep its own guard that no transformation starts during a finisher;
  - decide whether a short hold follows a pause. I assume none.
- **World**, later: a world-changing ability calls `request(S, SimPause.WORLD, slot)`.
- **Camera:** calls nothing. It reads `pause_start` (the kind, who, which version and how long) and plays its shot in real time for that length. `SimCore.step` returns false throughout, and `S.pause.left` counts down.
- **Rendering and VFX:** a paused tick is marked frozen like a hit-stop tick. If particles should keep moving in a cinematic, they read `S.pause.left` to tell the two apart.
- **Controls:** the host keeps its presses through frozen ticks today, which suits a hit-stop of a few frames. Over a 3 s pause it would release a pile of buffered presses at once. I suggest the host drops edges during a pause and re-reads holds when it ends; that is Controls' rule, and the sim only needs to expose which kind of frozen tick it is.
- **UI:** the match clock is `S.T`, which stops by itself.
- **QA:** `batch.gd` reports paused seconds per minute (the hard band is 2.5), the longest pause, the count of each version, and the median time of each fighter's first, second and third form step.

## 4. QA's tuning data

Final (`docs/qa/tuning-m1b.md`), data only, applied as the data flip's starting point:

| File | Change |
| :--- | :--- |
| `data/fight/mood.json` | `rates.decay` 4 to 3; `actFloors` [0, 600, 1500, 2400] to [0, 600, 1800, 2700] |
| `data/fight/style.json` | Narrative's revision 3 (`docs/narrative/style.draft.json`), as it is |
| Both fighters' `wounds.json` | `act1Damping` 0.85 to 1.30; `wearPerDamage` 270 to 216 (k 0.036); `cripple.base` 0.048 to 0.036 |

None is a pinned constant in `wounds.gd`, and none touches `data/combat`. QA tuned these on today's ladder; this slice slows the ladder and changes the act rule, so QA re-tunes on the slice's commit.

## 4b. Finisher survival is 0 from 11:00

- **Rule (spec-wounds section 5, a hard test):** once the time-cap event has set `S.game.timeCap`, the finisher contest's survival chance is 0.
- **Where:** both contest paths in `sim/director/exchange.gd` (the legacy contest and the branch-mode contest). They are Encounter's lines (see section 3 for the grant): after the chance is computed, `if S.game.timeCap: chance = 0.0`. The draw from `S.rng` stays, so the stream does not shift.
- **Rally:** Second Wind fires on a survived contest, so it cannot fire there either. No change in `wounds.gd`.
- **Test:** a forced parity check: with `timeCap` set, a contest reports chance 0 and the fighter falls, with and without a struggle.

## 4c. Form steps are per-fighter data, each marked pausing or live

- **Data:** `ladder.json` gains `stepKinds`, one entry per threshold: `"pausing"` or `"live"`. The placeholders use three pausing steps.
- **Sim:** `SimPause.request` takes the step's kind from the fighter's `LadderDef`. A live step always plays the live version and never draws on the bank or sets "first of its kind". A pausing step follows the table in section 3.
- **The count stays three for now.** The loader requires three thresholds, because the tier tables (the beam block, the tier multipliers, the collateral allowances) are indexed by four tiers. A fighter with another count (the Empress's twelve revisions) needs those tables lifted, which is F1's work with the roster. `stepKinds` is shaped so that F1 only lifts the count.
- **Schema:** `fighter-ladder.schema.json` gains `stepKinds` (Tools, same commit).

## 5. Order of work and proof

1. **Neutral code.** `chargePerSec` as data at 9.0, the act rule behind `formSteps: false`, `SimPause` with no caller. Parity passes on the untouched goldens.
2. **Hash** `S.pause`, and the parity checks: forced pause requests (each version, the bank's accrual and cap, the gaps, the time cap, two requests on one tick, a pause over a hit-stop, a replay through a pause).
3. **The data flip:** the ladder numbers, `formSteps: true`, QA's values. One golden regeneration.
4. **Batch of 100** for Game Design's targets: form steps at 1:15 to 1:45, 2:45 to 3:45 and 4:30 to 5:30; acts 2, 3 and 4 with them; the mood's band shares.

The two `SimPause.request` calls in Encounter's file are granted to me for this slice (EP, 2026-10-01), so pauses appear in matches when it lands.

## 6. Risks

- **The pace depends on the AI.** At 0.5 a second charging gives little, so an AI that charges for power wastes time. Encounter may need to retune when the AI charges.
- **Everything slows early.** Tiers arrive later, so damage and collateral fall in the first minutes; QA re-baselines length, collateral and the per-tier bands (spec-wounds section 8b, "Knock-on").
- **Wired-number probe seeds** tied to tier events will move, as with earlier retunes.
- **A skippable cinematic** (Camera's option) would need an input read on frozen ticks, which the sim does not do today. It is not in this slice.

## 7. As built (2026-10-01)

**Code.** `sim/core/pause.gd` (`SimPause`: the data, `reset`, `liveTick`, `frozenTick`, `request`), `S.pause` (`PauseState`), the frozen-tick check at the top of `SimCore.step`, `LadderDef.charge` and `stepKinds`, `SimMood.act` with the form track and `SimMood.onForm`, `S.mood.breaks`, the events `pause_start` and `pause_end`, and `version` on `transform`. In Encounter's `exchange.gd`, by grant: the request in `_transforms` and at the time cap, and no survival from the time cap in both contest paths (the draw kept).

**Differences from the plan**
- `request` reads the step's kind from the fighter's ladder itself, so the caller passes only the kind of set piece and the slot. It must be called before the tier rises.
- On a full or short version the transformer has no hold after the pause; the live version keeps the 0.8 s hold (now `live.lengthS` in the data, the same 48 ticks).
- A slot's "first set piece of its kind" is used up by its first request, whatever version played.
- `act1Damping` may now be up to 2 (the loader and Tools' schema allowed at most 1; QA's value is 1.3).
- Found while building: the mood read every event still in `S.out.fx`, so its state depended on the host draining the list. It now reads only the current tick's events, and `SimReplay.play` drains the list. The goldens did not move (their host drains every tick).
- `sigCooldown` joined the arm recipes' character keys, so a swap arm carries it with the character.

**Proof**
1. *Neutral code:* with `chargePerSec` 9, `formSteps` false and pause data under which every version is live (bank 0, time-cap length 0), the wired calls included, parity passed every match and replay on the untouched goldens (9 matches, 183,650 ticks). Only the two data-hash checks failed, as expected with new keys in the data.
2. *The flip:* the ladder numbers, `formSteps` true, the pause budget and QA's M1b values; the goldens regenerated once (9 matches, 175,124 ticks).
3. *Gates:* parity (with the new checks "pausing set pieces" and "act rule and time cap", and a wired-number row for `chargePerSec`), determinism, seam sweep, `npm test`, the validator (49 files, 0 errors) and its self-test (831 of 831), the touch test and the loader check all pass.

**100 matches** (default arm, seeds 1 to 100, digest 8df758e150774748):

| | Result | Target or band |
| :--- | :--- | :--- |
| Form steps (median, per fighter) | 104 s, 215 s, 320 s; every fighter took all three | 75 to 105, 165 to 225, 270 to 330 |
| Acts 2, 3, 4 (median) | 101 s, 211 s, 316 s | 90 to 150, 150 to 240, 270 to 345 |
| Pauses | 0.93 s per minute; no match over 2.5; longest 4 s (the time cap) | at most 2.5 s per minute |
| Versions | full 105, short 339, live 156 | |
| Survived a finisher after the time cap | 0 | 0 (hard) |
| Length | median 601 s (p10 488, p90 671) | 6:00 to 8:00 |
| First brink | 543 s | 4:30 to 7:00 |
| KAI wins | 65% | 45 to 55% |
| Mood | calm 13%, tense 39%, frenzied 47% | 30 to 55, 35 to 60, 5 to 20 |
| Finisher survival | 13% | 25 to 40% |
| Rallies | 0.14 a match | 0.3 to 0.7 |
| Civilians lost | 22% | |

The pace, the acts and the pause budget land in their targets. The rest is out, as Game Design's "Knock-on" predicted and more: the slower ladder cuts damage, so matches run ten minutes, the first brink comes at nine, most finisher contests fall after 8:00 where the tilt has eaten the survival chance, and the long tail in act 4 with a decay of 3 keeps the mood frenzied. QA's M1b values were tuned on the old ladder; QA re-tunes on this commit.

## 8. The break: the tier-up moves to the end of the gather (plan, 2026-10-01)

Plan only, for my next turn in the sim slot, with QA's re-tuned values. It builds the EP's ruling on Game Design's staging (`moveset-rules.md` section 10.8): the burst, the crater, the power and size step and the `tier_up` event happen at the **break**, after the gather (60 ticks full, 24 short, 10 live). Today they happen on the request tick, at the start of the gather.

### How

**One pending break per fighter.** A new hashed field `Fighter.act.breakIn` (ticks until the break, -1 for none).

1. **The request tick** (the director, as today): `SimPause.request`, the `transform` event, the hold. `SimFighter.transform` no longer raises the tier: it clears `formReady` and sets `breakIn` to the version's gather.
2. **The count.**
   - *Full and short:* `SimPause.frozenTick` counts the pause's own fighter down. The pause is not split into two: the break is applied by the sim on a frozen tick inside it, and the rest of the pause runs on. A split with a live tick between would let the clock, the AI and the players' inputs run for a tick in the middle of a cinematic.
   - *Live:* `SimFighter.stepFighter` counts it on live ticks. The same rule serves the second fighter of two requests on one tick: its gather starts when the first one's pause ends.
3. **The break** (`SimFighter.formBreak`, at 0): the tier rises, then today's `tierUp` runs unchanged (the burst, the crater and area damage if he is near the ground, `tier_up`, the act's cause). If a further tier is already earned, `formReady` is set again and `transform_ready` is sent for it (this closes the gap I reported at I2b).
4. **The rival's push** is Encounter's and sits at the request today. Game Design puts it at the break ("the snap, with the burst that pushes the rival back"). I propose the core calls `DirExchange.formBreak(S, f)` at the break and Encounter moves its push there. The direction is the same as the core's existing calls into the director.

**A frozen tick now changes the world.** On a paused version the crater, the area damage and any building it fells happen on a frozen tick. That is deterministic and hashed like anything else. What it means for others:
- Rendering must not assume the ground and the buildings are unchanged while the sim is frozen.
- The mood does not tick on a frozen tick. Casualties still reach it (it reads the casualty total, not events). An event-driven impulse raised at the break would be missed; the only one that could matter is the landmark's fall, and it is dormant.
- If the match ends during a live gather, the break does not happen.

### The beat lengths: who owns them

- **The sim owns the gather**, because it now decides when the world changes. It goes in `data/fight/pause.json` as `gatherTicks` per version (60, 24, 10), inside the replay's data hash. Ticks, not seconds: 10 ticks is not a round number of seconds.
- **The sim already owns each version's total** (`lengthS`).
- **Break and settle stay Animation's** in `data/anim/forms.json`: they change nothing in the sim.
- **So nobody has to read two files:** the `transform` event gains `gather` (seconds), next to `dur` and `version`. And since `tier_up` now arrives exactly at the break, Animation, VFX and Camera can key the break on that event and not on a count.
- `forms.json` keeps its `gather` for now, with a cross-check from Tools that it equals `pause.json`'s and that gather, break and settle add up to the version's length. Dropping it later is Animation's call.

### Replays, the hash, the goldens

- **Replays:** the format and the inputs do not change. The data hash in the header changes (`pause.json` gains keys), so a replay recorded before this refuses with reason `data`, as after any data change.
- **Hash:** one new field, `act.breakIn`. `transform` gains `gather`. `tier_up` moves later by the gather, and on a paused version it is sent on a frozen tick.
- **Goldens:** regenerated once, in the same slice as QA's values. This is a behaviour change, not a neutral one: on the live version the tier (damage, speed, the act) arrives 10 ticks later, and on every version the crater and its water come in a different order against the request tick's other work.
- **Tests:** parity checks for the break at the right tick in each version (frozen ticks for full and short, live ticks for live), the second fighter's gather starting after the first one's pause, no break after a KO, and `transform_ready` for a further earned tier.

### Open points for the EP

1. Encounter: move the push to the break through `DirExchange.formBreak`, or keep it at the request?
2. Tools: `gatherTicks` in the fight-pause schema, and the cross-check with `forms.json`.
3. The mood's form impulse (+10 for a transformation, spec-wounds section 9) is in the data but no code gives it, today or before. It could be given at the break. It would raise a mood that is already too frenzied, so I would add it only if QA includes it in its re-tune.

## 9. The break and QA's re-tune, as built (2026-10-02, on 0886750)

One slice: QA's re-tune values, the tier-up at the break (section 8), a forced probe in place of the wired-number check's seeds, and Encounter's three `craterT` lines. Added by the EP while it was open: the mixer label's `maxStancePct` 45 to 50 in `data/fight/style.json` (Game Design, spec-wounds section 9: the AI sits at 45 to 55% press and almost never reached the label); the mixer was 0.1% of labelled time before and is 1.0% after.

**The break.** `Fighter.act.breakIn` (hashed). `SimPause.request` sets it to the version's gather; `SimFighter.transform` now only takes the ready form; `SimFighter.formBreak` raises the tier and runs today's `tierUp`. Full and short count on the pause's frozen ticks (`SimPause.frozenTick`), live counts on live ticks (`stepFighter`). The gather is `gatherTicks` in `data/fight/pause.json` (60, 24, 10), and the `transform` event carries it as `gather` seconds.

**Differences from the plan**
- Nothing in `sim/director` changed. The rival's push stays at the request; the hook `DirExchange.formBreak` was not added. Moving the push to the break is Encounter's to do.
- `SimFx.transform` looks the gather up itself from the version, so Encounter's call is unchanged.
- A direct call to `SimFighter.transform` with no request before it (the tests) breaks at once.
- While a taken step waits for its break, the fighter cannot become ready again; a further step already earned becomes ready at the break, with its `transform_ready`.
- The mood's form impulse is still not given by any code. QA's value (300) is applied, and it changes nothing until the impulse is wired.

**Proof**
1. *Neutral:* with every `gatherTicks` at 0 the break lands on the request tick as before, and parity passed all 9 matches (184,536 ticks) on the untouched goldens of 0886750. Only the fight-data hash failed, as expected with new keys.
2. *The flip:* the gather at 60, 24 and 10, and QA's values; the goldens regenerated once (9 matches, 177,656 ticks).
3. *Gates:* parity (with the new check "the break" and the forced end-to-end probe), determinism, seam sweep, `npm test` (5 stages), the validator (0 errors) and its self-test (965 of 965), the touch test and the loader check pass.

**The wired-number check** no longer plays matches. Its end-to-end row sets VORR's menace, has VORR attack KAI through the director, and compares what KAI took. `WIRED_SEEDS`, `WIRED_TICKS` and `_wiredRun` are gone.

**100 matches** (default arm, seeds 1 to 100, digest c41bcef3de76d062 with the mixer value; the fight rows are the same with and without it):

| | Result | Band or target |
| :--- | :--- | :--- |
| KAI wins | 45% [36, 55] | 45 to 55% |
| Length | median 450 s, p10 369, p90 589 | 360 to 480; p10 at least 300; p90 at most 600 |
| First brink | 391 s | 270 to 420 |
| Finisher survival | 25.4% | 25 to 40% |
| Rallies | 0.28 a match | 0.3 to 0.7 |
| Region breaks, limb breaks | 2.00, 0.48 (arms 56%) | 1.5 to 2.5, 0.3 to 0.5 |
| Mood calm, tense, frenzied | 41%, 53%, 6% | 30 to 55, 35 to 60, 5 to 20 |
| Frenzied in act 4 | 13.3% | at least 15% |
| Acts 2, 3, 4 | 103 s, 218 s, 322 s | 90 to 150, 150 to 240, 270 to 345 |
| Form steps | 106 s, 225 s, 339 s; the third taken by 188 of 200 fighters | 75 to 105, 165 to 225, 270 to 330 |
| Pauses | 1.08 s a minute; none over 2.5 | at most 2.5 |
| Civilians lost | 17% | QA's open question |

QA measured its values on 21390f6, before step 2b and before the break; it re-centres on this commit. What I see: the form steps sit at or just past the late edge of their targets, rallies and the frenzied share of act 4 are just under their bands, and collateral is low as QA's note says.

