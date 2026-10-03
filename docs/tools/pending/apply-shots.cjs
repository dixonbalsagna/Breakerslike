// Run once from the repo root, in the commit where Simulation's shots slice lands its data/fight/shots.json
// (deflect speedMul, arcNear and arcFar; the mine's fuseBodyTicks and fuseShotTicks).
// Does not edit data/. Re-runnable: a second run changes nothing.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const keep = (o, order, rename) => {
  const out = {};
  for (const k of Object.keys(o)) {
    if (rename[k]) for (const [nk, nv] of rename[k]) out[nk] = nv;
    else out[k] = o[k];
  }
  return out;
};

// ---- schema ----
{
  const f = 'tools/schemas/fight-shots.schema.json';
  const s = rj(f);
  const d = s.properties.deflect;
  if (d.properties.speed) {
    d.properties = keep(d.properties, null, {
      speed: [['speedMul', { type: 'number', exclusiveMinimum: 0, description: 'The wild shot flies at this share of its own kind\'s speed.' }]],
      arcPer: [
        ['arcNear', { type: 'number', minimum: 0, description: 'The arc\'s height per unit of landing distance in the near band.' }],
        ['arcFar', { type: 'number', minimum: 0, description: 'The arc\'s height per unit of landing distance in the far band.' }],
      ],
    });
    d.required = d.required.flatMap((k) => (k === 'speed' ? ['speedMul'] : k === 'arcPer' ? ['arcNear', 'arcFar'] : [k]));
    const m = s.properties.kinds.additionalProperties.properties.mine;
    m.properties = keep(m.properties, null, {
      fuseTicks: [
        ['fuseBodyTicks', { type: 'integer', minimum: 0, description: 'Ticks from set off to blast when a body set it off (a fighter in the trigger radius, or a blow).' }],
        ['fuseShotTicks', { type: 'integer', minimum: 0, description: 'Ticks from set off to blast when a shot set it off.' }],
      ],
    });
    m.required = m.required.flatMap((k) => (k === 'fuseTicks' ? ['fuseBodyTicks', 'fuseShotTicks'] : [k]));
    s.description = s.description.replace('what a deflect does,', 'what a deflect does (the share of its kind\'s speed, the arc by band),');
    wj(f, s);
  }
}

// ---- xref: the deflect's bands and the mine's fuses and chain ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'shots-deflect'")) {
    const anchor = "  // ---- biomes blast: every shot kind has an entry; the tier multipliers do not fall ----";
    if (!t.includes(anchor)) throw new Error('shots anchor');
    t = t.replace(anchor, () => [
      "  // ---- fight shots: the deflect's bands are ordered; a mine chains at least as far as it blasts and a shot sets it off no later than a body ----",
      "  if (isObj(shotsD)) {",
      "    const SH = 'data/fight/shots.json';",
      "    const dfl = shotsD.deflect;",
      "    if (isObj(dfl)) {",
      "      if (typeof dfl.nearMin === 'number' && typeof dfl.nearMax === 'number' && dfl.nearMin > dfl.nearMax) err(SH, '/deflect/nearMin', 'shots-deflect', `nearMin ${dfl.nearMin} is above nearMax ${dfl.nearMax}`);",
      "      if (typeof dfl.farMin === 'number' && typeof dfl.farMax === 'number' && dfl.farMin > dfl.farMax) err(SH, '/deflect/farMin', 'shots-deflect', `farMin ${dfl.farMin} is above farMax ${dfl.farMax}`);",
      "      if (typeof dfl.nearMax === 'number' && typeof dfl.farMin === 'number' && dfl.nearMax > dfl.farMin) err(SH, '/deflect/farMin', 'shots-deflect', `the near band reaches ${dfl.nearMax} but the far band starts at ${dfl.farMin}; the bands overlap`, 'warning');",
      "      if (typeof dfl.arcNear === 'number' && typeof dfl.arcFar === 'number' && dfl.arcFar < dfl.arcNear) err(SH, '/deflect/arcFar', 'shots-deflect', `arcFar ${dfl.arcFar} is below arcNear ${dfl.arcNear}; a far deflect should arc at least as high`, 'warning');",
      "    }",
      "    for (const [name, k] of Object.entries(isObj(shotsD.kinds) ? shotsD.kinds : {})) {",
      "      if (name.startsWith('_') || !isObj(k) || !isObj(k.mine)) continue;",
      "      const m = k.mine;",
      "      if (typeof m.chainR === 'number' && typeof m.blastR === 'number' && m.chainR < m.blastR) err(SH, `/kinds/${esc(name)}/mine/chainR`, 'shots-mine', `chainR ${m.chainR} is below blastR ${m.blastR}; a blast would reach mines it cannot set off`, 'warning');",
      "      if (typeof m.fuseShotTicks === 'number' && typeof m.fuseBodyTicks === 'number' && m.fuseShotTicks > m.fuseBodyTicks) err(SH, `/kinds/${esc(name)}/mine/fuseShotTicks`, 'shots-mine', `a shot sets the mine off after ${m.fuseShotTicks} ticks, later than a body (${m.fuseBodyTicks})`, 'warning');",
      "    }",
      "  }",
      "",
      anchor,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// ---- the validator fixture gets a deflect, the mine row and the mine limits ----
{
  const f = 'tools/fixtures/virtual/data/fight/shots.json';
  const o = rj(f);
  if (!o.deflect) {
    const live = fs.existsSync('data/fight/shots.json') ? rj('data/fight/shots.json') : null;
    const useLive = live && live.deflect && live.deflect.speedMul !== undefined && live.kinds.mine && live.kinds.mine.mine && live.kinds.mine.mine.fuseBodyTicks !== undefined;
    const deflect = useLive
      ? Object.fromEntries(Object.entries(live.deflect).filter(([k]) => !k.startsWith('_')))
      : { scatter: false, nearMin: 300, nearMax: 1500, farMin: 1500, farMax: 3000, farChance: 0.15, awayChance: 0.75, speedMul: 0.8, minTicks: 12, arcNear: 0.15, arcFar: 0.35, safeTicks: 10, backCos: 0.866 };
    const mine = useLive
      ? Object.fromEntries(Object.entries(live.kinds.mine).filter(([k]) => !k.startsWith('_')))
      : { speed: 0, r: 30, power: 3, dmg: 52.8, lifeTicks: 1200, mine: { trigR: 112.5, blastR: 150, chainR: 225, armTicks: 30, fuseBodyTicks: 8, fuseShotTicks: 0, chainTicks: 6, ownShare: 0.3, tierR: [1, 1, 1.25, 1.5] } };
    const out = {};
    for (const k of Object.keys(o)) {
      out[k] = o[k];
      if (k === 'bodyR') { out.structures = true; out.deflect = deflect; out.mineCap = 6; out.mineGap = 150; }
    }
    out.kinds = Object.assign({}, o.kinds, { mine });
    wj(f, out);
  }
}

// ---- cases ----
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const S = 'data/fight/shots.json';
  const sh = (n, mut, expect) => ({ id: 'shots-' + n, schema: 'fight-shots.schema.json', mutate: [{ file: S, ...mut }], expect });
  const D = '/deflect/';
  const M = '/kinds/mine/mine/';
  const add = [
    sh('deflect-speed-retired', { set: { [D + 'speed']: 50 } }, { rule: 'additionalProperties', pointer: D + 'speed' }),
    sh('deflect-arc-per-retired', { set: { [D + 'arcPer']: 0.25 } }, { rule: 'additionalProperties', pointer: D + 'arcPer' }),
    sh('deflect-speed-mul-required', { del: [D + 'speedMul'] }, { rule: 'required', pointer: '/deflect' }),
    sh('deflect-speed-mul-zero', { set: { [D + 'speedMul']: 0 } }, { rule: 'exclusiveMinimum', pointer: D + 'speedMul' }),
    sh('deflect-speed-mul-type', { set: { [D + 'speedMul']: 'fast' } }, { rule: 'type', pointer: D + 'speedMul' }),
    sh('deflect-speed-mul-above-one-ok', { set: { [D + 'speedMul']: 1.5 } }, null),
    sh('deflect-arc-near-required', { del: [D + 'arcNear'] }, { rule: 'required', pointer: '/deflect' }),
    sh('deflect-arc-far-required', { del: [D + 'arcFar'] }, { rule: 'required', pointer: '/deflect' }),
    sh('deflect-arc-near-negative', { set: { [D + 'arcNear']: -0.1 } }, { rule: 'minimum', pointer: D + 'arcNear' }),
    sh('deflect-arc-far-negative', { set: { [D + 'arcFar']: -0.1 } }, { rule: 'minimum', pointer: D + 'arcFar' }),
    sh('deflect-arc-zero-ok', { set: { [D + 'arcNear']: 0, [D + 'arcFar']: 0 } }, null),
    sh('deflect-arc-far-below-near-warns', { set: { [D + 'arcFar']: 0.05 } }, { rule: 'xref:shots-deflect', pointer: D + 'arcFar' }),
    sh('deflect-near-band-reversed', { set: { [D + 'nearMin']: 2000 } }, { rule: 'xref:shots-deflect', pointer: D + 'nearMin' }),
    sh('deflect-far-band-reversed', { set: { [D + 'farMin']: 4000 } }, { rule: 'xref:shots-deflect', pointer: D + 'farMin' }),
    sh('deflect-bands-overlap-warns', { set: { [D + 'nearMax']: 2000 } }, { rule: 'xref:shots-deflect', pointer: D + 'farMin' }),
    sh('deflect-bands-touch-ok', { set: { [D + 'nearMax']: 1500 } }, null),
    sh('mine-fuse-retired', { set: { [M + 'fuseTicks']: 0 } }, { rule: 'additionalProperties', pointer: M + 'fuseTicks' }),
    sh('mine-fuse-body-required', { del: [M + 'fuseBodyTicks'] }, { rule: 'required', pointer: '/kinds/mine/mine' }),
    sh('mine-fuse-shot-required', { del: [M + 'fuseShotTicks'] }, { rule: 'required', pointer: '/kinds/mine/mine' }),
    sh('mine-fuse-body-negative', { set: { [M + 'fuseBodyTicks']: -1 } }, { rule: 'minimum', pointer: M + 'fuseBodyTicks' }),
    sh('mine-fuse-shot-negative', { set: { [M + 'fuseShotTicks']: -1 } }, { rule: 'minimum', pointer: M + 'fuseShotTicks' }),
    sh('mine-fuse-body-integer', { set: { [M + 'fuseBodyTicks']: 7.5 } }, { rule: 'type', pointer: M + 'fuseBodyTicks' }),
    sh('mine-fuse-shot-integer', { set: { [M + 'fuseShotTicks']: 0.5 } }, { rule: 'type', pointer: M + 'fuseShotTicks' }),
    sh('mine-fuse-both-zero-ok', { set: { [M + 'fuseBodyTicks']: 0, [M + 'fuseShotTicks']: 0 } }, null),
    sh('mine-fuse-shot-after-body-warns', { set: { [M + 'fuseShotTicks']: 12 } }, { rule: 'xref:shots-mine', pointer: M + 'fuseShotTicks' }),
    sh('mine-fuse-equal-ok', { set: { [M + 'fuseShotTicks']: 8 } }, null),
    sh('mine-chain-below-blast-warns', { set: { [M + 'chainR']: 100 } }, { rule: 'xref:shots-mine', pointer: M + 'chainR' }),
    sh('mine-chain-equals-blast-ok', { set: { [M + 'chainR']: 150 } }, null),
  ];
  // the mine's blast row should carry areaShare (xref blast-kind, in the tree since this script was written)
  const oldMine = c.cases.find((k) => k.id === 'biomes-blast-mine-optional-area-share-ok');
  if (oldMine) { oldMine.id = 'biomes-blast-mine-area-share-absent-warns'; oldMine.expect = { rule: 'xref:blast-kind', pointer: '/kinds/mine' }; }
  const B = 'data/biomes/blast.json';
  const bl = (n, mut, expect) => ({ id: 'biomes-blast-' + n, schema: 'biomes-blast.schema.json', mutate: [{ file: B, ...mut }], expect });
  add.push(
    bl('mine-row-missing-warns', { del: ['/kinds/mine'] }, { rule: 'xref:blast-kind', pointer: '/kinds' }),
    bl('mine-area-share-present-ok', { set: { '/kinds/mine/areaShare': 0.5 } }, null),
  );
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log('shots slice schema applied (' + n + ' new cases)');
}

// ---- docs ----
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('shots-deflect')) {
    const a = '| `shots-lob`, `shots-order` | data/fight/shots.json: ';
    const b = 'a kind that trades with more power does not do less damage (a warning) |';
    if (!t.includes(a) || !t.includes(b)) throw new Error('shots README row');
    t = t.replace(a, () => '| `shots-lob`, `shots-order`, `shots-deflect`, `shots-mine` | data/fight/shots.json: ')
      .replace(b, () => 'a kind that trades with more power does not do less damage (a warning); the deflect\'s near and far bands are each ordered (an error) and do not overlap, and its far arc is not below its near arc (warnings); a mine\'s chainR is not below its blastR and a shot sets it off no later than a body (warnings) |');
    fs.writeFileSync(f, t);
  }
}
