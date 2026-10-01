// The slam lever (balance-targets.md section 20, second landing ruling): UPPERCUT with more forward carry, so its fall
// lands under 70 degrees. CRATER SLAM stays behind its gates. Usage, from the repo root: node docs/director/pending/step3/apply-slam.cjs . [ux]
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw "usage: node apply-slam.cjs <root> [ux]";
const P = f => path.join(root, f);
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
const UX = process.argv[3] || "0.85";
edit("data/director/launch.json", [[
  `  "craterSlam": {`,
  `  "uppercut": {
    "ux": ${UX},
    "uy": 1.0,
    "_note": "UPPERCUT's direction, no unit: ux along the launcher's facing (it was 0.25), uy up. The forward carry is what makes the fall meet the ground under 70 degrees, so it skids or bounces instead of slamming (second landing ruling)"
  },
  "craterSlam": {`]]);
edit("sim/director/launch.gd", [[
  `		c.append({"name": "UPPERCUT", "ux": 0.25 * f, "uy": 1.0, "s": 10.0 + (12.0 if alt < 120.0 else 0.0)})
`,
  `		var up: Dictionary = data().uppercut   # the slam lever: more forward carry, so the fall lands under 70 degrees
		c.append({"name": "UPPERCUT", "ux": float(up.ux) * f, "uy": float(up.uy), "s": 10.0 + (12.0 if alt < 120.0 else 0.0)})
`]]);
console.log("slam lever applied to " + root + " (ux " + UX + ")");
