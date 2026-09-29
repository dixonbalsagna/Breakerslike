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
	if a.atk <= 0.0 and not o.hidden and st != 3.0 and S.dirS.ex == null:
		# Each attack beat either attacks or holds (repositions, charges): holding fills the downtime between exchanges.
		var r: float = S.rng.next()
		var pa: float = P_ATTACK[int(st)]
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
const P_ATTACK: Array = [0.55, 0.45, 0.5, 0.5]   # chance an attack beat attacks, per stance (ESCAPE never attacks)
const CAD_MIN: Array = [1.2, 2.0, 1.6, 1.6]      # attack-timer floor per stance while an exchange runs

# Fight location (balance-targets.md section 10). Underwater is a hiding state, not a place to fight.
const SURFACE_Y: float = 30.0          # over the sea, fighters who are not hiding hold at or above this height
const LURE_EMPTY: float = 0.1          # popNear(x, 900) at or below this, on land, is empty ground the hero leads to
const LURE_START: float = 0.2          # the hero lures while over the sea or while popNear(f.x, 900) is above this
const LURE_STEP: float = 200.0 * SimConst.PS
const LURE_POP_W: float = 2.0          # route cost: distance + this x the population crossed (popNear x step)
const LURE_KEEP: float = 800.0 * SimConst.PS         # route cost discount for the way the hero is already moving (no dithering)
const COVER_OCEAN: float = 1500.0 * SimConst.PS      # cover cost: water counts as this much farther than forest or ridge
const COVER_PAST_OPP: float = 1200.0 * SimConst.PS   # cover cost: running toward and past the opponent
const LURE_BUCKETS: int = 48           # SimConst.W / LURE_STEP
const LURE_WINDOW: int = 2             # +-2 buckets (of LURE_STEP) approximate popNear(x, 900 * WS): round(900 * WS / LURE_STEP)


## The hero's lure: +1 or -1 to head for the nearest empty land (not sea, population at most LURE_EMPTY), by the
## cheaper route (distance plus population crossed), or 0 when the hero already stands on empty-enough land. The route
## scan walks the whole planet in LURE_STEP buckets, with population from a bucket histogram (a window of +-4 buckets
## approximates popNear(x, 900)), so it stays cheap enough to run every tick.
static func heroLure(S: SimState, f) -> float:
	if not WorldTerrain.seaAt(S, f.x) and WorldBiomes.biomeAt(f.x) != "ocean" and WorldStructures.popNear(S, f.x, 900.0 * SimConst.WS) <= LURE_START:
		return 0.0
	var hist: Array = []
	hist.resize(LURE_BUCKETS)
	hist.fill(0.0)
	for b in S.buildings:
		if b.alive:
			var bi: int = int(floor(SimWrap.wrap(b.x) / LURE_STEP)) % LURE_BUCKETS
			hist[bi] += b.popAlive
	# Population within +-LURE_WINDOW buckets of each bucket, summed afresh per bucket (no running sum, so no drift).
	var near: Array = []
	near.resize(LURE_BUCKETS)
	for idx in range(LURE_BUCKETS):
		var sum: float = 0.0
		for k in range(-LURE_WINDOW, LURE_WINDOW + 1):
			sum += hist[((idx + k) % LURE_BUCKETS + LURE_BUCKETS) % LURE_BUCKETS]
		near[idx] = SimMathx.jclamp(sum / WorldStructures.POP_NEAR_REF, 0.0, 1.0)
	var i0: int = int(floor(SimWrap.wrap(f.x) / LURE_STEP)) % LURE_BUCKETS
	var best: float = 0.0
	var bestCost: float = 1e9
	for s in [1, -1]:
		var popCost: float = 0.0
		for n in range(1, LURE_BUCKETS):
			var idx: int = ((i0 + s * n) % LURE_BUCKETS + LURE_BUCKETS) % LURE_BUCKETS
			var p: float = near[idx]
			var x: float = idx * LURE_STEP + LURE_STEP / 2.0
			if p <= LURE_EMPTY and WorldBiomes.biomeAt(x) != "ocean" and not WorldTerrain.seaAt(S, x):
				var cost: float = n * LURE_STEP + LURE_POP_W * popCost - (LURE_KEEP if SimMathx.jsign(f.vx) == float(s) else 0.0)
				if cost < bestCost:
					bestCost = cost
					best = float(s)
				break
			popCost += p * LURE_STEP
	return best


## Escape cover: the nearest start of ocean, forest or mountains in each direction (100-unit steps out to 4000), costed
## by distance, plus COVER_OCEAN for water and COVER_PAST_OPP when the opponent is on the way. {"off", "b"} or null.
## d is the signed shortest-arc distance to the opponent. Static layout only.
static func chooseCover(x: float, d: float):
	var best = null
	var bestCost: float = 1e9
	for s in [1.0, -1.0]:
		var seen := {}
		var off: float = 0.0
		while off <= 4000.0 * SimConst.PS:
			var b: String = WorldBiomes.biomeAt(x + s * off)
			if (b == "ocean" or b == "forest" or b == "mountains") and not seen.has(b):
				seen[b] = true
				var cost: float = off + (COVER_OCEAN if b == "ocean" else 0.0)
				if off > 60.0 and SimMathx.jsign(d) == s and absf(d) < off:
					cost += COVER_PAST_OPP
				if cost < bestCost:
					bestCost = cost
					best = {"off": s * off, "b": b}
			off += 100.0 * SimConst.PS
	return best
