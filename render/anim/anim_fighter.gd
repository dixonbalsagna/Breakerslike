class_name AnimFighter
extends RefCounted
## The animator of one fighter (slice A1 of docs/animation/pose-pipeline.md): from the sim's state and events it solves a
## pose on rig R1 once a frame, and every pane's mannequin is written from it. Key poses come from data/anim/; between
## them it does the timing, easing, lag, overshoot and reactions. Render only: it reads the sim (fighter state, the running
## exchange's beats, events) and never writes it, draws no sim random numbers, and moves no anchor: a strike's contact
## pose lands on the beat's own time.
##
## The provisional part cue (until Combat's composer emits one): the running exchange is read straight from
## S.dirS.ex.beats. Its `strike` beats say when each blow lands and who throws it, its `rush` beats when a fighter
## closes, and every beat is scheduled before it fires, so the wind-up can start early enough. The pose layers, in order:
##   base (state, stance, movement, smoothed) -> cue pose -> approach or strike part -> beam -> reaction -> drift,
##   shiver and spring chains on the extras.
## What is not here yet (later slices): IK to the defender's socket and the ground, situation adaptation, the style
## modifier stack, inertialisation across parts, interpolation between tick states.

const DT := 1.0 / 60.0
const STANCES := ["aggressive", "defensive", "evasive", "escape"]

var slot: int = 0
var q: Array[Quaternion] = []
var hips := Vector3.ZERO
var curl := Vector2.ZERO
var root_off := Vector3.ZERO
var gq: Array[Quaternion] = []
var gp := PackedVector3Array()
var frame: int = -1
var version: int = 0                   # bumped by every real solve; a body skips its bone writes when it has this one
var _lag_k: float = -1.0
var _settle: int = 0
var _bkey: int = -1
var _full_fk: bool = false
const SOCKET_CHAIN := [0, 1, 2, 3, 4, 5, 11, 12, 13, 14]   # root, pelvis, spines, neck, head, near clavicle, arm, forearm, hand
const SOCKET_SET := ["root", "pelvis", "spine_1", "spine_2", "neck", "head", "clavicle_r", "upper_arm_r", "forearm_r", "hand_r"]

var _base: Array[Quaternion] = []
var _base_hips := Vector3.ZERO
var _base_curl := Vector2(0.5, 0.5)
var _tq: Array[Quaternion] = []
var _last_T: float = -1.0
var _cue: Dictionary = {}
var _reacts: Array = []
var _sx := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _sv := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _spring_dt: float = 0.0
var _spring_bones := PackedInt32Array()
var _lag := PackedFloat32Array()
var _prof: Dictionary = {}
var _part: String = ""                 # the key set playing this frame, "" for none (for tools)
var debug := {"contact_frames": 0, "contact_err_max": 0.0, "parts": 0, "nan": 0, "ik_frames": 0, "gap_max": 0.0, "gap_sum": 0.0, "gap_n": 0, "face_flips": 0, "gaps": [], "notes": [], "blows": 0, "late": 0, "late_notes": [], "variants": {}, "wound_strikes": 0, "wound_bad": 0}

## The facing the mannequin is drawn with (-1 or 1). The sim's `face` can lag a dodge warp or a swap of sides, so this one
## is derived from the opponent in an exchange and from the travel direction otherwise (A2, docs/animation section 9.3).
var vface: float = 1.0
var _face_key: int = -1
var _face_init: bool = false
var _face_want_t: float = -1.0
const IDLE_FAR := 700.0               # an idle fighter farther than this from the opponent relaxes
const FACE_DEAD := 14.0                # closer than this (on the shortest arc) the opponent gives no side
const FACE_HOLD := 0.03                # a new side must hold this long (s) before the turn starts
const TRAVEL_FACE := 250.0             # free of an exchange, faster than this faces the travel direction
const NEAR_LOOK := 900.0               # an idle fighter this close looks at the opponent

# the blow being thrown this frame, for the contact solve: weight, limb, target region, mirror, the defender
# Inertialisation (A2): when the solved pose jumps (a part starts or ends, a cue or a reaction lands, a mirrored key set
# follows its other-side twin), the jump is taken as an offset that decays over a short eased time, so nothing pops and the new
# pose is reached by itself. The offset is dropped on a blow's contact frame, so the contact key stays exact.
const INERTIA_JUMP := 0.5              # rad: a bone turning more than this in one solve is a join
const INERTIA_SNAPPY := 0.1            # s, how long a join takes to settle on a snappy fighter
const INERTIA_FLUID := 0.18
var _ip_raw: Array[Quaternion] = []
var _ip_off: Array[Quaternion] = []
var _ip_hraw := Vector3.ZERO
var _ip_hoff := Vector3.ZERO
var _ip_cur: Array[Quaternion] = []
var _ip_hcur := Vector3.ZERO
var _ip_t: float = 0.0
var _ip_acc: float = 0.0              # tick time since the last solve; a hit-stop still lets a join settle, at half speed
var _ip_dur: float = 0.1
var _ip_active: bool = false
var _ip_have: bool = false
var _ip_cos: float = cos(INERTIA_JUMP * 0.5)
var layers: String = ""                # tools: which layers shaped this frame (set only with debug_checks)
var _rushing: bool = false
var _contact_now: bool = false
# Battle damage (rule-of-cool feature 1), read from the wounds state the sim already has: how worn the fighter is (breathing),
# how close to the brink (the stagger and the sagging stance), and whether the arms or the legs are broken (one arm hangs, one
# leg is favoured; which one is a hash of the fighter's slot, since the sim keeps no side).
var _worn: float = 0.0
var _brinkp: float = 0.0
var _arm_broken: bool = false
var _leg_broken: bool = false
var _hang_right: bool = false
var _leg_right: bool = false
var _form: Dictionary = {}           # the running transformation: {t0, version}
var _seen_tc: int = -1
var _cx_n: int = -1                  # the parried exchange whose parry time is remembered
var _cx_t: float = 0.0               # ... its exchange time when the parry was first seen
var _tc_left: float = -1.0            # seconds to the next blow's contact, -1 when none is coming
var _ci_w: float = 0.0
var _ci_limb: String = "hand_r"
var _ci_target: String = "chest"
var _ci_side: bool = false
var _ci_opp = null
var _ci_tc: float = 0.0
var _ci_dmg: float = 0.0
var _gap_tc: float = -1.0
var _recoil_x: float = 0.0
var _step_x: float = 0.0               # the step-in a blow takes toward a defender beyond the arm and the hips' lunge


func _init(slot_: int) -> void:
	slot = slot_
	_hang_right = (_hash(slot_, 11, 3) & 1) == 0
	_leg_right = (_hash(slot_, 12, 5) & 1) == 0
	q = AnimPose.identity_q()
	_base = AnimPose.identity_q()
	_tq = AnimPose.identity_q()
	gq.resize(AnimRig.N)
	gp.resize(AnimRig.N)
	for nm in ["x_pack", "x_sash_a1", "x_sash_a2", "x_sash_b1", "x_sash_b2"]:
		_spring_bones.append(AnimRig.index[nm])
	_lag.resize(AnimRig.N)


# ------------------------------------------------------------------ events (called once a tick by RenderAnim)

func on_tick(dt: float, frozen: bool) -> void:
	_spring_dt += dt * (0.1 if frozen else 1.0)
	_ip_acc += dt * (0.5 if frozen else 1.0)


func on_cue(kind: String, T: float) -> void:
	if AnimData.cue_poses.has(kind) and RenderLook.CUE_POSES.has(kind):
		_cue = {"kind": kind, "t0": T, "dur": float(RenderLook.CUE_POSES[kind].dur)}


## `front`: the blow came from the side the victim faces. amp 0 to 1 from the hit's strength.
func on_hit(T: float, region: String, front: bool, amp: float, kind: String = "") -> void:
	_reacts.append({"t0": T, "region": region, "front": front, "amp": clampf(amp, 0.2, 1.0), "kind": kind})
	if _reacts.size() > 4:
		_reacts.pop_front()


## A transformation took place (the sim's `transform` event). Its three beats (data/anim/forms.json) play over the pause's
## own ticks (full and short) or over sim time (live).
func on_transform(T: float, version: String) -> void:
	if AnimData.forms.has(version):
		_form = {"t0": T, "version": version}
		debug["variants"]["transform_" + version] = int(debug["variants"].get("transform_" + version, 0)) + 1


func socket(name: String) -> Vector3:
	if not _full_fk and not SOCKET_SET.has(name):
		AnimPose.fk(q, hips, gq, gp)
		_full_fk = true
	return gp[AnimRig.index[name]] + root_off


## The head's centre in model space (for the head flashes).
func head_center() -> Vector3:
	var h: int = AnimRig.index["head"]
	return gp[h] + gq[h] * Vector3(0, 6, 0) + root_off


## The visual facing for this frame (computed once a frame, whichever pane asks first).
func update_face(S: SimState, f) -> float:
	var key: int = RenderAnim._frame_key(S)
	if key == _face_key:
		return vface
	_face_key = key
	if not _face_init:
		_face_init = true
		vface = f.face
		return vface
	var want: float = _wanted_face(S, f)
	if want == vface or want == 0.0:
		_face_want_t = -1.0
	elif _face_want_t < 0.0:
		_face_want_t = S.T
	elif S.T - _face_want_t >= FACE_HOLD:
		vface = want
		_face_want_t = -1.0
		debug["face_flips"] += 1
	return vface


func _opponent(S: SimState, f):
	for o in S.fighters:
		if o != f:
			return o
	return null


func _wanted_face(S: SimState, f) -> float:
	var opp = _opponent(S, f)
	var dx: float = SimWrap.sdx(f.x, opp.x) if opp != null else 0.0
	var ex = S.dirS.ex
	var engaged: bool = (ex != null and (ex.A == f or ex.D == f)) or f.state == "locked" or f.beamCharge != null
	if engaged:
		return signf(dx) if absf(dx) > FACE_DEAD else 0.0
	if f.state == "free" and absf(f.vx) > TRAVEL_FACE:
		var travel: float = signf(f.vx)
		# backing away from a close opponent keeps the face on him (the retreat pose); any other run faces the way it goes
		if travel != signf(dx) or absf(dx) > NEAR_LOOK or int(f.stance) == 3:
			return travel
		return signf(dx)
	if f.state == "free" and opp != null and absf(dx) > FACE_DEAD and absf(dx) < NEAR_LOOK and int(f.stance) != 3:
		return signf(dx)
	return f.face


static func _hash(a: int, b: int, c: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFFFFFF


static func _ease_out_back(u: float, ov: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u) + ov * sin(PI * u) * u


func _mixh(dst_h: Vector3, src_h: Vector3, w: float) -> Vector3:
	return dst_h.lerp(src_h, w)


# ------------------------------------------------------------------ the solve

func solve(S: SimState, f, prof: Dictionary) -> void:
	_prof = prof
	# On twos: a snappy fighter with nothing happening (no exchange, cue, reaction or beam) solves every second tick and the
	# bone writes are skipped on the others. A blow always solves, so no contact frame is missed.
	if version > 0 and float(prof.get("solve_hz", 60.0)) < 59.0 and (S.tick & 1) == 1 and _idle(S, f):
		frame = RenderAnim._frame_key(S)
		return
	version += 1
	update_face(S, f)
	_wound_read(f)
	var T: float = S.T
	var dt: float = clampf(T - _last_T, 0.0, 0.1) if _last_T >= 0.0 else 0.0
	var first: bool = _last_T < 0.0
	_last_T = T
	_set_lag(float(prof.get("lag", 0.3)))
	# 1. the base pose: what the fighter is doing when no blow, cue or reaction is on (a launch or a power-up moves on the
	# fluid profile, the rest on the default)
	_target_base(S, f, T)
	var bprof: Dictionary = _part_prof("launch") if f.state == "launched" else (_part_prof("power") if f.state == "charging" else prof)
	var k: float = 1.0 if first else 1.0 - exp(-dt / maxf(float(bprof.get("base_tau", 0.08)), 0.001))
	if _settle <= 40 or first:
		for i in range(AnimRig.N):
			_base[i] = _base[i].slerp(_tq[i], k)
		_base_hips = _base_hips.lerp(_tq_hips, k)
		_base_curl = _base_curl.lerp(_tq_curl, k)
	elif _settle == 41:
		for i in range(AnimRig.N):
			_base[i] = _tq[i]
		_base_hips = _tq_hips
		_base_curl = _tq_curl
	for i in range(AnimRig.N):
		q[i] = _base[i]
	hips = _base_hips
	curl = _base_curl
	# 2. a cue pose from Combat's cue events
	if not _cue.is_empty():
		var t: float = T - float(_cue.t0)
		var d: float = float(_cue.dur)
		if t >= d:
			_cue = {}
		elif t >= 0.0:
			var w: float = smoothstep(0.0, RenderLook.CUE_IN, t) * (1.0 - smoothstep(d - RenderLook.CUE_OUT, d, t))
			var cp: AnimPose = AnimData.pose(String(AnimData.cue_poses[_cue.kind]))
			AnimPose.mix(q, cp.q, w * 0.9)
			hips = hips.lerp(cp.hips, w * 0.9)
			curl = curl.lerp(cp.curl, w * 0.9)
	# 3. the exchange: approach and strike parts
	_part = ""
	_ci_w = 0.0
	_rushing = false
	_contact_now = false
	_tc_left = -1.0
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		_exchange_layers(S, f, ex, T)
	# 4. the signature beam, and a transformation
	_beam_layer(S, f, T)
	if not _form.is_empty():
		_transform_layer(S, T)
	# 4b. a broken arm hangs, a broken leg is favoured
	if _arm_broken or _leg_broken:
		_wound_limbs(f, T)
	# 5. reactions to blows
	_recoil_x = 0.0
	_step_x = 0.0
	_reaction_layer(T)
	# 5b. the striking limb reaches the defender (the contact solve)
	if _ci_w > 0.001:
		_contact_ik(S, f)
	# 6. moving hold, hit-stop shiver, spring chains
	var drift: float = float(prof.get("hold_drift", 0.0))
	if drift > 0.0:
		q[AnimRig.index["spine_2"]] = q[AnimRig.index["spine_2"]] * Quaternion(Vector3(0, 0, 1), sin(T * 2.3 + slot * 1.7) * 0.014 * drift)
		q[AnimRig.index["head"]] = q[AnimRig.index["head"]] * Quaternion(Vector3(0, 0, 1), sin(T * 1.7 + slot) * 0.02 * drift)
	if _worn > 0.04 or _brinkp > 0.4:
		_wear_motion(f, T)
	var shiver: float = float(prof.get("shiver", 0.0))
	if S.dirS.stop > 0.0 and shiver > 0.0:
		root_off = Vector3(_signed(S.tick, slot), _signed(S.tick + 13, slot) * 0.6, 0.0) * shiver
	else:
		root_off = root_off * 0.0
	root_off.x += _recoil_x + _step_x
	_springs(f)
	# 6a. inertialisation: a join in the solved pose decays instead of popping
	_inertialise(dt, prof)
	if RenderAnim.debug_checks:
		layers = ("cue:" + String(_cue.get("kind", "")) + " " if not _cue.is_empty() else "") + ("rush " if _rushing else "") + ("react " if not _reacts.is_empty() else "") + ("ik " if _ci_w > 0.001 else "") + ("beam " if f.beamCharge != null else "") + (f.state + " ")
	# 6b. the limb pass: elbows and knees stay hinges in human range, arms stay out of the shoulder's blind spot
	AnimPose.limit_limbs(q)
	# 7. sockets: only the chains the views read (the head and the near hand); the rest is on demand
	AnimPose.fk_chain(q, hips, gq, gp, SOCKET_CHAIN)
	_full_fk = false
	if is_nan(q[0].x) or is_nan(q[5].w):
		debug["nan"] += 1
		q[0] = Quaternion.IDENTITY
	elif RenderAnim.debug_checks:
		for i in range(AnimRig.N):
			if is_nan(q[i].x) or is_nan(q[i].w):
				debug["nan"] += 1
				q[i] = Quaternion.IDENTITY
	frame = RenderAnim._frame_key(S)


## Nothing is asking for a precise pose this tick.
func _idle(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	return (ex == null or (ex.A != f and ex.D != f)) and _cue.is_empty() and _reacts.is_empty() and f.beamCharge == null and S.beams.is_empty() and S.dirS.stop <= 0.0 and _form.is_empty()


## A blow counts as heavy from the exchange kind, the strike's own weight (o.big) or its damage.
static func _is_heavy(ex, args: Dictionary) -> bool:
	var o = args.get("o")
	return ex.kind == "heavy" or (o != null and bool(o.get("big", false))) or float(args.get("dmg", 0.0)) >= 40.0


static func _signed(tick: int, s: int) -> float:
	return float(_hash(tick, s, 7) & 1023) / 511.5 - 1.0


var _tq_hips := Vector3.ZERO
var _tq_curl := Vector2(0.5, 0.5)


func _target_base(S: SimState, f, T: float) -> void:
	var stance: int = clampi(int(f.stance), 0, 3)
	var vf: float = f.vx * vface
	var state: String = f.state
	# The blend weights, quantised to sixteenths: while they and the stance do not change the target is not rebuilt (the
	# base smoothing hides the steps), and once it has settled the smoothing stops too.
	var w1: float = 0.0
	var w2: float = 0.0
	var w3: float = 0.0
	var w4: float = 0.0              # hovering
	var w5: float = 0.0              # climbing
	var w6: float = 0.0              # diving
	var w7: float = 0.0              # winded (1) or relaxed (0.5) idle
	var w8: float = 0.0              # sprint, on top of the dash
	var w9: float = 0.0              # a guarded step forward
	var w10: float = 0.0             # a guarded step back
	var w11: float = 0.0             # the stance sagging toward the brink
	var mode: int = 0
	if f.slide > 0.0:
		mode = 1
	elif state == "launched":
		var speed: float = Vector2(f.vx, f.vy).length()
		w1 = smoothstep(700.0, 2200.0, speed)
		w2 = (1.0 - smoothstep(150.0, 600.0, speed)) * 0.7
		mode = 2
	elif state == "down":
		w1 = smoothstep(0.42, 0.72, f.stateT)
		mode = 7 if S.game.ko == f else 3
	elif state == "charging":
		mode = 4
	elif S.game.ko != null and S.game.ko != f and S.game.koT > 0.8 and state == "free":
		mode = 6
	else:
		w1 = smoothstep(140.0, 720.0, vf)
		w2 = smoothstep(140.0, 520.0, -vf) * (1.0 - w1)
		if w1 > 0.01:
			w3 = clampf(atan2(f.vy, maxf(absf(f.vx), 60.0)), -0.9, 0.9) * 0.7 * w1
		w8 = smoothstep(1000.0, 2200.0, vf)
		w9 = smoothstep(50.0, 180.0, vf) * (1.0 - smoothstep(300.0, 600.0, vf))
		w10 = smoothstep(50.0, 160.0, -vf) * (1.0 - smoothstep(260.0, 480.0, -vf))
		mode = 5
		if state == "free":
			w11 = smoothstep(0.35, 1.0, _brinkp) * 0.7
		# the variants: hovering (feet off the ground), climbing, diving; on the ground a winded idle when the ki is spent and
		# a relaxed one far from the opponent
		if state == "free" and w1 < 0.05 and w2 < 0.05:
			var air: float = smoothstep(30.0, 70.0, f.y - WorldTerrain.groundY(S, f.x))
			if air > 0.0:
				w4 = air
				w5 = air * smoothstep(150.0, 600.0, f.vy)
				w6 = air * smoothstep(150.0, 600.0, -f.vy)
			elif f.ki < 6.0:
				w7 = 1.0
			elif int(f.stance) < 2 and absf(f.vx) < 100.0:
				var opp = _opponent(S, f)
				if opp != null and absf(SimWrap.sdx(f.x, opp.x)) > IDLE_FAR:
					w7 = 0.5
	var key: int = mode | (stance << 3) | (int(w1 * 16.0) << 5) | (int(w2 * 16.0) << 10) | (int((w3 + 1.0) * 24.0) << 15) | (int(w4 * 8.0) << 21) | (int(w5 * 8.0) << 25) | (int(w6 * 8.0) << 29) | (int(w7 * 2.0) << 33) | (int(w8 * 8.0) << 35) | (int(w9 * 8.0) << 39) | (int(w10 * 8.0) << 43) | (int(w11 * 8.0) << 47)
	if key == _bkey:
		_settle += 1
		return
	_bkey = key
	_settle = 0
	var vk: String = ""
	if mode == 7:
		vk = "ko"
	elif mode == 6:
		vk = "victory"
	elif w4 > 0.5:
		vk = "hover" if w5 < 0.5 and w6 < 0.5 else ("climb" if w5 >= w6 else "dive")
	elif w8 > 0.5:
		vk = "sprint"
	elif w9 > 0.5 or w10 > 0.5:
		vk = "step"
	elif w7 >= 1.0:
		vk = "winded"
	elif w7 > 0.0:
		vk = "relaxed"
	if vk != "":
		debug["variants"][vk] = int(debug["variants"].get(vk, 0)) + 1
	var sp: AnimPose = AnimData.pose("stance." + STANCES[stance])
	for i in range(AnimRig.N):
		_tq[i] = sp.q[i]
	_tq_hips = sp.hips
	_tq_curl = sp.curl
	match mode:
		1:
			_blend_target("slide.brake", 1.0)
		2:
			_blend_target("launch.spread", 1.0)
			_blend_target("launch.stream", w1)
			_blend_target("launch.tuck", w2)
		3:
			_blend_target("down.prone", 1.0)
			_blend_target("down.getup", w1)
		4:
			_blend_target("charge.hold", 1.0)
		6:
			_blend_target("emote.victory", 1.0)
		7:
			_blend_target("down.ko", 1.0)
		_:
			_blend_target("move.dash", w1)
			_blend_target("move.retreat", w2)
			_blend_target("move.sprint", w8)
			_blend_target("move.step_f", w9)
			_blend_target("move.step_b", w10)
			_blend_target("wound.sag", w11)
			_blend_target("stance.air", w4)
			_blend_target("move.ascend", w5)
			_blend_target("move.descend", w6)
			if w7 >= 1.0:
				_blend_target("idle.winded", 1.0)
			elif w7 > 0.0:
				_blend_target("idle.relaxed", 0.8)
			if w3 != 0.0:
				var pi_: int = AnimRig.index["pelvis"]
				_tq[pi_] = _tq[pi_] * Quaternion(Vector3(0, 0, 1), w3)


func _blend_target(id: String, w: float) -> void:
	if w <= 0.001:
		return
	var p: AnimPose = AnimData.pose(id)
	for i in range(AnimRig.N):
		_tq[i] = _tq[i].slerp(p.q[i], w)
	_tq_hips = _tq_hips.lerp(p.hips, w)
	_tq_curl = _tq_curl.lerp(p.curl, w)


func _mix_pose(p: AnimPose, w: float) -> void:
	AnimPose.mix(q, p.q, w)
	hips = hips.lerp(p.hips, w)
	curl = curl.lerp(p.curl, w)


func _set_pose(p: AnimPose) -> void:
	for i in range(AnimRig.N):
		q[i] = p.q[i]
	hips = p.hips
	curl = p.curl


# ------------------------------------------------------------------ the exchange

func _exchange_layers(S: SimState, f, ex, T: float) -> void:
	var role: String = "A" if ex.A == f else "D"
	var t0: float = T - ex.t
	var strikes: Array = []
	var rushes: Array = []
	var ordinal: int = 0
	# a parried exchange: only the blows timed before the parry are drawn (the sim keeps listing, and later firing, the rest of
	# the string; Encounter will end it there)
	var ct: float = 1.0e9
	if ex.cancel:
		if _cx_n != int(ex.n):
			_cx_n = int(ex.n)
			_cx_t = ex.t
		ct = _cx_t
	for b in ex.beats:
		if b.op == "strike":
			var who: String = String(b.args.a)
			if who == role and (not ex.cancel or b.t <= ct + 0.0001):
				strikes.append([t0 + b.t, ordinal, b.args, "heavy" if _is_heavy(ex, b.args) else "light"])
			ordinal += 1
		elif b.op == "chainStrike":
			if role == "A" and (not ex.cancel or b.t <= ct + 0.0001):
				strikes.append([t0 + b.t, ordinal, {"o": {"big": true}}, "chain"])
			ordinal += 1
		elif b.op == "rush" and role == "A":
			rushes.append([t0 + b.t, float(b.args.dur)])
		elif b.op == "finRush" and String(b.args.w) == role:
			rushes.append([t0 + b.t, float(b.args.dur)])
	# approach: launch-off, flight, arrival (a rush is snappy)
	var rprof: Dictionary = _part_prof("rush")
	var rdq: float = 1.0 / float(rprof.get("solve_hz", 60.0))
	for r in rushes:
		var rs: float = r[0]
		var dur: float = maxf(r[1], DT)
		if T >= rs and T < rs + dur + 0.05:
			var tq: float = rs + floorf((T - rs) / rdq) * rdq
			var p: float = clampf((tq - rs) / dur, 0.0, 1.0)
			var fly: float = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.78, 1.0, p))
			_rushing = true
			_mix_pose(AnimData.pose("move.dash"), fly)
			var off: float = 1.0 - smoothstep(0.0, minf(4.0 * DT / dur, 0.3), p)
			_mix_pose(AnimData.pose("approach.launch"), off * 0.9)
	_beat_layers(ex, role, t0, T)
	# strikes: the one whose window (load, snap, follow, recover) holds now, latest start first. Each blow keeps the
	# profile of its own kind: light and chain blows snappy, heavy blows fluid.
	var best: int = -1
	var best_start: float = -1.0e9
	var lens: Array = []
	var profs: Array = []
	var prev_tc: float = -1.0e9
	for n in range(strikes.size()):
		var tc: float = strikes[n][0]
		var sp: Dictionary = _part_prof(String(strikes[n][3]))
		profs.append(sp)
		var Fn: float = float(sp.get("follow_ticks", 6)) * DT
		var Rn: float = float(sp.get("recover_ticks", 10)) * DT
		var Sn_: float = float(sp.get("snap_ticks", 3)) * DT
		var lnom: float = float(sp.get("load_ticks", {}).get("heavy" if strikes[n][3] == "heavy" else "light", 12)) * DT
		var gap: float = tc - prev_tc
		var L: float = clampf(minf(lnom, gap - 0.5 * Fn), Sn_ + 2.0 * DT, lnom)
		lens.append(L)
		var start: float = tc - L
		if T >= start and T < tc + Fn + Rn and start > best_start:
			best = n
			best_start = start
		prev_tc = tc
	if best < 0:
		return
	var prof: Dictionary = profs[best]
	_set_lag(float(prof.get("lag", 0.3)))
	var Sn: float = float(prof.get("snap_ticks", 3)) * DT
	var F: float = float(prof.get("follow_ticks", 6)) * DT
	var R: float = float(prof.get("recover_ticks", 10)) * DT
	var dq: float = 1.0 / float(prof.get("solve_hz", 60.0))
	var tc2: float = strikes[best][0]
	var L2: float = lens[best]
	var heavy2: bool = strikes[best][3] == "heavy"
	var side: bool = (_hash(int(ex.n), int(strikes[best][1]), slot + 1) & 1) == 1
	var picks: Array = AnimData.picks["heavy" if heavy2 else "light"]
	var ksid: String = String(picks[_hash(int(ex.n), int(strikes[best][1]), 3 + slot) % picks.size()])
	var ks: Dictionary = AnimData.keysets[ksid]
	# a broken arm does not strike and a broken leg does not kick: the blow uses the other limb (the sim keeps no side)
	var lb: String = String(ks.get("limb", "hand_r"))
	if lb.begins_with("hand") and _arm_broken:
		side = _hang_right
	elif lb.begins_with("foot") and _leg_broken:
		side = _leg_right
	if _arm_broken or _leg_broken:
		debug["wound_strikes"] += 1
		if (lb.begins_with("hand") and _arm_broken and (side == _hang_right) == false) or (lb.begins_with("foot") and _leg_broken and (side == _leg_right) == false):
			debug["wound_bad"] += 1
	_part = ksid
	var pc: AnimPose = AnimData.pose(String(ks["keys"][0]["pose"]), side)
	var pk: AnimPose = AnimData.pose(String(ks["keys"][1]["pose"]), side)
	var pf: AnimPose = AnimData.pose(String(ks["keys"][2]["pose"]), side)
	var tq2: float = tc2 + floorf((T - tc2) / dq + 0.0001) * dq
	if T >= tc2 - 0.0001 and T < tc2 + 0.0001:
		tq2 = tc2
	var dtc: float = tq2 - tc2
	var blow_id: int = int(ex.n) * 64 + int(strikes[best][1])
	if _seen_tc != blow_id:
		# a blow the sim announced fewer than 4 ticks ahead cannot be wound up (the pose pops to its contact key)
		_seen_tc = blow_id
		debug["blows"] += 1
		if T > tc2 - 3.5 * DT:
			debug["late"] += 1
			if debug["late_notes"].size() < 30:
				debug["late_notes"].append("tick %d %s (%s), %s, the blow %.0f ms ahead" % [S.tick, ex.kind, ex.tag, role, (tc2 - T) * 1000.0])
	if T < tc2 - 0.0001:
		_tc_left = tc2 - T
	debug["parts"] += 1
	if dtc < -Sn:
		var u: float = clampf((tq2 - (tc2 - L2)) / maxf(L2 - Sn, DT), 0.0, 1.0)
		u = pow(u, float(prof.get("load_ease", 2.0)))
		_mix_pose(pc, u)
	elif dtc < 0.0:
		_set_pose(pc)
		var u2: float = clampf((tq2 - (tc2 - Sn)) / Sn, 0.0, 1.0)
		AnimPose.mix_lag(q, pk.q, u2, _lag, 1.0)
		hips = pc.hips.lerp(pk.hips, u2)
		curl = pc.curl.lerp(pk.curl, u2)
	elif dtc < F:
		_set_pose(pk)
		var u3: float = clampf(dtc / F, 0.0, 1.0)
		var w3: float = _ease_out_back(u3, float(prof.get("overshoot", 0.1)))
		AnimPose.mix(q, pf.q, w3)
		hips = pk.hips.lerp(pf.hips, w3)
		curl = pk.curl.lerp(pf.curl, w3)
	else:
		_set_pose(pf)
		var u4: float = clampf((dtc - F) / R, 0.0, 1.0)
		var w4: float = u4 * u4 * (3.0 - 2.0 * u4)
		for i in range(AnimRig.N):
			q[i] = q[i].slerp(_base[i], w4)
		hips = pf.hips.lerp(_base_hips, w4)
		curl = pf.curl.lerp(_base_curl, w4)
	# timing fidelity: on the frame of contact the pose must be the contact key (checked before the contact solve moves it)
	if absf(T - tc2) < DT * 0.5:
		var err: float = 0.0
		for i in range(AnimRig.N):
			err = maxf(err, q[i].angle_to(pk.q[i]))
		_contact_now = true
		debug["contact_frames"] += 1
		debug["contact_err_max"] = maxf(float(debug["contact_err_max"]), err)
	# the contact solve's weight: in over the snap, full at the contact tick and through the first of the follow-through,
	# out over the rest of it
	var cw: float = 0.0
	if dtc >= -Sn and dtc < F + R * 0.4:
		if dtc < 0.0:
			cw = smoothstep(0.0, 1.0, (dtc + Sn) / Sn)
		elif dtc < F * 0.5:
			cw = 1.0
		else:
			cw = 1.0 - smoothstep(F * 0.5, F + R * 0.4, dtc)
	if cw > 0.001:
		_ci_w = cw
		_ci_limb = String(ks.get("limb", "hand_r"))
		_ci_target = String(ks.get("target", "chest"))
		_ci_side = side
		_ci_opp = ex.D if role == "A" else ex.A
		_ci_tc = tc2
		_ci_dmg = float(strikes[best][2].get("dmg", 0.0))


## The defensive and clash beats of the exchange (the sim's own: wind, slip, dodge, guardBreak, clashWave). Each is a short
## eased pose layer on the fighter it happens to, timed from the beat; a blow's own parts go over the top of them.
func _beat_layers(ex, role: String, t0: float, T: float) -> void:
	for b in ex.beats:
		var bt: float = t0 + b.t
		if T < bt - 0.2 or T > bt + 0.7:
			if b.op != "wind":
				continue
		match b.op:
			"wind":
				# the wind-up window: from the beat to the parryable blow that follows it
				var te: float = -1.0
				for b2 in ex.beats:
					if b2.op == "strike" and String(b2.args.a) == "A" and b2.t > b.t:
						te = t0 + b2.t
						break
				if te < 0.0 or T < bt or T > te + 0.4:
					continue
				var ready: float = smoothstep(bt, bt + 0.1, T) * (1.0 - smoothstep(te - 0.02, te + 0.1, T))
				if ready > 0.001 and not ex.cancel and role == "D":
					_mix_pose(AnimData.pose("def.parry_ready"), ready * 0.85)
				if ex.cancel:
					# parried: the defender sweeps the blow aside, the attacker is turned off line
					var pw: float = smoothstep(te - 0.02, te + 0.03, T) * (1.0 - smoothstep(te + 0.12, te + 0.3, T))
					if pw > 0.001:
						_mix_pose(AnimData.pose("def.parry" if role == "D" else "react.rebuff"), pw)
			"slip":
				if role == "D":
					_window_pose("def.slip", T - bt, 0.05, 0.15, 0.35)
			"dodge":
				if role == "D":
					_window_pose("def.blink_in", T - bt, 0.04, 0.12, 0.3)
			"guardBreak":
				if role == "D":
					_window_pose("def.guard_break", T - bt, 0.05, 0.25, 0.5)
			"clashWave":
				_window_pose("clash.push", T - bt, 0.05, 0.2, 0.4)


## A pose over the time since its beat: eased in over `rise`, held to `hold`, eased out by `end`.
func _window_pose(id: String, t: float, rise: float, hold: float, end: float) -> void:
	if t < 0.0 or t > end:
		return
	var w: float = smoothstep(0.0, rise, t) * (1.0 - smoothstep(hold, end, t))
	if w > 0.001:
		_mix_pose(AnimData.pose(id), w)


# ------------------------------------------------------------------ contact: the striking limb reaches the defender

const BODY_R := {"head": 5.0, "chest": 6.5, "gut": 6.5}   # how far the surface is in front of the point the region names
const END_LEN := {"hand": 6.0, "foot": 8.0}               # wrist (or ankle) to the face of the fist (or the foot)
const LUNGE_MAX := {"hand": 11.0, "foot": 7.0}            # how far the hips may carry the reach (model units)
const STEP_MAX := {"hand": 14.0, "foot": 10.0}            # ... and the whole body's step-in on top of that
const REACH_Z := {"hand": 5.0, "foot": 9.0}


## The defender's body point for a region, in the defender's model space.
func _region_point(name: String) -> Vector3:
	match name:
		"head":
			return head_center()
		"gut":
			var s1: int = AnimRig.index["spine_1"]
			return gp[s1] + gq[s1] * Vector3(0, 2, 0) + root_off
		_:
			var s2: int = AnimRig.index["spine_2"]
			return gp[s2] + gq[s2] * Vector3(0, 3, 0) + root_off


## IK the striking hand or foot onto the defender's body: the wrist (ankle) goes to the region's surface minus the fist, so
## the fist lands on him on the contact tick, and the hips lunge for what the arm cannot reach. The authored limb blends
## into the solved one by the contact weight, so the key poses stay the look and the defender's actual position decides
## where it lands. Nothing happens if the opponent is behind the thrower (the face override turns him first).
func _contact_ik(S: SimState, f) -> void:
	var opp = _ci_opp
	if opp == null or _ci_dmg <= 0.0:
		return
	var oaf: AnimFighter = RenderAnim.fighter(S, opp)
	if oaf.version == 0:
		return
	var base_limb: String = _ci_limb
	var limb: String = base_limb
	if _ci_side:
		limb = base_limb.substr(0, base_limb.length() - 1) + ("l" if base_limb.ends_with("r") else "r")
	var is_hand: bool = limb.begins_with("hand")
	var kind: String = "hand" if is_hand else "foot"
	var sfx: String = limb.substr(limb.length() - 1)
	var zs: float = 1.0 if sfx == "r" else -1.0
	var dx: float = SimWrap.sdx(f.x, opp.x)
	var rp: Vector3 = oaf._region_point(_ci_target)
	var mx: float = (dx + oaf.vface * rp.x) * vface
	if mx < 4.0:
		return
	var my: float = (opp.y - f.y) + rp.y
	var tgt := Vector3(mx - float(BODY_R.get(_ci_target, 6.5)) - float(END_LEN[kind]), my, float(REACH_Z[kind]) * zs)
	var ix: Dictionary = AnimRig.index
	var a: int = ix[("upper_arm_" if is_hand else "thigh_") + sfx]
	var b: int = ix[("forearm_" if is_hand else "shin_") + sfx]
	var c: int = ix[limb]
	AnimPose.fk(q, hips, gq, gp)
	_full_fk = true
	var reach: float = (gp[b] - gp[a]).length() + (gp[c] - gp[b]).length() - 0.5
	# how far forward the shoulder must come (along x, the way the hips and the step move it) for the arm to just reach
	var d3: Vector3 = tgt - gp[a]
	var side2: float = d3.y * d3.y + d3.z * d3.z
	var need: float = d3.x - (sqrt(reach * reach - side2) if side2 < reach * reach else 0.0)
	need = maxf(need, 0.0)
	# above or below the arm's reach whatever the lunge (a defender on another level): the excess is what is left over
	var excess: float = need - float(LUNGE_MAX[kind]) - float(STEP_MAX[kind])
	if side2 >= reach * reach:
		excess = sqrt(side2) - reach
	elif need <= 0.0 and d3.length() > reach:
		excess = d3.length() - reach   # the target is behind the shoulder (the fighters overlap): no step forward helps
	var lunge: float = minf(need, float(LUNGE_MAX[kind])) * _ci_w
	var step: float = clampf(need - float(LUNGE_MAX[kind]), 0.0, float(STEP_MAX[kind])) * _ci_w
	_step_x = step
	var ik_t: Vector3 = tgt - Vector3(lunge + step, 0.0, 0.0)
	var qa0: Quaternion = q[a]
	var qb0: Quaternion = q[b]
	var pole: Vector3 = gp[b]   # the elbow (knee) stays on the side the authored pose has it, so the solved limb is its neighbour
	AnimPose.ik2(q, gq, gp, a, b, c, ik_t, pole)
	AnimPose.hinge_fix(q, gq, gp, a, b, c, 1.0 if is_hand else -1.0)
	q[a] = qa0.slerp(q[a], _ci_w)
	q[b] = qb0.slerp(q[b], _ci_w)
	hips.x += lunge
	debug["ik_frames"] += 1
	if absf(S.T - _ci_tc) < DT * 0.5 and _ci_w > 0.99 and _ci_tc != _gap_tc:
		_gap_tc = _ci_tc
		var gap: float = maxf(0.0, (ik_t - gp[c]).length())
		debug["gap_max"] = maxf(float(debug["gap_max"]), gap)
		debug["gap_sum"] += gap
		debug["gap_n"] += 1
		debug["gaps"].append(snappedf(gap, 0.1))
		debug["gaps"].append(snappedf(excess, 0.1))
		if gap > 1.5 and debug["notes"].size() < 40:
			var ex = S.dirS.ex
			debug["notes"].append("tick %d %s (%s): target %.0f u ahead, short by %.1f (need %.1f, lunge %.1f, step %.1f), %s %s dmg %.0f" % [S.tick, ex.kind if ex != null else "-", ex.tag if ex != null else "-", mx, gap, need, lunge, step, _ci_target, limb, _ci_dmg])


func _inertialise(dt: float, prof: Dictionary) -> void:
	var n: int = AnimRig.N
	if not _form.is_empty() and _ip_have:
		# a transformation plays inside a pause (no ticks, so nothing to settle a join on): its own beats are the easing, and
		# the way back into the fight is inertialised once the ticks run again
		for i in range(n):
			_ip_raw[i] = q[i]
			_ip_cur[i] = Quaternion.IDENTITY
		_ip_hraw = hips
		_ip_hcur = Vector3.ZERO
		_ip_active = false
		return
	if not _ip_have:
		_ip_have = true
		_ip_raw.resize(n)
		_ip_off.resize(n)
		_ip_cur.resize(n)
		for i in range(n):
			_ip_raw[i] = q[i]
			_ip_off[i] = Quaternion.IDENTITY
			_ip_cur[i] = Quaternion.IDENTITY
		_ip_hraw = hips
		return
	var jump: bool = false
	for i in range(n):
		if absf(q[i].dot(_ip_raw[i])) < _ip_cos:
			jump = true
			break
	if jump:
		# continuity: what was drawn last solve (the old pose with the offset it carried) minus the new raw pose
		for i in range(n):
			_ip_off[i] = (_ip_cur[i] * _ip_raw[i]) * q[i].inverse()
		_ip_hoff = (_ip_hraw + _ip_hcur) - hips
		_ip_t = 0.0
		_ip_active = true
		# a join close to a blow must be spent by the contact tick (the contact key is exact), so it settles in the time left
		var dur0: float = float(prof.get("inertia_s", INERTIA_SNAPPY if float(prof.get("solve_hz", 60.0)) < 59.0 else INERTIA_FLUID))
		_ip_dur = dur0 if _tc_left < 0.0 else minf(dur0, maxf(_tc_left - 2.0 * DT, 0.0))
	for i in range(n):
		_ip_raw[i] = q[i]
	_ip_hraw = hips
	if not _ip_active:
		_ip_acc = 0.0
		return
	var idt: float = minf(_ip_acc, 0.1)
	_ip_acc = 0.0
	_ip_t += idt
	var w: float = 1.0 - smoothstep(0.0, _ip_dur, _ip_t) if _ip_dur > 0.0 else 0.0
	for i in range(n):
		var o: Quaternion = Quaternion.IDENTITY.slerp(_ip_off[i], w)
		_ip_cur[i] = o
		q[i] = o * q[i]
	_ip_hcur = _ip_hoff * w
	hips += _ip_hcur
	if w <= 0.0:
		_ip_active = false
		for i in range(n):
			_ip_cur[i] = Quaternion.IDENTITY
		_ip_hcur = Vector3.ZERO


func _set_lag(k: float) -> void:
	if k == _lag_k:
		return
	_lag_k = k
	for i in range(AnimRig.N):
		_lag[i] = AnimData.bone_lag[i] * k / 0.45


## The timing profile for a kind of part (light, heavy, chain, rush, launch, power): Orb's mix unless a style is forced.
func _part_prof(kind: String) -> Dictionary:
	if RenderAnim.style_forced():
		return _prof
	var nm: String = String(AnimData.by_part.get(kind, ""))
	return AnimData.profile(nm) if nm != "" else _prof


# ------------------------------------------------------------------ beam, reactions, springs

func _wound_read(f) -> void:
	if f.wd == null:
		return
	var at: float = float(f.wd.stageAt[2])
	var tot: float = 0.0
	for r in range(4):
		tot += float(f.wear[r])
	_worn = clampf(tot / (4.0 * at) * 1.6, 0.0, 1.0)
	_brinkp = SimWounds.brinkProgress(f)
	_arm_broken = int(f.stage[2]) == 3
	_leg_broken = int(f.stage[3]) == 3


## Heavy breathing from the average wear (faster and deeper as it rises, the shoulders heaving, the head heavy) and a
## stagger from the brink (a slow irregular sway of the pelvis and a little give in the hips). Sim time only, so it replays.
func _wear_motion(f, T: float) -> void:
	if f.state == "launched" or f.state == "down":
		return
	var ix: Dictionary = AnimRig.index
	var br: float = sin(T * TAU * (0.8 + 1.4 * _worn) + slot * 1.9)
	var amp: float = 0.02 + 0.08 * _worn
	var s2: int = ix["spine_2"]
	var hd: int = ix["head"]
	q[s2] = q[s2] * Quaternion(Vector3(0, 0, 1), br * amp)
	q[hd] = q[hd] * Quaternion(Vector3(0, 0, 1), -br * amp * 0.5 + 0.05 * _worn)
	var heave: float = br * 0.06 * _worn
	var cr: int = ix["clavicle_r"]
	var cl: int = ix["clavicle_l"]
	q[cr] = q[cr] * Quaternion(Vector3(1, 0, 0), -heave)
	q[cl] = q[cl] * Quaternion(Vector3(1, 0, 0), heave)
	var ps: float = smoothstep(0.45, 1.0, _brinkp)
	if ps > 0.0:
		var sw: float = 0.6 * sin(T * 1.7 + slot * 2.3) + 0.4 * sin(T * 2.9 + slot)
		var sw2: float = sin(T * 2.3 + slot * 1.1 + 1.0)
		var pe: int = ix["pelvis"]
		q[pe] = q[pe] * Quaternion(Vector3(1, 0, 0), ps * 0.07 * sw) * Quaternion(Vector3(0, 0, 1), ps * 0.04 * sw2)
		hips.x += ps * 2.0 * sw


## A broken arm hangs (the arm's bones go to wound.arm_limp, the hand slack) and a broken leg is favoured (the leg's bones and
## part of the pelvis go to wound.leg_favour, with a dip on each step when moving). Light in the air, strong on the ground.
func _wound_limbs(f, T: float) -> void:
	var ix: Dictionary = AnimRig.index
	var calm: bool = f.state != "launched" and f.state != "down"
	if _arm_broken:
		var lw: float = 0.92 if calm else 0.5
		var sfx: String = "r" if _hang_right else "l"
		var lp: AnimPose = AnimData.pose("wound.arm_limp", not _hang_right)
		for nm in ["upper_arm_", "forearm_", "hand_", "fingers_"]:
			var i: int = ix[nm + sfx]
			q[i] = q[i].slerp(lp.q[i], lw)
		if _hang_right:
			curl.y = lerpf(curl.y, lp.curl.y, lw)
		else:
			curl.x = lerpf(curl.x, lp.curl.x, lw)
	if _leg_broken:
		var lf: float = (0.85 if _part == "" else 0.5) if calm else 0.3
		var sf2: String = "r" if _leg_right else "l"
		var fp: AnimPose = AnimData.pose("wound.leg_favour", not _leg_right)
		for nm2 in ["thigh_", "shin_", "foot_"]:
			var i2: int = ix[nm2 + sf2]
			q[i2] = q[i2].slerp(fp.q[i2], lf)
		var pe: int = ix["pelvis"]
		q[pe] = q[pe].slerp(fp.q[pe], lf * 0.5)
		hips.z += fp.hips.z * lf * 0.7
		if calm and absf(f.vx) > 60.0 and _part == "":
			hips.y -= 2.0 * lf * maxf(0.0, sin(T * TAU * 1.6 + slot))


## The elapsed ticks of the running transformation, or -1 when it is over. full and short play inside the sim's pause, whose
## own ticks are the clock (S.pause.left counts them down); live has none and runs on sim time.
func _transform_layer(S: SimState, T: float) -> void:
	var v: String = String(_form.version)
	var spec: Dictionary = AnimData.forms[v]
	var total: int = int(spec.gather) + int(spec["break"]) + int(spec.settle)
	var e: float
	if v == "live":
		e = (T - float(_form.t0)) * 60.0
	elif S.pause.left > 0 and S.pause.actor == slot:
		e = float(total - S.pause.left)
	else:
		e = -1.0 if T > float(_form.t0) + 0.05 else 0.0
	if e < 0.0 or e >= float(total):
		_form = {}
		return
	_form_pose(spec, e, v == "live")


## The pose layer at `e` ticks into the transformation (the part tools test without a match).
func _form_pose(spec: Dictionary, e: float, live: bool) -> void:
	var g: float = float(spec.gather)
	var b: float = float(spec["break"])
	var s_: float = float(spec.settle)
	var hold: float = float(spec.hold)
	var fp: Dictionary = AnimData.form_poses
	if e < g:
		# the gather: compress (a live one is only a flinch inward)
		var u: float = e / g
		_mix_pose(AnimData.pose(String(fp.gather)), smoothstep(0.0, 1.0, u) * (0.6 if live else 1.0))
	elif e < g + b:
		# the break: one snap, the new pose locks on in this frame and the silhouette changes here and nowhere else
		var pb: AnimPose = AnimData.pose(String(fp["break"]))
		_set_pose(pb)
		var ub: float = (e - g) / b
		# a few ticks of overshoot past the lock, then the break pose holds
		var ov: float = sin(PI * clampf(ub * 4.0, 0.0, 1.0)) * 0.1
		AnimPose.mix(q, AnimData.pose(String(fp.settle)).q, clampf(smoothstep(0.4, 1.0, ub) - ov, 0.0, 1.0))
	else:
		# the settle: the new pose holds for `hold` ticks, then eases back into the fight (live: the upper body holds while he
		# drifts back, so it fades from the first tick)
		var ps: AnimPose = AnimData.pose(String(fp.settle))
		_set_pose(ps)
		var es: float = e - g - b
		var w: float = 1.0 - smoothstep(hold, s_, es)
		# back toward what he is doing
		for i in range(AnimRig.N):
			q[i] = _base[i].slerp(ps.q[i], w)
		hips = _base_hips.lerp(ps.hips, w)
		curl = _base_curl.lerp(ps.curl, w)


func _beam_layer(S: SimState, f, T: float) -> void:
	if f.beamCharge != null:
		var p: float = clampf((T - float(f.beamCharge)) / 0.8, 0.0, 1.0)
		_mix_pose(AnimData.pose("beam.charge"), smoothstep(0.0, 0.35, p))
		return
	for b in S.beams:
		if b.A == f and b.t < b.life:
			_mix_pose(AnimData.pose("beam.fire"), 1.0 - smoothstep(0.55, 0.95, b.t))
			return


func _reaction_layer(T: float) -> void:
	var keep: Array = []
	for r in _reacts:
		var tau: float = T - float(r.t0)
		var amp: float = float(r.amp)
		if tau < 0.0 or tau > 0.7:
			if tau < 0.0:
				keep.append(r)
			continue
		keep.append(r)
		_recoil_x += (-1.0 if bool(r.front) else 1.0) * amp * 6.0 * smoothstep(0.0, 0.02, tau) * exp(-tau / 0.07)
		var w: float = amp * smoothstep(0.0, 0.05, tau) * (1.0 - smoothstep(0.12, 0.12 + 0.3 * amp, tau))
		if w <= 0.001:
			continue
		if String(r.get("kind", "")) == "guard":
			# a guarded blow: forearms up and rocked back, no wound wave
			_mix_pose(AnimData.pose("def.guard_hit"), w * 0.85)
			continue
		var pose_id: String = "react.flinch_f" if bool(r.front) else "react.flinch_b"
		if String(r.region) == "core":
			pose_id = "react.fold" if amp > 0.7 else pose_id
		_mix_pose(AnimData.pose(pose_id), w * 0.7)
		var add_id: String = "react." + String(r.region)
		if AnimData.poses.has(add_id):
			AnimPose.add(q, AnimData.pose(add_id).q, w)
		# a damped wave up the spine
		var ix: Dictionary = AnimRig.index
		for pair in [["spine_1", 0.0], ["spine_2", 0.05], ["neck", 0.1], ["head", 0.15]]:
			var b2: int = ix[pair[0]]
			var ph: float = sin((tau - float(pair[1])) * 50.0) * exp(-(tau) * 9.0) * amp * 0.12
			q[b2] = q[b2] * Quaternion(Vector3(0, 0, 1), ph * (1.0 if bool(r.front) else -1.0))
	_reacts = keep


func _springs(f) -> void:
	var vf: float = f.vx * vface
	var target: float = -clampf(vf / 1600.0, -1.0, 1.0) * 0.9
	var h_all: float = minf(_spring_dt, 0.1)
	_spring_dt = 0.0
	if h_all > 0.0:
		var n: int = clampi(int(ceil(h_all / (1.0 / 120.0))), 1, 8)
		var h: float = h_all / n
		for _s in range(n):
			for kx in range(5):
				var stiff: float = [40.0, 60.0, 90.0, 60.0, 90.0][kx]
				var damp: float = 5.0
				var goal: float = target * [0.5, 1.0, 0.8, 1.0, 0.8][kx]
				var a: float = -stiff * (_sx[kx] - goal) - damp * _sv[kx]
				_sv[kx] += a * h
				_sx[kx] += _sv[kx] * h
	for kx in range(5):
		var bi: int = _spring_bones[kx]
		q[bi] = q[bi] * Quaternion(Vector3(0, 0, 1), clampf(_sx[kx], -0.9, 0.9))
