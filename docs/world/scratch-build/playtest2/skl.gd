extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var nm: int = 0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		nm += 1
		SimCore.dispose(S)
	var d: Array = SimFighter.DBGK
	# per skid episode: group by (actor, launchN, seed order) in time; episodes: ticks, distance
	var eps: Array = []
	var cur := {}
	for r in d:
		var key: String = "%d_%d" % [int(r[4]), int(r[3])]
		if not cur.has(key) or r[0] - cur[key][2] > 0.2:
			cur[key] = [0, 0.0, r[0], r[0]]
			eps.append(cur[key])
		var c: Array = cur[key]
		c[0] += 1
		c[1] += r[1]
		c[2] = r[0]
	var buckets := [[0.0, 150.0], [150.0, 300.0], [300.0, 450.0], [450.0, 900.0]]
	var out: String = "SKL %s: %d skid episodes (%.1f a match), mean %.1f ticks, mean distance %.0f units |" % [a[2], eps.size(), float(eps.size()) / nm, 0.0, 0.0]
	var tt: float = 0.0
	var dd: float = 0.0
	for e in eps:
		tt += e[0]
		dd += e[1]
	out = "SKL %s: %d skid episodes (%.1f a match), mean %.1f ticks, mean distance %.0f units |" % [a[2], eps.size(), float(eps.size()) / nm, tt / eps.size(), dd / eps.size()]
	for b in buckets:
		var c2: int = 0
		var t2: float = 0.0
		var d2: float = 0.0
		for e in eps:
			if e[3] >= b[0] and e[3] < b[1]:
				c2 += 1
				t2 += e[0]
				d2 += e[1]
		out += " match time %.0f to %.0f s: %d episodes, mean %.1f ticks, %.0f units;" % [b[0], b[1], c2, t2 / maxf(c2, 1), d2 / maxf(c2, 1)]
	print(out)
	quit(0)
