extends SceneTree
# one skid on open ground: speed 1500 at a shallow angle; per-tick trace summary
func _init() -> void:
	var tag: String = OS.get_cmdline_user_args()[0]
	for spd in [800.0, 1200.0, 1800.0]:
		var S := SimCore.createSim()
		SimCore.newMatch(S, 1, {}, {"intro": false})
		var f = S.fighters[0]
		var by = S.fighters[1]
		f.hp = 1.0e9
		by.tier = 3.0
		f.x = 89600.0 + 3000.0
		f.y = WorldTerrain.groundY(S, f.x) + 4.0
		f.vx = spd * float(OS.get_cmdline_user_args()[1])
		f.vy = -spd * 0.06
		f.state = "launched"
		f.launchBy = by
		f.launchT = 1.0
		WorldBrunt.arm(S, f, by, {})
		var x0: float = f.x
		var ticks: int = 0
		var trace: String = ""
		var kind: String = ""
		while f.state == "launched" and ticks < 1200:
			SimFighter.stepLaunched(S, f, SimConst.DT)
			if ticks % 15 == 0:
				trace += " %.0f" % f.slide if ticks % 30 == 0 else ""
			for e in S.out.fx:
				if e.type == "journey_end":
					kind = String(e.kind)
				elif e.type == "left_ground":
					trace += " [leave:%s]" % str(e.cause)
			S.out.fx.clear()
			ticks += 1
		print("SKID %s speed %.0f: %d ticks, travelled %.0f units, end %s; vN every 15 ticks:%s" % [tag, spd, ticks, absf(SimWrap.sdx(x0, f.x)), kind, trace])
		SimCore.dispose(S)
	quit(0)
