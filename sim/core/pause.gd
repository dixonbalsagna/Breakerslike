class_name SimPause
## Q10 (docs/architecture/q10-pace-acts-pauses.md; spec-wounds.md section 8b): pausing set pieces. Three things pause the
## fight for both players: a transformation, a world-changing ability and the planet giving way at 11:00. A pause is a run
## of frozen ticks, exactly like a hit-stop tick: SimCore.step consumes no input, S.T does not advance and nothing in the
## sim runs, so the match clock, every cooldown, both fighters and the director all stop. It is a match rule: integer
## ticks, hashed (S.pause), the same for both players and in a replay.
##
## The budget is a bank of ticks: it starts at bank.startS, gains bank.gainSPerMin for each minute of match time and holds
## at most bank.maxS. A set piece is never refused; request() picks its version:
##   full   the slot's first set piece of the kind, the bank covers it, and full.gapS of live time since the last pause
##   short  otherwise, if the bank holds short.lengthS and short.gapS have passed
##   live   otherwise: no pause, nothing spent; the caller plays its uninterruptible live version for live.lengthS
## A step marked "live" in the fighter's ladder (stepKinds) always plays live and leaves the bank and the first-of-kind
## mark alone. The time-cap kind always pauses, for timeCap.lengthS, outside the bank.
## The break: a transformation's tier-up (the burst, the crater, the power and size step, tier_up) lands at the end of
## the version's gather, not on the request tick (moveset-rules.md section 10.8). request() sets the fighter's act.breakIn
## to the gather. On a full or short version the count runs on the pause's own frozen ticks (frozenTick), so the world
## changes inside the pause; on a live version it runs on live ticks (SimFighter.stepFighter).
## The numbers are data/fight/pause.json (seconds there, whole ticks here; the gather is in ticks).

const TRANSFORM: int = 0
const WORLD: int = 1
const TIMECAP: int = 2
const KINDS: Array = ["transform", "world", "timecap"]
const LIVE: int = 0
const SHORT: int = 1
const FULL: int = 2
const VERSIONS: Array = ["live", "short", "full"]
const PATH: String = "res://data/fight/pause.json"
const TPS: int = 60
const TPM: int = 3600           # live ticks in a minute of match time
const LONG_AGO: int = 1000000   # sinceEnd at the start of a match: no pause yet

static var _loaded: bool = false
static var _hash: String = ""
static var _errors: Array = []
static var bankStart: int = 0
static var bankGain: int = 0    # ticks gained per minute of match time
static var bankMax: int = 0
static var fullTicks: int = 0
static var finalTicks: int = 0  # a final-form reveal's full version, at most this
static var fullGap: int = 0
static var shortTicks: int = 0
static var shortGap: int = 0
static var liveTicks: int = 0
static var capTicks: int = 0
static var gather: Array = [0, 0, 0]   # per VERSIONS index: ticks from the request to the break


# ---------------------------------------------------------------- data

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_errors = []
	var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (j is Dictionary):
		_err("data/fight/pause.json is missing or not valid JSON")
		j = {}
	var h := SimHash.Hasher.new()
	h.text("pause")
	FighterData._canon(h, j)
	_hash = h.hex()
	var b: Dictionary = j.get("bank", {})
	bankStart = _ticks("bank.startS", b.get("startS"))
	bankGain = _ticks("bank.gainSPerMin", b.get("gainSPerMin"))
	bankMax = _ticks("bank.maxS", b.get("maxS"))
	var f: Dictionary = j.get("full", {})
	fullTicks = _ticks("full.lengthS", f.get("lengthS"))
	finalTicks = _ticks("full.finalLengthS", f.get("finalLengthS"))
	fullGap = _ticks("full.gapS", f.get("gapS"))
	var s: Dictionary = j.get("short", {})
	shortTicks = _ticks("short.lengthS", s.get("lengthS"))
	shortGap = _ticks("short.gapS", s.get("gapS"))
	liveTicks = _ticks("live.lengthS", j.get("live", {}).get("lengthS"))
	capTicks = _ticks("timeCap.lengthS", j.get("timeCap", {}).get("lengthS"))
	gather = [0, 0, 0]
	for v in range(VERSIONS.size()):
		var g = j.get(VERSIONS[v], {}).get("gatherTicks")
		var len: int = [liveTicks, shortTicks, fullTicks][v]
		if not (g is float or g is int) or float(g) != floor(float(g)) or float(g) < 0.0 or (int(g) >= len and len > 0):
			_err(VERSIONS[v] + ".gatherTicks: must be a whole number of ticks, at least 0 and under the version's length, got " + str(g))
		else:
			gather[v] = int(g)
	if bankStart > bankMax:
		_err("bank.startS is above bank.maxS")
	if shortTicks > fullTicks or fullTicks > finalTicks:
		_err("the lengths must rise: short, full, final")
	if shortGap > fullGap:
		_err("short.gapS is above full.gapS")


static func dataHash() -> String:
	_ensure()
	return _hash


static func errors() -> Array:
	_ensure()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)
	push_error("SimPause: " + msg)


## Seconds in the data, whole ticks in the sim: a value that is not a whole number of ticks, or is negative, is an error.
static func _ticks(where: String, x) -> int:
	var t: float = (float(x) if x != null else -1.0) * float(TPS)
	var r: float = floor(t + 0.5)
	if x == null or t < 0.0 or absf(t - r) > 1e-6:
		_err(where + ": must be a number of seconds that is a whole number of ticks, got " + str(x))
		return 0
	return int(r)


# ---------------------------------------------------------------- state

## A new match (sim.gd newMatch).
static func reset(S: SimState) -> void:
	_ensure()
	S.pause = SimState.PauseState.new()
	S.pause.bank = bankStart
	S.pause.sinceEnd = LONG_AGO


## A live tick (SimCore.step, when the tick is not frozen): the bank accrues and the time since the last pause counts.
static func liveTick(S: SimState) -> void:
	var p = S.pause
	if p.sinceEnd < LONG_AGO:
		p.sinceEnd += 1
	p.acc += bankGain
	while p.acc >= TPM:
		p.acc -= TPM
		if p.bank < bankMax:
			p.bank += 1


## A paused tick (SimCore.step, before the hit-stop): one tick of the running pause. True while the pause runs.
static func frozenTick(S: SimState) -> bool:
	var p = S.pause
	if p.left <= 0:
		return false
	p.left -= 1
	p.total += 1
	if p.kind == TRANSFORM and p.actor >= 0:   # the break lands inside the pause
		var f = S.fighters[p.actor]
		if f.act.breakIn > 0:
			f.act.breakIn -= 1
			if f.act.breakIn == 0:
				SimFighter.formBreak(S, f)
	if p.left == 0:
		SimFx.pauseEnd(S, KINDS[p.kind])
	return true


## A set piece asks to play (the director, on a live tick). Returns {"version": LIVE, SHORT or FULL, "ticks": its length}
## and, unless the version is live, starts the pause: the frozen ticks begin with the next step. The caller applies the
## gameplay effect itself, on this tick, whatever the version. slot is the fighter's slot (-1 for the time cap); final
## marks a final-form reveal, whose full version may run to full.finalLengthS when the bank covers it.
static func request(S: SimState, kind: int, slot: int, final: bool = false) -> Dictionary:
	_ensure()
	var p = S.pause
	if kind == TIMECAP:
		if capTicks > 0:
			_start(S, kind, slot, FULL, capTicks, 0)
		return {"version": FULL, "ticks": capTicks}
	if kind == TRANSFORM and slot >= 0:
		var f = S.fighters[slot]
		var step: int = int(f.tier) - 1   # the step being taken: called before the tier rises
		if step >= 0 and step < f.ld.stepKinds.size() and f.ld.stepKinds[step] == "live":
			f.act.breakIn = gather[LIVE]
			return {"version": LIVE, "ticks": liveTicks}
	var bit: int = 1 << (maxi(slot, 0) * 4 + kind)
	var first: bool = (p.seen & bit) == 0
	p.seen |= bit
	if first and p.left == 0 and p.bank >= fullTicks and fullTicks > 0 and p.sinceEnd >= fullGap:
		var n: int = mini(finalTicks, p.bank) if final else fullTicks
		_start(S, kind, slot, FULL, n, n)
		_gather(S, kind, slot, FULL)
		return {"version": FULL, "ticks": n}
	if p.left == 0 and p.bank >= shortTicks and shortTicks > 0 and p.sinceEnd >= shortGap:
		_start(S, kind, slot, SHORT, shortTicks, shortTicks)
		_gather(S, kind, slot, SHORT)
		return {"version": SHORT, "ticks": shortTicks}
	_gather(S, kind, slot, LIVE)
	return {"version": LIVE, "ticks": liveTicks}


## A transformation's pending break: the version's gather, counted from this tick.
static func _gather(S: SimState, kind: int, slot: int, version: int) -> void:
	if kind == TRANSFORM and slot >= 0:
		S.fighters[slot].act.breakIn = gather[version]


## The gather of a version by its name, in ticks (the transform event's gather).
static func gatherOf(version: String) -> int:
	_ensure()
	var v: int = VERSIONS.find(version)
	return gather[v] if v >= 0 else 0


static func _start(S: SimState, kind: int, slot: int, version: int, ticks: int, cost: int) -> void:
	var p = S.pause
	p.left += ticks
	p.kind = kind
	p.version = version
	p.actor = slot
	p.bank -= cost
	p.sinceEnd = 0
	p.count += 1
	SimFx.pauseStart(S, KINDS[kind], slot, VERSIONS[version], float(ticks) / float(TPS))
