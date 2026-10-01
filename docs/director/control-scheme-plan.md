# Plan: the director under the new control scheme (ADR 0008)

Owner: Encounter Systems Director. Status: plan only, no sim edits. It revises `q4-director-control-plan.md`.

**What ADR 0008 changes for the director.** Questionnaire 4 gave the director the timing: when to attack, parries and the struggle. Playtests said that took agency away. Now:
- an attack press is a request again;
- defence is held and timed by the player;
- four inputs act inside an exchange;
- the director choreographs what was asked and never adds a counter or a beam the player didn't call for.

**What happens to the old Q4 checkpoints:**

| Old checkpoint | Under ADR 0008 |
| :--- | :--- |
| A, the attack clock | **AI only.** Humans press |
| B, parry by state | **Replaced** by the perfect block |
| C, struggle by state | **Stays:** it is a state read, not a press |
| D, acts and mood | Stays |
| E, tutorial | Stays, retargeted to the new inputs |
| V1 to V4, variety | Stay, after the agency fixes |

## Part 1: agency fixes (they ship first)

### 1. Held stances, read at exchange start
- The four stance columns stay; their source changes from a stance key to what the fighter is doing when the request arrives (the R8 snapshot):
  - **Press:** it has an attack request pending or pressed within the window. This is AGGRESSIVE.
  - **Guard:** guard is held. This is DEFENSIVE.
  - **Dodge:** a dodge tap within its window. This is EVASIVE.
  - **Escape:** dodge held while moving away (sprint). This is ESCAPE.
- **A fifth state, Neutral** (nothing held), is new. It needs Combat's and Game Design's column. My proposal: the AGGRESSIVE templates with every defender-favoured branch removed, so it trades or gets hit and never counters.
- The hold timers Game Design already ruled (continuous time in the state, read at exchange start) carry over as `guardSince` and the dodge-tap tick.

### 2. Counters only when the stance calls for it; no automatic beams
- **Selector change (data, with Combat).** Each defender-favoured branch needs the input that earns it:
  - DODGE & COUNTER needs the defender's own queued attack; without one the dodge is a clean DODGE & READ;
  - PRESSURE's counter needs a perfect block or a reversal;
  - HEAVY CLASH — COUNTERED and TRADE BLOWS need the defender in Press.
- **Beams.** CLASH happens only when the defender itself requested a signature or an energy attack (Press in energy mode with the ki). Otherwise the outcome follows its state: Guard, Dodge, Escape or a hit. The director never fires a beam for a fighter.
- I supply the plan context flags (`defQueued`, `defMode`, `defPerfect`); Combat edits the selectors.

### 3. Attack requests: one press, one exchange; repeats queue a short combo
- A press is `{weight, mode, entry}`. The chain window's timed press goes.
- **The queue.** Presses made while an exchange runs go into a per-fighter queue (depth 2 or 3, data; Controls owns the buffer rules). At each chain point the next queued press becomes the link. An empty queue plays the ender.
- The cooldown and the "ready" rule stay: a press the director can't take yet waits in the queue, and is never lost or wasted.

### 4. Direction is the entry; mode is the family
- `entry`, from the direction held at the press, relative to the opponent:
  - toward: rush;
  - neutral: stand, which in energy mode is a blast from where it stands;
  - away: retreat, a backstep strike or a retreating shot.
- `mode` (physical or energy) picks Combat's piece family.
- Both go through the style applier's slots (old checkpoint V1), so the applier lands here with entry and family as its first inputs. Outcomes are untouched: the defender's state still picks them.

### 5. Interrupt windows
Four inputs act inside an exchange, each at a defined window. Costs, cooldowns and widths are data (Controls and Game Design).

| Input | Window | Effect |
| :--- | :--- | :--- |
| **Dodge cancel** (tap) | Any time in an exchange, for either fighter | The canceller's pending beats drop and it exits with a dodge move. Energy cost and a cooldown |
| **Perfect block** (timed guard tap) | Only during a visible wind-up (`window_open` kind block: the 15 and 20 tick windows) | The S3b parry: the rest of the exchange is cancelled and the reward paid. A mistimed tap still guards |
| **Burst** (tap) | While pressured: being hit or guarding in an exchange | A shove ends the exchange with both released apart. Energy cost and a cooldown |
| **Reversal** (context, in guard, close) | The guard-holds beats | The defender turns the exchange with a throw |

- Events: `window_open` gains the kinds block, cancel, burst and reversal; results are `dodge_cancel`, `burst`, `reversal` and the existing `parry` (with `clean`).
- Cooldowns live in fighter state for the HUD.

### 6. The AI uses all of it
- The attack clock (old checkpoint A) becomes the AI's own policy. It presses through the same intent path as a human: weight, mode, entry, queue depth.
- The AI also holds guard, taps dodge, sprints to escape and uses the four interrupts, with chances per difficulty. All of it is in a profile file (`data/director/ai.json`), which also holds the tutorial rival.
- Acts and mood (D) scale the AI's cadence through M1's aggression scalar, as planned.

### 7. The Simple layout's assists
For a fighter flagged `assist: simple` in the match setup (Simple controller layout and Simple mobile), the director chooses, deterministically from state:
- **mode:** energy at range, physical close, with hysteresis;
- **burst:** fired when pressured, off cooldown and affordable;
- **special:** which of the 3 loadout specials Power+Attack fires, by context.

`sim/director/assist.gd` and data. An `assist {actor, kind}` event lets UI show what it chose.

### Game Design's rulings (`stance-matrix.md` §7; `control-rules.md` §7 to §10), folded in

| Topic | Ruling | What it changes above |
| :--- | :--- | :--- |
| **Neutral** | It never trades. The outcome is CLEAN HIT ×1.0, or CLIPPED when the defender flies at over half speed across or away: the opener lands, the string ends, and there is no launch. A signature against Neutral is HIT | Replaces my §1 proposal. Two new branches for Combat's data; I supply the defender's speed and heading in the plan context |
| **`defQueued`** | A request no more than 20 ticks old, or one in the queue. It gates TRADE BLOWS, HEAVY CLASH and DODGE & COUNTER | §2 |
| **`defPerfect` or a reversal** | Gates PRESSURE's counter and DEFLECT. A perfect block on a signature is DEFLECT | §2 and §5 |
| **CLASH** | Needs the defender's own signature or heavy energy request during the beam's tell | §2: the request window is the tell, not "pending" |
| **R4 and R5** | R4's patience roll is withdrawn for humans. The AI keeps R4 and R5 as its skill model and pays the same costs as a human's inputs | §6: the AI's perfect blocks and counters are rolled by R4 and R5, then issued as inputs |
| **Dodge cancel** | The defender's works only in the gaps between strikes; the burst is the tool while being hit | §5: the cancel window is narrower than "any time". `window_open` kind cancel opens per gap |
| **AI beam answers** | 15, 35 and 60% by difficulty | §6, in the AI profile |
| **Simple layout** | A beam shows a prompt and is never answered automatically | §7: the assist does not auto-clash or auto-deflect |

### Combat's step-2 data (`docs/combat/control-scheme-data.md`): how it runs

- **Interrupts are branch takeovers.** A perfect block, a reversal, a dodge cancel and a burst arrive mid-exchange. Each branch carries an `interrupts` block. The director drops the branch's pending beats and schedules the interrupt's beats from that tick, as the finisher takeover does today.
- **The beam is decided at the fire beat,** from what the defender did during the tell: no answer, a signature, or a heavy blast. The beam's draws, its loser and its outcome move to that tick. A new `beam_outcome {actor, target, kind}` event carries the result, since the `attack` event at the request no longer can.
- **Plan-time flags I supply:** `defQueued`, `defMode`, `defPerfect`, `defClipped`, both fighters' entries, the queue length, the reversal request, and the defender's answer at the fire beat.
- **Needs:**
  - Exchange fields for the template and branch ids, two hashed strings (Simulation);
  - QA's parser reading `beam_outcome`;
  - a fixed precedence for two interrupts in one tick. My proposal: perfect block, reversal, dodge cancel, burst, with the defender before the attacker.

## Part 2: variety, then the rest
1. **Fewer beams, more ordinary blasts** (ADR item 9):
   - the 120 s signature cooldown (data, planned);
   - the `volley` op (old V3) moves up as the standard energy attack;
   - each fighter's own beam style (Combat and VFX).
2. **Blink clashes, clean combo enders and the beam-clash shapes** (old V2 and V4).
3. **The finisher struggle by state** (old C), **acts and mood** (old D), **the tutorial** (old E), and the D1a follow-ups.

## The placeholder transform (Orb: in the next build)
The smallest one that works is a **manual tier-up with a short set piece**:
- Today a fighter's tier rises by itself when its power meter crosses a threshold (`sim/core/fighter.gd`).
- **Change:** at the threshold, the tier-up waits. The fighter is **ready** (`transform_ready {actor, tier}`), with a HUD prompt.
- The transform input takes it: both triggers held for 0.5 s. The Simple layout uses Power held with nothing else for 0.5 s at full meter. The AI takes it at once.
- **The set piece (director):** between exchanges only. A 0.8 s hold: `transform {actor, tier, dur}`, the existing power-up burst (aura, ground crater, banner), and the opponent pushed back. No exchange can start during it.
- Then the tier's existing bonuses apply. No new form art, no surge yet, no per-fighter rules. Those come with F1.

**Events (I2):**
- `transform_ready {actor, tier, source}`: the fighter's power crossed the threshold for `tier`, and the tier-up is waiting for the input. `source` is the input that will take it: triggers (both held), power (the Simple hold) or ai.
- `transform {actor, tier, source, dur}`: the transform was taken. `tier` is the new tier, `source` the input that took it and `dur` the hold in seconds. The existing `tier_up` follows when the hold ends.

**Needs:**
- Simulation: one gate in the tier-up check and a `formReady` flag.
- Controls: the `transform` edge.
- UI and Rendering: the prompt and the hold.

## SimIntent fields needed (Simulation and Controls)

| Field | Kind | Replaces | Used for |
| :--- | :--- | :--- | :--- |
| `light`, `heavy` | edge | themselves; now requests into the queue | the attack weight |
| `mode` | state: physical or energy | new | the piece family (Simple: set by the assist) |
| `entry` | −1, 0 or +1 at the press: away, neutral or toward the opponent | new (from `mx` and the opponent's side) | the entry |
| `guard` | held | the DEFENSIVE stance key | the Guard state |
| `guardTap` | edge | the old parry press | the perfect block |
| `dodge` | edge | the EVASIVE stance key | the Dodge state and the dodge cancel |
| `sprint` | held (dodge held and moving away) | the ESCAPE stance key | the Escape state |
| `burst` | edge | new | the burst |
| `context` | edge | new | grab, reversal, deflect, tackle and the fallback, by priority |
| `power` | held | `charge` | charging on release; the power layer |
| `special` | edge, 0 to 2 (with `power`) | new | loadout specials |
| `sig` | edge (with `power`) | itself | the signature |
| `transform` | edge (both triggers 0.5 s) | new | the placeholder transform |
| `stance` | | **removed** | |

**Fighter state** (Simulation, hashed):
- the request queue;
- `guardSince`;
- the last dodge tick;
- `dodgeCool` and `burstCool`;
- `mode`;
- `assist`;
- `formReady`.

**Agreed record (Simulation, `docs/architecture/intent-v2.md`).** Three differences from the table above:
- there is no `entry` field: it is derived at the press from the stick and the opponent's side;
- there is no `burst` field: `powerPress` and `powerTap`, with the sim choosing by "threatened";
- there is no cancel field: a `dodge` edge inside an exchange is the cancel.

The slices are I1 (transport, Simulation), then I2: step 1 below, with Controls and Simulation's core lines.

## Order
1. Intent and state (Simulation and Controls), with the held states feeding today's templates (Part 1 §1), plus the placeholder transform. Playable at once.
2. Counters and beams by request (§2); the queue (§3).
3. Interrupt windows (§5).
4. Entry and mode through the style applier (§4), with the AI profile (§6) and the Simple assists (§7).
5. Part 2.

Each step is a checkpoint with goldens, the feel probe, tempo and QA's bands.
