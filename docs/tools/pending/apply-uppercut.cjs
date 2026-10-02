// Schema for Encounter's slam lever: UPPERCUT's direction in data/director/launch.json (docs/director/pending/step3/apply-slam.cjs).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit where Encounter adds `uppercut` to data/director/launch.json
// (the live value is {"ux": 0.85, "uy": 1.0, "_note": "..."}, placed before craterSlam):
//     node docs/tools/pending/apply-uppercut.cjs
// It makes `uppercut` a required key of tools/schemas/director-launch.schema.json (a closed object: ux a number of 0 or more, uy a number above 0),
// adds the xref rule (launch-direction: uppercut.uy must be above 0, as craterSlam.uy is checked below 0), puts uppercut in the validator fixture
// tools/fixtures/virtual/data/director/launch.json and adds the cases. It does NOT edit data/. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };

// =============================== schema ===============================
{
  const f = 'tools/schemas/director-launch.schema.json';
  const s = rj(f);
  if (!s.properties.uppercut) {
    const up = Object.assign({
      type: 'object',
      description: 'The UPPERCUT launch direction: ux along the launcher\'s facing (0 or more), uy up (above 0). The slam lever: the direction was in the planner\'s code before.',
      required: ['ux', 'uy'],
      properties: {
        ux: { type: 'number', minimum: 0, description: 'Along the launcher\'s facing; 0 or more.' },
        uy: { type: 'number', exclusiveMinimum: 0, description: 'Up; above 0 (an uppercut goes up).' },
      },
    }, closed);
    // property and required order: uppercut before craterSlam, as the data has it
    const props = {};
    for (const k of Object.keys(s.properties)) { if (k === 'craterSlam') props.uppercut = up; props[k] = s.properties[k]; }
    s.properties = props;
    const i = s.required.indexOf('craterSlam');
    s.required.splice(i >= 0 ? i : s.required.length, 0, 'uppercut');
    s.description = s.description.replace('the downward direction of CRATER SLAM are checked', 'the downward direction of CRATER SLAM and the upward direction of UPPERCUT are checked');
    wj(f, s);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'launch-direction', `uppercut.uy")) {
    const a = "    const cs = launch.craterSlam;";
    if (!t.includes(a)) throw new Error('launch xref anchor');
    t = t.replace(a, () => [
      "    const up = launch.uppercut;",
      "    if (isObj(up) && typeof up.uy === 'number' && up.uy <= 0) err(LF, '/uppercut/uy', 'launch-direction', `uppercut.uy ${up.uy} is not upward (positive is up), so UPPERCUT would not lift`);",
      a,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== fixture ===============================
{
  const f = 'tools/fixtures/virtual/data/director/launch.json';
  const o = rj(f);
  if (!o.uppercut) {
    const out = {};
    for (const k of Object.keys(o)) { if (k === 'craterSlam') out.uppercut = { ux: 0.85, uy: 1.0 }; out[k] = o[k]; }
    wj(f, out);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const L = 'data/director/launch.json';
  const k = (n, mut, expect) => ({ id: 'director-launch-' + n, schema: 'director-launch.schema.json', mutate: [{ file: L, ...mut }], expect });
  const add = [
    k('uppercut-valid', { set: { '/uppercut': { ux: 0.85, uy: 1.0 } } }, null),
    k('uppercut-required', { del: ['/uppercut'] }, { rule: 'required', pointer: '' }),
    k('uppercut-note-ok', { set: { '/uppercut/_note': 'comment' } }, null),
    k('uppercut-key-required', { del: ['/uppercut/uy'] }, { rule: 'required', pointer: '/uppercut' }),
    k('uppercut-ux-required', { del: ['/uppercut/ux'] }, { rule: 'required', pointer: '/uppercut' }),
    k('uppercut-unknown-key', { set: { '/uppercut/uz': 1 } }, { rule: 'additionalProperties', pointer: '/uppercut/uz' }),
    k('uppercut-ux-negative', { set: { '/uppercut/ux': -0.1 } }, { rule: 'minimum', pointer: '/uppercut/ux' }),
    k('uppercut-ux-zero-ok', { set: { '/uppercut/ux': 0 } }, null),
    k('uppercut-uy-zero', { set: { '/uppercut/uy': 0 } }, { rule: 'exclusiveMinimum', pointer: '/uppercut/uy' }),
    k('uppercut-uy-down', { set: { '/uppercut/uy': -1 } }, { rule: 'xref:launch-direction', pointer: '/uppercut/uy' }),
    k('uppercut-uy-type', { set: { '/uppercut/uy': 'up' } }, { rule: 'type', pointer: '/uppercut/uy' }),
    k('uppercut-ux-type', { set: { '/uppercut/ux': 'forward' } }, { rule: 'type', pointer: '/uppercut/ux' }),
  ];
  let n = 0;
  for (const x of add) if (!c.cases.some((y) => y.id === x.id)) { c.cases.push(x); n++; }
  wj(cf, c);
  console.log(`uppercut schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('uppercut.uy')) {
    t = t.replace("CRATER SLAM's uy is negative (a warning if not)", () => "CRATER SLAM's uy is negative (a warning if not) and UPPERCUT's uy is positive (an error if not)");
    fs.writeFileSync(f, t);
  }
}
