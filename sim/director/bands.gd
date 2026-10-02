class_name DirBands
## The ranged press (agency-pass.md section 1; docs/director/agency-slice-2.md): three bands by distance, and the
## approach that comes before an exchange.
##  - A strike never exists at range: an exchange is planned only inside the close band.
##  - The exchange starts at the wind-up: a press from farther off starts only the attacker's own move, a lunge in the
##    mid band and a flight in the far band. The rival is free while it comes. When it ends the exchange is planned
##    from where both then stand and what the rival is then doing, exactly as a close press is.
## The approach is not an exchange: S.dirS.ex stays null. It lives in the approaching fighter's director state
## (f.act.dirI: DirInterrupt.APPR_*) and in his rush. One approach at a time: while it is on, his own later presses wait
## as his links, the rival's press waits to be read at the engage, and only the rival's signature starts (it ends the
## approach). Numbers: data/director/interrupts.json `bands`. Nothing here runs in a profile without the perfect block.

const CLOSE: int = 0
const MID: int = 1
const FAR: int = 2
const NAMES: Array = ["close", "mid", "far"]
const BH: float = 75.0
const SLOPE_STEPS: Array = [1.0, 0.66, 0.4]   # shares of engageBh tried for the approach's end point on a slope


static func data() -> Dictionary:
	return DirInterrupt.data().get("bands", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false)


## The distance the bands are measured on: centre to centre, the shortest arc and the height together.
static func dist(a, b) -> float:
	return SimDetMath.hypot(SimWrap.sdx(a.x, b.x), b.y - a.y)


## The band a press by a on b falls in now.
static func band(a, b) -> int:
	var c: Dictionary = data()
	var d: float = dist(a, b)
	return CLOSE if d <= float(c.closeBh) * BH else (MID if d <= float(c.midBh) * BH else FAR)


static func pending(f) -> bool:
	return DirInterrupt.gi(f, DirInterrupt.APPR_LEFT) > 0


## The slot whose approach is on, or -1.
static func who(S: SimState) -> int:
	for k in range(S.fighters.size()):
		if pending(S.fighters[k]):
			return k
	return -1


## A's press from outside the close band: his move toward D starts and nothing else is decided. It ends engageBh from
## D, on A's own side and at D's height, after the band's ticks: the lunge's, or the far flight's for his weight.
## opn is the opening the press held (a riposte, a reversal, a punish): it is kept for the engage.
static func begin(S: SimState, A, D, weight: int, entry: int, pressTick: int, opn: int = 0) -> void:
	var c: Dictionary = data()
	var d: float = dist(A, D)
	var b: int = band(A, D)
	var eng: float = float(c.engageBh) * BH
	var m: Dictionary = c.lunge if b == MID else c.far["heavy" if weight == SimAct.HEAVY else "light"]
	var n: int = clampi(int(ceil(maxf(0.0, d - eng) / float(m.speed) * DirData.TICKS_PER_SEC)), int(m.minTicks), int(m.maxTicks))
	A.state = "free"
	A.hideT = 0.0
	A.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(A.x, D.x)), A.face)
	var r := SimState.Rush.new()
	r.tgt = D
	r.off = _endOff(S, D, SimMathx.jsign(DirMelee.sideOff(A, D, eng, "own")))
	r.end = S.T + float(n) * SimConst.DT
	A.rush = r
	DirInterrupt.si(A, DirInterrupt.APPR_LEFT, n)
	DirInterrupt.si(A, DirInterrupt.APPR_REQ, weight | ((entry + 1) << 2) | (opn << 4))
	DirInterrupt.si(A, DirInterrupt.APPR_TICK, pressTick)
	SimFx.rush(S, A, D, S.tick + n)
	SimEvents.feed(S, A.name + " " + String(DirExchange.KIND[weight]).to_upper() + (": LUNGE" if b == MID else ": FLIES IN"), NAMES[b] + " band, " + SimMathx.jstr(SimMathx.jround(d / BH)) + " bh; the exchange starts at the wind-up, in " + str(n) + " ticks")


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


## Once per live tick, before the queues: the approach counts down and, at its end, the exchange starts (the engage).
## An approach whose fighter was shoved, staggered or caught by something else ends with nothing started. The end point
## follows the rival: it is set again for the ground where he now is, and when the approaching fighter moves first in
## the tick (slot 0) it leads the rival by his next tick of flight, so both slots arrive the same distance away.
static func tick(S: SimState) -> void:
	for f in S.fighters:
		var left: int = DirInterrupt.gi(f, DirInterrupt.APPR_LEFT)
		if left <= 0:
			continue
		if S.game.ko != null or S.dirS.ex != null or f.state != "free" or f.stunTicks > 0 or (f.rush == null and left > 2):
			drop(S, f, "he was stopped on the way")
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
## press log), against the rival as he now stands.
static func _engage(S: SimState, f) -> void:
	var req: int = DirInterrupt.gi(f, DirInterrupt.APPR_REQ)
	DirExchange.planEntry = ((req >> 2) & 3) - 1
	DirExchange.planTick = DirInterrupt.gi(f, DirInterrupt.APPR_TICK)
	DirExchange.planOpen = (req >> 4) & 3
	DirExchange.engaging = true
	var r: int = DirExchange._start(S, f, DirExchange.KIND[req & 3])
	DirExchange.engaging = false
	DirExchange.planOpen = 0
	DirExchange.planEntry = 0
	DirExchange.planTick = -1
	if r != DirExchange.STARTED:
		f.rush = null
		if r == DirExchange.WAIT:
			SimEvents.feed(S, f.name + " APPROACH ENDS", "the director could not start the exchange")


## The approach ends with nothing started.
static func drop(S: SimState, f, why: String) -> void:
	DirInterrupt.si(f, DirInterrupt.APPR_LEFT, 0)
	f.rush = null
	SimEvents.feed(S, f.name + " APPROACH ENDS", why)


## f's dodge during his own approach calls it off for nothing: the exchange had not started. It starts the short gap
## between dodges, as the free cancel inside an exchange does.
static func cancel(S: SimState, f) -> bool:
	if not pending(f) or f.act.dodgeCool > 0:
		return false
	var c: Dictionary = DirInterrupt.data().dodgeCancel
	f.act.dodgeCool = int(c.freeGapTicks)
	DirInterrupt.si(f, DirInterrupt.APPR_LEFT, 0)
	f.rush = null
	DirInterrupt.dash(f, SimRoster.opp(S, f), float(c.dash))
	SimFx.afterimage(S, f)
	SimFx.cue(S, f, "dodge_cancel", "", "")
	SimEvents.feed(S, f.name + " DODGE-CANCEL", "he calls the approach off; nothing had started")
	return true


## The layout's upgrade edge during f's approach: a hold makes it a heavy. A signature ends the approach, and the
## caller queues it. True when the approach took the upgrade.
static func upgrade(S: SimState, f, weight: int) -> bool:
	if not pending(f):
		return false
	if weight == SimAct.SIG:
		drop(S, f, "a signature instead")
		return false
	DirInterrupt.si(f, DirInterrupt.APPR_REQ, (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & ~3) | weight)
	return true
