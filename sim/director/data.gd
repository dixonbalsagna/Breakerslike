class_name DirData
## Combat's exchange templates, chain link, signature and finishers as data (data/combat/templates.json and
## finishers.json; schema docs/combat/data-fields.md section 10; contract docs/combat/s3b-loader-note.md).
## Ops stay in code (DirExchange.runBeat): the data chooses ops, times, args and branches, with the same S.rng draws in
## the same order as the code it replaced. Both files are loaded once per process and are match inputs: dataHash() is
## for the replay header. The profile field in each file picks the timing by name: "parity" reproduces 69c4a2f bit for
## bit; the others ("spaced", "dynamic"; "authored" for finishers) time their beats in ticks.

const TEMPLATES_PATH: String = "res://data/combat/templates.json"
const FINISHERS_PATH: String = "res://data/combat/finishers.json"
const TICKS_PER_SEC: float = 60.0

static var _tpl = null           # parsed templates.json (never written after load)
static var _fin = null           # parsed finishers.json
static var _hash: String = ""
## Tools and tests only: force a profile ("" keeps the files' own profile field).
static var templatesProfile: String = ""
static var finishersProfile: String = ""


static func _ensure() -> void:
	if _tpl != null:
		return
	var tt: String = FileAccess.get_file_as_string(TEMPLATES_PATH)
	var ft: String = FileAccess.get_file_as_string(FINISHERS_PATH)
	_tpl = JSON.parse_string(tt)
	_fin = JSON.parse_string(ft)
	if _tpl == null or _fin == null:
		push_error("DirData: could not parse data/combat/templates.json or finishers.json")
	var h := SimHash.Hasher.new()
	h.text(tt)
	h.text(ft)
	h.text(DirLocation.dataText())   # data/director/location.json (location variety)
	_hash = h.hex()


## Tools only: parse a data file, and swap the parsed data in (returns the previous [templates, finishers]).
static func parseFile(path: String):
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func swap(tpl, fin) -> Array:
	_ensure()
	var old: Array = [_tpl, _fin]
	_tpl = tpl
	_fin = fin
	return old


## The combat data's content hash (templates, finishers and data/director/location.json), for the replay header.
static func dataHash() -> String:
	_ensure()
	return _hash


static func tplProfile() -> String:
	_ensure()
	return templatesProfile if templatesProfile != "" else String(_tpl.profile)


static func finProfile() -> String:
	_ensure()
	return finishersProfile if finishersProfile != "" else String(_fin.profile)


## True when the templates' profile times its beats in ticks (timeUnit "tick"): every profile but parity.
static func ticked() -> bool:
	return String(_prof().get("timeUnit", "")) == "tick"


static func _prof() -> Dictionary:
	return _tpl.profiles[tplProfile()]


## The AI defender's parry-press delay range after the wind beat, from the active profile.
static func aiParryDelay() -> Array:
	return _prof().aiParryPressDelay


# ---------------------------------------------------------------- melee planning

## Plans a light or heavy exchange from the template for (kind, defender state). Returns the branch's "favours".
static func planMelee(S: SimState, ex) -> String:
	_ensure()
	var A = ex.A
	var D = ex.D
	var heavy: bool = ex.kind == "heavy"
	var dist: float = absf(SimWrap.sdx(A.x, D.x))
	var defState: String = "CHARGING" if (D.dPrev != null and D.dPrev == "charging") else DirExchange.STN[int(D.stance)]
	var ctx := {"S": S, "A": A, "D": D, "heavy": heavy, "dist": dist, "base": 66.0 if heavy else 26.0}
	var sp: bool = ticked()
	if sp:
		ctx.c = _approachTicks(dist)
	else:
		var ap: Dictionary = _prof().approach
		ctx.rt = SimMathx.jclamp(dist / float(ap.divisor), float(ap.min), float(ap.max))
	var tp: Dictionary = _template(ex.kind, defState)
	_penalties(ctx, D)
	ctx.tpl = tp
	var bid: String = _select(S, tp.selector, ctx)
	var br: Dictionary = _branch(tp, bid)
	ex.tag = br.tag
	ex.tpl = String(tp.id)   # I2b: the template and branch ids, for the interrupts of step 3
	ex.branch = String(br.id)
	var key: String = tplProfile()
	if tp.has("shared"):
		_scheduleList(ex, tp.shared[key], ctx, 0.0, "")
	_scheduleList(ex, br[key], ctx, 0.0, "")
	return String(br.favours)


static func _template(kind: String, defState: String) -> Dictionary:
	for tp in _tpl.templates:
		if kind in tp.trigger.kinds and tp.trigger.defender == defState:
			return tp
	push_error("DirData: no template for " + kind + " vs " + defState)
	return {}


static func _branch(tp: Dictionary, id: String) -> Dictionary:
	for br in tp.branches:
		if br.id == id:
			return br
	push_error("DirData: no branch " + id + " in " + String(tp.id))
	return {}


## The spaced approach, in ticks (rounded half up): clamp(dist / divisor) up to 'beyond', a pursuit flight past it.
static func _approachTicks(dist: float) -> float:
	var ap: Dictionary = _prof().approach
	var sec: float
	if ap.has("pursuit") and dist > float(ap.pursuit.beyond):
		var pu: Dictionary = ap.pursuit
		sec = SimMathx.jclamp(float(pu.base) + (dist - float(pu.beyond)) / float(pu.per), float(pu.base), float(pu.max))
	else:
		sec = SimMathx.jclamp(dist / float(ap.divisor), float(ap.min), float(ap.max))
	return floor(sec * TICKS_PER_SEC + 0.5)


# ---------------------------------------------------------------- selectors (data-fields.md 10.4)

static func _select(S: SimState, sel: Dictionary, ctx: Dictionary) -> String:
	match String(sel.kind):
		"fixed":
			return sel.branch
		"threshold":
			var r: float = S.rng.next()
			var p: float
			if sel.has("override") and _cond(sel.override["if"], ctx):
				p = float(sel.override.p)
			else:
				p = _linear(sel.p, ctx)
			p = _adjust(p, ctx, _favours(ctx, sel.ifBelow))
			return sel.ifBelow if r < p else sel["else"]
		"gated_threshold":
			if _cond(sel.gate, ctx) and S.rng.next() < _adjust(_num(sel.p, ctx), ctx, "defender"):
				return sel.ifBelow
			return sel["else"]
		"bands":
			var p2: float = _adjust(_linear(sel.p, ctx), ctx, "attacker")
			var r2: float = S.rng.next()
			if r2 < p2 + float(sel.below.offset):
				return sel.below.branch
			if r2 > p2 + float(sel.above.offset):
				return sel.above.branch
			return sel["else"]
		"score_compare":
			var sa: float = _score(S, sel.score, ctx, ctx.A, ctx.D)
			var sd: float = _score(S, sel.score, ctx, ctx.D, ctx.A)
			return sel.ifGreater if sa > sd else sel["else"]
	push_error("DirData: unknown selector " + String(sel.kind))
	return ""


## S3b stage penalties on the defender's rolls (spec-wounds.md §1): a broken head costs HEAD_DEFENCE on every roll, and
## battered legs cost LEGS_SLIP on the escape rolls (pursuit and beam escape).
static func _penalties(ctx: Dictionary, D) -> void:
	ctx.defPen = SimWounds.HEAD_DEFENCE if SimWounds.broken(D, SimWounds.HEAD) else 0.0
	ctx.slipPen = SimWounds.LEGS_SLIP if SimWounds.battered(D, SimWounds.LEGS) else 0.0


## The favours of a branch of the plan's template; the pursuit's slip is the defender's escape.
static func _favours(ctx: Dictionary, bid: String) -> String:
	var tp: Dictionary = ctx.get("tpl", {})
	if tp.get("id", "") == "pursuit" and bid == "slips":
		return "escape"
	for br in tp.get("branches", []):
		if br.id == bid:
			return String(br.favours)
	return "neutral"


## Shifts a probability by the defender's penalties toward the side that gains: down for the defender's own chances
## (escape: also the legs), up for the attacker's (attacker_escape: the beam's HIT against an escape). Unchanged, bit for
## bit, when the defender has no penalty.
static func _adjust(p: float, ctx: Dictionary, fav: String) -> float:
	var pen: float = float(ctx.get("defPen", 0.0))
	if fav == "escape" or fav == "attacker_escape":
		pen = pen + float(ctx.get("slipPen", 0.0))
	if pen == 0.0:
		return p
	match fav:
		"defender", "escape":
			return SimMathx.jclamp(p - pen, 0.0, 1.0)
		"attacker", "attacker_escape":
			return SimMathx.jclamp(p + pen, 0.0, 1.0)
	return p


## The linear probability form: acc = start, then each term left to right, then clamp.
static func _linear(p, ctx: Dictionary) -> float:
	if not (p is Dictionary):
		return float(p)
	var acc: float = float(p.start)
	for tm in p.terms:
		if tm.has("coef"):
			acc = acc + float(tm.coef) * (_name(tm.diff[0], ctx) - _name(tm.diff[1], ctx))
		else:
			acc = acc + (float(tm.then) if _cond(tm["if"], ctx) else float(tm["else"]))
	return SimMathx.jclamp(acc, float(p.clamp[0]), float(p.clamp[1]))


## A score summed left to right (trade blows): f and o are the scored fighter and its opponent.
static func _score(S: SimState, sc: Dictionary, ctx: Dictionary, f, o) -> float:
	var sub := ctx.duplicate()
	sub.f = f
	sub.o = o
	var acc: float = 0.0
	var first: bool = true
	for tm in sc.sum:
		var v: float
		if tm.has("var"):
			v = _name(tm["var"], sub)
		elif tm.has("div"):
			v = _name(tm.div[0], sub) / float(tm.div[1])
		elif tm.has("draw"):
			v = S.rng.range_(float(tm.draw[0]), float(tm.draw[1]))
		else:
			v = float(tm.then) if _cond(tm["if"], sub) else float(tm["else"])
		acc = v if first else acc + v
		first = false
	return acc


static func _cond(c, ctx: Dictionary) -> bool:
	if c.has("all"):
		for x in c.all:
			if not _cond(x, ctx):
				return false
		return true
	if c.has("not"):
		return not _cond(c["not"], ctx)
	if c.has("gt"):
		return _name(c.gt[0], ctx) > _name(c.gt[1], ctx)
	var v = _raw(c["var"], ctx)
	if not c.has("op"):
		return bool(v)
	var x: float = float(v)
	var val: float = float(c.value)
	match String(c.op):
		">":
			return x > val
		"<":
			return x < val
		">=":
			return x >= val
		"==":
			return x == val
	return false


static func _name(n: String, ctx: Dictionary) -> float:
	return float(_raw(n, ctx))


static func _raw(n: String, ctx: Dictionary):
	match n:
		"dist":
			return ctx.dist
		"heavy":
			return ctx.heavy
		"vitality(f)":
			return SimWounds.vitality(ctx.f)
		"vitality(o)":
			return SimWounds.vitality(ctx.o)
	var dot: int = n.find(".")
	var who = ctx[n.substr(0, dot)]
	return who.get(n.substr(dot + 1))


static func _num(v, ctx: Dictionary) -> float:
	return float(v)


# ---------------------------------------------------------------- scheduling

## Schedules a beat list in array order. t0 is the anchor on the exchange clock (0 for a new exchange, ex.t for the
## chain link and a finisher). w is "A" or "D" for finisher roles (W, L), "" otherwise.
static func _scheduleList(ex, beats: Array, ctx: Dictionary, t0: float, w: String) -> void:
	for b in beats:
		if b.has("when") and b.when == "heavy" and not ctx.heavy:
			continue
		DirExchange.schedule(ex, _time(b, ctx, t0), String(b.op), _args(b, ctx, w))


## A beat's time on the exchange clock: t0 plus the data's time (0.0 + x is x exactly, so a new exchange's times equal
## the code's; the chain link and the finisher add their times to ex.t as the code did).
static func _time(b: Dictionary, ctx: Dictionary, t0: float) -> float:
	if b.has("tick"):
		var tk = b.tick
		var ticks: float = _ticks(tk, ctx) if tk is Dictionary else float(tk)
		return t0 + ticks / TICKS_PER_SEC
	return t0 + float(_value(b.t, ctx))


## The spaced tick form: anchor (0, or c x times) + step x tempo.step + the named adds - the named subs.
static func _ticks(tk: Dictionary, ctx: Dictionary = {}) -> float:
	var tempo: Dictionary = _prof().tempo
	var acc: float = 0.0
	if tk.get("at", "start") == "c":
		acc = float(ctx.c) * float(tk.get("times", 1.0))
	if tk.has("step"):
		acc = acc + float(tk.step) * float(tempo.step)
	for n in tk.get("add", []):
		acc = acc + float(tempo[n])
	for n in tk.get("sub", []):
		acc = acc - float(tempo[n])
	return acc


static func _value(v, ctx: Dictionary):
	if v is Dictionary:
		if v.has("ref"):
			var base: float
			match String(v.ref):
				"rt":
					base = ctx.rt
				"c":
					base = ctx.c
				"base":
					base = ctx.base
				"dist":
					base = ctx.dist
			var out: float = base
			if v.has("times"):
				out = base * float(v.times)
			elif v.has("plus"):
				out = base + float(v.plus)
			return out / TICKS_PER_SEC if v.ref == "c" else out
		if v.has("light"):
			return float(v.heavy) if ctx.heavy else float(v.light)
		if v.has("clamp"):
			return SimMathx.jclamp(_value(v.clamp[0], ctx), float(v.clamp[1]), float(v.clamp[2]))
		if v.has("ticks"):
			return float(_prof().tempo[v.ticks]) / TICKS_PER_SEC
		return v
	if v is String and v.begins_with("$"):
		return ctx[v.substr(1)]
	if v is float or v is int:
		return float(v)
	return v


## A beat's args as the code passes them: value forms evaluated, finisher roles W/L mapped to A/D, a strike without
## "o" gets null, and a contest in "ko_now" mode (today's) carries no mode.
static func _args(b: Dictionary, ctx: Dictionary, w: String):
	if not b.has("args"):
		return null
	var a: Dictionary = {}
	for k in b.args:
		var v = b.args[k]
		if k == "o":
			a[k] = v.duplicate(true) if v is Dictionary else v
		elif k == "mode" and b.op == "contest" and v == "ko_now":
			continue
		elif w != "" and v is String and (v == "W" or v == "L"):
			a[k] = w if v == "W" else ("D" if w == "A" else "A")
		elif k == "launch" and v is Dictionary:
			a[k] = v.duplicate(true)
		else:
			a[k] = _value(v, ctx)
	if b.op == "strike" and not a.has("o"):
		a["o"] = null
	return a


# ---------------------------------------------------------------- chain link, signature, finisher

static func planChain(ex) -> void:
	_ensure()
	var cl: Dictionary = _tpl.chainLink
	_scheduleList(ex, cl[tplProfile()], {"heavy": false}, ex.t, "")


## Plans a signature: outcome by the beam rules (their draws), the tag, and the beams' plan beats.
static func planBeam(S: SimState, ex) -> String:
	_ensure()
	var bm: Dictionary = _tpl.beam
	var A = ex.A
	var D = ex.D
	var dist: float = absf(SimWrap.sdx(A.x, D.x))
	var defState: String = "CHARGING" if (D.dPrev != null and D.dPrev == "charging") else DirExchange.STN[int(D.stance)]
	var bio: String = WorldBiomes.biomeAt(D.x)
	var variant: String = bm.variants[bio]
	var ctx := {"S": S, "A": A, "D": D, "heavy": false, "dist": dist}
	_penalties(ctx, D)
	var out: String = "HIT"
	for rule in bm.outcome.rules:
		if rule.defender != defState:
			continue
		if rule.draw == "none":
			if rule.has("if"):
				out = rule.out if _cond(rule["if"], ctx) else rule["else"]
			else:
				out = rule.out
		else:
			var r: float = S.rng.next()
			var p: float = _linear(rule.p, ctx)
			# The defender's penalties: a DODGE is the defender's; the ESCAPE rule's p is the attacker's HIT.
			p = _adjust(p, ctx, "defender" if rule.has("ifBelowAndNot") else "attacker_escape")
			if rule.has("ifBelowAndNot"):
				out = rule.out if (r < p and not _cond(rule.ifBelowAndNot, ctx)) else rule["else"]
			else:
				out = rule.ifBelow if r < p else rule["else"]
		break
	ex.tag = A.sigName + " over " + bio + " (" + variant + ") → " + out
	ex.tpl = String(bm.id)   # I2b: the beam template, and its outcome as the branch
	ex.branch = out
	ctx.out = out
	ctx.variant = variant
	_scheduleList(ex, bm.parity, ctx, 0.0, "")
	return out


## The finisher for winner W (who is ex.A or ex.D): the placeholder in parity, the winner's own (or the generic) in
## authored. Scheduled from ex.t in array order. Returns the finisher Dictionary (for its outcomes and length).
static func planFinisher(ex, W) -> Dictionary:
	_ensure()
	var fin: Dictionary = _finisherFor(W)
	var w: String = "A" if W == ex.A else "D"
	ex.tpl = "finisher"   # I2b: a finisher takes the exchange over; its id is the branch
	ex.branch = String(fin.id)
	_scheduleList(ex, fin.beats, {"heavy": false}, ex.t, w)
	return fin


static func _finisherFor(W) -> Dictionary:
	var want: String = "generic.placeholder"
	if finProfile() != "parity":
		want = _fin.select.byFighter.get(W.id, _fin.select.fallback)   # S4: the stable roster id (the mirror arms rename)
	for f in _fin.finishers:
		if f.id == want:
			return f
	push_error("DirData: no finisher " + want)
	return {}


## The finisher's outcome beats (landed or survived), scheduled from the contest's time t.
static func scheduleOutcome(ex, W, landed: bool) -> void:
	var fin: Dictionary = _finisherFor(W)
	var w: String = "A" if W == ex.A else "D"
	_scheduleList(ex, fin.outcomes["landed" if landed else "survived"], {"heavy": false}, ex.t, w)


## Seconds from a finisher's start to its end: the placeholder's last beat, or an authored finisher's contest plus the
## longer outcome.
static func finisherDur(W) -> float:
	var fin: Dictionary = _finisherFor(W)
	var last: float = 0.0
	for b in fin.beats:
		last = maxf(last, float(b.tick) / TICKS_PER_SEC if b.has("tick") else float(b.t))
	if fin.outcomes is Dictionary and fin.outcomes.get("landed") is Array:
		var tail: float = 0.0
		for key in ["landed", "survived"]:
			for b in fin.outcomes[key]:
				tail = maxf(tail, float(b.tick) / TICKS_PER_SEC)
		last += tail
	return last


## The finisher struggle block (contest.struggle), in the authored profile when the contest takes input; {} otherwise.
static func struggle() -> Dictionary:
	_ensure()
	if finProfile() == "parity" or _fin.contest.get("input") != "struggle":
		return {}
	return _fin.contest.struggle


## The spaced profile's parry block (Controls' widths, Combat's rewards); {} in parity (the code's reward).
static func parryBlock() -> Dictionary:
	_ensure()
	return _prof().get("parry", {})


## The contest settings (Combat's data; Game Design's numbers).
static func contest() -> Dictionary:
	_ensure()
	return _fin.contest


## The time-cap stand-in (finishers.json contest.timeCapAt, seconds; 0 or absent is off): from then on every decisive win
## against a fighter on the brink is a finisher. The full 11:00 event is Game Design's and Simulation's.
static func timeCapAt() -> float:
	return float(contest().get("timeCapAt", 0.0))


## The brink chapter: decisive wins the rival needs against a fighter on the brink before it is open to a finisher
## (finishers.json contest.brinkSetups; spec-wounds.md §1b).
static func brinkSetups() -> int:
	return int(contest().get("brinkSetups", 1))


## W's finisher: its id, and its kind (launch, melee or beam) once Combat's finishers carry one (empty until then).
static func finisherId(W) -> String:
	_ensure()
	return String(_finisherFor(W).get("id", ""))


static func finisherKind(W) -> String:
	_ensure()
	return String(_finisherFor(W).get("kind", ""))
