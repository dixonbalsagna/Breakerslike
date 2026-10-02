# The tumble that is seen (balance-targets section 23)

Two lines, applied in World's window as its first small slice (goldens change):

- `data/biomes/contact.json`: `tumble.brakeMul` 2.0 to 0.7.
- `sim/world/contact.gd` (`_finish`): `te.dur = float(f.jT) * SimConst.DT` becomes `te.dur = float(maxi(f.tumbleT, 0))` (ticks rolled; `journey_end.dur` stays the whole journey in seconds).

`tum.gd` counts, over ground-ended journeys (`journey_end` kind stop, tumble, recover or capped), those with a `tumble_end` that rolled 18 ticks or more. `strikes.gd` repeats QA's reach check (records.gd) and prints each tall strike on flat ground. Run with `-- <first seed> <last seed> [arm]`.
