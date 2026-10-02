class_name DirBury
## The buried fighter (agency-pass.md sections 7 and 14.5; World's embed, docs/world/ground-contact.md section 19). A
## hard impact drives a fighter into its crater: World holds him down for its embed ticks (Fighter.embedT). The
## director's part:
##  - The free follow-up is a dive with a time limit and no distance limit: his rival presses within followTicks, the
##    director flies him to the crater at dive.speed, and the blow must land by landByTick of the burial. If he cannot
##    arrive in time there is no follow-up. It lands clean, deepens the crater and does not launch.
##  - A blast is the other free blow: with the energy family held, the press sends a charged shot into the crater. It
##    arrives from any distance (the shot's own rule) and is the weaker choice.
##  - He is held until the blow lands, and never past landByTick. Nothing of his stops a follow-up on its way.
##  - His guard counts only from guardFromTick, or once the follow-up has been used. Buried, he never dodges or presses.
##  - His burst throws him out, but not before burstFromTick. An AI bursts only when no follow-up is coming: from that
##    tick, with its rival within burstWithinBh, at its level's rate (one draw a burial).
##  - He comes out with safeTicks of safety: no exchange starts on him and no shot lands. The safety covers World's
##    get-up after its ticks as well.
##  - One follow-up to a burial. An exchange that takes him out of the crater ends the burial.
## State: the buried fighter's director state (f.act.dirI: DirInterrupt.BURY_*, SAFE_UNTIL). Numbers:
## data/director/interrupts.json `buried`. The follow-up's piece is an interim of the director's own (a rush, one heavy
## blow of class none, no launch, no chain window) until Combat authors it.

const TAG: String = "BURIED: FOLLOW-UP"
const TPL: String = "buried_followup"
const RISING: int = 2   # BURY_WAS: World's ticks are over and he is getting up (still down)
const AI_NO: int = 1
const AI_YES: int = 2
const DIVE: int = 1     # aiFollow: the AI's free blow is the dive ...
const BLAST: int = 2    # ... or the charged shot, when the dive cannot land in time


static func data() -> Dictionary:
	return DirInterrupt.data().get("buried", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false)


## True while World holds f in his crater.
static func buried(f) -> bool:
	return f.embedT > 0 and f.state == "down"


## Live ticks since he was driven in.
static func since(f) -> int:
	return DirInterrupt.gi(f, DirInterrupt.BURY_N)


## True while a buried fighter can answer nothing: before guardFromTick, with the follow-up not yet used.
static func helpless(f) -> bool:
	return on() and buried(f) and since(f) < int(data().guardFromTick) and DirInterrupt.gi(f, DirInterrupt.BURY_USED) == 0


## True while D lies buried with his follow-up still to take: inside followTicks, none used, none on its way.
static func _open(S: SimState, D) -> bool:
	if not on() or not buried(D) or S.dirS.ex != null or S.game.ko != null:
		return false
	return since(D) < int(data().followTicks) and DirInterrupt.gi(D, DirInterrupt.BURY_USED) == 0


## The ticks A's dive to D takes: the way at dive.speed, at least dive.minTicks.
static func diveTicks(A, D) -> int:
	var c: Dictionary = data().dive
	return maxi(int(c.minTicks), int(ceil(DirBands.dist(A, D) / float(c.speed) * DirData.TICKS_PER_SEC)))


## True when A's physical attack press now would be the free follow-up on D: the dive lands by landByTick.
static func followUp(S: SimState, A, D) -> bool:
	return _open(S, D) and since(D) + diveTicks(A, D) <= int(data().landByTick)


## True when A's energy press now would be the other free blow: a charged shot into the crater.
static func blastFollow(S: SimState, A, D) -> bool:
	return _open(S, D) and (A.state == "free" or A.state == "charging") and A.stunTicks <= 0


## The energy press on a buried rival (DirBlast.press): a charged shot leaves at once, free of ki, at blast.damage.
## It is the follow-up of this burial, and he is held until it lands (tick).
static func fireBlast(S: SimState, A, D) -> void:
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	var sh = SimShots.fire(S, S.fighters.find(A), String(DirBlast.data().heavy.kind), {"target": S.fighters.find(D), "dmg": float(data().blast.damage)})
	if sh == null:
		return   # the cap on live shots: the press is spent
	DirInterrupt.si(D, DirInterrupt.BURY_USED, 1)
	DirInterrupt.si(D, DirInterrupt.BURY_SHOT, sh.id)
	DirInterrupt.si(A, DirInterrupt.BLAST_AT, S.tick)
	SimFx.cue(S, A, "buried_blast", "", "")
	SimEvents.feed(S, A.name + " FIRES INTO THE CRATER", "the free blow as a charged shot: it arrives in " + str(sh.left) + " ticks")


## True when shot sh is the follow-up on its way to f (DirBlast.hit): it lands clean.
static func followShot(f, sh) -> bool:
	return on() and sh.id == DirInterrupt.gi(f, DirInterrupt.BURY_SHOT) and DirInterrupt.gi(f, DirInterrupt.BURY_SHOT) != 0


static func shotLanded(f) -> void:
	DirInterrupt.si(f, DirInterrupt.BURY_SHOT, 0)


## True while f is the defender of the follow-up's dive: nothing of his stops it.
static func diving(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	return ex != null and ex.tpl == TPL and ex.D == f


## The stance a buried defender is read in when an ordinary exchange starts on him: his guard from guardFromTick (or
## once the follow-up is used), and otherwise nothing. -1 when he is not buried.
static func stance(D) -> int:
	if not on() or not buried(D):
		return -1
	return 1 if (D.stance == 1.0 and not helpless(D)) else 0


## True while f cannot be attacked: getting up out of his crater, and for safeTicks after he is up.
static func safe(S: SimState, f) -> bool:
	return S.tick < DirInterrupt.gi(f, DirInterrupt.SAFE_UNTIL) or DirInterrupt.gi(f, DirInterrupt.BURY_WAS) == RISING


## The follow-up's exchange: the attacker dives, one heavy blow lands that nothing answers, and the crater deepens.
## No launch beat and no chain window. The buried fighter's burial ends with the exchange (onEnd).
static func plan(S: SimState, ex) -> void:
	var c: Dictionary = data()
	var tps: float = DirData.TICKS_PER_SEC
	var n: int = diveTicks(ex.A, ex.D)
	var t: float = float(n) / tps
	var foot: float = float(DirData._prof().tempo.foot) / tps
	ex.tag = TAG
	ex.tpl = TPL
	ex.branch = "lands"
	DirInterrupt.si(ex.D, DirInterrupt.BURY_USED, 1)
	SimEvents.feed(S, ex.A.name + " DIVES", "the free blow lands in " + str(n) + " ticks, at tick " + str(since(ex.D) + n) + " of the burial")
	DirExchange.schedule(ex, 0.0, "rush", {"off": float(DirData.contact().offset), "dur": t})
	DirExchange.schedule(ex, 0.0, "cue", {"cue": "buried_followup", "who": "A"})
	DirExchange.schedule(ex, t, "strike", {"a": "A", "d": "D", "dmg": float(c.damage), "o": {"class": "none", "noParry": true, "ignoreStance": true, "big": true}})
	DirExchange.schedule(ex, t, "buryDeepen", null)
	DirExchange.schedule(ex, t + foot, "nop", null)


## The follow-up's blow deepens the crater he lies in: World's deepen makes it 'deepen' times as deep as it was.
static func opDeepen(S: SimState, ex) -> void:
	if ex.cancel or S.game.ko != null:
		return
	WorldCrater.deepen(S, ex.D.x, ex.A, float(data().deepen))
	ex.D.y = WorldTerrain.groundY(S, ex.D.x)


## A blast met a buried fighter who could answer nothing (DirBlast.hit): it was the follow-up.
static func blasted(f) -> void:
	DirInterrupt.si(f, DirInterrupt.BURY_USED, 1)


## An exchange ends: a defender who was in his crater is out of it, with his safety.
static func onEnd(S: SimState, ex) -> void:
	if not on() or (ex.D.embedT <= 0 and ex.tpl != TPL):
		return
	ex.D.embedT = 0
	_rise(S, ex.D)


static func _rise(S: SimState, f) -> void:
	DirInterrupt.si(f, DirInterrupt.SAFE_UNTIL, S.tick + int(data().safeTicks))
	SimFx.cue(S, f, "buried_rise", "", "")


## True when a buried fighter's burst is allowed: not before burstFromTick, and not with a follow-up on its way.
static func canBurst(f) -> bool:
	return on() and buried(f) and since(f) >= int(data().burstFromTick) and DirInterrupt.gi(f, DirInterrupt.BURY_SHOT) == 0


## His burst throws him out of the crater (DirInterrupt.burst).
static func burstOut(S: SimState, f) -> void:
	if not buried(f):
		return
	f.embedT = 0
	f.state = "free"
	f.stateT = 0.0
	DirInterrupt.si(f, DirInterrupt.BURY_WAS, 0)
	_rise(S, f)
	SimEvents.feed(S, f.name + " BURSTS OUT", "out of the crater, with " + str(int(data().safeTicks)) + " ticks of safety")


## Once a live tick: a burial starts (the follow-up is offered again, and an AI rival decides whether to take it), goes
## on (the count; the hold for a shot on its way; the AI's burst) and ends (he gets up by himself: safe while he does,
## and for safeTicks after).
static func tick(S: SimState) -> void:
	if not on():
		return
	var c: Dictionary = data()
	for f in S.fighters:
		var was: int = DirInterrupt.gi(f, DirInterrupt.BURY_WAS)
		var now: int = 1 if buried(f) else (RISING if (was != 0 and f.state == "down" and f.embedT <= 0) else 0)
		var o = SimRoster.opp(S, f)
		if now == 1 and was != 1:
			DirInterrupt.si(f, DirInterrupt.BURY_USED, 0)
			DirInterrupt.si(f, DirInterrupt.BURY_SHOT, 0)
			DirInterrupt.si(f, DirInterrupt.BURY_BURST, 0)
			DirInterrupt.si(f, DirInterrupt.BURY_N, WorldContact.K_EMB_TICKS - f.embedT)
			DirInterrupt.si(f, DirInterrupt.BURY_E, 0)
			DirInterrupt.si(f, DirInterrupt.BURY_AI, 0)
			if o.ai != null:
				DirInterrupt.si(f, DirInterrupt.BURY_AI, AI_YES if S.rng.next() < float(DirAI.lv().get("buriedFollowUp", 0.0)) else AI_NO)
			SimEvents.feed(S, f.name + " IS BURIED", "a free blow for " + o.name + ": a press in the next " + str(int(c.followTicks)) + " ticks, landing by tick " + str(int(c.landByTick)))
		elif now == 1:
			DirInterrupt.si(f, DirInterrupt.BURY_N, since(f) + 1)
			_hold(S, f)
			_aiBurst(S, f, o)
			if not buried(f):
				now = 0   # it burst out: the rise is burstOut's
		elif now == 0 and was != 0 and f.state != "locked" and f.state != "launched":
			_rise(S, f)   # he is up, by himself
		DirInterrupt.si(f, DirInterrupt.BURY_WAS, now)


## A follow-up shot on its way holds him in the crater until it lands, and never past landByTick.
static func _hold(S: SimState, f) -> void:
	var id: int = DirInterrupt.gi(f, DirInterrupt.BURY_SHOT)
	if id == 0:
		return
	var live: bool = false
	for sh in S.shots:
		if sh.id == id and not sh.dead:
			live = true
	if not live or since(f) >= int(data().landByTick):
		DirInterrupt.si(f, DirInterrupt.BURY_SHOT, 0)
		return
	f.embedT = maxi(f.embedT, 2)


## The buried AI's burst (section 14.5): only when no follow-up is coming. From burstFromTick, with nothing used or on
## its way and its rival within burstWithinBh, one draw a burial at its level's rate.
static func _aiBurst(S: SimState, f, o) -> void:
	if f.ai == null or S.dirS.ex != null or DirInterrupt.gi(f, DirInterrupt.BURY_BURST) != 0 or not canBurst(f):
		return
	if DirInterrupt.gi(f, DirInterrupt.BURY_USED) != 0 or DirBands.dist(f, o) > float(data().burstWithinBh) * DirInterrupt.BH:
		return
	DirInterrupt.si(f, DirInterrupt.BURY_BURST, 1)
	if S.rng.next() < float(DirAI.lv().get("buriedBurst", 0.0)):
		DirInterrupt.burst(S, f)


## The free blow the AI fighter f takes on the buried rival o now: DIVE, BLAST (the dive cannot land in time), or 0.
## It chose to as he was buried, and its reaction time has passed.
static func aiFollow(S: SimState, f, o) -> int:
	if DirInterrupt.gi(o, DirInterrupt.BURY_AI) != AI_YES or since(o) < int(DirAI.skill().get("reactTicks", 14)):
		return 0
	if followUp(S, f, o):
		return DIVE
	return BLAST if blastFollow(S, f, o) else 0
