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
var _bkey2: int = -1
var _was_down: bool = false              # polish: a get-up after a fall (the rise out of the crouch is slower when worn)
var _rise_t0: float = -1.0
var _rise_dur: float = 0.3
var _air_w: float = 0.0                  # hovering, for the bob
var _lean: float = 0.0                  # the lean into acceleration, smoothed (rad)
var _prev_x: float = 0.0
var _have_x: bool = false
var _prev_cx: float = 0.0
var _smear: float = 0.0                 # the contact catch: how far behind the anchor the body is drawn (model units), decaying
var _smear_t0: float = -10.0
var _full_fk: bool = false
const _LEG_BONES := [16, 17, 19, 20]                  # thigh_l, shin_l, thigh_r, shin_r
const LEG_CHAIN := [0, 1, 16, 17, 18, 19, 20, 21]   # root, pelvis, thigh, shin, foot of each leg
const SOCKET_CHAIN := [0, 1, 2, 3, 4, 5, 11, 12, 13, 14]   # root, pelvis, spines, neck, head, near clavicle, arm, forearm, hand
const SOCKET_SET := ["root", "pelvis", "spine_1", "spine_2", "neck", "head", "clavicle_r", "upper_arm_r", "forearm_r", "hand_r"]

var _base: Array[Quaternion] = []
var _base_hips := Vector3.ZERO
var _base_curl := Vector2(0.5, 0.5)
var _tq: Array[Quaternion] = []
var _last_T: float = -1.0
var _cue: Dictionary = {}
var _seq: Dictionary = {}          # a pose sequence of Encounter's step 3 cues (data/anim/waves/step3.*): {id, t0, dur}
var _gc_hold_t0: float = -1.0           # a held ground-contact pose (the brace of a tumble) from this time ...
var _ag_hold: String = ""              # the agency slice's held pose (a knockback, a charge: docs 9.22) from _ag_t0 ...
var _ag_kind: String = ""              # ... of this kind (a key of data/anim/agency.json)
var _ag_t0: float = -1.0
var _ag_t1: float = -1.0               # ... until this time (-1: until the exchange, a fall or the cap ends it)
var _ag_w: float = 0.0
var _ag_in: float = 0.1
var _ag_out: float = 0.15
var _ls_t0: float = -1.0               # the last stand's window open from this time (the held resolve), -1 when closed ...
var _ls_t1: float = -1.0               # ... and closed at this time (the resolve fades out)
var _intro: Dictionary = {}           # the opening, from the sim's events: {on, fall_t, fall_dur, land_t, stare_t, stare_dur} (seconds on the sim's tick)
var _gc_hold_w: float = 0.5            # how much of the pose the brace is (set when it starts: firmer when slow and unworn, looser when fast and worn)
var _gc_hold_t1: float = -1.0           # ... until this one (-1 while it lasts)
var _stun_prev: int = 0
var _stun_watch: int = 0           # ticks left to see this fighter staggered after a perfect block or a reversal (a DEFLECT staggers nobody)
var _stun_seq: String = ""
var _stun_t0: float = 0.0
var _shove_watch: int = 0          # ticks left to see the burst shove this fighter (a jump in his own speed)
var _shove_vx: float = 0.0
var _reacts: Array = []
var _sx := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _sv := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _spring_dt: float = 0.0
var _spring_bones := PackedInt32Array()
var _lag := PackedFloat32Array()
var _prof: Dictionary = {}
var _part: String = ""                 # the key set playing this frame, "" for none (for tools)
var debug := {"contact_frames": 0, "contact_err_max": 0.0, "parts": 0, "nan": 0, "ik_frames": 0, "gap_max": 0.0, "gap_sum": 0.0, "gap_n": 0, "face_flips": 0, "gaps": [], "notes": [], "blows": 0, "late": 0, "late_notes": [], "variants": {}, "wound_strikes": 0, "wound_bad": 0, "skims": 0, "ground_events": 0, "rd_ticks": 0, "rd_usec": 0, "catches": 0, "slope_frames": 0, "aims": 0, "pre_brace": 0, "near_miss": 0, "guard_kicks": 0, "personality": 0, "feet_usec": 0, "feet_n": 0, "survey": 0, "ko_falls": 0, "leans": 0, "overcommits": 0, "blocked": 0, "turn_steps": 0, "bursts": 0, "brakes": 0, "shocks": 0}

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
# The active ragdoll (overhaul unit A): stepped once per sim tick from the fighter's own state, shown at out_w.
var _rd := AnimRagdoll.new()
var _rd_have: bool = false
var _rd_vw := Vector2.ZERO              # last tick's world velocity (for the acceleration)
var _rd_prev_state: String = ""
var _rd_prev_slide: bool = false
var _rd_prev_speed: float = 0.0
var _skim_t0: float = -1.0
var _shape_set: bool = false
var _skip_inertia: bool = false
var _blow_snap: bool = false             # this solve is the snap of a blow into its contact key: the authored jump, not a join to settle
var _lean_id: int = -1                  # the dodge already leaned away from
var _over_id: int = -1                  # the whiff already over-committed on
var _lean_t0: float = -10.0             # sim time of the lean-away, the over-commit and the blocked recoil
var _over_t0: float = -10.0
var _block_t0: float = -10.0
var _bank: float = 0.0                 # roll into a turn (flight overhaul, unit G), smoothed
var _burst_t0: float = -10.0           # a dash start and a stop: when they were seen (sim time)
var _brake_t0: float = -10.0
var _shock_t0: float = -10.0           # a nearby impact: when, and how hard
var _shock_amp: float = 0.0
var _gait_speed: float = 0.0
var _turn_t0: float = -10.0            # a turn-around is a step: when the visual facing last flipped, and to which side
var _turn_dir: float = 1.0
var _stance_prev: int = -1
var _base_r := PackedFloat32Array()
var _hit_w: float = 0.0                 # how much of the fighter's own flinch shape is pulled in after a hit (decays)
var _hit_crum: float = 0.0              # ... and how much of it is the crumple (a heavy blow) rather than the brace (a light one)
var _miss_id: int = -1                  # the last near miss flinched at
var _sp_vw := Vector2.ZERO
var _sp_have: bool = false
var _look_target: float = 0.0
var _look: float = 0.0                 # the head's pitch toward the opponent, smoothed
var _leg_dq: Array[Quaternion] = []
var _leg_tick: int = -10
var _gf_gtick: int = -100
var _gf_gx: float = 0.0
var _gf_g0c: float = 0.0
var _gf_x_valid: bool = false
var _gf_x: float = 0.0
var _gf_face: float = 1.0
var _gf_tick: int = -100
var _gf_g0: float = 0.0
var _gf_dF: float = 0.0
var _gf_dB: float = 0.0
var _gf_sl: float = 0.0
var _foot_w: float = 0.0               # how much the feet are placed on a slope now (eases in and out)
var _foot_shift: float = 0.0           # the pelvis shift of the last placement (for tools)
var _foot_dh := Vector2.ZERO           # the ground under each foot relative to under him (for tools)
var _skid_pitch: float = 0.0
var _hit_n: int = 0                     # hits taken (the variant hash)
var _hit_free: float = 0.0              # how loose a hit leaves the limbs; decays, slower with wear
var layers: String = ""                # tools: which layers shaped this frame (set only with debug_checks)
var _rushing: bool = false
var _contact_now: bool = false
# Battle damage (rule-of-cool feature 1), read from the wounds state the sim already has: how worn the fighter is (breathing),
# how close to the brink (the stagger and the sagging stance), and whether the arms or the legs are broken (one arm hangs, one
# leg is favoured; which one is a hash of the fighter's slot, since the sim keeps no side).
var _worn: float = 0.0
var _brinkp: float = 0.0
var audit: Dictionary = {}               # joint audit (RenderAnim.joint_audit): stage -> the violations found there (A before the contact solve, B after it, C after the ragdoll, D after every layer)
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
var _ci_limb2: String = ""             # a second striking limb of a two-limb blow (a key set's limb2), or ""
var _ci_step: float = -1.0              # the key set's own step-in limit (model units), or -1 for the limb's default in sockets.json
var _ci_opp = null
var _ci_tc: float = 0.0
var _ci_dmg: float = 0.0
var _gap_tc: float = -1.0
var _recoil_y: float = 0.0
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

func on_tick(dt: float, frozen: bool, S: SimState = null, f = null) -> void:
	_spring_dt += dt * (0.1 if frozen else 1.0)
	_ip_acc += dt * (0.5 if frozen else 1.0)
	if S != null and f != null:
		update_face(S, f)   # the facing is decided once per sim tick too, so everything keyed on it replays
		# a stagger with no cue of its own (the 12 ticks a blocked string leaves its attacker, the loser of a finisher's set-up): a short one
		var sn: int = int(f.stunTicks)
		if sn > 0 and _stun_prev == 0 and RenderAnim.step3_cues and _seq.is_empty() and _stun_watch == 0 and f.state == "free" and AnimData.entries.has("s3.stagger_short"):
			_seq = {"id": "s3.stagger_short", "t0": S.T, "dur": clampf(float(sn), 8.0, 30.0) / 60.0}
			debug["step3"] = int(debug.get("step3", 0)) + 1
		_stun_prev = sn
		if _stun_watch > 0:
			_stun_watch -= 1
			if int(f.stunTicks) > 0 and AnimData.entries.has(_stun_seq):
				_seq = {"id": _stun_seq, "t0": _stun_t0, "dur": float(AnimData.entries[_stun_seq].dur) / 60.0}
				debug["step3"] = int(debug.get("step3", 0)) + 1
				_stun_watch = 0
		if _shove_watch > 0:
			_shove_watch -= 1
			if absf(f.vx - _shove_vx) > 250.0 and AnimData.cue_map.has("burst") and AnimData.entries.has(String(AnimData.cue_map.burst.get("other_if_shoved", ""))):
				var sid2: String = String(AnimData.cue_map.burst.other_if_shoved)
				_seq = {"id": sid2, "t0": S.T, "dur": float(AnimData.entries[sid2].dur) / 60.0}
				_shove_watch = 0
		# a change of stance kicks the arms toward the new guard on the tick it happens (it was read at solve time, so a change on an odd tick
		# came a tick late at two ticks a frame and the ragdoll state differed)
		var st_now: int = clampi(int(f.stance), 0, 3)
		if _stance_prev != st_now:
			if _stance_prev >= 0 and RenderAnim.layer("transitions"):
				_stance_kick(_stance_prev, st_now)
			_stance_prev = st_now
		_spring_tick(S, f, dt, frozen)
		if not frozen:
			_rd_tick(S, f, dt)
			if RenderAnim.layer("look"):
				_look_tick(S, f, dt)


## A crater was dug near him (the sim's crater event): a hover shudders and the arms start; amp 0 to 1 from the energy and the distance.
func on_shock(T: float, amp: float) -> void:
	if amp <= 0.02:
		return
	_shock_t0 = T
	_shock_amp = minf(1.0, _shock_amp * exp(-(T - _shock_t0) / 0.5) + amp)
	var a: float = _rd_amp() * amp
	_rd.kick(2, 4.0 * a)
	_rd.kick(5, 4.0 * a)
	_rd.kick(1, -2.0 * a)
	_rd.out_w = 1.0
	debug["shocks"] += 1


## A launched fighter skipped off water (the sim's skim event): the body arches and flares for an instant.
func on_skim(T: float, spd: float) -> void:
	_skim_t0 = T
	var amp: float = _rd_amp()
	_rd.kick(0, 5.0 * amp)
	_rd.kick(1, 6.0 * amp)
	_rd.kick(2, -4.0 * amp)
	_rd.kick(5, -4.0 * amp)
	debug["skims"] += 1


## World's ground-contact events (left_ground, bounce, land, tumble_end; docs/world/ground-contact.md section 4). They plug
## into the same body: a bounce whips it by the normal speed, a slam or a skid folds it, the end of a tumble lets it go.
## The agency slice's events (data/anim/agency.json): a knockback holds a pose for as long as he is sent back, the embed plays its sequence over the held-down
## ticks, the far taunt a shrug over the flight, the charges a held flight pose until the exchange starts; a feint peels off (docs/director/agency-slice-3.md).
func on_agency(kind: String, T: float, e: Dictionary) -> void:
	var A: Dictionary = AnimData.agency
	if not RenderAnim.agency_poses or A.is_empty():
		return
	var wt: float = 0.6 if RenderAnim.reduced_motion else 1.0
	match kind:
		"knockback":
			var kk: Dictionary = A.get("knockback", {}).get(String(e.get("kind", "slideShort")), {})
			if kk.is_empty() or not AnimData.pose_exists(String(kk.hold)):
				return
			_ag_hold = String(kk.hold)
			_ag_kind = "knockback"
			_ag_t0 = T
			_ag_t1 = T + clampf(float(e.get("dur", 0.5)), 0.1, 3.0)
			_ag_w = float(kk.weight) * wt
			_ag_in = float(kk.get("in", 0.08))
			_ag_out = float(kk.get("out", 0.15))
			debug["agency"] = int(debug.get("agency", 0)) + 1
		"embed":
			var em: Dictionary = A.get("embed", {})
			if AnimData.entries.has(String(em.get("seq", ""))):
				var dur: float = maxf(float(e.get("dur", 1.0)), 0.3)
				_seq = {"id": String(em.seq), "t0": T, "dur": dur, "wt": float(em.get("weight", 1.0))}
				debug["agency"] = int(debug.get("agency", 0)) + 1
		"taunt_start":
			var tn: Dictionary = A.get("taunt", {})
			if AnimData.entries.has(String(tn.get("seq", ""))):
				_seq = {"id": String(tn.seq), "t0": T, "dur": float(AnimData.entries[String(tn.seq)].dur) / 60.0, "wt": float(tn.get("weight", 0.7)) * wt}
				debug["agency"] = int(debug.get("agency", 0)) + 1
		"taunt_end_cut":
			if String(_seq.get("id", "")) == String(A.get("taunt", {}).get("seq", "")):
				_seq = {}
		"charge_light", "charge_heavy", "charge_feint":
			var which: String = kind.substr(7)
			var cc: Dictionary = A.get("charge", {}).get(which, {})
			if cc.is_empty() or not AnimData.pose_exists(String(cc.hold)):
				return
			_ag_hold = String(cc.hold)
			_ag_kind = "charge_" + which
			_ag_t0 = T
			_ag_t1 = (T + float(cc.ticks) / 60.0) if cc.has("ticks") else -1.0
			_ag_w = float(cc.weight) * wt
			_ag_in = float(cc.get("in", 0.1))
			_ag_out = float(cc.get("out", 0.15))
			debug["agency"] = int(debug.get("agency", 0)) + 1


## The held agency pose: eased in, held, eased out. A charge ends by itself when its exchange starts (the sim begins it at the wind-up), when he falls or at its cap.
func _agency_layer(S: SimState, f, T: float) -> void:
	if _ag_t0 < 0.0 or not AnimData.pose_exists(_ag_hold):
		return
	var cfg: Dictionary = AnimData.agency
	if _ag_kind.begins_with("charge_") and _ag_t1 < 0.0:
		var cap: float = float(cfg.get("charge", {}).get(_ag_kind.substr(7), {}).get("max_ticks", 90)) / 60.0
		var ex = S.dirS.ex
		if T - _ag_t0 > cap or f.state == "launched" or f.state == "down" or (ex != null and (ex.A == f or ex.D == f)):
			_ag_t1 = T
	var wgt: float = smoothstep(0.0, _ag_in, T - _ag_t0)
	if _ag_t1 >= 0.0:
		wgt *= 1.0 - smoothstep(0.0, _ag_out, T - _ag_t1)
		if T - _ag_t1 >= _ag_out:
			_ag_t0 = -1.0
			_ag_t1 = -1.0
			return
	wgt *= _ag_w
	if wgt > 0.001:
		var ap: AnimPose = AnimData.pose(_ag_hold)
		AnimPose.mix(q, ap.q, wgt)
		hips = hips.lerp(ap.hips, wgt)
		curl = curl.lerp(ap.curl, wgt)


## The last stand (docs/architecture/last-stand.md): ready starts his steadying beat in his own shape and the held resolve; end `used` lets the resolve go
## (the signature's own animation takes over), `expired` slumps him.
func on_last_stand(kind: String, t: float, dur: float, end_kind: String) -> void:
	var L: Dictionary = AnimData.last_stand
	if not RenderAnim.last_stand_poses or L.is_empty():
		return
	if kind == "last_stand_ready":
		var sk: String = _rd.shape_key
		var sid: String = String(L.get("ready", {}).get(sk, L.get("ready", {}).get("default", "")))
		if AnimData.entries.has(sid):
			_seq = {"id": sid, "t0": t, "dur": float(AnimData.entries[sid].dur) / 60.0, "wt": 0.6 if RenderAnim.reduced_motion else 1.0}
			debug["last_stand"] = int(debug.get("last_stand", 0)) + 1
		_ls_t0 = t
		_ls_t1 = -1.0
	elif kind == "last_stand_end":
		if _ls_t0 >= 0.0 and _ls_t1 < 0.0:
			_ls_t1 = t
		if end_kind == "expired" and AnimData.entries.has("ls.slump"):
			_seq = {"id": "ls.slump", "t0": t, "dur": float(AnimData.entries["ls.slump"].dur) / 60.0, "wt": 0.6 if RenderAnim.reduced_motion else 1.0}


## The opening's pose from the sim's tick: waiting or falling (the body one narrow line, head first), the landing (a deep compression with one open hand on
## the ground and the head up, held, then up through a half crouch), the staredown (upright and loose, one small beat of character for his shape, then the
## tension in the last stretch before the clock). Reduced motion: no fall and no landing: he drops into frame and stands.
func _intro_layer(S: SimState, f) -> void:
	var I: Dictionary = AnimData.intro
	var tk: float = float(S.tick) / 60.0
	var reduced: bool = RenderAnim.reduced_motion
	var dq: float = 1.0 / 60.0
	var set_p: AnimPose = AnimData.pose("in.hold.set")
	var landed: bool = float(_intro.land_t) >= 0.0 and tk >= float(_intro.land_t)
	var pose_in: AnimPose = AnimData.pose("in.hold.fall") if not reduced else set_p
	if not landed:
		AnimPose.mix(q, pose_in.q, 1.0)
		hips = pose_in.hips
		curl = pose_in.curl
		return
	var tl: float = tk - float(_intro.land_t)
	var land_dur: float = float(AnimData.entries["in.land"].dur) / 60.0 if AnimData.entries.has("in.land") else 1.0
	if tl < land_dur and not reduced and AnimData.entries.has("in.land"):
		if tl < 0.12:
			_skip_inertia = true   # the touchdown snaps (the join from the fall is the blow of the landing, not something to ease)
		_entry_layer(float(_intro.land_t), land_dur, "in.land", tk, dq)
		return
	AnimPose.mix(q, set_p.q, 1.0)
	hips = set_p.hips
	curl = set_p.curl
	var st: float = float(_intro.stare_t)
	if st < 0.0:
		return
	# the tension in the last stretch of the staredown
	var tense_p: AnimPose = AnimData.pose("in.hold.tense")
	var lead: float = float(I.get("tense_lead", 1.8))
	var ramp: float = float(I.get("tense_ramp", 0.8))
	var t_end: float = st + float(_intro.stare_dur)
	var tw: float = smoothstep(t_end - lead, t_end - lead + ramp, tk) if not reduced else 0.0
	if tw > 0.001:
		AnimPose.mix(q, tense_p.q, tw)
		hips = hips.lerp(tense_p.hips, tw)
		curl = curl.lerp(tense_p.curl, tw)
	# one small beat of character for his shape, early in the staredown
	var sk: String = String(AnimRagdoll.shape_of.get(String(f.id), AnimRagdoll.shape_of.get("default", "")))
	var beat: Dictionary = I.get("beats", {}).get(sk, {})
	if not beat.is_empty() and not reduced and AnimData.entries.has(String(beat.get("seq", ""))):
		var b0: float = st + float(beat.get("at", 1.0))
		var bd: float = float(AnimData.entries[String(beat.seq)].dur) / 60.0
		if tk >= b0 and tk < b0 + bd + 0.05:
			_entry_layer(b0, bd, String(beat.seq), tk, dq)


## The opening's events (docs/architecture/intro-phase.md), at their own tick in seconds: the match clock is frozen, so this is the only time there is.
func on_intro(kind: String, t: float, dur: float, clock_kind: String) -> void:
	if not RenderAnim.intro_poses or AnimData.intro.is_empty():
		return
	match kind:
		"intro_start":
			_intro = {"on": true, "fall_t": -1.0, "fall_dur": 0.6, "land_t": -1.0, "stare_t": -1.0, "stare_dur": 2.6}
		"entrance_fall":
			if not _intro.is_empty():
				_intro["fall_t"] = t
				_intro["fall_dur"] = maxf(dur, 0.1)
		"entrance_land":
			if not _intro.is_empty():
				_intro["land_t"] = t
		"staredown_start":
			if not _intro.is_empty():
				_intro["stare_t"] = t
				_intro["stare_dur"] = maxf(dur, 0.5)
		"clock_start":
			_intro = {}


func on_ground_event(kind: String, e: Dictionary, T: float) -> void:
	var amp: float = _rd_amp()
	debug["ground_events"] += 1
	var G: Dictionary = AnimData.ground
	var poses_on: bool = RenderAnim.ground_poses and not G.is_empty() and AnimData.entries.has("gc.bounce")
	var surf: float = float(G.get("surface", {}).get(String(e.get("surface", "soil")), 1.0))
	match kind:
		"bounce":
			var vn: float = absf(float(e.get("vn", 0.0)))
			_rd.crumple(clampf(vn / 2500.0, 0.2, 1.5) * 0.6 * surf, amp)
			# the tangent speed whips the body the way it travels
			_rd.kick(1, clampf(float(e.get("vt", 0.0)) * vface / 220.0, -9.0, 9.0) * amp)
			if poses_on:
				var bw: float = clampf(vn / float(G.get("bounce", {}).get("ref", 1800.0)), float(G.get("bounce", {}).get("min", 0.35)), 1.0) * clampf(surf, 0.6, 1.0)
				_seq = {"id": "gc.bounce", "t0": T, "dur": float(AnimData.entries["gc.bounce"].dur) / 60.0, "wt": bw * (0.6 if RenderAnim.reduced_motion else 1.0)}
				debug["gc_poses"] = int(debug.get("gc_poses", 0)) + 1
		"left_ground":
			var cause: String = String(e.get("cause", ""))
			if poses_on and cause != "bounce" and cause != "":
				var lw: float = clampf(float(e.get("spd", 1000.0)) / float(G.get("launch", {}).get("ref", 2000.0)), float(G.get("launch", {}).get("min", 0.4)), 1.0)
				_seq = {"id": "gc.lip_launch", "t0": T, "dur": float(AnimData.entries["gc.lip_launch"].dur) / 60.0, "wt": lw * (0.6 if RenderAnim.reduced_motion else 1.0)}
				_gc_hold_t1 = T if _gc_hold_t0 >= 0.0 and _gc_hold_t1 < 0.0 else _gc_hold_t1
				debug["gc_poses"] = int(debug.get("gc_poses", 0)) + 1
		"land":
			var lk: String = String(e.get("kind", ""))
			if lk == "slam":
				_rd.crumple(1.0, amp)
				if poses_on:
					_seq = {"id": "gc.bounce", "t0": T, "dur": float(AnimData.entries["gc.bounce"].dur) / 60.0, "wt": 1.0}
			elif lk == "skid":
				_rd.crumple(0.5, amp)
			elif lk == "tumble":
				_rd.crumple(0.5 * surf, amp)
				if poses_on and (_gc_hold_t0 < 0.0 or _gc_hold_t1 >= 0.0):
					_gc_hold_t0 = T
					_gc_hold_t1 = -1.0
					var H: Dictionary = G.get("hold", {})
					var spd_k: float = lerpf(float(H.get("slow_k", 1.4)), float(H.get("fast_k", 0.7)), smoothstep(float(H.get("slow_speed", 300.0)), float(H.get("fast_speed", 1500.0)), float(e.get("spd", 800.0))))
					var wear_k: float = 1.0 - float(H.get("worn_loosen", 0.5)) * smoothstep(float(H.get("worn_from", 0.5)), 1.0, maxf(_worn, _brinkp))
					_gc_hold_w = clampf(float(H.get("weight", 0.5)) * spd_k * wear_k, 0.0, float(H.get("max", 0.85)))
					if RenderAnim.reduced_motion:
						_gc_hold_w *= 0.6
					debug["gc_poses"] = int(debug.get("gc_poses", 0)) + 1
		"tumble_end":
			_rd.free = minf(_rd.free, 0.3)
			if _gc_hold_t0 >= 0.0 and _gc_hold_t1 < 0.0:
				_gc_hold_t1 = T
			if poses_on and String(e.get("kind", "")) == "recover" and AnimData.entries.has("gc.tech_flip"):
				_seq = {"id": "gc.tech_flip", "t0": T, "dur": float(AnimData.entries["gc.tech_flip"].dur) / 60.0, "wt": 1.0}
				debug["gc_poses"] = int(debug.get("gc_poses", 0)) + 1
		"journey_end":
			if _gc_hold_t0 >= 0.0 and _gc_hold_t1 < 0.0:
				_gc_hold_t1 = T


func on_cue(kind: String, T: float, t_event: float = -1.0) -> void:
	if RenderAnim.step3_cues and AnimData.cue_map.has(kind):
		var sid: String = String(AnimData.cue_map[kind].get("actor", ""))
		if AnimData.entries.has(sid):
			_seq = {"id": sid, "t0": t_event if t_event >= 0.0 else T, "dur": float(AnimData.entries[sid].dur) / 60.0}
			debug["step3"] = int(debug.get("step3", 0)) + 1
		return
	if AnimData.cue_poses.has(kind) and RenderLook.CUE_POSES.has(kind):
		_cue = {"kind": kind, "t0": T, "dur": float(RenderLook.CUE_POSES[kind].dur)}


## The other fighter of a step 3 cue (the one who staggers after a perfect block or a reversal, the one who absorbs a burst); a burst shoves him
## only if his own speed jumps in the next ticks (the sim decides the range), so that one waits for the shove.
func on_cue_other(kind: String, t_event: float) -> void:
	if not RenderAnim.step3_cues or not AnimData.cue_map.has(kind):
		return
	var m: Dictionary = AnimData.cue_map[kind]
	if m.has("other_if_stunned"):
		_stun_watch = 3
		_stun_seq = String(m.other_if_stunned)
		_stun_t0 = t_event
	elif m.has("other"):
		var sid: String = String(m.other)
		if AnimData.entries.has(sid):
			_seq = {"id": sid, "t0": t_event, "dur": float(AnimData.entries[sid].dur) / 60.0}
			debug["step3"] = int(debug.get("step3", 0)) + 1
	elif m.has("other_if_shoved"):
		_shove_watch = 4
		_shove_vx = _rd_vw.x if _rd_have else 0.0


## `front`: the blow came from the side the victim faces. amp 0 to 1 from the hit's strength.
## `d` is the way the blow pushes, in the body frame (x forward: a blow from the front pushes him toward -x); `force` the
## damage over 60 (0.15 to 1.6). The reaction is the pose (a flinch) plus the ragdoll's own motion along d: a head snap, a torso
## fold or arch, limbs thrown by the push, a step; scaled by the blow's force and by the victim's wear, with a deterministic
## variant per hit (a hash of the tick, the slot and the hit count: no random stream, so a replay shows the same).
func on_hit(T: float, region: String, front: bool, amp: float, kind: String = "", d: Vector2 = Vector2.ZERO, force: float = -1.0, tick: int = 0) -> void:
	if d == Vector2.ZERO:
		d = Vector2(-1.0 if front else 1.0, 0.0)
	if force < 0.0:
		force = amp * 70.0 / 60.0
	_hit_n += 1
	var h: int = _hash(tick, slot, _hit_n)
	var u: float = float(h & 1023) / 511.5 - 1.0
	var u2: float = float((h >> 10) & 1023) / 511.5 - 1.0
	_reacts.append({"t0": T, "region": region, "front": front, "amp": clampf(amp, 0.2, 1.0), "kind": kind, "dx": d.x, "dy": d.y, "f": clampf(force, 0.15, 1.6), "u": u})
	if _reacts.size() > 4:
		_reacts.pop_front()
	if not RenderAnim.layer("ragdoll"):
		return
	var ra: float = _rd_amp()
	var wear_k: float = 1.0 + 0.7 * _worn + 0.5 * _brinkp
	var F: float = clampf(force, 0.15, 1.6) * wear_k * (1.0 + 0.25 * u) * ra
	if kind == "guard":
		F *= 0.4
	_rd.hit(d.x, d.y, F, int(AnimRagdoll.REGIONS.get(region, 1)), u, u2)
	_hit_free = minf(1.0, _hit_free + 0.5 * F + 0.3 * _worn)
	# the fighter's own shapes are the flinch keys: a light blow pulls in his brace shape, a heavy one his crumple shape
	var heavy_s: float = smoothstep(0.5, 1.1, force * wear_k)
	_hit_crum = heavy_s
	_hit_w = minf(1.0, _hit_w + 0.5 + 0.3 * heavy_s)
	_rd.out_w = 1.0


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
		_turn_t0 = S.T
		_turn_dir = want
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
		if RenderAnim.layer("transitions") and not first and _base_lagged():
			# the arms and hands follow the torso a little later (a guard comes up with overlap, not as one block)
			var e0: float = 1.0 - k
			for i in range(AnimRig.N):
				var kt: float = 1.0 - pow(e0, _base_r[i])
				_base[i] = AnimJoints.slerp_limb(_base[i], _tq[i], kt) if (AnimJoints.ik_limits and AnimJoints.is_limb[i] == 1) else _base[i].slerp(_tq[i], kt)
		else:
			AnimPose.mix(_base, _tq, k)
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
	if not _seq.is_empty():
		if T >= float(_seq.t0) + float(_seq.dur) + 0.05:
			_seq = {}
		else:
			_entry_layer(float(_seq.t0), float(_seq.dur), String(_seq.id), T, 1.0 / float(_prof.get("solve_hz", 60.0)), float(_seq.get("wt", 1.0)))
	if f.state == "intro" and RenderAnim.intro_poses and not AnimData.intro.is_empty():
		if _intro.is_empty():
			# the first frame, before any event has been drained (the sim sets the state at the start, the events come with the first tick): he is already falling
			_intro = {"on": true, "fall_t": -1.0, "fall_dur": 0.6, "land_t": -1.0, "stare_t": -1.0, "stare_dur": 2.6}
		_intro_layer(S, f)
	if _ls_t0 >= 0.0 and AnimData.pose_exists("ls.hold.resolve") and f.state == "free":
		var LS: Dictionary = AnimData.last_stand
		var lw: float = smoothstep(0.0, float(LS.get("in", 0.6)), T - _ls_t0)
		if _ls_t1 >= 0.0:
			lw *= 1.0 - smoothstep(0.0, float(LS.get("out", 0.5)), T - _ls_t1)
			if T - _ls_t1 >= float(LS.get("out", 0.5)):
				_ls_t0 = -1.0
				_ls_t1 = -1.0
		lw *= float(LS.get("hold_weight", 0.3)) * (0.6 if RenderAnim.reduced_motion else 1.0)
		if lw > 0.001:
			var rp: AnimPose = AnimData.pose("ls.hold.resolve")
			AnimPose.mix(q, rp.q, lw)
			hips = hips.lerp(rp.hips, lw)
			curl = curl.lerp(rp.curl, lw)
	_agency_layer(S, f, T)
	if _gc_hold_t0 >= 0.0 and AnimData.pose_exists("gc.hold.brace_tumble"):
		var hin: float = float(AnimData.ground.get("hold", {}).get("in", 0.08))
		var hout: float = float(AnimData.ground.get("hold", {}).get("out", 0.15))
		var hw: float = smoothstep(0.0, hin, T - _gc_hold_t0)
		if _gc_hold_t1 >= 0.0:
			hw *= 1.0 - smoothstep(0.0, hout, T - _gc_hold_t1)
			if T - _gc_hold_t1 >= hout:
				_gc_hold_t0 = -1.0
				_gc_hold_t1 = -1.0
		if hw > 0.001:
			var bt: AnimPose = AnimData.pose("gc.hold.brace_tumble")
			AnimPose.mix(q, bt.q, hw * _gc_hold_w)
			hips = hips.lerp(bt.hips, hw * _gc_hold_w)
			curl = curl.lerp(bt.curl, hw * _gc_hold_w)
	if _skim_t0 >= 0.0:
		var sk_t: float = T - _skim_t0
		if sk_t > 0.35:
			_skim_t0 = -1.0
		elif sk_t >= 0.0:
			_mix_pose(AnimData.pose("skip.water"), smoothstep(0.0, 0.04, sk_t) * (1.0 - smoothstep(0.12, 0.35, sk_t)) * 0.85)
	# 3. the exchange: approach and strike parts
	_part = ""
	_skip_inertia = false
	_blow_snap = false
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
	# 4a. the head looks at the opponent
	if RenderAnim.layer("look"):
		_look_at(S, f, dt)
	# 4b. a broken arm hangs, a broken leg is favoured
	if _arm_broken or _leg_broken:
		_wound_limbs(f, T)
	# 5. reactions to blows
	_recoil_x = 0.0
	_recoil_y = 0.0
	_step_x = 0.0
	_reaction_layer(T)
	# 5a. feet on the slope under him, a skid pitched to the ground (before the contact solve, so a blow reaches from the new stance)
	if RenderAnim.layer("feet"):
		var tf: int = Time.get_ticks_usec() if RenderAnim.debug_checks else 0
		_ground_feet(S, f, dt)
		if RenderAnim.debug_checks:
			debug["feet_usec"] += Time.get_ticks_usec() - tf
			debug["feet_n"] += 1
	if RenderAnim.joint_audit:
		audit = {"A": AnimJoints.violations(q, _rd.shape_key)}
	# 5b. the striking limb reaches the defender (the contact solve)
	if _ci_w > 0.001:
		_contact_ik(S, f)
	if RenderAnim.joint_audit:
		audit["B"] = AnimJoints.violations(q, _rd.shape_key)
	# 5c. the active ragdoll: the body's own motion on top of the pose (the pose is in charge while a blow is thrown)
	if _rd.out_w > 0.001:
		_rd.apply(q, _rd.out_w * (0.3 if (_part != "" or _ci_w > 0.001) else 1.0), _rd_scale())
	if RenderAnim.joint_audit:
		audit["C"] = AnimJoints.violations(q, _rd.shape_key)
	# 5d00. flight overhaul (unit G): the burst and the brake poses, the bank, the shudder of a nearby impact
	if RenderAnim.layer("flight"):
		_flight_layers(T, f)
	# 5d01. the winner in the wreckage (unit K)
	if RenderAnim.layer("personality"):
		_win_layer(S, f, T)
	# 5d0. idles and transitions with personality (overhaul unit F): the weight shift, the knee bounce and the breath of the stance and
	# the form, and a turn-around as a step
	if RenderAnim.layer("personality") and (f.state == "free" or f.state == "locked") and _part == "" and _ci_w < 0.001:
		var calm: float = 1.0 - clampf(absf(f.vx) / 300.0, 0.0, 1.0)
		if f.state == "free" and calm > 0.05:
			_personality_layer(T, int(f.stance), clampi(int(f.tier) - 1, 0, 3), calm)
		_turn_layer(T)
	# 5d. polish: lean into acceleration (free flight and movement), the hover bob
	if RenderAnim.layer("lean"):
		if absf(_lean) > 0.002:
			q[AnimRig.index["pelvis"]] = q[AnimRig.index["pelvis"]] * Quaternion(Vector3(0, 0, 1), -_lean * 0.6)
			q[AnimRig.index["spine_2"]] = q[AnimRig.index["spine_2"]] * Quaternion(Vector3(0, 0, 1), -_lean * 0.4)
		if _air_w > 0.3:
			hips.y += sin(T * TAU * 0.7 + slot * 1.3) * 1.4 * _air_w * _rd_amp()
			q[AnimRig.index["spine_2"]] = q[AnimRig.index["spine_2"]] * Quaternion(Vector3(0, 0, 1), sin(T * TAU * 0.5 + slot) * 0.03 * _air_w * _rd_amp())
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
	if _lean_t0 > -5.0 or _over_t0 > -5.0 or _block_t0 > -5.0:
		root_off.x += _evade_offsets(T)
	root_off.y += _recoil_y
	if _smear != 0.0:
		root_off.x += _smear_now(T)
		if T - _smear_t0 >= 0.05:
			_smear = 0.0
	_springs(f)
	# 6a. inertialisation: a join in the solved pose decays instead of popping
	_inertialise(dt, prof)
	if RenderAnim.debug_checks:
		layers = ("cue:" + String(_cue.get("kind", "")) + " " if not _cue.is_empty() else "") + ("rush " if _rushing else "") + ("react " if not _reacts.is_empty() else "") + ("ik " if _ci_w > 0.001 else "") + ("beam " if f.beamCharge != null else "") + (f.state + " ")
	# 6b. the limb pass: elbows and knees stay hinges in human range, arms stay out of the shoulder's blind spot
	if RenderAnim.joint_audit:
		audit["D"] = AnimJoints.violations(q, _rd.shape_key)
	debug["limit_fix"] = AnimPose.limit_limbs(q, _rd.shape_key)
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
	return (ex == null or (ex.A != f and ex.D != f)) and _cue.is_empty() and _seq.is_empty() and _shove_watch == 0 and _stun_watch == 0 and _reacts.is_empty() and f.beamCharge == null and S.beams.is_empty() and S.dirS.stop <= 0.0 and _form.is_empty() and _rd.out_w <= 0.001


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
	var w12: float = 0.0             # skidding on the back (moving away from the way he faces)
	var w13: float = 0.0             # skidding face down
	var w15: float = 0.0             # the push-up stage of a get-up
	var w16: int = 0                 # the winner's beat (1 stand, 2 survey, 3 the end)
	var w17: float = 0.0             # a KO's fall, 0 to 1 over the first half second down
	var w14: float = 0.0             # the rise out of the crouch after it (slower when worn)
	if state == "down":
		_was_down = true
	elif _was_down:
		_was_down = false
		_rise_t0 = T
		_rise_dur = 0.25 + 0.55 * maxf(_worn, _brinkp)
		if RenderAnim.ground_poses and RenderAnim.layer("transitions") and AnimData.entries.has("gc.getup_quick") and _seq.is_empty():
			var slow: bool = maxf(_worn, _brinkp) > float(AnimData.ground.get("getup", {}).get("slow_above", 0.45))
			_seq = {"id": "gc.getup_slow" if slow else "gc.getup_quick", "t0": T, "dur": _rise_dur, "wt": 1.0, "getup": true}
			_rise_t0 = -1.0   # the sequence is the rise; the blend toward down.getup would double it
	if _rise_t0 >= 0.0 and RenderAnim.layer("transitions"):
		var rt: float = T - _rise_t0
		if rt >= _rise_dur:
			_rise_t0 = -1.0
		elif state == "free":
			w14 = 1.0 - smoothstep(0.0, _rise_dur, rt)
	_air_w = 0.0
	var mode: int = 0
	if f.slide > 0.0:
		mode = 1
		var sk: float = smoothstep(250.0, 600.0, absf(f.vx))
		if vf < 0.0:
			w12 = sk
		else:
			w13 = sk
	elif state == "launched":
		var speed: float = Vector2(f.vx, f.vy).length()
		w1 = smoothstep(700.0, 2200.0, speed)
		w2 = (1.0 - smoothstep(150.0, 600.0, speed)) * 0.7
		mode = 2
	elif state == "down":
		if RenderAnim.ragdoll_enabled:
			w1 = smoothstep(0.5, 0.72, f.stateT)
			w15 = smoothstep(0.28, 0.5, f.stateT)
		else:
			w1 = smoothstep(0.42, 0.72, f.stateT)
		mode = 7 if is_same(S.game.ko, f) else 3
		w17 = smoothstep(0.0, 0.5, f.stateT) if RenderAnim.layer("personality") else 1.0
	elif state == "charging":
		mode = 4
	elif S.game.ko != null and not is_same(S.game.ko, f) and S.game.koT > float(AnimData.winner.get("start", 0.8)) and state == "free":
		mode = 6
		w16 = _win_phase(S.game.koT, String(f.id)) if RenderAnim.layer("personality") else 4
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
				_air_w = air
				w5 = air * smoothstep(150.0, 600.0, f.vy)
				w6 = air * smoothstep(150.0, 600.0, -f.vy)
			elif f.ki < 6.0:
				w7 = 1.0
			elif int(f.stance) < 2 and absf(f.vx) < 100.0:
				var opp = _opponent(S, f)
				if opp != null and absf(SimWrap.sdx(f.x, opp.x)) > IDLE_FAR:
					w7 = 0.5
	var key: int = mode | (stance << 3) | (int(w1 * 16.0) << 5) | (int(w2 * 16.0) << 10) | (int((w3 + 1.0) * 24.0) << 15) | (int(w4 * 8.0) << 21) | (int(w5 * 8.0) << 25) | (int(w6 * 8.0) << 29) | (int(w7 * 2.0) << 33) | (int(w8 * 8.0) << 35) | (int(w9 * 8.0) << 39) | (int(w10 * 8.0) << 43) | (int(w11 * 8.0) << 47) | (int(w12 * 8.0) << 50) | (int(w13 * 8.0) << 54)
	var key2: int = int(w15 * 8.0) | (int(w14 * 8.0) << 4) | (w16 << 8) | (int(w17 * 8.0) << 11)
	if key == _bkey and key2 == _bkey2:
		_settle += 1
		return
	_bkey = key
	_bkey2 = key2
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
			_blend_target("skid.back", w12)
			_blend_target("skid.front", w13)
		2:
			_blend_target("launch.spread", 1.0)
			_blend_target("launch.stream", w1)
			_blend_target("launch.tuck", w2)
		3:
			_blend_target("down.prone", 1.0)
			_blend_target("getup.push", w15)
			_blend_target("down.getup", w1)
		4:
			_blend_target("charge.hold", 1.0)
		6:
			match w16:
				1:
					_blend_target("win.stand", 1.0)
				2:
					_blend_target("win.survey", 1.0)
				_:
					_blend_target("emote.victory" if (w16 == 4 or _win_end(String(f.id)) == "victory") else "win.survey", 1.0)
		7:
			# a KO falls: a stagger first, then flat on the back
			_blend_target("react.stagger", (1.0 - w17) * 0.8)
			_blend_target("down.ko", w17)
		_:
			_blend_target("move.dash", w1)
			_blend_target("move.retreat", w2)
			_blend_target("move.sprint", w8)
			_blend_target("move.step_f", w9)
			_blend_target("move.step_b", w10)
			_blend_target("wound.sag", w11)
			_blend_target("down.getup", w14 * 0.75)
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
	AnimPose.mix(_tq, p.q, w)
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

## How heavy a blow is, continuously: the damage over 70 (a chain link, which carries no damage, counts as 1). It stretches the
## load, the follow-through and the recovery and deepens the overshoot (overhaul unit D); the contact tick never moves.
static func _blow_weight(args: Dictionary) -> float:
	if not RenderAnim.ragdoll_enabled:
		return 0.7   # neutral: the A/B off switch leaves the blow's timing as it was
	var d: float = float(args.get("dmg", -1.0))
	if d < 0.0:
		var o = args.get("o")
		return 1.0 if (o != null and bool(o.get("big", false))) else 0.6
	return clampf(d / 70.0, 0.2, 1.4)


## Go-live step 1 (docs/combat/pending/golive-step1.md), only with RenderAnim.wave1_live (--wave1-live, OFF by default): the key set of a blow of the
## Anti-hero's shape from wave 1's lists. The list is walked, not hashed blow by blow: it starts at a hash of the exchange and the fighter and takes
## every third entry (every fifth when the list has a multiple of three), so nothing repeats inside ten blows; a two-limb key set is skipped when a
## limb of its kind is drawn as broken; the gated key sets (the sweep with both fighters on the ground, the drop kick with the striker in the air)
## join the list only while their gate is open. Returns "" when not applicable (the flag is off, another fighter's shape, no data).
func _live_pick(S: SimState, f, ex, ordinal: int, heavy: bool) -> String:
	if not RenderAnim.wave1_live:
		return ""
	var lv: Dictionary = AnimData.live
	if lv.is_empty():
		return ""
	var sk: String = String(AnimRagdoll.shape_of.get(String(f.id), AnimRagdoll.shape_of.get("default", "")))
	if not (lv.get("shapes", []) as Array).has(sk):
		return ""
	var which: String = "heavy" if heavy else "light"
	var cand: Array = (lv.picks[which] as Array).duplicate()
	var opp = ex.D if ex.A == f else ex.A
	for g in lv.get("gated", []):
		if String(g.weight) != which:
			continue
		var open: bool = false
		match String(g.gate):
			"both_ground":
				open = f.y - WorldTerrain.groundY(S, f.x) < 8.0 and opp != null and opp.y - WorldTerrain.groundY(S, opp.x) < 8.0
			"striker_air":
				open = f.y - WorldTerrain.groundY(S, f.x) > 20.0
		if open:
			cand.append(String(g.keyset))
	var n: int = cand.size()
	if n == 0:
		return ""
	var stepw: int = 3 if n % 3 != 0 else 5
	var h: int = _hash(int(ex.n), slot, 11)
	for tries in range(n):
		var id: String = String(cand[(h + stepw * (ordinal + tries)) % n])
		var ks = AnimData.keysets.get(id)
		if ks == null:
			continue
		var two: String = String(ks.get("limb2", ""))
		if two != "" and ((_arm_broken and (two.begins_with("hand") or two.begins_with("elbow"))) or (_leg_broken and (two.begins_with("foot") or two.begins_with("knee")))):
			continue
		debug["live_picks"] = int(debug.get("live_picks", 0)) + 1
		return id
	return ""


## An entry (data/anim/waves/*.entries.json, parked: no live beat names one yet): a sequence of poses over `dur` seconds. A phase with
## `ticks` holds that long, the others share the rest by their weight `w`; the poses cross-fade over three ticks at each boundary. The
## strike that follows takes over from here by its own load (the join is inertialised).
func _entry_layer(es: float, dur: float, id: String, T: float, dq: float, wt: float = 1.0) -> void:
	var en = AnimData.entries.get(id)
	if en == null or T < es - 0.0001 or T >= es + dur + 0.05:
		return
	var ph: Array = en.phases
	var fixed: float = 0.0
	var sumw: float = 0.0
	for p in ph:
		if p.has("ticks"):
			fixed += float(p.ticks) * DT
		else:
			sumw += float(p.get("w", 1.0))
	var flex: float = maxf(dur - fixed, DT)
	var bounds: Array = [0.0]
	for p in ph:
		var seg: float = float(p.ticks) * DT if p.has("ticks") else flex * float(p.get("w", 1.0)) / maxf(sumw, 0.001)
		bounds.append(float(bounds[-1]) + seg)
	var tt: float = floorf(clampf(T - es, 0.0, dur) / dq + 0.0001) * dq
	var e: float = 1.5 * DT
	var base_q: Array[Quaternion] = []
	var base_h: Vector3 = hips
	var base_c: Vector2 = curl
	if wt < 0.999:
		base_q = q.duplicate()
	_mix_pose(AnimData.pose(String(ph[0].pose)), 1.0)
	for i in range(1, ph.size()):
		var w: float = smoothstep(float(bounds[i]) - e, float(bounds[i]) + e, tt)
		if w > 0.001:
			_mix_pose(AnimData.pose(String(ph[i].pose)), w)
	if wt < 0.999:
		for i in range(AnimRig.N):
			q[i] = base_q[i].slerp(q[i], wt)
		hips = base_h.lerp(hips, wt)
		curl = base_c.lerp(curl, wt)
	debug["entries"] = int(debug.get("entries", 0)) + 1


func _exchange_layers(S: SimState, f, ex, T: float) -> void:
	var role: String = "A" if ex.A == f else "D"
	var t0: float = T - ex.t
	var strikes: Array = []
	var rushes: Array = []
	var entries: Array = []   # parked entry sequences (data/anim/waves/*.entries.json), played by an `entry` beat or a rush beat that names one
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
		elif b.op == "entry" and String(b.args.get("who", "A")) == role:
			entries.append([t0 + b.t, float(b.args.dur), String(b.args.get("id", ""))])
		elif b.op == "rush" and role == "A":
			rushes.append([t0 + b.t, float(b.args.dur), String(b.args.get("entry", ""))])
		elif b.op == "finRush" and String(b.args.w) == role:
			rushes.append([t0 + b.t, float(b.args.dur), ""])
	# approach: launch-off, flight, arrival (a rush is snappy)
	var rprof: Dictionary = _part_prof("rush")
	var rdq: float = 1.0 / float(rprof.get("solve_hz", 60.0))
	for en in entries:
		_entry_layer(float(en[0]), maxf(float(en[1]), DT), String(en[2]), T, rdq)
	for r in rushes:
		var rs: float = r[0]
		var dur: float = maxf(r[1], DT)
		if String(r[2]) != "" and AnimData.entries.has(String(r[2])):
			_entry_layer(rs, dur, String(r[2]), T, rdq)
			continue
		if T >= rs and T < rs + dur + 0.05:
			var tq: float = rs + floorf((T - rs) / rdq) * rdq
			var p: float = clampf((tq - rs) / dur, 0.0, 1.0)
			# the streak holds to the last tick: the fastest ticks of a rush are its end, and they must not be drawn in a standing pose
			var fly: float = smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.93, 1.0, p))
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
		var Fn: float = float(sp.get("follow_ticks", 6)) * DT * (0.85 + 0.25 * _blow_weight(strikes[n][2]))
		var Rn: float = float(sp.get("recover_ticks", 10)) * DT
		var Sn_: float = float(sp.get("snap_ticks", 3)) * DT
		var bw: float = _blow_weight(strikes[n][2])
		var lnom: float = float(sp.get("load_ticks", {}).get("heavy" if strikes[n][3] == "heavy" else "light", 12)) * DT * (0.75 + 0.35 * bw)
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
	var bw2: float = _blow_weight(strikes[best][2])
	var F: float = float(prof.get("follow_ticks", 6)) * DT * (0.85 + 0.25 * bw2)
	var R: float = float(prof.get("recover_ticks", 10)) * DT * (0.9 + 0.2 * bw2)
	var dq: float = 1.0 / float(prof.get("solve_hz", 60.0))
	var tc2: float = strikes[best][0]
	var L2: float = lens[best]
	var heavy2: bool = strikes[best][3] == "heavy"
	var side: bool = (_hash(int(ex.n), int(strikes[best][1]), slot + 1) & 1) == 1
	var picks: Array = AnimData.picks["heavy" if heavy2 else "light"]
	var ksid: String = String(picks[_hash(int(ex.n), int(strikes[best][1]), 3 + slot) % picks.size()])
	var live_id: String = _live_pick(S, f, ex, int(strikes[best][1]), heavy2)
	if live_id != "":
		ksid = live_id
	if RenderAnim.force_keyset != "" and AnimData.keysets.has(RenderAnim.force_keyset):
		ksid = RenderAnim.force_keyset
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
		var kcount: Dictionary = debug.get("keysets", {})
		kcount[ksid] = int(kcount.get(ksid, 0)) + 1
		debug["keysets"] = kcount
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
		var w3: float = _ease_out_back(u3, float(prof.get("overshoot", 0.1)) * (0.6 + 0.8 * bw2))
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
	# the step from the wind-up into the contact key is the blow itself (on twos it is one step): inertialisation must not take it for a join
	# and smooth it over the next 0.1 s, or the fist reaches the defender late (--blowjoin restores the old behaviour for an A/B)
	_blow_snap = dtc >= -(Sn + dq) - 0.0001 and dtc <= 0.0001
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
		_ci_step = float(ks.get("step_max", -1.0))
		_ci_limb2 = String(ks.get("limb2", ""))
		_ci_target = String(ks.get("target", "chest")) if RenderAnim.force_target == "" else RenderAnim.force_target
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
					if String(b.args.get("side", "")) == "cross":
						# the step-around: up and over the attacker, then down behind him (two moves, a few ticks each)
						var leg: float = float(b.args.get("dur", 0.15)) * 0.5
						var tau: float = T - bt
						if tau >= -0.02 and tau < 2.0 * leg + 0.2:
							_skip_inertia = true   # the two moves are a few ticks each: the pose pulses must show, not be smoothed away
						if tau >= 0.0 and tau < leg + 0.05:
							_mix_pose(AnimData.pose("def.hop"), smoothstep(0.0, 0.025, tau) * (1.0 - smoothstep(leg - 0.04, leg + 0.04, tau)))
						if tau >= leg - 0.05 and tau < 2.0 * leg + 0.2:
							_mix_pose(AnimData.pose("def.drop"), smoothstep(leg - 0.04, leg + 0.03, tau) * (1.0 - smoothstep(2.0 * leg - 0.02, 2.0 * leg + 0.15, tau)))
					else:
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

## The defender's body point for a region (data/anim/sockets.json regions), in the defender's model space.
func _region_point(name: String) -> Vector3:
	var regs: Dictionary = AnimData.sockets.get("regions", {})
	var r: Dictionary = regs.get(name, regs.get("chest", {}))
	var bn: String = String(r.get("bone", "spine_2"))
	var off: Array = r.get("offset", [0, 3, 0])
	var bi: int = AnimRig.index[bn]
	if not _full_fk and not SOCKET_SET.has(bn):
		AnimPose.fk(q, hips, gq, gp)
		_full_fk = true
	return gp[bi] + gq[bi] * Vector3(float(off[0]), float(off[1]), float(off[2])) + root_off


## How far the striking part can reach from its root (the shoulder, the hip, the spine): the length of the chain for a two-bone
## limb, the distance to the tip for an aimed one. The tip is where the blow lands from (the wrist, the elbow, the head).
func _strike_tip(sk: Dictionary, a: int, b: int, c: int) -> Vector3:
	if String(sk.get("mode", "ik")) == "ik":
		return gp[c]
	var off: Array = sk.get("tip_offset", [0, 0, 0])
	return gp[c] + gq[c] * Vector3(float(off[0]), float(off[1]), float(off[2]))


func _strike_reach(sk: Dictionary, a: int, b: int, c: int) -> float:
	if String(sk.get("mode", "ik")) == "ik":
		return (gp[b] - gp[a]).length() + (gp[c] - gp[b]).length() - 0.5
	return (_strike_tip(sk, a, b, c) - gp[a]).length()


## IK the striking hand or foot onto the defender's body: the wrist (ankle) goes to the region's surface minus the fist, so
## the fist lands on him on the contact tick, and the hips lunge for what the arm cannot reach. The authored limb blends
## into the solved one by the contact weight, so the key poses stay the look and the defender's actual position decides
## where it lands. Nothing happens if the opponent is behind the thrower (the face override turns him first).
func _contact_ik(S: SimState, f) -> void:
	_contact_one(S, f, _ci_limb, false)
	if _ci_limb2 != "":
		_contact_one(S, f, _ci_limb2, true)


## One striking limb onto the defender. A second limb of the same blow (second = true) reaches from where the first left the body:
## the hips' lunge is already in the pose and the step-in in `_step_x`, so it only asks for what is still missing.
func _contact_one(S: SimState, f, base_limb: String, second: bool) -> void:
	var opp = _ci_opp
	if opp == null or _ci_dmg <= 0.0:
		return
	var oaf: AnimFighter = RenderAnim.fighter(S, opp)
	if oaf.version == 0:
		return
	var limb: String = base_limb
	var sided: bool = base_limb.contains("_")
	if _ci_side and sided:
		limb = base_limb.substr(0, base_limb.length() - 1) + ("l" if base_limb.ends_with("r") else "r")
	var kind: String = limb.get_slice("_", 0)
	var sk: Dictionary = AnimData.sockets.get("limbs", {}).get(kind, {})
	if sk.is_empty():
		return
	var aim: bool = String(sk.get("mode", "ik")) == "aim"
	var sfx: String = limb.substr(limb.length() - 1) if sided else "r"
	var zs: float = (1.0 if sfx == "r" else -1.0) if sided else 0.0
	var end_len: float = float(sk.get("end_len", 6.0))
	var lunge_max: float = float(sk.get("lunge_max", 8.0))
	var step_max: float = float(sk.get("step_max", 10.0)) if _ci_step < 0.0 else _ci_step
	var dx: float = SimWrap.sdx(f.x, opp.x)
	var rp: Vector3 = oaf._region_point(_ci_target)
	var mx: float = (dx + oaf.vface * rp.x) * vface
	if mx < 4.0:
		return
	var my: float = (opp.y - f.y) + rp.y
	var surf: float = float(AnimData.sockets.get("regions", {}).get(_ci_target, {}).get("surface", 6.5))
	var tgt := Vector3(mx - surf - end_len - _smear_now(S.T) - (_step_x if second else 0.0), my, float(sk.get("reach_z", 5.0)) * zs)
	var ix: Dictionary = AnimRig.index
	var a: int
	var b: int
	var c: int
	if aim:
		var abn: String = String(sk["bone"])
		a = ix[abn + "_" + sfx] if (sided and ix.has(abn + "_" + sfx)) else ix[abn]   # a bone with a side (upper_arm) or one without (spine_1)
		b = a
		c = ix[String(sk["tip"]) + ("_" + sfx if sided else "")]
	else:
		var ch: Array = sk["chain"]
		a = ix[String(ch[0]) + "_" + sfx]
		b = ix[String(ch[1]) + "_" + sfx]
		c = ix[limb]
	AnimPose.fk(q, hips, gq, gp)
	_full_fk = true
	var reach: float = _strike_reach(sk, a, b, c)
	# how far forward the shoulder must come (along x, the way the hips and the step move it) for the arm to just reach
	var d3: Vector3 = tgt - gp[a]
	var side2: float = d3.y * d3.y + d3.z * d3.z
	var need: float = d3.x - (sqrt(reach * reach - side2) if side2 < reach * reach else 0.0)
	need = maxf(need, 0.0)
	# the clavicle hunch brings the shoulder to meet it first (an arm blow; the legs and the head have no shoulder to give)
	var hm: float = float(sk.get("hunch_max", 0.0))
	if hm > 0.0 and need > 0.0 and AnimPose.hunch_auto and sided:
		AnimPose.hunch(q, sfx, minf(need, hm) * _ci_w, 0.0)
		AnimPose.fk(q, hips, gq, gp)
		reach = _strike_reach(sk, a, b, c)
		d3 = tgt - gp[a]
		side2 = d3.y * d3.y + d3.z * d3.z
		need = maxf(d3.x - (sqrt(reach * reach - side2) if side2 < reach * reach else 0.0), 0.0)
	# above or below the arm's reach whatever the lunge (a defender on another level): the excess is what is left over
	var excess: float = need - lunge_max - step_max
	if side2 >= reach * reach:
		excess = sqrt(side2) - reach
	elif need <= 0.0 and d3.length() > reach:
		excess = d3.length() - reach   # the target is behind the shoulder (the fighters overlap): no step forward helps
	var lunge: float = minf(need, lunge_max) * _ci_w
	var step: float = clampf(need - lunge_max, 0.0, step_max) * _ci_w
	_step_x = (_step_x + step) if second else step
	var ik_t: Vector3 = tgt - Vector3(lunge + step, 0.0, 0.0)
	var qa0: Quaternion = q[a]
	var qb0: Quaternion = q[b]
	var gap: float
	if aim:
		# one bone turned so the tip points at the target: what the joint cannot reach is the gap, what is nearer is overshoot
		var tip: Vector3 = _strike_tip(sk, a, b, c)
		var dir_now: Vector3 = (tip - gp[a]).normalized()
		var dir_to: Vector3 = (ik_t - gp[a]).normalized()
		var qa_new: Quaternion = Quaternion(dir_now, dir_to) * gq[a]
		q[a] = gq[AnimRig.parent[a]].inverse() * qa_new
		q[a] = qa0.slerp(q[a], _ci_w)
		gap = maxf(0.0, (ik_t - gp[a]).length() - reach)
	else:
		var pole: Vector3 = gp[b]   # the elbow (knee) stays on the side the authored pose has it, so the solved limb is its neighbour
		AnimPose.ik_limb(q, gq, gp, a, b, c, ik_t, pole, 1.0 if kind == "hand" else -1.0, _rd.shape_key)
		q[a] = AnimJoints.slerp_limb(qa0, q[a], _ci_w) if AnimJoints.ik_limits else qa0.slerp(q[a], _ci_w)
		q[b] = qb0.slerp(q[b], _ci_w)
		gap = maxf(0.0, (ik_t - gp[c]).length())
		if gap > 0.0 and (gp[c] - gp[a]).length() > (ik_t - gp[a]).length():
			gap = 0.0   # the limb folds no further than its joint allows, so it ends past a target that is nearer than that (inside the defender), not short of it
	hips.x += lunge
	debug["ik_frames"] += 1
	if second:
		if absf(S.T - _ci_tc) < DT * 0.5 and _ci_w > 0.99:
			debug["gap2_max"] = maxf(float(debug.get("gap2_max", 0.0)), gap)
			debug["gap2_n"] = int(debug.get("gap2_n", 0)) + 1
	elif absf(S.T - _ci_tc) < DT * 0.5 and _ci_w > 0.99 and _ci_tc != _gap_tc:
		_gap_tc = _ci_tc
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
	if (_skip_inertia or not _form.is_empty()) and _ip_have:
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
	if jump and _blow_snap and not RenderAnim.blow_join:
		jump = false
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


## How far behind the anchor the body is drawn now (the contact catch's smear); the contact solve reaches that much further.
func _smear_now(T: float) -> float:
	if _smear == 0.0:
		return 0.0
	var sp: float = (T - _smear_t0) / 0.05
	return 0.0 if sp >= 1.0 else _smear * (1.0 - smoothstep(0.0, 1.0, sp))


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

func _rd_amp() -> float:
	return 0.35 if RenderAnim.reduced_motion else 1.0


## One sim tick of the ragdoll, from the fighter's own state (never random, never written back). Velocity and acceleration are
## taken in the body frame: the body is rotated by the sim's rot, mirrored by the visual facing. A launch, a slam, a skid, a
## brace before the ground and a tuck in a spin are all this one controller.
## How much each ragdoll degree of freedom may move: a broken arm hangs heavy, so its three (upper arm, its sideways swing and forearm) move at a third
## while the body tumbles or settles (a limp arm does not whip like a good one); every other one is free.
func _rd_scale() -> PackedFloat32Array:
	if not _arm_broken:
		return PackedFloat32Array()
	var sc := PackedFloat32Array()
	sc.resize(AnimRagdoll.N)
	for i in range(AnimRagdoll.N):
		sc[i] = 1.0
	var base: int = 5 if _hang_right else 2
	for j in range(3):
		sc[base + j] = 0.33
	return sc


func _rd_tick(S: SimState, f, dt: float) -> void:
	if f.state == "intro" and RenderAnim.intro_poses:
		return   # the fall is scripted: nothing in the ragdoll should answer its speed
	if not RenderAnim.layer("ragdoll"):
		if _rd.out_w > 0.0 or _rd.energy() > 0.0:
			_rd.reset()
		_rd_have = false
		return
	var t0: int = Time.get_ticks_usec() if RenderAnim.debug_checks else 0
	var amp: float = _rd_amp()
	var vw := Vector2(f.vx, f.vy)
	var aw := Vector2.ZERO
	if _rd_have:
		aw = (vw - _rd_vw) / maxf(dt, 0.0001) + Vector2(0.0, 1000.0)
		if aw.length() > AnimRagdoll.a_max:
			aw = aw.normalized() * AnimRagdoll.a_max
	_rd_vw = vw
	var m: float = vface
	var c: float = cos(f.rot)
	var sn: float = sin(f.rot)
	var vo := Vector2(vw.x * m, vw.y)
	var ao := Vector2(aw.x * m, aw.y)
	var vl := Vector2(vo.x * c - vo.y * sn, vo.x * sn + vo.y * c)
	var al := Vector2(ao.x * c - ao.y * sn, ao.x * sn + ao.y * c)
	var st: String = f.state
	var sliding: bool = f.slide > 0.0
	var flying: bool = st == "launched" and not sliding
	var speed: float = vw.length()
	if _rd_have:
		# a slam (flight to down) folds the body; a skid starting from a flight whips it
		if st == "down" and _rd_prev_state == "launched":
			_rd.crumple(clampf(_rd_prev_speed / 3000.0, 0.3, 1.5), amp)
		elif st == "down" and _rd_prev_state != "down" and is_same(S.game.ko, f):
			_rd.crumple(0.9, amp)
			_rd.kick(0, 6.0 * amp)
			debug["ko_falls"] += 1
		elif sliding and not _rd_prev_slide and _rd_prev_state == "launched":
			_rd.crumple(clampf(_rd_prev_speed / 4000.0, 0.2, 0.9), amp)
	if not _shape_set:
		_shape_set = true
		_rd.set_shape(String(f.id))
		_rd.phase = float(slot) * 0.9
	var free_t: float = 0.0
	var tuck: float = 0.0
	var brace: float = 0.0
	var skid: float = 0.0
	var crum: float = 0.0
	var flail: float = 0.0
	if flying:
		# the early launch is a flail (limbs thrown about); the body tucks only at a high spin and only after the first moments
		free_t = 0.85
		tuck = AnimRagdoll.tuck_max * smoothstep(AnimRagdoll.tuck_spin.x, AnimRagdoll.tuck_spin.y, absf(f.spin)) * smoothstep(AnimRagdoll.tuck_after.x, AnimRagdoll.tuck_after.y, f.stateT) * (0.65 + 0.35 * cos(f.rot * 0.5))
		flail = (1.0 - smoothstep(AnimRagdoll.flail_fade.x, AnimRagdoll.flail_fade.y, f.stateT)) * (1.0 - tuck)
		if f.vy < -200.0 and f.aimB < 0:
			var h: float = f.y - WorldTerrain.groundY(S, f.x)
			if h > 0.0:
				var tc: float = (f.vy + sqrt(f.vy * f.vy + 2000.0 * h)) / 1000.0
				brace = 1.0 - smoothstep(AnimRagdoll.brace_time.x, AnimRagdoll.brace_time.y, tc)
				brace *= 1.0 - tuck * 0.5
				flail *= 1.0 - brace
	elif sliding:
		free_t = 0.55
		skid = AnimRagdoll.skid_w
	elif st == "down":
		free_t = 0.25 if f.stateT < 0.6 else 0.0
		crum = AnimRagdoll.crumple_down_w if f.stateT < 0.7 else 0.0
	# E: the defender's side. The blow the attacker is about to land is in the beat list ahead of time: a heavy one is braced for
	# (arms up, chin down, in the fighter's own brace shape) in the last 0.25 s, and a blow that misses (no damage) is flinched at
	var exc = S.dirS.ex
	var pre: float = 0.0
	if exc != null and exc.D == f and not flying and not sliding and st != "down" and RenderAnim.layer("defender"):
		var nb: Array = _next_blow(exc)
		if not nb.is_empty():
			var dtc: float = nb[0]
			if dtc > 0.0 and nb[2] > 0.0:
				pre = (1.0 - clampf(dtc / 0.25, 0.0, 1.0)) * (0.7 if nb[1] else 0.25) * (1.0 if int(f.stance) == 1 else 0.7)
				if pre > 0.05:
					debug["pre_brace"] += 1
			elif nb[2] <= 0.0 and dtc <= 0.0 and _miss_id != int(exc.n) * 64 + int(nb[3]) and not _has_evade(exc):
				_miss_id = int(exc.n) * 64 + int(nb[3])
				_near_miss(S, f, amp)
		# J: the dodge itself. He sees the blow coming and leans away from it in the 0.14 s before his dodge or slip beat
		var ev: Array = _next_evade(exc)
		if not ev.is_empty() and ev[0] > 0.0 and ev[0] < 0.14 and _lean_id != int(exc.n) * 64 + int(ev[1]):
			_lean_id = int(exc.n) * 64 + int(ev[1])
			_lean_away(S.T, amp)
	if exc != null and exc.A == f and not flying and not sliding and st != "down" and RenderAnim.layer("defender"):
		# J: the attacker's whiff: a blow that finds nothing (no damage, the defender gone) carries him past, off balance
		var ms: Array = _next_miss(exc)
		if not ms.is_empty() and ms[0] < 0.02 and _over_id != int(exc.n) * 64 + int(ms[1]):
			_over_id = int(exc.n) * 64 + int(ms[1])
			_over_commit(S.T, amp)
		else:
			# a dodge is the whiff of a rush: the defender is gone as the attacker arrives, and he is carried past
			var ea: Array = _next_evade(exc)
			if not ea.is_empty() and ea[0] < 0.02 and _over_id != int(exc.n) * 64 + 32 + int(ea[1]):
				_over_id = int(exc.n) * 64 + 32 + int(ea[1])
				_over_commit(S.T, amp)
	if not flying and not sliding:
		brace = maxf(brace, (1.0 - _hit_crum) * _hit_w * 0.45 + pre)
		crum = maxf(crum, _hit_crum * _hit_w * 0.5)
		free_t = maxf(free_t, 0.5 * _hit_w + 0.3 * pre)
	_hit_w = maxf(0.0, _hit_w - dt / (0.3 + 0.4 * _worn))
	_rd.w_tuck = tuck
	_rd.w_brace = brace
	_rd.w_skid = skid
	_rd.w_crumple = crum
	_rd.w_flail = flail
	# polish: the lean into acceleration while he is free, and the contact catch (a striker carried far in one tick is drawn
	# travelling to his place, not popping to it)
	var lean_t: float = 0.0
	if st == "free" or st == "locked":
		lean_t = clampf(ao.x / 9000.0, -1.0, 1.0) * 0.35 * amp
	_lean += (lean_t - _lean) * (1.0 - exp(-dt / 0.12))
	# G: banking into a turn, a burst on a dash start, a brake on a stop
	var bank_t: float = 0.0
	if (st == "free" or st == "locked") and (speed > 300.0 or _air_w > 0.3):
		bank_t = clampf(-ao.x / 9000.0, -1.0, 1.0) * 0.3 * amp
	_bank += (bank_t - _bank) * (1.0 - exp(-dt / 0.15))
	if st == "free":
		var ge: String = _gait_event(ao.x, _gait_speed, absf(vo.x))
		if ge == "burst" and S.T - _burst_t0 > 0.4:
			_burst_t0 = S.T
			debug["bursts"] += 1
		elif ge == "brake" and S.T - _brake_t0 > 0.5:
			_brake_t0 = S.T
			debug["brakes"] += 1
	_gait_speed = absf(vo.x)
	var cx: float = SimWrap.sdx(_prev_x, f.x) if _have_x else 0.0
	var pcx: float = _prev_cx
	_prev_x = f.x
	_prev_cx = cx
	_have_x = true
	var ex = S.dirS.ex
	if absf(cx) > 250.0 and ex != null and ex.A == f and not flying and not sliding and amp > 0.5 and _blow_due(ex):
		# a catch: the striker is carried far on the tick his blow lands; the body lags the anchor a little and the contact reaches that far
		_smear = clampf(-cx * m * 0.05, -10.0, 10.0)
		_smear_t0 = S.T
		debug["catches"] += 1
	_hit_free = maxf(0.0, _hit_free - dt * (1.6 - 0.8 * _worn))
	free_t = maxf(free_t, _hit_free)
	_rd_prev_state = st
	_rd_prev_slide = sliding
	_rd_prev_speed = speed if st == "launched" else _rd_prev_speed
	_rd_have = true
	var active: bool = st == "launched" or st == "down" or _rd.free > 0.02 or _rd.energy() > 0.03
	if active:
		_rd.step(dt, vl, al, free_t, amp, S.T)
	_rd.out_w = move_toward(_rd.out_w, 1.0 if active else 0.0, dt * 8.0)
	if not active and _rd.out_w <= 0.0 and _rd.energy() > 0.0:
		_rd.reset()
	if RenderAnim.debug_checks:
		debug["rd_ticks"] += 1
		debug["rd_usec"] += Time.get_ticks_usec() - t0


## Feet on the ground under them. A standing fighter on a slope (a crater wall, a rim, a heap) has one foot higher than the other:
## the pelvis follows the mean and each leg is solved to its own foot's ground (two-bone IK, the knee staying where the pose has
## it). A skid is pitched to the slope along its way. Reads the terrain only (WorldTerrain.groundY); cheap when the ground is flat
## (three reads, no solve).
func _ground_feet(S: SimState, f, dt: float) -> void:
	var st: String = f.state
	var sliding: bool = f.slide > 0.0
	# one ground read a solve; the slope reads only while he stands or slides, and cached while he stays within 3 units
	var g0: float
	if S.tick - _gf_gtick < 4 and absf(SimWrap.sdx(_gf_gx, f.x)) < 20.0:
		g0 = _gf_g0c
	else:
		g0 = WorldTerrain.groundY(S, f.x)
		_gf_g0c = g0
		_gf_gx = f.x
		_gf_gtick = S.tick
	var stand: bool = (st == "free" or st == "locked" or st == "charging") and not sliding and absf(f.y - g0) < 8.0
	var target_w: float = 0.0
	var pitch_t: float = 0.0
	if stand or sliding:
		if not (_gf_x_valid and absf(SimWrap.sdx(_gf_x, f.x)) < 3.0 and vface == _gf_face and S.tick - _gf_tick < 20):
			_gf_x_valid = true
			_gf_x = f.x
			_gf_face = vface
			_gf_tick = S.tick
			_gf_dF = WorldTerrain.groundY(S, f.x + vface * 10.0) - g0
			_gf_dB = WorldTerrain.groundY(S, f.x - vface * 10.0) - g0
			_gf_sl = (WorldTerrain.groundY(S, f.x + vface * 12.0) - WorldTerrain.groundY(S, f.x - vface * 12.0)) / 24.0
		if sliding:
			pitch_t = atan(_gf_sl) * 0.9
		elif absf(_gf_dF) > 2.5 or absf(_gf_dB) > 2.5:
			target_w = 1.0   # a gentler slope than this is under the pose's own tolerance and costs a leg solve for nothing
	if absf(target_w - _foot_w) < 0.001 and absf(pitch_t - _skid_pitch) < 0.001 and _foot_w < 0.02 and absf(_skid_pitch) < 0.01:
		_foot_shift = 0.0
		_foot_dh = Vector2.ZERO
		return
	var k: float = 1.0 - exp(-dt / 0.1)
	_foot_w += (target_w - _foot_w) * k
	_skid_pitch += (pitch_t - _skid_pitch) * (1.0 - exp(-dt / 0.08))
	if absf(_skid_pitch) > 0.01:
		var pe: int = AnimRig.index["pelvis"]
		q[pe] = q[pe] * Quaternion(Vector3(0, 0, 1), _skid_pitch)
	if _foot_w < 0.02:
		_foot_shift = 0.0
		_foot_dh = Vector2.ZERO
		return
	var ix: Dictionary = AnimRig.index
	# the leg solve runs every second tick; in between the last solve's local corrections are applied again (the pose moves little)
	if _leg_tick >= 0 and S.tick - _leg_tick == 1 and (S.tick & 1) == 1:
		hips.y += _foot_shift
		for kk in range(4):
			var bi: int = _LEG_BONES[kk]
			q[bi] = q[bi] * _leg_dq[kk]
		_leg_tick = S.tick
		return
	var q0: Array[Quaternion] = [q[16], q[17], q[19], q[20]]
	AnimPose.fk_chain(q, hips, gq, gp, LEG_CHAIN)   # only the legs and what they hang from
	var fl: int = ix["foot_l"]
	var fr: int = ix["foot_r"]
	var dhl: float = WorldTerrain.groundY(S, f.x + vface * gp[fl].x) - g0
	var dhr: float = WorldTerrain.groundY(S, f.x + vface * gp[fr].x) - g0
	_foot_dh = Vector2(dhl, dhr)
	var shift: float = clampf((dhl + dhr) * 0.5, -10.0, 10.0) * _foot_w
	_foot_shift = shift
	hips.y += shift
	for i in LEG_CHAIN:
		if i > 0:
			gp[i].y += shift
	debug["slope_frames"] += 1
	for leg in [["thigh_l", "shin_l", "foot_l", dhl], ["thigh_r", "shin_r", "foot_r", dhr]]:
		var a: int = ix[leg[0]]
		var b: int = ix[leg[1]]
		var c: int = ix[leg[2]]
		var want: float = float(leg[3]) * _foot_w - shift
		if absf(want) < 0.4:
			continue   # this foot is already where the ground is
		var tgt := Vector3(gp[c].x, gp[c].y + want, gp[c].z)
		var pole: Vector3 = gp[b]
		AnimPose.ik_limb(q, gq, gp, a, b, c, tgt, pole, -1.0, _rd.shape_key)
	if _leg_dq.size() != 4:
		_leg_dq.resize(4)
	for kk in range(4):
		_leg_dq[kk] = q0[kk].inverse() * q[_LEG_BONES[kk]]
	_leg_tick = S.tick


## The next blow the attacker throws in the running exchange: [time to contact, heavy, damage, beat index], or [] (a parried
## exchange has none). A blow just fired (up to 0.03 s ago) still counts, so a miss can be flinched at.
static func _next_blow(ex) -> Array:
	if ex.cancel:
		return []
	var best: Array = []
	var i: int = 0
	for b in ex.beats:
		if b.op == "strike" and String(b.args.a) == "A":
			var dtc: float = b.t - ex.t
			if dtc >= -0.03 and (best.is_empty() or dtc < best[0]):
				best = [dtc, _is_heavy(ex, b.args), float(b.args.get("dmg", 0.0)), i]
		i += 1
	return best


## The next dodge or slip beat of the exchange: [time to it, beat index], or [].
static func _next_evade(ex) -> Array:
	var best: Array = []
	var i: int = 0
	for b in ex.beats:
		if b.op == "dodge" or b.op == "slip":
			var dt_e: float = b.t - ex.t
			if dt_e >= 0.0 and (best.is_empty() or dt_e < best[0]):
				best = [dt_e, i]
		i += 1
	return best


## The attacker's next blow that does no damage (a whiff): [time to contact, beat index] from 0.03 s after it to 0.1 s before, or [].
static func _next_miss(ex) -> Array:
	var best: Array = []
	var i: int = 0
	for b in ex.beats:
		if b.op == "strike" and String(b.args.a) == "A" and float(b.args.get("dmg", 0.0)) <= 0.0:
			var dtc: float = b.t - ex.t
			if dtc >= -0.03 and dtc < 0.1 and (best.is_empty() or dtc < best[0]):
				best = [dtc, i]
		i += 1
	return best


## The defender's lean away from a blow he is about to dodge: head and chest back, arms flung back, the weight on the heels.
func _lean_away(T: float, amp: float) -> void:
	_lean_t0 = T
	_rd.kick(0, 8.0 * amp)
	_rd.kick(1, 7.0 * amp)
	_rd.kick(2, -3.0 * amp)
	_rd.kick(5, -3.0 * amp)
	_hit_free = minf(1.0, _hit_free + 0.25)
	_rd.out_w = 1.0
	debug["leans"] += 1


## The whiff's over-commit: the chest and head go forward after the blow, the arms with it, the body carried a step past.
func _over_commit(T: float, amp: float) -> void:
	_over_t0 = T
	_rd.kick(1, -8.0 * amp)
	_rd.kick(0, -5.0 * amp)
	_rd.kick(2, 6.0 * amp)
	_rd.kick(5, 6.0 * amp)
	_rd.kick(4, 3.0 * amp)
	_rd.kick(7, 3.0 * amp)
	_hit_free = minf(1.0, _hit_free + 0.3)
	_rd.out_w = 1.0
	debug["overcommits"] += 1


## His blow was blocked (the sim's damage event of kind guard): the arms bounce back, the chest rocks, a small step back.
func on_blocked(T: float) -> void:
	if not RenderAnim.layer("defender"):
		return
	_block_t0 = T
	var amp: float = _rd_amp()
	_rd.kick(2, -5.0 * amp)
	_rd.kick(5, -5.0 * amp)
	_rd.kick(1, 3.0 * amp)
	_rd.kick(0, 3.0 * amp)
	_rd.out_w = 1.0
	debug["blocked"] += 1


## The root offsets of the lean-away (back), the over-commit (forward) and the blocked recoil (back), decaying.
func _evade_offsets(T: float) -> float:
	var x: float = 0.0
	var a: float = _rd_amp()
	var tl: float = T - _lean_t0
	if tl >= 0.0 and tl < 0.6:
		x -= 3.0 * a * sin(minf(tl / 0.12, 1.0) * PI * 0.5) * exp(-tl / 0.3)
	var to: float = T - _over_t0
	if to >= 0.0 and to < 0.8:
		x += 7.0 * a * sin(minf(to / 0.1, 1.0) * PI * 0.5) * exp(-to / 0.25)
	var tb: float = T - _block_t0
	if tb >= 0.0 and tb < 0.5:
		x -= 4.0 * a * exp(-tb / 0.12)
	return x


## The attacker has a blow due now (from 0.03 s ago to 0.05 s ahead).
static func _blow_due(ex) -> bool:
	for b in ex.beats:
		if b.op == "chainStrike" or (b.op == "strike" and String(b.args.a) == "A"):
			var dtc: float = b.t - ex.t
			if dtc >= -0.03 and dtc <= 0.05:
				return true
	return false


static func _has_evade(ex) -> bool:
	for b in ex.beats:
		if b.op == "dodge" or b.op == "slip":
			return true
	return false


## A blow that does not land passes close: the head is pulled back and the body flinches, small, from the attacker's side.
func _near_miss(S: SimState, f, amp: float) -> void:
	var a = S.dirS.ex.A
	var d := Vector2(SimWrap.sdx(a.x, f.x) * vface, f.y - a.y)
	d = d.normalized() if d.length() > 1.0 else Vector2(-1.0, 0.0)
	_rd.hit(d.x, d.y, 0.3 * amp, 0, 0.0, 0.0)
	_hit_free = minf(1.0, _hit_free + 0.2)
	_rd.out_w = 1.0
	debug["near_miss"] += 1


func _flight_layers(T: float, f) -> void:
	if f.state != "free" or _part != "":
		return
	var tb: float = T - _burst_t0
	if tb >= 0.0 and tb < 0.22:
		_mix_pose(AnimData.pose("move.burst"), smoothstep(0.0, 0.03, tb) * (1.0 - smoothstep(0.08, 0.22, tb)) * 0.9)
	var tk: float = T - _brake_t0
	if tk >= 0.0 and tk < 0.3:
		_mix_pose(AnimData.pose("move.brake"), smoothstep(0.0, 0.04, tk) * (1.0 - smoothstep(0.1, 0.3, tk)) * 0.85)
	if absf(_bank) > 0.004:
		var ix: Dictionary = AnimRig.index
		q[ix["pelvis"]] = q[ix["pelvis"]] * Quaternion(Vector3(1, 0, 0), _bank * 0.6)
		q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(1, 0, 0), _bank * 0.4)
	_shock_layer(T)


func _shock_layer(T: float) -> void:
	var ts: float = T - _shock_t0
	if ts >= 0.0 and ts < 1.2 and _shock_amp > 0.0:
		var e: float = exp(-ts / 0.5) * _shock_amp * _rd_amp()
		var w: float = sin(ts * TAU * 3.2)
		hips.y += 1.6 * e * w
		var s2: int = AnimRig.index["spine_2"]
		q[s2] = q[s2] * Quaternion(Vector3(0, 0, 1), 0.06 * e * cos(ts * TAU * 2.6))


func _base_lagged() -> bool:
	if _base_r.size() != AnimRig.N:
		_base_r.resize(AnimRig.N)
		var lagk: float = float(AnimData.personality.get("guard", {}).get("lag", 2.0))
		for i in range(AnimRig.N):
			_base_r[i] = 1.0 / (1.0 + lagk * AnimData.bone_lag[i])
	return true


## The guard comes up or goes down with overlap: the arms are kicked toward the new guard and settle back on their springs.
func _stance_kick(old: int, new: int) -> void:
	var g: Dictionary = AnimData.personality.get("guard", {})
	var amp: float = _rd_amp()
	var dir: Array = []
	if new == 1:
		dir = g.get("up", [6.0, 4.0])
	elif old == 1:
		dir = g.get("down", [-5.0, -3.0])
	if dir.is_empty():
		return
	_rd.kick(2, float(dir[0]) * amp)
	_rd.kick(5, float(dir[0]) * amp)
	_rd.kick(4, float(dir[1]) * amp)
	_rd.kick(7, float(dir[1]) * amp)
	_rd.out_w = 1.0
	debug["guard_kicks"] += 1


## The weight shift, the knee bounce, the heel lift and the breath of a stance, scaled by the form's tier. calm is 1 for a fighter
## standing still and falls to 0 as he moves.
func _personality_layer(T: float, stance: int, tier: int, calm: float) -> void:
	var P: Dictionary = AnimData.personality
	var st: Dictionary = P.stances[STANCES[clampi(stance, 0, 3)]]
	var tr: Dictionary = P.tiers[clampi(tier, 0, 3)]
	var amp: float = _rd_amp() * calm
	var ix: Dictionary = AnimRig.index
	var ph: float = float(slot) * 1.9
	var shp: Dictionary = AnimData.shapes.get(_rd.shape_key, {}).get("idle", {})
	var sway: float = float(st.sway) * float(tr.sway) * amp * float(shp.get("sway", 1.0))
	var hzm: float = float(shp.get("hz", 1.0))
	var s1: float = sin(T * TAU * float(st.hz) * float(tr.hz) * hzm + ph)
	var pe: int = ix["pelvis"]
	q[pe] = q[pe] * Quaternion(Vector3(1, 0, 0), s1 * 0.02 * sway)
	hips.z += s1 * 0.6 * sway
	hips.x += sin(T * TAU * float(st.hz) * float(tr.hz) * hzm * 0.7 + ph + 1.0) * 0.3 * sway
	var bn: float = float(st.bounce) * float(tr.bounce) * amp * float(shp.get("bounce", 1.0))
	var b1: float = sin(T * TAU * float(st.bounce_hz) * float(tr.hz) * hzm + ph)
	hips.y += absf(b1) * 0.45 * bn   # a hop on the toes (never a dip: the legs are posed, so a dip would sink the feet)
	var heel: float = float(st.heel) * amp * float(shp.get("heel", 1.0))
	q[ix["thigh_l"]] = q[ix["thigh_l"]] * Quaternion(Vector3(0, 0, 1), heel * maxf(0.0, b1))
	q[ix["shin_l"]] = q[ix["shin_l"]] * Quaternion(Vector3(0, 0, 1), -heel * 1.2 * maxf(0.0, b1))
	q[ix["thigh_r"]] = q[ix["thigh_r"]] * Quaternion(Vector3(0, 0, 1), heel * maxf(0.0, -b1))
	q[ix["shin_r"]] = q[ix["shin_r"]] * Quaternion(Vector3(0, 0, 1), -heel * 1.2 * maxf(0.0, -b1))
	var br: float = sin(T * TAU * 0.45 * float(tr.breath_hz) + ph) * 0.012 * float(tr.breath_amp) * float(st.breath) * amp * float(shp.get("breath", 1.0))
	q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 0, 1), br)
	q[ix["head"]] = q[ix["head"]] * Quaternion(Vector3(0, 0, 1), -br * 0.5)
	# the shape's own idle: arms that drift out and in (a sweeping build), a head that glances and holds (a machine)
	var sweep: float = float(shp.get("sweep", 0.0)) * amp
	if sweep > 0.0:
		var sv: float = sin(T * TAU * 0.31 + ph) * sweep
		q[ix["upper_arm_r"]] = q[ix["upper_arm_r"]] * Quaternion(Vector3(1, 0, 0), sv)
		q[ix["upper_arm_l"]] = q[ix["upper_arm_l"]] * Quaternion(Vector3(1, 0, 0), -sv)
	var servo: float = float(shp.get("servo", 0.0)) * amp
	if servo > 0.0:
		var cyc: float = T / 2.6 + float(slot) * 0.37
		var tt: float = cyc - floorf(cyc)
		var gl: float = smoothstep(0.0, 0.04, tt) * (1.0 - smoothstep(0.5, 0.54, tt))
		var sgn: float = 1.0 if (_hash(int(floorf(cyc)), slot, 17) & 1) == 0 else -1.0
		q[ix["head"]] = q[ix["head"]] * Quaternion(Vector3(0, 1, 0), servo * 0.1 * gl * sgn)
	debug["personality"] += 1


## A turn-around is a step: the weight dips, one foot swings through, the hips twist toward the new side and the shoulders against
## it, over 0.22 s from the moment the visual facing flipped (the view turns through front-on over the same time).
func _turn_layer(T: float) -> void:
	var tp: Dictionary = AnimData.personality.get("turn", {})
	var dur: float = float(tp.get("dur", 0.22))
	var tau: float = T - _turn_t0
	if tau < 0.0 or tau >= dur:
		return
	var u: float = tau / dur
	var s: float = sin(PI * u) * _rd_amp()
	var ix: Dictionary = AnimRig.index
	hips.y -= float(tp.get("dip", 1.4)) * s
	var sw: float = float(tp.get("swing", 0.5)) * s
	q[ix["thigh_r"]] = q[ix["thigh_r"]] * Quaternion(Vector3(0, 0, 1), sw)
	q[ix["shin_r"]] = q[ix["shin_r"]] * Quaternion(Vector3(0, 0, 1), -sw * 1.2)
	q[ix["thigh_l"]] = q[ix["thigh_l"]] * Quaternion(Vector3(0, 0, 1), -sw * 0.4)
	var tw: float = float(tp.get("twist", 0.35)) * s * (1.0 - u) * _turn_dir
	var pe: int = ix["pelvis"]
	q[pe] = q[pe] * Quaternion(Vector3(0, 1, 0), tw)
	q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 1, 0), -tw * 0.6)
	debug["turn_steps"] += 1


## What a change of speed along the facing is: a dash start (a hard push from nearly still) or a brake (a hard slowdown from a run).
## ax the acceleration along the facing (u/s^2), prev and now the speeds before and after (u/s).
static func _gait_event(ax: float, prev: float, now: float) -> String:
	if ax > 15000.0 and prev < 250.0 and now > prev:
		return "burst"
	if ax < -9000.0 and prev > 500.0 and now < prev:
		return "brake"
	return ""


## The winner's beat after the KO: 1 standing spent, 2 looking over the wreckage, 3 the end (held or a raised fist).
static func _win_phase(ko_t: float, _id: String) -> int:
	var w: Dictionary = AnimData.winner
	var t0: float = float(w.get("start", 0.8))
	if ko_t < t0 + float(w.get("stand", 1.0)):
		return 1
	if ko_t < t0 + float(w.get("stand", 1.0)) + float(w.get("survey", 2.5)):
		return 2
	return 3


## How the winner ends: "hold" the survey or "victory" (emote.victory), by his shape key (a data choice, not code).
func _win_end(roster_id: String) -> String:
	var ends: Dictionary = AnimData.winner.get("end", {})
	var key: String = String(AnimRagdoll.shape_of.get(roster_id, AnimRagdoll.shape_of.get("default", "")))
	return String(ends.get(key, ends.get("default", "hold")))


## The survey: the head and neck sweep slowly across the scene, the chest heaves; only the winner, only after the KO.
func _win_layer(S: SimState, f, T: float) -> void:
	if S.game.ko == null or is_same(S.game.ko, f) or f.state != "free":
		return
	var w: Dictionary = AnimData.winner
	var t0: float = float(w.get("start", 0.8)) + float(w.get("stand", 1.0))
	var tau: float = S.game.koT - t0
	var amp: float = _rd_amp()
	var ix: Dictionary = AnimRig.index
	var heave: float = sin(T * TAU * 0.9) * 0.05 * amp
	q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 0, 1), heave)
	if tau >= 0.0 and tau < float(w.get("survey", 2.5)):
		var u: float = tau / float(w.get("survey", 2.5))
		var yaw: float = sin(u * TAU) * float(w.get("yaw", 0.8)) * smoothstep(0.0, 0.15, u) * amp
		q[ix["head"]] = q[ix["head"]] * Quaternion(Vector3(0, 1, 0), yaw * 0.6)
		q[ix["neck"]] = q[ix["neck"]] * Quaternion(Vector3(0, 1, 0), yaw * 0.4)
		q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 1, 0), yaw * 0.1)
		debug["survey"] += 1


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
		_aim_arms(_aim_angle(S, f, null), smoothstep(0.2, 0.6, p))
		return
	for b in S.beams:
		if b.A == f and b.t < b.life:
			var bwt: float = 1.0 - smoothstep(0.55, 0.95, b.t)
			_mix_pose(AnimData.pose("beam.fire"), bwt)
			_aim_arms(_aim_angle(S, f, b), bwt)
			return


## The angle the signature is aimed at, in the body frame (0 forward, positive up): the beam's own direction once it is fired, the
## opponent's direction while it charges.
func _aim_angle(S: SimState, f, b) -> float:
	if b != null:
		return clampf(atan2(float(b.uy), float(b.ux) * vface), -1.2, 1.2)
	var opp = _opponent(S, f)
	if opp == null:
		return 0.0
	var dx: float = absf(SimWrap.sdx(f.x, opp.x))
	return clampf(atan2((opp.y + 55.0) - (f.y + 55.0), maxf(dx, 40.0)), -1.2, 1.2)


## Both arms (and a little of the chest) turn to the aim: a beam is thrown along its line, not along the pose's fixed forward.
func _aim_arms(alpha: float, w: float) -> void:
	if not RenderAnim.layer("aim") or w <= 0.001:
		return
	var a: float = alpha * w * _rd_amp()
	var ix: Dictionary = AnimRig.index
	for nm in ["upper_arm_l", "upper_arm_r"]:
		q[ix[nm]] = q[ix[nm]] * Quaternion(Vector3(0, 0, 1), a)
	q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 0, 1), a * 0.25)
	debug["aims"] += 1


## The head looks at the opponent: up or down by where his head is, smoothed, in an exchange or when he is near (overhaul unit D).
func _look_tick(S: SimState, f, dt: float) -> void:
	# once per sim tick (so a replay shows the same head); the target is re-aimed every third tick, the smoothing is linear
	if (S.tick + slot) % 3 == 0:
		var opp = _opponent(S, f)
		var t: float = 0.0
		var st: String = f.state
		if opp != null and st != "launched" and st != "down" and not (f.beamCharge != null):
			var dxo: float = SimWrap.sdx(f.x, opp.x) * vface
			if dxo > 10.0 and dxo < 1200.0:
				t = clampf(atan2(opp.y - f.y, maxf(dxo, 40.0)), -0.7, 0.7) * 0.8
		_look_target = t
	_look += (_look_target - _look) * clampf(dt * 8.0, 0.0, 1.0)


func _look_at(S: SimState, f, dt: float) -> void:
	if absf(_look) > 0.004:
		var a: float = _look * _rd_amp()
		var ix: Dictionary = AnimRig.index
		q[ix["head"]] = q[ix["head"]] * Quaternion(Vector3(0, 0, 1), a * 0.55)
		q[ix["neck"]] = q[ix["neck"]] * Quaternion(Vector3(0, 0, 1), a * 0.3)
		q[ix["spine_2"]] = q[ix["spine_2"]] * Quaternion(Vector3(0, 0, 1), a * 0.1)


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
		var rf: float = float(r.get("f", amp))
		var rdx: float = float(r.get("dx", -1.0 if bool(r.front) else 1.0))
		var rdy: float = float(r.get("dy", 0.0))
		var wk: float = 1.0 + 0.5 * _worn
		_recoil_x += rdx * rf * 7.0 * wk * smoothstep(0.0, 0.02, tau) * exp(-tau / 0.07)
		_recoil_y += rdy * rf * 4.0 * smoothstep(0.0, 0.02, tau) * exp(-tau / 0.08)
		if rf > 0.8:
			# a heavy blow staggers him: a quick sway after the push
			_recoil_x += rdx * rf * 2.5 * sin(tau * TAU * 3.0) * exp(-tau / 0.25)
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
		_mix_pose(AnimData.pose(pose_id), w * (0.55 if RenderAnim.ragdoll_enabled else 0.7))
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


## The sash and pack chains, one step per sim tick (never per frame, so a replay shows the same cloth): driven by the velocity along
## the way he faces, the acceleration, and a flutter at speed (overhaul unit D); frozen ticks run at a tenth.
func _spring_tick(S: SimState, f, dt: float, frozen: bool) -> void:
	var m: float = vface
	var vw := Vector2(f.vx * m, f.vy) if not (f.state == "intro" and RenderAnim.intro_poses) else Vector2.ZERO   # no wind in the opening
	var aw := Vector2.ZERO
	if _sp_have:
		aw = (vw - _sp_vw) / maxf(dt, 0.0001)
	_sp_vw = vw
	_sp_have = true
	var h_all: float = dt * (0.1 if frozen else 1.0)
	var sp_n: float = clampf(vw.length() / 1600.0, 0.0, 1.0)
	var flutter: float = 0.12 * sp_n * (0.35 if RenderAnim.reduced_motion else 1.0) * (1.0 if RenderAnim.layer("cloth") else 0.0)
	var ov: float = 1.0 if RenderAnim.layer("cloth") else 0.0
	var target: float = -clampf(vw.x / 1600.0, -1.0, 1.0) * 0.9 - clampf(aw.x / 12000.0, -1.0, 1.0) * 0.5 * ov - clampf(-vw.y / 2400.0, 0.0, 1.0) * 0.6 * ov
	var n: int = 2
	var h: float = h_all / float(n)
	for _s in range(n):
		for kx in range(5):
			var stiff: float = [40.0, 60.0, 90.0, 60.0, 90.0][kx]
			var damp: float = 5.0
			var goal: float = target * [0.5, 1.0, 0.8, 1.0, 0.8][kx] + flutter * sin(S.T * TAU * 4.5 + float(kx) * 1.3 + float(slot))
			var a: float = -stiff * (_sx[kx] - goal) - damp * _sv[kx]
			_sv[kx] += a * h
			_sx[kx] += _sv[kx] * h


func _springs(f) -> void:
	for kx in range(5):
		var bi: int = _spring_bones[kx]
		q[bi] = q[bi] * Quaternion(Vector3(0, 0, 1), clampf(_sx[kx], -0.9, 0.9))
