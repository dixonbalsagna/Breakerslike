// Agency slice 9: the director's side of the wild deflect, the spray cone and mines (agency-pass.md sections 15.2,
// 15.4, 15.5 and 17; the core's side is docs/architecture/shots.md sections 15 to 17). Applies on top of slice 8.
// node apply.cjs <repo root>. Idempotent.
// Not mine, applied here by the EP's grant: data/fight/shots.json deflect.scatter true (Simulation's switch).
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

// ---------------------------------------------------------------- the state; the context press outside an exchange
edit("sim/director/interrupt.gd", [
  ["const N: int = 56\n",
   "const FREE_UNTIL: int = 56 # S.tick until which the approach he starts cannot be stopped by a shot (a deflect earned it)\n" +
   "const CTX_SHOT: int = 57   # the shot (or volley) his context deflect is set for: its group, or minus its id; 0 when none\n" +
   "const CTX_DEFL: int = 58   # ... and that shot's deflect count when it was set\n" +
   "const SPRAY: int = 59      # his bolts' spread, in thousandths (the spray cone)\n" +
   "const N: int = 60\n"],
  [L(1, "if ex != null:") +
   L(2, "_aiBlocks(S, ex)"),
   L(1, "for f in order:") +
   L(2, "if f.input.context and f.stunTicks <= 0 and (f.ai != null or _human(f)):") +
   L(3, "DirBlast.context(S, f)   # outside an exchange: a mine with the energy family held, the context deflect on a held guard") +
   L(1, "if ex != null:") +
   L(2, "_aiBlocks(S, ex)")],
]);

// ---------------------------------------------------------------- an approach no shot stops
edit("sim/director/bands.gd", [
  ["const CHARGED: int = 1 << 8   # APPR_REQ: ... and the rival was holding a heavy charge when he was met: he enters with an edge\n",
   "const CHARGED: int = 1 << 8   # APPR_REQ: ... and the rival was holding a heavy charge when he was met: he enters with an edge\n" +
   "const FREE: int = 1 << 9      # APPR_REQ: the free approach a deflect earned: no shot stops it (DirBlast.hit)\n"],
  [L(1, "DirInterrupt.si(A, DirInterrupt.APPR_REQ, weight | ((entry + 1) << 2) | (opn << 4) | (CHARGE if charge else 0))"),
   L(1, "var free: bool = S.tick < DirInterrupt.gi(A, DirInterrupt.FREE_UNTIL)   # a deflect's free approach: this charge or lunge uses it") +
   L(1, "if free:") +
   L(2, "DirInterrupt.si(A, DirInterrupt.FREE_UNTIL, 0)") +
   L(1, "DirInterrupt.si(A, DirInterrupt.APPR_REQ, weight | ((entry + 1) << 2) | (opn << 4) | (CHARGE if charge else 0) | (FREE if free else 0))")],
]);

// ---------------------------------------------------------------- a knock-back from a point (a mine's blast)
edit("sim/director/launch.gd", [
  ["static func knock(S: SimState, att, tgt, mul: float = 1.0) -> void:\n",
   "static func knock(S: SimState, att, tgt, mul: float = 1.0, ox: float = NAN) -> void:\n"],
  [L(1, "var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(att.x, tgt.x)), att.face)") +
   L(1, "var g: float = WorldTerrain.groundY(S, tgt.x)") +
   L(1, "var dist: float = float(kb.distBh[ti]) * BH * mul"),
   L(1, "var s: float = SimDamage.jor(SimMathx.jsign(SimWrap.sdx(att.x if is_nan(ox) else ox, tgt.x)), att.face)   # ox: away from that point (a mine's blast), not from the attacker") +
   L(1, "var g: float = WorldTerrain.groundY(S, tgt.x)") +
   L(1, "var dist: float = float(kb.distBh[ti]) * BH * mul")],
]);

// ---------------------------------------------------------------- a blow on a mine sets it off
edit("sim/director/melee.gd", [
  [L(1, "SimDamage.hit(S, ex, a, d, dmg, o)") +
   L(1, "if dmg > 0.0 and not o.get(\"ignoreStance\", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:"),
   L(1, "SimDamage.hit(S, ex, a, d, dmg, o)") +
   L(1, "if dmg > 0.0 and DirBlast.minesOn() and not S.shots.is_empty():") +
   L(2, "SimShots.tripNear(S, d.x, d.y + SimShots.chest, float(DirBlast.data().mine.blowR), \"blow\", S.fighters.find(a))   # a blow on a mine sets it off in the striker's face") +
   L(1, "if dmg > 0.0 and not o.get(\"ignoreStance\", false) and (ex.sD if d == ex.D else ex.sA) == 1.0:")],
]);

// ---------------------------------------------------------------- the blasts: the spray, the wild deflect's reward, the context deflect, mines
edit("sim/director/blast.gd", [
  // the AI spaces the bolts of its volley, so they stay measured and keep seeking
  [L(4, "DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, int(c.light.windupTicks))"),
   L(4, "DirInterrupt.si(f, DirInterrupt.BLAST_LEFT, int(c.light.get(\"aiGapTicks\", c.light.windupTicks)) if f.ai != null else int(c.light.windupTicks))   # the AI spaces its volley: measured bolts")],
  // the spray cone
  [L(1, "else:") +
   L(2, "var g: int = DirInterrupt.gi(f, DirInterrupt.BLAST_GROUP)") +
   L(2, "if g == 0 or S.tick - DirInterrupt.gi(f, DirInterrupt.BLAST_LAST) > int(w.groupTicks):") +
   L(3, "g = S.shotSeq + 1   # a new volley: its group is its first shot's id") +
   L(2, "DirInterrupt.si(f, DirInterrupt.BLAST_GROUP, g)") +
   L(2, "DirInterrupt.si(f, DirInterrupt.BLAST_LAST, S.tick)") +
   L(2, "o2[\"group\"] = g"),
   L(1, "else:") +
   L(2, "var g: int = DirInterrupt.gi(f, DirInterrupt.BLAST_GROUP)") +
   L(2, "var gap: int = S.tick - DirInterrupt.gi(f, DirInterrupt.BLAST_LAST)") +
   L(2, "if g == 0 or gap > int(w.groupTicks):") +
   L(3, "g = S.shotSeq + 1   # a new volley: its group is its first shot's id") +
   L(2, "DirInterrupt.si(f, DirInterrupt.BLAST_GROUP, g)") +
   L(2, "DirInterrupt.si(f, DirInterrupt.BLAST_LAST, S.tick)") +
   L(2, "o2[\"group\"] = g") +
   L(2, "_spray(S, f, o2, gap)")],
  [L(1, "SimEvents.feed(S, f.name + (\" CHARGED SHOT\" if weight == SimAct.HEAVY else \" BOLT\"), (\"charge \" + str(int(charge * 100.0)) + \"%, \" if weight == SimAct.HEAVY else \"\") + \"arrives in \" + str(sh.left) + \" ticks\")"),
   L(1, "SimEvents.feed(S, f.name + (\" CHARGED SHOT\" if weight == SimAct.HEAVY else \" BOLT\"), (\"charge \" + str(int(charge * 100.0)) + \"%, \" if weight == SimAct.HEAVY else \"\") + (\"arrives in \" + str(sh.left) + \" ticks\" if sh.mode == SimShots.SEEK else \"sprayed wide of him (spread \" + str(DirInterrupt.gi(f, DirInterrupt.SPRAY) / 10) + \"%)\"))") + "\n\n" +
   "## The spray cone (agency-pass.md section 15.4; interrupts.json blast.spray). A bolt fired measuredTicks or more after\n" +
   "## the last seeks, as before, and his spread recovers at recoverPerSec. Each bolt fired sooner adds perBolt to his\n" +
   "## spread, up to max. A bolt then still seeks with a chance of 1 - missShare x spread; otherwise it flies straight\n" +
   "## inside the cone at the rival (slopeMin at no spread to slopeMax at full) and explodes where it lands. The draw is\n" +
   "## keyed on the match seed and the shot's id: no stream shifts and a replay matches.\n" +
   "static func _spray(S: SimState, f, o2: Dictionary, gap: int) -> void:\n" +
   L(1, "var sp: Dictionary = data().get(\"spray\", {})") +
   L(1, "if sp.is_empty():") +
   L(2, "return") +
   L(1, "var s: float = float(DirInterrupt.gi(f, DirInterrupt.SPRAY)) / 1000.0") +
   L(1, "if gap < int(sp.measuredTicks):") +
   L(2, "s = minf(float(sp.max), s + float(sp.perBolt))") +
   L(1, "else:") +
   L(2, "s = maxf(0.0, s - float(sp.recoverPerSec) * float(gap) / DirData.TICKS_PER_SEC)") +
   L(1, "DirInterrupt.si(f, DirInterrupt.SPRAY, int(round(s * 1000.0)))") +
   L(1, "if s > 0.0 and SimRng.keyed(int(S.game.seed), \"blast.spray\", S.shotSeq + 1) < float(sp.missShare) * s:") +
   L(2, "o2[\"aim\"] = o2.target") +
   L(2, "o2.erase(\"target\")") +
   L(2, "o2[\"spread\"] = float(sp.slopeMin) + (float(sp.slopeMax) - float(sp.slopeMin)) * s") + "\n\n" +
   "## True when mines can be laid (interrupts.json blast.mine).\n" +
   "static func minesOn() -> bool:\n" +
   L(1, "return on() and data().get(\"mine\", {}).get(\"enabled\", false)") + "\n\n" +
   "## f's context press outside an exchange of his (DirInterrupt.tick): on a held guard it is the context deflect, and\n" +
   "## with the energy family held it lays a mine.\n" +
   "static func context(S: SimState, f) -> void:\n" +
   L(1, "if not on() or S.game.ko != null:") +
   L(2, "return") +
   L(1, "var ex = S.dirS.ex") +
   L(1, "if ex != null and (ex.A == f or ex.D == f):") +
   L(2, "return") +
   L(1, "if f.input.guard:") +
   L(2, "_contextDeflect(S, f)") +
   L(1, "elif f.act.mode == 1:") +
   L(2, "layMine(S, f)") + "\n\n" +
   "## The context deflect (section 15.2): with guard held, the context press sets a deflect on the shot coming at him,\n" +
   "## for deflect.context.ki and with no timing. It sends the shot off as a perfect block does, with none of its rewards.\n" +
   "static func _contextDeflect(S: SimState, f) -> void:\n" +
   L(1, "var cd: Dictionary = data().get(\"deflect\", {}).get(\"context\", {})") +
   L(1, "if cd.is_empty() or f.state == \"launched\" or f.state == \"down\" or f.ki < float(cd.ki):") +
   L(2, "return") +
   L(1, "var slot: int = S.fighters.find(f)") +
   L(1, "var best = null") +
   L(1, "for sh in S.shots:") +
   L(2, "if sh.dead or sh.owner == slot or sh.mode != SimShots.SEEK or sh.tgt != slot:") +
   L(3, "continue") +
   L(2, "if best == null or sh.left < best.left:") +
   L(3, "best = sh") +
   L(1, "if best == null:") +
   L(2, "return") +
   L(1, "var key: int = best.group if best.group != 0 else -best.id") +
   L(1, "if DirInterrupt.gi(f, DirInterrupt.CTX_SHOT) == key and DirInterrupt.gi(f, DirInterrupt.CTX_DEFL) == best.deflected:") +
   L(2, "return   # already set for this shot") +
   L(1, "f.ki -= float(cd.ki)") +
   L(1, "DirInterrupt.si(f, DirInterrupt.CTX_SHOT, key)") +
   L(1, "DirInterrupt.si(f, DirInterrupt.CTX_DEFL, best.deflected)") +
   L(1, "SimFx.cue(S, f, \"context_deflect_set\", \"\", \"\")") + "\n\n" +
   "## The mine (section 15.5; interrupts.json blast.mine): laid where he is, hovering, or resting on the ground when he\n" +
   "## stands on it. It costs mine.ki. The core holds the cap, the gap between mines, the arming, the trigger, the blast\n" +
   "## and the chain (data/fight/shots.json, the kind's mine block). Inside shoveWithinBh of the rival the press is the\n" +
   "## energy shove's, which is not built: nothing happens.\n" +
   "static func layMine(S: SimState, f) -> void:\n" +
   L(1, "if not minesOn() or (f.state != \"free\" and f.state != \"charging\") or DirBands.pending(f):") +
   L(2, "return") +
   L(1, "var m: Dictionary = data().mine") +
   L(1, "if DirBands.dist(f, SimRoster.opp(S, f)) <= float(m.shoveWithinBh) * DirInterrupt.BH:") +
   L(2, "return") +
   L(1, "if f.ki < float(m.ki):") +
   L(2, "if f.ai == null:") +
   L(3, "SimFx.banner(S, \"NEED \" + SimMathx.jstr(float(m.ki)) + \" KI\", \"#9fb4ff\", 0.6)") +
   L(2, "return") +
   L(1, "var grounded: bool = f.y - WorldTerrain.groundY(S, f.x) <= float(m.groundWithinBh) * DirInterrupt.BH") +
   L(1, "var sh = SimShots.fire(S, S.fighters.find(f), String(m.kind), {\"ground\": grounded})") +
   L(1, "if sh == null:") +
   L(2, "SimFx.cue(S, f, \"mine_refused\", \"\", \"\")   # the cap on live shots, or too near another mine: the press is spent") +
   L(2, "return") +
   L(1, "f.ki -= float(m.ki)") +
   L(1, "DirInterrupt.si(f, DirInterrupt.BLAST_AT, S.tick)") +
   L(1, "SimFx.cue(S, f, \"mine_lay\", \"\", \"\")") +
   L(1, "SimEvents.feed(S, f.name + \" LAYS A MINE\", \"on the ground\" if grounded else \"hovering\")") + "\n\n" +
   "## A mine's blast has reached f, who is not its owner (the core gives the owner his own share). It cannot be dodged\n" +
   "## or deflected; a held guard takes it at the guard's rate. Unguarded, on a fighter who is up and outside an exchange,\n" +
   "## it knocks him back from the mine, and that is decisive.\n" +
   "static func _mineHit(S: SimState, sh, by, f) -> bool:\n" +
   L(1, "var c: Dictionary = data()") +
   L(1, "if DirBury.safe(S, f):") +
   L(2, "SimFx.shotHit(S, sh, f, \"safe\")") +
   L(2, "return true") +
   L(1, "var guarded: bool = f.stance == 1.0 and f.state != \"down\" and f.state != \"launched\"") +
   L(1, "var brink0: bool = f.brink") +
   L(1, "SimDamage.hit(S, null, by, f, sh.dmg, {\"kind\": \"blast\", \"ignoreStance\": not guarded, \"stop\": float(c.stopTicks) / DirData.TICKS_PER_SEC, \"shake\": 7.0})") +
   L(1, "SimFx.shotHit(S, sh, f, \"guard\" if guarded else \"hit\")") +
   L(1, "if guarded or S.game.ko != null or S.dirS.ex != null or (f.state != \"free\" and f.state != \"charging\"):") +
   L(2, "return true") +
   L(1, "if DirBands.pending(f):") +
   L(2, "DirBands.drop(S, f, \"a mine knocked him back\")") +
   L(1, "DirLaunch.knock(S, by, f, 1.0, sh.x)") +
   L(1, "SimEvents.feed(S, \"MINE: KNOCK BACK\", by.name + \"'s mine caught \" + f.name + \": decisive\")") +
   L(1, "DirExchange.decisiveShot(S, by, f, -sh.id, brink0, \"blast\")") +
   L(1, "return true")],
  // a mine's blast takes its own rule
  [L(1, "var slot: int = S.fighters.find(f)") +
   L(1, "# Just out of his crater he is safe: the shot passes. Buried and helpless, he answers nothing: it is the follow-up."),
   L(1, "var slot: int = S.fighters.find(f)") +
   L(1, "if sh.mode == SimShots.MINE:") +
   L(2, "return _mineHit(S, sh, by, f)") +
   L(1, "# Just out of his crater he is safe: the shot passes. Buried and helpless, he answers nothing: it is the follow-up.")],
  // the perfect block's deflect: the free approach, and what the feed says
  [L(2, "SimEvents.feed(S, f.name + \" DEFLECTS\", \"a perfect block: the \" + sh.kind + \" goes back to \" + by.name)") +
   L(2, "return false"),
   L(2, "var fa: int = int(c.get(\"deflect\", {}).get(\"freeApproachTicks\", 0))") +
   L(2, "if fa > 0:") +
   L(3, "DirInterrupt.si(f, DirInterrupt.FREE_UNTIL, S.tick + fa)   # section 15.2: his next charge or lunge in that time is stopped by no shot") +
   L(2, "SimEvents.feed(S, f.name + \" DEFLECTS\", \"a perfect block: the \" + sh.kind + (\" flies wild\" if SimShots.scatter else \" goes back to \" + by.name) + (\"; a free approach for \" + str(fa) + \" ticks\" if fa > 0 else \"\"))") +
   L(2, "return false") +
   L(1, "# The context deflect: set by the context press on a held guard. The shot is sent off; no ki back, no free approach.") +
   L(1, "if DirInterrupt.gi(f, DirInterrupt.CTX_SHOT) == key and DirInterrupt.gi(f, DirInterrupt.CTX_DEFL) == sh.deflected and f.stunTicks <= 0 and f.state != \"launched\" and f.state != \"down\":") +
   L(2, "SimFx.shotHit(S, sh, f, \"deflect\")") +
   L(2, "SimShots.deflect(S, sh, slot)") +
   L(2, "SimFx.cue(S, f, \"context_deflect\", \"\", \"\")") +
   L(2, "SimEvents.feed(S, f.name + \" DEFLECTS\", \"the context deflect: the \" + sh.kind + (\" flies wild\" if SimShots.scatter else \" goes back to \" + by.name))") +
   L(2, "return false")],
  // the free approach: no shot stops it
  [L(1, "if DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.CHARGE) != 0:"),
   L(1, "if DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.FREE) != 0:") +
   L(2, "dmg *= float(c.charge.shrugMul)   # the free approach a deflect earned: any shot is shrugged off, and he keeps coming") +
   L(2, "outcome = \"shrug\"") +
   L(1, "elif DirBands.pending(f) and (DirInterrupt.gi(f, DirInterrupt.APPR_REQ) & DirBands.CHARGE) != 0:")],
]);

// ---------------------------------------------------------------- a finisher's volley (Combat's rival: three barrage beats)
edit("sim/director/exchange.gd", [
  [L(1, "var bark = a.get(\"bark\", \"\")") +
   L(1, "SimFx.cue(S, f, String(a.cue), String(a.get(\"cam\", \"\")), \"\" if bark == null else str(bark))"),
   L(1, "var bark = a.get(\"bark\", \"\")") +
   L(1, "SimFx.cue(S, f, String(a.cue), String(a.get(\"cam\", \"\")), \"\" if bark == null else str(bark))") +
   L(1, "# A volley on the cue (Combat's finisher rows: {dmg, shape, count}): the named fighter's volley lands on the other") +
   L(1, "# for dmg, whatever he holds. The shots are drawn from the cue volley_fire; count is the renderer's (by Pride).") +
   L(1, "if f != null and a.get(\"volley\") is Dictionary and S.game.ko == null and not ex.cancel:") +
   L(2, "var tgt = ex.D if f == ex.A else ex.A") +
   L(2, "SimFx.cue(S, f, \"volley_fire\", \"\", \"\")") +
   L(2, "SimDamage.hit(S, ex, f, tgt, float(a.volley.get(\"dmg\", 0.0)), {\"kind\": \"blast\", \"ignoreStance\": true, \"noParry\": true, \"stop\": 0.04, \"shake\": 5.0})")],
]);

// ---------------------------------------------------------------- the AI lays a mine now and then
edit("sim/director/ai.gd", [
  [L(4, "i.mode = 1   # it fires instead: a volley of bolts for a light, a charged shot for a heavy (DirBlast)"),
   L(4, "i.mode = 1   # it fires instead: a volley of bolts for a light, a charged shot for a heavy (DirBlast)") +
   L(3, "if (i.light or i.heavy) and DirBlast.minesOn() and DirBands.band(f, o) == DirBands.FAR and f.ki >= float(skill().get(\"mineMinKi\", 40.0)) and S.rng.next() < float(lv().get(\"mineShare\", 0.0)):") +
   L(4, "i.light = false") +
   L(4, "i.heavy = false") +
   L(4, "i.mode = 1") +
   L(4, "i.context = true   # a mine where it stands, in place of this beat's attack (DirBlast.layMine)")],
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
  j.blast.light.aiGapTicks = 10;
  j.blast.deflect = {
    freeApproachTicks: 45,
    context: { ki: 10 },
    _note: "Deflects (agency-pass.md section 15.2). Where a deflected shot goes is the core's (data/fight/shots.json deflect: wild with scatter on, back at the shooter with it off). freeApproachTicks: a perfect block of a shot gives him this long to start a charge or a lunge that no shot stops (a shot that meets him on it is shrugged off at charge.shrugMul); 0 switches it off. context.ki: with guard held, the context press sets a deflect on the shot coming at him for this much ki, with no timing; it sends the shot off with none of the perfect block's rewards",
  };
  j.blast.spray = {
    measuredTicks: 10,
    perBolt: 0.15,
    max: 1.0,
    missShare: 0.6,
    slopeMin: 0.105,
    slopeMax: 0.325,
    recoverPerSec: 0.5,
    _note: "The spray cone (agency-pass.md section 15.4). A bolt fired measuredTicks or more after his last seeks, and his spread recovers by recoverPerSec a second. Each bolt fired sooner adds perBolt to his spread, up to max. A bolt then still seeks with a chance of 1 - missShare x spread; otherwise it flies straight inside the cone at the rival, a half-angle whose slope runs from slopeMin (6 degrees) at no spread to slopeMax (18 degrees) at full, and explodes where it lands. light.aiGapTicks: the AI spaces the bolts of its volley this many ticks apart, so its bolts are measured and keep seeking",
  };
  j.blast.mine = {
    enabled: true,
    kind: "mine",
    ki: 8,
    shoveWithinBh: 3,
    groundWithinBh: 0.5,
    blowR: 60,
    _note: "Mines (agency-pass.md sections 15.5 and 17). With the energy family held, the context press lays a mine of 'kind' (data/fight/shots.json) where he is for 'ki': on the ground when his feet are within groundWithinBh of it, else hovering. Within shoveWithinBh of the rival the press is the energy shove's (not built: nothing). blowR: a landed blow whose target's chest is within this of a mine sets it off. The cap, the gap, the arming, the trigger, the blast, the chain and the fuse are the kind's own. A mine's blast on the rival cannot be dodged or deflected; unguarded it knocks him back from the mine and is decisive",
  };
});
const lvl = (guard, share) => [
  `      "barrageGuard": ${guard},
`,
  `      "barrageGuard": ${guard},
      "mineShare": ${share},
`];
edit("data/director/ai.json", [
  lvl("0.2", "0.02"),
  [`      "barrageGuard": 0.7,
`,
   `      "barrageGuard": 0.42,
      "mineShare": 0.04,
`],
  lvl("0.8", "0.06"),
  [`      "guardRepeat": 5.5,
`, `      "guardRepeat": 5.0,
`],
  [`      "blastShare": 0.18,
`, `      "blastShare": 0.2,
`],
  [`      "blastShare": 0.35,
`, `      "blastShare": 0.4,
`],
  [`      "blastShare": 0.45,
`, `      "blastShare": 0.5,
`],
  ["barrageGuard 0.5 gave 54 of 100, 0.6 gave 37, 0.7 gave 31. Both move with every slice: re-measure after each.",
   "barrageGuard 0.5 gave 54 of 100, 0.6 gave 37, 0.7 gave 31; with the spray cone (slice 9: a spammer lands fewer bolts) 0.7 gave 10, 0.5 gave 20, 0.45 gave 23, 0.4 gave 39, 0.3 gave 50, and 0.42 is in; guardRepeat went to 5.0 with it (the masher read 36 of 100 at 5.5 once the AI fired more). Both move with every slice: re-measure after each."],
  [`  "reactTicks": 14,
`,
   `  "mineMinKi": 40,
  "_mine": "Per level, mineShare: the chance its attack beat in the far band lays a mine instead (it needs mineMinKi of ki). It does not avoid mines",
  "reactTicks": 14,
`],
]);

// ---------------------------------------------------------------- not mine, by the EP's grant
edit("data/fight/shots.json", [   // Simulation's switch
  [`    "scatter": false,
`,
   `    "scatter": true,
`],
]);
console.log("done");
