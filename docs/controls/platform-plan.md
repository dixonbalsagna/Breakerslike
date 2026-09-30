# Plan: gamepad support in the web build and on desktop, and mobile's two schemes

Owner: Controls and Game Feel. Date: 2026-09-29. Status: plan. Audience: Rendering (host and input code), Encounter Systems (sim), UI, QA, Accessibility. Bindings are in `input-map.md`, glyphs in `prompt-glyphs.md`, timing in `rulings.md`.

## 1. Architecture: three layers, and the sim sees only one

```
device events  →  [1] device layer   →  [2] binding layer  →  [3] intent builder  →  SimIntent per tick per slot  →  sim
(Godot input)     normalise per          bindings (data) +     once per sim tick:       (recorded in the replay)         (buffers, holds,
                  device                 user overrides        edges, holds, sticks                                     windows live here)
```

- **Layer 1, device.** Reads Godot events (`InputEventKey`, `InputEventJoypadButton`, `InputEventJoypadMotion`, touch) into a per-device state: buttons held, edges since the last tick, axes. It is host code and never touches the sim. Today's equivalent is `render/core/main.gd` (`_unhandled_input`) plus `sim_host.gd` (`held`, `edges`).
- **Layer 2, bindings.** Maps device controls to *actions* per slot. Defaults are data (`data/input/bindings.json`, mine); the player's overrides are `user://input.json`. Rebinding writes only the override.
- **Layer 3, intent builder.** Once per sim tick, per slot: build a `SimIntent` (`input-map.md` §1) from the action states: edges as bools, holds as bools, sticks quantised to 1/16 integers, `stanceStep` from cycle edges. This is the only thing recorded in a replay and the only thing a network peer sends.
- **The sim owns everything that changes behaviour:** the weight and signature state, hold counters (`confirmTicks`) and hit-stop are integer state on the fighter and in `S`. The host never buffers on the sim's behalf. Today the host holds edges across a freeze (`step()` returns false, `sim.gd:73-76`); under this plan the input stage runs during a freeze, so what the replay records is what the sim saw.
- **No wall-clock timing anywhere below layer 3.** Press times are ticks. A key that goes down and up between two ticks is kept as an edge (as `edges` does now), so no press is lost at any frame rate.

## 2. Godot input, concretely

| Concern | Choice |
| :--- | :--- |
| Keyboard | Physical keycodes as today (`RenderKeys.code`). Add `Quote`, `Backquote`, `Minus`, `BracketLeft` to `NAMED` (Rendering) |
| Pad buttons | `InputEventJoypadButton` events set edges; `Input.is_joy_button_pressed(device, button)` gives holds. Buttons are positional (`JOY_BUTTON_A` = south) |
| Sticks and triggers | Poll `Input.get_joy_axis` at the start of each sim tick (do not accumulate motion events). Apply deadzone 0.20 inner, 0.90 outer, quantise to 1/16, square gate (`input-map.md` §3.1). Triggers digital, on 0.35, off 0.25 |
| Event flooding | `Input.use_accumulated_input = false` so no event is merged away between ticks |
| Controller database | Godot's bundled SDL mapping database covers Xbox, PlayStation and Switch-family pads; no per-pad code |
| Device to slot | First button press from a pad claims the left fighter on AI, else the right (`input-map.md` §6). `Input.joy_connection_changed` handles hot-plug |
| Disconnect | Release everything (as `release_all` does on focus-out, `main.gd:443-446`), show "reconnect", keep the fighter idle. Never hand it to the AI without the player choosing |
| Focus loss | Existing `NOTIFICATION_APPLICATION_FOCUS_OUT` handler releases all; extend it to pad state |
| Actions in menus | Godot's `InputMap` actions (`ui_accept`, `ui_cancel`, `ui_up`…) with pad events added, so menus work with pad and keyboard; in-match actions do **not** use `InputMap` for the sim, only for remapping storage |
| Rumble | `Input.start_joy_vibration(device, weak, strong, duration)`: optional. Used only for `press_ack` and struggle beats, never alone |

## 3. Desktop (Windows, Linux, macOS)

- Works with Godot's SDL mappings, XInput and Steam Input (when distributed through Steam, Steam Input presents an Xbox-style pad; the bindings above assume that layout).
- Latency: measure with the harness in `rulings.md` §10. Target 100 ms button to photon on wired pads. Bluetooth adds up to 15 ms and is reported, not fixed.
- Gyro, back paddles: not used.
- Linux: udev permissions for `/dev/input` are the player's; document them in the readme.

## 4. Web (single-threaded build; `variant/thread_support=false` in `export_presets.cfg`)

| Concern | Plan |
| :--- | :--- |
| API | Godot's web export reads the browser Gamepad API with the "standard" mapping, so the same buttons appear as on desktop |
| First use | Browsers hide a pad until it is touched. Show "Press any button on your controller" in the menu; a connection event only fires after the first press. Test on Chrome, Edge, Firefox and Safari |
| Focus | Gamepad data is only delivered to a focused tab; the keyboard needs canvas focus. On blur, release all and pause (the existing focus-out handler already releases keys) |
| Page keys | Space, arrows and Tab must not scroll or move focus. The handler already calls `set_input_as_handled` (`main.gd:375`); verify in the HTML shell (`build/web/index.html`) that `keydown` for these is `preventDefault`ed |
| Timing | The main loop follows `requestAnimationFrame`; the sim runs on its fixed 60 Hz accumulator, so a 144 Hz display samples inputs at most one display frame late. Never derive a window from frame time |
| Latency | Budget 133 ms button to photon on web (`rulings.md` §10). The web path adds a frame for the Gamepad API poll and browser compositing; log it, do not paper over it |
| Rumble | Available on some Chromium builds through the Gamepad API's vibration actuator; treat as absent elsewhere. Never carry information alone |
| Keyboard layout labels | `DisplayServer.keyboard_get_label_from_physical` may be missing on web; fall back to QWERTY labels and say "key position" (`prompt-glyphs.md` rule 3) |
| Touch | Same build serves touch devices; the mobile schemes (§7) are enabled when touch input is the last device used |
| CI | The live build is at dixonbalsagna.github.io/orb-combat-ex/play/. A scripted check drives synthetic events into the exported page for the keyboard; pads need a manual pass on each browser, logged in `docs/controls/pad-test-log.md` |

## 5. Rebinding and settings

- **UI:** a controls screen per device with the action list, the current glyph, and "press a key or button". Duplicates are refused with a message. "Reset to default" per device.
- **Storage:** `user://input.json`: bindings per device family, stick deadzones, toggle options, stance style (bumper cycle or radial), glyph style, struggle timing offset (−6 to +6), assist flags.
- **Accessibility options that live here:** hold-to-toggle for dash, charge and special; stance radial; pad-only one-hand layouts (a preset that moves dash to a bumper for a one-handed pad); the timing-press assists no longer exist (there is no timing press). Accessibility derives any presets from `stage-c-spec.md`.
- **Nothing here changes the sim's rules.** The only match-header values are `hitstopScale` and any handicap Game Design defines.

## 6. Tests and QA

| Test | Pass |
| :--- | :--- |
| Intent-builder unit tests (headless): deadzone, quantisation, square gate, cycle, debounce, priority (`transform` > `special` > `charge`) | all cases match a table |
| Synthetic-event test: the same script through keyboard events and pad events yields **identical** intents | byte-identical logs |
| Replay: a match with mixed devices replays to the same hash from the intent log alone | hash equal |
| Latency harness per platform (event, consuming tick, drawing frame) | p95 within the budget |
| Parity bots (`input-map.md` §7.7): a route bot per device profile | within 2% |
| Disconnect and focus-out mid-hold: nothing sticks | no stuck hold after re-focus |
| Web pad pass: Chrome, Edge, Firefox, Safari with an Xbox pad and a PlayStation pad | logged |

## 7. Mobile, later (P5): two schemes

Both schemes produce the same `SimIntent` from the same three layers. Neither invents a rule. Landscape is the phone default; portrait is a fallback with the HUD's touch reserve of 22% (`hud-spec.md` §2.2). Orb wants both schemes.

### 7.1 Scheme A: virtual stick and buttons (full control)

| Control | Touch design |
| :--- | :--- |
| Move | Floating left stick: appears where the left thumb lands, dead zone 0.20, quantised like a pad. Full deflection at 90% |
| Dash (hold) | A button under the right thumb's arc, or "flick past the stick's edge to hold dash" (option) |
| Light, heavy, signature | Three buttons in an arc, positions like the pad's X, Y and B: the two weight buttons set the sticky weight, the signature button queues or cancels; the signature ring shows the charge |
| Charge, special | Two hold buttons on the left edge above the stick; the transform hold is a small button shown only when available |
| Stance | A four-segment **stance ring** at the top right that shows the current stance; **tap = next**, **tap a segment = direct**. One tap always changes one stance |
| Layout | Sizes at least 9 mm (about 48 dp); left-handed mirror; a layout editor for position and size |

### 7.2 Scheme B: simplified tap

For players who want the fight, not the flying. The sim still runs the full rules; the interface hides the choices that need fine control.

| Control | Touch design |
| :--- | :--- |
| Move | **Auto-approach**: the fighter holds a comfortable range and follows the opponent. A swipe on the left half sets a **dash direction** (a burst), and a hold there is a hold-dash |
| Weight and signature | **One weight switch** (tap to flip light and heavy; the state shows on it and on the stance ring) and a **signature ring** that appears around it when charge is 45 or more (tap to queue, tap again to cancel). There is no attack button: the director times attacks |
| Stance | The same four-segment ring (tap = next, tap a segment = direct). Optionally a "smart stance" preset that Game Design and Accessibility can define later |
| Charge, special, transform | Two hold buttons on the left, same as scheme A |
| Everything else | Unchanged |

Rules for both schemes:
- **Touch latency budget:** 150 ms button to photon, +2 ticks of tolerance in the parry buffer (`rulings.md`, assist).
- **Haptics:** the Vibration API on Android; none on iOS Safari. Never carry information alone.
- **Multi-touch:** at least three simultaneous touches (stick, an attack button, a hold).
- **Accidental touches:** the transform is a 30-tick hold with a filling ring; edges of the screen ignore touches (safe area, 4%).
- **Online fairness (Orb decides):** scheme B removes fine movement and direct stance selection is the same, so the loss of control is real. Options: (1) allow cross-play with no separation; (2) separate queues by scheme; (3) scheme B only in single-player and local play. This is a product decision with a matchmaking cost.

### 7.3 Order of work (mobile)
1. After the desktop and web gamepad work lands (section 8), make the intent builder accept touch as a device (layer 1).
2. Scheme A first: it maps one-to-one to the pad. Scheme B is layered on top.
3. A hands-on test on two real phones (one Android, one iPhone) before any tuning: touch latency and thumb reach cannot be judged in a desktop emulator.

## 8. Phases and what I need

| Phase | Work | Owner | Needs |
| :--- | :--- | :--- | :--- |
| **G0 (now)** | These documents; rulings for the EP | me | none |
| **G1, when I have the tree** | `SimIntent` (`special`, `transform`, `stanceStep`); `control.gd` (press ticks, buffers, holds, priority, anti-mash, struggle scoring); hit-stop as an integer counter (Stage A: goldens bit-identical; Stage B: apply the table); data file `data/input/feel.json` | me, in `sim/input/`; the hit-stop counter and the `window_open` fields sit in `sim/core/` and `sim/director/`, so the EP names who edits them | A window when nobody else edits the sim; Encounter's loader to read the data; QA to regenerate goldens for Stage B |
| **G2** | Device layer, bindings, intent builder for keyboard and pad on desktop; the intent-builder tests | Rendering hosts it, I specify | Rendering (host and `RenderKeys`) |
| **G3** | Web pad pass on four browsers; rebinding UI; glyphs | Rendering, UI, me | UI/UX for the screen and the glyph art |
| **G4 (P5)** | Mobile schemes A and B; phone tests | me and UI | Orb's ruling on cross-play |

## 9. Note from the EP: touch HUD is live (2026-09-30)

UI's touch-mode HUD (a stance ring and a pause button, hit-tested with `UiHud.touch_target_at`) and Rendering's host glue are live; a tap on the pause button pauses for now. When I build scheme A (§7.1), the intent builder hit-tests `touch_target_at` for the stance ring and replaces the pause-tap glue. The How-to-play card's touch page describes scheme A, so the two are kept in step: any change to §7.1 updates that card through the EP.
