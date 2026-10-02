extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = 0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd, {}, {"intro": false})
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		n += 1
		SimCore.dispose(S)
	var d: Array = SimFighter.DBGE
	var out: String = "EMB %d matches, %d slam digs by a launched fighter (%.1f a match):" % [n, d.size(), float(d.size()) / n]
	for thr in [1.0, 1.2, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.5, 4.0]:
		var c: int = 0
		var cs: int = 0
		for r in d:
			if r[0] >= thr:
				c += 1
				if r[4] > 0.5:
					cs += 1
		out += " [depth >= %.1f bh: %.2f a match (%.2f special)]" % [thr, float(c) / n, float(cs) / n]
	print(out)
	var vs: String = "EMB by tier (ordinary, depth >= 1.5):"
	for t in [1, 2, 3, 4]:
		var c2: int = 0
		var all: int = 0
		for r in d:
			if int(r[3]) == t and r[4] < 0.5:
				all += 1
				if r[0] >= 1.5:
					c2 += 1
		vs += " tier %d: %d of %d slams" % [t, c2, all]
	print(vs)
	var mn: float = 1e9
	var mx: float = 0.0
	for r in d:
		if r[0] >= 1.5 and r[4] < 0.5:
			mn = minf(mn, r[2])
			mx = maxf(mx, r[2])
	print("EMB ordinary slams with depth >= 1.5 bh: speed %.0f to %.0f" % [mn, mx])
	quit(0)
