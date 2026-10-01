// Schema for Encounter's landing-mix data (docs/director/landing-mix.md; the draft is docs/director/pending/launch.json).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the same commit that copies the draft to data/director/launch.json:
//     node docs/tools/pending/apply-launch.cjs
// It adds tools/schemas/director-launch.schema.json, the map entry, the xref rules (launch-order, launch-direction), a validator fixture
// (tools/fixtures/virtual/data/director/launch.json, copied from the live file if it is there and from the parked draft if not) and the cases.
// It does NOT copy the data into data/; Encounter does. Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const group = (props, description) => Object.assign({ type: 'object', description, required: Object.keys(props), properties: props }, closed);
const deg = { type: 'number', minimum: 0, maximum: 90 };
const bh = { type: 'number', minimum: 0 };

// =============================== schema ===============================
wj('tools/schemas/director-launch.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/director-launch',
  title: 'director.launch/1',
  description: 'data/director/launch.json: the launch planner\'s landing-mix numbers (sim/director/launch.gd; docs/director/landing-mix.md). SLAM DOWN is a drive (down and forward, at an angle set by the target\'s height); the straight-down slam is its own gated candidate, CRATER SLAM. Heights are in body heights (_bh, 1 bh is 75 units) unless a key says units. Version field: schema. Policy: every key required, objects closed except keys starting with an underscore. Orders (lowDeg at most highDeg, lowBh below highBh) and the downward direction of CRATER SLAM are checked by tools/lib/xref-fight.js (launch-order, launch-direction).',
  type: 'object',
  required: ['schema', 'drive', 'craterSlam'],
  properties: {
    schema: { const: 'director.launch/1' },
    drive: group({ lowDeg: deg, highDeg: deg, lowBh: bh, highBh: bh }, 'The SLAM DOWN drive: the angle below level is lowDeg at lowBh or lower, rising evenly to highDeg at highBh and above.'),
    craterSlam: group({
      ux: Object.assign({ description: 'Along the launcher\'s facing; 0 or more.' }, { type: 'number', minimum: 0 }),
      uy: { type: 'number', description: 'Up; negative is down.' },
      below: group({ sideBh: bh, dropBh: bh }, 'Gate 1, a rival directly below: the target is within sideBh sideways of the launcher and at least dropBh lower.'),
      setPiece: group({
        minTier: { type: 'integer', minimum: 1, maximum: 4 },
        everySec: { type: 'number', minimum: 0 },
      }, 'Gate 2, the crater set piece: the launcher is at minTier or above, and throws at most one CRATER SLAM in everySec seconds of match time.'),
      score: group({
        base: { type: 'number' },
        perTier: { type: 'number' },
        high: { type: 'number' },
        highAlt: { type: 'number', minimum: 0, description: 'The target\'s height above the ground in units (not body heights).' },
      }, 'Planner score points: base + perTier x tier, + high when the target is over highAlt up.'),
    }, 'The gated CRATER SLAM candidate: the old straight-down vector (ux, uy) and the two gates that offer it.'),
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/director/launch.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/director/ai.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/director/launch.json', schema: 'director-launch.schema.json' });
    wj(f, m);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'launch-order'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- director launch: the drive angle and height orders, CRATER SLAM goes down ----',
      "  const launch = get('data/director/launch.json');",
      '  if (isObj(launch)) {',
      "    const LF = 'data/director/launch.json';",
      '    const d = launch.drive;',
      "    if (isObj(d) && typeof d.lowDeg === 'number' && typeof d.highDeg === 'number' && d.lowDeg > d.highDeg) err(LF, '/drive/lowDeg', 'launch-order', `lowDeg ${d.lowDeg} is above highDeg ${d.highDeg}`);",
      "    if (isObj(d) && typeof d.lowBh === 'number' && typeof d.highBh === 'number' && d.lowBh >= d.highBh) err(LF, '/drive/lowBh', 'launch-order', `lowBh ${d.lowBh} is not below highBh ${d.highBh}, so the angle has no range to rise over`);",
      "    const cs = launch.craterSlam;",
      "    if (isObj(cs) && typeof cs.uy === 'number' && cs.uy >= 0) err(LF, '/craterSlam/uy', 'launch-direction', `uy ${cs.uy} is not downward (negative is down), so CRATER SLAM would not slam`, 'warning');",
      '  }',
      '',
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== fixture ===============================
{
  const dst = 'tools/fixtures/virtual/data/director/launch.json';
  const src = fs.existsSync('data/director/launch.json') ? 'data/director/launch.json' : 'docs/director/pending/launch.json';
  const o = rj(src);
  o._about = 'Validator fixture, not game data: the shape docs/director/landing-mix.md describes, with the numbers of Encounter\'s draft.';
  if (!fs.existsSync(dst)) wj(dst, Object.assign({ _about: o._about }, Object.fromEntries(Object.entries(o).filter(([k]) => k !== '_about'))));
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const L = 'data/director/launch.json';
  const k = (n, mut, expect) => ({ id: 'director-launch-' + n, schema: 'director-launch.schema.json', mutate: [{ file: L, ...mut }], expect });
  const add = [
    k('valid', { set: { '/drive/lowDeg': 25 } }, null),
    k('key-required', { del: ['/craterSlam'] }, { rule: 'required', pointer: '' }),
    k('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    k('underscore-key-ok', { set: { '/drive/_why': 'comment' } }, null),
    k('schema-version', { set: { '/schema': 'director.launch/2' } }, { rule: 'const', pointer: '/schema' }),
    k('drive-key-required', { del: ['/drive/highBh'] }, { rule: 'required', pointer: '/drive' }),
    k('drive-degrees-range', { set: { '/drive/highDeg': 120 } }, { rule: 'maximum', pointer: '/drive/highDeg' }),
    k('drive-degrees-negative', { set: { '/drive/lowDeg': -5 } }, { rule: 'minimum', pointer: '/drive/lowDeg' }),
    k('drive-degrees-order', { set: { '/drive/lowDeg': 60 } }, { rule: 'xref:launch-order', pointer: '/drive/lowDeg' }),
    k('drive-degrees-equal-ok', { set: { '/drive/lowDeg': 50 } }, null),
    k('drive-height-order', { set: { '/drive/lowBh': 12 } }, { rule: 'xref:launch-order', pointer: '/drive/lowBh' }),
    k('drive-height-negative', { set: { '/drive/lowBh': -1 } }, { rule: 'minimum', pointer: '/drive/lowBh' }),
    k('crater-key-required', { del: ['/craterSlam/uy'] }, { rule: 'required', pointer: '/craterSlam' }),
    k('crater-unknown-key', { set: { '/craterSlam/gate': 1 } }, { rule: 'additionalProperties', pointer: '/craterSlam/gate' }),
    k('crater-ux-negative', { set: { '/craterSlam/ux': -0.2 } }, { rule: 'minimum', pointer: '/craterSlam/ux' }),
    k('crater-uy-up-warns', { set: { '/craterSlam/uy': 1.25 } }, { rule: 'xref:launch-direction', pointer: '/craterSlam/uy' }),
    k('crater-uy-type', { set: { '/craterSlam/uy': 'down' } }, { rule: 'type', pointer: '/craterSlam/uy' }),
    k('below-negative', { set: { '/craterSlam/below/dropBh': -3 } }, { rule: 'minimum', pointer: '/craterSlam/below/dropBh' }),
    k('below-key-required', { del: ['/craterSlam/below/sideBh'] }, { rule: 'required', pointer: '/craterSlam/below' }),
    k('tier-range', { set: { '/craterSlam/setPiece/minTier': 5 } }, { rule: 'maximum', pointer: '/craterSlam/setPiece/minTier' }),
    k('tier-integer', { set: { '/craterSlam/setPiece/minTier': 2.5 } }, { rule: 'type', pointer: '/craterSlam/setPiece/minTier' }),
    k('tier-zero', { set: { '/craterSlam/setPiece/minTier': 0 } }, { rule: 'minimum', pointer: '/craterSlam/setPiece/minTier' }),
    k('every-sec-negative', { set: { '/craterSlam/setPiece/everySec': -1 } }, { rule: 'minimum', pointer: '/craterSlam/setPiece/everySec' }),
    k('every-sec-zero-ok', { set: { '/craterSlam/setPiece/everySec': 0 } }, null),
    k('score-key-required', { del: ['/craterSlam/score/highAlt'] }, { rule: 'required', pointer: '/craterSlam/score' }),
    k('score-alt-negative', { set: { '/craterSlam/score/highAlt': -10 } }, { rule: 'minimum', pointer: '/craterSlam/score/highAlt' }),
    k('score-type', { set: { '/craterSlam/score/base': '12' } }, { rule: 'type', pointer: '/craterSlam/score/base' }),
  ];
  let n = 0;
  for (const x of add) if (!c.cases.some((y) => y.id === x.id)) { c.cases.push(x); n++; }
  wj(cf, c);
  console.log(`director-launch schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('launch-order')) {
    const line = t.split('\n').find((l) => l.includes('`strike-lead`'));
    t = t.replace(line, () => line + '\n| `launch-order`, `launch-direction` | data/director/launch.json: the drive\'s lowDeg is at most highDeg and lowBh is below highBh; CRATER SLAM\'s uy is negative (a warning if not) |');
    fs.writeFileSync(f, t);
  }
}
