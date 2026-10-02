class_name DirBlast
## Energy, the first slice (agency-pass.md section 5 and section 11, item 6; docs/architecture/shots.md): with the
## energy family held, an attack press outside an exchange fires a blast from where he stands, in any band.
##  - A light is a bolt. Taps while one is winding up queue more, and bolts fired close together are one volley.
##  - A heavy is a charged shot: it charges while the button is held, from tapShare of its damage to all of it over
##    chargeTicks, and leaves when the button is let go.
## The shot is the core's (SimShots: it flies, trades with opposing shots and finds what it meets). The director fires
## it and decides what meeting a fighter means (hit):
##  - a fighter inside his dodge window lets it pass;
##  - a fresh guard press in the shot's window before it arrives is a perfect block: the shot is sent back;
##  - a held guard takes it at the guard's rate, like a strike;
##  - a fighter in a light charge is stopped by any blast; one in a heavy charge shrugs off a shot of power 1 at half
##    damage, and is stopped by more.
## Nobody is locked: the shooter keeps flying while he winds up, and an exchange that takes him cancels it.
## State: the fighter's director state (f.act.dirI: DirInterrupt.BLAST_*, PB_SHOT, AI_SHOT). Numbers:
## data/director/interrupts.json `blast`; the shots' own are data/fight/shots.json.

const QUEUED: int = 3 << 1     # BLAST_REQ: more bolts waiting behind the one winding up (0 to 3)
const CHARGE_SHIFT: int = 3    # BLAST_REQ: ticks the heavy has charged (7 bits)
const TARGET_SHIFT: int = 10   # BLAST_REQ: the charge the AI means to reach (7 bits)


static func data() -> Dictionary:
	return DirInterrupt.data().get("blast", {})


static func on() -> bool:
	return DirInterrupt.on() and data().get("enabled", false)


## True when the director's rules decide what a shot does to a fighter (SimShots.hitFighter): the blasts are on and a
## blast press has been made in this match. A shot fired with no press at all (the core's own proofs) keeps the plain
## rule.
static func rules(S: SimState) -> bool:
	if not on():
		return false
	for f in S.fighters:
		if DirInterrupt.gi(f, DirInterrupt.BLAST_AT) != DirInterrupt.NEVER:
			return true
	return false


## A's attack press with the energy family held, on its own tick (DirExchange.requestAttack). True when the press was
## a blast press and is spent here. False inside an exchange of his, where an energy press is a link as before.
static func press(S: SimState, A, weight: int) -> bool:
	if not on() or S.game.ko != null:
		return false
	var ex = S.dirS.ex
	if ex != null and (ex.A == A or ex.D == A):
		return false
	if DirBands.pending(A):
		return true   # he is on his way in: the press is spent
	if (A.state != "free" and A.state != "charging") or A.stunTicks > 0:
		return true   # he cannot fire now: an energy press never becomes a rush
	var c: Dictionary = data()
	var left: int = DirInterrupt.gi(A, DirInterrupt.BLAST_LEFT)
	var req: int = DirInterrupt.gi(A, DirInterrupt.BLAST_REQ)
	if left > 0:
		DirInterrupt.si(A, DirInterrupt.BLAST_AT, S.tick)
		if weight == SimAct.LIGHT and (req & 1) == SimAct.LIGHT:
			var q: int = (req & QUEUED) >> 1
			DirInterrupt.si(A, DirInterrupt.BLAST_REQ, (req & ~QUEUED) | (mini(q + 1, int(c.light.queueMax)) << 1))
		return true   # one blast winds up at a time
	DirBands.endTaunt(S, A, false, "cut")
	A.state = "free"
	DirInterrupt.si(A, DirInterrupt.BLAST_AT, S.tick)
	var w: Dictionary = c.heavy if weight == SimAct.HEAVY else c.light
	req = weight
	if weight == SimAct.HEAVY and A.ai != null:
		req |= int(S.rng.next() * (float(c.heavy.chargeTicks) + 1.0)) << TARGET_SHIFT   # how long the AI charges: one draw
	elif weight == SimAct.LIGHT and A.ai != null:
		req |= (int(c.light.aiVolley) - 1) << 1   # the AI's light is a volley
	DirInterrupt.si(A, DirInterrupt.BLAST_LEFT, int(w.windupTicks))
	DirInterrupt.si(A, DirInterrupt.BLAST_REQ, req)
	SimFx.cue(S, A, "blast_charge" if weight == SimAct.HEAVY else "blast_windup", "", "")
	return true


## The layout's hold edge with the energy family held, outside an exchange: the light he pressed becomes the heavy. A
## bolt still winding up turns into the charged shot's charge; if it has left, the charge starts now. True when the
## edge was a blast's and is spent here (a signature's edge is not).
static func upgrade(S: SimState, f, weight: int) -> bool:
	if not on() or weight != SimAct.HEAVY or f.act.mode != 1 or S.game.ko != null:
		return false
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		return false
	if DirBands.pending(f) or (f.state != "free" and f.state != "charging") or f.stunTicks > 0:
		return true
	if DirInterrupt.gi(f, DirInterrupt.BLAST_LEFT) > 0 and (DirInterrupt.gi(f, DirInterrupt.BLAST_REQ) & 1) == SimAct.HEAVY:
		return true   # already charging
	DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, int(data().heavy.windupTicks))
	DirInterrupt.si(f, DirInterrupt.BLAST_REQ, SimAct.HEAVY)
	SimFx.cue(S, f, "blast_charge", "", "")
	return true


## Once a live tick, after the approaches: each blast winding up counts down and leaves, a heavy charges while its
## button is held, and the AI weighs a perfect block against a shot about to reach it.
static func tick(S: SimState) -> void:
	if not on():
		return
	for f in S.fighters:
		_aiBlock(S, f)
		var left: int = DirInterrupt.gi(f, DirInterrupt.BLAST_LEFT)
		if left <= 0:
			continue
		var ex = S.dirS.ex
		if S.game.ko != null or (f.state != "free" and f.state != "charging") or f.stunTicks > 0 or (ex != null and (ex.A == f or ex.D == f)) or DirBands.pending(f):
			DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, 0)   # taken by an exchange, staggered or sent flying: it never leaves
			SimFx.cue(S, f, "blast_cancel", "", "")
			continue
		var c: Dictionary = data()
		var req: int = DirInterrupt.gi(f, DirInterrupt.BLAST_REQ)
		left -= 1
		if (req & 1) == SimAct.HEAVY:
			var charge: int = (req >> CHARGE_SHIFT) & 127
			var holding: bool = f.input.heavyHeld if f.ai == null else charge < ((req >> TARGET_SHIFT) & 127)
			if holding and charge < int(c.heavy.holdMaxTicks):
				charge += 1
				req = (req & ~(127 << CHARGE_SHIFT)) | (charge << CHARGE_SHIFT)
				DirInterrupt.si(f, DirInterrupt.BLAST_REQ, req)
				if charge == int(c.heavy.chargeTicks):
					SimFx.cue(S, f, "blast_full", "", "")   # the flash: it is at full charge
			if left <= 0 and (not holding or charge >= int(c.heavy.holdMaxTicks)):
				DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, 0)
				_fire(S, f, SimAct.HEAVY, minf(1.0, float(charge) / float(c.heavy.chargeTicks)))
			else:
				DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, maxi(left, 1))
		elif left <= 0 and f.ai == null and f.input.upgrade == 0 and f.input.lightHeld and ((req >> CHARGE_SHIFT) & 127) < int(c.light.holdTicks):
			# still held: it waits for the release, or for a layout's hold to turn it into the heavy (upgrade)
			DirInterrupt.si(f, DirInterrupt.BLAST_REQ, req + (1 << CHARGE_SHIFT))
			DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, 1)
		elif left <= 0 and f.input.upgrade != 0 and f.ai == null:
			DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, 1)   # the hold's edge is this tick: the upgrade takes it
		elif left <= 0:
			_fire(S, f, SimAct.LIGHT, 0.0)
			var q: int = (req & QUEUED) >> 1
			if q > 0:
				DirInterrupt.si(f, DirInterrupt.BLAST_REQ, (req & ~QUEUED) | ((q - 1) << 1))
				DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, int(c.light.windupTicks))
			else:
				DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, 0)
		else:
			DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, left)


## The shot leaves f for his rival: it seeks him, and arrives. A charged shot's damage rises from tapShare of the kind's
## to all of it with the charge. Bolts fired within groupTicks of each other share a group: one volley.
static func _fire(S: SimState, f, weight: int, charge: float) -> void:
	var c: Dictionary = data()
	var w: Dictionary = c.heavy if weight == SimAct.HEAVY else c.light
	if f.ki < float(w.ki):
		if f.ai == null:
			SimFx.banner(S, "NEED " + SimMathx.jstr(float(w.ki)) + " KI", "#9fb4ff", 0.6)
		DirInterrupt.si(f, DirInterrupt.BLAST_REQ, DirInterrupt.gi(f, DirInterrupt.BLAST_REQ) & ~QUEUED)
		return
	var slot: int = S.fighters.find(f)
	var o = SimRoster.opp(S, f)
	var kind: String = String(w.kind)
	var o2: Dictionary = {"target": S.fighters.find(o)}
	if weight == SimAct.HEAVY:
		o2["dmg"] = float(SimShots.kinds[kind].dmg) * (float(w.tapShare) + (1.0 - float(w.tapShare)) * charge)
	else:
		var g: int = DirInterrupt.gi(f, DirInterrupt.BLAST_GROUP)
		if g == 0 or S.tick - DirInterrupt.gi(f, DirInterrupt.BLAST_LAST) > int(w.groupTicks):
			g = S.shotSeq + 1   # a new volley: its group is its first shot's id
		DirInterrupt.si(f, DirInterrupt.BLAST_GROUP, g)
		DirInterrupt.si(f, DirInterrupt.BLAST_LAST, S.tick)
		o2["group"] = g
	f.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)
	var sh = SimShots.fire(S, slot, kind, o2)
	if sh == null:
		return   # the cap on live shots: the press is spent
	f.ki -= float(w.ki)
	SimEvents.feed(S, f.name + (" CHARGED SHOT" if weight == SimAct.HEAVY else " BOLT"), ("charge " + str(int(charge * 100.0)) + "%, " if weight == SimAct.HEAVY else "") + "arrives in " + str(sh.left) + " ticks")


## The window, in ticks before it arrives, in which f's fresh guard press perfect-blocks the shot: the blast class's, by
## the shot's weight (power 2 and over is a heavy's).
static func _window(f, sh) -> float:
	return DirInterrupt._window(f, "blast", sh.power >= 2.0)


## The shot f's guard press would perfect-block now: the soonest one seeking him that is inside its window. Or null.
static func windowShot(S: SimState, f):
	var slot: int = S.fighters.find(f)
	var best = null
	for sh in S.shots:
		if sh.dead or sh.owner == slot or sh.mode != SimShots.SEEK or sh.tgt != slot:
			continue
		if float(sh.left) <= _window(f, sh) + 0.5 and (best == null or sh.left < best.left):
			best = sh
	return best


## True when f's latest attack press was a blast press, within the given ticks: a fighter who is firing is not
## pressing to meet a blow (DirData._flags).
static func pressedLately(S: SimState, f, ticks: float) -> bool:
	return on() and float(S.tick - DirInterrupt.gi(f, DirInterrupt.BLAST_AT)) <= ticks


## True while a shot is on its way to f: a wind-up he can see (the guard lockout's rule).
static func incoming(S: SimState, f) -> bool:
	var slot: int = S.fighters.find(f)
	for sh in S.shots:
		if not sh.dead and sh.owner != slot and sh.mode == SimShots.SEEK and sh.tgt == slot:
			return true
	return false


## f's fresh guard press with a shot inside its window (DirInterrupt.guardPress): the shot is marked, and its whole
## volley with it. The block resolves when it arrives (hit).
static func mark(S: SimState, f) -> bool:
	if not on():
		return false
	var sh = windowShot(S, f)
	if sh == null:
		return false
	DirInterrupt.si(f, DirInterrupt.PB_SHOT, sh.group if sh.group != 0 else -sh.id)
	DirInterrupt.si(f, DirInterrupt.PB_DEFL, sh.deflected)   # the mark is for this arrival: a shot sent back and returned needs a new press
	return true


## The AI's perfect block against a shot: once for each shot or volley, as it comes inside the window, one draw at its
## usual rate for the state it holds, times its level's share.
static func _aiBlock(S: SimState, f) -> void:
	if f.ai == null or f.stunTicks > 0 or S.shots.is_empty():
		return
	var sh = windowShot(S, f)
	if sh == null or float(sh.left) > 6.5:
		return
	var key: int = (sh.group if sh.group != 0 else -sh.id) * 16 + (sh.deflected & 15)   # once for each arrival of a shot or a volley
	if DirInterrupt.gi(f, DirInterrupt.AI_SHOT) == key:
		return
	DirInterrupt.si(f, DirInterrupt.AI_SHOT, key)
	var st: int = int(f.ai.st)
	var r5: Dictionary = DirAI.skill().perfectBlock
	var p: float = float(r5.guard) if st == 1 else (float(r5.press) if st == 0 else 0.0)
	if p > 0.0 and sh.power >= 2.0:
		p += float(r5.heavyAdd)
	if p > 0.0 and S.rng.next() < p * float(DirAI.lv().perfectBlockMul):
		DirInterrupt.guardPress(S, f)


## A shot has met f (SimShots.hitFighter). True when the shot ends on him.
static func hit(S: SimState, sh, f) -> bool:
	var c: Dictionary = data()
	var by = S.fighters[sh.owner]
	var slot: int = S.fighters.find(f)
	# Just out of his crater he is safe: the shot passes. Buried and helpless, he answers nothing: it is the follow-up.
	if DirBury.safe(S, f):
		SimFx.shotHit(S, sh, f, "safe")
		return false
	if DirBury.helpless(f):
		DirBury.blasted(f)
		SimDamage.hit(S, null, by, f, sh.dmg, {"kind": "blast", "ignoreStance": true, "stop": float(c.stopTicks) / DirData.TICKS_PER_SEC, "shake": 7.0})
		SimFx.shotHit(S, sh, f, "buried")
		return true
	# The dodge: inside his dodge window he lets it pass, and it flies on.
	if f.state != "launched" and f.state != "down" and f.stunTicks <= 0 and S.tick - f.act.dodgeTick < SimAct.dodgeWindow:
		SimFx.shotHit(S, sh, f, "dodge")
		return false
	# The perfect block: the guard press that marked it. The shot turns round and seeks the one who fired it.
	var key: int = sh.group if sh.group != 0 else -sh.id
	if DirInterrupt.gi(f, DirInterrupt.PB_SHOT) == key and DirInterrupt.gi(f, DirInterrupt.PB_DEFL) == sh.deflected and f.stunTicks <= 0 and f.state != "launched" and f.state != "down":
		f.ki = SimMathx.jmin(100.0, f.ki + float(DirInterrupt.data().perfectBlock.ki))
		SimFx.shotHit(S, sh, f, "deflect")
		SimShots.deflect(S, sh, slot)
		SimFx.cue(S, f, "perfect_block", "", "")
		SimEvents.feed(S, f.name + " DEFLECTS", "a perfect block: the " + sh.kind + " goes back to " + by.name)
		return false
	# A charge: a light one is stopped by any blast; a heavy one shrugs off a weak shot at part of its damage.
	var dmg: float = sh.dmg
	var outcome: String = "guard" if f.stance == 1.0 else "hit"
	if DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.CHARGE) != 0:
		var heavyCharge: bool = (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & 3) == SimAct.HEAVY
		if heavyCharge and sh.power <= float(c.charge.shrugPower):
			dmg *= float(c.charge.shrugMul)
			outcome = "shrug"
		else:
			DirBands.drop(S, f, "a " + sh.kind + " stopped his charge")
			SimFx.cue(S, f, "charge_stopped", "", "")
			outcome = "stop"
	SimDamage.hit(S, null, by, f, dmg, {"kind": "blast", "stop": float(c.stopTicks) / DirData.TICKS_PER_SEC, "shake": 3.0 if sh.power < 2.0 else 7.0})
	SimFx.shotHit(S, sh, f, outcome)
	return true
