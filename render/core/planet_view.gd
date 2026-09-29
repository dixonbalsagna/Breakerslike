class_name PlanetView
extends Node3D
## The wrapped planet: the ground and water, one surface from the fighter plane to the horizon (the far part is the
## same planet's terrain, fading into the sky), and the buildings, trees and crowd. Everything anchored to the world is
## built once per match in world x [0, W) and drawn as copies one planet apart, placed at k * W - cam.x: the ground
## and water in 2 * PLANET_COPIES + 1 copies (the horizon is wide), the props in three. The copies are identical, so the seam at x = 0 / W can never pop, at any zoom or separation, and a
## view wider than the planet (tiny zoom on an ultra-wide or phone screen) still shows every object at every place it
## appears. Per-frame cost is three node moves plus whatever changed in the sim since the last frame: the ground field
## (render/core/ground_field.gd: round crater bowls in depth, scorch, water) when craters dig, beams scorch or water
## flows, and the instances of damaged buildings, fallen trees and lost civilians, and of props on changed ground.
## Civilians who flee (World's evacuate events) run off as figures (render/core/crowd_flight.gd) instead of vanishing.
## Reads the sim only; never writes it.

const TERRAIN_SHADER: Shader = preload("res://render/shaders/terrain.gdshader")
const WATER_SHADER: Shader = preload("res://render/shaders/water.gdshader")
const CROWD_SHADER: Shader = preload("res://render/shaders/crowd.gdshader")

var ground := GroundField.new()
var _terrain_meshes: Array = []   # [ArrayMesh]: every chunk of the near and middle tiers, then the far tier
var _water_meshes: Array = []
var _crowd_mat: ShaderMaterial
var _terrain_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _bld: MultiMesh
var _roof: MultiMesh
var _tree: MultiMesh
var _crowd: MultiMesh
var _copies: Array = []
var _bld_seen: Array = []          # per building: [curH, alive, popAlive]
var _tree_seen: Array = []         # per tree: alive
var _tree_z := PackedFloat64Array()
var _crowd_first := PackedInt32Array()
var _crowd_x := PackedFloat64Array()   # world x per person
var _crowd_z := PackedFloat64Array()
var _shown := PackedInt32Array()       # per building: figures standing at home, -1 before the first placement
var flight := CrowdFlight.new()
## Per building, people the evacuation mock has taken out of a building on its own (render/tools/evac_mock.gd, main's
## --mock-evac): the crowd shows popAlive minus these. Empty in the game; goes when World's evacuation lands.
var crowd_extra: Array = []
var _blows: Array = []                 # this frame's blows (x): craters, scorch, building damage
var _startled: Dictionary = {}         # crowd instance -> sim time it calms down (RenderLook.STARTLE_*)
var _calm_at: float = INF              # the earliest of those


## Build the planet for the match in S (after SimCore.newMatch).
func build(S: SimState) -> void:
	for c in _copies:
		remove_child(c)
		c.free()
	_copies.clear()
	if _terrain_meshes.is_empty():
		_make_materials()
		_make_ground_meshes()
		_crowd_mat = ShaderMaterial.new()
		_crowd_mat.shader = CROWD_SHADER
		_crowd_mat.set_shader_parameter("outline_col", RenderLook.col(RenderLook.CROWD_OUTLINE))
		_crowd_mat.set_shader_parameter("skin_a", RenderLook.col(RenderLook.CROWD_SKIN[0]))
		_crowd_mat.set_shader_parameter("skin_b", RenderLook.col(RenderLook.CROWD_SKIN[1]))
		_crowd_mat.set_shader_parameter("legs", RenderLook.col(RenderLook.CROWD_LEGS))
		_crowd_mat.set_shader_parameter("run_hz", RenderLook.RUN_STRIDE_HZ)
		_crowd_mat.set_shader_parameter("leg_swing", RenderLook.RUN_LEG_SWING)
		_crowd_mat.set_shader_parameter("arm_swing", RenderLook.RUN_ARM_SWING)
		_crowd_mat.set_shader_parameter("run_lean", RenderLook.RUN_LEAN)
		_crowd_mat.set_shader_parameter("run_bob", RenderLook.RUN_BOB)
		_crowd_mat.set_shader_parameter("startle_arms", RenderLook.STARTLE_ARMS)
		_crowd_mat.set_shader_parameter("startle_crouch", RenderLook.STARTLE_CROUCH)
		_crowd_mat.set_shader_parameter("startle_tremble", RenderLook.STARTLE_TREMBLE)
	ground.rebuild(S)
	_make_props(S)
	for k in range(-RenderLook.PLANET_COPIES, RenderLook.PLANET_COPIES + 1):
		var n := Node3D.new()
		n.name = "Copy%d" % (k + RenderLook.PLANET_COPIES)
		n.set_meta("k", k)
		add_child(n)
		for m in range(_terrain_meshes.size()):
			_mesh_child(n, "Terrain%d" % m, _terrain_meshes[m], _terrain_mat)
			_mesh_child(n, "Water%d" % m, _water_meshes[m], _water_mat)
		if absi(k) <= 1:
			_mm_child(n, "Buildings", _bld)
			_mm_child(n, "Roofs", _roof)
			_mm_child(n, "Trees", _tree)
			_mm_child(n, "Crowd", _crowd, _crowd_mat)
		_copies.append(n)
	refresh(S, true)


## Per frame: place the copies around the camera's wrapped x and apply whatever changed in the world. heat is the
## render-side glow of fresh grooves (ImpactFx).
func update(S: SimState, cam_x: float, heat: PackedFloat32Array = PackedFloat32Array(), heat_changed: bool = false) -> void:
	for c in _copies:
		c.position.x = float(c.get_meta("k")) * SimConst.W - cam_x
	ground.update(S, heat, heat_changed)
	refresh(S, false)
	flight.step(S, _crowd)
	_startle(S)


## One tick's fx events, as the host drains them: the evacuate events start the flight, and blows startle the crowd.
func consume(events: Array) -> void:
	flight.consume(events)
	for e in events:
		if e.type == "crater" or e.type == "scorch" or e.type == "debris":
			_blows.append(e.x)


## Survivors standing near this frame's blows are startled for STARTLE_S; the calm ones go back to idle. A startled
## figure that starts running takes the flight's colours, and gets idle white again only if it is still home.
func _startle(S: SimState) -> void:
	var R: float = RenderLook.STARTLE_R
	var seen: Dictionary = {}
	for bx in _blows:
		var key: int = int(floor(SimWrap.wrap(bx) / (R * 0.5)))   # a beam's scorch comes in runs of nearby blows
		if seen.has(key):
			continue
		seen[key] = true
		for bi in range(S.buildings.size()):
			var b = S.buildings[bi]
			if absf(SimWrap.sdx(bx, b.x)) > R + b.w + RenderLook.CROWD_SPREAD or _shown[bi] <= 0:
				continue
			for j in range(_shown[bi]):
				var ci: int = _crowd_first[bi] + j
				if absf(SimWrap.sdx(bx, _crowd_x[ci])) < R and not flight.running(ci):
					if not _startled.has(ci):
						_crowd.set_instance_color(ci, Color(0.0, 1.0, 1.0, 1.0))
					_startled[ci] = S.T + RenderLook.STARTLE_S
					_calm_at = minf(_calm_at, S.T + RenderLook.STARTLE_S)
	_blows.clear()
	if S.T < _calm_at:
		return
	var calm: Array = []
	_calm_at = INF
	for ci in _startled:
		if S.T >= _startled[ci]:
			calm.append(ci)
		else:
			_calm_at = minf(_calm_at, _startled[ci])
	for ci in calm:
		_startled.erase(ci)
		if not flight.running(ci):
			_crowd.set_instance_color(ci, Color.WHITE)


## Crowd legibility for this frame: boost scales each figure about its feet; outline is the shell width in units.
func set_crowd_view(boost: float, outline: float) -> void:
	_crowd_mat.set_shader_parameter("boost", boost)
	_crowd_mat.set_shader_parameter("outline", outline)


## The copy nodes, left to right (for tools and tests).
func copies() -> Array:
	return _copies


## The ground meshes: the near tier's chunks first (they hold the fighter-plane row), then the middle chunks and the
## far tier.
func terrain_meshes() -> Array:
	return _terrain_meshes


## How many of terrain_meshes() are finest-run chunks (the ones holding the fighter-plane row).
func near_chunks() -> int:
	return SimConst.NC / RenderLook.CHUNK_COLS


## Props: buildings, roofs, trees and civilians whose state changed, or whose ground did (they stand on the ground as
## drawn at their own depth, so a bowl in depth does not leave them floating).
func refresh(S: SimState, force: bool) -> void:
	var dirty: PackedByteArray = ground.dirty
	var dchg: bool = force or ground.any_dirty
	for bi in range(S.buildings.size()):
		var b = S.buildings[bi]
		var h: float = WorldStructures.curH(b)
		var seen: Array = _bld_seen[bi]
		var moved: bool = dchg and (force or dirty[_col(b.x)] == 1)
		var pa: float = b.popAlive - (float(crowd_extra[bi]) if bi < crowd_extra.size() else 0.0)
		if moved or h != seen[0] or b.alive != seen[1] or pa != seen[2]:
			_set_building(S, bi, b, h, pa, moved or pa != seen[2])
			_bld_seen[bi] = [h, b.alive, pa]
	for ti in range(S.trees.size()):
		var t = S.trees[ti]
		if (dchg and (force or dirty[_col(t.x)] == 1)) or t.alive != _tree_seen[ti]:
			_tree_seen[ti] = t.alive
			if t.alive:
				var g: float = ground.ground_at(S, t.x, _tree_z[ti])
				_tree.set_instance_transform(ti, Transform3D(Basis.from_scale(Vector3(RenderLook.TREE_W, t.h, RenderLook.TREE_W)), Vector3(t.x, g + t.h * 0.5, _tree_z[ti])))
			else:
				_tree.set_instance_transform(ti, _hidden(t.x))
	if dchg:
		ground.dirty.fill(0)
		ground.any_dirty = false


static func _col(x: float) -> int:
	return int(floor(SimWrap.wrap(x) / SimConst.COL))


## pa: the people the building's crowd shows (popAlive, less the mock's own evacuations).
func _set_building(S: SimState, bi: int, b, h: float, pa: float, crowd: bool) -> void:
	var tower: bool = b.kind == "tower"
	var d: float = b.w * (0.8 if tower else 0.9)
	var zc: float = RenderLook.Z_BUILDING_FRONT - d * 0.5
	var g: float = minf(ground.ground_at(S, b.x, zc + d * 0.5), ground.ground_at(S, b.x, zc - d * 0.5))
	_bld.set_instance_transform(bi, Transform3D(Basis.from_scale(Vector3(b.w, h, d)), Vector3(b.x, g + h * 0.5, zc)))
	var c: String
	if tower:
		c = RenderLook.TOWER if b.alive else RenderLook.TOWER_DEAD
	else:
		c = RenderLook.HOUSE if b.alive else RenderLook.HOUSE_DEAD
	_bld.set_instance_color(bi, RenderLook.col(c))
	if not tower and b.alive:
		_roof.set_instance_transform(bi, Transform3D(Basis.from_scale(Vector3(b.w * 1.2, RenderLook.ROOF_H, d * 1.1)), Vector3(b.x, g + h + RenderLook.ROOF_H * 0.5, zc)))
	else:
		_roof.set_instance_transform(bi, _hidden(b.x))
	if crowd:
		var first: int = _crowd_first[bi]
		var n: int = _crowd_first[bi + 1] - first
		var alive: int = clampi(int(pa), 0, n)
		# Figures that just vanished: the fled share runs (the flight), the rest were casualties and go now.
		var gone_now := {}
		if _shown[bi] > alive:
			var slots: Array = range(first + alive, first + _shown[bi])
			for ci in flight.vanish(S, bi, b.x, slots, _crowd_x, _crowd_z, b.pop - pa, n - alive, ground):
				gone_now[ci] = true
		_shown[bi] = alive
		for j in range(n):
			var ci: int = first + j
			var x: float = _crowd_x[ci]
			if j < alive:
				_crowd.set_instance_transform(ci, Transform3D(Basis.from_scale(Vector3.ONE * RenderLook.CROWD_SCALE), Vector3(x, ground.ground_at(S, x, _crowd_z[ci]), _crowd_z[ci])))
			elif gone_now.has(ci) or not flight.running(ci):
				_crowd.set_instance_transform(ci, _hidden(x))


static func _hidden(x: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(x, 0.0, 0.0))


func _mesh_child(parent: Node3D, n: String, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _mm_child(parent: Node3D, n: String, mm: MultiMesh, mat: Material = null) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.multimesh = mm
	mi.material_override = mat if mat != null else RenderMats.flat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _make_materials() -> void:
	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = TERRAIN_SHADER
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	for m in [_terrain_mat, _water_mat]:
		m.set_shader_parameter("heights", ground.tex)
		m.set_shader_parameter("craters", ground.ctex)
		m.set_shader_parameter("nc", SimConst.NC)
		m.set_shader_parameter("tw", ground.tw)
		m.set_shader_parameter("rpl", ground.rpl)
		m.set_shader_parameter("far_scale", RenderLook.WS)
		m.set_shader_parameter("sea_base", WorldWater.RESERVOIR_BASE)
		m.set_shader_parameter("wet_min", WorldWater.MIN_DEPTH)
		m.set_shader_parameter("dent_min", 6.0 * RenderLook.WS)
		m.set_shader_parameter("col_w", SimConst.COL)
		m.set_shader_parameter("world_w", SimConst.W)
		m.set_shader_parameter("rim_in", WorldCrater.RIM_IN)
		m.set_shader_parameter("rim_out", WorldCrater.RIM_OUT)
		m.set_shader_parameter("groove_w0", WorldCrater.SCORCH_HW0)
		m.set_shader_parameter("groove_wp", WorldCrater.SCORCH_HW_P)
		m.set_shader_parameter("groove_i0", WorldCrater.SCORCH_INT0)
		m.set_shader_parameter("groove_ip", WorldCrater.SCORCH_INT_P)
		m.set_shader_parameter("groove_pmin", GroundField.P_MIN)
		m.set_shader_parameter("groove_pmax", GroundField.P_MAX)
		m.set_shader_parameter("spread_w", RenderLook.GROUND_SPREAD)
		m.set_shader_parameter("furrow_wr", RenderLook.FURROW_W_R)
		m.set_shader_parameter("furrow_wmin", RenderLook.FURROW_W_MIN)
		m.set_shader_parameter("z_band_back", RenderLook.Z_TERRAIN_BACK)
		m.set_shader_parameter("far_blend", RenderLook.FAR_BLEND)
		m.set_shader_parameter("meander_amp", RenderLook.MEANDER)
		m.set_shader_parameter("biome_colors", GroundField.BIOME_ORDER.map(func(b): return RenderLook.col(RenderLook.BIOME[b])))
		m.set_shader_parameter("fog_near", RenderLook.FOG_NEAR)
		m.set_shader_parameter("fog_far", RenderLook.FOG_FAR)
		m.set_shader_parameter("fore_drop", RenderLook.FORE_DROP)
		RenderMats.track(m)
	_terrain_mat.set_shader_parameter("sea_floor", RenderLook.col(RenderLook.SEA_FLOOR))
	_terrain_mat.set_shader_parameter("crater", RenderLook.col(RenderLook.CRATER))
	_terrain_mat.set_shader_parameter("crater_desert", RenderLook.col(RenderLook.CRATER_DESERT))
	_terrain_mat.set_shader_parameter("ejecta", RenderLook.col(RenderLook.EJECTA))
	_terrain_mat.set_shader_parameter("char_col", RenderLook.col(RenderLook.CHAR))
	_terrain_mat.set_shader_parameter("heat_lo", RenderLook.col(RenderLook.HEAT_LO))
	_terrain_mat.set_shader_parameter("heat_hi", RenderLook.col(RenderLook.HEAT_HI))
	_terrain_mat.set_shader_parameter("z_front", RenderLook.Z_TERRAIN_FRONT)
	_terrain_mat.set_shader_parameter("snow", RenderLook.col(RenderLook.SNOW))
	_terrain_mat.set_shader_parameter("snow_from", RenderLook.SNOW_FROM)
	_terrain_mat.set_shader_parameter("snow_full", RenderLook.SNOW_FULL)
	_terrain_mat.set_shader_parameter("cracked", RenderLook.col(RenderLook.CRACKED))
	_water_mat.set_shader_parameter("water", RenderLook.WATER)
	_water_mat.set_shader_parameter("surface", RenderLook.WATER_SURFACE)
	_water_mat.set_shader_parameter("fall_body", RenderLook.WATER_FALL_BODY)


## The camera's world position this frame, for the foreground rule in the ground and water shaders.
func set_camera(p: Vector3) -> void:
	if _terrain_mat == null:
		return
	_terrain_mat.set_shader_parameter("fore_cam", p)
	_water_mat.set_shader_parameter("fore_cam", p)


static func _planet_aabb(y0: float, y1: float, z0: float, z1: float) -> AABB:
	return AABB(Vector3(-64.0, y0, z0), Vector3(SimConst.W + 128.0, y1 - y0, z1 - z0))


## Row depths from Z_FORE in front to the horizon behind, front to back: spacing ROW_STEP0 at the fighter plane,
## growing by ROW_GROWTH of the distance, with 0 and every stride boundary (either side) included.
static func ground_rows() -> Array:
	var stops: Array = []
	for t in RenderLook.STRIDES:
		if t[0] < RenderLook.FOG_FAR:
			stops.append(t[0])
	var rows: Array = [0.0]
	for side in [1.0, -1.0]:
		var end: float = RenderLook.Z_FORE if side > 0.0 else RenderLook.FOG_FAR
		var d: float = 0.0
		while d < end:
			var nd: float = minf(d + maxf(RenderLook.ROW_STEP0, d * RenderLook.ROW_GROWTH), end)
			for st in stops:
				if st > d and st < nd:
					nd = st
			d = nd
			if side > 0.0:
				rows.push_front(d)
			else:
				rows.append(-d)
	return rows


static func stride_at(z: float) -> int:
	for t in RenderLook.STRIDES:
		if absf(z) <= t[0] + 0.001:
			return int(t[1])
	return int(RenderLook.STRIDES[-1][1])


## The ground and water meshes. The rows split into runs of one column stride (finer near the fighter plane, coarser
## away from it on both sides); a boundary row belongs to both runs and, on the finer side, snaps to the coarser
## stride (UV2.y = that stride) so they meet exactly. The finest run and the middle runs are cut into chunks of
## CHUNK_COLS columns, culled by the frustum; the coarsest runs (far in front and far behind) are one light mesh.
func _make_ground_meshes() -> void:
	var rows: Array = ground_rows()
	var runs: Array = []      # [rows, stride]; neighbouring runs share their boundary row (the row at the limit)
	var start: int = 0
	for i in range(1, rows.size()):
		var a: int = stride_at(rows[i - 1])
		var b: int = stride_at(rows[i])
		if a == b:
			continue
		var bnd: int = i if b < a else i - 1
		runs.append([rows.slice(start, bnd + 1), a])
		start = bnd
	runs.append([rows.slice(start), stride_at(rows[-1])])
	var smallest: int = int(RenderLook.STRIDES[0][1])
	var largest: int = int(RenderLook.STRIDES[-1][1])
	var cc: int = RenderLook.CHUNK_COLS
	for group in ["near", "mid"]:
		for c0 in range(0, SimConst.NC, cc):
			var tv: Array = [[], []]
			for k in range(runs.size()):
				var st: int = runs[k][1]
				if (group == "near") != (st == smallest) or st == largest:
					continue
				var sf: int = runs[k - 1][1] if k > 0 and runs[k - 1][1] > st else 0
				var sl: int = runs[k + 1][1] if k + 1 < runs.size() and runs[k + 1][1] > st else 0
				_grid(tv[0], c0, c0 + cc, runs[k][0], st, sf, sl, false)
				_grid(tv[1], c0, c0 + cc, runs[k][0], st, 0, 0, true)
			if tv[0].is_empty():
				continue
			_terrain_meshes.append(_finish(tv[0], c0 * SimConst.COL, (c0 + cc) * SimConst.COL, false))
			_water_meshes.append(_finish(tv[1], c0 * SimConst.COL, (c0 + cc) * SimConst.COL, true))
	var far: Array = [[], []]
	for k in range(runs.size()):
		if runs[k][1] == largest:
			_grid(far[0], 0, SimConst.NC, runs[k][0], largest, 0, 0, false)
			_grid(far[1], 0, SimConst.NC, runs[k][0], largest, 0, 0, true)
	_terrain_meshes.append(_finish(far[0], 0.0, SimConst.W, false))
	_water_meshes.append(_finish(far[1], 0.0, SimConst.W, true))


## A top grid (ground) or surface grid (water) over columns c0..c1 at the given stride and rows, appended to the
## vertex lists in tv = [verts, uv, uv2, colours, indices]. snap_first, snap_last: the stride the first or last row
## snaps to (0: none).
static func _grid(tv: Array, c0: int, c1: int, rows: Array, stride: int, snap_first: int, snap_last: int, water: bool) -> void:
	if tv.is_empty():
		tv.append_array([PackedVector3Array(), PackedVector2Array(), PackedVector2Array(), PackedColorArray(), PackedInt32Array()])
	var base: int = tv[0].size()
	var nr: int = rows.size()
	var ncols: int = 0
	for c in range(c0, c1 + 1, stride):
		var col: Color = _biome_col(c)
		for r in range(nr):
			var z: float = rows[r]
			var flag: float = 0.0
			if z == 0.0:
				flag = 1.0
			elif not water and r == nr - 1 and snap_last > 1:
				flag = float(snap_last)
			elif not water and r == 0 and snap_first > 1:
				flag = float(snap_first)
			tv[0].append(Vector3(float(c) * SimConst.COL, 0.0, z))
			tv[1].append(Vector2(float(c), 0.0 if water else 1.0))
			tv[2].append(Vector2(1.0, flag))
			tv[3].append(col)
		ncols += 1
	for ci in range(ncols - 1):
		var a: int = base + ci * nr
		var b: int = a + nr
		for r in range(nr - 1):
			tv[4].append_array([a + r, a + r + 1, b + r, b + r, a + r + 1, b + r + 1])


static func _biome_col(c: int) -> Color:
	var biome: String = WorldBiomes.biomeAt(float(posmod(c, SimConst.NC)) * SimConst.COL)
	var col: Color = RenderLook.col(RenderLook.BIOME[biome])
	col.a = 1.0 if biome == "desert" else 0.0
	return col


static func _finish(tv: Array, x0: float, x1: float, water: bool) -> ArrayMesh:
	var m := _mesh(tv[0], tv[1], tv[2], PackedColorArray() if water else tv[3], tv[4])
	var z0: float = INF
	var z1: float = -INF
	for v in tv[0]:
		z0 = minf(z0, v.z)
		z1 = maxf(z1, v.z)
	var y0: float = -4000.0 * RenderLook.WS
	m.custom_aabb = AABB(Vector3(x0 - 64.0, y0, z0 - 1.0), Vector3(x1 - x0 + 128.0, 14000.0 - y0, z1 - z0 + 2.0))
	return m


static func _mesh(v: PackedVector3Array, uv: PackedVector2Array, uv2: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	nrm.fill(Vector3(0.0, 0.0, 1.0))
	arr[Mesh.ARRAY_NORMAL] = nrm
	if uv.size():
		arr[Mesh.ARRAY_TEX_UV] = uv
	if uv2.size():
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	if cols.size():
		arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## custom: per-instance custom data, with instance colours too only if colors (else colours alone).
static func _multimesh(mesh: Mesh, count: int, y1: float, custom: bool = false, colors: bool = false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors or not custom
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.custom_aabb = _planet_aabb(-1000.0 * RenderLook.WS, y1 * RenderLook.WS, RenderLook.Z_TREE_MIN * 1.5, 100.0)
	return mm


## Buildings, roofs, trees and the crowd. Placement that the sim doesn't define (tree depth, where each civilian
## stands, their colours) comes from render-side streams seeded from the fixed world seed, never from S.rng.
func _make_props(S: SimState) -> void:
	var nb: int = S.buildings.size()
	var box := BoxMesh.new()
	var prism := PrismMesh.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 0
	_bld = _multimesh(box, nb, 1400.0)
	_roof = _multimesh(prism, nb, 1400.0)
	_tree = _multimesh(cone, S.trees.size(), 400.0)
	_bld_seen.clear()
	for bi in range(nb):
		_bld_seen.append([-1.0, false, -1.0])
		_roof.set_instance_color(bi, RenderLook.col(RenderLook.ROOF))
	var tr := SimRng.new(SimRng.deriveSeed(4242, "render.trees"))
	_tree_seen.clear()
	_tree_z.resize(S.trees.size())
	for ti in range(S.trees.size()):
		_tree_seen.append(null)
		_tree_z[ti] = tr.range_(RenderLook.Z_TREE_MIN, RenderLook.Z_TREE_MAX)
		_tree.set_instance_color(ti, RenderLook.col(RenderLook.TREE if tr.next() < 0.5 else RenderLook.TREE_TOP))
	var cr := SimRng.new(SimRng.deriveSeed(4242, "render.crowd"))
	_crowd_first.resize(nb + 1)
	_crowd_x.clear()
	_crowd_z.clear()
	var looks: Array = []
	for bi in range(nb):
		_crowd_first[bi] = _crowd_x.size()
		var b = S.buildings[bi]
		for j in range(int(b.pop)):
			_crowd_x.append(SimWrap.wrap(b.x + (cr.next() - 0.5) * (b.w + RenderLook.CROWD_SPREAD)))
			_crowd_z.append(cr.range_(RenderLook.Z_CROWD_MIN, RenderLook.Z_CROWD_MAX))
			var shirt: Color = RenderLook.col(RenderLook.CROWD[int(cr.next() * RenderLook.CROWD.size())]).srgb_to_linear()
			looks.append(Color(shirt.r, shirt.g, shirt.b, cr.next()))
	_crowd_first[nb] = _crowd_x.size()
	_crowd = _multimesh(CrowdMesh.build(), _crowd_x.size(), 80.0, true, true)
	for ci in range(looks.size()):
		_crowd.set_instance_custom_data(ci, looks[ci])
		_crowd.set_instance_color(ci, Color.WHITE)
	_shown.resize(nb)
	_shown.fill(-1)
	flight.reset(nb)
	_blows.clear()
	_startled.clear()
	_calm_at = INF
