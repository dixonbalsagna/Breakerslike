# L0 step B: the new fields join the hash, in two parts. Usage: python l0_b.py <repo root> state|events
#   state   the new state fields. Regenerate the goldens: the light digests must not move (golden_cmp.py).
#   events  the events' new fields (z, the launch's direction). The light digest folds the events, so it moves here by design.
import os, sys
os.chdir(sys.argv[1])
part=sys.argv[2]
assert part in ('state','events')
p='sim/core/hash.gd'
s=open(p,encoding='utf-8').read()
def rep(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a))
    s=s.replace(a,b)
STATE=[
 ('"aimB", "aimX0", "aimZ0", "aimZ1", "aimD", "chainEvt", "z",\n','"aimB", "aimX0", "aimZ0", "aimZ1", "aimD", "chainEvt", "z", "zT", "zWay",\n'),
 ('\t\t\tout.append("pt"); out.append(r.px); out.append(r.py); out.append(r.end)','\t\t\tout.append("pt"); out.append(r.px); out.append(r.py); out.append(r.end); out.append(r.pz)'),
 ('_obj(out, ex, ["kind", "t", "combo", "tag", "windowStart", "cancel", "sA", "sD", "loser"])','_obj(out, ex, ["kind", "t", "combo", "tag", "windowStart", "cancel", "sA", "sD", "loser", "z"])'),
 ('"variant", "col", "pw", "struck", "sf", "cap", "levelled"]','"variant", "col", "pw", "struck", "sf", "cap", "levelled", "oz", "zs"]'),
 ('const SLIDE: Array = ["x0", "x1", "hw", "depth", "energy", "t", "owner", "surface", "pop"]','const SLIDE: Array = ["x0", "x1", "hw", "depth", "energy", "t", "owner", "surface", "pop", "z0", "z1"]'),
 ('\t_obj(out, S.pause, ["left", "kind", "version", "actor", "bank", "acc", "sinceEnd", "seen", "total", "count"])   # Q10\n','\t_obj(out, S.pause, ["left", "kind", "version", "actor", "bank", "acc", "sinceEnd", "seen", "total", "count"])   # Q10\n\tout.append(S.depthOn)   # fight lanes (L0)\n'),
]
EVENTS=[
 ('"spark": ["x", "y", "n", "col", "spd"]','"spark": ["x", "y", "n", "col", "spd", "z"]'),
 ('"ring": ["x", "y", "gr", "col", "life", "r0"]','"ring": ["x", "y", "gr", "col", "life", "r0", "z"]'),
 ('"debris": ["x", "y", "n", "col", "spd"]','"debris": ["x", "y", "n", "col", "spd", "z"]'),
 ('"dust": ["x", "y", "n", "col"]','"dust": ["x", "y", "n", "col", "z"]'),
 ('"splash": ["x", "y", "n"]','"splash": ["x", "y", "n", "z"]'),
 ('"fire": ["x", "y", "n"]','"fire": ["x", "y", "n", "z"]'),
 ('"after": ["x", "y", "life", "col", "face"]','"after": ["x", "y", "life", "col", "face", "z"]'),
 ('"charge": ["x", "y", "col", "ground"]','"charge": ["x", "y", "col", "ground", "z"]'),
 ('"beamSplash": ["x"]','"beamSplash": ["x", "z"]'),
 ('"damage": ["x", "y", "amount", "col", "attacker", "victim", "region", "kind", "number"]','"damage": ["x", "y", "amount", "col", "attacker", "victim", "region", "kind", "number", "z"]'),
 ('"scorch": ["x", "y", "w", "power", "variant", "owner"]','"scorch": ["x", "y", "w", "power", "variant", "owner", "z"]'),
 ('"slide": ["x", "x1", "w", "depth", "energy", "variant", "owner", "pop"]','"slide": ["x", "x1", "w", "depth", "energy", "variant", "owner", "pop", "z", "z1"]'),
 ('"slide_dust": ["x", "y", "spd", "w", "variant", "n"]','"slide_dust": ["x", "y", "spd", "w", "variant", "n", "z"]'),
 ('"skim": ["x", "y", "spd", "n"]','"skim": ["x", "y", "spd", "n", "z"]'),
 ('"shake": ["k", "x"]','"shake": ["k", "x", "z"]'),
 ('"launch": ["actor", "target", "amount", "face"]','"launch": ["actor", "target", "amount", "face", "ux", "uy", "n"]'),
]
for a,b in (STATE if part=='state' else EVENTS):
    rep(a,b)
open(p,'w',encoding='utf-8',newline='\n').write(s)
print("L0 step B applied:", part)
