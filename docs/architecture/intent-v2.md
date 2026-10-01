# Intent v2: the input record for ADR 0008 (plan, reconciled and ruled)

Status: plan only (Simulation, 2026-10-01). No sim edits. Sources:
- `docs/decisions/0008-control-scheme.md`;
- Controls, `docs/controls/input-scheme.md` §3, §4 and §8;
- Encounter, `docs/director/control-scheme-plan.md` ("SimIntent fields needed", "Order");
- the EP's rulings of 2026-10-01 on this page's first draft (§4).

This page is the single agreed table.

## 1. The rule that divides the work (EP ruling 1)

- **Tap against hold always resolves in the layout layer**, outside the sim. A hold threshold, a tap that ended early, a swipe, a two-trigger chord: the layout turns each into an action before it becomes an intent. Layouts can then change without invalidating a replay.
- **Only timing that depends on the fight is in the sim.** That covers:
  - the perfect block against the wind-up;
  - the direction class against the opponent;
  - whether a fighter is threatened;
  - whether a request has already been started by the director;
  - whether a transformation is available.
- **An intent is the resolved action record** for one fighter for one tick. It is the only thing a replay or a network peer carries. The AI writes the same record.

## 2. The intent record

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `mx`, `my` | int, −127 to 127 | the stick, quantised by the layout (ruling 2); the sim uses `/ 127.0` |
| `guard` | bool, held | guarding |
| `guardPress` | bool, edge | a fresh guard press this tick; the sim judges the perfect block from it |
| `dodge` | bool, edge | the dodge. Inside an exchange it is the cancel (ruling 3: no separate bit; the sim decides by context) |
| `sprint` | bool, held | sprinting (the layout sends it once the dodge hold passes its threshold); moving away, it is Escape |
| `power` | bool, held | the power layer, and channelling |
| `powerPress` | bool, edge | the power control went down this tick |
| `powerTap` | bool, edge | a power tap completed (released before the hold threshold) |
| `mode` | int: −1 auto, 0 physical, 1 energy | the piece family, sent every tick (ruling 5). Auto lets the director pick (Simple layout, mobile) |
| `light`, `heavy`, `sig` | bool, edge | attack requests, one exchange request each |
| `upgrade` | int, edge: 0, 1 or 2 | 1 heavy, 2 signature: the layout saw the hold or the swipe; the sim replaces this button's last request if the director hasn't started it |
| `special` | int, edge: 0 none, 1 to 7 | a loadout special (ruling 4: 3 bits). 1 to 3 today, 4 reserved for the Cyborg's revealed weapon, 7 the Simple layout's auto pick |
| `context` | bool, edge | the context action; the sim picks which by priority |
| `transform` | bool, edge | the layout's chord completed; the sim ignores it unless a transformation is available |

- **Held** fields are true on every tick the action is held. **Edge** fields are true on one tick.
- **Removed:** `stance`, `dash`, `charge`.
- **No direction or entry field.** The stick is the direction; the sim classes it (toward, neutral, away) at the press.
- **No burst field.** The burst is the sim's reading of the power edges: `powerPress` when the fighter is threatened, `powerTap` otherwise (Controls' rule). The layout can't know "threatened".
- **Same tick** (ruling 6): `power` held plus a request on one tick fires the special on that tick. The sim adds no latency rule.

**Host guarantees (Controls):**
- A press shorter than a tick is stretched to one tick with its edge.
- A release and re-press between two ticks gives one edge.
- A face press inside the power layer sets `special` or `sig` and clears `light`, `heavy` and `context` for that press.
- Presses made during a hit-stop freeze are kept by the layout and sent on the first live tick. `SimCore.step` already consumes no input on a frozen tick.

## 3. What the sim derives (I2, not I1)

Encounter's fighter state is derived from the record and the fight, and lands in I2 (EP):
- the request queue (up to 3, each with its weight, mode and entry);
- `guardSince`;
- the last dodge tick;
- `dodgeCool` and `burstCool`;
- `formReady`;
- the burst (from the power edges).

`f.stance` is then derived each tick, and the director snapshots it at exchange start as now:
- Guard: `guard` held;
- Escape: `sprint` and moving away;
- Dodge: a `dodge` within its window;
- Press: an attack pending or just pressed;
- Neutral otherwise. Until Combat and Game Design give Neutral its column, it reads as AGGRESSIVE.

Controls owns these rules in `sim/input`, and Encounter reads them. Simulation owns the fields, their hashing and the core lines (the tier-up gate, `stepFighter`'s reads of sprint and channelling).

The per-slot assists (`autoBurst`, `specialPick`, `perfectBlockAssist`) go in the replay header's `setup` in I2, next to `slots`, `names` and `flip`. `autoMode` isn't needed: `mode` −1 says it.

## 4. Where the lists differed, and what was ruled

| Point | Controls | Encounter | Ruled or picked |
| :--- | :--- | :--- | :--- |
| Tap against hold | the sim counts holds | implied in the host | **Layout layer** (ruling 1). Controls' §3 thresholds move to the layout; the record carries their results (`sprint`, `powerTap`, `upgrade`, `transform`) |
| Movement | float, steps of 1/16 | `mx` | **8 bits per axis** (ruling 2) |
| Cancel | the dodge press in an exchange | the dodge edge | **No separate bit** (ruling 3) |
| `special` | 0 none, 1 to 3, 4 auto | 0 to 2 | **3 bits, 0 to 7** (ruling 4): 1 to 3, 4 reserved, 7 auto |
| `mode` | an edge (toggle) with a cooldown | a state | **A per-tick field with −1 auto** (ruling 5). The toggle and its cooldown are the layout's |
| Dodge | `dodge` held plus `dodgePress` | `dodge` edge, `sprint` held | **`dodge` edge, `sprint` held**: follows ruling 1 (the hold threshold is the layout's) |
| Guard | `guard` held plus `guardPress` | `guard` held, `guardTap` edge | **`guard`, `guardPress`.** The edge is needed: a release and re-press between ticks can't be seen in a held bool |
| Burst | derived from the power tap rule | an edge field | **No field.** `powerPress` and `powerTap` are recorded; the sim picks by "threatened" |
| `upgrade` | 0, 1 or 2 | none | **Controls.** The layout sees the hold; the sim applies the replacement, which depends on the director |
| `transform` | held; the sim counts 30 ticks while available | an edge | **An edge** (ruling 1: the chord's timing is the layout's). The sim ignores it when nothing is available |
| `entry` | none | −1, 0 or +1 | **Derived** at the press (it depends on the opponent's side) |
| Fighter state | suggested | listed | **I2** (EP) |

**For Controls' redesign:** `input-scheme.md` §3 and §8 need to follow these: the hold counts move to the layout, the stick to 8 bits, `mode` to a per-tick value, `transform` to an edge, `special` to 0 to 7, and `dodge` held gives way to `sprint`.

## 5. Determinism and the record

- **Packed form.** `SimIntent.pack() -> int` and `unpack(int)`: one integer of 35 bits.
  - 8 each for `mx` and `my`;
  - 2 for `mode`, 2 for `upgrade`, 3 for `special`;
  - 12 single bits.

  It is well inside what JSON carries exactly. `unpack(pack(i))` is the identity, and `unpack` rejects a value outside a field's range.
- **State hash.** The intent fields are hashed in the table's order.
- **Replay format v3.**
  - Inputs are `[tick, slot, packed]`.
  - The header gains `intent: 2`, the intent schema version.
  - `play()` refuses another format or intent version with reason `format`.
  - v2 replays are not migrated: none are kept.
- **Stun and wounds.** `SimWounds.gateIntent` clears movement, the held states and every edge while stunned. Broken legs clear `sprint`, as they clear `dash` today.

## 6. Slices

| Slice | Owner | Content | Goldens |
| :--- | :--- | :--- | :--- |
| **I1, transport** (next window, after World's terrain fixes) | Simulation | `SimIntent` gains the new fields next to today's `stance`, `dash` and `charge` (a superset, for one slice). `pack` and `unpack`. The hash list. Replay v3 with the intent version. The scripted-replay generator. Nothing reads the new fields | **Unchanged**, proved as before: with the new fields left out of the hash, the goldens reproduce; then one regeneration |
| **I2, consumption** (Encounter's step 1) | Controls for `sim/input`; Encounter for the director and the AI; Simulation for the core lines | The derived fighter state (§3) and the stance from the held states. `stepFighter` reads sprint and channelling in place of `dash` and `charge`. The AI writes v2. The tier-up gate, `formReady` and the placeholder transform. The assists in `setup`. `Exchange` gains `tpl` and `branch` (the template id and the branch id, two strings, hashed), so an interrupt (the perfect block, the reversal, a beam answer) can find its branch's `interrupts` block; `ex.tag` isn't a safe key | Regenerated: a behaviour change. QA's bands and the feel probe judge it |
| **I3, removal** | Simulation | `stance`, `dash` and `charge` leave the record. The intent version goes to 3; replays from I1 and I2 are refused | Regenerated (the hash list) |
| Encounter's steps 2 to 5 | Encounter, Controls, Combat | Counters by request; the queue; interrupt windows; entry and mode through the style applier | Each its own checkpoint |

**I1 tests:**
- pack round trip over every field's range, and rejection of out-of-range values;
- replay v3 record, play and JSON round trip;
- a changed bit is caught;
- a v2 file is refused.

## 7. Open points

1. **Controls:** confirm the two power edges (`powerPress`, `powerTap`) are enough for the burst rule, and the `sprint` threshold in the layout.
2. **Game Design and Combat:** the Neutral state's column.
3. **Encounter:** who raises the tier at a transform, and the `transform_ready` and `transform` event fields, for `fx-events.md` (I2).
