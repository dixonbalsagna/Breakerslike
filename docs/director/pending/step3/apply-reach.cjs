// The reach fix (QA: a few strikes in a million land beyond 68 u, or far off level on flat ground). Usage, from the repo root: node docs/director/pending/step3/apply-reach.cjs .
// Three causes, all in the director:
//  1. A catch on a body in flight: the closing move and the strike beat can land a tick apart, and the body's speed
//     can drop on the same tick (a bounce), so the placement limit computed from its speed was too small.
//  2. A break launch (a limb breaks mid-exchange) left the exchange's later moves and blows pending: a leftover move
//     dragged the launched fighter back, and a leftover blow hit it from far off level.
//  3. A fighter in flight or down could still throw the exchange's next blow.
const fs = require("fs"), path = require("path");
const root = process.argv[2];
if (!root) throw "usage: node apply-reach.cjs <root>";
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

edit("sim/director/melee.gd", [
  // 1. a catch always places the striker
  [`## the same tick, the strike itself places the striker. Farther than placementReaches (the contact block) plus two ticks of the
## target's own flight it is left alone and the feed says so (5.5, the reach check).`,
   `## the same tick, the strike itself places the striker. A catch always does: when the target is a body in flight, or the
## striker's closing move on it is still running (the move and the strike beat can land a tick apart). Otherwise, farther
## than placementReaches (the contact block) plus two ticks of the target's speed, it is left alone and the feed says so
## (5.5, the reach check).`],
  [`	var lim: float = reach * float(ct.placementReaches) + SimDetMath.hypot(d.vx, d.vy) * SimConst.DT * PLACE_FLIGHT_TICKS
	if absf(dx) > lim or absf(dy) > lim:
`,
   `	var lim: float = reach * float(ct.placementReaches) + SimDetMath.hypot(d.vx, d.vy) * SimConst.DT * PLACE_FLIGHT_TICKS
	var catching: bool = d.state == "launched" or (a.rush != null and a.rush.tgt == d)
	if not catching and (absf(dx) > lim or absf(dy) > lim):
`],
  // 3. a fighter in flight or down throws no blow
  [`	if dmg > 0.0:
		_contact(S, a, d)
	if d.state == "launched" or d.state == "down":
`,
   `	if (a.state == "launched" or a.state == "down") and not DirData.contact().is_empty():
		return   # a fighter in flight or down throws no blow (a blow scheduled before it was launched)
	if dmg > 0.0:
		_contact(S, a, d)
	if d.state == "launched" or d.state == "down":
`],
  // 2. a break ends the exchange's own string
  [`static func _breakChapter(S: SimState, ex, a, d) -> void:
	for b in ex.beats:
		if not b.done and (b.op == "launch" or b.op == "window"):
			b.done = true
`,
   `static func _breakChapter(S: SimState, ex, a, d) -> void:
	# With a contact block the break ends the string: every pending beat is dropped, not only the launches and the
	# window. A leftover step-in used to drag the launched fighter back, and a leftover blow hit it from far off.
	var all: bool = not DirData.contact().is_empty()
	for b in ex.beats:
		if not b.done and (all or b.op == "launch" or b.op == "window"):
			b.done = true
`]]);

edit("sim/director/exchange.gd", [
  [`		"rush":
			var r := SimState.Rush.new()
`,
   `		"rush":
			if (A.state == "launched" or A.state == "down") and not DirData.contact().is_empty():
				return   # a fighter in flight or down makes no closing move
			var r := SimState.Rush.new()
`],
  [`		"finRush":
			var fw = A if a.w == "A" else D
`,
   `		"finRush":
			var fw = A if a.w == "A" else D
			if (fw.state == "launched" or fw.state == "down") and not DirData.contact().is_empty():
				return   # a fighter in flight or down makes no closing move
`]]);
console.log("reach fix applied to " + root);
