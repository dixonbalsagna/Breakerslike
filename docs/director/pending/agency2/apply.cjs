// Agency slice 2 (1a and 1b): the approach before an exchange, the three bands, the upright slide.
// node apply.cjs <repo root>. Idempotent. bands.gd is copied beside this script's copy.
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

// ---------------------------------------------------------------- the state
edit("sim/director/interrupt.gd", [
  [`const N: int = 17
`,
   `const APPR_LEFT: int = 17  # ticks left of his approach (DirBands): the exchange starts when it reaches 0; 0 when none is on
const APPR_REQ: int = 18   # ... the press that began it: weight | (entry + 1) << 2 | its opening << 4
const APPR_TICK: int = 19  # ... and that press's tick (its place in the press log)
const N: int = 20
`],
  // the dodge during his own approach, and the dash shared with the cancel inside an exchange
  [`	if ex == null or ex.kind == "sig" or (f != ex.A and f != ex.D) or DirExchange.finisherPlanned(ex):
		return false
	var c: Dictionary = data().dodgeCancel
`,
   `	if ex == null:
		return DirBands.cancel(S, f)   # his own approach: nothing had started, so it costs nothing
	if ex.kind == "sig" or (f != ex.A and f != ex.D) or DirExchange.finisherPlanned(ex):
		return false
	var c: Dictionary = data().dodgeCancel
`],
  [`	var o = ex.D if f == ex.A else ex.A
	var mx: float = f.input.mx
	var my: float = f.input.my
	if mx == 0.0 and my == 0.0:
		mx = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)   # no direction held: away from the rival
	var l: float = SimDetMath.hypot(mx, my)
	f.vx = mx / l * float(c.dash)
	f.vy = my / l * float(c.dash)
	SimFx.afterimage(S, f)
`,
   `	dash(f, ex.D if f == ex.A else ex.A, float(c.dash))
	SimFx.afterimage(S, f)
`],
  [`## True until the exchange's first wind-up starts: its wind beat is still pending.
`,
   `## The cancel's dash: in the held direction, or away from the rival o when none is held.
static func dash(f, o, speed: float) -> void:
	var mx: float = f.input.mx
	var my: float = f.input.my
	if mx == 0.0 and my == 0.0:
		mx = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(f.x, o.x)), f.face)   # no direction held: away from the rival
	var l: float = SimDetMath.hypot(mx, my)
	f.vx = mx / l * speed
	f.vy = my / l * speed


## True until the exchange's first wind-up starts: its wind beat is still pending.
`],
]);

// ---------------------------------------------------------------- the exchange starts at the wind-up
edit("sim/director/exchange.gd", [
  [`const WAIT: int = 2
`,
   `const WAIT: int = 2
const APPROACH: int = 3   # the request began an approach (DirBands): it is spent, and the exchange starts when the approach ends
`],
  [`static var planTick: int = -1   # the tick of the request being started (its press in the log), -1 outside _drain
`,
   `static var planTick: int = -1   # the tick of the request being started (its press in the log), -1 outside _drain
static var engaging: bool = false   # true while an approach's end starts its exchange (DirBands._engage); not state
static var planOpen: int = 0        # ... and the opening that approach began with (DirInterrupt.OPEN_*, or 0)
`],
  [`			if r == WAIT:
				break
			SimAct.pop(f)
			if r == STARTED:
				return
`,
   `			if r == WAIT:
				break
			SimAct.pop(f)
			if r == STARTED or r == APPROACH:
				return
`],
  // the upgrade edge reaches an approach; nothing expires while one is on
  [`		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG):
			SimAct.push(f, SimAct.HEAVY if up == 1 else SimAct.SIG, f.act.mode, 0, S.tick)
`,
   `		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG) and not DirBands.upgrade(S, f, SimAct.HEAVY if up == 1 else SimAct.SIG):
			SimAct.push(f, SimAct.HEAVY if up == 1 else SimAct.SIG, f.act.mode, 0, S.tick)
`],
  [`		# a beam's tell (step 2b: the tell is longer than the expiry).
		var ex = S.dirS.ex
		if not (ex != null and (ex.A == f or (ex.kind == "sig" and ex.D == f and ex.branch == ""))):
`,
   `		# a beam's tell (step 2b: the tell is longer than the expiry). Nothing expires during an approach: the approaching
		# fighter's later presses are his links, and the rival's press is his answer, read when the exchange starts.
		var ex = S.dirS.ex
		if not (ex != null and (ex.A == f or (ex.kind == "sig" and ex.D == f and ex.branch == ""))) and DirBands.who(S) < 0:
`],
  [`	if S.dirS.ex != null or S.game.ko != null:
		return WAIT
	var opn: int = DirInterrupt.opening(S, A) if kind != "sig" else 0
`,
   `	if S.dirS.ex != null or S.game.ko != null:
		return WAIT
	# An approach is on (DirBands): every request waits for its end, except the rival's signature, which ends it.
	if not engaging and DirBands.who(S) >= 0 and (kind != "sig" or DirBands.pending(A)):
		return WAIT
	var opn: int = planOpen if engaging else (DirInterrupt.opening(S, A) if kind != "sig" else 0)   # an approach carries its opening to the engage
`],
  [`		SimFx.searching(S, A, D, D.lastSeen.x if D.lastSeen != null else D.x)
		return DROPPED
	if A.hidden:
`,
   `		SimFx.searching(S, A, D, D.lastSeen.x if D.lastSeen != null else D.x)
		return DROPPED
	# The ranged press (agency-pass.md section 1): outside the close band only the attacker's approach starts. Nothing
	# is decided, and the rival stays free, until it ends; the exchange then starts here again (engaging). An opening
	# (a riposte, a reversal, a punish) begins its approach through the cooldown and is kept for the engage.
	if kind != "sig" and not engaging and DirBands.on() and DirBands.band(A, D) != DirBands.CLOSE:
		DirBands.begin(S, A, D, KIND.find(kind), planEntry, planTick if planTick >= 0 else S.tick, opn)
		if opn != 0:
			DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
		return APPROACH
	if A.hidden:
`],
  [`	var ex := newEx(A, D, kind)
	A.exT = S.T
`,
   `	if DirBands.pending(D):
		DirBands.drop(S, D, A.name + "'s signature stops it")
	var ex := newEx(A, D, kind)
	A.exT = S.T
`],
  [`static func _transforms(S: SimState) -> void:
	if S.dirS.ex != null or S.game.ko != null:
		return
`,
   `static func _transforms(S: SimState) -> void:
	if S.dirS.ex != null or S.game.ko != null or DirBands.who(S) >= 0:
		return
`],
  [`	_queues(S)   # step 2: upgrades, expiry, and the next queued request once the director can take it
`,
   `	DirBands.tick(S)   # the approach before an exchange: it counts down, and the exchange starts at its end
	_queues(S)   # step 2: upgrades, expiry, and the next queued request once the director can take it
`],
]);

// ---------------------------------------------------------------- a heavy's least approach was compared in seconds
// (minHeavy is 0.3334 s, 20 ticks: the heavy opener's wind-up). Every exchange now starts in the close band, so the
// least approach is the usual one and a heavy's wind-up must fit in it.
edit("sim/director/data.gd", [
  [`		return maxf(float(ap.minHeavy), floor(SimMathx.jclamp(dist / float(ap.divisor), float(ap.min), float(ap.max)) * TICKS_PER_SEC + 0.5))
`,
   `		return maxf(floor(float(ap.minHeavy) * TICKS_PER_SEC + 0.5), floor(SimMathx.jclamp(dist / float(ap.divisor), float(ap.min), float(ap.max)) * TICKS_PER_SEC + 0.5))
`],
]);

// ---------------------------------------------------------------- the AI: an approach is an exchange to its attack timer
edit("sim/director/ai.gd", [
  [`	if S.dirS.ex == null:
		a.atk -= SimConst.DT
`,
   `	if S.dirS.ex == null and DirBands.who(S) < 0:
		a.atk -= SimConst.DT
`],
  // an AI that sees an attack coming answers it by its stance: it does not roam off while the rival approaches
  [`	var lure: float = DirLocation.roam(S, f) if st != 3.0 and not wantsCharge and not o.hidden else 0.0
`,
   `	var lure: float = DirLocation.roam(S, f) if st != 3.0 and not wantsCharge and not o.hidden and DirBands.who(S) < 0 else 0.0
`],
  [`	var ready: bool = S.dirS.cool <= 0.0 and o.state != "launched" and o.state != "locked"
`,
   `	var ready: bool = S.dirS.cool <= 0.0 and o.state != "launched" and o.state != "locked" and DirBands.who(S) < 0
`],
]);

// ---------------------------------------------------------------- the knock-back: upright under 4 bh, and the flag for World
edit("sim/director/launch.gd", [
  [`## The knock-back (launch.json knockBack): a short send, not a launch across the map. On the ground it is a low,
## send with no travel boost that the ground-contact model skids about distBh body heights (dust, a scuff, a trench). In
## the air, over the sea, or with groundMode "shove", the rival is carried back that far, upright, over driftTicks.
static func knock(S: SimState, att, tgt) -> void:
	var kb: Dictionary = data().knockBack
	var ti: int = clampi(int(att.tier) - 1, 0, 3)
	var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(att.x, tgt.x)), att.face)
	var g: float = WorldTerrain.groundY(S, tgt.x)
	if String(kb.groundMode) == "skid" and tgt.y - g <= float(kb.groundWithinBh) * BH and not WorldTerrain.seaAt(S, tgt.x):
		var sp: float = float(kb.skidSpeed[ti])
		doLaunch(S, att, tgt, {"name": "KNOCK BACK", "ux": s, "uy": float(kb.skidUy)}, sp, false)
		tgt.launchT = 1.0          # no travel boost: a knock-back is a short slide, not a flight across the map
		tgt.vx = s * sp            # ... and its speed is the data's, whatever the tier scaling of a launch
		tgt.vy = float(kb.skidUy) * sp
		return
	var r := SimState.Rush.new()
	r.px = SimWrap.wrap(tgt.x + s * float(kb.distBh[ti]) * BH)
	r.py = SimMathx.jmax(tgt.y, WorldTerrain.groundY(S, r.px))
	r.end = S.T + float(kb.driftTicks) * SimConst.DT
	tgt.rush = r
`,
   `## The knock-back (launch.json knockBack): a short send, not a launch across the map, distBh body heights by the
## striker's tier.
##  - On the ground, slideUnderBh and over: a low send with no travel boost that the ground-contact model skids (dust,
##    a scuff, a trench). Its plan carries slide "feet" and the distance, for World's slide on the feet.
##  - On the ground, under slideUnderBh: he slides back upright. The director carries him that far along the ground
##    over slideTicks. It is not a launch: no journey, no trench.
##  - In the air, over the sea, or with groundMode "shove": he is carried back that far, upright, over driftTicks.
static func knock(S: SimState, att, tgt) -> void:
	var kb: Dictionary = data().knockBack
	var ti: int = clampi(int(att.tier) - 1, 0, 3)
	var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(att.x, tgt.x)), att.face)
	var g: float = WorldTerrain.groundY(S, tgt.x)
	var dist: float = float(kb.distBh[ti]) * BH
	var ground: bool = String(kb.groundMode) == "skid" and tgt.y - g <= float(kb.groundWithinBh) * BH and not WorldTerrain.seaAt(S, tgt.x)
	if ground:
		SimFx.cue(S, tgt, "slide_brace", "", "")   # Combat's cue for the slide on the feet
	if ground and float(kb.distBh[ti]) >= float(kb.get("slideUnderBh", 0.0)):
		var sp: float = float(kb.skidSpeed[ti])
		doLaunch(S, att, tgt, {"name": "KNOCK BACK", "ux": s, "uy": float(kb.skidUy), "slide": "feet", "dist": dist}, sp, false)
		tgt.launchT = 1.0          # no travel boost: a knock-back is a short slide, not a flight across the map
		tgt.vx = s * sp            # ... and its speed is the data's, whatever the tier scaling of a launch
		tgt.vy = float(kb.skidUy) * sp
		return
	var r := SimState.Rush.new()
	r.px = SimWrap.wrap(tgt.x + s * dist)
	var g2: float = WorldTerrain.groundY(S, r.px)
	var slide: bool = ground and not WorldTerrain.seaAt(S, r.px)   # the upright slide ends on the ground; a drift keeps its height
	r.py = g2 if slide else SimMathx.jmax(tgt.y, g2)
	r.end = S.T + float(kb.slideTicks if slide else kb.driftTicks) * SimConst.DT
	tgt.rush = r
`],
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
  j.bands = {
    enabled: true,
    closeBh: 3,
    midBh: 12,
    engageBh: 2.5,
    lunge: { speed: 4000, minTicks: 3, maxTicks: 20 },
    far: {
      light: { speed: 4000, minTicks: 6, maxTicks: 90 },
      heavy: { speed: 4000, minTicks: 6, maxTicks: 90 },
    },
    _note: "The ranged press (agency-pass.md section 1; sim/director/bands.gd). The bands are measured centre to centre, the shortest arc and the height together, in body heights (75 u): close within closeBh, mid to midBh, far beyond. A close press starts its exchange at once. A press from farther off starts only the attacker's approach: it ends engageBh from the rival, on the attacker's own side and at the rival's height, and the exchange is planned then (the wind-up follows). The rival is free until it ends. lunge (the mid band) and far.light, far.heavy (the far band, by the press's weight): the approach lasts the distance to cover at 'speed' (units a second), in whole ticks, at least minTicks and at most maxTicks. Until the far taunt and the held charge are built a far press flies in on a tap, at about the speed it had (4000 u a second; it was 2600 with the wind-up inside the flight); the charge's own flight (light 0.5 to 1.5 s, heavy 0.8 to 2.0 s) comes with the hold. On a slope the end point is brought in until the pair is inside the close band",
  };
});
// launch.json keeps its own number formatting (25.0), so it is edited as text
edit("data/director/launch.json", [
  [`    "driftTicks": 20,
    "chain": false,
`,
   `    "driftTicks": 20,
    "chain": false,
    "slideUnderBh": 4.0,
    "slideTicks": 18,
    "_slide": "slideUnderBh: a ground knock-back shorter than this is the upright slide: the director carries him back distBh along the ground over slideTicks (Combat's 18), with no launch, no journey and no trench. At this length and over it is the skid: a launch whose plan carries slide 'feet' and the distance in units, for World's slide on the feet",
`],
]);
console.log("done");
