extends SceneTree
# QA's reach check (records.gd): damaging light and heavy strikes with a height difference over 68 where the ground is flat at the victim
func _init() -> void:
	var a: Array = OS.get_cmdline_user_args()
	var n: int = 0
	var tall: int = 0
	var flat: int = 0
	var fs
	for sd in range(int(a[0]), int(a[1])):
		var S := SimCore.createSim()
		SimCore.newMatch(S, sd)
		SimGolden.applyArm(a[2], S.fighters)
		var steps: int = 0
		while S.game.ko == null and steps < 54000:
			SimCore.step(S, null)
			fs = S.fighters
			var rex = S.dirS.ex
			for e in S.out.fx:
				if e.type == "damage" and e.number and e.amount > 0.0 and rex != null and (str(rex.kind) == "light" or str(rex.kind) == "heavy") and (str(e.get("kind")) == "light" or str(e.get("kind")) == "heavy" or str(e.get("kind")) == "guard") and int(e.attacker) >= 0 and int(e.attacker) < 2 and int(e.victim) >= 0 and int(e.victim) < 2:
					var fa = fs[int(e.attacker)]
					var fv = fs[int(e.victim)]
					n += 1
					var rdy: float = absf(fa.y - fv.y)
					if rdy > 68.0:
						tall += 1
						var gx: float = fv.x
						var slope: float = absf(WorldTerrain.groundY(S, gx + 40.0) - WorldTerrain.groundY(S, gx - 40.0)) / 80.0
						if slope <= 0.15:
							flat += 1
							var ga: float = WorldTerrain.groundY(S, fa.x)
							var gv: float = WorldTerrain.groundY(S, fv.x)
							print("FLAT seed %d t %.1f kind %s: attacker y %.0f (ground %.0f, +%.0f, state %s) victim y %.0f (ground %.0f, +%.0f, state %s); dy %.0f dx %.0f; ground step victim->attacker %.0f; slope at victim %.3f; slope at attacker %.3f" % [sd, S.T, str(e.get("kind")), fa.y, ga, fa.y - ga, fa.state, fv.y, gv, fv.y - gv, fv.state, rdy, absf(SimWrap.sdx(fa.x, fv.x)), ga - gv, slope, absf(WorldTerrain.groundY(S, fa.x + 40.0) - WorldTerrain.groundY(S, fa.x - 40.0)) / 80.0])
			S.out.fx.clear()
			S.out.feed.clear()
			steps += 1
		SimCore.dispose(S)
	print("STRIKES %s: %d strikes, %d with a height difference over 68, %d of those on flat ground" % [a[2], n, tall, flat])
	quit(0)
