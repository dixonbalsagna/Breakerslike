// Control-scheme step 3 (interrupts, staleness, the AI's defences). Usage, from the repo root: node docs/director/pending/step3/apply-step3.cjs . [--core]
// --core also writes the two lines that are Simulation's (ActState.dirI and its hash): for scratch copies only.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw "usage: node apply-step3.cjs <root> [--core]";
const core = process.argv.includes("--core");
const P = f => path.join(root, f);
const here = __dirname;
function edit(file, pairs) {
  let s = fs.readFileSync(P(file), "utf8");
  const crlf = s.includes("\r\n");
  if (crlf) s = s.replace(/\r\n/g, "\n");
  for (const [a, b] of pairs) {
    if (s.includes(b)) continue;
    if (!s.includes(a)) throw new Error(file + ": anchor not found: " + a.slice(0, 90));
    s = s.replace(a, () => b);
  }
  fs.writeFileSync(P(file), crlf ? s.replace(/\n/g, "\r\n") : s);
}

// ---- Simulation's two lines (scratch only) ----
if (core) {
  edit("sim/core/state.gd", [[
    `	var breakIn: int = -1         # the break: ticks until a transformation's tier-up lands (SimPause gather), -1 for none
`,
    `	var breakIn: int = -1         # the break: ticks until a transformation's tier-up lands (SimPause gather), -1 for none
	var dirI: PackedInt32Array = PackedInt32Array()   # the director's per-fighter integers (DirInterrupt: lockouts, openings, staleness); it sizes and owns them
`]]);
  edit("sim/core/hash.gd", [[
    `		out.append(float(act.queue.size()))
`,
    `		out.append(float(act.dirI.size())); for v in act.dirI: out.append(float(v))   # the director's per-fighter integers
		out.append(float(act.queue.size()))
`]]);
}

// ---- new files ----
fs.copyFileSync(path.join(here, "interrupt.gd"), P("sim/director/interrupt.gd"));
fs.copyFileSync(path.join(here, "interrupts.json"), P("data/director/interrupts.json"));
fs.copyFileSync(path.join(here, "ai.json"), P("data/director/ai.json"));

// ---- the loader ----
edit("sim/director/data.gd", [
  [`	h.text(DirLaunch.dataText())   # data/director/launch.json (the landing mix)
`,
   `	h.text(DirLaunch.dataText())   # data/director/launch.json (the landing mix)
	h.text(DirInterrupt.dataText())   # data/director/interrupts.json, and Controls' perfect-block timing
`],
  // the context template (the riposte), staleness, and a staggered defender has no press
  [`	var tp: Dictionary = _template(ex.kind, defState)
	_penalties(ctx, D)
`,
   `	var tp: Dictionary = _contextTemplate(DirExchange.planContext) if DirExchange.planContext != "" else _template(ex.kind, defState)
	ctx.riposteLaunch = DirExchange.planLaunch
	_penalties(ctx, D)
`],
  [`	if sp:
		ctx.c = _approachTicks(dist, heavy)
`,
   `	if sp:
		ctx.c = _approachTicks(dist, heavy) + float(DirExchange.planStale)   # step 3: a stale attack winds up slower
`],
  [`static func _hasTemplate(kind: String, defState: String) -> bool:
`,
   `## A context template (trigger.context: the riposte), for the active profile.
static func _contextTemplate(context: String) -> Dictionary:
	for tp in _tpl.templates:
		if String(tp.trigger.get("context", "")) == context and not (tp.has("only") and not tp.only.has(tplProfile())):
			return tp
	push_error("DirData: no context template " + context)
	return {}


static func _hasTemplate(kind: String, defState: String) -> bool:
`],
  [`	ctx.defQueued = not dq.is_empty() or (S.T - D.lastAtkT) * TICKS_PER_SEC <= DEF_QUEUED_TICKS
`,
   `	ctx.defQueued = not dq.is_empty() or (S.T - D.lastAtkT) * TICKS_PER_SEC <= DEF_QUEUED_TICKS
	if D.stunTicks > 0 and DirInterrupt.on():
		ctx.defQueued = false   # step 3: a staggered fighter is not pressing, whatever waits in its queue
`],
  [`		if b.has("when") and b.when == "heavy" and not ctx.heavy:
			continue
`,
   `		if b.has("when") and b.when == "heavy" and not ctx.heavy:
			continue
		if b.has("when") and b.when == "riposteLaunch" and not ctx.get("riposteLaunch", false):
			continue
`],
  [`## The contact block of the active profile (contact-spacing.md)`,
   `## Step 3: the active profile's perfect-block numbers (Combat's: staggerTicks, riposteTicks). Empty in the old profiles.
static func perfectBlock() -> Dictionary:
	_ensure()
	return _prof().get("perfectBlock", {})


## An interrupt's block (templates.json interrupts).
static func interrupt(name: String) -> Dictionary:
	_ensure()
	return _tpl.interrupts[name]


## Whether the exchange's branch allows the named interrupt (its "interrupts" list).
static func allows(ex, name: String) -> bool:
	_ensure()
	for tp in _tpl.templates:
		if String(tp.id) == ex.tpl:
			for br in tp.branches:
				if String(br.id) == ex.branch:
					return br.get("interrupts", []).has(name)
	return false


## The contact block of the active profile (contact-spacing.md)`],
  // the beam: a perfect block of the fire beat is a DEFLECT
  [`static func beamOutcome(S: SimState, ex, dist: float, answer: String) -> Dictionary:`,
   `static func beamOutcome(S: SimState, ex, dist: float, answer: String, perfect: bool = false) -> Dictionary:`],
  [`	ctx.defAnswer = answer
	for rule in _tpl.beam.outcomeByProfile[tplProfile()].rules:
`,
   `	ctx.defAnswer = answer
	ctx.defPerfect = perfect
	for rule in _tpl.beam.outcomeByProfile[tplProfile()].rules:
`]]);


edit("sim/director/data.gd", [[
  `	ctx.defClipped = sp > 0.5 * top and (away or absf(D.vy) > absf(D.vx))
`,
  `	ctx.defClipped = sp > 0.5 * top and (away or absf(D.vy) > absf(D.vx))
	if D.stunTicks > 0 and DirInterrupt.on():
		ctx.defClipped = false   # step 3: a staggered fighter is recoiling, not slipping away
`]]);

// ---- the exchange ----
edit("sim/director/exchange.gd", [
  [`static func requestAttack(S: SimState, A, kind: String) -> void:
	if not A.act.v2:
`,
   `static func requestAttack(S: SimState, A, kind: String) -> void:
	# A press during a live clash belongs to the clash (docs/controls/tech-and-pulse-input.md section 2): it is spent,
	# never queued, so mashed clash presses do not fire as attacks after it.
	if DirBeam.inClash(S, A):
		return
	if not A.act.v2:
`],
  [`## The entry of the request being started (+1 toward, 0, -1 away); 0 outside _drain. Not state: it lives for one call.
static var planEntry: int = 0
`,
   `## The entry of the request being started (+1 toward, 0, -1 away); 0 outside _drain. Not state: it lives for one call.
static var planEntry: int = 0
## Step 3, for the plan of the exchange being started (not state; each lives for one _start): the context template to
## plan from ("riposte"), whether that riposte launches, and the ticks staleness adds to the wind-up.
static var planContext: String = ""
static var planLaunch: bool = false
static var planStale: int = 0
`],
  [`static func _drain(S: SimState) -> void:
	if S.dirS.ex != null or S.dirS.cool > 0.0 or S.game.ko != null:
		return
`,
   `static func _drain(S: SimState) -> void:
	if S.dirS.ex != null or S.game.ko != null:
		return
	# Step 3: a fighter with an opening (a riposte, a reversal, a punish) starts through the cooldown.
	if S.dirS.cool > 0.0 and DirInterrupt.opening(S, S.fighters[0]) == 0 and DirInterrupt.opening(S, S.fighters[1]) == 0:
		return
`],
  [`static func _start(S: SimState, A, kind: String) -> int:
	if S.dirS.ex != null or S.dirS.cool > 0.0 or S.game.ko != null:
		return WAIT
	var D = SimRoster.opp(S, A)
`,
   `static func _start(S: SimState, A, kind: String) -> int:
	if S.dirS.ex != null or S.game.ko != null:
		return WAIT
	var opn: int = DirInterrupt.opening(S, A) if kind != "sig" else 0
	if S.dirS.cool > 0.0 and opn == 0:
		return WAIT
	if A.stunTicks > 0 and DirInterrupt.on():
		return WAIT   # step 3: a staggered fighter's requests wait
	var D = SimRoster.opp(S, A)
`],
  [`	if kind != "sig" and DirData.hasNeutral():
		DirAI.react(S, D, dState)   # step 2b: the AI defender's press, before the plan reads defQueued (dState: its state before the lock)
`,
   `	if kind != "sig" and DirData.hasNeutral() and opn == 0:
		DirAI.react(S, D, dState)   # step 2b: the AI defender's press, before the plan reads defQueued (dState: its state before the lock)
	# Step 3: staleness, and an opening spent on this attack (the riposte plans from its own template).
	planStale = DirInterrupt.onStart(S, ex, KIND.find(kind), A.act.mode, planEntry)
	planContext = "riposte" if (opn == DirInterrupt.OPEN_RIPOSTE or opn == DirInterrupt.OPEN_RIPOSTE_LAUNCH) else ""
	planLaunch = opn == DirInterrupt.OPEN_RIPOSTE_LAUNCH
	if opn != 0:
		DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
`],
  [`	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "sig" if kind == "sig" else "melee")
	var stanceLabel: String`,
   `	planContext = ""
	planLaunch = false
	planStale = 0
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "sig" if kind == "sig" else "melee")
	var stanceLabel: String`],
  [`	ex.t += dt
	DirMelee.contactTick(S, ex)`,
   `	ex.t += dt
	DirInterrupt.tick(S)   # step 3: this tick's inputs inside the exchange (perfect block, reversal, dodge-cancel, burst)
	DirMelee.contactTick(S, ex)`],
  [`	DirData.planChain(ex)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "chain")
`,
   `	DirData.planChain(ex)
	if chk != null:
		planCheck.call(chk, ex, S.rng.a, "chain")
	DirInterrupt.onChainLink(S, ex)   # step 3: the defender's burst at its link (the AI, the Simple layout's autoBurst)
`],
  [`	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)
`,
   `	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)
	DirInterrupt.onEnd(S, ex)   # step 3: a fully blocked string leaves its attacker behind
`]]);
// a burst outside an exchange: the tick's inputs are read there too
edit("sim/director/exchange.gd", [[
  `	var ex = S.dirS.ex
	if ex == null:
		return
	ex.t += dt
`,
  `	var ex = S.dirS.ex
	if ex == null:
		DirInterrupt.tick(S)   # step 3: a burst, or a guard press outside any window (the lockout), between exchanges
		return
	ex.t += dt
`]]);


edit("sim/director/exchange.gd", [[
  `	var e := SimState.Ext.new()
	e.start = S.T
`,
  `	if DirInterrupt.lastBlowBlocked(S, ex):
		return   # step 3: a blocked string opens no chain window; its attacker is left behind (DirInterrupt.onEnd)
	var e := SimState.Ext.new()
	e.start = S.T
`]]);

// ---- melee ----
edit("sim/director/melee.gd", [
  // the old parry leaves the profiles that have the perfect block; the wind beat keeps its tell
  [`	if D.ai != null and S.rng.next() < (0.5 if ex.sD == 1.0 else (0.3 if ex.sD == 0.0 else 0.12)):
`,
   `	if DirInterrupt.on():
		return   # step 3: the perfect block replaces the parry; the AI presses by DirInterrupt, in the strike's window
	if D.ai != null and S.rng.next() < (0.5 if ex.sD == 1.0 else (0.3 if ex.sD == 0.0 else 0.12)):
`],
  [`	if a == ex.A and not o.get("noParry", false) and armed and d.lastAtkT >= winStart - early:
`,
   `	if o.get("perfect", false):
		DirInterrupt.perfectBlock(S, ex, a, d, o)   # step 3: the timed guard press landed in this strike's window
		return
	if a == ex.A and not o.get("noParry", false) and armed and d.lastAtkT >= winStart - early and not DirInterrupt.on():
`],
  [`	var brokenBefore: int = _broken(d)
	SimDamage.hit(S, ex, a, d, dmg, o)
`,
   `	var brokenBefore: int = _broken(d)
	if dmg > 0.0:
		DirInterrupt.si(d, DirInterrupt.HIT_AT, S.tick)
	SimDamage.hit(S, ex, a, d, dmg, o)
	if dmg > 0.0 and not o.get("ignoreStance", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:
		DirInterrupt.onBlock(S, ex, d)   # a normal block: the reversal's window
`]]);

// ---- the beam: DEFLECT, and the clash flag ----
edit("sim/director/beam.gd", [
  [`		var res: Dictionary = DirData.beamOutcome(S, ex, dist, answer)
`,
   `		var res: Dictionary = DirData.beamOutcome(S, ex, dist, answer, args.get("perfect", false))
`],
  [`	if out == "HIT" or out == "GUARD":
		DirExchange.schedule(ex, ex.t + reach, "beamImpact", {"out": out, "ux": ux, "uy": uy})
`,
   `	if out == "DEFLECT":
		DirInterrupt.deflect(S, D)   # step 3: a perfect block of the fire beat; the beam is turned aside
	elif out == "HIT" or out == "GUARD":
		DirExchange.schedule(ex, ex.t + reach, "beamImpact", {"out": out, "ux": ux, "uy": uy})
`],
  [`## Beat "beamFire": fire, or start a beam clash`,
   `## True while f is one of the two fighters of a live clash (the beam struggle). The host and the input layer read it
## (docs/controls/tech-and-pulse-input.md): clash presses are the clash's, and the Simple layout fires on press.
static func inClash(S: SimState, f) -> bool:
	return S.game.clash != null and (S.game.clash.A == f or S.game.clash.D == f)


## Beat "beamFire": fire, or start a beam clash`]]);

// ---- the AI ----
edit("sim/director/ai.gd", [
  [`		_skill = {"pressReact": pr, "beamAnswer": float(j.beamAnswer), "sigPick": float(j.sigPick)}
	return _skill
`,
   `		_skill = {"pressReact": pr, "beamAnswer": float(j.beamAnswer), "sigPick": float(j.sigPick), "level": String(j.get("level", "medium")), "levels": j.get("levels", {}), "perfectBlock": j.get("perfectBlock", {})}
	return _skill


## The AI's level for this run: "" follows ai.json's "level". A host or a test sets it before the match (step 4 makes it
## a per-slot setup key). It is part of the data hash, so a replay made at another level has another header.
static var level: String = ""


## The level's numbers (ai.json levels): beamAnswer, perfectBlockMul, guardRepeat, punish, reversal, breakGuard, riposte,
## burstAtLink.
static func lv() -> Dictionary:
	var sk: Dictionary = skill()
	return sk.levels[level if level != "" else sk.level]
`],
  [`static func skillText() -> String:
	skill()
	return _skillText
`,
   `static func skillText() -> String:
	skill()
	return _skillText + level
`],
  // guard a repeated string
  [`		if o.hidden:
			w = [3.0, 0.3, 0.3, 0.1]
`,
   `		# Step 3: against a rival that has opened three exchanges running with one weight, the AI guards more (its level's weight): the guard, the perfect
		# block and the punish window are the answers to a masher.
		if DirInterrupt.on() and DirInterrupt.gi(o, DirInterrupt.WEIGHT_RUN) >= 3:
			w[1] += float(lv().guardRepeat)
		if o.hidden:
			w = [3.0, 0.3, 0.3, 0.1]
`],
  // break a fighter who only guards (the grab arrives with Combat's context templates)
  [`			elif q < sigPick + (1.0 - sigPick) * HEAVY_SHARE:
				i.heavy = true
`,
   `			elif q < sigPick + (1.0 - sigPick) * (maxf(HEAVY_SHARE, float(lv().breakGuard)) if DirInterrupt.on() and DirInterrupt.gi(o, DirInterrupt.GUARDED) >= 2 else HEAVY_SHARE):
				i.heavy = true   # step 3: a rival that only guards gets the guard-breaker (a heavy) at the level's rate
`]]);
edit("sim/director/beam.gd", [[
  `S.rng.next() < DirAI.skill().beamAnswer:`,
  `S.rng.next() < float(DirAI.lv().beamAnswer):`]]);
console.log("step 3 applied to " + root + (core ? " (with the two core lines)" : ""));
