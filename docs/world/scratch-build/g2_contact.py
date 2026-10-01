"""G2 and G3: the ground-contact model (switched off by data), its fields, its events, its hook in stepLaunched.
Usage: python g2_contact.py <repo root> <gpatch dir>"""
import sys, shutil
R = sys.argv[1].rstrip('/') + '/'
G = sys.argv[2].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = s.replace('\r\n', '\n')
    s = fn(s)
    if cr:
        s = s.replace('\n', '\r\n')
    open(R + p, 'w', encoding='utf-8', newline='').write(s)


def rep(s, old, new, n=1):
    assert old in s, old[:90]
    return s.replace(old, new, n)


shutil.copy(G + 'contact.gd', R + 'sim/world/contact.gd')
shutil.copy(G + 'contact.json', R + 'data/biomes/contact.json')


# ---------------------------------------------------------------- state.gd
def state(s):
    s = rep(s, "	var hopped: bool = false ", "	var jContacts: int = 0           # ground contact: contacts of this journey so far (world/contact.gd)\n	var jT: int = 0                  # ticks since the journey's first contact (cap 240)\n	var jV0: float = 0.0             # the journey's first-contact normalised speed (the wear budget)\n	var tumbleT: int = -1            # ticks rolled in a tumble, -1 when not tumbling (cap 72)\n	var contactT: int = 0            # ticks since the last contact, saturating at 8 (the early-recovery window)\n	var launchN: int = 0             # this fighter's launch number: every contact event carries it\n	var hopped: bool = false ")
    s = rep(s, "var game := Game.new()\n", "var game := Game.new()\nvar contactOn: bool = false           # ground contact on (a copy of data/biomes/contact.json enabled, taken by newMatch)\n")
    s = rep(s, "	var z: float = 0.0           # launch_depth", "	var surface: String = \"\"     # bounce, land: the surface class (paving, rock, soil, sand, rubble, water)\n	var vn: float = 0.0          # bounce, land: the speed into the surface (negative into the ground)\n	var vt: float = 0.0          # bounce, land: the speed along the surface\n	var sina: float = 0.0        # land, bounce: the sine of the contact angle to the surface\n	var vx: float = 0.0          # left_ground: the velocity he leaves with\n	var vy: float = 0.0\n	var slope: float = 0.0       # left_ground, bounce, land: the ground slope (rise over run) at the contact\n	var contacts: int = 0        # left_ground, land, bounce, tumble_end, journey_end: contacts so far\n	var lips: int = 0            # journey_end: flights off a lip\n	var nb: int = 0              # journey_end: bounces\n	var z: float = 0.0           # launch_depth")
    return s


rw('sim/core/state.gd', state)


# ---------------------------------------------------------------- hash.gd
def hsh(s):
    s = rep(s, '"chainEvt", "z",\n', '"chainEvt", "z", "jContacts", "jT", "jV0", "tumbleT", "contactT", "launchN",\n')
    s = rep(s, "	out.append(float(S.trees.size()))", "	out.append(1.0 if S.contactOn else 0.0)\n	out.append(float(S.trees.size()))")
    s = rep(s, '"launch": ["actor", "target", "amount", "face"],', '"launch": ["actor", "target", "amount", "face", "n", "ux", "uy"],')
    s = rep(s, '	"cue": ["actor", "kind", "text", "source"],',
            '	"left_ground": ["actor", "x", "y", "z", "spd", "n", "cause", "vx", "vy", "slope", "contacts", "dur"], "bounce": ["actor", "x", "y", "z", "spd", "n", "k", "keep", "vn", "vt", "surface", "sina", "slope", "contacts", "dur"],\n'
            '	"land": ["actor", "x", "y", "z", "spd", "n", "kind", "sina", "slope", "surface", "vn", "vt", "contacts", "dur"], "tumble_end": ["actor", "x", "y", "z", "spd", "n", "kind", "contacts", "dur"],\n'
            '	"journey_end": ["actor", "x", "y", "z", "spd", "n", "kind", "contacts", "lips", "nb", "dur"],\n'
            '	"cue": ["actor", "kind", "text", "source"],')
    return s


rw('sim/core/hash.gd', hsh)


# ---------------------------------------------------------------- fx.gd: one emitter for the contact events
def fx(s):
    return rep(s, "static func launch(S: SimState, f, by, speed: float, dir: float) -> void:",
               """## A ground-contact event (world/contact.gd): left_ground, bounce, land, tumble_end, journey_end. Every one carries the body's
## x, y, z, speed and the launch number n (the caller sets the rest).
static func contactEvent(S: SimState, type: String, f, x: float, y: float, speed: float) -> SimState.FxEvent:
	var e := _ev(S, type)
	e.actor = float(S.fighters.find(f))
	e.x = x
	e.y = y
	e.z = f.z
	e.spd = speed
	e.n = int(f.launchN)
	return e


static func launch(S: SimState, f, by, speed: float, dir: float) -> void:""")


rw('sim/core/fx.gd', fx)


# ---------------------------------------------------------------- view/fx.gd: the new events are ignored by the reference consumer
rw('sim/core/view/fx.gd', lambda s: rep(s, '"launch_depth", "chain_link", "floor_hit", "floors_fall":', '"launch_depth", "chain_link", "floor_hit", "floors_fall", "left_ground", "bounce", "land", "tumble_end", "journey_end":'))


# ---------------------------------------------------------------- sim.gd: the flag copied into the match
rw('sim/core/sim.gd', lambda s: rep(s, "	WorldTerrain.genWorld(S)\n", "	WorldTerrain.genWorld(S)\n	S.contactOn = WorldContact.enabled()\n"))


# ---------------------------------------------------------------- fighter.gd: the hook
rw('sim/core/fighter.gd', lambda s: rep(s, "	WorldBrunt.stepZ(S, f, dt)\n	if f.slide > 0.0:\n		WorldSlide.step(S, f, dt)\n		return\n",
                                       "	WorldBrunt.stepZ(S, f, dt)\n	if S.contactOn:   # ground contact (world/contact.gd): leave, land, bounce, skid, tumble\n		WorldContact.stepFighter(S, f, dt)\n		return\n	if f.slide > 0.0:\n		WorldSlide.step(S, f, dt)\n		return\n"))


# ---------------------------------------------------------------- brunt.gd arm: the journey's counters and the launch number
def brunt(s):
    return rep(s, "	f.flightHits = 0\n	f.splashed = PackedInt32Array()\n	if not plan.has(\"brunt\"):",
               """	f.flightHits = 0
	f.splashed = PackedInt32Array()
	# a new launch starts a new journey (world/contact.gd) and takes the next launch number, which its events carry
	f.jContacts = 0
	f.jT = 0
	f.jV0 = 0.0
	f.tumbleT = -1
	f.contactT = 0
	f.launchN += 1
	var slot: float = float(S.fighters.find(f))
	for i in range(S.out.fx.size() - 1, -1, -1):
		var le = S.out.fx[i]
		if le.type == "launch" and le.actor == slot:
			le.n = f.launchN
			le.ux = float(plan.get("ux", 0.0))   # the launch direction (Animation, Camera)
			le.uy = float(plan.get("uy", 0.0))
			break
	if not plan.has("brunt"):""")


rw('sim/world/brunt.gd', brunt)
print('g2 ok')
