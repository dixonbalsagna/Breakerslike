class_name DirBeam
## Signature beams: the twin of beam.js (planBeam and its beat ops, startClash, fireBeam, sampleBeam, beamStep).

const VARIANT: Dictionary = {"ocean": "HORIZON CLEAVE", "city": "BOULEVARD RAZE", "village": "BOULEVARD RAZE", "forest": "FIRESTORM", "mountains": "RIDGE BORE", "desert": "GLASS TRENCH", "plains": "MERIDIAN SCAR"}


## Plans a signature from Combat's data (DirData).
static func planBeam(S: SimState, ex) -> void:
	DirData.planBeam(S, ex)


## Beat "beamCharge": the attacker rises above the defender and charges.
static func opBeamCharge(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	A.beamCharge = S.T
	SimFx.banner(S, A.sigName.to_upper(), A.aura, 1.1)
	var r := SimState.Rush.new()
	r.px = A.x
	r.py = SimMathx.jmin(SimConst.CEILING - 200.0, D.y + args.rise)
	r.end = S.T + 0.55
	A.rush = r
	SimFx.ring(S, A.x, A.y + 40.0, 260.0, A.aura, 0.8, 10.0)


## Beat "beamFire": fire, or start a beam clash; the outcome was decided when the beam was planned.
static func opBeamFire(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	var out: String = args.out
	var variant: String = args.variant
	var dist: float = args.dist
	A.beamCharge = null
	if S.game.ko != null:
		return
	var len: float = SimMathx.jmin(4200.0 * SimConst.WS, dist + (2000.0 + A.tier * 400.0) * SimConst.WS)
	var ox: float = A.x
	var oy: float = A.y + 38.0
	var aimY: float = D.y + 36.0
	if out == "CLASH":
		D.ki -= 40.0
		startClash(S, ex, variant)
		return
	var dxs: float = SimWrap.sdx(ox, D.x)
	var dyy: float = aimY - oy
	var L: float = SimDamage.jor(SimDetMath.hypot(dxs, dyy), 1.0)
	var ux: float = dxs / L
	var uy: float = dyy / L
	fireBeam(S, A, ox, oy, ux, uy, len, variant)
	var reach: float = SimMathx.jmin(0.2, dist / len * 0.22)
	if out == "HIT" or out == "GUARD":
		DirExchange.schedule(ex, ex.t + reach, "beamImpact", {"out": out, "ux": ux, "uy": uy})
	elif out == "DODGE":
		DirExchange.schedule(ex, ex.t + 0.02, "beamDodge")
	else:
		DirExchange.schedule(ex, ex.t + 0.02, "beamEscape")
	DirExchange.schedule(ex, ex.t + 0.9, "nop")


## Beat "beamImpact": the beam connects (HIT) or is blocked (GUARD).
static func opBeamImpact(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	var out: String = args.out
	if S.game.ko != null:
		return
	if D.state == "locked":
		D.state = "free"
	SimDamage.hit(S, ex, A, D, 200.0 if out == "GUARD" else 230.0, {"ignoreStance": out != "GUARD", "stop": 0.14, "shake": 16.0, "big": true})
	WorldStructures.explode(S, D.x, D.y + 30.0, 60.0 + A.tier * 30.0, A)
	if S.game.ko == null:
		D.state = "locked"
		DirLaunch.doLaunch(S, A, D, {"ux": args.ux, "uy": args.uy * 0.6 + 0.12}, 1300.0 if out == "GUARD" else 2600.0)
		DirExchange.decisive(S, ex, A, D, "beam")


## Beat "beamDodge".
static func opBeamDodge(S: SimState, ex, _args) -> void:
	var D = ex.D
	SimFx.afterimage(S, D)
	D.y += 300.0
	D.vx = 0.0
	D.vy = 0.0
	SimFx.banner(S, "DODGED", "#9fe0ff", 0.7)


## Beat "beamEscape".
static func opBeamEscape(S: SimState, ex, _args) -> void:
	var A = ex.A
	var D = ex.D
	SimFx.afterimage(S, D)
	D.state = "free"
	D.vx = SimMathx.jsign(SimWrap.sdx(A.x, D.x)) * 1600.0
	D.vy = S.rng.range_(-100.0, 300.0)
	SimFx.banner(S, "ESCAPED", "#9fe0b0", 0.7)


## beam.js startClash sc(f): one draw per call, attacker first.
static func _clashScore(S: SimState, f) -> float:
	return f.tier * 10.0 + f.ki * 0.35 + S.rng.range_(0.0, 16.0) + (f.menace * 0.08 if f.role == "villain" else 0.0)


static func startClash(S: SimState, ex, variant: String) -> void:
	var A = ex.A
	var D = ex.D
	var aw: bool = _clashScore(S, A) > _clashScore(S, D)
	var c := SimState.Clash.new()
	c.A = A
	c.D = D
	c.t0 = S.T
	c.dur = 1.6
	c.aw = aw
	S.game.clash = c
	SimFx.banner(S, "BEAM CLASH", "#ffffff", 1.2)
	DirExchange.schedule(ex, ex.t + 1.6, "clashResolve", {"aw": aw, "variant": variant})
	DirExchange.schedule(ex, ex.t + 2.6, "nop")


## Beat "clashResolve": the clash winner's beam overpowers the loser.
static func opClashResolve(S: SimState, ex, args) -> void:
	var A = ex.A
	var D = ex.D
	var variant: String = args.variant
	var Wn = A if args.aw else D
	var Ls = D if args.aw else A
	S.game.clash = null
	if S.game.ko != null:
		return
	var dxs: float = SimWrap.sdx(Wn.x, Ls.x)
	var dyy: float = (Ls.y + 36.0) - (Wn.y + 38.0)
	var L: float = SimDamage.jor(SimDetMath.hypot(dxs, dyy), 1.0)
	var ux: float = dxs / L
	var uy: float = dyy / L
	var len: float = SimMathx.jmin(4200.0 * SimConst.WS, L + (2000.0 + Wn.tier * 400.0) * SimConst.WS)
	fireBeam(S, Wn, Wn.x, Wn.y + 38.0, ux, uy, len, variant)
	Ls.state = "locked"
	SimDamage.hit(S, ex, Wn, Ls, 260.0, {"ignoreStance": true, "stop": 0.16, "shake": 18.0, "big": true})
	WorldStructures.explode(S, Ls.x, Ls.y + 30.0, (70.0 + Wn.tier * 32.0) * SimConst.WS, Wn)
	if S.game.ko == null:
		DirLaunch.doLaunch(S, Wn, Ls, {"ux": ux, "uy": uy * 0.6 + 0.12}, 2600.0)
		DirExchange.decisive(S, ex, Wn, Ls, "beam_clash")


static func fireBeam(S: SimState, A, ox: float, oy: float, ux: float, uy: float, len: float, variant: String) -> void:
	var b := SimState.Beam.new()
	b.A = A; b.ox = ox; b.oy = oy; b.ux = ux; b.uy = uy; b.len = len
	b.p = 0.0; b.t = 0.0; b.life = 0.95; b.w = 24.0 + A.tier * 9.0; b.variant = variant; b.col = A.aura
	b.pw = WorldCrater.beamPower(A)
	S.beams.append(b)
	SimFx.shake(S, 14.0, ox)


static func sampleBeam(S: SimState, b, s: float) -> void:
	var A = b.A
	var P: float = b.pw   # the beam-power scalar (world/crater.gd): tier and charge; it equals the tier mid-band
	var x: float = SimWrap.wrap(b.ox + b.ux * s)
	var y: float = b.oy + b.uy * s
	var g: float = WorldTerrain.groundY(S, x)
	if y < g + WorldCrater.beamReach(P):
		# Scorch: a groove carved to a target depth along the ground, not a crater per sample (sim quirk 7 is gone).
		WorldCrater.scorch(S, x, P, b.variant, A)
		if not b.struck and b.uy <= -WorldCrater.BEAM_STRIKE_SLOPE:
			b.struck = true   # a steep beam digs one strike crater where it first meets the ground
			WorldCrater.dig(S, x, WorldCrater.beamStrikeEnergy(P), A, "beam")
		SimFx.dust(S, x, g + 8.0, 1, "#e6c47a" if b.variant == "GLASS TRENCH" else "#9b8f7e")
		if b.variant == "GLASS TRENCH":
			SimFx.spark(S, x, g + 6.0, 2, "#ffd98a", 300.0)
	WorldStructures.damageArea(S, x, y, (26.0 + P * 8.0) * SimConst.WS, 110.0 + P * 75.0, A)
	if y < 30.0 and WorldTerrain.seaAt(S, x):
		SimFx.beamSplash(S, x)   # the consumer rolls the prototype's 60% splash
	if b.variant == "FIRESTORM" and y < g + 140.0 * SimConst.WS:
		SimFx.fire(S, x, g, 1)


static func beamStep(S: SimState, dt: float) -> void:
	for i in range(S.beams.size() - 1, -1, -1):
		var b = S.beams[i]
		b.t += dt
		var np: float = SimMathx.jmin(1.0, b.t / 0.22)
		var s0: float = b.p * b.len
		var s1: float = np * b.len
		b.p = np
		var s: float = s0
		while s < s1:
			sampleBeam(S, b, s)
			s += 36.0 * SimConst.WS
		if b.t > b.life:
			S.beams.remove_at(i)
