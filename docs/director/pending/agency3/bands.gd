class_name DirBands
## The ranged press (agency-pass.md section 1; docs/director/agency-slice-2.md and agency-slice-3.md): three bands by
## distance, the approach that comes before an exchange, and the far band's taunt and charge.
##  - A strike never exists at range: an exchange is planned only inside the close band.
##  - The exchange starts at the wind-up: a press from farther off starts only the attacker's own move, a lunge in the
##    mid band and a flight in the far band. The rival is free while it comes. When it ends the exchange is planned
##    from where both then stand and what the rival is then doing, exactly as a close press is.
##  - In the far band a tap is a taunt and a hold is a charge. The taunt is a challenge: the rival's attack press
##    while it plays answers it, and both rush and meet in the middle. A held light is a fast charge that stops, for
##    nothing, when the button is let go; a held heavy is slower, committed, and can earn a launch.
## None of it is an exchange: S.dirS.ex stays null. It lives in the fighter's director state (f.act.dirI:
## DirInterrupt.APPR_*, TAUNT_*) and in his rush. One approach at a time: while it is on, his own later presses wait as
## his links, the rival's press waits to be read at the engage, and only the rival's signature starts (it ends the
## approach). Numbers: data/director/interrupts.json `bands`. Nothing here runs in a profile without the perfect block.

const CLOSE: int = 0
const MID: int = 1
const FAR: int = 2
const NAMES: Array = ["close", "mid", "far"]
const BH: float = 75.0
const SLOPE_STEPS: Array = [1.0, 0.66, 0.4]   # shares of engageBh tried for the approach's end point on a slope
const CHARGE: int = 1 << 6    # APPR_REQ: the approach is a held charge
const MEET: int = 1 << 7      # APPR_REQ: the approach is the answer to a taunt: both rush to the middle
const CHARGED: int = 1 << 8   # APPR_REQ: ... and the rival was holding a heavy charge when he was met: he enters with an edge
const PAYS: Array = ["half", "quarter", "eighth"]   # what an ignored far taunt pays: the first, the second, the third
# The AI's answer to a rival who is coming, or to his taunt (DirInterrupt.AI_REACT).
const R_NONE: int = 0
const R_GUARD: int = 1
const R_DODGE: int = 2
const R_LIGHT: int = 3
const R_HEAVY: int = 4


static func data() -> Dictionary:
	return DirInterrupt.data().get("bands", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false)


## True when a far press is a taunt or a charge (bands.taunt.enabled); off, a far press flies in on a tap.
static func farOn() -> bool:
	return on() and data().get("taunt", {}).get("enabled", false)


## The distance the bands are measured on: centre to centre, the shortest arc and the height together.
static func dist(a, b) -> float:
	return SimDetMath.hypot(SimWrap.sdx(a.x, b.x), b.y - a.y)


## The band a press by a on b falls in now. It is held state (both fighters carry it), set once a live tick with
## hysteresisBh across each edge, so a pair hovering on a line does not flip between bands. Before the first tick of
## a match it is read straight from the distance.
static func band(a, b) -> int:
	var st: int = DirInterrupt.gi(a, DirInterrupt.BAND)
	return st - 1 if st > 0 else _bandAt(dist(a, b), -1)


## The band at distance d for a pair now in band cur (-1: none yet). An edge is crossed only half the hysteresis
## beyond it: going out it sits further out, coming in it sits further in.
static func _bandAt(d: float, cur: int) -> int:
	var c: Dictionary = data()
	var h: float = float(c.get("hysteresisBh", 0.0)) * BH * 0.5 if cur >= 0 else 0.0
	var e0: float = float(c.closeBh) * BH + (h if cur == CLOSE else -h)
	var e1: float = float(c.midBh) * BH + (h if cur <= MID else -h)
	return CLOSE if d <= e0 else (MID if d <= e1 else FAR)


static func _bandTick(S: SimState) -> void:
	var a = S.fighters[0]
	var b = S.fighters[1]
	var nb: int = _bandAt(dist(a, b), DirInterrupt.gi(a, DirInterrupt.BAND) - 1)
	DirInterrupt.si(a, DirInterrupt.BAND, nb + 1)
	DirInterrupt.si(b, DirInterrupt.BAND, nb + 1)


static func pending(f) -> bool:
	return DirInterrupt.gi(f, DirInterrupt.APPR_LEFT) > 0


## True while f's far taunt plays (and his hold may still become a charge).
static func taunting(f) -> bool:
	return DirInterrupt.gi(f, DirInterrupt.TAUNT_AGE) > 0


## True when f's next ignored far taunt would pay nothing (the guard against farming).
static func tauntSpent(f) -> bool:
	return DirInterrupt.gi(f, DirInterrupt.TAUNT_N) >= PAYS.size()


## The slot whose approach is on, or -1.
static func who(S: SimState) -> int:
	for k in range(S.fighters.size()):
		if pending(S.fighters[k]):
			return k
	return -1


static func _weightName(weight: int) -> String:
	return "heavy" if weight == SimAct.HEAVY else "light"


## A's press from outside the close band: his move toward D starts and nothing else is decided. It ends engageBh from
## D, on A's own side and at D's height, after the band's ticks: the lunge's, the far flight's, or the charge's for
## his weight. opn is the opening the press held (a riposte, a reversal, a punish): it is kept for the engage.
static func begin(S: SimState, A, D, weight: int, entry: int, pressTick: int, opn: int = 0, charge: bool = false) -> void:
	var c: Dictionary = data()
	var d: float = dist(A, D)
	var b: int = band(A, D)
	var eng: float = float(c.engageBh) * BH
	var m: Dictionary = c.lunge
	if b == FAR:
		m = c.charge[_weightName(weight)] if charge else c.far[_weightName(weight)]
	var n: int = clampi(int(ceil(maxf(0.0, d - eng) / float(m.speed) * DirData.TICKS_PER_SEC)), int(m.minTicks), int(m.maxTicks))
	A.state = "free"
	A.hideT = 0.0
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	var r := SimState.Rush.new()
	r.tgt = D
	r.off = _endOff(S, D, SimMathx.jsign(DirMelee.sideOff(A, D, eng, "own")))
	r.end = S.T + float(n) * SimConst.DT
	A.rush = r
	DirInterrupt.si(A, DirInterrupt.TAUNT_AGE, 0)
	DirInterrupt.si(A, DirInterrupt.APPR_LEFT, n)
	DirInterrupt.si(A, DirInterrupt.APPR_REQ, weight | ((entry + 1) << 2) | (opn << 4) | (CHARGE if charge else 0))
	DirInterrupt.si(A, DirInterrupt.APPR_TICK, pressTick)
	SimFx.rush(S, A, D, S.tick + n)
	var what: String = ": CHARGES" if charge else (": LUNGE" if b == MID else ": FLIES IN")
	SimEvents.feed(S, A.name + " " + String(DirExchange.KIND[weight]).to_upper() + what, NAMES[b] + " band, " + SimMathx.jstr(SimMathx.jround(d / BH)) + " bh; the exchange starts at the wind-up, in " + str(n) + " ticks")
	_aiChoose(S, D, n)


## Where the approach ends, as an offset from D on the given side: engageBh away. On a slope the ground there can stand
## well above D, so the point is brought in until the pair is inside the close band.
static func _endOff(S: SimState, D, side: float) -> float:
	var c: Dictionary = data()
	var eng: float = float(c.engageBh) * BH
	var minS: float = float(DirData.contact().get("minSeparation", 45.0))
	var off: float = eng
	for k in SLOPE_STEPS:
		off = maxf(eng * float(k), minS)
		var rise: float = maxf(0.0, WorldTerrain.groundY(S, SimWrap.wrap(D.x + side * off)) - D.y)
		if SimDetMath.hypot(off, rise) <= float(c.closeBh) * BH:
			break
	return side * off


# ---------------------------------------------------------------- the far band: the taunt and the charge

## A v2 slot's attack press, on its own tick (DirExchange.requestAttack). True when it was a far press and is spent here:
## in the far band, with no exchange or approach running and A free, it answers the rival's taunt or opens A's own.
## A far press never waits in the queue.
static func farPressNow(S: SimState, A, weight: int, entry: int) -> bool:
	if not farOn() or S.dirS.ex != null or S.game.ko != null or who(S) >= 0:
		return false
	if (A.state != "free" and A.state != "charging") or A.stunTicks > 0 or DirInterrupt.opening(S, A) != 0:
		return false
	var D = SimRoster.opp(S, A)
	if band(A, D) != FAR:
		return false
	A.state = "free"
	if taunting(D):
		meet(S, A, D, weight, entry, S.tick)
	else:
		farPress(S, A, D, weight, entry, S.tick)
	return true


## A's press from the far band (a v2 slot with no opening). It opens his taunt: the line and the gesture play for
## windowTicks while he keeps flying, and the rival may answer. If he is still holding the button holdTicks later the
## taunt becomes a charge of that weight (tick). A press while his own taunt plays is spent.
static func farPress(S: SimState, A, D, weight: int, entry: int, pressTick: int) -> void:
	if taunting(A):
		return
	DirInterrupt.si(A, DirInterrupt.TAUNT_AGE, 1)
	DirInterrupt.si(A, DirInterrupt.APPR_REQ, weight | ((entry + 1) << 2))
	DirInterrupt.si(A, DirInterrupt.APPR_TICK, pressTick)
	SimFx.cue(S, A, "taunt_start", "", "")
	SimEvents.feed(S, A.name + " TAUNTS", "far band, " + SimMathx.jstr(SimMathx.jround(dist(A, D) / BH)) + " bh: a challenge for " + str(int(data().taunt.windowTicks)) + " ticks; holding the button makes it a charge")
	# The AI rival answers by its level's rate, after its reaction time (one or two draws).
	if D.ai != null and S.rng.next() < float(DirAI.lv().get("answerTaunt", 0.0)):
		DirInterrupt.si(D, DirInterrupt.AI_REACT, R_HEAVY if S.rng.next() < DirAI.HEAVY_SHARE else R_LIGHT)
		DirInterrupt.si(D, DirInterrupt.REACT_AT, int(DirAI.skill().get("answerTicks", 28)))   # after a heavy's hold: it answers a taunt, not a charge being gathered
		SimEvents.feed(S, D.name + " WILL ANSWER", "an attack press " + str(int(DirAI.skill().get("answerTicks", 28))) + " ticks from now, if the taunt still plays")


## T's taunt ends. answered: the rival's attack press came while it played, and it pays in full. Otherwise it was
## ignored and pays a half, a quarter, an eighth, then nothing until the two have traded blows (DirInterrupt.onStart
## clears the count). how names the ending for the cue (finished, accepted, takeoff_light, takeoff_heavy, cut): a
## take-off and a taunt cut short pay nothing and count for nothing.
static func endTaunt(S: SimState, T, answered: bool, how: String = "") -> void:
	if not taunting(T):
		return
	DirInterrupt.si(T, DirInterrupt.TAUNT_AGE, 0)
	if how == "":
		how = "accepted" if answered else "finished"
	SimFx.cue(S, T, "taunt_end_" + how, "", "")
	if how != "accepted" and how != "finished":
		return
	var n: int = DirInterrupt.gi(T, DirInterrupt.TAUNT_N)
	var pays: String = "full" if answered else (String(PAYS[n]) if n < PAYS.size() else "none")
	if not answered:
		DirInterrupt.si(T, DirInterrupt.TAUNT_N, n + 1)
	SimFx.cue(S, T, "taunt_credit_" + pays, "", "")
	SimEvents.feed(S, T.name + (" TAUNT ANSWERED" if answered else " TAUNT IGNORED"), "it pays " + ("in full" if answered else (("an " if pays == "eighth" else "a ") + pays if pays != "none" else "nothing: three ignored since blows were traded")))


## R's attack press while T's taunt plays: the challenge is answered. Each covers half the distance on a straight
## dash and they arrive on the same tick, engageBh apart about the midpoint. The exchange then starts as R's attack
## against a rival who is pressing too: a clash if either pressed a heavy, otherwise a trade (Combat's meeting; the
## interim pieces are today's HEAVY CLASH and TRADE BLOWS). A rival met while he held a heavy charge enters the clash
## with an edge for the charge he had built (meet.chargerEdge, on today's clash a tilt of the chance).
static func meet(S: SimState, R, T, weight: int, entry: int, pressTick: int) -> void:
	var c: Dictionary = data()
	var m: Dictionary = c.meet
	var tw: int = DirInterrupt.gi(T, DirInterrupt.APPR_REQ) & 3
	var charged: bool = tw == SimAct.HEAVY and T.input.heavyHeld   # met while he held a heavy charge (agency-pass.md section 12 c)
	endTaunt(S, T, true)
	var d: float = dist(R, T)
	var half: float = float(c.engageBh) * BH * 0.5
	var n: int = clampi(int(ceil(maxf(0.0, d * 0.5 - half) / float(m.speed) * DirData.TICKS_PER_SEC)), int(m.minTicks), int(m.maxTicks))
	var dx: float = SimWrap.sdx(T.x, R.x)
	var s: float = SimDamage.jor(SimMathx.jsign(dx), -T.face)   # R's side of T
	var mx: float = T.x + dx * 0.5
	var my: float = (T.y + R.y) * 0.5
	for k in range(2):
		var f = R if k == 0 else T
		var r := SimState.Rush.new()
		r.px = SimWrap.wrap(mx + (s if k == 0 else -s) * half)
		r.py = SimMathx.jmax(my, WorldTerrain.groundY(S, r.px))
		r.end = S.T + float(n) * SimConst.DT
		f.rush = r
		f.state = "free"
		f.hideT = 0.0
		f.face = s * (-1.0 if k == 0 else 1.0)
		SimFx.rush(S, f, T if k == 0 else R, S.tick + n)
	var w: int = SimAct.HEAVY if (weight == SimAct.HEAVY or tw == SimAct.HEAVY) else SimAct.LIGHT
	DirInterrupt.si(R, DirInterrupt.APPR_LEFT, n)
	DirInterrupt.si(R, DirInterrupt.APPR_REQ, w | ((entry + 1) << 2) | MEET | (CHARGED if charged else 0))
	DirInterrupt.si(R, DirInterrupt.APPR_TICK, pressTick)
	SimFx.cue(S, R, "challenge_answered", "", "")
	SimEvents.feed(S, R.name + " ANSWERS THE CHALLENGE", "both rush and meet in the middle in " + str(n) + " ticks: " + ("a clash" if w == SimAct.HEAVY else "a trade") + ("; " + T.name + " was charging and enters it with the edge" if charged else ""))


## The far taunt of f, once per live tick: it becomes a charge when the button of its weight has been held to
## holdTicks, and it ends, ignored, at windowTicks. An exchange or an approach of his own ends it too.
static func _tauntTick(S: SimState, f) -> void:
	var age: int = DirInterrupt.gi(f, DirInterrupt.TAUNT_AGE)
	if age <= 0:
		return
	var c: Dictionary = data()
	var o = SimRoster.opp(S, f)
	if S.game.ko != null or S.dirS.ex != null or f.state != "free" or f.stunTicks > 0:
		endTaunt(S, f, false, "cut")
		return
	var req: int = DirInterrupt.gi(f, DirInterrupt.APPR_REQ)
	var w: int = req & 3
	var held: bool = f.input.heavyHeld if w == SimAct.HEAVY else f.input.lightHeld
	if held and age >= int(c.charge[_weightName(w)].holdTicks) and who(S) < 0 and o.state != "launched" and o.state != "locked" and not o.hidden:
		endTaunt(S, f, false, "takeoff_" + _weightName(w))
		begin(S, f, o, w, ((req >> 2) & 3) - 1, DirInterrupt.gi(f, DirInterrupt.APPR_TICK), 0, true)
		SimFx.cue(S, f, "charge_" + _weightName(w), "", "")
		return
	if age >= int(c.taunt.windowTicks) and not held:
		endTaunt(S, f, false)
		return
	DirInterrupt.si(f, DirInterrupt.TAUNT_AGE, age + 1)


# ---------------------------------------------------------------- once a live tick

## Once per live tick, before the queues: the approach counts down and, at its end, the exchange starts (the engage).
## An approach whose fighter was shoved, staggered or caught by something else ends with nothing started. The end point
## follows the rival: it is set again for the ground where he now is, and when the approaching fighter moves first in
## the tick (slot 0) it leads the rival by his next tick of flight, so both slots arrive the same distance away. A
## light charge stops the moment its button is let go: the feint. A Simple layout's hold, which turns the light into a
## heavy, is not a release; and with the autoCharge assist a charge never feints.
static func tick(S: SimState) -> void:
	_bandTick(S)
	for f in S.fighters:
		var ra: int = DirInterrupt.gi(f, DirInterrupt.REACT_AT)
		if ra > 0:
			DirInterrupt.si(f, DirInterrupt.REACT_AT, ra - 1)
		_tauntTick(S, f)
	for f in S.fighters:
		var left: int = DirInterrupt.gi(f, DirInterrupt.APPR_LEFT)
		if left <= 0:
			continue
		var req: int = DirInterrupt.gi(f, DirInterrupt.APPR_REQ)
		if S.game.ko != null or S.dirS.ex != null or f.state != "free" or f.stunTicks > 0 or (f.rush == null and left > 2):
			drop(S, f, "he was stopped on the way")
			continue
		if (req & CHARGE) != 0 and (req & 3) == SimAct.LIGHT and not f.input.lightHeld and not f.input.heavyHeld and f.input.upgrade == 0 and not SimAct.assisted(f, "autoCharge"):
			drop(S, f, "a feint: he let the button go, and it costs nothing")
			SimFx.cue(S, f, "charge_feint", "", "")
			continue
		left -= 1
		DirInterrupt.si(f, DirInterrupt.APPR_LEFT, left)
		if left == 0:
			_engage(S, f)
			return
		var o = f.rush.tgt if f.rush != null else null
		if o != null:
			var lead: float = o.vx * SimConst.DT if (S.fighters[0] == f and o.rush == null and o.state == "free") else 0.0
			var side: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(o.x, f.x)), SimMathx.jsign(f.rush.off))   # his own side of the rival, as it now is
			f.rush.off = _endOff(S, o, side) + lead


## The engage: the exchange starts now, from the press that began the approach (its weight, entry and place in the
## press log), against the rival as he now stands. A charge's press was held. A meeting is planned against a rival who
## is pressing too.
static func _engage(S: SimState, f) -> void:
	var req: int = DirInterrupt.gi(f, DirInterrupt.APPR_REQ)
	if (req & CHARGE) != 0:
		DirAlchemy.heldAt(f, DirInterrupt.gi(f, DirInterrupt.APPR_TICK), req & 3)
	DirExchange.planEntry = ((req >> 2) & 3) - 1
	DirExchange.planTick = DirInterrupt.gi(f, DirInterrupt.APPR_TICK)
	DirExchange.planOpen = (req >> 4) & 3
	DirExchange.planMeet = (req & MEET) != 0
	DirExchange.planMeetEdge = float(data().meet.get("chargerEdge", 0.0)) / 100.0 if (req & CHARGED) != 0 else 0.0   # points off the attacker's chance
	DirExchange.engaging = true
	var r: int = DirExchange._start(S, f, DirExchange.KIND[req & 3])
	DirExchange.engaging = false
	DirExchange.planOpen = 0
	DirExchange.planMeet = false
	DirExchange.planMeetEdge = 0.0
	DirExchange.planEntry = 0
	DirExchange.planTick = -1
	if r != DirExchange.STARTED:
		f.rush = null
		if r == DirExchange.WAIT:
			SimEvents.feed(S, f.name + " APPROACH ENDS", "the director could not start the exchange")


## The approach ends with nothing started. A meeting ends for both.
static func drop(S: SimState, f, why: String) -> void:
	if (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & MEET) != 0:
		SimRoster.opp(S, f).rush = null
	DirInterrupt.si(f, DirInterrupt.APPR_LEFT, 0)
	f.rush = null
	SimEvents.feed(S, f.name + " APPROACH ENDS", why)


## f's dodge outside an exchange.
##  - During his own approach it calls it off: for nothing, with the short gap between dodges; but a heavy charge is
##    committed, and stopping it costs the dodge-cancel's ki and its cooldown.
##  - During the dash to a meeting either fighter's dodge ends it for both.
##  - During his own taunt it cuts the taunt short (it pays nothing); the dodge itself is an ordinary one.
static func cancel(S: SimState, f) -> bool:
	var o = SimRoster.opp(S, f)
	var c: Dictionary = DirInterrupt.data().dodgeCancel
	if not pending(f):
		if taunting(f):
			endTaunt(S, f, false, "cut")
		if pending(o) and (DirInterrupt.gi(o, DirInterrupt.APPR_REQ) & MEET) != 0 and f.rush != null and f.act.dodgeCool <= 0:
			f.act.dodgeCool = int(c.freeGapTicks)
			drop(S, o, f.name + " left the meeting")
			DirInterrupt.dash(f, o, float(c.dash))
			SimFx.afterimage(S, f)
			SimFx.cue(S, f, "dodge_cancel", "", "")
			return true
		return false
	if f.act.dodgeCool > 0:
		return false
	var req: int = DirInterrupt.gi(f, DirInterrupt.APPR_REQ)
	var paid: bool = (req & CHARGE) != 0 and (req & 3) == SimAct.HEAVY
	if paid:
		if f.ki < float(c.ki):
			return false
		f.ki -= float(c.ki)
	f.act.dodgeCool = int(c.cooldownTicks if paid else c.freeGapTicks)
	drop(S, f, "he calls it off" + ("; a heavy charge is committed, so it cost " + SimMathx.jstr(float(c.ki)) + " ki" if paid else "; nothing had started"))
	DirInterrupt.dash(f, o, float(c.dash))
	SimFx.afterimage(S, f)
	SimFx.cue(S, f, "dodge_cancel", "", "")
	SimEvents.feed(S, f.name + " DODGE-CANCEL", "he calls the approach off" + ("" if paid else "; nothing had started"))
	return true


## The layout's upgrade edge during f's approach or his taunt: a hold makes it a heavy. A signature ends either one,
## and the caller queues it. True when it took the upgrade.
static func upgrade(S: SimState, f, weight: int) -> bool:
	if not pending(f) and not taunting(f):
		return false
	if weight == SimAct.SIG:
		if pending(f):
			drop(S, f, "a signature instead")
		endTaunt(S, f, false, "cut")
		return false
	DirInterrupt.si(f, DirInterrupt.APPR_REQ, (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & ~3) | weight)
	return true


# ---------------------------------------------------------------- the AI's use of the free time

## The rival A is coming at the AI fighter D over n ticks. Given time to react (ai.json reactTicks), it picks an
## answer once, by its level's rates (approachReact: guard, dodge, meet; otherwise it keeps doing what it was doing).
## One draw. A meeting needs no answer: he is already rushing in.
static func _aiChoose(S: SimState, D, n: int) -> void:
	DirInterrupt.si(D, DirInterrupt.AI_REACT, R_NONE)
	var rt: int = int(DirAI.skill().get("reactTicks", 14))
	var ar = DirAI.lv().get("approachReact", null)
	if D.ai == null or ar == null or n < rt + 2:
		return
	var u: float = S.rng.next()
	var pick: int = R_NONE
	if u < float(ar[0]):
		pick = R_GUARD
	elif u < float(ar[0]) + float(ar[1]):
		pick = R_DODGE
	elif u < float(ar[0]) + float(ar[1]) + float(ar[2]):
		pick = R_LIGHT
	DirInterrupt.si(D, DirInterrupt.AI_REACT, pick)
	DirInterrupt.si(D, DirInterrupt.REACT_AT, rt)
	if pick != R_NONE:
		SimEvents.feed(S, D.name + " SEES HIM COMING", "it will " + String(["", "guard", "dodge", "press to meet him"][pick]) + ", " + str(rt) + " ticks from now")


## The AI fighter f's answer to the rival o this tick (R_*), or R_NONE: nothing chosen, its reaction time is not up,
## or the rival is no longer coming or taunting. A press (R_LIGHT, R_HEAVY) is returned once.
static func aiAnswer(f, o) -> int:
	var r: int = DirInterrupt.gi(f, DirInterrupt.AI_REACT)
	if r == R_NONE:
		return R_NONE
	if not pending(o) and not taunting(o):
		DirInterrupt.si(f, DirInterrupt.AI_REACT, R_NONE)
		return R_NONE
	if DirInterrupt.gi(f, DirInterrupt.REACT_AT) > 0:
		return R_NONE
	if r >= R_LIGHT:
		DirInterrupt.si(f, DirInterrupt.AI_REACT, R_NONE)
	return r
