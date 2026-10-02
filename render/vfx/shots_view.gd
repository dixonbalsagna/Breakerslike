class_name VfxShotsView
extends MultiMeshInstance3D
## Draws the energy blasts for one pane (shots.gd; Simulation's docs/architecture/shots.md): every live shot in S.shots each frame,
## interpolated, in its owner's lane colour; the charge on the hand while a charged shot is held; and the short effects the shot
## events call for (a hit's flash, a guard's splash, a deflect's ring, a trade's burst). One MultiMesh, one draw call, on the
## transformation's shader (a streak, a ring, a disc). Reads only; it is a child of the trail view (VfxTrailView), which the layer
## already updates every frame.
##
## A shot is a hard-edged cel disc in the lane colour with a darker rim and a lighter core (never white), a tapering tail behind
## it, and for a shot of power 2 or more a thin halo ring. A bolt is small with a short tail; a charged shot is bigger by its power
## and by its charge. A seeking shot is drawn on a slight arc that is zero at both ends (it leaves and arrives on its true line).
## A deflected shot is seen turning: the sim changes its owner and it flies back, and the colour changes with the owner.

const CAP := 224
const STRIDE := 20
const SHAPE_STREAK := 0.0
const SHAPE_RING := 1.0
const SHAPE_DISC := 2.0
const Z_SHOT := 4.0          # in front of the fighter plane, so a shot is not hidden behind a body it passes
const Z_FX := 6.0
const Z_HAND := 5.0

var _buf := PackedFloat32Array()
var count: int = 0           # instances drawn last frame (the tests)
var shots_drawn: int = 0     # shots drawn last frame
var charges_drawn: int = 0   # fighters with a charge drawn last frame


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


## a: the frame's interpolation between the last two ticks. host: anything with .S and fighter_x / fighter_pose / fighter_z (the
## pane's SimHost; a stub in the tests).
func update(hub: VfxHub, host, a: float, cam_x: float, zoom: float, half_w: float) -> void:
	var n: int = 0
	shots_drawn = 0
	charges_drawn = 0
	var S: SimState = host.S
	var bh: float = VfxLook.BH
	var minpx: float = 1.6 / maxf(zoom, 1e-6)
	var sh: VfxShots = hub.shots
	var alpha: float = VfxShots.p("shots", "alpha")
	var dt: float = SimConst.DT
	# The charge on the hand (behind the shots).
	for i in range(mini(2, S.fighters.size())):
		var c: VfxShots.Charge = sh.charges[i]
		var lvl: float = lerpf(c.prev, c.lvl, a)
		if lvl < 0.02 or n >= CAP - 16:
			continue
		var fx: float = host.fighter_x(i, a)
		var rel: float = SimWrap.sdx(cam_x, fx)
		if absf(rel) > half_w + 4.0 * bh:
			continue
		charges_drawn += 1
		n = _hand(n, S, host, i, c, lvl, rel, a, bh, minpx, alpha)
	# The shots in flight.
	var lim: float = half_w + 6.0 * bh
	var still: bool = sh.last_frozen
	for sp in S.shots:
		if n >= CAP - 24:
			break
		var rel: float = SimWrap.sdx(cam_x, sp.x)
		# Where it is at this frame: the state is the end of the last tick, so go back by what is left of the tick unless the shots
		# stood still (a hit-stop, a pause) or it was fired this tick.
		var back: Vector2 = shot_back(sp, a, still)
		var px: float = rel - back.x
		var py: float = sp.y - back.y
		if absf(px) > lim:
			continue
		var dirv: Vector2 = Vector2(sp.vx, sp.vy)
		# A seeking shot: a slight arc, zero at both ends.
		if int(sp.mode) == 1 and sp.total > 0:
			var prog: float = clampf(1.0 - (float(sp.left) + (0.0 if (still or sp.fresh) else 1.0 - a)) / float(sp.total), 0.0, 1.0)
			py += arc_y(prog, sp.total, bh)
			dirv.y += (arc_y(prog + 0.01, sp.total, bh) - arc_y(prog, sp.total, bh)) / (0.01 * maxf(float(sp.total) * dt, 1e-3))
		if dirv.length() < 1.0:
			dirv = Vector2(1.0, 0.0)
		dirv = dirv.normalized()
		var pz: float = float(sp.z) + Z_SHOT
		var lane: Color = VfxShots.lane_of(S, int(sp.owner))
		var look: Dictionary = VfxShots.look_of(sp)
		var rad: float = look["rad"]
		var tail: float = look["tail"]
		shots_drawn += 1
		var tcol: Color = lane
		tcol.a = alpha * 0.8
		n = _put(n, Vector2(px, py) - dirv * tail * 0.5, dirv, tail, rad * 1.5, pz - 0.6, tcol, 0.55, 0.04, SHAPE_STREAK)
		if look["halo"]:
			var hc: Color = lane
			hc.a = alpha * 0.7
			n = _put(n, Vector2(px, py), Vector2(1.0, 0.0), rad * 3.0, rad * 3.0, pz - 0.3, hc, maxf(0.06, 1.6 * minpx / (rad * 1.5)), 0.0, SHAPE_RING)
		var rim: Color = lane.darkened(0.35)
		rim.a = alpha
		n = _put(n, Vector2(px, py), Vector2(1.0, 0.0), rad * 2.0, rad * 2.0, pz, rim, 1.0, 0.0, SHAPE_RING)
		var body: Color = lane
		body.a = alpha
		n = _put(n, Vector2(px, py), Vector2(1.0, 0.0), rad * 1.55, rad * 1.55, pz + 0.2, body, 1.0, 0.0, SHAPE_RING)
		var core: Color = lane.lightened(0.18)
		core.a = alpha
		n = _put(n, Vector2(px, py), Vector2(1.0, 0.0), rad * 0.8, rad * 0.8, pz + 0.4, core, 1.0, 0.0, SHAPE_RING)
	# The short effects the events call for.
	for e: VfxShots.Fx in sh.fx:
		if n >= CAP - 14:
			break
		var rx: float = SimWrap.sdx(cam_x, e.x)
		if absf(rx) > half_w + e.size * 2.0:
			continue
		var st: float = maxf(e.age - (1.0 - a), 0.0)
		var u: float = clampf(st / e.life, 0.0, 1.0)
		var ez: float = e.z + Z_FX
		var eo: float = 1.0 - pow(1.0 - u, 2.0)
		match e.kind:
			"flash":
				var fr: float = e.size * (0.45 + 0.55 * eo)
				var fc: Color = e.col
				fc.a = alpha * pow(1.0 - u, 1.3)
				n = _put(n, Vector2(rx, e.y), Vector2(1.0, 0.0), fr * 2.0, fr * 2.0, ez, fc, 1.0, 0.0, SHAPE_RING)
			"ring":
				var rr: float = lerpf(e.size * 0.35, e.size, eo)
				var rc: Color = e.col
				rc.a = alpha * 0.85 * pow(1.0 - u, 1.4)
				n = _put(n, Vector2(rx, e.y), Vector2(1.0, 0.0), rr * 2.0, rr * 2.0, ez + 0.2, rc, maxf(0.07, 1.6 * minpx / maxf(rr, 1.0)), 0.0, SHAPE_RING)
			"splash":
				# A fan of short lines running back toward the shooter off the guard.
				for k in range(5):
					var ang: float = (float(k) - 2.0) * 0.42
					var dv: Vector2 = Vector2(e.dx * cos(ang), sin(ang) + 0.15).normalized()
					var d0: float = e.size * (0.25 + 0.75 * eo)
					var ln: float = e.size * 0.55 * (1.0 - u * 0.6)
					var sc: Color = e.col
					sc.a = alpha * 0.9 * (1.0 - u)
					n = _put(n, Vector2(rx, e.y) + dv * (d0 - ln * 0.5), dv, ln, maxf(6.0, minpx * 1.5), ez, sc, 0.5, 0.05, SHAPE_STREAK)
			"burst":
				# A trade: a ring in each colour and eight short lines out of the point.
				var br: float = lerpf(e.size * 0.3, e.size, eo)
				var c1: Color = e.col
				c1.a = alpha * 0.9 * pow(1.0 - u, 1.3)
				var c2: Color = e.col2
				c2.a = c1.a
				n = _put(n, Vector2(rx - 6.0, e.y), Vector2(1.0, 0.0), br * 2.0, br * 2.0, ez, c1, maxf(0.07, 1.6 * minpx / maxf(br, 1.0)), 0.0, SHAPE_RING)
				n = _put(n, Vector2(rx + 6.0, e.y), Vector2(1.0, 0.0), br * 1.7, br * 1.7, ez + 0.2, c2, maxf(0.07, 1.6 * minpx / maxf(br, 1.0)), 0.0, SHAPE_RING)
				for k in range(8):
					var an: float = TAU * float(k) / 8.0 + 0.2
					var dv2: Vector2 = Vector2(cos(an), sin(an))
					var d1: float = e.size * (0.2 + 0.8 * eo)
					var l2: float = e.size * 0.4 * (1.0 - u * 0.5)
					var lc: Color = c1 if k % 2 == 0 else c2
					n = _put(n, Vector2(rx, e.y) + dv2 * (d1 - l2 * 0.5), dv2, l2, maxf(6.0, minpx * 1.5), ez + 0.4, lc, 0.5, 0.05, SHAPE_STREAK)
	count = n
	multimesh.visible_instance_count = n
	if n > 0:
		multimesh.buffer = _buf


## The charge at the forearm of the arm toward the rival: plates stacking along it (the Anti-hero) or thin rings stacking along it
## (the others), more of them as the charge builds; a pulse ring along the forearm when it is full. Never a sphere in a palm.
func _hand(n: int, S: SimState, host, slot: int, c: VfxShots.Charge, lvl: float, rel: float, a: float, bh: float, minpx: float, alpha: float) -> int:
	var f = S.fighters[slot]
	var pose: Vector3 = host.fighter_pose(slot, a)
	var fz: float = host.fighter_z(slot, a)
	var face: float = float(f.face)
	var col: Color = VfxAura.lane_color(String(f.aura))
	var chest: Vector2 = Vector2(rel, pose.y + VfxLook.CHEST_Y)
	var elbow: Vector2 = chest + Vector2(face * 0.16 * bh, -0.10 * bh)
	var hand: Vector2 = chest + Vector2(face * 0.66 * bh, 0.0)
	var along: Vector2 = (hand - elbow).normalized()
	var perp: Vector2 = Vector2(-along.y, along.x)
	var pieces: int = 1 + int(floor(lvl * 5.0 + 0.001))
	var z: float = fz + Z_HAND
	for k in range(pieces):
		if n >= CAP - 8:
			break
		var t: float = (float(k) + 0.5) / 6.0 + 0.05
		var at: Vector2 = elbow.lerp(hand, t)
		var born: float = clampf(lvl * 5.0 - float(k) + 1.0, 0.0, 1.0)          # each arrives over a fifth of the charge
		var pc: Color = col
		pc.a = alpha * (0.5 + 0.5 * born)
		if c.look == "plates":
			# A short plate across the forearm.
			n = _put(n, at, perp, 0.2 * bh * (0.6 + 0.4 * born), 0.075 * bh, z, pc.darkened(0.15), 1.0, 1.0, SHAPE_STREAK)
			var edge: Color = col
			edge.a = alpha * born
			n = _put(n, at + along * 0.02 * bh, perp, 0.16 * bh * born, 0.03 * bh, z + 0.2, edge, 1.0, 1.0, SHAPE_STREAK)
		else:
			# A thin ring round the forearm, seen edge-on as a narrow ellipse across it.
			var rr: float = 0.13 * bh * (0.7 + 0.3 * born)
			n = _put(n, at, along, rr * 0.7, rr * 2.0, z, pc, maxf(0.09, 1.6 * minpx / rr), 0.0, SHAPE_RING)
	if c.full and c.on and c.pulse < 14.0:
		var u: float = c.pulse / 14.0
		var pr: float = lerpf(0.2, 0.55, 1.0 - pow(1.0 - u, 2.0)) * bh
		var qc: Color = col
		qc.a = alpha * 0.8 * (1.0 - u)
		n = _put(n, hand, along, pr * 0.7, pr * 2.0, z + 0.4, qc, maxf(0.07, 1.6 * minpx / pr), 0.0, SHAPE_RING)
	return n


## What is left of this tick's movement at the frame, as an offset to subtract from the state's position: the state is the end of the
## last tick, so a frame between two ticks is a fraction of a tick back along the velocity, unless the shots stood still (a hit-stop,
## a pause) or this one was fired this tick (it sits at its start).
static func shot_back(sp, a: float, still: bool) -> Vector2:
	if still or sp.fresh:
		return Vector2.ZERO
	return Vector2(sp.vx, sp.vy) * ((1.0 - a) * SimConst.DT)


## A seeking shot's arc: how far above its line it is at progress 0..1 of its flight (zero at both ends).
static func arc_y(prog: float, total: int, bh: float) -> float:
	var h: float = VfxShots.p("shots", "arc_bh") * bh * clampf(float(total) / 10.0, VfxShots.p("shots", "arc_min"), VfxShots.p("shots", "arc_max"))
	return h * sin(PI * clampf(prog, 0.0, 1.0))


## One quad: centre c (camera-relative x, world y), unit direction dir for its x axis, size l by w, depth z.
func _put(n: int, c: Vector2, dir: Vector2, l: float, w: float, z: float, col: Color, cx: float, cy: float, shape: float) -> int:
	if n >= CAP:
		return n
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
