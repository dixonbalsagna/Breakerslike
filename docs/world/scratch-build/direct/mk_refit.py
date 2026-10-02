"""Re-fit of mk_direct.py to Game Design's agency-pass section 15 (15.1 radii, 15.3 structure damage and the threshold).  python mk_refit.py <root with mk_direct applied>"""
import sys, json
R = sys.argv[1].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = fn(s.replace('\r\n', '\n'))
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, a, b):
    assert s.count(a) == 1, a[:90]
    return s.replace(a, b)


def blast(s):
    # shotHit: the charge, the radius by tier, the area share, one building at most
    s = rep(s, 'cause: String) -> Dictionary:\n	var res := {"crater": null, "levelled": 0}',
            'cause: String, charge: float = 1.0, capLeft: int = 1) -> Dictionary:\n	var res := {"crater": null, "levelled": 0}')
    s = rep(s, '	var E: float = float(k.craterE) * float(D.tierEnergy[ti])\n',
            '	var E: float = lerpf(float(k.get("craterETap", k.craterE)), float(k.craterE), charge) * float(D.tierEnergy[ti])\n')
    s = rep(s, '	res.levelled = WorldStructures.damageArea(S, x, g + 5.0, float(k.radius), float(k.damage) * float(D.tierDamage[ti]), f)\n',
            '	res.levelled = _area(S, f, k, D, ti, charge, x, g + 5.0, capLeft)\n')
    s = rep(s, '\n\nconst STEP: float = 24.0', '''

## Structure damage of a direct hit by kind and charge, before the tier factor (agency-pass 15.3): a charged shot runs from `damage` (a tap)
## to `fullDamage`.
static func structDamage(k: Dictionary, charge: float) -> float:
	return lerpf(float(k.damage), float(k.get("fullDamage", k.damage)), charge)


## The blast on the buildings around a point: half of a direct hit (areaShare) over the kind's radius (a charged shot's grows with its charge,
## every kind's with the shooter's tier), the tier factor on the damage. At most capLeft buildings fall; the rest are left at a quarter of their hp.
static func _area(S: SimState, f, k: Dictionary, D: Dictionary, ti: int, charge: float, x: float, y: float, capLeft: int) -> int:
	var rad: float = lerpf(float(k.radius), float(k.get("fullRadius", k.radius)), charge) * float(D.tierRadius[ti])
	var dmg: float = structDamage(k, charge) * float(k.get("areaShare", D.areaShare)) * float(D.tierDamage[ti])
	return WorldStructures.damageArea(S, x, y, rad, dmg, f, false, 0.0, capLeft, 0.25, 1.0)


const STEP: float = 24.0''')
    # the building hit: charge from the shot's damage, the pool for every kind, one building
    s = rep(s, '''	if D.is_empty() or not D.get("direct", {}).has(sh.kind):
		return false''', '''	if D.is_empty() or not D.kinds.has(sh.kind) or sh.kind == "mine":
		return false''')
    s = rep(s, '		shotBuilding(S, sh.owner, sh.kind, sh.power, hit, px2, py2, sh.z, sh.vx, sh.vy)\n', '		shotBuilding(S, sh.owner, sh.kind, sh.power, hit, px2, py2, sh.z, sh.vx, sh.vy, chargeOf(sh))\n')
    s = rep(s, '''static func shotBuilding(S: SimState, slot: int, kind: String, power: float, b, x: float, y: float, z: float, vx: float, vy: float) -> Dictionary:
	var D: Dictionary = data()
	var h: Dictionary = D.direct[kind]
	var f = S.fighters[slot]
	var ti: int = clampi(int(f.tier), 1, 4) - 1
	var dmg: float = float(h.damage) * float(D.tierDamage[ti])
	var res := {"outcome": "hit", "dmg": dmg, "levelled": false}
	var k: Dictionary = D.kinds[kind]
''', '''static func shotBuilding(S: SimState, slot: int, kind: String, power: float, b, x: float, y: float, z: float, vx: float, vy: float, charge: float = 1.0) -> Dictionary:
	var D: Dictionary = data()
	var k: Dictionary = D.kinds[kind]
	var f = S.fighters[slot]
	var ti: int = clampi(int(f.tier), 1, 4) - 1
	var dmg: float = structDamage(k, charge) * float(D.tierDamage[ti])
	var res := {"outcome": "hit", "dmg": dmg, "levelled": false}
''')
    s = rep(s, '''	if bool(h.get("chip", false)):
		b.wear += dmg
		if b.wear < float(D.chip.threshold) * b.maxhp:
			res.outcome = "chip"
			SimFx.debris(S, x, y, 2, "#77808f", 300.0, z)
			return res
		dmg = b.wear   # it shows: the pool is paid in one blow
		b.wear = 0.0
		res.dmg = dmg
		res.outcome = "wound"
''', '''	if b.wear >= 0.0:   # nothing has shown yet: the damage piles into the pool (scorch marks only) until a quarter of the hit points
		b.wear += dmg
		if b.wear < float(D.chip.threshold) * b.maxhp:
			res.outcome = "chip"
			SimFx.debris(S, x, y, 2, "#77808f", 300.0, z)
			SimFx.ring(S, x, y, float(k.ringR) * 0.5, "#ffffff", 0.3, 8.0, z)
			return res
		dmg = b.wear   # it shows: the pool is paid in one blow, and from now on every hit counts at once (wear -1)
		b.wear = -1.0
		res.dmg = dmg
		res.outcome = "wound"
''')
    s = rep(s, '''	SimFx.debris(S, x, y, int(k.debris), "#77808f", 500.0, z)
	SimFx.dust(S, x, y, int(k.dust), "", z)
	return res


## WorldBrunt.applyFloors for a shot''', '''	SimFx.debris(S, x, y, int(k.debris), "#77808f", 500.0, z)
	SimFx.dust(S, x, y, int(k.dust), "", z)
	_area(S, f, k, D, ti, charge, x, y, 1 - (1 if res.levelled else 0))   # the blast on its neighbours: one shot levels at most one building
	return res


## The charge of a charged shot from the damage the director gave it at the fire (a tap is 0.6 of the kind's damage, a full charge all of it): 0 to 1.
static func chargeOf(sh) -> float:
	if sh.kind != "charged" or not SimShots.kinds.has("charged"):
		return 1.0
	return clampf((sh.dmg / maxf(float(SimShots.kinds["charged"].dmg), 0.000001) - 0.6) / 0.4, 0.0, 1.0)


## WorldBrunt.applyFloors for a shot''')
    s = rep(s, '''	SimFx.ring(S, x, y, float(k.ringR) * 0.5, "#ffffff", 0.3, 8.0, z)
	SimFx.shake(S, float(k.shake) * 0.5, x, z)
	if b.wear >= 0.0:''', '''	SimFx.shake(S, float(k.shake) * 0.5, x, z)
	if b.wear >= 0.0:''')
    return s


rw('sim/world/blast.gd', blast)

# the wear field starts at 0 (pooling) and goes -1 once it has shown; nothing else changes in state.gd

p = R + 'data/biomes/blast.json'
d = json.load(open(p, encoding='utf-8'))
K = d['kinds']
K['bolt'].update(damage=12, radius=38)
K['shard'].update(damage=12, radius=38)
K['arc'].update(damage=40, radius=75, craterE=0.25)
K['lob'].update(damage=80, radius=112)
K['charged'].update(damage=60, fullDamage=140, radius=112, fullRadius=150, craterETap=0.5, craterE=0.8)
K['mine'].update(damage=140, radius=150, craterE=0.8, areaShare=1.0)
d['tierDamage'] = [0.25, 0.5, 1.0, 1.5]
d['tierRadius'] = [1.0, 1.0, 1.25, 1.5]
d['areaShare'] = 0.5
d['chip'] = {"threshold": 0.25}
d.pop('direct', None)
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')
print('refit ok')
