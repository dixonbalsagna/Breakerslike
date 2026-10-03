class_name WorldBrunt
## The director-chosen building impact, the chain and Rampage-style floors (docs/world/b2-plan.md, buildings-in-depth.md).
##
## A launch is aimed at one building. The fighter's x and y physics are exactly SimFighter.stepLaunched's; his depth z is a
## kinematic function of his x progress between waypoints (the building faces). Everything geometric lives here, as pure
## functions over the sim state with no random draw, so the planner's lookahead (aim, chainPlan) and the runtime (hit,
## next) are the same code and a plan is always its own outcome.
##
## Floors (buildings of FLOORS_MIN floors or more): a bit mask of standing floors and a lazily allocated damage array; a
## brunt picks the floor at its hit height and either punches through, cracks it or only dents it; a cleared span longer
## than TUNNEL_MAX pancakes the floors above; blasts and beams still hit the building's core hp and implode it whole.

const WS: float = SimConst.WS
const BH: float = 75.0
# ---- candidates and aim ----
const BR_MIN: float = 90.0 * WS            # buildings nearer than this (in x) are not candidates
const BR_MAX: float = 1300.0 * WS          # nor farther than this
const BR_PRESELECT: int = 2                # best per side by the cheap score
const AIM_UY: Array = [0.05, 0.12, 0.25, 0.4]
const AIM_MIN_SP: float = 500.0            # normalised arrival speed below which a brunt is not worth aiming
const FLIGHT_STEPS: int = 300              # the flight search horizon: 5 s at the fixed step
const FLIGHT_X_MAX: float = 40000.0
# ---- the hit ----
const BRUNT_MUL: float = 1.8               # damage = spN * (0.55 + 0.25 tier) * BRUNT_MUL
const FIGHTER_DMG: float = 0.012           # the fighter's damage per unit of normalised speed
const KEEP_HI: float = 0.8                 # speed kept after a punch: clamp(KEEP_HI - KEEP_K * strength / KEEP_REF, KEEP_MIN, KEEP_HI)
const KEEP_K: float = 0.45
const KEEP_REF: float = 3000.0
const KEEP_MIN: float = 0.35
const KEEP_FREE: float = 0.95              # through floors that are already gone
const HEAVY_KEEP: float = 0.7              # a heavy wreck (0.6 to 1) carries on at this much of the kept speed
const CHAIN_MIN_SP: float = 500.0
const CHAIN_GAP: float = 260.0 * WS        # the next building's near edge within this of the last one's far edge
const CHAIN_DZ: float = 180.0 * WS         # and its depth within this of the last one's
const CHAIN_MAX: Array = [2, 2, 3, 4]      # by the launcher's tier; a finisher (special) may use CHAIN_ABS
const CHAIN_ABS: int = 5
const SPLASH_FRAC: float = 0.25            # buildings beside a hit take this share of its damage, once per launch
const SPLASH_W: float = 0.9
const SPLASH_Z: float = 120.0 * WS
const SPLASH_CAP: int = 16
const STOP_FIRST: float = 0.35             # hit-stop seconds on the first hit, then STOP_LINK on each further one
const STOP_LINK: float = 0.12
const STOP_TOTAL: float = 0.8
# ---- floors ----
const FLOOR_H: float = 150.0               # 2 bh
const FLOORS_MIN: int = 5
const FLOORS_CAP: int = 62
const FLOOR_STR: float = 1.0
const STR_GRAD: float = 0.5                # a floor is this much stronger per floor above it
const HIT_FLOORS: int = 2                  # the floors a fighter's body covers
const CORE_SHARE: float = 0.25             # local damage also wears the core hp by this share
const TUNNEL_MAX: int = 2                  # a cleared span up to this many floors is carried by the columns
const PANCAKE_K: float = 0.6               # a falling stack of m floors breaks a floor of strength s when K * m >= s
const FLOOR_DEATH: float = 1.0             # a cracked floor's occupants die in proportion ratio * this


# ===================================================================== floors

## The floor count for a building of standing height h (set at generation).
static func floorCount(h: float) -> int:
	return clampi(int(round(h / FLOOR_H)), 1, FLOORS_CAP)


static func floorH(b) -> float:
	return b.h / float(b.floors)


static func isStanding(b, k: int) -> bool:
	return ((b.fmask >> k) & 1) == 1


static func topFloor(b) -> int:
	var k: int = b.floors - 1
	while k >= 0 and not isStanding(b, k):
		k -= 1
	return k


## Strength of floor k: stronger toward the ground (it carries more).
static func floorStr(b, k: int) -> float:
	return (b.maxhp / float(b.floors)) * FLOOR_STR * (1.0 + STR_GRAD * float(b.floors - 1 - k))


static func standingCount(b) -> int:
	var n: int = 0
	for k in range(b.floors):
		if isStanding(b, k):
			n += 1
	return n


## Living people on one standing floor: the building's people spread over its standing floors.
static func floorPop(b) -> float:
	var n: int = standingCount(b)
	return b.popAlive / float(n) if n > 0 else 0.0


# ===================================================================== geometry

## The depth of a building's face nearest the fighter plane.
static func faceZ(b) -> float:
	return b.z - signf(b.z) * b.d * 0.5 if b.z != 0.0 else 0.0


## Did the segment ox -> x (the shortest way) cross the plane at edge, in direction dir? Returns the fraction along it, or -1.
static func crossFrac(ox: float, x: float, edge: float, dir: float) -> float:
	var total: float = SimWrap.sdx(ox, x) * dir
	if total <= 0.0:
		return -1.0
	var to: float = SimWrap.sdx(ox, edge) * dir
	if to < 0.0 or to > total:
		return -1.0
	return to / total


## The flight from (x0, y0) with velocity (vx0, vy0) (vx0 already carries the launch's traversal factor trav), to building
## b: the same integration as SimFighter.stepLaunched and DirLaunch.predictFlight without buildings. Returns {"ok": false}
## or {"ok": true, "t", "x" (the near edge), "y", "vx", "vy", "spN" (the normalised speed there), "dir"}. The flight must
## enter b's footprint from the near edge at a height between the ground and b's current top, before it lands.
static func flightTo(S: SimState, x0: float, y0: float, vx0: float, vy0: float, trav: float, b) -> Dictionary:
	var dt: float = SimConst.DT
	var kAir: float = SimDetMath.pow(0.55, dt)
	var dir: float = -1.0 if vx0 < 0.0 else 1.0
	var edge: float = SimWrap.wrap(b.x - dir * b.w * 0.5)
	var ahead: float = SimWrap.sdx(x0, edge) * dir
	if ahead < 0.0 or ahead > FLIGHT_X_MAX:
		return {"ok": false}
	var gy: float = WorldStructures.baseY(S, b)
	var top: float = gy + WorldStructures.curH(b)
	if y0 < WorldWater.surfaceAt(S, x0):
		return {"ok": false}
	var x: float = x0
	var y: float = y0
	var vx: float = vx0
	var vy: float = vy0
	var t: float = 0.0
	for n in range(FLIGHT_STEPS):
		var ox: float = x
		var oy: float = y
		t += dt
		vy -= 1000.0 * dt
		vx *= kAir
		x = SimWrap.wrap(x + vx * dt)
		y += vy * dt
		if y < WorldWater.surfaceAt(S, x):
			return {"ok": false}   # a flight that enters water (skim, buoyancy, drag) is the runtime's, not a brunt's
		var fr: float = crossFrac(ox, x, edge, dir)
		if fr >= 0.0:
			var yc: float = oy + (y - oy) * fr
			if yc > gy - 10.0 and yc < top:
				return {"ok": true, "t": t - dt * (1.0 - fr), "x": edge, "y": yc, "vx": vx, "vy": vy, "spN": SimDetMath.hypot(vx / trav, vy), "dir": dir}
			return {"ok": false}
		if SimWrap.sdx(ox, x) * dir > 0.0 and SimWrap.sdx(edge, x) * dir > 0.0:
			return {"ok": false}
		if y <= WorldTerrain.groundY(S, x):
			return {"ok": false}
	return {"ok": false}


# ===================================================================== the outcome of one hit (pure)

## What hitting building b at height y with normalised speed spN and launcher tier does, without changing anything.
## Returns {"floors": bool, "k", "hit": Array of standing floors covered, "sumS", "dmg", "ratio", "outcome" (punch, crack,
## dent for floors; collapse, heavy, wreck, crack for whole buildings), "pass": continues through, "keep", "deaths"}.
static func outcomeOf(S: SimState, b, y: float, spN: float, tier: float) -> Dictionary:
	return outcomeDmg(S, b, y, spN * (0.55 + 0.25 * tier) * BRUNT_MUL)


## The same by the damage itself (a brunt's from its speed and tier, a shot's from its kind: WorldBlast.shotBuilding).
static func outcomeDmg(S: SimState, b, y: float, dmg: float) -> Dictionary:
	if b.floors >= FLOORS_MIN:
		var gy: float = WorldStructures.baseY(S, b)
		var fh: float = floorH(b)
		var pos: float = (y - gy) / fh
		var k: int = clampi(int(floor(pos)), 0, b.floors - 1)
		var nb: int = k + 1 if pos - float(k) >= 0.5 else k - 1
		var hit: Array = []
		var cand: Array = [k, nb] if nb > k else [nb, k]
		for j in cand:
			if j >= 0 and j < b.floors and isStanding(b, j):
				hit.append(j)
		if hit.is_empty():
			return {"floors": true, "k": k, "hit": hit, "sumS": 0.0, "dmg": dmg, "ratio": 999.0, "outcome": "punch", "pass": true, "keep": KEEP_FREE, "deaths": 0.0}
		var sumS: float = 0.0
		for j in hit:
			sumS += floorStr(b, j)
		var ratio: float = dmg / sumS
		var pop: float = floorPop(b)
		if ratio >= 1.0:
			var keep: float = clampf(KEEP_HI - KEEP_K * sumS / KEEP_REF, KEEP_MIN, KEEP_HI)
			return {"floors": true, "k": k, "hit": hit, "sumS": sumS, "dmg": dmg, "ratio": ratio, "outcome": "punch", "pass": true, "keep": keep, "deaths": pop * float(hit.size())}
		if ratio >= 0.4:
			return {"floors": true, "k": k, "hit": hit, "sumS": sumS, "dmg": dmg, "ratio": ratio, "outcome": "crack", "pass": false, "keep": 0.0, "deaths": pop * float(hit.size()) * minf(1.0, ratio * FLOOR_DEATH)}
		return {"floors": true, "k": k, "hit": hit, "sumS": sumS, "dmg": dmg, "ratio": ratio, "outcome": "dent", "pass": false, "keep": 0.0, "deaths": 0.0}
	var r: float = dmg / b.maxhp
	var keepw: float = clampf(KEEP_HI - KEEP_K * b.maxhp / KEEP_REF, KEEP_MIN, KEEP_HI)
	var frac: float = minf(b.hp, dmg) / b.maxhp
	var dead: float = minf(b.popAlive, b.pop * frac * 1.3)
	if r >= 1.0:
		return {"floors": false, "dmg": dmg, "ratio": r, "outcome": "collapse", "pass": true, "keep": keepw, "deaths": b.popAlive}
	if r >= 0.6:
		return {"floors": false, "dmg": dmg, "ratio": r, "outcome": "heavy", "pass": true, "keep": keepw * HEAVY_KEEP, "deaths": dead}
	if r >= 0.4:
		return {"floors": false, "dmg": dmg, "ratio": r, "outcome": "wreck", "pass": false, "keep": 0.0, "deaths": dead}
	return {"floors": false, "dmg": dmg, "ratio": r, "outcome": "crack", "pass": false, "keep": 0.0, "deaths": dead}


static func chainCap(tier: float, special: bool) -> int:
	return CHAIN_ABS if special else CHAIN_MAX[clampi(int(tier), 1, 4) - 1]


## The next building on the line after b, for a fighter leaving b's far edge with velocity (vx, vy) at height y (vx
## carries the traversal factor trav): the nearest building ahead within CHAIN_GAP in x and CHAIN_DZ in depth whose
## footprint the flight enters. Returns {"b": index, "r": flightTo result} or {"b": -1}.
static func next(S: SimState, b, y: float, vx: float, vy: float, trav: float) -> Dictionary:
	var dir: float = -1.0 if vx < 0.0 else 1.0
	var far: float = SimWrap.wrap(b.x + dir * b.w * 0.5)
	var best: Array = []
	for bi in WorldStructures.near(S, SimWrap.wrap(far + dir * CHAIN_GAP * 0.5), CHAIN_GAP * 0.5 + 64.0):
		var nb = S.buildings[bi]
		if not nb.alive or nb == b:
			continue
		var gap: float = SimWrap.sdx(far, nb.x) * dir - nb.w * 0.5
		if gap < 0.0 or gap > CHAIN_GAP or absf(nb.z - b.z) > CHAIN_DZ:
			continue
		best.append([gap, bi])
	best.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	for e in best:
		var cand = S.buildings[e[1]]
		var fr: Dictionary = flightTo(S, far, y, vx, vy, trav, cand)
		if fr.ok:
			return {"b": e[1], "r": fr}
	return {"b": -1}


## The chain a launch would make: starting from the first hit fr (a flightTo result) on building b, by a launcher of the given
## tier (special: a finisher may chain up to CHAIN_ABS). Returns an Array of {"b", "spN", "y", "dmg", "ratio", "outcome",
## "keep", "deaths", "t"}; length 1 is a plain brunt. A pure lookahead: nothing is changed.
static func chainPlan(S: SimState, tier: float, special: bool, b, fr: Dictionary, trav: float) -> Array:
	var out: Array = []
	var cap: int = chainCap(tier, special)
	var cur = b
	var r: Dictionary = fr
	var t0: float = fr.t
	while true:
		var oc: Dictionary = outcomeOf(S, cur, r.y, r.spN, tier)
		out.append({"b": cur.idx, "spN": r.spN, "y": r.y, "dmg": oc.dmg, "ratio": oc.ratio, "outcome": oc.outcome, "keep": oc.keep, "deaths": oc.deaths, "t": t0})
		if not oc.pass or out.size() >= cap:
			break
		var vx2: float = r.vx * oc.keep
		var vy2: float = r.vy * oc.keep
		if SimDetMath.hypot(vx2 / trav, vy2) < CHAIN_MIN_SP:
			break
		var nx: Dictionary = next(S, cur, r.y, vx2, vy2, trav)
		if nx.b < 0:
			break
		cur = S.buildings[nx.b]
		r = nx.r
		t0 += nx.r.t
	return out


## Expected deaths of a chain.
static func chainDeaths(chain: Array) -> float:
	var d: float = 0.0
	for e in chain:
		d += e.deaths
	return d


# ===================================================================== candidates and aim (the planner's interface)

## A cheap score used to choose which buildings are worth an aim search: tall, occupied, undamaged.
static func _cheap(b) -> float:
	return b.h / (BH * WS) + minf(b.popAlive, 8.0) + (2.0 if b.hp >= b.maxhp else 0.0)


## The buildings worth trying for a launch of D by A: alive, BR_MIN to BR_MAX away in x on either side, in any row, with
## the top above D's height minus 40, the best BR_PRESELECT per side by the cheap score. Ordered by side (-1 then 1) and
## score, then index, so the order is fixed.
static func candidates(S: SimState, D) -> Array:
	var sides: Array = [[], []]
	for bi in WorldStructures.near(S, D.x, BR_MAX):
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var dx: float = SimWrap.sdx(D.x, b.x)
		var d: float = absf(dx) - b.w * 0.5
		if d < BR_MIN or d > BR_MAX:
			continue
		if D.y > WorldStructures.baseY(S, b) + WorldStructures.curH(b) + 40.0:
			continue
		sides[0 if dx < 0.0 else 1].append([_cheap(b), bi])
	var out: Array = []
	for s in sides:
		s.sort_custom(func(p, q): return p[0] > q[0] or (p[0] == q[0] and p[1] < q[1]))
		for k in range(mini(BR_PRESELECT, s.size())):
			out.append(s[k][1])
	return out


## The launch that brings the target D (launched by A with the given force and tier factor) into building b, or null:
## the first uy in AIM_UY whose flight enters b above the ground and below its top at AIM_MIN_SP or more. The result has
## the plan fields the launch needs (ux, uy, fm) and "brunt": {"b", "hit", "chain", "deaths", "z1", "aimD"}.
static func aim(S: SimState, A, D, b, force: float, tierF: float, special: bool = false):
	var sign_: float = 1.0 if SimWrap.sdx(D.x, b.x) >= 0.0 else -1.0
	for uy in AIM_UY:
		var trav: float = WorldSlide.launchTravel(sign_, uy)
		var fr: Dictionary = flightTo(S, D.x, D.y, WorldSlide.launchVX(sign_, uy, force * tierF), uy * force * tierF, trav, b)
		if fr.ok and fr.spN >= AIM_MIN_SP:
			var chain: Array = chainPlan(S, A.tier, special, b, fr, trav)
			var edge: float = SimWrap.wrap(b.x - sign_ * b.w * 0.5)
			return {"ux": sign_, "uy": uy, "fm": 1.0, "name": "BUILDING SMASH",
				"brunt": {"b": b.idx, "hit": fr, "chain": chain, "deaths": chainDeaths(chain), "z1": faceZ(b), "aimD": absf(SimWrap.sdx(D.x, edge))}}
	return null


# ===================================================================== the runtime

## Give a launched fighter his aim from the plan (doLaunch): the building, the depth waypoints and the chain token.
static func arm(S: SimState, f, att, plan: Dictionary) -> void:
	f.aimB = -1
	f.aimX0 = f.x
	f.aimZ0 = 0.0
	f.aimZ1 = 0.0
	f.aimD = 1.0
	f.chainEvt = 0.0
	f.flightHits = 0
	f.splashed = PackedInt32Array()
	# a new launch starts a new journey (world/contact.gd) and takes the next launch number, which its events carry
	f.jContacts = 0
	f.jT = 0
	f.jV0 = 0.0
	f.tumbleT = -1
	f.contactT = 0
	f.jLips = 0
	f.slideDmg = 0.0
	f.launchN += 1
	var slot: float = float(S.fighters.find(f))
	for i in range(S.out.fx.size() - 1, -1, -1):
		var le = S.out.fx[i]
		if le.type == "launch" and le.actor == slot:
			le.n = f.launchN
			break
	if not plan.has("brunt"):
		return
	var br: Dictionary = plan.brunt
	f.aimB = br.b
	f.aimZ1 = br.z1
	f.aimD = maxf(br.aimD, 1.0)
	if br.chain.size() > 1:
		f.chainEvt = WorldCollateral.beginEvent(S, "chain", att)
	var b = S.buildings[br.b]
	SimFx.launchDepth(S, f, att, br.hit.x, br.hit.y, br.z1, br.b, br.hit.t, br.chain.size())


## The fighter's depth for this tick: a smoothstep of his x progress toward the aimed building's face, easing back to the
## plane when he is not aimed. A function of state; it enters no physics.
static func stepZ(S: SimState, f, dt: float) -> void:
	if f.aimB >= 0:
		var p: float = clampf(absf(SimWrap.sdx(f.aimX0, f.x)) / f.aimD, 0.0, 1.0)
		f.z = f.aimZ0 + (f.aimZ1 - f.aimZ0) * p * p * (3.0 - 2.0 * p)
	elif f.z != 0.0:
		f.z *= SimDetMath.pow(0.001, dt)
		if absf(f.z) < 0.5:
			f.z = 0.0


## The flight is over (a landing, a slide, water, a rebound): drop the aim, close the chain's token, release the depth.
static func endFlight(S: SimState, f) -> void:
	f.aimB = -1
	if f.chainEvt != 0.0:
		WorldCollateral.endEvent(S, f.chainEvt)
		f.chainEvt = 0.0


## Called each tick of a launched flight after the move, with the position before it (ox, oy): did the fighter cross the
## aimed building's near edge? If so, resolve the hit and carry on, rebound or end. Returns true if a hit happened.
static func checkHit(S: SimState, f, ox: float, oy: float) -> bool:
	if f.aimB < 0:
		return false
	var b = S.buildings[f.aimB]
	if not b.alive:
		f.aimB = -1
		return false
	var dir: float = -1.0 if f.vx < 0.0 else 1.0
	var edge: float = SimWrap.wrap(b.x - dir * b.w * 0.5)
	var fr: float = crossFrac(ox, f.x, edge, dir)
	if fr < 0.0:
		if SimWrap.sdx(edge, f.x) * dir > b.w:
			f.aimB = -1   # flew past without touching it
		return false
	var yc: float = oy + (f.y - oy) * fr
	var gy: float = WorldStructures.baseY(S, b)
	if yc < gy - 10.0 or yc > gy + WorldStructures.curH(b):
		f.aimB = -1
		return false
	hit(S, f, b, yc, edge, dir)
	return true


## Resolve one hit on building b at height y on the near edge, and what happens to the fighter.
static func hit(S: SimState, f, b, y: float, edge: float, dir: float) -> void:
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	var trav: float = f.launchT
	var spN: float = SimDetMath.hypot(f.vx / trav, f.vy)
	var oc: Dictionary = outcomeOf(S, b, y, spN, by.tier)
	f.flightHits += 1
	var link: int = f.flightHits
	var slot: float = float(S.fighters.find(f))
	var hitText: String = oc.outcome
	var evt: float = f.chainEvt
	var cx: float = f.x
	# --- apply to the building ---
	var pancaked: bool = false
	if oc.floors:
		var res: Dictionary = applyFloors(S, b, oc, by, evt, cx, f, y)
		pancaked = res.pancake
		if res.collapse:
			hitText = "collapse"
		elif pancaked:
			hitText = "pancake"
	else:
		WorldStructures.damageBuilding(S, b, oc.dmg, by, "burst", cx, evt)
		if not b.alive:
			hitText = "collapse"
	SimFx.buildingHitB2(S, f, b, y, link, by, oc, hitText, spN)
	var passes: bool = oc.pass or hitText == "collapse" or hitText == "pancake"
	var far: float = SimWrap.wrap(b.x + dir * b.w * 0.5)
	# --- what comes next: decided before the splash, so the splash can never take the next link of a chain away ---
	var keep: float = (oc.keep if oc.pass else KEEP_HI) if passes else 0.0
	var nx: Dictionary = {"b": -1}
	if passes and link < chainCap(by.tier, f.launchSpecial) and SimDetMath.hypot(f.vx * keep / trav, f.vy * keep) >= CHAIN_MIN_SP:
		nx = next(S, b, y, f.vx * keep, f.vy * keep, trav)
	# --- splash on the neighbours, once per launch ---
	_splash(S, f, b, oc.dmg, by, evt, cx, far, dir, passes and nx.b >= 0)
	# --- the fighter ---
	SimDamage.hurt(S, f, spN * FIGHTER_DMG, by)
	SimFx.debris(S, f.x, y + 20.0, 6, "#77808f", 500.0)
	var stop: float = STOP_FIRST if link == 1 else STOP_LINK
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, minf(stop, STOP_TOTAL))
	if passes:
		f.vx *= keep
		f.vy *= keep
		# out of the far face exactly where chainPlan's lookahead starts the next flight (plan and outcome stay one)
		f.x = far
		f.y = y
		f.aimX0 = f.x
		f.aimZ0 = faceZ(b)
		f.aimB = -1
		if nx.b >= 0:
			var nb = S.buildings[nx.b]
			f.aimB = nx.b
			f.aimZ1 = faceZ(nb)
			f.aimD = maxf(absf(SimWrap.sdx(f.x, nx.r.x)), 1.0)
			SimFx.chainLink(S, f, by, b, nb, y, nx.r, link + 1)
		else:
			endFlight(S, f)
	else:
		# a rebound: a quarter of the speed backward, outside the near face; the chain ends
		f.vx = -dir * absf(f.vx) * 0.25
		f.vy *= 0.85
		f.x = SimWrap.wrap(edge - dir * 18.0)
		endFlight(S, f)


## Splash: buildings beside b (within SPLASH_W of its width in x and SPLASH_Z in depth) take SPLASH_FRAC of the hit's damage,
## each at most once per launch (the launch keeps a small list), as area damage (they implode if levelled). While the flight
## goes on the buildings ahead of the hit are spared, so a chain is always its own plan (chainPlan reads pristine buildings).
static func _splash(S: SimState, f, b, dmg: float, by, evt: float, cx: float, far: float, dir: float, chainGoesOn: bool) -> void:
	for bi in WorldStructures.near(S, b.x, b.w * (0.5 + SPLASH_W) + 64.0):
		var nb = S.buildings[bi]
		if not nb.alive or nb == b or f.splashed.size() >= SPLASH_CAP:
			continue
		if f.splashed.has(bi) or nb.idx == f.aimB:
			continue
		if chainGoesOn and SimWrap.sdx(far, nb.x) * dir - nb.w * 0.5 >= 0.0:
			continue   # ahead of the hit while the flight goes on: the chain may need it standing
		if absf(SimWrap.sdx(b.x, nb.x)) - (b.w + nb.w) * 0.5 > SPLASH_W * b.w or absf(nb.z - b.z) > SPLASH_Z:
			continue
		f.splashed.append(bi)
		WorldStructures.damageBuilding(S, nb, dmg * SPLASH_FRAC, by, "implode", cx, evt)


# ===================================================================== floors: applying a hit and the pancake

## Apply a floor outcome to building b: clear the punched floors, crack or dent, wear the core, kill the occupants of the
## floors lost (through the collateral module, so the budget and the token apply), then the pancake. Returns
## {"pancake": bool, "collapse": bool}.
static func applyFloors(S: SimState, b, oc: Dictionary, by, evt: float, cx: float, f, y: float) -> Dictionary:
	var res := {"pancake": false, "collapse": false}
	var F: int = b.floors
	if b.fdmg.size() != F:
		b.fdmg = PackedFloat32Array()
		b.fdmg.resize(F)
		b.fdmg.fill(0.0)
	var popF: float = floorPop(b)
	var slot: float = float(S.fighters.find(f))
	var lowest: int = oc.k
	if oc.outcome == "punch":
		var cleared: int = 0
		for j in oc.hit:
			b.fmask = b.fmask & ~(1 << j)
			b.fdmg[j] = 0.0
			cleared += 1
			lowest = mini(lowest, j)
		if cleared > 0:
			WorldCollateral.kill(S, b.idx, popF * float(cleared), by, evt, cx, lowest)
		SimFx.floorHit(S, f, b, lowest, cleared, "punch", oc.ratio, y, by)
	elif oc.outcome == "crack":
		for j in oc.hit:
			b.fdmg[j] += oc.dmg
		var d: float = popF * float(oc.hit.size()) * minf(1.0, oc.ratio * FLOOR_DEATH)
		if d > 0.0:
			WorldCollateral.kill(S, b.idx, d, by, evt, cx, oc.hit[0])
		SimFx.floorHit(S, f, b, oc.hit[0], 0, "crack", oc.ratio, y, by)
	else:
		for j in oc.hit:
			b.fdmg[j] += oc.dmg
		SimFx.floorHit(S, f, b, oc.hit[0] if oc.hit.size() > 0 else oc.k, 0, "dent", oc.ratio, y, by)
	# local damage wears the core; the building goes when it is spent
	b.hp -= CORE_SHARE * oc.dmg
	if b.hp <= 0.0:
		res.collapse = true
		WorldStructures.collapse(S, b, by, "burst", cx, evt)
		return res
	if oc.outcome == "punch":
		var pk: Dictionary = pancake(S, b, by, evt, cx, f)
		res.pancake = pk.pancake
		res.collapse = pk.collapse
	return res


## A cleared span longer than TUNNEL_MAX drops the floors above it: the stack of m floors breaks each floor below while
## PANCAKE_K * m >= its strength, joining it. The floors it breaks, and the stack itself, are gone (their occupants die
## through the collateral module); if it reaches the ground the whole building goes. Returns {"pancake", "collapse"}.
static func pancake(S: SimState, b, by, evt: float, cx: float, f) -> Dictionary:
	var res := {"pancake": false, "collapse": false}
	var F: int = b.floors
	# the longest cleared run that contains a just-cleared floor and has standing floors above it
	var top: int = topFloor(b)
	if top < 0:
		return res
	var run_hi: int = -1
	var run_lo: int = -1
	var k: int = 0
	while k < top:
		if not isStanding(b, k):
			var lo: int = k
			while k < top and not isStanding(b, k):
				k += 1
			if k - lo > TUNNEL_MAX and k <= top:
				run_lo = lo
				run_hi = k - 1
				break
		else:
			k += 1
	if run_hi < 0:
		return res
	# the stack: every standing floor above the run
	var m: int = 0
	for j in range(run_hi + 1, F):
		if isStanding(b, j):
			m += 1
	var popF: float = floorPop(b)
	var from_floor: int = run_lo
	var lost: int = m
	# clear the stack
	for j in range(run_hi + 1, F):
		b.fmask = b.fmask & ~(1 << j)
	var j2: int = run_lo - 1
	var stack: float = float(m)
	while j2 >= 0:
		if isStanding(b, j2):
			if PANCAKE_K * stack >= floorStr(b, j2):
				b.fmask = b.fmask & ~(1 << j2)
				stack += 1.0
				lost += 1
				from_floor = j2
			else:
				break
		j2 -= 1
	res.pancake = true
	WorldCollateral.kill(S, b.idx, popF * float(lost), by, evt, cx, from_floor)
	SimFx.floorsFall(S, b, from_floor, F - 1, lost + (run_hi - run_lo + 1))
	if standingCount(b) == 0:
		res.collapse = true
		b.hp = 0.0
		WorldStructures.collapse(S, b, by, "burst", cx, evt)
	return res
