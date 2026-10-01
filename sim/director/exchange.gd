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


const QUEUE_LIFE: int = 36   # ticks a queued request waits to start (control-rules.md §6); the attacker's links wait through its own exchange
const KIND: Array = ["light", "heavy", "sig"]   # SimAct.LIGHT, HEAVY, SIG
const STARTED: int = 0
const DROPPED: int = 1
const WAIT: int = 2


## An attack press. For a v2 slot it is one request (ADR 0008): it joins the fighter's queue (SimAct, depth queueMax), and
## the director starts the oldest request as soon as it can (_drain: here, and every tick). A press the queue has no room
## for is ignored. A slot that is not v2 starts its attack directly, as before.
static func requestAttack(S: SimState, A, kind: String) -> void:
	if not A.act.v2:
		_start(S, A, kind)
		return
	var m: float = A.input.mx * SimMathx.jsign(SimWrap.sdx(A.x, SimRoster.opp(S, A).x))
	var entry: int = 1 if m > SimAct.awayDead else (-1 if m < -SimAct.awayDead else 0)   # toward, neutral or away (step 4 reads it)
	SimAct.push(A, KIND.find(kind), A.act.mode, entry, S.tick)
	_drain(S)


## Starts the oldest queued request the director can take: the older one first, the slots alternating on a tie. A request
## that cannot start yet (the cooldown, an exchange running, a target in the air) waits in its queue until it expires.
static func _drain(S: SimState) -> void:
	if S.dirS.ex != null or S.dirS.cool > 0.0 or S.game.ko != null:
		return
	var q0: Array = SimAct.peek(S.fighters[0])
	var q1: Array = SimAct.peek(S.fighters[1])
	if q0.is_empty() and q1.is_empty():
		return
	var order: Array = [0, 1]
	if q0.is_empty() or (not q1.is_empty() and (q1[3] < q0[3] or (q1[3] == q0[3] and S.tick % 2 == 1))):
		order = [1, 0]
	for k in order:
		var f = S.fighters[k]
		while not SimAct.peek(f).is_empty():
			var r: int = _start(S, f, KIND[int(SimAct.peek(f)[0])])
			if r == WAIT:
				break
			SimAct.pop(f)
			if r == STARTED:
				return


## Once per live tick, from dirUpdate: the layout's upgrade edge (a hold or a swipe makes the newest request heavier, or
## queues a new one if it has already started), the expiry of waiting requests, and the drain.
static func _queues(S: SimState) -> void:
	for f in S.fighters:
		if not f.act.v2:
			continue
		var up: int = f.input.upgrade
		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG):
			SimAct.push(f, SimAct.HEAVY if up == 1 else SimAct.SIG, f.act.mode, 0, S.tick)
		if not (S.dirS.ex != null and S.dirS.ex.A == f):
			SimAct.expire(f, S.tick, QUEUE_LIFE)
	_drain(S)


## Starts A's attack if the director can take it now. STARTED: an exchange began. DROPPED: the request was spent without
## one (no ki for a signature, the signature still recharging, lock lost). WAIT: not yet (a queued request keeps waiting).
static func _start(S: SimState, A, kind: String) -> int:
	if S.dirS.ex != null or S.dirS.cool > 0.0 or S.game.ko != null:
		return WAIT
	var D = SimRoster.opp(S, A)
	if A.state != "free" and A.state != "charging":
		return WAIT
	if D.state == "launched" or D.state == "locked":
		return WAIT
	if kind == "sig" and A.ki < 45.0:
		if A.ai == null:
			SimFx.banner(S, "NEED 45 KI", "#9fb4ff", 0.6)
		return DROPPED
	# The signature cooldown (questionnaire 5; fighter.json sigCooldown): 2 to 4 signatures a match, each an event.
	if kind == "sig" and S.T < A.sigReadyT:
		if A.ai == null:
			SimFx.banner(S, "SIGNATURE RECHARGING", "#9fb4ff", 0.6)
		return DROPPED
	if kind == "heavy" and A.ki < 4.0:
		kind = "light"
	if D.hidden:
		A.ki = SimMathx.jmax(0.0, A.ki - 2.0)
		S.dirS.cool = 0.5
		if A.ai == null:
			SimFx.banner(S, "LOCK LOST — TARGET HIDDEN", "#9fb4ff", 0.9)
		SimFx.lockLost(S, A, D)
		SimFx.searching(S, A, D, D.lastSeen.x if D.lastSeen != null else D.x)
		return DROPPED
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
		A.sigReadyT = S.T + A.sigCooldown
	var ex := newEx(A, D, kind)
	A.exT = S.T
	D.exT = S.T
	ex.sA = A.stance   # R8: the stances hit() uses for the whole exchange
	ex.sD = D.stance
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	D.face = -A.face
	var dState: String = D.state
	A.state = "locked"
	D.state = "locked"
	D.dPrev = dState
	S.dirS.ex = ex
	S.dirS.exN += 1; ex.n = S.dirS.exN   # D1a (granted line): the exchange index for keyed draws (SimRng.keyed)
	SimWounds.onExchangeStart(S, ex)   # pitch A: which limbs were already battered (only those can be crippled)
	# The brink chapter: who was on the brink as it began (the exchange that causes a brink never sets up or finishes).
	for s in range(S.fighters.size()):
		if S.fighters[s].brink:
			ex.startBrink |= 1 << s
	var chk = null
	if planCheck.is_valid():
		chk = _planByCode(S, ex, "sig" if kind == "sig" else "melee")
	if kind == "sig":
		DirBeam.planBeam(S, ex)
	else:
		var fav: String = DirMelee.planMelee(S, ex)
		ex.loser = S.fighters.find(D) if fav == "attacker" else (S.fighters.find(A) if fav == "defender" else -1)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "sig" if kind == "sig" else "melee")
	var stanceLabel: String = "CHARGING" if dState == "charging" else STN[int(D.stance)]
	SimEvents.feed(S, A.name + " " + kind.to_upper() + " vs " + stanceLabel, ex.tag + ("  (ambush)" if A.ambush else ""))
	SimFx.attack(S, A, D, kind, stanceLabel, ex.tag, A.ambush)
	if A.ambush:
		SimFx.ambush(S, A, D)
		SimFx.danger(S, D, "ambush", 0.0)
	return STARTED


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
			if a.get("queue", false):
				SimAct.push(who, SimAct.LIGHT, who.act.mode, 0, S.tick)   # the AI's chain press is a queued request, as a player's is
			else:
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
		"cue":
			_opCue(S, ex, a)
		"contestOpen":
			_opContestOpen(S, ex, a)
		"finalBlow":
			_opFinalBlow(S, ex, a)
		"fixedLaunch":
			var fw2 = A if a.w == "A" else D
			var fl2 = D if a.w == "A" else A
			DirLaunch.doLaunch(S, fw2, fl2, {"ux": a.ux * (fw2.face if a.get("faceRelative", false) else 1.0), "uy": a.uy}, a.force, true)
		"separate":
			var sw = A if a.w == "A" else D
			var sl = D if a.w == "A" else A
			sw.vx = -sw.face * a.speed
			sl.vx = sw.face * a.speed
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
			if a.get("mode", "ko_now") == "branch":
				_opContestBranch(S, ex, a)
			else:
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
	SimFx.windowOpen(S, ex.A, "chain", 0.6, int(ex.combo))
	if ex.A.ai != null and S.rng.next() < SimMathx.jclamp(0.62 - 0.14 * ex.combo, 0.05, 0.6):
		schedule(ex, ex.t + S.rng.range_(0.12, 0.35), "press", {"who": "A", "queue": ex.A.act.v2})


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
	# S3b: a broken head dazes the fighter who lost the exchange (SimWounds.daze checks the head).
	if ex.loser >= 0 and S.game.ko == null:
		SimWounds.daze(S, S.fighters[ex.loser])
	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)


## Breathing room after an exchange (balance-targets.md section 10): 0.8 s after a quick exchange, rising with its
## length (ex.t, request to release) to at most 1.5 s. Was a flat 0.22 s.
const COOL_MIN: float = 0.25   # dynamic feel (docs/combat/dynamic-feel.md §2.2): was 0.8 + 0.3 per s, at most 1.5
const COOL_PER_SEC: float = 0.1
const COOL_MAX: float = 0.6


static func cooldownAfter(ex) -> float:
	return SimMathx.jclamp(COOL_MIN + COOL_PER_SEC * ex.t, COOL_MIN, COOL_MAX)


static func dirUpdate(S: SimState, dt: float) -> void:
	DirLocation.record(S, dt)   # location variety: the fight's time per biome
	# The time-cap stand-in (granted write): past contest.timeCapAt every decisive win against a fighter on the brink is a
	# finisher (decisive()). The full 11:00 event is Game Design's and Simulation's.
	var cap: float = DirData.timeCapAt()
	if cap > 0.0 and not S.game.timeCap and S.T >= cap:
		S.game.timeCap = true
		SimEvents.feed(S, "TIME CAP", "every decisive win on the brink is a finisher")
	_transforms(S)
	if S.dirS.cool > 0.0:
		S.dirS.cool -= dt
	_queues(S)   # step 2: upgrades, expiry, and the next queued request once the director can take it
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
	_struggleTick(S, ex)
	if ex.ext != null and S.T < ex.ext.until:
		var A = ex.A
		var inReach: bool = not (ex.D.state == "launched" and absf(SimWrap.sdx(A.x, ex.D.x)) > CHAIN_REACH)
		# The link: a v2 slot's next queued light or heavy request (pressed before or during the window: repeats queue a short
		# combo, with no timed press); otherwise a press inside the window, as before.
		var head: Array = SimAct.peek(A)
		var pressed: bool = (not head.is_empty() and int(head[0]) != SimAct.SIG) if A.act.v2 else A.lastAtkT >= ex.ext.start
		if pressed and ex.combo < 5.0 and A.ki >= 6.0 and inReach:
			if A.act.v2:
				SimAct.pop(A)
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
	SimWounds.onDecisive(S, ex, W, L, why)   # S4: Spite; pitch A: the crippling roll
	ex.loser = S.fighters.find(L)
	# The brink chapter (spec-wounds.md §1b). A win by the fighter on the brink closes its opening (Spite, above, fired
	# first; a Rally has already reset it). A win against it finishes it only once it is open, and in a later exchange
	# than the set-up; before that, a win is a set-up, and the exchange that caused the brink is neither.
	if W.brink and (W.brinkOpen or W.brinkSetups > 0):
		if W.brinkOpen:
			SimFx.brinkClose(S, W, "won")
		W.brinkOpen = false
		W.brinkSetups = 0
	if not L.brink or finisherPlanned(ex):
		return
	if S.game.timeCap or (L.brinkOpen and L.brinkEx != ex.n):
		startFinisher(S, ex, W, L)
	elif not L.brinkOpen and (ex.startBrink & (1 << S.fighters.find(L))) != 0 and L.brinkEx != ex.n:
		L.brinkSetups += 1
		L.brinkEx = ex.n
		if L.brinkSetups >= DirData.brinkSetups():
			_openBrink(S, W, L)


# ---------------------------------------------------------------- the placeholder transform (ADR 0008, I2b)

const TRANSFORM_HOLD: float = 0.8      # seconds: no exchange starts and the transformer holds still
const TRANSFORM_PUSH: float = 900.0    # the burst pushes an opponent within TRANSFORM_PUSH_R back at this speed
const TRANSFORM_PUSH_R: float = 700.0


## The input that takes a ready form: ai, power (the power hold: the Simple layout's assist, and today's keyboard and touch
## bridge, where it is the charge control) or triggers (the two-trigger chord of the v2 layouts).
static func transformSource(f) -> String:
	if f.ai != null:
		return "ai"
	if not f.act.v2 or f.act.assist != 0:
		return "power"
	return "triggers"


## Between exchanges, a fighter with a form ready takes it on the transform request: the transform edge, or, on a slot
## that has no v2 inputs yet (today's keyboard and touch bridge), the charge control held. The tier rises at once with
## today's power-up burst (SimFighter.transform), the opponent in reach is pushed back, and for TRANSFORM_HOLD no exchange
## starts and the transformer holds still (its stun gate). One transform a tick.
static func _transforms(S: SimState) -> void:
	if S.dirS.ex != null or S.game.ko != null:
		return
	for f in S.fighters:
		if not f.act.formReady or (f.state != "free" and f.state != "charging"):
			continue
		var i: SimIntent = f.input
		if not (i.transform or (not f.act.v2 and f.ai == null and i.charge)):
			continue
		var o = SimRoster.opp(S, f)
		SimFx.transform(S, f, f.tier + 1.0, transformSource(f), TRANSFORM_HOLD)
		SimFighter.transform(S, f)
		S.dirS.cool = SimMathx.jmax(S.dirS.cool, TRANSFORM_HOLD)
		f.state = "free"
		f.vx = 0.0
		f.vy = 0.0
		f.stunTicks = maxi(f.stunTicks, int(TRANSFORM_HOLD * DirData.TICKS_PER_SEC + 0.5))
		var d: float = SimWrap.sdx(f.x, o.x)
		if absf(d) < TRANSFORM_PUSH_R and (o.state == "free" or o.state == "charging"):
			o.vx = (1.0 if d >= 0.0 else -1.0) * TRANSFORM_PUSH
		SimEvents.feed(S, f.name + " TRANSFORMS", "tier " + SimMathx.jstr(f.tier))
		return


## The set-up is won: L, on the brink, is open to W's finisher. A stagger (the fighter's own stagger length) and a
## dropped guard (UI and Rendering, from the event); the finisher's kind telegraphs in brink_open.
static func _openBrink(S: SimState, W, L) -> void:
	L.brinkOpen = true
	L.stunTicks = maxi(L.stunTicks, L.wd.staggerTicks)
	SimFx.brinkOpen(S, L, W, DirData.finisherKind(W), DirData.finisherId(W))
	SimEvents.feed(S, L.name + " IS OPEN", W.name + " can finish on the next decisive win")


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
	SimFx.finisherStart(S, W, L, DirData.finisherDur(W))
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
		_closeOnSurvival(S, L)
		SimWounds.onContestSurvived(S, L)   # S4: Second Wind
	else:
		SimDamage.ko(S, L, W)


# ---------------------------------------------------------------- authored finishers (Combat's data, S3b)

## A render-only cue: the named fighter (W, L, A, D, or both), the camera hint and the bark trigger. No state, no RNG.
static func _opCue(S: SimState, ex, a) -> void:
	var who: String = String(a.get("who", "both"))
	var f = null
	if who == "A":
		f = ex.A
	elif who == "D":
		f = ex.D
	var bark = a.get("bark", "")
	SimFx.cue(S, f, String(a.cue), String(a.get("cam", "")), "" if bark == null else str(bark))


## The contest window opens (the struggle): a window_open of kind "contest" for the fighter on the brink, lasting until
## the contest beat, the struggle cue, and the struggle's record in the contest beat's args. An AI on the brink presses
## each beat with its hit chance (one draw per beat, here); a human's presses are scored as they come (_struggleTick).
static func _opContestOpen(S: SimState, ex, a) -> void:
	var L = ex.D if a.w == "A" else ex.A
	var cb = _contestBeat(ex)
	if cb == null:
		return
	SimFx.windowOpen(S, L, "contest", cb.t - ex.t)
	SimFx.cue(S, L, String(a.get("cue", "struggle")), "", "")
	var st: Dictionary = DirData.struggle()
	if st.is_empty():
		return
	cb.args["sOpen"] = S.T
	cb.args["sHits"] = 0.0
	cb.args["sStrays"] = 0.0
	cb.args["sLast"] = -99.0
	for i in range(3):
		cb.args["sBeat" + str(i)] = false
	if L.ai != null:
		var p: float = float(st.aiHitChance)
		for i in range(st.beatTicks.size()):
			if S.rng.next() < p:
				schedule(ex, ex.t + float(st.beatTicks[i]) / DirData.TICKS_PER_SEC, "press", {"who": "D" if L == ex.D else "A"})


static func _contestBeat(ex):
	for b in ex.beats:
		if not b.done and b.op == "contest":
			return b
	return null


## Scores the fighter on the brink's struggle presses (Controls' rulings section 8): a press matches the nearest unclaimed
## beat within the half-width (a hit), otherwise it is a stray; a press within the debounce of a scored press is ignored.
static func _struggleTick(S: SimState, ex) -> void:
	var cb = _contestBeat(ex)
	if cb == null or not cb.args.has("sOpen"):
		return
	var L = ex.D if cb.args.w == "A" else ex.A
	if L.lastAtkT != S.T:
		return
	var st: Dictionary = DirData.struggle()
	var rel: float = (S.T - float(cb.args.sOpen)) * DirData.TICKS_PER_SEC
	if rel - float(cb.args.sLast) < float(st.debounceTicks):
		return
	var best: int = -1
	var bestD: float = 1e9
	for i in range(st.beatTicks.size()):
		var dd: float = absf(rel - float(st.beatTicks[i]))
		if not cb.args["sBeat" + str(i)] and dd <= float(st.halfWidthTicks) and dd < bestD:
			best = i
			bestD = dd
	cb.args.sLast = rel
	if best >= 0:
		cb.args["sBeat" + str(best)] = true
		cb.args.sHits = float(cb.args.sHits) + 1.0
		SimFx.strugglePress(S, L, "hit", best + 1)
	else:
		cb.args.sStrays = float(cb.args.sStrays) + 1.0
		SimFx.strugglePress(S, L, "stray", 0)


## The contest in "branch" mode: one S.rng draw, as today; the chance comes from the struggle when the finisher opened one
## (base 15, +10 per hit, -5 per missed beat or stray), otherwise from the contest's base; then the tilt past 8:00. The
## outcome's beats (landed or survived) are scheduled from here; the KO happens at finalBlow.
static func _opContestBranch(S: SimState, ex, a) -> void:
	var W = ex.A if a.w == "A" else ex.D
	var L = ex.D if a.w == "A" else ex.A
	var cs: Dictionary = DirData.contest()
	var late: float = SimMathx.jmax(0.0, (S.T - float(cs.tiltAfter)) / 60.0)
	var chance: float
	if a.has("sOpen"):
		var sc: Dictionary = DirData.struggle().scoring
		var beats: float = float(DirData.struggle().beatTicks.size())
		var misses: float = beats - float(a.sHits)
		chance = float(sc.base) + float(sc.perHit) * float(a.sHits) + float(sc.perMiss) * misses + float(sc.perStray) * float(a.sStrays) - float(cs.tiltPerMinute) * late
	else:
		chance = float(cs.base) - float(cs.tiltPerMinute) * late
	# The Rally tilt (spec-wounds.md §1; contest.rallyPenalty): each Rally the fighter has used costs it 10 points.
	chance -= float(cs.get("rallyPenalty", 0.0)) * float(L.rallies)
	chance = SimMathx.jmax(float(cs.floor), chance)
	var survived: bool = S.rng.next() < chance
	SimFx.finisherContest(S, L, chance, survived)
	SimEvents.feed(S, L.name + (" SURVIVES" if survived else " FALLS"), "finisher contest, survival chance " + SimMathx.jstr(SimMathx.jround(chance * 100.0)) + "%")
	if survived:
		SimFx.banner(S, L.name + " HOLDS ON", L.aura, 1.2)
		_closeOnSurvival(S, L)
		SimWounds.onContestSurvived(S, L)   # S4: Second Wind
	DirData.scheduleOutcome(ex, W, not survived)


## The brink chapter: surviving a finisher closes the opening; the rival needs a new set-up.
static func _closeOnSurvival(S: SimState, L) -> void:
	if L.brinkOpen:
		SimFx.brinkClose(S, L, "survived")
	L.brinkOpen = false
	L.brinkSetups = 0


## The final blow: a strike W to L, then the launch (fixed, or the planner's long-haul candidates), then the KO. The launch
## comes first so ko() keeps it.
static func _opFinalBlow(S: SimState, ex, a) -> void:
	var W = ex.A if a.w == "A" else ex.D
	var L = ex.D if a.w == "A" else ex.A
	if S.game.ko != null:
		return
	DirMelee.strike(S, ex, W, L, float(a.dmg), a.o)
	var ln: Dictionary = a.launch
	if ln.get("mode", "") == "fixed":
		DirLaunch.doLaunch(S, W, L, {"ux": float(ln.ux) * (W.face if ln.get("faceRelative", false) else 1.0), "uy": float(ln.uy)}, float(ln.force), true)
	else:
		DirMelee.launchBeat(S, ex, W, L, float(ln.force), true)
	SimDamage.ko(S, L, W)
