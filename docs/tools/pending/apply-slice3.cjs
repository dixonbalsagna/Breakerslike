// Schema keys for Encounter's agency slice 3 (the far taunt, the held charge, the meeting, the AI's reactions).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit that lands the slice's data:
//     node docs/tools/pending/apply-slice3.cjs
// It makes these keys required (the data lands in the same commit):
//   data/director/interrupts.json  bands.hysteresisBh (number, 0 or more); bands.taunt {enabled boolean, windowTicks integer, 1 or more};
//                                  bands.charge {light, heavy: each {holdTicks, speed, minTicks, maxTicks}}; bands.meet {speed, minTicks, maxTicks,
//                                  chargerEdge (number, 0 to 100: points off the attacker's chance)}; notes _edge and _far are allowed
//   data/director/ai.json          reactTicks, answerTicks (integers, 0 or more; the note _far is allowed); per level farTaunt, farCharge, farHeavy, answerTaunt
//                                  (chances, 0 to 1) and approachReact (three chances summing to at most 1)
// It adds the rules (bands-order: each approach's minTicks is at most its maxTicks and the light charge's holdTicks is below the heavy's;
// ai-approach-react: the three chances sum to at most 1), the validator fixtures (the interrupts and ai ones, built from these shapes) and the cases.
// It does NOT edit data/. Re-runnable (a second run changes nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const pos = { type: 'number', exclusiveMinimum: 0 };
const chance = { type: 'number', minimum: 0, maximum: 1 };

// the fixture values: Encounter's drafts are not in the tree yet, so these follow the shapes in the brief (the cases do not depend on the numbers)
const FX = {
  bands: { hysteresisBh: 0.5, taunt: { enabled: true, windowTicks: 60 }, charge: { light: { holdTicks: 30, speed: 4000, minTicks: 6, maxTicks: 90 }, heavy: { holdTicks: 60, speed: 4000, minTicks: 6, maxTicks: 90 } }, meet: { speed: 4000, minTicks: 3, maxTicks: 20, chargerEdge: 10 } },
  ai: { reactTicks: 12, answerTicks: 12, level: { farTaunt: 0.2, farCharge: 0.3, farHeavy: 0.3, answerTaunt: 0.5, approachReact: [0.4, 0.3, 0.2] } },
};

// =============================== interrupts schema ===============================
{
  const f = 'tools/schemas/director-interrupts.schema.json';
  const s = rj(f);
  const b = s.properties.bands;
  if (!b) throw new Error('bands is not in the interrupts schema (run the agency slice 2 schema first)');
  if (!b.properties.hysteresisBh) {
    const flight = (description) => obj({
      speed: Object.assign({ description: 'Units a second.' }, pos),
      minTicks: { type: 'integer', minimum: 1, description: 'At least this many whole ticks.' },
      maxTicks: { type: 'integer', minimum: 1, description: 'At most this many.' },
    }, { description });
    const hold = (description) => obj({
      holdTicks: { type: 'integer', minimum: 1, description: 'The ticks the press is held to count as a charge.' },
      speed: Object.assign({ description: 'Units a second.' }, pos),
      minTicks: { type: 'integer', minimum: 1 },
      maxTicks: { type: 'integer', minimum: 1 },
    }, { description });
    b.properties.hysteresisBh = { type: 'number', minimum: 0, description: 'The hysteresis, in body heights, at the edge of a band (Game Design\'s band rule): a pair that crossed a band edge must cross back by this much before it changes band again.' };
    b.properties.taunt = obj({ enabled: { type: 'boolean', description: 'The far taunt switch.' }, windowTicks: { type: 'integer', minimum: 1, description: 'The ticks the taunt\'s window stays open.' } }, { description: 'The far taunt.' });
    b.properties.charge = obj({ light: hold('The held light press\'s charged flight.'), heavy: hold('The held heavy press\'s charged flight.') }, { description: 'The held charge: a press held this long flies in on its own approach.' });
    b.properties.meet = flight('The meeting: both fighters closing on each other.');
    b.properties.meet.properties.chargerEdge = { type: 'number', minimum: 0, maximum: 100, description: 'Points off the attacker\'s chance when the rival is charging (the charger\'s edge); 0 to 100 (a share of 0 to 1 also fits).' };
    b.properties.meet.required.push('chargerEdge');
    for (const k of ['hysteresisBh', 'taunt', 'charge', 'meet']) if (!b.required.includes(k)) b.required.push(k);
    wj(f, s);
  }
}

// =============================== ai schema ===============================
{
  const f = 'tools/schemas/director-ai.schema.json';
  const s = rj(f);
  if (!s.properties.reactTicks) {
    s.properties.reactTicks = { type: 'integer', minimum: 0, description: 'Ticks the AI takes to react.' };
    s.properties.answerTicks = { type: 'integer', minimum: 0, description: 'Ticks the AI takes to answer.' };
    for (const k of ['reactTicks', 'answerTicks']) if (!s.required.includes(k)) s.required.push(k);
    for (const name of ['easy', 'medium', 'hard']) {
      const L = s.properties.levels.properties[name];
      L.properties.farTaunt = Object.assign({ description: 'The chance it taunts from far off.' }, chance);
      L.properties.farCharge = Object.assign({ description: 'The chance it holds a charge from far off.' }, chance);
      L.properties.farHeavy = Object.assign({ description: 'The chance a far press is a heavy.' }, chance);
      L.properties.answerTaunt = Object.assign({ description: 'The chance it answers a taunt.' }, chance);
      L.properties.approachReact = { type: 'array', minItems: 3, maxItems: 3, items: chance, description: 'Three chances for how it reacts to an approach; they sum to at most 1 (the rest: nothing).' };
      for (const k of ['farTaunt', 'farCharge', 'farHeavy', 'answerTaunt', 'approachReact']) if (!L.required.includes(k)) L.required.push(k);
    }
    wj(f, s);
  }
}

// =============================== fixtures ===============================
{
  const dir = 'tools/fixtures/virtual/data/director/';
  {
    const f = dir + 'interrupts.json';
    const o = rj(f);
    if (o.bands && o.bands.hysteresisBh === undefined) {
      o.bands = Object.assign({}, o.bands, JSON.parse(JSON.stringify(FX.bands)));
      wj(f, o);
    }
  }
  {
    const f = dir + 'ai.json';
    const o = rj(f);
    if (o.reactTicks === undefined) {
      const out = {};
      for (const k of Object.keys(o)) { out[k] = o[k]; if (k === 'sigPick') { out.reactTicks = FX.ai.reactTicks; out.answerTicks = FX.ai.answerTicks; } }
      if (out.reactTicks === undefined) { out.reactTicks = FX.ai.reactTicks; out.answerTicks = FX.ai.answerTicks; }
      for (const name of ['easy', 'medium', 'hard']) Object.assign(out.levels[name], JSON.parse(JSON.stringify(FX.ai.level)));
      wj(f, out);
    }
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'ai-approach-react'")) {
    // bands: the new approaches and the hold order
    const a = "      for (const [path, o] of [['lunge', bd.lunge], ['far/light', isObj(bd.far) ? bd.far.light : undefined], ['far/heavy', isObj(bd.far) ? bd.far.heavy : undefined]])";
    if (!t.includes(a)) throw new Error('bands anchor');
    t = t.replace(a, () => "      for (const [path, o] of [['lunge', bd.lunge], ['far/light', isObj(bd.far) ? bd.far.light : undefined], ['far/heavy', isObj(bd.far) ? bd.far.heavy : undefined], ['charge/light', isObj(bd.charge) ? bd.charge.light : undefined], ['charge/heavy', isObj(bd.charge) ? bd.charge.heavy : undefined], ['meet', bd.meet]])");
    const b = "      if (typeof bd.engageBh === 'number' && typeof bd.closeBh === 'number' && bd.engageBh > bd.closeBh)";
    if (!t.includes(b)) throw new Error('bands anchor 2');
    t = t.replace(b, () => [
      "      if (isObj(bd.charge) && isObj(bd.charge.light) && isObj(bd.charge.heavy) && typeof bd.charge.light.holdTicks === 'number' && typeof bd.charge.heavy.holdTicks === 'number' && bd.charge.light.holdTicks >= bd.charge.heavy.holdTicks) err(IT, '/bands/charge/light/holdTicks', 'bands-order', `the light charge's holdTicks ${bd.charge.light.holdTicks} is not below the heavy's ${bd.charge.heavy.holdTicks}`);",
      b,
    ].join('\n'));
    // ai: the approach reaction's chances sum to at most 1
    const c = "    const med = isObj(lv.medium) ? lv.medium.beamAnswer : undefined;";
    if (!t.includes(c)) throw new Error('ai anchor');
    t = t.replace(c, () => [
      "    for (const name of order) { const ar = isObj(lv[name]) ? lv[name].approachReact : undefined; if (Array.isArray(ar) && ar.every((x) => typeof x === 'number') && ar.reduce((s2, x) => s2 + x, 0) > 1 + 1e-9) err(AI, `/levels/${name}/approachReact`, 'ai-approach-react', `the three chances sum to ${ar.reduce((s2, x) => s2 + x, 0).toFixed(3)}, more than 1`); }",
      c,
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
  const flight = (over) => Object.assign({ speed: 4000, minTicks: 3, maxTicks: 20, chargerEdge: 10 }, over);
  const hold = (over) => Object.assign({ holdTicks: 30, speed: 4000, minTicks: 6, maxTicks: 90 }, over);
  const bd = (n, mut, expect) => ({ id: 'director-interrupts-bands-' + n, schema: 'director-interrupts.schema.json', mutate: [{ file: I, ...mut }], expect });
  const ai = (n, mut, expect) => ({ id: 'director-ai-' + n, schema: 'director-ai.schema.json', mutate: [{ file: A, ...mut }], expect });
  const add = [
    // bands: edgeSlackBh, taunt, charge, meet
    bd('hysteresis-required', { del: ['/bands/hysteresisBh'] }, { rule: 'required', pointer: '/bands' }),
    bd('hysteresis-negative', { set: { '/bands/hysteresisBh': -1 } }, { rule: 'minimum', pointer: '/bands/hysteresisBh' }),
    bd('hysteresis-zero-ok', { set: { '/bands/hysteresisBh': 0 } }, null),
    bd('hysteresis-type', { set: { '/bands/hysteresisBh': 'some' } }, { rule: 'type', pointer: '/bands/hysteresisBh' }),
    bd('edge-slack-retired', { set: { '/bands/edgeSlackBh': 0.5 } }, { rule: 'additionalProperties', pointer: '/bands/edgeSlackBh' }),
    bd('notes-ok', { set: { '/bands/_edge': 'comment', '/bands/_far': 'comment' } }, null),
    bd('taunt-required', { del: ['/bands/taunt'] }, { rule: 'required', pointer: '/bands' }),
    bd('taunt-key-required', { set: { '/bands/taunt': { enabled: true } } }, { rule: 'required', pointer: '/bands/taunt' }),
    bd('taunt-enabled-type', { set: { '/bands/taunt/enabled': 'yes' } }, { rule: 'type', pointer: '/bands/taunt/enabled' }),
    bd('taunt-window-positive', { set: { '/bands/taunt/windowTicks': 0 } }, { rule: 'minimum', pointer: '/bands/taunt/windowTicks' }),
    bd('taunt-window-integer', { set: { '/bands/taunt/windowTicks': 60.5 } }, { rule: 'type', pointer: '/bands/taunt/windowTicks' }),
    bd('taunt-unknown-key', { set: { '/bands/taunt/mocking': 1 } }, { rule: 'additionalProperties', pointer: '/bands/taunt/mocking' }),
    bd('taunt-off-ok', { set: { '/bands/taunt/enabled': false } }, null),
    bd('charge-required', { del: ['/bands/charge'] }, { rule: 'required', pointer: '/bands' }),
    bd('charge-weight-required', { set: { '/bands/charge': { light: hold() } } }, { rule: 'required', pointer: '/bands/charge' }),
    bd('charge-unknown-weight', { set: { '/bands/charge': { light: hold(), heavy: hold({ holdTicks: 60 }), medium: hold() } } }, { rule: 'additionalProperties', pointer: '/bands/charge/medium' }),
    bd('charge-key-required', { set: { '/bands/charge/light': { speed: 4000, minTicks: 6, maxTicks: 90 } } }, { rule: 'required', pointer: '/bands/charge/light' }),
    bd('charge-hold-positive', { set: { '/bands/charge/light/holdTicks': 0 } }, { rule: 'minimum', pointer: '/bands/charge/light/holdTicks' }),
    bd('charge-speed-positive', { set: { '/bands/charge/heavy/speed': 0 } }, { rule: 'exclusiveMinimum', pointer: '/bands/charge/heavy/speed' }),
    bd('charge-ticks-integer', { set: { '/bands/charge/light/minTicks': 6.5 } }, { rule: 'type', pointer: '/bands/charge/light/minTicks' }),
    bd('charge-light-min-above-max', { set: { '/bands/charge/light/minTicks': 100 } }, { rule: 'xref:bands-order', pointer: '/bands/charge/light/minTicks' }),
    bd('charge-heavy-min-above-max', { set: { '/bands/charge/heavy/minTicks': 100 } }, { rule: 'xref:bands-order', pointer: '/bands/charge/heavy/minTicks' }),
    bd('charge-hold-order', { set: { '/bands/charge/light/holdTicks': 90 } }, { rule: 'xref:bands-order', pointer: '/bands/charge/light/holdTicks' }),
    bd('charge-hold-equal', { set: { '/bands/charge/light/holdTicks': 60 } }, { rule: 'xref:bands-order', pointer: '/bands/charge/light/holdTicks' }),
    bd('meet-required', { del: ['/bands/meet'] }, { rule: 'required', pointer: '/bands' }),
    bd('meet-key-required', { set: { '/bands/meet': { speed: 4000, minTicks: 3, chargerEdge: 10 } } }, { rule: 'required', pointer: '/bands/meet' }),
    bd('charger-edge-required', { set: { '/bands/meet': { speed: 4000, minTicks: 3, maxTicks: 20 } } }, { rule: 'required', pointer: '/bands/meet' }),
    bd('charger-edge-points-ok', { set: { '/bands/meet/chargerEdge': 100 } }, null),
    bd('charger-edge-share-ok', { set: { '/bands/meet/chargerEdge': 0.1 } }, null),
    bd('charger-edge-zero-ok', { set: { '/bands/meet/chargerEdge': 0 } }, null),
    bd('charger-edge-above-100', { set: { '/bands/meet/chargerEdge': 120 } }, { rule: 'maximum', pointer: '/bands/meet/chargerEdge' }),
    bd('charger-edge-negative', { set: { '/bands/meet/chargerEdge': -5 } }, { rule: 'minimum', pointer: '/bands/meet/chargerEdge' }),
    bd('charger-edge-type', { set: { '/bands/meet/chargerEdge': 'ten' } }, { rule: 'type', pointer: '/bands/meet/chargerEdge' }),
    bd('meet-speed-positive', { set: { '/bands/meet': flight({ speed: 0 }) } }, { rule: 'exclusiveMinimum', pointer: '/bands/meet/speed' }),
    bd('meet-min-above-max', { set: { '/bands/meet': flight({ minTicks: 30 }) } }, { rule: 'xref:bands-order', pointer: '/bands/meet/minTicks' }),
    bd('meet-equal-ticks-ok', { set: { '/bands/meet': flight({ minTicks: 20 }) } }, null),
    // ai
    ai('far-note-ok', { set: { '/_far': 'comment' } }, null),
    ai('react-ticks-required', { del: ['/reactTicks'] }, { rule: 'required', pointer: '' }),
    ai('answer-ticks-required', { del: ['/answerTicks'] }, { rule: 'required', pointer: '' }),
    ai('react-ticks-negative', { set: { '/reactTicks': -1 } }, { rule: 'minimum', pointer: '/reactTicks' }),
    ai('react-ticks-integer', { set: { '/reactTicks': 12.5 } }, { rule: 'type', pointer: '/reactTicks' }),
    ai('answer-ticks-zero-ok', { set: { '/answerTicks': 0 } }, null),
    ai('far-taunt-required', { del: ['/levels/easy/farTaunt'] }, { rule: 'required', pointer: '/levels/easy' }),
    ai('far-charge-required', { del: ['/levels/medium/farCharge'] }, { rule: 'required', pointer: '/levels/medium' }),
    ai('far-heavy-required', { del: ['/levels/hard/farHeavy'] }, { rule: 'required', pointer: '/levels/hard' }),
    ai('answer-taunt-required', { del: ['/levels/easy/answerTaunt'] }, { rule: 'required', pointer: '/levels/easy' }),
    ai('approach-react-required', { del: ['/levels/hard/approachReact'] }, { rule: 'required', pointer: '/levels/hard' }),
    ai('far-taunt-range', { set: { '/levels/easy/farTaunt': 1.5 } }, { rule: 'maximum', pointer: '/levels/easy/farTaunt' }),
    ai('far-charge-negative', { set: { '/levels/medium/farCharge': -0.1 } }, { rule: 'minimum', pointer: '/levels/medium/farCharge' }),
    ai('far-heavy-type', { set: { '/levels/hard/farHeavy': 'often' } }, { rule: 'type', pointer: '/levels/hard/farHeavy' }),
    ai('answer-taunt-range', { set: { '/levels/hard/answerTaunt': 2 } }, { rule: 'maximum', pointer: '/levels/hard/answerTaunt' }),
    ai('approach-react-length', { set: { '/levels/easy/approachReact': [0.4, 0.3] } }, { rule: 'minItems', pointer: '/levels/easy/approachReact' }),
    ai('approach-react-too-long', { set: { '/levels/easy/approachReact': [0.2, 0.2, 0.2, 0.2] } }, { rule: 'maxItems', pointer: '/levels/easy/approachReact' }),
    ai('approach-react-chance-range', { set: { '/levels/easy/approachReact': [0.4, 1.5, 0.1] } }, { rule: 'maximum', pointer: '/levels/easy/approachReact/1' }),
    ai('approach-react-sum-ok', { set: { '/levels/easy/approachReact': [0.5, 0.3, 0.2] } }, null),
    ai('approach-react-sum-above-one', { set: { '/levels/easy/approachReact': [0.5, 0.4, 0.3] } }, { rule: 'xref:ai-approach-react', pointer: '/levels/easy/approachReact' }),
    ai('approach-react-sum-above-one-hard', { set: { '/levels/hard/approachReact': [1, 1, 1] } }, { rule: 'xref:ai-approach-react', pointer: '/levels/hard/approachReact' }),
    ai('approach-react-all-zero-ok', { set: { '/levels/medium/approachReact': [0, 0, 0] } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  // the earlier bands cases build the whole block; it now needs the slice 3 keys too (a case that expects the block to be incomplete keeps it so)
  for (const k of c.cases) {
    if (!k.id.startsWith('director-interrupts-bands-')) continue;
    const bo = k.mutate && k.mutate[0] && k.mutate[0].set && k.mutate[0].set['/bands'];
    if (bo && typeof bo === 'object' && bo.hysteresisBh === undefined && !(k.expect && k.expect.rule === 'required' && k.expect.pointer === '/bands')) Object.assign(bo, JSON.parse(JSON.stringify(FX.bands)));
  }
  wj(cf, c);
  console.log(`slice 3 schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('ai-approach-react')) {
    t = t.replace('| `bands-order` | data/director/interrupts.json bands (the ranged press): engageBh is at most closeBh, closeBh is below midBh, and each approach\'s minTicks is at most its maxTicks |', () => '| `bands-order` | data/director/interrupts.json bands (the ranged press): engageBh is at most closeBh, closeBh is below midBh, each approach\'s minTicks (lunge, far, charge, meet) is at most its maxTicks, and the light charge\'s holdTicks is below the heavy\'s |\n| `ai-approach-react` | data/director/ai.json: each level\'s three approachReact chances sum to at most 1 |');
    fs.writeFileSync(f, t);
  }
}
