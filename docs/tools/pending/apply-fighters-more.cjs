// Run once from the repo root, in the commit where Animation lands data/anim/fighters.json with `waves.more`
// (the waves that are a fighter's besides strikes, entries and energy, or the pair's shared pair1).
// Does not edit data/. Re-runnable: a second run changes nothing.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');

// ---- schema ----
{
  const f = 'tools/schemas/anim-fighters.schema.json';
  const s = rj(f);
  const w = s.properties.fighters.additionalProperties.properties.waves;
  if (!w.properties.more) {
    w.properties.more = {
      type: 'array',
      uniqueItems: true,
      items: { type: 'string', pattern: '^[a-z]+[0-9]+$' },
      description: 'Every other pose wave that is his: his finisher, taunts, blast presses and the rest, or the pair\'s shared wave (data/anim/waves/<wave>.poses.json).',
    };
    w.description = 'The pose waves that carry his strikes, his entries and his energy poses, and `more`: the rest that are his.';
    s.description = s.description.replace('waves: the pose waves that carry his strikes, his entries and his energy poses.', () => 'waves: the pose waves that carry his strikes, his entries and his energy poses, and `more`, every other wave that is his (the pair\'s shared wave too).')
      .replace('every named wave has a poses file', () => 'every named wave (the `more` ones too) has a poses file');
    wj(f, s);
  }
}

// ---- xref: every wave of `more` has a poses file; one already named as strikes, entries or energy is a warning ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('waves/more')) {
    const anchor = "      if (isObj(fd.timing)) for (const k of ['light', 'heavy'])";
    if (!t.includes(anchor)) throw new Error('fighters more anchor');
    t = t.replace(anchor, () => [
      "      if (isObj(fd.waves) && Array.isArray(fd.waves.more)) fd.waves.more.forEach((w, i) => {",
      "        if (typeof w !== 'string') return;",
      "        if (!get(`data/anim/waves/${w}.poses.json`)) err(AF, `${at}/waves/more/${i}`, 'fighters-wave', `more wave \"${w}\" has no data/anim/waves/${w}.poses.json`);",
      "        else if (['strikes', 'entries', 'energy'].some((k) => fd.waves[k] === w)) err(AF, `${at}/waves/more/${i}`, 'fighters-wave', `wave \"${w}\" is already named as ${['strikes', 'entries', 'energy'].find((k) => fd.waves[k] === w)}; it need not be in more`, 'warning');",
      "      });",
      anchor,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- cases ----
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const F = 'data/anim/fighters.json';
  const profile = { hand_states: { claw: 'open' }, rise: 3, stance: 1, twist: 1.15, guard_raise: 3, head_pitch: -3 };
  const one = (waves) => ({ set: { '/fighters/test': { shape: 'P', waves, pose_profile: profile } } });
  const fx = (n, mut, expect) => ({ id: 'anim-fighters-' + n, schema: 'anim-fighters.schema.json', mutate: [{ file: F, ...mut }], expect });
  const P = '/fighters/test/waves/more';
  const add = [
    fx('waves-more-ok', one({ strikes: 'protag1', more: ['protag4'] }), null),
    fx('waves-more-two-ok', one({ strikes: 'protag1', more: ['protag4', 'rival1'] }), null),
    fx('waves-more-empty-ok', one({ strikes: 'protag1', more: [] }), null),
    fx('waves-more-type', one({ strikes: 'protag1', more: 'protag4' }), { rule: 'type', pointer: P }),
    fx('waves-more-item-type', one({ strikes: 'protag1', more: [4] }), { rule: 'type', pointer: P + '/0' }),
    fx('waves-more-item-shape', one({ strikes: 'protag1', more: ['Protag 4'] }), { rule: 'pattern', pointer: P + '/0' }),
    fx('waves-more-duplicate', one({ strikes: 'protag1', more: ['protag4', 'protag4'] }), { rule: 'uniqueItems', pointer: P + '/1' }),
    fx('waves-more-without-poses', one({ strikes: 'protag1', more: ['protag9'] }), { rule: 'xref:fighters-wave', pointer: P + '/0' }),
    fx('waves-more-second-without-poses', one({ strikes: 'protag1', more: ['protag4', 'protag9'] }), { rule: 'xref:fighters-wave', pointer: P + '/1' }),
    fx('waves-more-repeats-named-wave-warns', one({ strikes: 'protag1', more: ['protag1'] }), { rule: 'xref:fighters-wave', pointer: P + '/0' }),
    fx('waves-more-repeats-energy-warns', one({ strikes: 'protag1', energy: 'protag3', more: ['protag3'] }), { rule: 'xref:fighters-wave', pointer: P + '/0' }),
    fx('waves-more-note-ok', one({ strikes: 'protag1', _more: 'comment', more: ['protag4'] }), null),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log('fighters waves.more applied (' + n + ' new cases)');
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('each of `more`')) {
    const a = 'every wave it names (strikes, entries, energy) has a poses file';
    if (!t.includes(a)) throw new Error('fighters README row');
    t = t.replace(a, () => 'every wave it names (strikes, entries, energy, and each of `more`) has a poses file, and a `more` wave already named as strikes, entries or energy is a warning');
    fs.writeFileSync(f, t);
  }
}
