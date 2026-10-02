class_name DirAI
## Opponent AI (Encounter Systems): born as the twin of ai.js (pickW, aiInput); since ADR 0006 it has its own tempo and
## fight-location rules (balance-targets.md section 10): a slower attack cadence, the hero's lure toward empty land
## instead of the sea, fighters who stay at the surface unless hiding, and escape cover that prefers forest and ridge.
## Timers count down by the fixed DT.


## True while f is the defender of a signature whose outcome is still to be decided at its fire beat (step 2b).
static func _beamTell(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	return ex != null and ex.kind == "sig" and ex.D == f and ex.branch == "" and DirData.beamAtFire()


## Index drawn with probability proportional to its weight. One draw from S.rng.
static func pickW(S: SimState, w: Array) -> int:
	var s: float = 0.0
	for v in w:
		s += v
	var r: float = S.rng.next() * s
	for k in range(w.size()):
		r -= w[k]
		if r <= 0.0:
			return k
	return 0


static func aiInput(S: SimState, f) -> void:
	var o = SimRoster.opp(S, f)
	var i: SimIntent = f.input
	var a = f.ai
	# I2b: the AI writes the v2 record. Its stance choice lives in a.st, and the held states below stand for it, so the
	# director reads the AI's stance through the same path as a player's (SimAct.stance). A ready form is taken at once.
	f.act.v2 = true
	i.mode = 0   # the physical family, unless this tick's press is a blast (below)
	if f.act.formReady:
		i.transform = true
	var d: float = SimWrap.sdx(f.x, o.x)
	var dist: float = absf(d)
	# Since S2 the AI reads its wounds, not an HP bar: 1 fresh, 0 on the brink (SimWounds.vitality).
	var hpF: float = SimWounds.vitality(f)
	a.t -= SimConst.DT
	# The attack timer runs only between exchanges and is held at the stance minimum during one, so the cadence is
	# breathing room after a release.
	if S.dirS.ex == null and DirBands.who(S) < 0:
		a.atk -= SimConst.DT
		# No lull over about 10 s: GAP_URGE seconds after the last exchange, attack within GAP_SOON. The clock is the
		# exchange's (exT), not the last press: a press at a launched target is refused but still stamps lastAtkT, which
		# held the urge off through long flights (S3b: 18 of the 25 gaps over 10 s in 200 matches).
		if S.T - SimMathx.jmax(f.exT, o.exT) > GAP_URGE and a.atk > GAP_SOON:
			a.atk = GAP_SOON
	else:
		a.atk = SimMathx.jmax(a.atk, CAD_MIN[int(a.st)])
	if a.t <= 0.0:
		a.t = S.rng.range_(0.7, 1.6)
		var w: Array = [2.4 if hpF > 0.35 else 1.0, 1.6 if hpF < 0.55 else 0.7, 1.2, 3.2 if hpF < 0.3 else (1.2 if f.ki < 25.0 else 0.25)]
		# Step 3: against a rival that has opened three exchanges running with one weight, the AI guards more (its level's weight): the guard, the perfect
		# block and the punish window are the answers to a masher.
		if DirInterrupt.on() and DirInterrupt.gi(o, DirInterrupt.WEIGHT_RUN) >= 3:
			w[1] += float(lv().guardRepeat)
		if o.hidden:
			w = [3.0, 0.3, 0.3, 0.1]
		# Stay in cover only while cover still heals: ki, or a battered region still fading (broken ones never do).
		if f.hidden and f.canHide and (f.ki < 85.0 or _healing(f)):
			w = [0.0, 0.0, 0.0, 1.0]
		if f.state == "free":
			a.st = float(pickW(S, w))
	# A charge is a held button: the AI keeps its button down while its taunt or its approach lasts.
	var hold: int = DirInterrupt.gi(f, DirInterrupt.AI_HOLD)
	if hold > 0:
		if DirBands.taunting(f) or DirBands.pending(f):
			i.lightHeld = hold == 1
			i.heavyHeld = hold == 2
		else:
			DirInterrupt.si(f, DirInterrupt.AI_HOLD, 0)
	# The rival is coming, or taunting (DirBands): the answer the AI chose, once its reaction time is up. It guards,
	# dodges, or presses to meet him.
	if f.state == "free" and DirBury.aiFollow(S, f, o):
		i.heavy = true   # the free blow on a buried rival, at its level's rate
	var ans: int = DirBands.aiAnswer(f, o) if f.state == "free" else DirBands.R_NONE
	if ans == DirBands.R_GUARD:
		a.st = 1.0
	elif ans == DirBands.R_DODGE:
		a.st = 2.0
	elif ans == DirBands.R_LIGHT:
		i.light = true
	elif ans == DirBands.R_HEAVY:
		i.heavy = true
	var st: float = a.st
	# The held states for the chosen stance: Guard holds guard; Dodge re-taps the dodge before its window lapses; Escape
	# sprints (and moves away, below); Press holds nothing. They are written in every state, so a downed AI keeps its guard.
	if st == 1.0:
		i.guard = true
	elif st == 2.0:
		# Never inside a melee exchange: there a dodge is the cancel (step 3). During a beam's tell it is the Dodge answer.
		i.dodge = (S.dirS.ex == null or _beamTell(S, f)) and S.tick - f.act.dodgeTick >= SimAct.dodgeWindow - 1
	elif st == 3.0:
		i.sprint = true
		if _beamTell(S, f):
			i.mx = -SimMathx.jsign(d) if d != 0.0 else 1.0   # still sprinting away at the fire beat: the ESCAPE gamble
	var free: bool = f.state == "free" or f.state == "charging"
	if not free:
		return
	# Location (DirLocation.roam): the hero leads fights away from people and on from a biome it has overstayed; the villain
	# prowls toward towns at high tiers. A DEFENSIVE fighter low on ki charges first (the lure used to starve it of ki).
	var wantsCharge: bool = st == 1.0 and f.ki < 55.0 and dist > 350.0
	# The roam yields while the opponent is out of lock: a hunter sweeps for it (below) and never leads the fight away from
	# a target it has lost (QA: the roam ran before the hunt, so a roaming hunter did not search).
	var lure: float = DirLocation.roam(S, f) if st != 3.0 and not wantsCharge and not o.hidden and DirBands.who(S) < 0 else 0.0
	var sea: bool = WorldTerrain.seaAt(S, f.x)
	if lure != 0.0:
		i.mx = lure
		i.dash = true
		i.my = 1.0 if sea and f.y < SURFACE_Y else 0.0
	elif st == 0.0 and o.hidden and o.lastSeen != null:
		# Hunt: sweep random offsets around the last known position, re-rolled every 1.2 to 2.4 s.
		a.sT -= SimConst.DT
		if a.sT <= 0.0:
			a.sT = S.rng.range_(1.2, 2.4)
			a.sOff = S.rng.range_(-1700.0, 1700.0)
			SimFx.searching(S, f, o, o.lastSeen.x + a.sOff, "sweep")
		var tx: float = o.lastSeen.x + a.sOff
		var sd: float = SimWrap.sdx(f.x, tx)
		i.mx = SimMathx.jsign(sd) if absf(sd) > 60.0 else 0.0
		i.dash = absf(sd) > 1500.0
		# Sweep low over land; over the sea, sweep at the surface rather than diving.
		i.my = -1.0 if not sea else (1.0 if f.y < SURFACE_Y else 0.0)
	elif st == 0.0 and dist <= CIRCLE_R:
		# In reach an AGGRESSIVE fighter never halts (dynamic feel): it circles the opponent on an ellipse, weaving,
		# until its attack beat. The two slots circle half a turn apart. No draws.
		var ph: float = S.T * CIRCLE_RATE + (3.14159265358979 if f == S.fighters[1] else 0.0)
		var cx: float = SimWrap.sdx(f.x, o.x + CIRCLE_X * SimDetMath.sin(ph))
		var cy: float = SimMathx.jmax(o.y, SURFACE_Y) if sea else o.y
		cy = cy + CIRCLE_Y * SimDetMath.cos(ph) - f.y
		i.mx = SimMathx.jsign(cx) if absf(cx) > 20.0 else 0.0
		i.my = SimMathx.jsign(cy) if absf(cy) > 20.0 else 0.0
	elif st == 0.0:
		i.mx = SimMathx.jsign(d) if dist > 130.0 else 0.0
		i.dash = dist > 700.0
		# Close in on the opponent's height, but not below the surface: underwater is for hiding, not fighting.
		var ty: float = SimMathx.jmax(o.y, SURFACE_Y) if sea else o.y
		var dy: float = ty - f.y
		i.my = SimMathx.jsign(dy) if absf(dy) > 40.0 else 0.0
	elif st == 1.0:
		# DEFENSIVE holds its ground, but in reach it sways (a small step back and in, and a bob) rather than freezing.
		i.mx = 0.0
		if dist <= CIRCLE_R:
			var sw: float = SimDetMath.sin(S.T * SWAY_RATE + (1.5707963267949 if f == S.fighters[1] else 0.0))
			i.mx = -0.5 * SimMathx.jsign(d) if sw > 0.3 else (0.5 * SimMathx.jsign(d) if sw < -0.3 else 0.0)
			i.my = 0.35 if SimDetMath.cos(S.T * SWAY_RATE) > 0.0 else -0.35
		if sea and f.y < 0.0:
			i.my = 1.0
		if f.ki < 55.0 and dist > 350.0:
			i.charge = true
	elif st == 2.0:
		i.mx = -SimMathx.jsign(d) if dist < 500.0 else SimMathx.jsign(d) * 0.5
		i.my = 1.0 if sea and f.y < 0.0 else SimDetMath.sin(S.T * 1.7 + f.x * 0.01)
	else:
		# Escape: head for cover (forest and ridge preferred over water, away from the opponent), then sink into it.
		var c = chooseCover(f.x, d)
		if c != null and absf(c.off) > 60.0:
			i.mx = SimMathx.jsign(c.off)
			i.dash = absf(c.off) > 300.0
			if sea and f.y < 0.0:
				i.my = 1.0
		else:
			i.mx = 0.0
			var g: float = WorldTerrain.groundY(S, f.x)
			if c != null and c.b == "ocean":
				i.my = -1.0 if f.y > -110.0 else 0.0
			else:
				i.my = -1.0 if f.y > g + 20.0 else 0.0
		# Escape is sprinting away from the opponent (ADR 0008). A cover run that stands still or heads toward the opponent
		# would read as Press, so the AI backs away instead: without the dash, which sent it so far that attacks became
		# long pursuits and matches ran about 40 s longer.
		if not f.canHide and i.mx * SimMathx.jsign(d) > -SimAct.awayDead:
			i.mx = -SimMathx.jsign(d) if d != 0.0 else 1.0
			i.dash = false
	# Underwater and not hiding there: dash for the surface (underwater is a hiding state, not a place to fight).
	if sea and f.y < 0.0 and i.my > 0.0:
		i.dash = true
	# A hunter sometimes swings blind at the last-seen spot (it pays the lock-lost cost: 2 ki and a 0.5 s cooldown).
	# A beat is not spent on a press the director would refuse (the cooldown, or a target in the air): it waits.
	var ready: bool = S.dirS.cool <= 0.0 and o.state != "launched" and o.state != "locked" and DirBands.who(S) < 0 and not DirBands.taunting(o)
	var blind: bool = a.atk <= 0.0 and ready and o.hidden and st == 0.0 and S.dirS.ex == null and S.rng.next() < BLIND_SWING
	if a.atk <= 0.0 and ready and (not o.hidden or blind) and st != 3.0 and S.dirS.ex == null:
		# Each attack beat either attacks or holds (repositions, charges): holding fills the downtime between exchanges.
		var r: float = S.rng.next()
		var pa: float = P_ATTACK[int(st)]
		# No lull over about 10 s: GAP_URGE seconds after the last exchange, attack beats stop holding.
		if S.T - SimMathx.jmax(f.exT, o.exT) > GAP_URGE:
			pa = 1.0
		if r < pa:
			var q: float = r / pa
			var sigPick: float = skill().sigPick
			if SimFighter.sigFree(f) or (f.ki >= 50.0 and q < sigPick and S.T >= f.sigReadyT):   # the signature cooldown (fighter.json sigCooldown); the AI takes its last stand
				i.sig = true
			elif q < sigPick + (1.0 - sigPick) * (maxf(HEAVY_SHARE, float(lv().breakGuard)) if DirInterrupt.on() and DirInterrupt.gi(o, DirInterrupt.GUARDED) >= 2 else HEAVY_SHARE):
				i.heavy = true   # step 3: a rival that only guards gets the guard-breaker (a heavy) at the level's rate
			else:
				i.light = true
			if (i.light or i.heavy) and DirBlast.on() and DirBands.band(f, o) != DirBands.CLOSE and not DirBands.taunting(o) and S.rng.next() < float(lv().get("blastShare", 0.0)):
				i.mode = 1   # it fires instead: a volley of bolts for a light, a charged shot for a heavy (DirBlast)
			elif (i.light or i.heavy) and DirBands.farOn() and DirBands.band(f, o) == DirBands.FAR and not DirBands.taunting(o):
				var u: float = S.rng.next()
				var ft: float = float(lv().get("farTaunt", 0.0)) if not DirBands.tauntSpent(f) else 0.0
				var urge: bool = S.T - SimMathx.jmax(f.exT, o.exT) > GAP_URGE   # no lull: after a long gap it always goes
				if u < ft and not urge:
					pass   # a tap: the taunt
				elif urge or u < ft + float(lv().get("farCharge", 1.0)):
					if i.heavy and S.rng.next() >= float(lv().get("farHeavy", 1.0)) * float(lv().get("earnerUse", 1.0)):   # a heavy charge is an earner too
						i.heavy = false   # the heavy charge is slow and committed: more often it charges light
						i.light = true
					DirInterrupt.si(f, DirInterrupt.AI_HOLD, 2 if i.heavy else 1)   # it holds the button: the charge
					i.lightHeld = i.light
					i.heavyHeld = i.heavy
				else:
					i.light = false   # it holds this beat
					i.heavy = false
		# Attack cadence (dynamic feel): AGGRESSIVE every 0.5 to 1.2 s, DEFENSIVE 1.0 to 2.0 s, the others 0.8 to 1.6 s.
		# S2/S3b ran 1.2 to 2.5, 2.0 to 3.6 and 1.6 to 3.0; the prototype 0.35 to 1.0, 1.2 to 2.5 and 0.9 to 1.8.
		a.atk = S.rng.range_(0.5, 1.2) if st == 0.0 else (S.rng.range_(1.0, 2.0) if st == 1.0 else S.rng.range_(0.8, 1.6))
	elif a.atk <= 0.0 and ready:
		a.atk = 0.3


## Called by the director as a melee attack starts against D, before it is planned: the AI defender's press (ai.json pressReact).
## No draw for a human, or in a stance that does not press.
static func react(S: SimState, D, state: String) -> void:
	if D.ai == null or (state != "free" and state != "charging"):
		return
	var p: float = skill().pressReact[int(D.ai.st)]
	if p > 0.0 and S.rng.next() < p:
		DirAlchemy.log(S, D, SimAct.LIGHT, D.act.mode)
		SimAct.push(D, SimAct.LIGHT, D.act.mode, 0, S.tick)


## True while hiding still mends a wound: a battered region above the hidden fade floor (spec-wounds.md §1 Recovery).
static func _healing(f) -> bool:
	for w in f.wear:
		if w > SimWounds.FADE_HIDDEN_FLOOR and w < SimWounds.STAGE_AT[2]:
			return true
	return false


# Tempo (balance-targets.md section 10).
## The AI's skill numbers (data/director/ai.json), read once: pressReact by stance (the chance it has an attack request
## in when attacked: its Press, stance-matrix.md §7.2), beamAnswer (the chance it answers a beam with its own signature when
## it can) and sigPick (the chance an attack is the signature when it can be). They are the AI's inputs made by a number,
## as a player's are made by hand: the outcome still goes through the same rules.
const SKILL_PATH: String = "res://data/director/ai.json"
static var _skill = null
static var _skillText: String = ""


static func skill() -> Dictionary:
	if _skill == null:
		_skillText = FileAccess.get_file_as_string(SKILL_PATH)
		var j = JSON.parse_string(_skillText)
		if j == null:
			push_error("DirAI: could not parse " + SKILL_PATH)
			j = {"pressReact": {}, "beamAnswer": 0.0, "sigPick": 0.0}
		var pr: Array = []
		for name in DirExchange.STN:
			pr.append(float(j.pressReact.get(name, 0.0)))
		_skill = {"pressReact": pr, "beamAnswer": float(j.beamAnswer), "sigPick": float(j.sigPick), "level": String(j.get("level", "medium")), "levels": j.get("levels", {}), "perfectBlock": j.get("perfectBlock", {})}
	return _skill


## The AI's level for this run: "" follows ai.json's "level". A host or a test sets it before the match (step 4 makes it
## a per-slot setup key). It is part of the data hash, so a replay made at another level has another header.
static var level: String = ""


## The level's numbers (ai.json levels): beamAnswer, perfectBlockMul, guardRepeat, punish, reversal, breakGuard, riposte,
## burstAtLink.
static func lv() -> Dictionary:
	var sk: Dictionary = skill()
	return sk.levels[level if level != "" else sk.level]


## The data file's text, for DirData.dataHash() (the replay header).
static func skillText() -> String:
	skill()
	return _skillText + level


const HEAVY_SHARE: float = 0.375                # of the other attacks, the share that are heavies (it was 0.3 of all)
const P_ATTACK: Array = [0.9, 0.8, 0.85, 0.5]    # chance an attack beat attacks, per stance (ESCAPE never attacks); S3b 0.43 to 0.52
const BLIND_SWING: float = 0.25                  # chance a hunting AGGRESSIVE attack beat swings at a target out of lock
const GAP_URGE: float = 6.0                      # seconds since the last exchange (either fighter's exT)
const GAP_SOON: float = 0.5                      # ... after which the next attack beat comes within this
const CAD_MIN: Array = [0.5, 1.0, 0.8, 0.8]      # attack-timer floor per stance while an exchange runs (the cadence minimums)
const CIRCLE_R: float = 260.0                   # in reach: AGGRESSIVE circles, DEFENSIVE sways (dynamic feel)
const CIRCLE_X: float = 120.0                   # the circle's half-width ...
const CIRCLE_Y: float = 70.0                    # ... and half-height, around the opponent
const CIRCLE_RATE: float = 2.4                  # radians per second (a turn in about 2.6 s)
const SWAY_RATE: float = 5.0                    # DEFENSIVE sway, radians per second

# Fight location (balance-targets.md section 10). Underwater is a hiding state, not a place to fight.
const SURFACE_Y: float = 150.0         # over the sea, fighters who are not hiding hold at or above this height
const COVER_OCEAN: float = 1500.0 * SimConst.PS      # cover cost: water counts as this much farther than forest or ridge
const COVER_PAST_OPP: float = 1200.0 * SimConst.PS   # cover cost: running toward and past the opponent
## Where ESCAPE heads: forest canopy and mountain ridges break line of sight (spec-wounds.md §1c). The sea does not.
const COVER_KINDS: Array = ["forest", "mountains"]
const COVER_REACH: float = 4000.0 * SimConst.PS   # cover farther than this is not considered
const COVER_EDGE: float = 100.0                  # stepping just inside a biome entered from its far end


## Escape cover: the nearest way into ocean, forest or mountains in each direction, out to COVER_REACH, costed by
## distance, plus COVER_OCEAN for water and COVER_PAST_OPP when the opponent is on the way. {"off", "b"} or null.
## d is the signed shortest-arc distance to the opponent. Computed from the biome table (static layout only).
static func chooseCover(x: float, d: float):
	var best = null
	var bestCost: float = 1e9
	var xw: float = SimWrap.wrap(x)
	var here: String = WorldBiomes.biomeAt(xw)
	for s in [1.0, -1.0]:
		for b in COVER_KINDS:
			var off: float = 1e9
			if here == b:
				off = 0.0
			else:
				for seg in WorldBiomes.SEG:
					if seg[2] == b:
						# Forward: to the segment's start. Backward: to just inside its end (the end is exclusive).
						var o: float = SimWrap.wrap(seg[0] - xw) if s > 0.0 else SimWrap.wrap(xw - seg[1]) + COVER_EDGE
						off = SimMathx.jmin(off, o)
			if off > COVER_REACH:
				continue
			var cost: float = off + (COVER_OCEAN if b == "ocean" else 0.0)
			if off > 60.0 and SimMathx.jsign(d) == s and absf(d) < off:
				cost += COVER_PAST_OPP
			if cost < bestCost:
				bestCost = cost
				best = {"off": s * off, "b": b}
	return best
