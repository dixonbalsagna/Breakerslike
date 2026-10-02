// Schema for Animation's re-aimed hand and foot targets, data/anim/targets.json (anim.targets/1; docs/animation/joint-limits.md).
// NOT run by CI, the validator or the sim. The data is on HEAD already, so the validator only warns "no schema" until this runs. Run once from the
// repo root, after Encounter's slice 3 is committed (the tree's tools files carry its uncommitted edits):
//     node docs/tools/pending/apply-targets.cjs
// It adds tools/schemas/anim-targets.schema.json, the map entry, the xref rules (targets-pose, targets-limb) and the cases. It does NOT edit data/.
// Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const vec3 = { type: 'array', minItems: 3, maxItems: 3, items: { type: 'number' } };

wj('tools/schemas/anim-targets.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/anim-targets',
  title: 'anim.targets/1',
  description: 'data/anim/targets.json: hand and foot targets re-aimed after the joint limits (docs/animation/joint-limits.md): pose id to the targets that replace the authored ones in that pose\'s sketch (render/anim/anim_data.gd, _fixed). A target is [x, y, z] in model units, as in a pose sketch. The limb that lands a blow is never changed here. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every pose is in data/anim/poses.json or a wave\'s poses file; a strike\'s contact pose does not retarget the limb that lands the blow) are checked by tools/lib/xref-fight.js (targets-pose, targets-limb).',
  type: 'object',
  required: ['schema', 'poses'],
  properties: {
    schema: { const: 'anim.targets/1' },
    poses: {
      type: 'object',
      minProperties: 1,
      propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*([.][a-z0-9_~]+)*)$' },
      additionalProperties: Object.assign({
        type: 'object',
        minProperties: 1,
        description: 'The targets that replace the authored ones in this pose.',
        properties: { hand_r: vec3, hand_l: vec3, foot_r: vec3, foot_l: vec3 },
      }, { additionalProperties: false, patternProperties: { '^_': true } }),
      patternProperties: { '^_': true },
    },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// ---- map ----
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/anim/targets.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/anim/joints.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/anim/targets.json', schema: 'anim-targets.schema.json' });
    wj(f, m);
  }
}

// ---- xref ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'targets-pose'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- anim targets: poses exist; a blow\'s limb is not retargeted in its contact pose ----',
      "  const tg = get('data/anim/targets.json');",
      '  if (isObj(tg) && isObj(tg.poses)) {',
      "    const TG = 'data/anim/targets.json';",
      "    const mainP = get('data/anim/poses.json');",
      '    const known = new Set(isObj(mainP) && isObj(mainP.poses) ? Object.keys(mainP.poses) : []);',
      '    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.poses\\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) known.add(k); }',
      '    const keysetDocs = [get(\'data/anim/keysets.json\')];',
      '    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.keysets\\.json$/)) keysetDocs.push(get(rel));',
      '    const contactLimbs = new Map();',
      '    for (const kd of keysetDocs) if (isObj(kd) && isObj(kd.keysets)) for (const [name, k] of Object.entries(kd.keysets)) {',
      "      if (name.startsWith('_') || !isObj(k) || !Array.isArray(k.keys)) continue;",
      "      const c = k.keys.find((x) => isObj(x) && x.role === 'contact');",
      '      if (!c || typeof c.pose !== \'string\') continue;',
      "      for (const l of [k.limb, k.limb2]) if (typeof l === 'string' && /^(hand|foot)_[lr]$/.test(l)) { if (!contactLimbs.has(c.pose)) contactLimbs.set(c.pose, new Set()); contactLimbs.get(c.pose).add(l); }",
      '    }',
      '    for (const [pose, o] of Object.entries(tg.poses)) {',
      "      if (pose.startsWith('_') || !isObj(o)) continue;",
      "      if (known.size && !known.has(pose)) err(TG, `/poses/${esc(pose)}`, 'targets-pose', `pose \"${pose}\" is not in data/anim/poses.json nor a wave's poses file`);",
      '      const lm = contactLimbs.get(pose);',
      "      if (lm) for (const l of lm) if (l in o) err(TG, `/poses/${esc(pose)}/${l}`, 'targets-limb', `${l} lands the blow of a key set whose contact pose this is; it is never changed here`);",
      '    }',
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
  const T = 'data/anim/targets.json';
  const x = (n, mut, expect) => ({ id: 'anim-targets-' + n, schema: 'anim-targets.schema.json', mutate: [{ file: T, ...mut }], expect });
  const add = [
    x('live-valid', { set: { '/schema': 'anim.targets/1' } }, null),
    x('key-required', { del: ['/poses'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'anim.targets/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('poses-empty', { set: { '/poses': {} } }, { rule: 'minProperties', pointer: '/poses' }),
    x('pose-name-shape', { set: { '/poses/Bad Name': { hand_r: [1, 2, 3] } } }, { rule: 'propertyNames', pointer: '/poses/Bad Name' }),
    x('pose-empty', { set: { '/poses/hurt.hold': {} } }, { rule: 'minProperties', pointer: '/poses/hurt.hold' }),
    x('pose-unknown-limb', { set: { '/poses/hurt.hold/elbow_r': [1, 2, 3] } }, { rule: 'additionalProperties', pointer: '/poses/hurt.hold/elbow_r' }),
    x('target-length', { set: { '/poses/hurt.hold/hand_r': [12, 50] } }, { rule: 'minItems', pointer: '/poses/hurt.hold/hand_r' }),
    x('target-too-long', { set: { '/poses/hurt.hold/hand_r': [12, 50, 13, 1] } }, { rule: 'maxItems', pointer: '/poses/hurt.hold/hand_r' }),
    x('target-type', { set: { '/poses/hurt.hold/hand_r': [12, 'a', 13] } }, { rule: 'type', pointer: '/poses/hurt.hold/hand_r/1' }),
    x('foot-target-ok', { set: { '/poses/hurt.hold/foot_l': [4, 2.5, -7] } }, null),
    x('both-hands-ok', { set: { '/poses/hurt.hold': { hand_r: [12, 50, 13], hand_l: [12, 50, -13] } } }, null),
    x('pose-not-in-files', { set: { '/poses/hurt.nowhere': { hand_r: [1, 2, 3] } } }, { rule: 'xref:targets-pose', pointer: '/poses/hurt.nowhere' }),
    x('wave-pose-ok', { set: { '/poses/w1.jab.chamber': { hand_l: [1, 2, 3] } } }, null),
    x('contact-limb-retargeted', { set: { '/poses/strike.jab.contact': { hand_r: [59, 66, 7] } } }, { rule: 'xref:targets-limb', pointer: '/poses/strike.jab.contact/hand_r' }),
    x('wave-contact-limb-retargeted', { set: { '/poses/w1.jab.contact': { hand_r: [59, 66, 7], hand_l: [26, 55, -6] } } }, { rule: 'xref:targets-limb', pointer: '/poses/w1.jab.contact/hand_r' }),
    x('other-limb-in-contact-pose-ok', { set: { '/poses/strike.jab.contact': { hand_l: [26, 55, -6] } } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  // two earlier cases give a test key set a second limb, hand_l, on a contact pose whose hand_l is retargeted (a real conflict for targets-limb):
  // they test only that limb2 is accepted, so the second limb becomes a foot
  for (const k of c.cases) {
    if (k.id !== 'anim-keysets-limb2-accepted' && k.id !== 'anim-wave-keysets-limb2-accepted') continue;
    const set = k.mutate[0].set;
    for (const key of Object.keys(set)) if (set[key] && set[key].limb2 === 'hand_l') set[key].limb2 = 'foot_l';
  }
  wj(cf, c);
  console.log(`targets schema applied (${n} new cases)`);
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('targets-pose')) {
    const line = t.split('\n').find((l) => l.includes('`joints-bone`'));
    t = t.replace(line, () => line + '\n| `targets-pose`, `targets-limb` | data/anim/targets.json: every pose is in poses.json or a wave\'s poses file; a strike\'s contact pose does not retarget the hand or foot that lands the blow (the key set\'s limb or limb2) |');
    fs.writeFileSync(f, t);
  }
}
