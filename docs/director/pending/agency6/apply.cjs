// Agency slice 6: the buried fighter (agency-pass.md section 7) and the hook for the slide's bump
// (docs/world/ground-contact.md section 24). node apply.cjs <repo root>. Idempotent.
// bury.gd beside this script becomes sim/director/bury.gd.
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

// ---------------------------------------------------------------- the state; the burst out of the crater
edit("sim/director/interrupt.gd", [
  ["const N: int = 35\n",
   "const BURY_WAS: int = 35   # 1 while he lay buried last tick (DirBury)\n" +
   "const BURY_USED: int = 36  # 1 once the follow-up of this burial has been used\n" +
   "const SAFE_UNTIL: int = 37 # S.tick until which he is safe, just out of his crater\n" +
   "const BURY_AI: int = 38    # the AI rival's choice for this burial's follow-up (DirBury.AI_*)\n" +
   "const BUMP_AT: int = 39    # S.tick his upright slide ends early against an obstacle (DirLaunch); 0 when none\n" +
   "const BUMP_REQ: int = 40   # ... the obstacle's kind (1 wall, 2 heap, 3 rim) | the slide's speed in whole units a second << 4\n" +
   "const BURY_E: int = 41     # the energy of the impact that buried him, in thousandths (from the embed event)\n" +
   "const N: int = 42\n"],
  [L(1, 'if f.ki < float(c.ki) or f.act.burstCool > 0 or f.state == "launched" or f.state == "down":'),
   L(1, 'if f.ki < float(c.ki) or f.act.burstCool > 0 or f.state == "launched" or (f.state == "down" and not DirBury.canBurst(f)):   # buried, he bursts out once the follow-up\'s time is over')],
  [L(1, "f.ki -= float(c.ki)") + L(1, "f.act.burstCool = int(c.cooldownTicks)"),
   L(1, "f.ki -= float(c.ki)") + L(1, "f.act.burstCool = int(c.cooldownTicks)") + L(1, "DirBury.burstOut(S, f)   # a buried fighter's burst throws him out of his crater")],
]);

// ---------------------------------------------------------------- the follow-up starts at once; the buried defender's stance; the safety
edit("sim/director/exchange.gd", [
  [L(1, "var opn: int = planOpen if engaging else (DirInterrupt.opening(S, A) if kind != \"sig\" else 0)   # an approach carries its opening to the engage") +
   L(1, "if S.dirS.cool > 0.0 and opn == 0:") + L(2, "return WAIT") +
   L(1, "if A.stunTicks > 0 and DirInterrupt.on():") + L(2, "return WAIT   # step 3: a staggered fighter's requests wait") +
   L(1, "var D = SimRoster.opp(S, A)"),
   L(1, "var opn: int = planOpen if engaging else (DirInterrupt.opening(S, A) if kind != \"sig\" else 0)   # an approach carries its opening to the engage") +
   L(1, "var D = SimRoster.opp(S, A)") +
   L(1, "# The buried fighter (DirBury): his rival's first press in time is the free follow-up, through the cooldown and from") +
   L(1, "# where he stands; and a fighter just out of his crater is safe for a moment.") +
   L(1, "var fu: bool = kind != \"sig\" and not engaging and DirBury.followUp(S, A, D)") +
   L(1, "if DirBury.safe(S, D):") + L(2, "return WAIT") +
   L(1, "if S.dirS.cool > 0.0 and opn == 0 and not fu:") + L(2, "return WAIT") +
   L(1, "if A.stunTicks > 0 and DirInterrupt.on():") + L(2, "return WAIT   # step 3: a staggered fighter's requests wait")],
  [L(1, "if kind != \"sig\" and not engaging and DirBands.on():") + L(2, "var pt: int = planTick if planTick >= 0 else S.tick"),
   L(1, "if kind != \"sig\" and not engaging and DirBands.on() and not fu:") + L(2, "var pt: int = planTick if planTick >= 0 else S.tick")],
  [L(1, "A.hideT = 0.0") + L(1, "A.state = \"free\"") + L(1, "if kind == \"heavy\":") + L(2, "A.ki -= 4.0"),
   L(1, "A.hideT = 0.0") + L(1, "A.state = \"free\"") + L(1, "if fu:") + L(2, "kind = \"heavy\"   # the follow-up is a heavy blow whatever was pressed, and it is free") + L(1, "elif kind == \"heavy\":") + L(2, "A.ki -= 4.0")],
  [L(1, "ex.sD = D.stance"),
   L(1, "ex.sD = D.stance") +
   L(1, "planDefStance = -1 if fu else DirBury.stance(D)   # a buried defender guards only from the ruled tick, and never dodges or presses") +
   L(1, "if planDefStance >= 0:") + L(2, "ex.sD = float(planDefStance)")],
  [L(1, "if kind != \"sig\" and DirData.hasNeutral() and opn == 0:"),
   L(1, "if kind != \"sig\" and DirData.hasNeutral() and opn == 0 and not fu and planDefStance < 0:")],
  [L(1, "else:") + L(2, "var fav: String = DirMelee.planMelee(S, ex)") + L(2, "ex.loser = S.fighters.find(D) if fav == \"attacker\" else (S.fighters.find(A) if fav == \"defender\" else -1)"),
   L(1, "elif fu:") + L(2, "DirBury.plan(S, ex)   # the director's interim piece: one heavy blow he cannot answer, no launch") + L(2, "DirData.defLabel = \"BURIED\"") + L(2, "ex.loser = S.fighters.find(D)") +
   L(1, "else:") + L(2, "var fav: String = DirMelee.planMelee(S, ex)") + L(2, "ex.loser = S.fighters.find(D) if fav == \"attacker\" else (S.fighters.find(A) if fav == \"defender\" else -1)") + L(1, "planDefStance = -1")],
  ["static var planMeet: bool = false",
   "static var planDefStance: int = -1   # ... and the stance a buried defender is read in (DirBury.stance), -1 otherwise\nstatic var planMeet: bool = false"],
  [L(2, "\"nop\":"),
   L(2, "\"buryDeepen\":") + L(3, "DirBury.opDeepen(S, ex)") + L(2, "\"nop\":")],
  [L(1, "DirInterrupt.onEnd(S, ex)   # step 3: a fully blocked string leaves its attacker behind"),
   L(1, "DirInterrupt.onEnd(S, ex)   # step 3: a fully blocked string leaves its attacker behind") + L(1, "DirBury.onEnd(S, ex)   # a defender taken in his crater is out of it, with his safety")],
  [L(1, "DirBlast.tick(S)   # blasts winding up leave; the AI weighs a perfect block against a shot about to arrive"),
   L(1, "DirBlast.tick(S)   # blasts winding up leave; the AI weighs a perfect block against a shot about to arrive") + L(1, "DirBury.tick(S)   # a burial starts and ends") + L(1, "DirLaunch.tick(S)   # an upright slide that ends early against an obstacle: the bump")],
  // the follow-up is never a far press, and it starts through the cooldown
  [L(1, "if kind != \"sig\" and DirBands.farPressNow(S, A, KIND.find(kind), entry):"),
   L(1, "if kind != \"sig\" and not DirBury.followUp(S, A, SimRoster.opp(S, A)) and DirBands.farPressNow(S, A, KIND.find(kind), entry):")],
  [L(1, "if S.dirS.cool > 0.0 and DirInterrupt.opening(S, S.fighters[0]) == 0 and DirInterrupt.opening(S, S.fighters[1]) == 0:"),
   L(1, "if S.dirS.cool > 0.0 and DirInterrupt.opening(S, S.fighters[0]) == 0 and DirInterrupt.opening(S, S.fighters[1]) == 0 and not DirBury.followUp(S, S.fighters[0], S.fighters[1]) and not DirBury.followUp(S, S.fighters[1], S.fighters[0]):")],
]);

edit("sim/director/data.gd", [
  [L(1, "var defState: String = \"CHARGING\" if (D.dPrev != null and D.dPrev == \"charging\") else DirExchange.STN[int(D.stance)]") +
   L(1, "var ctx := {\"S\": S, \"A\": A, \"D\": D, \"heavy\": heavy, \"dist\": dist, \"base\": 66.0 if heavy else 26.0}") +
   L(1, "_flags(S, ctx, A, D)"),
   L(1, "var defState: String = \"CHARGING\" if (D.dPrev != null and D.dPrev == \"charging\") else DirExchange.STN[int(D.stance)]") +
   L(1, "var ctx := {\"S\": S, \"A\": A, \"D\": D, \"heavy\": heavy, \"dist\": dist, \"base\": 66.0 if heavy else 26.0}") +
   L(1, "_flags(S, ctx, A, D)") +
   L(1, "if DirExchange.planDefStance >= 0:") +
   L(2, "defState = DirExchange.STN[DirExchange.planDefStance]   # a buried defender: his guard, or nothing; he neither presses nor moves") +
   L(2, "ctx.defQueued = false") + L(2, "ctx.defClipped = false")],
]);

// ---------------------------------------------------------------- a blast into the crater; the safety against shots
edit("sim/director/blast.gd", [
  [L(1, "# The dodge: inside his dodge window he lets it pass, and it flies on."),
   L(1, "# Just out of his crater he is safe: the shot passes. Buried and helpless, he answers nothing: it is the follow-up.") +
   L(1, "if DirBury.safe(S, f):") + L(2, "SimFx.shotHit(S, sh, f, \"safe\")") + L(2, "return false") +
   L(1, "if DirBury.helpless(f):") + L(2, "DirBury.blasted(f)") +
   L(2, "SimDamage.hit(S, null, by, f, sh.dmg, {\"kind\": \"blast\", \"ignoreStance\": true, \"stop\": float(c.stopTicks) / DirData.TICKS_PER_SEC, \"shake\": 7.0})") +
   L(2, "SimFx.shotHit(S, sh, f, \"buried\")") + L(2, "return true") +
   L(1, "# The dodge: inside his dodge window he lets it pass, and it flies on.")],
]);

// ---------------------------------------------------------------- the AI takes its free blow
edit("sim/director/ai.gd", [
  [L(1, "var ans: int = DirBands.aiAnswer(f, o) if f.state == \"free\" else DirBands.R_NONE"),
   L(1, "if f.state == \"free\" and DirBury.aiFollow(S, f, o):") + L(2, "i.heavy = true   # the free blow on a buried rival, at its level's rate") +
   L(1, "var ans: int = DirBands.aiAnswer(f, o) if f.state == \"free\" else DirBands.R_NONE")],
]);

// ---------------------------------------------------------------- the slide's bump: the hook for World's two functions and its flag
edit("sim/director/launch.gd", [
  [L(1, "tgt.wet = tgt.y < 0.0 and WorldTerrain.seaAt(S, tgt.x)"),
   L(1, "tgt.wet = tgt.y < 0.0 and WorldTerrain.seaAt(S, tgt.x)") +
   L(1, "if \"slideFeet\" in tgt:") + L(2, "tgt.slideFeet = String(plan.get(\"slide\", \"\")) == \"feet\"   # World's flag for a slide on the feet (ground-contact.md section 24), once the field exists")],
  [L(1, "r.py = g2 if slide else SimMathx.jmax(tgt.y, g2)") + L(1, "var ticks: float = float(kb.slideTicks if slide else kb.driftTicks)") +
   L(1, "r.end = S.T + ticks * SimConst.DT") + L(1, "tgt.rush = r") +
   L(1, "SimFx.knockback(S, tgt, att, \"slideShort\" if slide else \"drift\", dist, S.tick + int(ticks))"),
   L(1, "r.py = g2 if slide else SimMathx.jmax(tgt.y, g2)") + L(1, "var ticks: float = float(kb.slideTicks if slide else kb.driftTicks)") +
   L(1, "# The bump (World, ground-contact.md section 24): an obstacle inside an upright slide's length ends it early, a body") +
   L(1, "# short of it. World's slideObstacle finds it and its bump pays the light brunt when the slide ends; until World has") +
   L(1, "# both, the hook does nothing.") +
   L(1, "var bumpKind: int = 0") +
   L(1, "var so := Callable(WorldContact, \"slideObstacle\")") +
   L(1, "if slide and so.is_valid() and Callable(WorldContact, \"bump\").is_valid():") +
   L(2, "var ob = so.call(S, tgt.x, tgt.z, s, dist)") +
   L(2, "if ob is Dictionary and ob.get(\"hit\", false):") +
   L(3, "var d2: float = maxf(0.0, float(ob.d) - BUMP_SHORT)") +
   L(3, "ticks = maxf(1.0, round(ticks * d2 / maxf(dist, 1.0)))   # the same speed, a shorter way") +
   L(3, "dist = d2") +
   L(3, "r.px = SimWrap.wrap(tgt.x + s * dist)") +
   L(3, "r.py = WorldTerrain.groundY(S, r.px)") +
   L(3, "bumpKind = maxi(1, BUMP_KINDS.find(String(ob.get(\"kind\", \"wall\"))))") +
   L(3, "DirInterrupt.si(tgt, DirInterrupt.BUMP_AT, S.tick + int(ticks))") +
   L(3, "DirInterrupt.si(tgt, DirInterrupt.BUMP_REQ, bumpKind | (int(dist / (ticks * SimConst.DT)) << 4))") +
   L(1, "r.end = S.T + ticks * SimConst.DT") + L(1, "tgt.rush = r") +
   L(1, "SimFx.knockback(S, tgt, att, \"bump\" if bumpKind > 0 else (\"slideShort\" if slide else \"drift\"), dist, S.tick + int(ticks))")],
  ["## No launch in the old profiles: the strike shoves the (locked) target back along the attacker's facing.\n",
   "const BUMP_SHORT: float = 30.0   # the slide stops this far short of the obstacle (a body's radius; World's figure)\n" +
   "const BUMP_KINDS: Array = [\"\", \"wall\", \"heap\", \"rim\"]   # World's obstacle kinds, as BUMP_REQ packs them\n\n\n" +
   "## Once a live tick: an upright slide that was cut short by an obstacle ends now, and World's bump pays its light brunt.\n" +
   "static func tick(S: SimState) -> void:\n" +
   L(1, "for f in S.fighters:") +
   L(2, "var at: int = DirInterrupt.gi(f, DirInterrupt.BUMP_AT)") +
   L(2, "if at <= 0 or S.tick < at:") + L(3, "continue") +
   L(2, "DirInterrupt.si(f, DirInterrupt.BUMP_AT, 0)") +
   L(2, "var req: int = DirInterrupt.gi(f, DirInterrupt.BUMP_REQ)") +
   L(2, "var bump := Callable(WorldContact, \"bump\")") +
   L(2, "if bump.is_valid() and S.game.ko == null and f.state != \"launched\":") +
   L(3, "bump.call(S, f, SimRoster.opp(S, f), String(BUMP_KINDS[req & 15]), float(req >> 4))") +
   "\n\n## No launch in the old profiles: the strike shoves the (locked) target back along the attacker's facing.\n"],
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
  j.buried = {
    enabled: true,
    followTicks: 40,
    guardFromTick: 40,
    burstFromTick: 40,
    safeTicks: 10,
    reachBh: 2000,
    damage: 66,
    deepen: 1.2,
    _note: "The buried fighter (agency-pass.md section 7; sim/director/bury.gd; World's embed holds him down for its own ticks, data/biomes/contact.json embed.ticks). followTicks: his rival's first attack press this soon after the burial, from within reachBh, is the free follow-up: one heavy blow of 'damage' he cannot answer, no launch; it digs a bowl 'deepen' times as deep as the one that buried him (World's dig leaves ground alone that is already dented deeper than the bowl asked for). A blast that reaches him in that time is the follow-up too. guardFromTick: his guard counts only from here, or once the follow-up is used; buried, he never dodges or presses. burstFromTick: his burst throws him out, not before this. safeTicks: out of the crater, no exchange starts on him and no shot lands for this long",
  };
});
const lvl = (share, follow) => [
  `      "blastShare": ${share},
`,
  `      "blastShare": ${share},
      "buriedFollowUp": ${follow},
`];
edit("data/director/ai.json", [
  lvl("0.1", "0.4"), lvl("0.2", "0.8"), lvl("0.25", "1.0"),
  [`  "reactTicks": 14,
`,
   `  "_buriedFollowUp": "Per level, buriedFollowUp: the chance it takes the free blow on a rival it has buried (one draw a burial; it presses after reactTicks)",
  "reactTicks": 14,
`],
]);
console.log("done");
