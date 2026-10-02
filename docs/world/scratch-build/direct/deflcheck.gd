extends SceneTree
# What shotHit does for a shot that lands anywhere on the planet (a deflected shot): crater by kind and tier, structures, casualties, the seam, water.
func fresh() -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"intro": false})
	S.out.fx.clear()
	return S
func _init() -> void:
	print("== landing anywhere: shotHit at the planet's biomes ==")
	var W: float = SimConst.W
	var spots := {"seam": 0.0, "just before the seam": W - 40.0, "ocean": 3000.0}
	# find a city column, a village column, mountains
	var S0 := fresh()
	for nm in ["city", "village", "mountains", "desert", "forest"]:
		for i in range(0, SimConst.NC, 8):
			if WorldBiomes.biomeAt(float(i) * SimConst.COL) == nm:
				spots[nm] = float(i) * SimConst.COL + 400.0
				break
	for b in S0.buildings:
		if b.row != 1.0:
			continue
		var bn: String = WorldBiomes.biomeAt(b.x)
		if bn == "city" and not spots.has("city building"):
			spots["city building"] = b.x
		if bn == "village" and not spots.has("village building"):
			spots["village building"] = b.x
	for nm in spots:
		var line: String = "  %-20s x %6.0f:" % [nm, spots[nm]]
		for kind in ["bolt", "charged"]:
			for t in [1, 4]:
				var S := fresh()
				S.fighters[0].tier = float(t)
				var x: float = spots[nm]
				var g: float = WorldTerrain.groundY(S, x)
				var wet: bool = WorldWater.surfaceAt(S, x) > g
				var s0: float = S.world.structuresLost
				var c0: float = S.world.casualties
				var hp0: float = 0.0
				for b in S.buildings:
					hp0 += b.hp
				var r := WorldBlast.shotHit(S, 0, kind, x, g, 0.0, 600.0, -1500.0, "water" if wet else "ground")
				var hp1: float = 0.0
				for b in S.buildings:
					hp1 += b.hp
				line += "  %s t%d %s hp-%.0f lost %.0f cas %.1f |" % [kind, t, "water" if wet else ("no crater" if r.crater == null else "R%.0f d%.0f" % [r.crater.r, r.crater.depth]), hp0 - hp1, S.world.structuresLost - s0, S.world.casualties - c0]
		print(line)
	quit()
