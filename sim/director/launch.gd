class_name DirLaunch
## Launch planner (Encounter Systems): scores launch candidates for a launch beat and picks the best (chooseLaunch),
## then applies it (doLaunch). Born as the twin of launch.js; since ADR 0006 it scores where the fight goes as well as
## how the hit looks (balance-targets.md section 10):
##  - a flight predictor estimates where each candidate lands and how far it carries the target;
##  - a distance term favours long hauls across the map and a new-biome term favours landing somewhere new, both only
##    when the landing is open ground (empty land, not a town); a water term steers away from launches that end in the
##    sea (a fighter who hits water stops dead and the fight sinks);
##  - SLAM DOWN no longer gets a bonus over the ocean or the city;
##  - SMASH ACROSS is the long haul: a rising arc with extra force;
##  - "NONE" competes too: when no launch beats it, the strike knocks the target back instead of launching it, which
##    keeps launches to a few a minute and makes each one count. Holding back is scored with the personality term at
##    the target's position, so the hero throws the villain out of a town rather than leaving the fight there.
## Candidate order fixes the order of the noise draws.

const NOISE: float = 8.0            # uniform noise added to every candidate
const CARE_W: float = 34.0          # personality: -care x this x population near the landing point
const CARE_R: float = 700.0 * SimConst.WS
const REPEAT_1: float = 14.0        # variety: the previous launch
const REPEAT_2: float = 5.0         # variety: the one before
const DIST_W: float = 12.0          # per 1000 units of predicted horizontal travel
const DIST_UNIT: float = 1000.0 * SimConst.TRAV_LAUNCH   # a launch's horizontal reach is TRAV_LAUNCH times longer (world/slide.gd)
const DIST_CAP: float = 3.0 * DIST_UNIT
const OPEN_POP: float = 0.2         # popNear(landing, CARE_R) at or below this is open ground
const NEW_BIOME_W: float = 10.0     # predicted landing in a different biome that is not ocean
const WATER_W: float = 10.0         # predicted landing in the sea
const NONE_BASE: float = 34.0       # "no launch"
const ACROSS_UY: float = 0.32       # SMASH ACROSS arc
const ACROSS_FORCE: float = 2.0     # SMASH ACROSS force multiplier
const KNOCKBACK: float = 700.0      # push when no launch is chosen
const PREDICT_STEPS: int = 240      # flight predictor horizon: 4 s at the fixed step


## force is the template's launch force; the prediction uses it with the tier scaling doLaunch applies.
static func chooseLaunch(S: SimState, A, D, force: float) -> Dictionary:
	var g: float = WorldTerrain.groundY(S, D.x)
	var alt: float = D.y - g
	var bio: String = WorldBiomes.biomeAt(D.x)
	var f: float = A.face
	var c: Array = []
	c.append({"name": "UPPERCUT", "ux": 0.25 * f, "uy": 1.0, "s": 14.0 + (14.0 if alt < 120.0 else 0.0)})
	c.append({"name": "SLAM DOWN", "ux": 0.2 * f, "uy": -1.25, "s": (24.0 if alt > 140.0 else 6.0) + A.tier * 4.0 + (8.0 if bio == "forest" else 0.0)})
	c.append({"name": "SMASH ACROSS", "ux": f, "uy": ACROSS_UY, "fm": ACROSS_FORCE, "s": 16.0})
	for sign in [-1.0, 1.0]:
		var nb = WorldStructures.nearestBuilding(S, D.x, sign, 1100.0 * SimConst.WS, D.y)
		if nb != null:
			c.append({"name": "BUILDING SMASH", "ux": sign, "uy": 0.12, "s": 12.0 + nb.b.h / 32.0 + A.tier * 3.0 + (6.0 if sign == f else -4.0), "land": D.x + sign * nb.d})
		if WorldBiomes.biomeAt(D.x + sign * 520.0 * SimConst.WS) == "mountains":
			c.append({"name": "MOUNTAINSIDE", "ux": sign, "uy": 0.05, "s": 24.0, "land": D.x + sign * 520.0 * SimConst.WS})
	c.append({"name": "NONE", "ux": 0.0, "uy": 0.0, "s": NONE_BASE})
	var tierF: float = 1.0 + 0.16 * (A.tier - 1.0)
	for k in c:
		k.s += S.rng.range_(0.0, NOISE)
		if k.name == "NONE":
			# Holding back leaves the fight where it is: the same personality term, at the target's position.
			k.s += (-A.care) * CARE_W * WorldStructures.popNear(S, D.x, CARE_R)
			continue
		var fm: float = k.fm if k.has("fm") else 1.0
		var p: Dictionary = predictFlight(S, D.x, D.y, WorldSlide.launchVX(k.ux, k.uy, force * fm * tierF), k.uy * force * fm * tierF, WorldSlide.launchTravel(k.ux, k.uy))
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
	return {"best": c[0], "top": c.slice(0, 3)}


## Where a launched fighter would come to rest: the free-flight part of SimFighter.stepLaunched (gravity, air drag,
## water drag and the stop in water, ground impacts by the slam-or-slide rule of world/slide.gd), without buildings. It reads the terrain
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
				return {"x": x, "travel": absf(travel), "water": true}
		var g: float = WorldTerrain.groundY(S, x)
		if y <= g:
			# The same rule as SimFighter.impact: a slam (or the sea, or too slow) lands here; anything shallower is a
			# knockback slide that ends slideDistance() further on. The optional hop is ignored.
			y = g
			var spN: float = SimDetMath.hypot(vx / trav, vy)
			var sea: bool = WorldTerrain.seaAt(S, x)
			if sea or spN <= WorldSlide.MIN_IMPACT or WorldSlide.isSlam(vx, vy):
				return {"x": x, "travel": absf(travel), "water": sea}
			var dir: float = 1.0 if vx >= 0.0 else -1.0
			var d: float = minf(WorldSlide.slideDistance(spN, WorldSlide.slope(S, x, dir), trav), SimConst.W * 0.25)
			return {"x": SimWrap.wrap(x + dir * d), "travel": absf(travel) + d, "water": false}
	return {"x": x, "travel": absf(travel), "water": y < 0.0 and WorldTerrain.seaAt(S, x)}


static func doLaunch(S: SimState, att, tgt, plan: Dictionary, force: float) -> void:
	var fm: float = plan.fm if plan.has("fm") else 1.0
	var f: float = force * fm * (1.0 + 0.16 * (att.tier - 1.0))
	tgt.state = "launched"
	tgt.launchBy = att
	tgt.bounces = 0.0
	tgt.stateT = 0.0
	tgt.rush = null
	tgt.hidden = false
	tgt.wet = tgt.y < 0.0 and WorldTerrain.seaAt(S, tgt.x)
	tgt.launchT = WorldSlide.launchTravel(plan.ux, plan.uy)
	tgt.slide = 0.0
	tgt.vx = plan.ux * f * tgt.launchT
	tgt.vy = plan.uy * f
	tgt.spin = (1.0 if plan.ux >= 0.0 else -1.0) * S.rng.range_(8.0, 16.0)
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 600.0, "#ffffff", 0.3, 20.0)
	SimFx.shake(S, 10.0)


## No launch: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
