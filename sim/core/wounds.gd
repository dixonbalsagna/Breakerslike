class_name SimWounds
## Wounds, slice S1 (docs/design/spec-wounds.md §1 and §4; plan in docs/architecture/wounds-plan.md): body regions with
## wear, stages, the brink and recovery. Wear is fixed-point: WEAR_SCALE integer units per wear point, so the spec's
## rates are whole numbers per 60 Hz tick (1 wear per second is exactly 100 units per tick) and nothing drifts.
##
## S2 (Encounter): the HP bar no longer ends the match (HP_ENDS_MATCH false); only a finisher can KO (the director,
## sim/director/exchange.gd). Tuning from spec-wounds.md §1b: k 0.20, bruised fade 0.25 per second, focus weight
## (1 + wear/30). Still provisional: the region picker (family weights by attack kind), until per-atom weights arrive.
## Stage penalties (S3), Rally (S4) and per-fighter profiles (F1) come later.

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


## Recovery, once per tick from stepFighter: out of exchanges a region below 60 fades 1 per second; while hidden a
## battered region fades 3 per second, down to 59; broken regions never fade.
static func step(S: SimState, f) -> void:
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
