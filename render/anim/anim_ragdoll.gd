class_name AnimRagdoll
extends RefCounted
## The active ragdoll of the animation overhaul (docs/animation/overhaul-plan.md, unit A, with the shapes, the flail and the hit
## table of unit D). Twelve angular degrees of freedom (data/anim/ragdoll.json) on springs around the posed target, added on top
## of the solved pose. It is driven by the body's own motion in the body frame (a streamer drag from the velocity, an inertial
## whip from the acceleration), by the fighter's own shapes (a tuck, a brace, a skid and a crumple, from Art's silhouettes), by
## an early-launch limb flail, and by impulses (a crumple, a hit). It is stepped once per sim tick, never per frame, so the
## picture is the same in a replay at any frame rate, draws no random number and writes nothing to the sim.

const N := 12
const REGIONS := {"head": 0, "core": 1, "arms": 2, "legs": 3}

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
static var tuck_t := PackedFloat32Array()      # the generic shape, used when a fighter has none of its own
static var brace_t := PackedFloat32Array()
static var crumple_k := PackedFloat32Array()
static var flail_amp := PackedFloat32Array()
static var flail_hz := PackedFloat32Array()
static var flail_fade := Vector2(0.35, 1.2)
var shape_key: String = ""
var hit_k := PackedFloat32Array()               # per degree of freedom: the flinch multiplier of this fighter's shape (data/anim/shapes.json)
const REDUCED_LIMIT := 0.5               # reduced motion: every joint may turn only this share of its range
static var shapes: Dictionary = {}              # shape key -> {tuck, brace, skid, crumple: PackedFloat32Array}
static var shape_of: Dictionary = {}            # roster id -> shape key
static var hit_gain: float = 1.6
static var hit_kx := PackedFloat32Array()       # N x 4 (head, core, arms, legs)
static var hit_ky := PackedFloat32Array()
static var hit_kc := PackedFloat32Array()
static var hit_vx := PackedFloat32Array()
static var hit_vx_var := PackedInt32Array()     # 1 u, 2 u2
static var hit_kc_var := PackedInt32Array()     # 1 u, 2 u2, 3 one
static var v0: float = 1500.0
static var a0: float = 6000.0
static var a_max: float = 40000.0
static var gate: float = 0.25
static var free_rate: float = 6.0
static var tuck_spin := Vector2(10.0, 15.0)
static var tuck_max: float = 0.7
static var tuck_after := Vector2(0.25, 0.6)
static var brace_time := Vector2(0.08, 0.3)
static var skid_w: float = 0.6
static var crumple_down_w: float = 0.6

var th := PackedFloat32Array()
var om := PackedFloat32Array()
var free: float = 0.0          # 0 the pose is in charge, 1 the body is loose
var out_w: float = 0.0         # how much of the motion is shown (it fades in and out)
var w_tuck: float = 0.0        # the controller's weights this tick
var w_brace: float = 0.0
var w_skid: float = 0.0
var w_crumple: float = 0.0
var w_flail: float = 0.0
var shape := {}                # this fighter's tuck, brace, skid and crumple targets
var phase: float = 0.0


static func _varcode(s: String) -> int:
	match s:
		"u":
			return 1
		"u2":
			return 2
		"one":
			return 3
	return 0


static func setup() -> void:
	if loaded:
		return
	loaded = true
	AnimRig.setup()
	var d: Dictionary = AnimData.ragdoll
	var m: Dictionary = AnimData.ragdoll_motion
	var dofs: Array = d.get("dofs", [])
	bone_a.resize(N)
	bone_b.resize(N)
	for a in [share_a, beta_c, beta_s, k_stiff, k_loose, damp, drag, inertia, lo, hi, tsg, tuck_t, brace_t, crumple_k, flail_amp, flail_hz, hit_vx]:
		a.resize(N)
	for a in [hit_kx, hit_ky, hit_kc]:
		a.resize(N * 4)
	hit_vx_var.resize(N)
	hit_kc_var.resize(N)
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
	var fl: Dictionary = m.get("flail", {})
	var fa: Array = fl.get("amp", [])
	var fh: Array = fl.get("hz", [])
	for i in range(mini(N, fa.size())):
		flail_amp[i] = float(fa[i])
		flail_hz[i] = float(fh[i])
	var ff: Array = fl.get("fade", [0.35, 1.2])
	flail_fade = Vector2(float(ff[0]), float(ff[1]))
	var rg: Dictionary = d.get("regimes", {})
	var rm: Dictionary = m.get("regimes", {})
	var ts: Array = rg.get("tuck_spin", [10.0, 15.0])
	tuck_spin = Vector2(float(ts[0]), float(ts[1]))
	tuck_max = float(rm.get("tuck_max", 0.7))
	var ta: Array = rm.get("tuck_after", [0.25, 0.6])
	tuck_after = Vector2(float(ta[0]), float(ta[1]))
	var bt: Array = rg.get("brace_time", [0.08, 0.3])
	brace_time = Vector2(float(bt[0]), float(bt[1]))
	skid_w = float(rm.get("skid_w", 0.6))
	crumple_down_w = float(rm.get("crumple_down_w", 0.6))
	shapes.clear()
	var sh: Dictionary = m.get("shapes", {})
	for k in sh:
		var one: Dictionary = {}
		for beat in sh[k]:
			var arr := PackedFloat32Array()
			arr.resize(N)
			var src: Array = sh[k][beat]
			for i in range(mini(N, src.size())):
				arr[i] = float(src[i])
			one[beat] = arr
		shapes[k] = one
	shape_of = m.get("fighters", {})
	var hd: Dictionary = m.get("hit", {})
	hit_gain = float(hd.get("gain", 1.6))
	var hdofs: Array = hd.get("dofs", [])
	for i in range(mini(N, hdofs.size())):
		var e2: Dictionary = hdofs[i]
		for r in range(4):
			hit_kx[i * 4 + r] = float(e2.kx[r])
			hit_ky[i * 4 + r] = float(e2.ky[r])
			hit_kc[i * 4 + r] = float(e2.kc[r])
		hit_vx[i] = float(e2.get("vx", 0.0))
		hit_vx_var[i] = _varcode(String(e2.get("vx_var", "u")))
		hit_kc_var[i] = _varcode(String(e2.get("kc_var", "u2")))


func _init() -> void:
	setup()
	th.resize(N)
	om.resize(N)
	set_shape("")


## Picks the fighter's shape from its roster id (a placeholder map in the data until the four fighters have theirs).
func set_shape(roster_id: String) -> void:
	var key: String = String(shape_of.get(roster_id, shape_of.get("default", "")))
	shape = shapes.get(key, {})
	shape_key = key
	var ht: Dictionary = AnimData.shapes.get(key, {}).get("hit", {})
	hit_k.resize(N)
	for i in range(N):
		var bn: String = String(AnimRig.BONES[bone_a[i]][0])
		var grp: String = "legs"
		if bn.begins_with("head") or bn.begins_with("neck"):
			grp = "head"
		elif bn.begins_with("spine") or bn.begins_with("pelvis"):
			grp = "spine"
		elif bn.begins_with("upper_arm") or bn.begins_with("forearm") or bn.begins_with("clavicle"):
			grp = "arms"
		hit_k[i] = float(ht.get("gain", 1.0)) * float(ht.get(grp, 1.0))


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
	w_tuck = 0.0
	w_brace = 0.0
	w_skid = 0.0
	w_crumple = 0.0
	w_flail = 0.0


## One sim tick. v and a are the body's velocity (u/s) and non-gravitational acceleration (u/s^2) in the body frame (x
## forward, y up the body); free_t the looseness the regime asks for; the w_ weights (set by the controller) mix the tuck, brace,
## skid and crumple shapes and the flail in; tt the sim time (the flail's clock); amp scales the drive (reduced motion).
func step(dt: float, v: Vector2, a: Vector2, free_t: float, amp: float, tt: float) -> void:
	# reduced motion also narrows every joint's range (a hard tumble saturates the limits at any amplitude, so the drive alone does not calm it)
	var lk: float = REDUCED_LIMIT if amp < 0.999 else 1.0
	free = move_toward(free, free_t, dt * free_rate)
	var sp: float = clampf(v.length() / v0, 0.0, 2.0)
	var h: float = dt * 0.5
	var g: float = gate + (1.0 - gate) * free
	var s_tuck: PackedFloat32Array = shape.get("tuck", tuck_t)
	var s_brace: PackedFloat32Array = shape.get("brace", brace_t)
	var s_skid: PackedFloat32Array = shape.get("skid", tuck_t)
	var s_crum: PackedFloat32Array = shape.get("crumple", tuck_t)
	var wt: float = w_tuck * amp
	var wb: float = w_brace * amp
	var ws: float = w_skid * amp
	var wc: float = w_crumple * amp
	var wf: float = w_flail * amp
	for _s in range(2):
		for i in range(N):
			var kk: float = lerpf(k_stiff[i], k_loose[i], free)
			var target: float = tsg[i] * sp * free + wt * s_tuck[i] + wb * s_brace[i] + ws * s_skid[i] + wc * s_crum[i]
			if wf > 0.001:
				target += wf * flail_amp[i] * sin(tt * TAU * flail_hz[i] + phase + float(i) * 1.7)
			var nx: float = beta_c[i]
			var ny: float = beta_s[i]
			var drive: float = (-drag[i] * (v.x * nx + v.y * ny) / v0 - inertia[i] * (a.x * nx + a.y * ny) / a0) * g * amp
			var al: float = -kk * (th[i] - target) - damp[i] * om[i] + drive
			om[i] += al * h
			th[i] += om[i] * h
			if th[i] < lo[i] * lk:
				th[i] = lo[i] * lk
				om[i] = maxf(om[i], 0.0)
			elif th[i] > hi[i] * lk:
				th[i] = hi[i] * lk
				om[i] = minf(om[i], 0.0)


## An impulse on every degree of freedom along its crumple direction: a slam folds the body.
func crumple(sev: float, amp: float) -> void:
	for i in range(N):
		om[i] += crumple_k[i] * sev * amp


## An impulse on one degree of freedom (rad/s).
func kick(i: int, w: float) -> void:
	om[i] += w


## The hit-reaction kicks from the data table: dx, dy the blow's push in the body frame, force the scaled strength (wear and
## the variant included), region 0 to 3 (head, core, arms, legs), u and u2 the hit's deterministic variants (-1 to 1).
func hit(dx: float, dy: float, force: float, region: int, u: float, u2: float) -> void:
	var f: float = force * hit_gain
	for i in range(N):
		var k: int = i * 4 + region
		var vv: float = 0.0
		match hit_vx_var[i]:
			1:
				vv = u
			2:
				vv = u2
		var cv: float = 0.0
		match hit_kc_var[i]:
			1:
				cv = u
			2:
				cv = u2
			3:
				cv = 1.0
		om[i] += f * (hit_k[i] if i < hit_k.size() else 1.0) * (hit_kx[k] * dx * (1.0 + hit_vx[i] * vv) + hit_ky[k] * dy + hit_kc[k] * cv)


## Adds the motion to the solved pose, shown at weight w; `scale` (one factor a degree of freedom, optional) lets a limb move less (a broken arm hangs heavy).
func apply(q: Array[Quaternion], w: float, scale: PackedFloat32Array = PackedFloat32Array()) -> void:
	if w <= 0.001:
		return
	for i in range(N):
		var t: float = th[i] * w * (scale[i] if scale.size() == N else 1.0)
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
