class_name CrowdFlight
extends RefCounted
## Evacuation, seen: people who flee a blow run away from it and are gone. World's `evacuate` event {b, x, z, n, cx,
## reason, owner} (docs/world/collateral-caps.md section 5) comes in the same tick as the building's popAlive falls.
## The planet view hands over the figures that just vanished. This decides which of them run. From a building a blow
## hit this frame (its `debris` event: the sim's damage always throws it), as many run as the building's events have
## reported fled, farthest from the blow first; the rest, nearest the blow, were casualties and are simply gone.
## From a building no blow hit, everyone who vanished left on foot (people die only by damage), so they all run at
## once, even before the event that reports them (World reports a building's fled people in lots of half a person). Then it animates the runners on sim time (so pause and hit-stop hold them): away from the
## event's x at a run, faster the closer they were, and drifting back behind the building row; a share look back once;
## each fades out at the end of its run (RenderLook.RUN_*). Runners reuse their own
## crowd instances; the crowd shader draws the run cycle and the fade from the instance colour (g: 1 - run, a: fade).
## Render-side only: reads the sim and the events, never writes either.

class Run:
	var t0: float      # sim time it started
	var x0: float
	var z0: float
	var dir: float     # +1 or -1 along x
	var speed: float
	var dur: float
	var look: float    # seconds into the run it looks back, or -1
	var dy: float      # the drawn ground at its depth minus the fighter-plane profile, at the start

var _evac := PackedFloat64Array()   # per building: people evacuated so far (the events' n)
var _cx := PackedFloat64Array()     # per building: the x of the latest blow they fled
var _ran := PackedInt32Array()      # per building: figures sent running so far
var _runs: Dictionary = {}          # crowd instance -> Run
var _hit_x: Array = []              # this frame's damage (debris) x, cleared after each step
var _blow_x: float = 0.0            # the latest blow's x (crater, scorch or damage), for flights not yet reported
var started: int = 0                # runners started this match (for tools)
var events_n: float = 0.0           # the evacuate events' n this match (for tools)


func reset(nb: int) -> void:
	_evac.resize(nb)
	_evac.fill(0.0)
	_cx.resize(nb)
	_cx.fill(0.0)
	_ran.resize(nb)
	_ran.fill(0)
	_runs.clear()
	_hit_x.clear()
	_blow_x = 0.0
	started = 0
	events_n = 0.0


## The evacuate events among one tick's fx events.
func consume(events: Array) -> void:
	for e in events:
		if e.type == "debris":
			_hit_x.append(e.x)
			_blow_x = e.x
			continue
		if e.type == "crater" or e.type == "scorch":
			_blow_x = e.x
			continue
		if e.type != "evacuate":
			continue
		var b: int = int(e.b)
		if b < 0 or b >= _evac.size():
			continue
		_evac[b] += float(e.n)
		_cx[b] = float(e.cx)
		events_n += float(e.n)


## Building bi (at bx)'s figures in slots (crowd instances) just vanished: its people fell to what its figures now
## show. gone: the people it has lost in all (dead or fled); vanished: its figures gone in all, these included. Starts
## the runners and returns the rest (the casualties), for the caller to hide.
func vanish(S: SimState, bi: int, bx: float, slots: Array, xs: PackedFloat64Array, zs: PackedFloat64Array, gone: float, vanished: int, ground: GroundField) -> Array:
	var hit: bool = false
	for hx in _hit_x:
		if absf(SimWrap.sdx(hx, bx)) < 1.0:
			hit = true
			break
	var want: int = slots.size()
	if hit:
		if gone <= 0.0 or _evac[bi] <= 0.0:
			return slots
		want = clampi(mini(vanished, int(roundf(_evac[bi]))) - _ran[bi], 0, slots.size())
		if want == 0:
			return slots
	var cx: float = _cx[bi] if _evac[bi] > 0.0 else _blow_x
	var order: Array = slots.duplicate()
	order.sort_custom(func(a, b): return absf(SimWrap.sdx(cx, xs[a])) > absf(SimWrap.sdx(cx, xs[b])))
	for k in range(want):
		var ci: int = order[k]
		_start(S, ci, xs[ci], zs[ci], cx, ground)
	_ran[bi] += want
	started += want
	return order.slice(want)


func running(ci: int) -> bool:
	return _runs.has(ci)


func count() -> int:
	return _runs.size()


func _start(S: SimState, ci: int, x: float, z: float, cx: float, ground: GroundField) -> void:
	var r := Run.new()
	var dx: float = SimWrap.sdx(cx, x)
	r.t0 = S.T
	r.x0 = x
	r.z0 = z
	r.dir = signf(dx) if absf(dx) > 1.0 else (1.0 if _h(ci, 0) < 0.5 else -1.0)
	var near: float = clampf(1.0 - absf(dx) / RenderLook.RUN_NEAR_R, 0.0, 1.0)
	r.speed = RenderLook.RUN_SPEED * (1.0 + RenderLook.RUN_NEAR * near) * (0.85 + 0.3 * _h(ci, 1))
	r.dur = RenderLook.RUN_TIME * (0.75 + 0.5 * _h(ci, 2))
	r.look = r.dur * (0.3 + 0.3 * _h(ci, 4)) if _h(ci, 3) < RenderLook.RUN_LOOK_SHARE else -1.0
	r.dy = ground.ground_at(S, x, z) - WorldTerrain.groundY(S, x)
	_runs[ci] = r


## Per frame: move every runner, and hide the ones whose run is over.
func step(S: SimState, mm: MultiMesh) -> void:
	_hit_x.clear()
	if _runs.is_empty():
		return
	var done: Array = []
	var yaw: float = deg_to_rad(RenderLook.RUN_YAW)
	var scale := Basis.from_scale(Vector3.ONE * RenderLook.CROWD_SCALE)
	for ci in _runs:
		var r: Run = _runs[ci]
		var t: float = S.T - r.t0
		if t >= r.dur:
			done.append(ci)
			continue
		var lk: float = clampf(t - r.look, 0.0, RenderLook.RUN_LOOK_S) if r.look >= 0.0 else 0.0
		var looking: bool = lk > 0.0 and lk < RenderLook.RUN_LOOK_S
		var d: float = r.speed * (maxf(t, 0.0) - 0.7 * lk)
		var x: float = r.x0 + r.dir * d
		var u: float = clampf(t / r.dur, 0.0, 1.0)
		var z: float = lerpf(r.z0, RenderLook.RUN_Z_END, u * u * (3.0 - 2.0 * u))
		var y: float = WorldTerrain.groundY(S, SimWrap.wrap(x)) + r.dy * maxf(0.0, 1.0 - d / 200.0)
		# Local +x where it runs (or, looking back, where it came from), turned a little toward it.
		var turn: float = yaw if (r.dir > 0.0) != looking else PI - yaw
		mm.set_instance_transform(ci, Transform3D(Basis(Vector3.UP, turn) * scale, Vector3(x, y, z)))
		mm.set_instance_color(ci, Color(1.0, 0.8 if looking else 0.0, 1.0, clampf((r.dur - t) / RenderLook.RUN_FADE, 0.0, 1.0)))
	for ci in done:
		var r: Run = _runs[ci]
		mm.set_instance_transform(ci, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(r.x0, 0.0, 0.0)))
		mm.set_instance_color(ci, Color.WHITE)
		_runs.erase(ci)


## A fixed hash in [0, 1) per figure and channel: the same look for a figure at any frame rate.
static func _h(i: int, k: int) -> float:
	var v: int = (i * 73856093) ^ (k * 19349663 + 83492791)
	v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
	v = v ^ (v >> 16)
	return float(v & 0xFFFFFF) / 16777216.0
