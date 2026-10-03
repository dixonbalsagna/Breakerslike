// Agency slice 8 (3c): the beam plays (agency-pass.md section 5; rule-of-cool.md section 2).
// node apply.cjs <repo root>. Idempotent. beamplay.gd beside this script becomes sim/director/beamplay.gd.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw new Error("usage: node apply.cjs <repo root>");
const L = (n, s) => "\t".repeat(n) + s + "\n";

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

fs.copyFileSync(path.join(__dirname, "beamplay.gd"), path.join(root, "sim/director/beamplay.gd"));
console.log("sim/director/beamplay.gd: written");

// ---------------------------------------------------------------- the state; the beam's own perfect-block window
edit("sim/director/interrupt.gd", [
  ["const N: int = 51\n",
   "const BEAM_AI: int = 51    # the AI defender's plan for the beam coming at it (DirBeamPlay.AI_*)\n" +
   "const BEAM_FIRE: int = 52  # S.tick the beam aimed at him left\n" +
   "const BEAM_TRAVEL: int = 53   # the ticks his own main beam takes to reach its target; 0 when it is not on its way under the plays\n" +
   "const BEAM_REACH: int = 54 # ... and how far along it the target is, in whole units\n" +
   "const BEAM_DODGED: int = 55   # 1 once he tapped dodge inside the window of the beam coming at him\n" +
   "const N: int = 56\n"],
  ["return b if left <= _window(f, \"heavy\", true) + 0.5 and not b.args.get(\"perfect\", false) else null",
   "return b if left <= _window(f, \"beam\" if DirBeamPlay.on() else \"heavy\", true) + 0.5 and not b.args.get(\"perfect\", false) else null"],
]);

// ---------------------------------------------------------------- the beam leaves at the fire beat and reaches him later
edit("sim/director/beam.gd", [
  [L(1, "if DirData.beamAtFire() and D.ai != null:") +
   L(2, "var canSig: bool = (D.ki >= 45.0 and S.T >= D.sigReadyT) or SimFighter.sigFree(D)   # the last stand answers free") +
   L(2, "if (canSig or D.ki >= 40.0) and S.rng.next() < float(DirAI.lv().beamAnswer):") +
   L(3, "DirExchange.schedule(ex, ex.t + S.rng.range_(0.15, 0.6), \"press\", {\"who\": \"D\", \"sig\": canSig, \"blast\": not canSig})"),
   L(1, "var answers: bool = false") +
   L(1, "if DirData.beamAtFire() and D.ai != null:") +
   L(2, "var canSig: bool = (D.ki >= 45.0 and S.T >= D.sigReadyT) or SimFighter.sigFree(D)   # the last stand answers free") +
   L(2, "if (canSig or D.ki >= 40.0) and S.rng.next() < float(DirAI.lv().beamAnswer):") +
   L(3, "answers = true") +
   L(3, "DirExchange.schedule(ex, ex.t + S.rng.range_(0.15, 0.6), \"press\", {\"who\": \"D\", \"sig\": canSig, \"blast\": not canSig})") +
   L(1, "DirBeamPlay.aiPlan(S, ex, answers)   # the beam plays: its perfect block and its look, its dodge, its wade, a late answer")],
  [L(2, "var answer: String = _answer(S, D)") +
   L(2, "var res: Dictionary = DirData.beamOutcome(S, ex, dist, answer, args.get(\"perfect\", false))"),
   L(2, "var answer: String = _answer(S, D)") +
   L(2, "if answer == \"none\" and DirBeamPlay.on():") +
   L(3, "DirBeamPlay.fire(S, ex, args)   # the beam plays: it leaves now, and the outcome is read when it reaches him") +
   L(3, "return") +
   L(2, "var res: Dictionary = DirData.beamOutcome(S, ex, dist, answer, args.get(\"perfect\", false))")],
  [L(1, "S.beams.append(b)") +
   L(1, "SimFx.shake(S, 14.0, ox)"),
   L(1, "S.beams.append(b)") +
   L(1, "if DirInterrupt.on():") +
   L(2, "DirInterrupt.si(A, DirInterrupt.BEAM_TRAVEL, 0)   # a beam at its own speed, unless DirBeamPlay.fire says otherwise") +
   L(1, "SimFx.shake(S, 14.0, ox)")],
  [L(2, "var np: float = SimMathx.jmin(1.0, b.t / 0.22)"),
   L(2, "var np: float = SimMathx.jmin(1.0, b.t / 0.22)") +
   L(2, "var tv: int = DirBeamPlay.travel(S, b)") +
   L(2, "if tv > 0:") +
   L(3, "np = DirBeamPlay.front(b, tv)   # the beam plays: it reaches the defender at a set tick, at any distance")],
  [L(2, "if b.t > b.life:") +
   L(3, "S.beams.remove_at(i)"),
   L(2, "if b.t > b.life:") +
   L(3, "if tv > 0:") +
   L(4, "DirInterrupt.si(b.A, DirInterrupt.BEAM_TRAVEL, 0)") +
   L(3, "S.beams.remove_at(i)")],
]);

// ---------------------------------------------------------------- the new beats, the late answer, no pause after a walk
edit("sim/director/exchange.gd", [
  [L(2, "\"clashResolve\":") +
   L(3, "DirBeam.opClashResolve(S, ex, a)"),
   L(2, "\"clashResolve\":") +
   L(3, "DirBeam.opClashResolve(S, ex, a)") +
   L(2, "\"beamReach\":") +
   L(3, "DirBeamPlay.opReach(S, ex, a)") +
   L(2, "\"beamArrive\":") +
   L(3, "DirBeamPlay.opArrive(S, ex, a)")],
  [L(1, "DirInterrupt.tick(S)   # step 3: this tick's inputs inside the exchange (perfect block, reversal, dodge-cancel, burst)"),
   L(1, "DirInterrupt.tick(S)   # step 3: this tick's inputs inside the exchange (perfect block, reversal, dodge-cancel, burst)") +
   L(1, "DirBeamPlay.lateTick(S, ex)   # a late answer to a beam on its way")],
  [L(1, "S.dirS.cool = cooldownAfter(ex)"),
   L(1, "S.dirS.cool = cooldownAfter(ex)") +
   L(1, "DirBeamPlay.onEnd(S, ex)   # no pause after a walk through a beam")],
]);

// ---------------------------------------------------------------- the old dodge roll is out under the plays
edit("sim/director/data.gd", [
  ["static func beamOutcome(S: SimState, ex, dist: float, answer: String, perfect: bool = false) -> Dictionary:\n",
   "static func beamOutcome(S: SimState, ex, dist: float, answer: String, perfect: bool = false, noRoll: bool = false) -> Dictionary:\n"],
  [L(2, "if rule.has(\"defender\") and rule.defender != defState:") +
   L(3, "continue") +
   L(2, "if rule.has(\"if\") and not _cond(rule[\"if\"], ctx):"),
   L(2, "if rule.has(\"defender\") and rule.defender != defState:") +
   L(3, "continue") +
   L(2, "if noRoll and String(rule.get(\"defender\", \"\")) == \"EVASIVE\":") +
   L(3, "continue   # the beam plays: a dodge is a timed tap (DirBeamPlay.opReach), not a roll") +
   L(2, "if rule.has(\"if\") and not _cond(rule[\"if\"], ctx):")],
]);

// ---------------------------------------------------------------- the AI defender
edit("sim/director/ai.gd", [
  ["S.tick - f.act.dodgeTick >= SimAct.dodgeWindow - 1\n",
   "S.tick - f.act.dodgeTick >= SimAct.dodgeWindow - 1 and DirBeamPlay.aiMayDodge(S, f)\n"],
  [L(1, "var free: bool = f.state == \"free\" or f.state == \"charging\""),
   L(1, "var bd: float = DirBeamPlay.aiDir(S, f)") +
   L(1, "if bd != 0.0:") +
   L(2, "i.mx = bd   # the stick it holds as a beam reaches it: the look of its perfect block, or the wade") +
   L(1, "var free: bool = f.state == \"free\" or f.state == \"charging\"")],
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
  j.perfectBlock.windows.beam = 12;
  j.beamPlays = {
    enabled: true,
    travelTicks: 20,
    afterTicks: 42,
    dodge: { beforeTicks: 14, afterTicks: 6 },
    late: { ticks: 20, scoreAdd: -10 },
    walk: { speed: 3000, minTicks: 24, maxTicks: 54, recoverTicks: 20 },
    split: { spreadDeg: 14, lenBh: 12, widthMul: 0.5, powerMul: 0.6 },
    swat: { lenBh: 30, skyDeg: 50, groundDeg: 20 },
    _note: "The beam plays (agency-pass.md section 5; rule-of-cool.md section 2; sim/director/beamplay.gd). enabled false: a beam is decided at its fire beat, as before. travelTicks: a signature not answered in its tell reaches the defender this many ticks after it fires, at any distance; the outcome is read on that tick. afterTicks: the exchange's length after that. dodge: a dodge tap in the last beforeTicks of the tell or the first afterTicks of the beam avoids it, with no roll. late: the defender's own signature or heavy energy attack within ticks of the fire stops the beam in a struggle that starts scoreAdd on his score. The perfect block's window against a beam is perfectBlock.windows.beam; its look is the direction held as the beam reaches him: away the swat, level the split, toward the walk. A held guard with the stick toward is the wade (guard damage, no launch). walk: he advances at speed (units a second), for minTicks to maxTicks, and the attacker is left recoverTicks of recovery when he arrives. split: two lesser beams leave him spreadDeg either side of the beam's line, lenBh long, at widthMul of its width and powerMul of its power. swat: the turned beam is lenBh long; a fighter with an anguish meter sends it up at skyDeg, one with a menace meter at the nearest standing building within lenBh, anyone else down at groundDeg",
  };
});
const lvl = (follow, dodge, wade, late) => [
  `      "buriedFollowUp": ${follow},
`,
  `      "buriedFollowUp": ${follow},
      "beamDodge": ${dodge},
      "beamWade": ${wade},
      "beamLate": ${late},
`];
edit("data/director/ai.json", [
  lvl("0.4", "0.4", "0.3", "0.05"), lvl("0.8", "0.55", "0.5", "0.1"), lvl("1.0", "0.7", "0.7", "0.2"),
  [`  "reactTicks": 14,
`,
   `  "beamLook": {"split": 1.0, "walk": 1.0, "swat": 1.0},
  "_beam": "The beam plays (sim/director/beamplay.gd), drawn once as a signature starts charging at the AI. Per level: beamDodge, the chance its dodge is in time when it is dodging; beamWade, the chance it holds toward when it guards (the wade); beamLate, the chance of a late answer when it did not answer in the tell and can pay for one. Its perfect block against a beam uses perfectBlock (guard, press, heavyAdd) times perfectBlockMul. beamLook: the weights of the look of that perfect block",
  "reactTicks": 14,
`],
]);
console.log("done");
