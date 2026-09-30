class_name GroundField
extends RefCounted
## The ground band's data for the GPU, and its CPU mirror. The sim's ground is one profile across the planet (S.base +
## S.deform at the fighter plane); the band also has depth, where impacts must read as round bowls and beam trails as
## grooves. The band's height at world x and depth z is
##     base(x) + sum over nearby craters of WorldCrater.profile(sqrt(dx^2 + z^2) / r) + furrow(dx, z)
##            + (G(x) - R(x)) * groove(z) + R(x) * heap(z)
## where G(x) = deform(x) - (the same crater sum at z = 0) is the residual: scorch grooves (which have no records),
## dents of records the sim dropped, and clipping. R(x) is the rubble heap (S.rubble, part of S.deform): the sim's heap
## lies on the fighter plane, and in depth it runs as a plateau from there back to the fallen building's far face (row
## 0: forward to its near face), easing off over RenderLook.RUBBLE_EDGE beyond, so a levelled building's rubble fills
## its footprint and the street in front of it. heap(0) = groove(0) = 1, so at z = 0 the formula gives deform(x) back,
## and the mesh row that lies exactly on the fighter plane reads S.deform itself, so the slice the fighters stand on
## is the sim's, bit for bit.
##
## Data (one RF texture, a column per terrain column): row 0 base, 1 deform, 2 G, 3 scorch, 4 water, 5 heat (the
## render-side glow of fresh grooves), 6 to 11 up to K crater indices overlapping the column (-1 for none), 12 and 13
## the far terrain's relief amplitude and base multiplier (static, per biome, smoothed across borders), 14 the
## column's biome (an index into BIOME_ORDER), 15 pavement cracks (S.crack), 16 the half width across the band of any
## knockback-slide trench through the column (from S.slides), 17 the rubble height (S.rubble), 18 and 19 the depth
## range the column's heap spans (from the fallen buildings' z and d), 20 the shore level (the standing level of the
## nearest water within RenderLook.SHORE_COLS, NO_SHORE if none). Each data row of NC values is laid out as RPL texture
## rows of TW texels (TW at most 2,048, WebGL2's guaranteed minimum), so the bytes are the same either way. Crater
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
const ROW_FAR_AMP := ROW_LIST + K
const ROW_FAR_MUL := ROW_FAR_AMP + 1
const ROW_BIOME := ROW_FAR_MUL + 1
const ROW_CRACK := ROW_BIOME + 1
const ROW_TRENCH := ROW_CRACK + 1
const ROW_RUBBLE := ROW_TRENCH + 1
const ROW_RUB_LO := ROW_RUBBLE + 1
const ROW_RUB_HI := ROW_RUB_LO + 1
const ROW_SHORE := ROW_RUB_HI + 1
const ROWS := ROW_SHORE + 1
const NO_SHORE := -1.0e9
const SHORE_CHUNK := 64   # the water is compared in runs of this many columns, to find the few that changed
const TW_MAX := 2048
## Biome index order for the biome row and the shaders' biome_colors array.
const BIOME_ORDER: Array = ["ocean", "plains", "city", "village", "forest", "desert", "mountains"]
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
var _far := PackedFloat32Array()     # rows 12 to 14
var trench := PackedFloat32Array()   # row 16
var rub_lo := PackedFloat32Array()   # rows 18 and 19: the depth range of the heap in each column
var rub_hi := PackedFloat32Array()
var _rubble_seen := PackedFloat32Array()
var shore := PackedFloat32Array()    # row 20: the level of the water at or nearest each column (water.gdshader)
var rpl: int = 1                     # texture rows per data row
var tw: int = 1                      # texture width
var _nsl: int = 0
var _sl_first = null
var _sl_last = null
var _crack_seen := PackedFloat32Array()
var _deform_seen := PackedFloat32Array()
var _scorch_seen := PackedFloat32Array()
var _water_seen := PackedFloat32Array()
var _ncr: int = 0
var _first = null
var _last = null


func _init() -> void:
	var nc: int = SimConst.NC
	rpl = 1
	while nc / rpl > TW_MAX or nc % rpl != 0:
		rpl += 1
	tw = nc / rpl
	trench.resize(nc)
	rub_lo.resize(nc)
	rub_hi.resize(nc)
	shore.resize(nc)
	g.resize(nc)
	lists.resize(nc * K)
	dirty.resize(nc)
	_heat.resize(nc)
	cdata.resize(LIST_W * 2 * 4)
	_far = far_rows()
	img = Image.create_empty(tw, ROWS * rpl, false, Image.FORMAT_RF)
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
	trench.fill(0.0)
	for sl in S.slides:
		_add_slide(sl)
	_nsl = S.slides.size()
	_sl_first = S.slides[0] if _nsl > 0 else null
	_sl_last = S.slides[_nsl - 1] if _nsl > 0 else null
	_rubble_depths(S)
	_shore_levels(S)
	_deform_seen = S.deform.duplicate()
	_scorch_seen = S.scorch.duplicate()
	_water_seen = S.water.duplicate()
	_crack_seen = S.crack.duplicate()
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
	var ns: int = S.slides.size()
	if ns != _nsl or (ns > 0 and (S.slides[0] != _sl_first or S.slides[ns - 1] != _sl_last)):
		if ns > _nsl and (_nsl == 0 or S.slides[0] == _sl_first):
			for k in range(_nsl, ns):
				_add_slide(S.slides[k])
			_nsl = ns
			_sl_first = S.slides[0]
			_sl_last = S.slides[ns - 1]
			cchg = true
		else:
			_heat = heat
			rebuild(S)
			return true
	if S.rubble != _rubble_seen:
		_rubble_depths(S)
		cchg = true
	var moved := PackedInt32Array()   # columns whose ground or water changed, for the shore levels
	if cchg or S.deform != _deform_seen:
		var nc: int = SimConst.NC
		for i in range(nc):
			if dirty[i] == 1 or S.deform[i] != _deform_seen[i]:
				dirty[i] = 1
				_g_col(S, i)
				moved.append(i)
		_deform_seen = S.deform.duplicate()
		shape = true
		any_dirty = true
	var other: bool = S.scorch != _scorch_seen or S.water != _water_seen or S.crack != _crack_seen
	if S.water != _water_seen:
		var nc2: int = SimConst.NC
		for c0 in range(0, nc2, SHORE_CHUNK):
			var c1: int = mini(c0 + SHORE_CHUNK, nc2)
			if S.water.slice(c0, c1) != _water_seen.slice(c0, c1):
				for i in range(c0, c1):
					if S.water[i] != _water_seen[i]:
						moved.append(i)
	if not moved.is_empty():
		_shore_near(S, moved)
	if other:
		_scorch_seen = S.scorch.duplicate()
		_water_seen = S.water.duplicate()
		_crack_seen = S.crack.duplicate()
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
	var w: float = groove_half(S.scorch[i], trench[i])
	var t: float = clampf(1.0 - z * z / (w * w), 0.0, 1.0)
	var r: float = S.rubble[i] if i < S.rubble.size() else 0.0
	return s + (g[i] - r) * t * t + r * heap(z, rub_lo[i], rub_hi[i])


## The heap's share in depth (1 on its range, easing to 0 over RenderLook.RUBBLE_EDGE beyond): the CPU twin of
## heap_at() in render/shaders/ground.gdshaderinc.
static func heap(z: float, lo: float, hi: float) -> float:
	var out: float = maxf(lo - z, z - hi)
	if out <= 0.0:
		return 1.0
	var u: float = clampf(out / RenderLook.RUBBLE_EDGE, 0.0, 1.0)
	return 1.0 - u * u * (3.0 - 2.0 * u)


## Each column's shore level: the standing level (ground plus water) of the water in it, or else of the nearest wet
## column within RenderLook.SHORE_COLS either side (the nearer; the higher on a tie), or NO_SHORE. The water shader
## keeps a land vertex beside water at that level when the land stands above it, so the sheet stays flat and the
## shoreline is where the land rises through it. Two sweeps, run only when the water or the ground changed.
func _shore_levels(S: SimState) -> void:
	var nc: int = SimConst.NC
	var k: int = RenderLook.SHORE_COLS
	var dist := PackedInt32Array()
	dist.resize(nc)
	dist.fill(k + 1)
	shore.fill(NO_SHORE)
	for dir in [1, -1]:
		var lv: float = NO_SHORE
		var d: int = k + 1
		for n in range(-k, nc):
			var i: int = posmod(n if dir == 1 else nc - 1 - n, nc)
			if S.water[i] >= WorldWater.MIN_DEPTH:
				lv = S.base[i] + S.deform[i] + S.water[i]
				d = 0
			else:
				d += 1
			if d <= k and n >= 0 and (d < dist[i] or (d == dist[i] and lv > shore[i])):
				dist[i] = d
				shore[i] = lv


## The shore levels again within RenderLook.SHORE_COLS of the columns whose ground or water changed (the same answer
## as _shore_levels, for the few columns a tick touches).
func _shore_near(S: SimState, moved: PackedInt32Array) -> void:
	var nc: int = SimConst.NC
	var k: int = RenderLook.SHORE_COLS
	var todo := PackedByteArray()
	todo.resize(nc)
	var list := PackedInt32Array()
	for c in moved:
		for d in range(-k, k + 1):
			var i: int = posmod(c + d, nc)
			if todo[i] == 0:
				todo[i] = 1
				list.append(i)
	for i in list:
		shore[i] = _shore_at(S, i)


func _shore_at(S: SimState, i: int) -> float:
	var nc: int = SimConst.NC
	var m: float = WorldWater.MIN_DEPTH
	if S.water[i] >= m:
		return S.base[i] + S.deform[i] + S.water[i]
	for d in range(1, RenderLook.SHORE_COLS + 1):
		var a: int = posmod(i + d, nc)
		var b: int = posmod(i - d, nc)
		var la: float = S.base[a] + S.deform[a] + S.water[a] if S.water[a] >= m else NO_SHORE
		var lb: float = S.base[b] + S.deform[b] + S.water[b] if S.water[b] >= m else NO_SHORE
		if la > NO_SHORE or lb > NO_SHORE:
			return maxf(la, lb)
	return NO_SHORE


## The depth range each column's heap spans: from the fighter plane (where the sim puts it) back to the far face of
## the fallen building it came from (row 0: forward to its near face). Columns with no fallen building over them keep
## [0, 0] (the heap is only the plane's ridge).
func _rubble_depths(S: SimState) -> void:
	rub_lo.fill(0.0)
	rub_hi.fill(0.0)
	_rubble_seen = S.rubble.duplicate()
	var nc: int = SimConst.NC
	for b in S.buildings:
		if b.alive:
			continue
		var half: float = WorldStructures.RUBBLE_SPILL * b.w
		var c0: int = int(floor((b.x - half) / SimConst.COL))
		var c1: int = int(ceil((b.x + half) / SimConst.COL))
		for c in range(c0, c1 + 1):
			var i: int = posmod(c, nc)
			if S.rubble[i] <= 0.0:
				continue
			rub_lo[i] = minf(rub_lo[i], b.z - b.d * 0.5)
			rub_hi[i] = maxf(rub_hi[i], b.z + b.d * 0.5)
			dirty[i] = 1


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


## Half width across the band of the residual at a column: a slide trench is as wide across as its record says; a
## beam groove as wide across as the sim made it along (its half width grows with the beam power P, which the burn
## intensity encodes: WorldCrater.scorch); anything else spreads RenderLook.GROUND_SPREAD.
static func groove_half(scorch: float, trench_hw: float = 0.0) -> float:
	var w: float = 0.0
	if scorch > 0.01:
		var P: float = clampf((scorch - WorldCrater.SCORCH_INT0) / WorldCrater.SCORCH_INT_P, P_MIN, P_MAX)
		w = WorldCrater.SCORCH_HW0 + WorldCrater.SCORCH_HW_P * P
	if trench_hw > 0.0:
		return maxf(w, trench_hw)
	return w if w > 0.0 else RenderLook.GROUND_SPREAD


## A slide's trench width over the columns it crossed (and a trench's width beyond each end).
func _add_slide(sl) -> void:
	var nc: int = SimConst.NC
	var a: float = minf(sl.x0, sl.x0 + SimWrap.sdx(sl.x0, sl.x1)) - sl.hw
	var b: float = maxf(sl.x0, sl.x0 + SimWrap.sdx(sl.x0, sl.x1)) + sl.hw
	var c0: int = int(floor(a / SimConst.COL))
	var c1: int = int(ceil(b / SimConst.COL))
	for c in range(c0, c1 + 1):
		var i: int = posmod(c, nc)
		if sl.hw > trench[i]:
			trench[i] = sl.hw
		dirty[i] = 1


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
	var bytes: PackedByteArray = S.base.to_byte_array() + S.deform.to_byte_array() + g.to_byte_array() + S.scorch.to_byte_array() + S.water.to_byte_array() + _heat.to_byte_array() + lists.to_byte_array() + _far.to_byte_array() + S.crack.to_byte_array() + trench.to_byte_array() + S.rubble.to_byte_array() + rub_lo.to_byte_array() + rub_hi.to_byte_array() + shore.to_byte_array()
	img.set_data(tw, ROWS * rpl, false, Image.FORMAT_RF, bytes)
	tex.update(img)
	if craters_changed:
		cimg.set_data(LIST_W, 2, false, Image.FORMAT_RGBAF, cdata.to_byte_array())
		ctex.update(cimg)


## The far terrain's per-column relief amplitude and base multiplier (RenderLook.FAR_RELIEF by biome), box-smoothed
## over RenderLook.FAR_SMOOTH_COLS each side so biome borders don't step, then each column's biome index. Three rows
## of NC: amplitude, multiplier, biome.
static func far_rows() -> PackedFloat32Array:
	var nc: int = SimConst.NC
	var raw := PackedFloat32Array()
	raw.resize(nc * 2)
	var biome := PackedFloat32Array()
	biome.resize(nc)
	for i in range(nc):
		var b: String = WorldBiomes.biomeAt(float(i) * SimConst.COL + SimConst.COL * 0.5)
		var r: Array = RenderLook.FAR_RELIEF[b]
		raw[i] = r[1] * (RenderLook.MS if b == "mountains" else RenderLook.WS)
		raw[nc + i] = r[0]
		biome[i] = float(BIOME_ORDER.find(b))
	var out := PackedFloat32Array()
	out.resize(nc * 2)
	var m: int = RenderLook.FAR_SMOOTH_COLS
	for row in range(2):
		for i in range(nc):
			var s: float = 0.0
			for k in range(-m, m + 1):
				s += raw[row * nc + (i + k + nc) % nc]
			out[row * nc + i] = s / float(2 * m + 1)
	return out + biome


## The bytes the GPU holds for one data row (for tests).
func row_bytes(row: int) -> PackedByteArray:
	var d: PackedByteArray = img.get_data()
	var w: int = SimConst.NC * 4
	return d.slice(row * w, (row + 1) * w)
