class_name VfxTransformView
extends MultiMeshInstance3D
## Draws the transformation's effects (transform.gd) for one pane as one MultiMesh, one draw call, like the trail view: a
## dim disc behind the fighter, the aura, the gather's inward streaks, the break's flash and ring. Everything is a function
## of the form's age at this frame, positioned on the fighter's interpolated pose. Reads only.

const CAP := 220
const STRIDE := 20
const SHAPE_STREAK := 0.0
const SHAPE_RING := 1.0
const SHAPE_DISC := 2.0
const SHAPE_AURA := 3.0
const Z_DIM := -16.0        # behind the fighter plane (and behind a trail at -12)
const Z_AURA := -10.0
const Z_MOTE := -8.0
const Z_FLASH := -6.0
const Z_RING := 3.0
const Z_SPEED := -9.0
const DIM_COL := Color(0.03, 0.04, 0.09)

var _buf := PackedFloat32Array()
var count: int = 0              # instances drawn last frame, for the tests
var forms_drawn: int = 0


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
	m.shader = preload("res://render/vfx/shaders/transform.gdshader")
	m.render_priority = 1
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_buf.resize(CAP * STRIDE)


## a: the frame's interpolation between the last two ticks. cam_x: this pane's wrapped camera x. zoom: its pixels per unit.
func update(hub: VfxHub, host: SimHost, a: float, cam_x: float, zoom: float, half_w: float) -> void:
	var n: int = 0
	forms_drawn = 0
	var xf: VfxTransform = hub.xform
	var q: int = clampi(hub.quality, 0, 2)
	var qshare: float = VfxLook.QUALITY_SHARDS[q] * (0.5 if hub.reduced_motion else 1.0)
	var bh: float = VfxLook.BH
	var minpx: float = 1.6 / maxf(zoom, 1e-6)
	# The standing aura (aura.gd): the current tier's shape and colour while a fighter charges or attacks, weaker than the
	# transformation's own, with a slow breathing pulse (not with reduced motion) and no fill at quality low.
	if hub.standing_aura_enabled:
		for i in range(mini(2, host.S.fighters.size())):
			var lvl: float = lerpf(hub.aura.prev[i], hub.aura.level[i], a)
			var in_form: bool = false
			for fm: VfxTransform.Form in xf.forms:
				if fm.slot == i:
					in_form = true
			if lvl < 0.01 or in_form or n >= CAP - 8:
				continue
			var fxs: float = host.fighter_x(i, a)
			var rels: float = SimWrap.sdx(cam_x, fxs)
			if absf(rels) > half_w + 8.0 * bh:
				continue
			var ps: Vector3 = host.fighter_pose(i, a)
			var fzs: float = host.fighter_z(i, a)
			var fs = host.S.fighters[i]
			var ads: Dictionary = VfxTransform.aura(clampi(int(floor(float(fs.tier) + 0.001)), 1, 4))
			var ahs: float = float(ads["h_bh"]) * bh
			var pulse: float = 1.0
			if not hub.reduced_motion:
				pulse = 1.0 + VfxAura.p("standing", "pulse") * sin(TAU * (float(hub.aura.clock) + a) / maxf(VfxAura.p("standing", "pulse_ticks"), 1.0) + float(i) * 2.0)
			var colr: Color = VfxAura.lane_color(String(fs.aura))
			var fill: float = 0.0 if q == VfxLook.Q_LOW else float(ads["fill"]) * VfxAura.p("standing", "fill_scale")
			colr.a = VfxAura.p("standing", "alpha") * smoothstep(0.0, 1.0, lvl)
			if hub.flicker_enabled:
				colr.a *= VfxReact.flicker(fs, hub.aura.clock, i, hub.reduced_motion)
				pulse *= VfxReact.jitter(fs, hub.aura.clock, i, hub.reduced_motion)
			n = _put(n, Vector2(rels, ps.y + ahs * 0.5 - 0.1 * bh), Vector2(1.0, 0.0), float(ads["w_bh"]) * bh * pulse, ahs * pulse, fzs + Z_AURA, colr, float(ads["lobes"]), fill, SHAPE_AURA)
	# Speed lines alone (speed.gd): thin lines running toward the hit for six ticks, behind the fighters, quiet.
	if hub.speedlines_enabled:
		var nl: int = int(round(VfxReact.p("speed", "lines") * (0.5 if (hub.reduced_motion or q == VfxLook.Q_LOW) else 1.0)))
		var rim_on: bool = not (hub.reduced_motion or q == VfxLook.Q_LOW)
		var dur: float = VfxReact.p("speed", "ticks")
		var ln_w: float = maxf(VfxReact.p("speed", "width_bh") * bh, minpx)
		for s: VfxSpeed.Streak in hub.speed.streaks:
			var relx: float = SimWrap.sdx(cam_x, s.x)
			if absf(relx) > half_w + 6.0 * bh or n >= CAP - 20:
				continue
			var st: float = maxf(s.age - (1.0 - a), 0.0)
			var per: Vector2 = Vector2(-s.dy, s.dx)
			var dirv: Vector2 = Vector2(s.dx, s.dy)
			for k in range(nl):
				var o: int = k * VfxSpeed.LINE_STRIDE
				var across: float = s.lines[o] * bh
				var len_l: float = s.lines[o + 1] * bh
				var gap: float = s.lines[o + 2] * bh
				var tt: float = clampf((st - s.lines[o + 3]) / maxf(dur - s.lines[o + 3], 1.0), 0.0, 1.0)
				if tt <= 0.0:
					continue
				var head: float = lerpf(-VfxReact.p("speed", "dist_bh") * bh, -gap, 1.0 - pow(1.0 - tt, 2.0))
				var tail: float = head - len_l
				var al: float = VfxReact.p("speed", "alpha") * smoothstep(0.0, 0.15, tt) * (1.0 - smoothstep(0.65, 1.0, tt))
				if al < 0.01:
					continue
				var mid: Vector2 = Vector2(relx, s.y) + dirv * (head + tail) * 0.5 + per * across
				var core: Color = VfxPalette.trail_core()
				core.a = al
				if rim_on:
					var rimc: Color = Color(0.08, 0.1, 0.18, al * VfxReact.p("speed", "rim_alpha") / maxf(VfxReact.p("speed", "alpha"), 0.01))
					n = _put(n, mid, dirv, head - tail, ln_w * 2.6, s.z + Z_SPEED - 0.5, rimc, 0.5, 0.05, SHAPE_STREAK)
				n = _put(n, mid, dirv, head - tail, ln_w, s.z + Z_SPEED, core, 0.5, 0.05, SHAPE_STREAK)
	for f: VfxTransform.Form in xf.forms:
		if f.slot >= host.S.fighters.size() or n >= CAP - 8:
			continue
		var fx: float = host.fighter_x(f.slot, a)
		var rel: float = SimWrap.sdx(cam_x, fx)
		if absf(rel) > half_w + 8.0 * bh:
			continue
		var pose: Vector3 = host.fighter_pose(f.slot, a)
		var fz: float = host.fighter_z(f.slot, a)
		var col: Color = VfxAura.lane_color(String(host.S.fighters[f.slot].aura))
		var t: float = f.at(a)
		var beat: int = VfxTransform.beat_of(f, t)
		var sx: float = rel
		var sy: float = pose.y + VfxLook.CHEST_Y        # the sigil
		forms_drawn += 1
		# The light around him dims through the gather, and is gone a few ticks into the break.
		var dim: float = 0.0
		if beat == 0:
			dim = smoothstep(0.0, 0.5, t / float(f.g))
		elif beat == 1:
			dim = 1.0 - smoothstep(0.0, 4.0, t - float(f.g))
		if dim > 0.001:
			var dr: float = VfxTransform.p("gather", "dim_radius_bh") * bh
			var da: float = VfxTransform.p("gather", "dim_alpha") * dim * (0.5 if hub.reduced_motion else 1.0)
			n = _put(n, Vector2(sx, sy), Vector2(1.0, 0.0), dr * 2.0, dr * 2.0, fz + Z_DIM, Color(DIM_COL, da), 1.8, 0.0, SHAPE_DISC)
		# The aura: the old tier's shape drawn in on the gather, the new one in a single frame at the break.
		var al: float = VfxTransform.aura_alpha(f, t)
		var wj: float = 1.0
		if hub.flicker_enabled:
			var sfi = host.S.fighters[f.slot]
			al *= VfxReact.flicker(sfi, int(f.age), f.slot, hub.reduced_motion)
			wj = VfxReact.jitter(sfi, int(f.age), f.slot, hub.reduced_motion)
		if al > 0.002:
			var ad: Dictionary = VfxTransform.aura(f.old_tier if beat == 0 else f.tier)
			var sc: float = VfxTransform.aura_scale(f, t) * wj
			var aw: float = float(ad["w_bh"]) * bh
			var ah: float = float(ad["h_bh"]) * bh
			var cy_full: float = pose.y + ah * 0.5 - 0.1 * bh
			var cy: float = sy + (cy_full - sy) * sc
			var ac: Color = col
			n = _put(n, Vector2(sx, cy), Vector2(1.0, 0.0), aw * sc, ah * sc, fz + Z_AURA, Color(ac, al), float(ad["lobes"]), float(ad["fill"]), SHAPE_AURA)
		# The gather: streaks of aura and loose dust, drawn inward to the sigil.
		if beat == 0:
			n = _motes(n, f, t, sx, sy, fz, col, hub, qshare, q, minpx, fx)
		# The break: a flash in his own colour (not with reduced motion) and one ring leaving the body.
		if t >= float(f.g):
			var tb: float = t - float(f.g)
			if not hub.reduced_motion:
				var ft: float = VfxTransform.p("break", "flash_ticks")
				if tb < ft:
					var fr: float = VfxTransform.p("break", "flash_radius_bh") * bh
					n = _put(n, Vector2(sx, sy), Vector2(1.0, 0.0), fr * 2.0, fr * 2.0, fz + Z_FLASH, Color(col, VfxTransform.p("break", "flash_alpha") * (1.0 - tb / ft)), 1.4, 0.0, SHAPE_DISC)
			var rt: float = VfxTransform.p("break", "ring_ticks")
			if tb < rt:
				var u: float = tb / rt
				var rr: float = lerpf(VfxTransform.p("break", "ring_r0_bh"), VfxTransform.p("break", "ring_r1_bh"), 1.0 - pow(1.0 - u, 2.0)) * bh
				var rc: Color = col
				rc.a = VfxTransform.p("break", "ring_alpha") * pow(1.0 - u, 1.5)
				var thick: float = maxf(VfxTransform.p("break", "ring_thick"), 1.6 * minpx / maxf(rr, 1.0))
				n = _put(n, Vector2(sx, sy), Vector2(1.0, 0.0), rr * 2.0, rr * 2.0, fz + Z_RING, rc, thick, 0.0, SHAPE_RING)
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


## The gather's streaks: each loops from the rim of the gather radius to the sigil along its own angle, in a curve that
## speeds up as it nears. The lower half of the circle is flattened so nothing runs into the ground.
func _motes(n: int, f: VfxTransform.Form, t: float, sx: float, sy: float, fz: float, col: Color, hub: VfxHub, qshare: float, q: int, minpx: float, wx: float) -> int:
	var u: float = t / float(f.g)
	var vis: float = smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.85, 1.0, u))
	if vis <= 0.001:
		return n
	var loops: float = VfxTransform.p("gather", "loops_" + f.version)
	var bh: float = VfxLook.BH
	var rad: float = VfxTransform.p("gather", "radius_bh") * bh
	var len0: float = VfxTransform.p("gather", "len_bh") * bh
	var wd: float = maxf(VfxTransform.p("gather", "width_bh") * bh, minpx)
	var base_a: float = VfxTransform.p("gather", "alpha")
	var nm: int = int(VfxTransform.p("gather", "motes"))
	var total: int = f.motes.size() / VfxTransform.MOTE_STRIDE
	var want_aura: int = int(round(float(nm) * qshare))
	var want_dust: int = int(round(float(total - nm) * qshare)) if q > VfxLook.Q_LOW else 0
	var cmote: Color = col.lightened(0.1)
	var cdust: Color = VfxPalette.dust(VfxPalette.biome_key(wx), "light")
	var ai: int = 0
	var di: int = 0
	for i in range(total):
		if n >= CAP - 4:
			break
		var o: int = i * VfxTransform.MOTE_STRIDE
		var dust: bool = f.motes[o + 4] > 0.5
		if dust:
			if di >= want_dust:
				continue
			di += 1
		else:
			if ai >= want_aura:
				continue
			ai += 1
		var ui: float = fposmod(u * loops + f.motes[o + 2], 1.0)
		var r: float = rad * f.motes[o + 1] * pow(1.0 - ui, 1.7) * (0.8 if dust else 1.0)
		var th: float = f.motes[o]
		var dx: float = cos(th)
		var dy: float = sin(th)
		if dy < 0.0:
			dy *= 0.4
		var p0: Vector2 = Vector2(sx + dx * r, sy + dy * r)
		var inward: Vector2 = Vector2(-dx, -dy).normalized()
		var ln: float = minf(len0 * f.motes[o + 3] * (0.35 + 0.65 * (1.0 - ui)) * (0.6 if dust else 1.0), r)
		if ln < 2.0:
			continue
		var al: float = base_a * pow(sin(PI * ui), 0.6) * vis * (0.7 if dust else 1.0)
		var c: Color = cdust if dust else cmote
		c.a = al
		var mid: Vector2 = p0 - inward * ln * 0.5   # the head is at p0, the leading end; the tail trails outward behind it
		n = _put(n, mid, inward, ln, wd * (1.4 if dust else 1.0), fz + Z_MOTE, c, 0.5, 0.05, SHAPE_STREAK)
	return n


## One quad: centre c (camera-relative x, world y), unit direction dir for its x axis, size l by w, depth z.
func _put(n: int, c: Vector2, dir: Vector2, l: float, w: float, z: float, col: Color, cx: float, cy: float, shape: float) -> int:
	var o: int = n * STRIDE
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
	_buf[o + 16] = cx
	_buf[o + 17] = cy
	_buf[o + 18] = shape
	_buf[o + 19] = 0.0
	return n + 1
