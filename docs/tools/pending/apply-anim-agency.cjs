// Schemas for Animation's two agency data files: data/anim/agency.json (anim.agency/1) and data/anim/target_poles.json (anim.target_poles/1)
// (docs/animation/pose-pipeline.md section 9.22; docs/animation/joint-limits.md).
// NOT run by CI, the validator or the sim. The data is on HEAD already, so the validator only warns "no schema" until this runs. Run once from the
// repo root, after Encounter's slice 4 is committed (the tree's tools files carry its uncommitted edits):
//     node docs/tools/pending/apply-anim-agency.cjs
// It adds tools/schemas/anim-agency.schema.json and anim-target-poles.schema.json, the map entries, the xref rules (agency-pose, agency-seq, poles-pose)
// and the cases. It does NOT edit data/. Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const poseId = { type: 'string', pattern: '^[a-z][a-z0-9_]*([.][a-z0-9_~]+)*$' };
const weight = { type: 'number', minimum: 0, maximum: 1, description: 'The share of the pose mixed in over whatever he is doing.' };
const ease = (d) => ({ type: 'number', minimum: 0, description: d });
const vec3 = { type: 'array', minItems: 3, maxItems: 3, items: { type: 'number' } };
const KB = ['slideShort', 'slideLong', 'drift', 'bump'];

// =============================== agency ===============================
{
  const held = (extra) => obj(Object.assign({ hold: Object.assign({ description: 'The held pose (a pose of poses.json or a wave\'s poses file).' }, poseId), weight, in: ease('Ease-in time (s).'), out: ease('Ease-out time (s).') }, extra));
  wj('tools/schemas/anim-agency.schema.json', {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    $id: 'meridian/anim-agency',
    title: 'anim.agency/1',
    description: 'data/anim/agency.json: the agency slice\'s events as poses (render/anim/anim_fighter.gd, on_agency; docs/animation/pose-pipeline.md section 9.22; wave agency1). knockback: a rival sent back on his feet, by the kind of the sim\'s `knockback` event (slideShort, slideLong, drift, bump): the held pose mixed in for as long as the event says, eased in and out. embed: World\'s `embed` event: a sequence over the held-down ticks. taunt: the cue taunt_start plays a sequence over the flight, cut by the listed kinds. charge: the cues charge_light and charge_heavy hold the flight pose until the exchange starts (a fall or max_ticks ends it), and a feinted charge peels for `ticks`. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every held pose is in a pose file; every sequence is in a wave\'s sequences file) are checked by tools/lib/xref-fight.js (agency-pose, agency-seq).',
    type: 'object',
    required: ['schema', 'knockback', 'embed', 'taunt', 'charge'],
    properties: {
      schema: { const: 'anim.agency/1' },
      knockback: obj(Object.fromEntries(KB.map((k) => [k, held({})])), { description: 'The held pose by knockback kind.' }),
      embed: obj({ seq: Object.assign({ description: 'A sequence of a wave\'s sequences file, played over the held-down ticks.' }, poseId), weight }),
      taunt: obj({ seq: poseId, weight, cut_kinds: { type: 'array', uniqueItems: true, items: { type: 'string', pattern: '^[a-z][a-z0-9_]*$' }, description: 'The cue kinds that cut the shrug short.' } }),
      charge: obj({
        light: held({ max_ticks: { type: 'integer', minimum: 1, description: 'The most ticks the held flight pose lasts.' } }),
        heavy: held({ max_ticks: { type: 'integer', minimum: 1 } }),
        feint: held({ ticks: { type: 'integer', minimum: 1, description: 'The ticks the peel lasts.' } }),
      }),
    },
    additionalProperties: false,
    patternProperties: { '^_': true },
  });

  // =============================== target poles ===============================
  wj('tools/schemas/anim-target-poles.schema.json', {
    $schema: 'https://json-schema.org/draft/2020-12/schema',
    $id: 'meridian/anim-target-poles',
    title: 'anim.target_poles/1',
    description: 'data/anim/target_poles.json: the elbow and knee places that keep a re-aimed target\'s bend as it was (data/anim/targets.json; docs/animation/joint-limits.md): pose id to pole_hand_r, pole_hand_l, pole_foot_r and pole_foot_l, the joint\'s place relative to its root joint, as in a pose sketch ([x, y, z] in model units). Merged over the sketch with targets.json. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-reference: every pose is in a pose file (checked by tools/lib/xref-fight.js, poles-pose).',
    type: 'object',
    required: ['schema', 'poses'],
    properties: {
      schema: { const: 'anim.target_poles/1' },
      poses: {
        type: 'object',
        minProperties: 1,
        propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*([.][a-z0-9_~]+)*)$' },
        additionalProperties: Object.assign({ type: 'object', minProperties: 1, properties: { pole_hand_r: vec3, pole_hand_l: vec3, pole_foot_r: vec3, pole_foot_l: vec3 } }, { additionalProperties: false, patternProperties: { '^_': true } }),
        patternProperties: { '^_': true },
      },
    },
    additionalProperties: false,
    patternProperties: { '^_': true },
  });
}

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  let after = 'data/anim/targets.json';
  for (const [match, schema] of [['data/anim/agency.json', 'anim-agency.schema.json'], ['data/anim/target_poles.json', 'anim-target-poles.schema.json']]) {
    if (!m.rules.some((r) => r.match === match)) {
      const i = m.rules.findIndex((r) => r.match === after);
      m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match, schema });
    }
    after = match;
  }
  wj(f, m);
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'agency-pose'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- anim agency and target poles: poses and sequences exist ----',
      '  {',
      '    const allPoses = new Set();',
      "    const mainA = get('data/anim/poses.json');",
      '    if (isObj(mainA) && isObj(mainA.poses)) for (const k of Object.keys(mainA.poses)) allPoses.add(k);',
      '    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.poses\\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) allPoses.add(k); }',
      '    const allSeqs = new Set();',
      '    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.sequences\\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.sequences)) for (const k of Object.keys(d.sequences)) allSeqs.add(k); }',
      "    const ag = get('data/anim/agency.json');",
      '    if (isObj(ag)) {',
      "      const AG = 'data/anim/agency.json';",
      "      const needPose = (id, pointer) => { if (allPoses.size && typeof id === 'string' && !allPoses.has(id)) err(AG, pointer, 'agency-pose', `pose \"${id}\" is not in poses.json nor a wave's poses file`); };",
      "      const needSeq = (id, pointer) => { if (allSeqs.size && typeof id === 'string' && !allSeqs.has(id)) err(AG, pointer, 'agency-seq', `sequence \"${id}\" is not in a wave's sequences file`); };",
      "      if (isObj(ag.knockback)) for (const [k, v] of Object.entries(ag.knockback)) if (!k.startsWith('_') && isObj(v)) needPose(v.hold, `/knockback/${esc(k)}/hold`);",
      "      if (isObj(ag.charge)) for (const [k, v] of Object.entries(ag.charge)) if (!k.startsWith('_') && isObj(v)) needPose(v.hold, `/charge/${esc(k)}/hold`);",
      "      if (isObj(ag.embed)) needSeq(ag.embed.seq, '/embed/seq');",
      "      if (isObj(ag.taunt)) needSeq(ag.taunt.seq, '/taunt/seq');",
      '    }',
      "    const pl = get('data/anim/target_poles.json');",
      '    if (isObj(pl) && isObj(pl.poses) && allPoses.size) for (const p of Object.keys(pl.poses)) if (!p.startsWith(\'_\') && !allPoses.has(p)) err(\'data/anim/target_poles.json\', `/poses/${esc(p)}`, \'poles-pose\', `pose "${p}" is not in poses.json nor a wave\\\'s poses file`);',
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
  const A = 'data/anim/agency.json';
  const P = 'data/anim/target_poles.json';
  const ag = (n, mut, expect) => ({ id: 'anim-agency-' + n, schema: 'anim-agency.schema.json', mutate: [{ file: A, ...mut }], expect });
  const tp = (n, mut, expect) => ({ id: 'anim-target-poles-' + n, schema: 'anim-target-poles.schema.json', mutate: [{ file: P, ...mut }], expect });
  const add = [
    ag('live-valid', { set: { '/schema': 'anim.agency/1' } }, null),
    ag('key-required', { del: ['/charge'] }, { rule: 'required', pointer: '' }),
    ag('schema-version', { set: { '/schema': 'anim.agency/2' } }, { rule: 'const', pointer: '/schema' }),
    ag('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    ag('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    ag('knockback-kind-missing', { del: ['/knockback/bump'] }, { rule: 'required', pointer: '/knockback' }),
    ag('knockback-kind-unknown', { set: { '/knockback/shove': { hold: 'ag.hold.kb_short', weight: 0.8, in: 0.1, out: 0.1 } } }, { rule: 'additionalProperties', pointer: '/knockback/shove' }),
    ag('knockback-key-required', { del: ['/knockback/drift/out'] }, { rule: 'required', pointer: '/knockback/drift' }),
    ag('knockback-unknown-key', { set: { '/knockback/drift/loop': 1 } }, { rule: 'additionalProperties', pointer: '/knockback/drift/loop' }),
    ag('knockback-weight-range', { set: { '/knockback/drift/weight': 1.5 } }, { rule: 'maximum', pointer: '/knockback/drift/weight' }),
    ag('knockback-weight-negative', { set: { '/knockback/drift/weight': -0.1 } }, { rule: 'minimum', pointer: '/knockback/drift/weight' }),
    ag('knockback-ease-negative', { set: { '/knockback/drift/in': -0.1 } }, { rule: 'minimum', pointer: '/knockback/drift/in' }),
    ag('knockback-ease-zero-ok', { set: { '/knockback/drift/in': 0 } }, null),
    ag('knockback-hold-shape', { set: { '/knockback/drift/hold': 'AG Hold' } }, { rule: 'pattern', pointer: '/knockback/drift/hold' }),
    ag('knockback-hold-not-a-pose', { set: { '/knockback/drift/hold': 'ag.hold.nowhere' } }, { rule: 'xref:agency-pose', pointer: '/knockback/drift/hold' }),
    ag('embed-seq-required', { del: ['/embed/seq'] }, { rule: 'required', pointer: '/embed' }),
    ag('embed-seq-not-a-sequence', { set: { '/embed/seq': 'ag.nowhere' } }, { rule: 'xref:agency-seq', pointer: '/embed/seq' }),
    ag('embed-weight-range', { set: { '/embed/weight': 2 } }, { rule: 'maximum', pointer: '/embed/weight' }),
    ag('taunt-seq-not-a-sequence', { set: { '/taunt/seq': 'ag.nowhere' } }, { rule: 'xref:agency-seq', pointer: '/taunt/seq' }),
    ag('taunt-cut-kinds-duplicate', { set: { '/taunt/cut_kinds': ['taunt_end_cut', 'taunt_end_cut'] } }, { rule: 'uniqueItems', pointer: '/taunt/cut_kinds/1' }),
    ag('taunt-cut-kinds-shape', { set: { '/taunt/cut_kinds': ['Taunt End'] } }, { rule: 'pattern', pointer: '/taunt/cut_kinds/0' }),
    ag('taunt-cut-kinds-empty-ok', { set: { '/taunt/cut_kinds': [] } }, null),
    ag('charge-light-max-ticks-required', { del: ['/charge/light/max_ticks'] }, { rule: 'required', pointer: '/charge/light' }),
    ag('charge-max-ticks-positive', { set: { '/charge/heavy/max_ticks': 0 } }, { rule: 'minimum', pointer: '/charge/heavy/max_ticks' }),
    ag('charge-max-ticks-integer', { set: { '/charge/heavy/max_ticks': 120.5 } }, { rule: 'type', pointer: '/charge/heavy/max_ticks' }),
    ag('charge-feint-ticks-required', { del: ['/charge/feint/ticks'] }, { rule: 'required', pointer: '/charge/feint' }),
    ag('charge-feint-ticks-positive', { set: { '/charge/feint/ticks': 0 } }, { rule: 'minimum', pointer: '/charge/feint/ticks' }),
    ag('charge-kind-unknown', { set: { '/charge/medium': { hold: 'ag.hold.charge_light', weight: 0.8, in: 0.1, out: 0.1, max_ticks: 60 } } }, { rule: 'additionalProperties', pointer: '/charge/medium' }),
    ag('charge-hold-not-a-pose', { set: { '/charge/feint/hold': 'ag.hold.nowhere' } }, { rule: 'xref:agency-pose', pointer: '/charge/feint/hold' }),
    ag('charge-main-pose-ok', { set: { '/charge/light/hold': 'hurt.hold' } }, null),
    tp('live-valid', { set: { '/schema': 'anim.target_poles/1' } }, null),
    tp('key-required', { del: ['/poses'] }, { rule: 'required', pointer: '' }),
    tp('schema-version', { set: { '/schema': 'anim.target_poles/2' } }, { rule: 'const', pointer: '/schema' }),
    tp('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    tp('poses-empty', { set: { '/poses': {} } }, { rule: 'minProperties', pointer: '/poses' }),
    tp('pose-name-shape', { set: { '/poses/Bad Name': { pole_hand_r: [1, 2, 3] } } }, { rule: 'propertyNames', pointer: '/poses/Bad Name' }),
    tp('pose-empty', { set: { '/poses/hurt.hold': {} } }, { rule: 'minProperties', pointer: '/poses/hurt.hold' }),
    tp('pose-unknown-key', { set: { '/poses/hurt.hold': { pole_head: [1, 2, 3] } } }, { rule: 'additionalProperties', pointer: '/poses/hurt.hold/pole_head' }),
    tp('pole-length', { set: { '/poses/hurt.hold': { pole_hand_r: [1, 2] } } }, { rule: 'minItems', pointer: '/poses/hurt.hold/pole_hand_r' }),
    tp('pole-type', { set: { '/poses/hurt.hold': { pole_hand_r: [1, 'a', 3] } } }, { rule: 'type', pointer: '/poses/hurt.hold/pole_hand_r/1' }),
    tp('pole-all-four-ok', { set: { '/poses/hurt.hold': { pole_hand_r: [1, 2, 3], pole_hand_l: [1, 2, -3], pole_foot_r: [1, -2, 3], pole_foot_l: [1, -2, -3] } } }, null),
    tp('pose-not-in-files', { set: { '/poses/hurt.nowhere': { pole_hand_r: [1, 2, 3] } } }, { rule: 'xref:poles-pose', pointer: '/poses/hurt.nowhere' }),
    tp('wave-pose-ok', { set: { '/poses/w1.jab.chamber': { pole_hand_l: [1, 2, 3] } } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`anim agency and target poles schemas applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('agency-pose')) {
    const line = t.split('\n').find((l) => l.includes('`targets-pose`'));
    t = t.replace(line, () => line + '\n| `agency-pose`, `agency-seq`, `poles-pose` | data/anim/agency.json: every held pose is in poses.json or a wave\'s poses file and every sequence is in a wave\'s sequences file; data/anim/target_poles.json: every pose is in a pose file |');
    fs.writeFileSync(f, t);
  }
}
