extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var land := {}
	var causes := {}
	var ends := {}
	var contacts_hist := {}
	var bounces_per := {}
	var launches: int = 0
	var journeys: int = 0
	var tsum: float = 0.0
	var tmax: float = 0.0
	var bad: int = 0
	var len: float = 0.0
	var wins := {}
	var nan: int = 0
	var first_cls := {}
	var seen := {}
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				if e.type in ["land", "bounce", "skim"]:
					var key: String = "%d_%d_%d" % [sd, int(e.actor), int(e.n)]
					if not seen.has(key):
						seen[key] = true
						var cls: String = e.type
						if e.type == "land":
							cls = e.kind
						first_cls[cls] = first_cls.get(cls, 0) + 1
				match e.type:
					"launch":
						launches += 1
					"land":
						land[e.kind] = land.get(e.kind, 0) + 1
					"left_ground":
						causes[e.cause] = causes.get(e.cause, 0) + 1
					"journey_end":
						journeys += 1
						if e.contacts > 8 or e.dur > 5.0:
							print("LONG seed %d tick %d actor %.0f n %d kind %s contacts %d lips %d bounces %d dur %.2f x %.0f y %.0f" % [sd, S.tick, e.actor, e.n, e.kind, e.contacts, e.lips, e.nb, e.dur, e.x, e.y])
						ends[e.kind] = ends.get(e.kind, 0) + 1
						contacts_hist[e.contacts] = contacts_hist.get(e.contacts, 0) + 1
						bounces_per[e.nb] = bounces_per.get(e.nb, 0) + 1
						tsum += e.dur
						tmax = maxf(tmax, e.dur)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
			for f in S.fighters:
				if is_nan(f.x) or is_nan(f.y) or is_nan(f.vx) or is_nan(f.vy):
					nan += 1
		len += S.T
		SimCore.dispose(S)
	print("FIRST %s of %d launches" % [str(first_cls), launches])
	print("JS seeds %d..%d launches %d journeys %d nan %d | land %s | left %s | ends %s | contacts %s | bounces %s | journey t mean %.2f max %.2f | len %.0f" % [int(a[0]), int(a[1]), launches, journeys, nan, str(land), str(causes), str(ends), str(contacts_hist), str(bounces_per), tsum / maxf(journeys, 1.0), tmax, len])
	quit(0)
