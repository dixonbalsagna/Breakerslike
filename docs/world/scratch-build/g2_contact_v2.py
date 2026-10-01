"""G2 to G5 rebased on Simulation's L0 and L2 (d7d3db3): the fields, events and hash lines are already in the tree, so this adds only
contact.gd and contact.json, and the grant lines in Simulation's files: S.contactOn in newMatch, the hook at the top of
stepLaunched, SimFighter.spin handing over to WorldContact.spinFighter, and WorldBrunt.arm's journey reset and the launch event's n.
Usage: python g2_contact_v2.py <repo root> <gpatch dir>"""
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

rw('sim/core/sim.gd', lambda s: rep(s, "	WorldTerrain.genWorld(S)\n", "	WorldTerrain.genWorld(S)\n	S.contactOn = WorldContact.enabled()   # World's ground contact (world/contact.gd): a copy of the data's switch\n"))


def fighter(s):
    s = rep(s, "	WorldBrunt.stepZ(S, f, dt)\n	if f.slide > 0.0:\n		WorldSlide.step(S, f, dt)\n		return\n",
            "	WorldBrunt.stepZ(S, f, dt)\n	if S.contactOn:   # ground contact (world/contact.gd): leave, land, bounce, skid, tumble\n		WorldContact.stepFighter(S, f, dt)\n		return\n	if f.slide > 0.0:\n		WorldSlide.step(S, f, dt)\n		return\n")
    s = rep(s, "static func spin(_S: SimState, f, dt: float, how: int) -> void:\n",
            "static func spin(S: SimState, f, dt: float, how: int) -> void:\n	if S.contactOn:   # the journey's own rolling (world/contact.gd): rot only integrated or eased\n		WorldContact.spinFighter(f, dt, how)\n		return\n")
    return s


rw('sim/core/fighter.gd', fighter)


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
	f.jLips = 0
	f.launchN += 1
	var slot: float = float(S.fighters.find(f))
	for i in range(S.out.fx.size() - 1, -1, -1):
		var le = S.out.fx[i]
		if le.type == "launch" and le.actor == slot:
			le.n = f.launchN
			break
	if not plan.has("brunt"):""")


rw('sim/world/brunt.gd', brunt)
print('g2 v2 ok')
