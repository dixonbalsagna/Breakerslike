class_name WorldTerrain
## Terrain heightfield: the twin of terrain.js (genWorld, groundY, seaAt); craters live in crater.gd and water in
## water.gd. The heights are float32 storage (PackedFloat32Array), exactly as the JS Float32Arrays: every store rounds
## to float32.


## Terrain, buildings and trees. The layout draws from its own stream seeded 4242, never from S.rng.
static func genWorld(S: SimState) -> void:
	var r := SimRng.new(4242)
	var NC: int = SimConst.NC
	S.deform.resize(NC)
	S.deform.fill(0.0)
	var t := PackedFloat32Array()
	t.resize(NC)
	for i in range(NC):
		var x: float = float(i) * SimConst.COL
		var b: String = WorldBiomes.biomeAt(x)
		var n: float = SimDetMath.sin(x * 0.0021) * 0.5 + SimDetMath.sin(x * 0.0057 + 1.3) * 0.3 + SimDetMath.sin(x * 0.013 + 2.1) * 0.2
		if b == "ocean":
			t[i] = -340.0 + n * 35.0
		elif b == "mountains":
			var k: float = SimMathx.jclamp((x - 6500.0) / 1100.0, 0.0, 1.0)
			var env: float = SimDetMath.sin(PI * k)
			t[i] = env * (330.0 + 560.0 * absf(SimDetMath.sin(x * 0.0042 + 0.7)) * (0.55 + 0.45 * SimDetMath.sin(x * 0.013)))
		elif b == "desert":
			t[i] = n * 28.0
		elif b == "plains":
			t[i] = n * 16.0
		elif b == "forest":
			t[i] = 10.0 + n * 22.0
		else:
			t[i] = 0.0
	# Four wrapped 25-column box blurs, ping-ponging between two float32 buffers.
	var a := t
	var bf := PackedFloat32Array()
	bf.resize(NC)
	for p in range(4):
		for i in range(NC):
			var s: float = 0.0
			for k in range(-12, 13):
				s += a[(i + k + NC) % NC]
			bf[i] = s / 25.0
		var tmp := a
		a = bf
		bf = tmp
	S.base = a.duplicate()
	S.buildings.clear()
	S.trees.clear()
	var pop: float = 0.0
	pop += _row(S, r, 1260.0, 1760.0, "house")
	pop += _row(S, r, 2370.0, 3830.0, "tower")
	pop += _row(S, r, 3880.0, 4480.0, "house")
	pop += _row(S, r, 7640.0, 7960.0, "house")
	var x2: float = 4530.0
	while x2 < 5470.0:
		var tr := SimState.TreeState.new()
		tr.x = x2
		tr.h = r.range_(46.0, 110.0)
		S.trees.append(tr)
		x2 += r.range_(16.0, 40.0)
	S.world = SimState.World.new()
	S.world.pop0 = pop
	S.scorch = PackedFloat32Array()
	S.scorch.resize(NC)
	S.scorch.fill(0.0)
	S.craters.clear()
	WorldWater.init(S)


## One row of buildings from x0 to x1 (terrain.js row()); returns the population it added. The draws happen in the
## JS order: tower w, h, h, seed, spacing; house w, h, pop, seed, spacing.
static func _row(S: SimState, r: SimRng, x0: float, x1: float, kind: String) -> float:
	var pop: float = 0.0
	var x: float = x0
	while x < x1:
		var b := SimState.Building.new()
		if kind == "tower":
			var w: float = r.range_(30.0, 64.0)
			var cx: float = x + w / 2.0
			var mid: float = 1.0 - absf((cx - 3100.0) / 760.0)
			var h1: float = r.range_(120.0, 280.0)
			var h: float = h1 + SimMathx.jmax(0.0, mid) * r.range_(80.0, 380.0)
			b.x = cx; b.w = w; b.h = h; b.maxhp = h * 6.0; b.hp = h * 6.0; b.alive = true; b.kind = "tower"
			b.pop = SimMathx.jround(w * h / 1200.0)
			b.seed = r.next()
			x += w + r.range_(4.0, 16.0)
		else:
			var w: float = r.range_(28.0, 50.0)
			var h: float = r.range_(36.0, 72.0)
			b.x = x + w / 2.0; b.w = w; b.h = h; b.maxhp = h * 3.0; b.hp = h * 3.0; b.alive = true; b.kind = "house"
			b.pop = SimMathx.jround(r.range_(2.0, 6.0))
			b.seed = r.next()
			x += w + r.range_(16.0, 70.0)
		b.popAlive = b.pop
		S.buildings.append(b)
		pop += b.pop
	return pop


## Ground height at any x: linear between column samples of the generated base plus crater deformation.
static func groundY(S: SimState, x: float) -> float:
	var c: float = SimWrap.wrap(x) / SimConst.COL
	var fi: float = floor(c)
	var f: float = c - fi
	var i: int = int(fi)
	var j: int = (i + 1) % SimConst.NC
	var a: float = S.base[i] + S.deform[i]
	var b: float = S.base[j] + S.deform[j]
	return a + (b - a) * f


## The sea basin: water only where the original (base) terrain is below sea level (the prototype's rule). Craters that
## fill with water are WorldWater's business (S.water); this rule is what the AI, launch planner and fighter speed use.
static func seaAt(S: SimState, x: float) -> bool:
	return S.base[int(floor(SimWrap.wrap(x) / SimConst.COL))] < -30.0
