"""Apply the whole scratch build to a fresh HEAD export: G1 and reach, the freeze, G2 and G3, and their probe sections.
Usage: python build.py <repo root> <gpatch dir> [enable]"""
import sys, subprocess
root = sys.argv[1]
gp = sys.argv[2].rstrip('/') + '/'
enable = len(sys.argv) > 3 and sys.argv[3] == 'enable'
for scr, args in [('g1_reach.py', [root]), ('g1_freeze.py', [root]), ('g2_contact.py', [root, gp])]:
    subprocess.check_call([sys.executable, gp + scr] + args)
p = root.rstrip('/') + '/sim/world/tools/probe.gd'
s = open(p, encoding='utf-8', newline='').read()
mark = '\n\tprint("")\n\tprint("probe: %d check(s) failed" % fails)'
for f in ['probe_g1.txt', 'probe_g2.txt']:
    ins = open(gp + f, encoding='utf-8').read()
    assert mark in s
    s = s.replace(mark, ins + mark, 1)
a = "if S10.water[i] >= WorldWater.HIDE_MIN_DEPTH and S10.base[i] >= WorldWater.RESERVOIR_BASE:"
if a in s:
    s = s.replace(a, "if S10.water[i] >= WorldWater.HIDE_MIN_DEPTH + 20.0 and S10.base[i] >= WorldWater.RESERVOIR_BASE:", 1)
open(p, 'w', encoding='utf-8', newline='').write(s)
if enable:
    c = root.rstrip('/') + '/data/biomes/contact.json'
    t = open(c, encoding='utf-8').read().replace('"enabled": false', '"enabled": true')
    open(c, 'w', encoding='utf-8').write(t)
print('build ok')
