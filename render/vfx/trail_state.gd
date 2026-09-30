class_name VfxTrailState
extends RefCounted
## One fighter's motion-trail state (docs/vfx/plan.md section 2): a short history of where it was, an eased speed
## intensity k, and the wind marks it has left in the world. Steps once per unfrozen sim tick from the fighter's own
## displacement, so it works for free flight, launches, slides and rushes alike. Reads the fighter; never writes it.
## Its random numbers come from the caller's cosmetic stream (vfx.trail), a fixed number of draws per tick.

class Mark:
	var x: float = 0.0        # centre, world x (wrapped)
	var y: float = 0.0
	var dx: float = 1.0       # unit direction along the flight
	var dy: float = 0.0
	var len: float = 0.0      # world units
	var z: float = 0.0
	var age: float = 0.0
	var life: float = 0.5

var hx := PackedFloat64Array()     # history, oldest first: one point per unfrozen tick (wrapped x)
var hy := PackedFloat64Array()
var k: float = 0.0                 # eased intensity 0..1
var speed: float = 0.0             # world units a second over the last unfrozen tick
var speed_bh: float = 0.0
var sspeed: float = 0.0            # speed that decays instead of dropping, so a stopping fighter's ribbon fades out
var dir := Vector2(1.0, 0.0)       # unit direction of the last displacement
var marks: Array = []              # Mark
var spawned: int = 0               # counters for the tests
var max_marks_seen: int = 0
var max_k: float = 0.0
var _has_prev: bool = false
var _px: float = 0.0
var _py: float = 0.0


func reset() -> void:
	hx.clear()
	hy.clear()
	marks.clear()
	k = 0.0
	speed = 0.0
	speed_bh = 0.0
	sspeed = 0.0
	dir = Vector2(1.0, 0.0)
	_has_prev = false
	spawned = 0
	max_marks_seen = 0
	max_k = 0.0


## One unfrozen tick. f is the sim's fighter; rng is the vfx.trail stream; quality a VfxLook.Q_* level.
func step(S: SimState, f, dt: float, rng: SimRng, quality: int, reduced: bool) -> void:
	var dx: float = 0.0
	var dy: float = 0.0
	if _has_prev:
		dx = SimWrap.sdx(_px, f.x)
		dy = f.y - _py
	var d: float = sqrt(dx * dx + dy * dy)
	if d > 3000.0:
		# A teleport (a new match, a snapped position), not a flight: start again.
		hx.clear()
		hy.clear()
		marks.clear()
		k = 0.0
		sspeed = 0.0
		d = 0.0
		dx = 0.0
		dy = 0.0
	_px = f.x
	_py = f.y
	_has_prev = true
	speed = d / dt
	speed_bh = speed / VfxLook.BH
	sspeed = maxf(speed, sspeed * exp(-dt / VfxLook.K_DOWN_TAU))
	if d > 1e-6:
		dir = Vector2(dx / d, dy / d)
	var target: float = smoothstep(VfxLook.V_ON, VfxLook.V_FULL, speed_bh)
	if f.state == "down" or f.hidden:
		target = 0.0
	elif VfxLook.RUSH_GATE and f.rush != null and speed_bh < VfxLook.V_FULL:
		target = 0.0
	var tau: float = VfxLook.K_UP_TAU if target > k else VfxLook.K_DOWN_TAU
	k += (target - k) * (1.0 - exp(-dt / tau))
	max_k = maxf(max_k, k)
	hx.append(f.x)
	hy.append(f.y)
	if hx.size() > VfxLook.HIST_MAX:
		hx.remove_at(0)
		hy.remove_at(0)
	# Wind marks: age, then maybe spawn. The draws are fixed per tick whenever a mark could appear, whatever the
	# quality, so the stream does not depend on the frame rate or on the level.
	for i in range(marks.size() - 1, -1, -1):
		var m: Mark = marks[i]
		m.age += dt
		if m.age >= m.life:
			marks.remove_at(i)
	if k > 0.15:
		var r0: float = rng.next()
		var r1: float = rng.next()
		var r2: float = rng.next()
		var r3: float = rng.next()
		var r4: float = rng.next()
		var r5: float = rng.next()
		var cap: int = VfxLook.MARKS_BY_QUALITY[clampi(quality, 0, 2)]
		if not reduced and marks.size() < cap and r0 < VfxLook.MARK_P * k:
			var ahead: float = lerpf(VfxLook.MARK_AHEAD_MIN_BH, VfxLook.MARK_AHEAD_MAX_BH, r1) * VfxLook.BH
			var off: float = lerpf(VfxLook.MARK_OFF_MIN_BH, VfxLook.MARK_OFF_MAX_BH, r2) * VfxLook.BH * (1.0 if r3 < 0.5 else -1.0)
			var perp := Vector2(-dir.y, dir.x)
			var m := Mark.new()
			m.x = SimWrap.wrap(f.x + dir.x * ahead + perp.x * off)
			m.y = f.y + VfxLook.CHEST_Y + dir.y * ahead + perp.y * off
			m.dx = dir.x
			m.dy = dir.y
			m.len = clampf(speed * VfxLook.MARK_LEN_S, VfxLook.MARK_LEN_MIN_BH * VfxLook.BH, VfxLook.MARK_LEN_MAX_BH * VfxLook.BH)
			# Lives until the fighter has passed it and gone on out of the frame, at about this speed.
			m.life = clampf((ahead + VfxLook.MARK_BEHIND_BH * VfxLook.BH) / maxf(speed, 1.0) * lerpf(0.85, 1.15, r4), VfxLook.MARK_LIFE_MIN, VfxLook.MARK_LIFE_MAX)
			m.z = lerpf(VfxLook.Z_MARK_MIN, VfxLook.Z_MARK_MAX, r5)
			if m.y > WorldTerrain.groundY(S, m.x) + 10.0:
				marks.append(m)
				spawned += 1
				max_marks_seen = maxi(max_marks_seen, marks.size())


## The ribbon's polyline from the head back along the path, resampled into `segs` equal-length straight segments
## (segs + 1 points). Points are (offset in x from the head along the shortest arc, world y). The head is the given
## interpolated position, which lies between the last two history points. Returns fewer points if there is no path yet.
func ribbon(head_x: float, head_y: float, length: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, head_y))
	var acc: float = 0.0
	var prev := Vector2(0.0, head_y)
	var i: int = hx.size() - 2       # the newest point is this tick's position, ahead of the interpolated head
	while i >= 0 and acc < length:
		var p := Vector2(SimWrap.sdx(head_x, hx[i]), hy[i])
		var seg: float = prev.distance_to(p)
		if seg > 1e-6:
			if acc + seg >= length:
				pts.append(prev.lerp(p, (length - acc) / seg))
				acc = length
				break
			pts.append(p)
			acc += seg
			prev = p
		i -= 1
	if pts.size() < 2:
		return PackedVector2Array()
	# Resample by arc length into equal segments.
	var cum := PackedFloat32Array()
	cum.append(0.0)
	for j in range(1, pts.size()):
		cum.append(cum[j - 1] + pts[j - 1].distance_to(pts[j]))
	var total: float = cum[cum.size() - 1]
	var out := PackedVector2Array()
	var j: int = 0
	for s in range(segs + 1):
		var target: float = total * float(s) / float(segs)
		while j < cum.size() - 2 and cum[j + 1] < target:
			j += 1
		var span: float = cum[j + 1] - cum[j]
		var t: float = 0.0 if span < 1e-9 else clampf((target - cum[j]) / span, 0.0, 1.0)
		out.append(pts[j].lerp(pts[j + 1], t))
	return out
