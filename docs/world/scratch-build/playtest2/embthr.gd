extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = 0
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
		n += 1
		SimCore.dispose(S)
	var d: Array = SimFighter.DBGE
	var out: String = "THR %s: first-contact slam digs %d (%.1f a match):" % [a[2], d.size(), float(d.size()) / n]
	for thr in [1.4, 1.5, 1.6, 1.7, 1.75, 1.8, 1.9, 2.0, 3.0]:
		var c: int = 0
		var cs: int = 0
		for r in d:
			if r[5] > 0.5 and r[0] >= thr:
				c += 1
				if r[4] > 0.5:
					cs += 1
		out += " [>= %.2f: %.2f (%.2f special)]" % [thr, float(c) / n, float(cs) / n]
	print(out)
	quit(0)
