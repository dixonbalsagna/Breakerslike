# Parked spec: `autoForm`, the Simple layouts take a ready form for the player

Owner: Controls and Game Feel. Date: 2026-10-01. **Parked: nothing here is built.** It goes ahead only if Orb says yes. Trigger: `docs/director/masher-probes.md` (a masher who never transforms stays at tier 1 and never beats the medium AI; one who transforms wins 41 to 48%). Whole ticks at 60 a second.

## The rule

`autoForm` is an assist beside `autoBurst`, in the same place: a flag on the slot, recorded in the replay header's `setup.assists`, read by the sim.

1. A fighter's form becomes ready (`f.act.formReady`, the rising edge that raises `transform_ready`). From that tick the sim counts a **cue of 45 ticks** (0.75 s). A manual transform inside the cue takes the form at once, as today.
2. When the cue has run out **and** the director is at a boundary (`S.dirS.ex == null`, no KO, fighter `free` or `charging`: the conditions `_transforms` already tests), the sim takes the form exactly as if the `transform` edge had come in that tick. **Never mid-exchange:** a cue that finishes inside an exchange waits for its end; a form that is already ready when a long exchange ends waits only for the cue's age, not for a new one.
3. **The form goes before the queue.** A masher's queued attack starts the next exchange on the tick the last one ends, so there may be no free boundary tick. At a boundary tick, `_transforms` runs **before** `_drain`; the queued requests stay in the queue and expire as they normally do, so a transform costs a masher at most the presses that expire in its hold (the live version's `stunTicks`). Encounter may instead freeze queue ages for the pause; their call.
4. The transform event's `source` is a new value, **`"auto"`** (`transformSource` returns it when the assist is on and the manual edge did not come), so UI can word it and QA can count taken-for-you against taken-by-hand.

The cue is the point: a player is never surprised by a transformation; it announces itself for three-quarters of a second, and they can also take it earlier by hand.

## Where it is on

| Layout | Default |
| :--- | :--- |
| Simple pad, Simple touch | **on** (`"autoForm": true` in the layout's `slot` flags, next to `autoBurst`) |
| Arena, Brawler, Full touch, keyboard | off |
| Any layout | a **setting** ("Take forms for me") can turn it on, and on Simple turn it **off**. Opt-in everywhere is an accessibility gain at no cost |

The setting overrides the layout's flag per player, read at match start like all assists (a player who changes it mid-match gets it from the next match). **Ranked and replays:** the flag is in the header, so assisted players can be separated later, as for `autoBurst`.

## What it needs

**From me (Controls), small and mine:**
- `data/input/layouts.json`: `autoForm: true` in the two Simple presets' `slot`; `hub.setup()` appends `"autoForm"` to that slot's assists when the flag or the player's setting says so; a `hub.set_assist(slot, name, on)` for the setting; `timing.json` key `autoForm.cueTicks: 45`; tests (a Simple slot gets the assist, the setting overrides it, a Full slot does not). About an hour, tests included.

**From Simulation (`sim/core`, needs a grant):**
- `SimAct.ASSISTS` gets `"autoForm"` **appended** (the existing bits keep their numbers).
- `f.act.formReadyTick` (int), stamped at the rising edge in `stepFighter`, so the cue's age is `S.tick - formReadyTick`. It is new hashed state, so the golden refreshes (with every other match unchanged, since the field is only read under the assist). A read-only `act.formCueLeft` (ticks, 0 when none) in the same place lets UI draw the ring without counting.
- `SimData`/schema: the cue length read from `timing.json` into a `SimAct` static, as `queueMax` and `dodgeWindow` are.

**From Encounter (`sim/director/exchange.gd`):**
- In `_transforms` (`sim/director/exchange.gd`), the condition `if not (i.transform or ...)` gains `or (SimAct.assisted(f, "autoForm") and S.tick - f.act.formReadyTick >= cueTicks)`; `_transforms` runs ahead of `_drain` on the boundary tick; `transformSource` returns `"auto"`.

**From UI:**
- The ready prompt already exists (`avail["transform"]`, read from `f.act.formReady`). With the assist on, the prompt becomes **a filling ring with "Transforming" over the cue**, using `formCueLeft`, and the manual input still works through it. A tap on the touch Transform button or the chord takes it at once.
- Settings: one toggle, "Take forms for me", per player, on Simple's page and available under Accessibility for every layout.
- Wording for the `"auto"` source in the feed ("takes the form").

**From Audio, VFX and Tools (optional and small):** a rising cue sting on `transform_ready`; Tools' layouts schema must allow the new `slot` flag (a patch if I need one).

**From Game Design:** whether 45 ticks is the right cue, and whether an AI-tier match (easy to medium) should be rebalanced once masher players reach tier 2 and 3 on Simple. Encounter's masher probe can rerun with `autoForm` on to answer it.

## The Full layouts: a clearer "form ready" prompt instead (and as well)

Full layouts want the player to choose the moment, so **no auto-take by default**; the finding says the problem is awareness, and the cheap, UI-only cure is a louder prompt on **every** layout:

1. **A pulsing prompt at the Transform control** (Context's place on touch, near the ki bar on pad) from `transform_ready` until it is taken, with **both trigger glyphs** ("LT + RT, hold") on a pad and the keyboard chord's keys on a keyboard, from `UiGlyphs`.
2. **A short sting and, on a pad or phone, a 15 ms haptic** at the rising edge (the burst-ready's haptic, `input-scheme.md`). Never the only cue.
3. The not-ready chord already shows a cue; no change.

This costs no sim change and could ship first, then `autoForm` for Simple if Orb says yes. My recommendation: **do the prompt for all layouts now, and `autoForm` for Simple pad and Simple touch** (the players the finding is about, who by design have no "hold two triggers" in their hands), with the setting to turn it off. It is a pure assist: a player on Simple who learns the chord can turn it off and choose the moment.

## Tests when built

A Simple slot's setup carries `autoForm`; with the assist, a ready form is taken after the cue and at a boundary, never inside an exchange, and a manual transform inside the cue wins; a masher with queued requests still transforms (the queue goes after); `source` is `"auto"` by assist and `"triggers"` by hand; without the assist nothing changes (golden unchanged apart from the new hashed field); a replay of an assisted match reproduces.
