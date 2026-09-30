class_name DirLaunch
## Launch planner (Encounter Systems): scores launch candidates for a launch beat and picks the best (chooseLaunch),
## then applies it (doLaunch). Born as the twin of launch.js; since ADR 0006 it scores where the fight goes as well as
## how the hit looks (balance-targets.md section 10):
##  - a flight predictor estimates where each candidate lands and how far it carries the target;
##  - a distance term favours long hauls across the map and a new-biome term favours landing somewhere new, both only
##    when the landing is open ground (empty land, not a town); a water term steers away from launches that end in the
##    sea (a fighter who hits water stops dead and the fight sinks);
##  - SLAM DOWN no longer gets a bonus over the ocean or the city;
##  - SMASH ACROSS is the long haul or nothing: a rising arc whose force is raised (up to HAUL_FM_MAX) so the predicted
##    flight reaches HAUL_TARGET, and it drops out when it still cannot carry the target HAUL_MIN;
##  - the predictor stops a flight or a slide at the first standing building, so a throw into a town is scored as the
##    short crash it will be; MOUNTAINSIDE aims at the nearest slope ahead out to MOUNTAIN_REACH;
##  - BUILDING SMASH scores building height in fighter-scale terms (h / (32 x WS)) since the world scale;
##  - "NONE" competes too: when no launch beats it, the strike knocks the target back instead of launching it, which
##    keeps launches to a few a minute and makes each one count. Holding back is scored with the personality term at
##    the target's position, so the hero throws the villain out of a town rather than leaving the fight there.
## Candidate order fixes the order of the noise draws.

const NOISE: float = 8.0            # uniform noise added to every candidate
const CARE_W: float = 34.0          # personality: -care x this x population near the landing point
const CARE_R: float = 700.0 * SimConst.WS
const REPEAT_1: float = 20.0        # variety: the previous launch
const REPEAT_2: float = 10.0        # variety: the one before
const DIST_W: float = 12.0          # per 1000 units of predicted horizontal travel
const DIST_UNIT: float = 1000.0 * SimConst.TRAV_LAUNCH   # a launch's horizontal reach is TRAV_LAUNCH times longer (world/slide.gd)
const DIST_CAP: float = 3.0 * DIST_UNIT
const HAUL_TARGET: float = 2.2 * DIST_UNIT   # SMASH ACROSS aims to carry the target this far (13,200 units, 176 bh)
const HAUL_FM_MAX: float = 3.0             # ... with at most this force multiplier
const HAUL_MIN: float = 1.6 * DIST_UNIT     # below this predicted travel SMASH ACROSS drops out (9,600 units, 128 bh)
const HAUL_SHORT: float = 100.0            # the score it loses then
const MOUNTAIN_STEP: float = 520.0 * SimConst.WS   # the mountainside probe: first step (the old single probe) ...
const MOUNTAIN_REACH: float = 1560.0 * SimConst.WS # ... and the farthest slope it looks for (12,480 units)
const OPEN_POP: float = 0.2         # popNear(landing, CARE_R) at or below this is open ground
const NEW_BIOME_W: float = 10.0     # predicted landing in a different biome that is not ocean
const WATER_W: float = 45.0         # predicted landing in the sea
const NONE_BASE: float = 25.0       # "no launch"
const ACROSS_UY: float = 0.32       # SMASH ACROSS arc
const ACROSS_FORCE: float = 2.0     # SMASH ACROSS force multiplier
const KNOCKBACK: float = 700.0      # push when no launch is chosen
## BUILDING SMASH scoring (B2). The occupancy term saturates at BRUNT_POP_REF living people: at today's scale a building holds
## one to five, not the thirteen the first draft assumed.
const BRUNT_BASE: float = 14.0
const BRUNT_POP_REF: float = 8.0
const BRUNT_TALL_W: float = 12.0     # the fighter who feeds on collateral seeks tall buildings
const BRUNT_FRESH: float = 4.0       # an undamaged building
const BRUNT_ROW_W: float = 2.0       # ... and deeper rows (more dramatic)
const BRUNT_CHAIN_DRAMA: float = 5.0
const BRUNT_DRAMA_CAP: float = 14.0
const BRUNT_REPEAT: float = 12.0     # the same building twice running
const BRUNT_RAMP: float = 5.0        # per planner launch that had a building in reach and chose something else
const BRUNT_OVER_BUDGET: float = 40.0
const PREDICT_REACH: float = 40000.0  # buildings farther than this from the launch point are not checked
const PREDICT_STEPS: int = 240      # flight predictor horizon: 4 s at the fixed step


## force is the template's launch force; the prediction uses it with the tier scaling doLaunch applies.
## longOnly (break and finisher launches, spec-wounds.md §1): only the long-haul candidates (SMASH ACROSS, BUILDING SMASH,
## MOUNTAINSIDE), SMASH ACROSS always offered, and no "no launch".
static func chooseLaunch(S: SimState, A, D, force: float, longOnly: bool = false) -> Dictionary:
	var g: float = WorldTerrain.groundY(S, D.x)
	var alt: float = D.y - g
	var bio: String = WorldBiomes.biomeAt(D.x)
	var f: float = A.face
	var c: Array = []
	if not longOnly:
		c.append({"name": "UPPERCUT", "ux": 0.25 * f, "uy": 1.0, "s": 10.0 + (12.0 if alt < 120.0 else 0.0)})
	if not longOnly:
		c.append({"name": "SLAM DOWN", "ux": 0.2 * f, "uy": -1.25, "s": (18.0 if alt > 140.0 else 0.0) + A.tier * 4.0 + (8.0 if bio == "forest" else 0.0)})
	c.append({"name": "SMASH ACROSS", "ux": f, "uy": ACROSS_UY, "fm": ACROSS_FORCE, "s": 8.0})
	var tierF: float = 1.0 + A.ld.launch * (A.tier - 1.0)   # D1b: ladder.json
	# BUILDING SMASH (B2, docs/world/b2-plan.md section 4): one candidate per building the launch can be aimed at, in any row,
	# scored by personality first and drama on top; a chain through several buildings is part of the candidate.
	var hadBrunt: bool = false
	for bi in WorldBrunt.candidates(S, D):
		var plan = WorldBrunt.aim(S, A, D, S.buildings[bi], force, tierF, longOnly)
		if plan != null:
			hadBrunt = true
			plan.s = bruntScore(S, A, plan)
			c.append(plan)
	for sign in [-1.0, 1.0]:
		# The nearest mountainside ahead, out to MOUNTAIN_REACH: near slopes give a short throw, far ones a long haul.
		var md: float = MOUNTAIN_STEP
		while md <= MOUNTAIN_REACH:
			if WorldBiomes.biomeAt(D.x + sign * md) == "mountains":
				c.append({"name": "MOUNTAINSIDE", "ux": sign, "uy": 0.05, "s": 24.0, "land": D.x + sign * md})
				break
			md += MOUNTAIN_STEP
	if not longOnly:
		c.append({"name": "NONE", "ux": 0.0, "uy": 0.0, "s": NONE_BASE})
	for k in c:
		k.s += S.rng.range_(0.0, NOISE)
		if k.name == "NONE":
			# Holding back leaves the fight where it is: the same personality term, at the target's position.
			k.s += (-A.care) * CARE_W * WorldStructures.popNear(S, D.x, CARE_R)
			continue
		if k.has("brunt"):
			# A brunt is scored by bruntScore; its flight is WorldBrunt's, so there is nothing to predict here.
			var br: Dictionary = k.brunt
			var lastb = S.buildings[br.chain[br.chain.size() - 1].b]
			k.land = lastb.x
			k.travel = absf(SimWrap.sdx(D.x, lastb.x))
			k.p = {"x": br.hit.x, "travel": k.travel, "water": false, "building": true, "t": br.hit.t}
			if k.name == S.dirS.lastLaunch:
				k.s -= REPEAT_1
			if k.name == S.dirS.lastLaunch2:
				k.s -= REPEAT_2
			continue
		var fm: float = k.fm if k.has("fm") else 1.0
		var p: Dictionary = predictFlight(S, D.x, D.y, WorldSlide.launchVX(k.ux, k.uy, force * fm * tierF), k.uy * force * fm * tierF, WorldSlide.launchTravel(k.ux, k.uy))
		if k.name == "SMASH ACROSS" and p.travel < HAUL_TARGET:
			# The long haul: raise the force (once, square-root rule, capped) so the predicted flight reaches HAUL_TARGET.
			fm = SimMathx.jmin(HAUL_FM_MAX, fm * sqrt(HAUL_TARGET / SimMathx.jmax(p.travel, 1.0)))
			k.fm = fm
			p = predictFlight(S, D.x, D.y, WorldSlide.launchVX(k.ux, k.uy, force * fm * tierF), k.uy * force * fm * tierF, WorldSlide.launchTravel(k.ux, k.uy))
		if k.name == "SMASH ACROSS" and p.travel < HAUL_MIN and not longOnly:
			# SMASH ACROSS is the long haul or nothing: when it cannot carry the target HAUL_MIN, it is not offered.
			k.s -= HAUL_SHORT
		k.p = p
		var lx: float = k.land if k.has("land") else p.x
		k.travel = absf(SimWrap.sdx(D.x, lx)) if k.has("land") else p.travel
		var popL: float = WorldStructures.popNear(S, lx, CARE_R)
		k.s += (-A.care) * CARE_W * popL
		# Distance and new ground only count when the landing is open ground: long hauls carry the fight to empty land.
		if popL <= OPEN_POP:
			k.s += DIST_W * SimMathx.jmin(k.travel, DIST_CAP) / DIST_UNIT
		var lb: String = WorldBiomes.biomeAt(lx)
		if lb != bio and lb != "ocean" and popL <= OPEN_POP:
			k.s += NEW_BIOME_W
		if p.water and not k.has("land"):
			k.s -= WATER_W
		if k.name == S.dirS.lastLaunch:
			k.s -= REPEAT_1
		if k.name == S.dirS.lastLaunch2:
			k.s -= REPEAT_2
	# Stable sort by score, highest first: an insertion sort keeps equal scores in candidate order.
	for i in range(1, c.size()):
		var key = c[i]
		var j: int = i - 1
		while j >= 0 and key.s - c[j].s > 0.0:
			c[j + 1] = c[j]
			j -= 1
		c[j + 1] = key
	# The pity counter: launches that had a building in reach and chose something else make the next brunt likelier.
	if hadBrunt:
		if c[0].name == "BUILDING SMASH":
			S.dirS.sinceBrunt = 0.0
			S.dirS.lastBrunt = float(c[0].brunt.b)
		else:
			S.dirS.sinceBrunt += 1.0
	return {"best": c[0], "top": c.slice(0, 3), "all": c}


## The score of a BUILDING SMASH candidate (docs/world/b2-plan.md section 4): a base, the launcher's tier, personality (who
## is in the building and, for a fighter who feeds on collateral, how tall it is), drama on top (capped: personality decides
## which building, drama decides among near equals), the pity counter, a repeat penalty, and a penalty for a chain that would
## exceed the casualty budget the runtime will enforce.
static func bruntScore(S: SimState, A, plan: Dictionary) -> float:
	var chain: Array = plan.brunt.chain
	var pers: float = 0.0
	var drama: float = 0.0
	var first = S.buildings[chain[0].b]
	for i in range(chain.size()):
		var cb = S.buildings[chain[i].b]
		pers += (-A.care) * CARE_W * clampf(cb.popAlive / BRUNT_POP_REF, 0.0, 1.0)
		if A.care < 0.0:
			pers += (-A.care) * BRUNT_TALL_W * clampf(cb.h / SimConst.WS / 400.0, 0.0, 1.0)
	drama += first.h / SimConst.WS / 32.0 + (BRUNT_FRESH if first.hp >= first.maxhp else 0.0)
	if A.care < 0.0:
		drama += BRUNT_ROW_W * first.row
	drama += BRUNT_CHAIN_DRAMA * float(chain.size() - 1)
	var s: float = BRUNT_BASE + 3.0 * A.tier + pers + minf(drama, BRUNT_DRAMA_CAP) + BRUNT_RAMP * S.dirS.sinceBrunt
	if S.dirS.lastBrunt == float(chain[0].b):
		s -= BRUNT_REPEAT
	if chain.size() > 1:
		var allow: float = 0.0
		if A.tier >= 3.0:
			allow = WorldCollateral.EVENT_ALLOW["chain"][int(A.tier) - 1] * S.world.pop0
		if plan.brunt.deaths > WorldCollateral.room(S) + allow:
			s -= BRUNT_OVER_BUDGET
	return s


## Where a launched fighter would come to rest: the free-flight part of SimFighter.stepLaunched (gravity, air drag,
## water drag and the stop in water, ground impacts by the slam-or-slide rule of world/slide.gd), without buildings (a launch
## collides only with the building it is aimed at: WorldBrunt.aim and chainPlan predict that). It reads the terrain
## and never writes state. Returns {"x": landing x, "travel": horizontal distance, "water": ends in the sea}.
static func predictFlight(S: SimState, x0: float, y0: float, vx0: float, vy0: float, trav: float = 1.0) -> Dictionary:
	var dt: float = SimConst.DT
	var kAir: float = SimDetMath.pow(0.55, dt)
	var kWx: float = SimDetMath.pow(0.05, dt)
	var kWy: float = SimDetMath.pow(0.1, dt)
	var x: float = x0
	var y: float = y0
	var vx: float = vx0
	var vy: float = vy0
	var travel: float = 0.0
	var t: float = 0.0
	var dir0: float = -1.0 if vx0 < 0.0 else 1.0
	for n in range(PREDICT_STEPS):
		t += dt
		vy -= 1000.0 * dt
		vx *= kAir
		x = SimWrap.wrap(x + vx * dt)
		travel += vx * dt
		y += vy * dt
		if y < 0.0 and WorldTerrain.seaAt(S, x):
			vx *= kWx
			vy *= kWy
			if SimDetMath.hypot(vx, vy) < 200.0 and t > 0.3:
				return {"x": x, "travel": absf(travel), "water": true, "t": t}
		var g: float = WorldTerrain.groundY(S, x)
		if y <= g:
			# The same rule as SimFighter.impact: a slam (or the sea, or too slow) lands here; anything shallower is a
			# knockback slide that ends slideDistance() further on. The optional hop is ignored.
			y = g
			var spN: float = SimDetMath.hypot(vx / trav, vy)
			var sea: bool = WorldTerrain.seaAt(S, x)
			if sea or spN <= WorldSlide.MIN_IMPACT or WorldSlide.isSlam(vx, vy):
				return {"x": x, "travel": absf(travel), "water": sea, "t": t}
			var dir: float = 1.0 if vx >= 0.0 else -1.0
			var d: float = minf(WorldSlide.slideDistance(spN, WorldSlide.slope(S, x, dir), trav), SimConst.W * 0.25)
			return {"x": SimWrap.wrap(x + dir * d), "travel": absf(travel) + d, "water": false, "t": t}
	return {"x": x, "travel": absf(travel), "water": y < 0.0 and WorldTerrain.seaAt(S, x), "t": t}


## special marks a signature, a finisher or a break launch: its ground impact may leave a big crater (world/crater.gd).
static func doLaunch(S: SimState, att, tgt, plan: Dictionary, force: float, special: bool = false) -> void:
	var fm: float = plan.fm if plan.has("fm") else 1.0
	var f: float = force * fm * (1.0 + att.ld.launch * (att.tier - 1.0))   # D1b: ladder.json
	tgt.state = "launched"
	tgt.launchBy = att
	tgt.bounces = 0.0
	tgt.launchSpecial = special
	tgt.hopped = false
	tgt.stateT = 0.0
	tgt.rush = null
	tgt.hidden = false
	tgt.wet = tgt.y < 0.0 and WorldTerrain.seaAt(S, tgt.x)
	tgt.launchT = WorldSlide.launchTravel(plan.ux, plan.uy)
	tgt.slide = 0.0
	tgt.vx = plan.ux * f * tgt.launchT
	tgt.vy = plan.uy * f
	tgt.spin = (1.0 if plan.ux >= 0.0 else -1.0) * S.rng.range_(8.0, 16.0)
	SimFx.launch(S, tgt, att, SimDetMath.hypot(tgt.vx, tgt.vy), 1.0 if tgt.vx >= 0.0 else -1.0)
	WorldBrunt.arm(S, tgt, att, plan)   # B2: the aimed building, the depth waypoints and the chain's token
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 600.0, "#ffffff", 0.3, 20.0)
	SimFx.shake(S, 10.0, tgt.x)


## No launch: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
