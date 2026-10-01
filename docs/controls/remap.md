# Remap support and the Full touch preset

Owner: Controls and Game Feel. Date: 2026-10-01. Status: built and tested (`remap_test` 94, `touch_full_test` 560 checks); the host wiring is [remap-glue.patch](remap-glue.patch) against HEAD, for Rendering. Spec: `input-schema.md` sections 6 and 9; the Full layout is `input-scheme.md` section 6.2.

## The Full touch preset (`touch-full`, tablets)

`SimInputHub.set_touch_preset("touch-full")` (UI's `touch_preset` option) switches the touch layer. `SimTouch.layout(vw, vh, dp, portrait, left_handed, margin, full)` gives the geometry; with `full = true` it holds nine buttons: a diamond on the right (**Light** west, **Heavy** north, **Signature** east, **Context** south), **Power** and **Mode** above it, **Transform** beside it, and **Dodge** and **Guard** stacked on the left edge. The floating stick keeps the left zone. Every button goes through the same `SimLayout` as the pad and keyboard, so a tap fires on press, Dodge held 12 ticks is a sprint, Power held then a diamond button is a special (Light, Heavy, Context = 1, 2, 3; Signature is the signature), Mode toggles with its cooldown, and Transform held 30 ticks sends the edge. A stick flick is a dodge tap and a dash; the outer ring is a sprint. `display_state()` adds `full: {widget: {down}}` for UI's pressed looks, and `transform_hold()` is the ring. Layout checked on seven screens: on screen, 48 dp targets, no overlaps, hit tests. At least five fingers work at once.

## What the Remap screen calls

| Call | What it does |
| :--- | :--- |
| `SimInputRemap.listing(preset)` | one row per binding: `{action, layer, index, controls, fixed}`; `fixed` rows (gestures, the keyboard move axis) are not remappable |
| `SimInputRemap.rebind(preset, action, layer, index, controls)` | `{ok, preset, conflict, error}`; a control already on another action of the same layer is a conflict (`{action, layer, control}`); an index at the count adds a binding |
| `SimInputRemap.swap(preset, action, layer, index, control)` | the conflicting action takes the control this one gave up |
| `SimInputRemap.remove(preset, action, layer, index)` | removes one binding |
| `SimInputRemap.diff(original, edited)` | the override rows UI emits in `remap_changed`: `{controls, action, layer?}` for every action whose base bindings changed |
| `SimInputData.apply_overrides(id, overrides)` | replaces the effective preset with the shipped one plus the overrides; idempotent; an empty list restores the shipped preset; returns the effective preset, so `SimInputData.preset(id)` (and every glyph) follows. `SimInputData.original(id)` is the shipped one |
| `SimInputData.check_bindings(preset)` | `[{rule, action, control}]`: `layout-reserved` (N, T, Y, P, Esc, F-keys), `layout-required`, `layout-conflict`, `layout-device`, `layout-pair` (the two shared-keyboard halves share a key) |
| `SimInputRemap.missing_required(preset)` | the required actions left unbound |
| `SimInputData.save_overrides()` | writes the current overrides to `user://input.json`; `SimInputData.load_and_apply()` reads it at startup |
| `SimInputHub.reload_layouts()` | releases everything and rebuilds the keyboard layouts and the pads from `SimInputData.preset(...)`; safe mid-match, pad slots are kept |
| `SimInputNames.pad_control_from_event(e)` | the `pad:<position>` a button press or a trigger past `triggerOn` stands for, for "press a button" capture; `SimInputNames.PAD_BUTTONS` is the one table; a key is `"kb:" + RenderKeys.code(e)` |

**The file** is UI's shape: `{"schema": 1, "presets": {"arena": {"overrides": [{"controls": ["pad:east"], "action": "signature"}]}}, "options": {}}`. Unknown presets and actions are dropped on load and reported, never fatal.

**Rulings applied:**
- Pause and hints cannot be rebound (Start stays pause); touch presets are not remapped; a gesture binding is part of the layout.
- Mode can be rebound.
- A **layered partner follows its base action**: the partners are read from the shipped preset (a layered binding on the same control as a base binding), so special1 moves with light, special2 with heavy and special3 with context (or with mode on the Brawler). A layered row is never edited on its own, and `diff` never emits one.
- The two shared-keyboard halves cannot share a key (`layout-pair`); `check_bindings` reports it. Replays are unaffected: an intent v2 record carries no binding.

**Shared names (question 5):** yes for pads. `PAD_BUTTONS`, the trigger names and the control-id helpers now live in `sim/input/names.gd`, and the patch removes main's copy. Key names stay with `RenderKeys.code(event)`, which needs `InputEventKey` and so belongs in render; the screen builds a key's control id as `"kb:" + code`.

## Changes after UI's first run (2026-10-01)

1. **Chords stay fixed, members are free.** `controls_used` no longer counts a chord's controls, so on Arena L3 and R3 (chord-only) are free, and LT and RT belong to dodge and power as single bindings. A chord is never created, changed or overwritten by `rebind` or `swap` (`rebind` of several controls for a non-move action is refused: "chords are fixed"). `listing` marks chord rows `fixed: true`. Dodge or Power can now swap with another action across a chord member, and the chord stays.
2. **Gesture bindings follow their base action.** On Simple, `upgrade_heavy` (hold) sits on the same button as light, and it now moves with it, with the power-layer specials. The override row carries only the base action.
3. **The keyboard move axis is rebindable** as one row: `{action: "move", controls: [up, left, down, right], fixed: false}`. `rebind(preset, "move", null, 0, four_keys)` needs four different keys; each is checked against the other actions (the conflict names the key and its action); another action cannot take a move key; `swap` with a move key is refused (the screen rebinds the whole row). `diff` emits one `{controls: [4], action: "move"}` row, `apply_overrides` keeps the axis shape, and `check_bindings` applies the pair rule to all four keys. The pad stick stays fixed (its row is `fixed: true`).

**What UI must change:** show chord rows as fixed (greyed, no capture); allow L3, R3 and the other chord members when capturing a control for a single binding; show the Fly row on the keyboard as one row that captures four keys in order (Up, Left, Down, Right) and emit `{controls: [four keys], action: "move"}`; do not offer "swap" on a move-key conflict; leave the pad's move row fixed. Nothing changes for gesture or layered rows (they follow on their own).
