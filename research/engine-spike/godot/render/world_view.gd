extends Node3D
## Engine spike (throwaway, research only). The 2.5D side-on world renderer: terrain, water, beams, the two boxes and
## the Camera3D. Presentation only: sync() reads a scene and the camera and never writes either of them.
##
## Floating origin: the camera always sits at render x = 0. Every object is drawn at sdx(cam.x, worldX), computed in
## float64 here on the CPU. Nothing is ever placed at a raw world x.
##   terrain / water  one static grid of GRID_COLS columns centred on the camera; the shader reads the heights from a
##                    1200x1 RF texture with texelFetch at (col0 + i) mod 1200. Only two uniforms move per tick.
##   beams            one MultiMesh of 3 quads per beam (glow 44, core 14, flare r 60), additive, one draw call.
##   boxes            two MeshInstance3D (BoxMesh 40x60x40) from main.tscn.

const _Terrain = preload("res://sim/terrain.gd")

const NC: int = 1200
const COLW: float = 8.0
const W: float = 9600.0
const HALF: float = 4800.0
const GRID_COLS: int = 1100
const HALF_GRID: int = 550
const Z_BACK: float = -400.0
const Z_FRONT: float = 120.0
const NBEAM_MAX: int = 6
const GLOW_W: float = 44.0
const CORE_W: float = 14.0
const FLARE_R: float = 60.0

# Biome colours (plain, original): ocean floor, plains, city, village, forest, desert, mountains.
const BIOME_COLORS: Array[Color] = [
	Color(0.46, 0.43, 0.36), Color(0.42, 0.62, 0.30), Color(0.56, 0.56, 0.60), Color(0.64, 0.56, 0.38),
	Color(0.22, 0.44, 0.22), Color(0.86, 0.74, 0.48), Color(0.52, 0.46, 0.42),
]
const BEAM_GLOW: Array[Color] = [Color(0.30, 0.80, 1.00), Color(1.00, 0.52, 0.12)]
const BEAM_CORE: Array[Color] = [Color(0.85, 1.00, 1.00), Color(1.00, 0.94, 0.80)]

@onready var terrain_mi: MeshInstance3D = $Terrain
@onready var water_mi: MeshInstance3D = $Water
@onready var beams_mmi: MultiMeshInstance3D = $Beams
@onready var box_a: MeshInstance3D = $BoxA
@onready var box_b: MeshInstance3D = $BoxB

var camera3d: Camera3D
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var beam_mm: MultiMesh

var heights_img: Image
var heights_tex: ImageTexture
var base_tex: ImageTexture
var biome_tex: ImageTexture
var h32 := PackedFloat32Array()

var _terrain_obj: Object = null      # the SpikeTerrain the textures were last built from
var _terrain_version: int = -1
var _beam_count: int = -1
var uploads: int = 0                 # height-texture uploads done so far
var last_upload_ms: float = 0.0


func _ready() -> void:
	terrain_mat = terrain_mi.material_override
	water_mat = water_mi.material_override
	h32.resize(NC)
	heights_img = Image.create_empty(NC, 1, false, Image.FORMAT_RF)
	heights_tex = ImageTexture.create_from_image(heights_img)
	terrain_mi.mesh = _grid_mesh(4)
	water_mi.mesh = _grid_mesh(6)
	_build_beams()


func setup(cam3d: Camera3D) -> void:
	camera3d = cam3d


## A static grid of GRID_COLS columns with `per` vertices per column line. Vertex positions are placeholders: the
## vertex shader places everything from UV = (grid column, kind). Terrain (per 4): top back, top front, face top,
## face bottom. Water (per 6): back face top/bottom, surface back/front, front face top/bottom. Triangles are
## clockwise seen from the camera side (Godot's front faces).
func _grid_mesh(per: int) -> ArrayMesh:
	var n: int = GRID_COLS + 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	verts.resize(n * per)
	uvs.resize(n * per)
	norms.resize(n * per)
	for i in n:
		for k in per:
			var idx: int = i * per + k
			verts[idx] = Vector3(-4400.0 + float(i) * COLW, 0.0, 0.0)
			uvs[idx] = Vector2(float(i), float(k))
			norms[idx] = Vector3(0.0, 1.0, 0.0)
	# Index order is by face kind first, then by column: translucent water is drawn in index order within one mesh,
	# so every back face must come before every surface quad and every front face (column order made the half of
	# the screen right of the camera blend back faces over front faces).
	var ind := PackedInt32Array()
	for q in range(0, per, 2):
		for i in GRID_COLS:
			var a: int = i * per
			var b: int = (i + 1) * per
			# (a+q) top/back-left, (b+q) top/back-right, (a+q+1) bottom/front-left, (b+q+1) bottom/front-right
			ind.append_array(PackedInt32Array([a + q, b + q, a + q + 1, a + q + 1, b + q, b + q + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = ind
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# The shader moves every vertex, so the imported bounds mean nothing: give a box that always covers the view.
	mesh.custom_aabb = AABB(Vector3(-4700.0, -800.0, -450.0), Vector3(9400.0, 2000.0, 620.0))
	return mesh


func _build_beams() -> void:
	beam_mm = MultiMesh.new()
	beam_mm.transform_format = MultiMesh.TRANSFORM_3D
	beam_mm.use_colors = true
	beam_mm.use_custom_data = true
	beam_mm.mesh = QuadMesh.new()   # 1 x 1 in the XY plane, facing +z (the camera)
	beam_mm.instance_count = NBEAM_MAX * 3
	beam_mm.visible_instance_count = 0
	beam_mm.custom_aabb = AABB(Vector3(-6000.0, -2000.0, -10.0), Vector3(12000.0, 6000.0, 20.0))
	for i in NBEAM_MAX:
		beam_mm.set_instance_custom_data(i * 3, Color(0.0, 1.0, 0.0, 0.0))       # glow
		beam_mm.set_instance_custom_data(i * 3 + 1, Color(1.0, 1.0, 0.0, 0.0))   # core
		beam_mm.set_instance_custom_data(i * 3 + 2, Color(2.0, 1.0, 0.0, 0.0))   # impact flare
	beams_mmi.multimesh = beam_mm


## Static textures for a (new) terrain: base heights and the biome colours, with 32-unit stripes so that column
## continuity (for example across the seam) is easy to see.
func _build_static(terrain) -> void:
	var base: PackedFloat64Array = terrain.base
	var b32 := PackedFloat32Array()
	b32.resize(NC)
	var colors := PackedByteArray()
	colors.resize(NC * 4)
	for i in NC:
		b32[i] = base[i]
		var c: Color = BIOME_COLORS[_Terrain.biome_at(float(i) * COLW)]
		if (i >> 2) & 1 == 1:
			c = c * 0.93
		colors[i * 4] = c.r8
		colors[i * 4 + 1] = c.g8
		colors[i * 4 + 2] = c.b8
		colors[i * 4 + 3] = 255
	base_tex = ImageTexture.create_from_image(Image.create_from_data(NC, 1, false, Image.FORMAT_RF, b32.to_byte_array()))
	biome_tex = ImageTexture.create_from_image(Image.create_from_data(NC, 1, false, Image.FORMAT_RGBA8, colors))
	terrain_mat.set_shader_parameter("heights", heights_tex)
	terrain_mat.set_shader_parameter("base_heights", base_tex)
	terrain_mat.set_shader_parameter("biome_colors", biome_tex)
	water_mat.set_shader_parameter("heights", heights_tex)
	water_mat.set_shader_parameter("base_heights", base_tex)


## Re-uploads the 1200x1 height texture (base + deform, float32) when terrain.version moved. Returns the time spent
## in ms (0 when nothing changed): the CPU cost of filling the array plus ImageTexture.update().
func upload_heights(terrain) -> float:
	if terrain != _terrain_obj:
		_terrain_obj = terrain
		_terrain_version = -1
		_build_static(terrain)
	if terrain.version == _terrain_version:
		return 0.0
	var t0: int = Time.get_ticks_usec()
	var base: PackedFloat64Array = terrain.base
	var deform: PackedFloat64Array = terrain.deform
	for i in NC:
		h32[i] = base[i] + deform[i]
	heights_img.set_data(NC, 1, false, Image.FORMAT_RF, h32.to_byte_array())
	heights_tex.update(heights_img)
	_terrain_version = terrain.version
	uploads += 1
	last_upload_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return last_upload_ms


static func sdx(p: float, q: float) -> float:
	var d: float = fmod(q - p, W)
	if d > HALF:
		d -= W
	elif d < -HALF:
		d += W
	return d


## Places everything for the current sim state. Reads scene and cam only.
func sync(scene, cam) -> void:
	var cx: float = cam.x
	# Camera3D: render x = 0, height cam.y, distance so the z = 0 plane shows exactly cam.view_w.
	camera3d.position = Vector3(0.0, cam.y, cam.distance())
	# Terrain grid: grid column 0 shows planet column c - HALF_GRID, where c is the camera's column.
	var c: int = int(floor(cx / COLW))
	var first: int = c - HALF_GRID
	var x_off: float = float(first) * COLW - cx
	var col0: int = ((first % NC) + NC) % NC
	terrain_mat.set_shader_parameter("col0", col0)
	terrain_mat.set_shader_parameter("x_off", x_off)
	water_mat.set_shader_parameter("col0", col0)
	water_mat.set_shader_parameter("x_off", x_off)
	# Boxes.
	box_a.position = Vector3(sdx(cx, scene.a.x), scene.a.y, 0.0)
	box_b.position = Vector3(sdx(cx, scene.b.x), scene.b.y, 0.0)
	# Beams: source at sdx(cam, sx); target along the shortest arc from the source.
	var beams: Array = scene.beams
	var nb: int = mini(beams.size(), NBEAM_MAX)
	if nb != _beam_count:
		_beam_count = nb
		beam_mm.visible_instance_count = nb * 3
		for i in nb:
			var o: int = int(beams[i].owner)
			beam_mm.set_instance_color(i * 3, BEAM_GLOW[o])
			beam_mm.set_instance_color(i * 3 + 1, BEAM_CORE[o])
			beam_mm.set_instance_color(i * 3 + 2, BEAM_CORE[o])
	for i in nb:
		var bm: Dictionary = beams[i]
		var sx: float = sdx(cx, bm.sx)
		var tx: float = sx + sdx(bm.sx, bm.tx)
		var sy: float = bm.sy
		var ty: float = bm.ty
		var dx: float = tx - sx
		var dy: float = ty - sy
		var ln: float = sqrt(dx * dx + dy * dy)
		if ln < 0.001:
			ln = 0.001
		var ux: float = dx / ln
		var uy: float = dy / ln
		var mid := Vector3((sx + tx) * 0.5, (sy + ty) * 0.5, 0.0)
		var along := Vector3(dx, dy, 0.0)
		var z := Vector3(0.0, 0.0, 1.0)
		beam_mm.set_instance_transform(i * 3, Transform3D(Basis(along, Vector3(-uy, ux, 0.0) * GLOW_W, z), mid))
		beam_mm.set_instance_transform(i * 3 + 1, Transform3D(Basis(along, Vector3(-uy, ux, 0.0) * CORE_W, z), mid))
		var fl: float = FLARE_R * 2.0
		beam_mm.set_instance_transform(i * 3 + 2, Transform3D(Basis(Vector3(fl, 0.0, 0.0), Vector3(0.0, fl, 0.0), z), Vector3(tx, ty, 0.0)))


func set_production_look(sun: DirectionalLight3D, env: Environment, on: bool) -> void:
	sun.shadow_enabled = on
	env.glow_enabled = on
	terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
