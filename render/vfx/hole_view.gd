class_name VfxHoleView
extends MultiMeshInstance3D
## The holes fighters leave in building facades (docs/vfx/plan.md section 3) for one pane, one MultiMesh, one draw call.
## The hub keeps the list (VfxHub.holes, with each hole's building, position, size and outline seed); a hole goes when its
## building falls. Sits a hair in front of the facade, so the facade's own depth hides nothing. Reads only.

const CAP := VfxLook.HOLES_MAX + 4
const STRIDE := 20

var _buf := PackedFloat32Array()
var count: int = 0


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-40000.0, -12000.0, -1200.0), Vector3(80000.0, 60000.0, 2400.0))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/vfx/shaders/hole.gdshader")
	m.render_priority = 1
	m.set_shader_parameter("dark_col", Color(VfxLook.HOLE_DARK))
	m.set_shader_parameter("rim_col", Color(VfxLook.HOLE_RIM))
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


func update(hub: VfxHub, cam_x: float, half_w: float) -> void:
	var n: int = 0
	var lim: float = half_w + 2000.0
	for h in hub.holes:
		if n >= CAP:
			break
		var vx: float = SimWrap.sdx(cam_x, h.x)
		if absf(vx) > lim + h.w:
			continue
		var o: int = n * STRIDE
		_buf[o] = h.w
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = vx
		_buf[o + 4] = 0.0
		_buf[o + 5] = h.h
		_buf[o + 6] = 0.0
		_buf[o + 7] = h.y
		_buf[o + 8] = 0.0
		_buf[o + 9] = 0.0
		_buf[o + 10] = 1.0
		_buf[o + 11] = h.z
		_buf[o + 12] = 1.0
		_buf[o + 13] = 1.0
		_buf[o + 14] = 1.0
		_buf[o + 15] = 1.0
		_buf[o + 16] = h.seed
		_buf[o + 17] = 0.0
		_buf[o + 18] = 0.0
		_buf[o + 19] = 0.0
		n += 1
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf
