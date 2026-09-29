class_name ParticleView
extends MultiMeshInstance3D
## The reference fx consumer's particles (sim/core/view/fx.gd parts) and the render-side impact effects (ImpactFx),
## drawn as one MultiMesh of quads in a single draw call. Sizes follow the prototype's drawParts, which sets them in
## screen pixels, so each is divided by the zoom. Ripples and shock rings lie flat on the water or the ground.
## Per frame it rewrites one float buffer: 12 transform, 4 colour and 4 custom floats per particle.
## Reads the consumer's particles only.

const CAP := 2401 + ImpactFx.CAP   # the consumer's cap (fx.gd _P lets 2401 in) plus the impact effects'
const STRIDE := 20
const SHAPE := {"spark": 0.0, "deb": 0.0, "after": 0.0, "flame": 1.0, "splash": 1.0, "ring": 2.0, "dust": 3.0, "ripple": 2.0, "shock": 2.0}

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
	mm.custom_aabb = AABB(Vector3(-20000.0, -8000.0, -100.0), Vector3(40000.0, 16000.0, 200.0))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/shaders/particle.gdshader")
	m.render_priority = 2          # after the water, so ripples sit on top of it
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


## half_w: half the visible width in world units, for culling.
func update(V: SimFxView, I: ImpactFx, cam_x: float, z: float, half_w: float) -> void:
	var n: int = _fill(V.parts, 0, cam_x, z, half_w + 80.0)
	if I != null:
		n = _fill(I.parts, n, cam_x, z, half_w + 80.0)
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


func _fill(list: Array, n: int, cam_x: float, z: float, lim: float) -> int:
	var zz: float = RenderLook.Z_PARTICLES
	for p in list:
		if n >= CAP:
			break
		var vx: float = SimWrap.sdx(cam_x, p.x)
		if absf(vx) > lim:
			continue
		var k: float = 1.0 - p.age / p.life
		var c: Color = RenderLook.col(p.col)
		var sx: float
		var sy: float
		var rot: float = 0.0
		var cx: float = vx
		var cy: float = p.y
		var inner: float = 0.0
		var flat: bool = false
		match p.type:
			"spark":
				var v := Vector2(p.vx, p.vy)
				sx = maxf(v.length() * 0.03, 0.5 / z)
				sy = maxf(1.0, p.size * maxf(0.6, z)) / z
				rot = atan2(p.vy, p.vx)
				cx -= p.vx * 0.015
				cy -= p.vy * 0.015
				c.a = k
			"ring", "ripple", "shock":
				var lw: float = maxf(1.5, 5.0 * k * z + 1.0) / z
				var r: float = maxf(1.0, p.r * z) / z
				sx = 2.0 * (r + lw * 0.5)
				sy = sx
				inner = (r - lw * 0.5) / (r + lw * 0.5)
				c.a = k * (0.9 if p.type == "ring" else 0.7)
				flat = p.type != "ring"
			"deb":
				sx = maxf(1.5, p.size * z * 1.4) / z
				sy = sx
				c.a = minf(1.0, k * 2.0)
			"dust":
				sx = 2.0 * maxf(2.0, p.size * z * (1.5 - k * 0.5)) / z
				sy = sx
				c.a = 0.35 * k
			"flame":
				sx = 2.0 * maxf(1.5, p.size * z * k * 1.4) / z
				sy = sx
				c.a = 0.8 * k
			"splash":
				sx = 2.0 * maxf(1.5, p.size * maxf(0.7, z)) / z
				sy = sx
				c.a = k
			"after":
				sx = 28.0
				sy = 56.0
				cy += 26.0
				c.a = 0.4 * k
			_:
				continue
		var o: int = n * STRIDE
		if flat:
			# Lying on the ground or water: the quad's x across, its y into the depth, its normal up.
			_buf[o] = sx
			_buf[o + 1] = 0.0
			_buf[o + 2] = 0.0
			_buf[o + 3] = cx
			_buf[o + 4] = 0.0
			_buf[o + 5] = 0.0
			_buf[o + 6] = 1.0
			_buf[o + 7] = cy
			_buf[o + 8] = 0.0
			_buf[o + 9] = sy
			_buf[o + 10] = 0.0
			_buf[o + 11] = 0.0
		else:
			var cs: float = cos(rot)
			var sn: float = sin(rot)
			_buf[o] = cs * sx
			_buf[o + 1] = -sn * sy
			_buf[o + 2] = 0.0
			_buf[o + 3] = cx
			_buf[o + 4] = sn * sx
			_buf[o + 5] = cs * sy
			_buf[o + 6] = 0.0
			_buf[o + 7] = cy
			_buf[o + 8] = 0.0
			_buf[o + 9] = 0.0
			_buf[o + 10] = 1.0
			_buf[o + 11] = zz
		_buf[o + 12] = c.r
		_buf[o + 13] = c.g
		_buf[o + 14] = c.b
		_buf[o + 15] = c.a
		_buf[o + 16] = SHAPE[p.type]
		_buf[o + 17] = inner
		_buf[o + 18] = 0.0
		_buf[o + 19] = 0.0
		n += 1
	return n
