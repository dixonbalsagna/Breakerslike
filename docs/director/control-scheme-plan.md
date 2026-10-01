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
  - a fixed precedence for two interrupts in one tick. **Adopted** (Game Design, `control-rules.md` §2): perfect block, reversal, dodge cancel, burst, with the defender before the attacker. An interrupt that loses the same-tick tie isn't charged: it costs no ki and starts no cooldown.

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

## With I2: the time-cap stand-in (granted)

Long matches run past the tools' 12-minute cut-off because the brink chapter's backstop, the 11:00 time-cap event, isn't built. Until Game Design and Simulation build the full event, the director stands in for it:
- `DirExchange.dirUpdate` sets `S.game.timeCap = true` once `S.T` reaches `contest.timeCapAt` (660 s). The EP granted that write.
- `DirData` gets the accessor, and `data/combat/finishers.json` the `timeCapAt` line. The schema key goes to Tools at I2.
- From then on, every decisive win against a fighter on the brink is a finisher, which `decisive()` already honours.

The tool caps move to sim time or 15:00 separately, with their owners.

## Order
1. Intent and state (Simulation and Controls), with the held states feeding today's templates (Part 1 §1), plus the placeholder transform. Playable at once.
2. Counters and beams by request (§2); the queue (§3).
3. Interrupt windows (§5).
4. Entry and mode through the style applier (§4), with the AI profile (§6) and the Simple assists (§7).
5. Part 2.

Each step is a checkpoint with goldens, the feel probe, tempo and QA's bands.

## I2b as built (step 1)

**Status.** In the tree. Goldens regenerated.

**What runs**

| Part | What the director does | Where |
| :--- | :--- | :--- |
| **Held states feed today's templates** | The AI is a v2 slot (`f.act.v2`). Its stance choice lives in `f.ai.st`, and it writes the held states that stand for it: guard held (Guard), a dodge re-tapped before its window lapses and never inside an exchange (Dodge), sprint while moving away (Escape), nothing (Press). The director reads `f.stance` exactly as before | `ai.gd` |
| **Escape is sprinting away** | When the AI's cover run would stand still or head toward the opponent, it backs away instead, without the dash. With the dash it got so far that attacks became long pursuits and matches ran about 40 s longer | `ai.gd` |
| **Template and branch ids** | `ex.tpl` and `ex.branch` are set at planning: the template and branch for melee, the beam template and its outcome for a signature, and `finisher` with the finisher's id | `data.gd` |
| **The placeholder transform** | `manualTierUp` is on in both ladders. Between exchanges, a fighter with a form ready takes it on the transform edge; the AI asks at once. The tier rises with today's power-up burst, an opponent within 700 u is pushed back at 900 u/s, and for 0.8 s no exchange starts and the transformer holds still (48 stun ticks) | `exchange.gd` `_transforms` |
| **Legacy inputs** | The keyboard and the touch bridge have no transform control yet. Until Controls' I2c, holding the charge control while a form is ready takes it on those slots | `exchange.gd` |
| **The time-cap stand-in** | `S.game.timeCap` goes on once `S.T` reaches `contest.timeCapAt` (660 s) | `exchange.gd`, `data.gd`, `finishers.json` |
| **The parry chance reads the snapshot** | The AI's parry-press chance uses `ex.sD`, not the live stance. No change in results today; it is the R8 rule | `melee.gd` |

**Events** (shapes for `fx-events.md`, Simulation)
- `transform_ready {actor, tier, source}`: `actor`'s power crossed a threshold and `tier` waits for the input. `source` is the input that takes it: `triggers` (the two-trigger chord), `power` (the power hold: the Simple layout, and today's keyboard and touch through the charge control) or `ai`. Emitted once, on the rising edge, from `stepFighter`.
- `transform {actor, tier, source, dur}`: `actor` took it. `tier` is the new tier and `dur` the hold in seconds (0.8). `tier_up` follows in the same tick, at the start of the hold.

**Results** (seeds 1 to 100, default and swap arms, capped at 15:00; before is HEAD 3bf908c)

| Measure | Before | After |
| :--- | ---: | ---: |
| Match median, default / swap | 6:42 / 7:04 | 6:56 / 7:08 |
| p10 and p90, default | 5:03, 9:07 | 5:15, 8:53 |
| First brink, default / swap | 5:44 / 5:57 | 5:50 / 6:03 |
| KAI, both arms (200) | 44% | 47% |
| Transforms per match | 0 (automatic tier-ups) | 6.0, the first at about 0:35 |
| No KO by 15:00 | 0 | 0 |
| Matches where the time cap came on | | 3 of 200 |
| Attacks per minute | 17.3 | 16.8 |
| Defender stance at the request: Press, Guard, Dodge, Escape | 43, 19, 23, 15% | 46, 19, 23, 12% |

**Notes**
- The transform constants (hold 0.8 s, push 900 u/s within 700 u) are code constants for the placeholder. They move to data with F1's transformations.
- A stunned AI's held states end at the stun gate, so it reads as Press while staggered. That is the scheme's rule for any player.

## Step 2a as built (the queue, the signature cooldown, the beam tier gate)

**Status.** In the tree. Goldens regenerated. Step 2b (the Neutral column, request-only counters, the fire-beat beam outcome) follows with Combat's data and Tools' `apply-q4`.

**What runs**

| Part | What the director does | Where |
| :--- | :--- | :--- |
| **One press, one request** | For a v2 slot, `requestAttack` pushes `[weight, mode, entry, tick]` to SimAct's queue (depth 3). `_drain` starts the oldest request the director can take, the older first and the slots alternating on a tie. It runs at the press and once per live tick. A request that can't start yet waits; it expires after 36 ticks, except the attacker's own links during its exchange | `exchange.gd` `requestAttack`, `_drain`, `_queues`, `_start` |
| **Chain links from the queue** | At a chain window the attacker's next queued light or heavy request becomes the link, whether it was pressed before or during the window. The timed press is gone for v2 slots. The AI's chain press is a queued request too | `exchange.gd` `dirUpdate`, `openWindow`, the `press` op |
| **The upgrade edge** | A hold or a swipe makes the newest queued request heavier, or queues a new one if the first has already started (the Simple layout's attack on press) | `exchange.gd` `_queues` |
| **The signature cooldown** | `sigCooldown` (120 s, `fighter.json`). A signature sets `sigReadyT`; a request before it is dropped with a banner | `exchange.gd` `_start` |
| **The AI's signature pick** | 0.025 per attack with 50 ki and the cooldown over (it was 0.2), which gives about 3 signatures a match. The heavy share of the other attacks is unchanged | `ai.gd` `SIG_PICK`, `HEAVY_SHARE` |
| **The beam tier gate** (`balance-targets.md` §15) | Fixed at fire time from the firer's ladder: the structure factor (×0.25, 0.5, 1.0, 1.5), the level cap (1, 3, 8 and 20% of all structures, at least one), and the overshoot past the target (600, 1,200, 2,400 and 4,000 × WS). Past its cap a beam leaves buildings at 25% hp. The beam's impact explosion and a clash's blast count against the same beam | `beam.gd`; `ladder.json` `beam`; `WorldStructures.damageArea`, `damageBuilding`, `explode` (granted) |
| **The roam yields to the hunt** | A fighter doesn't lead the fight away while its opponent is out of lock; it sweeps for it. QA's report: the roam was tested before the hunt | `ai.gd` |
| **The Rally tilt** | Finisher survival loses `contest.rallyPenalty` (10 points) per Rally the fighter has used. It was missing since S4 | `exchange.gd` `_opContestBranch` |

**Results** (seeds 1 to 100 per arm, capped at 15:00; before is HEAD 723cc47)

| Measure | Band | Before | After |
| :--- | :--- | ---: | ---: |
| Signatures per match, median | 2 to 4 | 21 to 23 | **3** |
| Beam outcomes: CLASH | 30 to 60% of signatures | 44 to 47% | 50 to 51% |
| Structures levelled per minute at tier 1 | at most 2% | 5.3 to 5.8% | **0.08%** |
| ... at tier 2 | at most 4% | 7.5 to 7.8% | **0.95%** |
| ... at tier 3 | 3 to 10% | 8.3 to 11.5% | 1.2 to 3.0% |
| ... at tier 4 | 6 to 20% | 7.4 to 7.8% | **3.4%** |
| Matches losing over 10% of structures before tier 3 | none | 73 of 200 | 1 of 200 |
| A beam's own levelled count against its cap | never over | often over | never over (2, 6, 16 and 39 reached exactly) |
| Structures lost at the KO | 25 to 60% of all rows | 52 to 57% | 25 to 26% |
| Match median, default / swap | 6:00 to 8:00 | 6:56 / 7:08 | **8:31 / 8:42** |
| KAI, both arms | 45 to 55% | 47% | 55.5% |
| Chain links per match | | 33 | 49 to 52 |
| No KO by 15:00 | | 0 | 0 |

**A scripted masher** (a v2 human slot pressing light every 8 ticks) beats today's AI 100 times in 100, in about 2:30. It also wins 60 of 60 on HEAD, so the queue did not cause it: constant attacks with every chain taken already beat this AI. Game Design's bands (35 to 50% against a medium AI) need the perfect block and staleness of step 3 and the AI profile of step 4.

**Notes for Game Design and QA**
- **Length.** Matches run about 90 s longer, because each signature removed was 230 to 260 damage. k needs QA's damage-rate retune.
- **Top-tier destruction** is under its bands with 3 signatures a match (tier 4 at 3.4% a minute against 6 to 20%).
- **The one match over 10% before tier 3** lost its structures to launches and slides, not beams. World's rolling structure budget is the ruled fallback.
- **Old parry rule.** A defender's attack press during the wind-up still parries, until the perfect block replaces it in step 3. For a v2 slot that press now also queues an attack, so a parry is followed by the defender's own attack.

## Step 2b as built (the Neutral column, request-only counters, the beam decided at fire)

**Status.** In the tree with Combat's three 2b data files and Tools' `apply-2b` schemas. Goldens regenerated. Only the `dynamic` profile changes; `parity` and `spaced` are untouched.

**What runs**

| Part | What the director does | Where |
| :--- | :--- | :--- |
| **The Neutral column** | A defender in Press with no attack request of its own is NEUTRAL: the attack lands as CLEAN HIT, or CLIPPED when the defender is moving away or mostly vertically at over half its flight speed. No draw | `data.gd` `_flags`, `_matches`, `hasNeutral`, the `condition` selector |
| **Request-only counters** | A trade or a counter needs the defender's own request: one in its queue, or a press in the last 20 ticks (`defQueued`). A dodge that isn't read gives DODGE & COUNTER only with it, else DODGE — CLEAN. A guard holds and never counters by itself | `data.gd` `_selector` (`selectorByProfile`), `_pick` |
| **The Press skill number** | The AI gets a trade or a counter the way a player does, by an input. Attacked in Press it has a request in with chance 0.6, and in Dodge with chance 0.5 (one draw; the request goes through its queue). Guard and Escape: 0 | `ai.gd` `react`; `data/director/ai.json` `pressReact` |
| **The beam is decided at fire** | The request plans the beam without an outcome. At the fire beat the rules of `beam.outcomeByProfile.dynamic` run in order on what the defender did in the tell: an answering signature (45 ki, off cooldown) or heavy blast (40 ki, at -10) gives CLASH; then the live held state gives GUARD, the DODGE read or the ESCAPE gamble; otherwise HIT. The answer is paid for at fire, and an answered clash doesn't charge the old 40 ki | `beam.gd` `opBeamFire`, `_answer`; `data.gd` `beamOutcome` |
| **The AI in the tell** | It answers when it can with chance 0.35 (its own signature, or else a heavy blast), by a press during the tell. Its Dodge tap and its Escape sprint keep going through the tell, so those states read at fire | `beam.gd` `opBeamCharge`; `ai.gd` `_beamTell`; `ai.json` `beamAnswer` |
| **Strike classes** | Combat's `o.class` replaces `noParry`. The 2b parry rule: only an `opener`, `heavy` or `ender` that is the attacker's first strike after a wind-up can be parried, which is today's behaviour | `data.gd` `_args`; `melee.gd` `opWind`, `strike` |
| **`approach.minHeavy`** | A heavy opener's approach lasts at least 20 ticks, so its wind-up fits | `data.gd` `_approachTicks` |
| **The AI's skill numbers are data** | `data/director/ai.json`: `pressReact` by stance, `beamAnswer`, `sigPick`. Hashed with the combat data | `ai.gd` `skill` |
| **New event** | `beam_outcome` {actor, target, kind} at the fire beat. The `attack` event of a `dynamic` signature no longer carries the outcome | `sim/core/fx.gd`, `hash.gd`, `view/fx.gd` (granted) |

**Not read yet** (data for step 3 and 4): the `interrupts` block, `perfectBlock`, the `riposte` template, `defPerfect`, and the entry terms (`atkEntry`, `defEntry` are 0 until entries are wired).

**Results** (seeds 1 to 100 per arm, capped at 15:00; before is the Q10 slice, `21390f6`)

| Measure | Band | Before | After |
| :--- | :--- | ---: | ---: |
| TRADE BLOWS, share of melee exchanges | | 28.5% | **12.9%** |
| CLEAN HIT and CLIPPED | | none | 19.7% and 6.9% |
| DODGE & COUNTER / DODGE — CLEAN | | 13.8% / none | 5.6% / 7.5% |
| A guard that counters | none (R4) | 4.5% | **0** |
| HEAVY CLASH, all three | | 18.1% | 7.8% |
| Beam outcomes: CLASH | 30 to 60% | 46 to 47% | **33 to 36%** |
| ... HIT | | 16 to 17% | **41%** |
| ... GUARD / DODGE / ESCAPE | | 18 to 21 / 13 to 15 / 4 to 5% | 12 / 8 to 10 / 2 to 4% |
| Signatures per match, median | 2 to 4 | 3 | 3 |
| Match median, default / swap | 6:00 to 8:00 | 10:01 / 10:00 | 10:25 / 9:59 |
| KAI, default / swap arm | 45 to 55% | 65% / 44% | 67% / 54% |
| Chain links per match | | 58 to 60 | 81 to 83 |
| Attacks per minute | | 18.4 | 19.9 |
| Structures lost at the KO | 25 to 60% | 24 to 25% | 28 to 29% |
| No KO by 15:00 | | 0 | 0 |

**Notes for Game Design and QA**
- **Beams hit more.** An AI in Press that doesn't answer is hit, where the old rule gave it a free clash. A medium AI never switches to Guard on a tell; that is the AI profile of step 4.
- **KAI rose 6 points** over both arms (54.5% to 60.5%), and chain links rose from about 59 to about 82 a match. The likely cause of the longer chains is that a clean hit opens a chain window where a trade did not; that is not checked.
- **The scripted masher** still wins 100 of 100, in about 2:10. Its exchanges are now mixed (CLEAN HIT 652, TRADE BLOWS 716, GUARD HOLDS 854), where on 2a nearly every one was a trade.
- **The old parry rule** stays until step 3: a defender's press in the wind-up parries, and for a v2 slot that press also queues an attack.
- **VORR's menace is rarely fed early.** It rises inside the first 100 s in 14 of seeds 1 to 240. The parity tool's end-to-end row needed new seeds for that reason.

## Step 3 as built (the interrupts, staleness and the AI's defences)

**Status.** In the tree on HEAD `4fe8052` (after Simulation's `d7d3db3`, which added `ActState.dirI` and its hash line). Goldens regenerated. It was built and tuned on scratch copies first; the apply script and the data drafts are in `docs/director/pending/step3/`.

**What it does**

| Part | Rule | Where |
| :--- | :--- | :--- |
| **The perfect block** | A fresh guard press in the last ticks of a strike's wind-up. The window is per strike class, as data: 8 ticks for a light opener, 10 for a heavy or an ender, 6 for a return, none for a mid-string hit; 4 ticks of early tolerance (none for a return); 2 off for a broken arm. No damage, +8 ki, the attacker's string ends and it staggers 24 ticks. It replaces the old parry in `dynamic` | `interrupt.gd` `guardPress`, `perfectBlock`; `interrupts.json` `perfectBlock.windows` |
| **The lockout** | A guard press outside a window locks the perfect block out for 20 ticks (Controls' number), and each further press restarts it. The guard itself still works | `guardPress` |
| **The riposte** | The blocker's next attack within 30 ticks starts at once, through the cooldown, from the `riposte` template. It launches when the blocked strike was a heavy or an ender | `exchange.gd` `_start`; `data.gd` `_contextTemplate` |
| **DEFLECT** | A perfect block of a signature's fire beat: no damage, +8 ki, no stagger, no riposte | `beam.gd`; `interrupt.gd` `deflect` |
| **The dodge-cancel** | 15 ki, 3 s. The attacker at any time; the defender only 6 ticks or more after it was last struck. The exchange ends with no winner and the canceller dashes in the held direction | `dodgeCancel` |
| **The burst** | 30 ki, 8 s. A rival in 4 bh is shoved away and an exchange ends with no winner. A rival holding guard absorbs it and the burster staggers 30 ticks. Not during a signature, a launch or a finisher | `burst` |
| **The reversal** | The context button in guard, within 12 ticks of a normal block: 20 ki (10 after 2 s of guard), 6 s. The attacker's string ends, and after an 8-tick turn the defender's own heavy starts at once | `reversal` |
| **A blocked string** | A string blocked to its end opens **no chain window**, leaves its attacker unable to act for 12 ticks, and gives the guard those 12 ticks to start an attack at once | `exchange.gd` `openWindow`; `interrupt.gd` `lastBlowBlocked`, `onEnd` |
| **Staleness** | The same weight, mode and direction in three exchanges running: each further repeat adds 2 ticks to the wind-up (at most 6) and 2 to the rival's perfect-block window (at most 4) | `onStart`, `_staleWindow` |
| **A staggered fighter** | Its queued requests wait, it has no press of its own, and it is not "clipped" | `exchange.gd` `_start`; `data.gd` `_flags` |
| **Clash presses** | An attack press by a fighter in a live clash is spent, not queued. `DirBeam.inClash(S, f)` is the flag Controls asked for | `exchange.gd` `requestAttack`; `beam.gd` |
| **The same-tick order** | Perfect block, reversal, dodge-cancel, burst, the defender before the attacker. An input after a takeover on the same tick is not charged | `interrupt.gd` `tick` |

**The AI, by level** (`data/director/ai.json`, `levels`; a level is chosen by `DirAI.level` for now)

| Number | Easy | Medium | Hard | What it is |
| :--- | ---: | ---: | ---: | :--- |
| `perfectBlockMul` | 0.35 | 0.6 | 1.0 | Its share of R5's rates (25% in guard, 15% in press, +10 against a heavy or an ender), per strike with a window |
| `guardRepeat` | 2 | 8.75 | 20 | Weight added to its Guard choice once the rival has opened three exchanges running with one weight |
| `punish`, `punishHeavy` | 0.25, 0 | 0.6, 1 | 0.9, 1 | The chance it attacks in the 12-tick punish window, and the share of those that are heavies |
| `reversal` | 0.2, 0.08 | 0.5, 0.2 | 0.8, 0.4 | After 2 s of guard with over 25 ki, and otherwise (R4 at medium) |
| `breakGuard` | 0.375 | 0.6 | 0.9 | Its heavy share against a rival it found guarding twice running. The grab waits for Combat's context templates |
| `riposte` | 0.5 | 1 | 1 | The chance it takes its riposte |
| `burstAtLink` | never | 4 | 3 | The chain link at which it bursts out |
| `beamAnswer` | 0.15 | 0.35 | 0.6 | As before |

**Results** (in the tree; before is HEAD `4fe8052`)

| The scripted masher (light every 8 ticks) | Band | Before | After |
| :--- | :--- | ---: | ---: |
| Against the easy AI | At least 60% | | 20 of 20 |
| Against the medium AI | 35 to 50% | 20 of 20 | **33 of 80 (41%)** |
| Against the hard AI | | | 2 of 20 |
| Against an expert script (guards, punishes with a heavy, perfect-blocks heavies and enders) | At most 15% | | 0 of 20 (on a scratch build of this slice) |

| AI against AI (200 matches, seeds 1 to 100 per arm) | Band | Before | After |
| :--- | :--- | ---: | ---: |
| Perfect blocks per 100 melee exchanges, medium | 5 to 15 | | about 11 (RIPOSTE is 10.0% of melee exchanges) |
| Match median, default / swap | 6:00 to 8:00 | 7:09 / 7:02 | 6:58 / 7:16 |
| KAI, default / swap arm | 45 to 55% | 50% / 47% | 54% / 63% |
| Melee exchanges per minute | | 20.3 | 24.3 |
| Chain links per match | | 57 | 48 |
| TRADE BLOWS, share of melee exchanges | | 12.0% | 7.1% |
| CLEAN HIT | | 18.7% | 25.3% |
| PRESSURE — GUARD HOLDS / GUARD BREAK | | 12.1% / 7.5% | 13.0% / 9.5% |
| Structures lost at the KO | | 24 to 28% | 24 to 27% |

**What made the difference.** With every other rule in, the masher still won 20 of 20 at all three levels. A fully blocked string still opened a chain window, and chain blows ignore the guard, so guarding did nothing. Closing that window after a blocked string is what brings the masher into band; the medium AI's guard weight then sets the win rate, and steeply: in the tree 8.5 gave 49%, 8.75 gave 41% and 9 gave 33%, over 80 matches each.

**Open points**
- **KAI rose** from 48.5% to 58.5% over both arms on this base. On the scratch base the same slice read 51%. QA should re-measure and re-centre.
- **The schemas.** `ai.json` has three new keys (`perfectBlock`, `level`, `levels`) and `interrupts.json` is new, so the validator fails until Tools updates `director-ai.schema.json` and adds a schema for `interrupts.json`.
- **An expert who only ripostes light openers can never finish.** A riposte to a light does not launch, so it is never decisive; my first expert script won no match in 20. It has to punish a blocked string with a heavy, or perfect-block a heavy or an ender. For Game Design.
- **Touch's 2 extra ticks** need the slot's layout in the sim. Not applied.
- **Chain links have no window** (they strike a launched body), so the burst is the only out during a chain. Combat's chain phrase (small links, one ender with a tell) is not wired; the styles data is still marked as suggestions.
- **The grab** ("throw a fighter who only guards") needs Combat's context templates. Until then the AI answers a guard with heavies.
- **Feedback events.** The perfect block, the reversal, the dodge-cancel and the burst send `cue` events (`perfect_block`, `reversal`, `dodge_cancel`, `burst`, `burst_absorbed`) and the perfect block also sends `parry`. Controls' `press_ack` event would be Simulation's lines. `dodge_cancel`, `burst` and `burst_absorbed` are not in Combat's cue list yet.
- **Two mashing humans** used to parry each other on every opener (the old parry read any attack press in the wind-up). With the perfect block they play full exchanges: 8 exchanges in 40 s where there were 53 cut short.

**The loader check** (`sim/director/tools/loader_check.gd`) now treats an unexercised branch as a failure only in a full run of 200 matches or more. A short run notes it and passes: CHARGE INTERRUPT is too rare to come up in 50 matches.

**After step 3, in the same folder**
- **The slam lever** (`apply-slam.cjs`): UPPERCUT's direction moves to `launch.json`, with a forward carry of 0.85 (it was 0.25). Its craters fall from 58% to 22% of its launches, and slams overall from 15.0% to 11.2% (30 matches). At 0.6 it still cratered 42%. UPPERCUT's share of launches doubles to 22%, because it now carries far.
- **The queue tie-break** (`apply-tiebreak.cjs`): on a tie of age the fighter who did not start the last exchange goes first. Controls' probe shows no phase-lock after step 3 with or without it (longest run 4 to 5 at fixed gaps of 4, 7 and 12 ticks; it was 19 and 54 before step 3, when the old parry cut every exchange short).

## Queued after step 2a (EP notes)

- **Teleporting is on hold** (Orb). Blinks and the teleport clash drop out of the variety steps. The ping-pong blitz uses flight paths only (`docs/combat/blitz.md`).
- **The landing mix** (`balance-targets.md` §19), in my next slice, with QA re-measuring after each step:
  1. `SLAM_VERT` goes from 0.85 to 0.94 (World's constant, granted; to data if cheap).
  2. SLAM DOWN becomes a drive by default, 40 to 55 degrees below level. The straight-down slam stays for break and finisher launches, a rival directly below, and the tier-3 crater set piece.
  3. Only if slides are still under 40%: more planner weight for shallow launches, and more forward carry on UPPERCUT.
- **Fights in the city** (Rendering). In two AI matches no fighter was ever behind a building, so occlusion can't be judged in play yet. Keep it in mind for variety and L4.
- **Steps 3 and 4, from Game Design's §21** (after 2b):
  - The AI uses the new defences by difficulty: it guards a repeated string, perfect-blocks enders at R5's rates, punishes a fully blocked string, and throws a fighter who only guards.
  - A staleness rule for repeated attacks.
  - The medium AI doesn't guard on a beam tell yet (HIT is 41% of beams after 2b); that belongs to the same AI profile.
- **Contact constants move to Combat's data:** the step-around's 8 ticks, 98 u rise and 74 u end distance on the `dodge` beat, and the 3-reach placement limit in the contact block. I read them from data when Combat adds them (`contact-plan.md`).
- **Knocked-about rules** (`balance-targets.md` §20) replace §19's band table. The new bands, as shares of launches: slide 40 to 55%, bounce 8 to 15%, slam 8 to 15%, caught in the air 10 to 25%, water 5 to 15%, brunt 4 to 10%. §19's steps (`SLAM_VERT` 0.94, the drive) still stand. World plans the physics and a journey prediction. My part, later: the launch planner's budget check on the predicted journey, and the AI's tech on the dodge tap.
