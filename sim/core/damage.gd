class_name SimDamage
## Damage model: the twin of damage.js (hurt, hit, ko). Hit options o are a Dictionary like the JS object literal
## (ignoreStance, big, stop, shake, kb, noParry); a missing key reads as JS undefined.

const STANCE_MUL: Array = [1.12, 0.38, 1.0, 1.25]


## JS `v || d` for a number: d when v is 0, -0 or NaN.
static func jor(v: float, d: float) -> float:
	return v if (v != 0.0 and v == v) else d


static func hurt(S: SimState, f, amt: float, by) -> void:
	f.hp -= amt
	f.hurtT = S.T
	if f.hp <= 0.0 and S.game.ko == null:
		ko(S, f, by if by != null else SimRoster.opp(S, f))


static func hit(S: SimState, ex, A, D, dmg: float, o = null) -> float:
	if o == null:
		o = {}
	var m: float = A.dmgMul * (1.0 + 0.09 * (A.tier - 1.0))
	if A.role == "villain":
		m *= 1.0 + 0.25 * (A.menace / 100.0)
	else:
		m *= 1.0 + 0.5 * SimDetMath.pow(1.0 - A.hp / A.maxhp, 2.0)
	m *= 1.0 + 0.12 * ((ex.combo if ex != null else 1.0) - 1.0)
	if A.ambush:
		m *= 1.5
	var sm: float = 1.0
	if not o.get("ignoreStance", false):
		sm = STANCE_MUL[int(D.stance)]
		if D.state == "charging":
			sm = 1.35
	var dd: float = dmg * m * sm
	if D.state == "charging":
		D.state = "free"
	if D.stance == 1.0 and not o.get("ignoreStance", false):
		D.ki = SimMathx.jmax(0.0, D.ki - dd * 0.08)
	A.ki = SimMathx.jmin(100.0, A.ki + dd * 0.04)
	D.power = SimMathx.jmin(100.0, D.power + dd * 0.010)
	A.power = SimMathx.jmin(100.0, A.power + dd * 0.006)
	SimFx.spark(S, D.x, D.y + 34.0, 18 if o.get("big", false) else 9, "#fff3c0", 600.0)
	var fl := SimState.DmgFloat.new()
	fl.x = D.x
	fl.y = D.y + 90.0
	fl.txt = SimMathx.jstr(SimMathx.jround(dd))
	fl.t = 0.0
	fl.col = "#ffd45a" if o.get("ignoreStance", false) else "#ffffff"
	S.fx.floats.append(fl)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, jor(o.get("stop", 0.0), 0.05))
	S.fx.shake = SimMathx.jmax(S.fx.shake, jor(o.get("shake", 0.0), 6.0))
	hurt(S, D, dd, A)
	return dd


static func ko(S: SimState, D, A) -> void:
	if S.game.ko != null:
		return
	S.game.ko = D
	S.game.koT = 0.0
	S.game.ts = 0.35
	D.hp = 0.0
	SimFx.banner(S, "K.O.  " + A.name + " WINS", "#ffd45a", 4.0)
	SimEvents.feed(S, "K.O. — " + A.name + " wins", "Casualties " + SimMathx.jstr(SimMathx.jround(S.world.casualties)) + ", structures lost " + SimMathx.jstr(S.world.structuresLost))
	if S.dirS.ex != null:
		DirExchange.endEx(S, S.dirS.ex)
	A.state = "free" if A.state == "locked" else A.state
	if D.state != "launched":
		DirLaunch.doLaunch(S, A, D, {"ux": A.face * 0.9, "uy": 0.5}, 1800.0)
