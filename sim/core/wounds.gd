class_name SimWounds
## Wounds, slice S1 (docs/design/spec-wounds.md §1 and §4; plan in docs/architecture/wounds-plan.md): body regions with
## wear, stages, the brink and recovery. Wear is fixed-point: WEAR_SCALE integer units per wear point, so the spec's
## rates are whole numbers per 60 Hz tick (1 wear per second is exactly 100 units per tick) and nothing drifts.
##
## S2 (Encounter): the HP bar no longer ends the match (HP_ENDS_MATCH false); only a finisher can KO (the director,
## sim/director/exchange.gd). Tuning: k 0.06 (Encounter's sweep, docs/director/wounds-s2.md; spec §1b's 0.20 gave
## 90 s matches), bruised fade 0.25 per second, focus weight (1 + wear/30). Still provisional: the region picker (family
## weights by attack kind), until per-atom weights arrive.
## S3a (Simulation): the core-side stage penalties (constants below; spec §1 "Stage penalties"). S3b (Encounter) adds the
## director-side ones. Rally (S4) and per-fighter profiles (F1) come later.

const REGIONS: Array = ["head", "core", "arms", "legs"]
const HEAD: int = 0
const CORE: int = 1
const ARMS: int = 2
const LEGS: int = 3

const WEAR_SCALE: int = 6000                 # units per wear point
const WEAR_MAX: int = 600000                 # 100 wear
const WEAR_PER_DAMAGE: float = 360.0         # k = 0.06 wear per damage point, in units (0.06 x 6000); S1 had 0.08
## Stage floors in units: bruised 30, battered 60, broken 90. Stages: 0 fresh, 1 bruised, 2 battered, 3 broken.
const STAGE_AT: Array = [180000, 360000, 540000]
const FADE_OUT: int = 25                     # 0.25 wear per second, regions below 60, out of exchanges (S1: 1)
const FADE_HIDDEN: int = 300                 # 3 wear per second, battered regions, while hidden
const FADE_HIDDEN_FLOOR: int = 354000        # hidden fading stops at 59
## Second breath (spec-wounds.md §1c, S2): after BREATH_AFTER seconds with no exchange involving the fighter, battered
## regions fade 1 wear per second, down to 59. It replaces the hidden fade for everyone without the stealth kit.
const BREATH_AFTER: float = 4.0
const FADE_BREATH: int = 100
## Provisional region weights (head, core, arms, legs) by hit family (spec §1 "Region choice"): lights mostly head and
## arms, heavies mostly core and legs, guard hits arms only, beams and impacts spread. Encounter moves this to atoms.
const FAMILY: Dictionary = {
	"light": [3.0, 1.0, 3.0, 1.0],
	"heavy": [1.0, 3.0, 1.0, 3.0],
	"guard": [0.0, 0.0, 1.0, 0.0],
	"spread": [1.0, 1.0, 1.0, 1.0],
}
## S2: only a finisher can KO (spec §1, "The end"). The HP bar no longer ends the match.
const HP_ENDS_MATCH: bool = false
## "Go for the wound": a region's pick weight is multiplied by (1 + wear / FOCUS_WEAR) (spec §1b: 30 from S2; S1 had 50).
const FOCUS_WEAR: float = 30.0

## S3a stage penalties, core side. Battered means stage 2 or more (a broken region keeps its battered penalty).
const CORE_KI_REGEN: float = 0.7    # core battered: ki regen -30% (fighter.gd)
const LEGS_SPEED: float = 0.85      # legs battered: free-flight speed x0.85 (fighter.gd)
const LEGS_LOCK_BREAK: float = 2.0  # legs broken: the ESCAPE lock-break takes twice as long, 1.8 s (hiding.gd); no dash
const STAGGER_TICKS: int = 12       # head battered: 0.2 s stagger after taking a heavy (damage.gd)
const DAZE_TICKS: int = 24          # head broken: 0.4 s daze after a lost exchange (daze(), called by the director, S3b)


## The hit family for a hit() call: guard hits on a DEFENSIVE fighter who took the stance multiplier go to the arms,
## signature beams spread, heavies and lights by the exchange's kind.
static func family(ex, D, o: Dictionary) -> String:
	if D.stance == 1.0 and not o.get("ignoreStance", false):
		return "guard"
	if ex == null:
		return "spread"
	if ex.kind == "sig":
		return "spread"
	return "heavy" if ex.kind == "heavy" else "light"


static func stageOf(w: int) -> int:
	if w >= STAGE_AT[2]:
		return 3
	if w >= STAGE_AT[1]:
		return 2
	if w >= STAGE_AT[0]:
		return 1
	return 0


## A wearing hit on f: pick a region, then add damage x k to it. Returns the region's index, or -1 for no damage.
static func applyHit(S: SimState, f, damage: float, fam: String) -> int:
	if damage <= 0.0:
		return -1
	var region: int = pickRegion(S, f, fam)
	addWear(S, f, region, damage)
	return region


## The region a hit lands on: one S.rng draw, weights by family x "go for the wound" (1 + wear / FOCUS_WEAR), except that
## a broken region keeps its base weight (S2: hits spent on a region that cannot worsen stalled matches at the cap).
static func pickRegion(S: SimState, f, fam: String) -> int:
	var base: Array = FAMILY[fam]
	var w: Array = []
	var sum: float = 0.0
	for r in range(4):
		# A broken region cannot get worse, so the focus goes to the next wound: broken regions keep their base weight.
		var x: float = base[r] * (1.0 + (0.0 if f.stage[r] == 3 else float(f.wear[r]) / (FOCUS_WEAR * WEAR_SCALE)))
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
	f.wear[region] = mini(WEAR_MAX, f.wear[region] + int(SimMathx.jround(damage * WEAR_PER_DAMAGE)))
	updateStages(S, f)


## Recovery, once per tick from stepFighter: out of exchanges a region below 60 fades FADE_OUT; a battered region fades
## by second breath (or, for a fighter with the hiding kit, while hidden), down to 59; broken regions never fade. The
## stagger and daze timer counts down here too.
static func step(S: SimState, f) -> void:
	if f.stunTicks > 0:
		f.stunTicks -= 1
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		return
	var changed: bool = false
	for r in range(4):
		var w: int = f.wear[r]
		if w == 0:
			continue
		if w < STAGE_AT[1]:
			f.wear[r] = maxi(0, w - FADE_OUT)
			changed = true
		elif w < STAGE_AT[2] and f.hidden and f.canHide:
			f.wear[r] = maxi(FADE_HIDDEN_FLOOR, w - FADE_HIDDEN)
			changed = f.wear[r] != w or changed
		elif w < STAGE_AT[2] and w > FADE_HIDDEN_FLOOR and S.T - f.exT >= BREATH_AFTER:
			f.wear[r] = maxi(FADE_HIDDEN_FLOOR, w - FADE_BREATH)
			changed = true
	if changed:
		updateStages(S, f)


## Stage changes and the brink (the core broken, or two of head, arms and legs broken), with their events.
static func updateStages(S: SimState, f) -> void:
	for r in range(4):
		var st: int = stageOf(f.wear[r])
		if st != f.stage[r]:
			f.stage[r] = st
			SimFx.regionStage(S, f, REGIONS[r], st)
			if st == 3:
				SimFx.regionBroken(S, f, REGIONS[r])
	var limbs: int = 0
	for r in [HEAD, ARMS, LEGS]:
		if f.stage[r] == 3:
			limbs += 1
	var brink: bool = f.stage[CORE] == 3 or limbs >= 2
	if brink != f.brink:
		f.brink = brink
		if brink:
			SimFx.brinkEnter(S, f)
		else:
			SimFx.brinkExit(S, f)


## How far a fighter is from the brink, 0 (fresh) to 1 (on the brink): the core's wear, or the second most worn of
## head, arms and legs (the brink needs two of them broken), whichever is higher, over the broken threshold. The AI and
## the comeback bonus read vitality() = 1 - brinkProgress() where they read hp / maxhp before S2.
static func brinkProgress(f) -> float:
	var a: int = f.wear[HEAD]
	var b: int = f.wear[ARMS]
	var c: int = f.wear[LEGS]
	var second: int = maxi(mini(a, b), mini(maxi(a, b), c))
	return minf(1.0, float(maxi(f.wear[CORE], second)) / float(STAGE_AT[2]))


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
		f.stunTicks = maxi(f.stunTicks, STAGGER_TICKS)


## Head broken: a 0.4 s daze after an exchange the fighter lost. The director decides who lost (S3b calls this).
static func daze(S: SimState, f) -> void:
	if broken(f, HEAD):
		f.stunTicks = maxi(f.stunTicks, DAZE_TICKS)


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
	if broken(f, LEGS):
		i.dash = false
