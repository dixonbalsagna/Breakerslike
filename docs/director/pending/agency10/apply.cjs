// Agency slice 10: the alchemy layer's A1 and A2 (docs/director/alchemy-plan.md). The press log is read by Controls'
// classifier (SimPressRead), and each strike the director plans is given a piece from Combat's recipe pools by the
// fighter's style. Applies on top of slice 9. node apply.cjs <repo root>. Idempotent.
// alchemy.gd and recipe.gd beside this script become sim/director/alchemy.gd (replaced) and sim/director/recipe.gd (new);
// alchemy.json becomes data/director/alchemy.json (new).
// It also places Combat's parked recipes as data/combat/recipes.json (the EP's grant for that one file); Tools'
// docs/tools/pending/apply-recipes.cjs and apply-slice10.cjs add the schemas. Without the file the slice runs with no pieces.
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

for (const [src, dst] of [["alchemy.gd", "sim/director/alchemy.gd"], ["recipe.gd", "sim/director/recipe.gd"], ["alchemy.json", "data/director/alchemy.json"]]) {
  fs.copyFileSync(path.join(__dirname, src), path.join(root, dst));
  console.log(dst + ": written");
}

// ---------------------------------------------------------------- Combat's recipes become live data (the EP's grant: this one file)
{
  const src = path.join(root, "docs/combat/pending/recipes.alchemist.json");
  const dst = path.join(root, "data/combat/recipes.json");
  let t = fs.readFileSync(src, "utf8");
  const line = /^[ \t]*"_target":[^\n]*\n/m;
  if (!line.test(t)) throw new Error("recipes: no _target line in the parked draft");
  t = t.replace(line, "");   // Combat: it becomes data/combat/recipes.json as it stands, without _target
  JSON.parse(t);
  fs.writeFileSync(dst, t);
  console.log("data/combat/recipes.json: written from Combat's parked draft");
}

// ---------------------------------------------------------------- every planned strike is given its piece
edit("sim/director/exchange.gd", [
  [L(2, "planCheck.call(chk, ex, S.rng.a, \"sig\" if kind == \"sig\" else \"melee\")"),
   L(2, "planCheck.call(chk, ex, S.rng.a, \"sig\" if kind == \"sig\" else \"melee\")") +
   L(1, "DirRecipe.dress(S, ex)   # the alchemist: each strike of the plan takes a piece from the pool its fighter's style calls")],
  [L(1, "DirInterrupt.onChainLink(S, ex)   # step 3: the defender's burst at its link (the AI, the Simple layout's autoBurst)"),
   L(1, "DirRecipe.dress(S, ex)   # the link's strikes take their pieces") +
   L(1, "DirInterrupt.onChainLink(S, ex)   # step 3: the defender's burst at its link (the AI, the Simple layout's autoBurst)")],
  [L(1, "SimEvents.feed(S, ex.A.name + \" BLUR CLOSES\", \"no press came: the blur plays its ender\")") +
   L(1, "var chk = null") +
   L(1, "if planCheck.is_valid():") +
   L(2, "chk = _planByCode(S, ex, \"chain\")") +
   L(1, "DirData.planChain(ex)") +
   L(1, "if chk != null:") +
   L(2, "planCheck.call(chk, ex, S.rng.a, \"chain\")"),
   L(1, "SimEvents.feed(S, ex.A.name + \" BLUR CLOSES\", \"no press came: the blur plays its ender\")") +
   L(1, "var chk = null") +
   L(1, "if planCheck.is_valid():") +
   L(2, "chk = _planByCode(S, ex, \"chain\")") +
   L(1, "DirData.planChain(ex)") +
   L(1, "if chk != null:") +
   L(2, "planCheck.call(chk, ex, S.rng.a, \"chain\")") +
   L(1, "DirRecipe.dress(S, ex, true)   # the blur's own ender takes its piece")],
]);

// ---------------------------------------------------------------- the recipes and the alchemy numbers are in the data hash
edit("sim/director/data.gd", [
  [L(1, "h.text(DirInterrupt.dataText())   # data/director/interrupts.json, and Controls' perfect-block timing"),
   L(1, "h.text(DirInterrupt.dataText())   # data/director/interrupts.json, and Controls' perfect-block timing") +
   L(1, "h.text(DirRecipe.dataText())   # data/director/alchemy.json and Combat's data/combat/recipes.json")],
]);

// ---------------------------------------------------------------- a charged shot's flash, for the release grade
edit("sim/director/blast.gd", [
  [L(1, "DirInterrupt.si(A, DirInterrupt.BLAST_REQ, req)") +
   L(1, "SimFx.cue(S, A, \"blast_charge\" if weight == SimAct.HEAVY else \"blast_windup\", \"\", \"\")"),
   L(1, "DirInterrupt.si(A, DirInterrupt.BLAST_REQ, req)") +
   L(1, "if weight == SimAct.HEAVY:") +
   L(2, "DirAlchemy.flash(A, SimAct.HEAVY, S.tick + int(c.heavy.chargeTicks) - 1)   # the planned flash of the full charge: a release is graded against it") +
   L(1, "SimFx.cue(S, A, \"blast_charge\" if weight == SimAct.HEAVY else \"blast_windup\", \"\", \"\")")],
]);
console.log("done");
