class_name SimFighter
## Fighter simulation: the twin of fighter.js (tierUp, impact, stepLaunched, stepRush, stepFighter).


static func tierUp(S: SimState, f) -> void:
	SimFx.banner(S, f.name + " POWERS UP  TIER " + SimMathx.jstr(f.tier), f.aura, 1.4)
	var g: float = WorldTerrain.groundY(S, f.x)
	SimFx.ring(S, f.x, f.y + 34.0, 1300.0, f.aura, 0.8, 20.0)
	SimFx.spark(S, f.x, f.y + 34.0, 20, f.aura, 700.0)
	S.fx.shake = SimMathx.jmax(S.fx.shake, 14.0)
	if f.y < g + 140.0:
		WorldTerrain.crater(S, f.x, 60.0 + f.tier * 28.0, 12.0 + f.tier * 7.0, f)
		WorldStructures.damageArea(S, f.x, f.y, 130.0 + f.tier * 60.0, 90.0 + f.tier * 100.0, f)
		SimFx.debris(S, f.x, g + 10.0, 10, "#6d6a66", 600.0)
		SimFx.dust(S, f.x, g, 5)
	SimEvents.feed(S, f.name + " reaches tier " + SimMathx.jstr(f.tier), "Ground-level power-up scarred the terrain." if f.y < g + 140.0 else "Airborne power-up, no ground damage.")


static func impact(S: SimState, f, g: float, sp: float) -> void:
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	var tier: float = by.tier
	if sp > 350.0:
		var r: float = 28.0 + sp * 0.05 + tier * 12.0
		var dep: float = SimMathx.jmin(90.0, sp * 0.02 + tier * 3.5)
		WorldTerrain.crater(S, f.x, r, dep, by)
		if WorldTerrain.seaAt(S, f.x):
			SimFx.splash(S, f.x, g + 10.0, 14)
		else:
			SimFx.debris(S, f.x, g + 8.0, 12, "#6d6a66", 500.0)
			SimFx.dust(S, f.x, g, 4)
		SimFx.ring(S, f.x, g + 10.0, 700.0 + sp * 0.2, "#ffffff", 0.45, 10.0)
		WorldStructures.damageArea(S, f.x, g + 5.0, r * 1.7, sp * (0.22 + 0.12 * tier), by)
		S.fx.shake = SimMathx.jmax(S.fx.shake, SimMathx.jmin(30.0, sp * 0.01))
		S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.06)
		SimDamage.hurt(S, f, sp * 0.018, by)
	f.y = WorldTerrain.groundY(S, f.x)
	if sp > 700.0 and f.bounces < 2.0:
		f.bounces += 1.0
		f.vy = absf(f.vy) * 0.3
		f.vx *= 0.75
	else:
		f.state = "down"
		f.stateT = 0.0
		f.vx = 0.0
		f.vy = 0.0
		f.bounces = 0.0
		f.launchBy = null


static func stepLaunched(S: SimState, f, dt: float) -> void:
	f.stateT += dt
	f.vy -= 1000.0 * dt
	f.vx *= SimDetMath.pow(0.55, dt)
	var ox: float = f.x
	f.x = SimWrap.wrap(f.x + f.vx * dt)
	f.y += f.vy * dt
	f.rot += f.spin * dt
	var inW: bool = f.y < 0.0 and WorldTerrain.seaAt(S, f.x)
	if inW and not f.wet:
		f.wet = true
		SimFx.splash(S, f.x, 0.0, 12)
		SimFx.ring(S, f.x, 0.0, 500.0, "#bfe6ff", 0.5, 10.0)
	if not inW and f.wet and f.y > 0.0:
		f.wet = false
	if inW:
		f.vx *= SimDetMath.pow(0.05, dt)
		f.vy *= SimDetMath.pow(0.1, dt)
		if SimDetMath.hypot(f.vx, f.vy) < 200.0 and f.stateT > 0.3:
			f.state = "free"
			f.rot = 0.0
			return
	for b in S.buildings:
		if not b.alive:
			continue
		if absf(SimWrap.sdx(f.x, b.x)) < b.w / 2.0 + 16.0:
			var gy: float = WorldTerrain.groundY(S, b.x)
			if f.y < gy + WorldStructures.curH(b) and f.y > gy - 10.0:
				var sp: float = SimDetMath.hypot(f.vx, f.vy)
				var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
				WorldStructures.damageBuilding(S, b, sp * (0.55 + 0.25 * by.tier), by)
				SimDamage.hurt(S, f, sp * 0.006, by)
				SimFx.debris(S, f.x, f.y + 20.0, 6, "#77808f", 500.0)
				f.vx *= 0.6
				f.vy *= 0.85
				if b.alive:
					f.vx = -SimMathx.jsign(SimDamage.jor(f.vx, 1.0)) * absf(f.vx) * 0.25
					f.x = SimWrap.wrap(b.x + SimMathx.jsign(SimDamage.jor(SimWrap.sdx(b.x, ox), 1.0)) * (b.w / 2.0 + 18.0))
	var g: float = WorldTerrain.groundY(S, f.x)
	if f.y <= g:
		impact(S, f, g, SimDetMath.hypot(f.vx, f.vy))
	if f.y > 2600.0:
		f.y = 2600.0
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
	var p := SimState.Part.new()
	p.type = "after"; p.x = f.x; p.y = f.y; p.life = 0.16; p.col = f.aura; p.face = f.face
	SimFx.P(S, p)
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
	var regen: float = 5.0 + (25.0 if f.hidden else 0.0)
	if f.role == "villain":
		regen += f.menace * 0.03
	else:
		regen = SimMathx.jmax(1.0, regen - f.anguish * 0.025)
	if f.role == "hero":
		f.anguish = SimMathx.jmax(0.0, f.anguish - 0.6 * dt)
	if f.state == "free" or f.state == "locked" or f.state == "down":
		f.ki = SimMathx.jmin(100.0, f.ki + regen * dt)
	if f.hidden:
		f.hp = SimMathx.jmin(f.maxhp, f.hp + 40.0 * dt)
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
			if f.stance == 2.0:
				sp *= 1.25
			if f.stance == 3.0:
				sp *= 1.35
			if f.stance == 1.0:
				sp *= 0.8
			if i.dash:
				sp *= 2.4
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
			if f.y > 2600.0:
				f.y = 2600.0
				f.vy = 0.0
	elif f.state == "charging":
		if not i.charge:
			f.state = "free"
		else:
			f.vx *= 0.85
			f.vy *= 0.85
			f.ki = SimMathx.jmin(100.0, f.ki + 30.0 * dt)
			f.power = SimMathx.jmin(100.0, f.power + 9.0 * dt)
			# Cosmetic draws (module-spec section 6): the spark chance and its four ranges, then the dust chance.
			var r: SimRng = S.rngFx
			if r.next() < 0.4:
				var p := SimState.Part.new()
				p.type = "spark"
				p.x = f.x + r.range_(-40.0, 40.0)
				p.y = f.y + r.range_(0.0, 70.0)
				p.vx = r.range_(-40.0, 40.0)
				p.vy = r.range_(200.0, 500.0)
				p.life = 0.4
				p.col = f.aura
				p.size = 2.0
				SimFx.P(S, p)
			if r.next() < 0.06 and f.y < WorldTerrain.groundY(S, f.x) + 30.0:
				SimFx.dust(S, f.x, WorldTerrain.groundY(S, f.x), 1)
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
