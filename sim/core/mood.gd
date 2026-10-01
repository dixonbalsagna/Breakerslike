class_name SimMood
## M1: the fight's mood, the invisible acts and each fighter's play style, as sim state (docs/architecture/mood-style.md;
## Game Design's numbers, spec-wounds.md §9; Narrative's labels, docs/narrative/style-thresholds.md). All state is
## integer (S.mood, f.style) and hashed. It reads this tick's events and a few state values and writes only its own
## state and its events (mood_band, act_change, style_label, crowd_state), so no other code changes behaviour until
## something reads its outputs: S.mood.aggression (the director's scale, Encounter's Q4) and S.mood.crowd (World).
## The act is counted here and nowhere else: act() = min(max, 1 + beats). wounds.gd reports every stage change through
## onStage(), and mood.json's actBeats decide which are beats (M1b: every region break and transformation; the first limb
## battered, the first core bruised and the first core battered, once per match each).
## Numbers are data: data/fight/mood.json (fight.mood/1) and data/fight/style.json (fight.style/1), loaded once per
## process and folded into the replay header's data hash.

const MOOD_PATH: String = "res://data/fight/mood.json"
const STYLE_PATH: String = "res://data/fight/style.json"
const BANDS: Array = ["calm", "tense", "frenzied"]
const LABELS: Array = ["turtle", "rusher", "runner", "charger", "sniper", "mixer"]   # label index -> name
const CAUSES: Array = ["regionBreak", "form", "limbBattered", "coreBruised", "coreBattered"]   # act beats (act_change kind)
const ONCE: Array = ["limbBattered", "coreBruised", "coreBattered"]                       # S.mood.onceMask bits
## Style measures, by index into the per-second counters.
const M_S0: int = 0          # ticks in AGGRESSIVE ... M_S0 + 3: ESCAPE
const M_LIGHT: int = 4       # exchanges started, by weight at the start
const M_HEAVY: int = 5
const M_SIG: int = 6
const M_CLOSING: int = 7     # ticks spent closing on the opponent
const M_OPENED: int = 8      # units of distance opened
const M_CHARGE: int = 9      # ticks charging
const M_CUT: int = 10        # charges interrupted
const M: int = 11
## The measure's dead zone: moving along x toward (or away from) the opponent faster than this counts as closing (or
## opening). A definition of the measure, not a tuning number.
const CLOSE_DEAD: float = 50.0
## The measure strings of style.json, as closed keys: [part measures], whole ("stance" for stance time, "attacks").
const MEASURES: Dictionary = {
	"stance1 / stanceTotal": [[1], "stance"],
	"stance0 / stanceTotal": [[0], "stance"],
	"(stance2 + stance3) / stanceTotal": [[2, 3], "stance"],
	"charge / stanceTotal": [[M_CHARGE], "stance"],
	"sig / (light + heavy + sig)": [[M_SIG], "attacks"],
}
const NO_TIME: int = -100000   # "never" for the leftAt and shiftAt seconds

static var _loaded: bool = false
static var _hash: String = ""
static var _errors: Array = []
static var mood: Dictionary = {}    # parsed mood.json
static var imp: Dictionary = {}     # impulse name -> [plain units, AGGRESSIVE units]
static var defs: Array = []         # per LABELS index: the label's numbers
static var priority: Array = []     # label indices, first wins
static var beatsEvery: Array = []
static var beatsOnce: Array = []
static var formSteps: bool = false   # Q10 (actBeats.formSteps): the act takes the larger of the form track and the wound track
static var windowS: int = 60
static var minFill: int = 30
static var minHeld: int = 0
static var minGap: int = 20
static var refractory: int = 10


# ---------------------------------------------------------------- data

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_errors = []
	var mt: String = FileAccess.get_file_as_string(MOOD_PATH)
	var stt: String = FileAccess.get_file_as_string(STYLE_PATH)
	var h := SimHash.Hasher.new()
	var mj = JSON.parse_string(mt)
	var sj = JSON.parse_string(stt)
	if not (mj is Dictionary and sj is Dictionary):
		_err("data/fight/mood.json or style.json is missing or not valid JSON")
		mj = {}
		sj = {}
	h.text("mood")
	FighterData._canon(h, mj)
	h.text("style")
	FighterData._canon(h, sj)
	_hash = h.hex()
	_loadMood(mj)
	_loadStyle(sj)


static func dataHash() -> String:
	_ensure()
	return _hash


static func errors() -> Array:
	_ensure()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)
	push_error("SimMood: " + msg)


static func _int(where: String, x) -> int:
	var f: float = float(x) if x != null else 0.0
	if x == null or f != floor(f):
		_err(where + ": must be an integer, got " + str(x))
	return int(f)


static func _loadMood(j: Dictionary) -> void:
	mood = {}
	for k in ["unitPerPoint", "range"]:
		mood[k] = _int("mood." + k, j.get(k))
	var num: int = _int("mood.aggressiveMul.num", j.get("aggressiveMul", {}).get("num"))
	var den: int = _int("mood.aggressiveMul.den", j.get("aggressiveMul", {}).get("den"))
	if den <= 0:
		_err("mood.aggressiveMul.den must be above 0")
		den = 1
	imp = {}
	var ij: Dictionary = j.get("impulses", {})
	for k in ["strike", "heavyStrike", "chainLink", "parry", "clash", "beamLands", "regionBroken", "buildingLaunch", "buildingChain", "form", "finisherStart", "taunt", "landmarkFall"]:
		var u: int = _int("mood.impulses." + k, ij.get(k))
		imp[k] = [u, int(floor(float(u * num) / float(den)))]
	for k in ij:
		if not String(k).begins_with("_") and not imp.has(k):
			_err("mood.impulses." + k + " is not wired")
	var c: Dictionary = j.get("casualty", {})
	for k in ["perPerson", "capPerTick", "popRef"]:
		mood["cas_" + k] = _int("mood.casualty." + k, c.get(k))
	var r: Dictionary = j.get("rates", {})
	for k in ["bothAggressive", "decay", "bothGuarded"]:
		mood[k] = _int("mood.rates." + k, r.get(k))
	var pr: Dictionary = r.get("proportional", {})
	mood.propOn = pr.get("on", false) == true
	mood.propBase = _int("mood.rates.proportional.base", pr.get("base", 0))
	mood.propPerMille = _int("mood.rates.proportional.perMille", pr.get("perMille", 0))
	var ab: Dictionary = j.get("actBeats", {})
	beatsEvery = []
	beatsOnce = []
	for k in ab.get("every", []):
		if k in ["regionBreak", "form"]:
			beatsEvery.append(k)
		else:
			_err("mood.actBeats.every: unknown beat " + str(k))
	for k in ab.get("oncePerMatch", []):
		if ONCE.has(k):
			beatsOnce.append(k)
		else:
			_err("mood.actBeats.oncePerMatch: unknown beat " + str(k))
	formSteps = ab.get("formSteps", null) == true
	if not (ab.get("formSteps", null) is bool):
		_err("mood.actBeats.formSteps must be true or false")
	if formSteps and beatsEvery.has("form"):
		_err("mood.actBeats: with formSteps the form track counts the transformations, so every must not list form")
	var am: int = _int("mood.act.max", j.get("act", {}).get("max"))
	mood.actMax = am
	var fl = j.get("actFloors", [])
	if not (fl is Array and fl.size() == am):
		_err("mood.actFloors needs one floor per act (act.max)")
		fl = [0, 0, 0, 0]
	mood.floors = fl.map(func(x): return _int("mood.actFloors", x))
	var b: Dictionary = j.get("bands", {})
	for k in ["tense", "frenzied", "dwellTicks"]:
		mood["band_" + k] = _int("mood.bands." + k, b.get(k))
	if not (0 < mood.band_tense and mood.band_tense < mood.band_frenzied and mood.band_frenzied < mood.range):
		_err("mood.bands: 0 < tense < frenzied < range")
	var ag: Dictionary = j.get("aggression", {})
	for k in ["base", "perAct", "max"]:
		mood["agg_" + k] = _int("mood.aggression." + k, ag.get(k))
	var bb = ag.get("bandBonus", [])
	if not (bb is Array and bb.size() == 3):
		_err("mood.aggression.bandBonus needs three values (calm, tense, frenzied)")
		bb = [0, 0, 0]
	mood.bandBonus = bb.map(func(x): return _int("mood.aggression.bandBonus", x))
	var cr = j.get("crowd", [])
	if not (cr is Array and cr.size() == 3):
		_err("mood.crowd needs three names (calm, tense, frenzied)")
		cr = ["excited", "nervous", "fleeing"]
	mood.crowd = cr


static func _loadStyle(j: Dictionary) -> void:
	windowS = _int("style.windowS", j.get("windowS"))
	if windowS != 60 or _int("style.evalHz", j.get("evalHz")) != 1:
		_err("style: the code runs a 60 s window at 1 Hz")
		windowS = 60
	minFill = _int("style.minWindowFillS", j.get("minWindowFillS"))
	minHeld = _int("style.minHeldS", j.get("minHeldS"))
	var sh: Dictionary = j.get("shift", {})
	minGap = _int("style.shift.minGapS", sh.get("minGapS"))
	refractory = _int("style.shift.refractoryAfterLeaveS", sh.get("refractoryAfterLeaveS"))
	if sh.get("startUnlabelled", true) != true:
		_err("style.shift.startUnlabelled: the code starts unlabelled")
	var lj: Dictionary = j.get("labels", {})
	defs = []
	for name in LABELS:
		var d: Dictionary = lj.get(name, {})
		var where: String = "style.labels." + name
		var def := {"enterHold": _int(where + ".enterHoldS", d.get("enterHoldS")), "leaveHold": _int(where + ".leaveHoldS", d.get("leaveHoldS")),
			"minAttacks": int(d.get("minAttacksInWindow", 0))}
		if name == "mixer":
			for k in ["maxStancePct", "minStancesUsed", "stanceUsedPct", "maxAttackKindPct", "leaveMaxStancePct"]:
				def[k] = _int(where + "." + k, d.get(k))
		else:
			var ms: String = String(d.get("measure", ""))
			if not MEASURES.has(ms):
				_err(where + ".measure '" + ms + "' is not one the code implements")
				ms = "stance0 / stanceTotal"
			def.measure = MEASURES[ms]
			def.enterPct = _int(where + ".enterPct", d.get("enterPct"))
			def.leavePct = _int(where + ".leavePct", d.get("leavePct"))
		defs.append(def)
	for name in lj:
		if not String(name).begins_with("_") and not LABELS.has(name):
			_err("style.labels." + name + " is not a label the code implements")
	priority = []
	for name in j.get("priority", []):
		if LABELS.has(name):
			priority.append(LABELS.find(name))
		else:
			_err("style.priority: unknown label " + str(name))
	if priority.size() != LABELS.size():
		_err("style.priority must list every label once")


# ---------------------------------------------------------------- state

## A new match (sim.gd newMatch, after the fighters exist).
static func reset(S: SimState) -> void:
	_ensure()
	S.mood = SimState.MoodState.new()
	S.mood.aggression = mood.agg_base
	for f in S.fighters:
		f.style = newStyle()


static func newStyle() -> SimState.StyleState:
	var st := SimState.StyleState.new()
	st.cur = _zeros(M)
	st.buckets = _zeros(60 * M)
	st.win = _zeros(M)
	st.total = _zeros(M)
	st.enterT = _zeros(LABELS.size())
	st.leftAt = []
	for i in range(LABELS.size()):
		st.leftAt.append(NO_TIME)
	st.shiftAt = NO_TIME
	return st


static func _zeros(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(0)
	return a


## The act (1 to act.max): 1 + beats. The one source of truth for acts (wounds.gd's damping and crippling read it).
static func act(S: SimState) -> int:
	_ensure()
	if not formSteps:
		return mini(mood.actMax, 1 + S.mood.beats)
	# Q10 (spec-wounds.md section 8b): 1 + the larger of (form steps, wound beats) + region breaks. Form steps are the
	# most ladder steps any one fighter has taken; wound beats are the once-per-match beats reached so far.
	var steps: int = 0
	for f in S.fighters:
		steps = maxi(steps, int(f.tier) - 1)
	var wounds: int = 0
	for b in range(ONCE.size()):
		if (S.mood.onceMask & (1 << b)) != 0:
			wounds += 1
	return mini(mood.actMax, 1 + maxi(steps, wounds) + S.mood.breaks)


## Q10: a fighter took a form step (SimFighter.tierUp). The step itself is read from the tiers (act()); this names the
## cause for act_change.
static func onForm(S: SimState) -> void:
	_ensure()
	if formSteps:
		S.mood.cause = CAUSES.find("form")


## wounds.gd reports each stage change of f's region r (from prev to st). The data decide the beats: a region break
## ("every"), and the first limb (arms or legs) battered, the first core bruised and the first core battered, once per
## match each whichever fighter reaches it ("oncePerMatch").
static func onStage(S: SimState, f, r: int, st: int, prev: int) -> void:
	_ensure()
	if st == 3 and beatsEvery.has("regionBreak"):
		beat(S, "regionBreak")
	if st > prev:
		if (r == SimWounds.ARMS or r == SimWounds.LEGS) and st >= 2:
			_once(S, "limbBattered")
		if r == SimWounds.CORE and st >= 1:
			_once(S, "coreBruised")
		if r == SimWounds.CORE and st >= 2:
			_once(S, "coreBattered")


static func _once(S: SimState, name: String) -> void:
	var bit: int = 1 << ONCE.find(name)
	if beatsOnce.has(name) and (S.mood.onceMask & bit) == 0:
		S.mood.onceMask |= bit
		beat(S, name)


## An act beat (cause: a CAUSES name). A transformation (F1) calls beat(S, "form") when actBeats.every lists it.
static func beat(S: SimState, cause: String) -> void:
	if cause == "form" and not beatsEvery.has("form"):
		return
	S.mood.beats += 1
	if cause == "regionBreak":
		S.mood.breaks += 1
	S.mood.cause = CAUSES.find(cause)


# ---------------------------------------------------------------- the tick

## Once per non-frozen tick, at the end of SimCore.step (after the director, the beams and the water): impulses from this
## tick's events, the rates, the band and its dwell, the act, the outputs, the style counters; every 60 ticks the style
## window rotates and the labels are evaluated.
static func tick(S: SimState) -> void:
	_ensure()
	var m = S.mood
	var fs: Array = S.fighters
	m.t += 1
	var add: int = 0
	# Only this tick's events: the list is the host's to drain, and the mood must not depend on whether it has (a replay
	# played back without draining read every earlier event again). Events are in tick order, so they are the list's tail.
	var fx: Array = S.out.fx
	var i0: int = fx.size()
	while i0 > 0 and fx[i0 - 1].tick == S.tick:
		i0 -= 1
	for k in range(i0, fx.size()):
		var e = fx[k]
		match e.type:
			"damage":
				if e.number and (e.kind == "light" or e.kind == "heavy"):
					add += _imp(fs, "heavyStrike" if e.kind == "heavy" else "strike", int(e.attacker))
			"parry":
				add += _imp(fs, "parry", int(e.actor))
			"clash_draw":
				add += _imp(fs, "clash", int(e.actor))
			"decisive":
				if e.kind == "clash" or e.kind == "beam_clash":
					add += _imp(fs, "clash", int(e.winner))
				elif e.kind == "beam":
					add += _imp(fs, "beamLands", int(e.winner))
					fs[int(e.winner)].style.sigLanded += 1
			"region_broken":
				add += _imp(fs, "regionBroken", -1)
			"building_hit":
				add += _imp(fs, "buildingLaunch" if int(e.n) <= 1 else "buildingChain", -1)
			"building_fall":
				# A landmark falling (Game Design): dormant until World's D1 emits building_fall with landmark true. A building
				# falls once, so this is once per landmark.
				if e.get("landmark") == true:
					add += _imp(fs, "landmarkFall", -1)
			"finisher_start":
				add += _imp(fs, "finisherStart", int(e.actor))
			"attack":
				_countAttack(fs, e)
	var ex = S.dirS.ex
	var combo: int = int(ex.combo) if ex != null else 0
	if combo > m.lastCombo and m.lastCombo >= 1:
		add += _imp(fs, "chainLink", fs.find(ex.A))
	m.lastCombo = combo
	if S.world != null and S.world.pop0 > 0.0:
		var target: int = int(floor(float(mood.cas_perPerson) * float(mood.cas_popRef) * S.world.casualties / S.world.pop0))
		if target > m.casGiven:
			add += mini(mood.cas_capPerTick, target - m.casGiven)
			m.casGiven = target
	# the value: impulses, then the rates toward the act's floor
	var a: int = act(S)
	var fl: int = mood.floors[a - 1]
	var v: int = m.v + add
	if fs[0].stance == 0.0 and fs[1].stance == 0.0:
		v += mood.bothAggressive
	if v > fl:
		var dec: int = mood.decay
		if mood.propOn:
			dec = mood.propBase + int(floor(float((v - fl) * mood.propPerMille) / 60000.0))
		v = maxi(fl, v - dec)
	if _guarded(fs[0]) and _guarded(fs[1]) and v > fl:
		v = maxi(fl, v - mood.bothGuarded)
	m.v = clampi(v, 0, mood.range)
	# the band, after its dwell
	var nb: int = 0 if m.v < mood.band_tense else (1 if m.v <= mood.band_frenzied else 2)
	if nb == m.band:
		m.cand = nb
		m.candT = 0
	else:
		if nb == m.cand:
			m.candT += 1
		else:
			m.cand = nb
			m.candT = 1
		if m.candT >= mood.band_dwellTicks:
			m.band = nb
			m.candT = 0
			SimFx.moodBand(S, BANDS[nb], float(m.v) / float(mood.unitPerPoint), a)
	if a > m.act:
		m.act = a
		SimFx.actChange(S, a, CAUSES[m.cause])
	m.aggression = mini(mood.agg_max, mood.agg_base + mood.agg_perAct * (m.act - 1) + mood.bandBonus[m.band])
	if m.band != m.crowd:
		m.crowd = m.band
		SimFx.crowdState(S, mood.crowd[m.crowd])
	# style counters
	for k in range(fs.size()):
		var f = fs[k]
		var o = fs[1 - k]
		var st = f.style
		st.cur[int(f.stance)] += 1
		var vt: float = f.vx * SimMathx.jsign(SimWrap.sdx(f.x, o.x))
		if vt > CLOSE_DEAD:
			st.cur[M_CLOSING] += 1
		elif vt < -CLOSE_DEAD:
			st.cur[M_OPENED] += int(SimMathx.jround(-vt * S.dt))
		if f.state == "charging":
			st.cur[M_CHARGE] += 1
	if m.t % 60 == 0:
		m.sec += 1
		for f in fs:
			_rotate(f.style)
			_labels(S, f)


static func _imp(fs: Array, name: String, slot: int) -> int:
	return imp[name][1] if slot >= 0 and fs[slot].stance == 0.0 else imp[name][0]


static func _guarded(f) -> bool:
	return f.stance == 1.0 or f.stance == 3.0


## An attack event: the exchange the actor's director started, by its weight at the start; a charge it cut; the run of the
## same kind.
static func _countAttack(fs: Array, e) -> void:
	var st = fs[int(e.actor)].style
	var kind: int = M_SIG if e.kind == "sig" else (M_HEAVY if e.kind == "heavy" else M_LIGHT)
	st.cur[kind] += 1
	if kind == st.runKind:
		st.runLen += 1
	else:
		st.runKind = kind
		st.runLen = 1
	st.runMax = maxi(st.runMax, st.runLen)
	if e.defStance == "CHARGING" and int(e.target) >= 0:
		fs[int(e.target)].style.cur[M_CUT] += 1


## The second's counters into the window: add the new bucket, subtract the one leaving; match totals.
static func _rotate(st) -> void:
	var b: int = st.bi * M
	for q in range(M):
		st.win[q] += st.cur[q] - st.buckets[b + q]
		st.buckets[b + q] = st.cur[q]
		st.total[q] += st.cur[q]
		st.cur[q] = 0
	st.bi = (st.bi + 1) % 60
	st.filled = mini(60, st.filled + 1)


## The labels, once a second (style-thresholds.md): enter and leave conditions on the window by cross-multiplication,
## their holds, the refractory time after a label ends, the minimum gap before a shift (counted from the last label to
## begin, so a label that has just entered is not replaced a second later: a stable signal), and the priority order. One
## label at a time; a label ready to enter replaces the current one only if it comes earlier in the priority (any label
## replaces the mixer).
static func _labels(S: SimState, f) -> void:
	var st = f.style
	if st.filled < minFill:
		return
	var sec: int = S.mood.sec
	for li in range(LABELS.size()):
		st.enterT[li] = st.enterT[li] + 1 if _enters(st, li) else 0
	if st.label >= 0:
		st.leaveT = st.leaveT + 1 if _leaves(st, st.label) else 0
		if st.leaveT >= defs[st.label].leaveHold and sec - st.shiftAt >= minHeld:
			var gone: int = st.label
			st.leftAt[gone] = sec
			st.label = -1
			st.leaveT = 0
			SimFx.styleLabel(S, f, "", LABELS[gone])
	var cand: int = -1
	for li in priority:
		if li == st.label:
			if LABELS[li] == "mixer":
				continue
			break
		if st.enterT[li] >= defs[li].enterHold and sec - st.leftAt[li] >= refractory:
			cand = li
			break
	if cand < 0:
		return
	if st.label < 0:
		st.label = cand
		st.leaveT = 0
		st.shiftAt = sec
		SimFx.styleLabel(S, f, LABELS[cand], "")
	elif sec - st.shiftAt >= minGap:
		var prev: int = st.label
		st.leftAt[prev] = sec
		st.label = cand
		st.leaveT = 0
		st.shiftAt = sec
		SimFx.styleLabel(S, f, LABELS[cand], LABELS[prev])


static func _stanceTotal(st) -> int:
	return st.win[0] + st.win[1] + st.win[2] + st.win[3]


static func _attacks(st) -> int:
	return st.win[M_LIGHT] + st.win[M_HEAVY] + st.win[M_SIG]


static func _part(st, d: Dictionary) -> Array:
	var p: int = 0
	for q in d.measure[0]:
		p += st.win[q]
	return [p, _stanceTotal(st) if d.measure[1] == "stance" else _attacks(st)]


static func _enters(st, li: int) -> bool:
	var d: Dictionary = defs[li]
	if LABELS[li] == "mixer":
		var tot: int = _stanceTotal(st)
		var att: int = _attacks(st)
		if tot <= 0 or att < d.minAttacks:
			return false
		var used: int = 0
		for q in range(4):
			if 100 * st.win[q] > d.maxStancePct * tot:
				return false
			if 100 * st.win[q] >= d.stanceUsedPct * tot:
				used += 1
		for q in [M_LIGHT, M_HEAVY, M_SIG]:
			if 100 * st.win[q] > d.maxAttackKindPct * att:
				return false
		return used >= d.minStancesUsed
	var pw: Array = _part(st, d)
	if pw[1] <= 0 or (d.minAttacks > 0 and _attacks(st) < d.minAttacks):
		return false
	return 100 * pw[0] > d.enterPct * pw[1]


static func _leaves(st, li: int) -> bool:
	var d: Dictionary = defs[li]
	if LABELS[li] == "mixer":
		var tot: int = _stanceTotal(st)
		for q in range(4):
			if 100 * st.win[q] > d.leaveMaxStancePct * tot:
				return true
		return false
	var pw: Array = _part(st, d)
	if pw[1] <= 0 or (d.minAttacks > 0 and _attacks(st) < d.minAttacks):
		return true
	return 100 * pw[0] < d.leavePct * pw[1]
