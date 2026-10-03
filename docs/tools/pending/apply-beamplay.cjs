// Schema keys for Encounter's slice 8, the beam plays (docs/director/pending/agency8/agency-slice-8.md "Data keys for Tools";
// docs/director/update-apply-order.md step 1). NOT run by CI, the validator or the sim. Run once from the repo root, in the commit that lands
// the slice's data: node docs/tools/pending/apply-beamplay.cjs
// It does NOT edit data/. It adds:
//   data/director/interrupts.json  perfectBlock.windows.beam (integer, 0 or more; optional like the other window classes) and the required
//                                  top-level beamPlays {enabled, travelTicks, afterTicks, dodge, late, walk, split, swat} (closed; _note allowed)
//   data/director/ai.json          per level beamDodge, beamWade, beamLate (chances) and the required top-level beamLook {split, walk, swat}
//                                  (weights; _beam allowed)
// the two validator fixtures, rules beamplays-order, beamplays-split and ai-beam-look, `beam` in the oneArmedOff window check, the three
// beam chances in the levels-order check, and the cases. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const chance = { type: 'number', minimum: 0, maximum: 1 };
const ticks0 = (d) => ({ type: 'integer', minimum: 0, description: d });
const ticks1 = (d) => ({ type: 'integer', minimum: 1, description: d });
const deg = (d) => ({ type: 'number', minimum: 0, maximum: 90, description: d });
const pos = (d) => ({ type: 'number', exclusiveMinimum: 0, description: d });

// the brief's own values (agency-slice-8.md), used for the fixtures until the live data carries them
const FX = {
  beam: 12,
  beamPlays: {
    enabled: true,
    travelTicks: 20,
    afterTicks: 42,
    dodge: { beforeTicks: 14, afterTicks: 6 },
    late: { ticks: 20, scoreAdd: -10 },
    walk: { speed: 3000, minTicks: 24, maxTicks: 54, recoverTicks: 20 },
    split: { spreadDeg: 14, lenBh: 12, widthMul: 0.5, powerMul: 0.6 },
    swat: { lenBh: 30, skyDeg: 50, groundDeg: 20 },
  },
  level: { easy: { beamDodge: 0.4, beamWade: 0.3, beamLate: 0.05 }, medium: { beamDodge: 0.55, beamWade: 0.5, beamLate: 0.1 }, hard: { beamDodge: 0.7, beamWade: 0.7, beamLate: 0.2 } },
  beamLook: { split: 1.0, walk: 1.0, swat: 1.0 },
};
const live = (f) => (fs.existsSync(f) ? rj(f) : null);
const liveInt = live('data/director/interrupts.json');
const liveAi = live('data/director/ai.json');
const haveInt = liveInt && liveInt.beamPlays;
const haveAi = liveAi && liveAi.beamLook;
const clone = (o) => JSON.parse(JSON.stringify(o));

// =============================== interrupts schema ===============================
{
  const f = 'tools/schemas/director-interrupts.schema.json';
  const s = rj(f);
  if (!s.properties.beamPlays) {
    s.properties.perfectBlock.properties.windows.properties.beam = ticks0('The last ticks of a beam\'s tell in which a fresh guard press is a perfect block against it.');
    s.properties.beamPlays = obj({
      enabled: { type: 'boolean', description: 'false: a beam is decided at its fire beat, as before.' },
      travelTicks: ticks1('A signature not answered in its tell reaches the defender this many ticks after it fires, at any distance.'),
      afterTicks: ticks0('The exchange\'s length after that.'),
      dodge: obj({ beforeTicks: ticks0('A dodge tap in the last ticks of the tell avoids the beam.'), afterTicks: ticks0('A dodge tap in the first ticks of the beam avoids it.') }),
      late: obj({ ticks: ticks0('The defender\'s own signature or heavy energy attack within this many ticks of the fire stops the beam in a struggle.'), scoreAdd: { type: 'number', description: 'Added to the defender\'s score in that struggle.' } }),
      walk: obj({ speed: pos('Units a second he advances through the beam.'), minTicks: ticks1('The shortest walk.'), maxTicks: ticks1('The longest walk.'), recoverTicks: ticks0('Recovery left to the attacker when he arrives.') }),
      split: obj({ spreadDeg: deg('Degrees either side of the beam\'s line the two lesser beams leave.'), lenBh: pos('Their length, in body heights.'), widthMul: pos('Their width, as a share of the beam\'s.'), powerMul: pos('Their power, as a share of the beam\'s.') }),
      swat: obj({ lenBh: pos('The turned beam\'s length, in body heights.'), skyDeg: deg('A fighter with an anguish meter sends it up at this angle.'), groundDeg: deg('Anyone else sends it down at this angle.') }),
    }, { description: 'The beam plays (agency-pass.md section 5; sim/director/beamplay.gd): how a signature that reaches a defender plays out.' });
    s.required.push('beamPlays');
    s.description = s.description.replace('Orders (', () => 'Orders (a walk\'s minTicks at most its maxTicks; the split\'s width and power shares at most 1, a warning; ');
    wj(f, s);
  }
}

// =============================== ai schema ===============================
{
  const f = 'tools/schemas/director-ai.schema.json';
  const s = rj(f);
  if (!s.properties.beamLook) {
    for (const name of ['easy', 'medium', 'hard']) {
      const L = s.properties.levels.properties[name];
      L.properties.beamDodge = Object.assign({ description: 'The chance its dodge is in time when it is dodging a beam.' }, chance);
      L.properties.beamWade = Object.assign({ description: 'The chance it holds toward when it guards a beam (the wade).' }, chance);
      L.properties.beamLate = Object.assign({ description: 'The chance of a late answer when it did not answer in the tell and can pay for one.' }, chance);
      for (const k of ['beamDodge', 'beamWade', 'beamLate']) if (!L.required.includes(k)) L.required.push(k);
    }
    s.properties.beamLook = obj({
      split: { type: 'number', minimum: 0, description: 'The weight of the split look of a perfect block against a beam.' },
      walk: { type: 'number', minimum: 0, description: 'The weight of the walk-through look.' },
      swat: { type: 'number', minimum: 0, description: 'The weight of the swat look.' },
    }, { description: 'The weights of the look of the AI\'s perfect block against a beam (rule-of-cool.md section 2).' });
    s.required.push('beamLook');
    wj(f, s);
  }
}

// =============================== fixtures ===============================
{
  const dir = 'tools/fixtures/virtual/data/director/';
  {
    const f = dir + 'interrupts.json';
    const o = rj(f);
    if (o.beamPlays === undefined) {
      if (o.perfectBlock && o.perfectBlock.windows) o.perfectBlock.windows.beam = haveInt ? liveInt.perfectBlock.windows.beam : FX.beam;
      const src = haveInt ? Object.fromEntries(Object.entries(liveInt.beamPlays).filter(([k]) => !k.startsWith('_'))) : clone(FX.beamPlays);
      const out = {};
      for (const k of Object.keys(o)) { out[k] = o[k]; if (k === 'perfectBlock') out.beamPlays = src; }
      if (out.beamPlays === undefined) out.beamPlays = src;
      wj(f, out);
    }
  }
  {
    const f = dir + 'ai.json';
    const o = rj(f);
    if (o.beamLook === undefined) {
      for (const name of ['easy', 'medium', 'hard']) Object.assign(o.levels[name], haveAi ? Object.fromEntries(['beamDodge', 'beamWade', 'beamLate'].map((k) => [k, liveAi.levels[name][k]])) : clone(FX.level[name]));
      o.beamLook = haveAi ? clone(liveAi.beamLook) : clone(FX.beamLook);
      wj(f, o);
    }
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'beamplays-order'")) {
    // the window check knows the beam window
    const a = "['return', w.return]];";
    if (!t.includes(a)) throw new Error('window anchor');
    t = t.replace(a, () => "['return', w.return], ['beam', w.beam]];");
    // the levels-order check covers the beam chances
    const b = "'earnerUse', 'buriedFollowUp', 'barrageGuard']) {";
    if (!t.includes(b)) throw new Error('levels anchor');
    t = t.replace(b, () => "'earnerUse', 'buriedFollowUp', 'barrageGuard', 'beamDodge', 'beamWade', 'beamLate']) {");
    // the beam look's weights: something to draw
    const c = "    const med = isObj(lv.medium) ? lv.medium.beamAnswer : undefined;";
    if (!t.includes(c)) throw new Error('ai anchor');
    t = t.replace(c, () => [
      "    if (isObj(dai.beamLook) && Object.entries(dai.beamLook).filter(([k]) => !k.startsWith('_')).every(([, v]) => typeof v === 'number') && Object.entries(dai.beamLook).filter(([k]) => !k.startsWith('_')).reduce((s2, [, v]) => s2 + v, 0) <= 0) err(AI, '/beamLook', 'ai-beam-look', 'the three weights of beamLook sum to 0, so a perfect block against a beam has no look to draw');",
      c,
    ].join('\n'));
    // the beam plays
    const d = "    const dcI = itr.dodgeCancel;";
    if (!t.includes(d)) throw new Error('interrupts anchor');
    t = t.replace(d, () => [
      "    const bpl = itr.beamPlays;",
      "    if (isObj(bpl)) {",
      "      if (isObj(bpl.walk) && typeof bpl.walk.minTicks === 'number' && typeof bpl.walk.maxTicks === 'number' && bpl.walk.minTicks > bpl.walk.maxTicks) err(IT, '/beamPlays/walk/minTicks', 'beamplays-order', `walk minTicks ${bpl.walk.minTicks} is above maxTicks ${bpl.walk.maxTicks}`);",
      "      if (isObj(bpl.split)) for (const k of ['widthMul', 'powerMul']) if (typeof bpl.split[k] === 'number' && bpl.split[k] > 1) err(IT, `/beamPlays/split/${k}`, 'beamplays-split', `the split beams' ${k} ${bpl.split[k]} is above 1; they are meant to be lesser than the beam`, 'warning');",
      "    }",
      d,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const I = 'data/director/interrupts.json';
  const A = 'data/director/ai.json';
  const it = (n, mut, expect) => ({ id: 'director-interrupts-' + n, schema: 'director-interrupts.schema.json', mutate: [{ file: I, ...mut }], expect });
  const ai = (n, mut, expect) => ({ id: 'director-ai-' + n, schema: 'director-ai.schema.json', mutate: [{ file: A, ...mut }], expect });
  const B = '/beamPlays/';
  const add = [
    it('window-beam-ok', { set: { '/perfectBlock/windows/beam': 12 } }, null),
    it('window-beam-optional', { del: ['/perfectBlock/windows/beam'] }, null),
    it('window-beam-negative', { set: { '/perfectBlock/windows/beam': -1 } }, { rule: 'minimum', pointer: '/perfectBlock/windows/beam' }),
    it('window-beam-integer', { set: { '/perfectBlock/windows/beam': 12.5 } }, { rule: 'type', pointer: '/perfectBlock/windows/beam' }),
    it('window-beam-within-one-armed', { set: { '/perfectBlock/windows/beam': 1 } }, { rule: 'xref:interrupts-order', pointer: '/perfectBlock/oneArmedOff' }),
    it('beam-plays-required', { del: ['/beamPlays'] }, { rule: 'required', pointer: '' }),
    it('beam-plays-key-required', { del: [B + 'walk'] }, { rule: 'required', pointer: '/beamPlays' }),
    it('beam-plays-unknown-key', { set: { [B + 'sneeze']: 1 } }, { rule: 'additionalProperties', pointer: B + 'sneeze' }),
    it('beam-plays-note-ok', { set: { [B + '_note']: 'comment' } }, null),
    it('beam-plays-enabled-type', { set: { [B + 'enabled']: 'yes' } }, { rule: 'type', pointer: B + 'enabled' }),
    it('beam-plays-disabled-ok', { set: { [B + 'enabled']: false } }, null),
    it('beam-travel-zero', { set: { [B + 'travelTicks']: 0 } }, { rule: 'minimum', pointer: B + 'travelTicks' }),
    it('beam-travel-integer', { set: { [B + 'travelTicks']: 20.5 } }, { rule: 'type', pointer: B + 'travelTicks' }),
    it('beam-after-negative', { set: { [B + 'afterTicks']: -1 } }, { rule: 'minimum', pointer: B + 'afterTicks' }),
    it('beam-after-zero-ok', { set: { [B + 'afterTicks']: 0 } }, null),
    it('beam-dodge-key-required', { del: [B + 'dodge/beforeTicks'] }, { rule: 'required', pointer: B + 'dodge' }),
    it('beam-dodge-negative', { set: { [B + 'dodge/afterTicks']: -1 } }, { rule: 'minimum', pointer: B + 'dodge/afterTicks' }),
    it('beam-dodge-unknown-key', { set: { [B + 'dodge/extra']: 1 } }, { rule: 'additionalProperties', pointer: B + 'dodge/extra' }),
    it('beam-late-key-required', { del: [B + 'late/scoreAdd'] }, { rule: 'required', pointer: B + 'late' }),
    it('beam-late-ticks-negative', { set: { [B + 'late/ticks']: -1 } }, { rule: 'minimum', pointer: B + 'late/ticks' }),
    it('beam-late-score-type', { set: { [B + 'late/scoreAdd']: 'low' } }, { rule: 'type', pointer: B + 'late/scoreAdd' }),
    it('beam-late-score-positive-ok', { set: { [B + 'late/scoreAdd']: 10 } }, null),
    it('beam-walk-key-required', { del: [B + 'walk/recoverTicks'] }, { rule: 'required', pointer: B + 'walk' }),
    it('beam-walk-speed-zero', { set: { [B + 'walk/speed']: 0 } }, { rule: 'exclusiveMinimum', pointer: B + 'walk/speed' }),
    it('beam-walk-min-zero', { set: { [B + 'walk/minTicks']: 0 } }, { rule: 'minimum', pointer: B + 'walk/minTicks' }),
    it('beam-walk-max-integer', { set: { [B + 'walk/maxTicks']: 54.5 } }, { rule: 'type', pointer: B + 'walk/maxTicks' }),
    it('beam-walk-recover-negative', { set: { [B + 'walk/recoverTicks']: -1 } }, { rule: 'minimum', pointer: B + 'walk/recoverTicks' }),
    it('beam-walk-min-above-max', { set: { [B + 'walk/minTicks']: 60 } }, { rule: 'xref:beamplays-order', pointer: B + 'walk/minTicks' }),
    it('beam-walk-min-equals-max-ok', { set: { [B + 'walk/minTicks']: 54 } }, null),
    it('beam-split-key-required', { del: [B + 'split/powerMul'] }, { rule: 'required', pointer: B + 'split' }),
    it('beam-split-spread-range', { set: { [B + 'split/spreadDeg']: 120 } }, { rule: 'maximum', pointer: B + 'split/spreadDeg' }),
    it('beam-split-spread-negative', { set: { [B + 'split/spreadDeg']: -1 } }, { rule: 'minimum', pointer: B + 'split/spreadDeg' }),
    it('beam-split-length-zero', { set: { [B + 'split/lenBh']: 0 } }, { rule: 'exclusiveMinimum', pointer: B + 'split/lenBh' }),
    it('beam-split-width-zero', { set: { [B + 'split/widthMul']: 0 } }, { rule: 'exclusiveMinimum', pointer: B + 'split/widthMul' }),
    it('beam-split-width-above-one-warns', { set: { [B + 'split/widthMul']: 1.5 } }, { rule: 'xref:beamplays-split', pointer: B + 'split/widthMul' }),
    it('beam-split-power-above-one-warns', { set: { [B + 'split/powerMul']: 1.2 } }, { rule: 'xref:beamplays-split', pointer: B + 'split/powerMul' }),
    it('beam-split-edges-ok', { set: { [B + 'split/widthMul']: 1, [B + 'split/powerMul']: 1 } }, null),
    it('beam-swat-key-required', { del: [B + 'swat/groundDeg'] }, { rule: 'required', pointer: B + 'swat' }),
    it('beam-swat-length-zero', { set: { [B + 'swat/lenBh']: 0 } }, { rule: 'exclusiveMinimum', pointer: B + 'swat/lenBh' }),
    it('beam-swat-sky-range', { set: { [B + 'swat/skyDeg']: 100 } }, { rule: 'maximum', pointer: B + 'swat/skyDeg' }),
    it('beam-swat-ground-negative', { set: { [B + 'swat/groundDeg']: -5 } }, { rule: 'minimum', pointer: B + 'swat/groundDeg' }),
    ai('beam-dodge-required', { del: ['/levels/easy/beamDodge'] }, { rule: 'required', pointer: '/levels/easy' }),
    ai('beam-wade-required', { del: ['/levels/medium/beamWade'] }, { rule: 'required', pointer: '/levels/medium' }),
    ai('beam-late-required', { del: ['/levels/hard/beamLate'] }, { rule: 'required', pointer: '/levels/hard' }),
    ai('beam-dodge-range', { set: { '/levels/easy/beamDodge': 1.5 } }, { rule: 'maximum', pointer: '/levels/easy/beamDodge' }),
    ai('beam-wade-negative', { set: { '/levels/medium/beamWade': -0.1 } }, { rule: 'minimum', pointer: '/levels/medium/beamWade' }),
    ai('beam-late-type', { set: { '/levels/hard/beamLate': 'often' } }, { rule: 'type', pointer: '/levels/hard/beamLate' }),
    ai('beam-dodge-harder-level-lower-warns', { set: { '/levels/hard/beamDodge': 0.2 } }, { rule: 'xref:ai-levels-order', pointer: '/levels/hard/beamDodge' }),
    ai('beam-late-harder-level-lower-warns', { set: { '/levels/medium/beamLate': 0.01 } }, { rule: 'xref:ai-levels-order', pointer: '/levels/medium/beamLate' }),
    ai('beam-look-required', { del: ['/beamLook'] }, { rule: 'required', pointer: '' }),
    ai('beam-look-key-required', { del: ['/beamLook/swat'] }, { rule: 'required', pointer: '/beamLook' }),
    ai('beam-look-unknown-key', { set: { '/beamLook/dive': 1 } }, { rule: 'additionalProperties', pointer: '/beamLook/dive' }),
    ai('beam-look-negative', { set: { '/beamLook/walk': -1 } }, { rule: 'minimum', pointer: '/beamLook/walk' }),
    ai('beam-look-type', { set: { '/beamLook/split': 'half' } }, { rule: 'type', pointer: '/beamLook/split' }),
    ai('beam-look-weights-above-one-ok', { set: { '/beamLook/split': 3 } }, null),
    ai('beam-look-one-weight-ok', { set: { '/beamLook': { split: 0, walk: 1, swat: 0 } } }, null),
    ai('beam-look-all-zero', { set: { '/beamLook': { split: 0, walk: 0, swat: 0 } } }, { rule: 'xref:ai-beam-look', pointer: '/beamLook' }),
    ai('beam-note-ok', { set: { '/_beam': 'comment' } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`beam plays schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('beamplays-order')) {
    const line = t.split('\n').find((l) => l.includes('`ai-approach-react`')) || t.split('\n').find((l) => l.includes('`ai-level`'));
    if (!line) throw new Error('beamplay README anchor');
    t = t.replace(line, () => line + '\n| `beamplays-order`, `beamplays-split`, `ai-beam-look` | data/director/interrupts.json beamPlays: a walk\'s minTicks is at most its maxTicks; the split beams\' widthMul and powerMul above 1 are a warning; the perfect-block window `beam` counts in the one-armed check. data/director/ai.json: the three weights of beamLook do not all sum to 0; the beam chances (beamDodge, beamWade, beamLate) join the levels-order check |');
    fs.writeFileSync(f, t);
  }
}
