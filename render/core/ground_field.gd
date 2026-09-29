class_name GroundField
extends RefCounted
## The ground band's data for the GPU, and its CPU mirror. The sim's ground is one profile across the planet (S.base +
## S.deform at the fighter plane); the band also has depth, where impacts must read as round bowls and beam trails as
## grooves. The band's height at world x and depth z is
##     base(x) + sum over nearby craters of WorldCrater.profile(sqrt(dx^2 + z^2) / r) + furrow(dx, z)
##            + G(x) * groove(z)
## where G(x) = deform(x) - (the same crater sum at z = 0) is the residual: scorch grooves (which have no records),
## dents of records the sim dropped, and clipping. At z = 0 the formula gives deform(x) back, and the mesh row that lies
## exactly on the fighter plane reads S.deform itself, so the slice the fighters stand on is the sim's, bit for bit.
##
## Data (one RF texture, a column per terrain column): row 0 base, 1 deform, 2 G, 3 scorch, 4 water, 5 heat (the
## render-side glow of fresh grooves), 6 to 11 up to K crater indices overlapping the column (-1 for none). Crater
## records go to an RGBAF texture, a column per S.craters entry: (x, r, depth, rim) and (skid, sdepth, energy, t).
## Everything is rebuilt from state (S.craters, S.deform, S.scorch, S.water), incrementally when the crater list
## only grew, fully otherwise (a new match, a replay seek, a snapshot restore); events are never needed.
## Reads the sim only; never writes it.

const ROW_BASE := 0
const ROW_DEFORM := 1
const ROW_G := 2
const ROW_SCORCH := 3
const ROW_WATER := 4
const ROW_HEAT := 5
const ROW_LIST := 6
const K := 6                         # craters per column the GPU sums (the most energetic win)
const ROWS := ROW_LIST + K
const LIST_W := 400                  # WorldCrater.LIST_MAX

var img: Image
var tex: ImageTexture
var cimg: Image
var ctex: ImageTexture
var g := PackedFloat32Array()        # residual per column
var lists := PackedFloat32Array()    # K rows of NC: crater index or -1
var cdata := PackedFloat32Array()    # LIST_W x 2 texels x 4
var dirty := PackedByteArray()       # columns whose ground changed since the props last looked
var any_dirty: bool = false
var full_rebuilds: int = 0           # for tests
var _heat := PackedFloat32Array()
var _deform_seen := PackedFloat32Array()
var _scorch_seen := PackedFloat32Array()
var _water_seen := PackedFloat32Array()
var _ncr: int = 0
var _first = null
var _last = null


func _init() -> void:
	var nc: int = SimConst.NC
	g.resize(nc)
	lists.resize(nc * K)
	dirty.resize(nc)
	_heat.resize(nc)
	cdata.resize(LIST_W * 2 * 4)
	img = Image.create_empty(nc, ROWS, false, Image.FORMAT_RF)
	tex = ImageTexture.create_from_image(img)
	cimg = Image.create_empty(LIST_W, 2, false, Image.FORMAT_RGBAF)
	ctex = ImageTexture.create_from_image(cimg)


## Everything from state: a new match, or any change that is not the crater list growing.
func rebuild(S: SimState) -> void:
	full_rebuilds += 1
	lists.fill(-1.0)
	cdata.fill(0.0)
	for idx in range(S.craters.size()):
		_add(S, idx)
	for i in range(SimConst.NC):
		_g_col(S, i)
	dirty.fill(1)
	any_dirty = true
	_ncr = S.craters.size()
	_first = S.craters[0] if _ncr > 0 else null
	_last = S.craters[_ncr - 1] if _ncr > 0 else null
	_deform_seen = S.deform.duplicate()
	_scorch_seen = S.scorch.duplicate()
	_water_seen = S.water.duplicate()
	_upload(S, true)


## Per frame. heat is the render-side glow (ImpactFx); heat_changed says whether it moved. Returns whether the ground
## shape changed (then `dirty` marks the columns, for the props that stand on it).
func update(S: SimState, heat: PackedFloat32Array, heat_changed: bool) -> bool:
	var n: int = S.craters.size()
	var shape: bool = false
	var cchg: bool = false
	if n != _ncr or (n > 0 and (S.craters[0] != _first or S.craters[n - 1] != _last)):
		if n > _ncr and (_ncr == 0 or S.craters[0] == _first):
			for idx in range(_ncr, n):
				_add(S, idx)
			_ncr = n
			_first = S.craters[0]
			_last = S.craters[n - 1]
			cchg = true
		else:
			_heat = heat
			rebuild(S)
			return true
	if cchg or S.deform != _deform_seen:
		var nc: int = SimConst.NC
		for i in range(nc):
			if dirty[i] == 1 or S.deform[i] != _deform_seen[i]:
				dirty[i] = 1
				_g_col(S, i)
		_deform_seen = S.deform.duplicate()
		shape = true
		any_dirty = true
	var other: bool = S.scorch != _scorch_seen or S.water != _water_seen
	if other:
		_scorch_seen = S.scorch.duplicate()
		_water_seen = S.water.duplicate()
	if heat_changed:
		_heat = heat
	if shape or other or heat_changed:
		_upload(S, cchg)
	return shape


## Height offset (added to base) at column i, world x xw and depth z, off the fighter plane: the CPU twin of
## ground_offset() in render/shaders/ground.gdshaderinc.
func offset_at(S: SimState, i: int, xw: float, z: float) -> float:
	var s: float = 0.0
	for k in range(K):
		var ci: int = int(lists[k * SimConst.NC + i])
		if ci < 0:
			break
		var c = S.craters[ci]
		var dx: float = xw - c.x
		dx -= SimConst.W * roundf(dx / SimConst.W)
		s += WorldCrater.profile(sqrt(dx * dx + z * z) / c.r, c.depth, c.rim) + furrow(dx, z, c.r, c.skid, c.sdepth)
	var w: float = groove_half(S.scorch[i])
	var t: float = clampf(1.0 - z * z / (w * w), 0.0, 1.0)
	return s + g[i] * t * t


## Ground height at world x and depth z, as drawn: groundY on the fighter plane, the bowl field elsewhere (linear
## between columns, like the mesh).
func ground_at(S: SimState, x: float, z: float) -> float:
	if z == 0.0:
		return WorldTerrain.groundY(S, x)
	var c: float = SimWrap.wrap(x) / SimConst.COL
	var fi: float = floor(c)
	var i: int = int(fi)
	var j: int = (i + 1) % SimConst.NC
	var a: float = S.base[i] + offset_at(S, i, fi * SimConst.COL, z)
	var b: float = S.base[j] + offset_at(S, j, (fi + 1.0) * SimConst.COL, z)
	return a + (b - a) * (c - fi)


## The furrow of a glancing impact in depth: the sim's skid (a trench from the tail into the bowl, depth sdepth at the
## bowl fading as (1 - s / len)^2), given a width across the band that grows with the crater.
static func furrow(dx: float, z: float, r: float, skid: float, sd: float) -> float:
	if sd <= 0.0 or skid == 0.0 or dx * skid < 0.0:
		return 0.0
	var q: float = 1.0 - absf(dx) / absf(skid)
	if q <= 0.0:
		return 0.0
	var wf: float = maxf(RenderLook.FURROW_W_MIN, RenderLook.FURROW_W_R * r)
	var t: float = clampf(1.0 - z * z / (wf * wf), 0.0, 1.0)
	return -sd * q * q * t * t


## Half width across the band of the residual at a column: a beam groove is as wide across as the sim made it along
## (its half width grows with the beam power P, which the burn intensity encodes: WorldCrater.scorch); anything else
## spreads RenderLook.GROUND_SPREAD.
static func groove_half(scorch: float) -> float:
	if scorch <= 0.01:
		return RenderLook.GROUND_SPREAD
	var P: float = clampf((scorch - WorldCrater.SCORCH_INT0) / WorldCrater.SCORCH_INT_P, P_MIN, P_MAX)
	return WorldCrater.SCORCH_HW0 + WorldCrater.SCORCH_HW_P * P


const P_MIN: float = WorldCrater.BEAM_P_BASE
const P_MAX: float = WorldCrater.BEAM_P_BASE + 100.0 / WorldCrater.BEAM_P_POWER


## Put record idx into the lists of the columns it reaches (bowl, rim, apron and furrow), keeping each column's K most
## energetic craters; and into the crater texture.
func _add(S: SimState, idx: int) -> void:
	var c = S.craters[idx]
	if idx < LIST_W:
		var o: int = idx * 4
		cdata[o] = c.x
		cdata[o + 1] = c.r
		cdata[o + 2] = c.depth
		cdata[o + 3] = c.rim
		o = (LIST_W + idx) * 4
		cdata[o] = c.skid
		cdata[o + 1] = c.sdepth
		cdata[o + 2] = c.energy
		cdata[o + 3] = c.t
	var nc: int = SimConst.NC
	var reach: float = c.r * (1.0 + WorldCrater.RIM_OUT) + absf(c.skid)
	var c0: int = int(floor(c.x / SimConst.COL))
	var n: int = int(ceil(reach / SimConst.COL)) + 1
	for kk in range(-n, n + 1):
		var i: int = (c0 + kk + nc) % nc
		dirty[i] = 1
		var slot: int = -1
		for k in range(K):
			var cur: int = int(lists[k * nc + i])
			if cur < 0 or S.craters[cur].energy < c.energy:
				slot = k
				break
		if slot < 0:
			continue
		for k in range(K - 1, slot, -1):
			lists[k * nc + i] = lists[(k - 1) * nc + i]
		lists[slot * nc + i] = float(idx)


## The residual at column i: the sim's deform minus what the listed craters and furrows give on the fighter plane.
func _g_col(S: SimState, i: int) -> void:
	var xw: float = float(i) * SimConst.COL
	var s: float = 0.0
	for k in range(K):
		var ci: int = int(lists[k * SimConst.NC + i])
		if ci < 0:
			break
		var c = S.craters[ci]
		var dx: float = xw - c.x
		dx -= SimConst.W * roundf(dx / SimConst.W)
		s += WorldCrater.profile(absf(dx) / c.r, c.depth, c.rim) + furrow(dx, 0.0, c.r, c.skid, c.sdepth)
	g[i] = S.deform[i] - s


func _upload(S: SimState, craters_changed: bool) -> void:
	var bytes: PackedByteArray = S.base.to_byte_array() + S.deform.to_byte_array() + g.to_byte_array() + S.scorch.to_byte_array() + S.water.to_byte_array() + _heat.to_byte_array() + lists.to_byte_array()
	img.set_data(SimConst.NC, ROWS, false, Image.FORMAT_RF, bytes)
	tex.update(img)
	if craters_changed:
		cimg.set_data(LIST_W, 2, false, Image.FORMAT_RGBAF, cdata.to_byte_array())
		ctex.update(cimg)


## The bytes the GPU holds for one row (for tests).
func row_bytes(row: int) -> PackedByteArray:
	var d: PackedByteArray = img.get_data()
	var w: int = SimConst.NC * 4
	return d.slice(row * w, (row + 1) * w)
