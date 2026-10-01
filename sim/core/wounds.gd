class_name SimWounds
## Wounds, slice S1 (docs/design/spec-wounds.md §1 and §4; plan in docs/architecture/wounds-plan.md): body regions with
## wear, stages, the brink and recovery. Wear is fixed-point: WEAR_SCALE integer units per wear point, so the spec's
## rates are whole numbers per 60 Hz tick (1 wear per second is exactly 100 units per tick) and nothing drifts.
##
## S2 (Encounter): the HP bar no longer ends the match (HP_ENDS_MATCH false); only a finisher can KO (the director,
## sim/director/exchange.gd). Tuning: k 0.034 (Game Design's final, spec §1b; S3b had 0.065 and §1b's first 0.20
## gave 90 s matches), bruised fade 0.25 per second, focus weight (1 + wear/30). Still provisional: the region picker (family
## weights by attack kind), until per-atom weights arrive.
## S3a (Simulation): the core-side stage penalties (constants below; spec §1 "Stage penalties"). S3b (Encounter) adds the
## director-side ones. S4 (Simulation): Rally, the shared rule (spec §2; the Rally section below). Per-fighter profiles
## (F1) come later.
## Pitch A, "the crippling moment" (Orb; pitches.md §5, balance-targets.md §13): the brink is the core broken; limbs wear
## to battered and stop, spilling the rest into the core; a limb breaks only in a crippling moment (the section below).
## D1a: every per-fighter number is data (data/fighters/<id>/wounds.json), read here through f.wd (FighterData.WoundsDef).
## What stays below is the shared frame (regions, the unit scale, the overtime ramp) and five pinned values that other
## owners' files still read as constants; the loader requires the data to equal them until those readers move to f.wd.

const REGIONS: Array = ["head", "core", "arms", "legs"]
const HEAD: int = 0
const CORE: int = 1
const ARMS: int = 2
const LEGS: int = 3

const WEAR_SCALE: int = 6000                 # units per wear point
const WEAR_MAX: int = 600000                 # 100 wear
## k (wear per damage point, in units) is f.wd.wearPerDamage: 204 = 0.034 x 6000, Game Design's final (spec §1b).
## The overtime ramp (f.wd.overtimeStart, overtimePerMin, overtimeCap: k x min(cap, 1 + perMin x minutes past the
## start)) and the act-1 damping (f.wd.act1Damping while act() is 1) are data (spec-wounds.md §1b).
## Stage floors in units: bruised 30, battered 60, broken 90. Stages: 0 fresh, 1 bruised, 2 battered, 3 broken.
## Pinned: sim/director/ai.gd and qa/godot/records.gd read it (f.wd.stageAt is the fighter's own copy).
const STAGE_AT: Array = [180000, 360000, 540000]
## Pinned (sim/director/ai.gd): battered regions fade down to 59 (f.wd.hiddenFloor). The fade rates, second breath's delay
## (spec-wounds.md §1c) and the region weights by hit family are f.wd.fadeOut, fadeBreath, breathAfter, fadeHidden and
## family.
const FADE_HIDDEN_FLOOR: int = 354000
## S2: only a finisher can KO (spec §1, "The end"). The HP bar no longer ends the match.
const HP_ENDS_MATCH: bool = false
## "Go for the wound": a region's pick weight is multiplied by (1 + wear / f.wd.focusWear) (spec §1b).

## Stage penalties (S3a core side, S3b director side): battered means stage 2 or more (a broken region keeps its battered
## penalty). The numbers are f.wd: coreKiRegen, legsSpeed, legsLockBreak, staggerTicks, dazeTicks, armsGuardMul and
## armsBrokenMul. Pinned (the director reads the constants):
const HEAD_PARRY_NARROW: float = 0.2  # head battered: the parry window is 20% narrower (sim/director/melee.gd)
const HEAD_DEFENCE: float = 0.08      # head broken: -0.08 on the defender's rolls (sim/director/data.gd)
const LEGS_SLIP: float = 0.10         # legs battered: -0.10 on the ESCAPE slip chance (sim/director/data.gd)


## The hit family for a hit() call: guard hits on a DEFENSIVE fighter who took the stance multiplier go to the arms,
## signature beams spread, heavies and lights by the exchange's kind.
## stance: the defender's stance for this hit (the exchange's frozen one, S3b), or -1 for the live stance.
static func family(ex, D, o: Dictionary, stance: float = -1.0) -> String:
	if (D.stance if stance < 0.0 else stance) == 1.0 and not o.get("ignoreStance", false):
		return "guard"
	if ex == null:
		return "spread"
	if ex.kind == "sig":
		return "spread"
	return "heavy" if ex.kind == "heavy" else "light"


static func stageOf(w: int, at: Array = STAGE_AT) -> int:
	if w >= at[2]:
		return 3
	if w >= at[1]:
		return 2
	if w >= at[0]:
		return 1
	return 0


## A wearing hit on f: pick a region, then add damage x k to it. Returns the region's index, or -1 for no damage.
static func applyHit(S: SimState, f, damage: float, fam: String) -> int:
	if damage <= 0.0:
		return -1
	var region: int = pickRegion(S, f, fam)
	addWear(S, f, region, damage)
	return region


## The region a hit lands on: one S.rng draw, weights by family x "go for the wound" (1 + wear / focusWear), except that
## a broken region keeps its base weight (S2: hits spent on a region that cannot worsen stalled matches at the cap).
static func pickRegion(S: SimState, f, fam: String) -> int:
	var base: Array = f.wd.family[fam]
	var w: Array = []
	var sum: float = 0.0
	for r in range(4):
		# A broken region cannot get worse, so the focus goes to the next wound: broken regions keep their base weight.
		var x: float = base[r] * (1.0 + (0.0 if f.stage[r] == 3 else float(f.wear[r]) / (f.wd.focusWear * WEAR_SCALE)))
		w.append(x)
		sum += x
	var pick: float = S.rng.next() * sum
	var region: int = 0
	for r in range(4):
		if w[r] > 0.0:
			region = r      # the fallback if rounding leaves pick above 0: the last region with weight
	for r in range(4):
		pick -= w[r]
		if pick <= 0.0 and w[r] > 0.0:
			region = r
			break
	return region


static func addWear(S: SimState, f, region: int, damage: float) -> void:
	var wd = f.wd
	var k: float = wd.wearPerDamage * SimMathx.jmin(wd.overtimeCap, 1.0 + wd.overtimePerMin * SimMathx.jmax(0.0, S.T - wd.overtimeStart) / 60.0)
	if act(S) == 1:
		k *= wd.act1Damping
	var add: int = int(SimMathx.jround(damage * k))
	if wd.spill[region]:
		# Pitch A: a limb wears to battered and stops; the rest spills into the core (all of it once the limb is broken).
		var cap: int = f.wear[region] if f.stage[region] == 3 else wd.stageAt[2] - 1
		var w: int = f.wear[region] + add
		if w > cap:
			f.wear[CORE] = mini(WEAR_MAX, f.wear[CORE] + (w - cap))
			w = cap
		f.wear[region] = w
	else:
		f.wear[region] = mini(WEAR_MAX, f.wear[region] + add)
	updateStages(S, f)


## A hit into a raised guard (family guard): its wear is split between the arms and the legs by f.wd.guardArms and
## guardLegs (wounds.json guardWearSplit), so legs can become battered from guarding (Game Design's lever on the arm skew).
static func addGuardWear(S: SimState, f, damage: float) -> void:
	if f.wd.guardArms > 0.0:
		addWear(S, f, ARMS, damage * f.wd.guardArms)
	if f.wd.guardLegs > 0.0:
		addWear(S, f, LEGS, damage * f.wd.guardLegs)


## Recovery, once per tick from stepFighter: out of exchanges a region below 60 fades f.wd.fadeOut; a battered region fades
## by second breath (or, for a fighter with the hiding kit, while hidden), down to 59; broken regions never fade. The
## stagger and daze timer counts down here too.
static func step(S: SimState, f) -> void:
	if f.stunTicks > 0:
		f.stunTicks -= 1
	if f.rallyCool > 0:
		f.rallyCool -= 1
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		return
	var changed: bool = false
	var wd = f.wd
	for r in range(4):
		var w: int = f.wear[r]
		if w == 0:
			continue
		if w < wd.stageAt[1]:
			f.wear[r] = maxi(0, w - wd.fadeOut)
			changed = true
		elif w < wd.stageAt[2] and f.hidden and f.canHide:
			f.wear[r] = maxi(wd.hiddenFloor, w - wd.fadeHidden)
			changed = f.wear[r] != w or changed
		elif w < wd.stageAt[2] and w > wd.hiddenFloor and S.T - f.exT >= wd.breathAfter:
			f.wear[r] = maxi(wd.hiddenFloor, w - wd.fadeBreath)
			f.breathWear += w - f.wear[r]
			changed = true
	if changed:
		updateStages(S, f)


## Stage changes and the brink (a brink region broken: the core, pitch A), with their events. Every stage change goes to
## SimMood.onStage, which decides the act beats (mood.json actBeats).
static func updateStages(S: SimState, f) -> void:
	for r in range(4):
		var st: int = stageOf(f.wear[r], f.wd.stageAt)
		if st != f.stage[r]:
			var prev: int = f.stage[r]
			f.stage[r] = st
			SimFx.regionStage(S, f, REGIONS[r], st)
			SimMood.onStage(S, f, r, st, prev)
			if st == 3:
				SimFx.regionBroken(S, f, REGIONS[r])
	var brink: bool = false
	for r in range(4):
		if f.wd.brinkRegion[r] and f.stage[r] == 3:
			brink = true
	if brink != f.brink:
		f.brink = brink
		# The brink chapter: entering or leaving the brink (a Rally) starts the set-up count over; an open fighter closes.
		if f.brinkOpen:
			SimFx.brinkClose(S, f, "rally")
		f.brinkOpen = false
		f.brinkSetups = 0
		if brink:
			SimFx.brinkEnter(S, f)
		else:
			SimFx.brinkExit(S, f)


## How far a fighter is from the brink, 0 (fresh) to 1 (on the brink): the most worn brink region (the core, pitch A)
## over the broken threshold. The AI and
## the comeback bonus read vitality() = 1 - brinkProgress() where they read hp / maxhp before S2.
static func brinkProgress(f) -> float:
	var w: int = 0
	for r in range(4):
		if f.wd.brinkRegion[r]:
			w = maxi(w, f.wear[r])
	return minf(1.0, float(w) / float(f.wd.stageAt[2]))


static func vitality(f) -> float:
	return 1.0 - brinkProgress(f)


## S3a: a region at battered or worse (stage 2 or 3).
static func battered(f, region: int) -> bool:
	return f.stage[region] >= 2


static func broken(f, region: int) -> bool:
	return f.stage[region] == 3


## Head battered: a 0.2 s stagger after taking a heavy. Stagger and daze share one integer timer (the longer one wins).
static func stagger(S: SimState, f) -> void:
	if battered(f, HEAD):
		f.stunTicks = maxi(f.stunTicks, f.wd.staggerTicks)


## Head broken: a 0.4 s daze after an exchange the fighter lost. The director decides who lost (S3b calls this).
static func daze(S: SimState, f) -> void:
	if broken(f, HEAD):
		f.stunTicks = maxi(f.stunTicks, f.wd.dazeTicks)


## The intent penalties, applied by SimControl.control after the fighter's intent is read and before any attack request:
## a staggered or dazed fighter can neither move, dash, charge nor attack (stance changes still go through); broken legs
## remove the dash. stunTicks counts down in step(), after control, so a stun of n ticks blocks exactly n ticks of input.
static func gateIntent(f, i: SimIntent) -> void:
	if f.stunTicks > 0:
		i.mx = 0.0
		i.my = 0.0
		i.dash = false
		i.charge = false
		i.light = false
		i.heavy = false
		i.sig = false
		# intent v2 (I2a): the held states end and every edge is dropped; the mode stays.
		i.guard = false
		i.guardPress = false
		i.dodge = false
		i.sprint = false
		i.power = false
		i.powerPress = false
		i.powerTap = false
		i.upgrade = 0
		i.special = 0
		i.context = false
		i.transform = false
	if broken(f, LEGS):
		i.dash = false
		i.sprint = false


# ---------------------------------------------------------------- Rally (S4; spec-wounds.md §2)

## A Rally takes a fighter off the brink and mends one broken region to battered, at 89 wear. There is no Rally button:
## each fighter's rule fires on its own condition (Encore, the Empress's, is the one input; it waits for her). The looser
## limits (Orb): each region can be rallied once (at most 4 Rallies), and a 15 s cooldown after a Rally. The contest tilt
## of 10 points per Rally is the director's (Encounter).
## Rules (Fighter.rally): "second_wind" survives the finisher contest; "spite" wins a decisive exchange by hand (no
## signature), mending the arms first; "reboot" (the dock or a Press) and "encore" (an input) come with their fighters;
## "" has no Rally.
## The mend (f.wd.rallyWear, 89 wear: battered, one good hit from breaking again) and the cooldown (f.wd.rallyCool, 15 s,
## Orb's looser limit) are data.
const BY_HAND: Array = ["launch", "clash", "guard_break", "interrupt"]   # decisive kinds won without a signature
const RALLY_ORDER: Array = [CORE, HEAD, ARMS, LEGS]
const SPITE_ORDER: Array = [ARMS, CORE, HEAD, LEGS]


## Whether f would be on the brink with region r's wear set to wr.
static func _brinkWith(f, r: int, wr: int) -> bool:
	var st: Array = []
	for q in range(4):
		st.append(stageOf(wr if q == r else f.wear[q], f.wd.stageAt))
	for q in range(4):
		if f.wd.brinkRegion[q] and st[q] == 3:
			return true
	return false


## The region a Rally mends: the first broken, never-rallied region in the rule's order whose mend takes the fighter
## off the brink. -1 if there is none (the core already rallied). Pitch A: only a brink region's mend can do that, so
## Rally mends the core and a broken limb stays broken, as its scar.
static func rallyRegion(f, order: Array) -> int:
	for r in order:
		if f.stage[r] == 3 and (f.rallied & (1 << r)) == 0 and not _brinkWith(f, r, f.wd.rallyWear):
			return r
	return -1


## Rally f by rule kind if it is on the brink, off cooldown and has a region to mend. Returns true if it rallied.
static func rally(S: SimState, f, kind: String) -> bool:
	if not f.brink or f.rallyCool > 0 or S.game.ko != null:
		return false
	var r: int = rallyRegion(f, SPITE_ORDER if kind == "spite" else RALLY_ORDER)
	if r < 0:
		return false
	f.wear[r] = f.wd.rallyWear
	f.rallied |= 1 << r
	f.rallies += 1
	f.rallyCool = f.wd.rallyCool
	SimFx.rally(S, f, REGIONS[r], kind)
	updateStages(S, f)
	return true


## The act index (spec-wounds.md §9): SimMood owns it (M1), from the beats reported above. It never goes down: a Rally
## mends a region but not the act.
static func act(S: SimState) -> int:
	return SimMood.act(S)


## The director's hooks. f survived a finisher contest (Second Wind).
static func onContestSurvived(S: SimState, f) -> void:
	if f.rally == "second_wind":
		rally(S, f, "second_wind")


## W won a decisive exchange against L (why: decisive()'s kind). Spite needs it won by hand. Pitch A: if W's heavy-class
## blow landed on a battered limb of L in this exchange, the crippling roll.
static func onDecisive(S: SimState, ex, W, L, why: String) -> void:
	if W.rally == "spite" and BY_HAND.has(why):
		rally(S, W, "spite")
	if ex != null and ex.cripR >= 0 and ex.cripA == S.fighters.find(W) and ex.cripV == S.fighters.find(L):
		_crippleRoll(S, ex, W, L)


# ---------------------------------------------------------------- the crippling moment (pitch A)

## At an exchange's start: which limbs of both fighters are already battered. Only those can be crippled in it, so the
## blow that makes a limb battered cannot also break it (Game Design: a visible warning before every break).
static func onExchangeStart(S: SimState, ex) -> void:
	var mask: int = 0
	for s in range(S.fighters.size()):
		for r in range(4):
			if S.fighters[s].stage[r] == 2:
				mask |= 1 << (s * 4 + r)
	ex.startBattered = mask


## hit() reports every blow: a heavy-class blow (the victim's cripple.blows: a heavy, a signature, a guard break, a chain
## strike) on a limb of the victim's cripple.regions that was battered when the exchange started (and still is) is
## remembered on the exchange until the exchange's decisive result (onDecisive), the latest such blow winning.
static func noteBlow(S: SimState, ex, A, D, region: int, kind: String, o: Dictionary) -> void:
	if ex == null or region < 0 or D.limbBreaks >= D.wd.cripMax or not D.wd.cripRegions.has(region) or D.stage[region] != 2:
		return
	if (ex.startBattered & (1 << (S.fighters.find(D) * 4 + region))) == 0:
		return
	var blow: String = ""
	if ex.tag == "GUARD BREAK":
		blow = "guard_break"
	elif ex.kind == "sig":
		blow = "beam"
	elif ex.combo > 1.0 and o.get("noParry", false):
		blow = "chain"
	elif kind == "heavy":
		blow = "heavy"
	if blow == "" or not D.wd.cripBlows.has(blow):
		return
	ex.cripR = region
	ex.cripA = S.fighters.find(A)
	ex.cripV = S.fighters.find(D)


## The roll, keyed on the exchange (SimRng.keyed; no S.rng draw): base, + tierAhead if W is a tier ahead, + lateBonus from
## act lateAct, + defensive (negative) if L holds DEFENSIVE in this exchange. The victim's data set the odds.
static func _crippleRoll(S: SimState, ex, W, L) -> void:
	var r: int = ex.cripR
	ex.cripR = -1
	var wd = L.wd
	if L.limbBreaks >= wd.cripMax or L.stage[r] != 2:
		return
	var chance: float = wd.cripBase
	if W.tier >= L.tier + 1.0:
		chance += wd.cripTierAhead
	if act(S) >= wd.cripLateAct:
		chance += wd.cripLateBonus
	if (ex.sD if L == ex.D else ex.sA) == 1.0:
		chance += wd.cripDefensive
	if SimRng.keyed(int(S.game.seed), "cripple", ex.n * 16 + int(ex.combo)) < chance:
		cripple(S, W, L, _cripplePick(S, ex, L, r))


## Which limb breaks (Game Design's leg weighting, balance-targets §13): among the victim's eligible limbs (its cripple
## regions, battered when the exchange started and still battered), the legs weigh cripLegWeight against the arms' 1; a
## second keyed draw picks. With one eligible limb it is the one the blow landed on.
static func _cripplePick(S: SimState, ex, L, r: int) -> int:
	var slot: int = S.fighters.find(L)
	var elig: Array = []
	var sum: float = 0.0
	for q in L.wd.cripRegions:
		if L.stage[q] == 2 and (ex.startBattered & (1 << (slot * 4 + q))) != 0:
			elig.append(q)
			sum += L.wd.cripLegWeight if q == LEGS else 1.0
	if elig.size() < 2:
		return r
	var pick: float = SimRng.keyed(int(S.game.seed), "crippick", ex.n * 16 + int(ex.combo)) * sum
	for q in elig:
		pick -= L.wd.cripLegWeight if q == LEGS else 1.0
		if pick < 0.0:
			return q
	return elig[elig.size() - 1]


## W breaks L's limb r: broken for the match (Rally never mends it), a limb_break event, and W's power surges.
static func cripple(S: SimState, W, L, r: int) -> void:
	L.wear[r] = L.wd.stageAt[2]
	L.limbBreaks += 1
	W.power = SimMathx.jmin(100.0, W.power + W.wd.cripSurgePower)
	SimFx.limbBreak(S, W, L, REGIONS[r])
	updateStages(S, L)
