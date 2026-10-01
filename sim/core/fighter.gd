class_name SimFighter
## Fighter simulation: the twin of fighter.js (tierUp, impact, stepLaunched, stepRush, stepFighter).

## D1b: the meters' numbers (regen, decay) are f.md and the power ladder's are f.ld (data/fighters/<id>/meters.json and
## ladder.json).
## Water holds a launched fighter up (S3a gap fix): under water the launch's gravity is cancelled (neutral buoyancy), so
## the drag brings it below the free speed within about a second instead of holding it at a 430 u/s sink to the seabed.
const WATER_BUOY: float = 1000.0


static func tierUp(S: SimState, f) -> void:
	S.world.maxTier = maxf(S.world.maxTier, f.tier)
	SimMood.onForm(S)   # Q10: a form step may raise the act
	SimFx.banner(S, f.name + " POWERS UP  TIER " + SimMathx.jstr(f.tier), f.aura, 1.4)
	var g: float = WorldTerrain.groundY(S, f.x)
	SimFx.ring(S, f.x, f.y + 34.0, 1300.0, f.aura, 0.8, 20.0)
	SimFx.spark(S, f.x, f.y + 34.0, 20, f.aura, 700.0)
	SimFx.shake(S, 14.0, f.x)
	if f.y < g + 140.0:
		WorldCrater.dig(S, f.x, WorldCrater.powerupEnergy(f.tier), f, "powerup")
		WorldStructures.damageArea(S, f.x, f.y, (f.ld.areaR + f.tier * f.ld.areaRPerTier) * SimConst.WS, f.ld.areaDmg + f.tier * f.ld.areaDmgPerTier, f)
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
	WorldBrunt.endFlight(S, f)


## Launched flight: gravity, air drag, water (with the skip), the aimed building (B2), the ground (slam or slide) and the
## ceiling. A fighter that is sliding is handled by WorldSlide.step.
static func stepLaunched(S: SimState, f, dt: float) -> void:
	f.stateT += dt
	WorldBrunt.stepZ(S, f, dt)
	if f.slide > 0.0:
		WorldSlide.step(S, f, dt)
		return
	f.vy -= 1000.0 * dt
	f.vx *= SimDetMath.pow(0.55, dt)
	var ox: float = f.x
	var oy: float = f.y
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
			WorldBrunt.endFlight(S, f)
			return
	var hitNow: bool = WorldBrunt.checkHit(S, f, ox, oy)   # B2: only the building the launch is aimed at can be hit
	var g: float = WorldTerrain.groundY(S, f.x)
	if f.y <= g and not (hitNow and f.aimB >= 0):   # a chain link gets its next tick first (chainPlan's order)
		impact(S, f, g, SimDetMath.hypot(f.vx, f.vy))
	if f.y > SimConst.CEILING:
		f.y = SimConst.CEILING
		f.vy = SimMathx.jmin(f.vy, 0.0)


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


## The tier a fighter's power has earned: 1, plus one per threshold reached.
static func tierByPower(f) -> float:
	var nt: float = 1.0
	for th in f.ld.thresholds:
		if f.power >= th:
			nt += 1.0
	return nt


## I2a: take a ready form (ladder.json manualTierUp): the tier rises one step with today's power-up. The director's
## placeholder transform calls it between exchanges (I2b). Returns false if nothing was ready.
static func transform(S: SimState, f) -> bool:
	if not f.act.formReady:
		return false
	f.tier += 1.0
	tierUp(S, f)
	f.act.formReady = tierByPower(f) > f.tier
	return true


static func stepFighter(S: SimState, f, dt: float) -> void:
	var o = SimRoster.opp(S, f)
	if f.state != "launched":
		f.flightHits = 0
	var i: SimIntent = f.input
	f.power = SimMathx.jmin(100.0, f.power + f.ld.fill * dt)
	var nt: float = tierByPower(f)
	if nt > f.tier:
		if f.ld.manualTierUp:
			if not f.act.formReady: SimFx.transformReady(S, f, f.tier + 1.0, DirExchange.transformSource(f))   # I2b: the rising edge
			f.act.formReady = true   # I2a: the tier waits for the transform (transform())
		else:
			f.tier = nt
			tierUp(S, f)
	var regen: float = 5.0 + (25.0 if f.hidden and f.canHide else 0.0)
	if f.hasMenace:
		var bonus: float = f.menace * f.md.menaceRegen
		if f.md.menaceRegenCap >= 0.0:
			bonus = SimMathx.jmin(f.md.menaceRegenCap, bonus)
		regen += bonus
	else:
		var pen: float = f.anguish * f.md.anguishRegen
		if f.md.anguishRegenCap >= 0.0:
			pen = SimMathx.jmin(f.md.anguishRegenCap, pen)
		regen = SimMathx.jmax(1.0, regen - pen)
	if f.hasAnguish:
		f.anguish = SimMathx.jmax(0.0, f.anguish - f.md.anguishDecay * dt)
	# Menace decays when it is not fed (balance-targets.md section 9, S0): after f.md.menaceDelay ticks without a rise it
	# falls by f.md.menaceDecay per second. At the cap a casualty cannot raise it, so there a rise in world casualties also
	# counts as fed. (sim/world stays untouched: menace only ever rises through a casualty.)
	var fed: bool = f.menace > f.menaceSeen or (f.menace >= 100.0 and S.world.casualties > f.casSeen)
	f.menaceQuiet = 0 if fed else f.menaceQuiet + 1
	if f.menaceQuiet > f.md.menaceDelay:
		f.menace = SimMathx.jmax(0.0, f.menace - f.md.menaceDecay * dt)
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
			var sp: float = 430.0 * f.spd * (1.0 + f.ld.speed * (f.tier - 1.0))
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
			f.power = SimMathx.jmin(100.0, f.power + f.ld.charge * dt)   # Q10: ladder.json chargePerSec
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
