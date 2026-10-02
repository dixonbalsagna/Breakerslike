extends SceneTree
# Shots meeting buildings in flight, the chip pool, an air burst, mines (docs/world/ground-contact.md section 27).
var fails: int = 0
func ok(c: bool, w: String) -> void:
	print("  %s  %s" % ["ok  " if c else "FAIL", w])
	if not c:
		fails += 1
func fresh() -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 1, {}, {"intro": false})
	S.out.fx.clear()
	return S
func sig(b) -> float:
	var v: float = b.hp + b.wear + float(b.fmask) * 0.001
	for d in b.fdmg:
		v += d
	return v
func isolate(S: SimState, b) -> void:
	for q in S.buildings:
		if q != b and absf(SimWrap.sdx(q.x, b.x)) < 1500.0:
			q.alive = false   # the test's own: nothing in front of the target to catch the shot
func pick(S: SimState, kind: String, which: String):
	var best = null
	var arr: Array = []
	for b in S.buildings:
		if WorldStructures.dz(b) <= WorldStructures.Z_REACH and b.kind == kind and b.alive and WorldWater.surfaceAt(S, b.x - b.w * 0.5 - 200.0) < WorldStructures.baseY(S, b) and absf(WorldTerrain.groundY(S, b.x - b.w * 0.5 - 200.0) - WorldStructures.baseY(S, b)) < 15.0 and absf(WorldTerrain.groundY(S, b.x - b.w * 0.5 - 100.0) - WorldStructures.baseY(S, b)) < 15.0:
			arr.append(b)
	arr.sort_custom(func(a, c): return a.maxhp < c.maxhp)
	if arr.is_empty():
		return null
	var r = arr[arr.size() / 2]
	isolate(S, r)
	return r
# fire one LINE shot of the kind from 600 units to the left of the building at height y, run it to its end; returns its end cause
func shoot(S: SimState, b, kind: String, y: float, tier: int, power: float = -1.0) -> String:
	S.fighters[0].tier = float(tier)
	var o := {"x": SimWrap.wrap(b.x - b.w * 0.5 - 200.0), "y": y, "z": 0.0, "ux": 1.0, "uy": 0.0}
	if power > 0.0:
		o["power"] = power
	var sh = SimShots.fire(S, 0, kind, o)
	if sh == null:
		return "nofire"
	var cause := "life"
	for t in range(160):
		SimShots.step(S, 1.0 / 60.0)
		if sh.dead:
			break
	for e in S.out.fx:
		if e.type == "shot_end":
			cause = str(e.cause) if "cause" in e else cause
	return cause
func _init() -> void:
	print("== shots meet buildings ==")
	var S0 := fresh()
	var house = pick(S0, "house", "")
	var tower = pick(S0, "tower", "")
	print("  house maxhp %.0f floors %d h %.0f | tower maxhp %.0f floors %d h %.0f" % [house.maxhp, house.floors, house.h, tower.maxhp, tower.floors, tower.h])
	# A. shots to level a house, by kind and tier (each shot fresh from the same building)
	for kind in ["bolt", "shard", "arc", "lob", "charged"]:
		var line: String = "  %-8s to level the house by tier:" % kind
		for t in [1, 2, 3, 4]:
			var S := fresh()
			var b = pick(S, "house", "")
			var n: int = 0
			var firstShow: int = 0
			var tries: int = 0
			while b.alive and n < 80 and tries < 120:
				var w0: float = b.hp
				var q0: float = sig(b)
				shoot(S, b, kind, WorldStructures.baseY(S, b) + b.h * 0.15, t)
				tries += 1
				if sig(b) == q0:
					continue   # it flew past or met a neighbour at its start: not a shot at this building
				n += 1
				if firstShow == 0 and b.hp < w0:
					firstShow = n
			line += "  t%d %s (first shows at %d)" % [t, str(n) if not b.alive else ">80", firstShow]
		print(line)
	# B. a tower, charged and bolt, at heights
	for kind in ["bolt", "charged", "lob"]:
		for hf in [0.15, 0.5, 0.9]:
			var line: String = "  %-8s at %.0f%% of a %d-floor tower, shots to level / floors standing after 10 shots:" % [kind, hf * 100.0, tower.floors]
			for t in [1, 4]:
				var S := fresh()
				var b = pick(S, "tower", "")
				var n: int = 0
				var tries: int = 0
				while b.alive and n < 60 and tries < 150:
					var q0: float = sig(b)
					shoot(S, b, kind, WorldStructures.baseY(S, b) + b.h * hf, t)
					tries += 1
					if sig(b) == q0:
						continue
					n += 1
					if n == 10:
						line += "  t%d standing %d/%d" % [t, WorldBrunt.standingCount(b), b.floors]
				line += "  (t%d %s)" % [t, "levelled at " + str(n) if not b.alive else "stands after 60"]
			print(line)
	# C. a shot above the roof passes; one at the wall ends 'building'
	var S2 := fresh()
	var bb = pick(S2, "house", "")
	var c1: String = shoot(S2, bb, "charged", WorldStructures.baseY(S2, bb) + bb.h + 400.0, 1)
	ok(bb.hp == bb.maxhp, "a charged shot flying over a house's roof does nothing to it")
	var c2: String = shoot(S2, bb, "charged", WorldStructures.baseY(S2, bb) + bb.h * 0.4, 1)
	ok(bb.hp < bb.maxhp or not bb.alive, "and one at its wall does (hp %.0f of %.0f)" % [bb.hp, bb.maxhp])
	var ends := ""
	for e in S2.out.fx:
		if e.type == "shot_end":
			ends += " " + str(e.cause)
	print("  shot_end events:", ends)
	# D. the chip pool: bolts at a tower, wear before it shows
	var S3 := fresh()
	var tb = pick(S3, "tower", "")
	var shown: int = 0
	var n3: int = 0
	var tr3: int = 0
	while shown == 0 and n3 < 200 and tr3 < 300:
		var s0: float = sig(tb)
		var w0: float = tb.wear
		shoot(S3, tb, "bolt", WorldStructures.baseY(S3, tb) + tb.h * 0.3, 1)
		tr3 += 1
		if sig(tb) == s0:
			continue
		n3 += 1
		if tb.wear == 0.0 or tb.wear < w0:
			shown = n3
	print("  tower (%.0f hp), tier-1 bolts before the first shows: %d (wear pool then %.0f)" % [tb.maxhp, shown, tb.wear])
	# E. air bursts
	for h in [0.0, 150.0, 300.0, 450.0]:
		var line: String = "  burst %3.0f above the ground, crater by kind (tier 1):" % h
		for kind in ["bolt", "charged", "mine"]:
			var S := fresh()
			var X: float = 89600.0 + 3000.0
			var r := WorldBlast.shotHit(S, 0, kind, X, WorldTerrain.groundY(S, X) + h, 0.0, 0.0, -1500.0, "ground")
			line += "  %s %s |" % [kind, "none" if r.crater == null else "R%.0f d%.0f" % [r.crater.r, r.crater.depth]]
		print(line)
	# F. mines: one, and a field
	for t in [1, 4]:
		var S := fresh()
		S.fighters[0].tier = float(t)
		var X: float = 89600.0 + 3000.0
		var us := Time.get_ticks_usec()
		var r := WorldBlast.mineBlast(S, 0, X, WorldTerrain.groundY(S, X), 0.0)
		var cost: int = Time.get_ticks_usec() - us
		print("  ground mine tier %d: R%.0f depth %.0f (%d us)" % [t, r.crater.r if r.crater != null else 0.0, r.crater.depth if r.crater != null else 0.0, cost])
	var Sf := fresh()
	var X0: float = 89600.0 + 2000.0
	var us2 := Time.get_ticks_usec()
	var nc0: int = Sf.craters.size()
	var minG: float = 0.0
	for i in range(12):
		var x: float = X0 + 110.0 * float(i)
		WorldBlast.mineBlast(Sf, 0, x, WorldTerrain.groundY(Sf, x), 0.0)
	var cost2: int = Time.get_ticks_usec() - us2
	for i in range(int(X0 / 32.0), int((X0 + 1400.0) / 32.0)):
		minG = minf(minG, Sf.deform[i])
	print("  a field of 12 ground mines 110 units apart: %d craters recorded, deepest ground %.0f below base, %d us in all" % [Sf.craters.size() - nc0, minG, cost2])
	# G. a mine beside a tower and a house
	var Sm := fresh()
	var mt = pick(Sm, "tower", "")
	var mh = pick(Sm, "house", "")
	var t0: float = mt.hp
	WorldBlast.mineBlast(Sm, 0, mt.x - mt.w * 0.5 - 30.0, WorldTerrain.groundY(Sm, mt.x), 0.0)
	print("  a tier-1 ground mine at a tower's foot: tower %.0f of %.0f hp" % [mt.hp, mt.maxhp])
	var Sh := fresh()
	var mh2 = pick(Sh, "house", "")
	WorldBlast.mineBlast(Sh, 0, mh2.x, WorldTerrain.groundY(Sh, mh2.x), 0.0)
	print("  and at a house: %s (%.0f of %.0f hp)" % ["levelled" if not mh2.alive else "stands", maxf(mh2.hp, 0.0), mh2.maxhp])
	print("DIRECT: %d check(s) failed" % fails)
	quit()
