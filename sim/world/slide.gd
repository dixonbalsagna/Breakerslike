class_name WorldSlide
## The knockback slide (docs/world/knockback-slide.md): a launched fighter that meets the ground at a shallow or medium
## angle does not bounce and crater; he lands upright and brakes along the surface, carving a trench, cracking pavement
## and throwing dust. Only a near-vertical slam digs a single crater. This file is shared by the runtime (fighter.gd) and
## by Encounter's launch predictor (launch.gd predictFlight), so the plan and the outcome use the same rule.
##
## Traversal: a launch's horizontal speed is multiplied by launchTravel(), so fighters cross the big world. The slide's
## braking works on the unboosted ("normalised") speed, so a boosted launch slides TRAV times as far, in the same time.

const WS: float = SimConst.WS
# ---- classification ----
const SLAM_VERT: float = 0.94         # vertical share of the velocity at or above which a ground hit is a slam (about 70 degrees; balance-targets.md section 19, it was 0.85)
const HOP_SPEED: float = 2000.0       # a slam or a hard slide at this normalised speed may make one small hop ...
const HOP_LIFT: float = 0.25          # ... with the vertical speed scaled by this
const MIN_IMPACT: float = 350.0       # normalised speed at or below which a ground hit is neither slam nor slide
# ---- braking (normalised speed, fighter scale) ----
const MU: float = 1200.0              # constant friction, units per second squared
const KV: float = 1.2                 # speed term of the friction, per second
const GRAV: float = 1000.0            # the slope's gravity component: uphill costs this per unit of rise over run
const STOP: float = 60.0              # the slide ends below this normalised speed
const CLIFF: float = 1.0              # ground falling away steeper than this (drop over run) releases the fighter into the air
const WALL: float = 0.8               # ground rising steeper than this stops the slide with a small stop-impact
const RECOVER: float = 0.35           # seconds down after a slide (Orb 2026-09-29); a knock-down is 0.75
# ---- the trench (half the world scale: it is a fighter's feet and hands, not a crater) ----
const TRENCH_K: float = WS * 0.5
const HW0: float = 14.0 * TRENCH_K     # half width = HW0 + HW_E * sqrt(E)
const HW_E: float = 6.0 * TRENCH_K
const D0: float = 4.0 * TRENCH_K       # depth = D0 + D_V * normalised speed, capped at D_MAX
const D_V: float = 0.008 * TRENCH_K
const D_MAX: float = 38.0 * TRENCH_K   # half a fighter height, times the trench scale
const BERM: float = 0.3                # end berm height as a share of the trench depth
const CRACK0: float = 0.4              # pavement crack intensity = clamp(CRACK0 + CRACK_E * sqrt(E), 0, 1)
const CRACK_E: float = 0.1
# ---- damage ----
const TOUCH_DMG: float = 0.3           # share of the fighter's impact damage taken at touch-down; the rest by speed lost
const TOUCH_AREA: float = 0.5          # share of the impact's damageArea at touch-down
const PATH_AREA: float = 0.35          # per path sample: share of the impact's damageArea damage, times v_now / v_start
const SAMPLE: float = 40.0 * WS        # a path sample (damage, dust) every this many units
const SAMPLE_MAX: int = 60            # dust events per slide
const STOP_E: float = 0.15             # stop-impact dent energy as a share of E
const STOP_DMG: float = 0.006          # stop-impact damage per unit of normalised speed
const LIST_MAX: int = 200              # persistent slide records (S.slides)


## The horizontal launch factor: 1 for a vertical launch up to TRAV_LAUNCH for a fully horizontal one. So an uppercut or a
## slam stays vertical and a smash across the map is what crosses the map.
static func launchTravel(ux: float, uy: float) -> float:
	var ax: float = absf(ux)
	var s: float = ax / (ax + absf(uy) + 1e-9)
	return 1.0 + (SimConst.TRAV_LAUNCH - 1.0) * s


## The launch velocity for a plan direction and force: the horizontal part carries the traversal factor.
static func launchVX(ux: float, uy: float, force: float) -> float:
	return ux * force * launchTravel(ux, uy)


## True when a ground hit with this velocity is a slam (one crater) rather than a slide. vy is the vertical velocity.
static func isSlam(vx: float, vy: float) -> bool:
	var sp: float = SimDetMath.hypot(vx, vy)
	return sp > 0.0 and absf(vy) / sp >= SLAM_VERT


## How far a slide goes, in world units, from a normalised speed vN on ground with the given average uphill slope (rise
## over run along the direction of travel), for a fighter whose launch travel factor is travel. Closed form of the
## braking law without the terrain's detail (the predictor ignores the trench and cliffs).
static func slideDistance(vN: float, slope: float, travel: float) -> float:
	# dv/dt = -(a0 + KV v) with a0 = MU + GRAV * slope. Stopping distance of the linear-drag law:
	# v0 / KV - (a0 / KV^2) * ln(1 + KV * v0 / a0).
	var a0: float = MU + GRAV * slope
	if a0 <= 0.0:
		return 1e9
	var dist: float = vN / KV - (a0 / (KV * KV)) * SimDetMath.log(1.0 + KV * vN / a0)
	return maxf(0.0, dist) * travel


## The ground slope at x in the direction sign (+1 or -1): rise over run, from the columns either side.
static func slope(S: SimState, x: float, sign_: float) -> float:
	var e: float = SimConst.COL
	return (WorldTerrain.groundY(S, x + e) - WorldTerrain.groundY(S, x - e)) / (2.0 * e) * sign_


## Start a slide (called from impact()): the fighter lands upright and keeps his direction. spN is the normalised speed.
static func begin(S: SimState, f, by, spN: float, E: float) -> void:
	WorldBrunt.endFlight(S, f)
	f.slide = spN
	f.slideX0 = f.x
	f.slideD = 0.0
	f.state = "launched"
	f.vy = 0.0
	f.y = WorldTerrain.groundY(S, f.x)
	f.spin = 0.0
	f.rot = 0.0
	f.slideE = E
	f.slideDmg = spN * 0.018 * (1.0 - TOUCH_DMG)   # what is left to take by speed lost
	f.slideAcc = 0.0
	f.slideEvt = WorldCollateral.beginEvent(S, "slide", by)


static func _paved(x: float) -> bool:
	var b: String = WorldBiomes.biomeAt(x)
	return b == "city" or b == "village"


## One tick of a slide. Called from stepLaunched while f.slide > 0.
static func step(S: SimState, f, dt: float) -> void:
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	var tv: float = f.launchT
	var dir: float = 1.0 if f.vx >= 0.0 else -1.0
	var vN: float = absf(f.vx) / tv
	# The slope ahead, from the fighter's own height (the undug surface) to the ground one column on.
	var sl: float = (WorldTerrain.groundY(S, f.x + dir * SimConst.COL) - f.y) / SimConst.COL * dir * dir
	var a: float = MU + KV * vN + GRAV * sl
	var vN2: float = maxf(0.0, vN - a * dt)
	# Damage by speed lost, taken at each path sample and at the end (one wear hit each, not one per tick).
	if f.slide > 0.0 and vN > vN2:
		f.slideAcc += f.slideDmg * (vN - vN2) / f.slide
	var dx: float = dir * (vN + vN2) * 0.5 * tv * dt
	var x2: float = SimWrap.wrap(f.x + dx)
	var y2: float = WorldTerrain.groundY(S, x2)
	var run: float = maxf(absf(dx), 1e-6)
	var rise: float = (y2 - f.y) / run
	# Ground that rises like a wall stops the slide with a small stop-impact.
	if rise > WALL and vN2 > STOP:
		finish(S, f, by, true)
		return
	# Ground that falls away like a cliff releases the fighter into the air.
	if -rise > CLIFF:
		_record(S, f, by)
		f.slide = 0.0
		f.vx = dir * vN2 * tv
		f.vy = 0.0
		return
	var xa: float = f.x
	f.x = x2
	f.y = y2
	f.vx = dir * vN2 * tv
	f.vy = 0.0
	f.slideD += absf(dx)
	# The trench, the cracks, the dust and the path damage, at each sample of distance.
	var E: float = f.slideE
	var hw: float = HW0 + HW_E * sqrt(E)
	var depth: float = minf(D_MAX, D0 + D_V * vN)
	WorldCrater.carveSegment(S, xa, f.x, depth, _paved(f.x), CRACK0 + CRACK_E * sqrt(E))
	var idx: int = int(floor(f.slideD / SAMPLE))
	if idx > int(floor((f.slideD - absf(dx)) / SAMPLE)):
		var pav: bool = _paved(f.x)
		if idx <= SAMPLE_MAX:
			SimFx.slideDust(S, f.x, y2, vN, hw * 2.0, "paved" if pav else "ground", idx)
		SimFx.debris(S, f.x, y2 + 4.0, 3 if pav else 2, "#8f8b84" if pav else "#6d6a66", 500.0)
		WorldStructures.damageArea(S, f.x, y2 + 5.0, hw * 2.0, (0.22 + 0.12 * by.tier) * PATH_AREA * vN, by, false, f.slideEvt)
		if f.slideAcc > 0.0:
			SimDamage.hurt(S, f, f.slideAcc, by)
			f.slideAcc = 0.0
	if vN2 <= STOP:
		finish(S, f, by, false)


## End the slide: the berm, the record and the event; the fighter goes down for RECOVER seconds. A stop-impact (against a
## wall) also dents the ground and hurts a little.
static func finish(S: SimState, f, by, wall: bool) -> void:
	var E: float = f.slideE
	if wall:
		var vN: float = absf(f.vx) / f.launchT
		WorldCrater.dig(S, f.x, E * STOP_E, by, "impact", 0.0, 1.0)
		SimDamage.hurt(S, f, vN * STOP_DMG, by)
		SimFx.shake(S, 10.0, f.x)
	else:
		var hw: float = HW0 + HW_E * sqrt(E)
		var depth: float = minf(D_MAX, D0 + D_V * f.slide * 0.25)
		WorldCrater.berm(S, f.x, f.vx, hw, depth * BERM)
	if f.slideAcc > 0.0:
		SimDamage.hurt(S, f, f.slideAcc, by)
		f.slideAcc = 0.0
	_record(S, f, by)
	f.slide = 0.0
	f.vx = 0.0
	f.vy = 0.0
	f.state = "down"
	f.stateT = 0.75 - RECOVER
	f.bounces = 0.0
	f.launchBy = null
	f.launchT = 1.0
	f.launchSpecial = false
	f.hopped = false


## The persistent record and the event of a slide, at its end (or where a cliff released the fighter).
static func _record(S: SimState, f, by) -> void:
	var E: float = f.slideE
	var rec := SimState.Slide.new()
	rec.x0 = f.slideX0
	rec.x1 = f.x
	rec.hw = HW0 + HW_E * sqrt(E)
	rec.depth = minf(D_MAX, D0 + D_V * f.slide)
	rec.energy = E
	rec.t = S.T
	rec.owner = WorldCrater._slot(S, by)
	rec.surface = 1.0 if _paved(f.slideX0) else 0.0
	var er: Dictionary = WorldCollateral.endEvent(S, f.slideEvt)
	rec.pop = er.dead
	f.slideEvt = 0.0
	S.slides.append(rec)
	S.world.slides += 1.0
	if S.slides.size() > LIST_MAX:
		S.slides.remove_at(0)
	SimFx.slideEvent(S, rec)
