"""G1 and reach: rims (lip 0.5 R, crest 0.40 d, footings skipped), heaps (slope 0.6, spill 1.2), structure reach by tier
(scaled falloff, ring cap), the ladder data and schema, fighter_data's parse, beam.gd's explicit 1.0.
Usage: python g1_reach.py <repo root>   (re-appliable on a fresh HEAD export)"""
import sys, json, re
R = sys.argv[1].rstrip('/') + '/'


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


# ---------------------------------------------------------------- crater.gd
def crater(s):
    s = rep(s, "const RIM_IN: float = 0.3             # the rim starts to rise this far (in R) inside the lip",
            "const RIM_IN: float = 0.5             # the rim starts to rise this far (in R) inside the lip (ground-contact.md: a wide lip is a ramp)\nconst RIM_DEPTH_MAX: float = 0.40     # the crest is at most this share of the bowl depth: with RIM_IN 0.5 the inner slope stays at 0.57")
    s = rep(s, "	var hr: float = d * volFrac * RIM_H_PER_VOL\n",
            "	var hr: float = minf(d * volFrac * RIM_H_PER_VOL, RIM_DEPTH_MAX * d)\n")
    # dig loop: a rim never lands on a standing building's footing
    s = rep(s, "	var minG: float = 1e9\n	var pre := PackedFloat32Array()   # the deform before this crater, for the furrow's target\n	pre.resize(2 * n + 1)\n",
            "	var minG: float = 1e9\n	var pre := PackedFloat32Array()   # the deform before this crater, for the furrow's target\n	pre.resize(2 * n + 1)\n	var pinD: PackedByteArray = WorldStructures.pinned(S, c0, n)   # the rim and apron skip footings (T4 extended)\n")
    s = rep(s, "		var h: float = profile(u, d, hr)\n",
            "		var h: float = profile(u, d, hr)\n		if h > 0.0 and pinD[k + n] == 1:\n			h = 0.0\n")
    return s


rw('sim/world/crater.gd', crater)


# ---------------------------------------------------------------- structures.gd
def structures(s):
    s = rep(s, "const RUBBLE_SPILL: float = 0.8            # the heap is 2 * this * w wide (a mound 1.6 w across the footprint)",
            "const RUBBLE_SPILL: float = 1.0            # the heap is 2 * this * w wide (a mound 2.0 w across the footprint; above about 1.1 a low chain flight lands on the heap and plan and outcome differ)")
    s = rep(s, "const RUBBLE_SLOPE: float = 1.0            # the heap's steepest slope (crest height is capped to it): at most 45 degrees",
            "const RUBBLE_SLOPE: float = 0.6            # the heap's steepest slope (crest height is capped to it): a ramp a skid can climb (ground-contact.md)")
    s = rep(s, "const RUBBLE_BOWL_CAP", "const RING_KEEP: float = 0.25               # a building past a blast's ring cap is left at this share of its hit points\nconst RUBBLE_BOWL_CAP")
    s = rep(s, "float(gap) * lim * 0.9)", "float(gap) * RUBBLE_SLOPE * COL)")
    a = "static func damageArea(S: SimState, x: float, y: float, r: float, dmg: float, cause, beam: bool = false, evt: float = 0.0, capLeft: int = -1, keep: float = 0.0) -> int:\n	var levelled: int = 0\n	S.world.fallTick = -1.0\n	for bi in near(S, x, r):"
    b = """## reachMul: the area's growth by the causing fighter's tier (docs/world/structure-reach.md): -1 takes cause.ld.reach, a number
## uses that (the beam's path samples pass 1.0: the beam has its own tier gate). The whole blast scales, its falloff too.
## ringCap (cause.ld.reachRingCap, -1 off): at most this many buildings levelled beyond the old reach per call.
static func damageArea(S: SimState, x: float, y: float, r0: float, dmg: float, cause, beam: bool = false, evt: float = 0.0, capLeft: int = -1, keep: float = 0.0, reachMul: float = -1.0) -> int:
	var levelled: int = 0
	S.world.fallTick = -1.0
	var tf: float = 1.0
	var ringCap: int = -1
	if reachMul >= 0.0:
		tf = reachMul
	elif cause != null and "ld" in cause and cause.ld != null:
		tf = float(cause.ld.reachStructure[clampi(int(cause.tier), 1, 4) - 1])
		ringCap = int(cause.ld.reachRingCap)
	var r: float = r0 * tf
	var ringLevelled: int = 0
	for bi in near(S, x, r):"""
    s = rep(s, a, b)
    a = "		var lost0: float = S.world.structuresLost\n		damageBuilding(S, b, dmg * (1.0 - SimMathx.jclamp(d / r, 0.0, 1.0) * 0.7), cause, \"implode\", x, evt, false, keep if (capLeft >= 0 and levelled >= capLeft) else 0.0)\n		if S.world.structuresLost > lost0:\n			levelled += 1\n"
    b = "		var lost0: float = S.world.structuresLost\n		var inRing: bool = d > r0\n		var kp: float = keep if (capLeft >= 0 and levelled >= capLeft) else 0.0\n		if inRing and ringCap >= 0 and ringLevelled >= ringCap:\n			kp = RING_KEEP\n		damageBuilding(S, b, dmg * (1.0 - SimMathx.jclamp(d / r, 0.0, 1.0) * 0.7), cause, \"implode\", x, evt, false, kp)\n		if S.world.structuresLost > lost0:\n			levelled += 1\n			if inRing:\n				ringLevelled += 1\n"
    s = rep(s, a, b)
    return s


rw('sim/world/structures.gd', structures)


# ---------------------------------------------------------------- beam.gd: the path samples keep reach 1.0
def beam(s):
    a = "b.levelled += WorldStructures.damageArea(S, x, y, (26.0 + P * 8.0) * SimConst.WS, (110.0 + P * 75.0) * b.sf, A, false, 0.0, maxi(0, b.cap - b.levelled), BEAM_KEEP)"
    return rep(s, a, a[:-1] + ", 1.0)")


rw('sim/director/beam.gd', beam)


# ---------------------------------------------------------------- fighter_data.gd
def fdata(s):
    s = rep(s, "	var beamStructure: Array = []", "	var reachStructure: Array = [1.0, 1.0, 1.0, 1.0]   # structure reach by tier (docs/world/structure-reach.md)\n	var reachRingCap: float = -1.0                      # buildings one blast may level beyond the old reach (-1: off)\n	var beamStructure: Array = []")
    a = "	var bm: Dictionary = j.get(\"beam\", {})\n"
    b = """	var rc: Dictionary = j.get("reach", {})
	var rs = rc.get("structure", [1.0, 1.0, 1.0, 1.0])
	if not (rs is Array and rs.size() == 4):
		_err(where + ": reach.structure needs four values (one per tier)")
		rs = [1.0, 1.0, 1.0, 1.0]
	l.reachStructure = []
	for v in rs:
		if not (float(v) >= 1.0 and float(v) <= 6.0):
			_err(where + ": reach.structure values are 1 to 6")
		l.reachStructure.append(float(v))
	l.reachRingCap = float(rc.get("ringCap", -1))
"""
    s = rep(s, a, b + a)
    return s


rw('sim/core/fighter_data.gd', fdata)

# ---------------------------------------------------------------- ladder data and schema
for who in ['KAI', 'VORR']:
    p = R + 'data/fighters/%s/ladder.json' % who
    t = open(p, encoding='utf-8', newline='').read()
    cr = '\r\n' in t
    t = t.replace('\r\n', '\n')
    if '"reach"' not in t:
        t = rep(t, '  "beam": {', '  "reach": {\n    "structure": [1.0, 1.0, 1.6, 2.8],\n    "ringCap": -1,\n    "_note": "high-tier structure reach (docs/world/structure-reach.md): the area in which impacts, power-ups, clashes and blasts damage structures grows by tier (the whole blast scales); ringCap is a per-blast cap on buildings levelled beyond the old reach, -1 for none"\n  },\n  "beam": {')
    if cr:
        t = t.replace('\n', '\r\n')
    open(p, 'w', encoding='utf-8', newline='').write(t)

p = R + 'tools/schemas/fighter-ladder.schema.json'
t = open(p, encoding='utf-8', newline='').read()
cr = '\r\n' in t
t = t.replace('\r\n', '\n')
if '"reach"' not in t:
    a = '    "beam": {\n      "type": "object",'
    b = '''    "reach": {
      "type": "object",
      "required": [
        "structure",
        "ringCap"
      ],
      "description": "High-tier structure reach (docs/world/structure-reach.md): structure is the factor on the area in which impacts, power-ups, clashes and blasts damage structures, one per tier; ringCap the buildings one blast may level beyond the old reach, -1 for no cap.",
      "properties": {
        "structure": {
          "type": "array",
          "minItems": 4,
          "maxItems": 4,
          "items": {
            "type": "number",
            "minimum": 1,
            "maximum": 6
          }
        },
        "ringCap": {
          "type": "integer",
          "minimum": -1
        }
      },
      "additionalProperties": false,
      "patternProperties": {
        "^_": true
      }
    },
'''
    assert a in t
    t = t.replace(a, b + a, 1)
if cr:
    t = t.replace('\n', '\r\n')
open(p, 'w', encoding='utf-8', newline='').write(t)
print('g1_reach ok')
