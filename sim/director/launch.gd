class_name DirLaunch
## Launch planner (Encounter Systems): scores launch candidates for a launch beat and picks the best (chooseLaunch),
## then applies it (doLaunch). Born as the twin of launch.js; since ADR 0006 it scores where the fight goes as well as
## how the hit looks (balance-targets.md section 10):
##  - a flight predictor estimates where each candidate lands and how far it carries the target;
##  - a distance term favours long hauls across the map and a new-biome term favours landing somewhere new, both only
##    when the landing is open ground (empty land, not a town); a water term steers away from launches that end in the
##    sea (a fighter who hits water stops dead and the fight sinks);
##  - DRIVE DOWN (SLAM DOWN until the landing mix) gets no bonus over the ocean or the city;
##  - SMASH ACROSS is the long haul or nothing: a rising arc whose force is raised (up to HAUL_FM_MAX) so the predicted
##    flight reaches HAUL_TARGET, and it drops out when it still cannot carry the target HAUL_MIN;
##  - the predictor stops a flight or a slide at the first standing building, so a throw into a town is scored as the
##    short crash it will be; MOUNTAINSIDE aims at the nearest slope ahead out to MOUNTAIN_REACH;
##  - BUILDING SMASH scores building height in fighter-scale terms (h / (32 x WS)) since the world scale;
##  - "NONE" competes too: when no launch beats it, the strike knocks the target back instead of launching it, which
##    keeps launches to a few a minute and makes each one count. Holding back is scored with the personality term at
##    the target's position, so the hero throws the villain out of a town rather than leaving the fight there.
##  - the landing mix (balance-targets.md section 19): DRIVE DOWN (the old SLAM DOWN) sends the target down and forward
##    at 25 to 50 degrees by its height, which ploughs in and slides; the straight-down slam is its own candidate, CRATER SLAM, offered
##    only for a rival directly below the launcher and as the tier-3 crater set piece (data/director/launch.json).
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
const NONE_BASE: float = 25.0       # "no launch" in the old profiles; the knock-back's score is data (launch.json knockBack.score)
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
const BH: float = 75.0              # a body height, in units
const DATA_PATH: String = "res://data/director/launch.json"
static var _data = null
static var _dataText: String = ""


## data/director/launch.json: the drive's angle rule and the CRATER SLAM's gates and score.
static func data() -> Dictionary:
	if _data == null:
		_dataText = FileAccess.get_file_as_string(DATA_PATH)
		_data = JSON.parse_string(_dataText)
		if _data == null:
			push_error("DirLaunch: could not parse " + DATA_PATH)
			_data = {}
	return _data


## The data file's text, for DirData.dataHash() (the replay header).
static func dataText() -> String:
	data()
	return _dataText


## DRIVE DOWN's direction for a target alt units above the ground: [along the facing, up]. No draw.
static func driveDir(alt: float) -> Array:
	var d: Dictionary = data().drive
	var t: float = SimMathx.jclamp((alt / BH - float(d.lowBh)) / (float(d.highBh) - float(d.lowBh)), 0.0, 1.0)
	var a: float = (float(d.lowDeg) + (float(d.highDeg) - float(d.lowDeg)) * t) * PI / 180.0
	return [SimDetMath.cos(a), -SimDetMath.sin(a)]


## S.dirS.craterT holds the match time of each slot's last CRATER SLAM; it is sized here on first use.
static func _sizeCraterT(S: SimState) -> void:
	if S.dirS.craterT.size() < S.fighters.size():
		S.dirS.craterT.resize(S.fighters.size())


## Whether CRATER SLAM is offered: the rival is directly below the launcher, or the launcher is at the set piece's tier
## and has not thrown one in the last everySec seconds. (Break and finisher launches keep their authored vectors.)
static func craterOffered(S: SimState, A, D) -> bool:
	var cs: Dictionary = data().craterSlam
	if absf(SimWrap.sdx(A.x, D.x)) <= float(cs.below.sideBh) * BH and A.y - D.y >= float(cs.below.dropBh) * BH:
		return true
	_sizeCraterT(S)
	return A.tier >= float(cs.setPiece.minTier) and S.T - S.dirS.craterT[S.fighters.find(A)] >= float(cs.setPiece.everySec)


## force is the template's launch force; the prediction uses it with the tier scaling doLaunch applies.
## longOnly (break and finisher launches, spec-wounds.md §1): only the long-haul candidates (SMASH ACROSS, BUILDING SMASH,
## MOUNTAINSIDE), SMASH ACROSS always offered, and no "no launch".
static func chooseLaunch(S: SimState, A, D, force: float, longOnly: bool = false, sends: String = "", tilt: int = 0, noKnock: bool = false) -> Dictionary:
	var g: float = WorldTerrain.groundY(S, D.x)
	var alt: float = D.y - g
	var bio: String = WorldBiomes.biomeAt(D.x)
	var f: float = A.face
	var c: Array = []
	if not longOnly:
		var up: Dictionary = data().uppercut   # the slam lever: more forward carry, so the fall lands under 70 degrees
		c.append({"name": "UPPERCUT", "ux": float(up.ux) * f, "uy": float(up.uy), "s": 10.0 + (12.0 if alt < 120.0 else 0.0)})
	if not longOnly:
		var dv: Array = driveDir(alt)
		c.append({"name": "DRIVE DOWN", "ux": dv[0] * f, "uy": dv[1], "s": (18.0 if alt > 140.0 else 0.0) + A.tier * 4.0 + (8.0 if bio == "forest" else 0.0)})
		if craterOffered(S, A, D):
			var cs: Dictionary = data().craterSlam
			c.append({"name": "CRATER SLAM", "ux": float(cs.ux) * f, "uy": float(cs.uy), "s": float(cs.score.base) + float(cs.score.perTier) * A.tier + (float(cs.score.high) if alt > float(cs.score.highAlt) else 0.0)})
	c.append({"name": "SMASH ACROSS", "ux": f, "uy": ACROSS_UY, "fm": ACROSS_FORCE, "s": 8.0})
	var tierF: float = 1.0 + A.ld.launch * (A.tier - 1.0)   # D1b: ladder.json
	# BUILDING SMASH (B2, docs/world/b2-plan.md section 4): one candidate per building the launch can be aimed at, in any row,
	# scored by personality first and drama on top; a chain through several buildings is part of the candidate.
	var hadBrunt: bool = false
	# Contact (contact-spacing.md section 5.1): no launch goes back through the launcher. With a contact block only the
	# targets on the far side of the rival are offered.
	var fwdOnly: bool = not DirData.contact().is_empty()
	for bi in WorldBrunt.candidates(S, D):
		var plan = WorldBrunt.aim(S, A, D, S.buildings[bi], force, tierF, longOnly)
		if plan != null and fwdOnly and float(plan.ux) * f < 0.0:
			plan = null
		if plan != null:
			hadBrunt = true
			plan.s = bruntScore(S, A, plan)
			c.append(plan)
	for sign in [-1.0, 1.0]:
		if fwdOnly and sign * f < 0.0:
			continue
		# The nearest mountainside ahead, out to MOUNTAIN_REACH: near slopes give a short throw, far ones a long haul.
		var md: float = MOUNTAIN_STEP
		while md <= MOUNTAIN_REACH:
			if WorldBiomes.biomeAt(D.x + sign * md) == "mountains":
				c.append({"name": "MOUNTAINSIDE", "ux": sign, "uy": 0.05, "s": 24.0, "land": D.x + sign * md})
				break
			md += MOUNTAIN_STEP
	if not longOnly and not noKnock:
		c.append({"name": "KNOCK BACK", "ux": 0.0, "uy": 0.0, "s": float(data().knockBack.score)})   # "no launch": a scored outcome (it was NONE)
	if sends != "":
		# Combat's hook (alchemist-content.md): a piece that names where it sends the rival keeps only those candidates.
		var keep: Array = SENDS.get(sends, [])
		c = c.filter(func(k): return k.name == "KNOCK BACK" or keep.has(k.name))
	if tilt > 0:
		# The stick's tilt (1 up, then clockwise by eighths): only candidates within TILT_CONE of it compete. A tilt back
		# through the launcher is not a direction a launch can take (the turning throw is M0): it keeps its up or down part.
		var tx: float = [0.0, 0.7071, 1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071][tilt - 1]
		var ty: float = [1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071, 0.0, 0.7071][tilt - 1]
		if tx * f < 0.0:
			tx = 0.0
		if tx != 0.0 or ty != 0.0:
			var tl: float = SimDetMath.hypot(tx, ty)
			var near: Array = c.filter(func(k): return k.name == "KNOCK BACK" or (k.ux * tx + k.uy * ty) / (tl * SimMathx.jmax(SimDetMath.hypot(k.ux, k.uy), 0.000001)) >= TILT_CONE)
			if near.any(func(k): return k.name != "KNOCK BACK"):
				c = near
	for k in c:
		k.s += S.rng.range_(0.0, NOISE)
		if k.name == "KNOCK BACK":
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
	if plan.get("name", "") == "CRATER SLAM":
		_sizeCraterT(S)
		S.dirS.craterT[S.fighters.find(att)] = S.T
	SimFx.launch(S, tgt, att, SimDetMath.hypot(tgt.vx, tgt.vy), 1.0 if tgt.vx >= 0.0 else -1.0)
	WorldBrunt.arm(S, tgt, att, plan)   # B2: the aimed building, the depth waypoints and the chain's token
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 600.0, "#ffffff", 0.3, 20.0)
	SimFx.shake(S, 10.0, tgt.x)


const TILT_CONE: float = 0.7071     # the cosine of 45 degrees: how near the stick's tilt a launch candidate must point


## Which launch candidates a piece's "sends" tag keeps (Combat: across, up, down; turned waits for the turning throw).
const SENDS: Dictionary = {
	"across": ["SMASH ACROSS", "MOUNTAINSIDE", "BUILDING SMASH"],
	"up": ["UPPERCUT"],
	"down": ["DRIVE DOWN", "CRATER SLAM"],
}


## Whether att has earned a launch on tgt at this launch beat (agency-pass.md section 3; launch.json earned): Orb's four.
## Returns the reason, or "" when it has not.
static func earned(S: SimState, ex, att, tgt) -> String:
	var e: Dictionary = data().earned
	if ex.tag.begins_with("HEAVY CLASH"):
		return "a clash won"
	if ex.tag == "GUARD BREAK" or ex.tag == "RIPOSTE":
		return ""   # both end in a knock-back (Orb)
	var p: int = phrase(S, ex, att)
	if p < 0 or (p & 1) != SimAct.HEAVY:
		return ""
	if ((p >> 8) & 3) == DirAlchemy.HELD:
		return "a held heavy"
	var landed: int = DirInterrupt.gi(att, DirInterrupt.LANDED)
	if landed - 1 >= int(e.enderAfter):
		return "the ender of a full string (" + str(landed - 1) + " strikes landed before it)"
	if (p & DirAlchemy.INTENT) != 0 and DirInterrupt.gi(att, DirInterrupt.TAKEN) <= int(e.cleanTaken):
		return "a heavy with the stick, landing clean"
	return ""


## The press behind att's blow at this launch beat: the attacker's is the one that started his exchange or link; the
## defender's (a counter) is his newest press. Packed as the press log packs it; -1 when he pressed nothing.
static func phrase(S: SimState, ex, att) -> int:
	return DirInterrupt.gi(att, DirInterrupt.PHRASE_P) if att == ex.A else DirAlchemy.last(S, att)


## Whether the blow at this launch beat came from a heavy press (the knock-back) or a light one (the brawl goes on). A
## guard break and a launching riposte are heavy blows whatever was pressed.
static func heavyBlow(S: SimState, ex, att) -> bool:
	if ex.tag == "GUARD BREAK" or ex.tag == "RIPOSTE":
		return true
	var p: int = phrase(S, ex, att)
	return p >= 0 and (p & 1) == SimAct.HEAVY


## The knock-back (launch.json knockBack): a short send, not a launch across the map. On the ground it is a low,
## send with no travel boost that the ground-contact model skids about distBh body heights (dust, a scuff, a trench). In
## the air, over the sea, or with groundMode "shove", the rival is carried back that far, upright, over driftTicks.
static func knock(S: SimState, att, tgt) -> void:
	var kb: Dictionary = data().knockBack
	var ti: int = clampi(int(att.tier) - 1, 0, 3)
	var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(att.x, tgt.x)), att.face)
	var g: float = WorldTerrain.groundY(S, tgt.x)
	if String(kb.groundMode) == "skid" and tgt.y - g <= float(kb.groundWithinBh) * BH and not WorldTerrain.seaAt(S, tgt.x):
		var sp: float = float(kb.skidSpeed[ti])
		doLaunch(S, att, tgt, {"name": "KNOCK BACK", "ux": s, "uy": float(kb.skidUy)}, sp, false)
		tgt.launchT = 1.0          # no travel boost: a knock-back is a short slide, not a flight across the map
		tgt.vx = s * sp            # ... and its speed is the data's, whatever the tier scaling of a launch
		tgt.vy = float(kb.skidUy) * sp
		return
	var r := SimState.Rush.new()
	r.px = SimWrap.wrap(tgt.x + s * float(kb.distBh[ti]) * BH)
	r.py = SimMathx.jmax(tgt.y, WorldTerrain.groundY(S, r.px))
	r.end = S.T + float(kb.driftTicks) * SimConst.DT
	tgt.rush = r
	tgt.vx = 0.0
	tgt.vy = 0.0
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)


## No launch in the old profiles: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
