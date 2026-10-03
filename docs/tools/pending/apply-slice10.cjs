// Schema for Encounter's slice 10, data/director/alchemy.json (director.alchemy/1; docs/director/alchemy-plan.md; the draft is
// docs/director/pending/agency10/alchemy.json). NOT run by CI, the validator or the sim. Run once from the repo root, in the commit that
// lands the file, together with data/combat/recipes.json and apply-recipes.cjs (either order):
//     node docs/tools/pending/apply-slice10.cjs
// It does NOT edit data/. It adds tools/schemas/director-alchemy.schema.json (closed; underscore keys are notes), the map entry, a
// validator fixture (tools/fixtures/virtual/data/director/alchemy.json, data/director is virtual), the rules alchemy-fighter (every
// recipes.fighters key is a roster id), alchemy-pool (every value is a key of data/combat/recipes.json pools; a roster id the map does
// not list and whose lower-case id is no pool is a warning) and the cases. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);

// =============================== schema ===============================
{
  const f = 'tools/schemas/director-alchemy.schema.json';
  if (!fs.existsSync(f)) {
    wj(f, {
      $schema: 'https://json-schema.org/draft/2020-12/schema',
      $id: 'meridian/director-alchemy',
      title: 'director.alchemy/1',
      description: 'data/director/alchemy.json: the fight alchemist\'s switches (sim/director/alchemy.gd, recipe.gd; docs/director/alchemy-plan.md): whether strikes are given a piece, and which pool of data/combat/recipes.json each roster id draws on. The press log\'s own numbers are Controls\' (data/input/timing.json) and the pieces are Combat\'s (data/combat/recipes.json). Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every fighters key is a roster id; every value is a key of the recipes pools; a roster id with no entry and no pool of its lower-case id is a warning) are checked by tools/lib/xref-fight.js (alchemy-*).',
      type: 'object',
      required: ['schema', 'recipes'],
      properties: {
        schema: { const: 'director.alchemy/1' },
        recipes: obj({
          enabled: { type: 'boolean', description: 'true: every strike the director plans is given a piece (args.piece on its beat) from the pool its fighter\'s style calls; false: strikes carry no piece.' },
          fighters: {
            type: 'object',
            minProperties: 1,
            propertyNames: { pattern: '^(_.*|[A-Z][A-Z0-9_]*)$' },
            additionalProperties: { type: 'string', pattern: '^[a-z][a-z0-9_]*$', description: 'The key of data/combat/recipes.json pools this roster id draws on.' },
            patternProperties: { '^_': true },
            description: 'Roster id to the key of data/combat/recipes.json pools (a fighter not listed uses his id in lower case).',
          },
        }, { description: 'The recipe layer.' }),
      },
      additionalProperties: false,
      patternProperties: { '^_': true },
    });
  }
}

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/director/alchemy.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/director/launch.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/director/alchemy.json', schema: 'director-alchemy.schema.json' });
    wj(f, m);
  }
}

// =============================== fixture ===============================
{
  const f = 'tools/fixtures/virtual/data/director/alchemy.json';
  if (!fs.existsSync(f)) {
    wj(f, {
      schema: 'director.alchemy/1',
      _about: 'Validator fixture, not game data: the shape of the live file, keyed by the fixture roster.',
      recipes: { enabled: true, fighters: { FIXTURE_HERO: 'protagonist', FIXTURE_VILLAIN: 'rival' } },
    });
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'alchemy-pool'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- director alchemy: the fighters are roster ids and draw on pools of the recipes ----',
      "  const alch = get('data/director/alchemy.json');",
      '  if (isObj(alch) && isObj(alch.recipes) && isObj(alch.recipes.fighters)) {',
      "    const AL = 'data/director/alchemy.json';",
      "    const rosterAl = get('data/fighters/roster.json');",
      '    const rosterAlIds = Array.isArray(rosterAl) ? rosterAl : isObj(rosterAl) && Array.isArray(rosterAl.order) ? rosterAl.order : null;',
      "    const recAl = get('data/combat/recipes.json');",
      '    const poolKeys = isObj(recAl) && isObj(recAl.pools) ? Object.keys(recAl.pools).filter((k) => !k.startsWith(\'_\')) : null;',
      '    const map = alch.recipes.fighters;',
      '    for (const [rid, pool] of Object.entries(map)) {',
      "      if (rid.startsWith('_')) continue;",
      "      if (rosterAlIds && !rosterAlIds.includes(rid)) err(AL, `/recipes/fighters/${esc(rid)}`, 'alchemy-fighter', `\"${rid}\" is not in the roster (${rosterAlIds.join(', ')})`);",
      "      if (poolKeys && typeof pool === 'string' && !poolKeys.includes(pool)) err(AL, `/recipes/fighters/${esc(rid)}`, 'alchemy-pool', `\"${rid}\" draws on pool \"${pool}\", which is not a key of data/combat/recipes.json pools (${poolKeys.join(', ')})`);",
      '    }',
      "    if (rosterAlIds && poolKeys) for (const rid of rosterAlIds) if (typeof rid === 'string' && !(rid in map) && !poolKeys.includes(rid.toLowerCase())) err(AL, '/recipes/fighters', 'alchemy-pool', `roster id \"${rid}\" has no entry here and no pool \"${rid.toLowerCase()}\" in data/combat/recipes.json, so he gets no pieces`, 'warning');",
      '  }',
      '',
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const A = 'data/director/alchemy.json';
  const x = (n, mut, expect) => ({ id: 'director-alchemy-' + n, schema: 'director-alchemy.schema.json', mutate: [{ file: A, ...mut }], expect });
  const R = '/recipes/';
  const add = [
    x('live-valid', { set: { '/recipes/enabled': true } }, null),
    x('key-required', { del: ['/recipes'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'director.alchemy/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('recipes-key-required', { del: [R + 'enabled'] }, { rule: 'required', pointer: '/recipes' }),
    x('recipes-fighters-required', { del: [R + 'fighters'] }, { rule: 'required', pointer: '/recipes' }),
    x('recipes-unknown-key', { set: { [R + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: R + 'extra' }),
    x('recipes-note-ok', { set: { [R + '_note']: 'comment' } }, null),
    x('enabled-type', { set: { [R + 'enabled']: 'yes' } }, { rule: 'type', pointer: R + 'enabled' }),
    x('enabled-off-ok', { set: { [R + 'enabled']: false } }, null),
    x('fighters-type', { set: { [R + 'fighters']: ['rival'] } }, { rule: 'type', pointer: R + 'fighters' }),
    x('fighters-empty', { set: { [R + 'fighters']: {} } }, { rule: 'minProperties', pointer: R + 'fighters' }),
    x('fighter-key-shape', { set: { [R + 'fighters/hero']: 'rival' } }, { rule: 'propertyNames', pointer: R + 'fighters/hero' }),
    x('fighter-value-shape', { set: { [R + 'fighters/FIXTURE_HERO']: 'Rival' } }, { rule: 'pattern', pointer: R + 'fighters/FIXTURE_HERO' }),
    x('fighter-value-type', { set: { [R + 'fighters/FIXTURE_HERO']: 3 } }, { rule: 'type', pointer: R + 'fighters/FIXTURE_HERO' }),
    x('fighters-note-ok', { set: { [R + 'fighters/_why']: 'comment' } }, null),
    x('fighter-not-in-roster', { set: { [R + 'fighters/NOBODY']: 'rival' } }, { rule: 'xref:alchemy-fighter', pointer: R + 'fighters/NOBODY' }),
    x('fighter-pool-unknown', { set: { [R + 'fighters/FIXTURE_HERO']: 'nowhere' } }, { rule: 'xref:alchemy-pool', pointer: R + 'fighters/FIXTURE_HERO' }),
    x('fighters-share-a-pool-ok', { set: { [R + 'fighters/FIXTURE_HERO']: 'rival' } }, null),
    x('roster-id-unlisted-warns', { del: [R + 'fighters/FIXTURE_VILLAIN'] }, { rule: 'xref:alchemy-pool', pointer: R + 'fighters' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`slice 10 schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('alchemy-fighter')) {
    const line = t.split('\n').find((l) => l.includes('`launch-order`')) || t.split('\n').find((l) => l.includes('`blast-mine-kind`'));
    if (!line) throw new Error('slice 10 README anchor');
    t = t.replace(line, () => line + '\n| `alchemy-fighter`, `alchemy-pool` | data/director/alchemy.json: every recipes.fighters key is a roster id; every value is a key of data/combat/recipes.json pools; a roster id with no entry and no pool of his lower-case id is a warning |');
    fs.writeFileSync(f, t);
  }
}
