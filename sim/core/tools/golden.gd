extends SceneTree
## Regenerates the golden vectors from the GDScript sim (the source of truth since ADR 0006). From the repo root:
##   godot --headless --path . --script res://sim/core/tools/golden.gd
## writes sim/core/test/golden.json. Regenerate only for an intended change to sim behaviour, in the same commit as
## that change, and say why in the commit message (sim/README.md, "Golden hashes"). tools/parity.gd checks against it.

const OUT := "res://sim/core/test/golden.json"


func _init() -> void:
	var t0: int = Time.get_ticks_usec()
	var g: Dictionary = SimGolden.build()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(g, " ", false) + "\n")
	f.close()
	var ticks: int = 0
	for m in g.matches:
		ticks += m.ticks
	print("wrote %s: %d constants, %d rng streams, %d tick-0 states, %d matches (%d ticks), %d replays in %.1f s" % [OUT, g.constants.size(), g.rng.size(), g.tick0.size(), g.matches.size(), ticks, g.replays.size(), (Time.get_ticks_usec() - t0) / 1e6])
	quit(0)
