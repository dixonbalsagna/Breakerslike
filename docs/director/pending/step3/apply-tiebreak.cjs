// The queue's tie-break (docs/controls/two-player-feel.md): on a tie of age, the fighter who did not start the last
// exchange goes first. Needs step 3 (DirInterrupt.LAST_START). Usage, from the repo root: node docs/director/pending/step3/apply-tiebreak.cjs .
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw "usage: node apply-tiebreak.cjs <root>";
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
edit("sim/director/exchange.gd", [
  [`## Starts the oldest queued request the director can take: the older one first, the slots alternating on a tie. A request
`,
   `## Starts the oldest queued request the director can take: the older one first; on a tie of age the fighter who did not
## start the last exchange (two players pressing at one fixed gap could phase-lock the queue), then the slots alternating. A request
`],
  [`	if q0.is_empty() or (not q1.is_empty() and (q1[3] < q0[3] or (q1[3] == q0[3] and S.tick % 2 == 1))):
		order = [1, 0]
`,
   `	var l0: int = DirInterrupt.gi(S.fighters[0], DirInterrupt.LAST_START)
	var l1: int = DirInterrupt.gi(S.fighters[1], DirInterrupt.LAST_START)
	if q0.is_empty() or (not q1.is_empty() and (q1[3] < q0[3] or (q1[3] == q0[3] and (l1 < l0 or (l1 == l0 and S.tick % 2 == 1))))):
		order = [1, 0]
`]]);
console.log("tie-break applied to " + root);
