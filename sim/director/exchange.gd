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
	if D.state == "launched" or D.state == "locked":
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
		SimFx.lockLost(S, A, D)
		SimFx.searching(S, A, D, D.lastSeen.x if D.lastSeen != null else D.x)
		return
	if A.hidden:
		if A.canHide:
			A.hidden = false
			if A.hiddenFor > 1.8:
				A.ambushUntil = S.T + 1.0
		else:
			SimHiding.regainLock(S, A)   # the target attacking brings the lock back (spec-wounds.md §1c)
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
	A.exT = S.T
	D.exT = S.T
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	D.face = -A.face
	var dState: String = D.state
	A.state = "locked"
	D.state = "locked"
	D.dPrev = dState
	S.dirS.ex = ex
	var chk = null
	if planCheck.is_valid():
		chk = _planByCode(S, ex, "sig" if kind == "sig" else "melee")
	if kind == "sig":
		DirBeam.planBeam(S, ex)
	else:
		DirMelee.planMelee(S, ex)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "sig" if kind == "sig" else "melee")
	var stanceLabel: String = "CHARGING" if dState == "charging" else STN[int(D.stance)]
	SimEvents.feed(S, A.name + " " + kind.to_upper() + " vs " + stanceLabel, ex.tag + ("  (ambush)" if A.ambush else ""))
	SimFx.attack(S, A, D, kind, stanceLabel, ex.tag, A.ambush)
	if A.ambush:
		SimFx.ambush(S, A, D)
		SimFx.danger(S, D, "ambush", 0.0)


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
			SimFx.rush(S, A, D, S.tick + int(a.dur / SimConst.DT))
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
		"finisher":
			_opFinisher(S, ex, a)
		"finRush":
			var fw = A if a.w == "A" else D
			var fr := SimState.Rush.new()
			fr.tgt = D if a.w == "A" else A
			fr.off = -fw.face * a.off
			fr.end = S.T + a.dur
			fw.rush = fr
			SimFx.rush(S, fw, fr.tgt, S.tick + int(a.dur / SimConst.DT))
		"breakLaunch":
			DirMelee.launchBeat(S, ex, A if a.w == "A" else D, D if a.w == "A" else A, a.force, true)
		"contest":
			_opContest(S, ex, a)
		_:
			push_error("runBeat: unknown op " + b.op)


## No chain window when the launched target is already out of reach: a chain rush is a 0.24 s blink, and catching a
## long haul in mid-air would cut it short (balance-targets.md section 10: long gap closes are pursuit flights).
const CHAIN_REACH: float = 2500.0


static func openWindow(S: SimState, ex) -> void:
	if ex.D.state == "launched" and absf(SimWrap.sdx(ex.A.x, ex.D.x)) > CHAIN_REACH:
		return
	var e := SimState.Ext.new()
	e.start = S.T
	e.until = S.T + 0.6
	ex.ext = e
	SimFx.windowOpen(S, ex.A, "chain", 0.6)
	if ex.A.ai != null and S.rng.next() < SimMathx.jclamp(0.62 - 0.14 * ex.combo, 0.05, 0.6):
		schedule(ex, ex.t + S.rng.range_(0.12, 0.35), "press", {"who": "A"})


static func chain(S: SimState, ex) -> void:
	var A = ex.A
	ex.combo += 1.0
	ex.ext = null
	A.ki -= 6.0
	var t: float = ex.t
	SimFx.banner(S, SimMathx.jstr(ex.combo) + " HIT CHAIN", "#ffd45a", 0.7)
	var chk = null
	if planCheck.is_valid():
		chk = _planByCode(S, ex, "chain")
	DirData.planChain(ex)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "chain")


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
		SimFx.chainEnd(S, ex.A, int(ex.combo))
	ex.A.exT = S.T
	ex.D.exT = S.T
	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)


## Breathing room after an exchange (balance-targets.md section 10): 0.8 s after a quick exchange, rising with its
## length (ex.t, request to release) to at most 1.5 s. Was a flat 0.22 s.
const COOL_MIN: float = 0.8
const COOL_PER_SEC: float = 0.3
const COOL_MAX: float = 1.5


static func cooldownAfter(ex) -> float:
	return SimMathx.jclamp(COOL_MIN + COOL_PER_SEC * ex.t, COOL_MIN, COOL_MAX)


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
		var inReach: bool = not (ex.D.state == "launched" and absf(SimWrap.sdx(A.x, ex.D.x)) > CHAIN_REACH)
		if A.lastAtkT >= ex.ext.start and ex.combo < 5.0 and A.ki >= 6.0 and inReach:
			chain(S, ex)
	var pending: bool = false
	for b in ex.beats:
		if not b.done:
			pending = true
			break
	if not pending and not (ex.ext != null and S.T < ex.ext.until):
		endEx(S, ex)


# ---------------------------------------------------------------- decisive exchanges and finishers (S2)
# spec-wounds.md §1: a decisive exchange ends with the loser launched (however the launch lands), a heavy or beam clash
# won, or a GUARD BREAK. A "no launch" shove is not decisive unless the exchange also meets another clause. When the
# opponent of a fighter on the brink wins a decisive exchange, the winner's finisher replaces the normal ending, and the
# fighter on the brink survives it on a contest roll. A KO happens only there.
# The finisher below is a placeholder set piece until Combat's finisher templates arrive as data.

const FIN_RUSH: float = 0.35         # the winner closes in
const FIN_HIT1: Array = [0.4, 40.0]  # [time, damage] of the first finishing strike
const FIN_HIT2: Array = [0.75, 55.0] # ... and the second
const FIN_LAUNCH: Array = [0.8, 2600.0]   # [time, force] of the break launch (long, planner's long-haul candidates)
const FIN_CONTEST: float = 1.6       # the contest resolves while the loser flies
const FIN_END: float = 2.1
const CONTEST_BASE: float = 0.30     # survival chance
const CONTEST_TILT_AT: float = 480.0 # ... minus CONTEST_TILT per minute past 8:00 of match time, floor 0
const CONTEST_TILT: float = 0.10


## W won a decisive exchange against L (why: launch, clash, guard_break, beam, beam_clash).
static func decisive(S: SimState, ex, W, L, why: String) -> void:
	if S.game.ko != null or ex == null:
		return
	SimFx.decisive(S, W, L, why)
	if L.brink and not finisherPlanned(ex):
		startFinisher(S, ex, W, L)


static func finisherPlanned(ex) -> bool:
	for b in ex.beats:
		if b.op == "finisher":
			return true
	return false


## The finisher replaces the rest of the exchange: pending beats are dropped and the chain window closes.
static func startFinisher(S: SimState, ex, W, L) -> void:
	for b in ex.beats:
		if not b.done:
			b.done = true
	ex.ext = null
	var chk = null
	if planCheck.is_valid():
		chk = _planByCode(S, ex, "finisher", W)
	DirData.planFinisher(ex, W)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "finisher")


# ---------------------------------------------------------------- loader check (tools only)
## Set by sim/director/tools/loader_check.gd, never by the game: called after every plan with the plan the frozen copy
## of the parity data makes for the same exchange from the same RNG state (s3b-loader-note.md: the step 1 test kept as a
## regression). checkData is that frozen copy, [templates, finishers]. Invalid (the default) costs nothing.
static var planCheck: Callable = Callable()
static var checkData: Array = []


## Plans the exchange with the frozen parity data into a scratch copy, from the current RNG state, then restores the
## live data and that state. Returns {"ex", "rng"}: the frozen plan's beats and tag, and the RNG state after its draws.
static func _planByCode(S: SimState, ex, what: String, W = null) -> Dictionary:
	var r0: int = S.rng.a
	var c := newEx(ex.A, ex.D, ex.kind)
	c.t = ex.t
	c.combo = ex.combo
	c.tag = ex.tag
	for b in ex.beats:
		c.beats.append(b)
	var live: Array = DirData.swap(checkData[0], checkData[1])
	match what:
		"melee":
			DirData.planMelee(S, c)
		"sig":
			DirData.planBeam(S, c)
		"chain":
			DirData.planChain(c)
		"finisher":
			DirData.planFinisher(c, W)
	DirData.swap(live[0], live[1])
	var r1: int = S.rng.a
	S.rng.a = r0
	return {"ex": c, "rng": r1, "n0": ex.beats.size()}


static func _opFinisher(S: SimState, ex, a) -> void:
	var W = ex.A if a.w == "A" else ex.D
	var L = ex.D if a.w == "A" else ex.A
	W.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(W.x, L.x)), W.face)
	SimFx.banner(S, "FINISHER", W.aura, 1.2)
	SimFx.finisherStart(S, W, L)
	SimEvents.feed(S, W.name + " FINISHER", L.name + " is on the brink")


## The contest roll (one S.rng draw): survive with CONTEST_BASE, less CONTEST_TILT per minute past CONTEST_TILT_AT.
static func _opContest(S: SimState, ex, a) -> void:
	var W = ex.A if a.w == "A" else ex.D
	var L = ex.D if a.w == "A" else ex.A
	var late: float = SimMathx.jmax(0.0, (S.T - CONTEST_TILT_AT) / 60.0)
	var chance: float = SimMathx.jmax(0.0, CONTEST_BASE - CONTEST_TILT * late)
	var survived: bool = S.rng.next() < chance
	SimFx.finisherContest(S, L, chance, survived)
	SimEvents.feed(S, L.name + (" SURVIVES" if survived else " FALLS"), "finisher contest, survival chance " + SimMathx.jstr(SimMathx.jround(chance * 100.0)) + "%")
	if survived:
		SimFx.banner(S, L.name + " HOLDS ON", L.aura, 1.2)
	else:
		SimDamage.ko(S, L, W)
