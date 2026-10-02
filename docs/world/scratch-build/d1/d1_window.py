"""The D1 window's remaining pieces on top of the L1 with D1 scratch (l1d1.diff): python d1_window.py <root>
New Building fields (district, shape, landmark) and their hash lines, building_fall.landmark, the replay data hash, the brunt
candidate filter to rows 1 and 2, and S.lanes (the derived lane table the ground shader reads)."""
import sys, json
R = sys.argv[1].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = s.replace('\r\n', '\n')
    s = fn(s)
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, old, new, n=1):
    assert s.count(old) >= 1, old[:90]
    return s.replace(old, new, n)


# ------------------------------------------------------------ data: the street strips, the looks list, the districts' traffic
p = R + 'data/biomes/lanes.json'
d = json.load(open(p, encoding='utf-8'))
d['strips'] = [
    {"lane": "front_street", "kind": "sidewalk", "top": 5.0, "bottom": 4.0},
    {"lane": "front_street", "kind": "kerb", "top": 4.0, "bottom": 2.8},
    {"lane": "front_street", "kind": "carriageway", "top": 2.8, "bottom": -1.8},
    {"lane": "front_street", "kind": "kerb", "top": -1.8, "bottom": -3.0},
    {"lane": "front_street", "kind": "sidewalk", "top": -3.0, "bottom": -4.0},
    {"lane": "back_street", "kind": "sidewalk", "top": -12.0, "bottom": -13.0},
    {"lane": "back_street", "kind": "carriageway", "top": -13.0, "bottom": -17.0},
    {"lane": "back_street", "kind": "sidewalk", "top": -17.0, "bottom": -18.0},
]
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')
p = R + 'data/biomes/settlements.json'
d = json.load(open(p, encoding='utf-8'))
looks = []
for s in d['settlements']:
    for dd in s['districts']:
        if dd['look'] not in looks:
            looks.append(dd['look'])
d['looks'] = looks
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')


# ------------------------------------------------------------ state.gd: the Building fields, the lane table, the event field
def state(s):
    s = rep(s, "	var floors: int = 1        # floor count", "	var district: int = 0      # D1: the district it stands in (index over all settlements), set at generation\n	var shape: String = \"\"      # D1: the render shape (settlements.json shapes)\n	var landmark: int = 0      # D1: 1-based landmark index (0 none)\n	var floors: int = 1        # floor count")
    s = rep(s, "var low := PackedFloat32Array()", "var lanes := PackedFloat32Array()      # L1: the lane table (world/lanes.gd build), derived, not hashed: read by the ground shader and the props\nvar low := PackedFloat32Array()")
    s = rep(s, "	var rubble: float = 0.0      # building_fall: the heap height left", "	var rubble: float = 0.0      # building_fall: the heap height left\n	var landmark: float = 0.0    # building_fall: the landmark index of the fallen building (0 none)")
    return s


rw('sim/core/state.gd', state)


# ------------------------------------------------------------ hash.gd
def hsh(s):
    s = rep(s, '"floors", "fmask"]', '"floors", "fmask", "district", "shape", "landmark"]')
    s = rep(s, '"building_fall": ["b", "x", "y", "w", "depth", "mode", "delay", "cx", "rubble", "n"]', '"building_fall": ["b", "x", "y", "w", "depth", "mode", "delay", "cx", "rubble", "n", "landmark"]')
    return s


rw('sim/core/hash.gd', hsh)


# ------------------------------------------------------------ fx.gd
def fx(s):
    s = rep(s, "static func buildingFall(S: SimState, b: int, x: float, z: float, w: float, h: float, mode: String, delay: float, cx: float, rubble: float, n: float) -> void:\n	var e := _ev(S, \"building_fall\")\n	e.b = float(b); e.x = x; e.y = z; e.w = w; e.depth = h; e.mode = mode; e.delay = delay; e.cx = cx; e.rubble = rubble; e.n = n\n",
            "static func buildingFall(S: SimState, b: int, x: float, z: float, w: float, h: float, mode: String, delay: float, cx: float, rubble: float, n: float, landmark: float = 0.0) -> void:\n	var e := _ev(S, \"building_fall\")\n	e.b = float(b); e.x = x; e.y = z; e.w = w; e.depth = h; e.mode = mode; e.delay = delay; e.cx = cx; e.rubble = rubble; e.n = n; e.landmark = landmark\n")
    return s


rw('sim/core/fx.gd', fx)


# ------------------------------------------------------------ structures.gd: the landmark on the fall event
def structures(s):
    return rep(s, "			SimFx.buildingFall(S, b.idx, b.x, b.z, b.w, b.h, mode, delay, cx, heap, 1.0)", "			SimFx.buildingFall(S, b.idx, b.x, b.z, b.w, b.h, mode, delay, cx, heap, 1.0, float(b.landmark))")


rw('sim/world/structures.gd', structures)


# ------------------------------------------------------------ brunt.gd: candidates in the block rows only
def brunt(s):
    return rep(s, "		if not b.alive:\n			continue\n		var dx: float = SimWrap.sdx(D.x, b.x)\n		var d: float = absf(dx) - b.w * 0.5\n		if d < BR_MIN or d > BR_MAX:",
               "		if not b.alive or (WorldSettle.enabled() and b.row != 1.0 and b.row != 2.0):\n			continue   # D1: the scenery rows (0 and 3) are not brunt targets\n		var dx: float = SimWrap.sdx(D.x, b.x)\n		var d: float = absf(dx) - b.w * 0.5\n		if d < BR_MIN or d > BR_MAX:")


rw('sim/world/brunt.gd', brunt)


# ------------------------------------------------------------ settlements.gd: enabled(), dataHash(), the district list
def settle(s):
    s = rep(s, '"avenues": avenues})', '"avenues": avenues, "rows": dd.rows, "traffic": float(dd.get("traffic", 0.0))})')
    s = rep(s, "static func errors() -> Array:", '''static func enabled() -> bool:
	return bool(data().get("enabled", false))


## A hash of the parsed settlement and lane data (the "_" notes left out), for the replay header's data hash.
static func dataHash() -> String:
	var h := SimHash.Hasher.new()
	h.text("biomes.settlements")
	FighterData._canon(h, data())
	h.text("biomes.lanes")
	FighterData._canon(h, WorldLanes.data())
	return h.hex()


static func errors() -> Array:''')
    return s


rw('sim/world/settlements.gd', settle)


# ------------------------------------------------------------ replay.gd
def replay(s):
    return rep(s, "	h.text(WorldContact.dataHash())   # World's ground contact: data/biomes/contact.json\n", "	h.text(WorldContact.dataHash())   # World's ground contact: data/biomes/contact.json\n	h.text(WorldSettle.dataHash())    # World's settlements and lanes: data/biomes/settlements.json, lanes.json\n")


rw('sim/core/replay.gd', replay)


# ------------------------------------------------------------ terrain.gd: the fields, and the lane table
def terrain(s):
    s = rep(s, "		for sd in WorldSettle.data().settlements:\n			var g: Dictionary = WorldSettle.generate(S, sd)\n			for e in g.buildings:\n",
            "		var dOff: int = 0\n		var si: int = -1\n		var dlist: Array = []\n		for sd in WorldSettle.data().settlements:\n			si += 1\n			var g: Dictionary = WorldSettle.generate(S, sd)\n			for dd in g.districts:\n				dd[\"settlement\"] = si\n				dlist.append(dd)\n			for e in g.buildings:\n")
    s = rep(s, "				nb.floors = e.floors\n				nb.fmask = (1 << nb.floors) - 1\n				nb.maxhp = e.maxhp; nb.hp = e.maxhp; nb.alive = true\n",
            "				nb.district = dOff + int(e.district); nb.shape = String(e.shape); nb.landmark = int(e.landmark)\n				nb.floors = e.floors\n				nb.fmask = (1 << nb.floors) - 1\n				nb.maxhp = e.maxhp; nb.hp = e.maxhp; nb.alive = true\n")
    s = rep(s, "				S.buildings.append(nb)\n	else:", "				S.buildings.append(nb)\n			dOff += g.districts.size()\n		S.lanes = WorldLanes.build(S, dlist)\n	else:")
    return s


rw('sim/world/terrain.gd', terrain)

# ------------------------------------------------------------ lanes.gd: the lane table and its helpers (written once; L3 reuses it)
import os
here = os.path.dirname(os.path.abspath(__file__))
if not os.path.exists(R + 'sim/world/lanes.gd'):
    open(R + 'sim/world/lanes.gd', 'w', encoding='utf-8', newline='').write(open(os.path.join(here, 'lanes_d1.gd'), encoding='utf-8').read())
print('D1 window applied')
