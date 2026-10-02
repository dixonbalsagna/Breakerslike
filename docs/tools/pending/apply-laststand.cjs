// Schema for Animation's last-stand body cue, data/anim/laststand.json (docs/architecture/last-stand.md; render/anim/anim_fighter.gd, on_last_stand).
// NOT run by CI, the validator or the sim. Run once from the repo root, after Encounter's slice has been committed (the data is on HEAD already, so the
// validator only warns "no schema" until then):
//     node docs/tools/pending/apply-laststand.cjs
// It adds tools/schemas/anim-laststand.schema.json, the map entry, the xref rules (laststand-shape, laststand-seq) and the cases. It does NOT edit data/.
// Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const seqId = { type: 'string', pattern: '^[a-z][a-z0-9_]*([.][a-z0-9_~]+)*$' };

wj('tools/schemas/anim-laststand.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/anim-laststand',
  title: 'anim.laststand/1',
  description: 'data/anim/laststand.json: the last stand\'s body cue (docs/architecture/last-stand.md; render/anim/anim_fighter.gd, on_last_stand). ready: for each shape key, the steadying sequence played when last_stand_ready arrives (data/anim/waves/laststand1.sequences.json); hold_weight, in and out: the share of the held resolve pose mixed in while the window is open, and its fade in and out times (s). The `expired` end plays ls.slump; `used` hands over to the signature\'s own animation. Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every ready key is `default` or a shape in ragdoll_motion.json shapes; every sequence, and ls.slump, is in laststand1.sequences.json) are checked by tools/lib/xref-fight.js (laststand-shape, laststand-seq).',
  type: 'object',
  required: ['schema', 'ready', 'hold_weight', 'in', 'out'],
  properties: {
    schema: { const: 'anim.laststand/1' },
    ready: {
      type: 'object',
      description: 'Shape key (or `default`) to the sequence played when last_stand_ready arrives.',
      required: ['default'],
      propertyNames: { pattern: '^(_.*|default|[A-Za-z][A-Za-z0-9_]*)$' },
      additionalProperties: seqId,
      patternProperties: { '^_': true },
    },
    hold_weight: { type: 'number', minimum: 0, maximum: 1, description: 'The share of the held resolve pose mixed in while the window is open.' },
    in: { type: 'number', minimum: 0, description: 'Seconds the held resolve pose fades in.' },
    out: { type: 'number', minimum: 0, description: 'Seconds it fades out.' },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// ---- map ----
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/anim/laststand.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/anim/intro.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/anim/laststand.json', schema: 'anim-laststand.schema.json' });
    wj(f, m);
  }
}

// ---- xref ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'laststand-seq'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- anim last stand: ready keys are shapes, sequences exist ----',
      "  const lsd = get('data/anim/laststand.json');",
      '  if (isObj(lsd) && isObj(lsd.ready)) {',
      "    const LS = 'data/anim/laststand.json';",
      "    const motL = get('data/anim/ragdoll_motion.json');",
      "    const seqL = get('data/anim/waves/laststand1.sequences.json');",
      "    const shapesL = isObj(motL) && isObj(motL.shapes) ? Object.keys(motL.shapes).filter((k) => !k.startsWith('_')) : [];",
      '    const seqsL = isObj(seqL) && isObj(seqL.sequences) ? seqL.sequences : undefined;',
      '    for (const [k, id] of Object.entries(lsd.ready)) {',
      "      if (k.startsWith('_')) continue;",
      "      if (k !== 'default' && shapesL.length && !shapesL.includes(k)) err(LS, `/ready/${esc(k)}`, 'laststand-shape', `ready key \"${k}\" is not default nor a shape in ragdoll_motion.json shapes (${shapesL.join(', ')})`);",
      "      if (seqsL && typeof id === 'string' && !(id in seqsL)) err(LS, `/ready/${esc(k)}`, 'laststand-seq', `sequence \"${id}\" is not in data/anim/waves/laststand1.sequences.json`);",
      '    }',
      "    if (seqsL && !('ls.slump' in seqsL)) err(LS, '/ready', 'laststand-seq', 'the expired end plays ls.slump, which is not in data/anim/waves/laststand1.sequences.json');",
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
  const L = 'data/anim/laststand.json';
  const x = (n, mut, expect) => ({ id: 'anim-laststand-' + n, schema: 'anim-laststand.schema.json', mutate: [{ file: L, ...mut }], expect });
  const add = [
    x('live-valid', { set: { '/schema': 'anim.laststand/1' } }, null),
    x('key-required', { del: ['/out'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'anim.laststand/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('ready-default-required', { set: { '/ready': { P: 'ls.ready_p' } } }, { rule: 'required', pointer: '/ready' }),
    x('ready-key-shape', { set: { '/ready/bad key': 'ls.ready_p' } }, { rule: 'propertyNames', pointer: '/ready/bad key' }),
    x('ready-seq-shape', { set: { '/ready/P': 'LS Ready' } }, { rule: 'pattern', pointer: '/ready/P' }),
    x('ready-seq-type', { set: { '/ready/P': 3 } }, { rule: 'type', pointer: '/ready/P' }),
    x('ready-shape-unknown', { set: { '/ready/Z': 'ls.ready_p' } }, { rule: 'xref:laststand-shape', pointer: '/ready/Z' }),
    x('ready-seq-unknown', { set: { '/ready/A': 'ls.nowhere' } }, { rule: 'xref:laststand-seq', pointer: '/ready/A' }),
    x('ready-default-seq-unknown', { set: { '/ready/default': 'ls.nowhere' } }, { rule: 'xref:laststand-seq', pointer: '/ready/default' }),
    x('ready-partial-ok', { set: { '/ready': { default: 'ls.ready_p', A: 'ls.ready_a' } } }, null),
    x('hold-weight-range', { set: { '/hold_weight': 1.5 } }, { rule: 'maximum', pointer: '/hold_weight' }),
    x('hold-weight-negative', { set: { '/hold_weight': -0.1 } }, { rule: 'minimum', pointer: '/hold_weight' }),
    x('hold-weight-zero-ok', { set: { '/hold_weight': 0 } }, null),
    x('in-negative', { set: { '/in': -1 } }, { rule: 'minimum', pointer: '/in' }),
    x('out-type', { set: { '/out': 'slow' } }, { rule: 'type', pointer: '/out' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`laststand schema applied (${n} new cases)`);
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('laststand-shape')) {
    const line = t.split('\n').find((l) => l.includes('`intro-shape`'));
    t = t.replace(line, () => line + '\n| `laststand-shape`, `laststand-seq` | data/anim/laststand.json: every ready key is `default` or a shape in ragdoll_motion.json shapes; every ready sequence, and ls.slump, is in data/anim/waves/laststand1.sequences.json |');
    fs.writeFileSync(f, t);
  }
}
