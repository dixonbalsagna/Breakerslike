// M1b schema changes for Simulation's mood and style data (docs/architecture/mood-style.md). NOT run by CI, the validator or the sim.
// Run from the repo root, in the same commit that lands the M1b data: node docs/tools/pending/apply-m1b.cjs
// Re-runnable: every edit sets a value or checks before adding, so a second run changes nothing. See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const nonNeg = { type: 'integer', minimum: 0 };

// ---------------- fight-mood: rates.proportional and actBeats ----------------
{
  const f = 'tools/schemas/fight-mood.schema.json';
  const s = rj(f);
  const rates = s.properties.rates;
  rates.properties.proportional = {
    type: 'object',
    required: ['on', 'base', 'perMille'],
    description: 'A rate that grows with the mood (M1b): on switches it, base and perMille are integers of at least 0.',
    properties: { on: { type: 'boolean' }, base: nonNeg, perMille: nonNeg },
    additionalProperties: false,
    patternProperties: { '^_': true },
  };
  if (!rates.required.includes('proportional')) rates.required.push('proportional');
  s.properties.actBeats = {
    type: 'object',
    required: ['every', 'oncePerMatch'],
    description: 'Which events raise the act: every occurrence, or once per match.',
    properties: {
      every: { type: 'array', uniqueItems: true, items: { enum: ['regionBreak', 'form'] } },
      oncePerMatch: { type: 'array', uniqueItems: true, items: { enum: ['limbBattered', 'coreBruised', 'coreBattered'] } },
    },
    additionalProperties: false,
    patternProperties: { '^_': true },
  };
  if (!s.required.includes('actBeats')) s.required.push('actBeats');
  wj(f, s);
}

// ---------------- fight-mood: impulses.landmarkFall becomes required (it is already an optional property) ----------------
{
  const f = 'tools/schemas/fight-mood.schema.json';
  const s = rj(f);
  s.properties.impulses.properties.landmarkFall = { type: 'integer', minimum: 0, description: 'The mood impulse for a landmark falling (600 units is +10 points); dormant until D1.' };
  if (!s.properties.impulses.required.includes('landmarkFall')) s.properties.impulses.required.push('landmarkFall');
  wj(f, s);
  const g = 'tools/fixtures/virtual/data/fight/mood.json';
  const d = rj(g);
  d.impulses.landmarkFall = 600;
  wj(g, d);
}

// ---------------- fight-style: minHeldS; qaBands stays open ----------------
{
  const f = 'tools/schemas/fight-style.schema.json';
  const s = rj(f);
  s.properties.minHeldS = { type: 'integer', minimum: 0, description: 'The shortest time a label is held before it may change (M1b).' };
  if (!s.required.includes('minHeldS')) s.required.push('minHeldS');
  // qaBands is an open object, so Narrative's nested form (judgedOnAI, judgedOnHumanOrScriptedPlay) and the flat form both pass.
  s.properties.qaBands = { type: 'object' };
  wj(f, s);
}

// ---------------- virtual fixtures ----------------
{
  const f = 'tools/fixtures/virtual/data/fight/mood.json';
  const d = rj(f);
  d.rates.proportional = { on: true, base: 0, perMille: 50 };
  d.actBeats = { every: ['regionBreak', 'form'], oncePerMatch: ['limbBattered', 'coreBruised', 'coreBattered'] };
  wj(f, d);
  const g = 'tools/fixtures/virtual/data/fight/style.json';
  const st = rj(g);
  st.minHeldS = 10;
  wj(g, st);
}

// ---------------- cases (skipped when already present) ----------------
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const M = 'data/fight/mood.json';
  const ST = 'data/fight/style.json';
  const add = [
    { id: 'mood-proportional-required', schema: 'fight-mood.schema.json', mutate: [{ file: M, del: ['/rates/proportional'] }], expect: { rule: 'required', pointer: '/rates' } },
    { id: 'mood-proportional-type', schema: 'fight-mood.schema.json', mutate: [{ file: M, set: { '/rates/proportional/on': 'yes' } }], expect: { rule: 'type', pointer: '/rates/proportional/on' } },
    { id: 'mood-proportional-fraction', schema: 'fight-mood.schema.json', mutate: [{ file: M, set: { '/rates/proportional/perMille': 12.5 } }], expect: { rule: 'type', pointer: '/rates/proportional/perMille' } },
    { id: 'mood-act-beats-required', schema: 'fight-mood.schema.json', mutate: [{ file: M, del: ['/actBeats'] }], expect: { rule: 'required', pointer: '' } },
    { id: 'mood-act-beats-every-enum', schema: 'fight-mood.schema.json', mutate: [{ file: M, set: { '/actBeats/every/0': 'coreBroken' } }], expect: { rule: 'enum', pointer: '/actBeats/every/0' } },
    { id: 'mood-act-beats-once-enum', schema: 'fight-mood.schema.json', mutate: [{ file: M, set: { '/actBeats/oncePerMatch/1': 'headBattered' } }], expect: { rule: 'enum', pointer: '/actBeats/oncePerMatch/1' } },
    { id: 'mood-landmark-fall-required', schema: 'fight-mood.schema.json', mutate: [{ file: M, del: ['/impulses/landmarkFall'] }], expect: { rule: 'required', pointer: '/impulses' } },
    { id: 'mood-landmark-fall-type', schema: 'fight-mood.schema.json', mutate: [{ file: M, set: { '/impulses/landmarkFall': 600.5 } }], expect: { rule: 'type', pointer: '/impulses/landmarkFall' } },
    { id: 'style-min-held-required', schema: 'fight-style.schema.json', mutate: [{ file: ST, del: ['/minHeldS'] }], expect: { rule: 'required', pointer: '' } },
    { id: 'style-min-held-negative', schema: 'fight-style.schema.json', mutate: [{ file: ST, set: { '/minHeldS': -1 } }], expect: { rule: 'minimum', pointer: '/minHeldS' } },
    { id: 'style-qa-bands-nested-ok', schema: 'fight-style.schema.json', mutate: [{ file: ST, set: { '/qaBands': { judgedOnAI: { labelChangesPerMatchMedian: 'at most 4' }, judgedOnHumanOrScriptedPlay: { everyLabelReached: true } } } }], expect: null },
  ];
  let added = 0;
  for (const k of add) {
    if (!c.cases.some((x) => x.id === k.id)) {
      c.cases.push(k);
      added++;
    }
  }
  wj(cf, c);
  console.log(`M1b schema changes applied (${added} new cases)`);
}
