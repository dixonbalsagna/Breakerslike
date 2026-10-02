import sys,json
R=sys.argv[1].rstrip('/')+'/'
p=R+'sim/world/contact.gd'
s=open(p,encoding='utf-8',newline='').read()
nl='\r\n' if '\r\n' in s else '\n'
s=s.replace('\r\n','\n')
def rep(old,new):
    global s
    assert s.count(old)==1, old[:80]
    s=s.replace(old,new,1)
rep('static var K_GMUL: float = 1.0 ','static var K_FUR: Array = [1.0, 0.0, 1.0, 0.0, 1.0, 1.0]\nstatic var K_GMUL: float = 1.0 ')
rep('	K_GMUL = float(D.bounce.get("gravityMul", 1.0))\n','	K_GMUL = float(D.bounce.get("gravityMul", 1.0))\n	var fu: Dictionary = D.get("furrow", {})\n	K_FUR = [float(fu.get("depthMul", 1.0)), float(fu.get("tumble", 0.0)), float(fu.get("dMaxMul", 1.0)), float(fu.get("tierMul", 0.0)), float(fu.get("bermMul", 1.0)), float(fu.get("pathMul", 1.0))]\n')
rep('''	var depth: float = minf(WorldSlide.D_MAX, WorldSlide.D0 + WorldSlide.D_V * b.vN)
	if b.mode == SKID:
		WorldCrater.carveSegment(S, xa, f.x, depth, pav, WorldSlide.CRACK0 + WorldSlide.CRACK_E * sqrt(E), f.z)''','''	var tierF: float = 1.0 + K_FUR[3] * (by.tier - 1.0)
	var depth: float = minf(WorldSlide.D_MAX * K_FUR[2], (WorldSlide.D0 + WorldSlide.D_V * K_FUR[0] * b.vN) * tierF)
	if b.mode == SKID:
		WorldCrater.carveSegment(S, xa, f.x, depth, pav, WorldSlide.CRACK0 + WorldSlide.CRACK_E * sqrt(E), f.z)
	elif K_FUR[1] > 0.0:
		WorldCrater.carveSegment(S, xa, f.x, depth * K_FUR[1], pav, 0.0, f.z)''')
rep('(0.22 + 0.12 * by.tier) * WorldSlide.PATH_AREA * b.vN, by, false, f.slideEvt)','(0.22 + 0.12 * by.tier) * WorldSlide.PATH_AREA * K_FUR[5] * b.vN, by, false, f.slideEvt)')
rep('minf(WorldSlide.D_MAX, WorldSlide.D0 + WorldSlide.D_V * f.jV0 * 0.25) * WorldSlide.BERM, f.z)','minf(WorldSlide.D_MAX * K_FUR[2], (WorldSlide.D0 + WorldSlide.D_V * K_FUR[0] * f.jV0 * 0.25) * (1.0 + K_FUR[3] * (by.tier - 1.0))) * WorldSlide.BERM * K_FUR[4], f.z)')
open(p,'w',encoding='utf-8',newline='').write(s.replace('\n',nl))
fu=json.loads(sys.argv[2]) if len(sys.argv)>2 else {}
pj=R+'data/biomes/contact.json'
d=json.load(open(pj,encoding='utf-8')); d['furrow']=fu
open(pj,'w',encoding='utf-8').write(json.dumps(d,indent=2)+'\n')
print('furrow patch ok')
