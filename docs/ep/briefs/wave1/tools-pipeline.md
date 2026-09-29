# P0 wave 1 brief: tools-pipeline

From the Executive Producer, 2026-09-28. Prototype line references are pinned to commit 7233c96.

Brief from the EP (P0 wave 1): tonight you build the workshop foundations: data schemas with a validator, a one-command setup-and-check, CI, a pinned dependency and a PR template.

GOAL: A fresh clone can be set up and checked with one command, CI runs the same steps on Node 24, and schema validation catches bad data before runtime.

CONTEXT (read first):
- docs/directors/tools-pipeline.md (charter) and CLAUDE.md (Architecture, 'Content is data', Roadmap P0 exit criteria).
- prototype/index.html, read only. QA's edit tonight moved every line after 216 down by one, so anchor on function names.
  - Data still lives in code. Fighter shape is ROSTER (name, title, role, col, aura, hair, care, dmgMul, spd, maxhp, sigName).
  - Biomes are SEG [start,end,name] plus BCOL, with W=9600 and COL=8.
  - Atoms and exchanges are the beats in planMelee via B(ex,t,fn), S, LAUNCH, WIN, rush and the tag field. Beam variants are in planBeam.
  - Derive first-draft schemas from these and expect revisions: Combat, World and Narrative send field lists through the EP.
- data/ does not exist, and you must not create it. Folder owners:
  - data/atoms and data/exchanges: Combat. data/biomes: World. data/fighters: Narrative. All three wait for your schemas.
  - data/director: Encounter Systems. It has no schema yet.
  Ship valid and invalid fixtures under tools/.
- qa/README.md and qa/run-all.js: CommonJS, with no package.json in qa/. Exit code 0 or 1, about 30 s. Golden hashes were recorded on Node v24.19.0 on Windows (QA-005). Do not edit qa/ or sim/. Simulation is porting tonight and owns sim/package.json.
- prototype/package.json pins @napi-rs/canvas as '*' in optionalDependencies. prototype/tools/headless.js (QA's) requires it inside a try. Once it is installed, every session running the harness (QA, Simulation's parity runs, Performance, World) gets a real canvas instead of the stub. The runner never calls render(), so the hashes should not move. Prove it.
- docs/legal/licence-register.md rule 1 and Part A3: no third-party component (npm package or GitHub Action) is merged until Legal has a row for it. You cannot edit docs/legal/, so list each component for the EP. Legal is writing contributor rules and PR-template wording tonight; they reach you later through the EP. The licence is pending Orb, so nothing may assume one.

YOU OWN: tools/, build/ and .github/, plus these EP-ruled files: root package.json, root package-lock.json (only if the root gets dependencies), prototype/package.json and prototype/package-lock.json. Nothing else. The root .gitignore, .gitattributes, README.md and CLAUDE.md are the EP's, so ask. Keep tools/gen_directors.py working.

ACCEPTANCE CRITERIA:
1. tools/schemas/ holds JSON Schemas (draft 2020-12) for atom, exchange, fighter and biome. Each has a required version field and a stated additionalProperties policy. tools/schemas/README.md lists every field, its source in the prototype, and open questions for Combat, World and Narrative.
2. 'node tools/validate.js [paths]' validates data/**, or the given paths, through a folder-to-schema map (atoms, exchanges, fighters, biomes).
   - Exit 0 when everything passes, including when data/ is missing or empty. Exit 1 on any error.
   - Each error names the file, the JSON pointer and the rule.
   - A JSON file in a folder with no schema (for example data/director/) produces a warning, not a failure.
   - Prefer Node built-ins, implementing only the keywords your schemas use. If you choose a library such as ajv, pin it exactly, commit the root lockfile and state the trade-off.
3. Fixtures under tools/: at least one valid and three invalid per schema. 'node tools/validate.js --self-test' proves each invalid fixture fails on the expected rule and each valid one passes. A fighter fixture derived from ROSTER and a biome set derived from SEG and BCOL both validate. Fixture names are neutral ('fixture-hero', 'fixture-villain'), never KAI (RL-002), and no fixture uses '#ffd54a' (RL-014).
4. Root package.json scripts:
   - 'test' runs 'node qa/run-all.js' (EP ruling).
   - 'validate' runs the validator.
   - 'check' runs the validator self-test, validate and test.
   - 'setup' (build/setup.js) warns clearly when Node's major version is not 24, installs the prototype's pinned dependencies with npm ci, then runs check.
   Add engines node 24.x. Do not set 'type': 'module' at the root, because qa/*.js is CommonJS and would break; use .mjs for ESM. Declare no workspaces, and do not reference sim/ tonight.
5. One-command evidence: copy the working tree, without .git and node_modules, into your scratchpad directory and run 'npm run setup' there once. Put the exit code, the wall time and the last 20 lines of output in the report. If a failure comes from qa/ or prototype/, report it and do not fix it.
6. prototype/package.json pins @napi-rs/canvas to an exact current version (check with npm view, and keep it optional), and prototype/package-lock.json exists. Run 'node qa/run-all.js' and 'node prototype/tools/screenshot.js' both with the package installed and without it. Report both runs, including that the golden hashes still pass.
7. .github/workflows/ci.yml runs on push and pull_request:
   - Node pinned to 24.19.0, the version the goldens were recorded on, and no other Node major.
   - npm ci where a lockfile exists, then the validator self-test, validate, and 'node qa/run-all.js'.
   - Every action pinned to a full commit SHA, with its version in a comment.
   'npm run ci' (or build/ci-local.js) runs the same steps in the same order and passes on this machine. tools/README.md states three things: the first Actions run after the EP pushes is the real proof; the goldens were recorded on Windows, so a Linux runner is the first cross-OS check (fallback: windows-latest); and branch protection is not assumed on a private repo.
8. .github/pull_request_template.md has an engineering checklist: npm run check passes; data is validated; any sim-behaviour change comes with an intended golden update and a reason. It also has placeholders for DCO sign-off, the originality note, AI disclosure and third-party rows, each marked 'wording pending Legal'. No invented legal text.
9. tools/README.md covers each script, the folder-to-schema map, how to add a schema, and one line: 'licence check: planned after Orb's licence decision'. No licence-check script or workflow, and no LICENSE file, tonight.

CONSTRAINTS: No git state changes. Do not touch sim/, qa/, data/, docs/ or any root file other than package.json and package-lock.json. Validators and tools are deterministic: no clock or Math.random in output. No franchise names or terms in examples; fixture names follow docs/legal/originality-rules.md. Run the full QA suite only when a criterion needs it, because other sessions are timing on this machine.

RETURN: the standard report (SUMMARY, CHANGES, DECISIONS, NEEDS FROM EP, RISKS, NEXT), sent to me with SendMessage. NEEDS FROM EP lists every third-party component you added for Legal's register: name, exact version, licence, source URL, dev-only or shipped, and each GitHub Action with its SHA.

## Since this brief was drafted

1. QA's CI asks:
- Run node qa/run-all.js (6 test files, about 33 s) on every push and pull request.
- Pin Node to 24.19.0, because the golden hashes depend on it.
- Add a workflow_dispatch job for node qa/baseline-diff.js --fail (about 90 s), for use when numbers change.

2. Fields for your schemas, from Narrative:
- Fighter personality weights: docs/narrative/fighter-sketches.md section 4b.
- A place_name per region: docs/narrative/places.md.
Narrative also suggests that on-screen strings live in a data table (docs/narrative/glossary.md). Note it for schema v2, but don't build it tonight.

3. Simulation created sim/package.json ("type": "module") for its port. Don't reference sim/ tonight. You'll wire in npm test --prefix sim in wave 2.
