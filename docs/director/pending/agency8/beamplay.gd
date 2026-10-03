class_name DirBeamPlay
## The beam plays (agency-pass.md section 5; rule-of-cool.md section 2; Combat's wave 5 answers). A signature that is
## not answered in its tell leaves at the fire beat and reaches the defender travelTicks later, at any distance. What he
## did is read on the tick it reaches him:
##  - A late answer: his own signature, or a heavy energy attack, in the first late.ticks after it left stops the beam in
##    a struggle that starts late.scoreAdd down for him.
##  - A perfect block (a fresh guard press in the last ticks of the tell; perfectBlock.windows.beam) is a DEFLECT with
##    one of three looks, by the direction he holds as the beam reaches him: away, he swats it aside; level, it splits
##    round him; toward, he walks through it. None costs ki or takes damage.
##  - A dodge tap in the last dodge.beforeTicks of the tell or the first dodge.afterTicks of the beam avoids it. No roll.
##  - A held guard takes guard damage, as before. Held with the stick toward, he wades through at guard damage and is
##    not launched.
##  - Otherwise the old rules decide (the escape gamble, the hit).
## The walk and the wade take him to contact distance in front of the attacker, who is left walk.recoverTicks of recovery.
## State: the defender's BEAM_AI and BEAM_FIRE, the attacker's BEAM_TRAVEL and BEAM_REACH (DirInterrupt). Numbers:
## data/director/interrupts.json `beamPlays`; the AI's rates: data/director/ai.json.

const TOWARD: int = 1
const LEVEL: int = 0
const AWAY: int = 2
const AI_PERFECT: int = 1    # BEAM_AI: it perfect-blocks this beam
const AI_DODGE: int = 2      # ... its dodge, if it dodges, is in time
const AI_WADE: int = 4       # ... guarding, it holds toward
const AI_LOOK: int = 4       # ... the look of its perfect block, in bits 4 and 5 (LEVEL, TOWARD, AWAY)
const FRONT_SEC: float = 0.22   # a beam's time to its full length at its own speed (DirBeam.beamStep)


static func data() -> Dictionary:
	return DirInterrupt.data().get("beamPlays", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false) and DirData.beamAtFire()


static func _beat(ex, op: String):
	for b in ex.beats:
		if not b.done and b.op == op:
			return b
	return null


## The direction f holds, relative to his rival o.
static func held(f, o) -> int:
	var m: float = f.input.mx * SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)
	return TOWARD if m > SimAct.awayDead else (AWAY if m < -SimAct.awayDead else LEVEL)


# ---------------------------------------------------------------- the beam on its way

## The fire beat with no answer in the tell (DirBeam.opBeamFire): the beam leaves. Nothing is decided yet.
static func fire(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	var tv: int = int(data().travelTicks)
	var dist: float = args.dist
	var len: float = SimMathx.jmin(4200.0 * SimConst.WS, dist + float(A.ld.beamOvershoot[DirBeam._tierIx(A)]) * SimConst.WS)
	var ox: float = A.x
	var oy: float = A.y + 38.0
	var dxs: float = SimWrap.sdx(ox, D.x)
	var dyy: float = (D.y + 36.0) - oy
	var L: float = SimDamage.jor(SimDetMath.hypot(dxs, dyy), 1.0)
	DirBeam.fireBeam(S, A, ox, oy, dxs / L, dyy / L, len, String(args.variant))
	var b = S.beams[S.beams.size() - 1]
	b.life += float(tv) * SimConst.DT   # it lasts as long past him as it did
	DirInterrupt.si(A, DirInterrupt.BEAM_TRAVEL, tv)
	DirInterrupt.si(A, DirInterrupt.BEAM_REACH, int(SimMathx.jmin(L, len)))
	DirInterrupt.si(D, DirInterrupt.BEAM_FIRE, S.tick)
	DirInterrupt.si(D, DirInterrupt.BEAM_DODGED, 1 if D.act.dodgeTick >= S.tick - int(data().dodge.beforeTicks) else 0)   # a tap in the last ticks of the tell
	var perfect: bool = args.get("perfect", false) or (D.ai != null and (DirInterrupt.gi(D, DirInterrupt.BEAM_AI) & AI_PERFECT) != 0)
	SimEvents.feed(S, A.sigName + " FIRES", "it reaches " + D.name + " in " + str(tv) + " ticks")
	SimFx.cue(S, A, "beam_fire", "", "")
	DirExchange.schedule(ex, ex.t + float(tv) / DirData.TICKS_PER_SEC, "beamReach", {"perfect": perfect, "ux": dxs / L, "uy": dyy / L, "dist": dist, "variant": String(args.variant)})


## The ticks beam b takes to reach the defender, when it is a fighter's main beam under the plays; otherwise 0.
static func travel(S: SimState, b) -> int:
	var tv: int = DirInterrupt.gi(b.A, DirInterrupt.BEAM_TRAVEL)
	if tv <= 0:
		return 0
	for o in S.beams:
		if o.A == b.A:
			return tv if o == b else 0   # his first beam is the main one; a split's forks follow it
	return 0


## How far along its length that beam's front is: it reaches the defender at tv ticks, then goes on at a beam's own speed.
static func front(b, tv: int) -> float:
	var t1: float = float(tv) * SimConst.DT
	var share: float = SimMathx.jmin(1.0, float(DirInterrupt.gi(b.A, DirInterrupt.BEAM_REACH)) / b.len)
	if b.t <= t1:
		return share * b.t / t1
	return SimMathx.jmin(1.0, share + (b.t - t1) / FRONT_SEC)


static func _main(S: SimState, A):
	for b in S.beams:
		if b.A == A:
			return b
	return null


## The main beam ends where it has reached.
static func _stop(A, b) -> void:
	DirInterrupt.si(A, DirInterrupt.BEAM_TRAVEL, 0)
	if b != null:
		b.len = SimMathx.jmax(1.0, b.p * b.len)
		b.p = 1.0


## A beam that comes off src at (ox, oy): a fork of a split, or a swatted beam. It keeps src's colour, variant, structure
## factor and what is left of its life; owner is credited with what it does.
static func _spawn(S: SimState, src, owner, ox: float, oy: float, ux: float, uy: float, len: float, wMul: float, pwMul: float, cap: int) -> void:
	var b := SimState.Beam.new()
	b.A = owner; b.ox = ox; b.oy = oy; b.ux = ux; b.uy = uy; b.len = len
	b.p = 0.0; b.t = 0.0; b.life = SimMathx.jmax(0.3, src.life - src.t)
	b.w = src.w * wMul; b.variant = src.variant; b.col = src.col
	b.pw = src.pw * pwMul; b.sf = src.sf; b.cap = cap
	S.beams.append(b)


# ---------------------------------------------------------------- the late answer

## Once a live tick of a signature (DirExchange.dirUpdate): while the beam is on its way, a dodge tap in its first ticks
## is kept (a later tap does not undo it), and the defender's own signature or heavy energy attack stops it in a
## struggle. He starts late.scoreAdd down, on top of a heavy blast's own handicap.
static func lateTick(S: SimState, ex) -> void:
	if ex.kind != "sig" or ex.branch != "" or S.game.ko != null or not on():
		return
	var rb = _beat(ex, "beamReach")
	if rb == null:
		return
	var A = ex.A
	var D = ex.D
	if D.act.dodgeTick == S.tick and S.tick - DirInterrupt.gi(D, DirInterrupt.BEAM_FIRE) <= int(data().dodge.afterTicks):
		DirInterrupt.si(D, DirInterrupt.BEAM_DODGED, 1)
	if S.tick - DirInterrupt.gi(D, DirInterrupt.BEAM_FIRE) > int(data().late.ticks):
		return
	var answer: String = DirBeam._answer(S, D)
	if answer == "none":
		return
	rb.done = true
	for i in range(S.beams.size() - 1, -1, -1):
		if S.beams[i].A == A:
			S.beams.remove_at(i)
	DirInterrupt.si(A, DirInterrupt.BEAM_TRAVEL, 0)
	var res: Dictionary = DirData.beamOutcome(S, ex, float(rb.args.dist), answer, false)
	_decided(S, ex, "CLASH", "a late answer (" + answer + "): " + D.name + " starts " + str(int(round(-(float(res.dAdd) + float(data().late.scoreAdd))))) + " down")
	SimFx.cue(S, D, "beam_late", "", "")
	DirBeam.startClash(S, ex, String(rb.args.variant), float(res.dAdd) + float(data().late.scoreAdd))


static func _decided(S: SimState, ex, out: String, how: String) -> void:
	ex.branch = out
	ex.tag += " → " + out
	DirBeam._setLoser(S, ex, out)
	SimEvents.feed(S, ex.A.sigName + " → " + out, how)
	SimFx.beamOutcome(S, ex.A, ex.D, out)


# ---------------------------------------------------------------- the beam reaches him

## Beat "beamReach": the outcome, from what the defender did and what he holds now.
static func opReach(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	if S.game.ko != null:
		return
	var c: Dictionary = data()
	var dir: int = held(D, A)
	var dodged: bool = DirInterrupt.gi(D, DirInterrupt.BEAM_DODGED) != 0   # a tap in the window, kept when it came (fire, lateTick)
	var out: String = "DODGE"
	var look: String = ""
	var how: String = "a dodge in time"
	if args.perfect:
		out = "DEFLECT"
		look = "walk" if dir == TOWARD else ("swat" if dir == AWAY else "split")
		how = "a perfect block, " + ("the stick toward: he walks through it" if dir == TOWARD else ("the stick away: he swats it aside" if dir == AWAY else "the stick level: it splits round him"))
	elif not dodged:
		out = String(DirData.beamOutcome(S, ex, float(args.dist), "none", false, true).out)
		how = "no answer"
		if out == "GUARD":
			how = "a held guard"
			if dir == TOWARD:
				look = "wade"
				how = "a held guard, the stick toward: he wades through it"
	_decided(S, ex, out, how)
	var after: float = float(c.afterTicks) / DirData.TICKS_PER_SEC
	var b = _main(S, A)
	if look == "":
		if out == "HIT" or out == "GUARD":
			if out == "GUARD":
				ex.sD = 1.0   # the guard he holds now, not his state when the tell began
			DirBeam.opBeamImpact(S, ex, {"out": out, "ux": args.ux, "uy": args.uy})
		elif out == "DODGE":
			DirBeam.opBeamDodge(S, ex, null)
		else:
			DirBeam.opBeamEscape(S, ex, null)
		DirExchange.schedule(ex, ex.t + after, "nop")
		return
	if look == "split" or look == "swat":
		DirInterrupt.deflect(S, D)
		SimFx.cue(S, D, "beam_" + look, "", "")
		_stop(A, b)
		if b != null and look == "split":
			_split(S, b, A, D, args)
		elif b != null:
			_swat(S, b, A, D)
		DirExchange.schedule(ex, ex.t + after, "nop")
		return
	# The walk (clean) and the wade (at guard damage): he advances through the beam to contact distance.
	if look == "wade":
		ex.sD = 1.0
		SimDamage.hit(S, ex, A, D, 200.0 * DirBeam.sigDamageMul(), {"stop": 0.08, "shake": 12.0, "big": true})
		if S.game.ko != null:
			return
		D.state = "locked"
	else:
		DirInterrupt.deflect(S, D)
	SimFx.cue(S, D, "beam_" + look, "", "")
	ex.loser = S.fighters.find(A)
	var w: Dictionary = c.walk
	var far: float = SimDetMath.hypot(SimWrap.sdx(D.x, A.x), A.y - D.y)
	var n: int = clampi(int(ceil(far / float(w.speed) * DirData.TICKS_PER_SEC)), int(w.minTicks), int(w.maxTicks))
	var r := SimState.Rush.new()
	r.tgt = A
	r.off = DirMelee.sideOff(D, A, float(DirData.contact().get("offset", 60.0)), "own")
	r.end = S.T + float(n) * SimConst.DT
	D.rush = r
	SimFx.rush(S, D, A, S.tick + n)
	if b != null:
		b.life = SimMathx.jmax(b.life, b.t + float(n) * SimConst.DT)   # the beam lasts as long as his walk
	DirExchange.schedule(ex, ex.t + float(n) / DirData.TICKS_PER_SEC, "beamArrive", {"look": look})


## The split: the beam parts round him. Two lesser beams leave from where he stands, either side of its line, and scar
## the ground behind him. They are the attacker's, and share what is left of the beam's cap on buildings.
static func _split(S: SimState, b, A, D, args) -> void:
	var c: Dictionary = data().split
	var a: float = float(c.spreadDeg) * PI / 180.0
	var cs: float = SimDetMath.cos(a)
	var sn: float = SimDetMath.sin(a)
	var ux: float = args.ux
	var uy: float = args.uy
	var rem: int = maxi(0, b.cap - b.levelled) if b.cap >= 0 else -1
	var len: float = float(c.lenBh) * DirInterrupt.BH
	_spawn(S, b, A, D.x, D.y + 36.0, ux * cs - uy * sn, ux * sn + uy * cs, len, float(c.widthMul), float(c.powerMul), (rem + 1) / 2 if rem >= 0 else -1)
	_spawn(S, b, A, D.x, D.y + 36.0, ux * cs + uy * sn, -ux * sn + uy * cs, len, float(c.widthMul), float(c.powerMul), rem / 2 if rem >= 0 else -1)


## The swat: the beam is turned aside from where he stands, and the director picks where it goes. A fighter pressured by
## collateral sends it at the sky; one who feeds on collateral sends it at the nearest standing building in reach; anyone
## else, or with no building near, into the ground beyond him. It is the swatter's: it counts against the beam's own cap
## and what it does is credited to him.
static func _swat(S: SimState, b, A, D) -> void:
	var c: Dictionary = data().swat
	var len: float = float(c.lenBh) * DirInterrupt.BH
	var away: float = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(D.x, A.x)), D.face)
	var oy: float = D.y + 36.0
	var g: float = float(c.groundDeg) * PI / 180.0
	var ux: float = away * SimDetMath.cos(g)
	var uy: float = -SimDetMath.sin(g)
	var where: String = "into the ground"
	if D.hasAnguish:
		var s: float = float(c.skyDeg) * PI / 180.0
		ux = away * SimDetMath.cos(s)
		uy = SimDetMath.sin(s)
		where = "at the sky"
	elif D.hasMenace:
		var best = null
		var bestD: float = len
		for bd in S.buildings:
			if not bd.alive:
				continue
			var dx: float = absf(SimWrap.sdx(D.x, bd.x))
			if dx < bestD and dx > bd.w * 0.5:
				bestD = dx
				best = bd
		if best != null:
			var tx: float = SimWrap.sdx(D.x, best.x)
			var ty: float = WorldTerrain.groundY(S, best.x) + best.h * 0.5 - oy
			var l: float = SimDamage.jor(SimDetMath.hypot(tx, ty), 1.0)
			ux = tx / l
			uy = ty / l
			where = "at a building"
	SimEvents.feed(S, D.name + " SWATS IT", where)
	_spawn(S, b, D, D.x, oy, ux, uy, len, 1.0, 1.0, maxi(0, b.cap - b.levelled) if b.cap >= 0 else -1)


## Beat "beamArrive": he is through. The beam ends, and the attacker is left in recovery.
static func opArrive(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	D.rush = null
	for b in S.beams:
		if b.A == A:
			b.life = SimMathx.jmin(b.life, b.t)
	if S.game.ko != null:
		return
	var n: int = int(data().walk.recoverTicks)
	A.stunTicks = maxi(A.stunTicks, n)
	SimFx.cue(S, D, "beam_arrive", "", "")
	SimEvents.feed(S, D.name + (" WADES THROUGH" if String(args.look) == "wade" else " WALKS THROUGH"), A.name + " has " + str(n) + " ticks of recovery left")


## The exchange ends (DirExchange.endEx): after a walk or a wade there is no pause before the next exchange, so the
## attacker's recovery is the defender's to use.
static func onEnd(S: SimState, ex) -> void:
	if ex.kind != "sig":
		return
	for b in ex.beats:
		if b.op == "beamArrive":
			S.dirS.cool = 0.0


# ---------------------------------------------------------------- the AI defender

## As a signature starts charging at an AI (DirBeam.opBeamCharge): what it will do about this beam, drawn once.
## answers: it already chose to answer in the tell.
static func aiPlan(S: SimState, ex, answers: bool) -> void:
	var D = ex.D
	if not on() or D.ai == null:
		return
	var lv: Dictionary = DirAI.lv()
	var sk: Dictionary = DirAI.skill()
	var st: int = int(D.ai.st)
	var plan: int = 0
	var r5: Dictionary = sk.perfectBlock
	var p: float = float(r5.guard) if st == 1 else (float(r5.press) if st == 0 else 0.0)
	if p > 0.0:
		p += float(r5.heavyAdd)
	if S.rng.next() < p * float(lv.perfectBlockMul):
		plan |= AI_PERFECT
	var lk: Dictionary = sk.get("beamLook", {})
	plan |= DirAI.pickW(S, [float(lk.get("split", 1.0)), float(lk.get("walk", 1.0)), float(lk.get("swat", 1.0))]) << AI_LOOK
	if S.rng.next() < float(lv.get("beamDodge", 0.0)):
		plan |= AI_DODGE
	if S.rng.next() < float(lv.get("beamWade", 0.0)):
		plan |= AI_WADE
	DirInterrupt.si(D, DirInterrupt.BEAM_AI, plan)
	var canSig: bool = (D.ki >= 45.0 and S.T >= D.sigReadyT) or SimFighter.sigFree(D)
	var late: bool = S.rng.next() < float(lv.get("beamLate", 0.0))
	var fb = _beat(ex, "beamFire")
	if late and not answers and fb != null and (plan & AI_PERFECT) == 0 and (canSig or D.ki >= 40.0):
		var k: float = S.rng.range_(2.0, SimMathx.jmax(3.0, float(data().late.ticks) - 4.0))
		DirExchange.schedule(ex, fb.t + k / DirData.TICKS_PER_SEC, "press", {"who": "D", "sig": canSig, "blast": not canSig})


## False while an AI defender whose dodge is not in time would tap inside the window: it taps too early or too late.
static func aiMayDodge(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	if ex == null or ex.kind != "sig" or ex.D != f or ex.branch != "" or not on():
		return true
	if (DirInterrupt.gi(f, DirInterrupt.BEAM_AI) & AI_DODGE) != 0:
		return true
	var c: Dictionary = data().dodge
	var fb = _beat(ex, "beamFire")
	if fb != null:
		return (fb.t - ex.t) * DirData.TICKS_PER_SEC > float(c.beforeTicks) + 0.5
	return S.tick - DirInterrupt.gi(f, DirInterrupt.BEAM_FIRE) > int(c.afterTicks)


## The stick an AI defender holds as a beam comes: the look of its perfect block, or toward when it wades. 0: nothing.
static func aiDir(S: SimState, f) -> float:
	var ex = S.dirS.ex
	if ex == null or ex.kind != "sig" or ex.D != f or ex.branch != "" or not on():
		return 0.0
	var plan: int = DirInterrupt.gi(f, DirInterrupt.BEAM_AI)
	var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, ex.A.x)), f.face)
	if (plan & AI_PERFECT) != 0:
		var lk: int = (plan >> AI_LOOK) & 3
		return s if lk == TOWARD else (-s if lk == AWAY else 0.0)
	return s if (int(f.ai.st) == 1 and (plan & AI_WADE) != 0) else 0.0
