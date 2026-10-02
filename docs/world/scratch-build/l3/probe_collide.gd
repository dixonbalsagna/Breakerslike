extends SceneTree
# L3 checks: the swept test, the lanes helpers, flights in the streets, plan equals outcome at depth, blasts by plan distance.
var fails: int = 0
const BH: float = 75.0

func ok(cond: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		fails += 1


func fresh(depth: bool, seed: int = 1) -> SimState:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed, {}, {"depth": depth, "intro": false})
	S.out.fx.clear()
	return S


func setb(b, x: float, w: float, d: float, z: float, h: float) -> void:
	b.x = x; b.w = w; b.d = d; b.z = z; b.h = h
	b.maxhp = 1000.0; b.hp = 1000.0; b.alive = true
	b.floors = 3; b.fmask = 7


func _init() -> void:
	print("== L3: true collisions (depth forced on) ==")
	var S := fresh(true)
	var body: Array = WorldLanes.body()
	var rx: float = body[0]
	var ry: float = body[1]
	var rz: float = body[2]
	# a synthetic world: building 0 a box, the rest moved out of the way
	for i in range(1, S.buildings.size()):
		S.buildings[i].alive = false
	var b0 = S.buildings[0]
	var X: float = 20000.0
	setb(b0, X, 300.0, 300.0, -600.0, 1500.0)
	WorldStructures.buildIndex(S)
	var gy: float = WorldStructures.baseY(S, b0)
	var top: float = gy + WorldStructures.curH(b0)
	var list: Array = [0]
	var r1: Dictionary = WorldStructures.sweep(S, list, X - 1000.0, gy + 100.0, -600.0, X + 1000.0, gy + 100.0, -600.0, rx, ry, rz)
	ok(r1.hit and r1.face == "end" and absf(r1.x - (X - 150.0 - rx)) < 0.01 and r1.nx < 0.0, "a flight along x meets the near end face at the body's extent (x %.1f)" % r1.get("x", 0.0))
	var r2: Dictionary = WorldStructures.sweep(S, list, X, gy + 100.0, 300.0, X, gy + 100.0, -900.0, rx, ry, rz)
	ok(r2.hit and r2.face == "front" and absf(r2.z - (-600.0 + 150.0 + rz)) < 0.01, "a flight in depth from the street meets the front face (z %.1f)" % r2.get("z", 0.0))
	var r3: Dictionary = WorldStructures.sweep(S, list, X - 1000.0, top + ry + 5.0, -600.0, X + 1000.0, top + ry + 5.0, -600.0, rx, ry, rz)
	ok(not r3.hit, "a flight over the roof misses")
	var r4: Dictionary = WorldStructures.sweep(S, list, X - 1000.0, gy + 100.0, 0.0, X + 1000.0, gy + 100.0, 0.0, rx, ry, rz)
	ok(not r4.hit, "a flight in the street (z = 0) never meets a block building")
	var r5: Dictionary = WorldStructures.sweep(S, list, X, gy + 100.0, -600.0, X + 500.0, gy + 100.0, -600.0, rx, ry, rz)
	ok(r5.hit and r5.t == 0.0, "a body that starts inside is reported at t = 0")
	var r6: Dictionary = WorldStructures.sweep(S, list, X, gy + 100.0, -600.0, X + 500.0, gy + 100.0, -600.0, rx, ry, rz, true)
	ok(not r6.hit, "and skipped when the test asks (a body leaving the building it crossed)")
	var r7: Dictionary = WorldStructures.sweep(S, list, X, top + 100.0, -600.0, X, gy + 50.0, -600.0, rx, ry, rz)
	ok(r7.hit and r7.face == "top", "a body falling onto the roof meets the top face")
	# a tie goes to the lower index
	var b1 = S.buildings[1]
	setb(b1, X, 300.0, 300.0, -600.0, 1500.0)
	WorldStructures.buildIndex(S)
	var r8: Dictionary = WorldStructures.sweep(S, [0, 1], X - 1000.0, gy + 100.0, -600.0, X + 1000.0, gy + 100.0, -600.0, rx, ry, rz)
	var r8b: Dictionary = WorldStructures.sweep(S, [1, 0], X - 1000.0, gy + 100.0, -600.0, X + 1000.0, gy + 100.0, -600.0, rx, ry, rz)
	ok(r8.hit and r8.b == 0 and r8b.hit and r8b.b == 1, "two boxes hit at the same instant: the list's first wins (the callers sort ascending)")
	b1.alive = false
	# across the seam
	setb(b0, 40.0, 300.0, 300.0, -600.0, 1500.0)
	WorldStructures.buildIndex(S)
	var gy2: float = WorldStructures.baseY(S, b0)
	var r9: Dictionary = WorldStructures.sweep(S, [0], SimConst.W - 500.0, gy2 + 100.0, -600.0, 600.0, gy2 + 100.0, -600.0, rx, ry, rz)
	ok(r9.hit and absf(SimWrap.sdx(r9.x, 40.0 - 150.0 - rx)) < 0.01, "a sweep across the seam meets a box on the far side (x %.1f)" % r9.get("x", 0.0))
	# brute force: random segments against stepping
	setb(b0, X, 400.0, 250.0, -700.0, 1200.0)
	WorldStructures.buildIndex(S)
	var gy3: float = WorldStructures.baseY(S, b0)
	var top3: float = gy3 + WorldStructures.curH(b0)
	var rng := SimRng.new(5)
	var disagree: int = 0
	var worst: float = 0.0
	for n in range(400):
		var x0: float = X + rng.range_(-1500.0, 1500.0)
		var y0: float = gy3 + rng.range_(-50.0, 1500.0)
		var z0: float = rng.range_(-1400.0, 400.0)
		var x1: float = X + rng.range_(-1500.0, 1500.0)
		var y1: float = gy3 + rng.range_(-50.0, 1500.0)
		var z1: float = rng.range_(-1400.0, 400.0)
		var sr: Dictionary = WorldStructures.sweep(S, [0], x0, y0, z0, x1, y1, z1, rx, ry, rz)
		var bt: float = -1.0
		var N: int = 800
		for k in range(N + 1):
			var tt: float = float(k) / float(N)
			var px: float = x0 + (x1 - x0) * tt
			var py: float = y0 + (y1 - y0) * tt
			var pz: float = z0 + (z1 - z0) * tt
			if absf(px - X) <= 200.0 + rx and py >= gy3 - ry and py <= top3 + ry and pz >= -700.0 - 125.0 - rz and pz <= -700.0 + 125.0 + rz:
				bt = tt
				break
		if sr.hit != (bt >= 0.0):
			disagree += 1
			print("    corner graze (sweep hit, stepping misses): sweep hit %s t %.4f, stepped %.4f; seg (%.1f %.1f %.1f) -> (%.1f %.1f %.1f)" % [str(sr.hit), sr.get("t", -1.0), bt, x0 - X, y0 - gy3, z0, x1 - X, y1 - gy3, z1])
		elif sr.hit:
			worst = maxf(worst, absf(sr.t - bt))
	ok(disagree <= 1 and worst < 0.003, "400 random segments agree with brute-force stepping (%d disagree: a corner graze the stepped reference misses; the entry time within %.4f of the stepped one)" % [disagree, worst])
	# blocked
	ok(WorldStructures.blocked(S, X, gy3 + 100.0, -700.0, rx, ry, rz) == 0 and WorldStructures.blocked(S, X, gy3 + 100.0, 0.0, rx, ry, rz) == -1, "blocked: inside a footprint the index, in the street -1")
	# the lanes helpers on the L1 layout
	var S2 := fresh(true, 2)
	var bad: int = 0
	var out_of_street: int = 0
	var rr := SimRng.new(9)
	for n in range(200):
		var bx = S2.buildings[int(rr.next() * float(S2.buildings.size()))]
		var xq: float = SimWrap.wrap(bx.x + rr.range_(-300.0, 300.0))
		var zq: float = rr.range_(-1500.0, 600.0)
		var zc: float = WorldLanes.clearLane(S2, xq, zq)
		var ln: int = WorldLanes.laneAt(zc)
		if ln < 0 or String(WorldLanes.data().lanes[ln].kind) != "street":
			out_of_street += 1
		if WorldStructures.blocked(S2, xq, WorldTerrain.groundY(S2, xq) + 80.0, zc, rx, ry, rz) != -1:
			bad += 1
	print("    DBG clearLane: out of a street %d, blocked %d" % [out_of_street, bad])
	ok(out_of_street == 0 and bad == 0, "clearLane gives a depth inside a street that no footprint overlaps (200 tries on the lane layout)")
	# unaimed flights in the street never hit a building
	var stray: int = 0
	var rl := SimRng.new(11)
	for n in range(100):
		var S3 := fresh(true, 1 + n % 5)
		var A3 = S3.fighters[1]
		var D3 = S3.fighters[0]
		D3.hp = 1.0e9
		var bq = S3.buildings[int(rl.next() * float(S3.buildings.size()))]
		D3.x = SimWrap.wrap(bq.x - 3000.0)
		D3.y = WorldTerrain.groundY(S3, D3.x) + 150.0
		D3.z = 0.0
		D3.state = "launched"
		D3.launchBy = A3
		D3.launchT = 3.0
		D3.vx = 1500.0 * 3.0
		D3.vy = 400.0
		var g: int = 0
		while D3.state == "launched" and g < 900:
			SimFighter.stepLaunched(S3, D3, SimConst.DT)
			for e in S3.out.fx:
				if e.type == "building_hit":
					stray += 1
			S3.out.fx.clear()
			g += 1
	ok(stray == 0, "100 flights along the street through the city hit no building at depth (hits %d)" % stray)
	# plan equals outcome at depth (the B2 probe's test on the depth model)
	var aimed: int = 0
	var tried: int = 0
	var mism: int = 0
	var strays: int = 0
	var rgb := SimRng.new(77)
	for n in range(240):
		var Sb := fresh(true, 1 + n % 5)
		var Ab = Sb.fighters[1]
		var Db = Sb.fighters[0]
		Ab.tier = float(1 + int(rgb.next() * 4.0))
		Db.hp = 1.0e9
		Ab.hp = 1.0e9
		var pick: int = int(rgb.next() * float(Sb.buildings.size()))
		var bc = Sb.buildings[pick]
		var side: float = -1.0 if rgb.next() < 0.5 else 1.0
		Db.x = SimWrap.wrap(bc.x - side * rgb.range_(1200.0, 7000.0))
		Db.y = WorldTerrain.groundY(Sb, Db.x) + rgb.range_(40.0, 300.0)
		var force: float = rgb.range_(1500.0, 2600.0)
		var tierF: float = 1.0 + Ab.ld.launch * (Ab.tier - 1.0)
		var cands: Array = WorldBrunt.candidates(Sb, Db)
		if cands.is_empty():
			continue
		tried += 1
		var plan = null
		for cbi in cands:
			plan = WorldBrunt.aim(Sb, Ab, Db, Sb.buildings[cbi], force, tierF, false)
			if plan != null:
				break
		if plan == null:
			continue
		aimed += 1
		var predicted: Array = []
		for e in plan.brunt.chain:
			predicted.append(int(e.b))
		DirLaunch.doLaunch(Sb, Ab, Db, plan, force)
		var hits: Array = []
		var g2: int = 0
		while Db.state == "launched" and g2 < 900:
			SimFighter.stepLaunched(Sb, Db, SimConst.DT)
			for e in Sb.out.fx:
				if e.type == "building_hit":
					hits.append(int(e.b))
			Sb.out.fx.clear()
			g2 += 1
		if hits != predicted:
			mism += 1
			if mism <= 6:
				print("    mismatch seed %d tier %.0f: plan %s, got %s" % [n, Ab.tier, str(predicted), str(hits)])
		for hb in hits:
			if not predicted.has(hb):
				strays += 1
	ok(aimed > 20, "the aim search finds launches into the city at depth (%d of %d)" % [aimed, tried])
	ok(mism == 0, "plan equals outcome at depth: %d of %d launches differ, %d hits off the plan" % [mism, aimed, strays])
	# blasts by plan distance
	var S4 := fresh(true)
	for i in range(1, S4.buildings.size()):
		S4.buildings[i].alive = false
	var bb = S4.buildings[0]
	setb(bb, 30000.0, 300.0, 300.0, -600.0, 900.0)
	WorldStructures.buildIndex(S4)
	var F = S4.fighters[0]
	F.tier = 1.0
	F.z = 0.0
	var hp0: float = bb.hp
	WorldStructures.damageArea(S4, 30000.0, WorldTerrain.groundY(S4, 30000.0) + 50.0, 380.0, 400.0, F)
	ok(bb.hp == hp0, "a blast of radius 380 in the street does not reach a block face 450 away in plan")
	WorldStructures.damageArea(S4, 30000.0, WorldTerrain.groundY(S4, 30000.0) + 50.0, 520.0, 400.0, F)
	ok(bb.hp < hp0, "a blast of radius 520 does")
	F.z = -450.0
	bb.hp = hp0
	WorldStructures.damageArea(S4, 30000.0, WorldTerrain.groundY(S4, 30000.0) + 50.0, 100.0, 400.0, F)
	ok(bb.hp < hp0, "a blast at the block's own depth reaches it (the fighter's depth is the blast's)")
	print("L3: %d check(s) failed" % fails)
	quit(1 if fails > 0 else 0)
