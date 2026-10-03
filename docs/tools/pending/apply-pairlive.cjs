// Schema for Animation's data/anim/pair_live.json (anim.pairlive/1; docs/animation/pair-live.md; Animation's draft is
// docs/animation/handoff/anim-pairlive.schema.json). The data is on HEAD already, so the validator only warns "no schema" until this runs.
// NOT run by CI, the validator or the sim. Run once from the repo root, in any commit: node docs/tools/pending/apply-pairlive.cjs
// It does NOT edit data/. It adds tools/schemas/anim-pairlive.schema.json (the draft in the house style), the map entry, the xref rules
// (pairlive-fighter, pairlive-wave, pairlive-ref, pairlive-gated, pairlive-kind) and the cases. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const id = { type: 'string', minLength: 1 };
const SEQ = { type: 'string', pattern: '^[a-z]+[0-9]*\\.[a-z0-9_.]+$' };
const seq = obj({ seq: Object.assign({ description: 'A sequence of a parked wave, started where the cue or the shot says.' }, SEQ), wind_ticks: { type: 'number', minimum: 0, description: 'Ticks of wind-up before the shot leaves.' } }, { required: ['seq'] });
const hold = obj({
  pose: Object.assign({ description: 'The pose held and eased.' }, id),
  ticks: { type: 'number', exclusiveMinimum: 0 },
  in: { type: 'number', minimum: 0, description: 'Seconds to ease in.' },
  out: { type: 'number', minimum: 0, description: 'Seconds to ease out.' },
  w: { type: 'number', minimum: 0, maximum: 1, description: 'The weight of the hold over the body.' },
}, { required: ['pose', 'ticks'] });
const charged = obj({
  charge: Object.assign({ description: 'The pose or sequence held from the charge cue.' }, id),
  full: Object.assign({ description: 'The pose or sequence it takes at the flash.' }, id),
  release: hold,
});
const ROLES = ['bolt', 'volley', 'lob', 'charged', 'mine', 'rain', 'curve'];
const CUES = ['windup', 'charge', 'full', 'cancel', 'crater', 'volley', 'taunt_close', 'drop_the_act', 'crown_release', 'shove'];

// ---- schema ----
{
  const f = 'tools/schemas/anim-pairlive.schema.json';
  if (!fs.existsSync(f)) {
    wj(f, {
      $schema: 'https://json-schema.org/draft/2020-12/schema',
      $id: 'meridian/anim-pairlive',
      title: 'anim.pairlive/1',
      description: 'data/anim/pair_live.json: how the launch pair\'s parked waves play in a live match (docs/animation/pair-live.md). aliases: other names for a fighter of fighters.json. shared: waves baked for both. gated: strikes that join a pick list while their gate is open. spray_gap: ticks between a fighter\'s bolts under which the next is a spray beat. kinds: shot kind to energy role. cues: the sim\'s render cues to what they start. roles: per fighter of fighters.json what each role plays (a sequence, a held pose, a charged pair, the far taunts). Render only, outside the sim\'s data hash. Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (every roles and aliases fighter is in fighters.json; every shared wave has a poses file; every sequence and pose a role names exists; every gated strike is a strike of a wave manifest; every shot kind has a role) are checked by tools/lib/xref-fight.js (pairlive-*). Animation\'s draft: docs/animation/handoff/anim-pairlive.schema.json.',
      type: 'object',
      required: ['schema', 'shared', 'gated', 'spray_gap', 'kinds', 'cues', 'roles'],
      properties: {
        schema: { const: 'anim.pairlive/1' },
        aliases: { type: 'object', propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_-]*)$' }, additionalProperties: { type: 'string', pattern: '^[a-z][a-z0-9_]*$' }, patternProperties: { '^_': true }, description: 'Another name for a fighter of fighters.json.' },
        shared: { type: 'array', uniqueItems: true, items: { type: 'string', pattern: '^[a-z]+[0-9]+$' }, description: 'Waves baked for both fighters.' },
        gated: { type: 'array', items: obj({ strike: Object.assign({ description: 'The strike\'s name in its wave manifest.' }, id), weight: { enum: ['light', 'heavy'] }, gate: { enum: ['both_ground', 'striker_air'], description: 'both_ground: both fighters near the ground; striker_air: the striker well above it.' } }), description: 'Strikes that join their fighter\'s pick list only while their gate is open.' },
        spray_gap: { type: 'integer', minimum: 1, description: 'Ticks between a fighter\'s bolts under which the next is a spray beat.' },
        kinds: { type: 'object', propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' }, additionalProperties: { enum: ROLES }, patternProperties: { '^_': true }, description: 'A shot kind to the energy role it plays.' },
        cues: { type: 'object', propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' }, additionalProperties: { enum: CUES }, patternProperties: { '^_': true }, description: 'The sim\'s render cues to what they start.' },
        roles: {
          type: 'object',
          minProperties: 1,
          propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
          description: 'Per fighter, what each role plays.',
          additionalProperties: Object.assign({
            type: 'object',
            properties: {
              bolt: seq, volley: seq, lob: seq, curve: seq, spray: seq, mine: seq, swat: seq, taunt_close: seq, taunt_close_air: seq, drop_the_act: seq,
              crater: hold, rain: hold, shove: hold, crown_release: hold,
              charged,
              taunts: { type: 'array', minItems: 1, uniqueItems: true, items: id, description: 'The far taunts: one is picked by a hash of the tick.' },
              taunt_first: Object.assign({ description: 'The far taunt played first, one of the taunts.' }, id),
            },
          }, closed),
          patternProperties: { '^_': true },
        },
      },
      additionalProperties: false,
      patternProperties: { '^_': true },
    });
  }
}

// ---- schema upgrade: a first version of this script (without taunt_first and taunt_close_air) may have run already ----
{
  const f = 'tools/schemas/anim-pairlive.schema.json';
  const s = rj(f);
  const rp = s.properties.roles.additionalProperties.properties;
  if (!rp.taunt_first) {
    const out = {};
    for (const k of Object.keys(rp)) {
      out[k] = rp[k];
      if (k === 'taunt_close') out.taunt_close_air = seq;
    }
    out.taunt_first = Object.assign({ description: 'The far taunt played first, one of the taunts.' }, id);
    if (!out.taunt_close_air) out.taunt_close_air = seq;
    s.properties.roles.additionalProperties.properties = out;
    wj(f, s);
  }
}

// ---- map ----
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/anim/pair_live.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/anim/fighters.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/anim/pair_live.json', schema: 'anim-pairlive.schema.json' });
    wj(f, m);
  }
}

// ---- xref ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'pairlive-ref'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      "  // ---- anim pair live: the fighters and waves exist; every sequence and pose a role names exists; gated strikes and shot kinds are real ----",
      "  const plv = get('data/anim/pair_live.json');",
      "  if (isObj(plv)) {",
      "    const PL = 'data/anim/pair_live.json';",
      "    const fgs = get('data/anim/fighters.json');",
      "    const fids = isObj(fgs) && isObj(fgs.fighters) ? Object.keys(fgs.fighters).filter((k) => !k.startsWith('_')) : [];",
      "    if (fids.length) {",
      "      if (isObj(plv.roles)) for (const k of Object.keys(plv.roles)) if (!k.startsWith('_') && !fids.includes(k)) err(PL, `/roles/${esc(k)}`, 'pairlive-fighter', `roles for \"${k}\", who is not a fighter of fighters.json (${fids.join(', ')})`);",
      "      if (isObj(plv.aliases)) for (const [k, v] of Object.entries(plv.aliases)) if (!k.startsWith('_') && typeof v === 'string' && !fids.includes(v)) err(PL, `/aliases/${esc(k)}`, 'pairlive-fighter', `alias \"${k}\" names \"${v}\", who is not a fighter of fighters.json (${fids.join(', ')})`);",
      "    }",
      "    if (Array.isArray(plv.shared)) plv.shared.forEach((w, i) => { if (typeof w === 'string' && !get(`data/anim/waves/${w}.poses.json`)) err(PL, `/shared/${i}`, 'pairlive-wave', `shared wave \"${w}\" has no data/anim/waves/${w}.poses.json`); });",
      "    const poseSet = new Set(); const seqSet = new Set(); const strikeNames = new Set();",
      "    const mainPl = get('data/anim/poses.json');",
      "    if (isObj(mainPl) && isObj(mainPl.poses)) for (const k of Object.keys(mainPl.poses)) poseSet.add(k);",
      "    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.poses\\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) poseSet.add(k); }",
      "    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.sequences\\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.sequences)) for (const k of Object.keys(d.sequences)) seqSet.add(k); }",
      "    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.manifest\\.json$/)) { const d = get(rel); if (isObj(d) && Array.isArray(d.strikes)) for (const s of d.strikes) if (isObj(s) && typeof s.name === 'string') strikeNames.add(s.name); }",
      "    const needSeq = (v, at) => { if (seqSet.size && typeof v === 'string' && !seqSet.has(v)) err(PL, at, 'pairlive-ref', `sequence \"${v}\" is not in a wave's sequences file`); };",
      "    const needPose = (v, at) => { if (poseSet.size && typeof v === 'string' && !poseSet.has(v)) err(PL, at, 'pairlive-ref', `pose \"${v}\" is not in poses.json nor a wave's poses file`); };",
      "    const needEither = (v, at) => { if ((poseSet.size || seqSet.size) && typeof v === 'string' && !poseSet.has(v) && !seqSet.has(v)) err(PL, at, 'pairlive-ref', `\"${v}\" is neither a pose nor a sequence of the wave files`); };",
      "    for (const [fid, r] of Object.entries(isObj(plv.roles) ? plv.roles : {})) {",
      "      if (fid.startsWith('_') || !isObj(r)) continue;",
      "      for (const [role, v] of Object.entries(r)) {",
      "        if (role.startsWith('_')) continue;",
      "        const at = `/roles/${esc(fid)}/${esc(role)}`;",
      "        if (role === 'taunts') { if (Array.isArray(v)) v.forEach((x, i) => needEither(x, `${at}/${i}`)); }",
      "        else if (role === 'taunt_first') { needEither(v, at); if (Array.isArray(r.taunts) && typeof v === 'string' && !r.taunts.includes(v)) err(PL, at, 'pairlive-ref', `taunt_first \"${v}\" is not one of ${fid}'s taunts`, 'warning'); }",
      "        else if (!isObj(v)) continue;",
      "        else if (role === 'charged') { needEither(v.charge, `${at}/charge`); needEither(v.full, `${at}/full`); if (isObj(v.release)) needPose(v.release.pose, `${at}/release/pose`); }",
      "        else if (typeof v.seq === 'string') needSeq(v.seq, `${at}/seq`);",
      "        else if (typeof v.pose === 'string') needPose(v.pose, `${at}/pose`);",
      "      }",
      "    }",
      "    if (Array.isArray(plv.gated) && strikeNames.size) plv.gated.forEach((g, i) => { if (isObj(g) && typeof g.strike === 'string' && !strikeNames.has(g.strike)) err(PL, `/gated/${i}/strike`, 'pairlive-gated', `gated strike \"${g.strike}\" is no strike of any wave manifest`); });",
      "    const shotsPl = get('data/fight/shots.json');",
      "    if (isObj(shotsPl) && isObj(shotsPl.kinds) && isObj(plv.kinds)) for (const k of Object.keys(shotsPl.kinds)) if (!k.startsWith('_') && !(k in plv.kinds)) err(PL, '/kinds', 'pairlive-kind', `shot kind \"${k}\" of data/fight/shots.json has no energy role in kinds`, 'warning');",
      "  }",
      "",
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- xref upgrade: the taunt_first check, for a tree where the first version ran ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (t.includes("'pairlive-ref'") && !t.includes("role === 'taunt_first'")) {
    const a = "        else if (!isObj(v)) continue;";
    if (!t.includes(a)) throw new Error('pairlive upgrade anchor');
    t = t.replace(a, () => [
      "        else if (role === 'taunt_first') { needEither(v, at); if (Array.isArray(r.taunts) && typeof v === 'string' && !r.taunts.includes(v)) err(PL, at, 'pairlive-ref', `taunt_first \"${v}\" is not one of ${fid}'s taunts`, 'warning'); }",
      a,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- cases ----
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const P = 'data/anim/pair_live.json';
  const x = (n, mut, expect) => ({ id: 'anim-pairlive-' + n, schema: 'anim-pairlive.schema.json', mutate: [{ file: P, ...mut }], expect });
  const R = '/roles/protagonist/';
  const add = [
    x('live-valid', { set: { '/spray_gap': 10 } }, null),
    x('key-required', { del: ['/roles'] }, { rule: 'required', pointer: '' }),
    x('cues-required', { del: ['/cues'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'anim.pairlive/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('alias-type', { set: { '/aliases/rival': 3 } }, { rule: 'type', pointer: '/aliases/rival' }),
    x('alias-to-unknown-fighter', { set: { '/aliases/rival': 'nobody' } }, { rule: 'xref:pairlive-fighter', pointer: '/aliases/rival' }),
    x('alias-new-ok', { set: { '/aliases/foe': 'antihero' } }, null),
    x('shared-wave-shape', { set: { '/shared': ['Energy 1'] } }, { rule: 'pattern', pointer: '/shared/0' }),
    x('shared-duplicate', { set: { '/shared': ['energy1', 'energy1'] } }, { rule: 'uniqueItems', pointer: '/shared/1' }),
    x('shared-wave-without-poses', { set: { '/shared': ['energy9'] } }, { rule: 'xref:pairlive-wave', pointer: '/shared/0' }),
    x('shared-empty-ok', { set: { '/shared': [] } }, null),
    x('gated-key-required', { del: ['/gated/0/gate'] }, { rule: 'required', pointer: '/gated/0' }),
    x('gated-gate-enum', { set: { '/gated/0/gate': 'always' } }, { rule: 'enum', pointer: '/gated/0/gate' }),
    x('gated-weight-enum', { set: { '/gated/0/weight': 'medium' } }, { rule: 'enum', pointer: '/gated/0/weight' }),
    x('gated-unknown-key', { set: { '/gated/0/extra': 1 } }, { rule: 'additionalProperties', pointer: '/gated/0/extra' }),
    x('gated-strike-unknown', { set: { '/gated/0/strike': 'nowhere' } }, { rule: 'xref:pairlive-gated', pointer: '/gated/0/strike' }),
    x('spray-gap-zero', { set: { '/spray_gap': 0 } }, { rule: 'minimum', pointer: '/spray_gap' }),
    x('spray-gap-integer', { set: { '/spray_gap': 10.5 } }, { rule: 'type', pointer: '/spray_gap' }),
    x('kind-role-enum', { set: { '/kinds/bolt': 'beam' } }, { rule: 'enum', pointer: '/kinds/bolt' }),
    x('kind-without-role-warns', { del: ['/kinds/mine'] }, { rule: 'xref:pairlive-kind', pointer: '/kinds' }),
    x('kind-extra-ok', { set: { '/kinds/comet': 'bolt' } }, null),
    x('cue-start-enum', { set: { '/cues/blast_windup': 'explode' } }, { rule: 'enum', pointer: '/cues/blast_windup' }),
    x('cue-new-ok', { set: { '/cues/blast_new': 'charge' } }, null),
    x('roles-empty', { set: { '/roles': {} } }, { rule: 'minProperties', pointer: '/roles' }),
    x('role-fighter-unknown', { set: { '/roles/nobody': {} } }, { rule: 'xref:pairlive-fighter', pointer: '/roles/nobody' }),
    x('role-unknown-key', { set: { [R + 'sneeze']: { seq: 'pg.bolt' } } }, { rule: 'additionalProperties', pointer: R + 'sneeze' }),
    x('role-underscore-ok', { set: { [R + '_note']: 'comment' } }, null),
    x('seq-key-required', { set: { [R + 'bolt']: { wind_ticks: 4 } } }, { rule: 'required', pointer: R + 'bolt' }),
    x('seq-shape', { set: { [R + 'bolt/seq']: 'Bolt' } }, { rule: 'pattern', pointer: R + 'bolt/seq' }),
    x('seq-unknown', { set: { [R + 'bolt/seq']: 'pg.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'bolt/seq' }),
    x('seq-wind-negative', { set: { [R + 'bolt/wind_ticks']: -1 } }, { rule: 'minimum', pointer: R + 'bolt/wind_ticks' }),
    x('seq-unknown-key', { set: { [R + 'bolt/extra']: 1 } }, { rule: 'additionalProperties', pointer: R + 'bolt/extra' }),
    x('hold-key-required', { del: [R + 'crater/ticks'] }, { rule: 'required', pointer: R + 'crater' }),
    x('hold-pose-unknown', { set: { [R + 'crater/pose']: 'pg.hold.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'crater/pose' }),
    x('hold-ticks-zero', { set: { [R + 'crater/ticks']: 0 } }, { rule: 'exclusiveMinimum', pointer: R + 'crater/ticks' }),
    x('hold-in-negative', { set: { [R + 'crater/in']: -0.1 } }, { rule: 'minimum', pointer: R + 'crater/in' }),
    x('hold-weight-range', { set: { [R + 'crater/w']: 1.5 } }, { rule: 'maximum', pointer: R + 'crater/w' }),
    x('hold-optional-ok', { set: { [R + 'crater']: { pose: 'pg.hold.blast_down', ticks: 22 } } }, null),
    x('charged-key-required', { del: [R + 'charged/release'] }, { rule: 'required', pointer: R + 'charged' }),
    x('charged-charge-unknown', { set: { [R + 'charged/charge']: 'pn.hold.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'charged/charge' }),
    x('charged-full-unknown', { set: { [R + 'charged/full']: 'pn.hold.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'charged/full' }),
    x('charged-release-pose-unknown', { set: { [R + 'charged/release/pose']: 'pn.hold.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'charged/release/pose' }),
    x('taunt-first-ok', { set: { [R + 'taunt_first']: 'pg.taunt_bounce' } }, null),
    x('taunt-first-type', { set: { [R + 'taunt_first']: 3 } }, { rule: 'type', pointer: R + 'taunt_first' }),
    x('taunt-first-unknown', { set: { [R + 'taunt_first']: 'pg.taunt_nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'taunt_first' }),
    x('taunt-first-not-a-taunt-warns', { set: { [R + 'taunt_first']: 'pg.taunt_close' } }, { rule: 'xref:pairlive-ref', pointer: R + 'taunt_first' }),
    x('taunt-close-air-seq-unknown', { set: { [R + 'taunt_close_air/seq']: 'pg.nowhere' } }, { rule: 'xref:pairlive-ref', pointer: R + 'taunt_close_air/seq' }),
    x('taunt-close-air-key-required', { set: { [R + 'taunt_close_air']: {} } }, { rule: 'required', pointer: R + 'taunt_close_air' }),
    x('taunts-empty', { set: { [R + 'taunts']: [] } }, { rule: 'minItems', pointer: R + 'taunts' }),
    x('taunts-duplicate', { set: { [R + 'taunts']: ['pg.taunt_nod', 'pg.taunt_nod'] } }, { rule: 'uniqueItems', pointer: R + 'taunts/1' }),
    x('taunts-unknown', { set: { [R + 'taunts']: ['pg.taunt_nod', 'pg.taunt_nowhere'] } }, { rule: 'xref:pairlive-ref', pointer: R + 'taunts/1' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`pair live schema applied (${n} new cases)`);
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('pairlive-ref')) {
    const line = t.split('\n').find((l) => l.includes('`fighters-shape`')) || t.split('\n').find((l) => l.includes('`flight-order`'));
    if (!line) throw new Error('pairlive README anchor');
    t = t.replace(line, () => line + '\n| `pairlive-fighter`, `pairlive-wave`, `pairlive-ref`, `pairlive-gated`, `pairlive-kind` | data/anim/pair_live.json: every roles fighter and every alias target is a fighter of fighters.json; every shared wave has a poses file; every sequence and held pose a role names is in a wave\'s files (a charge, full or taunt may be either); every gated strike is a strike of a wave manifest; every shot kind of shots.json has an energy role in kinds (a warning) |');
    fs.writeFileSync(f, t);
  }
}
