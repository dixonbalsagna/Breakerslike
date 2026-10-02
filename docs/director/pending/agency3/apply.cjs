// Agency slice 3 (1c and 1d): the far taunt as a challenge, the held charge, and the AI's use of the free time.
// node apply.cjs <repo root>. Idempotent. bands.gd beside this script replaces sim/director/bands.gd.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw new Error("usage: node apply.cjs <repo root>");

function edit(rel, pairs) {
  const f = path.join(root, rel);
  let s = fs.readFileSync(f, "utf8");
  const crlf = s.includes("\r\n");
  if (crlf) s = s.split("\r\n").join("\n");
  let n = 0;
  for (const [a, b] of pairs) {
    if (s.includes(b)) continue;
    if (!s.includes(a)) throw new Error(rel + ": not found: " + a.slice(0, 80));
    if (s.split(a).length !== 2) throw new Error(rel + ": not unique: " + a.slice(0, 80));
    s = s.replace(a, () => b);
    n++;
  }
  if (crlf) s = s.split("\n").join("\r\n");
  fs.writeFileSync(f, s);
  console.log(rel + ": " + n + " edits");
}

fs.copyFileSync(path.join(__dirname, "bands.gd"), path.join(root, "sim/director/bands.gd"));
console.log("sim/director/bands.gd: replaced");

// ---------------------------------------------------------------- the state
edit("sim/director/interrupt.gd", [
  [`const N: int = 20
`,
   `const TAUNT_AGE: int = 20  # ticks his far taunt has played (DirBands); 0 when none is open
const TAUNT_N: int = 21    # far taunts of his that were ignored since the two last traded blows (the guard against farming)
const AI_REACT: int = 22   # the AI's chosen answer to the rival's approach or taunt (DirBands.R_*)
const REACT_AT: int = 23   # ... and the ticks left of its reaction time
const AI_HOLD: int = 24    # the AI is holding an attack button for a charge: 1 light, 2 heavy
const GUARD_AT: int = 25   # S.tick of his last fresh guard press (two within the lockout's length start the lockout)
const BAND: int = 26       # the range band the pair is in, plus 1 (DirBands; held with hysteresis; 0 before the first tick)
const N: int = 27
const END_NONE: int = -1   # LAST_END before any launch beat or launch: the exchange has sent nobody anywhere
`],
  [`		f.act.dirI[BLOCKED] = NEVER
`,
   `		f.act.dirI[BLOCKED] = NEVER
		f.act.dirI[GUARD_AT] = NEVER
`],
  // the lockout (agency-pass.md section 11, 3b)
  [`	var b = _windowBeat(S, S.dirS.ex, f)
	var assist: bool = SimAct.assisted(f, "perfectBlockAssist")
	if b == null or (S.tick < gi(f, PB_LOCK) and not assist):
		if not assist:
			si(f, PB_LOCK, S.tick + int(data().timing.antiMashLockout))
		return false
`,
   `	var b = _windowBeat(S, S.dirS.ex, f)
	var assist: bool = SimAct.assisted(f, "perfectBlockAssist")
	var last: int = gi(f, GUARD_AT)
	si(f, GUARD_AT, S.tick)
	if b == null or (S.tick < gi(f, PB_LOCK) and not assist):
		# The lockout starts only when the press came during a visible wind-up and missed its window, or when two guard
		# presses come within the lockout's length of each other (agency-pass.md section 11, 3b). A single press with no
		# wind-up showing starts nothing: raising a guard as a rival flies in must not cost the perfect block.
		var lock: int = int(data().timing.antiMashLockout)
		if not assist and (_windupShowing(S.dirS.ex, f) or S.tick - last <= lock):
			si(f, PB_LOCK, S.tick + lock)
		return false
`],
  [`## A fresh guard press by f. Inside a window, and not locked out, it marks the strike: the block resolves when the
`,
   `## True when a strike on f is visibly winding up: the exchange's next strike on him with a perfect-block window lands
## within the longest wind-up (a heavy's), or a signature aimed at him is in its tell.
static func _windupShowing(ex, f) -> bool:
	if ex == null:
		return false
	if ex.kind == "sig":
		return f == ex.D and ex.branch == ""
	var role: String = "A" if f == ex.A else "D"
	var longest: float = float(DirData._prof().tempo.get("heavyWindup", 20.0))
	for b in ex.beats:
		if b.done or b.op != "strike" or b.args.d != role or b.args.o == null:
			continue
		if _window(f, String(b.args.o.get("class", "")), ex.kind == "heavy") < 0.0:
			continue
		return (b.t - ex.t) * DirData.TICKS_PER_SEC <= longest + 0.5
	return false


## A fresh guard press by f. Inside a window, and not locked out, it marks the strike: the block resolves when the
`],
  [`	si(A, TAKEN, 0)
`,
   `	si(A, TAKEN, 0)
	si(A, TAUNT_N, 0)   # blows are traded: an ignored far taunt pays again
	si(D, TAUNT_N, 0)
`],
  [`	si(A, LAST_END, END_LAUNCH)
`,
   `	si(A, LAST_END, END_NONE)
`],
]);

edit("sim/director/alchemy.gd", [
  // the layout's hold turns the press into a heavy: the log says so, or the held heavy never earned its launch
  [`		f.act.dirI[k] = (f.act.dirI[k] & ~(3 << 8)) | (HELD << 8)
`,
   `		f.act.dirI[k] = (f.act.dirI[k] & ~(3 << 8)) | (HELD << 8) | SimAct.HEAVY   # held, and the heavy the hold made it
`],
  [`## True when one of f's own blows lands within TIMED_TICKS of now (the beat list knows every contact tick).
`,
   `## The press he made on that tick was held (a charge from the far band), and is the weight it ended as (a Simple
## layout's hold turns a light into a heavy on the way).
static func heldAt(f, tick: int, weight: int) -> void:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	for k in range(n - 1, maxi(-1, n - 1 - RING), -1):
		if f.act.dirI[T0 + k % RING] == tick:
			f.act.dirI[P0 + k % RING] = (f.act.dirI[P0 + k % RING] & ~(3 << 8) & ~1) | (HELD << 8) | (weight & 1)
			return


## True when one of f's own blows lands within TIMED_TICKS of now (the beat list knows every contact tick).
`],
  [`	var n: int = f.act.dirI[COUNT]
	var rhythm: int = PLAIN
	if _timed(S, f):
		rhythm = TIMED
`,
   `	var n: int = f.act.dirI[COUNT]
	var rhythm: int = PLAIN
	var timed: bool = _timed(S, f)
	# The flow count (agency-pass.md section 2): a timed press adds 1, up to FLOW_MAX; a press off the beat sets it back
	# to 0 (and so do FLOW_LIFE ticks without a press: tick). Nothing reads it yet but the HUD and QA.
	if DirInterrupt.on():
		SimAct.setFlow(S, f, mini(FLOW_MAX, f.act.flow + 1) if timed else 0)
	if timed:
		rhythm = TIMED
`],
  [`## The layout's hold edge: his newest press was held (a charged blow).
`,
   `const FLOW_MAX: int = 5     # the flow count's ceiling
const FLOW_LIFE: int = 90   # ticks without a press after which it lapses


## Once a live tick: a fighter's flow lapses FLOW_LIFE ticks after his last press.
static func tick(S: SimState) -> void:
	for f in S.fighters:
		if f.act.flow <= 0:
			continue
		_size(f)
		var n: int = f.act.dirI[COUNT]
		if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > FLOW_LIFE:
			SimAct.setFlow(S, f, 0)


## The layout's hold edge: his newest press was held (a charged blow).
`],
]);

// ---------------------------------------------------------------- the far press, the answer, the meeting
edit("sim/director/exchange.gd", [
  // the starts floor until the alchemist (agency-pass.md section 11, 4)
  [`## Starts the oldest queued request the director can take: the older one first; on a tie of age the fighter who did not
## start the last exchange (two players pressing at one fixed gap could phase-lock the queue), then the slots alternating. A request
`,
   `## Starts a queued request the director can take. When both fighters have one waiting, the fighter who did not start
## the last exchange goes first; if neither did, the older request, then the slots alternating. A request
`],
  [`	if q0.is_empty() or (not q1.is_empty() and (q1[3] < q0[3] or (q1[3] == q0[3] and (l1 < l0 or (l1 == l0 and S.tick % 2 == 1))))):
`,
   `	# The starts floor (agency-pass.md section 11, 4): when both have a press waiting, the one who did not start the
	# last exchange starts this one, whichever press is older. A patient player is not shut out by a masher.
	if q0.is_empty() or (not q1.is_empty() and (l1 < l0 or (l1 == l0 and (q1[3] < q0[3] or (q1[3] == q0[3] and S.tick % 2 == 1))))):
`],
  [`	var entry: int = 1 if m > SimAct.awayDead else (-1 if m < -SimAct.awayDead else 0)   # toward, neutral or away (step 4 reads it)
`,
   `	var entry: int = 1 if m > SimAct.awayDead else (-1 if m < -SimAct.awayDead else 0)   # toward, neutral or away (step 4 reads it)
	if kind != "sig" and DirBands.farPressNow(S, A, KIND.find(kind), entry):
		return   # the far band: the press fires on its tick as a taunt, an answer or (held) a charge; it never waits
`],
  [`static var planOpen: int = 0        # ... and the opening that approach began with (DirInterrupt.OPEN_*, or 0)
`,
   `static var planOpen: int = 0        # ... and the opening that approach began with (DirInterrupt.OPEN_*, or 0)
static var planMeet: bool = false   # ... and whether it is the meeting after an answered taunt: the rival is pressing too
`],
  [`	if kind != "sig" and not engaging and DirBands.on() and DirBands.band(A, D) != DirBands.CLOSE:
		DirBands.begin(S, A, D, KIND.find(kind), planEntry, planTick if planTick >= 0 else S.tick, opn)
		if opn != 0:
			DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
		return APPROACH
`,
   `	if kind != "sig" and not engaging and DirBands.on():
		var pt: int = planTick if planTick >= 0 else S.tick
		var bd: int = DirBands.band(A, D)
		# The far taunt is a challenge: the rival's attack press while it plays answers it, and both rush to meet.
		if DirBands.taunting(D) and opn == 0:
			if bd != DirBands.CLOSE:
				DirBands.meet(S, A, D, KIND.find(kind), planEntry, pt)
				return APPROACH
			DirBands.endTaunt(S, D, true)   # already in reach: the exchange itself is the answer
		# A far press fires on its own tick (requestAttack): a taunt, an answer or a charge. A request that waited in the
		# queue and comes up in the far band was pressed somewhere else, and is dropped.
		if bd == DirBands.FAR and opn == 0 and A.act.v2 and DirBands.farOn():
			return DROPPED
		if bd != DirBands.CLOSE:
			DirBands.begin(S, A, D, KIND.find(kind), planEntry, pt, opn)
			if opn != 0:
				DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
			return APPROACH
	DirBands.endTaunt(S, A, false, "cut")   # his own taunt, if one was playing, ends as his attack starts
`],
]);

edit("sim/director/exchange.gd", [
  [`static var planMeet: bool = false   # ... and whether it is the meeting after an answered taunt: the rival is pressing too
`,
   `static var planMeet: bool = false   # ... and whether it is the meeting after an answered taunt: the rival is pressing too
static var planMeetEdge: float = 0.0   # ... and the edge of a rival met while he held a heavy charge (off the attacker's clash chance)
`],
  // how the exchange ended, for QA and the HUD (Simulation's exchange_end): a launch, a knock-back, or both still in reach
  [`	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)
`,
   `	if DirInterrupt.on() and S.game.ko == null:
		var le: int = DirInterrupt.gi(ex.A, DirInterrupt.LAST_END)
		SimFx.exchangeEnd(S, ex.A, "launch" if le == DirInterrupt.END_LAUNCH else ("knockback" if le == DirInterrupt.END_KNOCK else "continue"))
	S.dirS.ex = null
	S.dirS.cool = cooldownAfter(ex)
`],
  [`	DirBands.tick(S)   # the approach before an exchange: it counts down, and the exchange starts at its end
`,
   `	DirBands.tick(S)   # the approach before an exchange: it counts down, and the exchange starts at its end
	DirAlchemy.tick(S)   # the flow count lapses
`],
]);

edit("sim/director/launch.gd", [
  // every real launch marks the exchange's ending (a beam's, a finisher's and a break's go past the launch beat)
  [`	tgt.state = "launched"
	tgt.launchBy = att
`,
   `	if S.dirS.ex != null and String(plan.get("name", "")) != "KNOCK BACK":
		DirInterrupt.si(S.dirS.ex.A, DirInterrupt.LAST_END, DirInterrupt.END_LAUNCH)
	tgt.state = "launched"
	tgt.launchBy = att
`],
  // Simulation's knockback event: Combat's kinds (the bump is World's)
  [`		tgt.vx = s * sp            # ... and its speed is the data's, whatever the tier scaling of a launch
		tgt.vy = float(kb.skidUy) * sp
		return
`,
   `		tgt.vx = s * sp            # ... and its speed is the data's, whatever the tier scaling of a launch
		tgt.vy = float(kb.skidUy) * sp
		SimFx.knockback(S, tgt, att, "slideLong", dist, S.tick + int(ceil(2.0 * dist / sp * DirData.TICKS_PER_SEC)))   # the end is an estimate (a steady brake); World's journey decides
		return
`],
  [`	r.end = S.T + float(kb.slideTicks if slide else kb.driftTicks) * SimConst.DT
	tgt.rush = r
`,
   `	r.end = S.T + float(kb.slideTicks if slide else kb.driftTicks) * SimConst.DT
	tgt.rush = r
	SimFx.knockback(S, tgt, att, "slideShort" if slide else "drift", dist, S.tick + int(kb.slideTicks if slide else kb.driftTicks))
`],
]);

edit("sim/director/data.gd", [
  // a rival met while he held a heavy charge: the edge comes off the attacker's chance in today's clash
  [`			var p2: float = _adjust(_linear(sel.p, ctx), ctx, "attacker")
`,
   `			var p2: float = _adjust(_linear(sel.p, ctx), ctx, "attacker") - DirExchange.planMeetEdge
`],
  [`	var sp: float = SimDetMath.hypot(D.vx, D.vy)
	var top: float = 430.0 * D.spd * (1.0 + D.ld.speed * (D.tier - 1.0))
`,
   `	if DirExchange.planMeet:
		ctx.defQueued = true   # the meeting after an answered taunt: both rushed in, so the rival is pressing too
	var sp: float = SimDetMath.hypot(D.vx, D.vy)
	var top: float = 430.0 * D.spd * (1.0 + D.ld.speed * (D.tier - 1.0))
`],
]);

// ---------------------------------------------------------------- the AI
edit("sim/director/ai.gd", [
  // its held button, and its answer to a rival who is coming or taunting
  [`		if f.state == "free":
			a.st = float(pickW(S, w))
	var st: float = a.st
`,
   `		if f.state == "free":
			a.st = float(pickW(S, w))
	# A charge is a held button: the AI keeps its button down while its taunt or its approach lasts.
	var hold: int = DirInterrupt.gi(f, DirInterrupt.AI_HOLD)
	if hold > 0:
		if DirBands.taunting(f) or DirBands.pending(f):
			i.lightHeld = hold == 1
			i.heavyHeld = hold == 2
		else:
			DirInterrupt.si(f, DirInterrupt.AI_HOLD, 0)
	# The rival is coming, or taunting (DirBands): the answer the AI chose, once its reaction time is up. It guards,
	# dodges, or presses to meet him.
	var ans: int = DirBands.aiAnswer(f, o) if f.state == "free" else DirBands.R_NONE
	if ans == DirBands.R_GUARD:
		a.st = 1.0
	elif ans == DirBands.R_DODGE:
		a.st = 2.0
	elif ans == DirBands.R_LIGHT:
		i.light = true
	elif ans == DirBands.R_HEAVY:
		i.heavy = true
	var st: float = a.st
`],
  // its ordinary attack beats wait while the rival taunts: it answers only by choice (answerTaunt)
  [`	var ready: bool = S.dirS.cool <= 0.0 and o.state != "launched" and o.state != "locked" and DirBands.who(S) < 0
`,
   `	var ready: bool = S.dirS.cool <= 0.0 and o.state != "launched" and o.state != "locked" and DirBands.who(S) < 0 and not DirBands.taunting(o)
`],
  // an attack beat in the far band: a taunt (a tap) or a charge (a hold)
  [`			else:
				i.light = true
		# Attack cadence (dynamic feel)`,
   `			else:
				i.light = true
			if (i.light or i.heavy) and DirBands.farOn() and DirBands.band(f, o) == DirBands.FAR and not DirBands.taunting(o):
				var u: float = S.rng.next()
				var ft: float = float(lv().get("farTaunt", 0.0)) if not DirBands.tauntSpent(f) else 0.0
				var urge: bool = S.T - SimMathx.jmax(f.exT, o.exT) > GAP_URGE   # no lull: after a long gap it always goes
				if u < ft and not urge:
					pass   # a tap: the taunt
				elif urge or u < ft + float(lv().get("farCharge", 1.0)):
					if i.heavy and S.rng.next() >= float(lv().get("farHeavy", 1.0)):
						i.heavy = false   # the heavy charge is slow and committed: more often it charges light
						i.light = true
					DirInterrupt.si(f, DirInterrupt.AI_HOLD, 2 if i.heavy else 1)   # it holds the button: the charge
					i.lightHeld = i.light
					i.heavyHeld = i.heavy
				else:
					i.light = false   # it holds this beat
					i.heavy = false
		# Attack cadence (dynamic feel)`],

]);

// ---------------------------------------------------------------- data
function json(rel, fn) {
  const f = path.join(root, rel);
  const txt = fs.readFileSync(f, "utf8");
  const j = JSON.parse(txt);
  fn(j);
  const eol = txt.includes("\r\n") ? "\r\n" : "\n";
  fs.writeFileSync(f, JSON.stringify(j, null, 2).split("\n").join(eol) + eol);
  console.log(rel + ": written");
}
json("data/director/interrupts.json", j => {
  j.bands.taunt = { enabled: true, windowTicks: 45 };
  j.bands.charge = {
    light: { holdTicks: 8, speed: 4000, minTicks: 18, maxTicks: 60 },
    heavy: { holdTicks: 16, speed: 3000, minTicks: 30, maxTicks: 84 },
  };
  j.bands.meet = { speed: 4000, minTicks: 20, maxTicks: 60, chargerEdge: 10 };
  j.bands.midBh = 12.5;
  j.bands.hysteresisBh = 0.5;
  j.bands._edge = "midBh is 12.5 (agency-pass.md section 12 b): a match opens with the pair 12 bh apart, and the opening press is a lunge. hysteresisBh: the band is held state, and an edge is crossed only half this much beyond it (going out it sits further out, coming in further in), so the band and its icon do not flicker for a pair hovering on a line";
  j.bands._far = "The far band (agency-pass.md section 1). taunt: a tap is a taunt, a challenge that plays for windowTicks while he keeps flying; the rival's attack press in that time answers it and both rush to the middle (meet: each covers half the distance at 'speed', in whole ticks between minTicks and maxTicks, and they arrive together, engageBh apart; chargerEdge: a rival met while he held a heavy charge enters the clash with this many points (of 100) off the attacker's chance, the interim form of Game Design's +5 until the fist clash on the pulse is wired). Answered, it pays in full; ignored, a half, a quarter, an eighth, then nothing until the two have traded blows. charge: a press still held holdTicks after it becomes a charge of that weight, flying at 'speed' for minTicks to maxTicks (section 12 a: a light goes after 8 ticks and flies 0.3 to 1.0 s; a heavy after 16 and flies 0.5 to 1.4 s). A light charge stops for nothing when the button is let go; a heavy charge is committed (only a dodge-cancel at its full cost stops it) and its heavy counts as held, so landing it earns a launch. taunt.enabled false: a far press flies in on a tap at far.light or far.heavy, as before";
});
// ai.json keeps its inline arrays, so it is edited as text
const lvl = (held, taunt, charge, answer, react, heavy) => [
  `      "heldHeavy": ${held}
`,
  `      "heldHeavy": ${held},
      "farTaunt": ${taunt},
      "farCharge": ${charge},
      "farHeavy": ${heavy},
      "answerTaunt": ${answer},
      "approachReact": ${react}
`];
edit("data/director/ai.json", [
  lvl("0.1", "0.1", "1.0", "0.7", "[0.1, 0.05, 0.1]", "1.0"),
  lvl("0.25", "0.06", "1.0", "0.5", "[0.2, 0.1, 0.15]", "1.0"),
  lvl("0.35", "0.04", "1.0", "0.3", "[0.3, 0.2, 0.2]", "1.0"),
  [`  "level": "medium",
`,
   `  "reactTicks": 14,
  "answerTicks": 20,
  "_far": "The far band and the free approach (sim/director/bands.gd). reactTicks: the AI's reaction time to a rival's approach; an approach shorter than this gets no answer. answerTicks: how long after a rival's far taunt begins it presses its answer (past a heavy's 16-tick hold, so it answers a taunt and not a charge being gathered). Per level: farTaunt, the chance its attack beat in the far band is a taunt (a tap); farCharge, the chance it is otherwise a charge (it holds the button); below 1 it sometimes holds the beat instead, which measured slower (matches ran to the time cap at 0.5). After 6 s with no exchange it always charges. farHeavy: when it charges with a heavy, the chance it stays a heavy charge (slow and committed); otherwise it charges light. answerTaunt: the chance it answers a rival's far taunt with an attack press. approachReact: [guard, dodge, meet], the chances it answers a rival's approach by guarding, by dodging or by pressing to meet him; otherwise it carries on as it was",
  "level": "medium",
`],
]);
console.log("done");
