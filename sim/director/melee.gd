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
	if DirInterrupt.on():
		return   # step 3: the perfect block replaces the parry; the AI presses by DirInterrupt, in the strike's window
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


const DODGE_OFF: float = 74.0         # the blink ends this far behind the attacker (the old profiles; the step-around reads the beat)
const DODGE_PAST: float = 10.0        # the step-around's pass point is this far past the attacker's centre, on the far side
const BODY_H: float = 75.0
const HEIGHT_TOL: float = 17.0        # contact: "the same height" is within this (a quarter of the reach)
const PLACE_FLIGHT_TICKS: float = 2.0  # contact: the placement limit is the block's placementReaches plus this many ticks of the target's flight


## Contact (contact-spacing.md section 5.1): a move's offset from its target is measured on the mover's own side of it,
## along the shortest arc, never from its facing; only side "cross" changes sides. A target in a move of its own is
## read at that move's end, so a re-close during a dodge takes the side the pair will end on. Never inside
## minSeparation. The old profiles (no contact block) keep the facing-based offset.
static func sideOff(mover, tgt, off: float, side: String) -> float:
	var ct: Dictionary = DirData.contact()
	if ct.is_empty():
		return -mover.face * off
	var tx: float = tgt.x
	if tgt.rush != null:
		tx = SimWrap.wrap(tgt.rush.tgt.x + tgt.rush.off) if tgt.rush.tgt != null else tgt.rush.px
	var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(tx, mover.x)), -mover.face)
	return (-s if side == "cross" else s) * SimMathx.jmax(off, float(ct.minSeparation))


## Contact, once per tick of an exchange: each fighter faces the other (section 5.4), and two bodies at rest never
## overlap (5.3): closer than minSeparation at the same height, they are moved apart evenly, each on its own side. A
## body in an authored move or in flight is left alone: a move's end already respects the separation.
static func contactTick(S: SimState, ex) -> void:
	var ct: Dictionary = DirData.contact()
	if ct.is_empty() or ex.kind == "sig":
		return
	var A = ex.A
	var D = ex.D
	var dx: float = SimWrap.sdx(A.x, D.x)
	var s: float = SimDamage.jor(SimMathx.jsign(dx), A.face)
	A.face = s
	D.face = -s
	var minS: float = float(ct.minSeparation)
	if absf(dx) >= minS or absf(A.y - D.y) >= BODY_H or A.rush != null or D.rush != null or A.state == "launched" or D.state == "launched":
		return
	var push: float = (minS - absf(dx)) * 0.5
	A.x = SimWrap.wrap(A.x - s * push)
	D.x = SimWrap.wrap(D.x + s * push)


## Contact, on a damaging strike (section 5.2): the striker is at the contact offset, on its own side and at its
## target's height, on the contact tick. The closing move before it usually put it there; when the target moved on in
## the same tick, the strike itself places the striker. A catch always does: when the target is a body in flight, or the
## striker's closing move on it is still running (the move and the strike beat can land a tick apart). Otherwise, farther
## than placementReaches (the contact block) plus two ticks of the target's speed, it is left alone and the feed says so
## (5.5, the reach check).
static func _contact(S: SimState, a, d) -> void:
	var ct: Dictionary = DirData.contact()
	if ct.is_empty():
		return
	var dx: float = SimWrap.sdx(d.x, a.x)
	var dy: float = a.y - d.y
	var reach: float = float(ct.reach)
	if absf(dx) <= reach and absf(dx) >= float(ct.minSeparation) and absf(dy) <= HEIGHT_TOL:
		return
	var lim: float = reach * float(ct.placementReaches) + SimDetMath.hypot(d.vx, d.vy) * SimConst.DT * PLACE_FLIGHT_TICKS
	var catching: bool = d.state == "launched" or d.state == "down" or (a.rush != null and a.rush.tgt == d)   # "down": it hit a wall or stopped on this tick
	if not catching and (absf(dx) > lim or absf(dy) > lim):
		SimEvents.feed(S, "OUT OF REACH", a.name + " strikes from " + SimMathx.jstr(SimMathx.jround(absf(dx))) + " u, " + SimMathx.jstr(SimMathx.jround(absf(dy))) + " u off level")
		return
	var s: float = SimDamage.jor(SimMathx.jsign(dx), -a.face)
	a.x = SimWrap.wrap(d.x + s * float(ct.offset))
	a.y = SimMathx.jmax(d.y, WorldTerrain.groundY(S, a.x))
	a.rush = null
	a.vx = 0.0
	a.vy = 0.0


## Beat "dodge": the evasive defender gets behind the attacker. With a contact block and side "cross" it is a physical
## step-around (teleporting is on hold): two short moves, over the attacker (under it at the ceiling) and down behind
## it at its height. The beat gives its length (dur), how far over it passes (rise) and where it ends (off). Otherwise
## it is the old blink.
static func opDodge(S: SimState, ex, _args) -> void:
	var A = ex.A
	var D = ex.D
	SimFx.afterimage(S, D)
	if _args != null and String(_args.get("side", "")) == "cross" and not DirData.contact().is_empty():
		var far: float = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)   # the side D ends on, from A
		var leg: float = float(_args.dur) * 0.5
		var rise: float = float(_args.rise)
		var over: bool = A.y + rise <= SimConst.CEILING or A.y - rise < WorldTerrain.groundY(S, A.x) + BODY_H
		var r := SimState.Rush.new()
		r.px = SimWrap.wrap(A.x + far * DODGE_PAST)
		r.py = A.y + (rise if over else -rise)
		r.end = S.T + leg
		D.rush = r
		D.vx = 0.0
		D.vy = 0.0
		DirExchange.schedule(ex, ex.t + leg, "dodgeLand", {"far": far, "dur": leg, "off": float(_args.off)})
		SimFx.rush(S, D, A, S.tick + int(leg * 2.0 / SimConst.DT))
		return
	D.x = SimWrap.wrap(A.x - A.face * DODGE_OFF)
	D.y = SimMathx.jmax(WorldTerrain.groundY(S, D.x), A.y + S.rng.range_(-30.0, 70.0))
	D.vx = 0.0
	D.vy = 0.0
	SimFx.ring(S, D.x, D.y + 34.0, 500.0, "#9fe0ff", 0.3, 8.0)


## The attacker's arrival side (interrupts.json arrival): a human who holds the stick up or down as he presses comes in
## over (or under) the rival and lands on the far side, in two moves like the dodge's step-around. True when it took
## the approach. Only the exchange's first move, and only with a contact block.
static func approachOver(S: SimState, ex, a) -> bool:
	var A = ex.A
	var D = ex.D
	if A.ai != null or not A.act.v2 or ex.t > SimConst.DT * 1.5 or ex.combo > 1.0 or DirData.contact().is_empty():
		return false
	var ar: Dictionary = DirInterrupt.data().get("arrival", {})
	if ar.is_empty() or absf(A.input.my) <= float(ar.tiltDead):
		return false
	var far: float = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(D.x, A.x)), -A.face)   # the far side of the rival, from where he is now
	var rise: float = float(ar.riseBh) * BODY_H
	var over: bool = A.input.my > 0.0 or D.y - rise < WorldTerrain.groundY(S, D.x) + BODY_H
	var leg: float = float(a.dur) * float(ar.overShare)
	var r := SimState.Rush.new()
	r.px = SimWrap.wrap(D.x + far * DODGE_PAST)
	r.py = D.y + (rise if over else -rise)
	r.end = S.T + leg
	A.rush = r
	DirExchange.schedule(ex, ex.t + leg, "rushLand", {"far": far, "dur": float(a.dur) - leg, "off": a.off})
	SimFx.rush(S, A, D, S.tick + int(float(a.dur) / SimConst.DT))
	return true


## The approach's second move after coming in over the rival: down on the far side, at its height.
static func opRushLand(S: SimState, ex, args) -> void:
	if ex.A.state == "launched" or ex.A.state == "down":
		return
	var r := SimState.Rush.new()
	r.tgt = ex.D
	r.off = float(args.far) * maxf(float(args.off), float(DirData.contact().minSeparation))
	r.end = S.T + float(args.dur)
	ex.A.rush = r


## The step-around's second move: down behind the attacker, at its height.
static func opDodgeLand(S: SimState, ex, args) -> void:
	var r := SimState.Rush.new()
	r.tgt = ex.A
	r.off = float(args.far) * float(args.off)
	r.end = S.T + float(args.dur)
	ex.D.rush = r
	SimFx.ring(S, ex.D.x, ex.D.y + 34.0, 500.0, "#9fe0ff", 0.3, 8.0)


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
	if o.get("perfect", false):
		DirInterrupt.perfectBlock(S, ex, a, d, o)   # step 3: the timed guard press landed in this strike's window
		return
	if a == ex.A and not o.get("noParry", false) and armed and d.lastAtkT >= winStart - early and not DirInterrupt.on():
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
			# A parry ends the string (contact-spacing.md section 7): no strike, step-in or chain window runs after it,
			# and the exchange closes this tick. Only in the profiles with a parry block, so parity is unchanged.
			for b in ex.beats:
				b.done = true
			ex.ext = null
		SimFx.ring(S, a.x + a.face * 30.0, a.y + 34.0, 700.0, "#9fe0ff", 0.4, 10.0)
		SimFx.banner(S, "PARRY", "#9fe0ff", 0.8)
		SimEvents.feed(S, d.name + " PARRIES", "Timed the wind-up. Rest of the exchange cancelled.")
		SimFx.parry(S, d, a)
		return
	if (a.state == "launched" or a.state == "down") and not DirData.contact().is_empty():
		return   # a fighter in flight or down throws no blow (a blow scheduled before it was launched)
	if dmg > 0.0:
		_contact(S, a, d)
	if d.state == "launched" or d.state == "down":
		d.state = "locked"
		d.vx *= 0.1
		d.vy *= 0.1
	var brokenBefore: int = _broken(d)
	if dmg > 0.0:
		DirInterrupt.si(d, DirInterrupt.HIT_AT, S.tick)
		# Mashed lights do blur.strikeMul of a light each (section 13, rule 5): the blow of a light press that was mashed.
		var bl: Dictionary = DirLaunch.data().get("blur", {})
		if not bl.is_empty() and DirInterrupt.on():
			var pp: int = DirLaunch.phrase(S, ex, a)
			if pp >= 0 and (pp & 1) == SimAct.LIGHT and ((pp >> 8) & 3) == DirAlchemy.MASHED:
				dmg *= float(bl.strikeMul)
	SimDamage.hit(S, ex, a, d, dmg, o)
	if dmg > 0.0 and not o.get("ignoreStance", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:
		DirInterrupt.onBlock(S, ex, d)   # a normal block: the reversal's window
	elif dmg > 0.0:
		DirInterrupt.si(a, DirInterrupt.LANDED, DirInterrupt.gi(a, DirInterrupt.LANDED) + 1)   # a landed strike: the earned launch counts them
		DirInterrupt.si(d, DirInterrupt.TAKEN, DirInterrupt.gi(d, DirInterrupt.TAKEN) + 1)
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
	# With a contact block the break ends the string: every pending beat is dropped, not only the launches and the
	# window. A leftover step-in used to drag the launched fighter back, and a leftover blow hit it from far off.
	var all: bool = not DirData.contact().is_empty()
	for b in ex.beats:
		if not b.done and (all or b.op == "launch" or b.op == "window"):
			b.done = true
	ex.ext = null
	DirExchange.schedule(ex, ex.t + BREAK_LAUNCH_AT, "breakLaunch", {"w": "A" if a == ex.A else "D", "force": BREAK_FORCE})


## A knock-back is a decisive exchange (agency-pass.md section 13, rule 1): being driven back means he lost it. It
## counts for the brink's set-up and the finisher as a launch does. The kind is the exchange's own clause when it has
## one (a clash won, a guard break, a charge interrupt), and otherwise knockback.
static func _knockDecisive(S: SimState, ex, att, tgt, setup: String = "") -> void:
	var why: String = "knockback"
	if ex.tag.begins_with("HEAVY CLASH"):
		why = "clash"
	elif ex.tag == "GUARD BREAK":
		why = "guard_break"
	elif ex.tag == "CHARGE INTERRUPT":
		why = "interrupt"
	DirExchange.decisive(S, ex, att, tgt, why, setup)


## longOnly: a break or finisher launch, chosen among the long-haul candidates only (no "no launch").
## args (the launch beat's own): "ends" and "sends" are Combat's hooks (alchemist-content.md): a piece that ends "level"
## never sends the rival away, and "sends" keeps only the launch candidates in that direction.
static func launchBeat(S: SimState, ex, att, tgt, force: float, longOnly: bool = false, args = null) -> void:
	if ex.cancel or S.game.ko != null:
		return
	var ends: String = String(args.get("ends", "")) if args != null else ""
	var gate: Dictionary = DirLaunch.data().get("earned", {})
	var why: String = "the gate is off"
	if not longOnly and (gate.get("enabled", false) or ends == "level") and not DirData.contact().is_empty():
		# The earned launch (agency-pass.md section 3): not earned, a heavy gives the knock-back and a light leaves both
		# fighters in reach, so the brawl goes on.
		why = DirLaunch.earned(S, ex, att, tgt) if ends != "level" else ""
		if why == "":
			var heavy: bool = DirLaunch.heavyBlow(S, ex, att) and ends != "level"
			# A blur always closes (section 13): the light that follows enderAfter landed strikes is the blur's own ender,
			# a knock-back the player did not have to earn, at enderDist of the distance. Never a launch.
			var bl: Dictionary = DirLaunch.data().get("blur", {})
			var ender: bool = not heavy and ends != "level" and not bl.is_empty() and DirInterrupt.gi(att, DirInterrupt.LANDED) - 1 >= int(bl.enderAfter)
			var sent: bool = heavy or ender
			DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_KNOCK if sent else DirInterrupt.END_STAY)
			SimFx.launchPlan(S, att, tgt, "", "KNOCK BACK" if sent else "STAY")
			if sent:
				DirLaunch.knock(S, att, tgt, 1.0 if heavy else float(bl.enderDist))
				SimEvents.feed(S, "KNOCK BACK" if heavy else "BLUR ENDER", "a heavy, but no launch was earned" if heavy else "the light after " + str(DirInterrupt.gi(att, DirInterrupt.LANDED) - 1) + " landed strikes: the blur closes with its own knock-back")
				_knockDecisive(S, ex, att, tgt, "" if heavy else "blurPlain")   # a plain blur's ender is half a set-up (section 14.4)
			else:
				SimEvents.feed(S, "STAYS IN REACH", "a light: the brawl goes on")
			return
		force *= float(gate.get("forceMul", 1.0))
	# The stick picks the direction and the planner snaps to the most dramatic target near it (a human's press only).
	var pt: int = DirLaunch.phrase(S, ex, att) if (att.ai == null and not longOnly and not DirData.contact().is_empty()) else -1
	var r: Dictionary = DirLaunch.chooseLaunch(S, att, tgt, force, longOnly, String(args.get("sends", "")) if args != null else "", (pt >> 4) & 15 if pt >= 0 else 0, gate.get("enabled", false) and not DirData.contact().is_empty())
	var parts: PackedStringArray = []
	for k in r.top:
		parts.append(k.name + " " + SimMathx.jstr(SimMathx.jround(k.s)))
	var all: PackedStringArray = []
	for k in r.all:
		all.append(k.name + ("#" + str(k.brunt.b) if k.has("brunt") else "") + " " + SimMathx.jstr(SimMathx.jround(k.s)))   # B2: which building
	SimFx.launchPlan(S, att, tgt, "|".join(all), r.best.name)
	if r.best.name == "KNOCK BACK":
		# Nothing scored above holding back: the strike knocks the target back instead of launching it.
		DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_KNOCK)
		if DirData.contact().is_empty():
			DirLaunch.knockBack(S, att, tgt)   # the old profiles keep the shove
		else:
			DirLaunch.knock(S, att, tgt)
		SimEvents.feed(S, "KNOCK BACK", "  |  ".join(parts))
		if not DirData.contact().is_empty():
			_knockDecisive(S, ex, att, tgt)
		# In the old profiles a shove is decisive only when the exchange meets another clause: a heavy clash won, a
		# GUARD BREAK, or a CHARGE INTERRUPT (it stops a fill).
		elif ex.tag.begins_with("HEAVY CLASH") or ex.tag == "GUARD BREAK" or ex.tag == "CHARGE INTERRUPT":
			DirExchange.decisive(S, ex, att, tgt, "clash" if ex.tag.begins_with("HEAVY CLASH") else ("guard_break" if ex.tag == "GUARD BREAK" else "interrupt"))
		return
	DirLaunch.doLaunch(S, att, tgt, r.best, force, longOnly)
	if r.best.has("p") and r.best.p.get("building", false):
		SimFx.hazardTelegraph(S, tgt, "brunt", r.best.p.t, r.best.p.x)
	S.dirS.lastLaunch2 = S.dirS.lastLaunch
	S.dirS.lastLaunch = r.best.name
	DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_LAUNCH)
	SimEvents.feed(S, "LAUNCH: " + r.best.name + (" (earned: " + why + ")" if gate.get("enabled", false) and not longOnly else ""), "  |  ".join(parts))
	DirExchange.decisive(S, ex, att, tgt, "launch")
