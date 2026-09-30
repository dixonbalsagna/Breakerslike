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

var _base: Array[Quaternion] = []
var _base_hips := Vector3.ZERO
var _base_curl := Vector2(0.5, 0.5)
var _cur: Array[Quaternion] = []       # the base as smoothed this frame (recovery blends back to it)
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
var debug := {"contact_frames": 0, "contact_err_max": 0.0, "parts": 0, "nan": 0}


func _init(slot_: int) -> void:
	slot = slot_
	q = AnimPose.identity_q()
	_base = AnimPose.identity_q()
	_cur = AnimPose.identity_q()
	_tq = AnimPose.identity_q()
	gq.resize(AnimRig.N)
	gp.resize(AnimRig.N)
	for nm in ["x_pack", "x_sash_a1", "x_sash_a2", "x_sash_b1", "x_sash_b2"]:
		_spring_bones.append(AnimRig.index[nm])
	_lag.resize(AnimRig.N)


# ------------------------------------------------------------------ events (called once a tick by RenderAnim)

func on_tick(dt: float, frozen: bool) -> void:
	_spring_dt += dt * (0.1 if frozen else 1.0)


func on_cue(kind: String, T: float) -> void:
	if AnimData.cue_poses.has(kind) and RenderLook.CUE_POSES.has(kind):
		_cue = {"kind": kind, "t0": T, "dur": float(RenderLook.CUE_POSES[kind].dur)}


## `front`: the blow came from the side the victim faces. amp 0 to 1 from the hit's strength.
func on_hit(T: float, region: String, front: bool, amp: float) -> void:
	_reacts.append({"t0": T, "region": region, "front": front, "amp": clampf(amp, 0.2, 1.0)})
	if _reacts.size() > 4:
		_reacts.pop_front()


func socket(name: String) -> Vector3:
	return gp[AnimRig.index[name]] + root_off


## The head's centre in model space (for the head flashes).
func head_center() -> Vector3:
	var h: int = AnimRig.index["head"]
	return gp[h] + gq[h] * Vector3(0, 6, 0) + root_off


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
	var T: float = S.T
	var dt: float = clampf(T - _last_T, 0.0, 0.1) if _last_T >= 0.0 else 0.0
	var first: bool = _last_T < 0.0
	_last_T = T
	var lagk: float = float(prof.get("lag", 0.3))
	for i in range(AnimRig.N):
		_lag[i] = AnimData.bone_lag[i] * lagk / 0.45
	# 1. the base pose: what the fighter is doing when no blow, cue or reaction is on
	_target_base(S, f, T)
	var k: float = 1.0 if first else 1.0 - exp(-dt / maxf(float(prof.get("base_tau", 0.08)), 0.001))
	for i in range(AnimRig.N):
		_base[i] = _base[i].slerp(_tq[i], k)
	_base_hips = _base_hips.lerp(_tq_hips, k)
	_base_curl = _base_curl.lerp(_tq_curl, k)
	for i in range(AnimRig.N):
		q[i] = _base[i]
		_cur[i] = _base[i]
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
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		_exchange_layers(S, f, ex, T)
	# 4. the signature beam
	_beam_layer(S, f, T)
	# 5. reactions to blows
	_reaction_layer(T)
	# 6. moving hold, hit-stop shiver, spring chains
	var drift: float = float(prof.get("hold_drift", 0.0))
	if drift > 0.0:
		q[AnimRig.index["spine_2"]] = q[AnimRig.index["spine_2"]] * Quaternion(Vector3(0, 0, 1), sin(T * 2.3 + slot * 1.7) * 0.014 * drift)
		q[AnimRig.index["head"]] = q[AnimRig.index["head"]] * Quaternion(Vector3(0, 0, 1), sin(T * 1.7 + slot) * 0.02 * drift)
	var shiver: float = float(prof.get("shiver", 0.0))
	if S.dirS.stop > 0.0 and shiver > 0.0:
		root_off = Vector3(_signed(S.tick, slot), _signed(S.tick + 13, slot) * 0.6, 0.0) * shiver
	else:
		root_off = root_off * 0.0
	_springs(f)
	# 7. sockets
	AnimPose.fk(q, hips, gq, gp)
	for i in range(AnimRig.N):
		if is_nan(q[i].x) or is_nan(q[i].w):
			debug["nan"] += 1
			q[i] = Quaternion.IDENTITY
	frame = RenderAnim._frame_key(S)


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
	var sp: AnimPose = AnimData.pose("stance." + STANCES[stance])
	for i in range(AnimRig.N):
		_tq[i] = sp.q[i]
	_tq_hips = sp.hips
	_tq_curl = sp.curl
	var face: float = f.face
	var vf: float = f.vx * face
	var state: String = f.state
	if f.slide > 0.0:
		_blend_target("slide.brake", 1.0)
	elif state == "launched":
		var speed: float = Vector2(f.vx, f.vy).length()
		var stream: float = smoothstep(700.0, 2200.0, speed)
		var slow: float = 1.0 - smoothstep(150.0, 600.0, speed)
		_blend_target("launch.spread", 1.0)
		_blend_target("launch.stream", stream)
		_blend_target("launch.tuck", slow * 0.7)
	elif state == "down":
		_blend_target("down.prone", 1.0)
		_blend_target("down.getup", smoothstep(0.42, 0.72, f.stateT))
	elif state == "charging":
		_blend_target("charge.hold", 1.0)
	else:
		var wd: float = smoothstep(140.0, 720.0, vf)
		var wr: float = smoothstep(140.0, 520.0, -vf)
		_blend_target("move.dash", wd)
		_blend_target("move.retreat", wr * (1.0 - wd))
		if wd > 0.01:
			var pitch: float = clampf(atan2(f.vy, maxf(absf(f.vx), 60.0)), -0.9, 0.9) * 0.7 * wd
			var pi_: int = AnimRig.index["pelvis"]
			_tq[pi_] = _tq[pi_] * Quaternion(Vector3(0, 0, 1), pitch)


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
	for b in ex.beats:
		if b.op == "strike":
			var who: String = String(b.args.a)
			if who == role and (b.done or not ex.cancel):
				strikes.append([t0 + b.t, ordinal, b.args])
			ordinal += 1
		elif b.op == "chainStrike":
			if role == "A" and (b.done or not ex.cancel):
				strikes.append([t0 + b.t, ordinal, {"o": {"big": true}}])
			ordinal += 1
		elif b.op == "rush" and role == "A":
			rushes.append([t0 + b.t, float(b.args.dur)])
		elif b.op == "finRush" and String(b.args.w) == role:
			rushes.append([t0 + b.t, float(b.args.dur)])
	var prof: Dictionary = _prof
	var dq: float = 1.0 / float(prof.get("solve_hz", 60.0))
	# approach: launch-off, flight, arrival
	for r in rushes:
		var rs: float = r[0]
		var dur: float = maxf(r[1], DT)
		if T >= rs and T < rs + dur + 0.05:
			var tq: float = rs + floorf((T - rs) / dq) * dq
			var p: float = clampf((tq - rs) / dur, 0.0, 1.0)
			var fly: float = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.78, 1.0, p))
			_mix_pose(AnimData.pose("move.dash"), fly)
			var off: float = 1.0 - smoothstep(0.0, minf(4.0 * DT / dur, 0.3), p)
			_mix_pose(AnimData.pose("approach.launch"), off * 0.9)
	# strikes: the one whose window (load, snap, follow, recover) holds now, latest start first
	var Sn: float = float(prof.get("snap_ticks", 3)) * DT
	var F: float = float(prof.get("follow_ticks", 6)) * DT
	var R: float = float(prof.get("recover_ticks", 10)) * DT
	var best: int = -1
	var best_start: float = -1.0e9
	var lens: Array = []
	var prev_tc: float = -1.0e9
	for n in range(strikes.size()):
		var tc: float = strikes[n][0]
		var heavy: bool = _is_heavy(ex, strikes[n][2])
		var lnom: float = float(prof.get("load_ticks", {}).get("heavy" if heavy else "light", 12)) * DT
		var gap: float = tc - prev_tc
		var L: float = clampf(minf(lnom, gap - 0.5 * F), Sn + 2.0 * DT, lnom)
		lens.append(L)
		var start: float = tc - L
		if T >= start and T < tc + F + R and start > best_start:
			best = n
			best_start = start
		prev_tc = tc
	if best < 0:
		return
	var tc2: float = strikes[best][0]
	var L2: float = lens[best]
	var heavy2: bool = _is_heavy(ex, strikes[best][2])
	var side: bool = (_hash(int(ex.n), int(strikes[best][1]), slot + 1) & 1) == 1
	var picks: Array = AnimData.picks["heavy" if heavy2 else "light"]
	var ksid: String = String(picks[_hash(int(ex.n), int(strikes[best][1]), 3 + slot) % picks.size()])
	var ks: Dictionary = AnimData.keysets[ksid]
	_part = ksid
	var pc: AnimPose = AnimData.pose(String(ks["keys"][0]["pose"]), side)
	var pk: AnimPose = AnimData.pose(String(ks["keys"][1]["pose"]), side)
	var pf: AnimPose = AnimData.pose(String(ks["keys"][2]["pose"]), side)
	var tq2: float = tc2 + floorf((T - tc2) / dq + 0.0001) * dq
	if T >= tc2 - 0.0001 and T < tc2 + 0.0001:
		tq2 = tc2
	var dtc: float = tq2 - tc2
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
			q[i] = q[i].slerp(_cur[i], w4)
		hips = pf.hips.lerp(_base_hips, w4)
		curl = pf.curl.lerp(_base_curl, w4)
	# timing fidelity: on the frame of contact the pose must be the contact key
	if absf(T - tc2) < DT * 0.5:
		var err: float = 0.0
		for i in range(AnimRig.N):
			err = maxf(err, q[i].angle_to(pk.q[i]))
		debug["contact_frames"] += 1
		debug["contact_err_max"] = maxf(float(debug["contact_err_max"]), err)


# ------------------------------------------------------------------ beam, reactions, springs

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
		var w: float = amp * smoothstep(0.0, 0.05, tau) * (1.0 - smoothstep(0.12, 0.12 + 0.3 * amp, tau))
		if w <= 0.001:
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
	var vf: float = f.vx * f.face
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
