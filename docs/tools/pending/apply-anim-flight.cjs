// Schema for Animation's flight lead, data/anim/flight.json (anim.flight/1; docs/animation/pose-pipeline.md section 9.23, GB-006).
// Animation's draft: docs/animation/handoff/anim-flight.schema.json (adopted here in the house style, with ranges and an order rule).
// NOT run by CI, the validator or the sim. The data is on HEAD already, so the validator only warns "no schema" until this runs. Run once from the
// repo root, after Encounter's slice 7 is committed (the tree's tools files carry its edits):
//     node docs/tools/pending/apply-anim-flight.cjs
// It adds tools/schemas/anim-flight.schema.json, the map entry (after the agency rule), the xref rule (flight-order) and the cases. It does NOT edit data/.
// Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const pairOf = (item, description) => ({ type: 'array', minItems: 2, maxItems: 2, items: item, description });
const nn = { type: 'number', minimum: 0 };
const sine = { type: 'number', minimum: 0, maximum: 1 };
const pos = { type: 'number', exclusiveMinimum: 0 };

wj('tools/schemas/anim-flight.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/anim-flight',
  title: 'anim.flight/1',
  description: 'data/anim/flight.json: the flight lead (render/anim/anim_fighter.gd, _lead_layer; docs/animation/pose-pipeline.md section 9.23, GB-006): a launched body that has stopped tumbling flies head first along its velocity; a fighter carried fast with his head against the way he goes is stood up to a tilt cap. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Each (from, to) pair rises (checked by tools/lib/xref-fight.js, flight-order). Animation\'s draft: docs/animation/handoff/anim-flight.schema.json.',
  type: 'object',
  required: ['schema', 'speed', 'spin', 'steep', 'rate', 'skid_rate', 'tilt', 'tilt_rate', 'lay', 'pivot_y'],
  properties: {
    schema: { const: 'anim.flight/1' },
    speed: pairOf(nn, 'Units a second over which the lead comes in (from, to).'),
    spin: pairOf(nn, 'The |spin| in rad/s under which the lead comes in (from, to): a tumble spinning faster than `to` is left to tumble.'),
    steep: pairOf(nn, 'A steep fall (down over across, from, to) is not chased: a landing is upright.'),
    rate: Object.assign({ description: '1/s: how fast the turn chases its aim or lets go.' }, pos),
    skid_rate: Object.assign({ description: '1/s: the same, landing into a skid.' }, pos),
    tilt: { type: 'number', minimum: 0, maximum: 90, description: 'Degrees: the most a fighter carried fast against his head\'s way is left tilted.' },
    tilt_rate: Object.assign({ description: '1/s: the same for the knockback tilt.' }, pos),
    lay: pairOf(sine, 'The sine of the spine\'s tilt from upright (from, to) over which a pose that lays the body out is flown head first, even in a skid.'),
    pivot_y: { type: 'number', description: 'The body\'s middle in model space (the view\'s PIVOT_Y).' },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// ---- map (after the agency rule, as Animation asks) ----
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/anim/flight.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/anim/agency.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/anim/flight.json', schema: 'anim-flight.schema.json' });
    wj(f, m);
  }
}

// ---- xref ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'flight-order'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- anim flight: each (from, to) pair rises ----',
      "  const fl = get('data/anim/flight.json');",
      '  if (isObj(fl)) for (const k of [\'speed\', \'spin\', \'steep\', \'lay\']) {',
      "    const p = fl[k];",
      "    if (Array.isArray(p) && p.length === 2 && typeof p[0] === 'number' && typeof p[1] === 'number' && p[0] >= p[1]) err('data/anim/flight.json', `/${k}/0`, 'flight-order', `${k} runs from ${p[0]} to ${p[1]}; the lead needs a range that rises`);",
      '  }',
      '',
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- cases ----
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const F = 'data/anim/flight.json';
  const x = (n, mut, expect) => ({ id: 'anim-flight-' + n, schema: 'anim-flight.schema.json', mutate: [{ file: F, ...mut }], expect });
  const add = [
    x('live-valid', { set: { '/schema': 'anim.flight/1' } }, null),
    x('key-required', { del: ['/pivot_y'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'anim.flight/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('speed-length', { set: { '/speed': [300] } }, { rule: 'minItems', pointer: '/speed' }),
    x('speed-too-long', { set: { '/speed': [300, 700, 900] } }, { rule: 'maxItems', pointer: '/speed' }),
    x('speed-negative', { set: { '/speed': [-1, 700] } }, { rule: 'minimum', pointer: '/speed/0' }),
    x('speed-type', { set: { '/speed': [300, 'fast'] } }, { rule: 'type', pointer: '/speed/1' }),
    x('speed-order', { set: { '/speed': [700, 300] } }, { rule: 'xref:flight-order', pointer: '/speed/0' }),
    x('speed-equal', { set: { '/speed': [500, 500] } }, { rule: 'xref:flight-order', pointer: '/speed/0' }),
    x('spin-order', { set: { '/spin': [4.5, 3] } }, { rule: 'xref:flight-order', pointer: '/spin/0' }),
    x('spin-negative', { set: { '/spin': [-1, 4.5] } }, { rule: 'minimum', pointer: '/spin/0' }),
    x('steep-order', { set: { '/steep': [1.3, 0.7] } }, { rule: 'xref:flight-order', pointer: '/steep/0' }),
    x('steep-length', { set: { '/steep': [0.7] } }, { rule: 'minItems', pointer: '/steep' }),
    x('lay-order', { set: { '/lay': [0.95, 0.7] } }, { rule: 'xref:flight-order', pointer: '/lay/0' }),
    x('lay-range', { set: { '/lay': [0.7, 1.5] } }, { rule: 'maximum', pointer: '/lay/1' }),
    x('lay-negative', { set: { '/lay': [-0.1, 0.9] } }, { rule: 'minimum', pointer: '/lay/0' }),
    x('lay-edges-ok', { set: { '/lay': [0, 1] } }, null),
    x('rate-positive', { set: { '/rate': 0 } }, { rule: 'exclusiveMinimum', pointer: '/rate' }),
    x('skid-rate-positive', { set: { '/skid_rate': -1 } }, { rule: 'exclusiveMinimum', pointer: '/skid_rate' }),
    x('tilt-range', { set: { '/tilt': 120 } }, { rule: 'maximum', pointer: '/tilt' }),
    x('tilt-negative', { set: { '/tilt': -5 } }, { rule: 'minimum', pointer: '/tilt' }),
    x('tilt-zero-ok', { set: { '/tilt': 0 } }, null),
    x('tilt-rate-positive', { set: { '/tilt_rate': 0 } }, { rule: 'exclusiveMinimum', pointer: '/tilt_rate' }),
    x('pivot-type', { set: { '/pivot_y': 'middle' } }, { rule: 'type', pointer: '/pivot_y' }),
    x('pivot-negative-ok', { set: { '/pivot_y': -2 } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`flight schema applied (${n} new cases)`);
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('flight-order')) {
    const line = t.split('\n').find((l) => l.includes('`agency-pose`'));
    t = t.replace(line, () => line + '\n| `flight-order` | data/anim/flight.json: each (from, to) pair (speed, spin, steep, lay) rises |');
    fs.writeFileSync(f, t);
  }
}
