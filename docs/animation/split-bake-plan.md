# The split bake: a plan (2026-10-03), not built

Owner: Animation. The EP asked for a plan for baking the strike and entry waves first and the rest a few frames later, to be built only once the web build's bake time is measured. Nothing here is built.

## What the bake costs, wave by wave (native, headless, this PC)

`AnimData.ensure_fighter` bakes a fighter's waves with `AnimPose.bake` (the pose's inverse kinematics and its joint limits). Measured with each wave baked once:

| Fighter | Wave | Holds | ms | Poses |
| :--- | :--- | :--- | ---: | ---: |
| protagonist | protag1 | strikes (42) | 48.8 | 126 |
| protagonist | protag2 | entries (17) | 19.0 | 54 |
| protagonist | protag5 | blast presses, taunts, brace | 16.4 | 33 |
| protagonist | protag3, protag4, protag6, pair1 | hands, finisher, body hook, checks | 9.8 | 24 |
| both | energy1 | mine, swat, spray | 4.6 | 8 |
| rival | wave1 | strikes (34) | 44.9 | 120 |
| rival | wave2 | entries (15) | 20.8 | 62 |
| rival | rival1, rival2, rival3 | On the Chin and the rest, three strikes, presses and taunts | 16.6 | 59 |
| | **Total** | | **181** | **486** |

About 0.37 ms a pose. **Strikes and entries are 134 of the 181 ms (74%)**: baking them first and the rest later moves only a quarter of the cost out of the first frame, so a plain split is a weak lever.

## What I would build instead (if the web build shows a hitch)

An **incremental bake with an on-demand fallback**, which takes the cost out of any single frame:

1. `ensure_fighter` still registers everything at once and cheaply: the key sets, the entries, the sequences, the pick lists and the `raw` sketches (parsing the JSON is a small part of the cost).
2. The baking of the poses (the 486) becomes a queue, strikes and entries first, the rest after (the order the match will need them). `RenderAnim.consume`'s `tick` event bakes at most a fixed number of poses a tick (8 is about 3 ms), so the whole bake spreads over about 60 ticks, a second, inside the intro, which has no fighting in it.
3. `AnimData.pose(id)` and `pose_exists(id)` bake a pose that is still queued the moment something asks for it, so no consumer can see a missing pose; the tools call `AnimData.bake_pending()` first.
4. The numbers (poses a tick) live in `data/anim/pair_live.json`.

It touches `anim_data.gd` (the queue, `pose`, `pose_exists`, `bake_pending`), `render_anim.gd` (the tick) and the tools that read `AnimData.poses` directly (a one-line call each). The determinism and joint checks stay as they are, because nothing is skipped, only moved.

## What to measure first

On the web build, the time `AnimData.pair_bake_usec` holds after the first frame of a match (it counts the bake of both fighters), against the native 181 to 200 ms. A scripted page can read it as Rendering's probe does (`JavaScriptBridge.eval("window.__probe = {...}")`). My guess for the web is 3 to 5 times slower than native (0.6 to 1.0 s), which is a guess. If it comes in under about 300 ms, nothing needs building; over about 500 ms, build the incremental bake above rather than the plain split.
