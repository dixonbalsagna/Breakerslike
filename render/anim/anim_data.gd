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
static var personality: Dictionary = {}
static var ragdoll_motion: Dictionary = {}
static var ragdoll: Dictionary = {}      # data/anim/ragdoll.json (read by AnimRagdoll.setup)
static var form_poses: Dictionary = {}  # beat -> pose id


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
	var pj: Dictionary = _read("poses.json")
	var src: Dictionary = pj.get("poses", {})
	for id in src:
		poses[id] = AnimPose.bake(id, src[id])
	var kj: Dictionary = _read("keysets.json")
	keysets = kj.get("keysets", {})
	picks = kj.get("picks", {})
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
