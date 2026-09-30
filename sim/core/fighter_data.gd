class_name FighterData
## D1a, the roster as data (docs/architecture/d1-roster-data.md): data/fighters/roster.json and, per fighter,
## data/fighters/<id>/fighter.json, wounds.json and meters.json (which meters it has). Loaded once per process, like DirData; the data are match inputs.
## createFighter copies each def's scalars into Fighter fields and points f.wd at one immutable WoundsDef, so the tick
## never reads a Dictionary. dataHash() is the canonical hash of the parsed content (sorted keys, "_" keys skipped):
## comments and whitespace are free to change, any number or rule change shows (goldens, replay header). Every problem is
## collected in errors(), which the parity gate checks; the numbers are exact (the D1a proof reproduced the pre-D1a
## goldens bit for bit).

const ROOT: String = "res://data/fighters/"
const RALLY_RULES: Array = ["second_wind", "spite", "reboot", "encore", "none"]
const PROFILES: Array = ["plain"]
const METERS: Array = ["anguish", "menace"]
const PENALTIES: Array = ["coreKiRegen", "legsSpeed", "legsLockBreak", "staggerTicks", "dazeTicks", "armsGuardMul", "armsBrokenMul", "headParryNarrow", "headDefence", "legsSlip"]


## One fighter's wound numbers (wounds.json). Read-only after load.
class WoundsDef:
	var wearPerDamage: float = 0.0
	var stageAt: Array = []        # int units: bruised, battered, broken
	var fadeOut: int = 0
	var fadeBreath: int = 0
	var breathAfter: float = 0.0   # seconds (breathAfterTicks / 60), compared with S.T - f.exT like the old constant
	var fadeHidden: int = 0
	var hiddenFloor: int = 0
	var focusWear: float = 0.0
	var family: Dictionary = {}    # family -> [head, core, arms, legs] weights
	var coreKiRegen: float = 0.0
	var legsSpeed: float = 0.0
	var legsLockBreak: float = 0.0
	var staggerTicks: int = 0
	var dazeTicks: int = 0
	var armsGuardMul: float = 0.0
	var armsBrokenMul: float = 0.0
	var headParryNarrow: float = 0.0
	var headDefence: float = 0.0
	var legsSlip: float = 0.0
	var rallyWear: int = 0
	var rallyCool: int = 0
	var profile: String = ""


static var root: String = ROOT   # tests only: loadFrom() points the loader at a fixture folder
static var quiet: bool = false   # tests only: collect errors without printing them (the negative controls)
static var _defs = null          # id -> the createFighter Dictionary (with "wd", a WoundsDef)
static var _order: Array = []
static var _hash: String = ""
static var _errors: Array = []


static func _ensure() -> void:
	if _defs != null:
		return
	_defs = {}
	_order = []
	_errors = []
	var h := SimHash.Hasher.new()
	var roster = _read("roster.json", h)
	var ids: Array = []
	if roster is Array:
		ids = roster
	elif roster is Dictionary and roster.get("order") is Array:   # {"schema": "roster/1", "order": [...]}, if Tools adopts it
		ids = roster.order
	else:
		_err("roster.json: expected an array of fighter ids")
	for id in ids:
		if not (id is String) or _defs.has(id):
			_err("roster.json: bad or duplicate id " + str(id))
			continue
		var fj = _read(id + "/fighter.json", h)
		var wj = _read(id + "/wounds.json", h)
		var mj = _read(id + "/meters.json", h) if FileAccess.file_exists(root + id + "/meters.json") else {}
		if not (fj is Dictionary and wj is Dictionary):
			continue
		var def := _fighter(id, fj)
		def.wd = _wounds(id, wj)
		# D1a reads only which meters the fighter has (D1b wires their numbers).
		var meters: Dictionary = mj.get("meters", {}) if mj is Dictionary else {}
		for m in meters:
			if not String(m).begins_with("_") and not METERS.has(m):
				_err(id + "/meters.json: unknown meter '" + m + "' (D1a knows anguish and menace)")
		def.anguish = meters.has("anguish")
		def.menace = meters.has("menace")
		_defs[id] = def
		_order.append(id)
	_hash = h.hex()


## Tests only: load again from dir (the parity gate's negative controls), then back from ROOT.
static func loadFrom(dir: String = ROOT) -> void:
	root = dir
	_defs = null
	_ensure()


## The roster order (the select screen; the first two are the default pairing).
static func order() -> Array:
	_ensure()
	return _order


static func def(id: String) -> Dictionary:
	_ensure()
	if not _defs.has(id):
		push_error("FighterData: no fighter " + id)
		return {}
	return _defs[id]


static func dataHash() -> String:
	_ensure()
	return _hash


static func errors() -> Array:
	_ensure()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)
	if not quiet:
		push_error("FighterData: " + msg)


## Read, lint (at most 15 significant digits per number, as for literals) and parse one file, and fold its canonical form
## into the data hash.
static func _read(rel: String, h: SimHash.Hasher):
	var path: String = root + rel
	if not FileAccess.file_exists(path):
		_err(rel + ": missing")
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string("(?<![#\\w.])-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?")
	for m in re.search_all(text):
		var digits: String = m.get_string().split("e")[0].split("E")[0].replace("-", "").replace(".", "").lstrip("0")
		if digits.length() > 15:
			_err(rel + ": more than 15 significant digits in " + m.get_string())
	var v = JSON.parse_string(text)
	if v == null:
		_err(rel + ": not valid JSON")
		return null
	h.text(rel)
	_canon(h, v)
	return v


## Canonical walk: dictionaries by sorted key, "_" keys skipped; every value tagged by type.
static func _canon(h: SimHash.Hasher, v) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			var keys: Array = v.keys().filter(func(k): return not String(k).begins_with("_"))
			keys.sort()
			h.text("{")
			h.num(float(keys.size()))
			for k in keys:
				h.text(k)
				_canon(h, v[k])
		TYPE_ARRAY:
			h.text("[")
			h.num(float(v.size()))
			for x in v:
				_canon(h, x)
		TYPE_FLOAT, TYPE_INT:
			h.text("n")
			h.num(float(v))
		TYPE_STRING:
			h.text("s")
			h.text(v)
		TYPE_BOOL:
			h.text("b")
			h.u(1 if v else 0)
		_:
			h.text("z")


## fighter.json -> the createFighter Dictionary.
static func _fighter(id: String, j: Dictionary) -> Dictionary:
	var where: String = id + "/fighter.json"
	if j.get("id", "") != id:
		_err(where + ": id must equal the folder name")
	var idn: Dictionary = j.get("identity", {})
	var st: Dictionary = j.get("stats", {})
	var rule: String = String(j.get("rally", {}).get("rule", ""))
	if not RALLY_RULES.has(rule):
		_err(where + ": unknown Rally rule '" + rule + "'")
	var d := {"id": id, "name": String(idn.get("name", id)), "title": String(idn.get("title", "")), "role": String(idn.get("role", "")),
		"col": String(idn.get("col", "#ffffff")), "aura": String(idn.get("aura", "#ffffff")), "hair": String(idn.get("hair", "#000000")),
		"sigName": String(idn.get("sigName", "")), "care": float(st.get("care", 0.0)), "dmgMul": float(st.get("dmgMul", 1.0)),
		"spd": float(st.get("spd", 1.0)), "maxhp": float(st.get("maxhp", 1.0)), "canHide": bool(j.get("kit", {}).get("canHide", false)),
		"rally": "" if rule == "none" else rule, "finisher": String(j.get("finishers", {}).get("base", ""))}
	if not ["hero", "villain", "rival"].has(d.role):
		_err(where + ": unknown role '" + d.role + "'")
	return d


## wounds.json -> a WoundsDef. D1a supports the plain profile over the four shared regions; values marked pinned must equal
## the SimWounds constant another owner's file still reads.
static func _wounds(id: String, j: Dictionary) -> WoundsDef:
	var where: String = id + "/wounds.json"
	var w := WoundsDef.new()
	var regions: Dictionary = j.get("regions", {})
	for r in SimWounds.REGIONS:
		if not (regions.get(r, {}).get("brink", false) == true):
			_err(where + ": D1a needs the regions head, core, arms and legs, each with brink true")
	if regions.keys().filter(func(k): return not String(k).begins_with("_")).size() != 4:
		_err(where + ": extra regions wait for F1 and N1")
	w.stageAt = []
	for x in j.get("stageAt", []):
		w.stageAt.append(_int(where + " stageAt", x))
	w.wearPerDamage = float(j.get("wearPerDamage", 0.0))
	var fd: Dictionary = j.get("fade", {})
	w.fadeOut = _int(where + " fade.out", fd.get("out", 0))
	w.fadeBreath = _int(where + " fade.breath", fd.get("breath", 0))
	w.breathAfter = float(_int(where + " fade.breathAfterTicks", fd.get("breathAfterTicks", 0))) / 60.0
	w.fadeHidden = _int(where + " fade.hidden", fd.get("hidden", 0))
	w.hiddenFloor = _int(where + " fade.hiddenFloor", fd.get("hiddenFloor", 0))
	w.focusWear = float(j.get("focusWear", 0.0))
	for fam in ["light", "heavy", "guard", "spread"]:
		var row = j.get("family", {}).get(fam)
		if not (row is Array and row.size() == 4):
			_err(where + ": family." + fam + " needs 4 weights")
			row = [0.0, 0.0, 0.0, 0.0]
		w.family[fam] = row.map(func(x): return float(x))
	var p: Dictionary = j.get("penalties", {})
	for k in PENALTIES:
		if not p.has(k):
			_err(where + ": penalties." + k + " missing")
	w.coreKiRegen = float(p.get("coreKiRegen", 1.0))
	w.legsSpeed = float(p.get("legsSpeed", 1.0))
	w.legsLockBreak = float(p.get("legsLockBreak", 1.0))
	w.staggerTicks = _int(where + " penalties.staggerTicks", p.get("staggerTicks", 0))
	w.dazeTicks = _int(where + " penalties.dazeTicks", p.get("dazeTicks", 0))
	w.armsGuardMul = float(p.get("armsGuardMul", 1.0))
	w.armsBrokenMul = float(p.get("armsBrokenMul", 1.0))
	w.headParryNarrow = float(p.get("headParryNarrow", 0.0))
	w.headDefence = float(p.get("headDefence", 0.0))
	w.legsSlip = float(p.get("legsSlip", 0.0))
	w.profile = String(j.get("profile", {}).get("type", ""))
	if not PROFILES.has(w.profile):
		_err(where + ": unknown profile type '" + w.profile + "'")
	var ra: Dictionary = j.get("rally", {})
	w.rallyWear = _int(where + " rally.rallyWear", ra.get("rallyWear", 0))
	w.rallyCool = _int(where + " rally.coolTicks", ra.get("coolTicks", 0))
	# Pinned: another owner's file reads the SimWounds constant; a different value would be silently half-applied.
	_pin(where, "stageAt", w.stageAt, SimWounds.STAGE_AT, "sim/director/ai.gd, qa/godot/records.gd")
	_pin(where, "fade.hiddenFloor", w.hiddenFloor, SimWounds.FADE_HIDDEN_FLOOR, "sim/director/ai.gd")
	_pin(where, "penalties.headParryNarrow", w.headParryNarrow, SimWounds.HEAD_PARRY_NARROW, "sim/director/melee.gd")
	_pin(where, "penalties.headDefence", w.headDefence, SimWounds.HEAD_DEFENCE, "sim/director/data.gd")
	_pin(where, "penalties.legsSlip", w.legsSlip, SimWounds.LEGS_SLIP, "sim/director/data.gd")
	return w


static func _int(where: String, x) -> int:
	var f: float = float(x)
	if f != floor(f):
		_err(where + ": must be an integer, got " + str(x))
	return int(f)


static func _pin(where: String, key: String, got, want, reader: String) -> void:
	if got != want:
		_err("%s: %s is pinned to %s while %s reads the SimWounds constant" % [where, key, str(want), reader])
