extends SceneTree
## Headless checks of the crater, scorch and water rules (World and Environment). From the repo root:
##   godot --headless --path . --script res://sim/world/tools/probe.gd
## Prints the crater size table, the repeated-hit and furrow tests, the scorch table, the coastal-bay fill time and the
## random-crater flood test. Exit code 1 if a hard check fails (the "FAIL" lines). It never changes any sim file.

var fails: int = 0


func check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1


func fresh(seed: int = 1) -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	S.out.fx.clear()
	return S


## 1D area (units squared) of the profile between lo_u and hi_u (in R), both sides; sign_ picks bowl (-1) or rim (+1).
func area(lo_u: float, hi_u: float, rec, sign_: float) -> float:
	var sum: float = 0.0
	var step: float = 0.002
	var u: float = lo_u
	while u < hi_u:
		var h: float = WorldCrater.profile(u + step * 0.5, rec.depth, rec.rim)
		if h * sign_ > 0.0:
			sum += absf(h) * step * rec.r
		u += step
	return sum * 2.0


func settle(S: SimState, limit: int = 20000) -> int:
	var steps: int = 0
	while not S.waterWin.is_empty() and steps < limit:
		WorldWater.step(S)
		steps += 1
	return steps


func wet_dynamic(S: SimState) -> int:
	var n: int = 0
	for i in range(SimConst.NC):
		if S.base[i] >= WorldWater.RESERVOIR_BASE and S.water[i] >= WorldWater.MIN_DEPTH:
			n += 1
	return n


func _init() -> void:
	print("== crater size by energy (straight-down hits on flat ground, x = 3000) ==")
	print("  E      R    depth   rim   depth/diam   bowl area   rim+apron area   rim/bowl")
	for E in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0]:
		var S := fresh()
		var rec = WorldCrater.dig(S, 3000.0, E, null, "impact", 0.0, 1.0)
		var bowl: float = area(0.0, 1.0, rec, -1.0)
		var rim: float = area(0.0, 1.0 + WorldCrater.RIM_OUT, rec, 1.0)
		print("  %5.1f %6.1f %6.1f %5.1f   %.3f       %8.0f     %8.0f          %.2f" % [E, rec.r, rec.depth, rec.rim, rec.depth / (2.0 * rec.r), bowl, rim, rim / bowl])
	print("== impact energy: speed and tier to bowl radius (the prototype's radius in brackets) ==")
	for sp in [400.0, 800.0, 1200.0, 2000.0, 2600.0]:
		var line: String = "  speed %4.0f:" % sp
		for tier in [1.0, 2.0, 3.0, 4.0]:
			var E: float = WorldCrater.impactEnergy(sp, tier)
			line += "  t%d %4.0f [%4.0f]" % [int(tier), WorldCrater.radiusOf(E), 28.0 + sp * 0.05 + tier * 12.0]
		print(line)
	print("== power-up, explosion and clash-wave radius by tier (the prototype's in brackets) ==")
	for tier in [2.0, 3.0, 4.0]:
		print("  tier %d: power-up %4.0f [%3.0f]   explosion %4.0f [%3.0f]   clash wave %4.0f [%3.0f]" % [int(tier), WorldCrater.radiusOf(WorldCrater.powerupEnergy(tier)), 60.0 + tier * 28.0, WorldCrater.radiusOf(WorldCrater.explodeEnergy(tier)), (70.0 + tier * 32.0) * 0.9, WorldCrater.radiusOf(WorldCrater.clashEnergy(tier)), 60.0 + tier * 16.0])

	print("== repeated hits never dig a shaft ==")
	var S1 := fresh()
	var first = WorldCrater.dig(S1, 3000.0, 8.0, null, "impact", 0.0, 1.0)
	var count: int = 1
	for i in range(60):
		if WorldCrater.dig(S1, 3000.0, 8.0, null, "impact", 0.0, 1.0) != null:
			count += 1
	var lowest: float = 0.0
	for i in range(SimConst.NC):
		lowest = minf(lowest, S1.deform[i])
	print("  61 identical E=8 hits on one spot: %d dug, lowest deform %.1f (first hit depth %.1f, R %.1f, cap %.1f)" % [count, lowest, first.depth, first.r, WorldCrater.RELIEF_MAX_RATIO * first.r])
	check(lowest >= -(WorldCrater.RELIEF_MAX_RATIO * first.r + 0.5), "lowest point stays within the relief cap")
	var S2 := fresh()
	WorldCrater.dig(S2, 3000.0, 16.0, null, "impact", 0.0, 1.0)
	var c2: int = int(3000.0 / SimConst.COL)
	var deep0: float = S2.deform[c2]
	var small: int = 0
	for i in range(80):
		if WorldCrater.dig(S2, 3000.0, 0.5, null, "impact", 0.0, 1.0) != null:
			small += 1
	print("  80 small hits (E=0.5) in the bottom of an E=16 bowl: %d dug, centre %.1f -> %.1f" % [small, deep0, S2.deform[c2]])
	check(S2.deform[c2] > deep0 - WorldCrater.RELIEF_MAX_RATIO * WorldCrater.radiusOf(0.5) - 0.5, "small hits only dent the bowl floor by their own relief cap")
	var S3 := fresh()
	var rng := SimRng.new(99)
	for i in range(400):
		WorldCrater.dig(S3, 3000.0 + rng.range_(-300.0, 300.0), rng.range_(1.0, 30.0), null, "impact", 0.0, 1.0)
	var lo3: float = 0.0
	var hi3: float = 0.0
	for i in range(SimConst.NC):
		lo3 = minf(lo3, S3.deform[i])
		hi3 = maxf(hi3, S3.deform[i])
	print("  400 random hits (E 1..30) within +-300 units: deform range %.1f .. %.1f, records %d (cap %d)" % [lo3, hi3, S3.craters.size(), WorldCrater.LIST_MAX])
	check(lo3 >= WorldCrater.DEFORM_FLOOR and hi3 <= WorldCrater.DEFORM_CEIL and S3.craters.size() <= WorldCrater.LIST_MAX, "deform stays inside its limits and the record list is capped")

	print("== a diagonal slam skids a furrow into the bowl ==")
	for dx in [0.0, 0.5, 0.7, 0.9]:
		var S4 := fresh()
		var rec = WorldCrater.dig(S4, 3000.0, 8.0, null, "impact", dx, sqrt(1.0 - dx * dx))
		print("  horizontal share %.1f: bowl depth %5.1f  furrow tail offset %7.1f  furrow depth %4.1f" % [dx, rec.depth, rec.skid, rec.sdepth])
	var S5 := fresh()
	var r5 = WorldCrater.dig(S5, 3000.0, 8.0, null, "impact", 0.8, 0.6)
	check(r5.skid < 0.0 and absf(r5.skid) <= WorldCrater.SKID_LEN_R * r5.r + 0.1 and r5.sdepth > 0.0, "a rightward diagonal hit skids from the left (tail at x - length)")

	print("== scorch: groove by beam power (plains, a 40-sample beam every 20 units) ==")
	for P in [0.5, 1.0, 2.0, 3.0, 4.0, 4.5]:
		var S6 := fresh()
		for k in range(40):
			WorldCrater.scorch(S6, 3000.0 + 20.0 * float(k), P, "MERIDIAN SCAR", null)
		var depth1: float = 0.0
		for i in range(SimConst.NC):
			depth1 = minf(depth1, S6.deform[i])
		for k in range(40):
			WorldCrater.scorch(S6, 3000.0 + 20.0 * float(k), P, "MERIDIAN SCAR", null)
		var depth2: float = 0.0
		for i in range(SimConst.NC):
			depth2 = minf(depth2, S6.deform[i])
		var hw: float = WorldCrater.SCORCH_HW0 + WorldCrater.SCORCH_HW_P * P
		var dd: float = WorldCrater.SCORCH_D0 + WorldCrater.SCORCH_D_P * P
		print("  P %.1f: half width %5.1f  reach %4.0f  groove depth %5.1f after one beam, %5.1f after two   (ridge bore %4.1f, glass trench %4.1f)" % [P, hw, WorldCrater.beamReach(P), -depth1, -depth2, dd * 1.6, dd * 0.8])
		check(absf(depth2 - depth1) < 0.01, "a second beam over the groove does not deepen it (P %.1f)" % P)

	print("== water: a bay dug at the coast ==")
	for cx in [1200.0, 1290.0, 8270.0]:
		var S7 := fresh()
		var rec = WorldCrater.dig(S7, cx, 25.0, null, "impact", 0.0, 1.0)
		var wet0: int = wet_dynamic(S7)
		var steps: int = settle(S7, 4000)
		var wet: int = wet_dynamic(S7)
		var maxsurf: float = -1e9
		for i in range(SimConst.NC):
			if S7.base[i] >= WorldWater.RESERVOIR_BASE and S7.water[i] >= WorldWater.MIN_DEPTH:
				maxsurf = maxf(maxsurf, S7.base[i] + S7.deform[i] + S7.water[i])
		print("  E=25 at x=%4.0f (%s): R %.0f depth %.0f; wet crater columns %d -> %d, settled after %d ticks (%.1f s), highest surface %.2f" % [cx, WorldBiomes.biomeAt(cx), rec.r, rec.depth, wet0, wet, steps, float(steps) / 60.0, maxsurf])
		check(wet == 0 or absf(maxsurf) < 0.6, "settled water stands at sea level")
	print("== water: an inland crater stays dry ==")
	for cx in [2000.0, 3000.0, 4000.0, 6000.0, 7000.0]:
		var S8 := fresh()
		var rec = WorldCrater.dig(S8, cx, 30.0, null, "impact", 0.0, 1.0)
		settle(S8, 4000)
		var wet: int = wet_dynamic(S8)
		print("  E=30 at x=%4.0f (%s): R %.0f depth %.0f, wet columns %d" % [cx, WorldBiomes.biomeAt(cx), rec.r, rec.depth, wet])
		check(wet == 0, "no water in an inland crater at x=%.0f" % cx)

	print("== flood test: 1000 random craters and beam scorch lines across the planet, three planets ==")
	var bad_total: int = 0
	for seed in [1, 2, 3]:
		var S9 := fresh(seed)
		var rg := SimRng.new(seed * 7919)
		for i in range(1000):
			var x: float = rg.range_(0.0, SimConst.W)
			if rg.next() < 0.7:
				WorldCrater.dig(S9, x, rg.range_(0.5, 30.0), null, "impact", rg.range_(-1.0, 1.0) * 0.7, 0.7)
			else:
				for k in range(int(rg.range_(5.0, 40.0))):
					WorldCrater.scorch(S9, x + 30.0 * float(k), rg.range_(0.5, 4.5), "GLASS TRENCH", null)
			if i % 5 == 0:
				for k in range(3):
					WorldWater.step(S9)
		var steps: int = settle(S9)
		# every wet dynamic column must sit in an unbroken run of ground below WET_GROUND that reaches a reservoir column
		var NC: int = SimConst.NC
		var reach := PackedByteArray()
		reach.resize(NC)
		for dir in [1, -1]:
			var wet: bool = false
			for lap in range(2 * NC):
				var i: int = lap % NC if dir == 1 else NC - 1 - (lap % NC)
				if S9.base[i] < WorldWater.RESERVOIR_BASE:
					wet = true
				elif wet and S9.base[i] + S9.deform[i] < WorldWater.WET_GROUND:
					reach[i] = 1
				else:
					wet = false
		var dyn: int = 0
		var bad: int = 0
		var far: int = 0
		for i in range(NC):
			if S9.base[i] >= WorldWater.RESERVOIR_BASE and S9.water[i] >= WorldWater.MIN_DEPTH:
				dyn += 1
				if reach[i] == 0:
					bad += 1
				var b: String = WorldBiomes.biomeAt(float(i) * SimConst.COL)
				if b != "ocean" and b != "village" and b != "plains":
					far += 1
		bad_total += bad
		print("  planet %d: %d craters recorded, water windows left %d (%d ticks to settle), dynamic wet columns %d, not connected to the sea %d, in non-coastal biomes %d" % [seed, S9.craters.size(), S9.waterWin.size(), steps, dyn, bad, far])
	check(bad_total == 0, "no wet column is disconnected from the sea (craters cannot flood inland)")

	print("== a fighter under the surface of a crater lake is submerged ==")
	var S10 := fresh()
	WorldCrater.dig(S10, 1250.0, 25.0, null, "impact", 0.0, 1.0)
	settle(S10, 4000)
	var lake_x: float = -1.0
	for i in range(140, 200):
		if S10.water[i] >= WorldWater.HIDE_MIN_DEPTH and S10.base[i] >= WorldWater.RESERVOIR_BASE:
			lake_x = float(i) * SimConst.COL + 4.0
	if lake_x < 0.0:
		print("  (no dynamic column in this bay reaches the %.0f-unit hiding depth; the sea itself does)" % WorldWater.HIDE_MIN_DEPTH)
	else:
		S10.fighters[0].x = lake_x
		S10.fighters[0].y = WorldWater.surfaceAt(S10, lake_x) - 90.0
		print("  fighter at x=%.0f, y=%.0f, water depth %.0f: cover = %s" % [lake_x, S10.fighters[0].y, WorldWater.depthAt(S10, lake_x), str(WorldCover.coverAt(S10, S10.fighters[0]))])
		check(WorldCover.coverAt(S10, S10.fighters[0]) == "submerged", "a fighter under the surface of a crater lake is submerged")

	print("")
	print("probe: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
