// Agency slice 12: the barrage counts every clean shot (docs/design/agency-pass.md section 21). Applies on top of
// slice 11. node apply.cjs <repo root>. Idempotent.
//  - A clean hit of any kind of shot counts toward the barrage's ender (it was bolts only); the window is 120 ticks.
//  - A shot of a group that is not a pressed bolt (a split, a rain: one press, several shots) counts once for its group.
//  - A full charged shot still knocks back by itself, and counts as one hit; the barrage does not close on that shot.
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

edit("sim/director/interrupt.gd", [
  ["const BURY_E: int = 41     # unused since World's deepen call (it was the energy of the impact that buried him)",
   "const BAR_GROUP: int = 41  # the group of his last grouped shot a barrage counted (a split, a rain: once for the group); 0 when none"],
]);

edit("sim/director/bury.gd", [
  [L(3, "DirInterrupt.si(f, DirInterrupt.BURY_N, WorldContact.K_EMB_TICKS - f.embedT)") +
   L(3, "DirInterrupt.si(f, DirInterrupt.BURY_E, 0)") +
   L(3, "DirInterrupt.si(f, DirInterrupt.BURY_AI, 0)"),
   L(3, "DirInterrupt.si(f, DirInterrupt.BURY_N, WorldContact.K_EMB_TICKS - f.embedT)") +
   L(3, "DirInterrupt.si(f, DirInterrupt.BURY_AI, 0)")],
]);

edit("sim/director/blast.gd", [
  [L(1, "_knock(S, sh, by, f, outcome, brink0)") +
   L(1, "_barrage(S, sh, by, f, outcome, brink0)"),
   L(1, "var knocked: bool = _knock(S, sh, by, f, outcome, brink0)") +
   L(1, "_barrage(S, sh, by, f, outcome, brink0, knocked)")],
  ["## A barrage closes (agency-pass.md section 16), as a blur does: when enderAfter of a fighter's bolts land clean on his\n" +
   "## rival inside 'window' ticks, the last is a knock-back he did not press: decisive, never a launch. Clean: not guarded,\n" +
   "## not shrugged off, not a shot that was deflected. If each of them was fired measuredTicks or more after the one\n" +
   "## before, it goes the tier's full distance and is a full set-up; otherwise enderDist.plain of it and half a set-up.\n" +
   "## The count starts again, and the rival cannot be knocked back by another barrage for 'immune' ticks. A bolt that\n" +
   "## would close while he is in an exchange, down, flying or immune still counts, and the next clean one closes.\n" +
   "static func _barrage(S: SimState, sh, by, f, outcome: String, brink0: bool) -> void:\n" +
   L(1, "var c: Dictionary = data().get(\"barrage\", {})") +
   L(1, "if c.is_empty() or sh.kind != String(data().light.kind) or sh.deflected != 0 or (outcome != \"hit\" and outcome != \"stop\"):") +
   L(2, "return"),
   "## A barrage closes (agency-pass.md sections 16 and 21), as a blur does: when enderAfter of a fighter's shots, of any\n" +
   "## kind, land clean on his rival inside 'window' ticks, the last is a knock-back he did not press: decisive, never a\n" +
   "## launch. Clean: not guarded, not shrugged off, not a shot that was deflected. Each shot counts once; the shots of a\n" +
   "## group that is not a run of pressed bolts (a split, a rain: one press, several shots) count once for the group. If\n" +
   "## each was fired measuredTicks or more after the one before, it goes the tier's full distance and is a full set-up;\n" +
   "## otherwise enderDist.plain of it and half a set-up. The count starts again, and the rival cannot be knocked back by\n" +
   "## another barrage for 'immune' ticks. A shot that would close while he is in an exchange, down, flying or immune\n" +
   "## still counts, and the next clean one closes. knocked: this shot was a full charged one and has knocked him back\n" +
   "## by itself (_knock): it counts, and the barrage does not close on it.\n" +
   "static func _barrage(S: SimState, sh, by, f, outcome: String, brink0: bool, knocked: bool = false) -> void:\n" +
   L(1, "var c: Dictionary = data().get(\"barrage\", {})") +
   L(1, "if c.is_empty() or sh.deflected != 0 or (outcome != \"hit\" and outcome != \"stop\"):") +
   L(2, "return") +
   L(1, "# Pressed bolts share a group when fired close together (one volley to block), and each is still a shot of its own.") +
   L(1, "if sh.group != 0 and sh.kind != String(data().light.kind):") +
   L(2, "if DirInterrupt.gi(by, DirInterrupt.BAR_GROUP) == sh.group:") +
   L(3, "return") +
   L(2, "DirInterrupt.si(by, DirInterrupt.BAR_GROUP, sh.group)")],
  [L(1, "var up: bool = S.game.ko == null and S.dirS.ex == null and (f.state == \"free\" or f.state == \"charging\")"),
   L(1, "var up: bool = not knocked and S.game.ko == null and S.dirS.ex == null and (f.state == \"free\" or f.state == \"charging\")")],
  [" clean bolts inside \" + str(int(c.window)) + \" ticks: a knock-back, \"",
   " clean shots inside \" + str(int(c.window)) + \" ticks: a knock-back, \""],
  ["## A fully charged shot that lands clean knocks him back, and that is decisive (agency-pass.md section 14.6). Clean:\n" +
   "## not guarded and not shrugged off. Outside an exchange only, on a fighter who is up.\n" +
   "static func _knock(S: SimState, sh, by, f, outcome: String, brink0: bool) -> void:\n" +
   L(1, "var c: Dictionary = data()") +
   L(1, "if not c.heavy.get(\"knockFull\", false) or S.game.ko != null or S.dirS.ex != null:") +
   L(2, "return") +
   L(1, "if sh.kind != String(c.heavy.kind) or sh.dmg < float(SimShots.kinds[sh.kind].dmg) - 0.001:") +
   L(2, "return") +
   L(1, "if (outcome != \"hit\" and outcome != \"stop\") or (f.state != \"free\" and f.state != \"charging\"):") +
   L(2, "return"),
   "## A fully charged shot that lands clean knocks him back, and that is decisive (agency-pass.md section 14.6). Clean:\n" +
   "## not guarded and not shrugged off. Outside an exchange only, on a fighter who is up. True when it knocked him back.\n" +
   "static func _knock(S: SimState, sh, by, f, outcome: String, brink0: bool) -> bool:\n" +
   L(1, "var c: Dictionary = data()") +
   L(1, "if not c.heavy.get(\"knockFull\", false) or S.game.ko != null or S.dirS.ex != null:") +
   L(2, "return false") +
   L(1, "if sh.kind != String(c.heavy.kind) or sh.dmg < float(SimShots.kinds[sh.kind].dmg) - 0.001:") +
   L(2, "return false") +
   L(1, "if (outcome != \"hit\" and outcome != \"stop\") or (f.state != \"free\" and f.state != \"charging\"):") +
   L(2, "return false")],
  [L(1, "SimEvents.feed(S, \"CHARGED SHOT: KNOCK BACK\", \"a full charge landed clean on \" + f.name + \": decisive\")") +
   L(1, "DirExchange.decisiveShot(S, by, f, -sh.id, brink0)"),
   L(1, "SimEvents.feed(S, \"CHARGED SHOT: KNOCK BACK\", \"a full charge landed clean on \" + f.name + \": decisive\")") +
   L(1, "DirExchange.decisiveShot(S, by, f, -sh.id, brink0)") +
   L(1, "return true")],
]);

edit("data/director/interrupts.json", [
  [`      "enderAfter": 4,
      "window": 90,
`,
   `      "enderAfter": 4,
      "window": 120,
`],
  [`"_note": "A barrage closes (agency-pass.md section 16). When enderAfter of a fighter's bolts land clean on his rival inside 'window' ticks (not guarded, not shrugged off, not deflected), the last is a knock-back he did not press`,
   `"_note": "A barrage closes (agency-pass.md sections 16 and 21). When enderAfter of a fighter's shots, of any kind, land clean on his rival inside 'window' ticks (not guarded, not shrugged off, not deflected; each shot once, and the shots of a split or a rain once for their group), the last is a knock-back he did not press`],
]);
console.log("done");
