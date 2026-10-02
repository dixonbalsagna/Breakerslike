extends SceneTree
# A/B: matches with depth on or off (args: first last on|off): length, structures, civilians, craters, and the tick cost
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var depth: bool = a[2] == "on"
	var n: int = 0
	var T: float = 0.0
	var st: float = 0.0
	var cas: float = 0.0
	var cr: float = 0.0
	var ticks: int = 0
	var t0: int = Time.get_ticks_usec()
	var rows_nz: float = 0.0
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd, {}, {"depth": depth, "intro": false})
		SimGolden.applyArm("default", S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		ticks += steps
		T += S.T
		st += S.world.structuresLost
		cas += S.world.casualties / maxf(S.world.pop0, 1.0)
		cr += S.world.craters
		if depth:
			for k in range(8):
				if k == 1:
					continue
				for v in S.deformZ[k]:
					if v != 0.0:
						rows_nz += 1.0
		n += 1
		SimCore.dispose(S)
	var dt: float = float(Time.get_ticks_usec() - t0) / 1.0e6
	print("BD %s: %d matches, length %.0f s, structures %.1f, civilians %.1f%%, craters %.1f, %.0f ticks/s%s" % [a[2], n, T / n, st / n, 100.0 * cas / n, cr / n, ticks / dt, (", non-zero columns on the depth rows a match %.0f" % (rows_nz / n)) if depth else ""])
	quit(0)
