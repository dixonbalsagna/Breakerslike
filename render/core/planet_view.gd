class_name PlanetView
extends Node3D
## The wrapped planet: the ground band, sea water, far ridges, buildings, trees and the crowd. Everything anchored to
## the world is built once per match in world x [0, W) and drawn as three copies one planet apart, placed at
## k * W - cam.x. The copies are identical, so the seam at x = 0 / W can never pop, at any zoom or separation, and a
## view wider than the planet (tiny zoom on an ultra-wide or phone screen) still shows every object at every place it
## appears. Per-frame cost is three node moves plus whatever changed in the sim since the last frame: the heightfield
## texture when craters dig, and the instances of damaged buildings, fallen trees and lost civilians.
## Reads the sim only; never writes it.

const COPIES: Array = [-1, 0, 1]
const TERRAIN_SHADER: Shader = preload("res://render/shaders/terrain.gdshader")
const WATER_SHADER: Shader = preload("res://render/shaders/water.gdshader")
const CROWD_SIZE := Vector3(3.2, 9.0, 3.2)

var _img: Image
var _tex: ImageTexture
var _deform_seen := PackedFloat32Array()
var _terrain_mesh: ArrayMesh
var _water_mesh: ArrayMesh
var _ridges: Array = []            # [ArrayMesh, ShaderMaterial]
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
	_make_height_texture(S)
	if _terrain_mesh == null:
		_terrain_mesh = _make_terrain_mesh()
		for r in RenderLook.RIDGES:
			_ridges.append([_make_ridge_mesh(r[0], r[1], r[2], _ridges.size()), RenderMats.flat(RenderLook.col(r[3]), 0.0)])
	_water_mesh = _make_water_mesh(S)
	_make_props(S)
	for k in COPIES:
		var n := Node3D.new()
		n.name = "Copy%d" % (k + 1)
		add_child(n)
		_mesh_child(n, "Terrain", _terrain_mesh, _terrain_mat)
		_mesh_child(n, "Water", _water_mesh, _water_mat)
		for i in range(_ridges.size()):
			_mesh_child(n, "Ridge%d" % i, _ridges[i][0], _ridges[i][1])
		_mm_child(n, "Buildings", _bld)
		_mm_child(n, "Roofs", _roof)
		_mm_child(n, "Trees", _tree)
		_mm_child(n, "Crowd", _crowd)
		_copies.append(n)
	_deform_seen = PackedFloat32Array()
	refresh(S, true)


## Per frame: place the copies around the camera's wrapped x and apply whatever changed in the world.
func update(S: SimState, cam_x: float) -> void:
	for i in range(_copies.size()):
		_copies[i].position.x = float(COPIES[i]) * SimConst.W - cam_x
	refresh(S, false)


## The three copy nodes, left to right (for tools and tests).
func copies() -> Array:
	return _copies


func terrain_mesh() -> ArrayMesh:
	return _terrain_mesh


func refresh(S: SimState, force: bool) -> void:
	var dchg: bool = force or S.deform != _deform_seen
	if dchg:
		_deform_seen = S.deform.duplicate()
		_img.set_data(SimConst.NC, 2, false, Image.FORMAT_RF, S.base.to_byte_array() + S.deform.to_byte_array())
		_tex.update(_img)
	for bi in range(S.buildings.size()):
		var b = S.buildings[bi]
		var h: float = WorldStructures.curH(b)
		var seen: Array = _bld_seen[bi]
		if dchg or h != seen[0] or b.alive != seen[1] or b.popAlive != seen[2]:
			_set_building(S, bi, b, h, dchg or b.popAlive != seen[2])
			_bld_seen[bi] = [h, b.alive, b.popAlive]
	for ti in range(S.trees.size()):
		var t = S.trees[ti]
		if dchg or t.alive != _tree_seen[ti]:
			_tree_seen[ti] = t.alive
			if t.alive:
				var g: float = WorldTerrain.groundY(S, t.x)
				_tree.set_instance_transform(ti, Transform3D(Basis.from_scale(Vector3(26.0, t.h, 26.0)), Vector3(t.x, g + t.h * 0.5, _tree_z[ti])))
			else:
				_tree.set_instance_transform(ti, _hidden(t.x))


func _set_building(S: SimState, bi: int, b, h: float, crowd: bool) -> void:
	var g: float = WorldTerrain.groundY(S, b.x)
	var tower: bool = b.kind == "tower"
	var d: float = b.w * (0.8 if tower else 0.9)
	var zc: float = RenderLook.Z_BUILDING_FRONT - d * 0.5
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
				var cg: float = WorldTerrain.groundY(S, x)
				_crowd.set_instance_transform(ci, Transform3D(Basis.from_scale(CROWD_SIZE), Vector3(x, cg + CROWD_SIZE.y * 0.5, _crowd_z[ci])))
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


func _mm_child(parent: Node3D, n: String, mm: MultiMesh) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.multimesh = mm
	mi.material_override = RenderMats.flat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _make_height_texture(S: SimState) -> void:
	_img = Image.create_from_data(SimConst.NC, 2, false, Image.FORMAT_RF, S.base.to_byte_array() + S.deform.to_byte_array())
	if _tex == null:
		_tex = ImageTexture.create_from_image(_img)
		_terrain_mat = ShaderMaterial.new()
		_terrain_mat.shader = TERRAIN_SHADER
		_terrain_mat.set_shader_parameter("heights", _tex)
		_terrain_mat.set_shader_parameter("nc", SimConst.NC)
		_terrain_mat.set_shader_parameter("sea_floor", RenderLook.col(RenderLook.SEA_FLOOR))
		_terrain_mat.set_shader_parameter("crater", RenderLook.col(RenderLook.CRATER))
		_terrain_mat.set_shader_parameter("crater_desert", RenderLook.col(RenderLook.CRATER_DESERT))
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = WATER_SHADER
		_water_mat.set_shader_parameter("heights", _tex)
		_water_mat.set_shader_parameter("nc", SimConst.NC)
		_water_mat.set_shader_parameter("water", RenderLook.WATER)
		_water_mat.set_shader_parameter("surface", RenderLook.WATER_SURFACE)
	else:
		_tex.update(_img)


static func _planet_aabb(y0: float, y1: float, z0: float, z1: float) -> AABB:
	return AABB(Vector3(-64.0, y0, z0), Vector3(SimConst.W + 128.0, y1 - y0, z1 - z0))


## Ground band: per column vertex (NC + 1, the last one reading column 0 again so copies meet exactly), a front face
## from the surface to the floor and a top face from the front edge to the back edge.
func _make_terrain_mesh() -> ArrayMesh:
	var zf: float = RenderLook.Z_TERRAIN_FRONT
	var zb: float = RenderLook.Z_TERRAIN_BACK
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
		for e in [[0.0, 1.0, 0.0, 0.0, zf], [RenderLook.TERRAIN_FLOOR, 0.0, 0.0, 0.0, zf], [0.0, 1.0, 1.0, 0.0, zf], [0.0, 1.0, 1.0, 1.0, zb]]:
			v.append(Vector3(x, e[0], e[4]))
			uv.append(Vector2(float(i), e[1]))
			uv2.append(Vector2(e[2], e[3]))
			cols.append(c)
	for i in range(SimConst.NC):
		var a: int = i * 4
		var b: int = a + 4
		idx.append_array([a, b, a + 1, a + 1, b, b + 1, a + 2, a + 3, b + 2, b + 2, a + 3, b + 3])
	var m := _mesh(v, uv, uv2, cols, idx)
	m.custom_aabb = _planet_aabb(RenderLook.TERRAIN_FLOOR, 2000.0, RenderLook.Z_TERRAIN_BACK, RenderLook.Z_TERRAIN_FRONT)
	return m


## Water: the same layout as the ground, only over columns where the base terrain is below sea level.
func _make_water_mesh(S: SimState) -> ArrayMesh:
	var zf: float = RenderLook.Z_TERRAIN_FRONT + 1.0
	var zb: float = RenderLook.Z_TERRAIN_BACK
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var nc: int = SimConst.NC
	for i in range(nc):
		if S.base[i] >= -30.0 and S.base[(i + 1) % nc] >= -30.0:
			continue
		var a: int = v.size()
		for k in [i, i + 1]:
			var x: float = float(k) * SimConst.COL
			for e in [[1.0, 0.0, 0.0, zf], [0.0, 0.0, 0.0, zf], [0.0, 1.0, 0.0, zf], [0.0, 1.0, 1.0, zb]]:
				v.append(Vector3(x, 0.0, e[3]))
				uv.append(Vector2(float(k), e[0]))
				uv2.append(Vector2(e[1], e[2]))
		var b: int = a + 4
		idx.append_array([a, b, a + 1, a + 1, b, b + 1, a + 2, a + 3, b + 2, b + 2, a + 3, b + 3])
	var m := _mesh(v, uv, uv2, PackedColorArray(), idx)
	m.custom_aabb = _planet_aabb(-700.0, 10.0, RenderLook.Z_TERRAIN_BACK, RenderLook.Z_TERRAIN_FRONT + 2.0)
	return m


## A far ridge silhouette: whole-number harmonics of the circumference, so it wraps seamlessly.
func _make_ridge_mesh(z: float, base: float, amp: float, layer: int) -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var n: int = 300
	var tau: float = TAU / SimConst.W
	for i in range(n + 1):
		var x: float = SimConst.W * float(i) / float(n)
		var h: float = base + amp * (0.5 * sin(x * tau * 7.0 + layer) + 0.3 * sin(x * tau * 23.0 + 2.0 * layer) + 0.2 * sin(x * tau * 61.0 + 3.0 * layer))
		v.append(Vector3(x, h, z))
		v.append(Vector3(x, RenderLook.TERRAIN_FLOOR, z))
	for i in range(n):
		var a: int = i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var m := _mesh(v, PackedVector2Array(), PackedVector2Array(), PackedColorArray(), idx)
	m.custom_aabb = _planet_aabb(RenderLook.TERRAIN_FLOOR, base + amp + 10.0, z - 1.0, z + 1.0)
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


static func _multimesh(mesh: Mesh, count: int, y1: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
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
	var cols: Array = []
	for bi in range(nb):
		_crowd_first[bi] = _crowd_x.size()
		var b = S.buildings[bi]
		for j in range(int(b.pop)):
			_crowd_x.append(SimWrap.wrap(b.x + (cr.next() - 0.5) * (b.w + 28.0)))
			_crowd_z.append(cr.range_(RenderLook.Z_CROWD_MIN, RenderLook.Z_CROWD_MAX))
			cols.append(RenderLook.col(RenderLook.CROWD[int(cr.next() * RenderLook.CROWD.size())]))
	_crowd_first[nb] = _crowd_x.size()
	_crowd = _multimesh(box, _crowd_x.size(), 40.0)
	for ci in range(cols.size()):
		_crowd.set_instance_color(ci, cols[ci])
