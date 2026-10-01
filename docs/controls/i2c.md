# I2c: the layout layer produces intent v2 (keyboard, pad, touch)

Owner: Controls and Game Feel. Date: 2026-10-01. Status: built and tested; the render glue is applied in the working tree (and as [i2c-glue.patch](i2c-glue.patch) against HEAD). No sim core edits; goldens unchanged. Spec: [input-scheme.md](input-scheme.md); the record: `docs/architecture/intent-v2.md`.

## What a player gets

| Device | Layout | What the sim reads |
| :--- | :--- | :--- |
| One human on a keyboard | `kb-solo`: WASD, Space dodge and sprint, Shift guard, Q mode, E power, J K L I attacks and context, R transform | v2 intent; stance derived from the held guard, dodge and sprint |
| Two humans on one keyboard | `kb-shared-p1` (left hand) and `kb-shared-p2` (right: IJKL move, H M U comma, O, period, semicolon, slash) | the same, one layout per slot |
| Gamepad | `arena` by default (Brawler and Simple are data presets: set `SimInputHub.pad_preset`) | the same; a pad takes the first human slot without one |
| Touch | `touch-simple` (stick, Attack, Guard, Power, Transform in the context slot) | the same, with the Simple assists set in the match setup |

Held guard, dodge and sprint drive the stance (SimAct derives it); a tap fires on press; a hold adds behaviour on top. The director still starts light, heavy and signature exactly as before, so play is no worse than it was.

**The transform control is real.** A form that is ready is taken by: the **chord** (both triggers, or Space and E on the solo keyboard, Space and Q on the shared one) held 30 ticks, **L3 and R3** on every pad, a **single key** (R solo), **RB** on the Simple pad, or the **Transform button** on touch. Holding charge alone no longer transforms a v2 slot.

## Files (mine)

| File | What |
| :--- | :--- |
| `sim/input/input_data.gd` | loads `data/input/*.json` once, with a built-in copy of the shipped timing as fallback; `load_and_apply()` sets `SimAct.queueMax`, `dodgeWindow` and `awayDead` from it |
| `sim/input/layout.gd` | `SimLayout`: the keyboard and pad resolver (tap, hold, power layer, chord, mode toggle, hold-attack bridge, analog triggers with hysteresis, stick gate) |
| `sim/input/touch.gd` | `SimTouch` now builds intent v2 too (guard and its edge, flick as the dodge edge, sprint, power with tap and channel, the layer special, the transform hold) |
| `sim/input/hub.gd` | `SimInputHub`: which device drives which slot (last input wins, held controls are let go on a switch), the solo or shared keyboard, pads by device id, the match setup (`v2` and the Simple assists), `SimIntent.canon` on every intent |
| `data/input/actions.json`, `layouts.json`, `timing.json` | the three data files from the schema (validator: 0 errors) |
| `sim/input/test/layout_test.gd`, `hub_test.gd` | 113 and 34 checks; `touch_test.gd` 167 and `touch_glue_test.gd` 16 were updated |

For a v2 slot the layer also writes today's `dash` (a dodge lunge or a sprint) and `charge` (power held past 12 ticks), because `fighter.gd` still reads them until I3; `stance` is left unset.

## Render glue (granted by the EP; Rendering reviews)

- `render/core/sim_host.gd`: a `hub` replaces the bridge's touch fields; `new_match` passes `hub.setup()`; `tick()` takes `hub.intent(k)` for each human slot and `hub.consumed()` after a consumed step; key calls and `release_all` forward to the hub. `host.touch` stays as an alias of the hub's touch layer.
- `render/core/main.gd`: `SimInputData.load_and_apply()` before the host is built; joypad buttons, the left stick and the analog triggers go to the hub (`_pad_event`; Start pauses); touch events go to the hub.

## Proof

On a clean export of HEAD plus these files:

| Check | Result |
| :--- | :--- |
| Golden check (`parity.gd`) | passed, goldens unchanged (no core line was touched) |
| Render determinism (60 Hz, 144 Hz, jitter) | passed |
| Seam sweep | passed |
| `npm test --prefix sim` | all 5 stages passed |
| Validator (`node tools/validate.js`) | 46 files, 0 errors |
| `touch_test` / `layout_test` / `hub_test` / `touch_glue_test` | 167 / 113 / 34 / 16 checks, 0 failed |
| Real sim through the hub | guard is DEFENSIVE, a Space tap is Dodge for its window, Space held while moving away is Escape, a light starts a light exchange, the chord or R takes a ready form and raises the tier, power held alone does not |

**Phone-profile web check** (a web export of that clean copy, 844 by 390, real touch events on the canvas): the touch buttons draw; a held Guard shows GUARD on the plate with the guard ring ([touch](img/i2c-touch-guard.jpg)); a key press moves the HUD to keyboard mode and Shift shows GUARD, releasing it shows PRESS ([keyboard](img/i2c-keyboard-guard.jpg)); the How to play card still closes by touch. Pads cannot be driven in the browser pane, so the pad path is covered by the scene test (synthetic `InputEventJoypad` events through `main.tscn`: LB guard, RT charge, the stick) and by `layout_test`.

## Known gaps and asks

1. **UI:** the keyboard legend and the How to play card still describe the old keys (Space "Dash", R "Signature", keys 1 to 4 for stances) and the old touch scheme; they should follow the presets above. The glyph mapping (`prompt-glyphs.md`) needs the new action names.
2. **Pad preset choice** (Arena, Brawler, Simple) and handedness have no settings screen yet; `SimInputHub.pad_preset` is the hook. The Simple assists are read at match start.
3. **Encore** needs the 18-tick confirm from the sim's availability event; today every transform hold is `transformConfirm` (30).
4. **Dodge** is the stance and a free lunge until Encounter's windows and costs arrive; **burst, special, context, mode** are sent but not read yet; the request queue (`upgrade`) waits for Encounter, so Simple's attack still fires on release.
5. **Palm rejection** (`touch.edgeIgnoreDp`) is data but not yet applied.
6. **Tools:** the schema now carries `chordWindow`, `dodge.stateTicks` and `stick.awayDead`; `dodge.lungeTicks` and `stick.fullAt` are code defaults until it has them.
