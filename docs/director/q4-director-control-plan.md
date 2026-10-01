# Plan: the director takes the timing (Q4)

> **Revised by ADR 0008** (the control scheme, 2026-09-30): see `control-scheme-plan.md`. Checkpoint A (the attack clock) is now the AI's policy only, and B (parry by state) is replaced by the perfect block. C (struggle by state), D (acts and mood), E (the tutorial), the variety checkpoints and the event shapes below stay.

Owner: Encounter Systems Director. Status: plan only, no edits. It follows the dynamic-feel slice, which is not yet applied.

Inputs:
- `docs/design/stance-matrix.md` §4b: R9, R4 and R5, plus R2, which the sim doesn't have yet;
- `docs/design/spec-wounds.md`: the finisher row and §9 (acts and mood);
- `docs/design/tutorial.md`;
- `docs/controls/intent-queue-plan.md`;
- `docs/ep/vision.md`, questionnaire 4.

**The principle.** The player sets stance, weight, charging, transformations and specials. The director decides when every fighter attacks, chains, parries and survives, the human's fighter included. The AI then differs from a human only in how it picks stance and weight, because both fighters go through one timing path. With no timing presses left, **everything the rival intends must telegraph**, so each sub-slice lists the events it adds.

## Checkpoint order, with Combat's variety pass

Combat's variety pass (`docs/combat/variety-pass.md` §5, `data/combat/styles.json`) answers Orb's questionnaire-4 asks: cleaner combos, teleport clashes, flying and ground styles, blasts and varied beam struggles. It goes early, so Orb sees it.

| # | Checkpoint | Combat §5 rows | Visible result |
| ---: | :--- | :--- | :--- |
| 0 | The dynamic-feel slice (committed, da5fb09), then the k retune after QA's damage-rate measurement. **If civilians lost stays under 25% after k**, strengthen the villain's pull toward settlements at tiers 3 and 4 inside the personality-weighted targeting (the launch planner's care term, and the villain AI's movement). This is Game Design's first lever before any budget change (`balance-targets.md` §4b) | | The pace Orb liked; collateral back in its band |
| 1a | **D1a follow-ups** (roster as data, 806d58a), each unpinning one value in Simulation's loader: the finisher is selected by `W.finisher`, replacing `data.gd`'s `byFighter` name lookup (it also fixes mirror arms falling back to the generic finisher); and `HEAD_PARRY_NARROW` (`melee.gd`), `HEAD_DEFENCE` and `LEGS_SLIP` (`data.gd`), and `STAGE_AT` and `FADE_HIDDEN_FLOOR` (`ai.gd`) are read from `f.wd`. B later replaces the parry narrowing with R5's −10 | | None (bit-identical with today's roster data) |
| 1 | **V1, ground and aerial styles:** the style applier, `rush` `arc`/`offY`/`ground`, and `strike` `kbMul`/`crater` | 1, 2, 5, 9 | Exchanges fly arcs, or brawl along the ground with skids and craters |
| 2 | **A, the attack clock, with V2 blink clashes and clean chains:** R9 cadence and weight, chains by `chainP` (blitz at the first window, fixed link gaps, an ender with no window after it), and the `blink` op | 3, 6, 9 | Teleport clashes; chains that flow without press pauses |
| 3 | **V3, volleys:** the `volley` op (scheduled arrival strikes that can't be parried, and render-only projectile fx) | 4, 9 | Energy blasts |
| 4 | **B, parry, counter and clash by state, with V4 beam-clash shapes:** R5 and the clean parry; R4 from `selectorByProfile` with `defHeld`; the clash score from `styles.json`; shape pick and resolve (deflect, split, mutual blast) | 7, 10, 12, 9 | Varied beam struggles |
| 5 | **C, the struggle by state:** finisher `kind` on `finisher_start`, the `byState` draw at `contestOpen`, and the pulses | 11 | Readable finishers |
| 6 | **D, acts and mood:** styles, `chainP`, blitz and beam shapes read act and mood (M1). Until M1 lands, momentum from decisive results stands in | 8 | Escalation |
| 7 | **E, the tutorial rival and beat runner** | | Onboarding |

Notes:
- **The composition stream.** A keyed, stateless draw per exchange and slot (`procedural-moves.md` §10), so adding a style changes only the exchanges it could apply to. Simulation provides it in D1a, before Q4: `S.dirS.exN`, `ex.n` (set in `requestAttack`) and a stateless `SimRng.keyed(seed, key, n)`. Composition draws use `keyed(seed, "compose", ex.n)`, plus `ex.combo` for chain links, and never touch `S.rng`.
- **Row 9 in every checkpoint.** Every new beat emits a `cue`, and the new cue names go in the fx hash map.

### Rendering's event fields (`docs/rendering/variety-cues-plan.md`)

| Cue | What the sim emits | Checkpoint |
| :--- | :--- | ---: |
| `tell_light`, `tell_heavy` | the existing `attack` event (actor, kind) | now |
| `finisher_tell_launch`, `_melee`, `_beam` | `finisher_start` with `kind` (actor, target, dur, kind) | 5 |
| `struggle_hold`, `struggle_slip` | `struggle_open {actor}` at `contestOpen`, then `struggle_pulse {actor, n, state}`, n 1 to 3, state HOLDING or SLIPPING (UI's spelling, `hud-spec.md` §18). It carries the pulse index a plain `cue` lacks | 5 |
| `blink_out`, `blink_in` | `blink_out {actor, x, y}` and `blink_in {actor, x, y}`, with the slot as `actor` (like `damage` and `tier_up`) and the departure or arrival position, emitted **in the tick the position jumps** (agreed with Camera, VFX and Rendering: `docs/camera/blinks.md`). From out to in takes 6 ticks at most; a longer gap in Combat's data gets flagged | 2 |
| `blink_meet` | `blink_meet {actor, target, x, y}`: both slots, and the contact point, in the tick both fighters arrive | 2 |
| `chain_ender` | `chain_ender {actor, x, y, n}`: the attacker, the contact point and the chain count | 2 |
| the clash shapes | `game.clash.shape` and its keyframes in state, set when the shape is picked: the seesaw reversal times, the deflect time and direction, the split time and angle, the mutual detonation time. Plus a `clash_shape {shape}` event at the pick | 4 |

## Sub-slices (each is a checkpoint: goldens, feel probe, tempo, QA bands)

### A. The attack clock (R9), for both fighters
- **New `sim/director/cadence.gd`, fed from new `data/director/cadence.json`.** Once per tick, per fighter, it decides when to call `requestAttack`. The timing logic in `ai.gd` moves here (the attack timer, `P_ATTACK`, `CAD_MIN`, the lull urge, the refused-press waits); `ai.gd` keeps movement, stance and weight choice.

  | Stance | When the clock fires |
  | :--- | :--- |
  | AGGRESSIVE | The fastest cadence (the dynamic slice's 0.5 to 1.2 s), and chains most readily |
  | DEFENSIVE | Mostly a punish: an attack inside R2's 0.6 s window after its guard absorbed an exchange, plus rare pokes |
  | EVASIVE | After a dodge or a read it won, plus occasional pokes |
  | ESCAPE | Hit and run only when the opponent has committed (just released from its own exchange, charging, or down); otherwise it disengages |

- **What the clock fires.** The fighter's **sticky weight**: light or heavy, starting in light. A **queued signature** fires instead at the next opening once ki reaches 45, within **180 ticks** at most (R9 answer 4). It falls back down the ladder when ki is short, with a visible mark.
- **Charging and specials pause the clock** until they end.
- **The signature cooldown** (questionnaire 5): 120 s per fighter after a signature fires (`sigCooldown`, data; see `location-variety-plan.md` for where it lives). The clock won't fire or queue a signature until it has passed. That sets the 2 to 4 signatures a match, and QA adds a "signatures fired" row.
- **Chains become the director's call.** At each chain window, one draw against `chainP(stance, ki, mood, combo)` from data. It replaces the attacker's press, and the AI's press draw becomes this draw.
  - Heat (R9, ruled): only a fighter with the heat track (today the Protagonist) gets +5 points at Heated, +10 at Simmering and +20 at Boiling.
  - chainP is capped at 0.8. The chain limit stays 5, and each link still costs 6 ki.
  - Other fighters use their own hooks, with no heat input: Drop the Act raises the Anti-hero's limit to 6.
- **R2 comes in with this sub-slice:** the attacker-stance multipliers and the ×1.3 DEFENSIVE punish. The DEFENSIVE cadence needs the same window.
- **Events:**
  - `weight_set {actor, weight}`;
  - `sig_queued {actor, state}`, with state queued, fired, fallback or expired;
  - `stance_set {actor, stance}`, the rival's stance read, where UI needs an edge rather than polling state.
  - `blitz {actor, band, act}` when the director opens a chain as a blitz at the first window, with the current mood band (Calm, Tense or Frenzied; the momentum stand-in until M1) and act. It is for QA's blitz band: 2 to 6 a minute in Tense and Frenzied.

  Controls' `press_ack` is theirs.

### B. Parry, counter and clash by state (R5, R4)
- **The parry is one draw** when the window opens (`opWind`), in the four parryable templates:
  - base: DEFENSIVE 25%, AGGRESSIVE 15%, EVASIVE and ESCAPE 0%;
  - modifiers: a heavy +10; a battered head −10, which replaces the 20% window narrowing; ±5 per tier of difference; 50 ki or more +5; a Boiling attacker +5.

  Heat (Game Design, 7e87793): +5 against a Boiling attacker, and −5 when the defender is a Protagonist at Simmering or Boiling.

  On a parry, the counter beat is scheduled at the first parryable strike. `window_open` and `danger` stay as the tell, and the parry ring and counter beat stay visible. The press-timing code goes: the buffer, clean ticks and the AI press delay.
- **The clean parry is a perfect read, decided by state.** It happens when the defender held the parrying stance for 2 s or more at attack start and has 50 ki or more. It adds a riposte launch and +8 ki. QA band: 20 to 40% of parries are clean.
- **The hold timer** (Game Design's ruling): continuous time in the current stance, counted inside exchanges too, and read at attack start with R8's snapshot. A change mid-exchange doesn't affect that exchange but restarts the timer. It serves the clean parry and R4.
- **The counter (R4).** PRESSURE's counter branch runs at 50% when the defender held DEFENSIVE for 2 s or more with more than 25 ki, and 20% otherwise. That is a data condition in Combat's selector; I supply `defHeld` and `ki` in the plan context. It needs a per-fighter `stanceT`, the time the stance was last set (Simulation, `state.gd` and the hash).
- **Beam clash:** CLASH when the defender is AGGRESSIVE with 40 ki or more (Combat's beam rule), resolved as today by tier, ki and meters.
- QA band: 5 to 15 parries per 100 melee exchanges.

### C. The finisher struggle by state, with a telegraphed kind
- **Each finisher gets a kind:** launch, melee or beam (Combat, `finishers.json`). `finisher_start` gains `kind`, and the finisher's wind-up cue carries it, so the counter stance is readable.
- **The chance is computed and drawn once at `contestOpen`:**
  - base 15;
  - +15 for the matching stance: DEFENSIVE against a launch finisher, EVASIVE against a melee one, AGGRESSIVE with 40 ki or more against a beam one; +5 for any other stance;
  - +5 at 50 ki or more;
  - heat: +5 at Simmering, +10 at Boiling (this folds in the old +10 "Boiling on the brink");
  - the other fighter-state bonuses: hooks keyed by roster data, active once F1's fighters exist;
  - −10 per Rally, and −10 per minute past 8:00.
- **`struggle_open {actor}`** is emitted at `contestOpen`. **The three pulses** at the contest's beat ticks emit `struggle_pulse {actor, n, state}`, with state HOLDING or SLIPPING. The sequence depends only on the drawn result and the margin, so it reveals the outcome step by step without another draw. `struggle_press` retires.

### D. Invisible acts and the fight's mood (§9)
- **The act** is 1 + region breaks + transformations (both fighters, counted as events), capped at 4. Each act makes the clock 10% faster and raises the weights for blitzes, long launches, beam struggles, teleport clashes and set pieces, within the tier caps.
  - Event: `act_change {act}`, for Audio's music layer, Camera's stance and Narrative's bark density.
- **The mood (0 to 100)** is a 10 s moving average in director state.
  - Raised by: strikes landed, clashes, breaks, launches through buildings, collateral and taunts, faster under AGGRESSIVE.
  - Lowered by: decay, and long DEFENSIVE or ESCAPE stretches.
  - Bands: Calm below 30, Tense 30 to 70, Frenzied above 70.
  - Events: `mood_band {band}` on each crossing, and the value in state for crowds, audio and UI.
- **The aggression scalar** (Game Design, 7e87793). The act and the mood combine into one match-wide permille value, which Simulation's M1 produces:
  - 1000 + 100 × (act − 1) + 0, 250 or 500 for Calm, Tense or Frenzied, at most 1,800;
  - it divides the clock's intervals and multiplies the blitz chance;
  - it stacks multiplicatively with the stance cadence (R9) and personality.

  The director reads it and doesn't compute it, so the per-act 10% and Tense's +25% above are this one scalar.
- **Blitzes and teleport clashes** are Combat's templates. The director only selects them, by mood and act.
- QA bands: Frenzied at most 25% of the time; Calm at least 15%; 2 to 6 blitzes a minute while Tense or Frenzied.

### E. The tutorial rival and beat runner
- **A rival profile in data** (the same AI path, different numbers). It:
  - keeps a slow cadence and holds each stance for at least 3 s;
  - always telegraphs its weight and finisher kind;
  - steers toward beats 3, 5 and 8 until they happen;
  - stops at the brink for beat 8 and never finishes the player.
- **A deterministic beat runner** (`sim/director/tutorial.gd`, `data/director/tutorial.json`) reads the existing events and emits `tutorial_beat {id, state}` and `tutorial_hint {id, text_key}` (UI's spec, `hud-spec.md` §19). Ids look like `b3`; text keys are `b3.hint`, `b3.alt0`, `b3.nudge` or `b3.done`. Hints repeat after 20 s without the action.
- QA's bot playthrough ticks every beat.

## Needs from others (through the EP)
1. **Simulation and Controls:** the intent-queue Stage A:
   - `SimIntent` edges become a weight latch and a one-shot signature slot on the fighter;
   - `control()` stops calling `requestAttack` from presses;
   - a `stanceT` field;
   - hashing for all three.
2. **Combat:**
   - finisher kinds;
   - the R4 counter condition in PRESSURE's selector;
   - the beam CLASH rule from state;
   - blitz and teleport-clash templates;
   - `chainP` numbers, if Combat wants them in its data rather than mine.
3. **Game Design:** all answered (7e87793 and R9) and folded in above: the clean parry, heat, the aggression scalar, the hold timer and chainP's heat input. The mood's per-event weights are in M1.
4. **Simulation:** M1's aggression scalar, and heat stages readable by the director.
5. **Thought barks:** they carry `display: {style, dur_s}` for UI. The dialogue director emits them, and it stays read-only to me. If any bark passes through a director event, I add the field.
6. **UI and Rendering:** consumers for `weight_set`, `sig_queued`, `stance_set`, `finisher_start.kind`, `struggle_open`, `struggle_pulse`, `act_change`, `mood_band` and the tutorial events.

## Risks
- **Responsiveness.** A player whose attacks the director times may feel unheard. The weight press must acknowledge within 2 ticks, and AGGRESSIVE must feel immediate: the dynamic slice's release to request is 0.93 s, and Tense brings it to 0.6 s.
- **Rebalance.** Parry rates move from timing to state, the AI's press advantage disappears, and match length moves again. The k retune from the dynamic slice should land first, then these, one sub-slice at a time.
- **Telegraph debt.** If a consumer is missing, the read is invisible. QA can assert that every attack, parry and finisher is preceded by its tell event.
