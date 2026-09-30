class_name VfxTrailView
extends MultiMeshInstance3D
## Draws the motion trails and wind marks of one pane (docs/vfx/plan.md section 2) as one MultiMesh, one draw call,
## the way render/core/particle_view.gd draws particles: 12 transform, 4 colour and 4 custom floats per instance in
## one buffer. The history and the marks are shared by every pane (VfxHub); this pane supplies its own camera x and
## zoom, so widths are kept at least a few pixels on screen for this pane's zoom. Reads only.

const CAP := 96
const STRIDE := 20

var _buf := PackedFloat32Array()
var count: int = 0
var ribbons: int = 0      # for the tests: ribbon segments written last frame
var mark_count: int = 0   # ... and marks


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
	mm.custom_aabb = AABB(Vector3(-40000.0, -12000.0, -100.0), Vector3(80000.0, 40000.0, 200.0))
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/vfx/shaders/trail.gdshader")
	m.render_priority = 1          # under the particles (2) and over the water
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


## a: the frame's interpolation between the last two ticks. cam_x: this pane's wrapped camera x. zoom: this pane's
## pixels per unit on the fighter plane. half_w: half the visible width in world units.
func update(hub: VfxHub, host: SimHost, a: float, cam_x: float, zoom: float, half_w: float) -> void:
	var n: int = 0
	ribbons = 0
	mark_count = 0
	var lim: float = half_w + 40.0 * VfxLook.BH
	var q: int = clampi(hub.quality, 0, 2)
	# Wind marks first (behind the ribbons).
	for i in range(mini(2, hub.trails.size())):
		var ts: VfxTrailState = hub.trails[i]
		var col: Color = hub.accents[i].lerp(Color.WHITE, 0.8)
		var rim: Color = hub.accents[i].darkened(0.3)
		# A fighter's marks are drawn only while that fighter is on screen: in a split, the far fighter's marks would
		# otherwise cross this pane with nothing to do with what it is following.
		if absf(SimWrap.sdx(cam_x, host.fighter_x(i, a))) > half_w * 1.3:
			continue
		for m in ts.marks:
			if n >= CAP - 1:
				break
			var vx: float = SimWrap.sdx(cam_x, m.x)
			var mlen: float = minf(m.len, half_w * 0.6)   # never longer than most of a screen half
			if absf(vx) > lim + mlen:
				continue
			var f: float = m.age / m.life
			var al: float = VfxLook.MARK_A * minf(1.0, m.age / 0.05) * (1.0 - smoothstep(0.7, 1.0, f))
			if hub.reduced_motion:
				al *= 0.5
			var w: float = maxf(VfxLook.MARK_W_BH * VfxLook.BH, VfxLook.MARK_MIN_PX / zoom)
			# A darker rim under the pale core, so a mark reads on a light sky as well as on dark ground.
			_put(n, Vector2(vx, m.y), Vector2(m.dx, m.dy), mlen * 1.06, w * 2.0, m.z - 0.5, Color(rim, al * 0.35), 1.0, 0.0, 1.0)
			_put(n + 1, Vector2(vx, m.y), Vector2(m.dx, m.dy), mlen, w, m.z, Color(col, al), 1.0, 0.0, 1.0)
			n += 2
			mark_count += 1
	# Ribbons.
	for i in range(mini(2, hub.trails.size())):
		var ts: VfxTrailState = hub.trails[i]
		if ts.k < 0.02 or n >= CAP - 2 * VfxLook.SEGS:
			continue
		var fx: float = host.fighter_x(i, a)
		var pose: Vector3 = host.fighter_pose(i, a)
		var head_rel: float = SimWrap.sdx(cam_x, fx)
		if absf(head_rel) > lim + VfxLook.LEN_MAX_BH * VfxLook.BH:
			continue
		var span: float = lerpf(VfxLook.SPAN_MIN, VfxLook.SPAN_MAX, ts.k)
		var length: float = minf(ts.sspeed * span, VfxLook.LEN_MAX_BH * VfxLook.BH) * (0.4 + 0.6 * ts.k)
		var pts: PackedVector2Array = ts.ribbon(fx, pose.y + VfxLook.CHEST_Y, length, VfxLook.SEGS)
		if pts.size() < VfxLook.SEGS + 1:
			continue
		var acc: Color = hub.accents[i]
		var layers: Array = []
		if VfxLook.OUTER_BY_QUALITY[q]:
			layers.append([VfxLook.W_OUTER_BH, VfxLook.A_OUTER, acc.lightened(0.25), VfxLook.Z_TRAIL - 0.5, 1.0])
		layers.append([VfxLook.W_CORE_BH, VfxLook.A_CORE, Color(VfxLook.TRAIL_CORE).lerp(acc, 0.12), VfxLook.Z_TRAIL, VfxLook.MIN_CORE_PX / zoom])
		var kk: float = smoothstep(0.0, 1.0, ts.k)
		if hub.reduced_motion:
			kk *= 0.5
		for ly in layers:
			var w0: float = maxf(ly[0] * VfxLook.BH * (0.5 + 0.5 * ts.k), ly[4])
			for j in range(VfxLook.SEGS):
				if n >= CAP:
					break
				var pa: Vector2 = pts[j]              # nearer the head
				var pb: Vector2 = pts[j + 1]
				var wa: float = w0 * (1.0 - float(j) / float(VfxLook.SEGS))
				var wb: float = w0 * (1.0 - float(j + 1) / float(VfxLook.SEGS))
				var wq: float = maxf(wa, 1.0)
				var d: Vector2 = pa - pb
				var l: float = d.length()
				if l < 0.01:
					continue
				var mid: Vector2 = (pa + pb) * 0.5
				var c: Color = ly[2]
				c.a = ly[1] * VfxLook.SEG_ALPHA[j] * kk
				_put(n, Vector2(head_rel + mid.x, mid.y), d / l, l, wq, ly[3], c, wa / wq, wb / wq, 0.0)
				n += 1
				ribbons += 1
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


## One quad: centre c (camera-relative x, world y), unit direction dir (tail to head), length l, width w, depth z.
func _put(i: int, c: Vector2, dir: Vector2, l: float, w: float, z: float, col: Color, hw_head: float, hw_tail: float, shape: float) -> void:
	var o: int = i * STRIDE
	_buf[o] = dir.x * l
	_buf[o + 1] = -dir.y * w
	_buf[o + 2] = 0.0
	_buf[o + 3] = c.x
	_buf[o + 4] = dir.y * l
	_buf[o + 5] = dir.x * w
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
	_buf[o + 16] = hw_head
	_buf[o + 17] = hw_tail
	_buf[o + 18] = shape
	_buf[o + 19] = 0.0
