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
## A deflected shot is seen turning: the sim changes its owner and it flies back, and the colour changes with the owner. A shot that has
## been knocked loose (`deflected` above zero: the sim sends it off, today back at its first owner) also tumbles: a cross of light turning
## on it and a tail that wobbles, with the smoke trail (shots.gd) behind it. The mines of concept (shots.gd `Mine`, look only) are
## drawn here too, in the same draw call, each fighter's own look: the Anti-hero's plates, the others' thin rings.

const CAP := 380
const STRIDE := 20
const SHAPE_STREAK := 0.0
const SHAPE_RING := 1.0
const SHAPE_DISC := 2.0
const SHAPE_HEX := 4.0
const Z_SHOT := 4.0          # in front of the fighter plane, so a shot is not hidden behind a body it passes
const Z_FX := 6.0
const PLAY_LIFT := 30.0     # the beam plays sit in front of the ground dust (its puffs are put up to about z 26)
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
		if int(sp.mode) == SimShots.MINE:
			continue          # a mine is not a shot in flight: it is drawn below, by its own look
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
		var tumbling: bool = (int(sp.deflected) > 0 or bool(sp.wild)) and hub.explosions_enabled
		var spin: float = (float(sh.clock) + a) * 0.55 + float(sp.id)
		if tumbling and not hub.reduced_motion:
			dirv = dirv.rotated(sin(spin * 0.8) * 0.35)
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
		if tumbling:
			# Tumbling: a cross of light turning on it (still, at a slant, with reduced motion).
			var ang0: float = 0.6 if hub.reduced_motion else spin
			var xc: Color = lane.lightened(0.1)
			xc.a = alpha * 0.9
			n = _put(n, Vector2(px, py), Vector2(cos(ang0), sin(ang0)), rad * 3.4, rad * 0.5, pz + 0.5, xc, 1.0, 1.0, SHAPE_STREAK)
			n = _put(n, Vector2(px, py), Vector2(cos(ang0 + PI * 0.5), sin(ang0 + PI * 0.5)), rad * 2.2, rad * 0.4, pz + 0.5, xc, 1.0, 1.0, SHAPE_STREAK)
	# The beam plays: a crossing beam's head, the cues' effects, a walk or a wade in progress.
	if hub.beamplay_enabled:
		n = _beamplay(n, S, hub, host, cam_x, half_w, a, bh, minpx, alpha)
	# The mines (concept).
	n = _mines(n, S, hub, sh, cam_x, half_w, a, bh, minpx, alpha)
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
			"mark":
				# Where a wild shot will come down: a thin flat ring on the ground that closes in as it flies.
				var mr: float = lerpf(e.size * 1.25, e.size * 0.35, u)
				var mc: Color = e.col
				mc.a = alpha * 0.4 * smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.85, 1.0, u))
				n = _put(n, Vector2(rx, e.y + 6.0), Vector2(1.0, 0.0), mr * 2.0, mr * 2.0 * 0.28, ez - 1.0, mc, maxf(0.05, 1.6 * minpx / maxf(mr, 1.0)), 0.0, SHAPE_RING)
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


## A hard-edged wedge: from base, along dir, length l, width w (narrow at the tip, wide at the back, brightest at the tip).
func _wedge(n: int, base: Vector2, dir: Vector2, l: float, w: float, z: float, col: Color) -> int:
	return _put(n, base + dir * (l * 0.5), dir, l, w, z, col, 0.04, 0.5, SHAPE_STREAK)


## A thin ring seen edge-on across dir: an ellipse short along dir (a share of its height) and size tall across it.
func _across(n: int, c: Vector2, dir: Vector2, size: float, along: float, z: float, col: Color, minpx: float) -> int:
	return _put(n, c, dir, size * along, size, z, col, maxf(0.05, 1.6 * minpx / maxf(size * 0.5, 1.0)), 0.0, SHAPE_RING)


## The beam plays (beamplay.gd). All hard-edged wedges and thin rings in the lane colour of whose they are.
func _beamplay(n: int, S: SimState, hub: VfxHub, host, cam_x: float, half_w: float, a: float, bh: float, minpx: float, alpha: float) -> int:
	var bp: VfxBeamPlay = hub.beamplay
	var al: float = alpha * VfxBeamPlay.p("beamplay", "alpha")
	var z0: float = Z_FX + 1.0 + PLAY_LIFT
	# A beam crossing: its head leads it, so it is seen to travel.
	for b in S.beams:
		if n >= CAP - 30:
			break
		if not VfxBeamPlay.crossing(b):
			continue
		var slot: int = S.fighters.find(b.A)
		var lane: Color = VfxBeamPlay.lane_of(S, slot)
		var s0: float = float(b.p) * float(b.len)
		var rx0: float = SimWrap.sdx(cam_x, float(b.ox)) + float(b.ux) * s0
		if absf(rx0) > half_w + 8.0 * bh:
			continue
		var hd := Vector2(rx0, float(b.oy) + float(b.uy) * s0)
		var dv := Vector2(float(b.ux), float(b.uy))
		var pulse: float = 1.0 if hub.reduced_motion else 0.8 + 0.2 * sin(TAU * (float(bp.clock) + a) / 6.0)
		var c1: Color = lane
		c1.a = al * 0.85 * pulse
		n = _wedge(n, hd - dv * 24.0, dv, VfxBeamPlay.p("beamplay", "head_len"), VfxBeamPlay.p("beamplay", "head_w") * (0.8 + 0.1 * float(b.pw)), float(b.oz) + z0, c1)
		var c2: Color = lane.lightened(0.18)
		c2.a = al * pulse
		n = _wedge(n, hd - dv * 10.0, dv, VfxBeamPlay.p("beamplay", "head_len") * 0.62, VfxBeamPlay.p("beamplay", "head_w") * 0.4, float(b.oz) + z0 + 0.1, c2)
		var c3: Color = lane
		c3.a = al * 0.6
		n = _across(n, hd + dv * 6.0, dv, VfxBeamPlay.p("beamplay", "head_ring"), 0.34, float(b.oz) + z0 - 0.2, c3, minpx)
	# The effects the cues made.
	for e: VfxBeamPlay.Fx in bp.fx:
		if n >= CAP - 14:
			break
		var rx: float = SimWrap.sdx(cam_x, e.x)
		if absf(rx) > half_w + 6.0 * bh:
			continue
		var st: float = maxf(e.age - (1.0 - a), 0.0)
		var u: float = clampf(st / e.life, 0.0, 1.0)
		var eo: float = 1.0 - pow(1.0 - u, 2.0)
		var c := Vector2(rx, e.y)
		var dv2 := Vector2(e.dx, e.dy)
		var pv := Vector2(-e.dy, e.dx)
		var ez: float = e.z + z0
		var fa: float = al * (1.0 - u)
		match e.kind:
			"wake":
				var wc: Color = e.col
				wc.a = al * 0.5 * (1.0 - u)
				n = _across(n, c, dv2, e.size * lerpf(0.8, 1.3, eo), 0.3, ez - 0.4, wc, minpx)
			"launch":
				var lc: Color = e.col
				lc.a = fa
				n = _wedge(n, c, dv2, lerpf(40.0, e.size, eo), 54.0 * (1.0 - 0.6 * u), ez, lc)
				var lr: Color = e.col
				lr.a = fa * 0.7
				n = _across(n, c + dv2 * 20.0, dv2, lerpf(60.0, 130.0, eo), 0.3, ez - 0.2, lr, minpx)
			"sweep":
				# A slash: wedges at the angles it has swept through, the newest the brightest, then a ring at his hand.
				for k in range(4):
					var tk: float = clampf(eo - 0.14 * float(k), 0.0, 1.0)
					var ang: float = lerpf(e.a0, e.a1, tk)
					var sd := Vector2(cos(ang), sin(ang))
					if k == 0:
						n = _wedge(n, c + sd * 30.0, sd, e.size + 14.0, 50.0, ez - 0.5, Color(0.04, 0.02, 0.1, al * (1.0 - u) * 0.6))
					var sc: Color = e.col if k == 0 else e.col.lerp(e.col2, 0.35)
					sc.a = al * (1.0 - u * 0.7) * (1.0 - 0.22 * float(k))
					n = _wedge(n, c + sd * 36.0, sd, e.size * (1.0 - 0.1 * float(k)), 34.0 * (1.0 - 0.15 * float(k)), ez + 0.05 * float(k), sc)
				var sr: Color = e.col2
				sr.a = fa * 0.6
				n = _across(n, c, Vector2(cos(e.a1), sin(e.a1)), lerpf(70.0, 150.0, eo), 0.35, ez - 0.3, sr, minpx)
			"part":
				# The beam parts round him: two wedges slide apart along the forks' lines, with a tall ring across him.
				var ang0: float = atan2(e.dy, e.dx)
				for sg in [-1.0, 1.0]:
					var pa: float = ang0 + sg * 20.0 * PI / 180.0
					var pd := Vector2(cos(pa), sin(pa))
					n = _wedge(n, c + pv * (sg * 50.0 * eo) - pd * 6.0, pd, lerpf(60.0, e.size * 1.6 + 12.0, eo), 64.0, ez - 0.5, Color(0.04, 0.02, 0.1, fa * 0.65))
					var pc: Color = e.col
					pc.a = fa
					n = _wedge(n, c + pv * (sg * 50.0 * eo), pd, lerpf(54.0, e.size * 1.6, eo), 70.0, ez, pc)
					var pw: Color = Color(1.0, 1.0, 1.0, fa * 0.9)
					n = _wedge(n, c + pv * (sg * 50.0 * eo), pd, lerpf(40.0, e.size * 1.2, eo), 26.0, ez + 0.2, pw)
				var pr: Color = e.col2
				pr.a = fa * 0.7
				n = _across(n, c, dv2, lerpf(90.0, 170.0, eo), 0.3, ez - 0.3, pr, minpx)
			"land":
				# He arrives against the attacker: a flat ring on the ground and a second inside it.
				var rr: float = lerpf(e.size * 0.4, e.size, eo)
				var lr2: Color = e.col
				lr2.a = fa
				n = _put(n, c, Vector2(1.0, 0.0), rr * 2.0, rr * 2.0 * 0.28, ez, lr2, maxf(0.05, 1.6 * minpx / maxf(rr, 1.0)), 0.0, SHAPE_RING)
				var lr3: Color = e.col2
				lr3.a = fa * 0.6
				n = _put(n, c, Vector2(1.0, 0.0), rr * 1.2, rr * 1.2 * 0.28, ez + 0.1, lr3, maxf(0.07, 1.6 * minpx / maxf(rr * 0.6, 1.0)), 0.0, SHAPE_RING)
			"cut":
				# The beam is cut where it had got to: lines burst back from the cut and a ring across it.
				for k in range(5):
					var ca: float = atan2(e.dy, e.dx) + (float(k) - 2.0) * 0.45
					var cd := Vector2(cos(ca), sin(ca))
					var cc: Color = e.col if k % 2 == 0 else e.col2
					cc.a = fa
					n = _wedge(n, c + cd * lerpf(10.0, 40.0, eo), cd, lerpf(24.0, e.size * 0.8, eo), 14.0, ez, cc)
				var cr: Color = e.col
				cr.a = fa * 0.8
				n = _across(n, c, Vector2(-e.dx, -e.dy), lerpf(70.0, 150.0, eo), 0.3, ez - 0.2, cr, minpx)
			"answer":
				# His answer runs out along the line to where the beam was cut.
				var to := Vector2(SimWrap.sdx(cam_x, e.x1), e.y1)
				var dd: Vector2 = to - c
				var dl: float = maxf(dd.length(), 1.0)
				var ad: Vector2 = dd / dl
				var head: Vector2 = c + ad * (dl * eo)
				var ac: Color = e.col
				ac.a = al * (1.0 - smoothstep(0.7, 1.0, u))
				n = _wedge(n, head - ad * minf(e.size, dl * eo), ad, minf(e.size, dl * eo + 10.0), 32.0, ez, ac)
	# A walk or a wade in progress, on the defender and following him.
	for si in range(mini(2, S.fighters.size())):
		var w: VfxBeamPlay.Walk = bp.walks[si]
		if not (w.on or w.fade > 0.0):
			continue
		if n >= CAP - 14:
			break
		var fx: float = host.fighter_x(si, a)
		var rxw: float = SimWrap.sdx(cam_x, fx)
		if absf(rxw) > half_w + 6.0 * bh:
			continue
		var pose: Vector3 = host.fighter_pose(si, a)
		var fzw: float = host.fighter_z(si, a)
		var toward: float = 1.0 if SimWrap.sdx(S.fighters[si].x, S.fighters[1 - si].x) >= 0.0 else -1.0
		var fwd := Vector2(toward, 0.0)
		var chest: Vector2 = Vector2(rxw, pose.y + VfxLook.CHEST_Y)
		var vis: float = 1.0 if w.on else w.fade / 6.0
		var beamc: Color = VfxBeamPlay.lane_of(S, 1 - si)
		var selfc: Color = VfxBeamPlay.lane_of(S, si)
		var ww: float = (float(bp.clock) + a)
		var zw: float = fzw + z0
		if w.look == "walk":
			# Clean: a tall thin bow wave in front of him and the beam parting round him in two long wedges.
			var bc: Color = beamc
			bc.a = al * 0.75 * vis
			n = _across(n, chest + fwd * 34.0, fwd, VfxBeamPlay.p("beamplay", "wave_h"), 0.3, zw, bc, minpx)
			for sg in [-1.0, 1.0]:
				var pd2 := Vector2(-toward * cos(0.42), sg * sin(0.42)).normalized()
				var wc2: Color = beamc
				wc2.a = al * 0.6 * vis
				n = _wedge(n, chest + fwd * 40.0 + Vector2(0.0, sg * 26.0), pd2, 150.0, 22.0, zw - 0.1, wc2)
		else:
			# Rough: a fan of short guard blades in front of him, jittering, and a spray of short lines peeling back along the beam.
			for k in range(3):
				var ja: float = (float(k) - 1.0) * 0.8 + (0.0 if hub.reduced_motion else sin(ww * 1.7 + float(k) * 2.0) * 0.12)
				var gd := Vector2(toward * cos(ja), sin(ja))
				var gc: Color = selfc
				gc.a = al * 0.9 * vis
				n = _wedge(n, chest + gd * 26.0, gd, 84.0, 24.0, zw, gc)
			for k in range(4):
				var ra: float = (float(k) - 1.5) * 0.55
				var jit: float = 0.0 if hub.reduced_motion else fposmod(ww * 0.37 + float(k) * 0.31, 1.0)
				var rd2 := Vector2(-toward * cos(ra), sin(ra))
				var rc2: Color = beamc
				rc2.a = al * 0.7 * vis * (1.0 - jit * 0.5)
				n = _wedge(n, chest + fwd * 30.0 + rd2 * (20.0 + 60.0 * jit), rd2, 56.0, 9.0, zw - 0.1, rc2)
	return n


## The mines, each fighter's own look, and never a sphere (Legal, RL-062): the others' is a hexagonal plate (a flat hexagon with a raised
## inner hexagon, a thin ring round it), the Anti-hero's a faceted caltrop (three tapering spikes round a small hexagonal hub). A hovering
## one bobs, with a faint line down to a flat shadow on the ground, face-on; a ground one lies flat (the plate squashed) or stands on its
## spikes. Arming: the plate's ring and the spikes close in from far out while they fade up (dim, then bright); armed: a slow breathing
## of the inner hexagon; the fuse (about to go): a quick blink, the inner hexagon swelling, and one thin warning ring running out to the
## blast's radius. One mine at a time per spot: no row of matching shapes is staged. The lane colour only, never white, gold or red.
func _mines(n: int, S: SimState, hub: VfxHub, sh: VfxShots, cam_x: float, half_w: float, a: float, bh: float, minpx: float, alpha: float) -> int:
	# The concept list (tools and the events a sim may send), then the real ones: every entry of S.shots whose mode is MINE.
	for m: VfxShots.Mine in sh.mines:
		n = _draw_mine(n, m, 1.0, S, hub, sh, cam_x, half_w, a, bh, minpx, alpha)
	for sp in S.shots:
		if int(sp.mode) != SimShots.MINE:
			continue
		var m := VfxShots.mine_of(S, sp, sh)
		var life_k: float = lerpf(0.35, 1.0, smoothstep(0.0, 0.08, float(sp.left) / maxf(float(sp.total), 1.0)))    # it dims over its last seconds, then fizzles
		n = _draw_mine(n, m, life_k, S, hub, sh, cam_x, half_w, a, bh, minpx, alpha)
	return n


## One mine. life_k: how bright it is for its age (1 until its last seconds).
func _draw_mine(n: int, m: VfxShots.Mine, life_k: float, S: SimState, hub: VfxHub, sh: VfxShots, cam_x: float, half_w: float, a: float, bh: float, minpx: float, alpha: float) -> int:
	if n >= CAP - 16:
		return n
	var rx: float = SimWrap.sdx(cam_x, m.x)
	if absf(rx) > half_w + 3.0 * bh:
		return n
	var lane: Color = VfxShots.lane_of(S, m.owner)
	var villain: bool = String(S.fighters[m.owner].role) == "villain"
	var age: float = m.age + (0.0 if sh.last_frozen else a)
	var hover: bool = m.mode == "hover"
	var gy: float = WorldTerrain.groundY(S, m.x)
	var bob: float = 0.0 if (not hover or hub.reduced_motion) else sin(TAU * (float(sh.clock) + a) / 90.0 + float(m.id)) * 5.0
	var c := Vector2(rx, m.y + bob)
	var z: float = m.z + Z_SHOT - 0.5
	var close: float = 1.0
	var ak: float = 1.0
	var core_k: float = 1.0
	var blink: float = 1.0
	var grow: float = 1.0
	match m.state:
		"arming":
			var u: float = clampf(age / VfxShots.MINE_ARM_TICKS, 0.0, 1.0)
			close = lerpf(2.4, 1.0, 1.0 - pow(1.0 - u, 2.0))
			ak = lerpf(0.25, 1.0, u)
			grow = lerpf(0.4, 1.0, u)
		"armed":
			var br: float = 0.0 if hub.reduced_motion else sin(TAU * age / 60.0)
			close = 1.0 + 0.03 * br
			core_k = 0.9 + 0.1 * br
		"trigger":
			var uf: float = clampf(age / VfxShots.MINE_FUSE_TICKS, 0.0, 1.0)
			close = lerpf(1.0, 0.8, uf)
			core_k = lerpf(1.0, 1.4, uf)
			blink = 1.0 if (hub.reduced_motion or int(age / 4.0) % 2 == 0) else 0.45
			var wr: float = lerpf(40.0, m.radius, 1.0 - pow(1.0 - uf, 2.0))
			var wc: Color = lane
			wc.a = alpha * 0.55 * (1.0 - uf * 0.5)
			n = _put(n, Vector2(rx, m.y) if hover else Vector2(rx, gy + 12.0), Vector2(1.0, 0.0), wr * 2.0, wr * (2.0 if hover else 0.5), z - 0.6, wc, maxf(0.03, 1.6 * minpx / wr), 0.0, SHAPE_RING)
	var a_all: float = alpha * ak * blink * life_k
	# What shows it hovers, or sits.
	if hover:
		var sc: Color = lane.darkened(0.55)
		sc.a = alpha * 0.28
		n = _put(n, Vector2(rx, gy + 5.0), Vector2(1.0, 0.0), 96.0, 22.0, z - 1.4, sc, 1.0, 0.0, SHAPE_RING)
		var gap: float = maxf((c.y - 30.0) - (gy + 8.0), 0.0)
		var steps: int = clampi(int(gap / 34.0), 0, 4)
		for k in range(steps):
			var lc: Color = lane
			lc.a = alpha * 0.32 * (1.0 - float(k) / float(maxi(steps, 1)) * 0.6)
			n = _put(n, Vector2(rx, c.y - 32.0 - float(k) * 34.0 - 9.0), Vector2(0.0, 1.0), 18.0, maxf(3.0, minpx), z - 1.0, lc, 0.5, 0.5, SHAPE_STREAK)
	var flat_k: float = 1.0 if hover else 0.3          # a plate on the ground lies flat
	var base: Vector2 = c if hover else Vector2(rx, gy + 9.0)
	var plate: Color = lane.darkened(0.45)
	plate.a = a_all * 0.92
	var rimc: Color = lane
	rimc.a = a_all
	var inner: Color = lane.lightened(0.14 + 0.12 * (core_k - 1.0))
	inner.a = a_all
	if villain:
		# A faceted caltrop: three tapering spikes round a small hexagonal hub; in the air a spike up and two down, on the ground one up and two
		# low to the sides.
		var angs: Array = [PI * 0.5, PI * 1.17, PI * 1.83] if hover else [PI * 0.5, PI * 0.12, PI * 0.88]
		var ln: float = 40.0 * grow
		for an in angs:
			var dv: Vector2 = Vector2(cos(an), sin(an))
			var sp0: Color = lane.darkened(0.2)
			sp0.a = a_all
			n = _put(n, base + dv * (ln * 0.5 + 6.0), dv, ln, 15.0, z + 0.1, sp0, 0.04, 0.5, SHAPE_STREAK)
			var sp1: Color = lane
			sp1.a = a_all * 0.9
			n = _put(n, base + dv * (ln * 0.5 + 8.0), dv, ln * 0.8, 5.0, z + 0.2, sp1, 0.04, 0.5, SHAPE_STREAK)
		n = _put(n, base, Vector2(1.0, 0.0), 30.0 * close, 30.0 * 0.866 * close, z + 0.3, plate, maxf(0.09, 1.6 * minpx / 15.0), 1.0, SHAPE_HEX)
		n = _put(n, base, Vector2(1.0, 0.0), 30.0 * close, 30.0 * 0.866 * close, z + 0.35, rimc, maxf(0.14, 1.6 * minpx / 15.0), 0.0, SHAPE_HEX)
		n = _put(n, base, Vector2(1.0, 0.0), 14.0 * core_k, 14.0 * 0.866 * core_k, z + 0.4, inner, 0.15, 1.0, SHAPE_HEX)
	else:
		# A hexagonal plate with a raised inner hexagon and a thin ring round it (flat on the ground, face-on in the air).
		var rr: float = 46.0 * close
		var rc: Color = lane
		rc.a = a_all * 0.55
		n = _put(n, base, Vector2(1.0, 0.0), rr * 2.0, rr * 2.0 * flat_k, z - 0.2, rc, maxf(0.04, 1.6 * minpx / rr), 0.0, SHAPE_RING)
		n = _put(n, base, Vector2(1.0, 0.0), 54.0, 54.0 * 0.866 * flat_k, z + 0.1, plate, maxf(0.07, 1.6 * minpx / 27.0), 1.0, SHAPE_HEX)
		n = _put(n, base, Vector2(1.0, 0.0), 54.0, 54.0 * 0.866 * flat_k, z + 0.15, rimc, maxf(0.1, 1.6 * minpx / 27.0), 0.0, SHAPE_HEX)
		n = _put(n, base, Vector2(1.0, 0.0), 28.0 * core_k, 28.0 * 0.866 * core_k * flat_k, z + 0.3, inner, 0.14, 1.0, SHAPE_HEX)
	return n


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
