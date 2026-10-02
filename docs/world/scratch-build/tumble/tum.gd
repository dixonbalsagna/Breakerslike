extends SceneTree
# tumbles: of the journeys that travel along the ground (journey_end stop, tumble, recover, capped), how many have a tumble_end rolling 18 ticks or more
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var ground := 0
	var seen := 0
	var anyt := 0
	var durs: Array = []
	var kinds := {}
	var tum := {}
	var launches := 0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		tum.clear()
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				var key: String = "%d_%d" % [int(e.actor), int(e.n)]
				if e.type == "launch":
					launches += 1
				elif e.type == "tumble_end":
					tum[key] = maxf(float(tum.get(key, 0.0)), float(e.dur))
					durs.append(float(e.dur))
				elif e.type == "journey_end":
					var k: String = String(e.kind)
					kinds[k] = kinds.get(k, 0) + 1
					if k in ["stop", "tumble", "recover", "capped"]:
						ground += 1
						if tum.has(key):
							anyt += 1
							if tum[key] >= 18.0:
								seen += 1
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		SimCore.dispose(S)
	durs.sort()
	var med: float = durs[durs.size() / 2] if not durs.is_empty() else 0.0
	var p90: float = durs[durs.size() * 9 / 10] if not durs.is_empty() else 0.0
	var mx: float = durs[durs.size() - 1] if not durs.is_empty() else 0.0
	print("TUM launches %d, ground-ended journeys %d, with a tumble %.1f%%, with a tumble of 18 ticks or more %.1f%%; tumble_end n %d, rolled ticks median %.0f p90 %.0f max %.0f; journey ends %s" % [launches, ground, 100.0 * anyt / maxf(ground, 1), 100.0 * seen / maxf(ground, 1), durs.size(), med, p90, mx, str(kinds)])
	quit(0)
