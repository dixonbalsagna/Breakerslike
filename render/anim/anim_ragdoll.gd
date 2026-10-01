class_name AnimRagdoll
extends RefCounted
## The active ragdoll of the animation overhaul (docs/animation/overhaul-plan.md, unit A). Twelve angular degrees of freedom
## (data/anim/ragdoll.json) on springs around the posed target, added on top of the solved pose. It is driven by the body's own
## motion in the body frame (a streamer drag from the velocity, an inertial whip from the acceleration), by the tuck and brace
## targets the controller asks for, and by impulses (a crumple, a hit). It is stepped once per sim tick, never per frame, so the
## picture is the same in a replay at any frame rate, draws no random number and writes nothing to the sim.

const N := 12

static var loaded: bool = false
static var bone_a := PackedInt32Array()
static var bone_b := PackedInt32Array()
static var share_a := PackedFloat32Array()
static var is_x := PackedByteArray()
static var beta_c := PackedFloat32Array()
static var beta_s := PackedFloat32Array()
static var k_stiff := PackedFloat32Array()
static var k_loose := PackedFloat32Array()
static var damp := PackedFloat32Array()
static var drag := PackedFloat32Array()
static var inertia := PackedFloat32Array()
static var lo := PackedFloat32Array()
static var hi := PackedFloat32Array()
static var tsg := PackedFloat32Array()
static var tuck_t := PackedFloat32Array()
static var brace_t := PackedFloat32Array()
static var crumple_k := PackedFloat32Array()
static var v0: float = 1500.0
static var a0: float = 6000.0
static var a_max: float = 40000.0
static var gate: float = 0.25
static var free_rate: float = 6.0

var th := PackedFloat32Array()
var om := PackedFloat32Array()
var free: float = 0.0          # 0 the pose is in charge, 1 the body is loose
var out_w: float = 0.0         # how much of the motion is shown (it fades in and out)


static func setup() -> void:
	if loaded:
		return
	loaded = true
	AnimRig.setup()
	var d: Dictionary = AnimData.ragdoll
	var dofs: Array = d.get("dofs", [])
	bone_a.resize(N)
	bone_b.resize(N)
	for a in [share_a, beta_c, beta_s, k_stiff, k_loose, damp, drag, inertia, lo, hi, tsg, tuck_t, brace_t, crumple_k]:
		a.resize(N)
	is_x.resize(N)
	for i in range(mini(N, dofs.size())):
		var e: Dictionary = dofs[i]
		bone_a[i] = AnimRig.index[String(e.bone)]
		bone_b[i] = AnimRig.index[String(e.bone2)] if e.has("bone2") else -1
		share_a[i] = float(e.get("share", 1.0))
		is_x[i] = 1 if String(e.axis) == "x" else 0
		beta_c[i] = cos(float(e.beta))
		beta_s[i] = sin(float(e.beta))
		k_stiff[i] = float(e.k_stiff)
		k_loose[i] = float(e.k_loose)
		damp[i] = float(e.c)
		drag[i] = float(e.drag)
		inertia[i] = float(e.inertia)
		lo[i] = float(e.lo)
		hi[i] = float(e.hi)
		tsg[i] = float(e.tsg)
		tuck_t[i] = float(e.tuck)
		brace_t[i] = float(e.brace)
		crumple_k[i] = float(e.crumple)
	var dr: Dictionary = d.get("drive", {})
	v0 = float(dr.get("v0", 1500.0))
	a0 = float(dr.get("a0", 6000.0))
	a_max = float(dr.get("a_max", 40000.0))
	gate = float(dr.get("gate", 0.25))
	free_rate = float(dr.get("free_rate", 6.0))


func _init() -> void:
	setup()
	th.resize(N)
	om.resize(N)


## How much the body is moving on its own (for deciding whether to keep stepping).
func energy() -> float:
	var e: float = 0.0
	for i in range(N):
		e += absf(th[i]) + 0.05 * absf(om[i])
	return e


func reset() -> void:
	for i in range(N):
		th[i] = 0.0
		om[i] = 0.0
	free = 0.0
	out_w = 0.0


## One sim tick. v and a are the body's velocity (u/s) and non-gravitational acceleration (u/s^2) in the body frame (x
## forward, y up the body); free_t the looseness the regime asks for; tuck and brace 0 to 1; amp scales the drive (reduced
## motion).
func step(dt: float, v: Vector2, a: Vector2, free_t: float, tuck: float, brace: float, amp: float) -> void:
	free = move_toward(free, free_t, dt * free_rate)
	var sp: float = clampf(v.length() / v0, 0.0, 2.0)
	var h: float = dt * 0.5
	var g: float = gate + (1.0 - gate) * free
	for _s in range(2):
		for i in range(N):
			var kk: float = lerpf(k_stiff[i], k_loose[i], free)
			var target: float = tsg[i] * sp * free + tuck * tuck_t[i] + brace * brace_t[i]
			var nx: float = beta_c[i]
			var ny: float = beta_s[i]
			var drive: float = (-drag[i] * (v.x * nx + v.y * ny) / v0 - inertia[i] * (a.x * nx + a.y * ny) / a0) * g * amp
			var al: float = -kk * (th[i] - target) - damp[i] * om[i] + drive
			om[i] += al * h
			th[i] += om[i] * h
			if th[i] < lo[i]:
				th[i] = lo[i]
				om[i] = maxf(om[i], 0.0)
			elif th[i] > hi[i]:
				th[i] = hi[i]
				om[i] = minf(om[i], 0.0)


## An impulse on every degree of freedom along its crumple direction: a slam folds the body.
func crumple(sev: float, amp: float) -> void:
	for i in range(N):
		om[i] += crumple_k[i] * sev * amp


## An impulse on one degree of freedom (rad/s).
func kick(i: int, w: float) -> void:
	om[i] += w


## Adds the motion to the solved pose, shown at weight w.
func apply(q: Array[Quaternion], w: float) -> void:
	if w <= 0.001:
		return
	for i in range(N):
		var t: float = th[i] * w
		if absf(t) < 0.0005:
			continue
		var axis: Vector3 = Vector3(1, 0, 0) if is_x[i] == 1 else Vector3(0, 0, 1)
		var b2: int = bone_b[i]
		if b2 >= 0:
			var sa: float = share_a[i]
			q[bone_a[i]] = q[bone_a[i]] * Quaternion(axis, t * sa)
			q[b2] = q[b2] * Quaternion(axis, t * (1.0 - sa))
		else:
			q[bone_a[i]] = q[bone_a[i]] * Quaternion(axis, t)
