# Intent v2: the input record for ADR 0008 (plan)

Status: plan only (Simulation, 2026-10-01). No sim edits. Source: `docs/decisions/0008-control-scheme.md`. The field list is a proposal to settle with Controls' redesign, routed by the EP.

## 1. What an intent is, and what it is not

- **An intent is the resolved, device-independent action record for one fighter for one tick.** The sim acts on it and on nothing else. Keyboards, pads, the three layouts, the mobile gestures and the AI all produce the same record.
- **Resolving gestures is the layout layer's job, outside the sim.** Tap against hold on one button, a swipe for the signature, the 0.5 s two-trigger hold for a transform: Controls' layout code turns each into an action before it becomes an intent. Layouts can then change without invalidating a replay, because a replay stores actions.
- **Timing that depends on the fight stays in the sim.** The perfect block is judged from the tick the guard goes from not held to held, against the wind-up in sim state. The direction class (toward, neutral, away) is judged from the stick against the opponent's position. Neither is recorded as a field.
- **Stances stop being inputs.** `f.stance` is derived each tick in `SimControl.control` from the held states, so the director still reads "what each fighter is doing at exchange start":
  - Guard: guard held;
  - Escape: sprint held and moving away;
  - Dodge: the dodge action;
  - Press: otherwise.

## 2. Fields (proposal)

| Field | Type | Meaning | Replaces |
| :--- | :--- | :--- | :--- |
| `mx`, `my` | int, −127 to 127 | the stick, quantised by the host; the sim uses `/ 127.0` | float `mx`, `my` |
| `guard` | bool, held | guarding. Its rising edge is the perfect-block tap | stance 1 |
| `dodge` | bool, held | the dodge action. Its rising edge is the dodge | stance 2 |
| `sprint` | bool, held | sprinting; away from the opponent it is Escape | `dash`, stance 3 |
| `power` | bool, held | the power layer. Held with no special fired, it channels or charges | `charge` |
| `mode` | int: −1 auto, 0 physical, 1 energy | the piece family. Auto lets the director pick (Simple layout, mobile) | new |
| `light`, `heavy` | bool, request | one exchange request each, weight by button | same |
| `special` | int: −1 none, 0 to 2 | a loadout special (power layer plus a face button) | new |
| `sig` | bool, request | the signature | same |
| `transform` | bool, request | transform (the layout resolves the two-trigger hold) | new |
| `context` | bool, request | the context action; the sim picks which by priority | new |
| `burst` | bool, request | the answer to pressure; the sim charges energy and a cooldown | new |
| `cancel` | bool, request | cancel mid-exchange. Default layouts send it with a dodge tap | new |

- **Held** fields are true on every tick the action is held. **Request** fields are true on the tick of the press only.
- **Removed:** `stance`, `dash`, `charge`.
- **No direction field.** The direction held is `mx`, `my`; `SimControl` classifies it (toward, neutral, away) with a dead zone from data.

## 3. Determinism and the record

- **Packed form.** `SimIntent.pack() -> int` and `unpack(int)` hold the whole record in one 32-bit integer: 8 bits each for `mx` and `my`, 4 held bits, 2 for `mode`, 2 for `special`, 7 request bits, 1 spare. Replays and, later, rollback netcode carry that integer. Equal intents are equal integers.
- **Canonical values.** `unpack(pack(i))` is the identity. The host quantises the stick before the sim sees it, so a recorded match and a live one read the same bits.
- **State hash.** `f.input`'s fields are hashed, in the order of the table.
- **Replay format v3.**
  - Inputs become `[tick, slot, packed]`.
  - The header gains `intent: 2`, the intent schema version.
  - `play()` refuses another format or intent version with reason `format`. It does not guess.
  - v2 replays are not migrated: none are kept.
- **Requests and hit-stop.** `SimCore.step` already returns false on a frozen tick and consumes no input. The host keeps a request until a step returns true. A replay stores what each consumed step received, so playback is exact.
- **Stun and wounds.** `SimWounds.gateIntent` clears movement, the held states and every request while stunned. Broken legs clear `sprint`, as they clear `dash` today.

## 4. What sits around the intent (other owners)

| Owner | Work |
| :--- | :--- |
| Controls | The layout layer (Arena, Brawler, Simple, touch): gestures into actions, quantisation, remapping. In `sim/input`: the derived stance, the perfect-block edge, the direction class, the request queue for short combos and its hashed state |
| Encounter | The director reads the derived states at exchange start, the interrupt windows (dodge cancel, perfect block, burst, reversal), and no beam fired on its own. The AI writes intent v2 |
| Combat | Energy-mode piece families, selected by `mode`; the context actions |
| UI | The mode chip and the context icon read sim state, not the intent |
| Tools | The input schemas |

## 5. Slices

1. **I1, transport (Simulation; small).**
   - `SimIntent` gains the v2 fields next to today's (a superset, for one slice), plus `pack` and `unpack`.
   - The hash list, replay v3 and the scripted-replay generator follow.
   - `control.gd` still acts on today's subset.
   - Proof: with the new fields left out of the hash, the goldens reproduce; then one regeneration.
   - Tests: pack round trip over every field's range; replay v3 record, play, JSON round trip; a changed bit is caught; a v2 file is refused.
2. **I2, consumption (Controls, then Encounter's Q4).** `control.gd` derives the stance and classifies direction. The director takes the interrupt requests. The AI writes v2.
3. **I3, removal (Simulation).** `stance`, `dash` and `charge` leave the record once nothing writes them. The intent version goes to 3, and replays from I1 and I2 are refused.

## 6. Questions for Controls (through the EP)

1. Is tap against hold always resolved in the layout layer, as proposed? The alternative is that the sim resolves it from held ticks. That would put layout timing rules inside replays.
2. Stick quantisation: is 8 bits per axis enough for analogue flight, or should it be an angle plus a magnitude?
3. Is `cancel` a separate action, or always the dodge tap? A separate bit costs nothing and lets a layout bind it apart.
4. `special` 0 to 2 matches three loadout specials. Is a fourth slot wanted?
5. Is `mode` −1 (auto) per tick, or a match setting outside the intent? Per tick is simpler for the AI and the Simple layout.
6. Does a held `power` with a request on the same tick fire the special on that tick, with no extra latency rule in the sim?
