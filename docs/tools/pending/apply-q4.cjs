// Q4 schema changes for Combat's parked data batch (docs/combat/pending, docs/combat/variety-pass.md section 6). NOT run by CI, the validator or the sim.
// Run once from the repo root, in the same commit that lands the batch data: node docs/tools/pending/apply-q4.cjs
// See README.md next to this file.
const fs = require('fs');

// ---- finishers schema: (a) kind, (b) byState ----
const ff = 'tools/schemas/combat-finishers.schema.json';
const fs1 = JSON.parse(fs.readFileSync(ff, 'utf8'));
const fin = fs1.$defs.finisher;
fin.properties.kind = { enum: ['launch', 'melee', 'beam'], description: 'What the finisher is, so the loser can read it in the wind-up (copied into finisher_start; the telegraph cue is finisher_tell_<kind>).' };
fin.required = ['id', 'kind', 'fighter', 'profile', 'timeUnit', 'beats', 'outcomes'];
const struggle = fs1.properties.contest.properties.struggle;
struggle.properties.byState = {
  type: 'object',
  description: 'The struggle resolved by state (no presses): one draw at contestOpen. The press fields above become optional in a later change.',
  required: ['base', 'stanceRead', 'kiBonus', 'rallyPenalty', 'tiltPerMinute', 'tiltAfter', 'floor'],
  properties: {
    base: { type: 'number', minimum: 0, maximum: 1 },
    stanceRead: {
      type: 'object',
      required: ['match', 'other', 'matches'],
      properties: {
        match: { type: 'number', minimum: 0, maximum: 1 },
        other: { type: 'number', minimum: 0, maximum: 1 },
        matches: {
          type: 'object',
          required: ['launch', 'melee', 'beam'],
          properties: {
            launch: { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'AGGRESSIVE_40KI'] },
            melee: { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'AGGRESSIVE_40KI'] },
            beam: { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'AGGRESSIVE_40KI'] },
          },
          additionalProperties: false,
        },
      },
      additionalProperties: false,
      patternProperties: { '^_': true },
    },
    kiBonus: {
      type: 'object',
      required: ['atLeast', 'add'],
      properties: { atLeast: { type: 'number', minimum: 0 }, add: { type: 'number' } },
      additionalProperties: false,
    },
    rallyPenalty: { type: 'number', minimum: 0 },
    tiltPerMinute: { type: 'number', minimum: 0 },
    tiltAfter: { type: 'number', minimum: 0 },
    floor: { type: 'number', minimum: 0, maximum: 1 },
    fighterState: { type: 'string' },
    pulses: { type: 'string' },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
};
fs.writeFileSync(ff, JSON.stringify(fs1, null, 2) + '\n');

// ---- templates schema: (c) selectorByProfile ----
const tf = 'tools/schemas/combat-templates.schema.json';
const ts = JSON.parse(fs.readFileSync(tf, 'utf8'));
ts.$defs.template.properties.selectorByProfile = {
  type: 'object',
  minProperties: 1,
  description: 'A selector per timing profile, read before `selector` when the active profile has one. Same shape as `selector`; conditions may use the variable defHeld (S.T - D.stanceT, supplied by Encounter).',
  propertyNames: { enum: ['parity', 'spaced', 'dynamic'] },
  additionalProperties: { $ref: '#/$defs/selector' },
};
fs.writeFileSync(tf, JSON.stringify(ts, null, 2) + '\n');

// ---- xref: selectorByProfile branch references ----
const xf = 'tools/lib/xref.js';
let x = fs.readFileSync(xf, 'utf8');
const a = "      const s = t.selector;\n      if (isObj(s)) {\n        const refs = [['branch', s.branch], ['ifBelow', s.ifBelow], ['else', s.else], ['ifGreater', s.ifGreater]];\n        if (isObj(s.below)) refs.push(['below/branch', s.below.branch]);\n        if (isObj(s.above)) refs.push(['above/branch', s.above.branch]);\n        for (const [key, target] of refs) {\n          if (target !== undefined && !ids.has(target)) err(TPL, `/templates/${ti}/selector/${key}`, 'selector-branch', `selector points at branch \"${target}\", but template \"${t.id}\" has only: ${[...ids].join(', ')}`);\n        }\n      }";
if (!x.includes(a)) throw new Error('xref selector block not found');
const b = "      const selectors = [['selector', t.selector], ...Object.entries(isObj(t.selectorByProfile) ? t.selectorByProfile : {}).map(([p, sel]) => [`selectorByProfile/${p}`, sel])];\n      for (const [where, s] of selectors) {\n        if (!isObj(s)) continue;\n        const refs = [['branch', s.branch], ['ifBelow', s.ifBelow], ['else', s.else], ['ifGreater', s.ifGreater]];\n        if (isObj(s.below)) refs.push(['below/branch', s.below.branch]);\n        if (isObj(s.above)) refs.push(['above/branch', s.above.branch]);\n        for (const [key, target] of refs) {\n          if (target !== undefined && !ids.has(target)) err(TPL, `/templates/${ti}/${where}/${key}`, 'selector-branch', `selector points at branch \"${target}\", but template \"${t.id}\" has only: ${[...ids].join(', ')}`);\n        }\n      }";
x = x.replace(a, () => b);
fs.writeFileSync(xf, x);

// ---- cases ----
const cf = 'tools/fixtures/cases.json';
let c = fs.readFileSync(cf, 'utf8');
const anchor = '    { "id": "flashes-version"';
if (!c.includes(anchor)) throw new Error('cases anchor');
const F = 'data/combat/finishers.json';
const T = 'data/combat/templates.json';
const cases = [
  { id: 'finishers-kind-enum', schema: 'combat-finishers.schema.json', mutate: [{ file: F, set: { '/finishers/2/kind': 'sniper' } }], expect: { rule: 'enum', pointer: '/finishers/2/kind' } },
  { id: 'finishers-kind-required', schema: 'combat-finishers.schema.json', mutate: [{ file: F, del: ['/finishers/2/kind'] }], expect: { rule: 'required', pointer: '/finishers/2' } },
  { id: 'finishers-bystate-type', schema: 'combat-finishers.schema.json', mutate: [{ file: F, set: { '/contest/struggle/byState/base': 'high' } }], expect: { rule: 'type', pointer: '/contest/struggle/byState/base' } },
  { id: 'finishers-bystate-read', schema: 'combat-finishers.schema.json', mutate: [{ file: F, set: { '/contest/struggle/byState/stanceRead/matches/launch': 'SPRINT' } }], expect: { rule: 'enum', pointer: '/contest/struggle/byState/stanceRead/matches/launch' } },
  { id: 'finishers-bystate-needs-read', schema: 'combat-finishers.schema.json', mutate: [{ file: F, del: ['/contest/struggle/byState/stanceRead'] }], expect: { rule: 'required', pointer: '/contest/struggle/byState' } },
  { id: 'templates-profile-selector-kind', schema: 'combat-templates.schema.json', mutate: [{ file: T, set: { '/templates/3/selectorByProfile/dynamic/kind': 'roulette' } }], expect: { rule: 'enum', pointer: '/templates/3/selectorByProfile/dynamic/kind' } },
  { id: 'templates-profile-name', schema: 'combat-templates.schema.json', mutate: [{ file: T, set: { '/templates/3/selectorByProfile/turbo': { kind: 'fixed', branch: 'holds' } } }], expect: { rule: 'propertyNames', pointer: '/templates/3/selectorByProfile/turbo' } },
  { id: 'templates-profile-selector-branch', schema: 'combat-templates.schema.json', mutate: [{ file: T, set: { '/templates/3/selectorByProfile/dynamic/ifBelow': 'nope' } }], expect: { rule: 'xref:selector-branch', pointer: '/templates/3/selectorByProfile/dynamic/ifBelow' } },
  { id: 'templates-profile-selector-needs-draw', schema: 'combat-templates.schema.json', mutate: [{ file: T, del: ['/templates/3/selectorByProfile/dynamic/draw'] }], expect: { rule: 'required', pointer: '/templates/3/selectorByProfile/dynamic' } },
];
const text = cases.map((k) => '    ' + JSON.stringify(k).replace(/^\{/, '{ ').replace(/\}$/, ' }') + ',\n').join('');
c = c.replace(anchor, () => text + anchor);
fs.writeFileSync(cf, c);
console.log('prep applied');
