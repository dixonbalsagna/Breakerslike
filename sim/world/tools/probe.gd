extends SceneTree
## Headless checks of the crater, scorch and water rules (World and Environment). From the repo root:
##   godot --headless --path . --script res://sim/world/tools/probe.gd
## Prints the crater size table, the repeated-hit and furrow tests, the scorch table, the coastal-bay fill time and the
## random-crater flood test. Exit code 1 if a hard check fails (the "FAIL" lines). It never changes any sim file.

var fails: int = 0


## World coordinates of the original planet, on the scaled one.
func X(v: float) -> float:
	return v * SimConst.PS


## The x of the first dry column past the sea's edge on the east coast (east = true) or the west coast (false): the shore.
func shore_x(east: bool) -> float:
	var NC: int = SimConst.NC
	var S := fresh()
	if east:
		var i: int = int(X(1200.0) / SimConst.COL) - 400
		while i < NC and (S.base[i] < WorldWater.SHORE_WET or S.water[i] > 0.0):
			i += 1
		return float(i) * SimConst.COL
	var j: int = int(X(8300.0) / SimConst.COL) + 400
	while j > 0 and (S.base[j] < WorldWater.SHORE_WET or S.water[j] > 0.0):
		j -= 1
	return float(j) * SimConst.COL


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


var bad_steps: int = 0


## One water step, then check the rule on every column inside the active windows that has just become wet: it needs a wet
## neighbour (or a sea column) from before the step, and ground below the wet limit.
func checked_step(S: SimState) -> void:
	var NC: int = SimConst.NC
	var before := S.water.duplicate()
	var wins: Array = []
	for w in S.waterWin:
		wins.append([w[0], w[1]])
	WorldWater.step(S)
	for w in wins:
		for j in range(w[0] - w[1] - 1, w[0] + w[1] + 2):
			var i: int = posmod(j, NC)
			if S.base[i] < WorldWater.RESERVOIR_BASE:
				continue
			if before[i] < WorldWater.MIN_DEPTH and S.water[i] >= WorldWater.MIN_DEPTH:
				var l: int = posmod(i - 1, NC)
				var r: int = posmod(i + 1, NC)
				var fed: bool = before[l] > 0.0 or before[r] > 0.0
				if not fed or S.base[i] + S.deform[i] >= WorldWater.WET_GROUND:
					bad_steps += 1


func settle_checked(S: SimState, limit: int = 20000) -> int:
	var steps: int = 0
	while not S.waterWin.is_empty() and steps < limit:
		checked_step(S)
		steps += 1
	return steps


func _sum(a: PackedFloat32Array) -> float:
	var t: float = 0.0
	for v in a:
		t += v
	return t


var _wet0: PackedByteArray = PackedByteArray()


## Dynamic wet columns that were not already wet at the start of the match (the shore shallows are wet from the start).
func wet_dynamic(S: SimState) -> int:
	if _wet0.is_empty():
		var S0 := fresh()
		_wet0.resize(SimConst.NC)
		for i in range(SimConst.NC):
			_wet0[i] = 1 if (S0.base[i] >= WorldWater.RESERVOIR_BASE and S0.water[i] >= WorldWater.MIN_DEPTH) else 0
	var n: int = 0
	for i in range(SimConst.NC):
		if S.base[i] >= WorldWater.RESERVOIR_BASE and S.water[i] >= WorldWater.MIN_DEPTH and _wet0[i] == 0:
			n += 1
	return n


func _init() -> void:
	print("== crater size by energy (straight-down hits on flat ground, x = 3000) ==")
	print("  E      R    depth   rim   depth/diam   bowl area   rim+apron area   rim/bowl")
	for E in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0]:
		var S := fresh()
		var rec = WorldCrater.dig(S, X(3000.0), E, null, "impact", 0.0, 1.0)
		var bowl: float = area(0.0, 1.0, rec, -1.0)
		var rim: float = area(0.0, 1.0 + WorldCrater.RIM_OUT, rec, 1.0)
		print("  %5.1f %6.1f %6.1f %5.1f   %.3f       %8.0f     %8.0f          %.2f" % [E, rec.r, rec.depth, rec.rim, rec.depth / (2.0 * rec.r), bowl, rim, rim / bowl])
	print("== impact energy: speed and tier to bowl radius (the prototype's radius in brackets) ==")
	for sp in [400.0, 800.0, 1200.0, 2000.0, 2600.0]:
		var line: String = "  speed %4.0f:" % sp
		for tier in [1.0, 2.0, 3.0, 4.0]:
			var E: float = WorldCrater.impactEnergy(sp, tier)
			line += "  t%d %4.0f [%4.0f]" % [int(tier), WorldCrater.radiusOf(E), (28.0 + sp * 0.05 + tier * 12.0) * SimConst.WS]
		print(line)
	print("== power-up, explosion and clash-wave radius by tier (the prototype's in brackets) ==")
	for tier in [2.0, 3.0, 4.0]:
		print("  tier %d: power-up %4.0f [%3.0f]   explosion %4.0f [%3.0f]   clash wave %4.0f [%3.0f]" % [int(tier), WorldCrater.radiusOf(WorldCrater.powerupEnergy(tier), true), (60.0 + tier * 28.0) * SimConst.WS, WorldCrater.radiusOf(WorldCrater.explodeEnergy(tier)), (70.0 + tier * 32.0) * 0.9 * SimConst.WS, WorldCrater.radiusOf(WorldCrater.clashEnergy(tier)), (60.0 + tier * 16.0) * SimConst.WS])

	print("== repeated hits never dig a shaft ==")
	var S1 := fresh()
	var first = WorldCrater.dig(S1, X(3000.0), 8.0, null, "impact", 0.0, 1.0)
	var count: int = 1
	for i in range(60):
		if WorldCrater.dig(S1, X(3000.0), 8.0, null, "impact", 0.0, 1.0) != null:
			count += 1
	var lowest: float = 0.0
	for i in range(SimConst.NC):
		lowest = minf(lowest, S1.deform[i])
	print("  61 identical E=8 hits on one spot: %d dug, lowest deform %.1f (first hit depth %.1f, R %.1f, cap %.1f)" % [count, lowest, first.depth, first.r, WorldCrater.RELIEF_MAX_RATIO * first.r])
	check(lowest >= -(WorldCrater.RELIEF_MAX_RATIO * first.r + 0.5), "lowest point stays within the relief cap")
	var S2 := fresh()
	WorldCrater.dig(S2, X(3000.0), 16.0, null, "impact", 0.0, 1.0)
	var c2: int = int(X(3000.0) / SimConst.COL)
	var deep0: float = S2.deform[c2]
	var small: int = 0
	for i in range(80):
		if WorldCrater.dig(S2, X(3000.0), 0.5, null, "impact", 0.0, 1.0) != null:
			small += 1
	print("  80 small hits (E=0.5) in the bottom of an E=16 bowl: %d dug, centre %.1f -> %.1f" % [small, deep0, S2.deform[c2]])
	check(S2.deform[c2] > deep0 - WorldCrater.RELIEF_MAX_RATIO * WorldCrater.radiusOf(0.5) - 0.5, "small hits only dent the bowl floor by their own relief cap")
	var S3 := fresh()
	var rng := SimRng.new(99)
	for i in range(400):
		WorldCrater.dig(S3, X(3000.0) + rng.range_(-300.0, 300.0) * SimConst.WS, rng.range_(1.0, 30.0), null, "impact", 0.0, 1.0)
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
		var rec = WorldCrater.dig(S4, X(3000.0), 8.0, null, "impact", dx, sqrt(1.0 - dx * dx))
		print("  horizontal share %.1f: bowl depth %5.1f  furrow tail offset %7.1f  furrow depth %4.1f" % [dx, rec.depth, rec.skid, rec.sdepth])
	var S5 := fresh()
	var r5 = WorldCrater.dig(S5, X(3000.0), 8.0, null, "impact", 0.8, 0.6)
	check(r5.skid < 0.0 and absf(r5.skid) <= WorldCrater.SKID_LEN_R * r5.r + 0.1 and r5.sdepth > 0.0, "a rightward diagonal hit skids from the left (tail at x - length)")

	print("== scorch: groove by beam power (plains, a 40-sample beam every 20 units) ==")
	for P in [0.5, 1.0, 2.0, 3.0, 4.0, 4.5]:
		var S6 := fresh()
		for k in range(40):
			WorldCrater.scorch(S6, X(3000.0) + 20.0 * SimConst.WS * float(k), P, "MERIDIAN SCAR", null)
		var depth1: float = 0.0
		for i in range(SimConst.NC):
			depth1 = minf(depth1, S6.deform[i])
		for k in range(40):
			WorldCrater.scorch(S6, X(3000.0) + 20.0 * SimConst.WS * float(k), P, "MERIDIAN SCAR", null)
		var depth2: float = 0.0
		for i in range(SimConst.NC):
			depth2 = minf(depth2, S6.deform[i])
		var hw: float = WorldCrater.SCORCH_HW0 + WorldCrater.SCORCH_HW_P * P
		var dd: float = WorldCrater.SCORCH_D0 + WorldCrater.SCORCH_D_P * P
		print("  P %.1f: half width %5.1f  reach %4.0f  groove depth %5.1f after one beam, %5.1f after two   (ridge bore %4.1f, glass trench %4.1f)" % [P, hw, WorldCrater.beamReach(P), -depth1, -depth2, dd * 1.6, dd * 0.8])
		check(absf(depth2 - depth1) < 0.01, "a second beam over the groove does not deepen it (P %.1f)" % P)

	print("== water: a bay dug at the coast ==")
	for cx in [shore_x(true) + 400.0, shore_x(true) + 2200.0, shore_x(false) - 1200.0]:
		var S7 := fresh()
		var rec = WorldCrater.dig(S7, cx, 25.0, null, "impact", 0.0, 1.0)
		var wet0: int = wet_dynamic(S7)
		var steps: int = settle(S7, 4000)
		var wet: int = wet_dynamic(S7)
		var maxsurf: float = -1e9
		for i in range(SimConst.NC):
			if S7.base[i] >= WorldWater.RESERVOIR_BASE and S7.water[i] >= WorldWater.MIN_DEPTH and _wet0[i] == 0:
				maxsurf = maxf(maxsurf, S7.base[i] + S7.deform[i] + S7.water[i])
		print("  E=25 at x=%4.0f (%s): R %.0f depth %.0f; wet crater columns %d -> %d, settled after %d ticks (%.1f s), highest surface %.2f" % [cx, WorldBiomes.biomeAt(cx), rec.r, rec.depth, wet0, wet, steps, float(steps) / 60.0, maxsurf])
		check(wet == 0 or (maxsurf <= 3.5 * SimConst.WS and maxsurf >= WorldWater.SHORE_WET - 75.0), "a coastal bay fills toward the shore limit and never above the sea")
	print("== water: an inland crater stays dry ==")
	for cx in [X(2000.0), X(3000.0), X(4000.0), X(6000.0), X(7000.0)]:
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
					checked_step(S9)
		var steps: int = settle_checked(S9)
		var dyn: int = wet_dynamic(S9)
		var far: int = 0
		for i in range(SimConst.NC):
			if S9.base[i] >= WorldWater.RESERVOIR_BASE and S9.water[i] >= WorldWater.MIN_DEPTH:
				var b: String = WorldBiomes.biomeAt(float(i) * SimConst.COL)
				if b != "ocean" and b != "village" and b != "plains":
					far += 1
		bad_total += bad_steps
		print("  planet %d: %d craters recorded, water windows left %d (%d ticks to settle), dynamic wet columns %d, columns that became wet without a wet neighbour or low enough ground %d, in non-coastal biomes %d" % [seed, S9.craters.size(), S9.waterWin.size(), steps, dyn, bad_steps, far])
		bad_steps = 0
	check(bad_total == 0, "every column that becomes wet has a wet neighbour and ground below the wet limit (craters cannot flood inland)")

	print("== a fighter under the surface of a crater lake is submerged ==")
	var S10 := fresh()
	WorldCrater.dig(S10, shore_x(true) + 400.0, 25.0, null, "impact", 0.0, 1.0)
	settle(S10, 4000)
	var lake_x: float = -1.0
	for i in range(int(shore_x(true) / SimConst.COL) - 40, int(shore_x(true) / SimConst.COL) + 200):
		if S10.water[i] >= WorldWater.HIDE_MIN_DEPTH + 20.0 and S10.base[i] >= WorldWater.RESERVOIR_BASE:   # a margin: the ground between columns is a little shallower than at one
			lake_x = float(i) * SimConst.COL + 4.0
	if lake_x < 0.0:
		print("  (no dynamic column in this bay reaches the %.0f-unit hiding depth; the sea itself does)" % WorldWater.HIDE_MIN_DEPTH)
	else:
		S10.fighters[0].x = lake_x
		S10.fighters[0].y = WorldWater.surfaceAt(S10, lake_x) - 90.0
		print("  fighter at x=%.0f, y=%.0f, water depth %.0f: cover = %s" % [lake_x, S10.fighters[0].y, WorldWater.depthAt(S10, lake_x), str(WorldCover.coverAt(S10, S10.fighters[0]))])
		check(WorldCover.coverAt(S10, S10.fighters[0]) == "submerged", "a fighter under the surface of a crater lake is submerged")


	print("== knockback slide: slam or slide by the angle of the hit ==")
	for v in [[1500.0, -300.0], [1500.0, -1200.0], [400.0, -900.0], [100.0, -1500.0], [3000.0, -200.0]]:
		print("  velocity (%6.0f, %6.0f): vertical share %.2f -> %s" % [v[0], v[1], absf(v[1]) / SimDetMath.hypot(v[0], v[1]), "SLAM (one crater)" if WorldSlide.isSlam(v[0], v[1]) else "SLIDE"])
	check(WorldSlide.isSlam(100.0, -1500.0) and not WorldSlide.isSlam(1500.0, -1200.0), "near-vertical hits slam, the rest slide")
	print("== knockback slide: distance by speed (flat plains, travel factor 1 and 6) ==")
	var flat_ok: bool = true
	for spN in [400.0, 900.0, 1500.0, 2500.0]:
		var line: String = "  normalised speed %4.0f:" % spN
		for tv in [1.0, 6.0]:
			var S11 := fresh()
			var f = S11.fighters[0]
			var o = S11.fighters[1]
			f.hp = 1e9
			var x0: float = X(2050.0)
			var g0: float = WorldTerrain.groundY(S11, x0)
			f.launchBy = o
			f.launchT = tv
			f.x = x0
			f.y = g0 + 1.0
			f.state = "launched"
			f.vx = spN * tv * 0.98
			f.vy = -spN * 0.2
			var rng11 := S11.rng.state_i32()
			var craters0: int = S11.craters.size()
			SimFighter.impact(S11, f, g0, SimDetMath.hypot(f.vx, f.vy))
			var ticks11: int = 0
			while f.state == "launched" and ticks11 < 3000:
				SimFighter.stepLaunched(S11, f, SimConst.DT)
				ticks11 += 1
			var moved: float = absf(SimWrap.sdx(x0, f.x))
			var pred: float = WorldSlide.slideDistance(spN * 0.98, 0.0, tv)
			line += "  x%d: slid %6.0f units (%.1f bh, %.2f s), closed form %6.0f" % [int(tv), moved, moved / 75.0, ticks11 / 60.0, pred]
			if spN < WorldSlide.HOP_SPEED and absf(moved - pred) > 0.15 * pred + 30.0 * SimConst.WS:
				flat_ok = false
			var draws: int = 0
			for e in S11.out.fx:
				if e.type == "damage" and e.region != "":
					draws += 1
			var expect: int = (rng11 + draws * 0x6D2B79F5) & 0xFFFFFFFF
			check(expect == (S11.rng.state_i32() & 0xFFFFFFFF), "the only S.rng draws in a slide are the %d wear hits (speed %.0f, travel %.0f)" % [draws, spN, tv])
			check(S11.craters.size() == craters0 or spN >= WorldSlide.HOP_SPEED, "a slide digs no crater unless it ends at a wall (speed %.0f, travel %.0f)" % [spN, tv])
		print(line)
	check(flat_ok, "the closed-form slide distance predicts the stepped slide on flat ground (15%% plus a margin)")

	print("== one crater per launch on ground: 300 random launches ==")
	var multi: int = 0
	var slides_n: int = 0
	var slams_n: int = 0
	var rg2 := SimRng.new(4242)
	for n in range(300):
		var S12 := fresh(1 + n % 7)
		var f2 = S12.fighters[0]
		f2.hp = 1e9
		f2.launchBy = S12.fighters[1]
		var x2: float = X(rg2.range_(1850.0, 2300.0))
		var ux: float = rg2.range_(-1.0, 1.0)
		var uy: float = rg2.range_(-1.4, 1.0)
		var frc: float = rg2.range_(800.0, 3000.0)
		f2.x = x2
		f2.y = WorldTerrain.groundY(S12, x2) + rg2.range_(20.0, 600.0)
		f2.launchT = WorldSlide.launchTravel(ux, uy)
		f2.vx = WorldSlide.launchVX(ux, uy, frc)
		f2.vy = uy * frc
		f2.state = "launched"
		var c0: int = S12.craters.size()
		var s0: int = S12.slides.size()
		var guard: int = 0
		while f2.state == "launched" and guard < 2400:
			SimFighter.stepLaunched(S12, f2, SimConst.DT)
			guard += 1
		var dc: int = S12.craters.size() - c0
		if dc > 1:
			multi += 1
		slides_n += S12.slides.size() - s0
		slams_n += dc
	print("  300 launches: %d slides, %d craters, %d launches with more than one crater" % [slides_n, slams_n, multi])
	check(multi == 0, "no launch leaves more than one crater on the ground")


	print("== collateral: the rolling budget, borrowing, the ceiling, evacuation ==")
	var Sc := fresh()
	var pop0: float = Sc.world.pop0
	var bcity: int = -1
	for b in Sc.buildings:
		if b.kind == "tower" and b.row == 1.0 and b.pop >= 8.0:
			bcity = b.idx
			break
	var cause = Sc.fighters[1]
	Sc.fighters[0].tier = 1.0
	Sc.fighters[1].tier = 1.0
	var want_total: float = 0.0
	var granted_total: float = 0.0
	for k in range(60):
		var bb = Sc.buildings[bcity + (k % 20)]
		var w: float = minf(bb.popAlive, 2.0)
		want_total += w
		granted_total += WorldCollateral.kill(Sc, bb.idx, w, cause, 0.0, bb.x)
	print("  tier 1, T 0: %.1f people would die, %.2f may (budget %.2f = 2 percent of %.0f), evacuated %.2f" % [want_total, granted_total, 0.02 * pop0, pop0, Sc.world.evacuated])
	check(granted_total <= 0.02 * pop0 + 0.001, "tier 1: no more than 2 percent die in 60 s")
	check(absf(granted_total + Sc.world.evacuated - want_total) < 0.001, "casualties plus evacuated equal what would have died")
	Sc.T = 61.0
	check(WorldCollateral.room(Sc) > 0.019 * pop0, "the window refills after 60 s")
	# borrowing: only at tier 3 and above, only for the event's own token
	var Sb := fresh()
	Sb.fighters[0].tier = 3.0
	Sb.fighters[1].tier = 1.0
	var tok: float = WorldCollateral.beginEvent(Sb, "slide", Sb.fighters[1])
	var g3: float = 0.0
	var pop3: float = Sb.world.pop0
	for bb in Sb.buildings:
		g3 += WorldCollateral.kill(Sb, bb.idx, bb.popAlive, Sb.fighters[1], tok, bb.x)
	print("  tier 3, one slide: %.2f died (window 8 percent = %.2f plus the slide allowance 5 percent = %.2f)" % [g3, 0.08 * pop3, 0.05 * pop3])
	check(g3 <= 0.13 * pop3 + 0.001 and g3 > 0.08 * pop3, "tier 3: a slide borrows up to 5 percent beyond the window")
	var Sn := fresh()
	Sn.fighters[0].tier = 3.0
	Sn.fighters[1].tier = 1.0
	WorldCollateral.beginEvent(Sn, "slide", Sn.fighters[1])
	var gn: float = 0.0
	for bb in Sn.buildings:
		gn += WorldCollateral.kill(Sn, bb.idx, bb.popAlive, Sn.fighters[1], 0.0, bb.x)
	check(gn <= 0.08 * Sn.world.pop0 + 0.001, "another source (token 0) cannot use the slide allowance")
	var S1t := fresh()
	S1t.fighters[0].tier = 1.0
	WorldCollateral.beginEvent(S1t, "slide", S1t.fighters[1])
	check(S1t.world.evtLeft == 0.0, "no borrowing at tier 1 or 2")
	# the ceiling
	var Sx := fresh()
	Sx.fighters[0].tier = 4.0
	Sx.world.maxTier = 1.0
	Sx.world.casualties = 0.099 * Sx.world.pop0
	WorldCollateral.kill(Sx, bcity, 5.0, Sx.fighters[1], 0.0, 0.0)
	check(Sx.world.casualties <= 0.10 * Sx.world.pop0 + 0.001, "the cumulative ceiling holds (10 percent at highest tier 1)")
	# normalisation and data-driven anguish
	var Sm1 := fresh()
	var Sm2 := fresh()
	Sm2.world.pop0 = Sm1.world.pop0 * 2.0
	WorldCollateral._feed(Sm1, 0.01 * Sm1.world.pop0, Sm1.fighters[1])
	WorldCollateral._feed(Sm2, 0.01 * Sm2.world.pop0, Sm2.fighters[1])
	check(absf(Sm1.fighters[1].menace - Sm2.fighters[1].menace) < 0.001 and absf(Sm1.fighters[0].anguish - Sm2.fighters[0].anguish) < 0.001, "a share of the population lost feeds the meters the same on any planet")
	var Sa := fresh()
	Sa.fighters[1].hasAnguish = true
	WorldCollateral._feed(Sa, 4.0, Sa.fighters[1])
	var an_ok: bool = true
	for fi in range(2):
		var fx = Sa.fighters[fi]
		var want_an: float = 4.0 * (fx.md.anguishCasSelf if fi == 1 else fx.md.anguishCasOther) * WorldCollateral.POP_REF / Sa.world.pop0
		print("  fighter %d: anguish %.3f after 4 casualties (data says %.3f)" % [fi, fx.anguish, want_an])
		if absf(fx.anguish - want_an) > 0.001:
			an_ok = false
	check(an_ok, "every fighter with the meter gains anguish at its data rates (meters.json: casualty/self, casualty/opponent)")
	# the choke point: nothing but collateral.gd feeds casualties
	var stray: int = 0
	for sub in ["core", "world", "director", "input"]:
		var d2 := DirAccess.open("res://sim/" + sub)
		for fname in d2.get_files():
			if fname.ends_with(".gd") and fname != "collateral.gd":
				var txt: String = FileAccess.get_file_as_string("res://sim/" + sub + "/" + fname)
				if txt.contains("casualty(") or txt.contains("world.casualties +=") or txt.contains("_feed("):
					stray += 1
					print("  stray casualty code in " + sub + "/" + fname)
	check(stray == 0, "no casualty is counted outside collateral.gd")
	# every source, budget spent: nothing dies, the people flee
	var Sd := fresh()
	Sd.fighters[0].tier = 1.0
	Sd.fighters[1].tier = 1.0
	Sd.world.cbSum = 1000.0
	Sd.world.cbBuckets[0] = 1000.0
	var cas0: float = Sd.world.casualties
	var pop_before: float = 0.0
	for b in Sd.buildings:
		pop_before += b.popAlive
	var cxx: float = Sd.buildings[bcity].x
	WorldStructures.damageArea(Sd, cxx, 0.0, 3000.0, 100000.0, Sd.fighters[1])
	WorldStructures.damageArea(Sd, cxx, 0.0, 3000.0, 100000.0, Sd.fighters[1], true)
	var pop_after: float = 0.0
	for b in Sd.buildings:
		pop_after += b.popAlive
	print("  budget spent, a huge blast and a huge beam: casualties %.2f, evacuated %.1f, people left in buildings %.1f of %.1f" % [Sd.world.casualties - cas0, Sd.world.evacuated, pop_after, pop_before])
	check(Sd.world.casualties == cas0 and Sd.world.evacuated > 0.0, "with the budget spent, blasts and beams kill nobody and evacuate instead")
	check(pop_before - pop_after <= Sd.world.evacuated + 0.01 and pop_before - pop_after >= Sd.world.evacuated - 0.01 - (Sd.world.evacuated if WorldCollateral.RELOCATE else 0.0), "everyone removed from a building is counted evacuated (some may have taken shelter in another)")

	print("== depth rows, the spatial index, implode and rubble ==")
	var Sr := fresh()
	var rows := [0, 0, 0, 0]
	for b in Sr.buildings:
		rows[int(b.row)] += 1
	print("  buildings by row (foreground, front street, mid, back): %s of %d, people %.0f" % [str(rows), Sr.buildings.size(), Sr.world.pop0])
	check(rows[1] > 0 and rows[2] > 0 and rows[3] > 0 and rows[0] > 0, "every depth row has buildings")
	var idx_ok: bool = true
	var rg3 := SimRng.new(5)
	for k in range(60):
		var xq: float = rg3.range_(0.0, SimConst.W)
		var rq: float = rg3.range_(500.0, 20000.0)
		var brute: float = 0.0
		for b in Sr.buildings:
			if b.alive and absf(SimWrap.sdx(xq, b.x)) < rq:
				brute += b.popAlive
		var viaIdx: float = WorldStructures.popNear(Sr, xq, rq) * WorldStructures.POP_NEAR_REF
		var cl: float = minf(brute, WorldStructures.POP_NEAR_REF)
		if absf(viaIdx - cl) > 0.01:
			idx_ok = false
	check(idx_ok, "popNear through the spatial index equals the brute-force sum")
	var tw = null
	for b in Sr.buildings:
		if b.kind == "tower" and b.row == 1.0:
			tw = b
			break
	Sr.out.fx.clear()
	WorldStructures.damageArea(Sr, tw.x + 4000.0, 0.0, 6000.0, 1.0e7, Sr.fighters[1])
	var fell: int = 0
	var implode: int = 0
	for e in Sr.out.fx:
		if e.type == "building_fall":
			fell += 1
			if e.mode == "implode":
				implode += 1
	var ci: int = int(tw.x / SimConst.COL)
	print("  a huge blast at the city: %d building_fall events (%d implode), heap at the tower %.0f (crest wanted %.0f), rubble total %.0f" % [fell, implode, Sr.rubble[ci], clampf(0.10 * tw.h, WorldStructures.RUBBLE_MIN, WorldStructures.RUBBLE_MAX), _sum(Sr.rubble)])
	check(fell > 0 and fell == implode and Sr.rubble[ci] > 0.0 and not tw.alive, "blast-levelled buildings implode and leave a rubble heap")
	var r_before: float = _sum(Sr.rubble)
	WorldCrater.dig(Sr, tw.x, 12.0, Sr.fighters[1], "impact", 0.0, 1.0)
	print("  then a crater on it: rubble %.0f -> %.0f" % [r_before, _sum(Sr.rubble)])


	print("== the hard hit makes the mark (Orb's playtest bug) ==")
	for special in [false, true]:
		var S13 := fresh()
		var f3 = S13.fighters[0]
		f3.hp = 1e9
		f3.launchBy = S13.fighters[1]
		var x3: float = X(2050.0)
		f3.x = x3
		f3.y = WorldTerrain.groundY(S13, x3) + 400.0
		f3.launchT = 1.0
		f3.vx = 200.0
		f3.vy = -2800.0
		f3.state = "launched"
		f3.launchSpecial = special
		var g3guard: int = 0
		var first_t: float = -1.0
		while f3.state == "launched" and g3guard < 1200:
			var nb: int = S13.craters.size()
			SimFighter.stepLaunched(S13, f3, SimConst.DT)
			if S13.craters.size() > nb and first_t < 0.0:
				first_t = S13.T
			g3guard += 1
		var cr3: Array = S13.craters
		var line3: String = "  a %s slam at speed 2800: %d crater(s)" % ["special" if special else "ordinary", cr3.size()]
		for c in cr3:
			line3 += ", R %.0f depth %.0f" % [c.r, c.depth]
		print(line3 + ", hopped %s" % str(f3.hopped))
		check(cr3.size() == 1, "a hard slam leaves exactly one crater, made by the first contact (special %s)" % str(special))


	print("== placement and the shore (docs/world/cities.md section 6) ==")
	var Sp := fresh()
	var NCp: int = SimConst.NC
	var bad_foot: int = 0
	var in_water: int = 0
	var names := ["Netmend", "Bellgate", "outskirts", "far village"]
	var per := [0, 0, 0, 0]
	for b in Sp.buildings:
		per[WorldTerrain._settlementOf(b.x)] += 1
		if not WorldTerrain._footOk(Sp, b.x, b.w):
			bad_foot += 1
		if Sp.water[int(b.x / SimConst.COL)] > 0.0:
			in_water += 1
	print("  buildings by settlement: Netmend %d, Bellgate %d, outskirts %d, far village %d (%d in all), people %.0f" % [per[0], per[1], per[2], per[3], Sp.buildings.size(), Sp.world.pop0])
	check(bad_foot == 0, "every building's footprint is above BUILD_MIN_GROUND and not on a slope")
	check(in_water == 0, "no building stands in the water")
	var lowest_g: float = 1.0e9
	for b in Sp.buildings:
		var c0b: int = int(floor((b.x - b.w * 0.5) / SimConst.COL))
		var c1b: int = int(floor((b.x + b.w * 0.5) / SimConst.COL))
		for c in range(c0b, c1b + 1):
			lowest_g = minf(lowest_g, Sp.base[posmod(c, NCp)])
	print("  lowest ground under any building: %.1f (limit %.1f)" % [lowest_g, WorldTerrain.BUILD_MIN_GROUND])
	check(lowest_g >= WorldTerrain.BUILD_MIN_GROUND - 0.01, "no building has ground below the limit under it")
	# the waterline: no dry column below the shore limit connected to the sea; the step to the dry land is small
	var reach := PackedByteArray()
	reach.resize(NCp)
	for dir in [1, -1]:
		var on: bool = false
		for lap in range(2 * NCp):
			var i: int = lap % NCp if dir == 1 else NCp - 1 - (lap % NCp)
			if Sp.base[i] < WorldWater.RESERVOIR_BASE:
				on = true
			elif on and Sp.base[i] < WorldWater.SHORE_WET:
				reach[i] = 1
			else:
				on = false
	var dry_connected: int = 0
	var init_mismatch: int = 0
	for i in range(NCp):
		if Sp.base[i] >= WorldWater.RESERVOIR_BASE:
			if reach[i] == 1 and Sp.water[i] <= 0.0:
				dry_connected += 1
			if reach[i] == 0 and Sp.water[i] > 0.0:
				init_mismatch += 1
	var max_step: float = 0.0
	for i in range(NCp):
		var j: int = (i + 1) % NCp
		var wi: bool = Sp.water[i] > 0.0
		var wj: bool = Sp.water[j] > 0.0
		if wi != wj:
			var dry: int = j if wi else i
			max_step = maxf(max_step, absf(Sp.base[dry]))
	print("  dry columns below sea level connected to the sea: %d; wet columns not from the flood fill: %d; largest step from the water surface to the dry ground beside it: %.1f (limit %.1f)" % [dry_connected, init_mismatch, max_step, absf(WorldWater.SHORE_WET)])
	check(dry_connected == 0, "no dry column below the shore limit is connected to the sea")
	check(init_mismatch == 0, "the start water is the reservoir plus the connected shallows and nothing else")
	check(max_step <= absf(WorldWater.SHORE_WET) + 1.0, "the step from the sea's surface to the land beside it is at most a quarter of a fighter height")
	# evacuee menace
	var Se := fresh()
	Se.fighters[0].tier = 1.0
	Se.fighters[1].tier = 1.0
	Se.world.cbSum = 1000.0
	Se.world.cbBuckets[0] = 1000.0
	var m0: float = Se.fighters[1].menace
	var an0: float = Se.fighters[0].anguish
	var bt = null
	for b in Se.buildings:
		if b.pop >= 3.0:
			bt = b
			break
	WorldCollateral.kill(Se, bt.idx, 3.0, Se.fighters[1], 0.0, bt.x)
	var expect_m: float = 3.0 * WorldCollateral.EVAC_MENACE * 425.0 / Se.world.pop0
	print("  three evacuees caused by the villain: menace +%.2f (wanted %.2f), anguish +%.2f" % [Se.fighters[1].menace - m0, expect_m, Se.fighters[0].anguish - an0])
	check(absf(Se.fighters[1].menace - m0 - expect_m) < 0.001 and Se.fighters[0].anguish == an0, "evacuees feed the causer's menace at 0.45 times 425 / pop0 and nobody's anguish")

	print("== B2: aimed launches, chains, floors (docs/world/b2-plan.md) ==")
	var aimed: int = 0
	var tried: int = 0
	var plan_mismatch: int = 0
	var chain_hist := {}
	var stray_hits: int = 0
	var cap_break: int = 0
	var open_token: int = 0
	var rng_draws: int = 0
	var rgb := SimRng.new(77)
	for n in range(240):
		var Sb2 := fresh(1 + n % 5)
		var Ab = Sb2.fighters[1]
		var Db = Sb2.fighters[0]
		Ab.tier = float(1 + int(rgb.next() * 4.0))
		Db.hp = 1.0e9
		Ab.hp = 1.0e9
		# a target on the ground somewhere in the city, a little way from a tower
		var pick: int = int(rgb.next() * float(Sb2.buildings.size()))
		var bcity2 = Sb2.buildings[pick]
		var side: float = -1.0 if rgb.next() < 0.5 else 1.0
		Db.x = SimWrap.wrap(bcity2.x - side * rgb.range_(1200.0, 7000.0))
		Db.y = WorldTerrain.groundY(Sb2, Db.x) + rgb.range_(40.0, 300.0)
		var force: float = rgb.range_(1500.0, 2600.0)
		var tierF: float = 1.0 + Ab.ld.launch * (Ab.tier - 1.0)
		var cands: Array = WorldBrunt.candidates(Sb2, Db)
		if cands.is_empty():
			continue
		tried += 1
		var plan = null
		var rng_before: int = Sb2.rng.state_i32()
		for cbi in cands:
			plan = WorldBrunt.aim(Sb2, Ab, Db, Sb2.buildings[cbi], force, tierF, false)
			if plan != null:
				break
		if plan == null:
			continue
		if Sb2.rng.state_i32() != rng_before:
			rng_draws += 1
		aimed += 1
		var predicted: Array = []
		for e in plan.brunt.chain:
			predicted.append(int(e.b))
		if false:
			print("    DBG chain %s; plan %s from x %.1f y %.1f ground %.1f; building x %.1f w %.1f" % [str(plan.brunt.chain), str(plan.brunt.hit), Db.x, Db.y, WorldTerrain.groundY(Sb2, Db.x), Sb2.buildings[plan.brunt.b].x, Sb2.buildings[plan.brunt.b].w])
		DirLaunch.doLaunch(Sb2, Ab, Db, plan, force)
		var hits: Array = []
		var hit_txt: Array = []
		var guard2: int = 0
		while Db.state == "launched" and guard2 < 900:
			SimFighter.stepLaunched(Sb2, Db, SimConst.DT)
			if false:
				print("    DBG x %.1f y %.1f vx %.1f vy %.1f aim %d state %s" % [Db.x, Db.y, Db.vx, Db.vy, Db.aimB, Db.state])
			for e in Sb2.out.fx:
				if e.type == "building_hit":
					hits.append(int(e.b))
					hit_txt.append("%s(%d r%.2f)" % [e.outcome, int(e.b), e.ratio])
			Sb2.out.fx.clear()
			guard2 += 1
		chain_hist[hits.size()] = chain_hist.get(hits.size(), 0) + 1
		if hits != predicted:
			plan_mismatch += 1
			if plan_mismatch <= 8:
				var pt: Array = []
				for e in plan.brunt.chain:
					pt.append("%s(%d r%.2f sp%.0f)" % [e.outcome, int(e.b), e.ratio, e.spN])
				print("    mismatch seed %d tier %.0f: plan %s, got %s" % [n, Ab.tier, str(pt), str(hit_txt)])
		for hb in hits:
			if not predicted.has(hb):
				stray_hits += 1
		if hits.size() > WorldBrunt.chainCap(Ab.tier, false):
			cap_break += 1
		if Db.aimB != -1 or Db.chainEvt != 0.0:
			open_token += 1
	print("  %d of %d launches with a candidate were aimable; chain lengths (buildings hit): %s; plan differed from the outcome in %d; hits off the plan %d; over the tier cap %d; aim or token left open %d" % [aimed, tried, str(chain_hist), plan_mismatch, stray_hits, cap_break, open_token])
	check(aimed > 20, "the aim search finds launches into the city")
	check(plan_mismatch == 0, "the planned chain is the chain that happens (buildings and order)")
	check(stray_hits == 0, "no building is hit outside the plan")
	check(open_token == 0, "the aim and the chain token are closed after every flight")
	check(cap_break == 0, "no chain is longer than its tier's cap")
	check(rng_draws == 0, "the aim search and the chain lookahead draw nothing from the match RNG")
	# no incidental collision: an unaimed launch through the city hits nothing
	var incidental: int = 0
	var rgc := SimRng.new(5)
	for n in range(120):
		var Sc2 := fresh(1 + n % 3)
		var Dc = Sc2.fighters[0]
		var Ac = Sc2.fighters[1]
		Dc.hp = 1.0e9
		Dc.x = X(2500.0) + rgc.range_(0.0, 14000.0)
		Dc.y = WorldTerrain.groundY(Sc2, Dc.x) + 50.0
		var ux2: float = 1.0 if rgc.next() < 0.5 else -1.0
		var plan2 := {"ux": ux2, "uy": 0.12, "fm": 1.0}
		DirLaunch.doLaunch(Sc2, Ac, Dc, plan2, rgc.range_(1500.0, 2600.0))
		var g3b: int = 0
		while Dc.state == "launched" and g3b < 900:
			SimFighter.stepLaunched(Sc2, Dc, SimConst.DT)
			for e in Sc2.out.fx:
				if e.type == "building_hit":
					incidental += 1
			Sc2.out.fx.clear()
			g3b += 1
	check(incidental == 0, "an unaimed launch never collides with a building (%d hits in 120 launches through the city)" % incidental)
	# floors: a skyscraper
	var Sf := fresh()
	var tall = null
	for bb in Sf.buildings:
		if bb.floors >= 12:
			tall = bb
			break
	check(tall != null, "the city has a tower of at least 12 floors")
	if tall != null:
		var gy: float = WorldTerrain.groundY(Sf, tall.x)
		var fh: float = WorldBrunt.floorH(tall)
		print("  a tower of %d floors, height %.0f, hp %.0f, people %.1f" % [tall.floors, tall.h, tall.maxhp, tall.popAlive])
		var ohigh: Dictionary = WorldBrunt.outcomeOf(Sf, tall, gy + (float(tall.floors) - 2.5) * fh, 1800.0, 2.0)
		var olow: Dictionary = WorldBrunt.outcomeOf(Sf, tall, gy + 1.0 * fh, 1800.0, 2.0)
		print("  speed 1800, tier 2: high hit ratio %.2f (%s), low hit ratio %.2f (%s)" % [ohigh.ratio, ohigh.outcome, olow.ratio, olow.outcome])
		check(ohigh.ratio > olow.ratio, "a higher floor is weaker than a lower one")
		# a real punch through the top floors: the tower stands shorter
		var Fa = Sf.fighters[0]
		var Fby = Sf.fighters[1]
		Fa.launchT = 1.0
		Fa.vx = 1500.0
		Fa.vy = 0.0
		Fa.launchBy = Fby
		var pop_b: float = tall.popAlive
		var top_y: float = gy + (float(tall.floors) - 1.0) * fh
		var oc1: Dictionary = WorldBrunt.outcomeOf(Sf, tall, top_y, 1800.0, 4.0)
		oc1["outcome"] = "punch"
		oc1["pass"] = true
		var res: Dictionary = WorldBrunt.applyFloors(Sf, tall, oc1, Fby, 0.0, tall.x, Fa, top_y)
		print("  a punch through the top: pancake %s, collapse %s, floors standing %d of %d, people %.1f -> %.1f, height now %.0f" % [str(res.pancake), str(res.collapse), WorldBrunt.standingCount(tall), tall.floors, pop_b, tall.popAlive, WorldStructures.curH(tall)])
		check(tall.alive and WorldBrunt.standingCount(tall) == tall.floors - oc1.hit.size() and not res.pancake, "a punch through the top leaves a shorter tower (nothing above to fall)")
		check(WorldStructures.curH(tall) < tall.h, "the tower is shorter after the punch")
		# a punch low down: the span is wider than a tunnel, so the floors above pancake
		var Sg := fresh()
		var tall2 = null
		for bb in Sg.buildings:
			if bb.floors >= 12:
				tall2 = bb
				break
		var gy2: float = WorldTerrain.groundY(Sg, tall2.x)
		var fh2: float = WorldBrunt.floorH(tall2)
		# clear floors 2..5 by hand (a four floor span), then punch at floor 1: the span above the ground floor grows past a tunnel
		var y_low: float = gy2 + 2.0 * fh2
		var oc2: Dictionary = WorldBrunt.outcomeOf(Sg, tall2, y_low, 99999.0, 4.0)
		var pop2: float = tall2.popAlive
		var res2: Dictionary = WorldBrunt.applyFloors(Sg, tall2, oc2, Sg.fighters[1], 0.0, tall2.x, Sg.fighters[0], y_low)
		print("  a hard punch at floor 2 of %d (%s): pancake %s, collapse %s, floors standing %d, people %.1f -> %.1f" % [tall2.floors, oc2.outcome, str(res2.pancake), str(res2.collapse), WorldBrunt.standingCount(tall2), pop2, tall2.popAlive])
		check(res2.pancake or res2.collapse or WorldBrunt.standingCount(tall2) >= tall2.floors - 2, "a long cleared span pancakes the stack above it, a short one is a tunnel")
		# occupants never go negative and never exceed what was there
		check(tall2.popAlive >= 0.0 and tall2.popAlive <= pop2 + 0.0001, "people only fall")
		# a blast still implodes the whole building
		var Sh := fresh()
		var tall3 = null
		for bb in Sh.buildings:
			if bb.floors >= 12:
				tall3 = bb
				break
		WorldStructures.damageArea(Sh, tall3.x, 0.0, 600.0, 1.0e8, Sh.fighters[1])
		check(not tall3.alive, "an area blast still levels a skyscraper whole")

	print("== terrain fixes T1 to T4 (docs/world/terrain-audit.md) ==")
	var lim_t: float = WorldCrater.REPOSE_SLOPE * SimConst.COL
	# T2: a wall on flat plains relaxes to the angle of repose, conserving volume
	var St_t := fresh()
	var cw: int = int(X(2100.0) / SimConst.COL)
	var vol0_t: float = _sum(St_t.deform)
	for k in range(-3, 4):
		St_t.deform[cw + k] = 450.0
		St_t.rubble[cw + k] = 450.0
	var vol1_t: float = _sum(St_t.deform)
	var mg_t: float = WorldCrater.relax(St_t, cw, 40)
	var worst_step: float = 0.0
	for k in range(-60, 60):
		worst_step = maxf(worst_step, absf((St_t.base[cw + k + 1] + St_t.deform[cw + k + 1]) - (St_t.base[cw + k] + St_t.deform[cw + k])))
	print("  a 7-column wall of 450: largest step %.1f after relaxing (limit %.0f), volume %.0f -> %.0f, rubble %.0f" % [worst_step, lim_t, vol1_t, _sum(St_t.deform), _sum(St_t.rubble)])
	check(worst_step <= lim_t + WorldCrater.REPOSE_EPS + 0.5, "a wall relaxes to the angle of repose")
	check(absf(_sum(St_t.deform) - vol1_t) < 2.0, "the relaxation conserves volume")
	check(absf(_sum(St_t.rubble) - 7.0 * 450.0) < 2.0, "and its rubble")
	# craters stay as dug: relaxing a fresh crater of any size changes nothing
	var moved_by_relax: float = 0.0
	for E in [0.5, 2.0, 8.0, 30.0]:
		var Sc_t := fresh()
		var rc = WorldCrater.dig(Sc_t, X(2050.0), E, Sc_t.fighters[1], "impact", 0.0, 1.0, E > 20.0)
		var before := Sc_t.deform.duplicate()
		WorldCrater.relax(Sc_t, int(X(2050.0) / SimConst.COL), int(rc.r * 3.0 / SimConst.COL) + 20)
		for i in range(SimConst.NC):
			moved_by_relax += absf(Sc_t.deform[i] - before[i])
	check(moved_by_relax < 0.5, "a crater's bowl and rim are already inside the angle of repose (relaxing moves %.2f units in all)" % moved_by_relax)
	# T3: a slide over a heap does not cut a slot_t; over flat ground it still carves
	var Sh_t := fresh()
	var ch_t: int = int(X(2100.0) / SimConst.COL)
	for k in range(-4, 5):
		Sh_t.deform[ch_t + k] = 200.0
		Sh_t.rubble[ch_t + k] = 200.0
	WorldCrater.carveSegment(Sh_t, float(ch_t - 2) * SimConst.COL, float(ch_t + 2) * SimConst.COL, 30.0, true, 0.5)
	var slot_t: float = 1.0e9
	for k in range(-2, 2):
		slot_t = minf(slot_t, Sh_t.deform[ch_t + k])
	WorldCrater.carveSegment(Sh_t, X(2300.0), X(2300.0) + 4.0 * SimConst.COL, 30.0, false, 0.0)
	var flat_cut: float = Sh_t.deform[int(X(2300.0) / SimConst.COL) + 1]
	print("  a slide over a 200 heap: lowest column %.0f; over flat ground: %.0f" % [slot_t, flat_cut])
	check(slot_t > 150.0, "a slide never cuts a slot through a heap")
	check(flat_cut < -20.0, "and still carves a trench in open ground")
	# T3: a beam groove across a heap leaves no step over the limit
	var Sg_t := fresh()
	var cg_t: int = int(X(2100.0) / SimConst.COL)
	for k in range(-10, 11):
		Sg_t.deform[cg_t + k] = 400.0 * (1.0 - absf(float(k)) / 11.0)
		Sg_t.rubble[cg_t + k] = Sg_t.deform[cg_t + k]
	for i in range(30):
		WorldCrater.scorch(Sg_t, X(2100.0) + float(i - 15) * 20.0, 2.0, "HORIZON CLEAVE", Sg_t.fighters[1])
	var gstep: float = 0.0
	for k in range(-80, 80):
		gstep = maxf(gstep, absf((Sg_t.base[cg_t + k + 1] + Sg_t.deform[cg_t + k + 1]) - (Sg_t.base[cg_t + k] + Sg_t.deform[cg_t + k])))
	check(gstep <= lim_t + WorldCrater.REPOSE_EPS + 0.5, "a beam groove across a heap leaves no step over the limit (largest %.1f)" % gstep)
	# T1: heaps. A front-row building leaves a gentle heap; a back-row one leaves none on the ground
	var Sr_t := fresh()
	var f1_t = null
	var f2_t = null
	for b in Sr_t.buildings:
		if b.row == 1.0 and f1_t == null and b.h > 2000.0:
			f1_t = b
		if b.row == 3.0 and f2_t == null and b.h > 2000.0:
			f2_t = b
	var d0_t := Sr_t.deform.duplicate()
	WorldStructures.damageBuilding(Sr_t, f2_t, 1.0e9, Sr_t.fighters[1], "implode", f2_t.x, 0.0)
	var changed2: float = 0.0
	for i in range(SimConst.NC):
		changed2 += absf(Sr_t.deform[i] - d0_t[i])
	var d1_t := Sr_t.deform.duplicate()
	WorldStructures.damageBuilding(Sr_t, f1_t, 1.0e9, Sr_t.fighters[1], "implode", f1_t.x, 0.0)
	var heap_max: float = 0.0
	var heap_step: float = 0.0
	var under_t: float = 0.0
	var cf_t: int = int(f1_t.x / SimConst.COL)
	for k in range(-80, 80):
		var i2: int = cf_t + k
		heap_max = maxf(heap_max, Sr_t.deform[i2] - d1_t[i2])
		heap_step = maxf(heap_step, absf((Sr_t.base[i2 + 1] + Sr_t.deform[i2 + 1]) - (Sr_t.base[i2] + Sr_t.deform[i2])))
	for b in Sr_t.buildings:
		if b.alive and b != f1_t:
			var c0f: int = int(floor((b.x - b.w * 0.5) / SimConst.COL)) - 1
			var c1f: int = int(floor((b.x + b.w * 0.5) / SimConst.COL)) + 1
			for c in range(c0f, c1f + 1):
				under_t += absf(Sr_t.deform[c] - d1_t[c])
	print("  a tower of %.0f units in row 3 leaves %.0f of heap on the ground; one in row 1 leaves a crest of %.0f, largest step %.1f, change under standing footings %.1f" % [f2_t.h, changed2, heap_max, heap_step, under_t])
	check(changed2 == 0.0, "a back-row building leaves no heap on the fighter plane's ground")
	check(heap_max > 0.0 and heap_step <= lim_t + WorldCrater.REPOSE_EPS + 0.5, "a front-row building leaves a heap no steeper than the angle of repose")
	check(under_t == 0.0, "a heap never lands on a standing building's footing")
	# T4: a building stands on the highest ground under its footprint
	var Sf2_t := fresh()
	var tb_t = Sf2_t.buildings[40]
	var cc_t: int = int(floor((tb_t.x + tb_t.w * 0.5) / SimConst.COL))
	Sf2_t.deform[cc_t] = 150.0
	check(WorldStructures.baseY(Sf2_t, tb_t) >= Sf2_t.base[cc_t] + 150.0 - 0.01, "a building's footing is the highest ground under its footprint (%.0f)" % WorldStructures.baseY(Sf2_t, tb_t))

	print("== G1: rims as ramps, gentle heaps, structure reach by tier (docs/world/ground-contact.md, structure-reach.md) ==")
	var worst_in: float = 0.0
	var worst_vol: float = 0.0
	var crest_ok: bool = true
	for E in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0]:
		var Sr1_g := fresh()
		var rc1 = WorldCrater.dig(Sr1_g, X(2050.0), E, Sr1_g.fighters[1], "impact", 0.0, 1.0)
		var c01: int = int(X(2050.0) / SimConst.COL)
		var nn: int = int(ceil(rc1.r * 2.0 / SimConst.COL)) + 2
		# the steepest rise on the way out from the centre to the crest
		var crest_k: int = 0
		var crest_v: float = -1.0e9
		for k in range(0, nn):
			if Sr1_g.deform[c01 + k] > crest_v and k * SimConst.COL > rc1.r * 0.5:
				crest_v = Sr1_g.deform[c01 + k]
				crest_k = k
		var mx_in: float = 0.0
		for k in range(0, crest_k):
			mx_in = maxf(mx_in, (Sr1_g.deform[c01 + k + 1] - Sr1_g.deform[c01 + k]) / SimConst.COL)
		worst_in = maxf(worst_in, mx_in)
		if crest_v > WorldCrater.RIM_DEPTH_MAX * rc1.depth + 1.0:
			crest_ok = false
		var neg1: float = 0.0
		var pos1: float = 0.0
		for k in range(-nn, nn + 1):
			var dv: float = Sr1_g.deform[c01 + k]
			if dv < 0.0:
				neg1 += -dv
			else:
				pos1 += dv
		worst_vol = maxf(worst_vol, pos1 / maxf(neg1, 1.0))
		print("  E %.1f: R %.0f depth %.0f, crest %.1f (%.2f d), steepest slope into the crest %.2f, rim and apron area / bowl area %.2f" % [E, rc1.r, rc1.depth, crest_v, crest_v / rc1.depth, mx_in, pos1 / maxf(neg1, 1.0)])
	check(worst_in <= 0.62, "a crater's inner slope up to the lip is at most 0.6 at every energy (largest %.2f)" % worst_in)
	check(crest_ok, "the rim crest is at most RIM_DEPTH_MAX of the depth")
	check(worst_vol <= 1.0, "the rim and apron hold no more than the bowl (the 1D profile)")
	# heaps: gentle
	var Sh1_g := fresh()
	var fh1_g = null
	for b in Sh1_g.buildings:
		if b.row == 1.0 and fh1_g == null and b.h > 2000.0:
			fh1_g = b
	WorldStructures.damageBuilding(Sh1_g, fh1_g, 1.0e9, Sh1_g.fighters[1], "implode", fh1_g.x, 0.0)
	var ch1_g: int = int(fh1_g.x / SimConst.COL)
	var hs1_g: float = 0.0
	for k in range(-90, 90):
		hs1_g = maxf(hs1_g, absf(Sh1_g.deform[ch1_g + k + 1] - Sh1_g.deform[ch1_g + k]) / SimConst.COL)
	check(hs1_g <= WorldStructures.RUBBLE_SLOPE * 1.1, "a heap is a ramp: its steepest slope is at most %.2f (largest %.2f)" % [WorldStructures.RUBBLE_SLOPE, hs1_g])
	# structure reach: a house, a blast, three tiers
	var Sx_g := fresh()
	var house_g = null
	for b in Sx_g.buildings:
		if b.kind == "house" and b.row == 1.0 and b.maxhp < 400.0 and house_g == null:
			house_g = b
	var hits_g: Array = []
	for tier in [1.0, 2.0, 3.0, 4.0]:
		for mul in [1.05, 1.5, 1.7, 2.3, 2.7, 3.0]:
			var S2_g := fresh()
			var A2_g = S2_g.fighters[1]
			A2_g.tier = tier
			var h2_g = S2_g.buildings[house_g.idx]
			var r0_g: float = 300.0
			var xb_g: float = SimWrap.wrap(h2_g.x - (r0_g * mul + h2_g.w * 0.5))
			var hp0_g: float = h2_g.hp
			WorldStructures.damageArea(S2_g, xb_g, WorldTerrain.groundY(S2_g, xb_g) + 10.0, r0_g, 5000.0, A2_g)
			if h2_g.hp < hp0_g:
				hits_g.append([tier, mul])
	var reach_ok_g: bool = true
	for tier in [1.0, 2.0, 3.0, 4.0]:
		var want_g: float = Sx_g.fighters[1].ld.reachStructure[int(tier) - 1]
		for mul in [1.05, 1.5, 1.7, 2.3, 2.7, 3.0]:
			var got_g: bool = hits_g.has([tier, mul])
			if got_g != (mul <= want_g):
				reach_ok_g = false
	print("  structure reach hits (tier, distance in old radii): %s" % str(hits_g))
	check(reach_ok_g, "a blast reaches a building out to the tier's factor times the old radius and no further (data: %s)" % str(Sx_g.fighters[1].ld.reachStructure))
	var S3_g := fresh()
	var A3_g = S3_g.fighters[1]
	A3_g.tier = 4.0
	var h3_g = S3_g.buildings[house_g.idx]
	var x3_g: float = SimWrap.wrap(h3_g.x - (300.0 * 1.5 + h3_g.w * 0.5))
	var hp3_g: float = h3_g.hp
	WorldStructures.damageArea(S3_g, x3_g, WorldTerrain.groundY(S3_g, x3_g) + 10.0, 300.0, 5000.0, A3_g, false, 0.0, -1, 0.0, 1.0)
	check(h3_g.hp == hp3_g or Sx_g.fighters[1].ld.reachStructure[3] <= 1.5, "a beam's path sample (reach 1.0) is not widened by the tier")

	print("")
	print("probe: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
