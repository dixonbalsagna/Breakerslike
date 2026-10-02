// Agency slice 5, second part: Game Design's provisional signature limit (agency-pass.md section 5) as data behind a
// switch. node apply-sig.cjs <repo root>. Idempotent.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw new Error("usage: node apply-sig.cjs <repo root>");
const T = "\t";
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
edit("sim/director/beam.gd", [
  [T + T + T + "D.sigReadyT = S.T + D.sigCooldown\n",
   T + T + T + "D.sigReadyT = S.T + sigCooldown(D)\n"],
  [T + "SimDamage.hit(S, ex, A, D, 200.0 if out == \"GUARD\" else 230.0, {",
   T + "SimDamage.hit(S, ex, A, D, (200.0 if out == \"GUARD\" else 230.0) * sigDamageMul(), {"],
  [T + "SimDamage.hit(S, ex, Wn, Ls, 260.0, {",
   T + "SimDamage.hit(S, ex, Wn, Ls, 260.0 * sigDamageMul(), {"],
  ["static func inClash(S: SimState, f) -> bool:\n",
   "## Game Design's provisional signature limit (agency-pass.md section 5; interrupts.json `signature`): with the switch on,\n" +
   "## a signature recharges in cooldownSec (not the fighter's own sigCooldown) and does damageMul of its damage, because\n" +
   "## there will be several times as many. Off, or in a profile without the perfect block, both are as they were.\n" +
   "static func sigCooldown(f) -> float:\n" +
   T + "var sg: Dictionary = DirInterrupt.data().get(\"signature\", {})\n" +
   T + "return float(sg.cooldownSec) if DirInterrupt.on() and sg.get(\"provisional\", false) else f.sigCooldown\n\n\n" +
   "static func sigDamageMul() -> float:\n" +
   T + "var sg: Dictionary = DirInterrupt.data().get(\"signature\", {})\n" +
   T + "return float(sg.damageMul) if DirInterrupt.on() and sg.get(\"provisional\", false) else 1.0\n\n\n" +
   "static func inClash(S: SimState, f) -> bool:\n"],
]);
edit("sim/director/exchange.gd", [
  [T + T + "A.sigReadyT = S.T + A.sigCooldown\n", T + T + "A.sigReadyT = S.T + DirBeam.sigCooldown(A)\n"],
]);
const f = path.join(root, "data/director/interrupts.json");
const txt = fs.readFileSync(f, "utf8");
const j = JSON.parse(txt);
j.signature = {
  provisional: true,
  cooldownSec: 15,
  damageMul: 0.6,
  _note: "Game Design's provisional signature limit (agency-pass.md section 5; Orb's to revisit once he has played the energy slice). provisional true: a signature recharges in cooldownSec and does damageMul of its damage; it still costs 45 ki. false: the fighter's own sigCooldown (120 s) and full damage, as before. QA's band to watch: signatures deal at most 30% of a match's damage",
};
const eol = txt.includes("\r\n") ? "\r\n" : "\n";
fs.writeFileSync(f, JSON.stringify(j, null, 2).split("\n").join(eol) + eol);
console.log("data/director/interrupts.json: written");
