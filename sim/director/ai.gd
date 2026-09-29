class_name DirAI
## Opponent AI: the twin of ai.js (pickW, aiInput). Timers count down by the fixed DT, as in JS.


## Index drawn with probability proportional to its weight. One draw from S.rng.
static func pickW(S: SimState, w: Array) -> int:
	var s: float = 0.0
	for v in w:
		s += v
	var r: float = S.rng.next() * s
	for k in range(w.size()):
		r -= w[k]
		if r <= 0.0:
			return k
	return 0


static func aiInput(S: SimState, f) -> void:
	var o = SimRoster.opp(S, f)
	var i: SimIntent = f.input
	var a = f.ai
	var d: float = SimWrap.sdx(f.x, o.x)
	var dist: float = absf(d)
	var hpF: float = f.hp / f.maxhp
	a.t -= SimConst.DT
	a.atk -= SimConst.DT
	if a.t <= 0.0:
		a.t = S.rng.range_(0.7, 1.6)
		var w: Array = [2.4 if hpF > 0.35 else 1.0, 1.6 if hpF < 0.55 else 0.7, 1.2, 3.2 if hpF < 0.3 else (1.2 if f.ki < 25.0 else 0.25)]
		if o.hidden:
			w = [3.0, 0.3, 0.3, 0.1]
		if f.hidden and (hpF < 0.85 or f.ki < 85.0):
			w = [0.0, 0.0, 0.0, 1.0]
		if f.state == "free":
			f.stance = float(pickW(S, w))
	var free: bool = f.state == "free" or f.state == "charging"
	if not free:
		return
	var st: float = f.stance
	# The hero leads fights out of populated areas, steering away from the city centre (x 3100).
	var lure: bool = f.role == "hero" and st != 3.0 and WorldStructures.popNear(S, f.x, 900.0) > 0.2
	if lure:
		i.mx = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(3100.0, f.x)), 1.0)
		i.dash = true
		i.my = 0.0
	elif st == 0.0 and o.hidden and o.lastSeen != null:
		# Hunt: sweep random offsets around the last known position, re-rolled every 1.2 to 2.4 s.
		a.sT -= SimConst.DT
		if a.sT <= 0.0:
			a.sT = S.rng.range_(1.2, 2.4)
			a.sOff = S.rng.range_(-1700.0, 1700.0)
		var tx: float = o.lastSeen.x + a.sOff
		var sd: float = SimWrap.sdx(f.x, tx)
		i.mx = SimMathx.jsign(sd) if absf(sd) > 60.0 else 0.0
		i.dash = absf(sd) > 1500.0
		i.my = -1.0
	elif st == 0.0:
		i.mx = SimMathx.jsign(d) if dist > 130.0 else 0.0
		i.dash = dist > 700.0
		var dy: float = o.y - f.y
		i.my = SimMathx.jsign(dy) if absf(dy) > 40.0 else 0.0
	elif st == 1.0:
		i.mx = 0.0
		if f.ki < 55.0 and dist > 350.0:
			i.charge = true
	elif st == 2.0:
		i.mx = -SimMathx.jsign(d) if dist < 500.0 else SimMathx.jsign(d) * 0.5
		i.my = SimDetMath.sin(S.T * 1.7 + f.x * 0.01)
	else:
		# Escape: head for the nearest cover biome, then sink into it.
		var c = WorldCover.nearestCover(f.x)
		if c != null and absf(c.off) > 60.0:
			i.mx = SimMathx.jsign(c.off)
			i.dash = absf(c.off) > 300.0
		else:
			i.mx = 0.0
			var g: float = WorldTerrain.groundY(S, f.x)
			if c != null and c.b == "ocean":
				i.my = -1.0 if f.y > -110.0 else 0.0
			else:
				i.my = -1.0 if f.y > g + 20.0 else 0.0
	if a.atk <= 0.0 and not o.hidden and st != 3.0 and S.dirS.ex == null:
		var r: float = S.rng.next()
		if f.ki >= 50.0 and r < 0.2:
			i.sig = true
		elif r < 0.5:
			i.heavy = true
		else:
			i.light = true
		a.atk = S.rng.range_(0.35, 1.0) if st == 0.0 else (S.rng.range_(1.2, 2.5) if st == 1.0 else S.rng.range_(0.9, 1.8))
	elif a.atk <= 0.0:
		a.atk = 0.3
