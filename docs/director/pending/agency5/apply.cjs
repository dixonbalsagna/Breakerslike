// Agency slice 5 (3a): blasts on the energy family. node apply.cjs <repo root>. Idempotent.
// blast.gd beside this script becomes sim/director/blast.gd.
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

fs.copyFileSync(path.join(__dirname, "blast.gd"), path.join(root, "sim/director/blast.gd"));
console.log("sim/director/blast.gd: written");

// ---------------------------------------------------------------- the state, and the guard press against a shot
edit("sim/director/interrupt.gd", [
  [`const N: int = 27
`,
   `const BLAST_LEFT: int = 27  # ticks left before his blast leaves (DirBlast); 0 when none is winding up
const BLAST_REQ: int = 28   # ... its weight | bolts queued behind it << 1 | a heavy's charge << 3 | the AI's charge target << 10
const BLAST_GROUP: int = 29 # the group of the volley he is firing (its first shot's id)
const BLAST_LAST: int = 30  # ... and the S.tick of its last bolt
const PB_SHOT: int = 31     # the shot his guard press marked for a perfect block: its group, or minus its id
const AI_SHOT: int = 32     # the last shot the AI weighed a perfect block against (the same key)
const BLAST_AT: int = 33    # S.tick of his last blast press
const PB_DEFL: int = 34     # ... and how many times the marked shot had been sent back when he marked it
const N: int = 35
`],
  [`		f.act.dirI[GUARD_AT] = NEVER
`,
   `		f.act.dirI[GUARD_AT] = NEVER
		f.act.dirI[BLAST_AT] = NEVER
`],
  [`	if b == null or (S.tick < gi(f, PB_LOCK) and not assist):
		# The lockout starts only when the press came during a visible wind-up and missed its window, or when two guard
`,
   `	if b == null and not (S.tick < gi(f, PB_LOCK) and not assist) and DirBlast.mark(S, f):
		return true   # a shot inside its window: the block resolves when it arrives (DirBlast.hit)
	if b == null or (S.tick < gi(f, PB_LOCK) and not assist):
		# The lockout starts only when the press came during a visible wind-up and missed its window, or when two guard
`],
  [`		if not assist and (_windupShowing(S.dirS.ex, f) or S.tick - last <= lock):
`,
   `		if not assist and (_windupShowing(S.dirS.ex, f) or DirBlast.incoming(S, f) or S.tick - last <= lock):   # a shot on its way is a wind-up he can see
`],
]);

// ---------------------------------------------------------------- the press, the upgrade, the tick
edit("sim/director/exchange.gd", [
  [`	if kind != "sig" and DirBands.farPressNow(S, A, KIND.find(kind), entry):
`,
   `	if kind != "sig" and A.act.mode == 1 and DirBlast.press(S, A, KIND.find(kind)):
		return   # the energy family, outside an exchange: the press fires a blast from where he stands, in any band
	if kind != "sig" and DirBands.farPressNow(S, A, KIND.find(kind), entry):
`],
  [`		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG) and not DirBands.upgrade(S, f, SimAct.HEAVY if up == 1 else SimAct.SIG):
`,
   `		if up > 0 and not SimAct.upgrade(f, SimAct.HEAVY if up == 1 else SimAct.SIG) and not DirBands.upgrade(S, f, SimAct.HEAVY if up == 1 else SimAct.SIG) and not DirBlast.upgrade(S, f, SimAct.HEAVY if up == 1 else SimAct.SIG):
`],
  [`	DirAlchemy.tick(S)   # the flow count lapses
`,
   `	DirAlchemy.tick(S)   # the flow count lapses
	DirBlast.tick(S)   # blasts winding up leave; the AI weighs a perfect block against a shot about to arrive
`],
]);

edit("sim/director/data.gd", [
  // a fighter who is firing is not pressing to meet a blow
  [`	ctx.defQueued = not dq.is_empty() or (S.T - D.lastAtkT) * TICKS_PER_SEC <= DEF_QUEUED_TICKS
`,
   `	ctx.defQueued = not dq.is_empty() or ((S.T - D.lastAtkT) * TICKS_PER_SEC <= DEF_QUEUED_TICKS and not DirBlast.pressedLately(S, D, DEF_QUEUED_TICKS))
`],
]);

// ---------------------------------------------------------------- the AI fires
edit("sim/director/ai.gd", [
  [`			if (i.light or i.heavy) and DirBands.farOn() and DirBands.band(f, o) == DirBands.FAR and not DirBands.taunting(o):
`,
   `			if (i.light or i.heavy) and DirBlast.on() and DirBands.band(f, o) != DirBands.CLOSE and not DirBands.taunting(o) and S.rng.next() < float(lv().get("blastShare", 0.0)):
				i.mode = 1   # it fires instead: a volley of bolts for a light, a charged shot for a heavy (DirBlast)
			elif (i.light or i.heavy) and DirBands.farOn() and DirBands.band(f, o) == DirBands.FAR and not DirBands.taunting(o):
`],
  [`	f.act.v2 = true
`,
   `	f.act.v2 = true
	i.mode = 0   # the physical family, unless this tick's press is a blast (below)
`],
]);

// ---------------------------------------------------------------- Simulation's file: the two hooks the shots design names
edit("sim/core/shots.gd", [
  [`static func hitFighter(S: SimState, sh, f) -> bool:
	SimDamage.hurt(S, f, sh.dmg, S.fighters[sh.owner], "spread", "blast", "", true)
`,
   `static func hitFighter(S: SimState, sh, f) -> bool:
	if DirBlast.rules(S):
		return DirBlast.hit(S, sh, f)   # the director's blast rules: the dodge, the perfect block's deflect, the guard, a charge
	SimDamage.hurt(S, f, sh.dmg, S.fighters[sh.owner], "spread", "blast", "", true)
`],
  [`					else:
						sh.passed |= 1 << k   # he let it pass: it flies on, and is not offered to him again
`,
   `					elif sh.owner != k:   # (a deflect made it his own shot: it is already on its way back)
						sh.passed |= 1 << k   # he let it pass: it flies on, and is not offered to him again
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
  j.blast = {
    enabled: true,
    light: { kind: "bolt", ki: 1, windupTicks: 6, holdTicks: 14, queueMax: 3, groupTicks: 20, aiVolley: 3 },
    heavy: { kind: "charged", ki: 8, windupTicks: 8, chargeTicks: 30, tapShare: 0.6, holdMaxTicks: 45 },
    stopTicks: 1,
    charge: { shrugPower: 1, shrugMul: 0.5 },
    _note: "Energy, the first slice (agency-pass.md section 5 and section 11, item 6; sim/director/blast.gd). With the energy family held, an attack press outside an exchange fires a blast from where he stands, in any band. light: a bolt (the kind in data/fight/shots.json) for 'ki', leaving windupTicks after the press (a light still held waits for its release, up to holdTicks, so a layout's hold can turn it into the heavy); presses while one winds up queue up to queueMax more; bolts fired within groupTicks of each other are one volley; the AI's light is aiVolley bolts. heavy: a charged shot for 'ki'; it charges while the button is held and leaves when it is let go (not before windupTicks, and by itself at holdMaxTicks); its damage rises from tapShare of the kind's to all of it over chargeTicks. stopTicks: the hit-stop of a blast that lands. charge: a fighter in a heavy charge takes a shot of power up to shrugPower at shrugMul of its damage and keeps coming; a stronger shot, or any shot on a light charge, stops him. The perfect block's window is perfectBlock.windows.blast; the shot's speed, power and damage are the kind's",
  };
});
const lvl = (answer, share) => [
  `      "answerTaunt": ${answer},
`,
  `      "answerTaunt": ${answer},
      "blastShare": ${share},
`];
edit("data/director/ai.json", [
  lvl("0.7", "0.1"), lvl("0.5", "0.2"), lvl("0.3", "0.25"),
  [`  "reactTicks": 14,
`,
   `  "_blastShare": "Per level, blastShare: the chance its attack beat outside the close band is a blast (a volley of bolts for a light, a charged shot for a heavy; it charges for a random part of the full time)",
  "reactTicks": 14,
`],
]);
console.log("done");
