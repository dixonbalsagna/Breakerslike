"""G1 part: a slide's trench never relaxes the column the fighter stands on or the ground ahead of him (it would drop away beneath
him, and the leave test would read it as a lip of his own making). Usage: python g1_freeze.py <repo root>"""
import sys
R = sys.argv[1].rstrip('/') + '/'
p = R + 'sim/world/crater.gd'
s = open(p, encoding='utf-8', newline='').read()
cr = '\r\n' in s
s = s.replace('\r\n', '\n')


def rep(old, new):
    global s
    assert old in s, old[:80]
    s = s.replace(old, new, 1)


rep("static func relax(S: SimState, c0: int, half: int) -> float:",
    "static func relax(S: SimState, c0: int, half: int, freezeFrom: int = 0, freezeDir: int = 0) -> float:")
rep("	var pin: PackedByteArray = WorldStructures.pinned(S, c0, half)   # a standing building's footing is never moved\n",
    "	var pin: PackedByteArray = WorldStructures.pinned(S, c0, half)   # a standing building's footing is never moved\n"
    "	if freezeDir != 0:   # columns from freezeFrom on, in this direction, are not touched at all (value 2)\n"
    "		for kf in range(cnt):\n"
    "			var cf: int = posmod(lo + kf, NC)\n"
    "			if posmod((cf - freezeFrom) * freezeDir, NC) < NC / 2:\n"
    "				pin[kf] = 2\n")
rep("				if pin[kk + 1 if lw == j else kk] == 1:\n					continue   # a footing may be lowered but never raised\n",
    "				if pin[kk] == 2 or pin[kk + 1] == 2:\n					continue\n"
    "				if pin[kk + 1 if lw == j else kk] == 1:\n					continue   # a footing may be lowered but never raised\n")
rep("		minG = minf(minG, relax(S, mid, half))\n", "		minG = minf(minG, relax(S, mid, half, cb, dir))\n")
if cr:
    s = s.replace('\n', '\r\n')
open(p, 'w', encoding='utf-8', newline='').write(s)
print('freeze ok')
