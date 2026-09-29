class_name UiData
## Loads the HUD's content data (ui/data/*.json) once: the player-facing terms and the per-fighter readout profiles.
## Nothing here reads the sim. A missing key returns the key itself, so a data mistake is visible, not silent.

const TERMS_PATH := "res://ui/data/terms.json"
const PROFILES_PATH := "res://ui/data/readout_profiles.json"

static var _terms: Dictionary = {}
static var _profiles: Dictionary = {}
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_terms = _read(TERMS_PATH)
	_profiles = _read(PROFILES_PATH)


static func reload() -> void:
	_loaded = false
	ensure()


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("UiData: missing " + path)
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	if v is Dictionary:
		return v
	push_error("UiData: cannot parse " + path)
	return {}


## A term by dotted path, e.g. "stance.press" or "card.heat.2". Missing: the path itself.
static func t(path: String) -> String:
	ensure()
	var cur = _terms
	var parts: PackedStringArray = path.split(".")
	var i := 0
	while i < parts.size():
		if not (cur is Dictionary):
			return path
		# Keys may themselves contain a dot ("heat.2", "rally.anti_hero"): try the longest join first.
		var found := false
		var j := parts.size()
		while j > i:
			var key: String = ".".join(parts.slice(i, j))
			if cur.has(key):
				cur = cur[key]
				i = j
				found = true
				break
			j -= 1
		if not found:
			return path
	return str(cur) if not (cur is Dictionary or cur is Array) else path


static func fmt(path: String, vars: Dictionary) -> String:
	var s: String = t(path)
	for k in vars:
		s = s.replace("{" + str(k) + "}", str(vars[k]))
	return s


static func tier_name(tier: int) -> String:
	ensure()
	var a: Array = _terms.get("tier", [])
	if a.is_empty():
		return "TIER"
	return str(a[clampi(tier - 1, 0, a.size() - 1)])


static func places() -> Array:
	ensure()
	return _terms.get("places", [])


static func place_at(x: float) -> String:
	for p in places():
		if x >= float(p.x0) and x < float(p.x1):
			return str(p.name)
	return ""


static func caption_for(gesture: String) -> String:
	ensure()
	var c: Dictionary = _terms.get("caption", {})
	return str(c.get(gesture, gesture))


## Rename a prototype banner to the glossary's wording ("NEED 45 KI" becomes "NEED 45 CHARGE"). Unknown text passes through.
static func banner(text: String) -> String:
	ensure()
	var m: Dictionary = _terms.get("banner_rename", {})
	if m.has(text):
		return str(m[text])
	return text.replace(" KI", " CHARGE")


## The readout profile for a fighter id (its own entry over the default; aliases such as the sim's placeholder KAI
## and VORR map onto a base profile with overrides).
static func profile(id: String) -> Dictionary:
	ensure()
	var out: Dictionary = (_profiles.get("default", {}) as Dictionary).duplicate(true)
	var key: String = id
	var al: Dictionary = _profiles.get("aliases", {})
	if al.has(id):
		var a: Dictionary = al[id]
		var base: String = str(a.get("base", "default"))
		if base != "default" and _profiles.has(base):
			out.merge(_profiles[base], true)
		for k in a:
			if k != "base":
				out[k] = a[k]
		out["id"] = id
		return out
	if _profiles.has(key):
		out.merge(_profiles[key], true)
	out["id"] = id
	return out


const OPTIONS_PATH := "res://ui/data/options.json"
static var _options: Dictionary = {}


## The option definitions (ui/data/options.json): key -> {default, group, label, help, accessibility, choices}.
static func options() -> Dictionary:
	if _options.is_empty():
		_options = _read(OPTIONS_PATH).get("options", {})
	return _options


## The defaults of every option, key -> value.
static func option_defaults() -> Dictionary:
	var out := {}
	var o: Dictionary = options()
	for k in o:
		out[k] = o[k].get("default")
	return out
