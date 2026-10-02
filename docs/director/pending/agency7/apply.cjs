// Agency slice 7: Game Design's rulings on the slice 4 baseline (agency-pass.md section 14): a plain blur's ender is
// half a set-up; the buried follow-up is a dive with a time limit, a charged shot is the other free blow, the AI bursts
// out; bolts and charged shots hit harder, and a full charged shot knocks back and is decisive; the AI fires more.
// node apply.cjs <repo root>. Idempotent. bury.gd beside this script replaces sim/director/bury.gd.
// Not mine, applied here by the EP's grant: data/fight/shots.json (Simulation).
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

fs.copyFileSync(path.join(__dirname, "bury.gd"), path.join(root, "sim/director/bury.gd"));
console.log("sim/director/bury.gd: written");

// ---------------------------------------------------------------- the state; nothing of his stops a dive on its way
edit("sim/director/interrupt.gd", [
  ["const N: int = 42\n",
   "const SETUP_FRAC: int = 42 # the part of a set-up against him, in thousandths (a plain blur's ender is half of one)\n" +
   "const BURY_N: int = 43     # live ticks since he was buried (DirBury)\n" +
   "const BURY_SHOT: int = 44  # the id of the follow-up shot on its way to his crater; 0 when none\n" +
   "const BURY_BURST: int = 45 # 1 once the buried AI has drawn its burst for this burial\n" +
   "const BAR_1: int = 46      # his last three bolts that landed clean on the rival, newest first (DirBlast._barrage):\n" +
   "const BAR_2: int = 47      # ... each the tick it landed << 12 | its ticks of flight; 0 when none\n" +
   "const BAR_3: int = 48\n" +
   "const BAR_IMMUNE: int = 49 # S.tick until which a barrage cannot knock him back again\n" +
   "const BAR_GUARD: int = 50  # S.tick until which the AI holds guard against a barrage that is building on it\n" +
   "const N: int = 51\n"],
  ["const BURY_E: int = 41     # the energy of the impact that buried him, in thousandths (from the embed event)\n",
   "const BURY_E: int = 41     # unused since World's deepen call (it was the energy of the impact that buried him)\n"],
  [L(1, "return ex == null or (ex.kind != \"sig\" and not DirExchange.finisherPlanned(ex))"),
   L(1, "return ex == null or (ex.kind != \"sig\" and not DirExchange.finisherPlanned(ex) and not DirBury.diving(S, f))   # a burst cannot escape a dive on its way")],
  [L(1, "if ex.kind == \"sig\" or (f != ex.A and f != ex.D) or DirExchange.finisherPlanned(ex):"),
   L(1, "if ex.kind == \"sig\" or (f != ex.A and f != ex.D) or DirExchange.finisherPlanned(ex) or DirBury.diving(S, f):")],
  [L(1, "if ex == null or f != ex.D or not DirData.allows(ex, \"reversal\"):"),
   L(1, "if ex == null or f != ex.D or not DirData.allows(ex, \"reversal\") or DirBury.diving(S, f):")],
]);

// ---------------------------------------------------------------- set-up weights; a decisive shot
edit("sim/director/exchange.gd", [
  ["static func decisive(S: SimState, ex, W, L, why: String) -> void:\n",
   "static func decisive(S: SimState, ex, W, L, why: String, setup: String = \"\") -> void:\n"],
  [L(1, "if W.brink and (W.brinkOpen or W.brinkSetups > 0):") +
   L(2, "if W.brinkOpen:") +
   L(3, "SimFx.brinkClose(S, W, \"won\")") +
   L(2, "W.brinkOpen = false") +
   L(2, "W.brinkSetups = 0") +
   L(1, "if not L.brink or finisherPlanned(ex):"),
   L(1, "_winCloses(S, W)") +
   L(1, "if not L.brink or finisherPlanned(ex):")],
  [L(2, "L.brinkSetups += 1") +
   L(2, "L.brinkEx = ex.n") +
   L(2, "if L.brinkSetups >= DirData.brinkSetups():") +
   L(3, "_openBrink(S, W, L)") + "\n",
   L(2, "_setup(S, W, L, setup if setup != \"\" else why, ex.n)") + "\n\n" +
   "## A win by a fighter on the brink closes its opening and starts the set-up count against it over.\n" +
   "static func _winCloses(S: SimState, W) -> void:\n" +
   L(1, "if W.brink and (W.brinkOpen or W.brinkSetups > 0 or DirInterrupt.gi(W, DirInterrupt.SETUP_FRAC) > 0):") +
   L(2, "if W.brinkOpen:") +
   L(3, "SimFx.brinkClose(S, W, \"won\")") +
   L(2, "W.brinkOpen = false") +
   L(2, "W.brinkSetups = 0") +
   L(2, "DirInterrupt.si(W, DirInterrupt.SETUP_FRAC, 0)") + "\n\n" +
   "## A set-up against L, on the brink, in exchange n (agency-pass.md section 14.4): worth launch.json setup.weight of its\n" +
   "## kind (1, and a plain blur's ender half of one). Whole set-ups are the fighter's count; the part left over is the\n" +
   "## director's state. Without the data every set-up is worth 1, as before.\n" +
   "static func _setup(S: SimState, W, L, kind: String, n: int) -> void:\n" +
   L(1, "var wt: Dictionary = DirLaunch.data().get(\"setup\", {}).get(\"weight\", {})") +
   L(1, "var fr: int = DirInterrupt.gi(L, DirInterrupt.SETUP_FRAC) + int(round(float(wt.get(kind, wt.get(\"default\", 1.0))) * 1000.0))") +
   L(1, "L.brinkSetups += fr / 1000") +
   L(1, "DirInterrupt.si(L, DirInterrupt.SETUP_FRAC, fr % 1000)") +
   L(1, "L.brinkEx = n") +
   L(1, "if fr % 1000 != 0:") +
   L(2, "SimEvents.feed(S, \"PART OF A SET-UP\", kind + \" against \" + L.name + \": \" + str(L.brinkSetups * 1000 + fr % 1000) + \" thousandths of \" + str(DirData.brinkSetups()))") +
   L(1, "if L.brinkSetups >= DirData.brinkSetups():") +
   L(2, "_openBrink(S, W, L)") + "\n\n" +
   "## A shot knocked L back (DirBlast: a fully charged shot, why blast; a barrage's ender, why barrage): decisive, outside\n" +
   "## any exchange. The brink chapter is decisive()'s: it closes the shooter's own opening; against a fighter who was on\n" +
   "## the brink before it landed (brink0) it is a set-up, worth setup.weight of 'setup' (or of why); and against one who\n" +
   "## is open (or past the time cap) it starts the shooter's finisher, as an exchange of its own.\n" +
   "## n: a number no exchange has (the shot's id, negated).\n" +
   "static func decisiveShot(S: SimState, W, L, n: int, brink0: bool, why: String = \"blast\", setup: String = \"\") -> void:\n" +
   L(1, "if S.game.ko != null:") +
   L(2, "return") +
   L(1, "SimFx.decisive(S, W, L, why)") +
   L(1, "SimWounds.onDecisive(S, null, W, L, why)") +
   L(1, "_winCloses(S, W)") +
   L(1, "if not L.brink or not brink0:") +
   L(2, "return") +
   L(1, "if S.game.timeCap or (L.brinkOpen and L.brinkEx != n):") +
   L(2, "_shotFinisher(S, W, L)") +
   L(1, "elif not L.brinkOpen and L.brinkEx != n:") +
   L(2, "_setup(S, W, L, setup if setup != \"\" else why, n)") + "\n\n" +
   "## The finisher after a decisive shot: there is no exchange to take over, so one starts here, the shooter its\n" +
   "## attacker. He closes in as any finisher's winner does. It needs the shooter free; otherwise the rival stays open.\n" +
   "static func _shotFinisher(S: SimState, W, L) -> void:\n" +
   L(1, "if S.dirS.ex != null or (W.state != \"free\" and W.state != \"charging\") or W.stunTicks > 0:") +
   L(2, "return") +
   L(1, "DirBands.endTaunt(S, W, false, \"cut\")") +
   L(1, "if DirBands.pending(W):") +
   L(2, "DirBands.drop(S, W, \"his finisher starts\")") +
   L(1, "var ex := newEx(W, L, \"heavy\")") +
   L(1, "W.exT = S.T") +
   L(1, "L.exT = S.T") +
   L(1, "ex.sA = W.stance") +
   L(1, "ex.sD = L.stance") +
   L(1, "W.face = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(W.x, L.x)), W.face)") +
   L(1, "L.face = -W.face") +
   L(1, "W.state = \"locked\"") +
   L(1, "if L.state == \"free\" or L.state == \"charging\":") +
   L(2, "L.state = \"locked\"   # carried back by the knock-back, as in an exchange") +
   L(1, "S.dirS.ex = ex") +
   L(1, "S.dirS.exN += 1; ex.n = S.dirS.exN") +
   L(1, "SimWounds.onExchangeStart(S, ex)") +
   L(1, "for s in range(S.fighters.size()):") +
   L(2, "if S.fighters[s].brink:") +
   L(3, "ex.startBrink |= 1 << s") +
   L(1, "DirInterrupt.onStart(S, ex, SimAct.SIG, W.act.mode, 0)   # no staleness: it is not a strike he chose") +
   L(1, "ex.tag = \"SHOT FINISHER\"") +
   L(1, "ex.loser = S.fighters.find(L)") +
   L(1, "SimEvents.feed(S, W.name + \" FINISHES FROM RANGE\", ex.tag)") +
   L(1, "SimFx.attack(S, W, L, \"heavy\", STN[int(L.stance)], ex.tag, false)") +
   L(1, "startFinisher(S, ex, W, L)") + "\n\n" +
   "## The part of a set-up lapses with the brink (SimWounds resets the whole count when a fighter enters or leaves it).\n" +
   "static func _setupLapse(S: SimState) -> void:\n" +
   L(1, "for f in S.fighters:") +
   L(2, "if not f.brink and DirInterrupt.gi(f, DirInterrupt.SETUP_FRAC) != 0:") +
   L(3, "DirInterrupt.si(f, DirInterrupt.SETUP_FRAC, 0)") + "\n"],
  [L(1, "L.brinkOpen = false") +
   L(1, "L.brinkSetups = 0") + "\n",
   L(1, "L.brinkOpen = false") +
   L(1, "L.brinkSetups = 0") +
   L(1, "DirInterrupt.si(L, DirInterrupt.SETUP_FRAC, 0)") + "\n"],
  [L(1, "DirLaunch.tick(S)   # an upright slide that ends early against an obstacle: the bump"),
   L(1, "DirLaunch.tick(S)   # an upright slide that ends early against an obstacle: the bump") +
   L(1, "_setupLapse(S)   # the part of a set-up lapses with the brink")],
]);

// ---------------------------------------------------------------- a plain blur's ender is half a set-up
edit("sim/director/melee.gd", [
  ["static func _knockDecisive(S: SimState, ex, att, tgt) -> void:\n",
   "static func _knockDecisive(S: SimState, ex, att, tgt, setup: String = \"\") -> void:\n"],
  [L(1, "DirExchange.decisive(S, ex, att, tgt, why)") + "\n\n## longOnly:",
   L(1, "DirExchange.decisive(S, ex, att, tgt, why, setup)") + "\n\n## longOnly:"],
  [L(4, "_knockDecisive(S, ex, att, tgt)") +
   L(3, "else:") +
   L(4, "SimEvents.feed(S, \"STAYS IN REACH\", \"a light: the brawl goes on\")"),
   L(4, "_knockDecisive(S, ex, att, tgt, \"\" if heavy else \"blurPlain\")   # a plain blur's ender is half a set-up (section 14.4)") +
   L(3, "else:") +
   L(4, "SimEvents.feed(S, \"STAYS IN REACH\", \"a light: the brawl goes on\")")],
]);

// ---------------------------------------------------------------- the blast as the other free blow; the full shot's knock-back
edit("sim/director/blast.gd", [
  [L(1, "if (A.state != \"free\" and A.state != \"charging\") or A.stunTicks > 0:") +
   L(2, "return true   # he cannot fire now: an energy press never becomes a rush") +
   L(1, "var c: Dictionary = data()"),
   L(1, "if (A.state != \"free\" and A.state != \"charging\") or A.stunTicks > 0:") +
   L(2, "return true   # he cannot fire now: an energy press never becomes a rush") +
   L(1, "if DirBury.blastFollow(S, A, SimRoster.opp(S, A)):") +
   L(2, "DirInterrupt.si(A, DirInterrupt.BLAST_LEFT, 0)   # a blast of his own winding up gives way") +
   L(2, "DirBury.fireBlast(S, A, SimRoster.opp(S, A))   # the other free blow on a buried rival: a charged shot, at once") +
   L(2, "return true") +
   L(1, "var c: Dictionary = data()")],
  [L(1, "if DirBury.safe(S, f):") +
   L(2, "SimFx.shotHit(S, sh, f, \"safe\")") +
   L(2, "return false"),
   L(1, "if DirBury.followShot(f, sh):") +
   L(2, "DirBury.shotLanded(f)   # the follow-up he was held for: it lands clean") +
   L(2, "SimDamage.hit(S, null, by, f, sh.dmg, {\"kind\": \"blast\", \"ignoreStance\": true, \"stop\": float(c.stopTicks) / DirData.TICKS_PER_SEC, \"shake\": 7.0})") +
   L(2, "SimFx.shotHit(S, sh, f, \"buried\")") +
   L(2, "return true") +
   L(1, "if DirBury.safe(S, f):") +
   L(2, "SimFx.shotHit(S, sh, f, \"safe\")") +
   L(2, "return false")],
  [L(1, "SimDamage.hit(S, null, by, f, dmg, {\"kind\": \"blast\", \"stop\": float(c.stopTicks) / DirData.TICKS_PER_SEC, \"shake\": 3.0 if sh.power < 2.0 else 7.0})") +
   L(1, "SimFx.shotHit(S, sh, f, outcome)") +
   L(1, "return true"),
   L(1, "var brink0: bool = f.brink") +
   L(1, "SimDamage.hit(S, null, by, f, dmg, {\"kind\": \"blast\", \"stop\": float(c.stopTicks) / DirData.TICKS_PER_SEC, \"shake\": 3.0 if sh.power < 2.0 else 7.0})") +
   L(1, "SimFx.shotHit(S, sh, f, outcome)") +
   L(1, "_knock(S, sh, by, f, outcome, brink0)") +
   L(1, "_barrage(S, sh, by, f, outcome, brink0)") +
   L(1, "return true") + "\n\n" +
   "## A barrage closes (agency-pass.md section 16), as a blur does: when enderAfter of a fighter's bolts land clean on his\n" +
   "## rival inside 'window' ticks, the last is a knock-back he did not press: decisive, never a launch. Clean: not guarded,\n" +
   "## not shrugged off, not a shot that was deflected. If each of them was fired measuredTicks or more after the one\n" +
   "## before, it goes the tier's full distance and is a full set-up; otherwise enderDist.plain of it and half a set-up.\n" +
   "## The count starts again, and the rival cannot be knocked back by another barrage for 'immune' ticks. A bolt that\n" +
   "## would close while he is in an exchange, down, flying or immune still counts, and the next clean one closes.\n" +
   "static func _barrage(S: SimState, sh, by, f, outcome: String, brink0: bool) -> void:\n" +
   L(1, "var c: Dictionary = data().get(\"barrage\", {})") +
   L(1, "if c.is_empty() or sh.kind != String(data().light.kind) or sh.deflected != 0 or (outcome != \"hit\" and outcome != \"stop\"):") +
   L(2, "return") +
   L(1, "var flight: int = clampi(sh.total - sh.left, 0, 4095)") +
   L(1, "var fires: Array = [S.tick - flight]   # the fire ticks of the clean bolts inside the window, newest first") +
   L(1, "for k in [DirInterrupt.BAR_1, DirInterrupt.BAR_2, DirInterrupt.BAR_3]:") +
   L(2, "var v: int = DirInterrupt.gi(by, k)") +
   L(2, "if v != 0 and S.tick - (v >> 12) < int(c.window):") +
   L(3, "fires.append((v >> 12) - (v & 4095))") +
   L(1, "var up: bool = S.game.ko == null and S.dirS.ex == null and (f.state == \"free\" or f.state == \"charging\")") +
   L(1, "if fires.size() < int(c.enderAfter) or not up or S.tick < DirInterrupt.gi(f, DirInterrupt.BAR_IMMUNE):") +
   L(2, "DirInterrupt.si(by, DirInterrupt.BAR_3, DirInterrupt.gi(by, DirInterrupt.BAR_2))") +
   L(2, "DirInterrupt.si(by, DirInterrupt.BAR_2, DirInterrupt.gi(by, DirInterrupt.BAR_1))") +
   L(2, "DirInterrupt.si(by, DirInterrupt.BAR_1, (S.tick << 12) | flight)") +
   L(2, "# The AI's answer (section 16: a held guard stops the count): as the barrage reaches half way, one draw at its") +
   L(2, "# level's rate, and it holds guard until those bolts have left the window.") +
   L(2, "if f.ai != null and fires.size() == int(c.enderAfter) / 2 and S.rng.next() < float(DirAI.lv().get(\"barrageGuard\", 0.0)):") +
   L(3, "DirInterrupt.si(f, DirInterrupt.BAR_GUARD, S.tick + int(c.window))") +
   L(2, "return") +
   L(1, "var measured: bool = true") +
   L(1, "for k in range(int(c.enderAfter) - 1):") +
   L(2, "if int(fires[k]) - int(fires[k + 1]) < int(c.measuredTicks):") +
   L(3, "measured = false") +
   L(1, "for k in [DirInterrupt.BAR_1, DirInterrupt.BAR_2, DirInterrupt.BAR_3]:") +
   L(2, "DirInterrupt.si(by, k, 0)") +
   L(1, "DirInterrupt.si(f, DirInterrupt.BAR_IMMUNE, S.tick + int(c.immune))") +
   L(1, "if DirBands.pending(f):") +
   L(2, "DirBands.drop(S, f, \"a barrage knocked him back\")") +
   L(1, "DirLaunch.knock(S, by, f, float(c.enderDist.measured if measured else c.enderDist.plain))") +
   L(1, "SimFx.cue(S, by, \"barrage_ender\", \"\", \"\")") +
   L(1, "SimEvents.feed(S, \"BARRAGE ENDER\", by.name + \"'s \" + str(int(c.enderAfter)) + \" clean bolts inside \" + str(int(c.window)) + \" ticks: a knock-back, \" + (\"measured\" if measured else \"spammed (the weak one)\"))") +
   L(1, "DirExchange.decisiveShot(S, by, f, -sh.id, brink0, \"barrage\", \"barrage\" if measured else \"barragePlain\")") + "\n\n" +
   "## A fully charged shot that lands clean knocks him back, and that is decisive (agency-pass.md section 14.6). Clean:\n" +
   "## not guarded and not shrugged off. Outside an exchange only, on a fighter who is up.\n" +
   "static func _knock(S: SimState, sh, by, f, outcome: String, brink0: bool) -> void:\n" +
   L(1, "var c: Dictionary = data()") +
   L(1, "if not c.heavy.get(\"knockFull\", false) or S.game.ko != null or S.dirS.ex != null:") +
   L(2, "return") +
   L(1, "if sh.kind != String(c.heavy.kind) or sh.dmg < float(SimShots.kinds[sh.kind].dmg) - 0.001:") +
   L(2, "return") +
   L(1, "if (outcome != \"hit\" and outcome != \"stop\") or (f.state != \"free\" and f.state != \"charging\"):") +
   L(2, "return") +
   L(1, "if DirBands.pending(f):") +
   L(2, "DirBands.drop(S, f, \"a full charged shot knocked him back\")") +
   L(1, "DirLaunch.knock(S, by, f, 1.0)") +
   L(1, "SimEvents.feed(S, \"CHARGED SHOT: KNOCK BACK\", \"a full charge landed clean on \" + f.name + \": decisive\")") +
   L(1, "DirExchange.decisiveShot(S, by, f, -sh.id, brink0)")],
]);

// ---------------------------------------------------------------- the AI's free blow: the dive, or the shot
edit("sim/director/ai.gd", [
  [L(1, "if f.state == \"free\" and DirBury.aiFollow(S, f, o):") +
   L(2, "i.heavy = true   # the free blow on a buried rival, at its level's rate"),
   L(1, "var bf: int = DirBury.aiFollow(S, f, o) if f.state == \"free\" else 0") +
   L(1, "if bf != 0:") +
   L(2, "i.heavy = true   # the free blow on a buried rival, at its level's rate: the dive, or the charged shot when the dive cannot land in time") +
   L(2, "if bf == DirBury.BLAST:") +
   L(3, "i.mode = 1") +
   L(1, "if S.tick < DirInterrupt.gi(f, DirInterrupt.BAR_GUARD):") +
   L(2, "a.st = 1.0   # a barrage is building on it: it guards until those bolts have left the window (DirBlast._barrage)")],
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
  j.blast.heavy.knockFull = true;
  j.blast.barrage = {
    enderAfter: 4,
    window: 90,
    measuredTicks: 10,
    enderDist: { measured: 1.0, plain: 0.6 },
    immune: 90,
    _note: "A barrage closes (agency-pass.md section 16). When enderAfter of a fighter's bolts land clean on his rival inside 'window' ticks (not guarded, not shrugged off, not deflected), the last is a knock-back he did not press: decisive (kind barrage), never a launch. measuredTicks: if each was fired this many ticks or more after the one before, it goes enderDist.measured of the tier's knock-back distance and is a full set-up; otherwise enderDist.plain and launch.json setup.weight.barragePlain. immune: the count starts again and the rival cannot be knocked back by another barrage for this many ticks",
  };
  j.buried = {
    enabled: true,
    followTicks: 40,
    landByTick: 100,
    guardFromTick: 40,
    burstFromTick: 40,
    burstWithinBh: 12,
    safeTicks: 10,
    damage: 66,
    deepen: 1.2,
    dive: { speed: 4000, minTicks: 18 },
    blast: { damage: 44 },
    _note: "The buried fighter (agency-pass.md sections 7 and 14.5; sim/director/bury.gd; World's embed holds him down for its own ticks, data/biomes/contact.json embed.ticks). followTicks: his rival's first attack press this soon after the burial is the free follow-up. A physical press is a dive: the director flies him to the crater at dive.speed (units a second, the light charge's; at least dive.minTicks), and the blow must land by landByTick of the burial, otherwise there is no follow-up. It is one heavy blow of 'damage' that he cannot answer, free of ki, with no launch, and it makes his crater 'deepen' times as deep as it was (WorldCrater.deepen). An energy press is the other free blow: a charged shot of blast.damage, free of ki, that arrives from any distance (data/fight/shots.json arriveTicks). He is held until the blow lands, never past landByTick; nothing of his stops a follow-up on its way. One follow-up to a burial. guardFromTick: his guard counts from this tick, or once the follow-up is used. burstFromTick: his burst throws him out, not before this tick; an AI bursts only when no follow-up is coming, with its rival within burstWithinBh (ai.json buriedBurst). safeTicks: out of the crater he is safe this long: no exchange starts on him and a shot passes",
  };
});
edit("data/director/launch.json", [
  [`  "blur": {
`,
   `  "setup": {
    "weight": {"default": 1.0, "blurPlain": 0.5, "barragePlain": 0.5},
    "_note": "Set-ups against a fighter on the brink (agency-pass.md sections 14.4 and 16). Opening him needs finishers.json contest.brinkSetups set-ups. weight: what a decisive win is worth, by its kind (launch, clash, guard_break, interrupt, knockback, beam, beam_clash, blast, barrage: default), blurPlain for a plain blur's own ender, from untimed presses, and barragePlain for a barrage's ender when any of its bolts was spammed: half of one each, so a masher or a spammer needs twice as many"
  },
  "blur": {
`],
]);
const GUARD = process.argv[3] || "6.5";   // the medium AI's guardRepeat (the masher's band); an argument only while it is tuned in scratch
const BG = (process.argv[4] || "0.2,0.5,0.8").split(",");   // barrageGuard by level; an argument only while it is tuned in scratch
const lvl = (share0, share1, follow, burst) => [
  `      "blastShare": ${share0},
      "buriedFollowUp": ${follow},
`,
  `      "blastShare": ${share1},
      "buriedFollowUp": ${follow},
      "buriedBurst": ${burst},
      "barrageGuard": ${BG[["0.2", "0.5", "0.8"].indexOf(burst)]},
`];
edit("data/director/ai.json", [
  lvl("0.1", "0.18", "0.4", "0.2"), lvl("0.2", "0.35", "0.8", "0.5"), lvl("0.25", "0.45", "1.0", "0.8"),
  [`      "perfectBlockMul": 1,
`,
   `      "perfectBlockMul": 0.9,
`],
  ["perfectBlockMul: its share of the perfectBlock rates above (band:", "perfectBlockMul: its share of the perfectBlock rates above (0.35, 0.6, 0.9: agency-pass.md section 16 took the hard AI from 1.0 to 0.9; band:"],
  [`      "guardRepeat": 8.75,
`,
   `      "guardRepeat": ${GUARD},
`],
  ["guardRepeat 8.75, punish 0.4 and punishHeavy 0.5 measured 40 of 100 on the buried-fighter build (guardRepeat 8: 56; 9.5 and 10.5: 35). The win rate is steep in guardRepeat and moves with every slice: re-measure after each. On slice 4 guardRepeat 8 gave 40, 7.5 gave 49, 7 gave 52",
   "guardRepeat 6.5, punish 0.4 and punishHeavy 0.5 measured 40 of 100 on the section 14 rulings (a plain blur's ender is half a set-up, which slows his kills; guardRepeat 6.0: 39; 8.75: 24). The win rate moves with every slice: re-measure after each. On the buried-fighter build guardRepeat 8.75 gave 40 and 8 gave 56"],
  [`it presses after reactTicks)",
`,
   `it presses after reactTicks: the dive, or the charged shot when the dive cannot land in time). buriedBurst: buried itself, the chance it bursts out when no follow-up is coming (one draw a burial, from interrupts.json buried.burstFromTick, with its rival within burstWithinBh). barrageGuard: the chance it holds guard when a barrage is half way to closing on it (agency-pass.md section 16: a held guard stops the count; one draw as the second clean bolt lands, and it guards until those bolts leave the window)",
`],
]);

// ---------------------------------------------------------------- not mine, by the EP's grant
edit("data/fight/shots.json", [   // Simulation's
  ["a bolt a third of a light (26 / 3)", "a bolt half a light (26 / 2; agency-pass.md section 14.6)"],
  ["a charged shot a full heavy (its value at 30 ticks of charge", "a charged shot 1.25 of a heavy (its value at 30 ticks of charge"],
  [`      "power": 1.0,
      "dmg": 8.67,
`,
   `      "power": 1.0,
      "dmg": 13.0,
`],
  [`      "power": 3.0,
      "dmg": 66.0,
      "lifeTicks": 120
`,
   `      "power": 3.0,
      "dmg": 82.5,
      "lifeTicks": 120
`],
]);
console.log("done");
