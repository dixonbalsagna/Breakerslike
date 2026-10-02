"""Slice T (terrain rows) applied to an export of HEAD: python t_rows.py <root>"""
import sys
R = sys.argv[1].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = s.replace('\r\n', '\n')
    s = fn(s)
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, old, new, n=1):
    assert s.count(old) >= 1, old[:90]
    return s.replace(old, new, n)


# ------------------------------------------------------------------ state.gd
def state(s):
    return rep(s, "var rubble := PackedFloat32Array()    # rubble heap height",
               "var deformZ: Array = []               # T: the depth rows' deform (a PackedFloat32Array each; the plane row's slot is an empty placeholder: S.deform is the plane row), only when depthOn\n"
               "var rubbleZ: Array = []               # T: the same for the rubble heaps\n"
               "var low := PackedFloat32Array()       # T: the lowest deform across the rows at each column (derived, not hashed): the ground water runs on when depthOn\n"
               "var rubble := PackedFloat32Array()    # rubble heap height")


rw('sim/core/state.gd', state)


# ------------------------------------------------------------------ sim.gd
def sim(s):
    return rep(s, "	S.depthOn = setup.get(\"depth\", false) == true   # fight lanes: off until the director's switch-on (L4); a setup may force it for probes\n",
               "	S.depthOn = setup.get(\"depth\", false) == true   # fight lanes: off until the director's switch-on (L4); a setup may force it for probes\n"
               "	WorldTerrain.initRows(S)   # T: the depth rows exist only when depth is on\n")


rw('sim/core/sim.gd', sim)


# ------------------------------------------------------------------ hash.gd
def hsh(s):
    return rep(s, "	for i in range(S.deform.size()):\n		out.append(S.deform[i])\n",
               "	for i in range(S.deform.size()):\n		out.append(S.deform[i])\n"
               "	if S.depthOn:   # T: the depth rows (their non-zero columns), only when depth is on, so a match without depth hashes as before\n"
               "		for arrs in [S.deformZ, S.rubbleZ]:\n"
               "			for k in range(arrs.size()):\n"
               "				var row: PackedFloat32Array = arrs[k]\n"
               "				var nzr: Array = []\n"
               "				for i in range(row.size()):\n"
               "					if row[i] != 0.0:\n"
               "						nzr.append(i)\n"
               "				out.append(float(nzr.size()))\n"
               "				for i in nzr:\n"
               "					out.append(float(i)); out.append(row[i])\n")


rw('sim/core/hash.gd', hsh)


# ------------------------------------------------------------------ terrain.gd
def terrain(s):
    s = rep(s, "## Ground height at any x: linear between column samples of the generated base plus crater deformation.\nstatic func groundY(S: SimState, x: float) -> float:\n",
            '''# ---------------------------------------------------------------------------------------------- depth rows (slice T)
## Eight rows of 300 units across the fight band, at z = +300, 0, -300 ... -1,800 (z positive toward the camera). Row PLANE_ROW (z = 0) is
## S.deform and S.rubble themselves, so everything that reads them is unchanged; the other seven live in S.deformZ and S.rubbleZ. They
## exist only when S.depthOn (docs/world/fight-lanes-world.md section 10): with it off nothing here runs and the ground is the old model's.
## A writer works on one row at a time by swapping that row's arrays into S.deform and S.rubble for the length of its write
## (enterRow/leaveRow), so the existing writers, their relaxation and their footing rules run unchanged on the row.
const ROWS: int = 8
const PLANE_ROW: int = 1
const ROW_Z0: float = 300.0
const ROW_STEP: float = -300.0
static var rowZ: float = NAN        # z of the row swapped into S.deform right now; NAN outside a writer
static var _swapK: int = -1         # the row swapped in (-1: none, or the plane row)


static func rowZOf(k: int) -> float:
	return ROW_Z0 + ROW_STEP * float(k)


## The row nearest to depth z (clamped to the band's rows).
static func rowOfZ(z: float) -> int:
	return clampi(int(round((z - ROW_Z0) / ROW_STEP)), 0, ROWS - 1)


static func initRows(S: SimState) -> void:
	S.deformZ = []
	S.rubbleZ = []
	S.low = PackedFloat32Array()
	rowZ = NAN
	_swapK = -1
	if not S.depthOn:
		return
	var NC: int = SimConst.NC
	for k in range(ROWS):
		var d := PackedFloat32Array()
		var r := PackedFloat32Array()
		if k != PLANE_ROW:
			d.resize(NC)
			d.fill(0.0)
			r.resize(NC)
			r.fill(0.0)
		S.deformZ.append(d)
		S.rubbleZ.append(r)
	S.low = S.deform.duplicate()


## The deform array of row k, wherever it is held right now.
static func rowArr(S: SimState, k: int) -> PackedFloat32Array:
	if _swapK >= 0:
		if k == _swapK:
			return S.deform
		if k == PLANE_ROW:
			return S.deformZ[_swapK]
	elif k == PLANE_ROW:
		return S.deform
	return S.deformZ[k]


static func rubArr(S: SimState, k: int) -> PackedFloat32Array:
	if _swapK >= 0:
		if k == _swapK:
			return S.rubble
		if k == PLANE_ROW:
			return S.rubbleZ[_swapK]
	elif k == PLANE_ROW:
		return S.rubble
	return S.rubbleZ[k]


## Swap row k's arrays into S.deform and S.rubble; returns k, or -1 when depth is off, or -2 when a writer already holds a row.
static func enterRow(S: SimState, k: int) -> int:
	if not S.depthOn or S.deformZ.is_empty():
		return -1
	if not is_nan(rowZ):
		return -2
	rowZ = rowZOf(k)
	if k != PLANE_ROW:
		var t: PackedFloat32Array = S.deform
		S.deform = S.deformZ[k]
		S.deformZ[k] = t
		var u: PackedFloat32Array = S.rubble
		S.rubble = S.rubbleZ[k]
		S.rubbleZ[k] = u
		_swapK = k
	return k


static func leaveRow(S: SimState, k: int) -> void:
	if k < 0:
		return
	if k != PLANE_ROW:
		var t: PackedFloat32Array = S.deform
		S.deform = S.deformZ[k]
		S.deformZ[k] = t
		var u: PackedFloat32Array = S.rubble
		S.rubble = S.rubbleZ[k]
		S.rubbleZ[k] = u
	_swapK = -1
	rowZ = NAN


## Recompute the lowest deform across the rows for the columns c0 - half .. c0 + half (every writer calls this after a write).
static func lowRefresh(S: SimState, c0: int, half: int) -> void:
	if not S.depthOn or S.low.size() != SimConst.NC:
		return
	var NC: int = SimConst.NC
	var arrs: Array = [S.deform]
	for a in S.deformZ:
		if a.size() == NC:
			arrs.append(a)
	var cnt: int = mini(2 * half + 1, NC)
	var lo: int = c0 - half
	for q in range(cnt):
		var i: int = posmod(lo + q, NC)
		var m: float = 1.0e9
		for a in arrs:
			m = minf(m, a[i])
		S.low[i] = m


## The ground water runs on: the lowest ground across the rows when depth is on, the one row otherwise.
static func lowD(S: SimState) -> PackedFloat32Array:
	return S.low if S.depthOn and S.low.size() == SimConst.NC else S.deform


## Ground height at x on the plane row, or at depth z (the two nearest rows blended, the edge rows holding beyond the band) when
## depth is on; with depth off z is ignored and the ground is the old model's.
static func groundY(S: SimState, x: float, z: float = 0.0) -> float:
	if z != 0.0 and S.depthOn and not S.deformZ.is_empty():
		return _groundZ(S, x, z)
''')
    s = rep(s, "	var a: float = S.base[i] + S.deform[i]\n	var b: float = S.base[j] + S.deform[j]\n	return a + (b - a) * f\n",
            '''	var a: float = S.base[i] + S.deform[i]
	var b: float = S.base[j] + S.deform[j]
	return a + (b - a) * f


static func _groundZ(S: SimState, x: float, z: float) -> float:
	var t: float = clampf((z - ROW_Z0) / ROW_STEP, 0.0, float(ROWS - 1))
	var k0: int = int(floor(t))
	var fz: float = t - float(k0)
	var k1: int = mini(k0 + 1, ROWS - 1)
	var c: float = SimWrap.wrap(x) / SimConst.COL
	var fi: float = floor(c)
	var f: float = c - fi
	var i: int = int(fi)
	var j: int = (i + 1) % SimConst.NC
	var a0: PackedFloat32Array = rowArr(S, k0)
	var g0: float = (S.base[i] + a0[i]) + ((S.base[j] + a0[j]) - (S.base[i] + a0[i])) * f
	if fz == 0.0 or k1 == k0:
		return g0
	var a1: PackedFloat32Array = rowArr(S, k1)
	var g1: float = (S.base[i] + a1[i]) + ((S.base[j] + a1[j]) - (S.base[i] + a1[i])) * f
	return g0 + (g1 - g0) * fz
''')
    return s


rw('sim/world/terrain.gd', terrain)


# ------------------------------------------------------------------ water.gd
def water(s):
    s = rep(s, "	return S.base[i] + S.deform[i] + d if d >= MIN_DEPTH else DRY", "	return S.base[i] + WorldTerrain.lowD(S)[i] + d if d >= MIN_DEPTH else DRY")
    s = rep(s, "			S.water[i] = maxf(0.0, SEA_LEVEL - (S.base[i] + S.deform[i]))", "			S.water[i] = maxf(0.0, SEA_LEVEL - (S.base[i] + WorldTerrain.lowD(S)[i]))")
    s = rep(s, "				var g: float = S.base[i2] + S.deform[i2]", "				var g: float = S.base[i2] + WorldTerrain.lowD(S)[i2]")
    s = rep(s, "	var dfm: PackedFloat32Array = S.deform\n", "	var dfm: PackedFloat32Array = WorldTerrain.lowD(S)\n", 2)
    s = rep(s, "	var NC: int = SimConst.NC\n	var base: PackedFloat32Array = S.base\n	var dfm: PackedFloat32Array = WorldTerrain.lowD(S)\n	for k in range(-cols, cols + 1):",
            "	var NC: int = SimConst.NC\n	var base: PackedFloat32Array = S.base\n	var dfm: PackedFloat32Array = WorldTerrain.lowD(S)\n	if S.depthOn:   # the lowest ground over all the rows, in the window\n		for k in range(-cols, cols + 1):\n			var ic: int = (c0 + k + NC) % NC\n			minG = minf(minG, base[ic] + dfm[ic])\n	for k in range(-cols, cols + 1):")
    return s


rw('sim/world/water.gd', water)


# ------------------------------------------------------------------ crater.gd
def crater(s):
    # dig: wrapper + neighbours
    s = rep(s, "static func dig(S: SimState, x: float, energy: float, cause, kind: String, dirx: float = 0.0, vert: float = 1.0, special: bool = false):\n	if energy <= 0.0:\n		return null\n",
            '''static func dig(S: SimState, x: float, energy: float, cause, kind: String, dirx: float = 0.0, vert: float = 1.0, special: bool = false, z: float = NAN):
	if not S.depthOn:
		return _dig(S, x, energy, cause, kind, dirx, vert, special)
	var zz: float = z
	if is_nan(zz):
		zz = float(cause.z) if (cause != null and "z" in cause) else 0.0
	var k: int = WorldTerrain.enterRow(S, WorldTerrain.rowOfZ(zz))
	var rec = _dig(S, x, energy, cause, kind, dirx, vert, special)
	WorldTerrain.leaveRow(S, k)
	if rec != null and k >= 0:
		_digNeighbours(S, rec, k)
	return rec


## The bowl on the other rows inside its plan radius: the same bowl and rim, the distance taken in plan (so a row 300 units from the
## centre sees a shallower, narrower slice), written row by row with the same footing rule and relaxation.
static func _digNeighbours(S: SimState, rec, kc: int) -> void:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var R: float = rec.r
	var reach: float = R * (1.0 + RIM_OUT)
	var c0: int = _col(rec.x)
	for k in range(WorldTerrain.ROWS):
		if k == kc:
			continue
		var dz: float = absf(WorldTerrain.rowZOf(k) - WorldTerrain.rowZOf(kc))
		if dz >= reach:
			continue
		var half: float = sqrt(reach * reach - dz * dz)
		var n: int = int(ceil(half / COL)) + 1
		var kk: int = WorldTerrain.enterRow(S, k)
		if kk < 0:
			continue
		var pinD: PackedByteArray = WorldStructures.pinned(S, c0, n)
		var minG: float = 1e9
		for q in range(-n, n + 1):
			var i: int = (c0 + q + NC) % NC
			var dxq: float = SimWrap.sdx(rec.x, float(i) * COL)
			var u: float = sqrt(dxq * dxq + dz * dz) / R
			var old: float = S.deform[i]
			var h: float = profile(u, rec.depth, rec.rim)
			if h > 0.0 and pinD[q + n] == 1:
				h = 0.0
			var v: float = maxf(old, h) if (h > 0.0 and old > 0.0) else old + h
			var nv: float = clampf(v, DEFORM_FLOOR, DEFORM_CEIL)
			if nv < old and S.rubble[i] > 0.0:
				S.rubble[i] = maxf(0.0, S.rubble[i] - (old - nv))
			S.deform[i] = nv
			minG = minf(minG, S.base[i] + S.deform[i])
		minG = minf(minG, relax(S, c0, n + REPOSE_PAD))
		WorldTerrain.lowRefresh(S, c0, n + REPOSE_PAD)
		WorldTerrain.leaveRow(S, kk)
		WorldWater.touched(S, c0, n + REPOSE_PAD, minG)


static func _dig(S: SimState, x: float, energy: float, cause, kind: String, dirx: float = 0.0, vert: float = 1.0, special: bool = false):
	if energy <= 0.0:
		return null
''')
    s = rep(s, "	var cols: int = n + int(ceil(absf(skid) / COL)) + REPOSE_PAD\n	minG = minf(minG, relax(S, c0, cols))\n	WorldWater.touched(S, c0, cols, minG)\n	return rec",
            "	var cols: int = n + int(ceil(absf(skid) / COL)) + REPOSE_PAD\n	minG = minf(minG, relax(S, c0, cols))\n	WorldTerrain.lowRefresh(S, c0, cols)\n	WorldWater.touched(S, c0, cols, minG)\n	return rec")
    # scorch
    s = rep(s, "static func scorch(S: SimState, x: float, P: float, variant: String, cause) -> void:\n",
            '''static func scorch(S: SimState, x: float, P: float, variant: String, cause, z: float = NAN) -> void:
	if not S.depthOn:
		_scorch(S, x, P, variant, cause)
		return
	var zz: float = z
	if is_nan(zz):
		zz = float(cause.z) if (cause != null and "z" in cause) else 0.0
	var k: int = WorldTerrain.enterRow(S, WorldTerrain.rowOfZ(zz))
	_scorch(S, x, P, variant, cause)
	WorldTerrain.leaveRow(S, k)


static func _scorch(S: SimState, x: float, P: float, variant: String, cause) -> void:
''')
    s = rep(s, "	if carved:\n		minG = minf(minG, relax(S, c0, n + REPOSE_PAD))\n	WorldWater.touched(S, c0, n + REPOSE_PAD, minG)",
            "	if carved:\n		minG = minf(minG, relax(S, c0, n + REPOSE_PAD))\n	WorldTerrain.lowRefresh(S, c0, n + REPOSE_PAD)\n	WorldWater.touched(S, c0, n + REPOSE_PAD, minG)")
    # carveSegment
    s = rep(s, "static func carveSegment(S: SimState, xa: float, xb: float, depth: float, paved: bool, crack: float) -> void:\n",
            '''static func carveSegment(S: SimState, xa: float, xb: float, depth: float, paved: bool, crack: float, z: float = 0.0) -> void:
	if not S.depthOn:
		_carveSegment(S, xa, xb, depth, paved, crack)
		return
	var k: int = WorldTerrain.enterRow(S, WorldTerrain.rowOfZ(z))
	_carveSegment(S, xa, xb, depth, paved, crack)
	WorldTerrain.leaveRow(S, k)


static func _carveSegment(S: SimState, xa: float, xb: float, depth: float, paved: bool, crack: float) -> void:
''')
    s = rep(s, "	if carved:\n		minG = minf(minG, relax(S, mid, half, cb, dir))\n	WorldWater.touched(S, mid, half, minG)",
            "	if carved:\n		minG = minf(minG, relax(S, mid, half, cb, dir))\n	WorldTerrain.lowRefresh(S, mid, half)\n	WorldWater.touched(S, mid, half, minG)")
    # berm
    s = rep(s, "static func berm(S: SimState, x: float, vx: float, hw: float, h: float) -> void:\n",
            '''static func berm(S: SimState, x: float, vx: float, hw: float, h: float, z: float = 0.0) -> void:
	if not S.depthOn:
		_berm(S, x, vx, hw, h)
		return
	var k: int = WorldTerrain.enterRow(S, WorldTerrain.rowOfZ(z))
	_berm(S, x, vx, hw, h)
	WorldTerrain.lowRefresh(S, _col(x), 4)
	WorldTerrain.leaveRow(S, k)


static func _berm(S: SimState, x: float, vx: float, hw: float, h: float) -> void:
''')
    return s


rw('sim/world/crater.gd', crater)


# ------------------------------------------------------------------ structures.gd
def structures(s):
    s = rep(s, "static func baseY(S: SimState, b) -> float:\n	var NC: int = SimConst.NC\n	var COL: float = SimConst.COL\n",
            '''static func baseY(S: SimState, b) -> float:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	if S.depthOn and not S.deformZ.is_empty():   # T: the highest ground over the footprint in x and in depth (the rows inside its interval)
		var m2: float = -1.0e9
		var ca: int = int(floor((b.x - b.w * 0.5) / COL))
		var cb: int = int(floor((b.x + b.w * 0.5) / COL)) + 1
		var any: bool = false
		for k in range(WorldTerrain.ROWS):
			var zk: float = WorldTerrain.rowZOf(k)
			if zk > b.z - b.d * 0.5 - 0.001 and zk < b.z + b.d * 0.5 + 0.001:
				any = true
				var ar: PackedFloat32Array = WorldTerrain.rowArr(S, k)
				for c in range(ca, cb + 1):
					var ic: int = posmod(c, NC)
					m2 = maxf(m2, S.base[ic] + ar[ic])
		if any:
			return m2
		var ar2: PackedFloat32Array = WorldTerrain.rowArr(S, WorldTerrain.rowOfZ(b.z))
		for c in range(ca, cb + 1):
			var ic2: int = posmod(c, NC)
			m2 = maxf(m2, S.base[ic2] + ar2[ic2])
		return m2
''')
    # pinned: row z filter
    s = rep(s, "		var b = S.buildings[bi]\n		if not b.alive:\n			continue\n		var k0: int = int(floor((b.x - b.w * 0.5) / COL)) - 1",
            "		var b = S.buildings[bi]\n		if not b.alive:\n			continue\n		if not is_nan(WorldTerrain.rowZ) and (WorldTerrain.rowZ < b.z - b.d * 0.5 - 0.001 or WorldTerrain.rowZ > b.z + b.d * 0.5 + 0.001):\n			continue   # T: a building is a footing only for the rows inside its depth interval\n		var k0: int = int(floor((b.x - b.w * 0.5) / COL)) - 1")
    # heap rows
    s = rep(s, "static func _heap(S: SimState, b) -> float:\n",
            '''static func _heap(S: SimState, b) -> float:
	if not S.depthOn or S.deformZ.is_empty():
		return _heapRow(S, b, false)
	# T: the heap goes on the rows strictly inside the footprint's depth interval (never on a street's row, so a carriageway stays
	# flat), once on each; a footprint with no row inside leaves only the cosmetic heap
	var H: float = 0.0
	for k in range(WorldTerrain.ROWS):
		var zk: float = WorldTerrain.rowZOf(k)
		if zk > b.z - b.d * 0.5 and zk < b.z + b.d * 0.5:
			var kk: int = WorldTerrain.enterRow(S, k)
			H = maxf(H, _heapRow(S, b, true))
			WorldTerrain.leaveRow(S, kk)
	if H <= 0.0:
		H = minf(clampf(RUBBLE_H_FRAC * b.h, RUBBLE_MIN, RUBBLE_MAX), RUBBLE_SLOPE * RUBBLE_SPILL * b.w / RUBBLE_CREST_K)
	return H


static func _heapRow(S: SimState, b, anyRow: bool) -> float:
''')
    s = rep(s, "	if H <= 0.0 or b.row > RUBBLE_ROW_MAX:\n		return maxf(H, 0.0)", "	if H <= 0.0 or (b.row > RUBBLE_ROW_MAX and not anyRow):\n		return maxf(H, 0.0)")
    s = rep(s, "	WorldCrater.relax(S, c0, n + WorldCrater.REPOSE_PAD)\n	return H", "	WorldCrater.relax(S, c0, n + WorldCrater.REPOSE_PAD)\n	WorldTerrain.lowRefresh(S, c0, n + WorldCrater.REPOSE_PAD)\n	return H")
    return s


rw('sim/world/structures.gd', structures)


# ------------------------------------------------------------------ contact.gd (z of the body)
def contact(s):
    s = rep(s, "	var lips: int = 0\n", "	var lips: int = 0\n	var z: float = 0.0            # depth (T: the row the ground is read on when depth is on)\n")
    s = s.replace("WorldTerrain.groundY(S, b.x)", "WorldTerrain.groundY(S, b.x, b.z)")
    s = rep(s, "static func launchBody(x: float, y: float, vx: float, vy: float, launchT: float, tier: float, wet: bool = false) -> Body:", "static func launchBody(x: float, y: float, vx: float, vy: float, launchT: float, tier: float, wet: bool = false, z: float = 0.0) -> Body:")
    s = rep(s, "	b.launchT = launchT\n", "	b.launchT = launchT\n	b.z = z\n")
    s = s.replace("WorldTerrain.groundY(S, x + e) - WorldTerrain.groundY(S, x - e)", "WorldTerrain.groundY(S, x + e, z) - WorldTerrain.groundY(S, x - e, z)")
    s = s.replace("static func _gslope(S: SimState, x: float) -> float:", "static func _gslope(S: SimState, x: float, z: float = 0.0) -> float:")
    s = s.replace("_gslope(S, b.x)", "_gslope(S, b.x, b.z)")
    s = s.replace("WorldTerrain.groundY(S, b.x + dir * SimConst.COL)", "WorldTerrain.groundY(S, b.x + dir * SimConst.COL, b.z)")
    s = s.replace("WorldTerrain.groundY(S, x2)", "WorldTerrain.groundY(S, x2, b.z)")
    s = s.replace("WorldTerrain.groundY(S, xa)", "WorldTerrain.groundY(S, xa, b.z)")
    s = s.replace("	b.x = f.x\n	b.y = f.y\n	b.vx = f.vx\n", "	b.x = f.x\n	b.y = f.y\n	b.z = f.z\n	b.vx = f.vx\n")
    s = s.replace("WorldCrater.carveSegment(S, xa, f.x, depth, pav, WorldSlide.CRACK0 + WorldSlide.CRACK_E * sqrt(E))", "WorldCrater.carveSegment(S, xa, f.x, depth, pav, WorldSlide.CRACK0 + WorldSlide.CRACK_E * sqrt(E), f.z)")
    s = s.replace('WorldCrater.dig(S, f.x, E * WorldSlide.STOP_E, by, "impact", 0.0, 1.0)', 'WorldCrater.dig(S, f.x, E * WorldSlide.STOP_E, by, "impact", 0.0, 1.0, false, f.z)')
    s = s.replace('vert, f.launchSpecial)', 'vert, f.launchSpecial, f.z)')
    s = s.replace("* WorldSlide.BERM)", "* WorldSlide.BERM, f.z)")
    return s


rw('sim/world/contact.gd', contact)
print('slice T applied')
