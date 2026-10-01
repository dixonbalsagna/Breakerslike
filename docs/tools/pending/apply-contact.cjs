// Schema changes for Combat's contact spacing data (docs/combat/contact-spacing.md section 6), and the swap of the two parked files.
// NOT run by CI, the validator or the sim. Run AFTER apply-2b.cjs (and the 2b data), once from the repo root, in the same commit that lands the data:
//     node docs/tools/pending/apply-contact.cjs
// It adds the schema keys, copies docs/combat/pending/templates.contact.json and finishers.contact.json over data/combat/templates.json and
// finishers.json, and adds the cases (also: tempo.stepAround, contact.placementReaches and the crossing dodge's dur, rise and off). Then: node tools/validate.js (0 errors) and node tools/validate.js --self-test (all pass).
// Re-runnable: every edit sets a value or checks first, cases are added by id, and the file copy is idempotent. See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };

const TPL = 'data/combat/templates.json';
const FIN = 'data/combat/finishers.json';
const SCHEMA = 'tools/schemas/combat-templates.schema.json';

const s = rj(SCHEMA);
if (!s.$defs.profileDynamic || !s.$defs.beam || !(JSON.stringify(s).includes('outcomeByProfile'))) {
  throw new Error('apply-2b.cjs has not been run (the templates schema has no 2b shapes). Run it first.');
}

// =============================== schema ===============================
{
  const pd = s.$defs.profileDynamic;
  const tempo = pd.properties.tempo;
  const ticks = { $ref: '#/$defs/ticks' };
  // (2) tempo.stepIn and tempo.chainClose: required in the dynamic profile, because the beats that use them (rush before a strike, the chain catch) read them
  tempo.properties.stepIn = ticks;
  tempo.properties.chainClose = ticks;
  tempo.properties.stepAround = ticks;   // the dodge's cross-over (dur: {ticks: stepAround})
  for (const k of ['stepIn', 'chainClose', 'stepAround']) if (!tempo.required.includes(k)) tempo.required.push(k);

  // (3) profiles.dynamic.contact
  const len = { type: 'number', exclusiveMinimum: 0 };
  pd.properties.contact = Object.assign({
    type: 'object',
    description: 'Contact spacing (docs/combat/contact-spacing.md): on every damaging strike\'s contact tick the two fighters are within reach (centre to centre, world units) and at the same height. offset is where an approach, lunge or step-in ends; minSeparation is the least distance two bodies may come. reach not below offset and offset not below minSeparation are checked by tools/lib/xref.js (contact-range).',
    required: ['reach', 'offset', 'minSeparation', 'sameHeight', 'placementReaches'],
    properties: { reach: len, offset: len, minSeparation: len, sameHeight: { type: 'boolean' }, placementReaches: Object.assign({ description: 'How many reaches a placement (the dodge\'s landing, a re-close) may be from the contact point.' }, len) },
  }, closed);
  if (!pd.required.includes('contact')) pd.required.push('contact');

  // (1) a branch's endSides
  s.$defs.branch.properties.endSides = {
    enum: ['same', 'swapped'],
    description: 'Where the pair ends relative to where it began: the same side of each other, or swapped (a dodge crossed over). A branch with dynamic beats must state it, and it must agree with the beats: swapped exactly when a beat has args.side "cross" (checked by tools/lib/xref.js, branch-end-sides).',
  };
  wj(SCHEMA, s);
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'branch-end-sides'")) {
    const a1 = "  if (isObj(tpl) && Array.isArray(tpl.templates)) {\n    dupes(TPL, tpl.templates.map(";
    if (!t.includes(a1)) throw new Error('xref anchor 1');
    t = t.replace(a1, () => [
      '  // contact spacing: reach is at least the offset, and the offset at least the least separation',
      '  const contact = isObj(tpl) && isObj(tpl.profiles) && isObj(tpl.profiles.dynamic) ? tpl.profiles.dynamic.contact : undefined;',
      '  if (isObj(contact) && [contact.reach, contact.offset, contact.minSeparation].every((n) => typeof n === \'number\')) {',
      "    if (contact.reach < contact.offset) err(TPL, '/profiles/dynamic/contact/reach', 'contact-range', `reach ${contact.reach} is below offset ${contact.offset}, so a strike that ends at the offset would be out of reach`);",
      "    if (contact.offset < contact.minSeparation) err(TPL, '/profiles/dynamic/contact/offset', 'contact-range', `offset ${contact.offset} is below minSeparation ${contact.minSeparation}, so an approach would end inside the other body`);",
      '  }',
      a1,
    ].join('\n'));
    const a2 = "      const selectors = [['selector', t.selector],";
    if (!t.includes(a2)) throw new Error('xref anchor 2');
    t = t.replace(a2, () => [
      '      // sides: a beat with args.side is "own" or "cross"; a branch with dynamic beats states endSides, and it is swapped exactly when a beat crosses',
      '      t.branches.forEach((b, bi) => {',
      '        if (!isObj(b) || !Array.isArray(b.dynamic)) return;',
      '        let cross = false;',
      '        b.dynamic.forEach((be, bei) => {',
      '          const side = isObj(be) && isObj(be.args) ? be.args.side : undefined;',
      "          if (side === undefined) return;",
      "          if (side !== 'own' && side !== 'cross') err(TPL, `/templates/${ti}/branches/${bi}/dynamic/${bei}/args/side`, 'beat-side', `side \"${side}\" is not own or cross`);",
      "          if (side === 'cross') cross = true;",
      "          if (be.op === 'dodge' && side === 'cross') {",
      "            const a = be.args;",
      "            const where = `/templates/${ti}/branches/${bi}/dynamic/${bei}/args`;",
      "            for (const k of ['dur', 'rise', 'off']) if (a[k] === undefined) err(TPL, where, 'dodge-cross', `a crossing dodge in branch \"${b.id}\" has no ${k}`);",
      "            if (typeof a.rise === 'number' && a.rise <= 0) err(TPL, `${where}/rise`, 'dodge-cross', `rise ${a.rise} must be above 0`);",
      "            if (typeof a.off === 'number' && isObj(contact) && typeof contact.minSeparation === 'number' && a.off < contact.minSeparation) err(TPL, `${where}/off`, 'dodge-cross', `off ${a.off} is below minSeparation ${contact.minSeparation}, so the dodge would land inside the other body`);",
      "          }",
      '        });',
      '        const at = `/templates/${ti}/branches/${bi}`;',
      "        if (b.endSides === undefined) err(TPL, at, 'branch-end-sides', `branch \"${b.id}\" has dynamic beats but no endSides`);",
      "        else if ((b.endSides === 'swapped') !== cross) err(TPL, `${at}/endSides`, 'branch-end-sides', cross ? `branch \"${b.id}\" has a beat that crosses (side \"cross\") but endSides is \"${b.endSides}\"` : `branch \"${b.id}\" has endSides \"swapped\" but no beat crosses (args.side \"cross\")`);",
      '      });',
      a2,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== the data ===============================
fs.copyFileSync('docs/combat/pending/templates.contact.json', TPL);
fs.copyFileSync('docs/combat/pending/finishers.contact.json', FIN);

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const tpl = rj(TPL);
  // pointers into the contact data, found by id so the cases follow the file
  const ti = (id) => tpl.templates.findIndex((x) => x.id === id);
  const bi = (t, id) => tpl.templates[ti(t)].branches.findIndex((b) => b.id === id);
  const dodge = ti('dodge');
  const trade = ti('trade_blows');
  const dRead = bi('dodge', 'read');
  const tWon = bi('trade_blows', 'won');
  const crossAt = tpl.templates[dodge].branches[dRead].dynamic.findIndex((be) => be.args && be.args.side === 'cross');
  const guard = ti('guard_break');
  const gBreak = bi('guard_break', 'break');
  const rushAt = tpl.templates[guard].branches[gBreak].dynamic.findIndex((be) => be.op === 'rush' && be.args && be.args.side === 'own');
  if ([dodge, trade, guard, dRead, tWon, gBreak, crossAt, rushAt].some((n) => n < 0)) throw new Error('contact data: a case anchor was not found');
  const b = (t, br) => `/templates/${t}/branches/${br}`;
  const k = (id, mut, expect) => ({ id: 'contact-' + id, schema: 'combat-templates.schema.json', mutate: [{ file: TPL, ...mut }], expect });
  const add = [
    k('end-sides-enum', { set: { [b(trade, tWon) + '/endSides']: 'both' } }, { rule: 'enum', pointer: b(trade, tWon) + '/endSides' }),
    k('end-sides-required', { del: [b(trade, tWon) + '/endSides'] }, { rule: 'xref:branch-end-sides', pointer: b(trade, tWon) }),
    k('swapped-without-cross', { set: { [b(trade, tWon) + '/endSides']: 'swapped' } }, { rule: 'xref:branch-end-sides', pointer: b(trade, tWon) + '/endSides' }),
    k('cross-needs-swapped', { set: { [b(dodge, dRead) + '/endSides']: 'same' } }, { rule: 'xref:branch-end-sides', pointer: b(dodge, dRead) + '/endSides' }),
    k('side-name', { set: { [b(guard, gBreak) + `/dynamic/${rushAt}/args/side`]: 'left' } }, { rule: 'xref:beat-side', pointer: b(guard, gBreak) + `/dynamic/${rushAt}/args/side` }),
    k('cross-side-name', { set: { [b(dodge, dRead) + `/dynamic/${crossAt}/args/side`]: 'behind' } }, { rule: 'xref:beat-side', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args/side` }),
    k('step-in-required', { del: ['/profiles/dynamic/tempo/stepIn'] }, { rule: 'required', pointer: '/profiles/dynamic/tempo' }),
    k('chain-close-required', { del: ['/profiles/dynamic/tempo/chainClose'] }, { rule: 'required', pointer: '/profiles/dynamic/tempo' }),
    k('step-in-type', { set: { '/profiles/dynamic/tempo/stepIn': 'short' } }, { rule: 'type', pointer: '/profiles/dynamic/tempo/stepIn' }),
    k('contact-required', { del: ['/profiles/dynamic/contact'] }, { rule: 'required', pointer: '/profiles/dynamic' }),
    k('contact-key-required', { del: ['/profiles/dynamic/contact/offset'] }, { rule: 'required', pointer: '/profiles/dynamic/contact' }),
    k('contact-unknown-key', { set: { '/profiles/dynamic/contact/gap': 5 } }, { rule: 'additionalProperties', pointer: '/profiles/dynamic/contact/gap' }),
    k('contact-positive', { set: { '/profiles/dynamic/contact/minSeparation': 0 } }, { rule: 'exclusiveMinimum', pointer: '/profiles/dynamic/contact/minSeparation' }),
    k('same-height-type', { set: { '/profiles/dynamic/contact/sameHeight': 'yes' } }, { rule: 'type', pointer: '/profiles/dynamic/contact/sameHeight' }),
    k('reach-below-offset', { set: { '/profiles/dynamic/contact/reach': 50 } }, { rule: 'xref:contact-range', pointer: '/profiles/dynamic/contact/reach' }),
    k('offset-below-separation', { set: { '/profiles/dynamic/contact/minSeparation': 60 } }, { rule: 'xref:contact-range', pointer: '/profiles/dynamic/contact/offset' }),
    k('step-around-required', { del: ['/profiles/dynamic/tempo/stepAround'] }, { rule: 'required', pointer: '/profiles/dynamic/tempo' }),
    k('step-around-type', { set: { '/profiles/dynamic/tempo/stepAround': 'short' } }, { rule: 'type', pointer: '/profiles/dynamic/tempo/stepAround' }),
    k('placement-reaches-required', { del: ['/profiles/dynamic/contact/placementReaches'] }, { rule: 'required', pointer: '/profiles/dynamic/contact' }),
    k('placement-reaches-positive', { set: { '/profiles/dynamic/contact/placementReaches': 0 } }, { rule: 'exclusiveMinimum', pointer: '/profiles/dynamic/contact/placementReaches' }),
    k('dodge-cross-needs-dur', { del: [b(dodge, dRead) + `/dynamic/${crossAt}/args/dur`] }, { rule: 'xref:dodge-cross', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args` }),
    k('dodge-cross-needs-rise', { del: [b(dodge, dRead) + `/dynamic/${crossAt}/args/rise`] }, { rule: 'xref:dodge-cross', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args` }),
    k('dodge-cross-needs-off', { del: [b(dodge, dRead) + `/dynamic/${crossAt}/args/off`] }, { rule: 'xref:dodge-cross', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args` }),
    k('dodge-cross-rise-positive', { set: { [b(dodge, dRead) + `/dynamic/${crossAt}/args/rise`]: 0 } }, { rule: 'xref:dodge-cross', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args/rise` }),
    k('dodge-cross-off-inside-body', { set: { [b(dodge, dRead) + `/dynamic/${crossAt}/args/off`]: 30 } }, { rule: 'xref:dodge-cross', pointer: b(dodge, dRead) + `/dynamic/${crossAt}/args/off` }),
    k('dodge-cross-off-at-separation-ok', { set: { [b(dodge, dRead) + `/dynamic/${crossAt}/args/off`]: 45 } }, null),
    k('contact-equal-ok', { set: { '/profiles/dynamic/contact/reach': 58, '/profiles/dynamic/contact/minSeparation': 58 } }, null),
  ];
  let n = 0;
  for (const x of add) if (!c.cases.some((y) => y.id === x.id)) { c.cases.push(x); n++; }
  wj(cf, c);
  console.log(`contact schema changes applied and data swapped in (${n} new cases)`);
}
