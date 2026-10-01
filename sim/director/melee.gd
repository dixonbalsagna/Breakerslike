class_name DirMelee
## Melee exchanges: the twin of melee.js (planMelee and its beat ops, clashWave, strike, launchBeat). The schedule
## calls keep melee.js's order exactly: beats with equal t run in scheduling order.


static func _strike(ex, t: float, a: String, d: String, dmg: float, o = null) -> void:
	DirExchange.schedule(ex, t, "strike", {"a": a, "d": d, "dmg": dmg, "o": o})


static func _launch(ex, t: float, force: float, who: String = "") -> void:
	DirExchange.schedule(ex, t, "launch", {"force": force, "rev": who == "D"})


## Plans a melee exchange from Combat's data (DirData, data/combat/templates.json).
static func planMelee(S: SimState, ex) -> String:
	return DirData.planMelee(S, ex)


## Beat "wind": the parry window opens; an AI defender may time a parry press.
static func opWind(S: SimState, ex, _args) -> void:
	var D = ex.D
	# The window is real only if a parryable strike by the attacker follows; its length is the time until that strike.
	var width: float = -1.0
	for b in ex.beats:
		# Step 2b: with strike classes, only the attacker's first strike after the wind beat can be parried.
		if not b.done and b.op == "strike" and b.args.a == "A" and (b.args.o == null or not b.args.o.get("noParry", false)):
			width = b.t - ex.t
			break
		if not b.done and b.op == "strike" and b.args.a == "A" and b.args.o != null and b.args.o.has("class"):
			break
	if DirData.ticked():
		# Controls' rule: no window without a cue. windowStart and the AI's press draw exist only with a window_open.
		if width < 0.0:
			return
		ex.windowStart = S.T
		# S3b stage penalty: a battered head narrows the parry window by 20% (its early part stops counting).
		if SimWounds.battered(D, SimWounds.HEAD):
			ex.windowStart = S.T + SimWounds.HEAD_PARRY_NARROW * width
	else:
		ex.windowStart = S.T
	if width >= 0.0:
		SimFx.windowOpen(S, D, "parry", width)
		SimFx.danger(S, D, "windup", width)
	# The stance is the exchange's snapshot (R8): a v2 slot's live stance follows its held states, and a dodge lapses mid-exchange.
	if D.ai != null and S.rng.next() < (0.5 if ex.sD == 1.0 else (0.3 if ex.sD == 0.0 else 0.12)):
		var pd: Array = DirData.aiParryDelay()
		DirExchange.schedule(ex, ex.t + S.rng.range_(float(pd[0]), float(pd[1])), "press", {"who": "D"})


## Beat "slip": the escaping defender breaks away from the pursuit.
static func opSlip(S: SimState, ex, _args) -> void:
	var A = ex.A
	var D = ex.D
	SimFx.afterimage(S, D)
	D.state = "free"
	D.vx = SimMathx.jsign(SimWrap.sdx(A.x, D.x)) * (1500.0 + D.tier * 200.0)
	D.vy = S.rng.range_(-150.0, 300.0)
	SimFx.banner(S, "SLIPPED AWAY", "#9fe0b0", 0.8)
	A.ki = SimMathx.jmax(0.0, A.ki - 3.0)


## Beat "dodge": the evasive defender blinks behind the attacker.
static func opDodge(S: SimState, ex, _args) -> void:
	var A = ex.A
	var D = ex.D
	SimFx.afterimage(S, D)
	D.x = SimWrap.wrap(A.x - A.face * 74.0)
	D.y = SimMathx.jmax(WorldTerrain.groundY(S, D.x), A.y + S.rng.range_(-30.0, 70.0))
	D.vx = 0.0
	D.vy = 0.0
	SimFx.ring(S, D.x, D.y + 34.0, 500.0, "#9fe0ff", 0.3, 8.0)


## Beat "guardBreak": the defensive guard shatters.
static func opGuardBreak(S: SimState, ex, _args) -> void:
	var D = ex.D
	if ex.cancel:
		return
	D.ki = SimMathx.jmax(0.0, D.ki - 25.0)
	SimFx.banner(S, "GUARD BREAK", "#ffd45a", 0.8)
	SimFx.shake(S, 12.0, D.x)


static func clashWave(S: SimState, ex) -> void:
	var A = ex.A
	var D = ex.D
	SimFx.clashDraw(S, A, D)
	var mx: float = SimWrap.wrap(A.x + SimWrap.sdx(A.x, D.x) / 2.0)
	var my: float = (A.y + D.y) / 2.0 + 34.0
	SimFx.ring(S, mx, my, 1400.0, "#ffffff", 0.6, 20.0)
	SimFx.ring(S, mx, my, 800.0, "#ffd45a", 0.8, 10.0)
	SimFx.spark(S, mx, my, 30, "#fff3c0", 900.0)
	A.vx = -A.face * 900.0
	D.vx = A.face * 900.0
	SimDamage.hit(S, ex, A, D, 18.0, {"ignoreStance": true, "stop": 0.1})
	SimDamage.hit(S, ex, D, A, 18.0, {"ignoreStance": true, "stop": 0.02})
	var tier: float = SimMathx.jmax(A.tier, D.tier)
	if my < WorldTerrain.groundY(S, mx) + 200.0 * SimConst.WS:
		WorldCrater.dig(S, mx, WorldCrater.clashEnergy(tier), A, "impact")
	WorldStructures.damageArea(S, mx, my, (160.0 + tier * 40.0) * SimConst.WS, 110.0 + tier * 80.0, A)
	SimFx.banner(S, "CLASH", "#ffffff", 0.7)
	SimFx.shake(S, 18.0, mx)


const BREAK_LAUNCH_AT: float = 0.1   # the break launch follows the breaking strike after this
const BREAK_FORCE: float = 2400.0    # ... with this template force (the planner scales long hauls)


static func strike(S: SimState, ex, a, d, dmg: float, o = null) -> void:
	if o == null:
		o = {}
	if ex.cancel or S.game.ko != null:
		return
	a.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(a.x, d.x)), a.face)
	var pb: Dictionary = DirData.parryBlock()
	var early: float = float(pb.bufferTicks) / DirData.TICKS_PER_SEC if not pb.is_empty() else 0.0
	var armed: bool = ex.windowStart >= 0.0
	var winStart: float = ex.windowStart
	if a == ex.A and o.has("class"):
		ex.windowStart = -1.0   # step 2b: the window serves the attacker's first strike after a wind beat, and no later one
	if a == ex.A and not o.get("noParry", false) and armed and d.lastAtkT >= winStart - early:
		ex.cancel = true
		ex.loser = S.fighters.find(a)
		if pb.is_empty():
			# parity: the code's reward
			SimDamage.hit(S, ex, d, a, 18.0, {"ignoreStance": true, "stop": 0.12, "shake": 9.0})
			a.vx = -a.face * 520.0
			d.ki = SimMathx.jmin(100.0, d.ki + 8.0)
		else:
			# spaced: Controls' widths and Combat's rewards; a press in the last clean ticks before the strike is a clean parry
			var cleanT: float = float(pb.cleanTicks["heavy" if ex.kind == "heavy" else "light"]) / DirData.TICKS_PER_SEC
			var rw: Dictionary = pb.cleanReward if d.lastAtkT >= S.T - cleanT else pb.reward
			SimDamage.hit(S, ex, d, a, float(rw.damage), {"ignoreStance": true, "stop": float(rw.stopTicks) / DirData.TICKS_PER_SEC, "shake": 9.0})
			a.vx = -a.face * float(rw.pushback)
			d.ki = SimMathx.jmin(100.0, d.ki + float(rw.ki))
			SimFx.cue(S, d, String(rw.cue), "", "")
		SimFx.ring(S, a.x + a.face * 30.0, a.y + 34.0, 700.0, "#9fe0ff", 0.4, 10.0)
		SimFx.banner(S, "PARRY", "#9fe0ff", 0.8)
		SimEvents.feed(S, d.name + " PARRIES", "Timed the wind-up. Rest of the exchange cancelled.")
		SimFx.parry(S, d, a)
		return
	if d.state == "launched" or d.state == "down":
		d.state = "locked"
		d.vx *= 0.1
		d.vy *= 0.1
	var brokenBefore: int = _broken(d)
	SimDamage.hit(S, ex, a, d, dmg, o)
	d.vx += a.face * SimDamage.jor(o.get("kb", 0.0), 220.0)
	if _broken(d) > brokenBefore and not DirExchange.finisherPlanned(ex):
		_breakChapter(S, ex, a, d)


## Regions of f at the broken stage.
static func _broken(f) -> int:
	var n: int = 0
	for st in f.stage:
		if st == 3:
			n += 1
	return n


## Breaks are chapters (spec-wounds.md §1): the strike that breaks a region ends the exchange with a break launch, long
## by rule (the planner's long-haul candidates only). The exchange's own pending launches and chain window are dropped.
static func _breakChapter(S: SimState, ex, a, d) -> void:
	for b in ex.beats:
		if not b.done and (b.op == "launch" or b.op == "window"):
			b.done = true
	ex.ext = null
	DirExchange.schedule(ex, ex.t + BREAK_LAUNCH_AT, "breakLaunch", {"w": "A" if a == ex.A else "D", "force": BREAK_FORCE})


## longOnly: a break or finisher launch, chosen among the long-haul candidates only (no "no launch").
static func launchBeat(S: SimState, ex, att, tgt, force: float, longOnly: bool = false) -> void:
	if ex.cancel or S.game.ko != null:
		return
	var r: Dictionary = DirLaunch.chooseLaunch(S, att, tgt, force, longOnly)
	var parts: PackedStringArray = []
	for k in r.top:
		parts.append(k.name + " " + SimMathx.jstr(SimMathx.jround(k.s)))
	var all: PackedStringArray = []
	for k in r.all:
		all.append(k.name + ("#" + str(k.brunt.b) if k.has("brunt") else "") + " " + SimMathx.jstr(SimMathx.jround(k.s)))   # B2: which building
	SimFx.launchPlan(S, att, tgt, "|".join(all), r.best.name)
	if r.best.name == "NONE":
		# Nothing scored above holding back: the strike shoves the target instead of launching it.
		DirLaunch.knockBack(S, att, tgt)
		SimEvents.feed(S, "NO LAUNCH", "  |  ".join(parts))
		# A shove is decisive only when the exchange meets another clause: a heavy clash won, a GUARD BREAK, or a
		# CHARGE INTERRUPT (it stops a fill).
		if ex.tag.begins_with("HEAVY CLASH") or ex.tag == "GUARD BREAK" or ex.tag == "CHARGE INTERRUPT":
			DirExchange.decisive(S, ex, att, tgt, "clash" if ex.tag.begins_with("HEAVY CLASH") else ("guard_break" if ex.tag == "GUARD BREAK" else "interrupt"))
		return
	DirLaunch.doLaunch(S, att, tgt, r.best, force, longOnly)
	if r.best.has("p") and r.best.p.get("building", false):
		SimFx.hazardTelegraph(S, tgt, "brunt", r.best.p.t, r.best.p.x)
	S.dirS.lastLaunch2 = S.dirS.lastLaunch
	S.dirS.lastLaunch = r.best.name
	SimEvents.feed(S, "LAUNCH: " + r.best.name, "  |  ".join(parts))
	DirExchange.decisive(S, ex, att, tgt, "launch")
