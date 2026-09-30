class_name WorldTerrain
## Terrain heightfield: the twin of terrain.js (genWorld, groundY, seaAt); craters live in crater.gd and water in
## water.gd. The heights are float32 storage (PackedFloat32Array), exactly as the JS Float32Arrays: every store rounds
## to float32.


## Depth rows (docs/world/buildings-in-depth.md, written in fighter heights, 1 bh = 75 units): the depth of each row's
## centre from the fighter plane. Row 0 is the foreground (in front of the plane), 1 the front street, 2 mid, 3 back.
const BH: float = 75.0
const ROW_Z_BH: Array = [10.0, -8.0, -22.0, -38.0]
const ROW_JITTER_BH: float = 1.0            # per-building depth jitter (rows 1 to 3), from the building's seed: no extra draw
const FG_H_MAX_BH: float = 6.0              # the foreground row is low: at most this many fighter heights
## Placement (docs/world/cities.md section 6): a settlement sits on a platform, its span is trimmed to where the natural
## ground is dry enough, and a building is only accepted where its footprint is above the sea and not on a slope.
const SETTLE_FLOOR: float = 0.5 * BH        # the platform: the ground inside a settlement is at least this high
const TRIM_G: float = -1.0 * BH             # a span starts where the natural ground first reaches this (never fills the sea in)
const PLATFORM_BLEND: int = 24              # columns over which the platform blends into the natural ground
const BUILD_MIN_GROUND: float = 0.25 * BH   # every column under a footprint (and one either side) is at least this high
const BUILD_MAX_SLOPE: float = 0.35         # and the ground under it varies by at most this share of its width
## Settlements: the span (original coordinates), the building kind of the front street, and the extra rows laid after it:
## [row, kind, height factor, gap factor, x offset in units]. The front street is generated exactly as before, so its
## layout is unchanged; the extra rows draw after every front street, and the settlement's people are then rescaled so
## its population is the front street's.
const SETTLEMENTS: Array = [
	{"x0": 1260.0, "x1": 1760.0, "kind": "house", "rows": [[0, "house", 1.0, 3.5, 120.0], [2, "house", 1.0, 1.8, 200.0]]},
	{"x0": 2370.0, "x1": 3830.0, "kind": "tower", "rows": [[0, "house", 1.0, 5.5, 300.0], [2, "tower", 1.2, 1.0, 260.0], [3, "tower", 1.4, 1.4, 500.0]]},
	{"x0": 3880.0, "x1": 4480.0, "kind": "house", "rows": [[2, "house", 1.0, 1.5, 200.0]]},
	{"x0": 7640.0, "x1": 7960.0, "kind": "house", "rows": [[2, "house", 1.0, 1.5, 200.0]]},
]


## Terrain, buildings and trees. The layout draws from its own stream seeded 4242, never from S.rng. Every original
## length is in the coordinates of the original planet (xn = x / PS), then the relief and the object sizes are
## multiplied by the feature scale WS (and the mountains by MS), so the planet is PS times longer with WS times bigger
## things on it (SimConst).
static func genWorld(S: SimState) -> void:
	var r := SimRng.new(4242)
	var NC: int = SimConst.NC
	var WS: float = SimConst.WS
	var PS: float = SimConst.PS
	S.deform.resize(NC)
	S.deform.fill(0.0)
	var t := PackedFloat32Array()
	t.resize(NC)
	for i in range(NC):
		var xn: float = float(i) * SimConst.COL / PS
		var b: String = WorldBiomes.biomeAt(float(i) * SimConst.COL)
		var n: float = SimDetMath.sin(xn * 0.0021) * 0.5 + SimDetMath.sin(xn * 0.0057 + 1.3) * 0.3 + SimDetMath.sin(xn * 0.013 + 2.1) * 0.2
		if b == "ocean":
			t[i] = (-340.0 + n * 35.0) * WS
		elif b == "mountains":
			var k: float = SimMathx.jclamp((xn - 6500.0) / 1100.0, 0.0, 1.0)
			var env: float = SimDetMath.sin(PI * k)
			t[i] = env * (330.0 + 560.0 * absf(SimDetMath.sin(xn * 0.0042 + 0.7)) * (0.55 + 0.45 * SimDetMath.sin(xn * 0.013))) * SimConst.MS
		elif b == "desert":
			t[i] = n * 28.0 * WS
		elif b == "plains":
			t[i] = n * 16.0 * WS
		elif b == "forest":
			t[i] = (10.0 + n * 22.0) * WS
		else:
			t[i] = 0.0
	# Four wrapped box blurs of half width SMOOTH_HALF columns (the original 12 columns of 8 units, times PS, in columns
	# of COL), ping-ponging between two float32 buffers. A running sum keeps the cost linear.
	var half: int = int(round(12.0 * 8.0 * PS / SimConst.COL))
	var kw: float = float(2 * half + 1)
	var a := t
	var bf := PackedFloat32Array()
	bf.resize(NC)
	for p in range(4):
		var s: float = 0.0
		for k in range(-half, half + 1):
			s += a[(k + NC) % NC]
		bf[0] = s / kw
		for i in range(1, NC):
			s += a[(i + half) % NC] - a[(i - half - 1 + NC) % NC]
			bf[i] = s / kw
		var tmp := a
		a = bf
		bf = tmp
	S.base = a.duplicate()
	S.buildings.clear()
	S.trees.clear()
	var spans: Array = _platforms(S)
	# Front streets first (the original layout, draw for draw), then the extra rows of each settlement.
	var totals: Array = []
	for st in SETTLEMENTS:
		totals.append(_row(S, r, spans[totals.size()][0], spans[totals.size()][1], st.kind, 1, 1.0, 1.0, 0.0))
	for k in range(SETTLEMENTS.size()):
		var st = SETTLEMENTS[k]
		for rw in st.rows:
			_row(S, r, spans[k][0], spans[k][1], rw[1], rw[0], rw[2], rw[3], rw[4] * WS)
	# Conserve each settlement's population: rescale all its rows to the front street's total.
	var pop: float = 0.0
	var byS: Array = []
	for k in range(SETTLEMENTS.size()):
		byS.append([])
	for i in range(S.buildings.size()):
		var b = S.buildings[i]
		var k: int = _settlementOf(b.x)
		byS[k].append(b)
	for k in range(SETTLEMENTS.size()):
		var raw: float = 0.0
		for b in byS[k]:
			raw += b.pop
		var scale: float = totals[k] / maxf(raw, 1.0)
		for b in byS[k]:
			b.pop = SimMathx.jmax(1.0, SimMathx.jround(b.pop * scale))
			b.popAlive = b.pop
			pop += b.pop
	var x2: float = 4530.0 * PS
	while x2 < 5470.0 * PS:
		var tr := SimState.TreeState.new()
		tr.x = x2
		tr.h = r.range_(46.0, 110.0) * WS
		S.trees.append(tr)
		x2 += r.range_(16.0, 40.0) * WS
	S.world = SimState.World.new()
	S.world.pop0 = pop
	S.rubble = PackedFloat32Array()
	S.rubble.resize(NC)
	S.rubble.fill(0.0)
	WorldStructures.buildIndex(S)
	S.scorch = PackedFloat32Array()
	S.scorch.resize(NC)
	S.scorch.fill(0.0)
	S.craters.clear()
	S.crack = PackedFloat32Array()
	S.crack.resize(NC)
	S.crack.fill(0.0)
	S.slides.clear()
	WorldWater.init(S)
	WorldCollateral.init(S)


## The platform under each settlement: trim the span to where the natural ground first reaches TRIM_G (from each end), lift
## the ground inside to at least SETTLE_FLOOR with a smooth blend over PLATFORM_BLEND columns at each end, and return the
## trimmed spans [x start, x end] in world units.
static func _platforms(S: SimState) -> Array:
	var PS: float = SimConst.PS
	var COL: float = SimConst.COL
	var NC: int = SimConst.NC
	var out: Array = []
	for st in SETTLEMENTS:
		var i0: int = int(st.x0 * PS / COL)
		var i1: int = int(st.x1 * PS / COL)
		while i0 < i1 and S.base[i0 % NC] < TRIM_G:
			i0 += 1
		while i1 > i0 and S.base[i1 % NC] < TRIM_G:
			i1 -= 1
		for i in range(i0 - PLATFORM_BLEND, i1 + PLATFORM_BLEND + 1):
			var j: int = (i + NC) % NC
			var g: float = S.base[j]
			if g >= SETTLE_FLOOR or g < TRIM_G:
				continue
			var w: float = 1.0
			if i < i0 + PLATFORM_BLEND:
				w = clampf(float(i - (i0 - PLATFORM_BLEND)) / float(2 * PLATFORM_BLEND), 0.0, 1.0)
			if i > i1 - PLATFORM_BLEND:
				w = minf(w, clampf(float((i1 + PLATFORM_BLEND) - i) / float(2 * PLATFORM_BLEND), 0.0, 1.0))
			w = w * w * (3.0 - 2.0 * w)
			S.base[j] = g + (SETTLE_FLOOR - g) * w
		out.append([float(i0) * COL, float(i1) * COL])
	return out


## Is a building of width w centred at cx on ground that is high enough and flat enough?
static func _footOk(S: SimState, cx: float, w: float) -> bool:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var c0: int = int(floor((cx - w * 0.5) / COL)) - 1
	var c1: int = int(floor((cx + w * 0.5) / COL)) + 1
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for c in range(c0, c1 + 1):
		var g: float = S.base[posmod(c, NC)]
		lo = minf(lo, g)
		hi = maxf(hi, g)
	return lo >= BUILD_MIN_GROUND and hi - lo <= BUILD_MAX_SLOPE * w


## The settlement index a building at x belongs to (by the original spans).
static func _settlementOf(x: float) -> int:
	var xn: float = x / SimConst.PS
	for k in range(SETTLEMENTS.size()):
		if xn >= SETTLEMENTS[k].x0 - 100.0 and xn < SETTLEMENTS[k].x1 + 100.0:
			return k
	return 0


## One row of buildings across a span. Population per building is the original's times POP_K = WS / PS (rescaled per
## settlement afterwards). hp follows the building's original (unscaled) height, so a tower WS times bigger is not WS
## times harder to knock over. hmul makes the row taller, gapMul sparser, xoff staggers it. Returns the row's population.
static func _row(S: SimState, r: SimRng, x0: float, x1: float, kind: String, row: int, hmul: float, gapMul: float, xoff: float) -> float:
	var WS: float = SimConst.WS
	var PS: float = SimConst.PS
	var popK: float = WS / PS
	var pop: float = 0.0
	var x: float = x0 + xoff
	while x < x1:
		var b := SimState.Building.new()
		if kind == "tower":
			var w0: float = r.range_(30.0, 64.0)
			var w: float = w0 * WS
			var cx: float = x + w / 2.0
			var mid: float = 1.0 - absf((cx - 3100.0 * PS) / (760.0 * PS))
			var h1: float = r.range_(120.0, 280.0)
			var h0: float = (h1 + SimMathx.jmax(0.0, mid) * r.range_(80.0, 380.0)) * hmul
			b.x = cx; b.w = w; b.h = h0 * WS; b.maxhp = h0 * 6.0; b.hp = h0 * 6.0; b.alive = true; b.kind = "tower"
			b.pop = SimMathx.jmax(1.0, SimMathx.jround(w0 * h0 / 1200.0 * popK))
			b.seed = r.next()
			b.d = w * 0.8
			x += w + r.range_(4.0, 16.0) * WS * gapMul
		else:
			var w0: float = r.range_(28.0, 50.0)
			var w: float = w0 * WS
			var h0: float = r.range_(36.0, 72.0) * hmul
			if row == 0:
				h0 = minf(h0, FG_H_MAX_BH * BH / WS)   # the foreground is low
			b.x = x + w / 2.0; b.w = w; b.h = h0 * WS; b.maxhp = h0 * 3.0; b.hp = h0 * 3.0; b.alive = true; b.kind = "house"
			b.pop = SimMathx.jmax(1.0, SimMathx.jround(r.range_(2.0, 6.0) * popK))
			b.seed = r.next()
			b.d = w * 0.9
			x += w + r.range_(16.0, 70.0) * WS * gapMul
		b.row = float(row)
		b.z = ROW_Z_BH[row] * BH + ((b.seed - 0.5) * 2.0 * ROW_JITTER_BH * BH if row > 0 else 0.0)
		b.popAlive = b.pop
		pop += b.pop   # a rejected candidate's people still count toward the settlement's total (rescaled onto the rest)
		if _footOk(S, b.x, b.w):
			S.buildings.append(b)
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
	return S.base[int(floor(SimWrap.wrap(x) / SimConst.COL))] < WorldWater.RESERVOIR_BASE
