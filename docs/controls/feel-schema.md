# Schema proposal for `data/input/feel.json` (for Tools)

Owner: Controls and Game Feel. Audience: Tools and Pipeline (`tools/validate.js`, `tools/schemas/`). Date: 2026-09-30. Status: proposal. The values are in `stage-c-spec.md` §7; this page is the schema and the checks.

## 1. Conventions followed

From the existing schemas (`tools/schemas/*.schema.json`): JSON Schema draft 2020-12, `$id` `meridian/<name>`, a `schema` integer constant, closed objects (`additionalProperties: false`) except that **keys starting with an underscore are allowed** for notes, and the file lives in a folder mapped to its schema by `node tools/validate.js --list`.

- **Folder map entry:** `data/input/` → `input-feel`. One file today, `feel.json`.
- **`schema` is the integer `1`.** The draft in `stage-c-spec.md` §7 writes `"input.feel/2"` as a string; it is corrected to the integer `1` here (the first published version of this file).
- **Times are integer ticks** at 60 per second (`ticksPerSecond` is a documented constant, `const 60`). No seconds anywhere in this file.

## 2. The schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "meridian/input-feel",
  "title": "input feel (schema 1)",
  "description": "data/input/feel.json: weight, signature intent, hit-stop, hold and stick settings for sim/input and the hit-stop counter. Times are whole ticks at 60 per second. Policy: closed except underscore keys.",
  "type": "object",
  "required": ["schema", "ticksPerSecond", "weight", "signature", "stance", "hitstopTicks", "hold"],
  "properties": {
    "schema": { "const": 1 },
    "ticksPerSecond": { "const": 60 },
    "weight": {
      "type": "object",
      "required": ["start", "heavyKi"],
      "properties": {
        "start": { "enum": ["light", "heavy"] },
        "heavyKi": { "type": "number", "minimum": 0, "maximum": 100 }
      },
      "additionalProperties": false, "patternProperties": { "^_": {} }
    },
    "signature": {
      "type": "object",
      "required": ["ki", "maxWaitFunded", "unfundedExpiry", "clockPausedBy"],
      "properties": {
        "ki": { "type": "number", "minimum": 0, "maximum": 100 },
        "maxWaitFunded": { "type": "integer", "minimum": 1 },
        "unfundedExpiry": { "type": "integer", "minimum": 1 },
        "clockPausedBy": {
          "type": "array",
          "uniqueItems": true,
          "items": { "enum": ["charge", "special", "transform", "cinematic", "exchange"] }
        }
      },
      "additionalProperties": false, "patternProperties": { "^_": {} }
    },
    "stance": {
      "type": "object",
      "required": ["cycleRepeat", "cycleDebounce"],
      "properties": {
        "cycleRepeat": { "type": "integer", "minimum": 1 },
        "cycleDebounce": { "type": "integer", "minimum": 0 }
      },
      "additionalProperties": false, "patternProperties": { "^_": {} }
    },
    "hitstopTicks": {
      "type": "object",
      "required": ["light", "chain", "tradeFinal", "heavy", "guardBreak", "parry", "clashWave", "impact",
                   "explosion", "beamConnect", "beamClash", "finisherHit1", "finisherHit2", "finalBlow"],
      "propertyNames": { "pattern": "^(_.*|[a-z][A-Za-z0-9]*)$" },
      "additionalProperties": { "type": "integer", "minimum": 0, "maximum": 60 }
    },
    "hold": {
      "type": "object",
      "required": ["confirmTicks", "encoreConfirm", "encoreOffer", "stickDeadzone", "stickQuant", "triggerOn", "triggerOff"],
      "properties": {
        "confirmTicks": { "type": "integer", "minimum": 1 },
        "encoreConfirm": { "type": "integer", "minimum": 1 },
        "encoreOffer": { "type": "integer", "minimum": 1 },
        "stickDeadzone": { "type": "number", "minimum": 0, "exclusiveMaximum": 0.5 },
        "stickQuant": { "type": "integer", "minimum": 2, "maximum": 127 },
        "triggerOn": { "type": "number", "exclusiveMinimum": 0, "maximum": 1 },
        "triggerOff": { "type": "number", "minimum": 0, "exclusiveMaximum": 1 }
      },
      "additionalProperties": false, "patternProperties": { "^_": {} }
    }
  },
  "additionalProperties": false,
  "patternProperties": { "^_": {} }
}
```

Note for Tools: the closed-object idiom above (`additionalProperties: false` beside `patternProperties: {"^_": {}}`) is how I read the "closed except underscore keys" policy; if `tools/lib/core.js` implements the policy differently (a flag, or a keyword), use that instead. `hitstopTicks` is an open-valued map with a required key set so a new impact class can be added by data plus one code read.

## 3. Cross-reference rules (`--xref`)

| Rule id | Check | Why |
| :--- | :--- | :--- |
| `feel-order` | `triggerOff < triggerOn` | Hysteresis has to open a gap |
| `feel-cap` | `signature.maxWaitFunded <= signature.unfundedExpiry` | A funded signature must not outlive an unfunded one |
| `feel-encore` | `hold.encoreConfirm <= hold.confirmTicks` and `hold.encoreConfirm < hold.encoreOffer` | The Encore confirm is the short one and must fit in the offer |
| `feel-hitstop-order` | `light <= chain <= heavy <= guardBreak <= parry` and `finalBlow >= beamClash >= beamConnect` | The impact hierarchy of `rulings.md` §5; a violation is a warning, not an error |
| `feel-hitstop-budget` | no single value above 30 except `finalBlow` (up to 30) | Guards against a freeze that reads as a hang |
| `feel-ticks-only` | no key ends in `Seconds` or `Sec` and no value is a non-integer where the schema says integer | The file is in ticks |

## 4. Who reads it, and how

- **`sim/input/control.gd` and the fighter state** read `weight`, `signature` and `hold` at match start into the sim (a `SimFeel` constants object), the way Combat's loader reads `data/combat/`. The contents are part of the match's inputs: hash the file into the replay header, so a replay names the data it used.
- **The hit-stop counter** (`sim.gd`, `damage.gd`) reads `hitstopTicks`; the strike ops name a class (`"light"`, `"heavy"`, …) instead of carrying seconds. Until Stage B, the class table equals today's effective ticks.
- **The host** (`render/`) reads `stance`, and the stick and trigger values under `hold`, for the intent builder.
- **No code carries a window, buffer or hit-stop number.** A grep for the literals in `sim/input/` and the counter's write sites is part of Stage B's acceptance.

## 5. Fixtures for `tools/fixtures/`

- **valid:** the sample in `stage-c-spec.md` §7 with `schema` `1`.
- **invalid, one per rule:** `weight.start` `"medium"`; a missing `hitstopTicks.finalBlow`; a non-integer `maxWaitFunded`; `triggerOff` above `triggerOn`; `encoreOffer` below `encoreConfirm`; an unknown top-level key; an underscore key (must be accepted).

## 6. Versioning

`schema` bumps when a key's meaning changes (not when a value does). A change to the meaning of a value that alters behaviour is a golden regeneration, so it goes in the same commit as the new goldens (ADR 0006).
