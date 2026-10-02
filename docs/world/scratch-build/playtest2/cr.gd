extends SceneTree
# crater statistics by cause: depth in body heights (75 units), radius, energy, special; and the vertical share of impacts
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var by := {}
	var n: int = 0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd, {}, {"intro": false})
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			for e in S.out.fx:
				if e.type == "crater":
					var k: String = String(e.cause) + (" special" if e.special else "")
					if not by.has(k):
						by[k] = []
					by[k].append([float(e.depth) / 75.0, float(e.r) / 75.0, float(e.energy), S.fighters[maxi(int(e.owner), 0)].tier])
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		n += 1
		SimCore.dispose(S)
	for k in by:
		var arr: Array = by[k]
		var c15: int = 0
		var c10: int = 0
		var c20: int = 0
		var emax: float = 0.0
		var dmax: float = 0.0
		var t4: int = 0
		for r in arr:
			if r[0] >= 1.5:
				c15 += 1
				if r[3] >= 4.0:
					t4 += 1
			if r[0] >= 1.0:
				c10 += 1
			if r[0] >= 2.0:
				c20 += 1
			emax = maxf(emax, r[2])
			dmax = maxf(dmax, r[0])
		print("CR %s: %.1f a match; depth >= 1.0 bh %.2f a match, >= 1.5 bh %.2f a match (tier 4: %d), >= 2.0 bh %.2f; deepest %.1f bh, most energy %.1f" % [k, float(arr.size()) / n, float(c10) / n, float(c15) / n, t4, float(c20) / n, dmax, emax])
	quit(0)
