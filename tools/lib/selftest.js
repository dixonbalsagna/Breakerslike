'use strict';
// `node tools/validate.js --self-test`: proves the validator can fail, and fail on the right rule.
//   1. the strict parser agrees with JSON.parse on every data file, and rejects/flags bad text
//   2. the schema engine, keyword by keyword (tools/fixtures/engine-cases.json)
//   3. the schema files: supported keywords only, references resolve, none orphaned
//   4. the data cases (tools/fixtures/cases.json): mutate real data, expect exactly the named finding
//   5. coverage: every schema has a valid document and at least three invalid cases
// Fighter data does not exist yet, so the self-test uses tools/fixtures/virtual/data/fighters
// (neutral FIXTURE_* names) in its place and ignores any real data/fighters folder.
const fs = require('node:fs');
const path = require('node:path');
const core = require('./core');
const { validate, checkSchema } = require('./schema');

const fixtures = path.join(core.repoRoot, 'tools', 'fixtures');
// Folders whose data does not exist yet: the self-test uses tools/fixtures/virtual in their place and ignores real files.
const VIRTUAL_DIRS = ['data/fighters/', 'data/fight/', 'data/input/'];
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));

function walk(dir, base, out) {
  for (const name of fs.readdirSync(dir).sort()) {
    const abs = path.join(dir, name);
    if (fs.statSync(abs).isDirectory()) walk(abs, base, out);
    else if (name.endsWith('.json')) out.push(core.posix(path.relative(base, abs)));
  }
  return out;
}

// { rel -> { text, value, lineOf, lint } } for the live data (minus fighters) plus the virtual fighters.
function loadBase() {
  const base = new Map();
  const add = (rel, text) => {
    const { parsed, findings } = core.lintText(rel, text);
    base.set(rel, { text, parsed, lint: findings, value: parsed.ok ? parsed.value : undefined, lineOf: parsed.line });
  };
  for (const rel of core.discover([])) {
    if (VIRTUAL_DIRS.some((p) => rel.startsWith(p))) continue;
    add(rel, fs.readFileSync(path.join(core.repoRoot, rel), 'utf8'));
  }
  const vdir = path.join(fixtures, 'virtual');
  for (const rel of walk(vdir, vdir, [])) add(rel, fs.readFileSync(path.join(vdir, rel), 'utf8'));
  return base;
}

const tokens = (pointer) => (pointer === '' ? [] : pointer.slice(1).split('/').map((t) => t.replace(/~1/g, '/').replace(/~0/g, '~')));

function applyValueMutation(value, m) {
  if (m.root !== undefined) return structuredClone(m.root);
  const doc = structuredClone(value);
  const parentOf = (pointer) => {
    const ts = tokens(pointer);
    let node = doc;
    for (const t of ts.slice(0, -1)) {
      if (node === null || typeof node !== 'object' || !(t in node)) throw new Error(`fixture path missing: ${pointer}`);
      node = node[t];
    }
    return { node, key: ts[ts.length - 1] };
  };
  for (const [pointer, v] of Object.entries(m.set || {})) {
    if (pointer === '') throw new Error('cannot replace the root');
    const { node, key } = parentOf(pointer);
    if (Array.isArray(node) && !(Number(key) in node)) throw new Error(`fixture path missing: ${pointer}`);
    node[key] = v;
  }
  for (const pointer of m.del || []) {
    const { node, key } = parentOf(pointer);
    if (Array.isArray(node)) {
      if (!(Number(key) in node)) throw new Error(`fixture path missing: ${pointer}`);
      node.splice(Number(key), 1);
    } else {
      if (!(key in node)) throw new Error(`fixture path missing: ${pointer}`);
      delete node[key];
    }
  }
  return doc;
}

// Findings for the base data with the given mutations applied.
function analyze(base, mutations) {
  const docs = new Map();
  const findings = [];
  for (const [rel, b] of base) {
    if (b.value !== undefined) docs.set(rel, { value: b.value, lineOf: b.lineOf });
    findings.push(...b.lint);
  }
  for (const m of mutations) {
    const b = base.get(m.file);
    if (!b) throw new Error(`fixture file missing: ${m.file}`);
    if (m.replace) {
      if (!b.text.includes(m.replace[0])) throw new Error(`fixture text missing: ${m.replace[0]}`);
      const { parsed, findings: lint } = core.lintText(m.file, b.text.replace(m.replace[0], m.replace[1]));
      findings.push(...lint.filter((f) => !b.lint.some((o) => o.rule === f.rule && o.pointer === f.pointer)));
      if (parsed.ok) docs.set(m.file, { value: parsed.value, lineOf: parsed.line });
    } else {
      docs.set(m.file, { value: applyValueMutation(b.value, m), lineOf: b.lineOf });
    }
  }
  findings.push(...core.analyzeDocs(docs, { withXref: true }));
  return findings;
}

const keyOf = (f) => `${f.file}|${f.rule}|${f.pointer}`;

function run() {
  let pass = 0;
  const failures = [];
  const record = (section, name, ok, detail) => {
    if (ok) pass++;
    else failures.push(`${section}: ${name}${detail ? `\n      ${detail}` : ''}`);
  };
  const guard = (section, name, fn) => {
    try {
      fn();
    } catch (e) {
      record(section, name, false, e.message);
    }
  };

  // 1. parser ---------------------------------------------------------------
  const base = loadBase();
  for (const [rel, b] of base) {
    guard('parser', `${rel} parses like JSON.parse`, () => {
      record('parser', `${rel} parses like JSON.parse`, b.parsed.ok && JSON.stringify(b.value) === JSON.stringify(JSON.parse(b.text)), b.parsed.ok ? 'values differ' : b.parsed.error.message);
    });
  }
  const textCases = readJson(path.join(fixtures, 'cases.json')).text;
  for (const c of textCases) {
    guard('parser', c.id, () => {
      const { findings } = core.lintText('case.json', c.text);
      if (c.expect === null) return record('parser', c.id, findings.length === 0, `unexpected: ${findings.map((f) => f.rule).join(', ')}`);
      const hit = findings.find((f) => f.rule === c.expect.rule && (c.expect.pointer === undefined || f.pointer === c.expect.pointer));
      record('parser', c.id, Boolean(hit), `expected [${c.expect.rule}]${c.expect.pointer ? ` at ${c.expect.pointer}` : ''}, got ${findings.map((f) => `[${f.rule}] ${f.pointer}`).join('; ') || 'nothing'}`);
    });
  }

  // 2. engine ----------------------------------------------------------------
  const engine = readJson(path.join(fixtures, 'engine-cases.json'));
  for (const c of engine.cases) {
    guard('engine', c.id, () => {
      const problems = checkSchema(c.schema);
      if (problems.length) return record('engine', c.id, false, `case schema is unsupported: ${problems[0]}`);
      const got = validate(c.schema, c.instance).map((e) => `${e.pointer}|${e.rule}`).sort();
      const want = c.expect.map(([p, r]) => `${p}|${r}`).sort();
      record('engine', c.id, JSON.stringify(got) === JSON.stringify(want), `expected ${JSON.stringify(want)}, got ${JSON.stringify(got)}`);
    });
  }
  for (const c of engine.unsupported) {
    guard('engine', `checkSchema rejects ${c.id}`, () => record('engine', `checkSchema rejects ${c.id}`, checkSchema(c.schema).length > 0, 'accepted a schema it cannot honour'));
  }

  // 3. schema files ------------------------------------------------------------
  const schemaFindings = core.checkSchemaFiles();
  record('schemas', 'every schema file is valid, uses supported keywords only, and its $refs resolve', schemaFindings.length === 0, schemaFindings.map((f) => `${f.file}: ${f.message}`).join('; '));
  const mapped = new Set(core.loadMap().rules.map((r) => r.schema));
  for (const name of mapped) record('schemas', `map.json names an existing schema: ${name}`, core.loadSchema(name) !== undefined);
  const onDisk = fs.readdirSync(core.schemaDir).filter((n) => n.endsWith('.schema.json'));
  const referenced = new Set([...mapped]);
  for (const name of onDisk) {
    const text = fs.readFileSync(path.join(core.schemaDir, name), 'utf8');
    for (const m of text.matchAll(/"\$ref":\s*"([^"#]+)#/g)) referenced.add(m[1]);
  }
  for (const name of onDisk) record('schemas', `${name} is used by map.json or referenced by another schema`, referenced.has(name));
  for (const name of onDisk) {
    const s = core.loadSchema(name);
    guard('schemas', `${name} declares a version field`, () => {
      const req = (s.required || []).includes('schema') || (s.required || []).includes('version') || s.type === 'array' || Array.isArray(s.oneOf);
      record('schemas', `${name} requires a version field (schema or version), or is a bare array`, req);
    });
    record('schemas', `${name} states its additionalProperties policy`, typeof s.description === 'string' && /policy/i.test(s.description), 'add "Policy: ..." to the description');
  }

  // 4. data cases --------------------------------------------------------------
  const { cases } = readJson(path.join(fixtures, 'cases.json'));
  guard('data', 'the unmutated data has no errors', () => {
    const errors = analyze(base, []).filter((f) => f.level === 'error');
    record('data', 'the unmutated data has no errors (run `node tools/validate.js`)', errors.length === 0, errors.slice(0, 3).map((f) => `${f.file} ${f.pointer} [${f.rule}]`).join('; '));
  });
  const baseKeys = new Set(analyze(base, []).map(keyOf));
  const perSchema = new Map();
  for (const c of cases) {
    perSchema.set(c.schema, (perSchema.get(c.schema) || 0) + 1);
    guard('data', c.id, () => {
      const mutations = c.mutate || [{ file: c.text.file, replace: c.text.replace }];
      const got = analyze(base, mutations).filter((f) => !baseKeys.has(keyOf(f)));
      if (c.expect === null) {
        // A "must be accepted" case: the mutation may add no error.
        const errors = got.filter((f) => f.level === 'error');
        return record('data', c.id, errors.length === 0, `unexpected errors: ${errors.slice(0, 3).map((f) => `${f.file} ${JSON.stringify(f.pointer)} [${f.rule}]`).join('; ')}`);
      }
      const file = c.expect.file || mutations[0].file;
      const hit = got.find((f) => f.file === file && f.rule === c.expect.rule && (c.expect.pointer === undefined || f.pointer === c.expect.pointer));
      record('data', c.id, Boolean(hit), `expected [${c.expect.rule}] in ${file}${c.expect.pointer !== undefined ? ` at ${JSON.stringify(c.expect.pointer)}` : ''}; new findings: ${got.slice(0, 4).map((f) => `${f.file} ${JSON.stringify(f.pointer)} [${f.rule}]`).join('; ') || 'none'}`);
    });
  }

  // 5. coverage ------------------------------------------------------------------
  for (const name of [...mapped].sort()) {
    const docsFor = [...base.keys()].filter((rel) => core.schemaNameFor(rel) === name);
    record('coverage', `${name}: at least one valid document`, docsFor.length >= 1, 'no live or virtual document maps to it');
    record('coverage', `${name}: at least three invalid cases`, (perSchema.get(name) || 0) >= 3, `has ${perSchema.get(name) || 0}`);
  }
  const known = new Set(mapped);
  for (const name of perSchema.keys()) record('coverage', `cases.json names a real schema: ${name}`, known.has(name));

  // report -------------------------------------------------------------------
  for (const f of failures) console.log(`FAIL  ${f}`);
  const total = pass + failures.length;
  console.log(`self-test: ${pass} of ${total} checks passed${failures.length ? `, ${failures.length} FAILED` : ''}`);
  console.log(`  parser ${base.size} files + ${textCases.length} text cases; engine ${engine.cases.length} cases + ${engine.unsupported.length} unsupported; schemas ${onDisk.length}; data cases ${cases.length}`);
  return failures.length ? 1 : 0;
}

module.exports = { run };
