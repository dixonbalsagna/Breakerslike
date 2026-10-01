"""Apply G2 to G5 (rebased on L0 and L2) to a fresh HEAD export: python build2.py <root> <gpatch dir> [enable]"""
import sys, subprocess
root = sys.argv[1]
gp = sys.argv[2].rstrip('/') + '/'
enable = len(sys.argv) > 3 and sys.argv[3] == 'enable'
subprocess.check_call([sys.executable, gp + 'g2_contact_v2.py', root, gp])
p = root.rstrip('/') + '/sim/world/tools/probe.gd'
s = open(p, encoding='utf-8', newline='').read()
mark = '\n\tprint("")\n\tprint("probe: %d check(s) failed" % fails)'
ins = open(gp + 'probe_g2.txt', encoding='utf-8').read()
assert mark in s
if 'G2: ground contact' not in s:
    s = s.replace(mark, ins + mark, 1)
open(p, 'w', encoding='utf-8', newline='').write(s)
if enable:
    c = root.rstrip('/') + '/data/biomes/contact.json'
    t = open(c, encoding='utf-8').read().replace('"enabled": false', '"enabled": true')
    open(c, 'w', encoding='utf-8').write(t)
print('build2 ok')
