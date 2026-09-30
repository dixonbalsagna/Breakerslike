class_name SimFighter
## Fighter simulation: the twin of fighter.js (tierUp, impact, stepLaunched, stepRush, stepFighter).

## Placeholder balance (balance-targets.md section 9, slice S0): menace decays at MENACE_DECAY per second once it has
## gone MENACE_QUIET_TICKS (4 s) without being fed.
const MENACE_DECAY: float = 0.4
const MENACE_QUIET_TICKS: int = 240
## Water holds a launched fighter up (S3a gap fix): under water the launch's gravity is cancelled (neutral buoyancy), so
## the drag brings it below the free speed within about a second instead of holding it at a 430 u/s sink to the seabed.
const WATER_BUOY: float = 1000.0


static func tierUp(S: SimState, f) -> void:
	S.world.maxTier = maxf(S.world.maxTier, f.tier)
	SimFx.banner(S, f.name + " POWERS UP  TIER " + SimMathx.jstr(f.tier), f.aura, 1.4)
	var g: float = WorldTerrain.groundY(S, f.x)
	SimFx.ring(S, f.x, f.y + 34.0, 1300.0, f.aura, 0.8, 20.0)
	SimFx.spark(S, f.x, f.y + 34.0, 20, f.aura, 700.0)
	SimFx.shake(S, 14.0, f.x)
	if f.y < g + 140.0:
		WorldCrater.dig(S, f.x, WorldCrater.powerupEnergy(f.tier), f, "powerup")
		WorldStructures.damageArea(S, f.x, f.y, (130.0 + f.tier * 60.0) * SimConst.WS, 90.0 + f.tier * 100.0, f)
		SimFx.debris(S, f.x, g + 10.0, 10, "#6d6a66", 600.0)
		SimFx.dust(S, f.x, g, 5)
	SimFx.tierUp(S, f, f.y < g + 140.0)
	SimEvents.feed(S, f.name + " reaches tier " + SimMathx.jstr(f.tier), "Ground-level power-up scarred the terrain." if f.y < g + 140.0 else "Airborne power-up, no ground damage.")


## A launched fighter meets the ground. sp is the actual speed; the damage and the energy use the unboosted speed (the
## horizontal traversal factor of the launch is divided out). A near-vertical slam digs one crater and stays down; anything
## shallower is a knockback slide (world/slide.gd), with at most one small hop first at very high energy. Nothing bounces
## more than once on ground, so a launch leaves at most one crater.
static func impact(S: SimState, f, g: float, sp: float) -> void:
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	var tier: float = by.tier
	var WS: float = SimConst.WS
	var spN: float = SimDetMath.hypot(f.vx / f.launchT, f.vy)
	var vert: float = absf(f.vy) / SimMathx.jmax(sp, 0.000001)
	var sea: bool = WorldTerrain.seaAt(S, f.x)
	f.y = g
	if spN > WorldSlide.MIN_IMPACT:
		var r: float = (28.0 + spN * 0.05 + tier * 12.0) * WS
		var E: float = WorldCrater.impactEnergy(spN, tier)
		var slam: bool = sea or vert >= WorldSlide.SLAM_VERT
		# A very hard slam makes its mark on the first contact and then hops once; the hop's landing digs nothing more (the
		# hard hit makes the crater, never the lighter one after it). A slide never hops: it starts at the first contact.
		var hop: bool = slam and not sea and spN >= WorldSlide.HOP_SPEED and not f.hopped
		if slam and not f.hopped:
			WorldCrater.dig(S, f.x, E, by, "impact", f.vx / f.launchT / SimMathx.jmax(spN, 0.000001), vert, f.launchSpecial)
		if sea:
			SimFx.splash(S, f.x, g + 10.0, 14)
		else:
			SimFx.debris(S, f.x, g + 8.0, 12, "#6d6a66", 500.0)
			SimFx.dust(S, f.x, g, 4)
		SimFx.ring(S, f.x, g + 10.0, 700.0 + spN * 0.2, "#ffffff", 0.45, 10.0)
		var slideStart: bool = not slam
		var touch: float = WorldSlide.TOUCH_AREA if slideStart else 1.0
		WorldStructures.damageArea(S, f.x, g + 5.0, r * 1.7, spN * (0.22 + 0.12 * tier) * touch, by)
		SimFx.shake(S, SimMathx.jmin(30.0, spN * 0.01), f.x)
		S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.06)
		SimDamage.hurt(S, f, spN * 0.018 * (WorldSlide.TOUCH_DMG if slideStart else 1.0), by)
		if hop:
			f.hopped = true
			f.vy = absf(f.vy) * WorldSlide.HOP_LIFT
			return
		if slideStart:
			WorldSlide.begin(S, f, by, spN, E)
			return
	f.state = "down"
	f.stateT = 0.0
	f.vx = 0.0
	f.vy = 0.0
	f.bounces = 0.0
	f.launchBy = null
	f.launchT = 1.0
	f.launchSpecial = false
	f.hopped = false


## Launched flight: gravity, air drag, water (with the skip), building collisions, the ground (slam or slide) and the
## ceiling. A fighter that is sliding is handled by WorldSlide.step.
static func stepLaunched(S: SimState, f, dt: float) -> void:
	f.stateT += dt
	if f.slide > 0.0:
		var ox0: float = f.x
		WorldSlide.step(S, f, dt)
		if f.slide > 0.0 and _buildingHits(S, f, ox0):
			var by0 = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
			WorldSlide.finish(S, f, by0, true)
		return
	f.vy -= 1000.0 * dt
	f.vx *= SimDetMath.pow(0.55, dt)
	var ox: float = f.x
	f.x = SimWrap.wrap(f.x + f.vx * dt)
	f.y += f.vy * dt
	f.rot += f.spin * dt
	var wsurf: float = WorldWater.surfaceAt(S, f.x)
	var inW: bool = f.y < wsurf
	if inW and not f.wet:
		f.wet = true
		SimFx.splash(S, f.x, wsurf, 12)
		SimFx.ring(S, f.x, wsurf, 500.0, "#bfe6ff", 0.5, 10.0)
		var wsp: float = SimDetMath.hypot(f.vx, f.vy)
		# A fast, shallow entry skips off the surface like a stone; a steep or slow one goes in and is slowed as before.
		if f.vy < 0.0 and wsp > WorldWater.SKIM_MIN_SPEED and -f.vy < absf(f.vx) * WorldWater.SKIM_MAX_TAN and f.bounces < WorldWater.SKIM_MAX:
			f.bounces += 1.0
			f.y = wsurf
			f.vy = -f.vy * WorldWater.SKIM_LIFT
			f.vx *= WorldWater.SKIM_KEEP
			f.wet = false
			inW = false
			SimFx.splash(S, f.x, wsurf, 8)
			SimFx.skim(S, f.x, wsurf, wsp, int(f.bounces))
	if not inW and f.wet and f.y > wsurf:
		f.wet = false
	if inW:
		f.vy += WATER_BUOY * dt
		f.vx *= SimDetMath.pow(0.05, dt)
		f.vy *= SimDetMath.pow(0.1, dt)
		if SimDetMath.hypot(f.vx, f.vy) < 200.0 and f.stateT > 0.3:
			f.state = "free"
			f.rot = 0.0
			f.launchT = 1.0
			return
	_buildingHits(S, f, ox)
	var g: float = WorldTerrain.groundY(S, f.x)
	if f.y <= g:
		impact(S, f, g, SimDetMath.hypot(f.vx, f.vy))
	if f.y > SimConst.CEILING:
		f.y = SimConst.CEILING
		f.vy = SimMathx.jmin(f.vy, 0.0)


## The incidental building collision (until the director-chosen brunt replaces it, buildings-in-depth.md section 3): a
## launched or sliding fighter whose x is inside a standing building's footprint, below its top, hits it. Returns true if
## it hit one.
static func _buildingHits(S: SimState, f, ox: float) -> bool:
	var hit: bool = false
	for bi in WorldStructures.near(S, f.x, 64.0):
		var b = S.buildings[bi]
		if not b.alive or b.row != WorldStructures.PLANE_ROW:
			continue
		if absf(SimWrap.sdx(f.x, b.x)) < b.w / 2.0 + 16.0:
			var gy: float = WorldTerrain.groundY(S, b.x)
			if f.y < gy + WorldStructures.curH(b) and f.y > gy - 10.0:
				var sp: float = SimDetMath.hypot(f.vx / f.launchT, f.vy)
				var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
				WorldStructures.damageBuilding(S, b, sp * (0.55 + 0.25 * by.tier), by)
				SimDamage.hurt(S, f, sp * 0.006, by)
				SimFx.debris(S, f.x, f.y + 20.0, 6, "#77808f", 500.0)
				f.vx *= 0.6
				f.vy *= 0.85
				if b.alive:
					f.vx = -SimMathx.jsign(SimDamage.jor(f.vx, 1.0)) * absf(f.vx) * 0.25
					f.x = SimWrap.wrap(b.x + SimMathx.jsign(SimDamage.jor(SimWrap.sdx(b.x, ox), 1.0)) * (b.w / 2.0 + 18.0))
				hit = true
	return hit


static func stepRush(S: SimState, f, dt: float) -> void:
	var r = f.rush
	if r == null:
		return
	var tx: float = r.tgt.x + r.off if r.tgt != null else r.px
	var ty: float = r.tgt.y if r.tgt != null else r.py
	var rem: float = r.end - S.T
	if rem <= dt:
		f.x = SimWrap.wrap(tx)
		f.y = SimMathx.jmax(ty, WorldTerrain.groundY(S, tx))
		f.rush = null
		f.vx = 0.0
		f.vy = 0.0
		return
	var k: float = dt / rem
	SimFx.afterimage(S, f, 0.16)
	f.x = SimWrap.wrap(f.x + SimWrap.sdx(f.x, tx) * k)
	f.y += (ty - f.y) * k


static func stepFighter(S: SimState, f, dt: float) -> void:
	var o = SimRoster.opp(S, f)
	var i: SimIntent = f.input
	f.power = SimMathx.jmin(100.0, f.power + 0.45 * dt)
	var nt: float = 1.0 + (1.0 if f.power >= 25.0 else 0.0) + (1.0 if f.power >= 50.0 else 0.0) + (1.0 if f.power >= 75.0 else 0.0)
	if nt > f.tier:
		f.tier = nt
		tierUp(S, f)
	var regen: float = 5.0 + (25.0 if f.hidden and f.canHide else 0.0)
	if f.hasMenace:
		regen += f.menace * 0.03
	else:
		regen = SimMathx.jmax(1.0, regen - f.anguish * 0.025)
	if f.hasAnguish:
		f.anguish = SimMathx.jmax(0.0, f.anguish - 0.6 * dt)
	# Menace decays when it is not fed (balance-targets.md section 9, S0): after MENACE_QUIET_TICKS without a rise it
	# falls by MENACE_DECAY per second. At the cap a casualty cannot raise it, so there a rise in world casualties also
	# counts as fed. (sim/world stays untouched: menace only ever rises through a casualty.)
	var fed: bool = f.menace > f.menaceSeen or (f.menace >= 100.0 and S.world.casualties > f.casSeen)
	f.menaceQuiet = 0 if fed else f.menaceQuiet + 1
	if f.menaceQuiet > MENACE_QUIET_TICKS:
		f.menace = SimMathx.jmax(0.0, f.menace - MENACE_DECAY * dt)
	f.menaceSeen = f.menace
	f.casSeen = S.world.casualties
	if SimWounds.battered(f, SimWounds.CORE):
		regen *= f.wd.coreKiRegen
	if f.state == "free" or f.state == "locked" or f.state == "down":
		f.ki = SimMathx.jmin(100.0, f.ki + regen * dt)
	if f.hidden and f.canHide:
		f.hp = SimMathx.jmin(f.maxhp, f.hp + 40.0 * dt)
	SimWounds.step(S, f)   # wound recovery (wounds.gd)
	if f.state != "launched":
		f.rot *= SimDetMath.pow(0.001, dt)

	if f.rush != null:
		stepRush(S, f, dt)
	elif f.state == "free":
		var dxo: float = SimWrap.sdx(f.x, o.x)
		if absf(dxo) > 20.0:
			f.face = 1.0 if dxo > 0.0 else -1.0
		if i.charge:
			f.state = "charging"
			f.hidden = false
		else:
			var sp: float = 430.0 * f.spd * (1.0 + 0.10 * (f.tier - 1.0))
			if SimWounds.battered(f, SimWounds.LEGS):
				sp *= f.wd.legsSpeed
			if f.stance == 2.0:
				sp *= 1.25
			if f.stance == 3.0:
				sp *= 1.35
			if f.stance == 1.0:
				sp *= 0.8
			if i.dash:
				sp *= 2.4
				# Traversal: flat out and far from the opponent, the dash is TRAV_FREE times faster (a lap of the planet in about
				# 15 s); close in, it is the melee dash it always was.
				var sep: float = absf(SimWrap.sdx(f.x, o.x))
				sp *= 1.0 + (SimConst.TRAV_FREE - 1.0) * SimMathx.jclamp((sep - SimConst.BOOST_NEAR) / (SimConst.BOOST_FAR - SimConst.BOOST_NEAR), 0.0, 1.0)
			if f.y < 0.0 and WorldTerrain.seaAt(S, f.x):
				sp *= 0.55
			var k: float = 1.0 - SimDetMath.pow(0.0008, dt)
			f.vx += (i.mx * sp - f.vx) * k
			f.vy += (i.my * sp * 0.85 - f.vy) * k
			f.x = SimWrap.wrap(f.x + f.vx * dt)
			f.y += f.vy * dt
			var g: float = WorldTerrain.groundY(S, f.x)
			if f.y < g:
				f.y = g
				if f.vy < 0.0:
					f.vy = 0.0
			if f.y > SimConst.CEILING:
				f.y = SimConst.CEILING
				f.vy = 0.0
	elif f.state == "charging":
		if not i.charge:
			f.state = "free"
		else:
			f.vx *= 0.85
			f.vy *= 0.85
			f.ki = SimMathx.jmin(100.0, f.ki + 30.0 * dt)
			f.power = SimMathx.jmin(100.0, f.power + 9.0 * dt)
			SimFx.chargeFx(S, f, WorldTerrain.groundY(S, f.x))   # the aura's sparks and dust are cosmetic: the consumer rolls them
	elif f.state == "down":
		f.stateT += dt
		f.y = WorldTerrain.groundY(S, f.x)
		if f.stateT > 0.75:
			f.state = "free"
			f.rot = 0.0
	elif f.state == "launched":
		stepLaunched(S, f, dt)
	elif f.state == "locked":
		f.vx *= SimDetMath.pow(0.03, dt)
		f.vy *= SimDetMath.pow(0.03, dt)
		f.x = SimWrap.wrap(f.x + f.vx * dt)
		f.y = SimMathx.jmax(WorldTerrain.groundY(S, f.x), f.y + f.vy * dt)
	if S.game.ko == null:
		SimHiding.updateHidden(S, f, dt)
