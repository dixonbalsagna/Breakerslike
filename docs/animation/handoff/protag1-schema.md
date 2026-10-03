# Schema handoff for the Protagonist's waves (Tools)

Two edits, tested on an export of HEAD with the data files of units 9.25 and 9.26 (0 errors, 0 warnings):

1. New file `tools/schemas/anim-fighters.schema.json` (here: `anim-fighters.schema.json`), and in `tools/schemas/map.json` after the flight rule: `{"match": "data/anim/fighters.json", "schema": "anim-fighters.schema.json"}`.
2. The wave-name pattern takes a fighter's wave: in `anim-wave-keysets.schema.json` (line 108), `anim-wave-manifest.schema.json` (line 15), `anim-wave-entries.schema.json` (line 149) and `anim-wave-entrymap.schema.json` (line 16) change `"^wave[0-9]+$"` to `"^(wave|protag)[0-9]+$"`.
