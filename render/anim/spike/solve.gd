extends RefCounted
## A representative slice of the animation layer stack (docs/animation/pose-pipeline.md section 4.1), written to be
## measured, not to look good: key blend, inertialisation, modifiers, forward kinematics, closed-form two-bone IK on
## four limbs, spring chains on the extras, an impact-wave additive, a final joint clamp and the write to the rig.
## One instance per fighter. Layers are bits of a mask (the key blend always runs):
##   1 inertia, 2 modifiers, 4 FK + IK on two limbs, 8 IK on the other two, 16 three springs, 32 two more springs,
##   64 impact wave + joint clamp.
## The degrade ladder (section 7.2): level 2 = mask 0, level 1 = mask 21, level 0 = mask 127.

const N := 27

var rig
var parent: PackedInt32Array
var rest_local: PackedVector3Array
var qa: Array[Quaternion] = []
var qb: Array[Quaternion] = []
var lag := PackedFloat32Array()
var off: Array[Quaternion] = []
var modq: Array[Quaternion] = []
var mod_idx := PackedInt32Array()
var q: Array[Quaternion] = []
var gq: Array[Quaternion] = []
var gp := PackedVector3Array()
var spring_x := PackedFloat32Array()
var spring_v := PackedFloat32Array()
var spring_bone := PackedInt32Array()
var react_bone := PackedInt32Array()
var react_axis: Array[Vector3] = []
var clamp_bone := PackedInt32Array()
var tick: int = 0
var seed_phase: float = 0.0
var pelvis_off := Vector3.ZERO
var b_fingers_l: int
var b_fingers_r: int
var ik_chains: Array = []   # [upper, lower, end, the bone whose position the target orbits, phase]


func _init(rig_, seed_: int) -> void:
	rig = rig_
	parent = rig.parent
	rest_local = rig.rest_local
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_
	seed_phase = rng.randf()
	q.resize(N)
	gq.resize(N)
	gp.resize(N)
	off.resize(N)
	qa.resize(N)
	qb.resize(N)
	lag.resize(N)
	for i in range(N):
		qa[i] = _rand_q(rng, 0.5)
		qb[i] = _rand_q(rng, 0.5)
		off[i] = _rand_q(rng, 0.05)
		q[i] = Quaternion.IDENTITY
		gq[i] = Quaternion.IDENTITY
		lag[i] = float(i % 7) * 0.04
	for nm in ["spine_1", "spine_2", "neck", "head", "clavicle_l", "clavicle_r", "upper_arm_l", "upper_arm_r", "thigh_l", "thigh_r"]:
		mod_idx.append(rig.index[nm])
		modq.append(_rand_q(rng, 0.25))
	for nm in ["x_pack", "x_cable_a1", "x_cable_a2", "x_cable_b1", "x_cable_b2"]:
		spring_bone.append(rig.index[nm])
	spring_x.resize(5)
	spring_v.resize(5)
	for nm in ["spine_1", "spine_2", "neck", "head", "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r"]:
		react_bone.append(rig.index[nm])
		react_axis.append(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized())
	for nm in ["forearm_l", "forearm_r", "shin_l", "shin_r", "spine_1", "spine_2"]:
		clamp_bone.append(rig.index[nm])
	b_fingers_l = rig.index["fingers_l"]
	b_fingers_r = rig.index["fingers_r"]
	var ix: Dictionary = rig.index
	ik_chains = [
		[ix["upper_arm_r"], ix["forearm_r"], ix["hand_r"], ix["clavicle_r"], 0.0],
		[ix["upper_arm_l"], ix["forearm_l"], ix["hand_l"], ix["clavicle_l"], 1.7],
		[ix["thigh_r"], ix["shin_r"], ix["foot_r"], ix["pelvis"], 3.4],
		[ix["thigh_l"], ix["shin_l"], ix["foot_l"], ix["pelvis"], 5.1],
	]


static func mask_for_level(level: int) -> int:
	return 0 if level == 2 else (21 if level == 1 else 127)


func _rand_q(rng: RandomNumberGenerator, amp: float) -> Quaternion:
	var axis := Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
	if axis.length() < 0.01:
		axis = Vector3.UP
	return Quaternion(axis.normalized(), (rng.randf() - 0.5) * 2.0 * amp)


func _fk() -> void:
	gq[0] = q[0]
	gp[0] = Vector3.ZERO
	for i in range(1, N):
		var p: int = parent[i]
		gq[i] = gq[p] * q[i]
		gp[i] = gp[p] + gq[p] * rest_local[i]


## Closed-form two-bone IK: rotates the upper and lower bones so the end reaches `target`, bending toward `pole`.
func _ik2(a: int, b: int, c: int, target: Vector3, pole: Vector3) -> void:
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
	pv = (pv - u * pv.dot(u)).normalized()
	var E: Vector3 = A + u * (l1 * cos_a) + pv * (l1 * sin_a)
	var T: Vector3 = A + u * d
	var qa_new: Quaternion = Quaternion((B - A).normalized(), (E - A).normalized()) * gq[a]
	var qb_new: Quaternion = Quaternion((C - B).normalized(), (T - E).normalized()) * gq[b]
	q[a] = gq[parent[a]].inverse() * qa_new
	q[b] = qa_new.inverse() * qb_new
	gq[a] = qa_new
	gq[b] = qb_new
	gp[b] = E
	gq[c] = qb_new * q[c]
	gp[c] = T


## Runs one solve with the layers in `mask` (see the header).
func solve_mask(mask: int) -> void:
	tick += 1
	var phase: float = fposmod(float(tick) * 0.011 + seed_phase, 1.0)
	# layer 1: key blend with per-bone lag and an ease
	for i in range(N):
		var t: float = clampf(phase * 1.3 - lag[i], 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		q[i] = qa[i].slerp(qb[i], t)
	if mask & 1:
		# layer 3: inertialisation offsets, decayed each tick
		for i in range(N):
			off[i] = off[i].slerp(Quaternion.IDENTITY, 0.12)
			q[i] = q[i] * off[i]
	if mask & 2:
		# layers 4 and 5: style modifiers on ten bones
		var w: float = 0.5 + 0.5 * sin(float(tick) * 0.02)
		for k in range(mod_idx.size()):
			var i: int = mod_idx[k]
			q[i] = q[i] * Quaternion.IDENTITY.slerp(modq[k], w)
	if mask & (4 | 8):
		# layer 6: hand and foot pins by two-bone IK (two arms; with bit 8 the two legs too)
		_fk()
		var chains: int = 4 if (mask & 8) else 2
		var tt: float = float(tick) * 0.03
		for k in range(chains):
			var ch: Array = ik_chains[k]
			var base: Vector3 = gp[ch[3]]
			var ph: float = tt + float(ch[4])
			var tgt: Vector3 = base + Vector3(12.0 + 8.0 * sin(ph), -18.0 + 6.0 * cos(ph * 1.3), 6.0 * sin(ph * 0.7))
			var pole: Vector3 = gp[ch[0]] + Vector3(-10.0, 0.0, 0.0)
			if k >= 2:
				tgt = base + Vector3(6.0 * sin(ph), -34.0 + 3.0 * cos(ph), 5.0)
				pole = gp[ch[0]] + Vector3(10.0, 0.0, 0.0)
			_ik2(ch[0], ch[1], ch[2], tgt, pole)
	if mask & (16 | 32):
		# layer 7: spring chains on the extras (three links, or five with bit 32)
		var links: int = 5 if (mask & 32) else 3
		var drive: float = sin(float(tick) * 0.05) * 6.0
		for k in range(links):
			var a: float = -60.0 * spring_x[k] - 6.0 * spring_v[k] + drive
			spring_v[k] += a * 0.0166667
			spring_x[k] += spring_v[k] * 0.0166667
			var bi: int = spring_bone[k]
			q[bi] = q[bi] * Quaternion(Vector3(0, 0, 1), clampf(spring_x[k], -0.8, 0.8))
	if mask & 64:
		# layer 8: impact wave on ten bones
		var decay: float = exp(-float(tick % 90) * 0.05)
		var wv: float = sin(float(tick) * 0.6) * 0.12 * decay
		for k in range(react_bone.size()):
			var i: int = react_bone[k]
			q[i] = q[i] * Quaternion(react_axis[k], wv)
		# layer 9: joint limits
		for k in range(clamp_bone.size()):
			var i: int = clamp_bone[k]
			var ang: float = q[i].get_angle()
			if ang > 1.9:
				q[i] = Quaternion.IDENTITY.slerp(q[i], 1.9 / ang)
	pelvis_off = Vector3(0, 1.5 * sin(float(tick) * 0.08), 0)


## The write to a Skeleton3D (skinned rig). Bone poses are offsets from the rest pose.
func apply_skeleton(skel: Skeleton3D, fist: float) -> void:
	for i in range(N):
		skel.set_bone_pose_rotation(i, q[i])
	skel.set_bone_pose_position(1, pelvis_off)
	var fq := Quaternion(Vector3(0, 0, 1), fist)
	skel.set_bone_pose_rotation(b_fingers_l, fq)
	skel.set_bone_pose_rotation(b_fingers_r, fq)


## The write to a puppet of Node3D pieces (each node sits at its rest offset from its parent).
func apply_nodes(nodes: Array, fist: float) -> void:
	for i in range(N):
		nodes[i].quaternion = q[i]
	nodes[1].position = rest_local[1] + pelvis_off
	var fq := Quaternion(Vector3(0, 0, 1), fist)
	nodes[b_fingers_l].quaternion = fq
	nodes[b_fingers_r].quaternion = fq
