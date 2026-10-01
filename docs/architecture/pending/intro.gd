class_name SimIntro
## The intro phase (docs/architecture/intro-phase.md; Camera's row 7): a run of pre-clock ticks at the start of a match,
## built like a pause. SimCore.step returns false, S.T stays 0, no input is consumed and nothing else in the sim runs.
## Inside it a fixed timeline plays: each fighter falls from the sky and lands in a crater, they stare, the clock starts.
##
## It is a match setting, in newMatch's setup and so in the replay header: "intro": true plays it; "intro": "skip" applies
## its effects at once (both craters, both fighters on the ground) with no pre-clock tick, for batches and probes; without
## the key a match starts as it always did. A press on a human slot skips it (after intro.json's skipFrom ticks): the
## landings left are applied at once, in order, so the state at the clock is the same whether it ran or was skipped.
## The fall is a closed-form path, not flight physics, and nothing here draws a random number.

const PATH: String = "res://data/fight/intro.json"
const TPS: int = 60

static var _loaded: bool = false
static var _hash: String = ""
static var _errors: Array = []
static var fall: Array = [0, 0]      # per slot: the tick its fall starts ...
static var land: Array = [0, 0]      # ... and the tick it lands
static var staredown: int = 0
static var clock: int = 0            # the tick the clock starts: the intro's length
static var skipFrom: int = 0         # a press skips from this tick on
static var fallHeight: float = 0.0   # units above the ground the fall starts from
static var craterE: float = 0.0      # the entrance crater's energy (WorldCrater.dig)


# ---------------------------------------------------------------- data

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_errors = []
	var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (j is Dictionary):
		_err("data/fight/intro.json is missing or not valid JSON")
		j = {}
	var h := SimHash.Hasher.new()
	h.text("intro")
	FighterData._canon(h, j)
	_hash = h.hex()
	var t: Dictionary = j.get("ticks", {})
	fall = [_tick("ticks.fallA", t.get("fallA")), _tick("ticks.fallB", t.get("fallB"))]
	land = [_tick("ticks.landA", t.get("landA")), _tick("ticks.landB", t.get("landB"))]
	staredown = _tick("ticks.staredown", t.get("staredown"))
	clock = _tick("ticks.clock", t.get("clock"))
	skipFrom = _tick("ticks.skipFrom", t.get("skipFrom"))
	fallHeight = float(j.get("fallHeight", 0.0))
	craterE = float(j.get("craterEnergy", 0.0))
	if not (fall[0] < land[0] and fall[1] < land[1] and land[0] <= land[1] and land[1] <= staredown and staredown < clock):
		_err("ticks: each fall before its landing, A's landing not after B's, then the staredown, then the clock")
	if skipFrom >= clock:
		_err("ticks.skipFrom must be before the clock")
	if not (fallHeight > 0.0) or craterE < 0.0:
		_err("fallHeight must be above 0 and craterEnergy at least 0")


static func dataHash() -> String:
	_ensure()
	return _hash


static func errors() -> Array:
	_ensure()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)
	push_error("SimIntro: " + msg)


static func _tick(where: String, x) -> int:
	var f: float = float(x) if x != null else -1.0
	if x == null or f != floor(f) or f < 0.0:
		_err(where + ": must be a whole number of ticks, at least 0, got " + str(x))
		return 0
	return int(f)


# ---------------------------------------------------------------- the match

## A new match (sim.gd newMatch, after the fighters exist and before it clears the event list).
static func setup(S: SimState, su: Dictionary) -> void:
	_ensure()
	S.intro = SimState.IntroState.new()
	var mode = su.get("intro", false)
	if mode is String and mode == "skip":
		for k in range(S.fighters.size()):
			_land(S, k)
		_stand(S)
	elif mode is bool and mode == true:
		S.intro.left = clock
		for f in S.fighters:
			f.state = "intro"
			f.vx = 0.0
			f.vy = 0.0
			f.y = WorldTerrain.groundY(S, f.x) + fallHeight


## One step of the sim (SimCore.step, before the pause and the hit-stop). True while the intro runs: the tick is a
## pre-clock tick. inputs is what step was given; only a press on a human slot is read, and only to skip.
static func tick(S: SimState, inputs) -> bool:
	var it = S.intro
	if it.left <= 0:
		return false
	var t: int = it.t
	if t == 0:
		SimFx.introStart(S, float(clock) / float(TPS), float(skipFrom) / float(TPS))
	if t >= skipFrom and _pressed(S, inputs):
		for k in range(S.fighters.size()):
			if (it.landed & (1 << k)) == 0:
				_land(S, k)
		it.left = 0
		it.t += 1
		_stand(S)
		SimFx.clockStart(S, "skip")
		return true
	for k in range(S.fighters.size()):
		var f = S.fighters[k]
		if (it.landed & (1 << k)) != 0:
			continue
		var g: float = WorldTerrain.groundY(S, f.x)
		if t == fall[k]:
			SimFx.entranceFall(S, f, g, g + fallHeight, float(land[k] - fall[k]) / float(TPS))
		if t >= land[k]:
			_land(S, k)
		elif t >= fall[k]:
			var p: float = float(t - fall[k] + 1) / float(land[k] - fall[k])
			f.y = g + fallHeight * (1.0 - p * p)   # he accelerates down: a closed-form fall, no flight physics
	if t == staredown:
		SimFx.staredownStart(S, float(clock - staredown) / float(TPS))
	it.t += 1
	it.left -= 1
	if it.left == 0:
		_stand(S)
		SimFx.clockStart(S, "full")
	return true


## Slot k touches down: he is on the ground and the entrance crater is dug under him (World's dig; the start spots are
## open ground, clear of every town, so nobody is hurt).
static func _land(S: SimState, k: int) -> void:
	var f = S.fighters[k]
	var top: float = WorldTerrain.groundY(S, f.x) + fallHeight
	var r: float = 0.0
	if craterE > 0.0:
		var rec = WorldCrater.dig(S, f.x, craterE, f, "impact", 0.0, 1.0)
		if rec != null:
			r = rec.r
	f.y = WorldTerrain.groundY(S, f.x)
	S.intro.landed |= 1 << k
	SimFx.entranceLand(S, f, top, r)


## The clock starts: both fighters are free, standing where they landed.
static func _stand(S: SimState) -> void:
	for f in S.fighters:
		f.state = "free"
		f.vx = 0.0
		f.vy = 0.0
		f.y = WorldTerrain.groundY(S, f.x)


static func _pressed(S: SimState, inputs) -> bool:
	if inputs == null:
		return false
	for k in range(mini(inputs.size(), S.fighters.size())):
		var i = inputs[k]
		if i == null or S.fighters[k].ai != null:
			continue
		if i.light or i.heavy or i.sig or i.guardPress or i.dodge or i.powerPress or i.transform or i.context or i.dash:
			return true
	return false
