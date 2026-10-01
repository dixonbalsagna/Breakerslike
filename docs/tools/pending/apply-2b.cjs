// Schema changes for Encounter's step 2b (docs/combat/pending/README.md, "Schema changes for Tools", items 1 to 10).
// NOT run by CI, the validator or the sim. Replaces apply-q4.cjs (the Q4 batch became 2b).
// Run once from the repo root, in the same commit that lands the 2b data (the three docs/combat/pending/*.2b.json files copied
// over data/combat/templates.json, finishers.json and styles.json):   node docs/tools/pending/apply-2b.cjs
// Then: node tools/validate.js (0 errors) and node tools/validate.js --self-test (all pass). Re-runnable: every edit sets a
// value or checks first, and cases are added by id. See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const edit = (f, pairs) => {
  let t = fs.readFileSync(f, 'utf8');
  for (const [a, b] of pairs) {
    if (t.includes(b)) continue; // already applied
    if (!t.includes(a)) throw new Error(f + ' missing ' + a.slice(0, 90));
    t = t.replace(a, () => b);
  }
  fs.writeFileSync(f, t);
};
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const CLASSES = ['opener', 'heavy', 'ender', 'blast', 'mid', 'none'];
const INTERRUPTS = ['perfect_block', 'reversal', 'dodge_cancel', 'burst'];

// =============================== combat-templates ===============================
{
  const f = 'tools/schemas/combat-templates.schema.json';
  const s = rj(f);
  const d = s.$defs;
  const req = (o, k) => { if (!o.required.includes(k)) o.required.push(k); };
  const drop = (o, k) => { o.required = o.required.filter((x) => x !== k); };

  // (1) trigger: NEUTRAL, and `context` (riposte) as an alternative to `defender`
  d.trigger.required = ['kinds'];
  d.trigger.properties.defender = { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'CHARGING', 'NEUTRAL', 'any'] };
  d.trigger.properties.context = { enum: ['riposte'] };
  d.trigger.oneOf = [{ required: ['defender'] }, { required: ['context'] }];

  // (2) `only`: a template or branch may be for some profiles only, then it needs only those profiles' beats
  const only = { type: 'array', minItems: 1, uniqueItems: true, items: { enum: ['parity', 'spaced', 'dynamic'] }, description: 'The profiles this template or branch exists in. Without it, parity and spaced beats are required (checked by tools/lib/xref.js, branch-profiles).' };
  d.template.properties.only = only;
  d.branch.properties.only = only;
  for (const k of ['spacedTiming', 'parity', 'spaced']) drop(d.branch, k);
  d.branch.dependentRequired = { dynamicTiming: ['dynamic'] };
  d.branch.properties.interrupts = { type: 'array', uniqueItems: true, items: { enum: INTERRUPTS }, description: "The interrupts this branch allows (the data is read from Encounter's step 3)." };

  // (3) strike classes
  d.args.properties.o.properties.class = { enum: CLASSES, description: 'In the dynamic profile a strike class replaces noParry (noParry stays valid in the older profiles).' };

  // (4) selectors: selectorByProfile, kind `condition`, a condition `else`, defenderAdd, the `is` form
  d.cond.properties.is = { type: 'string', minLength: 1 };
  d.selector.properties.kind = { enum: ['fixed', 'threshold', 'gated_threshold', 'bands', 'score_compare', 'condition'] };
  d.selector.properties.if = { $ref: '#/$defs/cond' };
  d.selector.properties.then = { $ref: '#/$defs/id' };
  d.selector.properties.else = { anyOf: [{ $ref: '#/$defs/id' }, { $ref: '#/$defs/condElse' }] };
  d.selector.properties.defenderAdd = { type: 'object', required: ['if', 'then', 'else'], properties: { if: { $ref: '#/$defs/cond' }, then: { type: 'number' }, else: { type: 'number' } }, ...closed };
  d.condElse = { type: 'object', required: ['if', 'then', 'else'], properties: { if: { $ref: '#/$defs/cond' }, then: { $ref: '#/$defs/id' }, else: { $ref: '#/$defs/id' } }, ...closed, description: 'A selector `else` that is itself a condition (no draw).' };
  if (!d.selector.allOf.some((x) => JSON.stringify(x).includes('"condition"'))) {
    d.selector.allOf.push({ if: { properties: { kind: { const: 'condition' } }, required: ['kind'] }, then: { required: ['if', 'then', 'else'] } });
  }
  d.template.properties.selectorByProfile = {
    type: 'object',
    minProperties: 1,
    description: 'A selector per timing profile, read before `selector` when the active profile has one. Same shape as `selector`. Conditions may use defHeld, defQueued, defClipped, defPerfect, defEntry, atkEntry and defAnswer (supplied by Encounter).',
    propertyNames: { enum: ['parity', 'spaced', 'dynamic'] },
    additionalProperties: { $ref: '#/$defs/selector' },
  };

  // (5) profiles.dynamic: its own definition (windups, perfectBlock, strikeClass, enderWindup, minHeavy)
  const dyn = JSON.parse(JSON.stringify(d.profileSpaced));
  dyn.properties.tempo.properties.enderWindup = { $ref: '#/$defs/ticks' };
  dyn.properties.approach.properties.minHeavy = { type: 'number', exclusiveMinimum: 0 };
  const cls = (light) => ({ type: 'object', required: ['light', 'heavy'], properties: { light: { $ref: '#/$defs/ticks' }, heavy: { $ref: '#/$defs/ticks' } }, ...closed });
  dyn.properties.windups = {
    type: 'object',
    required: ['opener', 'heavy', 'ender', 'blast', 'mid'],
    properties: { opener: cls(), heavy: { $ref: '#/$defs/ticks' }, ender: { $ref: '#/$defs/ticks' }, blast: cls(), mid: { $ref: '#/$defs/ticks' } },
    ...closed,
  };
  dyn.properties.perfectBlock = {
    type: 'object',
    required: ['windowTicks', 'lockoutTicks', 'staggerTicks', 'riposteTicks'],
    properties: { windowTicks: { $ref: '#/$defs/ticks' }, lockoutTicks: { $ref: '#/$defs/ticks' }, staggerTicks: { $ref: '#/$defs/ticks' }, riposteTicks: { $ref: '#/$defs/ticks' } },
    ...closed,
  };
  dyn.properties.strikeClass = {
    type: 'object',
    required: ['classes'],
    properties: { classes: { type: 'array', uniqueItems: true, items: { enum: CLASSES } } },
    ...closed,
  };
  req(dyn, 'windups');
  req(dyn, 'perfectBlock');
  req(dyn, 'strikeClass');
  req(dyn.properties.tempo, 'enderWindup');
  req(dyn.properties.approach, 'minHeavy');
  d.profileDynamic = dyn;
  s.properties.profiles.properties.dynamic = { $ref: '#/$defs/profileDynamic' };

  // (6) interrupts, the beat op `stagger`, when: riposteLaunch
  s.properties.interrupts = {
    type: 'object',
    description: "Branch takeovers that arrive inside an exchange (docs/combat/control-scheme-data.md section 4). Step 2b only carries the data; Encounter's step 3 reads it.",
    properties: Object.fromEntries(INTERRUPTS.map((k) => [k, {
      type: 'object',
      required: ['beats'],
      properties: {
        on: { type: 'array', uniqueItems: true, items: { enum: CLASSES } },
        after: { type: 'string' },
        beats: { type: 'array', items: { $ref: '#/$defs/spacedBeat' } },
        opens: { type: 'object', required: ['template', 'withinTicks'], properties: { template: { $ref: '#/$defs/id' }, withinTicks: { $ref: '#/$defs/value' } }, ...closed },
        then: { type: 'string' },
      },
      ...closed,
    }])),
    ...closed,
  };
  req(s, 'interrupts');
  d.op.enum = [...new Set([...d.op.enum, 'stagger'])];
  d.beat.properties.when = { enum: ['light', 'heavy', 'riposteLaunch'] };
  d.args.properties.ticks = { $ref: '#/$defs/value' };
  if (!d.beat.allOf.some((x) => JSON.stringify(x).includes('"stagger"'))) {
    d.beat.allOf.push({ if: { properties: { op: { const: 'stagger' } }, required: ['op'] }, then: { required: ['args'], properties: { args: { required: ['w', 'ticks'] } } } });
  }
  d.value.anyOf[2].properties.ref = { type: 'string', pattern: '^[A-Za-z][A-Za-z0-9_.]*$' };

  // (7) beam.outcomeByProfile and the DEFLECT outcome
  d.beamOutcome = { enum: ['CLASH', 'GUARD', 'DODGE', 'HIT', 'ESCAPE', 'DEFLECT'] };
  d.beamRuleDynamic = {
    type: 'object',
    required: ['draw'],
    properties: {
      defender: { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'CHARGING', 'NEUTRAL'] },
      draw: { enum: ['none', 'next'] },
      if: { $ref: '#/$defs/cond' },
      p: { $ref: '#/$defs/probability' },
      ifBelow: { $ref: '#/$defs/beamOutcome' },
      ifBelowAndNot: { $ref: '#/$defs/cond' },
      out: { $ref: '#/$defs/beamOutcome' },
      else: { $ref: '#/$defs/beamOutcome' },
      clashScoreAdd: { type: 'object', minProperties: 1, propertyNames: { enum: ['A', 'D'] }, additionalProperties: { type: 'number' } },
    },
    ...closed,
  };
  d.beam.properties.outcomeByProfile = {
    type: 'object',
    propertyNames: { enum: ['parity', 'spaced', 'dynamic'] },
    additionalProperties: {
      type: 'object',
      required: ['decideAt', 'rules'],
      properties: { decideAt: { enum: ['fire', 'start'] }, rules: { type: 'array', minItems: 1, items: { $ref: '#/$defs/beamRuleDynamic' } } },
      ...closed,
    },
  };
  wj(f, s);
}

// =============================== combat-finishers: (8) kind and byState ===============================
{
  const f = 'tools/schemas/combat-finishers.schema.json';
  const s = rj(f);
  const fin = s.$defs.finisher;
  fin.properties.kind = { enum: ['launch', 'melee', 'beam'], description: 'What the finisher is, so the loser can read it in the wind-up (copied into finisher_start; the telegraph cue is finisher_tell_<kind>).' };
  if (!fin.required.includes('kind')) fin.required.push('kind');
  const stance = { enum: ['AGGRESSIVE', 'DEFENSIVE', 'EVASIVE', 'ESCAPE', 'AGGRESSIVE_40KI'] };
  s.properties.contest.properties.struggle.properties.byState = {
    type: 'object',
    description: 'The struggle resolved by state (no presses): one draw at contestOpen. The press fields beside it retire when Encounter switches the struggle over.',
    required: ['base', 'stanceRead', 'kiBonus', 'rallyPenalty', 'tiltPerMinute', 'tiltAfter', 'floor'],
    properties: {
      base: { type: 'number', minimum: 0, maximum: 1 },
      stanceRead: {
        type: 'object',
        required: ['match', 'other', 'matches'],
        properties: {
          match: { type: 'number', minimum: 0, maximum: 1 },
          other: { type: 'number', minimum: 0, maximum: 1 },
          matches: { type: 'object', required: ['launch', 'melee', 'beam'], properties: { launch: stance, melee: stance, beam: stance }, additionalProperties: false },
        },
        ...closed,
      },
      kiBonus: { type: 'object', required: ['atLeast', 'add'], properties: { atLeast: { type: 'number', minimum: 0 }, add: { type: 'number' } }, additionalProperties: false },
      rallyPenalty: { type: 'number', minimum: 0 },
      tiltPerMinute: { type: 'number', minimum: 0 },
      tiltAfter: { type: 'number', minimum: 0 },
      floor: { type: 'number', minimum: 0, maximum: 1 },
      fighterState: { type: 'string' },
      pulses: { type: 'string' },
    },
    ...closed,
  };
  wj(f, s);
}

// =============================== combat-styles: (9) heat table and blitz cap ===============================
{
  const f = 'tools/schemas/combat-styles.schema.json';
  const s = rj(f);
  const chainP = s.properties.chains.properties.chainP;
  delete chainP.properties.heatBoiling;
  chainP.properties.heat = {
    type: 'object',
    description: 'Heat bonus added to the chain probability for fighters with the heat track, by heat stage. Replaces heatBoiling.',
    required: ['Heated', 'Simmering', 'Boiling'],
    properties: { Heated: { type: 'number' }, Simmering: { type: 'number' }, Boiling: { type: 'number' } },
    ...closed,
  };
  if (!chainP.required.includes('heat')) chainP.required.push('heat');
  const chance = s.properties.chains.properties.blitz.properties.chance;
  chance.properties.cap = { type: 'number', minimum: 0, maximum: 1, description: 'The blitz chance never exceeds this (balance-targets.md section 12).' };
  if (!chance.required.includes('cap')) chance.required.push('cap');
  // a style may be held with a weight of 0 (Combat's teleport hold: blink_clash)
  s.$defs.style.properties.weight.properties.base = { type: 'number', minimum: 0 };
  wj(f, s);
}

// =============================== xref ===============================
// branch profiles, selectorByProfile / condition-else branch references, the style blitz-cap warning
edit('tools/lib/xref.js', [[
  "      const s = t.selector;\n      if (isObj(s)) {\n        const refs = [['branch', s.branch], ['ifBelow', s.ifBelow], ['else', s.else], ['ifGreater', s.ifGreater]];",
  "      // a branch needs parity, spaced and spacedTiming unless it (or its template) is for some profiles only\n      t.branches.forEach((b, bi) => {\n        if (!isObj(b) || t.only !== undefined || b.only !== undefined) return;\n        for (const k of ['parity', 'spaced', 'spacedTiming']) if (b[k] === undefined) err(TPL, `/templates/${ti}/branches/${bi}`, 'branch-profiles', `branch \"${b.id}\" has no ${k}; a branch without \"only\" carries parity and spaced beats`);\n        if (b.dynamic !== undefined && b.dynamicTiming === undefined) err(TPL, `/templates/${ti}/branches/${bi}`, 'branch-profiles', `branch \"${b.id}\" has dynamic beats but no dynamicTiming`);\n      });\n      const selectors = [['selector', t.selector], ...Object.entries(isObj(t.selectorByProfile) ? t.selectorByProfile : {}).map(([p, sel]) => [`selectorByProfile/${p}`, sel])];\n      for (const [where, s] of selectors) {\n        if (!isObj(s)) continue;\n        const elseRefs = isObj(s.else) ? [['else/then', s.else.then], ['else/else', s.else.else]] : [['else', s.else]];\n        const refs = [['branch', s.branch], ['ifBelow', s.ifBelow], ...elseRefs, ['then', s.then], ['ifGreater', s.ifGreater]];",
], [
  "`/templates/${ti}/selector/${key}`, 'selector-branch'",
  "`/templates/${ti}/${where}/${key}`, 'selector-branch'",
]]);
console.log('xref edited');

// the blitz cap warning (styles): the chance should not sit above the cap that clips it
edit('tools/lib/xref-fight.js', [[
  '    // Tempo names used in beats',
  [
    '    // The blitz chance cap should not sit below the chances it caps (it would silently clip them).',
    '    const bl = isObj(styles.chains) && isObj(styles.chains.blitz) ? styles.chains.blitz.chance : undefined;',
    "    if (isObj(bl) && typeof bl.cap === 'number') {",
    "      for (const k of ['Tense', 'Frenzied']) {",
    "        if (typeof bl[k] === 'number' && bl[k] > bl.cap) err(STYLES, '/chains/blitz/chance/' + k, 'style-blitz-cap', k + ' chance ' + bl[k] + ' is above the cap ' + bl.cap + ', so it is always clipped', 'warning');",
    '      }',
    '    }',
    '    // Tempo names used in beats',
  ].join('\n'),
]]);

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  // the dependentRequired both ways became an xref (a branch without "only" needs dynamicTiming with dynamic)
  const old = c.cases.find((k) => k.id === 'templates-dynamic-needs-timing');
  if (old) old.expect = { rule: 'xref:branch-profiles', pointer: '/templates/6/branches/0' };
  const T = 'data/combat/templates.json';
  const F = 'data/combat/finishers.json';
  const S = 'data/combat/styles.json';
  const tc = (id, mut, expect) => ({ id: '2b-' + id, schema: 'combat-templates.schema.json', mutate: [{ file: T, ...mut }], expect });
  const fc = (id, mut, expect) => ({ id: '2b-' + id, schema: 'combat-finishers.schema.json', mutate: [{ file: F, ...mut }], expect });
  const sc = (id, mut, expect) => ({ id: '2b-' + id, schema: 'combat-styles.schema.json', mutate: [{ file: S, ...mut }], expect });
  const add = [
    tc('trigger-defender-enum', { set: { '/templates/7/trigger/defender': 'FLOATING' } }, { rule: 'enum', pointer: '/templates/7/trigger/defender' }),
    tc('trigger-needs-defender-or-context', { del: ['/templates/9/trigger/context'] }, { rule: 'oneOf', pointer: '/templates/9/trigger' }),
    tc('only-enum', { set: { '/templates/7/only': ['turbo'] } }, { rule: 'enum', pointer: '/templates/7/only/0' }),
    tc('branch-needs-parity', { del: ['/templates/0/branches/0/parity'] }, { rule: 'xref:branch-profiles', pointer: '/templates/0/branches/0' }),
    tc('branch-interrupt-enum', { set: { '/templates/3/branches/0/interrupts/0': 'parry' } }, { rule: 'enum', pointer: '/templates/3/branches/0/interrupts/0' }),
    tc('strike-class-enum', { set: { '/templates/0/branches/0/dynamic/2/args/o/class': 'weak' } }, { rule: 'enum', pointer: '/templates/0/branches/0/dynamic/2/args/o/class' }),
    tc('no-parry-still-valid', { set: { '/templates/0/branches/0/dynamic/2/args/o/noParry': true } }, null),
    tc('profile-selector-name', { set: { '/templates/2/selectorByProfile/turbo': { kind: 'fixed', branch: 'read' } } }, { rule: 'propertyNames', pointer: '/templates/2/selectorByProfile/turbo' }),
    tc('condition-selector-needs-then', { del: ['/templates/7/selector/then'] }, { rule: 'required', pointer: '/templates/7/selector' }),
    tc('condition-selector-branch', { set: { '/templates/7/selector/then': 'nowhere' } }, { rule: 'xref:selector-branch', pointer: '/templates/7/selector/then' }),
    tc('else-condition-branch', { set: { '/templates/2/selectorByProfile/dynamic/else/then': 'nowhere' } }, { rule: 'xref:selector-branch', pointer: '/templates/2/selectorByProfile/dynamic/else/then' }),
    tc('defender-add-type', { set: { '/templates/5/selectorByProfile/dynamic/defenderAdd/then': 'high' } }, { rule: 'type', pointer: '/templates/5/selectorByProfile/dynamic/defenderAdd/then' }),
    tc('condition-is-type', { set: { '/beam/outcomeByProfile/dynamic/rules/0/if/is': 5 } }, { rule: 'type', pointer: '/beam/outcomeByProfile/dynamic/rules/0/if/is' }),
    tc('dynamic-needs-windups', { del: ['/profiles/dynamic/windups'] }, { rule: 'required', pointer: '/profiles/dynamic' }),
    tc('windup-ticks-integer', { set: { '/profiles/dynamic/windups/ender': 18.5 } }, { rule: 'type', pointer: '/profiles/dynamic/windups/ender' }),
    tc('perfect-block-needs-stagger', { del: ['/profiles/dynamic/perfectBlock/staggerTicks'] }, { rule: 'required', pointer: '/profiles/dynamic/perfectBlock' }),
    tc('min-heavy-positive', { set: { '/profiles/dynamic/approach/minHeavy': 0 } }, { rule: 'exclusiveMinimum', pointer: '/profiles/dynamic/approach/minHeavy' }),
    tc('ender-windup-type', { set: { '/profiles/dynamic/tempo/enderWindup': 'long' } }, { rule: 'type', pointer: '/profiles/dynamic/tempo/enderWindup' }),
    tc('strike-class-list-enum', { set: { '/profiles/dynamic/strikeClass/classes/0': 'weak' } }, { rule: 'enum', pointer: '/profiles/dynamic/strikeClass/classes/0' }),
    tc('interrupt-unknown', { set: { '/interrupts/parry': { beats: [] } } }, { rule: 'additionalProperties', pointer: '/interrupts/parry' }),
    tc('interrupt-stagger-needs-ticks', { del: ['/interrupts/perfect_block/beats/1/args/ticks'] }, { rule: 'required', pointer: '/interrupts/perfect_block/beats/1/args' }),
    tc('when-enum', { set: { '/templates/9/branches/0/dynamic/3/when': 'sometimes' } }, { rule: 'enum', pointer: '/templates/9/branches/0/dynamic/3/when' }),
    tc('beam-outcome-enum', { set: { '/beam/outcomeByProfile/dynamic/rules/2/out': 'MISS' } }, { rule: 'enum', pointer: '/beam/outcomeByProfile/dynamic/rules/2/out' }),
    tc('beam-decide-at', { set: { '/beam/outcomeByProfile/dynamic/decideAt': 'never' } }, { rule: 'enum', pointer: '/beam/outcomeByProfile/dynamic/decideAt' }),
    tc('beam-clash-score-side', { set: { '/beam/outcomeByProfile/dynamic/rules/1/clashScoreAdd/X': -5 } }, { rule: 'propertyNames', pointer: '/beam/outcomeByProfile/dynamic/rules/1/clashScoreAdd/X' }),
    fc('kind-enum', { set: { '/finishers/2/kind': 'sniper' } }, { rule: 'enum', pointer: '/finishers/2/kind' }),
    fc('kind-required', { del: ['/finishers/2/kind'] }, { rule: 'required', pointer: '/finishers/2' }),
    fc('by-state-type', { set: { '/contest/struggle/byState/base': 'high' } }, { rule: 'type', pointer: '/contest/struggle/byState/base' }),
    fc('by-state-read-enum', { set: { '/contest/struggle/byState/stanceRead/matches/launch': 'SPRINT' } }, { rule: 'enum', pointer: '/contest/struggle/byState/stanceRead/matches/launch' }),
    fc('by-state-needs-read', { del: ['/contest/struggle/byState/stanceRead'] }, { rule: 'required', pointer: '/contest/struggle/byState' }),
    sc('heat-stage-required', { del: ['/chains/chainP/heat/Boiling'] }, { rule: 'required', pointer: '/chains/chainP/heat' }),
    sc('heat-type', { set: { '/chains/chainP/heat/Simmering': 'hot' } }, { rule: 'type', pointer: '/chains/chainP/heat/Simmering' }),
    sc('heat-boiling-retired', { set: { '/chains/chainP/heatBoiling': 0.2 } }, { rule: 'additionalProperties', pointer: '/chains/chainP/heatBoiling' }),
    sc('blitz-cap-range', { set: { '/chains/blitz/chance/cap': 1.4 } }, { rule: 'maximum', pointer: '/chains/blitz/chance/cap' }),
    sc('blitz-cap-required', { del: ['/chains/blitz/chance/cap'] }, { rule: 'required', pointer: '/chains/blitz/chance' }),
    sc('style-weight-zero-held-ok', { set: { '/styles/0/weight/base': 0 } }, null),
    sc('style-weight-negative', { set: { '/styles/0/weight/base': -1 } }, { rule: 'minimum', pointer: '/styles/0/weight/base' }),
    sc('blitz-cap-clips', { set: { '/chains/blitz/chance/cap': 0.3 } }, { rule: 'xref:style-blitz-cap', pointer: '/chains/blitz/chance/Frenzied' }),
  ];
  let added = 0;
  for (const k of add) if (!c.cases.some((x) => x.id === k.id)) { c.cases.push(k); added++; }
  wj(cf, c);
  console.log(`2b schema changes applied (${added} new cases)`);
}
