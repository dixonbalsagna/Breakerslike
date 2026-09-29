class_name DirMelee
## Melee exchanges: the twin of melee.js (planMelee and its beat ops, clashWave, strike, launchBeat). The schedule
## calls keep melee.js's order exactly: beats with equal t run in scheduling order.


static func _strike(ex, t: float, a: String, d: String, dmg: float, o = null) -> void:
	DirExchange.schedule(ex, t, "strike", {"a": a, "d": d, "dmg": dmg, "o": o})


static func _launch(ex, t: float, force: float, who: String = "") -> void:
	DirExchange.schedule(ex, t, "launch", {"force": force, "rev": who == "D"})


static func planMelee(S: SimState, ex) -> void:
	var A = ex.A
	var D = ex.D
	var heavy: bool = ex.kind == "heavy"
	var dist: float = absf(SimWrap.sdx(A.x, D.x))
	var rt: float = SimMathx.jclamp(dist / 2600.0, 0.18, 0.65)
	var ds: float = 4.0 if (D.dPrev != null and D.dPrev == "charging") else D.stance
	var as_: float = A.stance
	var base: float = 66.0 if heavy else 26.0
	var t: float = rt

	if ds == 4.0:
		DirExchange.schedule(ex, 0.0, "rush", {"off": 58.0, "dur": rt})
		ex.tag = "CHARGE INTERRUPT"
		_strike(ex, t, "A", "D", base * 1.4, {"noParry": true, "ignoreStance": true, "big": true})
		_launch(ex, t + 0.05, 1500.0 if heavy else 900.0)
		DirExchange.schedule(ex, t + 0.32, "window")
		return
	if ds == 3.0:
		var pEsc: float = SimMathx.jclamp(0.5 + 0.07 * (D.tier - A.tier) + (0.12 if dist > 800.0 else 0.0) - (1.0 if A.ambush else 0.0), 0.05, 0.88)
		if S.rng.next() < pEsc:
			ex.tag = "PURSUIT — TARGET SLIPS AWAY"
			DirExchange.schedule(ex, 0.0, "rush", {"off": 260.0, "dur": rt * 0.8})
			DirExchange.schedule(ex, rt * 0.55, "slip")
			DirExchange.schedule(ex, rt + 0.5, "nop")
			return
		DirExchange.schedule(ex, 0.0, "rush", {"off": 58.0, "dur": rt})
		ex.tag = "PURSUIT — CAUGHT"
		_strike(ex, t, "A", "D", base * 1.2, {"noParry": true})
		if heavy:
			_launch(ex, t + 0.05, 1500.0)
		else:
			_launch(ex, t + 0.05, 800.0)
		DirExchange.schedule(ex, t + 0.3, "window")
		return
	if ds == 2.0:
		DirExchange.schedule(ex, 0.0, "rush", {"off": 58.0, "dur": rt})
		var pRead: float = 1.0 if A.ambush else SimMathx.jclamp(0.42 + 0.08 * (A.tier - D.tier) + (0.08 if as_ == 0.0 else 0.0) - (0.12 if A.ki < 12.0 else 0.0) - (0.05 if heavy else 0.0), 0.15, 0.8)
		var read: bool = S.rng.next() < pRead
		ex.tag = "DODGE & READ" if read else "DODGE & COUNTER"
		DirExchange.schedule(ex, t - 0.12, "wind")
		DirExchange.schedule(ex, t, "dodge")
		if read:
			_strike(ex, t + 0.22, "A", "D", base, {"noParry": true})
			if heavy:
				_launch(ex, t + 0.27, 1400.0)
			DirExchange.schedule(ex, t + 0.5, "window")
		else:
			_strike(ex, t + 0.24, "D", "A", base * 0.9, {"noParry": true})
			_launch(ex, t + 0.3, 900.0, "D")
			DirExchange.schedule(ex, t + 0.6, "nop")
		return
	if ds == 1.0:
		DirExchange.schedule(ex, 0.0, "rush", {"off": 58.0, "dur": rt})
		if not heavy:
			ex.tag = "PRESSURE — GUARD HOLDS"
			DirExchange.schedule(ex, t - 0.1, "wind")
			_strike(ex, t, "A", "D", 26.0, {"kb": 120.0})
			_strike(ex, t + 0.16, "A", "D", 26.0, {"kb": 120.0, "noParry": true})
			_strike(ex, t + 0.32, "A", "D", 26.0, {"kb": 120.0, "noParry": true})
			if D.ki > 25.0 and S.rng.next() < 0.4:
				ex.tag += " → COUNTER"
				_strike(ex, t + 0.55, "D", "A", 24.0, {"noParry": true, "ignoreStance": true})
				DirExchange.schedule(ex, t + 0.8, "nop")
			else:
				DirExchange.schedule(ex, t + 0.42, "window")
		else:
			ex.tag = "GUARD BREAK"
			DirExchange.schedule(ex, t - 0.1, "wind")
			_strike(ex, t, "A", "D", 45.0, {"kb": 150.0})
			_strike(ex, t + 0.2, "A", "D", 45.0, {"kb": 150.0, "noParry": true})
			DirExchange.schedule(ex, t + 0.4, "guardBreak")
			_strike(ex, t + 0.42, "A", "D", base * 1.15, {"noParry": true, "ignoreStance": true, "stop": 0.12, "shake": 12.0, "big": true})
			_launch(ex, t + 0.46, 1700.0)
			DirExchange.schedule(ex, t + 0.72, "window")
		return
	# aggressive defender
	DirExchange.schedule(ex, 0.0, "rush", {"off": 58.0, "dur": rt})
	if not heavy:
		ex.tag = "TRADE BLOWS"
		var aw: bool = _trade(S, A, D) > _trade(S, D, A)
		DirExchange.schedule(ex, t - 0.1, "wind")
		_strike(ex, t, "A", "D", 24.0)
		_strike(ex, t + 0.17, "D", "A", 20.0, {"noParry": true})
		_strike(ex, t + 0.34, "A", "D", 24.0, {"noParry": true})
		_strike(ex, t + 0.51, "D", "A", 20.0, {"noParry": true})
		if aw:
			_strike(ex, t + 0.72, "A", "D", 34.0, {"noParry": true, "stop": 0.1})
			_launch(ex, t + 0.76, 1000.0)
			DirExchange.schedule(ex, t + 0.98, "window")
		else:
			_strike(ex, t + 0.72, "D", "A", 32.0, {"noParry": true, "stop": 0.1})
			_launch(ex, t + 0.76, 1000.0, "D")
			DirExchange.schedule(ex, t + 1.0, "nop")
	else:
		var p: float = SimMathx.jclamp(0.5 + 0.09 * (A.tier - D.tier) + (0.05 if A.ki > D.ki else -0.05), 0.2, 0.8)
		var r: float = S.rng.next()
		DirExchange.schedule(ex, t - 0.05, "wind")
		if r < p - 0.12:
			ex.tag = "HEAVY CLASH — WON"
			_strike(ex, t + 0.28, "A", "D", base + 8.0, {"stop": 0.12, "shake": 12.0, "ignoreStance": true, "big": true})
			_launch(ex, t + 0.32, 1800.0)
			DirExchange.schedule(ex, t + 0.58, "window")
		elif r > p + 0.12:
			ex.tag = "HEAVY CLASH — COUNTERED"
			_strike(ex, t + 0.28, "D", "A", base, {"noParry": true, "stop": 0.12, "shake": 12.0, "ignoreStance": true, "big": true})
			_launch(ex, t + 0.32, 1600.0, "D")
			DirExchange.schedule(ex, t + 0.6, "nop")
		else:
			ex.tag = "CLASH SHOCKWAVE"
			DirExchange.schedule(ex, t + 0.28, "clashWave")
			DirExchange.schedule(ex, t + 0.7, "nop")


## melee.js sc(f, o) for TRADE BLOWS: one draw per call.
static func _trade(S: SimState, f, o) -> float:
	return f.tier + f.ki / 70.0 + S.rng.range_(0.0, 1.6) + (0.3 if f.hp > o.hp else 0.0)


## Beat "wind": the parry window opens; an AI defender may time a parry press.
static func opWind(S: SimState, ex, _args) -> void:
	var D = ex.D
	ex.windowStart = S.T
	if D.ai != null and S.rng.next() < (0.5 if D.stance == 1.0 else (0.3 if D.stance == 0.0 else 0.12)):
		DirExchange.schedule(ex, ex.t + S.rng.range_(0.05, 0.16), "press", {"who": "D"})


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
	SimFx.shake(S, 12.0)


static func clashWave(S: SimState, ex) -> void:
	var A = ex.A
	var D = ex.D
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
	if my < WorldTerrain.groundY(S, mx) + 200.0:
		WorldTerrain.crater(S, mx, 60.0 + tier * 16.0, 10.0 + tier * 4.0, A)
	WorldStructures.damageArea(S, mx, my, 160.0 + tier * 40.0, 110.0 + tier * 80.0, A)
	SimFx.banner(S, "CLASH", "#ffffff", 0.7)
	SimFx.shake(S, 18.0)


static func strike(S: SimState, ex, a, d, dmg: float, o = null) -> void:
	if o == null:
		o = {}
	if ex.cancel or S.game.ko != null or d.hp <= 0.0 or a.hp <= 0.0:
		return
	a.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(a.x, d.x)), a.face)
	if a == ex.A and not o.get("noParry", false) and ex.windowStart >= 0.0 and d.lastAtkT >= ex.windowStart:
		ex.cancel = true
		SimDamage.hit(S, ex, d, a, 18.0, {"ignoreStance": true, "stop": 0.12, "shake": 9.0})
		SimFx.ring(S, a.x + a.face * 30.0, a.y + 34.0, 700.0, "#9fe0ff", 0.4, 10.0)
		SimFx.banner(S, "PARRY", "#9fe0ff", 0.8)
		a.vx = -a.face * 520.0
		d.ki = SimMathx.jmin(100.0, d.ki + 8.0)
		SimEvents.feed(S, d.name + " PARRIES", "Timed the wind-up. Rest of the exchange cancelled.")
		return
	if d.state == "launched" or d.state == "down":
		d.state = "locked"
		d.vx *= 0.1
		d.vy *= 0.1
	SimDamage.hit(S, ex, a, d, dmg, o)
	d.vx += a.face * SimDamage.jor(o.get("kb", 0.0), 220.0)


static func launchBeat(S: SimState, ex, att, tgt, force: float) -> void:
	if ex.cancel or S.game.ko != null or tgt.hp <= 0.0:
		return
	var r: Dictionary = DirLaunch.chooseLaunch(S, att, tgt)
	DirLaunch.doLaunch(S, att, tgt, r.best, force)
	S.dirS.lastLaunch2 = S.dirS.lastLaunch
	S.dirS.lastLaunch = r.best.name
	var parts: PackedStringArray = []
	for k in r.top:
		parts.append(k.name + " " + SimMathx.jstr(SimMathx.jround(k.s)))
	SimEvents.feed(S, "LAUNCH: " + r.best.name, "  |  ".join(parts))
