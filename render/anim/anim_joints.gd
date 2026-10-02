class_name AnimJoints
extends RefCounted
## The joint limits of rig R1 (data/anim/joints.json; docs/animation/joint-limits.md). One table decides what a bone may do, and every source of
## motion answers to it: the pose bake and the limb solves keep to it by construction (`ik_limb` moves the bend plane, never the end), the
## blender's output and the ragdoll pass through `enforce` last, so no layer can leave a knee or an elbow bent the wrong way.
##
## Two kinds of joint. A HINGE (the elbow, the knee) turns about its own z axis only, one way: the elbow from -give to its max, the knee the
## other way (`sign` -1), and nothing sideways. A BALL joint (the shoulder, the hip, the spine, the neck, the head, the clavicle, the ankle,
## the wrist) is split into a swing (where the bone points, a cone of `swing` degrees about its rest axis) and a twist (the turn about the bone's
## own axis, a range of `twist` degrees, mirrored for the left side). The twist is what decides which side a hinge below it folds to: a thigh
## twisted 180 degrees folds its knee forward, so the twist of the thigh and the upper arm is the limit that matters most.
## Render only: nothing here reads or writes the sim.

const KIND_NONE := 0
const KIND_HINGE := 1
const KIND_BALL := 2
const POLE_SWING := 3.0   # a swing past this (172 degrees) points the bone almost opposite to its rest axis, where its twist is not defined

static var loaded: bool = false
static var enabled: bool = true                       # the passes (the bake's, the ragdoll's and the solve's last): the lint switches them off to measure the sources alone
static var ik_limits: bool = true                     # the limb solves keep the upper bone's twist inside its range (the lint switches it off for the "before")
static var give: float = 0.05                         # radians of give past a hinge's end
static var retarget_max: float = 0.0                 # the pose bake may slide a hand target this far forward when no comfortable bend reaches it (0: never)
static var comfort: float = 1.3                       # the twist (rad) past which a bend is not comfortable
static var arm_back_soft: float = 0.8                 # an upper arm may not point straight back along the body: its last reach is squeezed into 0.8 to 0.9 of the axis
static var kind := PackedInt32Array()                 # per bone
static var swing_max := PackedFloat32Array()          # ball: the narrowest the swing cone is in any direction (rad): what a quick test uses
static var sw_dir := PackedFloat32Array()             # ball: the cone toward the front, the back, the outside and the inside of the body (4 each), rad
static var twist_lo := PackedFloat32Array()           # ball: twist range, in the bone's own frame (the right-hand side's sign; the left is mirrored)
static var twist_hi := PackedFloat32Array()
static var hinge_min := PackedFloat32Array()          # hinge: radians (in the direction of flexion)
static var hinge_max := PackedFloat32Array()
static var hinge_sign := PackedFloat32Array()         # +1 elbow (flexes toward +x), -1 knee (toward -x)
static var side_sign := PackedFloat32Array()          # -1 for a left bone (its twist is the mirror of the right's)
static var axis_of := PackedInt32Array()              # ball: the bone's own axis (0 x, 1 y, 2 z) the twist is measured about
static var relax_lo := PackedFloat32Array()           # ball with a hinge below it: the twist range allowed while that hinge is nearly straight (a straight arm hides its twist)
static var relax_hi := PackedFloat32Array()
static var relax_from: float = 0.26                   # the hinge flexion (rad) up to which the relaxed range applies ...
static var relax_to: float = 0.79                     # ... and from which the normal range does
static var shape_scale: Dictionary = {}               # shape key -> {swing, twist, hinge}
static var limb_bones := PackedInt32Array()           # the shoulders and the hips: their twist decides which side the elbow or knee below folds to, so a blend treats it on its own
static var _fast_shape: String = ""                 # the shape the last quick-reject table was for (a solve asks for the same one every time)
static var _fast_last: Dictionary = {}
static var ua_l: int = 7                              # the upper arms (set by setup)
static var ua_r: int = 12
static var row_of := PackedInt32Array()               # bone -> its row in the quick-reject tables (-1: unconstrained)
static var is_limb := PackedByteArray()               # 1 for the shoulders and the hips
static var others := PackedInt32Array()               # every other bone: the blends handle the four above on their own
static var _fast: Dictionary = {}                     # shape -> the quick-reject tables of `enforce` (built on first use)
static var last_fix: float = 0.0                      # the largest correction (rad) the last `enforce` made


static func setup(d: Dictionary) -> void:
	AnimRig.setup()
	var n: int = AnimRig.N
	kind.resize(n)
	swing_max.resize(n)
	sw_dir.resize(n * 4)
	twist_lo.resize(n)
	twist_hi.resize(n)
	hinge_min.resize(n)
	hinge_max.resize(n)
	hinge_sign.resize(n)
	side_sign.resize(n)
	axis_of.resize(n)
	relax_lo.resize(n)
	relax_hi.resize(n)
	for i in range(n):
		kind[i] = KIND_NONE
		swing_max[i] = PI
		for d4 in range(4):
			sw_dir[i * 4 + d4] = PI
		twist_lo[i] = -PI
		twist_hi[i] = PI
		hinge_min[i] = -give
		hinge_max[i] = 2.62
		hinge_sign[i] = 1.0
		side_sign[i] = -1.0 if String(AnimRig.BONES[i][0]).ends_with("_l") else 1.0
		axis_of[i] = 1
		relax_lo[i] = NAN
		relax_hi[i] = NAN
	give = deg_to_rad(float(d.get("give_deg", 3.0)))
	arm_back_soft = float(d.get("arm_back_soft", 0.8))
	retarget_max = float(d.get("retarget_units", 0.0))
	comfort = deg_to_rad(float(d.get("comfort_twist_deg", 75.0)))
	relax_from = deg_to_rad(float(d.get("straight_below_deg", 15.0)))
	relax_to = deg_to_rad(float(d.get("bent_above_deg", 45.0)))
	var hinges: Dictionary = d.get("hinges", {})
	for k in hinges:
		var h: Dictionary = hinges[k]
		for bn in h.get("bones", []):
			var i: int = int(AnimRig.index[String(bn)])
			kind[i] = KIND_HINGE
			hinge_sign[i] = float(h.get("sign", 1.0))
			hinge_min[i] = deg_to_rad(float(h.get("min_deg", -3.0)))
			hinge_max[i] = deg_to_rad(float(h.get("max_deg", 150.0)))
	var balls: Dictionary = d.get("balls", {})
	for k in balls:
		var b: Dictionary = balls[k]
		for bn in b.get("bones", []):
			var i: int = int(AnimRig.index[String(bn)])
			kind[i] = KIND_BALL
			var sd: float = float(b.get("swing_deg", 180.0))
			var f4: Array = [float(b.get("swing_fwd_deg", sd)), float(b.get("swing_back_deg", sd)), float(b.get("swing_out_deg", sd)), float(b.get("swing_in_deg", sd))]
			swing_max[i] = deg_to_rad(minf(minf(f4[0], f4[1]), minf(f4[2], f4[3])))
			for d4 in range(4):
				sw_dir[i * 4 + d4] = deg_to_rad(f4[d4])
			var tw: Array = b.get("twist_deg", [-180.0, 180.0])
			twist_lo[i] = deg_to_rad(float(tw[0]))
			twist_hi[i] = deg_to_rad(float(tw[1]))
			axis_of[i] = {"x": 0, "y": 1, "z": 2}.get(String(b.get("axis", "y")), 1)
			if b.has("straight_twist_deg"):
				relax_lo[i] = deg_to_rad(float(b["straight_twist_deg"][0]))
				relax_hi[i] = deg_to_rad(float(b["straight_twist_deg"][1]))
	limb_bones = PackedInt32Array([AnimRig.index["upper_arm_l"], AnimRig.index["upper_arm_r"], AnimRig.index["thigh_l"], AnimRig.index["thigh_r"]])
	ua_l = AnimRig.index["upper_arm_l"]
	ua_r = AnimRig.index["upper_arm_r"]
	is_limb.resize(n)
	others.clear()
	for i in range(n):
		is_limb[i] = 1 if limb_bones.has(i) else 0
		if is_limb[i] == 0:
			others.append(i)
	_fast.clear()
	row_of.resize(n)
	var rw := 0
	for i in range(n):
		if kind[i] == KIND_NONE:
			row_of[i] = -1
		else:
			row_of[i] = rw
			rw += 1
	_fast_shape = ""
	shape_scale = d.get("shapes", {})
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--no-ik-limits"):
		ik_limits = false
	if args.has("--no-joint-pass"):
		enabled = false
	loaded = true


## The scale of a shape (P, A, E, C; "" for none) for one kind of limit.
static func scale_of(shape: String, what: String) -> float:
	var s = shape_scale.get(shape)
	if s == null:
		s = shape_scale.get("default", {})
	return float(s.get(what, 1.0))


## The component of a rotation about axis k (0 x, 1 y, 2 z).
static func _comp(q: Quaternion, k: int) -> float:
	return q.x if k == 0 else (q.y if k == 1 else q.z)


static func _axis_quat(k: int, half: float) -> Quaternion:
	var sn: float = sin(half)
	return Quaternion(sn if k == 0 else 0.0, sn if k == 1 else 0.0, sn if k == 2 else 0.0, cos(half))


## Signed twist of a local rotation about its own axis k (the bone's axis; 1 for most), in (-pi, pi].
static func twist_of(q: Quaternion, k: int = 1) -> float:
	var t: float = 2.0 * atan2(_comp(q, k), q.w)
	if t > PI:
		t -= TAU
	elif t < -PI:
		t += TAU
	return t


## The swing cone toward the way the bone is tilting: the four limits (front, back, outside, inside) joined as an ellipse. (sx, sz) is the swing's axis
## (unit, in the x-z plane); the bone tilts toward (sz, -sx): +x is the front of the body, +z the near side.
static func swing_limit(bone: int, sx: float, sz: float, shape: String) -> float:
	var tx: float = sz
	var tl: float = -sx * side_sign[bone]   # toward the outside of the body when positive
	var lx: float = sw_dir[bone * 4] if tx >= 0.0 else sw_dir[bone * 4 + 1]
	var lz: float = sw_dir[bone * 4 + 2] if tl >= 0.0 else sw_dir[bone * 4 + 3]
	var m: float = sqrt((tx / lx) * (tx / lx) + (tl / lz) * (tl / lz))
	return (1.0 / m if m > 0.000001 else PI) * scale_of(shape, "swing")


## The swing angle (rad) of a local rotation once its twist `t` about axis k is taken out: how far the bone's axis is from its rest axis.
static func swing_of(q: Quaternion, t: float, k: int = 1) -> float:
	var sw: Quaternion = q * _axis_quat(k, -t * 0.5)
	return 2.0 * atan2(sqrt(sw.x * sw.x + sw.y * sw.y + sw.z * sw.z), absf(sw.w))


## The swing limit for this rotation's own direction of tilt (the cone is the same in every direction for the bones with one number).
static func _limit_of(q: Quaternion, bone: int, tw: float, k: int, shape: String) -> float:
	if k != 1:
		return swing_max[bone] * scale_of(shape, "swing")
	var sw: Quaternion = q * _axis_quat(1, -tw * 0.5)
	var vl: float = sqrt(sw.x * sw.x + sw.z * sw.z)
	if vl < 0.000001:
		return swing_max[bone] * scale_of(shape, "swing")
	return swing_limit(bone, sw.x / vl, sw.z / vl, shape)


## The twist range of a ball joint now, [lo, hi] in radians for this side: the data's range scaled by the shape, and widened toward the "straight" range
## while the hinge below it (the elbow under the shoulder, the knee under the hip) is nearly straight.
static func twist_range(lq: Array[Quaternion], bone: int, shape: String) -> Vector2:
	var fl: float = 0.0
	if not is_nan(relax_lo[bone]) and bone + 1 < AnimRig.N and kind[bone + 1] == KIND_HINGE:
		fl = absf(hinge_state(lq[bone + 1], bone + 1).x)
	return twist_range_at(bone, shape, fl)


## The same for a given flexion `fl` (rad) of the hinge below.
static func twist_range_at(bone: int, shape: String, fl: float) -> Vector2:
	var lo: float = twist_lo[bone]
	var hi: float = twist_hi[bone]
	var ts: float = scale_of(shape, "twist")
	lo *= ts
	hi *= ts
	if not is_nan(relax_lo[bone]):
		var r: float = 1.0 - smoothstep(relax_from, relax_to, fl)
		lo = lerpf(lo, relax_lo[bone], r)
		hi = lerpf(hi, relax_hi[bone], r)
	if side_sign[bone] < 0.0:
		var t0: float = lo
		lo = -hi
		hi = -t0
	return Vector2(lo, hi)


## Excess of one candidate rotation `q` of a ball joint, given the flexion of the hinge below it (what a limb solve tries before it commits).
static func excess_at(q: Quaternion, bone: int, shape: String, fl: float) -> Vector2:
	var k: int = axis_of[bone]
	var tw: float = twist_of(q, k)
	var rg: Vector2 = twist_range_at(bone, shape, fl)
	var sa: float = swing_of(q, tw, k)
	var smax: float = _limit_of(q, bone, tw, k, shape)
	return Vector2(0.0 if minf(sa, smax) > POLE_SWING else maxf(maxf(rg.x - tw, tw - rg.y), 0.0), maxf(sa - smax, 0.0))


## How far past its limits a ball joint's rotation is: [twist excess, swing excess] in radians (0 when inside). `bone` is the bone index.
static func ball_excess(lq: Array[Quaternion], bone: int, shape: String = "") -> Vector2:
	var q: Quaternion = lq[bone]
	var k: int = axis_of[bone]
	var tw: float = twist_of(q, k)
	var rg: Vector2 = twist_range(lq, bone, shape)
	var sa: float = swing_of(q, tw, k)
	var smax: float = _limit_of(q, bone, tw, k, shape)
	var ex_t: float = 0.0 if minf(sa, smax) > POLE_SWING else maxf(maxf(rg.x - tw, tw - rg.y), 0.0)   # near the pole of the swing the twist means nothing
	var ex_s: float = maxf(sa - smax, 0.0)
	return Vector2(ex_t, ex_s)


## A hinge's flexion angle (rad, positive in its own direction of flexion) and its sideways amount (the z of the lower bone's direction).
static func hinge_state(q: Quaternion, bone: int) -> Vector2:
	var v: Vector3 = q * Vector3(0, -1, 0)
	return Vector2(atan2(v.x, -v.y) * hinge_sign[bone], v.z)


## Puts every constrained bone inside its limits (the last pass of a solve, and what the lint's "after" runs). Returns the largest correction made
## in radians and keeps it in `last_fix`; a source that respects the limits makes none. Most bones are inside their range, and a few float tests
## (no trig) say so; only a bone near or past a limit is worked out in full.
static func enforce(lq: Array[Quaternion], shape: String = "") -> float:
	if not enabled or not loaded:
		return 0.0
	var worst: float = 0.0
	var ft: Dictionary = _fast_last if shape == _fast_shape else _fast_table(shape)
	var hs: float = ft.hs
	var ids: PackedInt32Array = ft.ids
	var tlo: PackedFloat32Array = ft.tlo
	var thi: PackedFloat32Array = ft.thi
	var c2: PackedFloat32Array = ft.c2
	var hmx: PackedFloat32Array = ft.hmx
	var n: int = ids.size()
	while n > 0:   # the lower bones first: a hinge is made right before the shoulder or hip above it asks how far it is bent
		n -= 1
		var i: int = ids[n]
		var q: Quaternion = lq[i]
		if kind[i] == KIND_HINGE:
			# the lower bone's direction: x toward the flexion side, y along the bone; inside when it is turned between -give and the maximum
			var vx: float = 2.0 * (q.w * q.z - q.x * q.y) * hinge_sign[i]
			var vy: float = 1.0 - 2.0 * (q.x * q.x + q.z * q.z)
			var vz: float = 2.0 * (q.w * q.x + q.y * q.z)
			if absf(vz) <= 0.02 and ((vx >= 0.0 and vy >= hmx[n]) or (vx < 0.0 and vx >= -0.05 and vy > 0.0)):
				continue
		else:
			# a ball joint is inside when its twist is inside the narrow range and its swing inside the cone: both without a trig call
			var k: int = axis_of[i]
			var c: float = q.x if k == 0 else (q.y if k == 1 else q.z)
			var aw: float = absf(q.w)
			var sc: float = c if q.w >= 0.0 else -c
			if sc >= tlo[n] * aw and sc <= thi[n] * aw and q.w * q.w + c * c >= c2[n]:
				continue
		worst = maxf(worst, _fix_bone(lq, i, shape, hs))
	var qa: Quaternion = lq[ua_l]
	if 2.0 * (qa.w * qa.z - qa.x * qa.y) < -arm_back_soft:
		worst = maxf(worst, _arm_back(lq, ua_l))
	qa = lq[ua_r]
	if 2.0 * (qa.w * qa.z - qa.x * qa.y) < -arm_back_soft:
		worst = maxf(worst, _arm_back(lq, ua_r))
	last_fix = worst
	return worst


## Is this local rotation of a constrained bone inside its limits? The quick test of `enforce` for one bone: true means surely inside, false means "look closer".
static func fast_ok(q: Quaternion, bone: int, shape: String) -> bool:
	var ft: Dictionary = _fast_last if shape == _fast_shape else _fast_table(shape)
	var n: int = row_of[bone]
	if n < 0:
		return true
	if kind[bone] == KIND_HINGE:
		var vx: float = 2.0 * (q.w * q.z - q.x * q.y) * hinge_sign[bone]
		var vy: float = 1.0 - 2.0 * (q.x * q.x + q.z * q.z)
		var vz: float = 2.0 * (q.w * q.x + q.y * q.z)
		return absf(vz) <= 0.02 and ((vx >= 0.0 and vy >= ft.hmx[n]) or (vx < 0.0 and vx >= -0.05 and vy > 0.0))
	var k: int = axis_of[bone]
	var c: float = q.x if k == 0 else (q.y if k == 1 else q.z)
	var aw: float = absf(q.w)
	var sc: float = c if q.w >= 0.0 else -c
	return sc >= ft.tlo[n] * aw and sc <= ft.thi[n] * aw and q.w * q.w + c * c >= ft.c2[n]


static func _fast_table(shape: String) -> Dictionary:
	var ft: Dictionary = _fast.get(shape) if _fast.has(shape) else _build_fast(shape)
	_fast_shape = shape
	_fast_last = ft
	return ft


## The quick-reject tables for one shape scale: the constrained bones and, for each, the tangents of its narrow twist range's half angles, the squared
## cosine of its swing cone's half angle and the cosine of a hinge's maximum.
static func _build_fast(shape: String) -> Dictionary:
	var ids := PackedInt32Array()
	var tlo := PackedFloat32Array()
	var thi := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	var hmx := PackedFloat32Array()
	var hs: float = scale_of(shape, "hinge")
	for i in range(AnimRig.N):
		if kind[i] == KIND_NONE:
			continue
		ids.append(i)
		if kind[i] == KIND_HINGE:
			tlo.append(0.0)
			thi.append(0.0)
			c2.append(0.0)
			hmx.append(cos(minf(hinge_max[i] * hs, PI)))
		else:
			var lo: float = twist_lo[i] * scale_of(shape, "twist")
			var hi: float = twist_hi[i] * scale_of(shape, "twist")
			if side_sign[i] < 0.0:
				var t0: float = lo
				lo = -hi
				hi = -t0
			tlo.append(tan(clampf(lo * 0.5, -1.5, 1.5)))
			thi.append(tan(clampf(hi * 0.5, -1.5, 1.5)))
			var cs: float = cos(minf(swing_max[i] * scale_of(shape, "swing"), PI) * 0.5)
			c2.append(cs * cs)
			hmx.append(0.0)
	var r: Dictionary = {"ids": ids, "tlo": tlo, "thi": thi, "c2": c2, "hmx": hmx, "hs": hs}
	_fast[shape] = r
	return r


## Puts one constrained bone inside its limits (a limb solve that could find no legal bend plane clamps the upper bone and folds the joint below to reach as
## near as it can). Returns the correction in radians.
static func clamp_bone(lq: Array[Quaternion], i: int, shape: String = "") -> float:
	return _fix_bone(lq, i, shape, scale_of(shape, "hinge"))


static func _fix_bone(lq: Array[Quaternion], i: int, shape: String, hs: float) -> float:
	var q: Quaternion = lq[i]
	if kind[i] == KIND_HINGE:
		var st: Vector2 = hinge_state(q, i)
		var th: float = st.x
		var tc: float = clampf(th, hinge_min[i], hinge_max[i] * hs)
		if tc != th or absf(st.y) > 0.02:
			lq[i] = Quaternion(Vector3(0, 0, 1), tc * hinge_sign[i])
			return maxf(absf(tc - th), asin(clampf(absf(st.y), 0.0, 1.0)))
		return 0.0
	# a ball joint: split, clamp, rejoin
	var k: int = axis_of[i]
	var tw: float = twist_of(q, k)
	var rg: Vector2 = twist_range(lq, i, shape)
	var sw: Quaternion = q * _axis_quat(k, -tw * 0.5)
	var vl: float = sqrt(sw.x * sw.x + sw.y * sw.y + sw.z * sw.z)
	var sa: float = 2.0 * atan2(vl, absf(sw.w))
	var smax: float = swing_max[i] * scale_of(shape, "swing")
	if k == 1 and vl > 0.000001:
		smax = swing_limit(i, sw.x / vl, sw.z / vl, shape)
	var tc2: float = clampf(tw, rg.x, rg.y) if minf(sa, smax) <= POLE_SWING else tw
	if tc2 == tw and sa <= smax:
		return 0.0
	var worst: float = absf(tc2 - tw)
	if sa > smax and vl > 0.000001:
		sw = Quaternion(Vector3(sw.x, sw.y, sw.z) / vl, smax)
		worst = maxf(worst, sa - smax)
	lq[i] = (sw * _axis_quat(k, tc2 * 0.5)).normalized()
	return worst


## The shoulder's blind spot: an upper arm may not point straight back along the body (its last reach is squeezed into 0.8 to 0.9 of the axis; the arm's
## up, down or sideways lean is kept, so the map stays continuous).
static func _arm_back(lq: Array[Quaternion], i2: int) -> float:
	var v2: Vector3 = lq[i2] * Vector3(0, -1, 0)
	if v2.x >= -arm_back_soft:
		return 0.0
	var xn: float = -arm_back_soft - (-v2.x - arm_back_soft) * 0.5
	var r0: float = sqrt(maxf(1.0 - v2.x * v2.x, 0.0))
	if r0 <= 0.0001:
		return 0.0
	var k: float = sqrt(1.0 - xn * xn) / r0
	var to := Vector3(xn, v2.y * k, v2.z * k).normalized()
	lq[i2] = Quaternion(v2, to) * lq[i2]
	return acos(clampf(v2.normalized().dot(to), -1.0, 1.0))


## What a limb solve has to know: is this bone's candidate rotation inside its limits (ball joints only; a hinge is made one by the solve).
static func ball_ok(lq: Array[Quaternion], bone: int, shape: String = "") -> bool:
	var e: Vector2 = ball_excess(lq, bone, shape)
	return e.x <= 0.0001 and e.y <= 0.0001


## Every violation in a local pose, as a list of [what, bone name, amount in degrees]; what is one of
## "hinge past end", "hinge wrong way", "hinge sideways", "twist", "swing" or "arm back". The lint's measure (the same limits `enforce` applies, with a
## tolerance of `tol_deg`).
static func violations(lq: Array[Quaternion], shape: String = "", tol_deg: float = 2.0) -> Array:
	var out: Array = []
	if not loaded:
		return out
	var hs: float = scale_of(shape, "hinge")
	var tol: float = deg_to_rad(tol_deg)
	for i in range(AnimRig.N):
		var kd: int = kind[i]
		if kd == KIND_NONE:
			continue
		var bn: String = String(AnimRig.BONES[i][0])
		if kd == KIND_HINGE:
			var st: Vector2 = hinge_state(lq[i], i)
			if st.x < hinge_min[i] - tol:
				out.append(["hinge wrong way", bn, rad_to_deg(hinge_min[i] - st.x)])
			elif st.x > hinge_max[i] * hs + tol:
				out.append(["hinge past end", bn, rad_to_deg(st.x - hinge_max[i] * hs)])
			if absf(st.y) > 0.02:
				out.append(["hinge sideways", bn, rad_to_deg(asin(clampf(absf(st.y), 0.0, 1.0)))])
			continue
		var e: Vector2 = ball_excess(lq, i, shape)
		if e.x > tol:
			out.append(["twist", bn, rad_to_deg(e.x)])
		if e.y > tol:
			out.append(["swing", bn, rad_to_deg(e.y)])
	for nm in ["upper_arm_l", "upper_arm_r"]:
		var v2: Vector3 = lq[int(AnimRig.index[nm])] * Vector3(0, -1, 0)
		if v2.x < -(arm_back_soft + 0.1 + 0.01):
			out.append(["arm back", nm, rad_to_deg(acos(clampf(-v2.x, 0.0, 1.0)))])
	return out


## A blend of two rotations of a shoulder or a hip: the twist about the bone's own axis is blended as an angle and the swing as a rotation, so two legal
## rotations never blend through a frame twisted past the range (a plain slerp of a bone with a large turn between the two can swing its twist by 150 degrees
## on the way, which folds the knee or the elbow below it the wrong way for those frames). Small turns take the plain slerp.
static func slerp_limb(a: Quaternion, b: Quaternion, t: float) -> Quaternion:
	if absf(a.dot(b)) > 0.9:
		return a.slerp(b, t)
	var ta: float = twist_of(a, 1)
	var tb: float = twist_of(b, 1)
	var sa: Quaternion = a * Quaternion(0.0, -sin(ta * 0.5), 0.0, cos(ta * 0.5))
	var sb: Quaternion = b * Quaternion(0.0, -sin(tb * 0.5), 0.0, cos(tb * 0.5))
	# the swing is blended as a turn vector (axis times angle): the way through the rest pose, not the shorter way round, which for a hip carried from far
	# forward to a little back would swing out through the back of the body, the one place the cone forbids
	var va: Vector3 = _swing_vec(sa)
	var vb: Vector3 = _swing_vec(sb)
	var vm: Vector3 = va.lerp(vb, t)
	var ang: float = vm.length()
	var sw: Quaternion = Quaternion(vm / ang, ang) if ang > 0.000001 else Quaternion.IDENTITY
	var tt: float = lerpf(ta, tb, t)
	return (sw * Quaternion(0.0, sin(tt * 0.5), 0.0, cos(tt * 0.5))).normalized()


static func _swing_vec(sw: Quaternion) -> Vector3:
	var vl: float = sqrt(sw.x * sw.x + sw.y * sw.y + sw.z * sw.z)
	if vl < 0.000001:
		return Vector3.ZERO
	var ang: float = 2.0 * atan2(vl, absf(sw.w))
	var sg: float = 1.0 if sw.w >= 0.0 else -1.0
	return Vector3(sw.x, sw.y, sw.z) * (sg * ang / vl)


## How much of a turn `t` (rad, about the bone's own z, the sagittal plane) a ragdoll may add to a shoulder or a hip whose pose is `q` before the bone leaves
## its swing cone toward the front or the back: the room is the cone's limit less where the pose already points. Keeps a loose leg from swinging through
## the pole of the hip and out the other side. A pure function of the pose.
static func flex_room(q: Quaternion, bone: int, t: float, shape: String = "") -> float:
	var v: Vector3 = q * Vector3(0, -1, 0)
	var phi: float = atan2(v.x, -v.y) if v.y < 0.0 or absf(v.x) > 0.0001 else PI
	var fwd: float = sw_dir[bone * 4] * scale_of(shape, "swing")
	var back: float = sw_dir[bone * 4 + 1] * scale_of(shape, "swing")
	return clampf(phi + t, -back, fwd) - phi
