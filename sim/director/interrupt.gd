class_name DirInterrupt
## Control-scheme step 3 (ADR 0008; control-rules.md sections 1, 2 and 6; docs/director/control-scheme-plan.md): what a
## fighter does inside an exchange, by an input of its own.
##  - The perfect block: a fresh guard press in the last ticks of a strike's wind-up. No damage; the attacker's string
##    ends and it staggers; the blocker's next attack is a riposte. A press outside a window locks it out for a while.
##  - The dodge-cancel: a dodge tap ends the exchange with no winner (the attacker at any time, the defender in a gap).
##  - The burst: a power tap shoves the rival away and ends the exchange. A guarding rival absorbs it.
##  - The reversal: the context button, in guard, just after a normal block: the defender's own heavy starts at once.
##  - A fully blocked string leaves its attacker behind for a few ticks: the guard's punish window.
##  - Staleness: the same attack many exchanges running winds up slower and is easier to perfect-block.
## The AI makes the same inputs by its level's numbers (DirAI.lv, data/director/ai.json). Nothing here runs in a profile
## without a perfectBlock block (the old profiles keep the parry), except the per-fighter state's bookkeeping.
##
## Per-fighter director state is f.act.dirI (integers, hashed; a granted field, sized here).

const PB_LOCK: int = 0      # S.tick until which a guard press cannot be a perfect block (the anti-mash lockout)
const REV_READY: int = 1    # S.tick from which the reversal is off cooldown
const OPEN_UNTIL: int = 2   # S.tick until which this fighter has an opening: its next attack starts at once ...
const OPEN_KIND: int = 3    # ... as OPEN_RIPOSTE, OPEN_RIPOSTE_LAUNCH or OPEN_PLAIN (a reversal, a punish)
const STALE_KEY: int = 4    # the last exchange this fighter started: weight, mode and direction
const STALE_N: int = 5      # exchanges in a row it started with that key
const BLOCKED: int = 6      # S.tick of its last normal block (the reversal's window)
const GUARDED: int = 7      # exchanges in a row it was attacked while guarding (the AI's "only guards" read)
const HIT_AT: int = 8       # S.tick it was last struck (the defender's dodge-cancel needs a gap)
const REV_TRIED: int = 9    # the exchange index in which the AI last weighed a reversal (one draw an exchange)
const LAST_START: int = 10  # the index of the last exchange it started (the queue's tie-break)
const WEIGHT_KEY: int = 11  # the weight of the last exchange it started ...
const WEIGHT_RUN: int = 12  # ... and how many it has started in a row with that weight (the AI's read of a repeated string)
const LANDED: int = 13      # strikes it has landed in the exchange now running (the earned launch)
const PHRASE_P: int = 14    # the press that started its exchange or its latest chain link, as the press log packs it
const TAKEN: int = 15       # blows it has taken unblocked in the exchange now running (a heavy "landing clean")
const LAST_END: int = 16    # how the last launch beat of its exchange ended: END_LAUNCH, END_KNOCK or END_STAY
const N: int = 17
const END_LAUNCH: int = 0
const END_KNOCK: int = 1
const END_STAY: int = 2
const NEVER: int = -100000
const OPEN_RIPOSTE: int = 1
const OPEN_RIPOSTE_LAUNCH: int = 2
const OPEN_PLAIN: int = 3
const BH: float = 75.0

const DATA_PATH: String = "res://data/director/interrupts.json"
const TIMING_PATH: String = "res://data/input/timing.json"
static var _data = null
static var _text: String = ""


## data/director/interrupts.json (costs, cooldowns, windows by strike class, staleness), plus Controls' perfect-block
## timing as data().timing (data/input/timing.json perfectBlock: the lockout and the assist factor).
static func data() -> Dictionary:
	if _data == null:
		_text = FileAccess.get_file_as_string(DATA_PATH)
		_data = JSON.parse_string(_text)
		var tt: String = FileAccess.get_file_as_string(TIMING_PATH)
		var tj = JSON.parse_string(tt)
		if _data == null or tj == null:
			push_error("DirInterrupt: could not parse " + DATA_PATH + " or " + TIMING_PATH)
			_data = {}
			return _data
		_data["timing"] = tj.perfectBlock
		_text += JSON.stringify(tj.perfectBlock)
	return _data


## The text the numbers came from, for DirData.dataHash() (the replay header).
static func dataText() -> String:
	data()
	return _text


## True in a profile that has the perfect block (dynamic). The old profiles keep the parry and none of this.
static func on() -> bool:
	return not DirData.perfectBlock().is_empty()


static func _size(f) -> void:
	if f.act.dirI.size() < N:
		f.act.dirI.resize(N)
		f.act.dirI[BLOCKED] = NEVER
		f.act.dirI[HIT_AT] = NEVER
		f.act.dirI[REV_TRIED] = -1
		f.act.dirI[STALE_KEY] = -1
		f.act.dirI[WEIGHT_KEY] = -1


static func gi(f, k: int) -> int:
	_size(f)
	return f.act.dirI[k]


static func si(f, k: int, v: int) -> void:
	_size(f)
	f.act.dirI[k] = v


## The opening f holds now (OPEN_*), or 0.
static func opening(S: SimState, f) -> int:
	return gi(f, OPEN_KIND) if S.tick < gi(f, OPEN_UNTIL) else 0


static func _open(S: SimState, f, kind: int, ticks: int) -> void:
	si(f, OPEN_UNTIL, S.tick + ticks)
	si(f, OPEN_KIND, kind)


# ---------------------------------------------------------------- staleness and the start of an exchange

## As A's attack starts (before it is planned): its repeat count, and the defender's guard run. Returns the ticks the
## repeat adds to the wind-up (control-rules.md section 6: after `after` exchanges with the same weight, mode and
## direction, windupPerRepeat ticks for each further one, at most windupMax).
static func onStart(S: SimState, ex, weight: int, mode: int, entry: int) -> int:
	var A = ex.A
	var D = ex.D
	si(A, LAST_START, ex.n)
	si(A, LANDED, 0)
	si(D, LANDED, 0)
	si(D, TAKEN, 0)
	si(A, TAKEN, 0)
	var pp: int = DirAlchemy.at(A, DirExchange.planTick if DirExchange.planTick >= 0 else S.tick)
	si(A, PHRASE_P, pp if pp >= 0 and (pp & 1) == mini(weight, 1) else mini(weight, 1))   # the press log's newest press, when it is this one
	si(A, LAST_END, END_LAUNCH)
	si(D, GUARDED, gi(D, GUARDED) + 1 if ex.sD == 1.0 else 0)
	si(A, WEIGHT_RUN, gi(A, WEIGHT_RUN) + 1 if gi(A, WEIGHT_KEY) == weight else 1)
	si(A, WEIGHT_KEY, weight)
	if not on() or weight == SimAct.SIG:
		si(A, STALE_KEY, -1)
		si(A, STALE_N, 0)
		return 0
	var key: int = weight + 4 * mode + 16 * (entry + 1)
	if gi(A, STALE_KEY) == key:
		si(A, STALE_N, gi(A, STALE_N) + 1)
	else:
		si(A, STALE_KEY, key)
		si(A, STALE_N, 1)
	var st: Dictionary = data().stale
	return mini(int(st.windupMax), int(st.windupPerRepeat) * maxi(0, gi(A, STALE_N) - int(st.after)))


## The ticks a's staleness adds to its rival's perfect-block window.
static func _staleWindow(a) -> int:
	var st: Dictionary = data().stale
	return mini(int(st.windowMax), int(st.windowPerRepeat) * maxi(0, gi(a, STALE_N) - int(st.after)))


# ---------------------------------------------------------------- the perfect block

## The window, in ticks before contact, in which f's fresh guard press perfect-blocks a strike of this class: the
## class's window (by the exchange's weight for an opener and a blast), times the assist, less two ticks for a
## one-armed guard, plus the class's early tolerance. -1 when the class has no window.
static func _window(f, cls: String, heavy: bool) -> float:
	var pb: Dictionary = data().perfectBlock
	if not pb.windows.has(cls):
		return -1.0
	var w = pb.windows[cls]
	var ticks: float = float(w.heavy if heavy else w.light) if w is Dictionary else float(w)
	if SimAct.assisted(f, "perfectBlockAssist"):
		ticks *= float(data().timing.assistFactor)
	if SimWounds.broken(f, SimWounds.ARMS):
		ticks -= float(pb.oneArmedOff)
	return ticks + float(pb.early.get(cls, pb.early["default"]))


## The pending beat f could perfect-block now, or null: a strike on f whose class has a window and whose wind-up is in
## its last ticks (plus the attacker's staleness); or, for the defender of a signature, the fire beat.
static func _windowBeat(S: SimState, ex, f):
	if ex == null:
		return null
	var tm: Dictionary = data().timing
	var k: float = float(tm.assistFactor) if SimAct.assisted(f, "perfectBlockAssist") else 1.0
	if ex.kind == "sig":
		if f != ex.D or ex.branch != "" or not DirData.beamAtFire():
			return null
		for b in ex.beats:
			if not b.done and b.op == "beamFire":
				var left: float = (b.t - ex.t) * DirData.TICKS_PER_SEC
				return b if left <= _window(f, "heavy", true) + 0.5 and not b.args.get("perfect", false) else null
		return null
	if not DirData.allows(ex, "perfect_block"):
		return null
	var role: String = "A" if f == ex.A else "D"
	# (the classes with a window are the keys of interrupts.json perfectBlock.windows)
	for b in ex.beats:
		if b.done or b.op != "strike" or b.args.d != role or b.args.o == null:
			continue
		var cls: String = String(b.args.o.get("class", ""))
		var w: float = _window(f, cls, ex.kind == "heavy")
		if w < 0.0 or b.args.o.get("perfect", false):
			continue
		w += float(_staleWindow(ex.A if b.args.a == "A" else ex.D))
		var left2: float = (b.t - ex.t) * DirData.TICKS_PER_SEC
		if left2 <= w + 0.5:
			return b
		return null   # the next strike with a window has not reached it yet
	return null


## A fresh guard press by f. Inside a window, and not locked out, it marks the strike: the block resolves when the
## strike lands. Outside a window, or during the lockout, it (re)starts the lockout. The guard itself is unaffected.
static func guardPress(S: SimState, f) -> bool:
	if not on():
		return false
	var b = _windowBeat(S, S.dirS.ex, f)
	var assist: bool = SimAct.assisted(f, "perfectBlockAssist")
	if b == null or (S.tick < gi(f, PB_LOCK) and not assist):
		if not assist:
			si(f, PB_LOCK, S.tick + int(data().timing.antiMashLockout))
		return false
	if b.op == "beamFire":
		b.args["perfect"] = true
	else:
		b.args.o["perfect"] = true
	return true


## The marked strike lands: a's strike is perfect-blocked by d (DirMelee.strike calls this in place of the hit).
static func perfectBlock(S: SimState, ex, a, d, o: Dictionary) -> void:
	var pb: Dictionary = DirData.perfectBlock()
	var c: Dictionary = data().perfectBlock
	_takeOver(ex)
	ex.loser = S.fighters.find(a)
	d.ki = SimMathx.jmin(100.0, d.ki + float(c.ki))
	a.stunTicks = maxi(a.stunTicks, int(pb.staggerTicks))
	a.rush = null
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, float(c.stopTicks) / DirData.TICKS_PER_SEC)
	var cls: String = String(o.get("class", ""))
	var launch: bool = cls == "heavy" or cls == "ender" or ex.kind == "heavy"
	_open(S, d, OPEN_RIPOSTE_LAUNCH if launch else OPEN_RIPOSTE, int(pb.riposteTicks))
	SimFx.cue(S, d, "perfect_block", "", "")
	SimFx.ring(S, a.x + a.face * 30.0, a.y + 34.0, 700.0, "#9fe0ff", 0.4, 10.0)
	SimFx.banner(S, "PERFECT BLOCK", "#9fe0ff", 0.8)
	SimEvents.feed(S, d.name + " PERFECT BLOCK", a.name + " staggers; the next attack is a riposte" + (" that launches" if launch else ""))
	SimFx.parry(S, d, a)   # the mood and Pride read it as a parry
	if d.ai != null and S.rng.next() < DirAI.lv().riposte:
		DirAlchemy.log(S, d, SimAct.HEAVY if launch else SimAct.LIGHT, d.act.mode)
		SimAct.push(d, SimAct.HEAVY if launch else SimAct.LIGHT, d.act.mode, 0, S.tick)


## The defender of a signature perfect-blocked the fire beat: a DEFLECT (DirBeam.opBeamFire). No damage, no stagger, no riposte.
static func deflect(S: SimState, d) -> void:
	d.ki = SimMathx.jmin(100.0, d.ki + float(data().perfectBlock.ki))
	SimFx.cue(S, d, "perfect_block", "", "")
	SimFx.banner(S, "DEFLECT", "#9fe0ff", 0.8)


## The exchange is taken over: nothing pending runs, the chain window is shut, and it ends this tick.
static func _takeOver(ex) -> void:
	for b in ex.beats:
		b.done = true
	ex.ext = null
	ex.cancel = true


# ---------------------------------------------------------------- once a live tick, before the beats

## The inputs of the tick, in the ruled order: perfect block, reversal, dodge-cancel, burst, the defender before the
## attacker. An input that comes after a takeover on the same tick is not charged.
static func tick(S: SimState) -> void:
	if S.game.ko != null or not on():
		return
	var ex = S.dirS.ex
	var order: Array = [ex.D, ex.A] if ex != null else S.fighters
	for f in order:
		if _human(f) and f.input.guardPress:
			guardPress(S, f)
	if ex != null:
		_aiBlocks(S, ex)
	var taken: bool = false
	for f in order:
		if not taken and _human(f) and f.input.context and f.input.guard:
			taken = reversal(S, ex, f)
	for f in order:
		if not taken and _human(f) and f.input.dodge:
			taken = dodgeCancel(S, ex, f)
	for f in order:
		if taken or not _human(f):
			continue
		var threatened: bool = ex != null and (f == ex.D or S.tick - gi(f, HIT_AT) <= int(data().burst.threatTicks))
		if _canBurst(S, f) and SimAct.wantsBurst(f, f.input, threatened):
			taken = burst(S, f)


static func _human(f) -> bool:
	return f.ai == null and f.act.v2 and f.stunTicks <= 0


## The AI's perfect block: once for each strike with a window, one draw against R5's rate for the state it holds
## (plus heavyAdd against a heavy or an ender), times its level's share (moveset-rules.md section 11(g)).
static func _aiBlocks(S: SimState, ex) -> void:
	if ex.kind == "sig":
		return
	for f in [ex.D, ex.A]:
		if f.ai == null or f.stunTicks > 0:
			continue
		var b = _windowBeat(S, ex, f)
		if b == null or b.args.o.get("weighed", false):
			continue
		if (b.t - ex.t) * DirData.TICKS_PER_SEC > 6.5:
			continue   # it presses well inside the window, not in the early tolerance
		b.args.o["weighed"] = true
		var lv: Dictionary = DirAI.lv()
		var st: int = int(f.ai.st)
		var r5: Dictionary = DirAI.skill().perfectBlock
		var p: float = float(r5.guard) if st == 1 else (float(r5.press) if st == 0 else 0.0)
		if p > 0.0 and (String(b.args.o.get("class", "")) != "opener" or ex.kind == "heavy"):
			p += float(r5.heavyAdd)
		if p > 0.0 and S.rng.next() < p * float(lv.perfectBlockMul):
			guardPress(S, f)


# ---------------------------------------------------------------- the dodge-cancel

static func dodgeCancel(S: SimState, ex, f) -> bool:
	if ex == null or ex.kind == "sig" or (f != ex.A and f != ex.D) or DirExchange.finisherPlanned(ex):
		return false
	var c: Dictionary = data().dodgeCancel
	# The attacker's cancel is free until his first wind-up starts (agency-pass.md section 1): he was flown in by the
	# director and may call it off. It still starts the short gap between dodges.
	var free: bool = c.get("freeBeforeWindup", false) and f == ex.A and ex.combo <= 1.0 and _beforeWindup(ex)
	if (not free and f.ki < float(c.ki)) or f.act.dodgeCool > 0 or f.state == "launched" or f.state == "down":
		return false
	if f == ex.D and S.tick - gi(f, HIT_AT) < int(c.gapTicks):
		return false   # the defender cancels only in a gap between strikes, never in hit-stun
	if free:
		f.act.dodgeCool = int(c.freeGapTicks)
	else:
		f.ki -= float(c.ki)
		f.act.dodgeCool = int(c.cooldownTicks)
	_takeOver(ex)
	ex.loser = -1
	ex.A.rush = null
	ex.D.rush = null
	var o = ex.D if f == ex.A else ex.A
	var mx: float = f.input.mx
	var my: float = f.input.my
	if mx == 0.0 and my == 0.0:
		mx = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)   # no direction held: away from the rival
	var l: float = SimDetMath.hypot(mx, my)
	f.vx = mx / l * float(c.dash)
	f.vy = my / l * float(c.dash)
	SimFx.afterimage(S, f)
	SimFx.cue(S, f, "dodge_cancel", "", "")
	SimEvents.feed(S, f.name + " DODGE-CANCEL", "the exchange ends with no winner")
	return true


## True until the exchange's first wind-up starts: its wind beat is still pending.
static func _beforeWindup(ex) -> bool:
	for b in ex.beats:
		if b.op == "wind":
			return not b.done
	return false


# ---------------------------------------------------------------- the burst

static func _canBurst(S: SimState, f) -> bool:
	var c: Dictionary = data().burst
	var ex = S.dirS.ex
	if f.ki < float(c.ki) or f.act.burstCool > 0 or f.state == "launched" or f.state == "down":
		return false
	return ex == null or (ex.kind != "sig" and not DirExchange.finisherPlanned(ex))


## f bursts: a shove all round. A rival holding guard absorbs it and f staggers (the bait). Otherwise a rival in
## range is pushed away, and an exchange between them ends with no winner. No damage.
static func burst(S: SimState, f) -> bool:
	if not _canBurst(S, f):
		return false
	var c: Dictionary = data().burst
	var ex = S.dirS.ex
	var o = SimRoster.opp(S, f)
	f.ki -= float(c.ki)
	f.act.burstCool = int(c.cooldownTicks)
	SimFx.ring(S, f.x, f.y + 34.0, float(c.rangeBh) * BH * 2.0, f.aura, 0.5, 14.0)
	if o.input.guard and o.stunTicks <= 0:
		f.stunTicks = maxi(f.stunTicks, int(c.baitStaggerTicks))
		SimFx.cue(S, f, "burst_absorbed", "", "")
		SimEvents.feed(S, f.name + " BURST", o.name + " was guarding and absorbs it; " + f.name + " staggers")
		return false
	var dx: float = SimWrap.sdx(f.x, o.x)
	if absf(dx) <= float(c.rangeBh) * BH and absf(o.y - f.y) <= float(c.rangeBh) * BH and o.state != "launched":
		o.rush = null
		o.vx = SimDamage.jor(SimMathx.jsign(dx), f.face) * float(c.pushSpeed)
	if ex != null:
		_takeOver(ex)
		ex.loser = -1
		ex.A.rush = null
		ex.D.rush = null
	SimFx.cue(S, f, "burst", "", "")
	SimEvents.feed(S, f.name + " BURST", "a shove; no damage, no winner")
	return true


## A chain reaches its next link: the AI defender, or a Simple-layout slot that pressed nothing, bursts out at its link.
static func onChainLink(S: SimState, ex) -> void:
	if not on():
		return
	var D = ex.D
	var at: int = int(DirAI.lv().burstAtLink) if D.ai != null else (int(data().burst.autoLink) if SimAct.assisted(D, "autoBurst") else 0)
	if at > 0 and int(ex.combo) >= at:
		burst(S, D)


# ---------------------------------------------------------------- the reversal and the punish window

## True when the attacker's last blow in this exchange was blocked: a blocked string opens no chain window (a chain
## follows a hit), and its attacker is left behind instead (onEnd).
static func lastBlowBlocked(S: SimState, ex) -> bool:
	var t0: int = S.tick - int(ex.t * DirData.TICKS_PER_SEC + 0.5) - 1
	return on() and gi(ex.D, BLOCKED) >= t0 and gi(ex.D, BLOCKED) == gi(ex.D, HIT_AT)


## d took a normal block (DirMelee.strike). The AI weighs its reversal once an exchange (R4's rates at medium).
static func onBlock(S: SimState, ex, d) -> void:
	si(d, BLOCKED, S.tick)
	if not on() or d.ai == null or d != ex.D or gi(d, REV_TRIED) == ex.n:
		return
	si(d, REV_TRIED, ex.n)
	if not _canReverse(S, ex, d):
		return
	var rv: Array = DirAI.lv().reversal
	var patient: bool = d.act.guardSince >= 0 and S.tick - d.act.guardSince >= int(data().reversal.patientTicks) and d.ki > 25.0
	if S.rng.next() < float(rv[0] if patient else rv[1]):
		reversal(S, ex, d)


static func _cost(S: SimState, f) -> float:
	var c: Dictionary = data().reversal
	return float(c.kiPatient) if f.act.guardSince >= 0 and S.tick - f.act.guardSince >= int(c.patientTicks) else float(c.ki)


static func _canReverse(S: SimState, ex, f) -> bool:
	if ex == null or f != ex.D or not DirData.allows(ex, "reversal"):
		return false
	var c: Dictionary = data().reversal
	return S.tick - gi(f, BLOCKED) <= int(c.afterBlockTicks) and S.tick >= gi(f, REV_READY) and f.ki >= _cost(S, f)


## The guard-cancel counter: the attacker's string ends, and after a short turn the defender's own heavy starts at once,
## planned against the attacker as it then stands (it has no press of its own: its queue is dropped).
static func reversal(S: SimState, ex, f) -> bool:
	if not _canReverse(S, ex, f):
		return false
	var c: Dictionary = data().reversal
	f.ki -= _cost(S, f)
	si(f, REV_READY, S.tick + int(c.cooldownTicks))
	_takeOver(ex)
	ex.loser = -1
	SimAct.clear(ex.A)
	ex.A.stunTicks = maxi(ex.A.stunTicks, int(c.delayTicks) + int(c.landTicks))
	f.stunTicks = maxi(f.stunTicks, int(c.delayTicks))
	_open(S, f, OPEN_PLAIN, int(c.delayTicks) + int(c.landTicks))
	SimAct.clear(f)
	DirAlchemy.log(S, f, SimAct.HEAVY, f.act.mode)
	SimAct.push(f, SimAct.HEAVY, f.act.mode, 0, S.tick)
	SimFx.cue(S, f, "reversal", "", "")
	SimFx.banner(S, "REVERSAL", "#ffd45a", 0.8)
	SimEvents.feed(S, f.name + " REVERSAL", "guard-cancel: its own heavy starts")
	return true


## An exchange ends (DirExchange.endEx). A string that was blocked to its end leaves its attacker behind: it cannot act
## for behindTicks, and the guard has that long to start an attack at once. The AI takes it by its level's rate.
static func onEnd(S: SimState, ex) -> void:
	if not on() or ex.cancel or S.game.ko != null or not ex.tag.begins_with("PRESSURE"):
		return
	var n: int = int(data().blockedString.behindTicks)
	ex.A.stunTicks = maxi(ex.A.stunTicks, n)
	_open(S, ex.D, OPEN_PLAIN, n)
	var lv: Dictionary = DirAI.lv()
	if ex.D.ai != null and S.rng.next() < float(lv.punish):
		var pw: int = SimAct.HEAVY if S.rng.next() < float(lv.punishHeavy) else SimAct.LIGHT
		DirAlchemy.log(S, ex.D, pw, ex.D.act.mode)
		SimAct.push(ex.D, pw, ex.D.act.mode, 0, S.tick)
