import sys, json
R = sys.argv[1].rstrip('/') + '/'
def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = fn(s.replace('\r\n', '\n'))
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)
def rep(s, a, b):
    assert s.count(a) == 1, a[:80]
    return s.replace(a, b)
def crater(s):
    return s.rstrip('\n') + '''


## A mark on the ground and nothing else (a missed power-1 shot, docs/design/agency-pass.md section 14 item 6): raise the burn paint over
## half width hw to intensity inten and emit the scorch event. No groove, no crater, no structure damage; the paint is one row, so no depth rows.
static func mark(S: SimState, x: float, hw: float, inten: float, variant: String, cause, z: float = 0.0) -> void:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var c0: int = _col(x)
	var n: int = int(ceil(hw / COL))
	var inv: float = COL / hw
	var scm: PackedFloat32Array = S.scorch
	for k in range(-n, n + 1):
		var u: float = absf(float(k)) * inv
		if u >= 1.0:
			continue
		var t: float = 1.0 - u * u
		var i: int = (c0 + k + NC) % NC
		var sc: float = inten * t
		if sc > scm[i]:
			scm[i] = sc
	S.scorch = scm
	SimFx.scorchEvent(S, x, WorldTerrain.groundY(S, x, z), hw * 2.0, 0.0, variant, _slot(S, cause), z)
'''
rw('sim/world/crater.gd', crater)
def blast(s):
    s = rep(s, 'static func shotHit(S: SimState, slot: int, kind: String, x: float, y: float, z: float, vx: float, vy: float, cause: String) -> Dictionary:',
            'static func shotHit(S: SimState, slot: int, kind: String, x: float, y: float, z: float, vx: float, vy: float, cause: String, power: float = 3.0) -> Dictionary:')
    s = rep(s, '	var g: float = WorldTerrain.groundY(S, x, z)\n	var sp: float',
'''	var g: float = WorldTerrain.groundY(S, x, z)
	if power < float(D.get("structureMinPower", 2.0)):   # a shot of power 1 that missed: a scorch mark, no crater, no structure damage (agency-pass section 14 item 6)
		WorldCrater.mark(S, x, float(k.get("markHw", 40.0)), float(k.get("markInten", 0.5)), kind, f, z)
		SimFx.dust(S, x, g, int(k.dust), "", z)
		return res
	var sp: float''')
    return s
rw('sim/world/blast.gd', blast)
def shots(s):
    return rep(s, 'sh.vx, sh.vy, cause)   # World', 'sh.vx, sh.vy, cause, sh.power)   # World')
rw('sim/core/shots.gd', shots)
p = R + 'data/biomes/blast.json'
d = json.load(open(p, encoding='utf-8'))
d['structureMinPower'] = 2.0
d['kinds']['bolt'].update(markHw=45, markInten=0.5)
d['kinds']['shard'].update(markHw=35, markInten=0.4)
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')
print('ok')
