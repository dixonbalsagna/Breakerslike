# Schema handoff for the Protagonist's waves (Tools)

Two edits, tested on an export of HEAD with the data files of units 9.25 to 9.27 (0 errors, 0 warnings):

1. New file `tools/schemas/anim-fighters.schema.json` (here: `anim-fighters.schema.json`), and in `tools/schemas/map.json` after the flight rule: `{"match": "data/anim/fighters.json", "schema": "anim-fighters.schema.json"}`.
2. The wave-name pattern takes a fighter's wave: in `anim-wave-keysets.schema.json` (line 108), `anim-wave-manifest.schema.json` (line 15), `anim-wave-entries.schema.json` (line 149) and `anim-wave-entrymap.schema.json` (line 16) change `"^wave[0-9]+$"` to `"^(wave|protag|rival)[0-9]+$"`.

3. (2026-10-03, the coverage audit) `data/anim/fighters.json` now has a `more` key under `waves`: an array of wave names (the fighter's other waves: finisher, taunts, blast presses, the shared pair1). `anim-fighters.schema.json` here is `tools/schemas/anim-fighters.schema.json` with that one property added to `waves` (an array of strings matching `^[a-z]+[0-9]+$`, unique); tested on an export of HEAD: validate 0 errors, 0 warnings. The fighters xref (`fighters-wave`) can check that each wave in `more` has a poses file.
