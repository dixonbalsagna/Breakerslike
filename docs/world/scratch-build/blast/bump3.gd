extends SceneTree
func _init() -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"intro": false})
	var f = S.fighters[0]
	var by = S.fighters[1]
	f.hp = 1000.0
	by.tier = 1.0
	var found: int = 0
	var x: float = 100000.0
	while x < 125000.0 and found < 3:
		for dir in [1.0, -1.0]:
			var r: Dictionary = WorldContact.slideObstacle(S, x, 0.0, dir, 3.5 * 75.0)
			if r.hit and found < 3:
				found += 1
				f.x = SimWrap.wrap(x + dir * (r.d - 30.0))
				f.y = WorldTerrain.groundY(S, f.x)
				var hp0: float = f.hp
				var c0: int = S.craters.size()
				var dmg: float = WorldContact.bump(S, f, by, r.kind, 870.0)
				print("BUMP3 obstacle %s at %.0f units (rise %.2f), speed 870: damage %.1f of %.0f hp, craters +%d, events %d" % [r.kind, r.d, r.rise, hp0 - f.hp, hp0, S.craters.size() - c0, S.out.fx.size()])
				S.out.fx.clear()
		x += 200.0
	quit(0)
