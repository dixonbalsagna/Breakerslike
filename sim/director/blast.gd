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
	if DirBury.blastFollow(S, A, SimRoster.opp(S, A)):
		DirInterrupt.si(A, DirInterrupt.BLAST_LEFT, 0)   # a blast of his own winding up gives way
		DirBury.fireBlast(S, A, SimRoster.opp(S, A))   # the other free blow on a buried rival: a charged shot, at once
		return true
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
	if weight == SimAct.HEAVY:
		DirAlchemy.flash(A, SimAct.HEAVY, S.tick + int(c.heavy.chargeTicks) - 1)   # the planned flash of the full charge: a release is graded against it
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
				DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, int(c.light.get("aiGapTicks", c.light.windupTicks)) if f.ai != null else int(c.light.windupTicks))   # the AI spaces its volley: measured bolts
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
		var gap: int = S.tick - DirInterrupt.gi(f, DirInterrupt.BLAST_LAST)
		if g == 0 or gap > int(w.groupTicks):
			g = S.shotSeq + 1   # a new volley: its group is its first shot's id
		DirInterrupt.si(f, DirInterrupt.BLAST_GROUP, g)
		DirInterrupt.si(f, DirInterrupt.BLAST_LAST, S.tick)
		o2["group"] = g
		_spray(S, f, o2, gap)
	f.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)
	var sh = SimShots.fire(S, slot, kind, o2)
	if sh == null:
		return   # the cap on live shots: the press is spent
	f.ki -= float(w.ki)
	SimEvents.feed(S, f.name + (" CHARGED SHOT" if weight == SimAct.HEAVY else " BOLT"), ("charge " + str(int(charge * 100.0)) + "%, " if weight == SimAct.HEAVY else "") + ("arrives in " + str(sh.left) + " ticks" if sh.mode == SimShots.SEEK else "sprayed wide of him (spread " + str(DirInterrupt.gi(f, DirInterrupt.SPRAY) / 10) + "%)"))


## The spray cone (agency-pass.md section 15.4; interrupts.json blast.spray). A bolt fired measuredTicks or more after
## the last seeks, as before, and his spread recovers at recoverPerSec. Each bolt fired sooner adds perBolt to his
## spread, up to max. A bolt then still seeks with a chance of 1 - missShare x spread; otherwise it flies straight
## inside the cone at the rival (slopeMin at no spread to slopeMax at full) and explodes where it lands. The draw is
## keyed on the match seed and the shot's id: no stream shifts and a replay matches.
static func _spray(S: SimState, f, o2: Dictionary, gap: int) -> void:
	var sp: Dictionary = data().get("spray", {})
	if sp.is_empty():
		return
	var s: float = float(DirInterrupt.gi(f, DirInterrupt.SPRAY)) / 1000.0
	if gap < int(sp.measuredTicks):
		s = minf(float(sp.max), s + float(sp.perBolt))
	else:
		s = maxf(0.0, s - float(sp.recoverPerSec) * float(gap) / DirData.TICKS_PER_SEC)
	DirInterrupt.si(f, DirInterrupt.SPRAY, int(round(s * 1000.0)))
	if s > 0.0 and SimRng.keyed(int(S.game.seed), "blast.spray", S.shotSeq + 1) < float(sp.missShare) * s:
		o2["aim"] = o2.target
		o2.erase("target")
		o2["spread"] = float(sp.slopeMin) + (float(sp.slopeMax) - float(sp.slopeMin)) * s


## True when mines can be laid (interrupts.json blast.mine).
static func minesOn() -> bool:
	return on() and data().get("mine", {}).get("enabled", false)


## f's context press outside an exchange of his (DirInterrupt.tick): on a held guard it is the context deflect, and
## with the energy family held it lays a mine.
static func context(S: SimState, f) -> void:
	if not on() or S.game.ko != null:
		return
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		return
	if f.input.guard:
		_contextDeflect(S, f)
	elif f.act.mode == 1:
		layMine(S, f)


## The context deflect (section 15.2): with guard held, the context press sets a deflect on the shot coming at him,
## for deflect.context.ki and with no timing. It sends the shot off as a perfect block does, with none of its rewards.
static func _contextDeflect(S: SimState, f) -> void:
	var cd: Dictionary = data().get("deflect", {}).get("context", {})
	if cd.is_empty() or f.state == "launched" or f.state == "down" or f.ki < float(cd.ki):
		return
	var slot: int = S.fighters.find(f)
	var best = null
	for sh in S.shots:
		if sh.dead or sh.owner == slot or sh.mode != SimShots.SEEK or sh.tgt != slot:
			continue
		if best == null or sh.left < best.left:
			best = sh
	if best == null:
		return
	var key: int = best.group if best.group != 0 else -best.id
	if DirInterrupt.gi(f, DirInterrupt.CTX_SHOT) == key and DirInterrupt.gi(f, DirInterrupt.CTX_DEFL) == best.deflected:
		return   # already set for this shot
	f.ki -= float(cd.ki)
	DirInterrupt.si(f, DirInterrupt.CTX_SHOT, key)
	DirInterrupt.si(f, DirInterrupt.CTX_DEFL, best.deflected)
	SimFx.cue(S, f, "context_deflect_set", "", "")


## The mine (section 15.5; interrupts.json blast.mine): laid where he is, hovering, or resting on the ground when he
## stands on it. It costs mine.ki. The core holds the cap, the gap between mines, the arming, the trigger, the blast
## and the chain (data/fight/shots.json, the kind's mine block). Inside shoveWithinBh of the rival the press is the
## energy shove's, which is not built: nothing happens.
static func layMine(S: SimState, f) -> void:
	if not minesOn() or (f.state != "free" and f.state != "charging") or DirBands.pending(f):
		return
	var m: Dictionary = data().mine
	if DirBands.dist(f, SimRoster.opp(S, f)) <= float(m.shoveWithinBh) * DirInterrupt.BH:
		return
	if f.ki < float(m.ki):
		if f.ai == null:
			SimFx.banner(S, "NEED " + SimMathx.jstr(float(m.ki)) + " KI", "#9fb4ff", 0.6)
		return
	var grounded: bool = f.y - WorldTerrain.groundY(S, f.x) <= float(m.groundWithinBh) * DirInterrupt.BH
	var sh = SimShots.fire(S, S.fighters.find(f), String(m.kind), {"ground": grounded})
	if sh == null:
		SimFx.cue(S, f, "mine_refused", "", "")   # the cap on live shots, or too near another mine: the press is spent
		return
	f.ki -= float(m.ki)
	DirInterrupt.si(f, DirInterrupt.BLAST_AT, S.tick)
	SimFx.cue(S, f, "mine_lay", "", "")
	SimEvents.feed(S, f.name + " LAYS A MINE", "on the ground" if grounded else "hovering")


## A mine's blast has reached f, who is not its owner (the core gives the owner his own share). It cannot be dodged
## or deflected; a held guard takes it at the guard's rate. Unguarded, on a fighter who is up and outside an exchange,
## it knocks him back from the mine, and that is decisive.
static func _mineHit(S: SimState, sh, by, f) -> bool:
	var c: Dictionary = data()
	if DirBury.safe(S, f):
		SimFx.shotHit(S, sh, f, "safe")
		return true
	var guarded: bool = f.stance == 1.0 and f.state != "down" and f.state != "launched"
	var brink0: bool = f.brink
	SimDamage.hit(S, null, by, f, sh.dmg, {"kind": "blast", "ignoreStance": not guarded, "stop": float(c.stopTicks) / DirData.TICKS_PER_SEC, "shake": 7.0})
	SimFx.shotHit(S, sh, f, "guard" if guarded else "hit")
	if guarded or S.game.ko != null or S.dirS.ex != null or (f.state != "free" and f.state != "charging"):
		return true
	if DirBands.pending(f):
		DirBands.drop(S, f, "a mine knocked him back")
	DirLaunch.knock(S, by, f, 1.0, sh.x)
	SimEvents.feed(S, "MINE: KNOCK BACK", by.name + "'s mine caught " + f.name + ": decisive")
	DirExchange.decisiveShot(S, by, f, -sh.id, brink0, "blast")
	return true


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
	if sh.mode == SimShots.MINE:
		return _mineHit(S, sh, by, f)
	# Just out of his crater he is safe: the shot passes. Buried and helpless, he answers nothing: it is the follow-up.
	if DirBury.followShot(f, sh):
		DirBury.shotLanded(f)   # the follow-up he was held for: it lands clean
		SimDamage.hit(S, null, by, f, sh.dmg, {"kind": "blast", "ignoreStance": true, "stop": float(c.stopTicks) / DirData.TICKS_PER_SEC, "shake": 7.0})
		SimFx.shotHit(S, sh, f, "buried")
		return true
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
		var fa: int = int(c.get("deflect", {}).get("freeApproachTicks", 0))
		if fa > 0:
			DirInterrupt.si(f, DirInterrupt.FREE_UNTIL, S.tick + fa)   # section 15.2: his next charge or lunge in that time is stopped by no shot
		SimEvents.feed(S, f.name + " DEFLECTS", "a perfect block: the " + sh.kind + (" flies wild" if SimShots.scatter else " goes back to " + by.name) + ("; a free approach for " + str(fa) + " ticks" if fa > 0 else ""))
		return false
	# The context deflect: set by the context press on a held guard. The shot is sent off; no ki back, no free approach.
	if DirInterrupt.gi(f, DirInterrupt.CTX_SHOT) == key and DirInterrupt.gi(f, DirInterrupt.CTX_DEFL) == sh.deflected and f.stunTicks <= 0 and f.state != "launched" and f.state != "down":
		SimFx.shotHit(S, sh, f, "deflect")
		SimShots.deflect(S, sh, slot)
		SimFx.cue(S, f, "context_deflect", "", "")
		SimEvents.feed(S, f.name + " DEFLECTS", "the context deflect: the " + sh.kind + (" flies wild" if SimShots.scatter else " goes back to " + by.name))
		return false
	# A charge: a light one is stopped by any blast; a heavy one shrugs off a weak shot at part of its damage.
	var dmg: float = sh.dmg
	var outcome: String = "guard" if f.stance == 1.0 else "hit"
	if DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.FREE) != 0:
		dmg *= float(c.charge.shrugMul)   # the free approach a deflect earned: any shot is shrugged off, and he keeps coming
		outcome = "shrug"
	elif DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.CHARGE) != 0:
		var heavyCharge: bool = (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & 3) == SimAct.HEAVY
		if heavyCharge and sh.power <= float(c.charge.shrugPower):
			dmg *= float(c.charge.shrugMul)
			outcome = "shrug"
		else:
			DirBands.drop(S, f, "a " + sh.kind + " stopped his charge")
			SimFx.cue(S, f, "charge_stopped", "", "")
			outcome = "stop"
	var brink0: bool = f.brink
	SimDamage.hit(S, null, by, f, dmg, {"kind": "blast", "stop": float(c.stopTicks) / DirData.TICKS_PER_SEC, "shake": 3.0 if sh.power < 2.0 else 7.0})
	SimFx.shotHit(S, sh, f, outcome)
	var knocked: bool = _knock(S, sh, by, f, outcome, brink0)
	_barrage(S, sh, by, f, outcome, brink0, knocked)
	return true


## A barrage closes (agency-pass.md sections 16 and 21), as a blur does: when enderAfter of a fighter's shots, of any
## kind, land clean on his rival inside 'window' ticks, the last is a knock-back he did not press: decisive, never a
## launch. Clean: not guarded, not shrugged off, not a shot that was deflected. Each shot counts once; the shots of a
## group that is not a run of pressed bolts (a split, a rain: one press, several shots) count once for the group. If
## each was fired measuredTicks or more after the one before, it goes the tier's full distance and is a full set-up;
## otherwise enderDist.plain of it and half a set-up. The count starts again, and the rival cannot be knocked back by
## another barrage for 'immune' ticks. A shot that would close while he is in an exchange, down, flying or immune
## still counts, and the next clean one closes. knocked: this shot was a full charged one and has knocked him back
## by itself (_knock): it counts, and the barrage does not close on it.
static func _barrage(S: SimState, sh, by, f, outcome: String, brink0: bool, knocked: bool = false) -> void:
	var c: Dictionary = data().get("barrage", {})
	if c.is_empty() or sh.deflected != 0 or (outcome != "hit" and outcome != "stop"):
		return
	# Pressed bolts share a group when fired close together (one volley to block), and each is still a shot of its own.
	if sh.group != 0 and sh.kind != String(data().light.kind):
		if DirInterrupt.gi(by, DirInterrupt.BAR_GROUP) == sh.group:
			return
		DirInterrupt.si(by, DirInterrupt.BAR_GROUP, sh.group)
	var flight: int = clampi(sh.total - sh.left, 0, 4095)
	var fires: Array = [S.tick - flight]   # the fire ticks of the clean bolts inside the window, newest first
	for k in [DirInterrupt.BAR_1, DirInterrupt.BAR_2, DirInterrupt.BAR_3]:
		var v: int = DirInterrupt.gi(by, k)
		if v != 0 and S.tick - (v >> 12) < int(c.window):
			fires.append((v >> 12) - (v & 4095))
	var up: bool = not knocked and S.game.ko == null and S.dirS.ex == null and (f.state == "free" or f.state == "charging")
	if fires.size() < int(c.enderAfter) or not up or S.tick < DirInterrupt.gi(f, DirInterrupt.BAR_IMMUNE):
		DirInterrupt.si(by, DirInterrupt.BAR_3, DirInterrupt.gi(by, DirInterrupt.BAR_2))
		DirInterrupt.si(by, DirInterrupt.BAR_2, DirInterrupt.gi(by, DirInterrupt.BAR_1))
		DirInterrupt.si(by, DirInterrupt.BAR_1, (S.tick << 12) | flight)
		# The AI's answer (section 16: a held guard stops the count): as the barrage reaches half way, one draw at its
		# level's rate, and it holds guard until those bolts have left the window.
		if f.ai != null and fires.size() == int(c.enderAfter) / 2 and S.rng.next() < float(DirAI.lv().get("barrageGuard", 0.0)):
			DirInterrupt.si(f, DirInterrupt.BAR_GUARD, S.tick + int(c.window))
		return
	var measured: bool = true
	for k in range(int(c.enderAfter) - 1):
		if int(fires[k]) - int(fires[k + 1]) < int(c.measuredTicks):
			measured = false
	for k in [DirInterrupt.BAR_1, DirInterrupt.BAR_2, DirInterrupt.BAR_3]:
		DirInterrupt.si(by, k, 0)
	DirInterrupt.si(f, DirInterrupt.BAR_IMMUNE, S.tick + int(c.immune))
	if DirBands.pending(f):
		DirBands.drop(S, f, "a barrage knocked him back")
	DirLaunch.knock(S, by, f, float(c.enderDist.measured if measured else c.enderDist.plain))
	SimFx.cue(S, by, "barrage_ender", "", "")
	SimEvents.feed(S, "BARRAGE ENDER", by.name + "'s " + str(int(c.enderAfter)) + " clean shots inside " + str(int(c.window)) + " ticks: a knock-back, " + ("measured" if measured else "spammed (the weak one)"))
	DirExchange.decisiveShot(S, by, f, -sh.id, brink0, "barrage", "barrage" if measured else "barragePlain")


## A fully charged shot that lands clean knocks him back, and that is decisive (agency-pass.md section 14.6). Clean:
## not guarded and not shrugged off. Outside an exchange only, on a fighter who is up. True when it knocked him back.
static func _knock(S: SimState, sh, by, f, outcome: String, brink0: bool) -> bool:
	var c: Dictionary = data()
	if not c.heavy.get("knockFull", false) or S.game.ko != null or S.dirS.ex != null:
		return false
	if sh.kind != String(c.heavy.kind) or sh.dmg < float(SimShots.kinds[sh.kind].dmg) - 0.001:
		return false
	if (outcome != "hit" and outcome != "stop") or (f.state != "free" and f.state != "charging"):
		return false
	if DirBands.pending(f):
		DirBands.drop(S, f, "a full charged shot knocked him back")
	DirLaunch.knock(S, by, f, 1.0)
	SimEvents.feed(S, "CHARGED SHOT: KNOCK BACK", "a full charge landed clean on " + f.name + ": decisive")
	DirExchange.decisiveShot(S, by, f, -sh.id, brink0)
	return true
