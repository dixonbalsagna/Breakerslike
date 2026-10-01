class_name SimInputData
## The input scheme's data (docs/controls/input-schema.md): the action list, the presets and every tick value, loaded
## once from res://data/input/. The layout layer (layout.gd, touch.gd, hub.gd) reads its numbers from here and never
## from code. If the files are missing (a headless tool run from a copy without them) the built-in copy of the shipped
## values is used, so a test or a batch plays the same without the data folder.
##
## load_and_apply() also sets SimAct's three statics from this data, as intent-v2.md section 6c asks.

const DIR: String = "res://data/input/"

## The shipped timing.json, as a fallback. Keep it equal to the file; sim/input/test/hub_test.gd checks that it is.
const DEFAULT_TIMING: Dictionary = {
	"schema": 1, "ticksPerSecond": 60,
	"tapHold": {"holdStart": 12, "transformConfirm": 30, "encoreConfirm": 18, "encoreOffer": 180, "chordWindow": 6},
	"perfectBlock": {"lightWindow": 8, "heavyWindow": 10, "buffer": 4, "touchBufferBonus": 2, "antiMashLockout": 20, "assistFactor": 2},
	"dodge": {"buffer": 4, "stateTicks": 12},
	"attackQueue": {"max": 3, "expiry": 36, "upgradeWindow": 24, "heavyKi": 4, "signatureKi": 45},
	"mode": {"toggleCooldown": 12},
	"touch": {"flickToDodgeTicks": 6, "flickThreshold": 0.7, "outerRingScale": 1.3, "outerRingHold": 6, "fullDeflectionSprint": 30, "swipeUpPx": 40, "swipeUpTicks": 24, "edgeIgnoreDp": 8},
	"stick": {"deadzone": 0.2, "quant": 16, "triggerOn": 0.35, "triggerOff": 0.25, "awayDead": 0.3},
}

## Values the schema does not carry (dodge.lungeTicks, stick.fullAt are code defaults until it does), and the last
## fallback for any key a data file lacks.
const EXTRA: Dictionary = {
	"chordWindow": 6,     # two triggers down within this many ticks are the transform chord
	"stateTicks": 12,     # a dodge reads as the Dodge state for this long (SimAct.dodgeWindow)
	"lungeTicks": 12,     # the dash that goes with a dodge until the director moves the fighter itself
	"awayDead": 0.3,      # SimAct.awayDead
	"fullAt": 0.9,        # a stick reaches full speed at this fraction of its travel
}

static var timing: Dictionary = {}
static var presets: Dictionary = {}
static var actions: Dictionary = {}
static var loaded: bool = false


## Read the three files. True if they were found; the defaults stand in otherwise. Safe to call more than once.
static func load_data(dir: String = DIR) -> bool:
	var ok := true
	var t = _read(dir + "timing.json")
	if t is Dictionary:
		timing = t
	else:
		timing = DEFAULT_TIMING.duplicate(true)
		ok = false
	var l = _read(dir + "layouts.json")
	presets = {}
	if l is Dictionary and l.has("presets"):
		for p in l["presets"]:
			presets[str(p["id"])] = p
	else:
		ok = false
	var a = _read(dir + "actions.json")
	actions = {}
	if a is Dictionary and a.has("actions"):
		for x in a["actions"]:
			actions[str(x["id"])] = x
	loaded = true
	return ok


static func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func ensure() -> void:
	if not loaded:
		load_data()


## One timing value by path, for example t(["tapHold", "holdStart"]); the built-in values and EXTRA back it up.
static func t(path: Array, fallback = null):
	ensure()
	var cur = timing
	for k in path:
		if cur is Dictionary and cur.has(k):
			cur = cur[k]
		else:
			cur = null
			break
	if cur != null:
		return cur
	var d = DEFAULT_TIMING
	for k in path:
		if d is Dictionary and d.has(k):
			d = d[k]
		else:
			d = null
			break
	if d != null:
		return d
	return EXTRA.get(path[path.size() - 1], fallback)


static func ti(path: Array, fallback: int = 0) -> int:
	return int(t(path, fallback))


static func tf(path: Array, fallback: float = 0.0) -> float:
	return float(t(path, fallback))


## A preset by id, or an empty dictionary.
static func preset(id: String) -> Dictionary:
	ensure()
	return presets.get(id, {})


## The default preset id for a device ("kb", "pad" or "touch").
static func default_preset(device: String) -> String:
	ensure()
	for id in presets:
		var p: Dictionary = presets[id]
		if p.get("device", "") == device and p.get("default", false) == true:
			return id
	return ""


## Load the data and set SimAct's statics from it: the request queue's depth, the dodge's state window and the away
## dead zone. Called once by the host at startup.
static func load_and_apply() -> void:
	load_data()
	SimAct.queueMax = ti(["attackQueue", "max"], SimAct.queueMax)
	SimAct.dodgeWindow = ti(["dodge", "stateTicks"], SimAct.dodgeWindow)
	SimAct.awayDead = tf(["stick", "awayDead"], SimAct.awayDead)
