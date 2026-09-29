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
	for sign in [-1.0, 1.0]:
		var nb = WorldStructures.nearestBuilding(S, D.x, sign, 1100.0 * SimConst.WS, D.y)
		if nb != null:
			c.append({"name": "BUILDING SMASH", "ux": sign, "uy": 0.12, "s": 7.0 + nb.b.h / (32.0 * SimConst.WS) + A.tier * 3.0 + (6.0 if sign == f else -4.0), "land": D.x + sign * nb.d})
		# The nearest mountainside ahead, out to MOUNTAIN_REACH: near slopes give a short throw, far ones a long haul.
		var md: float = MOUNTAIN_STEP
		while md <= MOUNTAIN_REACH:
			if WorldBiomes.biomeAt(D.x + sign * md) == "mountains":
				c.append({"name": "MOUNTAINSIDE", "ux": sign, "uy": 0.05, "s": 24.0, "land": D.x + sign * md})
				break
			md += MOUNTAIN_STEP
	if not longOnly:
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
	return {"best": c[0], "top": c.slice(0, 3), "all": c}


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
	# Standing buildings ahead within reach, as [offset along the flight, half width + 16, ground, top, index], sorted by
	# offset: the flight stops at the first one it meets (the same box as SimFighter._buildingHits; smashing through is
	# not predicted). The flight never reverses (drag and water only slow it), so one pointer walks the list.
	var dir0: float = -1.0 if vx0 < 0.0 else 1.0
	var blds: Array = []
	var bi: int = 0
	for b in S.buildings:
		if b.alive:
			var off: float = SimWrap.sdx(x0, b.x) * dir0
			var half: float = b.w / 2.0 + 16.0
			if off + half > 0.0 and off < PREDICT_REACH:
				var gy: float = WorldTerrain.groundY(S, b.x)
				blds.append([off, half, gy, gy + WorldStructures.curH(b), bi])
		bi += 1
	blds.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[4] < q[4]))
	var bp: int = 0
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
		var along: float = travel * dir0
		while bp < blds.size() and blds[bp][0] + blds[bp][1] <= along:
			bp += 1
		var q: int = bp
		while q < blds.size() and blds[q][0] - blds[q][1] < along:
			var bb: Array = blds[q]
			if y < bb[3] and y > bb[2] - 10.0:
				return {"x": x, "travel": absf(travel), "water": false, "building": true, "t": t}
			q += 1
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
			# A slide stops at the first standing building on its path (the slide keeps the flight's direction).
			var along2: float = travel * dir0
			for q2 in range(bp, blds.size()):
				var ahead: float = blds[q2][0] - blds[q2][1] - along2
				if ahead >= 0.0 and ahead < d:
					d = ahead
					break
			return {"x": SimWrap.wrap(x + dir * d), "travel": absf(travel) + d, "water": false, "t": t}
	return {"x": x, "travel": absf(travel), "water": y < 0.0 and WorldTerrain.seaAt(S, x), "t": t}


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
	SimFx.launch(S, tgt, att, SimDetMath.hypot(tgt.vx, tgt.vy), 1.0 if tgt.vx >= 0.0 else -1.0)
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 600.0, "#ffffff", 0.3, 20.0)
	SimFx.shake(S, 10.0, tgt.x)


## No launch: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
