# Q10 slice: the transformation pace, the act rule and pausing set pieces

Owner: Simulation and Engine. Status: plan, docs only (2026-10-01), for my window after Encounter's step 2. It builds Game Design's questionnaire-10 rulings (`docs/design/spec-wounds.md` sections 8, 8b and 9). Four parts land in one slice with one golden regeneration.

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

## 5. Order of work and proof

1. **Neutral code.** `chargePerSec` as data at 9.0, the act rule behind `formSteps: false`, `SimPause` with no caller. Parity passes on the untouched goldens.
2. **Hash** `S.pause`, and the parity checks: forced pause requests (each version, the bank's accrual and cap, the gaps, the time cap, two requests on one tick, a pause over a hit-stop, a replay through a pause).
3. **The data flip:** the ladder numbers, `formSteps: true`, QA's values. One golden regeneration.
4. **Batch of 100** for Game Design's targets: form steps at 1:15 to 1:45, 2:45 to 3:45 and 4:30 to 5:30; acts 2, 3 and 4 with them; the mood's band shares.

Pauses appear in matches only when Encounter wires `_transforms`. That is one call in its file: by grant in my window, or in its next one.

## 6. Risks

- **The pace depends on the AI.** At 0.5 a second charging gives little, so an AI that charges for power wastes time. Encounter may need to retune when the AI charges.
- **Everything slows early.** Tiers arrive later, so damage and collateral fall in the first minutes; QA re-baselines length, collateral and the per-tier bands (spec-wounds section 8b, "Knock-on").
- **Wired-number probe seeds** tied to tier events will move, as with earlier retunes.
- **A skippable cinematic** (Camera's option) would need an input read on frozen ticks, which the sim does not do today. It is not in this slice.
