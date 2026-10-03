// Schema keys for Encounter's slice 11, the string's flow, the timed combo and the blur's cadence (docs/director/update-apply-order.md step 4).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit that lands the slice's data (the same commit as
// apply-pieces.cjs and Combat's recipes.json):
//     node docs/tools/pending/apply-slice11.cjs
// It does NOT edit data/. It adds:
//   data/director/alchemy.json  the required flow {enabled, max, lapseTicks, enderAfter, launchAt, showcaseAt}, timing {comboMul} and
//                               blur {enabled, cadences, minLeadTicks} (closed; _note allowed)
//   data/director/launch.json   the required blur.perfectDist (number, 0 or more)
//   data/director/ai.json       the required per-level timedPress (a chance) (`_timedPress` is a note and is allowed)
// and drops `read.steadyJitter` from tools/schemas/input-timing.schema.json (Controls' data has no steadyJitter any more; the closed schema
// then rejects it if it comes back). It adds the three fixtures' keys, the rule alchemy-flow, `timedPress` to the levels-order check, and
// the cases (the earlier whole-blur launch case is patched). Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const chance = { type: 'number', minimum: 0, maximum: 1 };
const int1 = (d) => ({ type: 'integer', minimum: 1, description: d });
const int0 = (d) => ({ type: 'integer', minimum: 0, description: d });
const clone = (o) => JSON.parse(JSON.stringify(o));
const strip = (o) => Object.fromEntries(Object.entries(o).filter(([k]) => !k.startsWith('_')).map(([k, v]) => [k, v && typeof v === 'object' && !Array.isArray(v) ? strip(v) : v]));

// placeholders for the fixtures until the live data carries the keys
const FX = {
  flow: { enabled: true, max: 5, lapseTicks: 180, enderAfter: 3, launchAt: 3, showcaseAt: 5 },
  timing: { comboMul: 1.15 },
  blur: { enabled: true, cadences: [7, 8, 9, 10], minLeadTicks: 6 },
  perfectDist: 0.8,
  timedPress: { easy: 0.2, medium: 0.4, hard: 0.6 },
};
const live = (f) => (fs.existsSync(f) ? rj(f) : null);
const liveAl = live('data/director/alchemy.json');
const liveLa = live('data/director/launch.json');
const liveAi = live('data/director/ai.json');
const haveAl = liveAl && liveAl.flow;
const haveLa = liveLa && liveLa.blur && liveLa.blur.perfectDist !== undefined;
const haveAi = liveAi && liveAi.levels && liveAi.levels.medium && liveAi.levels.medium.timedPress !== undefined;

// =============================== alchemy schema ===============================
{
  const f = 'tools/schemas/director-alchemy.schema.json';
  const s = rj(f);
  if (!s.properties.flow) {
    s.properties.flow = obj({
      enabled: { type: 'boolean', description: 'false: a string has no flow.' },
      max: int1('The most flow a string reaches.'),
      lapseTicks: int1('Ticks without a press after which the flow lapses.'),
      enderAfter: int1('The flow at which the string\'s ender is the flow\'s own.'),
      launchAt: int1('The flow at which a launch takes the panel.'),
      showcaseAt: int1('The flow at which a showcase ender can replace the plain one.'),
    }, { description: 'The flow of a string (agency-pass.md section 2; sim/director/alchemy.gd).' });
    s.properties.timing = obj({ comboMul: { type: 'number', minimum: 0, description: 'The damage multiplier of a clean and hard combo tap.' } }, { description: 'The timed press.' });
    s.properties.blur = obj({
      enabled: { type: 'boolean', description: 'false: a blur string has no pattern or cadence.' },
      cadences: { type: 'array', minItems: 1, items: { type: 'integer', minimum: 1 }, description: 'The ticks between the blows of a blur string; the string draws one (agency-pass.md section 20).' },
      minLeadTicks: int0('The least lead, in ticks, a blur blow has over its press.'),
    }, { description: 'The blur\'s pattern and cadence.' });
    for (const k of ['flow', 'timing', 'blur']) if (!s.required.includes(k)) s.required.push(k);
    wj(f, s);
  }
}

// =============================== launch schema ===============================
{
  const f = 'tools/schemas/director-launch.schema.json';
  const s = rj(f);
  const b = s.properties.blur;
  if (!b.properties.perfectDist) {
    b.properties.perfectDist = { type: 'number', minimum: 0, description: 'How far the perfect blur\'s ender goes.' };
    if (!b.required.includes('perfectDist')) b.required.push('perfectDist');
    wj(f, s);
  }
}

// =============================== ai schema ===============================
{
  const f = 'tools/schemas/director-ai.schema.json';
  const s = rj(f);
  if (!s.properties.levels.properties.easy.properties.timedPress) {
    for (const name of ['easy', 'medium', 'hard']) {
      const L = s.properties.levels.properties[name];
      L.properties.timedPress = Object.assign({ description: 'The chance an AI press is timed (on the beat).' }, chance);
      if (!L.required.includes('timedPress')) L.required.push('timedPress');
    }
    wj(f, s);
  }
}

// =============================== input timing schema: steadyJitter is gone ===============================
{
  const f = 'tools/schemas/input-timing.schema.json';
  const s = rj(f);
  const rd = s.properties.read;
  if (rd.properties.steadyJitter) {
    delete rd.properties.steadyJitter;
    if (Array.isArray(rd.required)) rd.required = rd.required.filter((k) => k !== 'steadyJitter');
    wj(f, s);
  }
}

// =============================== fixtures ===============================
{
  const dir = 'tools/fixtures/virtual/data/director/';
  {
    const f = dir + 'alchemy.json';
    const o = rj(f);
    if (o.flow === undefined) {
      o.flow = haveAl ? strip(liveAl.flow) : clone(FX.flow);
      o.timing = haveAl ? strip(liveAl.timing) : clone(FX.timing);
      o.blur = haveAl ? strip(liveAl.blur) : clone(FX.blur);
      wj(f, o);
    }
  }
  {
    const f = dir + 'launch.json';
    const o = rj(f);
    if (o.blur && o.blur.perfectDist === undefined) {
      o.blur.perfectDist = haveLa ? liveLa.blur.perfectDist : FX.perfectDist;
      wj(f, o);
    }
  }
  {
    const f = dir + 'ai.json';
    const o = rj(f);
    if (o.levels && o.levels.easy && o.levels.easy.timedPress === undefined) {
      for (const name of ['easy', 'medium', 'hard']) o.levels[name].timedPress = haveAi ? liveAi.levels[name].timedPress : FX.timedPress[name];
      wj(f, o);
    }
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'alchemy-flow'")) {
    const a = "'beamDodge', 'beamWade', 'beamLate']) {";
    if (!t.includes(a)) throw new Error('levels anchor');
    t = t.replace(a, () => "'beamDodge', 'beamWade', 'beamLate', 'timedPress']) {");
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      "  // ---- director alchemy flow: the thresholds rise and fit under the maximum ----",
      "  const alf = get('data/director/alchemy.json');",
      "  if (isObj(alf) && isObj(alf.flow)) {",
      "    const AF = 'data/director/alchemy.json';",
      "    const fl = alf.flow;",
      "    if (typeof fl.launchAt === 'number' && typeof fl.showcaseAt === 'number' && fl.launchAt > fl.showcaseAt) err(AF, '/flow/launchAt', 'alchemy-flow', `launchAt ${fl.launchAt} is above showcaseAt ${fl.showcaseAt}; the showcase is the flow's top ending`);",
      "    for (const k of ['enderAfter', 'launchAt', 'showcaseAt']) if (typeof fl[k] === 'number' && typeof fl.max === 'number' && fl[k] > fl.max) err(AF, `/flow/${k}`, 'alchemy-flow', `${k} ${fl[k]} is above max ${fl.max}, so the flow never reaches it`, 'warning');",
      "  }",
      "",
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const AL = 'data/director/alchemy.json';
  const LA = 'data/director/launch.json';
  const AI = 'data/director/ai.json';
  // the earlier whole-blur launch case needs the new required key
  for (const k of c.cases) for (const m of k.mutate || []) {
    const o = k.id.startsWith('director-launch-blur-') && m.set && m.set['/blur'];
    if (o && typeof o === 'object' && o.perfectDist === undefined) o.perfectDist = 0.8;
  }
  const al = (n, mut, expect) => ({ id: 'director-alchemy-' + n, schema: 'director-alchemy.schema.json', mutate: [{ file: AL, ...mut }], expect });
  const la = (n, mut, expect) => ({ id: 'director-launch-' + n, schema: 'director-launch.schema.json', mutate: [{ file: LA, ...mut }], expect });
  const ai = (n, mut, expect) => ({ id: 'director-ai-' + n, schema: 'director-ai.schema.json', mutate: [{ file: AI, ...mut }], expect });
  const F = '/flow/';
  const T = '/timing/';
  const B = '/blur/';
  const add = [
    al('flow-required', { del: ['/flow'] }, { rule: 'required', pointer: '' }),
    al('timing-required', { del: ['/timing'] }, { rule: 'required', pointer: '' }),
    al('blur-required', { del: ['/blur'] }, { rule: 'required', pointer: '' }),
    al('flow-key-required', { del: [F + 'lapseTicks'] }, { rule: 'required', pointer: '/flow' }),
    al('flow-unknown-key', { set: { [F + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: F + 'extra' }),
    al('flow-note-ok', { set: { [F + '_note']: 'comment' } }, null),
    al('flow-enabled-type', { set: { [F + 'enabled']: 'yes' } }, { rule: 'type', pointer: F + 'enabled' }),
    al('flow-off-ok', { set: { [F + 'enabled']: false } }, null),
    al('flow-max-zero', { set: { [F + 'max']: 0 } }, { rule: 'minimum', pointer: F + 'max' }),
    al('flow-max-integer', { set: { [F + 'max']: 5.5 } }, { rule: 'type', pointer: F + 'max' }),
    al('flow-lapse-zero', { set: { [F + 'lapseTicks']: 0 } }, { rule: 'minimum', pointer: F + 'lapseTicks' }),
    al('flow-ender-after-zero', { set: { [F + 'enderAfter']: 0 } }, { rule: 'minimum', pointer: F + 'enderAfter' }),
    al('flow-launch-at-zero', { set: { [F + 'launchAt']: 0 } }, { rule: 'minimum', pointer: F + 'launchAt' }),
    al('flow-showcase-at-type', { set: { [F + 'showcaseAt']: 'top' } }, { rule: 'type', pointer: F + 'showcaseAt' }),
    al('flow-launch-above-showcase', { set: { [F + 'launchAt']: 5, [F + 'showcaseAt']: 3 } }, { rule: 'xref:alchemy-flow', pointer: F + 'launchAt' }),
    al('flow-launch-equals-showcase-ok', { set: { [F + 'launchAt']: 4, [F + 'showcaseAt']: 4 } }, null),
    al('flow-showcase-above-max-warns', { set: { [F + 'showcaseAt']: 9 } }, { rule: 'xref:alchemy-flow', pointer: F + 'showcaseAt' }),
    al('flow-ender-above-max-warns', { set: { [F + 'enderAfter']: 9 } }, { rule: 'xref:alchemy-flow', pointer: F + 'enderAfter' }),
    al('timing-key-required', { set: { '/timing': {} } }, { rule: 'required', pointer: '/timing' }),
    al('timing-unknown-key', { set: { [T + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: T + 'extra' }),
    al('timing-note-ok', { set: { [T + '_note']: 'comment' } }, null),
    al('timing-combo-mul-negative', { set: { [T + 'comboMul']: -1 } }, { rule: 'minimum', pointer: T + 'comboMul' }),
    al('timing-combo-mul-type', { set: { [T + 'comboMul']: 'more' } }, { rule: 'type', pointer: T + 'comboMul' }),
    al('blur-key-required', { del: [B + 'minLeadTicks'] }, { rule: 'required', pointer: '/blur' }),
    al('blur-unknown-key', { set: { [B + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: B + 'extra' }),
    al('blur-note-ok', { set: { [B + '_note']: 'comment' } }, null),
    al('blur-enabled-type', { set: { [B + 'enabled']: 1 } }, { rule: 'type', pointer: B + 'enabled' }),
    al('blur-cadences-empty', { set: { [B + 'cadences']: [] } }, { rule: 'minItems', pointer: B + 'cadences' }),
    al('blur-cadences-type', { set: { [B + 'cadences']: 8 } }, { rule: 'type', pointer: B + 'cadences' }),
    al('blur-cadence-integer', { set: { [B + 'cadences']: [7, 8.5] } }, { rule: 'type', pointer: B + 'cadences/1' }),
    al('blur-cadence-zero', { set: { [B + 'cadences']: [7, 0] } }, { rule: 'minimum', pointer: B + 'cadences/1' }),
    al('blur-cadence-one-ok', { set: { [B + 'cadences']: [8] } }, null),
    al('blur-min-lead-negative', { set: { [B + 'minLeadTicks']: -1 } }, { rule: 'minimum', pointer: B + 'minLeadTicks' }),
    al('blur-min-lead-zero-ok', { set: { [B + 'minLeadTicks']: 0 } }, null),
    la('blur-perfect-dist-required', { del: ['/blur/perfectDist'] }, { rule: 'required', pointer: '/blur' }),
    la('blur-perfect-dist-negative', { set: { '/blur/perfectDist': -0.1 } }, { rule: 'minimum', pointer: '/blur/perfectDist' }),
    la('blur-perfect-dist-type', { set: { '/blur/perfectDist': 'far' } }, { rule: 'type', pointer: '/blur/perfectDist' }),
    la('blur-perfect-dist-zero-ok', { set: { '/blur/perfectDist': 0 } }, null),
    ai('timed-press-required-easy', { del: ['/levels/easy/timedPress'] }, { rule: 'required', pointer: '/levels/easy' }),
    ai('timed-press-required-medium', { del: ['/levels/medium/timedPress'] }, { rule: 'required', pointer: '/levels/medium' }),
    ai('timed-press-required-hard', { del: ['/levels/hard/timedPress'] }, { rule: 'required', pointer: '/levels/hard' }),
    ai('timed-press-range', { set: { '/levels/easy/timedPress': 1.5 } }, { rule: 'maximum', pointer: '/levels/easy/timedPress' }),
    ai('timed-press-negative', { set: { '/levels/medium/timedPress': -0.1 } }, { rule: 'minimum', pointer: '/levels/medium/timedPress' }),
    ai('timed-press-type', { set: { '/levels/hard/timedPress': 'often' } }, { rule: 'type', pointer: '/levels/hard/timedPress' }),
    ai('timed-press-harder-level-lower-warns', { set: { '/levels/hard/timedPress': 0.01 } }, { rule: 'xref:ai-levels-order', pointer: '/levels/hard/timedPress' }),
    ai('timed-press-edges-ok', { set: { '/levels/easy/timedPress': 0, '/levels/hard/timedPress': 1 } }, null),
    ai('timed-press-note-ok', { set: { '/_timedPress': 'comment' } }, null),
    {
      id: 'input-timing-steady-jitter-retired',
      schema: 'input-timing.schema.json',
      mutate: [{ file: 'data/input/timing.json', set: { '/read/steadyJitter': 4 } }],
      expect: { rule: 'additionalProperties', pointer: '/read/steadyJitter' },
    },
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`slice 11 schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('alchemy-flow')) {
    const line = t.split('\n').find((l) => l.includes('`alchemy-fighter`'));
    if (!line) throw new Error('slice 11 README anchor');
    t = t.replace(line, () => line + '\n| `alchemy-flow` | data/director/alchemy.json flow: launchAt is at most showcaseAt (an error); enderAfter, launchAt and showcaseAt above max are warnings (the flow never reaches them) |');
    fs.writeFileSync(f, t);
  }
}
