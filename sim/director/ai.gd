class_name DirAI
## Opponent AI (Encounter Systems): born as the twin of ai.js (pickW, aiInput); since ADR 0006 it has its own tempo and
## fight-location rules (balance-targets.md section 10): a slower attack cadence, the hero's lure toward empty land
## instead of the sea, fighters who stay at the surface unless hiding, and escape cover that prefers forest and ridge.
## Timers count down by the fixed DT.


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
	# The attack timer runs only between exchanges and is held at the stance minimum during one, so the cadence is
	# breathing room after a release.
	if S.dirS.ex == null:
		a.atk -= SimConst.DT
	else:
		a.atk = SimMathx.jmax(a.atk, CAD_MIN[int(f.stance)])
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
	# The hero leads fights away from people and out of the water, toward the nearest empty land.
	# A DEFENSIVE hero low on ki charges first (the lure used to starve it of ki).
	var wantsCharge: bool = st == 1.0 and f.ki < 55.0 and dist > 350.0
	var lure: float = heroLure(S, f) if f.role == "hero" and st != 3.0 and not wantsCharge else 0.0
	var sea: bool = WorldTerrain.seaAt(S, f.x)
	if lure != 0.0:
		i.mx = lure
		i.dash = true
		i.my = 1.0 if sea and f.y < SURFACE_Y else 0.0
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
		# Sweep low over land; over the sea, sweep at the surface rather than diving.
		i.my = -1.0 if not sea else (1.0 if f.y < SURFACE_Y else 0.0)
	elif st == 0.0:
		i.mx = SimMathx.jsign(d) if dist > 130.0 else 0.0
		i.dash = dist > 700.0
		# Close in on the opponent's height, but not below the surface: underwater is for hiding, not fighting.
		var ty: float = SimMathx.jmax(o.y, SURFACE_Y) if sea else o.y
		var dy: float = ty - f.y
		i.my = SimMathx.jsign(dy) if absf(dy) > 40.0 else 0.0
	elif st == 1.0:
		i.mx = 0.0
		if sea and f.y < 0.0:
			i.my = 1.0
		if f.ki < 55.0 and dist > 350.0:
			i.charge = true
	elif st == 2.0:
		i.mx = -SimMathx.jsign(d) if dist < 500.0 else SimMathx.jsign(d) * 0.5
		i.my = 1.0 if sea and f.y < 0.0 else SimDetMath.sin(S.T * 1.7 + f.x * 0.01)
	else:
		# Escape: head for cover (forest and ridge preferred over water, away from the opponent), then sink into it.
		var c = chooseCover(f.x, d)
		if c != null and absf(c.off) > 60.0:
			i.mx = SimMathx.jsign(c.off)
			i.dash = absf(c.off) > 300.0
			if sea and f.y < 0.0:
				i.my = 1.0
		else:
			i.mx = 0.0
			var g: float = WorldTerrain.groundY(S, f.x)
			if c != null and c.b == "ocean":
				i.my = -1.0 if f.y > -110.0 else 0.0
			else:
				i.my = -1.0 if f.y > g + 20.0 else 0.0
	# Underwater and not hiding there: dash for the surface (underwater is a hiding state, not a place to fight).
	if sea and f.y < 0.0 and i.my > 0.0:
		i.dash = true
	if a.atk <= 0.0 and not o.hidden and st != 3.0 and S.dirS.ex == null:
		# Each attack beat either attacks or holds (repositions, charges): holding fills the downtime between exchanges.
		var r: float = S.rng.next()
		var pa: float = P_ATTACK[int(st)]
		# No lull over about 10 s: once neither fighter has attacked for GAP_URGE seconds, attack beats stop holding.
		if S.T - SimMathx.jmax(f.lastAtkT, o.lastAtkT) > GAP_URGE:
			pa = 1.0
		if r < pa:
			var q: float = r / pa
			if f.ki >= 50.0 and q < 0.2:
				i.sig = true
			elif q < 0.5:
				i.heavy = true
			else:
				i.light = true
		# Attack cadence (balance-targets.md section 10): AGGRESSIVE every 1.2 to 2.5 s, the others scaled to match.
		# Was 0.35 to 1.0 s, 1.2 to 2.5 s and 0.9 to 1.8 s.
		a.atk = S.rng.range_(1.2, 2.5) if st == 0.0 else (S.rng.range_(2.0, 3.6) if st == 1.0 else S.rng.range_(1.6, 3.0))
	elif a.atk <= 0.0:
		a.atk = 0.3


# Tempo (balance-targets.md section 10).
const P_ATTACK: Array = [0.62, 0.5, 0.56, 0.5]   # chance an attack beat attacks, per stance (ESCAPE never attacks)
const GAP_URGE: float = 6.0                      # seconds without an attack press from either fighter
const CAD_MIN: Array = [1.2, 2.0, 1.6, 1.6]      # attack-timer floor per stance while an exchange runs

# Fight location (balance-targets.md section 10). Underwater is a hiding state, not a place to fight.
const SURFACE_Y: float = 150.0         # over the sea, fighters who are not hiding hold at or above this height
const LURE_EMPTY: float = 0.1          # popNear(x, 900) at or below this, on land, is empty ground the hero leads to
const LURE_START: float = 0.2          # the hero lures while over the sea or while popNear(f.x, 900) is above this
const LURE_STEP: float = 200.0 * SimConst.PS
const LURE_POP_W: float = 2.0          # route cost: distance + this x the population crossed (popNear x step)
const LURE_KEEP: float = 800.0 * SimConst.PS         # route cost discount for the way the hero is already moving (no dithering)
const COVER_OCEAN: float = 1500.0 * SimConst.PS      # cover cost: water counts as this much farther than forest or ridge
const COVER_PAST_OPP: float = 1200.0 * SimConst.PS   # cover cost: running toward and past the opponent
const COVER_REACH: float = 4000.0 * SimConst.PS   # cover farther than this is not considered
const COVER_EDGE: float = 100.0                  # stepping just inside a biome entered from its far end
const LURE_BUCKETS: int = 48           # SimConst.W / LURE_STEP
const LURE_WINDOW: int = 2             # +-2 buckets (of LURE_STEP) approximate popNear(x, 900 * WS): round(900 * WS / LURE_STEP)


## The hero's lure: +1 or -1 to head for the nearest empty land (not sea, population at most LURE_EMPTY), by the
## cheaper route (distance plus population crossed), or 0 when the hero already stands on empty-enough land. Population
## comes from a histogram of the planet in LURE_STEP buckets; a bucket's window of +-LURE_WINDOW buckets estimates
## popNear(x, 900 x WS). One pass over the buildings and one over the biome table per call, so it is cheap every tick.
static func heroLure(S: SimState, f) -> float:
	# Hot path (every tick while the hero is off empty land): plain arithmetic, no helper calls inside the loops.
	var hist := PackedFloat64Array()
	hist.resize(LURE_BUCKETS)
	for b in S.buildings:
		if b.alive:
			hist[mini(int(b.x / LURE_STEP), LURE_BUCKETS - 1)] += b.popAlive
	var i0: int = mini(int(SimWrap.wrap(f.x) / LURE_STEP), LURE_BUCKETS - 1)
	if not WorldTerrain.seaAt(S, f.x) and WorldBiomes.biomeAt(f.x) != "ocean" and _window(hist, i0) <= LURE_START:
		return 0.0
	var seg: Array = WorldBiomes.SEG
	var best: float = 0.0
	var bestCost: float = 1e9
	for s in [1, -1]:
		var popCost: float = 0.0
		var idx: int = i0
		for n in range(1, LURE_BUCKETS):
			idx += s
			if idx < 0:
				idx += LURE_BUCKETS
			elif idx >= LURE_BUCKETS:
				idx -= LURE_BUCKETS
			var p: float = _window(hist, idx)
			if p <= LURE_EMPTY:
				# Land at the bucket's centre: not the ocean biome and not below the sea line.
				var x: float = idx * LURE_STEP + LURE_STEP / 2.0
				var ocean: bool = true
				for sg in seg:
					if x >= sg[0] and x < sg[1]:
						ocean = sg[2] == "ocean"
						break
				if not ocean and not S.base[int(x / SimConst.COL)] < WorldWater.RESERVOIR_BASE:
					var cost: float = n * LURE_STEP + LURE_POP_W * popCost - (LURE_KEEP if SimMathx.jsign(f.vx) == float(s) else 0.0)
					if cost < bestCost:
						bestCost = cost
						best = float(s)
					break
			popCost += p * LURE_STEP
	return best


## Population within +-LURE_WINDOW buckets of bucket i, as popNear reads it (70 or more is 1).
static func _window(hist: PackedFloat64Array, i: int) -> float:
	var sum: float = 0.0
	for k in range(i - LURE_WINDOW, i + LURE_WINDOW + 1):
		sum += hist[k + LURE_BUCKETS if k < 0 else (k - LURE_BUCKETS if k >= LURE_BUCKETS else k)]
	return minf(sum / WorldStructures.POP_NEAR_REF, 1.0)


## Escape cover: the nearest way into ocean, forest or mountains in each direction, out to COVER_REACH, costed by
## distance, plus COVER_OCEAN for water and COVER_PAST_OPP when the opponent is on the way. {"off", "b"} or null.
## d is the signed shortest-arc distance to the opponent. Computed from the biome table (static layout only).
static func chooseCover(x: float, d: float):
	var best = null
	var bestCost: float = 1e9
	var xw: float = SimWrap.wrap(x)
	var here: String = WorldBiomes.biomeAt(xw)
	for s in [1.0, -1.0]:
		for b in ["ocean", "forest", "mountains"]:
			var off: float = 1e9
			if here == b:
				off = 0.0
			else:
				for seg in WorldBiomes.SEG:
					if seg[2] == b:
						# Forward: to the segment's start. Backward: to just inside its end (the end is exclusive).
						var o: float = SimWrap.wrap(seg[0] - xw) if s > 0.0 else SimWrap.wrap(xw - seg[1]) + COVER_EDGE
						off = SimMathx.jmin(off, o)
			if off > COVER_REACH:
				continue
			var cost: float = off + (COVER_OCEAN if b == "ocean" else 0.0)
			if off > 60.0 and SimMathx.jsign(d) == s and absf(d) < off:
				cost += COVER_PAST_OPP
			if cost < bestCost:
				bestCost = cost
				best = {"off": s * off, "b": b}
	return best
