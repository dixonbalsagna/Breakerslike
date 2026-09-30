class_name AnimPose
extends RefCounted
## One baked pose on rig R1 (docs/animation/pose-pipeline.md section 3.1): a local rotation for each of the 27 bones,
## a pelvis offset and the finger curl of each hand. Poses are authored as data (data/anim/poses.json) in a sketch form
## (torso lean, twist and bend, head turn, hand and foot targets in model space, per-bone rotation overrides) and baked
## here once at load: forward kinematics, then closed-form two-bone IK to the targets. Render only; nothing here reads or
## writes the sim.
##
## Model space: feet at y = 0, facing +x, the character's right (near) side at +z. Angles are degrees. "lean" leans
## forward (toward +x), "twist" swings the near (+z) shoulder forward, "bend" leans toward the camera side, head "pitch"
## nods forward, head "yaw" turns the face toward the camera.

const CURL := {"fist": 1.7, "open": 0.0, "relaxed": 0.5, "claw": 1.0, "point": 1.2}

var id: String = ""
var family: String = "upright"
var q: Array[Quaternion] = []
var hips := Vector3.ZERO
var curl := Vector2.ZERO
var additive: bool = false
var note: String = ""


static func identity_q() -> Array[Quaternion]:
	var a: Array[Quaternion] = []
	a.resize(AnimRig.N)
	for i in range(AnimRig.N):
		a[i] = Quaternion.IDENTITY
	return a


static func _rad(v: float) -> float:
	return deg_to_rad(v)


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Forward kinematics: global rotations and positions for every bone from local rotations (rest offsets, root at the
## origin, the pelvis moved by `hips`).
static func fk(lq: Array[Quaternion], hip_off: Vector3, gq: Array[Quaternion], gp: PackedVector3Array) -> void:
	for i in range(AnimRig.N):
		var p: int = AnimRig.parent[i]
		if p < 0:
			gq[i] = lq[i]
			gp[i] = Vector3.ZERO
		else:
			gq[i] = gq[p] * lq[i]
			gp[i] = gp[p] + gq[p] * AnimRig.rest_local[i] + (hip_off if i == 1 else Vector3.ZERO)


## Forward kinematics for a chain of bones only: `order` lists bone indices, parents before children.
static func fk_chain(lq: Array[Quaternion], hip_off: Vector3, gq: Array[Quaternion], gp: PackedVector3Array, order: Array) -> void:
	for i in order:
		var p: int = AnimRig.parent[i]
		if p < 0:
			gq[i] = lq[i]
			gp[i] = Vector3.ZERO
		else:
			gq[i] = gq[p] * lq[i]
			gp[i] = gp[p] + gq[p] * AnimRig.rest_local[i] + (hip_off if i == 1 else Vector3.ZERO)


## Closed-form two-bone IK on local rotations: bends bones a, b so the end c reaches `target`, elbow or knee toward
## `pole` (a point). gq and gp are current FK arrays and are updated for a, b and c.
static func ik2(lq: Array[Quaternion], gq: Array[Quaternion], gp: PackedVector3Array, a: int, b: int, c: int, target: Vector3, pole: Vector3) -> void:
	var A: Vector3 = gp[a]
	var B: Vector3 = gp[b]
	var C: Vector3 = gp[c]
	var l1: float = (B - A).length()
	var l2: float = (C - B).length()
	var to: Vector3 = target - A
	var d: float = clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var u: Vector3 = to.normalized()
	var cos_a: float = (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
	var sin_a: float = sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var pv: Vector3 = pole - A
	pv = pv - u * pv.dot(u)
	pv = pv.normalized() if pv.length() > 0.001 else Vector3(0, 0, 1)
	var E: Vector3 = A + u * (l1 * cos_a) + pv * (l1 * sin_a)
	var T: Vector3 = A + u * d
	var qa_new: Quaternion = Quaternion((B - A).normalized(), (E - A).normalized()) * gq[a]
	var qb_new: Quaternion = Quaternion((C - B).normalized(), (T - E).normalized()) * gq[b]
	lq[a] = gq[AnimRig.parent[a]].inverse() * qa_new
	lq[b] = qa_new.inverse() * qb_new
	gq[a] = qa_new
	gq[b] = qb_new
	gp[b] = E
	gq[c] = qb_new * lq[c]
	gp[c] = T


## Bakes a pose from its sketch dictionary.
static func bake(pid: String, d: Dictionary) -> AnimPose:
	AnimRig.setup()
	var p := AnimPose.new()
	p.id = pid
	p.family = String(d.get("family", "upright"))
	p.additive = bool(d.get("additive", false))
	p.note = String(d.get("_note", ""))
	p.q = identity_q()
	var ix: Dictionary = AnimRig.index
	var lean: float = float(d.get("lean", 0.0))
	p.q[ix["pelvis"]] = Quaternion(Vector3(0, 0, 1), -_rad(lean)) * Quaternion(Vector3(0, 1, 0), _rad(float(d.get("hip_twist", 0.0))))
	if d.has("hips"):
		p.hips = _v3(d["hips"])
	var sp: Dictionary = d.get("spine", {})
	var sl: float = float(sp.get("lean", 0.0))
	var stw: float = float(sp.get("twist", 0.0))
	var sb: float = float(sp.get("bend", 0.0))
	for pair in [["spine_1", 0.4], ["spine_2", 0.6]]:
		var k: float = pair[1]
		p.q[ix[pair[0]]] = Quaternion(Vector3(0, 0, 1), -_rad(sl * k)) * Quaternion(Vector3(0, 1, 0), _rad(stw * k)) * Quaternion(Vector3(1, 0, 0), _rad(sb * k))
	var hd: Dictionary = d.get("head", {})
	var hp: float = float(hd.get("pitch", 0.0))
	var hy: float = float(hd.get("yaw", 0.0))
	var hr: float = float(hd.get("roll", 0.0))
	p.q[ix["neck"]] = Quaternion(Vector3(0, 0, 1), -_rad(hp * 0.35)) * Quaternion(Vector3(0, 1, 0), -_rad(hy * 0.35)) * Quaternion(Vector3(1, 0, 0), _rad(hr * 0.35))
	p.q[ix["head"]] = Quaternion(Vector3(0, 0, 1), -_rad(hp * 0.65)) * Quaternion(Vector3(0, 1, 0), -_rad(hy * 0.65)) * Quaternion(Vector3(1, 0, 0), _rad(hr * 0.65))
	# Free-form overrides: bone -> [rx, ry, rz] degrees, applied after the sketch fields.
	var fko: Dictionary = d.get("fk", {})
	for bn in fko:
		var e: Array = fko[bn]
		var i: int = int(ix[bn])
		p.q[i] = p.q[i] * Quaternion.from_euler(Vector3(_rad(float(e[0])), _rad(float(e[1])), _rad(float(e[2]))))
	# Limbs: targets are model-space positions of the wrist or ankle joint.
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	fk(p.q, p.hips, gq, gp)
	for s in ["r", "l"]:
		var zs: float = 1.0 if s == "r" else -1.0
		var up: int = ix["upper_arm_" + s]
		var lo: int = ix["forearm_" + s]
		var en: int = ix["hand_" + s]
		if d.has("hand_" + s):
			var pole: Vector3 = gp[up] + (_v3(d["pole_hand_" + s]) if d.has("pole_hand_" + s) else Vector3(-3.0, -10.0, 6.0 * zs))
			ik2(p.q, gq, gp, up, lo, en, _v3(d["hand_" + s]), pole)
		var th: int = ix["thigh_" + s]
		var sh: int = ix["shin_" + s]
		var ft: int = ix["foot_" + s]
		if d.has("foot_" + s):
			var pole2: Vector3 = gp[th] + (_v3(d["pole_foot_" + s]) if d.has("pole_foot_" + s) else Vector3(10.0, 1.0, 0.0))
			ik2(p.q, gq, gp, th, sh, ft, _v3(d["foot_" + s]), pole2)
	var hs: Dictionary = d.get("hands", {})
	p.curl = Vector2(float(CURL.get(String(hs.get("l", "relaxed")), 0.5)), float(CURL.get(String(hs.get("r", "relaxed")), 0.5)))
	return p


## The mirror image across the body plane (z to -z): the near and far limbs swap. Used for the far-side variants.
func mirrored() -> AnimPose:
	var m := AnimPose.new()
	m.id = id + "#m"
	m.family = family
	m.additive = additive
	m.q = identity_q()
	for i in range(AnimRig.N):
		var nm: String = AnimRig.BONES[i][0]
		var j: int = i
		if nm.ends_with("_l"):
			j = AnimRig.index[nm.substr(0, nm.length() - 2) + "_r"]
		elif nm.ends_with("_r"):
			j = AnimRig.index[nm.substr(0, nm.length() - 2) + "_l"]
		var s: Quaternion = q[i]
		m.q[j] = Quaternion(-s.x, -s.y, s.z, s.w)
	m.hips = Vector3(hips.x, hips.y, -hips.z)
	m.curl = Vector2(curl.y, curl.x)
	return m


## dst[i] = slerp(dst[i], src[i], w) for every bone.
static func mix(dst: Array[Quaternion], src: Array[Quaternion], w: float) -> void:
	if w <= 0.0:
		return
	for i in range(AnimRig.N):
		dst[i] = dst[i].slerp(src[i], w)


## dst[i] = slerp(dst[i], src[i], clamp(u - lag[i]) rescaled), the strike snap with the pelvis leading and the hands last.
static func mix_lag(dst: Array[Quaternion], src: Array[Quaternion], u: float, lag: PackedFloat32Array, ease_pow: float) -> void:
	for i in range(AnimRig.N):
		var l: float = lag[i]
		var t: float = clampf((u - l) / maxf(1.0 - l, 0.001), 0.0, 1.0)
		if ease_pow != 1.0:
			t = pow(t, ease_pow)
		dst[i] = dst[i].slerp(src[i], t)


## dst *= slerp(identity, delta, w) for every bone: a pose used as an additive layer.
static func add(dst: Array[Quaternion], delta: Array[Quaternion], w: float) -> void:
	if w <= 0.0:
		return
	for i in range(AnimRig.N):
		dst[i] = dst[i] * Quaternion.IDENTITY.slerp(delta[i], w)
