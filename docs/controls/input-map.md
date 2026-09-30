# Input map: keyboard (P1 and P2) and gamepad

Owner: Controls and Game Feel. Date: 2026-09-29. Status: design; code follows when the EP hands me `sim/input/`. Orb wants keyboard and gamepad **equally**: every action has a binding on both, and neither device gets a capability the other lacks (section 7 lists the parity rules).

Stance names below are Narrative's proposals (glossary): **PRESS, GUARD, DODGE, ESCAPE**. The sim ids stay AGGRESSIVE, DEFENSIVE, EVASIVE, ESCAPE.

## 1. The intent record

Today `SimIntent` is `{mx, my, dash, charge, light, heavy, sig, stance}` (`sim/input/intent.gd`). Proposed additions, all raw (the sim does the counting):

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `special` | bool, held | the fighter's own hold (stoke, Press, Swallow It); inert if the fighter has none |
| `transform` | bool, held | a deliberate, once-only choice (Drop the Act, the fold); the sim counts `confirmTicks` |
| `stanceStep` | int −1, 0, +1 | cycle one stance around the ring. If `stance` (direct) is also set, direct wins |

Everything else keeps its meaning. `light`, `heavy`, `sig` are edges (a press this tick); `dash`, `charge`, `special`, `transform` are holds. Sticks are quantised (section 3).

## 2. Keyboard

### 2.1 As live today (exactly `SimKeyboard.KEYS`)

| Action | P1 | P2 |
| :--- | :--- | :--- |
| Move left / right | `KeyA` / `KeyD` | `ArrowLeft` / `ArrowRight` |
| Move up / down | `KeyW` / `KeyS` | `ArrowUp` / `ArrowDown` |
| Dash (hold) | `Space` | `Enter` |
| Light | `KeyF` | `Comma` |
| Heavy | `KeyG` | `Period` |
| Signature | `KeyR` | `Slash` |
| Charge (hold) | `KeyQ` | `Semicolon` |
| Stance 1, 2, 3, 4 | `Digit1`, `Digit2`, `Digit3`, `Digit4` | `Digit7`, `Digit8`, `Digit9`, `Digit0` |

System keys (Rendering's, unchanged): `N` new match, `T` toggle P2 AI, `Y` toggle P1 AI, `P` pause, `Esc` quit (desktop), `F2` legacy HUD, `F3` perf, `F4` feed (Shift+F4 reserved for the full overlay), `F7`/`F8` flash options, `F9` split, `F10` solo split, `F11` reduced motion. Any non-function key hands the fighter to a human (`take_over`).

### 2.2 Proposed additions

| Action | P1 | P2 | Why this key |
| :--- | :--- | :--- | :--- |
| Special (hold) | `KeyE` | `Quote` | Next to charge (`Q`, `;`): "a variant of the charge input", as spec-wounds §1b proposes |
| Transform (hold to confirm) | `KeyX` | `BracketLeft` | Deliberate and rare; out of the fighting cluster, so no accidental holds |
| Stance: previous | `Backquote` | `Digit6` | The key just left of the stance group |
| Stance: next | `Digit5` | `Minus` | The key just right of the stance group |

Notes:
- `RenderKeys` (`render/core/key_codes.gd`) maps only some physical keys by name. `Quote`, `Backquote`, `Minus` and `BracketLeft` fall through to `OS.get_keycode_string`, whose names differ (Godot: `Apostrophe`, `QuoteLeft`, `Minus`, `BracketLeft`; verify at implementation). **Rendering must add these four to `NAMED`** or the bindings will not match. I have not touched that file.
- Bindings follow key **positions** (physical keycodes), so they work on any layout. The glyph shows the local label (`prompt-glyphs.md`).
- **Ergonomic risk (hot-seat, one keyboard):** P2's arrows and `, . / ;` are both under one hand. That is the prototype's map and I keep it, but two humans on one keyboard should be treated as a fallback. The recommended local pairing is one keyboard plus one gamepad (or two gamepads). Rebinding covers the rest. **Orb decides** whether to design a dedicated second keyboard layout.
- Every binding is rebindable (`platform-plan.md` §5). Duplicate keys are refused, not silently shared.

## 3. Gamepad (Xbox layout)

Godot's `JOY_BUTTON_A/B/X/Y` are positional (south, east, west, north). The layout below is by position, so it is identical on Xbox, PlayStation and Switch controllers; only the printed label differs (`prompt-glyphs.md`).

| Action | Xbox binding | Position, hand | Keyboard equivalent |
| :--- | :--- | :--- | :--- |
| Move | Left stick | left thumb | WASD / arrows |
| Dash (hold) | **A** (south) | right thumb | Space / Enter |
| Light | **X** (west) | right thumb | F / comma |
| Heavy | **Y** (north) | right thumb | G / period |
| Signature | **B** (east) | right thumb | R / slash |
| Charge (hold) | **RT** | right index | Q / semicolon |
| Special (hold) | **LT** | left index | E / apostrophe |
| Transform (hold to confirm) | **R3** (right stick click) | right thumb | X / left bracket |
| **Stance: previous / next** (one button) | **LB / RB** | index fingers | prev / next keys |
| Stance: direct (parity with 1 to 4) | **D-pad** up, right, down, left = PRESS, GUARD, DODGE, ESCAPE | left thumb | 1, 2, 3, 4 |
| Parry (defender) | **X or Y** (light or heavy) | | F or G |
| Chain (attacker) | **X or Y** | | F or G |
| Finisher struggle | **X or Y** | | F or G |
| Pause | Start | | P |
| Take over (join) | any button | | any key |
| Dev: new match / toggle AI | View (back) + Start held 1 s / not exposed | | N / T, Y |

**Stance access, the rule.** One press changes one stance, on both devices: the bumpers cycle around the ring (any stance is at most two presses), and the D-pad selects directly. Neither costs a thumb off the stick the way a face button would: the bumpers are index fingers.

**Optional scheme: stance radial** (a setting, off by default). Hold RB and flick the right stick: up = PRESS, right = GUARD, down = DODGE, left = ESCAPE. Recommended only for players who prefer a radial over cycling. The right stick is otherwise unused in a match, so nothing collides.

### 3.1 Stick and trigger handling
- **Deadzone:** inner 0.20 radial, outer 0.90 (full speed at 90% tilt, so no one needs to pin the stick). Response is linear between them.
- **Quantised to 1/16** before the intent is built, stored as integers −16 to +16, so replays and rollback see integers and not floats.
- **Square gate (for parity, until Stage B):** the sim takes `mx` and `my` as independent axes (`fighter.gd:214-237`), so a keyboard diagonal is (1, 1), √2 times faster than a stick held at the diagonal of a round gate. Until Simulation normalises diagonals, the pad output is clamped **per axis** after scaling so a full diagonal also reads (1, 1). Game Design has ruled that the sim normalises diagonals (**Stage B**, because it changes the goldens). When it lands, drop the gate and let the pad use a round gate; keyboard diagonals become (0.707, 0.707) in `control()`. Stage A stays bit-identical.
- **Triggers** are digital: on at 0.35, off at 0.25 (hysteresis).
- **D-pad** edges with a 4-tick debounce; stance cycle repeat while held: 12 ticks.
- **Hot-plug:** `Input.joy_connection_changed`. A pad that disconnects mid-match releases everything (`release_all`) and shows a "reconnect" prompt; the fighter idles. It does not hand the fighter to the AI without the player choosing to.

## 4. The special and transform holds, per fighter

The buttons are slots. What a slot does comes from the fighter's kit. A fighter has at most two extra actions; a kit that needs a third has to use a context prompt on an existing button.

| Fighter | `special` (hold) | `transform` (hold to confirm) | Notes |
| :--- | :--- | :--- | :--- |
| Protagonist | **Stoke**: +25 heat per second, no ki, exposed like charging (attack on him = CHARGE INTERRUPT), spec-wounds §1b | **The fold**, once the ring has closed and the floor has passed | The confirm is an input safeguard, not the 1.5 s interruptible hold Game Design dropped |
| Anti-hero | **Swallow It** (reserved; inert unless Orb keeps it) | **Drop the Act**: once per match, after 2:00, Pride ≥ 50 | Prompt only when available |
| Empress | none | **Encore**: a contextual prompt for 180 ticks (3 s) after she enters the brink, once per match, hold 18 ticks to confirm | Her revisions are automatic. No new button (spec-wounds §2) |
| Cyborg | none (**Press is the charge input held near people**, Game Design) | none | Press needs no slot of its own; the sim reads `charge` plus nearby civilians. Molts and docking are automatic |

**Rally has no button** (Game Design): Rallies fire automatically. The one contextual input is the Empress's **Encore** (`transform`, above); the prompt is drawn only inside its 180-tick offer, with a ring that shows the time left. If she does not confirm, the offer lapses (the AI decides for itself). The 18-tick confirm is shorter than the 30-tick default because the offer is short and she is on the brink; it is a data value (`encoreConfirm`).

### 4.1 Hold rules (sim-side, deterministic)
- **Confirm-hold, `transform`:** `confirmTicks = 30` (0.5 s). The fighter stays in `free`: it is not exposed as charging and is attacked normally. Releasing early resets the count to 0. Reaching 30 ends the hold and starts the respected cinematic. The prompt shows a filling ring and is drawn only when the action is available.
- **Continuous hold, `special` and `charge`:** they behave like today's charge (`fighter.gd:214-256`). At most one hold is active. Priority `transform` > `special` > `charge`; if two are held, the last pressed wins and the earlier resumes on release. Stoke and charge share the exposed `charging` state.
- **A hold begun while illegal** (locked in an exchange, launched, stunned) starts counting when it becomes legal, so a player who keeps the button down does not have to re-press.
- **Toggle option (accessibility, host-side):** dash, charge and special can be set to toggle. The host converts a toggle to the held bool per tick; the sim sees no difference.

## 5. Actions used by the exchange

| Situation | Input | Rule |
| :--- | :--- | :--- |
| Attacker starts an exchange | light, heavy or signature | buffer 6 ticks; priority signature > heavy > light (`rulings.md` §6) |
| Defender parries | light or heavy in the window | 15 ticks light, 20 heavy, buffer 4, clean parry in the last 6 or 8 |
| Attacker chains | light or heavy in the chain window | 36 ticks, buffer 4 |
| Fighter on the brink, finisher | light or heavy on three beats | ±4 ticks, assist ±8 |
| Waiting through the opponent's cinematic | charge, special and stance only | attacks dropped, not buffered |

The signature never parries or chains (CC-010).

## 6. Who drives whom (devices to fighters)

- Keyboard P1 keys drive fighter 0, keyboard P2 keys drive fighter 1, as today.
- A gamepad drives the slot it claims: the first button press from a pad takes the left fighter if it is still on the AI, otherwise the right fighter. The next pad takes the other. Menus can reassign.
- Pads and keyboards can mix freely (one keyboard plus one pad is the recommended local pairing).
- The match records **intents per tick per slot**, never devices, so a replay is device-independent.

## 7. Keyboard and gamepad parity (rules I enforce)

1. **Same action set.** Every row above has both a keyboard binding and a pad binding. A missing one is a bug.
2. **Same reach.** Any stance is at most two presses on both devices; direct select exists on both.
3. **Same movement envelope.** After the gate and quantisation, a pad can reach exactly the (mx, my) values a keyboard can, plus fractions. Fractions never exceed ±1.
4. **Same timing rules.** Windows, buffers and lockouts do not depend on the device. There is no pad-only auto-parry and no keyboard-only shortcut.
5. **Same feedback.** Rumble, when present, only repeats what the picture and audio already say (`press_ack`, struggle beats). It carries no information alone.
6. **No chords needed in play.** Nothing in a fight needs two buttons pressed together; LT or RT plus a face button is comfortable but never required.
7. **Test:** the scripted route and rhythm bots run once per device profile and must agree within 2% on route time and parry rate.
