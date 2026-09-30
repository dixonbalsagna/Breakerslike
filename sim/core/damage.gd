class_name SimDamage
## Damage model: the twin of damage.js (hurt, hit, ko). Hit options o are a Dictionary like the JS object literal
## (ignoreStance, big, stop, shake, kb, noParry); a missing key reads as JS undefined.

const STANCE_MUL: Array = [1.12, 0.38, 1.0, 1.25]
## Menace's damage bonus at full menace (balance-targets.md section 9, slice S0): was 0.25.
const MENACE_DMG_CAP: float = 0.15
## The hero's composure bonus while anguish is under COMPOSURE_ANGUISH (section 9's fallback, S0).
const COMPOSURE_BONUS: float = 0.0   # off (balance-targets.md §4b ruling 6); was 0.10
const COMPOSURE_ANGUISH: float = 10.0


## JS `v || d` for a number: d when v is 0, -0 or NaN.
static func jor(v: float, d: float) -> float:
	return v if (v != 0.0 and v == v) else d


## fam: the wounds hit family (wounds.gd family()); kind, col and number describe the damage event. The defaults are a
## landing or collision: spread over the body, kind "impact", no damage number.
static func hurt(S: SimState, f, amt: float, by, fam: String = "spread", kind: String = "impact", col: String = "", number: bool = false) -> void:
	# Since S2 hp is a readout only (the HUD bar): it floors at 0, and wounds and finishers decide the match.
	f.hp = f.hp - amt if SimWounds.HP_ENDS_MATCH else SimMathx.jmax(0.0, f.hp - amt)
	f.hurtT = S.T
	var region: int = SimWounds.pickRegion(S, f, fam) if amt > 0.0 else -1
	SimFx.damage(S, f, by, amt, SimWounds.REGIONS[region] if region >= 0 else "", kind, col, number)
	if region >= 0:
		SimWounds.addWear(S, f, region, amt)
	# The Wounds hook (wounds-plan.md S1/S2): the HP bar ends the match until Encounter's S2 flips HP_ENDS_MATCH; then
	# only a finisher can KO (spec-wounds.md §1, "The end").
	if SimWounds.HP_ENDS_MATCH and f.hp <= 0.0 and S.game.ko == null:
		ko(S, f, by if by != null else SimRoster.opp(S, f))


static func hit(S: SimState, ex, A, D, dmg: float, o = null) -> float:
	if o == null:
		o = {}
	var m: float = A.dmgMul * (1.0 + 0.09 * (A.tier - 1.0))
	if A.hasMenace:
		m *= 1.0 + MENACE_DMG_CAP * (A.menace / 100.0)
	elif A.hasAnguish:
		# Comeback (a fighter with the anguish meter, GD-B09): stronger the closer he is to the brink (S2: wounds replace hp / maxhp).
		m *= 1.0 + 0.5 * SimDetMath.pow(1.0 - SimWounds.vitality(A), 2.0)
	# Composure (balance-targets.md section 9, S0 fallback): the hero hits harder while collateral has not rattled him.
	if A.hasAnguish and A.anguish < COMPOSURE_ANGUISH:
		m *= 1.0 + COMPOSURE_BONUS
	m *= 1.0 + 0.12 * ((ex.combo if ex != null else 1.0) - 1.0)
	if A.ambush:
		m *= 1.5
	# S3b stage penalty (spec-wounds.md §1): the exchange attacker with broken arms deals x0.8 with heavies and signatures.
	if ex != null and A == ex.A and (ex.kind == "heavy" or ex.kind == "sig") and SimWounds.broken(A, SimWounds.ARMS):
		m *= SimWounds.ARMS_BROKEN_MUL
	# S3b (R8): inside an exchange the stances are the ones frozen at requestAttack; outside, the live stance.
	var dStance: float = D.stance
	if ex != null and (D == ex.D or D == ex.A):
		dStance = ex.sD if D == ex.D else ex.sA
	var sm: float = 1.0
	if not o.get("ignoreStance", false):
		sm = STANCE_MUL[int(dStance)]
		# S3b stage penalty: battered arms weaken the guard (DEFENSIVE 0.38 becomes 0.55).
		if dStance == 1.0 and SimWounds.battered(D, SimWounds.ARMS):
			sm = SimWounds.ARMS_GUARD_MUL
		if D.state == "charging":
			sm = 1.35
	var dd: float = dmg * m * sm
	if D.state == "charging":
		D.state = "free"
	if dStance == 1.0 and not o.get("ignoreStance", false):
		D.ki = SimMathx.jmax(0.0, D.ki - dd * 0.08)
	A.ki = SimMathx.jmin(100.0, A.ki + dd * 0.04)
	D.power = SimMathx.jmin(100.0, D.power + dd * 0.010)
	A.power = SimMathx.jmin(100.0, A.power + dd * 0.006)
	SimFx.spark(S, D.x, D.y + 34.0, 18 if o.get("big", false) else 9, "#fff3c0", 600.0)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, jor(o.get("stop", 0.0), 0.05))
	SimFx.shake(S, jor(o.get("shake", 0.0), 6.0), D.x)
	var fam: String = SimWounds.family(ex, D, o, dStance)
	var kind: String = o.get("kind", "") if o.get("kind", "") != "" else ("guard" if fam == "guard" else ("beam" if ex != null and ex.kind == "sig" else ("heavy" if ex != null and ex.kind == "heavy" else "light")))
	hurt(S, D, dd, A, fam, kind, "#ffd45a" if o.get("ignoreStance", false) else "#ffffff", true)
	if kind == "heavy" and dd > 0.0:
		SimWounds.stagger(S, D)
	return dd


static func ko(S: SimState, D, A) -> void:
	if S.game.ko != null:
		return
	S.game.ko = D
	S.game.koT = 0.0
	S.game.ts = 0.35
	D.hp = 0.0
	SimFx.banner(S, "K.O.  " + A.name + " WINS", "#ffd45a", 4.0)
	SimFx.ko(S, A, D)
	SimEvents.feed(S, "K.O. — " + A.name + " wins", "Casualties " + SimMathx.jstr(SimMathx.jround(S.world.casualties)) + ", structures lost " + SimMathx.jstr(S.world.structuresLost))
	if S.dirS.ex != null:
		DirExchange.endEx(S, S.dirS.ex)
	A.state = "free" if A.state == "locked" else A.state
	if D.state != "launched":
		DirLaunch.doLaunch(S, A, D, {"ux": A.face * 0.9, "uy": 0.5}, 1800.0)
