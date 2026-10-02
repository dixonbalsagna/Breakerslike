// The first agency slice (docs/director/agency-evidence.md; docs/design/agency-pass.md). Usage, from the repo root: node docs/director/pending/agency1/apply-agency1.cjs .
//  1. The attacker's dodge-cancel is free before his first wind-up, and the stick at the press picks his arrival side.
//  2. The earned-launch gate, the knock-back as a skid, and "no launch" as a scored outcome in data.
//  3. The read-only press log (DirAlchemy).
//  4. QA's far strikes: a catch also places the striker on a body that came to rest this tick.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw "usage: node apply-agency1.cjs <root>";
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
function data(file, fn) {
  const j = JSON.parse(fs.readFileSync(P(file), "utf8"));
  fn(j);
  fs.writeFileSync(P(file), JSON.stringify(j, null, 2).replace(/\[\n\s+([-\d.]+),\n\s+([-\d.]+),\n\s+([-\d.]+),\n\s+([-\d.]+)\n\s+\]/g, "[$1, $2, $3, $4]") + "\n");
}

fs.copyFileSync(path.join(here, "alchemy.gd"), P("sim/director/alchemy.gd"));

// ---------------------------------------------------------------- data
{
  const f = P("data/director/launch.json");
  let t = fs.readFileSync(f, "utf8");
  if (!t.includes('"knockBack"')) {
    const add = {
      knockBack: {
        score: 25.0,
        distBh: [3.5, 5.0, 6.5, 8.0],
        groundMode: "skid",
        skidSpeed: [900.0, 1100.0, 1250.0, 1450.0],
        skidUy: 0.05,
        groundWithinBh: 0.5,
        driftTicks: 20,
        chain: false,
        _note: "The knock-back: a short send that is not a launch across the map (agency-pass.md section 3; Combat's brawl-endings-and-trades.md section 2). score: its base score against the launch candidates (it was the planner's NONE, 25). distBh: how far it sends the rival, in body heights, by the striker's tier (Combat's proposal). On the ground (within groundWithinBh of it, not over the sea) with groundMode 'skid' it is a low send with no travel boost that the ground-contact model skids: skidSpeed is its speed by tier, in units a second, sized to slide about distBh on open ground, and skidUy its small lift. Otherwise ('shove', or in the air: the drift) the rival is carried back distBh over driftTicks and stays upright. chain: whether a chain window may open after it"
      },
      earned: {
        enabled: true,
        enderAfter: 4,
        cleanTaken: 1,
        forceMul: 1.6,
        _note: "The earned launch (agency-pass.md section 3). enabled: the switch; off, every launch beat goes to the planner as before. With it on, a launch beat launches only when earned, by four things (Orb, questionnaire 14): a held heavy that lands; a heavy after enderAfter or more of the string's strikes landed (the ender of a full string); a heavy pressed with a stick direction that lands clean, which means the striker has taken no more than cleanTaken blows in the exchange; a clash won. A guard break and a riposte end in the knock-back. Not earned: a heavy gives the knock-back and a light leaves both fighters in reach. forceMul: the launch force of an earned launch, so fewer launches can be bigger ones (the impact wear itself is World's)"
      }
    };
    // keep the short arrays on one line, as the rest of the file has them
    const one = v => Array.isArray(v) ? "[" + v.map(x => JSON.stringify(x) + (Number.isInteger(x) ? ".0" : "")).join(", ") + "]" : JSON.stringify(v);
    const NL = String.fromCharCode(10);
    const block = (name, o) => "  " + JSON.stringify(name) + ": {" + NL + Object.keys(o).map(k => "    " + JSON.stringify(k) + ": " + (typeof o[k] === "number" && Number.isInteger(o[k]) && !["enderAfter", "cleanTaken", "driftTicks"].includes(k) ? o[k] + ".0" : one(o[k]))).join("," + NL) + NL + "  }";
    const body = block("knockBack", add.knockBack) + "," + NL + block("earned", add.earned);
    const k = t.lastIndexOf("}");
    t = t.slice(0, k).trimEnd() + "," + NL + body + NL + "}" + NL;
    JSON.parse(t);
    fs.writeFileSync(f, t);
  }
}
data("data/director/interrupts.json", j => {
  if (j.dodgeCancel.freeBeforeWindup === undefined) {
    j.dodgeCancel.freeBeforeWindup = true;
    j.dodgeCancel.freeGapTicks = 30;
    j.dodgeCancel._note += ". freeBeforeWindup: the attacker's cancel costs nothing until his first wind-up starts (agency-pass.md section 1, solution E); it then starts freeGapTicks of cooldown and not cooldownTicks";
  }
  if (!j.arrival) j.arrival = {
    tiltDead: 0.5,
    riseBh: 1.3,
    overShare: 0.6,
    _note: "The attacker's arrival side: with the stick up or down past tiltDead as he presses, his approach passes over (or under) the rival and lands on the far side. riseBh: how far over, in body heights. overShare: the share of the approach spent reaching the point above him"
  };
});

// ---------------------------------------------------------------- DirInterrupt: state, the free cancel
edit("sim/director/interrupt.gd", [
  [`const N: int = 13
`,
   `const LANDED: int = 13      # strikes it has landed in the exchange now running (the earned launch)
const PHRASE_P: int = 14    # the press that started its exchange or its latest chain link, as the press log packs it
const TAKEN: int = 15       # blows it has taken unblocked in the exchange now running (a heavy "landing clean")
const LAST_END: int = 16    # how the last launch beat of its exchange ended: END_LAUNCH, END_KNOCK or END_STAY
const N: int = 17
const END_LAUNCH: int = 0
const END_KNOCK: int = 1
const END_STAY: int = 2
`],
  [`	if f.ki < float(c.ki) or f.act.dodgeCool > 0 or f.state == "launched" or f.state == "down":
		return false
	if f == ex.D and S.tick - gi(f, HIT_AT) < int(c.gapTicks):
		return false   # the defender cancels only in a gap between strikes, never in hit-stun
	f.ki -= float(c.ki)
	f.act.dodgeCool = int(c.cooldownTicks)
`,
   `	# The attacker's cancel is free until his first wind-up starts (agency-pass.md section 1): he was flown in by the
	# director and may call it off. It still starts the short gap between dodges.
	var free: bool = c.get("freeBeforeWindup", false) and f == ex.A and ex.combo <= 1.0 and _beforeWindup(ex)
	if (not free and f.ki < float(c.ki)) or f.act.dodgeCool > 0 or f.state == "launched" or f.state == "down":
		return false
	if f == ex.D and S.tick - gi(f, HIT_AT) < int(c.gapTicks):
		return false   # the defender cancels only in a gap between strikes, never in hit-stun
	if free:
		f.act.dodgeCool = int(c.freeGapTicks)
	else:
		f.ki -= float(c.ki)
		f.act.dodgeCool = int(c.cooldownTicks)
`],
  [`# ---------------------------------------------------------------- the burst
`,
   `## True until the exchange's first wind-up starts: its wind beat is still pending.
static func _beforeWindup(ex) -> bool:
	for b in ex.beats:
		if b.op == "wind":
			return not b.done
	return false


# ---------------------------------------------------------------- the burst
`],
  // the exchange's bookkeeping for the earned launch
  [`	si(A, LAST_START, ex.n)
`,
   `	si(A, LAST_START, ex.n)
	si(A, LANDED, 0)
	si(D, LANDED, 0)
	si(D, TAKEN, 0)
	si(A, TAKEN, 0)
	var pp: int = DirAlchemy.last(S, A)
	si(A, PHRASE_P, pp if pp >= 0 and (pp & 1) == mini(weight, 1) else mini(weight, 1))   # the press log's newest press, when it is this one
	si(A, LAST_END, END_LAUNCH)
`]]);

// ---------------------------------------------------------------- the planner: the gate, the knock-back
edit("sim/director/launch.gd", [
  [`const NONE_BASE: float = 25.0       # "no launch"
`,
   `const NONE_BASE: float = 25.0       # "no launch" in the old profiles; the knock-back's score is data (launch.json knockBack.score)
`],
  [`	if not longOnly:
		c.append({"name": "NONE", "ux": 0.0, "uy": 0.0, "s": NONE_BASE})
	for k in c:
		k.s += S.rng.range_(0.0, NOISE)
		if k.name == "NONE":
`,
   `	if not longOnly and not noKnock:
		c.append({"name": "KNOCK BACK", "ux": 0.0, "uy": 0.0, "s": float(data().knockBack.score)})   # "no launch": a scored outcome (it was NONE)
	if sends != "":
		# Combat's hook (alchemist-content.md): a piece that names where it sends the rival keeps only those candidates.
		var keep: Array = SENDS.get(sends, [])
		c = c.filter(func(k): return k.name == "KNOCK BACK" or keep.has(k.name))
	if tilt > 0:
		# The stick's tilt (1 up, then clockwise by eighths): only candidates within TILT_CONE of it compete. A tilt back
		# through the launcher is not a direction a launch can take (the turning throw is M0): it keeps its up or down part.
		var tx: float = [0.0, 0.7071, 1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071][tilt - 1]
		var ty: float = [1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071, 0.0, 0.7071][tilt - 1]
		if tx * f < 0.0:
			tx = 0.0
		if tx != 0.0 or ty != 0.0:
			var tl: float = SimDetMath.hypot(tx, ty)
			var near: Array = c.filter(func(k): return k.name == "KNOCK BACK" or (k.ux * tx + k.uy * ty) / (tl * SimMathx.jmax(SimDetMath.hypot(k.ux, k.uy), 0.000001)) >= TILT_CONE)
			if near.any(func(k): return k.name != "KNOCK BACK"):
				c = near
	for k in c:
		k.s += S.rng.range_(0.0, NOISE)
		if k.name == "KNOCK BACK":
`],
  [`static func chooseLaunch(S: SimState, A, D, force: float, longOnly: bool = false) -> Dictionary:`,
   `static func chooseLaunch(S: SimState, A, D, force: float, longOnly: bool = false, sends: String = "", tilt: int = 0, noKnock: bool = false) -> Dictionary:`],
  [`## No launch: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
`,
   `const TILT_CONE: float = 0.7071     # the cosine of 45 degrees: how near the stick's tilt a launch candidate must point


## Which launch candidates a piece's "sends" tag keeps (Combat: across, up, down; turned waits for the turning throw).
const SENDS: Dictionary = {
	"across": ["SMASH ACROSS", "MOUNTAINSIDE", "BUILDING SMASH"],
	"up": ["UPPERCUT"],
	"down": ["DRIVE DOWN", "CRATER SLAM"],
}


## Whether att has earned a launch on tgt at this launch beat (agency-pass.md section 3; launch.json earned): Orb's four.
## Returns the reason, or "" when it has not.
static func earned(S: SimState, ex, att, tgt) -> String:
	var e: Dictionary = data().earned
	if ex.tag.begins_with("HEAVY CLASH"):
		return "a clash won"
	if ex.tag == "GUARD BREAK" or ex.tag == "RIPOSTE":
		return ""   # both end in a knock-back (Orb)
	var p: int = phrase(S, ex, att)
	if p < 0 or (p & 1) != SimAct.HEAVY:
		return ""
	if ((p >> 8) & 3) == DirAlchemy.HELD:
		return "a held heavy"
	var landed: int = DirInterrupt.gi(att, DirInterrupt.LANDED)
	if landed - 1 >= int(e.enderAfter):
		return "the ender of a full string (" + str(landed - 1) + " strikes landed before it)"
	if (p & DirAlchemy.INTENT) != 0 and DirInterrupt.gi(att, DirInterrupt.TAKEN) <= int(e.cleanTaken):
		return "a heavy with the stick, landing clean"
	return ""


## The press behind att's blow at this launch beat: the attacker's is the one that started his exchange or link; the
## defender's (a counter) is his newest press. Packed as the press log packs it; -1 when he pressed nothing.
static func phrase(S: SimState, ex, att) -> int:
	return DirInterrupt.gi(att, DirInterrupt.PHRASE_P) if att == ex.A else DirAlchemy.last(S, att)


## Whether the blow at this launch beat came from a heavy press (the knock-back) or a light one (the brawl goes on). A
## guard break and a launching riposte are heavy blows whatever was pressed.
static func heavyBlow(S: SimState, ex, att) -> bool:
	if ex.tag == "GUARD BREAK" or ex.tag == "RIPOSTE":
		return true
	var p: int = phrase(S, ex, att)
	return p >= 0 and (p & 1) == SimAct.HEAVY


## The knock-back (launch.json knockBack): a short send, not a launch across the map. On the ground it is a low,
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
	tgt.vx = 0.0
	tgt.vy = 0.0
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)


## No launch in the old profiles: the strike shoves the (locked) target back along the attacker's facing.
static func knockBack(S: SimState, att, tgt) -> void:
	tgt.vx += att.face * KNOCKBACK
	SimFx.ring(S, tgt.x, tgt.y + 34.0, 300.0, "#ffffff", 0.25, 12.0)
`]]);

// ---------------------------------------------------------------- melee: the launch beat, landed strikes, the catch
edit("sim/director/melee.gd", [
  [`static func launchBeat(S: SimState, ex, att, tgt, force: float, longOnly: bool = false) -> void:
	if ex.cancel or S.game.ko != null:
		return
	var r: Dictionary = DirLaunch.chooseLaunch(S, att, tgt, force, longOnly)
`,
   `## args (the launch beat's own): "ends" and "sends" are Combat's hooks (alchemist-content.md): a piece that ends "level"
## never sends the rival away, and "sends" keeps only the launch candidates in that direction.
static func launchBeat(S: SimState, ex, att, tgt, force: float, longOnly: bool = false, args = null) -> void:
	if ex.cancel or S.game.ko != null:
		return
	var ends: String = String(args.get("ends", "")) if args != null else ""
	var gate: Dictionary = DirLaunch.data().get("earned", {})
	var why: String = "the gate is off"
	if not longOnly and (gate.get("enabled", false) or ends == "level") and not DirData.contact().is_empty():
		# The earned launch (agency-pass.md section 3): not earned, a heavy gives the knock-back and a light leaves both
		# fighters in reach, so the brawl goes on.
		why = DirLaunch.earned(S, ex, att, tgt) if ends != "level" else ""
		if why == "":
			var heavy: bool = DirLaunch.heavyBlow(S, ex, att) and ends != "level"
			DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_KNOCK if heavy else DirInterrupt.END_STAY)
			SimFx.launchPlan(S, att, tgt, "", "KNOCK BACK" if heavy else "STAY")
			if heavy:
				DirLaunch.knock(S, att, tgt)
				SimEvents.feed(S, "KNOCK BACK", "a heavy, but no launch was earned")
			else:
				SimEvents.feed(S, "STAYS IN REACH", "a light: the brawl goes on")
			return
		force *= float(gate.get("forceMul", 1.0))
	# The stick picks the direction and the planner snaps to the most dramatic target near it (a human's press only).
	var pt: int = DirLaunch.phrase(S, ex, att) if (att.ai == null and not longOnly and not DirData.contact().is_empty()) else -1
	var r: Dictionary = DirLaunch.chooseLaunch(S, att, tgt, force, longOnly, String(args.get("sends", "")) if args != null else "", (pt >> 4) & 15 if pt >= 0 else 0, gate.get("enabled", false) and not DirData.contact().is_empty())
`],
  [`	if r.best.name == "NONE":
		# Nothing scored above holding back: the strike shoves the target instead of launching it.
		DirLaunch.knockBack(S, att, tgt)
		SimEvents.feed(S, "NO LAUNCH", "  |  ".join(parts))
`,
   `	if r.best.name == "KNOCK BACK":
		# Nothing scored above holding back: the strike knocks the target back instead of launching it.
		DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_KNOCK)
		if DirData.contact().is_empty():
			DirLaunch.knockBack(S, att, tgt)   # the old profiles keep the shove
		else:
			DirLaunch.knock(S, att, tgt)
		SimEvents.feed(S, "KNOCK BACK", "  |  ".join(parts))
`],
  [`	SimEvents.feed(S, "LAUNCH: " + r.best.name, "  |  ".join(parts))
`,
   `	DirInterrupt.si(ex.A, DirInterrupt.LAST_END, DirInterrupt.END_LAUNCH)
	SimEvents.feed(S, "LAUNCH: " + r.best.name + (" (earned: " + why + ")" if gate.get("enabled", false) and not longOnly else ""), "  |  ".join(parts))
`],
  // a landed strike counts toward the earned launch; a normal block does not
  [`	if dmg > 0.0 and not o.get("ignoreStance", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:
		DirInterrupt.onBlock(S, ex, d)   # a normal block: the reversal's window
`,
   `	if dmg > 0.0 and not o.get("ignoreStance", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:
		DirInterrupt.onBlock(S, ex, d)   # a normal block: the reversal's window
	elif dmg > 0.0:
		DirInterrupt.si(a, DirInterrupt.LANDED, DirInterrupt.gi(a, DirInterrupt.LANDED) + 1)   # a landed strike: the earned launch counts them
		DirInterrupt.si(d, DirInterrupt.TAKEN, DirInterrupt.gi(d, DirInterrupt.TAKEN) + 1)
`],
  // QA's far strikes: a body that came to rest on this very tick is still a catch
  [`	var catching: bool = d.state == "launched" or (a.rush != null and a.rush.tgt == d)
`,
   `	var catching: bool = d.state == "launched" or d.state == "down" or (a.rush != null and a.rush.tgt == d)   # "down": it hit a wall or stopped on this tick
`]]);

// ---------------------------------------------------------------- the exchange
edit("sim/director/exchange.gd", [
  // the press log
  [`	if DirBeam.inClash(S, A):
		return
	if not A.act.v2:
`,
   `	if DirBeam.inClash(S, A):
		return
	DirAlchemy.log(S, A, KIND.find(kind), A.act.mode)   # the press log (read-only for now)
	if not A.act.v2:
`],
  [`		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG):
			SimAct.push(f, SimAct.HEAVY if up == 1 else SimAct.SIG, f.act.mode, 0, S.tick)
`,
   `		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG):
			SimAct.push(f, SimAct.HEAVY if up == 1 else SimAct.SIG, f.act.mode, 0, S.tick)
		if up == 1:
			DirAlchemy.held(f)   # the press log: the newest press was held
`],
  // an opening, for the earned launch; the press log's feed line
  [`	if opn != 0:
		DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
`,
   `	if opn != 0:
		DirInterrupt.si(A, DirInterrupt.OPEN_UNTIL, 0)
	if kind != "sig" and DirInterrupt.on():
		DirAlchemy.report(S, ex)
`],
  // the approach: the stick at the press picks the arrival side
  [`			var r := SimState.Rush.new()
			r.tgt = D
			r.off = DirMelee.sideOff(A, D, a.off, String(a.get("side", "own")))
			r.end = S.T + a.dur
			A.rush = r
`,
   `			if DirMelee.approachOver(S, ex, a):
				return   # the stick was up or down at the press: he comes in over (or under) the rival and lands on the far side
			var r := SimState.Rush.new()
			r.tgt = D
			r.off = DirMelee.sideOff(A, D, a.off, String(a.get("side", "own")))
			r.end = S.T + a.dur
			A.rush = r
`],
  [`		"dodgeLand":
			DirMelee.opDodgeLand(S, ex, a)
`,
   `		"dodgeLand":
			DirMelee.opDodgeLand(S, ex, a)
		"rushLand":
			DirMelee.opRushLand(S, ex, a)
		"knockBack":
			DirLaunch.knock(S, D if a.get("w", "A") == "D" else A, A if a.get("w", "A") == "D" else D)   # Combat's op (brawl endings): w sends the other
		"stagger":
			var sg = A if a.get("w", "D") == "A" else D
			sg.stunTicks = maxi(sg.stunTicks, int(a.get("ticks", 0)))   # Combat's op: w cannot act for ticks
`],
  [`		"launch":
			DirMelee.launchBeat(S, ex, D if a.rev else A, A if a.rev else D, a.force)
`,
   `		"launch":
			DirMelee.launchBeat(S, ex, D if a.rev else A, A if a.rev else D, a.force, false, a)
`],
  // the chain link's weight; no chain window after a knock-back
  [`			if A.act.v2:
				SimAct.pop(A)
			chain(S, ex)
`,
   `			if A.act.v2:
				var rq: Array = SimAct.pop(A)
				var lp: int = DirAlchemy.at(A, int(rq[3]))
				DirInterrupt.si(A, DirInterrupt.PHRASE_P, lp if lp >= 0 and (lp & 1) == mini(int(rq[0]), 1) else mini(int(rq[0]), 1))   # the link's press, for the earned launch
			chain(S, ex)
`],
  [`	if DirInterrupt.lastBlowBlocked(S, ex):
		return   # step 3: a blocked string opens no chain window; its attacker is left behind (DirInterrupt.onEnd)
`,
   `	if DirInterrupt.lastBlowBlocked(S, ex):
		return   # step 3: a blocked string opens no chain window; its attacker is left behind (DirInterrupt.onEnd)
	if DirInterrupt.on() and DirInterrupt.gi(ex.A, DirInterrupt.LAST_END) == DirInterrupt.END_KNOCK and not DirLaunch.data().knockBack.get("chain", false):
		return   # a knock-back opens no chain window: the rival was sent off, not juggled
`]]);
// the AI's presses made by the director are logged too
edit("sim/director/exchange.gd", [
  [`			if a.get("sig", false):
				SimAct.push(who, SimAct.SIG, who.act.mode, 0, S.tick)`,
   `			if a.get("queue", false) or a.get("blast", false):
				DirAlchemy.log(S, who, SimAct.HEAVY if a.get("blast", false) else SimAct.LIGHT, 1 if a.get("blast", false) else who.act.mode)
			if a.get("sig", false):
				SimAct.push(who, SimAct.SIG, who.act.mode, 0, S.tick)`]]);

edit("sim/director/melee.gd", [
  [`## The step-around's second move: down behind the attacker, at its height.
`,
   `## The attacker's arrival side (interrupts.json arrival): a human who holds the stick up or down as he presses comes in
## over (or under) the rival and lands on the far side, in two moves like the dodge's step-around. True when it took
## the approach. Only the exchange's first move, and only with a contact block.
static func approachOver(S: SimState, ex, a) -> bool:
	var A = ex.A
	var D = ex.D
	if A.ai != null or not A.act.v2 or ex.t > SimConst.DT * 1.5 or ex.combo > 1.0 or DirData.contact().is_empty():
		return false
	var ar: Dictionary = DirInterrupt.data().get("arrival", {})
	if ar.is_empty() or absf(A.input.my) <= float(ar.tiltDead):
		return false
	var far: float = -SimDamage.jor(SimMathx.jsign(SimWrap.sdx(D.x, A.x)), -A.face)   # the far side of the rival, from where he is now
	var rise: float = float(ar.riseBh) * BODY_H
	var over: bool = A.input.my > 0.0 or D.y - rise < WorldTerrain.groundY(S, D.x) + BODY_H
	var leg: float = float(a.dur) * float(ar.overShare)
	var r := SimState.Rush.new()
	r.px = SimWrap.wrap(D.x + far * DODGE_PAST)
	r.py = D.y + (rise if over else -rise)
	r.end = S.T + leg
	A.rush = r
	DirExchange.schedule(ex, ex.t + leg, "rushLand", {"far": far, "dur": float(a.dur) - leg, "off": a.off})
	SimFx.rush(S, A, D, S.tick + int(float(a.dur) / SimConst.DT))
	return true


## The approach's second move after coming in over the rival: down on the far side, at its height.
static func opRushLand(S: SimState, ex, args) -> void:
	if ex.A.state == "launched" or ex.A.state == "down":
		return
	var r := SimState.Rush.new()
	r.tgt = ex.D
	r.off = float(args.far) * maxf(float(args.off), float(DirData.contact().minSeparation))
	r.end = S.T + float(args.dur)
	ex.A.rush = r


## The step-around's second move: down behind the attacker, at its height.
`]]);

// the loader hashes nothing new: launch.json and interrupts.json are already in the data hash
// ---------------------------------------------------------------- the director's own presses are logged
edit("sim/director/ai.gd", [[
  `		SimAct.push(D, SimAct.LIGHT, D.act.mode, 0, S.tick)
`,
  `		DirAlchemy.log(S, D, SimAct.LIGHT, D.act.mode)
		SimAct.push(D, SimAct.LIGHT, D.act.mode, 0, S.tick)
`]]);
edit("sim/director/interrupt.gd", [
  [`		SimAct.push(d, SimAct.HEAVY if launch else SimAct.LIGHT, d.act.mode, 0, S.tick)
`,
   `		DirAlchemy.log(S, d, SimAct.HEAVY if launch else SimAct.LIGHT, d.act.mode)
		SimAct.push(d, SimAct.HEAVY if launch else SimAct.LIGHT, d.act.mode, 0, S.tick)
`],
  [`	SimAct.push(f, SimAct.HEAVY, f.act.mode, 0, S.tick)
`,
   `	DirAlchemy.log(S, f, SimAct.HEAVY, f.act.mode)
	SimAct.push(f, SimAct.HEAVY, f.act.mode, 0, S.tick)
`],
  [`		SimAct.push(ex.D, SimAct.HEAVY if S.rng.next() < float(lv.punishHeavy) else SimAct.LIGHT, ex.D.act.mode, 0, S.tick)
`,
   `		var pw: int = SimAct.HEAVY if S.rng.next() < float(lv.punishHeavy) else SimAct.LIGHT
		DirAlchemy.log(S, ex.D, pw, ex.D.act.mode)
		SimAct.push(ex.D, pw, ex.D.act.mode, 0, S.tick)
`],
  // the phrase's press is the one stamped with the request's tick
  [`	var pp: int = DirAlchemy.last(S, A)
`,
   `	var pp: int = DirAlchemy.at(A, DirExchange.planTick if DirExchange.planTick >= 0 else S.tick)
`]]);
edit("sim/director/exchange.gd", [
  [`static var planStale: int = 0
`,
   `static var planStale: int = 0
static var planTick: int = -1   # the tick of the request being started (its press in the log), -1 outside _drain
`],
  [`			planEntry = int(SimAct.peek(f)[2])   # step 2b: the direction held at the press, for the plan's atkEntry
			var r: int = _start(S, f, KIND[int(SimAct.peek(f)[0])])
			planEntry = 0
`,
   `			planEntry = int(SimAct.peek(f)[2])   # step 2b: the direction held at the press, for the plan's atkEntry
			planTick = int(SimAct.peek(f)[3])
			var r: int = _start(S, f, KIND[int(SimAct.peek(f)[0])])
			planEntry = 0
			planTick = -1
`],
  // the AI's chain press: a heavy once enough of the string has landed (the ender of a full string)
  [`			if a.get("queue", false) or a.get("blast", false):
				DirAlchemy.log(S, who, SimAct.HEAVY if a.get("blast", false) else SimAct.LIGHT, 1 if a.get("blast", false) else who.act.mode)
`,
   `			var ender: bool = a.get("queue", false) and DirInterrupt.on() and DirLaunch.data().get("earned", {}).get("enabled", false) and DirInterrupt.gi(who, DirInterrupt.LANDED) >= int(DirLaunch.data().earned.enderAfter)
			if a.get("queue", false) or a.get("blast", false):
				DirAlchemy.log(S, who, SimAct.HEAVY if (a.get("blast", false) or ender) else SimAct.LIGHT, 1 if a.get("blast", false) else who.act.mode)
`],
  [`				SimAct.push(who, SimAct.LIGHT, who.act.mode, 0, S.tick)   # the AI's chain press is a queued request, as a player's is
`,
   `				SimAct.push(who, SimAct.HEAVY if ender else SimAct.LIGHT, who.act.mode, 0, S.tick)   # the AI's chain press is a queued request, as a player's is; a heavy when the string is full (its ender)
`]]);

// ---------------------------------------------------------------- the AI's launch intent
{
  const f = P("data/director/ai.json");
  let t = fs.readFileSync(f, "utf8");
  if (!t.includes('"launchIntent"')) {
    const vals = { easy: [0.7, 0.1], medium: [1.0, 0.25], hard: [1.0, 0.35] };
    for (const l of ["easy", "medium", "hard"]) {
      const j = JSON.parse(t).levels[l];
      const anchor = '"punishHeavy": ' + JSON.stringify(j.punishHeavy);
      const i = t.indexOf(anchor, t.indexOf('"' + l + '": {'));
      if (i < 0) throw new Error("ai.json: no punishHeavy in " + l);
      t = t.slice(0, i + anchor.length) + ',' + String.fromCharCode(10) + '      "launchIntent": ' + vals[l][0] + ',' + String.fromCharCode(10) + '      "heldHeavy": ' + vals[l][1] + t.slice(i + anchor.length);
    }
    t = t.replace("burstAtLink: the chain link at which it bursts out (0: never).", "burstAtLink: the chain link at which it bursts out (0: never). launchIntent: the chance its heavy is thrown with a direction, to launch (the earned launch's third rule; its stick is its flight path, so this stands for a player's tilt). heldHeavy: the chance it charges a heavy by holding it (the first rule).");
    JSON.parse(t);
    fs.writeFileSync(f, t);
  }
}
console.log("agency slice 1 applied to " + root);
