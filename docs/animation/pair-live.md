# The launch pair live (2026-10-03)

Owner: Animation. The EP's brief: in a live match the Protagonist and the rival play their own waves, and blast presses show a body pose. This is what was built (all in `render/anim` and `data/anim`; nothing of Rendering's or the sim's was edited), how to switch it off, what it costs, and what it waits for from the sim.

## What plays now

- **Each fighter's own waves are baked at match start.** `AnimData.ensure_fighter(roster id)` runs when a fighter's first body is built (`RenderAnim.fighter`). A roster id plays as a fighter of `data/anim/fighters.json`: its key, or the id it `replaces` (KAI is the protagonist, VORR the antihero), or an alias in `pair_live.json` (the neutral id `rival` is the antihero). It bakes the waves of that fighter (`waves.strikes`, `entries`, `energy` and `more`) and the waves both share (`pair_live.json` `shared`: energy1), once, and builds his pick lists and his entries by name.
- **Blows are his own key sets.** `AnimFighter._pair_pick` replaces the placeholder pick: his light or heavy list (every light or heavy strike of his strike waves, never the tail; the sweep and the drop kick join only while their gate is open, as in go-live step 1), walked by the same hash walk, skipping a two-limb key set when a limb of its kind is broken. KAI plays `pr.*` and `ph.*`, VORR `w1.*` and `rb.*`. If a strike beat carries `args.piece` (`strike.jab`: the alchemist's pick, when it exists) that exact key set plays (`AnimData.resolve_strike`). Go-live step 1 (`--wave1-live`) stays as the fallback for anyone else.
- **Entries resolve to his own.** A beat that names `entry.dash` plays `w2.dash` for the rival and `pe.dash` for the Protagonist (`AnimData.resolve_entry`); an id already in the data plays as it is.
- **Far taunts are his own gestures.** `taunt_start` plays one of his gestures (picked by a hash of the tick), cut like the shared shrug by `taunt_end_cut` and the rest. Anyone else keeps the shrug.
- **Blast presses show a body pose** (`pair_live.json`, `AnimFighter.on_blast_cue`, `on_shot`, `on_deflect`, `_energy_layer`; none of it plays inside an exchange, where a blast press is a link drawn by the strike's own poses):
  | The sim sends | He plays |
  | :--- | :--- |
  | cue `blast_windup` | the bolt sequence (`pg.bolt`, `rw.bolt`) from the wind-up |
  | `shot_fire` kind bolt, shard, ricochet | the same sequence aligned so its fire beat is the shot; a second bolt within 10 ticks of the last is a spray beat (`pg.spray`, `en.spray`) |
  | cue `blast_charge` | the charge pose, held (`pn.hold.brace_load`, `rw.charged_brace.charge`) |
  | cue `blast_full` (the flash) | the full-charge pose (`pn.hold.brace_hold`; the rival's stays the charge) |
  | `shot_fire` kind charged or split | the release (`pn.hold.palm_thrust`, `rw.charged_brace.release`), taking over from the charge |
  | cue `blast_cancel` | the hold eases out |
  | cue `buried_blast` | the shot down into the crater (`pg.hold.blast_down`, `rw.hold.blast_down`) |
  | `shot_fire` kind mine (laying) | `en.mine` |
  | `shot_deflect` (a wild deflect) | `en.swat`, unless the perfect block's own sequence is playing |
  | `shot_fire` kind arc, or cue `volley_fire` | the fan (`pg.volley_arc`, `rw.volley_fan`) |
  | `shot_fire` kind lob | `pg.lob`, `rw.lob` |
  | `shot_fire` kind curve | `pn.curve` (the Protagonist's curving shot) |
  | `shot_fire` kind rain | the rain throw (`rv.hold.rain_throw`) |
  | cues `taunt_close`, `drop_the_act`, `regalia_release`, `energy_shove` | his close taunt, the Drop the Act cinematic, the Regalia release, the shove |
- `--no-pair-live` (or `RenderAnim.pair_live = false`) switches all of it off: the placeholder picks and the shared poses play as before.

## What the live count is now

`render/anim/tools/coverage_live.gd --strict` restates the coverage table (`launch-pair-coverage.json`, 228 rows) with only what a match loads (`AnimData.load_all` and `ensure_fighter`, no `--waves`), and `launch-pair-live-status.json` says which loaded rows the sim starts today:

| | Before | Now |
| :--- | ---: | ---: |
| **live** (loaded and started by an event or beat the sim sends today) | 26 | **154** |
| **wired** (loaded, the runtime starts it when the sim sends its trigger, which it does not yet) | 0 | **37** |
| **baked** (loaded for the fighter, nothing starts it yet) | 0 | **15** |
| parked (not loaded by a match) | 180 | **0** |
| no pose by design, later, blocked | 13, 4, 5 | 13, 4, 5 |

- **Wired, waiting on the sim** (37): the entries (no live beat names one: `data/combat` has no `entry` op yet), the close taunt, the shot kinds rain, split and curve and the cues `volley_fire`, `energy_shove`, `drop_the_act` and `regalia_release`, and the volley and lob presses (their shots leave the strikes' emitters inside exchanges today).
- **Baked, nothing starts them yet** (15): the six emitting hands, the arc and shard poses, his two hands (the ring hand), On the Chin, Blow for Blow's brace and the finishers, the checks and the clash recoil. They are in the fighter's loaded waves; they need Encounter's beats and cues (the alchemy slices A6 and A7, the finishers).

## What it costs

- **Match start:** the two fighters' waves bake in about 200 ms natively (headless, this PC): 482 poses beyond the 189 of `load_all`, about 100 ms a fighter (the second fighter's shared waves are already baked, so the two are alike). It happens once, in the first frame of a match, when the first body is built; the intro that follows has no fighting in it. **Not measured on the web build:** there is no web export here, and the web runs GDScript several times slower than a PC (my estimate is 3 to 5 times, so 0.6 to 1.0 s, a visible hitch if it falls on the first frame). If it does, the cheap fix is to bake the strike and entry waves first and the energy, taunt and finisher waves a few frames later (`ensure_fighter` already names the waves in order); say so and I will.
- **Per solve:** unchanged, 132 microseconds a solve with the live pair on and off (seed 4, 1500 ticks, three alternating rounds).
- **Hash:** the gameplay hash is unchanged (`determinism.gd` passes: the animation layer reads the sim and writes nothing).

## What I want from the sim (nothing of it is built; each plays the moment it is sent)

| Event | Fields | For |
| :--- | :--- | :--- |
| `cue` kind `taunt_close` | actor | the close taunt (60 ticks, he can be hit): `rw.taunt_close`, `pg.taunt_close`; `taunt_end_cut` and the other cuts end it |
| `cue` kind `drop_the_act` | actor | the rival's 1.5 s cinematic (90 ticks): `rw.drop_the_act`; with a `pause_start` of the same kind if it pauses |
| `cue` kind `regalia_release` | actor | each time the Regalia shards leave: `rw.hold.crown_release` |
| `cue` kind `energy_shove` | actor | the energy shove (the context button at close range with the energy family held) |
| `cue` kind `volley_fire` | actor | a fan of darts or arcs from one sweep of the arm |
| `shot_fire` kinds `rain`, `split`, `curve`, `ricochet` | the usual fields | the roles are mapped already (`kinds` in `pair_live.json`) |
| `entry` beats | `who`, `id` `entry.<name>`, `dur` (and a rush beat's `entry` arg) | the fighter's own entry sequence |
| `strike` and `chainStrike` beats | `args.piece` `strike.<name>` | the alchemist's pick: that exact key set plays, instead of the hash walk of his list |

## Files

`data/anim/pair_live.json` (new; schema draft `docs/animation/handoff/anim-pairlive.schema.json`, the map rule `{"match": "data/anim/pair_live.json", "schema": "anim-pairlive.schema.json"}`), `render/anim/anim_data.gd` (`fighter_key`, `ensure_fighter`, `resolve_entry`, `resolve_strike`), `anim_fighter.gd` (`_pair_pick`, the energy layer and events, the taunt gestures), `render_anim.gd` (`pair_live`, the fighter's bake, the routing of `shot_fire`, `shot_deflect` and the blast cues), `tools/anim_check.gd` (`_test_pair_live`), `tools/coverage_live.gd`, `docs/animation/launch-pair-live-status.json`.
