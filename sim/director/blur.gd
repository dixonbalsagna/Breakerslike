class_name DirBlur
## The blur string (docs/design/agency-pass.md section 20; docs/director/alchemy-plan.md A3; Combat's
## docs/combat/alchemist-recipes.md section 6). A string that starts on a light press in the blur style draws a cadence
## (the ticks between its blows) and a pattern (the order of limbs and targets) when it starts. Both are keyed draws on
## the match seed and the exchange, so no stream shifts and a replay matches.
##  - The cadence: the chain window opens on the blow, and a link whose press is waiting lands its blow one cadence
##    after the last; a press that comes later lands minLeadTicks after it. The first two blows show the cadence.
##  - The lock: Controls' steady read (SimPressRead: steadyPresses presses in a row, each within blurBeatHalf ticks of
##    a different blow's contact) locks the blur in for the rest of the string: each strike does a full light's damage
##    (a plain blur's does launch.json blur.strikeMul), and the ender is the full one.
##  - A heavy press in the string ends the blur: the link plays on the template's own timing.
## It never launches, in either form. State: the attacker's director integers (DirAlchemy.BLUR_*). Numbers:
## data/director/alchemy.json `blur`.


static func cfg() -> Dictionary:
	return DirRecipe.cfg().get("blur", {})


static func on() -> bool:
	return DirInterrupt.on() and cfg().get("enabled", false)


## True while f is the attacker of a live blur string.
static func live(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	return ex != null and ex.A == f and f.act.dirI.size() > DirAlchemy.BLUR_CAD and f.act.dirI[DirAlchemy.BLUR_CAD] > 0


## True once his blur is locked in.
static func perfect(S: SimState, f) -> bool:
	return live(S, f) and f.act.dirI[DirAlchemy.BLUR_ON] >= _need()


## The presses a lock takes (Controls' steadyPresses).
static func _need() -> int:
	return int(SimPressRead.params().get("steadyPresses", 4))


## The pattern names, in a fixed order (the recipes' own keys, sorted).
static func _patterns() -> Array:
	var bp = DirRecipe.rec().get("blurPatterns", {})
	var out: Array = []
	for k in bp:
		if not String(k).begins_with("_") and bp[k] is Array:
			out.append(String(k))
	out.sort()
	return out


## Whether a pattern may be drawn for this string (the recipes' patternGates): the stick toward, both on the ground,
## his fighter. With the stick toward, the draw is among the patterns gated to toward.
static func _open(S: SimState, ex, pat: String, toward: bool) -> bool:
	var g = DirRecipe.rec().get("patternGates", {}).get(pat)
	if not (g is Dictionary):
		return not toward
	if (String(g.get("stick", "")) == "toward") != toward:
		return false
	if g.get("ground", false):
		for f in [ex.A, ex.D]:
			if f.y - WorldTerrain.groundY(S, f.x) > 0.5 * DirInterrupt.BH:
				return false
	if g.has("fighters") and not (g.fighters as Array).has(DirRecipe.poolKey(ex.A)):
		return false
	return true


## The live tick now: the match clock in ticks (it stops in a hit-stop, as the exchange's clock does).
static func _now(S: SimState) -> int:
	return int(round(S.T * DirData.TICKS_PER_SEC))


## A blow of f's landed (DirMelee.strike): in his blur string, the cadence counts from it.
static func onBlow(S: SimState, f) -> void:
	if live(S, f):
		f.act.dirI[DirAlchemy.BLUR_AT] = _now(S)


## As an exchange starts (DirExchange._start, after its plan): a light press in the blur style starts a blur string.
static func onStart(S: SimState, ex, kind: String) -> void:
	var A = ex.A
	DirAlchemy._size(A)
	for k in [DirAlchemy.BLUR_CAD, DirAlchemy.BLUR_PAT, DirAlchemy.BLUR_STEP, DirAlchemy.BLUR_ON, DirAlchemy.BLUR_U1, DirAlchemy.BLUR_U2, DirAlchemy.BLUR_U3, DirAlchemy.BLUR_U4, DirAlchemy.BLUR_AT]:
		A.act.dirI[k] = 0
	if not on() or kind != "light" or DirExchange.finisherPlanned(ex) or ex.tpl == DirBury.TPL or DirRecipe.style(S, A) != "blur":
		return
	var ts: float = -1.0
	for b in ex.beats:
		if not b.done and b.op == "strike" and b.args != null and String(b.args.get("a", "A")) == "A":
			ts = maxf(ts, b.t)
	if ts < 0.0:
		return
	var cads: Array = cfg().get("cadences", [8])
	var cad: int = int(cads[int(SimRng.keyed(int(S.game.seed), "blur.cadence", S.dirS.exN) * float(cads.size())) % cads.size()])
	A.act.dirI[DirAlchemy.BLUR_CAD] = cad
	var all: Array = _patterns()
	var toward: bool = ((DirInterrupt.gi(A, DirInterrupt.PHRASE_P) >> 2) & 3) == 2
	var pats: Array = []
	for pass2 in [toward, false]:
		if pats.is_empty():
			for p in all:
				if _open(S, ex, p, pass2):
					pats.append(p)
	var pat: String = String(pats[int(SimRng.keyed(int(S.game.seed), "blur.pattern", S.dirS.exN) * float(pats.size())) % pats.size()]) if not pats.is_empty() else ""
	A.act.dirI[DirAlchemy.BLUR_PAT] = (all.find(pat) + 1) if pat != "" else 0
	# The chain window opens on the blow, so a press on the landing has a whole cadence for the next blow: the opener's
	# launch beat and its window move onto its last strike.
	var moved: Array = []
	for i in range(ex.beats.size() - 1, -1, -1):
		var w = ex.beats[i]
		if not w.done and (w.op == "window" or w.op == "launch") and w.t > ts:
			ex.beats.remove_at(i)
			moved.push_front(w)
	for w in moved:
		DirExchange.schedule(ex, ts, String(w.op), w.args)
	SimEvents.feed(S, A.name + " BLUR", "a blow every " + str(cad) + " ticks" + (", the " + pat + " pattern" if pat != "" else ""))


## A link was taken and planned (DirExchange.chain; `before` is the beat list as it was before the plan). In a blur
## string a light link's blow lands one cadence after the last one, or minLeadTicks from now if the press came late; its
## launch beat and its window share the blow's tick. A heavy link ends the blur and keeps the template's timing.
static func onLink(S: SimState, ex, before: Array) -> void:
	var A = ex.A
	if not live(S, A):
		return
	var p: int = DirInterrupt.gi(A, DirInterrupt.PHRASE_P)
	if (p & 1) != SimAct.LIGHT or DirRecipe.style(S, A) != "blur":
		A.act.dirI[DirAlchemy.BLUR_CAD] = 0   # a heavy joined: it is a combo now
		return
	var c: Dictionary = cfg()
	var tps: float = DirData.TICKS_PER_SEC
	var since: int = (_now(S) - A.act.dirI[DirAlchemy.BLUR_AT]) if A.act.dirI[DirAlchemy.BLUR_AT] > 0 else 99
	var lead: int = maxi(int(c.get("minLeadTicks", 5)), A.act.dirI[DirAlchemy.BLUR_CAD] - since)
	var d: float = (float(lead) - 0.25) / tps   # a quarter tick early, so the beat runs on its tick whatever the clock's rounding
	var fresh: Array = []
	for i in range(ex.beats.size() - 1, -1, -1):
		var b = ex.beats[i]
		if b.done:
			continue
		if not before.has(b):
			ex.beats.remove_at(i)
			fresh.push_front(b)
		elif b.op == "rush":
			b.done = true   # the chase after the last blow is dropped: the next blow is already on its way
	var rushed: bool = false
	for b in fresh:
		if b.op == "rush":
			if rushed:
				continue
			rushed = true
			if b.args is Dictionary:
				b.args["dur"] = d
			DirExchange.schedule(ex, ex.t, "rush", b.args)
		else:
			DirExchange.schedule(ex, ex.t + d, String(b.op), b.args)


## A light press of his while his blur string is live (DirAlchemy.log): `hit`, it was on the beat; `steady`, Controls'
## read of a player's log with this press in it. A player's blur locks when the read is steady; the AI's when
## steadyPresses of its presses in a row were on the beat. It stays locked for the string. Returns hit.
static func onPress(S: SimState, f, hit: bool, steady: bool) -> bool:
	var need: int = _need()
	var n: int = f.act.dirI[DirAlchemy.BLUR_ON]
	if n >= need:
		return hit
	n = (n + 1) if hit else 0
	if f.ai == null:
		n = need if steady else mini(n, need - 1)   # a player's lock is Controls' read
	if n >= need:
		SimFx.cue(S, f, "blur_locked", "", "")
		SimEvents.feed(S, f.name + " BLUR LOCKED IN", str(need) + " presses on the beat: full contact, and the full ender")
	f.act.dirI[DirAlchemy.BLUR_ON] = n
	return hit


## The AI's link press in a blur string (DirExchange.openWindow): one draw at its level's timedPress decides whether it
## is on the beat. On it, the press comes with the blow, so its next blow lands on the cadence; off it, at its own delay.
static func aiPress(S: SimState, ex, args: Dictionary) -> bool:
	if not live(S, ex.A):
		return false
	args["onBeat"] = S.rng.next() < float(DirAI.lv().get("timedPress", 0.0))
	return args.onBeat


## His pattern's step k, [limb, target]; [] with no pattern.
static func _step(f, k: int) -> Array:
	if f.act.dirI[DirAlchemy.BLUR_PAT] <= 0:
		return []
	var pats: Array = _patterns()
	var pat = DirRecipe.rec().get("blurPatterns", {}).get(pats[f.act.dirI[DirAlchemy.BLUR_PAT] - 1])
	if not (pat is Array) or pat.is_empty():
		return []
	return pat[((k % pat.size()) + pat.size()) % pat.size()]


## The piece for the string's next blow, by its pattern: the step's limb and target, from his blur pools, and not one
## the string has used while another fits. "" when there is no pattern, no `pieces` table, or nothing fits (the caller
## picks as usual).
static func piece(S: SimState, f, toward: bool) -> String:
	if not live(S, f):
		return ""
	var rec: Dictionary = DirRecipe.rec()
	var pieces = rec.get("pieces")
	var k: int = f.act.dirI[DirAlchemy.BLUR_STEP]
	var step: Array = _step(f, k)
	if not (pieces is Dictionary) or step.is_empty():
		return ""
	f.act.dirI[DirAlchemy.BLUR_STEP] = k + 1   # each blow of the string takes the next step
	var used: Array = [f.act.dirI[DirAlchemy.BLUR_U1], f.act.dirI[DirAlchemy.BLUR_U2], f.act.dirI[DirAlchemy.BLUR_U3], f.act.dirI[DirAlchemy.BLUR_U4]]
	var pools: Dictionary = rec.pools.get(DirRecipe.poolKey(f), {})
	var ok: Array = []
	var again: Array = []
	for pn in (["blur.toward", "blur.base"] if toward else ["blur.base", "blur.toward"]):
		for row in pools.get(pn, []):
			var id: String = String(row.id)
			var pc = pieces.get(id)
			if String(row.get("status", "live")) == "waiting" or not (pc is Dictionary) or ok.has(id) or again.has(id):
				continue
			if String(pc.get("limb", "")) == String(step[0]) and String(pc.get("target", "")) == String(step[1]):
				if used.has(id.hash() & 0x7fffffff):
					again.append(id)
				else:
					ok.append(id)
	if ok.is_empty():
		ok = again   # the pattern wins: a step with one piece plays it again
	if ok.is_empty():
		return ""
	var id2: String = ok[int(SimRng.keyed(int(S.game.seed), "blur.piece", S.dirS.exN * 16 + k) * float(ok.size())) % ok.size()]
	f.act.dirI[DirAlchemy.BLUR_U4] = f.act.dirI[DirAlchemy.BLUR_U3]
	f.act.dirI[DirAlchemy.BLUR_U3] = f.act.dirI[DirAlchemy.BLUR_U2]
	f.act.dirI[DirAlchemy.BLUR_U2] = f.act.dirI[DirAlchemy.BLUR_U1]
	f.act.dirI[DirAlchemy.BLUR_U1] = id2.hash() & 0x7fffffff
	return id2


## The piece for the blur's closing blow: one of his ender pool that lands where the string's last light landed, when
## the pool has one. "" when none fits (the caller picks any piece of the pool).
static func ender(S: SimState, f) -> String:
	if not live(S, f):
		return ""
	var rec: Dictionary = DirRecipe.rec()
	var pieces = rec.get("pieces")
	var step: Array = _step(f, f.act.dirI[DirAlchemy.BLUR_STEP] - 1)
	if not (pieces is Dictionary) or step.is_empty():
		return ""
	var ok: Array = []
	for row in rec.pools.get(DirRecipe.poolKey(f), {}).get("blur.ender", []):
		var pc = pieces.get(String(row.id))
		if String(row.get("status", "live")) != "waiting" and pc is Dictionary and String(pc.get("target", "")) == String(step[1]):
			ok.append(String(row.id))
	if ok.is_empty():
		return ""
	return ok[int(SimRng.keyed(int(S.game.seed), "blur.ender", S.dirS.exN) * float(ok.size())) % ok.size()]
