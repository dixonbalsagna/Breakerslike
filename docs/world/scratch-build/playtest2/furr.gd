extends SceneTree
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = 0
	var T: float = 0.0
	var st: float = 0.0
	var cas: float = 0.0
	var cr: float = 0.0
	var slides: float = 0.0
	var t0: int = Time.get_ticks_usec()
	var ticks: int = 0
	var lowest: float = 0.0
	var ground_stats: float = 0.0
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
		ticks += steps
		T += S.T
		st += S.world.structuresLost
		cas += S.world.casualties / maxf(S.world.pop0, 1.0)
		cr += S.world.craters
		slides += S.world.slides
		# the ground the fighters leave: carved columns (deform below -5) and raised (above +5)
		var low: int = 0
		var high: int = 0
		for i in range(SimConst.NC):
			if S.deform[i] < -5.0:
				low += 1
			elif S.deform[i] > 5.0:
				high += 1
		lowest += float(low)
		ground_stats += float(high)
		n += 1
		SimCore.dispose(S)
	var dt: float = float(Time.get_ticks_usec() - t0) / 1.0e6
	var d: Array = SimFighter.DBGT
	print("FURR %d matches: length %.0f s, structures %.1f, civilians %.1f%%, craters %.1f, slide records %.1f; skid furrow: %.0f units of length a match, mean depth %.0f; tumble furrow %.0f units, mean depth %.0f; ground at the KO: %.0f columns below -5, %.0f above +5; %.0f ticks/s" % [n, T / n, st / n, 100.0 * cas / n, cr / n, slides / n, d[2] / n, d[0] / maxf(d[2], 1.0), d[3] / n, d[1] / maxf(d[3], 1.0), lowest / n, ground_stats / n, ticks / dt])
	quit(0)
