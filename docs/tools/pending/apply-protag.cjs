// Schemas for Animation's Protagonist wave: data/anim/fighters.json (anim.fighters/1; docs/animation/pose-pipeline.md section 9.25) and the wave name
// `protag1` in the wave schemas (docs/animation/handoff/protag1-schema.md; Animation's draft: docs/animation/handoff/anim-fighters.schema.json).
// NOT run by CI, the validator or the sim. The data files (data/anim/fighters.json and data/anim/waves/protag1.*.json) are in the tree, so the validator
// rejects them until this runs. Run once from the repo root, after Simulation's shots commit (it edits cases.json, map.json and fight-shots.schema.json):
//     node docs/tools/pending/apply-protag.cjs
// It adds tools/schemas/anim-fighters.schema.json, the map entry (after the flight rule, or after the agency rule if flight has none), widens the wave-name
// pattern "^wave[0-9]+$" to "^(wave|protag)[0-9]+$" in the four wave schemas that carry it (keysets, manifest, entries, entrymap), adds the xref rules
// (fighters-shape, fighters-wave, fighters-timing) and the cases. It does NOT edit data/. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const HANDS = ['open', 'fist', 'relaxed', 'claw'];

// =============================== the wave-name pattern ===============================
for (const f of ['anim-wave-keysets', 'anim-wave-manifest', 'anim-wave-entries', 'anim-wave-entrymap']) {
  const file = `tools/schemas/${f}.schema.json`;
  const t = fs.readFileSync(file, 'utf8');
  if (t.includes('"^wave[0-9]+$"')) fs.writeFileSync(file, t.split('"^wave[0-9]+$"').join('"^(wave|protag)[0-9]+$"'));
}

// =============================== fighters schema ===============================
wj('tools/schemas/anim-fighters.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/anim-fighters',
  title: 'anim.fighters/1',
  description: 'data/anim/fighters.json: each fighter\'s animation profile (docs/animation/pose-pipeline.md section 9.25). shape: the key into shapes.json, ragdoll_motion.json and joints.json. pose_profile: the numbers wave_gen.mjs applies to the rival\'s wave 1 for the strike slots that keep his poses (read at generation, never at runtime). wave: the pose wave that carries the fighter\'s own strikes. timing and arc: parked, not read yet. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every shape is in ragdoll_motion.json shapes; the wave has a keysets file in data/anim/waves; timing names profiles of profiles.json) are checked by tools/lib/xref-fight.js (fighters-*). Animation\'s draft: docs/animation/handoff/anim-fighters.schema.json.',
  type: 'object',
  required: ['schema', 'fighters'],
  properties: {
    schema: { const: 'anim.fighters/1' },
    fighters: {
      type: 'object',
      minProperties: 1,
      propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
      additionalProperties: obj({
        replaces: { type: 'string', pattern: '^[A-Z][A-Z0-9_]*$', description: 'The placeholder fighter this one replaces (a roster id).' },
        shape: { type: 'string', pattern: '^[A-Z]$', description: 'The shape key into shapes.json, ragdoll_motion.json and joints.json.' },
        wave: { type: 'string', pattern: '^[a-z]+[0-9]+$', description: 'The pose wave that carries the fighter\'s own strikes (data/anim/waves/<wave>.*.json).' },
        pose_profile: obj({
          hand_states: { type: 'object', propertyNames: { enum: HANDS }, additionalProperties: { enum: HANDS }, description: 'A hand state replaced by another (his hands are never claws).' },
          rise: { type: 'number', minimum: 0, description: 'Units the hips are lifted out of a crouch of 8 or more (never above standing).' },
          stance: { type: 'number', exclusiveMinimum: 0, description: 'Scale of how far the front foot is planted (1.0 is off).' },
          twist: { type: 'number', exclusiveMinimum: 0, description: 'Gain on the spine\'s turn (rounder arcs).' },
          guard_raise: { type: 'number', minimum: 0, description: 'Units the free hand is lifted (kicks: both hands).' },
          head_pitch: { type: 'number', description: 'Degrees added to the head\'s pitch (chin up, eyes on the rival).' },
        }, { description: 'The numbers that turn the rival\'s wave 1 into this fighter\'s own for the reuse slots.' }),
        timing: obj({
          light: { type: 'string', pattern: '^[a-z][a-z0-9_]*$', description: 'A profile of profiles.json for light blows.' },
          heavy: { type: 'string', pattern: '^[a-z][a-z0-9_]*$', description: 'A profile of profiles.json for heavy blows.' },
          fluid_bias: { type: 'number', minimum: 0, maximum: 1 },
        }, { required: [], description: 'Parked: how the fighter\'s blows are timed.' }),
        arc: obj({ bias: { type: 'number', minimum: 0, maximum: 1 } }, { required: [], description: 'Parked: how wide his arcs run.' }),
      }, { required: ['shape', 'wave', 'pose_profile'] }),
      patternProperties: { '^_': true },
    },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/anim/fighters.json')) {
    let i = m.rules.findIndex((r) => r.match === 'data/anim/flight.json');
    if (i < 0) i = m.rules.findIndex((r) => r.match === 'data/anim/agency.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/anim/fighters.json', schema: 'anim-fighters.schema.json' });
    wj(f, m);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'fighters-shape'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- anim fighters: the shape, the wave and the timing profiles exist ----',
      "  const afs = get('data/anim/fighters.json');",
      '  if (isObj(afs) && isObj(afs.fighters)) {',
      "    const AF = 'data/anim/fighters.json';",
      "    const motF = get('data/anim/ragdoll_motion.json');",
      "    const prF = get('data/anim/profiles.json');",
      "    const shapesF = isObj(motF) && isObj(motF.shapes) ? Object.keys(motF.shapes).filter((k) => !k.startsWith('_')) : [];",
      "    const profsF = isObj(prF) && isObj(prF.profiles) ? Object.keys(prF.profiles) : [];",
      '    for (const [id, fd] of Object.entries(afs.fighters)) {',
      "      if (id.startsWith('_') || !isObj(fd)) continue;",
      '      const at = `/fighters/${esc(id)}`;',
      "      if (typeof fd.shape === 'string' && shapesF.length && !shapesF.includes(fd.shape)) err(AF, `${at}/shape`, 'fighters-shape', `shape \"${fd.shape}\" is not in ragdoll_motion.json shapes (${shapesF.join(', ')})`);",
      "      if (typeof fd.wave === 'string' && !get(`data/anim/waves/${fd.wave}.keysets.json`)) err(AF, `${at}/wave`, 'fighters-wave', `wave \"${fd.wave}\" has no data/anim/waves/${fd.wave}.keysets.json`);",
      "      if (isObj(fd.timing)) for (const k of ['light', 'heavy']) if (typeof fd.timing[k] === 'string' && profsF.length && !profsF.includes(fd.timing[k])) err(AF, `${at}/timing/${k}`, 'fighters-timing', `timing ${k} \"${fd.timing[k]}\" is not a profile of profiles.json (${profsF.join(', ')})`);",
      '    }',
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
  const F = 'data/anim/fighters.json';
  const fx = (n, mut, expect) => ({ id: 'anim-fighters-' + n, schema: 'anim-fighters.schema.json', mutate: [{ file: F, ...mut }], expect });
  const profile = (over) => Object.assign({ hand_states: { claw: 'open' }, rise: 3, stance: 1, twist: 1.15, guard_raise: 3, head_pitch: -3 }, over);
  const one = (over, del) => ({ set: { '/fighters/test': (() => { const o = Object.assign({ shape: 'P', wave: 'protag1', pose_profile: profile() }, over); for (const k of del || []) delete o[k]; return o; })() } });
  const wv = (n, mut, expect, schema, file) => ({ id: n, schema, mutate: [{ file, ...mut }], expect });
  const add = [
    fx('live-valid', { set: { '/schema': 'anim.fighters/1' } }, null),
    fx('key-required', { del: ['/fighters'] }, { rule: 'required', pointer: '' }),
    fx('schema-version', { set: { '/schema': 'anim.fighters/2' } }, { rule: 'const', pointer: '/schema' }),
    fx('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    fx('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    fx('fighters-empty', { set: { '/fighters': {} } }, { rule: 'minProperties', pointer: '/fighters' }),
    fx('fighter-name-shape', { set: { '/fighters/Bad Name': { shape: 'P', wave: 'protag1', pose_profile: profile() } } }, { rule: 'propertyNames', pointer: '/fighters/Bad Name' }),
    fx('fighter-valid', one({}), null),
    fx('fighter-key-required', one({}, ['wave']), { rule: 'required', pointer: '/fighters/test' }),
    fx('fighter-unknown-key', one({ colour: 'red' }), { rule: 'additionalProperties', pointer: '/fighters/test/colour' }),
    fx('replaces-shape', one({ replaces: 'kai' }), { rule: 'pattern', pointer: '/fighters/test/replaces' }),
    fx('replaces-ok', one({ replaces: 'VORR' }), null),
    fx('shape-shape', one({ shape: 'PP' }), { rule: 'pattern', pointer: '/fighters/test/shape' }),
    fx('shape-not-in-motion', one({ shape: 'Z' }), { rule: 'xref:fighters-shape', pointer: '/fighters/test/shape' }),
    fx('wave-shape', one({ wave: 'Protag 1' }), { rule: 'pattern', pointer: '/fighters/test/wave' }),
    fx('wave-without-files', one({ wave: 'protag9' }), { rule: 'xref:fighters-wave', pointer: '/fighters/test/wave' }),
    fx('profile-key-required', one({ pose_profile: (() => { const p = profile(); delete p.twist; return p; })() }), { rule: 'required', pointer: '/fighters/test/pose_profile' }),
    fx('profile-unknown-key', one({ pose_profile: profile({ lean: 2 }) }), { rule: 'additionalProperties', pointer: '/fighters/test/pose_profile/lean' }),
    fx('hand-state-enum', one({ pose_profile: profile({ hand_states: { claw: 'talon' } }) }), { rule: 'enum', pointer: '/fighters/test/pose_profile/hand_states/claw' }),
    fx('hand-state-name', one({ pose_profile: profile({ hand_states: { talon: 'open' } }) }), { rule: 'propertyNames', pointer: '/fighters/test/pose_profile/hand_states/talon' }),
    fx('hand-states-empty-ok', one({ pose_profile: profile({ hand_states: {} }) }), null),
    fx('rise-negative', one({ pose_profile: profile({ rise: -1 }) }), { rule: 'minimum', pointer: '/fighters/test/pose_profile/rise' }),
    fx('stance-positive', one({ pose_profile: profile({ stance: 0 }) }), { rule: 'exclusiveMinimum', pointer: '/fighters/test/pose_profile/stance' }),
    fx('twist-positive', one({ pose_profile: profile({ twist: 0 }) }), { rule: 'exclusiveMinimum', pointer: '/fighters/test/pose_profile/twist' }),
    fx('guard-raise-negative', one({ pose_profile: profile({ guard_raise: -2 }) }), { rule: 'minimum', pointer: '/fighters/test/pose_profile/guard_raise' }),
    fx('head-pitch-type', one({ pose_profile: profile({ head_pitch: 'up' }) }), { rule: 'type', pointer: '/fighters/test/pose_profile/head_pitch' }),
    fx('head-pitch-negative-ok', one({ pose_profile: profile({ head_pitch: -10 }) }), null),
    fx('timing-valid', one({ timing: { light: 'snappy', heavy: 'fluid', fluid_bias: 0.15 } }), null),
    fx('timing-profile-unknown', one({ timing: { light: 'jerky' } }), { rule: 'xref:fighters-timing', pointer: '/fighters/test/timing/light' }),
    fx('timing-heavy-unknown', one({ timing: { heavy: 'jerky' } }), { rule: 'xref:fighters-timing', pointer: '/fighters/test/timing/heavy' }),
    fx('timing-bias-range', one({ timing: { fluid_bias: 1.5 } }), { rule: 'maximum', pointer: '/fighters/test/timing/fluid_bias' }),
    fx('timing-unknown-key', one({ timing: { slow: 1 } }), { rule: 'additionalProperties', pointer: '/fighters/test/timing/slow' }),
    fx('arc-bias-range', one({ arc: { bias: -0.1 } }), { rule: 'minimum', pointer: '/fighters/test/arc/bias' }),
    fx('arc-ok', one({ arc: { bias: 0.25 } }), null),
    // the wave name: a fighter's wave is accepted (the live protag1 files carry it)
    wv('anim-wave-keysets-fighter-wave-ok', { set: { '/keysets/w1.jab/_wave': 'protag1' } }, null, 'anim-wave-keysets.schema.json', 'data/anim/waves/wave1.keysets.json'),
    wv('anim-wave-keysets-wave-name-shape', { set: { '/keysets/w1.jab/_wave': 'Protag 1' } }, { rule: 'pattern', pointer: '/keysets/w1.jab/_wave' }, 'anim-wave-keysets.schema.json', 'data/anim/waves/wave1.keysets.json'),
    wv('anim-wave-manifest-fighter-wave-ok', { set: { '/wave': 'protag1' } }, { rule: 'xref:wave-manifest', pointer: '/wave' }, 'anim-wave-manifest.schema.json', 'data/anim/waves/wave1.manifest.json'),
    wv('anim-wave-manifest-wave-name-shape', { set: { '/wave': 'fighter1' } }, { rule: 'pattern', pointer: '/wave' }, 'anim-wave-manifest.schema.json', 'data/anim/waves/wave1.manifest.json'),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`protag schemas applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('fighters-shape')) {
    const line = t.split('\n').find((l) => l.includes('`flight-order`')) || t.split('\n').find((l) => l.includes('`agency-pose`'));
    t = t.replace(line, () => line + '\n| `fighters-shape`, `fighters-wave`, `fighters-timing` | data/anim/fighters.json: each fighter\'s shape is in ragdoll_motion.json shapes; its wave has a keysets file in data/anim/waves; timing light and heavy are profiles of profiles.json. A wave name is `wave` or `protag` and a number |');
    fs.writeFileSync(f, t);
  }
}
