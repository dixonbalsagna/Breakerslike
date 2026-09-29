class_name DirExchange
## Exchange director: the twin of exchange.js (STN, newEx, schedule, requestAttack, runBeat, openWindow, chain, endEx,
## dirUpdate). Beats are data (SimState.Beat); args is a Dictionary like the JS object, or null.

const STN: Array = ["AGGRESSIVE", "DEFENSIVE", "EVASIVE", "ESCAPE"]


static func newEx(A, D, kind: String) -> SimState.Exchange:
	var ex := SimState.Exchange.new()
	ex.A = A
	ex.D = D
	ex.kind = kind
	return ex


## The JS push-then-stable-sort by t: the new beat goes after every beat with t <= its t. (GDScript's sort is not
## stable, so the insert is explicit.)
static func schedule(ex, t: float, op: String, args = null) -> void:
	var b := SimState.Beat.new()
	b.t = t
	b.op = op
	b.args = args
	b.done = false
	var i: int = ex.beats.size()
	while i > 0 and ex.beats[i - 1].t > t:
		i -= 1
	ex.beats.insert(i, b)


static func requestAttack(S: SimState, A, kind: String) -> void:
	if S.dirS.ex != null or S.dirS.cool > 0.0 or S.game.ko != null:
		return
	var D = SimRoster.opp(S, A)
	if A.state != "free" and A.state != "charging":
		return
	if D.state == "launched" or D.state == "locked" or D.hp <= 0.0:
		return
	if kind == "sig" and A.ki < 45.0:
		if A.ai == null:
			SimFx.banner(S, "NEED 45 KI", "#9fb4ff", 0.6)
		return
	if kind == "heavy" and A.ki < 4.0:
		kind = "light"
	if D.hidden:
		A.ki = SimMathx.jmax(0.0, A.ki - 2.0)
		S.dirS.cool = 0.5
		if A.ai == null:
			SimFx.banner(S, "LOCK LOST — TARGET HIDDEN", "#9fb4ff", 0.9)
		return
	if A.hidden:
		A.hidden = false
		if A.hiddenFor > 1.8:
			A.ambushUntil = S.T + 1.0
	if S.T < A.ambushUntil:
		A.ambush = true
		A.ambushUntil = 0.0
		SimFx.banner(S, "AMBUSH FROM COVER", "#ffd45a", 1.1)
	A.hideT = 0.0
	A.state = "free"
	if kind == "heavy":
		A.ki -= 4.0
	if kind == "sig":
		A.ki -= 45.0
	var ex := newEx(A, D, kind)
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	D.face = -A.face
	var dState: String = D.state
	A.state = "locked"
	D.state = "locked"
	D.dPrev = dState
	S.dirS.ex = ex
	if kind == "sig":
		DirBeam.planBeam(S, ex)
	else:
		DirMelee.planMelee(S, ex)
	var stanceLabel: String = "CHARGING" if dState == "charging" else STN[int(D.stance)]
	SimEvents.feed(S, A.name + " " + kind.to_upper() + " vs " + stanceLabel, ex.tag + ("  (ambush)" if A.ambush else ""))


## Runs one beat (module-spec section 4). Fighters are read from ex when the beat runs.
static func runBeat(S: SimState, ex, b) -> void:
	var A = ex.A
	var D = ex.D
	var a = b.args
	match b.op:
		"rush":
			var r := SimState.Rush.new()
			r.tgt = D
			r.off = -A.face * a.off
			r.end = S.T + a.dur
			A.rush = r
		"wind":
			DirMelee.opWind(S, ex, a)
		"press":
			var who = A if a.who == "A" else D
			who.lastAtkT = S.T
		"strike":
			DirMelee.strike(S, ex, A if a.a == "A" else D, A if a.d == "A" else D, a.dmg, a.o)
		"launch":
			DirMelee.launchBeat(S, ex, D if a.rev else A, A if a.rev else D, a.force)
		"window":
			openWindow(S, ex)
		"nop":
			pass
		"slip":
			DirMelee.opSlip(S, ex, a)
		"dodge":
			DirMelee.opDodge(S, ex, a)
		"guardBreak":
			DirMelee.opGuardBreak(S, ex, a)
		"clashWave":
			DirMelee.clashWave(S, ex)
		"chainStrike":
			DirMelee.strike(S, ex, A, D, 52.0 + ex.combo * 7.0, {"noParry": true, "ignoreStance": true, "big": true, "stop": 0.08})
		"beamCharge":
			DirBeam.opBeamCharge(S, ex, a)
		"beamFire":
			DirBeam.opBeamFire(S, ex, a)
		"beamImpact":
			DirBeam.opBeamImpact(S, ex, a)
		"beamDodge":
			DirBeam.opBeamDodge(S, ex, a)
		"beamEscape":
			DirBeam.opBeamEscape(S, ex, a)
		"clashResolve":
			DirBeam.opClashResolve(S, ex, a)
		_:
			push_error("runBeat: unknown op " + b.op)


static func openWindow(S: SimState, ex) -> void:
	var e := SimState.Ext.new()
	e.start = S.T
	e.until = S.T + 0.6
	ex.ext = e
	if ex.A.ai != null and S.rng.next() < SimMathx.jclamp(0.62 - 0.14 * ex.combo, 0.05, 0.6):
		schedule(ex, ex.t + S.rng.range_(0.12, 0.35), "press", {"who": "A"})


static func chain(S: SimState, ex) -> void:
	var A = ex.A
	ex.combo += 1.0
	ex.ext = null
	A.ki -= 6.0
	var t: float = ex.t
	SimFx.banner(S, SimMathx.jstr(ex.combo) + " HIT CHAIN", "#ffd45a", 0.7)
	schedule(ex, t, "rush", {"off": 60.0, "dur": 0.24})
	schedule(ex, t + 0.26, "chainStrike")
	schedule(ex, t + 0.3, "launch", {"force": 1500.0, "rev": false})
	schedule(ex, t + 0.55, "window")


static func endEx(S: SimState, ex) -> void:
	if ex.A.state == "locked":
		ex.A.state = "free"
	if ex.D.state == "locked":
		ex.D.state = "free"
	ex.A.rush = null
	ex.A.beamCharge = null
	ex.A.ambush = false
	if ex.D.dPrev != null and ex.D.dPrev != "":
		ex.D.dPrev = null
	S.game.clash = null
	if ex.combo > 1.0:
		SimEvents.feed(S, "CHAIN x" + SimMathx.jstr(ex.combo) + " ended", ex.A.name + " landed " + SimMathx.jstr(ex.combo) + " linked exchanges")
	S.dirS.ex = null
	S.dirS.cool = 0.22


static func dirUpdate(S: SimState, dt: float) -> void:
	if S.dirS.cool > 0.0:
		S.dirS.cool -= dt
	var ex = S.dirS.ex
	if ex == null:
		return
	ex.t += dt
	var i: int = 0
	while i < ex.beats.size():
		var b = ex.beats[i]
		if not b.done and b.t <= ex.t:
			b.done = true
			runBeat(S, ex, b)
			if S.dirS.ex != ex:
				return
		i += 1
	if ex.ext != null and S.T < ex.ext.until:
		var A = ex.A
		if A.lastAtkT >= ex.ext.start and ex.combo < 5.0 and A.ki >= 6.0 and A.hp > 0.0 and ex.D.hp > 0.0:
			chain(S, ex)
	var pending: bool = false
	for b in ex.beats:
		if not b.done:
			pending = true
			break
	if not pending and not (ex.ext != null and S.T < ex.ext.until):
		endEx(S, ex)
