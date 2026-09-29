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
## Reads the sim only; never writes it.

const TERRAIN_SHADER: Shader = preload("res://render/shaders/terrain.gdshader")
const WATER_SHADER: Shader = preload("res://render/shaders/water.gdshader")
const CROWD_SHADER: Shader = preload("res://render/shaders/crowd.gdshader")

var ground := GroundField.new()
var _terrain_mesh: ArrayMesh
var _water_mesh: ArrayMesh
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


## Build the planet for the match in S (after SimCore.newMatch).
func build(S: SimState) -> void:
	for c in _copies:
		remove_child(c)
		c.free()
	_copies.clear()
	if _terrain_mesh == null:
		_make_materials()
		_terrain_mesh = _make_terrain_mesh()
		_water_mesh = _make_water_mesh()
		_crowd_mat = ShaderMaterial.new()
		_crowd_mat.shader = CROWD_SHADER
		_crowd_mat.set_shader_parameter("outline_col", RenderLook.col(RenderLook.CROWD_OUTLINE))
		_crowd_mat.set_shader_parameter("skin_a", RenderLook.col(RenderLook.CROWD_SKIN[0]))
		_crowd_mat.set_shader_parameter("skin_b", RenderLook.col(RenderLook.CROWD_SKIN[1]))
		_crowd_mat.set_shader_parameter("legs", RenderLook.col(RenderLook.CROWD_LEGS))
	ground.rebuild(S)
	_make_props(S)
	for k in range(-RenderLook.PLANET_COPIES, RenderLook.PLANET_COPIES + 1):
		var n := Node3D.new()
		n.name = "Copy%d" % (k + RenderLook.PLANET_COPIES)
		n.set_meta("k", k)
		add_child(n)
		_mesh_child(n, "Terrain", _terrain_mesh, _terrain_mat)
		_mesh_child(n, "Water", _water_mesh, _water_mat)
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


## Crowd legibility for this frame: boost scales each figure about its feet; outline is the shell width in units.
func set_crowd_view(boost: float, outline: float) -> void:
	_crowd_mat.set_shader_parameter("boost", boost)
	_crowd_mat.set_shader_parameter("outline", outline)


## The copy nodes, left to right (for tools and tests).
func copies() -> Array:
	return _copies


func terrain_mesh() -> ArrayMesh:
	return _terrain_mesh


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
		if moved or h != seen[0] or b.alive != seen[1] or b.popAlive != seen[2]:
			_set_building(S, bi, b, h, moved or b.popAlive != seen[2])
			_bld_seen[bi] = [h, b.alive, b.popAlive]
	for ti in range(S.trees.size()):
		var t = S.trees[ti]
		if (dchg and (force or dirty[_col(t.x)] == 1)) or t.alive != _tree_seen[ti]:
			_tree_seen[ti] = t.alive
			if t.alive:
				var g: float = ground.ground_at(S, t.x, _tree_z[ti])
				_tree.set_instance_transform(ti, Transform3D(Basis.from_scale(Vector3(26.0, t.h, 26.0)), Vector3(t.x, g + t.h * 0.5, _tree_z[ti])))
			else:
				_tree.set_instance_transform(ti, _hidden(t.x))
	if dchg:
		ground.dirty.fill(0)
		ground.any_dirty = false


static func _col(x: float) -> int:
	return int(floor(SimWrap.wrap(x) / SimConst.COL))


func _set_building(S: SimState, bi: int, b, h: float, crowd: bool) -> void:
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
		_roof.set_instance_transform(bi, Transform3D(Basis.from_scale(Vector3(b.w * 1.2, 16.0, d * 1.1)), Vector3(b.x, g + h + 8.0, zc)))
	else:
		_roof.set_instance_transform(bi, _hidden(b.x))
	if crowd:
		var first: int = _crowd_first[bi]
		var n: int = _crowd_first[bi + 1] - first
		var alive: int = int(b.popAlive)
		for j in range(n):
			var ci: int = first + j
			var x: float = _crowd_x[ci]
			if j < alive:
				_crowd.set_instance_transform(ci, Transform3D(Basis.IDENTITY, Vector3(x, ground.ground_at(S, x, _crowd_z[ci]), _crowd_z[ci])))
			else:
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
	_water_mat.set_shader_parameter("water", RenderLook.WATER)
	_water_mat.set_shader_parameter("surface", RenderLook.WATER_SURFACE)
	_water_mat.set_shader_parameter("z_front", RenderLook.Z_TERRAIN_FRONT + 1.0)


static func _planet_aabb(y0: float, y1: float, z0: float, z1: float) -> AABB:
	return AABB(Vector3(-64.0, y0, z0), Vector3(SimConst.W + 128.0, y1 - y0, z1 - z0))


## Ground band: per column vertex (NC + 1, the last one reading column 0 again so copies meet exactly), a top grid of
## RenderLook.BAND_ROWS rows in depth (one exactly on the fighter plane, flagged to read the sim's deform directly)
## and a front face from the front row down to the floor.
func _make_terrain_mesh() -> ArrayMesh:
	var zs: Array = RenderLook.BAND_ROWS + RenderLook.FAR_ROWS
	var nz: int = zs.size()
	var per: int = nz + 2
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in range(SimConst.NC + 1):
		var x: float = float(i) * SimConst.COL
		var biome: String = WorldBiomes.biomeAt(x)
		var c: Color = RenderLook.col(RenderLook.BIOME[biome])
		c.a = 1.0 if biome == "desert" else 0.0
		for z in zs:
			v.append(Vector3(x, 0.0, z))
			uv.append(Vector2(float(i), 1.0))
			uv2.append(Vector2(1.0, 1.0 if z == 0.0 else 0.0))
			cols.append(c)
		for e in [[0.0, 1.0], [RenderLook.TERRAIN_FLOOR, 0.0]]:
			v.append(Vector3(x, e[0], zs[0]))
			uv.append(Vector2(float(i), e[1]))
			uv2.append(Vector2(0.0, 0.0))
			cols.append(c)
	for i in range(SimConst.NC):
		var a: int = i * per
		var b: int = a + per
		for r in range(nz - 1):
			idx.append_array([a + r, a + r + 1, b + r, b + r, a + r + 1, b + r + 1])
		idx.append_array([a + nz, b + nz, a + nz + 1, a + nz + 1, b + nz, b + nz + 1])
	var m := _mesh(v, uv, uv2, cols, idx)
	m.custom_aabb = _planet_aabb(RenderLook.TERRAIN_FLOOR, 2000.0, RenderLook.FAR_ROWS[-1], RenderLook.Z_TERRAIN_FRONT)
	return m


## Water: a surface grid over every column (the same rows in depth; the shader drops dry columns and undug ground)
## and a front face just in front of the ground's front face.
func _make_water_mesh() -> ArrayMesh:
	var zs: Array = RenderLook.BAND_ROWS + RenderLook.FAR_ROWS
	var nz: int = zs.size()
	var per: int = nz + 2
	var zf: float = RenderLook.Z_TERRAIN_FRONT + 1.0
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(SimConst.NC + 1):
		var x: float = float(i) * SimConst.COL
		for r in range(nz):
			v.append(Vector3(x, 0.0, zf if r == 0 else zs[r]))
			uv.append(Vector2(float(i), 0.0))
			uv2.append(Vector2(1.0, 1.0 if zs[r] == 0.0 else 0.0))
		for e in [0.0, 1.0]:
			v.append(Vector3(x, 0.0, zf + 0.5))
			uv.append(Vector2(float(i), e))
			uv2.append(Vector2(0.0, 0.0))
	for i in range(SimConst.NC):
		var a: int = i * per
		var b: int = a + per
		for r in range(nz - 1):
			idx.append_array([a + r, a + r + 1, b + r, b + r, a + r + 1, b + r + 1])
		idx.append_array([a + nz, b + nz, a + nz + 1, a + nz + 1, b + nz, b + nz + 1])
	var m := _mesh(v, uv, uv2, PackedColorArray(), idx)
	m.custom_aabb = _planet_aabb(-700.0, 60.0, RenderLook.FAR_ROWS[-1], RenderLook.Z_TERRAIN_FRONT + 2.0)
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


static func _multimesh(mesh: Mesh, count: int, y1: float, custom: bool = false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not custom
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.custom_aabb = _planet_aabb(-700.0, y1, -300.0, 10.0)
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
	_crowd = _multimesh(CrowdMesh.build(), _crowd_x.size(), 80.0, true)
	for ci in range(looks.size()):
		_crowd.set_instance_custom_data(ci, looks[ci])
