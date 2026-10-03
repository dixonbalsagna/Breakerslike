// Combat's one spelling for the archetype (docs/combat/pending/apply-order.md step 1, the split): `antihero` becomes `rival`.
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit where Combat re-keys data/combat/finishers.json
// (shapes.antihero -> shapes.rival; the two `fighter` strings and the two select.byFighter keys) and styles.json (traits and
// futureKinds antihero -> rival), with the roster ids Simulation's split lands:
//     node docs/tools/pending/apply-split-keys.cjs
// It does NOT edit data/. It renames the archetype key under `shapes` in tools/schemas/combat-finishers.schema.json (the styles schema
// does not name it; the style-fighter rule reads the keys of shapes, so it follows) and adds the rule `finisher-fighter`: a finisher's
// `fighter` is `*` or an id of data/fighters/roster.json, and every key of select.byFighter is a roster id. Re-runnable.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');

// ---- schema: the shapes key ----
{
  const f = 'tools/schemas/combat-finishers.schema.json';
  const s = rj(f);
  const sh = s.properties.shapes;
  if (sh.properties.antihero) {
    const props = {};
    for (const k of Object.keys(sh.properties)) props[k === 'antihero' ? 'rival' : k] = sh.properties[k];
    sh.properties = props;
    sh.required = sh.required.map((k) => (k === 'antihero' ? 'rival' : k));
    wj(f, s);
  }
}

// ---- xref: the finisher's fighter and the select keys are roster ids ----
{
  const f = 'tools/lib/xref.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'finisher-fighter'")) {
    const anchor = "      if (fin.select.fallback !== undefined && !finIds.has(fin.select.fallback))";
    if (!t.includes(anchor)) throw new Error('finisher select anchor');
    t = t.replace(anchor, () => [
      "      const rosterFin = get(ROSTER);",
      "      const rosterFinIds = Array.isArray(rosterFin) ? rosterFin : isObj(rosterFin) && Array.isArray(rosterFin.order) ? rosterFin.order : null;",
      "      // the self-test runs against the validator's own fixture roster (FIXTURE_HERO and the like), which no live finisher names: skip it",
      "      const rosterFinLive = Array.isArray(rosterFinIds) && !rosterFinIds.every((x) => typeof x === 'string' && x.startsWith('FIXTURE_'));",
      "      if (rosterFinLive) for (const fighter of Object.keys(fin.select.byFighter || {})) if (!fighter.startsWith('_') && !rosterFinIds.includes(fighter)) err(FIN, `/select/byFighter/${esc(fighter)}`, 'finisher-fighter', `select.byFighter names \"${fighter}\", who is not in the roster (${rosterFinIds.join(', ')})`);",
      "      if (rosterFinLive) fin.finishers.forEach((fr, i) => { if (isObj(fr) && typeof fr.fighter === 'string' && fr.fighter !== '*' && !rosterFinIds.includes(fr.fighter)) err(FIN, `/finishers/${i}/fighter`, 'finisher-fighter', `finisher \"${fr.id}\" is for \"${fr.fighter}\", who is not in the roster (${rosterFinIds.join(', ')})`); });",
      anchor,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- cases ----
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const F = 'data/combat/finishers.json';
  const fin = rj(F);
  const idx = (id) => fin.finishers.findIndex((x) => x.id === id);
  const placed = fin.finishers.findIndex((x) => x.fighter !== '*' && x.profile === 'authored');
  const fx = (n, mut, expect) => ({ id: 'combat-finishers-' + n, schema: 'combat-finishers.schema.json', mutate: [{ file: F, ...mut }], expect });
  // the rule runs only against a roster that is not the self-test's fixture: these cases swap in a two-id roster (which also draws roster-id
  // findings for its missing folders; they are not what the cases look for)
  const R = 'data/fighters/roster.json';
  const rosterOf = (mut, expect) => ({ mutate: [{ file: R, set: { '/0': 'ROSTERED_A', '/1': 'ROSTERED_B' } }, { file: F, ...mut }], expect: Object.assign({ file: F }, expect) });
  const rx = (n, mut, expect) => Object.assign({ id: 'combat-finishers-' + n, schema: 'combat-finishers.schema.json' }, rosterOf(mut, expect));
  const P = `/finishers/${placed}/fighter`;
  const add = [
    fx('shapes-rival-required', { del: ['/shapes/rival'] }, { rule: 'required', pointer: '/shapes' }),
    fx('shapes-antihero-retired', { set: { '/shapes/antihero': {} } }, { rule: 'additionalProperties', pointer: '/shapes/antihero' }),
    fx('shapes-protagonist-required', { del: ['/shapes/protagonist'] }, { rule: 'required', pointer: '/shapes' }),
    fx('fighter-under-fixture-roster-skipped', { set: { [P]: 'NOBODY' } }, null),
    rx('fighter-not-in-roster', { set: { [P]: 'NOBODY' } }, { rule: 'xref:finisher-fighter', pointer: P }),
    rx('fighter-lowercase-not-in-roster', { set: { [P]: 'rostered_a' } }, { rule: 'xref:finisher-fighter', pointer: P }),
    rx('select-key-not-in-roster', { set: { '/select/byFighter/NOBODY': fin.select.fallback } }, { rule: 'xref:finisher-fighter', pointer: '/select/byFighter/NOBODY' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`split keys applied (${n} new cases)`);
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('finisher-fighter')) {
    const line = t.split('\n').find((l) => l.includes('`finisher-key`'));
    if (!line) throw new Error('split README anchor');
    t = t.replace(line, () => line + '\n| `finisher-fighter` | data/combat/finishers.json: a finisher\'s `fighter` is `*` or an id of data/fighters/roster.json, and every key of select.byFighter is a roster id |');
    fs.writeFileSync(f, t);
  }
}
