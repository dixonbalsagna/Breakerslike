class_name DirBury
## The buried fighter (agency-pass.md section 7; World's embed, docs/world/ground-contact.md section 19). A hard impact
## drives a fighter into its crater: World holds him down for its embed ticks (Fighter.embedT). The director's part:
##  - The free follow-up: his rival's first attack press in the first followTicks, from within reach, is one blow he
##    cannot answer. It lands clean, deepens the crater and does not launch. A blast into the crater is one too.
##  - His guard counts only from guardFromTick, or once the follow-up has been used. Buried, he never dodges or presses.
##  - His burst throws him out, but not before burstFromTick.
##  - He comes out with safeTicks of safety: no exchange starts on him and no shot lands.
##  - One follow-up to a burial. An exchange that takes him out of the crater ends the burial.
##  - The safety covers World's get-up after its ticks as well.
## State: the buried fighter's director state (f.act.dirI: DirInterrupt.BURY_*, SAFE_UNTIL). Numbers:
## data/director/interrupts.json `buried`. The follow-up's piece is an interim of the director's own (a rush, one heavy
## blow of class none, no launch, no chain window) until Combat authors it.

const TAG: String = "BURIED: FOLLOW-UP"
const BH: float = 75.0
const RISING: int = 2   # BURY_WAS: World's ticks are over and he is getting up (still down)
const AI_NO: int = 1
const AI_YES: int = 2


static func data() -> Dictionary:
	return DirInterrupt.data().get("buried", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false)


## True while World holds f in his crater.
static func buried(f) -> bool:
	return f.embedT > 0 and f.state == "down"


## Ticks since he was driven in.
static func since(f) -> int:
	return WorldContact.K_EMB_TICKS - f.embedT


## True while a buried fighter can answer nothing: before guardFromTick, with the follow-up not yet used.
static func helpless(f) -> bool:
	return on() and buried(f) and since(f) < int(data().guardFromTick) and DirInterrupt.gi(f, DirInterrupt.BURY_USED) == 0


## True when A's attack press now would be the free follow-up on D.
static func followUp(S: SimState, A, D) -> bool:
	if not on() or not buried(D) or S.dirS.ex != null or S.game.ko != null:
		return false
	var c: Dictionary = data()
	if since(D) >= int(c.followTicks) or DirInterrupt.gi(D, DirInterrupt.BURY_USED) != 0:
		return false
	return DirBands.dist(A, D) <= float(c.reachBh) * BH


## The stance a buried defender is read in when an ordinary exchange starts on him: his guard from guardFromTick (or
## once the follow-up is used), and otherwise nothing. -1 when he is not buried.
static func stance(D) -> int:
	if not on() or not buried(D):
		return -1
	return 1 if (D.stance == 1.0 and not helpless(D)) else 0


## True while f cannot be attacked: getting up out of his crater, and for safeTicks after he is up.
static func safe(S: SimState, f) -> bool:
	return S.tick < DirInterrupt.gi(f, DirInterrupt.SAFE_UNTIL) or DirInterrupt.gi(f, DirInterrupt.BURY_WAS) == RISING


## The follow-up's exchange: the attacker closes, one heavy blow lands that nothing answers, and the crater deepens.
## No launch beat and no chain window. The buried fighter's burial ends with the exchange (onEnd).
static func plan(S: SimState, ex) -> void:
	var c: Dictionary = data()
	var tps: float = DirData.TICKS_PER_SEC
	var t: float = DirData._approachTicks(absf(SimWrap.sdx(ex.A.x, ex.D.x)), true) / tps
	var foot: float = float(DirData._prof().tempo.foot) / tps
	ex.tag = TAG
	ex.tpl = "buried_followup"
	ex.branch = "lands"
	DirInterrupt.si(ex.D, DirInterrupt.BURY_USED, 1)
	DirExchange.schedule(ex, 0.0, "rush", {"off": float(DirData.contact().offset), "dur": t})
	DirExchange.schedule(ex, 0.0, "cue", {"cue": "buried_followup", "who": "A"})
	DirExchange.schedule(ex, t, "strike", {"a": "A", "d": "D", "dmg": float(c.damage), "o": {"class": "none", "noParry": true, "ignoreStance": true, "big": true}})
	DirExchange.schedule(ex, t, "buryDeepen", null)
	DirExchange.schedule(ex, t + foot, "nop", null)


## The follow-up's blow deepens the crater he lies in. World's dig does nothing on ground already dented deeper than
## the bowl asked for, so the blow digs a bowl 'deepen' times as deep as the one that buried him: the embed's own
## energy (kept from its event), times deepen squared, since a bowl's depth goes with the square root of its energy.
static func opDeepen(S: SimState, ex) -> void:
	if ex.cancel or S.game.ko != null:
		return
	var e0: float = float(DirInterrupt.gi(ex.D, DirInterrupt.BURY_E)) / 1000.0
	if e0 <= 0.0:
		e0 = WorldCrater.clashEnergy(ex.A.tier)
	var k: float = float(data().deepen)
	WorldCrater.dig(S, ex.D.x, e0 * k * k, ex.A, "impact")
	ex.D.y = WorldTerrain.groundY(S, ex.D.x)


## A blast met a buried fighter who could answer nothing (DirBlast.hit): it was the follow-up.
static func blasted(f) -> void:
	DirInterrupt.si(f, DirInterrupt.BURY_USED, 1)


## An exchange ends: a defender who was in his crater is out of it, with his safety.
static func onEnd(S: SimState, ex) -> void:
	if not on() or ex.D.embedT <= 0:
		return
	ex.D.embedT = 0
	_rise(S, ex.D)


static func _rise(S: SimState, f) -> void:
	DirInterrupt.si(f, DirInterrupt.SAFE_UNTIL, S.tick + int(data().safeTicks))
	SimFx.cue(S, f, "buried_rise", "", "")


## True when a buried fighter's burst is allowed: not before burstFromTick.
static func canBurst(f) -> bool:
	return on() and buried(f) and since(f) >= int(data().burstFromTick)


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


## Once a live tick: a burial starts (the follow-up is offered again, and an AI rival decides whether to take it) and
## ends (he gets up by himself: safe while he does, and for safeTicks after).
static func tick(S: SimState) -> void:
	if not on():
		return
	for f in S.fighters:
		var was: int = DirInterrupt.gi(f, DirInterrupt.BURY_WAS)
		var now: int = 1 if buried(f) else (RISING if (was != 0 and f.state == "down" and f.embedT <= 0) else 0)
		if now == 1 and was != 1:
			DirInterrupt.si(f, DirInterrupt.BURY_USED, 0)
			var o = SimRoster.opp(S, f)
			# the energy of the impact that buried him, from this tick's embed event (the follow-up digs deeper than it)
			var e0: float = 0.0
			var fx: Array = S.out.fx
			var k: int = fx.size() - 1
			while k >= 0 and fx[k].tick == S.tick:
				if fx[k].type == "embed" and int(fx[k].actor) == S.fighters.find(f):
					e0 = float(fx[k].energy)
				k -= 1
			DirInterrupt.si(f, DirInterrupt.BURY_E, int(e0 * 1000.0))
			DirInterrupt.si(f, DirInterrupt.BURY_AI, 0)
			if o.ai != null:
				DirInterrupt.si(f, DirInterrupt.BURY_AI, AI_YES if S.rng.next() < float(DirAI.lv().get("buriedFollowUp", 0.0)) else AI_NO)
			SimEvents.feed(S, f.name + " IS BURIED", "a free blow for " + o.name + " in the next " + str(int(data().followTicks)) + " ticks, from within " + SimMathx.jstr(float(data().reachBh)) + " bh")
		elif now == 0 and was != 0 and f.state != "locked" and f.state != "launched":
			_rise(S, f)   # he is up, by himself
		DirInterrupt.si(f, DirInterrupt.BURY_WAS, now)


## True when the AI fighter f takes its free blow on the buried rival o now: it chose to as he was buried, its reaction
## time has passed, and the follow-up is still there.
static func aiFollow(S: SimState, f, o) -> bool:
	return DirInterrupt.gi(o, DirInterrupt.BURY_AI) == AI_YES and followUp(S, f, o) and since(o) >= int(DirAI.skill().get("reactTicks", 14))
