"""World's window on top of Simulation's shots second round (shots2.py code + hash): the building hit as the body of SimShots.hitStructure, the air burst,
the mine row behind hitWorld(..., "mine"), the wear pool and section 15's numbers, wallHaltBelow 900, leave.rimLift 3.0, structures on.
python mk_window.py <root> <scratch with sh5 (blast.gd, blast.json)> [off]"""
import sys, json, shutil
R = sys.argv[1].rstrip('/') + '/'
SH5 = sys.argv[2].rstrip('/') + '/'
STRUCT = not (len(sys.argv) > 3 and sys.argv[3] == 'off')


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = fn(s.replace('\r\n', '\n'))
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, a, b):
    assert s.count(a) == 1, (a[:90], s.count(a))
    return s.replace(a, b)


# ---- state, hash, fx, brunt
rw('sim/core/state.gd', lambda s: rep(s, '	var popAlive: float = 0.0\n\n\nclass TreeState', '	var popAlive: float = 0.0\n	var wear: float = 0.0      # the unshown wear a building has taken from shots (WorldBlast.shotBuilding): 0 or more while it only scorches, -1 once it has shown\n\n\nclass TreeState'))
rw('sim/core/hash.gd', lambda s: rep(s, '"floors", "fmask"]', '"floors", "fmask", "wear"]'))
rw('sim/core/fx.gd', lambda s: rep(s, '## B2: a brunt hit floors of a skyscraper', '''## A shot hit floors of a skyscraper (WorldBlast.shotBuilding): the same event as a brunt's, victim -1, the shot's direction in ux, uy.
static func floorHitShot(S: SimState, b, floor_: int, n: int, outcome: String, ratio: float, y: float, slot: int, ux: float, uy: float) -> void:
	var e := _ev(S, "floor_hit")
	e.b = float(b.idx); e.floor = floor_; e.n = n; e.outcome = outcome; e.ratio = ratio
	e.x = b.x; e.y = y; e.z = WorldBrunt.faceZ(b)
	e.ux = ux; e.uy = uy
	e.kind = b.kind; e.owner = float(slot); e.victim = -1.0


## B2: a brunt hit floors of a skyscraper'''))
rw('sim/world/brunt.gd', lambda s: rep(s, '''static func outcomeOf(S: SimState, b, y: float, spN: float, tier: float) -> Dictionary:
	var dmg: float = spN * (0.55 + 0.25 * tier) * BRUNT_MUL
''', '''static func outcomeOf(S: SimState, b, y: float, spN: float, tier: float) -> Dictionary:
	return outcomeDmg(S, b, y, spN * (0.55 + 0.25 * tier) * BRUNT_MUL)


## The same by the damage itself (a brunt's from its speed and tier, a shot's from its kind: WorldBlast.shotBuilding).
static func outcomeDmg(S: SimState, b, y: float, dmg: float) -> Dictionary:
'''))


# ---- World's blast: the prototype of section 28 without its own test (Simulation's exact swept test replaces it)
def blast(s):
    a = s.index('const STEP: float = 24.0')
    b = s.index('## A shot hits building b at')
    s = s[:a] + s[b:]
    s = rep(s, 'res.levelled = _area(S, f, k, D, ti, charge, x, g + 5.0, capLeft)', 'res.levelled = _area(S, f, k, D, ti, charge, x, maxf(y, g + 5.0), capLeft)   # an air burst blasts at its height')
    s = rep(s, '## A shot hits building b at (x, y)', '## A shot hits building b at (x, y) (SimShots.hitStructure calls this)')
    return s


src = open(SH5 + 'blast.gd', encoding='utf-8', newline='').read().replace('\r\n', '\n')
open(R + 'sim/world/blast.gd', 'w', encoding='utf-8', newline='').write(blast(src))
shutil.copy(SH5 + 'blast.json', R + 'data/biomes/blast.json')


# ---- the hooks in shots.gd
def shots(s):
    s = rep(s, '''static func hitStructure(_S: SimState, _sh, _b) -> bool:
	return true
''', '''static func hitStructure(S: SimState, sh, b) -> bool:
	WorldBlast.shotBuilding(S, sh.owner, sh.kind, sh.power, b, sh.x, sh.y, sh.z, sh.vx, sh.vy, WorldBlast.chargeOf(sh))   # World: the shot's hit on the building (the wear pool, the floors, one building at most)
	return true
''')
    s = rep(s, '''static func hitWorld(S: SimState, sh, cause: String) -> void:
	WorldBlast.shotHit(S, sh.owner, sh.kind, sh.x, sh.y, sh.z, sh.vx, sh.vy, cause)   # World's blast on the ground, the structures and the water
''', '''static func hitWorld(S: SimState, sh, cause: String) -> void:
	if cause == "mine":
		WorldBlast.mineBlast(S, sh.owner, sh.x, sh.y, sh.z)   # a mine's blast, on the ground or hanging in the air (the bowl fades with the height)
		return
	WorldBlast.shotHit(S, sh.owner, sh.kind, sh.x, sh.y, sh.z, sh.vx, sh.vy, cause, WorldBlast.chargeOf(sh))   # World's blast on the ground, the structures and the water; cause "air" for a burst where the shot's life ran out
''')
    s = rep(s, '''		elif arrived[i]:
			end(S, sh, "life")''', '''		elif arrived[i]:
			hitWorld(S, sh, "air")   # a shot that ran out of life bursts where it is
			end(S, sh, "life")''')
    return s


rw('sim/core/shots.gd', shots)

# ---- contact: rimLift, wallHaltBelow 900
def contact(s):
    s = rep(s, '	var vyT: float = sprev * vN2 * K_LIFT\n', '	var vyT: float = sprev * vN2 * K_LIFT\n	if sprev > 0.0 and K_RIMLIFT != 1.0 and _nearRim(S, b.x):\n		vyT *= K_RIMLIFT   # a crater\'s lip throws him further than the same slope on natural ground (Orb\'s ramp)\n')
    s = rep(s, 'static var K_CLEAR: float = 1.5\n', 'static var K_CLEAR: float = 1.5\nstatic var K_RIMLIFT: float = 1.0       # extra lift of a skid climbing a crater\'s lip (leave.rimLift)\n')
    s = rep(s, '	K_CLEAR = float(D.leave.clear)\n', '	K_CLEAR = float(D.leave.clear)\n	K_RIMLIFT = float(D.leave.get("rimLift", 1.0))\n')
    return s


rw('sim/world/contact.gd', contact)
p = R + 'data/biomes/contact.json'
t = open(p, encoding='utf-8').read()
assert '"lipLift": 1.0,' in t and '"wallHaltBelow": 600' in t
t = t.replace('"lipLift": 1.0,', '"lipLift": 1.0,\n    "rimLift": 3.0,', 1).replace('"wallHaltBelow": 600', '"wallHaltBelow": 900', 1)
open(p, 'w', encoding='utf-8', newline='').write(t)
json.load(open(p, encoding='utf-8'))

# ---- structures on
if STRUCT:
    p = R + 'data/fight/shots.json'
    t = open(p, encoding='utf-8').read()
    assert '"structures": false' in t
    open(p, 'w', encoding='utf-8', newline='').write(t.replace('"structures": false', '"structures": true', 1))
print('window applied, structures', 'on' if STRUCT else 'off')
