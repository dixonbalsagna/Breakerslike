class_name WorldCollateral
## The collateral cap and the casualty ramp (docs/world/collateral-caps.md; numbers: docs/design/balance-targets.md 4b).
##
## Every civilian death goes through kill(): nothing else may count a casualty (a probe and a parity lint check it). A rolling
## 60 s budget by the higher fighter's tier limits how many can die; set pieces (a slide, a chain, later a landslide or a
## quake) may borrow their own allowance at tier 3 and above; a cumulative ceiling by the highest tier reached limits the
## total. People who would die beyond those limits evacuate instead: they leave the building, never return, and an
## evacuate event tells the renderer to draw them running. Structures still take their damage. Every per-casualty gain
## (menace, the villain's power, anguish) is normalised by 425 / pop0, and anguish belongs to every fighter whose profile
## has the meter, not to the role called "hero".
##
## No draw from S.rng anywhere here.

const WS: float = SimConst.WS
const POP_REF: float = 425.0
const WINDOW_S: int = 60
## Budget per rolling 60 s and ceiling on the cumulative total, by tier 1 to 4, as shares of the starting population.
const BUDGET: Array = [0.02, 0.04, 0.08, 0.15]
const CEILING: Array = [0.10, 0.30, 0.60, 0.90]
## What one set piece may borrow beyond the window's room, by tier 1 to 4 (0 at tier 1 and 2: no borrowing there).
const EVENT_ALLOW: Dictionary = {
	"slide": [0.0, 0.0, 0.05, 0.10],
	"chain": [0.0, 0.0, 0.12, 0.20],
	"landslide": [0.0, 0.0, 0.05, 0.10],
	"quake": [0.0, 0.0, 0.0, 0.10],
}
# ---- the district flight: while the window is over budget (or the ceiling is reached) and a heavy event was recent ----
const EVAC_R: float = 375.0 * WS       # buildings this close to the latest heavy event empty (3,000 units at WS 8)
const EVAC_RATE: float = 0.30          # of a building's remaining people per second
const FLIGHT_MAX: float = 0.4          # the district flight takes at most this share of a building's people over a match
const EVAC_ACTIVE_S: float = 8.0       # the flight goes on for this long after the latest heavy event
const EVAC_LOT: float = 0.5            # flight lots are reported in events of at least this many people
const EVAC_MAX_PER_TICK: int = 12
## Where the fleeing go. With RELOCATE the people who flee take shelter in the nearest standing building outside the danger
## zone (SHELTER_MIN to SHELTER_MAX from the event, at most SHELTER_CAP times its own people), so the population is conserved
## and only the budget limits how many die; without it they leave the planet's count for good.
const RELOCATE: bool = true
const SHELTER_MIN: float = EVAC_R
const SHELTER_MAX: float = 4.0 * EVAC_R
const SHELTER_CAP: float = 2.0
## Evacuees feed the menace of the fighter who caused the blow, if it has a menace meter (Game Design, 2026-09-30): +0.45 per
## evacuee, times 425 / pop0. Anguish gets nothing from evacuees.
const EVAC_MENACE: float = 0.45
const HIST_BUCKETS: int = 48           # the lure's population histogram (director/ai.gd LURE_STEP = W / 48)
const HIST_STEP: float = SimConst.W / 48.0


static func histBucket(x: float) -> int:
	return mini(int(SimWrap.wrap(x) / HIST_STEP), HIST_BUCKETS - 1)


## Start of a match, after the buildings exist: the window, the state and the lure histogram.
static func init(S: SimState) -> void:
	var w: SimState.World = S.world
	w.cbBuckets = PackedFloat32Array()
	w.cbBuckets.resize(WINDOW_S)
	w.cbBuckets.fill(0.0)
	w.cbSec = 0.0
	w.cbSum = 0.0
	w.maxTier = 1.0
	w.evtKind = ""
	w.evtLeft = 0.0
	w.evtToken = 0.0
	w.evtDead = 0.0
	w.evtEvac = 0.0
	w.tokenSeq = 0.0
	w.heavyX = -1.0
	w.heavyT = -1.0e9
	w.stateT = 0.0
	w.evacuated = 0.0
	w.lotAcc = PackedFloat32Array()
	w.lotAcc.resize(S.buildings.size())
	w.lotAcc.fill(0.0)
	S.popHist = PackedFloat32Array()
	S.popHist.resize(HIST_BUCKETS)
	S.popHist.fill(0.0)
	for b in S.buildings:
		S.popHist[histBucket(b.x)] += b.popAlive


## The higher of the two fighters' tiers, 1 to 4.
static func tier(S: SimState) -> int:
	var t: float = 1.0
	for f in S.fighters:
		t = maxf(t, f.tier)
	return clampi(int(t), 1, 4)


static func _advance(S: SimState) -> void:
	var w: SimState.World = S.world
	var sec: int = int(floor(S.T))
	var last: int = int(w.cbSec)
	if sec <= last:
		return
	if sec - last >= WINDOW_S:
		w.cbBuckets.fill(0.0)
	else:
		for s in range(last + 1, sec + 1):
			w.cbBuckets[s % WINDOW_S] = 0.0
	w.cbSec = float(sec)
	var sum: float = 0.0
	for i in range(WINDOW_S):
		sum += w.cbBuckets[i]
	w.cbSum = sum


static func budget(S: SimState) -> float:
	return BUDGET[tier(S) - 1] * S.world.pop0


## Casualties the window still admits right now (before borrowing).
static func room(S: SimState) -> float:
	_advance(S)
	return maxf(0.0, budget(S) - S.world.cbSum)


## Casualties the cumulative ceiling still admits.
static func ceilingLeft(S: SimState) -> float:
	return maxf(0.0, CEILING[int(S.world.maxTier) - 1] * S.world.pop0 - S.world.casualties)


static func isOver(S: SimState) -> bool:
	return room(S) <= 0.000001 or ceilingLeft(S) <= 0.000001


## Open a set piece: returns its token, which the source passes to kill() (through damageArea and damageBuilding) so the
## allowance belongs to this event's own source. At tier 1 and 2 there is no allowance.
static func beginEvent(S: SimState, kind: String, cause) -> float:
	var w: SimState.World = S.world
	w.tokenSeq += 1.0
	w.evtToken = w.tokenSeq
	w.evtKind = kind
	var t: int = tier(S)
	w.evtLeft = EVENT_ALLOW[kind][t - 1] * w.pop0 if EVENT_ALLOW.has(kind) else 0.0
	w.evtDead = 0.0
	w.evtEvac = 0.0
	return w.evtToken


## Close a set piece and return {"dead", "evac", "borrowed"} for the token; an unknown token returns zeros.
static func endEvent(S: SimState, token: float) -> Dictionary:
	var w: SimState.World = S.world
	var r := {"dead": 0.0, "evac": 0.0}
	if token != 0.0 and token == w.evtToken:
		r.dead = w.evtDead
		r.evac = w.evtEvac
		w.evtKind = ""
		w.evtLeft = 0.0
		w.evtToken = 0.0
		w.evtDead = 0.0
		w.evtEvac = 0.0
	return r


## Record where the latest heavy event was (the district flight flees from it).
static func heavy(S: SimState, x: float) -> void:
	S.world.heavyX = x
	S.world.heavyT = S.T


## The nearest standing building outside the danger zone that can take n more people, or -1.
static func shelter(S: SimState, cx: float, n: float) -> int:
	if not RELOCATE:
		return -1
	var best: int = -1
	var bd: float = 1e18
	for bi in WorldStructures.near(S, cx, SHELTER_MAX):
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var d: float = absf(SimWrap.sdx(cx, b.x))
		if d < SHELTER_MIN or d > SHELTER_MAX or b.popAlive + n > SHELTER_CAP * b.pop:
			continue
		if d < bd:
			bd = d
			best = bi
	return best


## The one place a civilian dies. want is how many would die in building bi (or -1 for people outside any building);
## they all leave the building; the allowed number are casualties and the rest evacuate. cx is the x of the event that
## caused it (the crowd flees from it); evt is the caller's set-piece token or 0. Returns the casualties.
static func kill(S: SimState, bi: int, want: float, cause, evt: float, cx: float) -> float:
	if want <= 0.0:
		return 0.0
	var w: SimState.World = S.world
	_advance(S)
	var b = S.buildings[bi] if bi >= 0 else null
	if b != null:
		want = minf(want, b.popAlive)
		b.popAlive -= want
		S.popHist[histBucket(b.x)] -= want
	var rm: float = maxf(0.0, budget(S) - w.cbSum)
	var borrow: float = w.evtLeft if (evt != 0.0 and evt == w.evtToken) else 0.0
	var cl: float = ceilingLeft(S)
	var granted: float = minf(want, minf(rm + borrow, cl))
	if granted > rm:
		w.evtLeft -= granted - rm
	w.cbBuckets[int(w.cbSec) % WINDOW_S] += granted
	w.cbSum += granted
	var evac: float = want - granted
	if granted > 0.0:
		_feed(S, granted, cause)
	if evt != 0.0 and evt == w.evtToken:
		w.evtDead += granted
		w.evtEvac += evac
	if evac > 0.000001:
		w.evacuated += evac
		if cause != null and cause.hasMenace:
			cause.menace = SimMathx.jmin(100.0, cause.menace + evac * cause.md.menaceEvac * POP_REF / w.pop0)   # D1b: meters.json
		var reason: String = "ceiling" if cl < rm + borrow else "budget"
		var owner: float = WorldCrater._slot(S, cause)
		var dest: int = shelter(S, cx, evac)
		if dest >= 0:
			S.buildings[dest].popAlive += evac
			S.popHist[histBucket(S.buildings[dest].x)] += evac
		SimFx.evacuate(S, bi, b.x if b != null else cx, evac, cx, reason, owner, dest)
	heavy(S, cx)
	return granted


## The meters: the villain feeds on casualties it caused; every fighter with an anguish meter is pressured by all of them.
## Everything is times 425 / pop0, so the meters read the share of the population lost and planets are equivalent.
static func _feed(S: SimState, n: float, cause) -> void:
	var norm: float = POP_REF / S.world.pop0
	S.world.casualties += n
	if cause != null and cause.hasMenace:
		cause.menace = SimMathx.jmin(100.0, cause.menace + n * cause.md.menaceCas * norm)   # D1b: meters.json
		cause.power = SimMathx.jmin(100.0, cause.power + n * 0.09 * norm)
	for f in S.fighters:
		if f.hasAnguish:
			f.anguish = SimMathx.jmin(100.0, f.anguish + n * (f.md.anguishCasSelf if cause == f else f.md.anguishCasOther) * norm)   # D1b: meters.json


## Once per unfrozen tick: advance the window, report the state once a second, and run the district flight.
static func tick(S: SimState) -> void:
	var w: SimState.World = S.world
	_advance(S)
	var sec: int = int(floor(S.T))
	if sec > int(w.stateT):
		w.stateT = float(sec)
		SimFx.collateralState(S, room(S), budget(S), ceilingLeft(S), isOver(S))
	if w.heavyX < 0.0 or S.T - w.heavyT > EVAC_ACTIVE_S:
		return
	if not isOver(S):
		return
	var dt: float = S.dt
	var events: int = 0
	var dest: int = shelter(S, w.heavyX, 1.0)
	var moved: float = 0.0
	for bi in WorldStructures.near(S, w.heavyX, EVAC_R):
		var b = S.buildings[bi]
		if not b.alive or b.popAlive <= 0.0:
			continue
		if absf(SimWrap.sdx(w.heavyX, b.x)) - b.w / 2.0 > EVAC_R:
			continue
		var take: float = minf(b.popAlive * EVAC_RATE * dt, FLIGHT_MAX * b.pop - b.fled)
		if take <= 0.0:
			continue
		b.fled += take
		b.popAlive -= take
		S.popHist[histBucket(b.x)] -= take
		w.evacuated += take
		w.lotAcc[bi] += take
		moved += take
		if w.lotAcc[bi] >= EVAC_LOT and events < EVAC_MAX_PER_TICK:
			SimFx.evacuate(S, bi, b.x, w.lotAcc[bi], w.heavyX, "flight", -1.0, dest)
			w.lotAcc[bi] = 0.0
			events += 1
	if dest >= 0 and moved > 0.0:
		S.buildings[dest].popAlive += moved
		S.popHist[histBucket(S.buildings[dest].x)] += moved
