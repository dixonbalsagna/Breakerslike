# Core backlog

Owner: Simulation and Engine. A list of what is asked of `sim/core` and not yet built, so it survives between sessions. Each item names who asked and what it would add. Nothing here is designed in detail; an item gets its plan when its turn comes.

## Planned, in order

| Item | Plan | Waits for |
| :--- | :--- | :--- |
| Fight lanes, the rest (World's lane table, true collisions, terrain rows, the switch-on, beams) | `fight-lanes.md` | the ragdoll physics (Orb's ruling) |

## For the agency pass (EP, 2026-10-02)

- **Shots** (energy blasts in flight): designed and parked, `shots.md` and `pending/`. Encounter's slice 3a waits for it.
- The other asks, each small, are sized in `shots.md` section 10: the `knockback` and `exchange_end` events, a flow value per fighter, the press log if it moves to core, Controls' `intent-hash.patch`, World's embed fields and event, `autoCharge` in `SimAct.ASSISTS`.

## At M0 (Combat's moveset milestone), asked through the EP on 2026-10-02

| Item | Who needs it | What the core would add |
| :--- | :--- | :--- |
| A `held` state for throws | Combat, Animation | Per fighter: the holder's slot, the socket he is held by, the start and release ticks; hashed. The held fighter's position follows the holder until the release |
| `react` on the `damage` event | Animation | A field naming the reaction the blow asks for (the strike's class or direction), so the hit reaction does not have to be guessed from the amount and the region |
| The broken side per limb region | Animation, Art, UI | Which arm or leg broke (left or right), decided when the limb breaks and hashed, so the body, the wound card and the readout agree |
| A `path` event for curved rushes | Animation, Camera, VFX | When a rush follows a curve (Combat's variety pass, the `arc` argument), an event with the path's shape and end tick, so the trail and the camera can lead it |
| A per-slot AI level in the match setup | Encounter, QA, UI | `"aiLevel": [n, n]` in the setup (and so in the replay header), in place of Encounter's static `DirAI.level` |

## Smaller, approved or noted

- **Done 2026-10-02:** the intro phase, the last stand, the mood's form impulse.
- **Rename `act1Damping` to `act1WearMul`** (EP approved): the data, the loader and Tools' schema together.
- **I3:** remove the legacy `stance`, `dash` and `charge` intent fields and the `act.v2` flag; move `transformSource` into `SimAct`.
- **`Rush.arc`** for a rush over a roof (Encounter's fight-lanes section) and for Combat's curved rushes: the same field as the `path` event's source.
- **World's data in the replay's data hash:** `contact.json` is in (below). `settlements.json` and the lane table join when World has a `dataHash()` for them.

## Notes from reviews, for other owners

- **World, `WorldContact.dataHash()`** hashes the file's raw text. The other loaders hash the parsed data with keys that start with an underscore left out (`FighterData._canon`), so a changed note or a reformat does not refuse old replays. Line endings are normalised by `.gitattributes`, so this is a consistency point, not a bug.
- **World, `WorldContact.spinFighter`:** a stop (`SPIN_STOP`) is called once, not every tick, so `rot` is barely eased there; the free ease then takes it to 0 through every whole turn it holds (a body that stops with `rot` at 25 radians unwinds four turns in about a second). Wrap `rot` by whole turns at the stop first: that is not a jump, and the ease then goes the short way. It also reads `how` as the literals 0 and 1; `SimFighter.SPIN_AIR` and `SPIN_FREE` are the names.
