extends SceneTree
# the seed-6 mountain tumble: a fighter drifting at a cliff top (x 107081, y 3474, speed 300) rolls off it
func _init() -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 6, {}, {"intro": false})
	var f = S.fighters[0]
	var by = S.fighters[1]
	f.hp = 1.0e9
	f.x = 107081.0
	f.y = WorldTerrain.groundY(S, f.x) + 75.0
	f.vx = -330.0
	f.vy = -50.0
	f.state = "launched"
	f.launchBy = by
	f.launchT = 2.0
	WorldBrunt.arm(S, f, by, {})
	var x0: float = f.x
	var y0: float = f.y
	var peak: float = 0.0
	var peakland: float = 0.0
	var ticks: int = 0
	var contacts := 0
	var first: float = 0.0
	while f.state == "launched" and ticks < 1200:
		SimFighter.stepLaunched(S, f, SimConst.DT)
		peak = maxf(peak, f.slide)
		for e in S.out.fx:
			if e.type == "land" or e.type == "bounce":
				contacts += 1
				if first == 0.0:
					first = float(e.spd)
				peakland = maxf(peakland, float(e.spd))
		S.out.fx.clear()
		ticks += 1
	print("MCASE %s: first contact %.0f, peak landing speed %.0f (x%.2f), peak ground speed %.0f, contacts %d, %.2f s, fell %.0f units, travelled %.0f" % [OS.get_cmdline_user_args()[0], first, peakland, peakland / maxf(first, 1.0), peak, contacts, ticks / 60.0, y0 - f.y, absf(SimWrap.sdx(x0, f.x))])
	quit(0)
