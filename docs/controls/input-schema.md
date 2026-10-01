# Remap data, presets and schemas for Tools (ADR 0008)

Owner: Controls and Game Feel. Audience: Tools and Pipeline. Date: 2026-09-30. Status: proposal; **no files are created in `data/input/` yet**, so CI's data job is not affected. This page supersedes `feel-schema.md` (its hit-stop, hold and stick values carry over into `timing.json` below). The scheme itself is in [input-scheme.md](input-scheme.md).

Conventions (from `tools/schemas/*.schema.json`): JSON Schema 2020-12, `$id` `meridian/<name>`, an integer `schema` constant, closed objects except underscore keys, folder map entry in `tools/validate.js --list`.

## 1. Files

| File | Schema `$id` | What it holds | Who edits |
| :--- | :--- | :--- | :--- |
| `data/input/actions.json` | `meridian/input-actions` | the action list: id, kind, which intent fields it writes, which layers and chords it takes part in | Controls |
| `data/input/layouts.json` | `meridian/input-layouts` | the presets (three pads, three keyboards, two touch) as control-to-action bindings | Controls; players override per slot |
| `data/input/timing.json` | `meridian/input-timing` | every tick value: hold threshold, windows, buffers, lockouts, queue, hit-stop table, stick and trigger | Controls; Game Design owns costs elsewhere |
| `user://input.json` (not in the repo) | `meridian/input-user` | the player's choices: preset per slot, overrides, deadzones, toggles, assists | the settings screen |

Folder map: `data/input/` has three files, each validated against its own schema (match by file name).

## 2. Control ids

A control id names one physical control, never an action.

| Device | Pattern | Examples |
| :--- | :--- | :--- |
| Keyboard | `kb:<KeyboardEvent.code>` | `kb:KeyF`, `kb:Space`, `kb:Shift`, `kb:Semicolon` |
| Pad | `pad:<position>` | `pad:south`, `pad:east`, `pad:west`, `pad:north`, `pad:lb`, `pad:rb`, `pad:lt`, `pad:rt`, `pad:l3`, `pad:r3`, `pad:ls`, `pad:rs`, `pad:dpad_up`, `pad:start`, `pad:back` |
| Touch | `touch:<widget>` | `touch:stick`, `touch:attack`, `touch:guard`, `touch:power`, `touch:context`, `touch:transform`, `touch:dodge`, `touch:mode`, `touch:light`, `touch:heavy`, `touch:signature`, `touch:pause` |

## 3. `actions.json`

```json
{
  "schema": 1,
  "actions": [
    { "id": "move",        "kind": "axis",  "fields": ["mx", "my"] },
    { "id": "light",       "kind": "press", "fields": ["light"] },
    { "id": "heavy",       "kind": "press", "fields": ["heavy"] },
    { "id": "signature",   "kind": "press", "fields": ["sig"] },
    { "id": "guard",       "kind": "hold",  "fields": ["guard", "guardPress"] },
    { "id": "dodge",       "kind": "hold",  "fields": ["dodge", "dodgePress"] },
    { "id": "power",       "kind": "hold",  "fields": ["power", "powerPress"], "layer": "power" },
    { "id": "special1",    "kind": "layer", "layer": "power", "fields": ["special"], "value": 1 },
    { "id": "special2",    "kind": "layer", "layer": "power", "fields": ["special"], "value": 2 },
    { "id": "special3",    "kind": "layer", "layer": "power", "fields": ["special"], "value": 3 },
    { "id": "special_auto","kind": "layer", "layer": "power", "fields": ["special"], "value": 4 },
    { "id": "context",     "kind": "press", "fields": ["context"] },
    { "id": "mode",        "kind": "press", "fields": ["mode"] },
    { "id": "transform",   "kind": "chord", "fields": ["transform"] },
    { "id": "upgrade_heavy","kind": "gesture", "fields": ["upgrade"], "value": 1 },
    { "id": "upgrade_sig", "kind": "gesture", "fields": ["upgrade"], "value": 2 },
    { "id": "pause",       "kind": "system" },
    { "id": "hints",       "kind": "system" }
  ]
}
```

`burst` has no entry: it is derived by the sim from the `power` tap rules (`input-scheme.md` §3), so every layout produces it the same way.

### Schema (summary)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "meridian/input-actions",
  "title": "input actions (schema 1)",
  "type": "object",
  "required": ["schema", "actions"],
  "properties": {
    "schema": { "const": 1 },
    "actions": {
      "type": "array", "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "kind"],
        "properties": {
          "id": { "type": "string", "pattern": "^[a-z][a-z0-9_]*$" },
          "kind": { "enum": ["axis", "press", "hold", "layer", "chord", "gesture", "system"] },
          "fields": { "type": "array", "items": { "enum": ["mx","my","light","heavy","sig","upgrade","guard","guardPress","dodge","dodgePress","power","powerPress","special","context","mode","transform"] }, "uniqueItems": true },
          "layer": { "enum": ["power"] },
          "value": { "type": "integer", "minimum": 1, "maximum": 4 }
        },
        "additionalProperties": false, "patternProperties": { "^_": {} }
      }
    }
  },
  "additionalProperties": false, "patternProperties": { "^_": {} }
}
```

## 4. `layouts.json`

A preset is a list of bindings. A binding is `{controls: [...], action, layer?}`: one control for a normal binding, two or more for a chord (all down together). `layer: "power"` makes the binding active only while the `power` action is held. A modifier `"hold": "transform"` is not stored: tick values live in `timing.json`.

```json
{
  "schema": 1,
  "presets": [
    { "id": "arena", "name": "Arena", "device": "pad", "players": 1, "default": true,
      "bindings": [
        { "controls": ["pad:ls"],              "action": "move" },
        { "controls": ["pad:lt"],              "action": "dodge" },
        { "controls": ["pad:lb"],              "action": "guard" },
        { "controls": ["pad:rb"],              "action": "mode" },
        { "controls": ["pad:rt"],              "action": "power" },
        { "controls": ["pad:west"],            "action": "light" },
        { "controls": ["pad:north"],           "action": "heavy" },
        { "controls": ["pad:east"],            "action": "signature" },
        { "controls": ["pad:south"],           "action": "context" },
        { "controls": ["pad:west"],  "layer": "power", "action": "special1" },
        { "controls": ["pad:north"], "layer": "power", "action": "special2" },
        { "controls": ["pad:south"], "layer": "power", "action": "special3" },
        { "controls": ["pad:east"],  "layer": "power", "action": "signature" },
        { "controls": ["pad:lt", "pad:rt"],    "action": "transform" },
        { "controls": ["pad:l3", "pad:r3"],    "action": "transform" },
        { "controls": ["pad:start"],           "action": "pause" },
        { "controls": ["pad:back"],            "action": "hints" }
      ] },
    { "id": "brawler", "name": "Brawler", "device": "pad", "players": 1,
      "bindings": [
        { "controls": ["pad:ls"],              "action": "move" },
        { "controls": ["pad:lt"],              "action": "dodge" },
        { "controls": ["pad:lb"],              "action": "guard" },
        { "controls": ["pad:rb"],              "action": "light" },
        { "controls": ["pad:rt"],              "action": "heavy" },
        { "controls": ["pad:west"],            "action": "mode" },
        { "controls": ["pad:north"],           "action": "power" },
        { "controls": ["pad:east"],            "action": "signature" },
        { "controls": ["pad:south"],           "action": "context" },
        { "controls": ["pad:rb"],    "layer": "power", "action": "special1" },
        { "controls": ["pad:rt"],    "layer": "power", "action": "special2" },
        { "controls": ["pad:west"],  "layer": "power", "action": "special3" },
        { "controls": ["pad:east"],  "layer": "power", "action": "signature" },
        { "controls": ["pad:l3", "pad:r3"],    "action": "transform" },
        { "controls": ["pad:start"],           "action": "pause" },
        { "controls": ["pad:back"],            "action": "hints" }
      ] },
    { "id": "simple-pad", "name": "Simple", "device": "pad", "players": 1,
      "slot": { "autoMode": true, "autoBurst": true, "specialPick": "auto" },
      "bindings": [
        { "controls": ["pad:ls"],              "action": "move" },
        { "controls": ["pad:west"],            "action": "light" },
        { "controls": ["pad:west"],            "action": "upgrade_heavy", "gesture": "hold" },
        { "controls": ["pad:north"],           "action": "signature" },
        { "controls": ["pad:east"],            "action": "guard" },
        { "controls": ["pad:south"],           "action": "dodge" },
        { "controls": ["pad:rt"],              "action": "power" },
        { "controls": ["pad:lb"],              "action": "context" },
        { "controls": ["pad:west"],  "layer": "power", "action": "special_auto" },
        { "controls": ["pad:north"], "layer": "power", "action": "signature" },
        { "controls": ["pad:rb"],              "action": "transform" },
        { "controls": ["pad:l3", "pad:r3"],    "action": "transform" },
        { "controls": ["pad:start"],           "action": "pause" }
      ] },
    { "id": "kb-solo", "name": "Keyboard, one player", "device": "kb", "players": 1, "default": true,
      "bindings": [
        { "controls": ["kb:KeyW", "kb:KeyA", "kb:KeyS", "kb:KeyD"], "action": "move", "axis": ["up", "left", "down", "right"] },
        { "controls": ["kb:Space"],            "action": "dodge" },
        { "controls": ["kb:Shift"],            "action": "guard" },
        { "controls": ["kb:KeyQ"],             "action": "mode" },
        { "controls": ["kb:KeyE"],             "action": "power" },
        { "controls": ["kb:KeyJ"],             "action": "light" },
        { "controls": ["kb:KeyK"],             "action": "heavy" },
        { "controls": ["kb:KeyL"],             "action": "signature" },
        { "controls": ["kb:KeyI"],             "action": "context" },
        { "controls": ["kb:KeyJ"], "layer": "power", "action": "special1" },
        { "controls": ["kb:KeyK"], "layer": "power", "action": "special2" },
        { "controls": ["kb:KeyI"], "layer": "power", "action": "special3" },
        { "controls": ["kb:KeyL"], "layer": "power", "action": "signature" },
        { "controls": ["kb:Space", "kb:KeyE"], "action": "transform" },
        { "controls": ["kb:KeyR"],             "action": "transform" }
      ] },
    { "id": "kb-shared-p1", "name": "Shared keyboard, left", "device": "kb", "players": 2, "pair": "kb-shared-p2",
      "bindings": [
        { "controls": ["kb:KeyW", "kb:KeyA", "kb:KeyS", "kb:KeyD"], "action": "move", "axis": ["up", "left", "down", "right"] },
        { "controls": ["kb:KeyF"],             "action": "light" },
        { "controls": ["kb:KeyG"],             "action": "heavy" },
        { "controls": ["kb:KeyR"],             "action": "signature" },
        { "controls": ["kb:KeyV"],             "action": "context" },
        { "controls": ["kb:KeyE"],             "action": "mode" },
        { "controls": ["kb:Space"],            "action": "dodge" },
        { "controls": ["kb:Shift"],            "action": "guard" },
        { "controls": ["kb:KeyQ"],             "action": "power" },
        { "controls": ["kb:KeyF"], "layer": "power", "action": "special1" },
        { "controls": ["kb:KeyG"], "layer": "power", "action": "special2" },
        { "controls": ["kb:KeyV"], "layer": "power", "action": "special3" },
        { "controls": ["kb:KeyR"], "layer": "power", "action": "signature" },
        { "controls": ["kb:Space", "kb:KeyQ"], "action": "transform" }
      ] },
    { "id": "kb-shared-p2", "name": "Shared keyboard, right", "device": "kb", "players": 2, "pair": "kb-shared-p1",
      "bindings": [
        { "controls": ["kb:KeyI", "kb:KeyJ", "kb:KeyK", "kb:KeyL"], "action": "move", "axis": ["up", "left", "down", "right"] },
        { "controls": ["kb:KeyH"],             "action": "light" },
        { "controls": ["kb:KeyM"],             "action": "heavy" },
        { "controls": ["kb:KeyU"],             "action": "signature" },
        { "controls": ["kb:Comma"],            "action": "context" },
        { "controls": ["kb:KeyO"],             "action": "mode" },
        { "controls": ["kb:Period"],           "action": "dodge" },
        { "controls": ["kb:Semicolon"],        "action": "guard" },
        { "controls": ["kb:Slash"],            "action": "power" },
        { "controls": ["kb:KeyH"],   "layer": "power", "action": "special1" },
        { "controls": ["kb:KeyM"],   "layer": "power", "action": "special2" },
        { "controls": ["kb:Comma"],  "layer": "power", "action": "special3" },
        { "controls": ["kb:KeyU"],   "layer": "power", "action": "signature" },
        { "controls": ["kb:Period", "kb:Slash"], "action": "transform" }
      ] },
    { "id": "touch-simple", "name": "Simple touch", "device": "touch", "players": 1,
      "slot": { "autoMode": true, "autoBurst": true, "specialPick": "auto" },
      "bindings": [
        { "controls": ["touch:stick"],         "action": "move" },
        { "controls": ["touch:attack"],        "action": "light" },
        { "controls": ["touch:attack"],        "action": "upgrade_heavy", "gesture": "hold" },
        { "controls": ["touch:attack"],        "action": "upgrade_sig", "gesture": "swipe_up" },
        { "controls": ["touch:guard"],         "action": "guard" },
        { "controls": ["touch:power"],         "action": "power" },
        { "controls": ["touch:attack"], "layer": "power", "action": "special_auto" },
        { "controls": ["touch:stick"],         "action": "dodge", "gesture": "flick" },
        { "controls": ["touch:stick"],         "action": "dodge", "gesture": "outer_ring_hold" },
        { "controls": ["touch:context"],       "action": "context" },
        { "controls": ["touch:transform"],     "action": "transform" },
        { "controls": ["touch:pause"],         "action": "pause" }
      ] },
    { "id": "touch-full", "name": "Full touch", "device": "touch", "players": 1,
      "bindings": [
        { "controls": ["touch:stick"],         "action": "move" },
        { "controls": ["touch:stick"],         "action": "dodge", "gesture": "flick" },
        { "controls": ["touch:dodge"],         "action": "dodge" },
        { "controls": ["touch:guard"],         "action": "guard" },
        { "controls": ["touch:mode"],          "action": "mode" },
        { "controls": ["touch:power"],         "action": "power" },
        { "controls": ["touch:light"],         "action": "light" },
        { "controls": ["touch:heavy"],         "action": "heavy" },
        { "controls": ["touch:signature"],     "action": "signature" },
        { "controls": ["touch:context"],       "action": "context" },
        { "controls": ["touch:light"],     "layer": "power", "action": "special1" },
        { "controls": ["touch:heavy"],     "layer": "power", "action": "special2" },
        { "controls": ["touch:context"],   "layer": "power", "action": "special3" },
        { "controls": ["touch:signature"], "layer": "power", "action": "signature" },
        { "controls": ["touch:transform"],     "action": "transform" },
        { "controls": ["touch:pause"],         "action": "pause" }
      ] }
  ]
}
```

One more preset, `kb-p2-arrows` (the legacy arrow keys for `move` with the other `kb-shared-p2` keys), is mechanical and omitted here. Left-handed touch is a setting that mirrors the anchors, not a preset.

### Schema (summary)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "meridian/input-layouts",
  "title": "input layouts (schema 1)",
  "type": "object",
  "required": ["schema", "presets"],
  "properties": {
    "schema": { "const": 1 },
    "presets": {
      "type": "array", "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "name", "device", "players", "bindings"],
        "properties": {
          "id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
          "name": { "type": "string" },
          "device": { "enum": ["pad", "kb", "touch"] },
          "players": { "enum": [1, 2] },
          "default": { "type": "boolean" },
          "pair": { "type": "string" },
          "slot": {
            "type": "object",
            "properties": {
              "autoMode": { "type": "boolean" },
              "autoBurst": { "type": "boolean" },
              "specialPick": { "enum": ["chosen", "auto"] }
            },
            "additionalProperties": false
          },
          "bindings": {
            "type": "array", "minItems": 1,
            "items": {
              "type": "object",
              "required": ["controls", "action"],
              "properties": {
                "controls": { "type": "array", "minItems": 1, "items": { "type": "string", "pattern": "^(kb|pad|touch):[A-Za-z0-9_]+$" } },
                "action": { "type": "string" },
                "layer": { "enum": ["power"] },
                "gesture": { "enum": ["hold", "swipe_up", "flick", "outer_ring_hold"] },
                "axis": { "type": "array", "items": { "enum": ["up", "left", "down", "right"] }, "minItems": 4, "maxItems": 4 }
              },
              "additionalProperties": false, "patternProperties": { "^_": {} }
            }
          }
        },
        "additionalProperties": false, "patternProperties": { "^_": {} }
      }
    }
  },
  "additionalProperties": false, "patternProperties": { "^_": {} }
}
```

### Cross-reference rules (`--xref`)

| Rule id | Check |
| :--- | :--- |
| `layout-action` | every `action` is an id in `actions.json` |
| `layout-device` | every control id's prefix equals the preset's `device` |
| `layout-required` | each preset binds every **required** action for its device: `move`, `light`, `heavy`, `signature`, `guard`, `dodge`, `power`, `context`, `pause`; `mode` and `special1..3` unless `slot.autoMode` / `specialPick` is `auto`; `special_auto` when `specialPick` is `auto`; `transform` |
| `layout-conflict` | within a preset and a layer, no control is bound to two actions (a control may appear once on the base layer and once on the `power` layer; a `gesture` binding may share a control with its base binding; a control that is part of a chord may also be a single hold binding) |
| `layout-layer` | a `layer: "power"` binding exists only if the preset binds `power`; only `special*`, `signature` and `upgrade*` may be layered |
| `layout-pair` | `pair` names a preset with `players: 2` whose `pair` points back, and the two share no control id |
| `layout-reserved` | no keyboard preset binds `kb:KeyN`, `kb:KeyT`, `kb:KeyY`, `kb:KeyP`, `kb:Escape` or an F-key |
| `layout-default` | exactly one `default: true` per device |
| `layout-axis` | a `move` binding on `kb` has an `axis` with four controls |

## 5. `timing.json`

All values are **whole ticks at 60 per second** unless noted. It carries over `feel-schema.md`'s hit-stop, hold and stick values and replaces its weight and signature-queue blocks.

```json
{
  "schema": 1,
  "ticksPerSecond": 60,
  "tapHold": { "holdStart": 12, "transformConfirm": 30, "encoreConfirm": 18, "encoreOffer": 180 },
  "perfectBlock": { "lightWindow": 8, "heavyWindow": 10, "buffer": 4, "touchBufferBonus": 2,
                    "antiMashLockout": 18, "assistFactor": 2 },
  "dodge": { "buffer": 4 },
  "attackQueue": { "max": 3, "expiry": 36, "upgradeWindow": 24, "heavyKi": 4,
                   "signatureKi": 45, "signatureUnfundedExpiry": 600 },
  "mode": { "toggleCooldown": 12 },
  "touch": { "flickToDodgeTicks": 4, "flickThreshold": 0.7, "outerRingScale": 1.3, "outerRingHold": 6,
             "fullDeflectionSprint": 30, "swipeUpPx": 48, "swipeUpTicks": 24, "edgeIgnoreDp": 8 },
  "stick": { "deadzone": 0.2, "quant": 16, "triggerOn": 0.35, "triggerOff": 0.25 },
  "hitstopTicks": { "light": 4, "chain": 5, "tradeFinal": 6, "heavy": 7, "guardBreak": 8, "parry": 9,
                    "clashWave": 7, "impact": 4, "explosion": 5, "beamConnect": 9, "beamClash": 10,
                    "finisherHit1": 4, "finisherHit2": 7, "finalBlow": 18 }
}
```

Cross-reference rules: `timing-order` (`triggerOff < triggerOn`), `timing-perfect` (`lightWindow <= 15` and `heavyWindow <= 20`, the authored tells), `timing-hold` (`encoreConfirm <= transformConfirm < encoreOffer`), `timing-queue` (`signatureUnfundedExpiry >= 180`), `timing-hitstop-order` (as `feel-schema.md`, a warning). The schema is the obvious object-of-integers form with the key set above required; I will send the full JSON when Tools wants it, in the same style as section 3.

Costs, cooldowns and the perfect-block reward are **not** here: they belong to Game Design's economy data.

## 6. `user://input.json` (not in the repo)

```json
{
  "schema": 1,
  "slots": [
    { "device": "pad", "preset": "arena",
      "overrides": [ { "controls": ["pad:east"], "action": "signature" } ],
      "deadzone": 0.2, "toggles": { "dodge": false, "guard": false, "power": false },
      "assist": { "perfectBlock": false },
      "touch": { "leftHanded": false, "sprintStyle": "outer_ring" } }
  ]
}
```

- **Remap rules:** a player rebinds one action to one control at a time; the settings screen refuses a control already used on the same layer and offers a swap. `Reset to preset` clears `overrides`. `layout-required` still applies to the result; the screen shows what is unbound and will not leave a required action empty.
- **Device to slot:** the first device to press claims a slot (`platform-plan.md`). The preset is chosen per device family, with the `default: true` preset as the start.
- **Replay header:** `slot` flags (`autoMode`, `autoBurst`, `specialPick`) and `assist` values are recorded; bindings are not (a replay stores intents).

## 7. Fixtures for `tools/fixtures/`

- **valid:** the full `layouts.json` above; `timing.json` above; `actions.json` above.
- **invalid, one each:** an unknown action id; a pad control in a keyboard preset; a missing `guard`; the same control bound to two actions on one layer; a `power` layer without `power`; a `pair` that does not point back; a preset binding `kb:KeyP`; a `kb` move binding without an `axis`; two defaults for one device; `triggerOff` above `triggerOn`; an underscore key (must be accepted).
