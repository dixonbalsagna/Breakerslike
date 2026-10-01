class_name VfxShardView
extends MultiMeshInstance3D
## Draws the shared debris pool (debris.gd) for one pane: glass, steel, chunks, dust puffs and rings, one MultiMesh, one
## draw call, the way render/core/particle_view.gd draws particles. Puffs go first (behind), shards after, rings last.
## Each bit's own depth is its z, so it sits in front of the facade it came out of and behind the fighters. Reads only.

const CAP := VfxLook.DEBRIS_CAP + 8
const STRIDE := 20

var _buf := PackedFloat32Array()
var count: int = 0
var puffs: int = 0
var shards: int = 0


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
	m.shader = preload("res://render/vfx/shaders/shard.gdshader")
	m.render_priority = 2
	m.set_shader_parameter("rim_glass", Color(VfxLook.GLASS_HI))
	m.set_shader_parameter("rim_steel", Color(VfxLook.STEEL_HI))
	m.set_shader_parameter("rim_dust", Color(VfxLook.DUST_B))
	m.set_shader_parameter("rim_conc", Color(VfxLook.STEEL_HI))
	m.set_shader_parameter("rim_spray", VfxPalette.dust("ocean", "shadow"))
	m.set_shader_parameter("ember_dark", VfxPalette.ember("rim"))
	m.set_shader_parameter("ember_light", VfxPalette.ember("hot"))
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


## cam_x: this pane's wrapped camera x; zoom: its pixels per unit at the fighter plane; half_w: half the visible width.
func update(hub: VfxHub, cam_x: float, zoom: float, half_w: float) -> void:
	var d: VfxDebris = hub.debris
	var n: int = 0
	puffs = 0
	shards = 0
	var lim: float = half_w + 1500.0
	var minpx: float = 1.6 / maxf(zoom, 1e-6)
	# Three passes so the order is puffs, then shards, then rings, without sorting.
	for pass_i in range(3):
		for b in d.bits:
			var is_puff: bool = b.kind == VfxDebris.PUFF
			var is_ring: bool = b.kind == VfxDebris.RING
			if pass_i == 0 and not is_puff:
				continue
			if pass_i == 1 and (is_puff or is_ring):
				continue
			if pass_i == 2 and not is_ring:
				continue
			if n >= CAP:
				break
			var vx: float = SimWrap.sdx(cam_x, b.x)
			if absf(vx) > lim + b.sx:
				continue
			var f: float = b.age / b.life
			var c: Color = b.col
			var sx: float = maxf(b.sx, minpx)
			var sy: float = maxf(b.sy, minpx * 0.5)
			match b.kind:
				VfxDebris.PUFF:
					c.a = 0.82 * (1.0 - smoothstep(0.5, 1.0, f)) * minf(1.0, b.age / 0.06)
					if hub.reduced_motion:
						c.a *= 0.6
					puffs += 1
				VfxDebris.RING:
					c.a = 0.6 * (1.0 - f)
					sy = sx
				_:
					c.a = 1.0 - smoothstep(0.7, 1.0, f)
					shards += 1
			var mode: float = 0.0
			if b.kind == VfxDebris.EMBER and b.col2.a > 0.5 and not b.glass:
				# Art's ember ramp: core, hot, warm, then a char chip with a light rim. Brightness, not hue.
				if f < 0.2:
					c = VfxPalette.ember("core")
				elif f < 0.5:
					c = VfxPalette.ember("hot")
				elif f < 0.8:
					c = VfxPalette.ember("warm")
				else:
					c = VfxPalette.ember("char")
					mode = 1.0
				c.a = 1.0 - smoothstep(0.85, 1.0, f)
			_put(n, Vector2(vx, b.y), b.rot if not is_puff and not is_ring else 0.0, sx, sy, b.z, c, float(b.kind), b.seed, mode)
			n += 1
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


func _put(i: int, c: Vector2, rot: float, sx: float, sy: float, z: float, col: Color, shape: float, sd: float, mode: float = 0.0) -> void:
	var o: int = i * STRIDE
	var cs: float = cos(rot)
	var sn: float = sin(rot)
	_buf[o] = cs * sx
	_buf[o + 1] = -sn * sy
	_buf[o + 2] = 0.0
	_buf[o + 3] = c.x
	_buf[o + 4] = sn * sx
	_buf[o + 5] = cs * sy
	_buf[o + 6] = 0.0
	_buf[o + 7] = c.y
	_buf[o + 8] = 0.0
	_buf[o + 9] = 0.0
	_buf[o + 10] = 1.0
	_buf[o + 11] = z
	_buf[o + 12] = col.r
	_buf[o + 13] = col.g
	_buf[o + 14] = col.b
	_buf[o + 15] = col.a
	_buf[o + 16] = shape
	_buf[o + 17] = sd
	_buf[o + 18] = mode
	_buf[o + 19] = 0.0
