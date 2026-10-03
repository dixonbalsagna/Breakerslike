// Agency slice 11: the alchemy layer's A4 and A3's blur and combo upgrades (docs/director/alchemy-plan.md;
// agency-pass.md sections 2, 18 and 20). Applies on top of slice 10. node apply.cjs <repo root>. Idempotent.
// blur.gd beside this script becomes sim/director/blur.gd (new). It also places Combat's parked
// docs/combat/pending/recipes.slice11.json as data/combat/recipes.json (the EP's grant); Tools' apply-pieces.cjs adds its schema keys.
//  - The window lapses as a whole 90 ticks after his last press; the style is Controls' read (the share of heavies).
//  - A blur string draws a cadence and a pattern when it starts; its blows land on the cadence; four presses on the
//    beat in a row lock it in (full strikes, the full ender).
//  - The rhythm tag and the flow follow the beat (Controls' grade); the AI times its presses at its level's rate.
//  - Flow gates the string's ender; the stick earner counts only as its own exchange; the showcase cue at flow 5.
//  - In the combo style a strike from a timed press does comboMul.
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

fs.copyFileSync(path.join(__dirname, "blur.gd"), path.join(root, "sim/director/blur.gd"));
console.log("sim/director/blur.gd: written");

// ---------------------------------------------------------------- Combat's slice 11 recipes become the live file (the EP's grant: this one file)
{
  const src = path.join(root, "docs/combat/pending/recipes.slice11.json");
  const dst = path.join(root, "data/combat/recipes.json");
  let t = fs.readFileSync(src, "utf8");
  for (const k of ["_target", "_changes"]) {
    const line = new RegExp("^[ \t]*\"" + k + "\":[^\n]*\n", "m");
    if (!line.test(t)) throw new Error("recipes: no " + k + " line in the parked file");
    t = t.replace(line, "");   // Combat: it lands without _target and _changes
  }
  JSON.parse(t);
  fs.writeFileSync(dst, t);
  console.log("data/combat/recipes.json: written from Combat's parked slice 11 file");
}

// ---------------------------------------------------------------- the log: the blur's state, the window, the tags, the AI's timing
edit("sim/director/alchemy.gd", [
  ["const PIECE_2: int = READ + 2\nconst SIZE: int = READ + 3\n",
   "const PIECE_2: int = READ + 2\n" +
   "const BLUR_CAD: int = READ + 3               # his blur string's cadence, in ticks between blows; 0 when he is in none (DirBlur)\n" +
   "const BLUR_PAT: int = READ + 4               # ... its pattern, as its place in the recipes' names plus 1; 0 for none\n" +
   "const BLUR_STEP: int = READ + 5              # ... the step of the pattern its next blow takes\n" +
   "const BLUR_ON: int = READ + 6                # ... his presses on the beat in a row\n" +
   "const BLUR_U1: int = READ + 7                # ... the pieces the string has used, as hashes, newest first\n" +
   "const BLUR_U2: int = READ + 8\n" +
   "const BLUR_U3: int = READ + 9\n" +
   "const BLUR_U4: int = READ + 10\n" +
   "const BLUR_AT: int = READ + 11               # ... the live tick its last blow landed on\n" +
   "const SIZE: int = READ + 12\n"],
  [L(2, "var n: int = maxi(1, int(ceil((b.t - ex.t) * DirData.TICKS_PER_SEC - 0.000001)))"),
   L(2, "var n: int = 0   # the steps until the beat runs: the director adds a tick to the exchange's clock, then runs every beat at or before it") +
   L(2, "var tt: float = ex.t") +
   L(2, "while n <= BEAT_REACH + 1 and (n == 0 or tt < b.t):") +
   L(3, "tt += SimConst.DT") +
   L(3, "n += 1")],
  [L(1, "var timed: bool = _timed(S, f)") +
   L(1, "var mashing: bool = n >= 2 and S.tick - f.act.dirI[T0 + (n - 2) % RING] <= MASH_TICKS"),
   L(1, "var timed: bool = _timed(S, f)") +
   L(1, "var mashing: bool = n >= 2 and S.tick - f.act.dirI[T0 + (n - 2) % RING] <= MASH_TICKS") +
   L(1, "var keep: bool = false   # a press with no blow to time against leaves the flow as it is") +
   L(1, "if DirInterrupt.on():") +
   L(2, "# The beat decides (alchemy-plan.md A3): a press is timed when it is within the beat's window (Controls' grade)") +
   L(2, "# of a blow of the exchange, either fighter's. A press outside any exchange has no beat: the flow stays. In a") +
   L(2, "# blur string the beat is tighter (Controls' blurBeatHalf), and Controls' steady read locks the blur in. The AI times") +
   L(2, "# its presses at its level's rate.") +
   L(2, "var ex = S.dirS.ex") +
   L(2, "var inEx: bool = ex != null and (f == ex.A or f == ex.D)") +
   L(2, "keep = not inEx and (f.ai != null or beat == SimPressRead.NO_BEAT)") +
   L(2, "if f.ai != null:") +
   L(3, "timed = inEx and ((aiBeat == 1) if aiBeat >= 0 else S.rng.next() < float(DirAI.lv().get(\"timedPress\", 0.0)))") +
   L(2, "else:") +
   L(3, "timed = beat != SimPressRead.NO_BEAT and SimPressRead.grade_of(beat) == \"perfect\"") +
   L(2, "if weight == SimAct.LIGHT and DirBlur.live(S, f):") +
   L(3, "var hit: bool = timed if f.ai != null else (beat != SimPressRead.NO_BEAT and absi(beat) <= int(SimPressRead.params().get(\"blurBeatHalf\", 2)))") +
   L(3, "timed = DirBlur.onPress(S, f, hit, f.ai == null and bool(c.steady))")],
  [L(1, "if DirInterrupt.on():") +
   L(2, "SimAct.setFlow(S, f, mini(FLOW_MAX, f.act.flow + 1) if timed else 0)"),
   L(1, "if DirInterrupt.on() and not keep:") +
   L(2, "SimAct.setFlow(S, f, mini(int(DirRecipe.cfg().get(\"flow\", {}).get(\"max\", FLOW_MAX)), f.act.flow + 1) if timed else 0)")],
  ["## A press: weight (SimAct.LIGHT or HEAVY; a signature is not an ingredient), family (0 physical, 1 energy), and the stick.\n",
   "## The AI's press being logged is on the beat (1) or off it (0), decided where it was planned (DirBlur.aiPress); -1, the\n" +
   "## log draws. Not state: it lives for one call.\n" +
   "static var aiBeat: int = -1\n\n\n" +
   "## A press: weight (SimAct.LIGHT or HEAVY; a signature is not an ingredient), family (0 physical, 1 energy), and the stick.\n"],
  ["## release on the flash. That read is recorded with each press (READ). The rhythm tag on each press (held, mashed,\n## timed) and the flow still follow the director's own rules; they move onto the read with the timing upgrades (A3).\n",
   "## release on the flash. That read is recorded with each press (READ). In the dynamic profile the timed tag and the\n## flow follow the beat (Controls' grade; in a blur string the blur's own beat, DirBlur); the mashed tag is three\n## presses inside MASH_TICKS.\n"],
  ["\t# The tags and the flow keep the director's own rules in this slice: timed is one of his own blows landing within\n\t# TIMED_TICKS of the press, and mashed is three presses inside MASH_TICKS. Controls' read is recorded beside them\n\t# (READ) and takes the tags over with the timing upgrades (alchemy-plan.md A3).\n",
   "\t# Outside the dynamic profile the timed tag keeps the old rule: one of his own blows landing within TIMED_TICKS of\n\t# the press. Mashed is three presses inside MASH_TICKS in every profile.\n"],
  [L(1, "for k in range(maxi(0, n - WINDOW), n):") +
   L(2, "if S.tick - f.act.dirI[T0 + k % RING] <= LIFE:") +
   L(3, "out.append(f.act.dirI[P0 + k % RING])") +
   L(1, "return out"),
   L(1, "# Section 20: his last five presses stay until LIFE ticks pass with no press, and then the window clears as a") +
   L(1, "# whole (as the flow does, and as Controls' classifier reads its mix).") +
   L(1, "if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > LIFE:") +
   L(2, "return out") +
   L(1, "for k in range(maxi(0, n - WINDOW), n):") +
   L(2, "out.append(f.act.dirI[P0 + k % RING])") +
   L(1, "return out")],
  [L(3, "if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > FLOW_LIFE:"),
   L(3, "if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > int(DirRecipe.cfg().get(\"flow\", {}).get(\"lapseTicks\", FLOW_LIFE)):")],
]);

// ---------------------------------------------------------------- the style by share; the blur's pattern picks the piece
edit("sim/director/recipe.gd", [
  ["static func cfg() -> Dictionary:\n" + L(1, "_ensure()") + L(1, "return _cfg") + "\n",
   "static func cfg() -> Dictionary:\n" + L(1, "_ensure()") + L(1, "return _cfg") + "\n\n" +
   "## Combat's recipes (data/combat/recipes.json); {} when the file is not there.\n" +
   "static func rec() -> Dictionary:\n" + L(1, "_ensure()") + L(1, "return _rec") + "\n"],
  [L(1, "var rows = _rec.get(\"styles\", STYLES)") +
   L(1, "for st in rows:"),
   L(1, "var rows = _rec.get(\"styles\", STYLES)") +
   L(1, "# Section 20: the style goes by the share of heavies among the presses in the window, and Controls' classifier") +
   L(1, "# reads it (none is blur, up to its powerShare combo, over it power; a lone heavy is power).") +
   L(1, "var want: String = String(DirAlchemy.read(S, f).get(\"recipe\", \"\"))") +
   L(1, "for st in rows:") +
   L(2, "if String(st.id) == (\"blur\" if want == \"none\" else want):") +
   L(3, "return st") +
   L(1, "for st in rows:")],
  [L(2, "var id: String = pick(S, who, poolName(S, who, weight, toward, b == lastA and (blurEnder or weight == SimAct.HEAVY)), salt)"),
   L(2, "# A blur string's blows follow its pattern, and its closing blow lands where its last light did.") +
   L(2, "var closing: bool = who == ex.A and weight == SimAct.LIGHT and b == lastA and DirBlur.live(S, who) and (blurEnder or DirInterrupt.gi(who, DirInterrupt.LANDED) >= int(DirLaunch.data().get(\"blur\", {}).get(\"enderAfter\", 99)))") +
   L(2, "var id: String = \"\"") +
   L(2, "if closing:") +
   L(3, "id = DirBlur.ender(S, who)") +
   L(2, "elif who == ex.A and weight == SimAct.LIGHT:") +
   L(3, "id = DirBlur.piece(S, who, toward)") +
   L(2, "if id == \"\":") +
   L(3, "id = pick(S, who, poolName(S, who, weight, toward, b == lastA and (closing or blurEnder or weight == SimAct.HEAVY)), salt)")],
]);

// ---------------------------------------------------------------- a blur string starts, and its links land on the cadence
edit("sim/director/exchange.gd", [
  [L(1, "DirRecipe.dress(S, ex)   # the alchemist: each strike of the plan takes a piece from the pool its fighter's style calls"),
   L(1, "DirBlur.onStart(S, ex, kind)   # a light press in the blur style starts a blur string: its cadence and its pattern") +
   L(1, "DirRecipe.dress(S, ex)   # the alchemist: each strike of the plan takes a piece from the pool its fighter's style calls")],
  [L(1, "if ex.A.ai != null and S.rng.next() < SimMathx.jclamp(0.62 - 0.14 * ex.combo, 0.05, 0.6):") +
   L(2, "schedule(ex, ex.t + S.rng.range_(0.12, 0.35), \"press\", {\"who\": \"A\", \"queue\": ex.A.act.v2})"),
   L(1, "if ex.A.ai != null and S.rng.next() < SimMathx.jclamp(0.62 - 0.14 * ex.combo, 0.05, 0.6):") +
   L(2, "var pa: Dictionary = {\"who\": \"A\", \"queue\": ex.A.act.v2}") +
   L(2, "var late: float = S.rng.range_(0.12, 0.35)") +
   L(2, "schedule(ex, ex.t if DirBlur.aiPress(S, ex, pa) else ex.t + late, \"press\", pa)   # in a blur string its press is on the beat at its level's rate")],
  [L(3, "var ender: bool = a.get(\"queue\", false) and DirInterrupt.on() and DirLaunch.data().get(\"earned\", {}).get(\"enabled\", false) and DirInterrupt.gi(who, DirInterrupt.LANDED) >= int(DirLaunch.data().earned.enderAfter) and S.rng.next() < float(DirAI.lv().get(\"earnerUse\", 1.0))") +
   L(3, "if a.get(\"queue\", false) or a.get(\"blast\", false):") +
   L(4, "DirAlchemy.log(S, who, SimAct.HEAVY if (a.get(\"blast\", false) or ender) else SimAct.LIGHT, 1 if a.get(\"blast\", false) else who.act.mode)"),
   L(3, "var ender: bool = a.get(\"queue\", false) and DirInterrupt.on() and DirLaunch.data().get(\"earned\", {}).get(\"enabled\", false) and DirLaunch.aiEnder(who) and S.rng.next() < float(DirAI.lv().get(\"earnerUse\", 1.0))") +
   L(3, "if a.get(\"queue\", false) or a.get(\"blast\", false):") +
   L(4, "DirAlchemy.aiBeat = (1 if a.onBeat else 0) if a.has(\"onBeat\") else -1") +
   L(4, "DirAlchemy.log(S, who, SimAct.HEAVY if (a.get(\"blast\", false) or ender) else SimAct.LIGHT, 1 if a.get(\"blast\", false) else who.act.mode)") +
   L(4, "DirAlchemy.aiBeat = -1")],
  [L(1, "A.ki -= 6.0") +
   L(1, "var t: float = ex.t"),
   L(1, "A.ki -= 6.0") +
   L(1, "var t: float = ex.t") +
   L(1, "var before: Array = ex.beats.duplicate()   # the link's own beats are the ones planned after this (DirBlur.onLink)")],
  [L(2, "planCheck.call(chk, ex, S.rng.a, \"chain\")") +
   L(1, "DirRecipe.dress(S, ex)   # the link's strikes take their pieces"),
   L(2, "planCheck.call(chk, ex, S.rng.a, \"chain\")") +
   L(1, "DirBlur.onLink(S, ex, before)   # in a blur string the link's blow lands on the cadence") +
   L(1, "DirRecipe.dress(S, ex)   # the link's strikes take their pieces")],
]);

// ---------------------------------------------------------------- flow gates the string's ender; the stick only as its own exchange
edit("sim/director/launch.gd", [
  [L(1, "var landed: int = DirInterrupt.gi(att, DirInterrupt.LANDED)") +
   L(1, "if landed - 1 >= int(e.enderAfter):") +
   L(2, "return \"the ender of a full string (\" + str(landed - 1) + \" strikes landed before it)\""),
   L(1, "var landed: int = DirInterrupt.gi(att, DirInterrupt.LANDED)") +
   L(1, "var fl: Dictionary = DirRecipe.cfg().get(\"flow\", {})   # data/director/alchemy.json") +
   L(1, "if fl.get(\"enabled\", false):") +
   L(2, "# Section 18: flow governs the string's ender. A heavy that ends a string of stringAfter or more landed strikes") +
   L(2, "# launches only at flow launchAt or more; below that it is a knock-back, and the stick only aims. The stick") +
   L(2, "# earner below is for a heavy that is its own exchange.") +
   L(2, "if landed - 1 >= int(fl.enderAfter):") +
   L(3, "return (\"the ender of a string at flow \" + str(att.act.flow) + \" (\" + str(landed - 1) + \" strikes landed before it)\") if att.act.flow >= int(fl.launchAt) else \"\"") +
   L(1, "elif landed - 1 >= int(e.enderAfter):") +
   L(2, "return \"the ender of a full string (\" + str(landed - 1) + \" strikes landed before it)\"")],
  ["## The press behind att's blow at this launch beat:",
   "## Whether the AI's next link press is its ender, a heavy: the string is full, or (with the flow gate) it has landed\n" +
   "## enderAfter strikes and its flow would launch.\n" +
   "static func aiEnder(who) -> bool:\n" +
   L(1, "var e: Dictionary = data().earned") +
   L(1, "var landed: int = DirInterrupt.gi(who, DirInterrupt.LANDED)") +
   L(1, "var fl: Dictionary = DirRecipe.cfg().get(\"flow\", {})") +
   L(1, "if fl.get(\"enabled\", false):") +
   L(2, "return landed >= int(fl.enderAfter) and who.act.flow >= int(fl.launchAt)") +
   L(1, "return landed >= int(e.enderAfter)") +
   "\n\n" +
   "## The press behind att's blow at this launch beat:"],
]);

// ---------------------------------------------------------------- the blur's strikes and ender, the timed combo strike, the showcase cue
edit("sim/director/melee.gd", [
  [L(3, "if pp >= 0 and (pp & 1) == SimAct.LIGHT and ((pp >> 8) & 3) == DirAlchemy.MASHED:") +
   L(4, "dmg *= float(bl.strikeMul)"),
   L(3, "DirBlur.onBlow(S, a)   # a blur string's cadence counts from this blow") +
   L(3, "if DirBlur.live(S, a) and ex.combo > 1.0:") +
   L(4, "# Section 20: a plain blur's strikes do strikeMul of a light each; a blur that is locked in lands clean.") +
   L(4, "if not DirBlur.perfect(S, a):") +
   L(5, "dmg *= float(bl.strikeMul)") +
   L(3, "elif pp >= 0 and (pp & 1) == SimAct.LIGHT and ((pp >> 8) & 3) == DirAlchemy.MASHED:") +
   L(4, "dmg *= float(bl.strikeMul)") +
   L(3, "# Clean and hard (section 2): in the combo style a strike from a timed press does comboMul.") +
   L(3, "var tm: Dictionary = DirRecipe.cfg().get(\"timing\", {})") +
   L(3, "if pp >= 0 and ((pp >> 8) & 3) == DirAlchemy.TIMED and tm.has(\"comboMul\") and DirRecipe.style(S, a) == \"combo\":") +
   L(4, "dmg *= float(tm.comboMul)")],
  [L(4, "DirLaunch.knock(S, att, tgt, 1.0 if heavy else float(bl.enderDist))"),
   L(4, "# The perfect blur's ender (section 20): locked in, it goes the full distance and is a full set-up; a plain") +
   L(4, "# blur's goes enderDist and is half of one.") +
   L(4, "var perfect: bool = ender and DirBlur.perfect(S, att)") +
   L(4, "DirLaunch.knock(S, att, tgt, 1.0 if heavy else (float(bl.get(\"perfectDist\", 1.0)) if perfect else float(bl.enderDist)))")],
  [L(4, "SimEvents.feed(S, \"KNOCK BACK\" if heavy else \"BLUR ENDER\", \"a heavy, but no launch was earned\" if heavy else \"the light after \" + str(DirInterrupt.gi(att, DirInterrupt.LANDED) - 1) + \" landed strikes: the blur closes with its own knock-back\")"),
   L(4, "SimEvents.feed(S, \"KNOCK BACK\" if heavy else \"BLUR ENDER\", \"a heavy, but no launch was earned\" if heavy else (\"locked in: the pattern's closing blow and the full knock-back\" if perfect else \"the light after \" + str(DirInterrupt.gi(att, DirInterrupt.LANDED) - 1) + \" landed strikes: the blur closes with its own knock-back\"))")],
  [L(4, "_knockDecisive(S, ex, att, tgt, \"\" if heavy else \"blurPlain\")   # a plain blur's ender is half a set-up (section 14.4)"),
   L(4, "_knockDecisive(S, ex, att, tgt, \"\" if (heavy or perfect) else \"blurPlain\")   # a plain blur's ender is half a set-up (section 14.4); a locked-in blur's is a full one")],
  [L(1, "DirLaunch.doLaunch(S, att, tgt, r.best, force, longOnly)") +
   L(1, "if r.best.has(\"p\") and r.best.p.get(\"building\", false):"),
   L(1, "DirLaunch.doLaunch(S, att, tgt, r.best, force, longOnly)") +
   L(1, "# The showcase (section 2): a string's ender launched at flow showcaseAt is the showcase ender. The cue is the panel's;") +
   L(1, "# Combat's showcase rows and the extra impact wear wait for their data and for a wear hook on a launch.") +
   L(1, "if not longOnly and why.begins_with(\"the ender of a string\") and att.act.flow >= int(DirRecipe.cfg().get(\"flow\", {}).get(\"showcaseAt\", 99)):") +
   L(2, "SimFx.cue(S, att, \"showcase_ender\", \"\", \"\")") +
   L(2, "SimEvents.feed(S, att.name + \" SHOWCASE ENDER\", \"a string's ender at flow \" + str(att.act.flow))") +
   L(1, "if r.best.has(\"p\") and r.best.p.get(\"building\", false):")],
]);

// ---------------------------------------------------------------- data
edit("data/director/launch.json", [
  [`    "strikeMul": 0.8,
`,
   `    "strikeMul": 0.8,
    "perfectDist": 1.0,
`],
]);
function json(rel, fn) {
  const f = path.join(root, rel);
  const txt = fs.readFileSync(f, "utf8");
  const j = JSON.parse(txt);
  fn(j);
  const eol = txt.includes("\r\n") ? "\r\n" : "\n";
  fs.writeFileSync(f, JSON.stringify(j, null, 2).split("\n").join(eol) + eol);
  console.log(rel + ": written");
}
json("data/director/alchemy.json", j => {
  j.flow = {
    enabled: true,
    max: 5,
    lapseTicks: 90,
    enderAfter: 1,
    launchAt: 3,
    showcaseAt: 5,
    _note: "The flow count (agency-pass.md sections 2, 18 and 20). A timed press adds 1, up to max: a press within the beat's window (Controls' data/input/timing.json read.beatHalf; in a blur string, the blur's beat below) of a blow of the exchange, either fighter's. A press off the beat sets it to 0, and so do lapseTicks with no press. A press outside any exchange leaves it as it is. The AI's presses are timed at its level's ai.json timedPress. enabled: flow gates the string's ender: a heavy that lands after enderAfter or more landed strikes of his in the exchange is the string's ender, and it launches only at flow launchAt or more; below that it knocks back and the stick only aims (launch.json earned.enderAfter is then not read). The stick earner is for a heavy with nothing landed before it. An ender launched at flow showcaseAt sends the showcase cue. false: the earners of launch.json alone",
  };
  j.timing = {
    comboMul: 1.15,
    _note: "Clean and hard (agency-pass.md section 2): in the combo style a strike from a timed press does comboMul of its damage",
  };
  j.blur = {
    enabled: true,
    cadences: [7, 8, 9, 10],
    minLeadTicks: 5,
    _note: "The blur string (agency-pass.md section 20; sim/director/blur.gd). A string that starts on a light press in the blur style draws its cadence from 'cadences' (ticks between its blows) and its pattern from the recipes' blurPatterns, by keyed draws. The chain window opens on the blow; a link whose press is waiting lands one cadence after the last blow, and a later press lands minLeadTicks after it. The lock is Controls' steady read (data/input/timing.json read.steadyPresses presses in a row, each within blurBeatHalf ticks of a different blow's contact): from it each strike does a full light's damage (a plain blur's does launch.json blur.strikeMul) and the ender is the full one (launch.json blur.perfectDist, a full set-up). The AI's blur locks after steadyPresses of its presses in a row were timed. A heavy press ends the blur. enabled false: strings keep the template's timing and no blur locks in",
  };
});
const lvl = (guard, timed) => [
  `      "barrageGuard": ${guard},
`,
  `      "barrageGuard": ${guard},
      "timedPress": ${timed},
`];
edit("data/director/ai.json", [
  [`      "guardRepeat": 5.0,
`, `      "guardRepeat": 6.5,
`],
  [`On the buried-fighter build guardRepeat 8.75 gave 40 and 8 gave 56",`,
   `On the buried-fighter build guardRepeat 8.75 gave 40 and 8 gave 56. On slice 11 (a blur's blows land on its cadence, about twice as fast) 5.0 gave 52, 5.5 gave 50, 6.0 gave 45, 6.5 gave 42, 7.0 gave 35, and 6.5 is in",`],
  lvl("0.2", "0.4"), lvl("0.42", "0.65"), lvl("0.8", "0.85"),
  [`  "reactTicks": 14,
`,
   `  "_timedPress": "Per level, timedPress: the chance each of its attack presses is timed (agency-pass.md section 2: 40, 65 and 85%). A timed press adds to its flow and, in a blur string, counts toward locking the blur in; a press that is not sets both back",
  "reactTicks": 14,
`],
]);
console.log("done");
