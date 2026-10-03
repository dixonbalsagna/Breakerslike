// Schema keys for Encounter's slice 9, the wild deflect, the spray and mines (docs/director/update-apply-order.md step 2).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit that lands the slice's data:
//     node docs/tools/pending/apply-slice9.cjs
// It does NOT edit data/. It adds:
//   data/director/interrupts.json  the required blast.light.aiGapTicks (integer, 0 or more) and the required blast.deflect {freeApproachTicks, context {ki}}, blast.spray {measuredTicks, perBolt, max,
//                                  missShare, slopeMin, slopeMax, recoverPerSec} and blast.mine {enabled, kind, ki, shoveWithinBh,
//                                  groundWithinBh, blowR} (closed; _note allowed)
//   data/director/ai.json          the required top-level mineMinKi (note _mine allowed) and, per level, mineShare (a chance)
// the two validator fixtures, rules blast-mine-kind (the mine's kind is a shot kind of data/fight/shots.json that has a mine block),
// blast-spray (slopeMin at most slopeMax; missShare above 1 is a warning) and the cases, and it adds the new keys to the earlier
// whole-blast cases. Re-runnable (a second run changes nothing).
// The cue names mine_lay, mine_refused, context_deflect_set, context_deflect and volley_fire are render cues the sim emits (SimFx.cue):
// no schema or rule here checks that vocabulary, so nothing is added for them (pair_live.json `cues` maps the ones Animation plays).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const n0 = (d) => ({ type: 'number', minimum: 0, description: d });
const i0 = (d) => ({ type: 'integer', minimum: 0, description: d });
const chance = { type: 'number', minimum: 0, maximum: 1 };
const clone = (o) => JSON.parse(JSON.stringify(o));

// placeholders for the fixtures until the live data carries the keys
const FX = {
  blast: {
    deflect: { freeApproachTicks: 20, context: { ki: 10 } },
    spray: { measuredTicks: 10, perBolt: 2, max: 12, missShare: 0.4, slopeMin: 0.1, slopeMax: 0.5, recoverPerSec: 6 },
    mine: { enabled: true, kind: 'mine', ki: 20, shoveWithinBh: 3, groundWithinBh: 1, blowR: 80 },
  },
  mineMinKi: 20,
  aiGapTicks: 10,
  mineShare: { easy: 0.1, medium: 0.2, hard: 0.3 },
};
const liveI = fs.existsSync('data/director/interrupts.json') ? rj('data/director/interrupts.json') : null;
const liveA = fs.existsSync('data/director/ai.json') ? rj('data/director/ai.json') : null;
const haveI = liveI && liveI.blast && liveI.blast.mine;
const haveA = liveA && liveA.mineMinKi !== undefined;
const strip = (o) => Object.fromEntries(Object.entries(o).filter(([k]) => !k.startsWith('_')).map(([k, v]) => [k, v && typeof v === 'object' && !Array.isArray(v) ? strip(v) : v]));

// =============================== interrupts schema ===============================
{
  const f = 'tools/schemas/director-interrupts.schema.json';
  const s = rj(f);
  const b = s.properties.blast;
  if (!b.properties.light.properties.aiGapTicks) {
    b.properties.light.properties.aiGapTicks = i0('The AI spaces the bolts of its volley this many ticks apart, so its bolts are measured and keep seeking.');
    if (!b.properties.light.required.includes('aiGapTicks')) b.properties.light.required.push('aiGapTicks');
    wj(f, s);
  }
}
{
  const f = 'tools/schemas/director-interrupts.schema.json';
  const s = rj(f);
  const b = s.properties.blast;
  if (!b.properties.mine) {
    b.properties.deflect = obj({
      freeApproachTicks: i0('Ticks of free approach a wild deflect leaves the deflector (no shot stops him).'),
      context: obj({ ki: n0('The ki a context deflect costs.') }),
    }, { description: 'The director\'s side of the wild deflect (agency-pass.md section 15.2).' });
    b.properties.spray = obj({
      measuredTicks: i0('A bolt fired this many ticks or more after the one before is measured, not sprayed.'),
      perBolt: n0('The spread each spammed bolt adds.'),
      max: n0('The widest the spread grows.'),
      missShare: n0('The share of sprayed bolts that miss.'),
      slopeMin: n0('The least slope of the cone.'),
      slopeMax: n0('The most slope of the cone.'),
      recoverPerSec: n0('How fast the spread recovers while he waits, a second.'),
    }, { description: 'The spray: spammed bolts fan out into a cone (agency-pass.md section 15.4).' });
    b.properties.mine = obj({
      enabled: { type: 'boolean', description: 'false: no mines are laid.' },
      kind: { type: 'string', pattern: '^[a-z][a-z0-9_]*$', description: 'A shot kind of data/fight/shots.json that has a mine block (checked by tools/lib/xref-fight.js, blast-mine-kind).' },
      ki: n0('The ki a mine costs.'),
      shoveWithinBh: n0('A rival within this many body heights is shoved.'),
      groundWithinBh: n0('A mine is laid on the ground when it is this close to it.'),
      blowR: n0('The radius in which a blow sets a mine off.'),
    }, { description: 'Mines (agency-pass.md section 15.5).' });
    for (const k of ['deflect', 'spray', 'mine']) if (!b.required.includes(k)) b.required.push(k);
    wj(f, s);
  }
}

// =============================== ai schema ===============================
{
  const f = 'tools/schemas/director-ai.schema.json';
  const s = rj(f);
  if (!s.properties.mineMinKi) {
    s.properties.mineMinKi = n0('The ki below which the AI lays no mine.');
    if (!s.required.includes('mineMinKi')) s.required.push('mineMinKi');
    for (const name of ['easy', 'medium', 'hard']) {
      const L = s.properties.levels.properties[name];
      L.properties.mineShare = Object.assign({ description: 'The chance an AI blast press is a mine.' }, chance);
      if (!L.required.includes('mineShare')) L.required.push('mineShare');
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
    if (o.blast && o.blast.light && o.blast.light.aiGapTicks === undefined) { o.blast.light.aiGapTicks = haveI && liveI.blast.light.aiGapTicks !== undefined ? liveI.blast.light.aiGapTicks : FX.aiGapTicks; wj(f, o); }
  }
  {
    const f = dir + 'interrupts.json';
    const o = rj(f);
    if (o.blast && o.blast.mine === undefined) {
      const src = haveI ? strip({ deflect: liveI.blast.deflect, spray: liveI.blast.spray, mine: liveI.blast.mine }) : clone(FX.blast);
      Object.assign(o.blast, src);
      wj(f, o);
    }
  }
  {
    const f = dir + 'ai.json';
    const o = rj(f);
    if (o.mineMinKi === undefined) {
      o.mineMinKi = haveA ? liveA.mineMinKi : FX.mineMinKi;
      for (const name of ['easy', 'medium', 'hard']) o.levels[name].mineShare = haveA ? liveA.levels[name].mineShare : FX.mineShare[name];
      wj(f, o);
    }
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'blast-mine-kind'")) {
    const a = "    const bu = itr.buried;";
    if (!t.includes(a)) throw new Error('blast anchor');
    t = t.replace(a, () => [
      "    if (isObj(bl2) && isObj(bl2.mine) && typeof bl2.mine.kind === 'string') {",
      "      const shotsM = get('data/fight/shots.json');",
      "      const kindsM = isObj(shotsM) && isObj(shotsM.kinds) ? shotsM.kinds : undefined;",
      "      if (kindsM && !isObj(kindsM[bl2.mine.kind])) err(IT, '/blast/mine/kind', 'blast-mine-kind', `mine kind \"${bl2.mine.kind}\" is not a kind of data/fight/shots.json (${Object.keys(kindsM).filter((k) => !k.startsWith('_')).join(', ')})`);",
      "      else if (kindsM && !isObj(kindsM[bl2.mine.kind].mine)) err(IT, '/blast/mine/kind', 'blast-mine-kind', `mine kind \"${bl2.mine.kind}\" has no mine block in data/fight/shots.json, so it is not a mine`);",
      "    }",
      "    if (isObj(bl2) && isObj(bl2.spray)) {",
      "      if (typeof bl2.spray.slopeMin === 'number' && typeof bl2.spray.slopeMax === 'number' && bl2.spray.slopeMin > bl2.spray.slopeMax) err(IT, '/blast/spray/slopeMin', 'blast-spray', `slopeMin ${bl2.spray.slopeMin} is above slopeMax ${bl2.spray.slopeMax}`);",
      "      if (typeof bl2.spray.missShare === 'number' && bl2.spray.missShare > 1) err(IT, '/blast/spray/missShare', 'blast-spray', `missShare ${bl2.spray.missShare} is above 1; it is a share of the sprayed bolts`, 'warning');",
      "    }",
      a,
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
  // the earlier cases that build the whole blast block need the new required keys
  const fxI = rj('tools/fixtures/virtual/data/director/interrupts.json');
  const newKeys = { deflect: fxI.blast.deflect, spray: fxI.blast.spray, mine: fxI.blast.mine };
  for (const k of c.cases) {
    if (!/^director-interrupts-blast-/.test(k.id)) continue;
    for (const m of k.mutate || []) {
      const o = m.set && m.set['/blast'];
      if (o && typeof o === 'object' && o.light && typeof o.light === 'object' && o.light.aiGapTicks === undefined && !(k.expect && k.expect.rule === 'required' && k.expect.pointer === '/blast/light')) o.light.aiGapTicks = 10;
      if (o && typeof o === 'object') for (const key of Object.keys(newKeys)) if (o[key] === undefined) o[key] = clone(newKeys[key]);
    }
  }
  const it = (n, mut, expect) => ({ id: 'director-interrupts-' + n, schema: 'director-interrupts.schema.json', mutate: [{ file: I, ...mut }], expect });
  const ai = (n, mut, expect) => ({ id: 'director-ai-' + n, schema: 'director-ai.schema.json', mutate: [{ file: A, ...mut }], expect });
  const D = '/blast/deflect/';
  const S = '/blast/spray/';
  const M = '/blast/mine/';
  const add = [
    it('blast-light-ai-gap-required', { del: ['/blast/light/aiGapTicks'] }, { rule: 'required', pointer: '/blast/light' }),
    it('blast-light-ai-gap-negative', { set: { '/blast/light/aiGapTicks': -1 } }, { rule: 'minimum', pointer: '/blast/light/aiGapTicks' }),
    it('blast-light-ai-gap-integer', { set: { '/blast/light/aiGapTicks': 10.5 } }, { rule: 'type', pointer: '/blast/light/aiGapTicks' }),
    it('blast-light-ai-gap-zero-ok', { set: { '/blast/light/aiGapTicks': 0 } }, null),
    it('blast-deflect-required', { del: ['/blast/deflect'] }, { rule: 'required', pointer: '/blast' }),
    it('blast-spray-required', { del: ['/blast/spray'] }, { rule: 'required', pointer: '/blast' }),
    it('blast-mine-required', { del: ['/blast/mine'] }, { rule: 'required', pointer: '/blast' }),
    it('blast-deflect-key-required', { del: [D + 'context'] }, { rule: 'required', pointer: '/blast/deflect' }),
    it('blast-deflect-unknown-key', { set: { [D + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: D + 'extra' }),
    it('blast-deflect-note-ok', { set: { [D + '_note']: 'comment' } }, null),
    it('blast-deflect-free-negative', { set: { [D + 'freeApproachTicks']: -1 } }, { rule: 'minimum', pointer: D + 'freeApproachTicks' }),
    it('blast-deflect-free-integer', { set: { [D + 'freeApproachTicks']: 20.5 } }, { rule: 'type', pointer: D + 'freeApproachTicks' }),
    it('blast-deflect-free-zero-ok', { set: { [D + 'freeApproachTicks']: 0 } }, null),
    it('blast-deflect-context-key-required', { set: { [D + 'context']: {} } }, { rule: 'required', pointer: D + 'context' }),
    it('blast-deflect-context-ki-negative', { set: { [D + 'context/ki']: -1 } }, { rule: 'minimum', pointer: D + 'context/ki' }),
    it('blast-deflect-context-unknown-key', { set: { [D + 'context/extra']: 1 } }, { rule: 'additionalProperties', pointer: D + 'context/extra' }),
    it('blast-spray-key-required', { del: [S + 'recoverPerSec'] }, { rule: 'required', pointer: '/blast/spray' }),
    it('blast-spray-unknown-key', { set: { [S + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: S + 'extra' }),
    it('blast-spray-note-ok', { set: { [S + '_note']: 'comment' } }, null),
    it('blast-spray-measured-negative', { set: { [S + 'measuredTicks']: -1 } }, { rule: 'minimum', pointer: S + 'measuredTicks' }),
    it('blast-spray-measured-integer', { set: { [S + 'measuredTicks']: 10.5 } }, { rule: 'type', pointer: S + 'measuredTicks' }),
    it('blast-spray-per-bolt-negative', { set: { [S + 'perBolt']: -1 } }, { rule: 'minimum', pointer: S + 'perBolt' }),
    it('blast-spray-max-negative', { set: { [S + 'max']: -1 } }, { rule: 'minimum', pointer: S + 'max' }),
    it('blast-spray-miss-negative', { set: { [S + 'missShare']: -0.1 } }, { rule: 'minimum', pointer: S + 'missShare' }),
    it('blast-spray-miss-above-one-warns', { set: { [S + 'missShare']: 1.5 } }, { rule: 'xref:blast-spray', pointer: S + 'missShare' }),
    it('blast-spray-miss-one-ok', { set: { [S + 'missShare']: 1 } }, null),
    it('blast-spray-slope-negative', { set: { [S + 'slopeMin']: -0.1 } }, { rule: 'minimum', pointer: S + 'slopeMin' }),
    it('blast-spray-slope-max-type', { set: { [S + 'slopeMax']: 'wide' } }, { rule: 'type', pointer: S + 'slopeMax' }),
    it('blast-spray-slopes-reversed', { set: { [S + 'slopeMin']: 0.9, [S + 'slopeMax']: 0.2 } }, { rule: 'xref:blast-spray', pointer: S + 'slopeMin' }),
    it('blast-spray-slopes-equal-ok', { set: { [S + 'slopeMin']: 0.3, [S + 'slopeMax']: 0.3 } }, null),
    it('blast-spray-recover-negative', { set: { [S + 'recoverPerSec']: -1 } }, { rule: 'minimum', pointer: S + 'recoverPerSec' }),
    it('blast-mine-key-required', { del: [M + 'blowR'] }, { rule: 'required', pointer: '/blast/mine' }),
    it('blast-mine-unknown-key', { set: { [M + 'extra']: 1 } }, { rule: 'additionalProperties', pointer: M + 'extra' }),
    it('blast-mine-note-ok', { set: { [M + '_note']: 'comment' } }, null),
    it('blast-mine-enabled-type', { set: { [M + 'enabled']: 'yes' } }, { rule: 'type', pointer: M + 'enabled' }),
    it('blast-mine-off-ok', { set: { [M + 'enabled']: false } }, null),
    it('blast-mine-kind-shape', { set: { [M + 'kind']: 'Mine' } }, { rule: 'pattern', pointer: M + 'kind' }),
    it('blast-mine-kind-not-a-shot', { set: { [M + 'kind']: 'nowhere' } }, { rule: 'xref:blast-mine-kind', pointer: M + 'kind' }),
    it('blast-mine-kind-not-a-mine', { set: { [M + 'kind']: 'bolt' } }, { rule: 'xref:blast-mine-kind', pointer: M + 'kind' }),
    it('blast-mine-ki-negative', { set: { [M + 'ki']: -1 } }, { rule: 'minimum', pointer: M + 'ki' }),
    it('blast-mine-shove-negative', { set: { [M + 'shoveWithinBh']: -1 } }, { rule: 'minimum', pointer: M + 'shoveWithinBh' }),
    it('blast-mine-ground-negative', { set: { [M + 'groundWithinBh']: -1 } }, { rule: 'minimum', pointer: M + 'groundWithinBh' }),
    it('blast-mine-blow-negative', { set: { [M + 'blowR']: -1 } }, { rule: 'minimum', pointer: M + 'blowR' }),
    it('blast-mine-blow-zero-ok', { set: { [M + 'blowR']: 0 } }, null),
    ai('mine-min-ki-required', { del: ['/mineMinKi'] }, { rule: 'required', pointer: '' }),
    ai('mine-min-ki-negative', { set: { '/mineMinKi': -1 } }, { rule: 'minimum', pointer: '/mineMinKi' }),
    ai('mine-min-ki-type', { set: { '/mineMinKi': 'lots' } }, { rule: 'type', pointer: '/mineMinKi' }),
    ai('mine-min-ki-zero-ok', { set: { '/mineMinKi': 0 } }, null),
    ai('mine-note-ok', { set: { '/_mine': 'comment' } }, null),
    ai('mine-share-required-easy', { del: ['/levels/easy/mineShare'] }, { rule: 'required', pointer: '/levels/easy' }),
    ai('mine-share-required-medium', { del: ['/levels/medium/mineShare'] }, { rule: 'required', pointer: '/levels/medium' }),
    ai('mine-share-required-hard', { del: ['/levels/hard/mineShare'] }, { rule: 'required', pointer: '/levels/hard' }),
    ai('mine-share-range', { set: { '/levels/easy/mineShare': 1.5 } }, { rule: 'maximum', pointer: '/levels/easy/mineShare' }),
    ai('mine-share-negative', { set: { '/levels/medium/mineShare': -0.1 } }, { rule: 'minimum', pointer: '/levels/medium/mineShare' }),
    ai('mine-share-type', { set: { '/levels/hard/mineShare': 'often' } }, { rule: 'type', pointer: '/levels/hard/mineShare' }),
    ai('mine-share-edges-ok', { set: { '/levels/easy/mineShare': 0, '/levels/hard/mineShare': 1 } }, null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`slice 9 schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('blast-mine-kind')) {
    const line = t.split('\n').find((l) => l.includes('`blast-shot-kind`'));
    if (!line) throw new Error('slice 9 README anchor');
    t = t.replace(line, () => line + '\n| `blast-mine-kind`, `blast-spray` | data/director/interrupts.json blast: the mine\'s kind is a kind of data/fight/shots.json with a mine block; the spray\'s slopeMin is at most slopeMax, and a missShare above 1 is a warning |');
    fs.writeFileSync(f, t);
  }
}
