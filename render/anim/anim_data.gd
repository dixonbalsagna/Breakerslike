class_name AnimData
extends RefCounted
## Loads and bakes the animation data in data/anim/ (poses, key sets, timing profiles, the cue map) once. Render only:
## nothing here is read by the sim, and the files sit outside the sim's data hash (tools/validate.js guards that).
## Poses are baked from their sketch form (anim_pose.gd); the far-side (mirrored) variant of each is made on first use.

const DIR := "res://data/anim/"

static var loaded: bool = false
static var poses: Dictionary = {}       # id -> AnimPose (the near-side version)
static var mirrors: Dictionary = {}     # id -> AnimPose (the mirrored version), made lazily
static var keysets: Dictionary = {}
static var picks: Dictionary = {}
static var profiles: Dictionary = {}
static var default_profile: String = "snappy"
static var by_part: Dictionary = {}          # part kind (light, heavy, chain, rush, launch, power) -> profile name
static var bone_lag := PackedFloat32Array()
static var cue_poses: Dictionary = {}   # cue kind -> pose id
static var forms: Dictionary = {}       # transformation: version -> {gather, break, settle, hold} in ticks
static var quality_levels: Dictionary = {}   # level -> the overhaul layers it switches off
static var winner: Dictionary = {}          # data/anim/winner.json (the winner after a KO)
static var personality: Dictionary = {}
static var ragdoll_motion: Dictionary = {}
static var ragdoll: Dictionary = {}      # data/anim/ragdoll.json (read by AnimRagdoll.setup)
static var form_poses: Dictionary = {}  # beat -> pose id
static var load_waves: bool = false      # --waves: also bake the parked pose waves of data/anim/waves/ (tools only; no live match plays them)
static var raw: Dictionary = {}         # id -> the sketch each pose was baked from (poses.json, and the waves when loaded)
static var live: Dictionary = {}         # data/anim/waves/wave1.live.json: the go-live step 1 pick lists, gates and shapes (used only with --wave1-live)
static var entries: Dictionary = {}      # parked entry sequences (data/anim/waves/*.entries.json): id -> {phases: [{pose, ticks}]}; played by an `entry` beat
static var wave_of: Dictionary = {}     # pose id -> the wave file it came from
static var shapes: Dictionary = {}      # data/anim/shapes.json: shape key -> {idle, hit} tuning
static var sockets: Dictionary = {}     # data/anim/sockets.json (regions a blow lands on, limbs that land it)
static var effector_poses: Dictionary = {}   # data/anim/effectors.json: pose id -> authored clavicle hunch


static func _read(name: String) -> Dictionary:
	var txt: String = FileAccess.get_file_as_string(DIR + name)
	if txt == "":
		push_error("AnimData: cannot read " + DIR + name)
		return {}
	var j = JSON.parse_string(txt)
	return j if typeof(j) == TYPE_DICTIONARY else {}


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	AnimRig.setup()
	var ej: Dictionary = _read("effectors.json")
	var hj: Dictionary = ej.get("hunch", {})
	AnimPose.hunch_auto = bool(hj.get("auto", true)) and not OS.get_cmdline_user_args().has("--nohunch")
	AnimPose.hunch_fwd_max = float(hj.get("fwd_max", 2.5))
	AnimPose.hunch_up_max = float(hj.get("up_max", 2.0))
	effector_poses = ej.get("poses", {})
	sockets = _read("sockets.json")
	shapes = _read("shapes.json").get("shapes", {})
	if live_flag_early() and FileAccess.file_exists(DIR + "waves/wave1.live.json"):
		live = _read("waves/wave1.live.json")
	var pj: Dictionary = _read("poses.json")
	var src: Dictionary = pj.get("poses", {})
	for id in src:
		var sk: Dictionary = src[id]
		if effector_poses.has(id) and AnimPose.hunch_auto:
			sk = sk.duplicate()
			for sd in ["r", "l"]:
				if effector_poses[id].has(sd):
					sk["hunch_" + sd] = effector_poses[id][sd]
		poses[id] = AnimPose.bake(id, sk)
		raw[id] = sk
	var kj: Dictionary = _read("keysets.json")
	keysets = kj.get("keysets", {})
	picks = kj.get("picks", {})
	var live_flag: bool = OS.get_cmdline_user_args().has("--wave1-live")
	if load_waves or live_flag or OS.get_cmdline_user_args().has("--waves"):
		var da := DirAccess.open(DIR + "waves")
		if da != null:
			var names: Array = []
			for fn in da.get_files():
				if fn.ends_with(".poses.json"):
					var wn0: String = fn.trim_suffix(".poses.json")
					if load_waves or OS.get_cmdline_user_args().has("--waves") or wn0 == "wave1":   # the live flag loads wave 1 only
						names.append(wn0)
			names.sort()
			for wn in names:
				var wp: Dictionary = _read("waves/" + wn + ".poses.json").get("poses", {})
				for id in wp:
					poses[id] = AnimPose.bake(id, wp[id])
					raw[id] = wp[id]
					wave_of[id] = wn
				if FileAccess.file_exists(DIR + "waves/" + wn + ".keysets.json"):
					var wk: Dictionary = _read("waves/" + wn + ".keysets.json").get("keysets", {})
					for kid in wk:
						keysets[kid] = wk[kid]
				if FileAccess.file_exists(DIR + "waves/" + wn + ".entries.json"):
					var we: Dictionary = _read("waves/" + wn + ".entries.json").get("entries", {})
					for eid in we:
						entries[eid] = we[eid]
	var prj: Dictionary = _read("profiles.json")
	profiles = prj.get("profiles", {})
	default_profile = String(prj.get("default", "snappy"))
	by_part = prj.get("by_part", {})
	bone_lag.resize(AnimRig.N)
	var bl: Dictionary = prj.get("bone_lag", {})
	for i in range(AnimRig.N):
		bone_lag[i] = float(bl.get(AnimRig.BONES[i][0], 0.0))
	cue_poses = _read("cues.json").get("cues", {})
	var fj: Dictionary = _read("forms.json")
	forms = fj.get("versions", {})
	form_poses = fj.get("poses", {})
	ragdoll = _read("ragdoll.json")
	ragdoll_motion = _read("ragdoll_motion.json")
	personality = _read("personality.json")
	winner = _read("winner.json")
	quality_levels = _read("quality.json").get("levels", {})


static func pose(id: String, mirror: bool = false) -> AnimPose:
	var p = poses.get(id)
	if p == null:
		push_error("AnimData: unknown pose " + id)
		return poses.values()[0]
	if not mirror:
		return p
	var m = mirrors.get(id)
	if m == null:
		m = (p as AnimPose).mirrored()
		mirrors[id] = m
	return m


static func profile(name: String) -> Dictionary:
	return profiles.get(name, profiles.get(default_profile, {}))


static func live_flag_early() -> bool:
	return OS.get_cmdline_user_args().has("--wave1-live") or RenderAnim.wave1_live
