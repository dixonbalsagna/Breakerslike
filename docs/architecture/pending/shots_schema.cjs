// Shots: Tools' side (a schema for data/fight/shots.json, its map rule, its fixture and cases). Needs the EP's grant:
// these are Tools' files. Run from the repo root. Re-runnable; additive in map.json and cases.json.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
{
  const num = (d, min) => (min === undefined ? { type: 'number', exclusiveMinimum: 0, description: d } : { type: 'number', minimum: min, description: d });
  const s = {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    $id: 'meridian/fight-shots',
    title: 'fight.shots/1 (docs/architecture/shots.md)',
    description: 'data/fight/shots.json: energy blasts in flight (sim/core/shots.gd): the cap on live shots, the arrival bound of a seeking shot, the fighter\'s contact size, and each kind\'s speed (units a tick), radius, trade power, plain damage and flight times. Version field: schema. Policy: closed except keys starting with an underscore; the kinds are an open table of closed records.',
    type: 'object',
    required: ['schema', 'cap', 'arriveTicks', 'chest', 'bodyR', 'kinds'],
    properties: {
      schema: { const: 'fight.shots/1' },
      cap: { type: 'integer', minimum: 1, maximum: 64, description: 'Live shots at once.' },
      arriveTicks: { type: 'integer', minimum: 1, description: 'A seeking shot arrives within this many ticks.' },
      chest: num('A fighter\'s centre above his feet.', 0),
      bodyR: num('A fighter\'s radius for a shot\'s contact.', 0),
      kinds: {
        type: 'object',
        minProperties: 1,
        description: 'The kinds of shot, by name.',
        additionalProperties: {
          type: 'object',
          required: ['speed', 'r', 'power', 'dmg', 'lifeTicks'],
          properties: {
            speed: num('Units a tick (a minimum for a seeking shot).'),
            r: num('Its radius, for contact and trades.', 0),
            power: num('What it trades with.'),
            dmg: num('What a plain hit does (a placeholder until the director\'s blasts set their own).', 0),
            lifeTicks: { type: 'integer', minimum: 1, description: 'How long a straight shot flies.' },
            lobTicks: { type: 'integer', minimum: 1, description: 'A lobbed shot\'s flight time.' },
            lobArc: num('A lobbed shot\'s height above the straight line.', 0),
          },
          additionalProperties: false,
          patternProperties: { '^_': true },
        },
      },
    },
    additionalProperties: false,
    patternProperties: { '^_': true },
  };
  wj('tools/schemas/fight-shots.schema.json', s);
  wj('tools/fixtures/virtual/data/fight/shots.json', {
    _about: 'Validator fixture, not game data.',
    schema: 'fight.shots/1',
    cap: 32, arriveTicks: 45, chest: 40, bodyR: 40,
    kinds: { bolt: { speed: 60, r: 14, power: 1, dmg: 6, lifeTicks: 120 }, lob: { speed: 40, r: 24, power: 2, dmg: 20, lifeTicks: 36, lobTicks: 36, lobArc: 300 } },
  });
  const mf = 'tools/schemas/map.json';
  const m = rj(mf);
  if (!m.rules.some((r) => r.match === 'data/fight/shots.json')) {
    const at = m.rules.findIndex((r) => r.match === 'data/fight/intro.json');
    m.rules.splice(at + 1, 0, { match: 'data/fight/shots.json', schema: 'fight-shots.schema.json' });
    wj(mf, m);
  }
}
{
  const f = 'tools/fixtures/cases.json';
  const c = rj(f);
  const file = 'data/fight/shots.json';
  const add = [
    { id: 'shots-needs-kinds', schema: 'fight-shots.schema.json', mutate: [{ file, del: ['/kinds'] }], expect: { rule: 'required', pointer: '' } },
    { id: 'shots-cap-fraction', schema: 'fight-shots.schema.json', mutate: [{ file, set: { '/cap': 32.5 } }], expect: { rule: 'type', pointer: '/cap' } },
    { id: 'shots-speed-zero', schema: 'fight-shots.schema.json', mutate: [{ file, set: { '/kinds/bolt/speed': 0 } }], expect: { rule: 'exclusiveMinimum', pointer: '/kinds/bolt/speed' } },
    { id: 'shots-kind-unknown-key', schema: 'fight-shots.schema.json', mutate: [{ file, set: { '/kinds/bolt/homing': 1 } }], expect: { rule: 'additionalProperties', pointer: '/kinds/bolt/homing' } },
    { id: 'shots-kind-needs-power', schema: 'fight-shots.schema.json', mutate: [{ file, del: ['/kinds/bolt/power'] }], expect: { rule: 'required', pointer: '/kinds/bolt' } },
  ];
  let added = 0;
  for (const k of add) {
    if (!c.cases.some((x) => x.id === k.id)) { c.cases.push(k); added++; }
  }
  wj(f, c);
  console.log(`shots schema changes applied (${added} new cases)`);
}
