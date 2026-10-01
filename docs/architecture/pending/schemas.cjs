// The intro phase and the last stand: Tools' side (a schema for data/fight/intro.json, its map rule, its fixture and
// cases; lastStand in the wounds schema and fixtures). Needs the EP's grant: these are Tools' files.
// Run from the repo root. Re-runnable: every edit sets a value or checks before adding. Additive in map.json and cases.json.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');

// ---------------- fight-intro: the new schema, its map rule and its fixture ----------------
{
  const tick = (d) => ({ type: 'integer', minimum: 0, description: d });
  const s = {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    $id: 'meridian/fight-intro',
    title: 'fight.intro/1 (docs/architecture/intro-phase.md)',
    description: 'data/fight/intro.json: the intro phase\'s timeline (sim/core/intro.gd), in sim ticks (60 a second) from the first step. Fighter A is slot 0. The loader checks the order: each fall before its landing, A\'s landing not after B\'s, then the staredown, then the clock; skipFrom before the clock. Version field: schema. Policy: closed except keys starting with an underscore.',
    type: 'object',
    required: ['schema', 'ticks', 'fallHeight', 'craterEnergy'],
    properties: {
      schema: { const: 'fight.intro/1' },
      ticks: {
        type: 'object',
        required: ['fallA', 'landA', 'fallB', 'landB', 'staredown', 'clock', 'skipFrom'],
        description: 'The timeline.',
        properties: {
          fallA: tick('A\'s fall starts.'), landA: tick('A touches down; the entrance crater is dug.'),
          fallB: tick('B\'s fall starts.'), landB: tick('B touches down.'),
          staredown: tick('Both stand.'), clock: tick('The fight starts: the intro\'s length.'),
          skipFrom: tick('A press on a human slot skips from this tick on.'),
        },
        additionalProperties: false,
        patternProperties: { '^_': true },
      },
      fallHeight: { type: 'number', exclusiveMinimum: 0, description: 'Units above the ground a fall starts from.' },
      craterEnergy: { type: 'number', minimum: 0, description: 'The entrance crater\'s energy (World\'s crater scale); 0 digs none.' },
    },
    additionalProperties: false,
    patternProperties: { '^_': true },
  };
  wj('tools/schemas/fight-intro.schema.json', s);
  wj('tools/fixtures/virtual/data/fight/intro.json', {
    _about: 'Validator fixture, not game data.',
    schema: 'fight.intro/1',
    ticks: { fallA: 0, landA: 36, fallB: 84, landB: 114, staredown: 144, clock: 300, skipFrom: 30 },
    fallHeight: 6000,
    craterEnergy: 1.5,
  });
  const mf = 'tools/schemas/map.json';
  const m = rj(mf);
  if (!m.rules.some((r) => r.match === 'data/fight/intro.json')) {
    const at = m.rules.findIndex((r) => r.match === 'data/fight/pause.json');
    m.rules.splice(at + 1, 0, { match: 'data/fight/intro.json', schema: 'fight-intro.schema.json' });
    wj(mf, m);
  }
}

// ---------------- fighter-wounds: lastStand ----------------
{
  const f = 'tools/schemas/fighter-wounds.schema.json';
  const s = rj(f);
  s.properties.lastStand = {
    type: 'object',
    required: ['windowS'],
    description: 'The last stand (spec-wounds section 1b, point 7): one free signature at the fighter\'s first brink of a match.',
    properties: { windowS: { type: 'number', minimum: 0, description: 'The window in seconds of his free time; 0 switches it off. The loader requires a whole number of ticks.' } },
    additionalProperties: false,
    patternProperties: { '^_': true },
  };
  if (!s.required.includes('lastStand')) s.required.push('lastStand');
  wj(f, s);
  for (const id of ['FIXTURE_HERO', 'FIXTURE_VILLAIN']) {
    const ff = `tools/fixtures/virtual/data/fighters/${id}/wounds.json`;
    if (!fs.existsSync(ff)) continue;
    const d = rj(ff);
    if (d.lastStand === undefined) d.lastStand = { windowS: 20 };
    wj(ff, d);
  }
}

// ---------------- self-test cases (additive) ----------------
{
  const f = 'tools/fixtures/cases.json';
  const c = rj(f);
  const hero = 'data/fighters/FIXTURE_HERO/wounds.json';
  const add = [
    { id: 'intro-needs-ticks', schema: 'fight-intro.schema.json', mutate: [{ file: 'data/fight/intro.json', del: ['/ticks'] }], expect: { rule: 'required', pointer: '' } },
    { id: 'intro-fractional-tick', schema: 'fight-intro.schema.json', mutate: [{ file: 'data/fight/intro.json', set: { '/ticks/landA': 36.5 } }], expect: { rule: 'type', pointer: '/ticks/landA' } },
    { id: 'intro-unknown-key', schema: 'fight-intro.schema.json', mutate: [{ file: 'data/fight/intro.json', set: { '/ticks/bow': 200 } }], expect: { rule: 'additionalProperties', pointer: '/ticks/bow' } },
    { id: 'intro-fall-height', schema: 'fight-intro.schema.json', mutate: [{ file: 'data/fight/intro.json', set: { '/fallHeight': 0 } }], expect: { rule: 'exclusiveMinimum', pointer: '/fallHeight' } },
    { id: 'wounds-last-stand-required', schema: 'fighter-wounds.schema.json', mutate: [{ file: hero, del: ['/lastStand'] }], expect: { rule: 'required', pointer: '' } },
    { id: 'wounds-last-stand-negative', schema: 'fighter-wounds.schema.json', mutate: [{ file: hero, set: { '/lastStand/windowS': -1 } }], expect: { rule: 'minimum', pointer: '/lastStand/windowS' } },
    { id: 'wounds-last-stand-off-accepted', schema: 'fighter-wounds.schema.json', mutate: [{ file: hero, set: { '/lastStand/windowS': 0 } }], expect: null },
  ];
  let added = 0;
  for (const k of add) {
    if (!c.cases.some((x) => x.id === k.id)) { c.cases.push(k); added++; }
  }
  wj(f, c);
  console.log(`intro and last stand schema changes applied (${added} new cases)`);
}
