// Schema keys for Combat's slice 11 recipes (docs/combat/pending/recipes.slice11.json, which becomes data/combat/recipes.json):
// the required top-level `pieces` block, one row per strike id: {limb, target}. NOT run by CI, the validator or the sim. Run once from the
// repo root, in the commit where the file lands as data/combat/recipes.json (drop _target and _changes), after apply-recipes.cjs (which is
// applied already):
//     node docs/tools/pending/apply-pieces.cjs
// It does NOT edit data/. It adds `pieces` to tools/schemas/combat-recipes.schema.json (required; _ keys are notes; every other key is a
// piece id with a closed {limb, target} value, both required), the validator fixture's `pieces` (from the live file if it has them, else
// from the draft), the rule recipes-pieces and a recipes-blur that reads pieces instead of the manifests, and the cases:
//   - every pool id and showcase strike has a pieces row (error); a row nothing uses is a warning
//   - a row's target is a region of sockets.json (error)
//   - a piece that is not waiting in any pool has the limb (without _l or _r) and the target of each of its manifest rows (error)
//   - a blur pattern's steps are filled from the pieces of the fighter's blur.base and blur.toward pools that are not waiting; a step a
//     pattern uses k times needs k such pieces (error)
//   - the optional `patternGates` (pattern name to {stick: "toward", ground: true, fighters: [pool keys]}, at least one of the three; `_` keys
//     are notes): every key names a pattern of blurPatterns and every fighter is a key of pools; recipes-blur checks a pattern only for the
//     fighters it is for
// Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const LIMBS = ['hand', 'foot', 'elbow', 'knee', 'shoulder', 'head', 'own'];

// =============================== schema ===============================
{
  const f = 'tools/schemas/combat-recipes.schema.json';
  const s = rj(f);
  if (!s.properties.pieces) {
    const props = {};
    for (const k of Object.keys(s.properties)) {
      props[k] = s.properties[k];
      if (k === 'patternRule') {
        props.pieces = {
          type: 'object',
          minProperties: 1,
          propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*([.][a-z0-9_]+)*)$' },
          description: 'Each pool strike\'s striking limb and the socket it lands on, one row per strike id, shared by both fighters (each fighter\'s own key set plays it).',
          additionalProperties: obj({
            limb: { enum: LIMBS, description: 'The striking limb: hand, foot, elbow, knee, shoulder, head or own.' },
            target: { type: 'string', pattern: '^[a-z][a-z_]*$', description: 'A socket (region) of data/anim/sockets.json.' },
          }),
          patternProperties: { '^_': true },
        };
      }
    }
    if (!props.pieces) throw new Error('patternRule anchor');
    s.properties = props;
    s.required.push('pieces');
    wj(f, s);
  }
}

{
  const f = 'tools/schemas/combat-recipes.schema.json';
  const s = rj(f);
  if (!s.properties.patternGates) {
    const props = {};
    for (const k of Object.keys(s.properties)) {
      props[k] = s.properties[k];
      if (k === 'blurPatterns') {
        props.patternGates = {
          type: 'object',
          propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
          description: 'Optional. When a blur pattern may be drawn, read at the string\'s first blow; a pattern with no row is always open. stick: the stick toward; ground: both fighters on the ground; fighters: only these fighters\' strings draw it.',
          additionalProperties: Object.assign({
            type: 'object',
            properties: {
              stick: { const: 'toward', description: 'Open only with the stick toward at that press.' },
              ground: { const: true, description: 'Open only with both fighters on the ground.' },
              fighters: { type: 'array', minItems: 1, uniqueItems: true, items: { type: 'string', pattern: '^[a-z][a-z0-9_]*$' }, description: 'Keys of pools whose strings draw it.' },
            },
            anyOf: [{ required: ['stick'] }, { required: ['ground'] }, { required: ['fighters'] }],
          }, closed),
          patternProperties: { '^_': true },
        };
      }
    }
    if (!props.patternGates) throw new Error('blurPatterns anchor');
    s.properties = props;
    wj(f, s);
  }
}

// =============================== fixture ===============================
{
  const f = 'tools/fixtures/virtual/data/combat/recipes.json';
  const o = rj(f);
  if (!o.pieces || (!o.patternGates && (fs.existsSync('data/combat/recipes.json') ? rj('data/combat/recipes.json') : rj('docs/combat/pending/recipes.slice11.json')).patternGates)) {
    const live = fs.existsSync('data/combat/recipes.json') ? rj('data/combat/recipes.json') : null;
    const full = live && live.pieces ? live : rj('docs/combat/pending/recipes.slice11.json');
    // the fixture is the whole file again (its patterns, gates and pieces belong together)
    const out = {};
    for (const k of Object.keys(full)) if (!['_target', '_changes', '_status', '_counts'].includes(k)) out[k] = full[k];
    out._about = o._about || 'Validator fixture, not game data: Combat\'s alchemist recipes (docs/combat/alchemist-recipes.md section 5).';
    wj(f, out);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'recipes-pieces'")) {
    const START = "    // a blur step [limb, target] can be filled by a posed piece of the fighter's blur pools";
    const s = t.indexOf(START);
    if (s < 0) throw new Error('blur block start');
    const e = t.indexOf('\n  }\n\n  // ---- ', s);
    if (e < 0) throw new Error('blur block end');
    const block = [
      "    // the pieces block: one row per strike id, shared by both fighters; the blur is filled from it",
      "    const prow = isObj(rec.pieces) ? rec.pieces : null;",
      "    const sockE = get('data/anim/sockets.json');",
      "    const regsE = isObj(sockE) && isObj(sockE.regions) ? Object.keys(sockE.regions).filter((k) => !k.startsWith('_')) : [];",
      "    if (prow) {",
      "      const used = new Set();",
      "      const live = new Set();",
      "      for (const fid of fighters) for (const [pn, list] of Object.entries(isObj(pools[fid]) ? pools[fid] : {})) {",
      "        if (pn.startsWith('_') || !Array.isArray(list)) continue;",
      "        list.forEach((e, i) => {",
      "          if (!isObj(e) || typeof e.id !== 'string') return;",
      "          used.add(e.id);",
      "          if (e.status !== 'waiting') live.add(e.id);",
      "          if (!(e.id in prow)) err(RC, `/pools/${esc(fid)}/${esc(pn)}/${i}/id`, 'recipes-pieces', `\"${e.id}\" has no row in pieces`);",
      "        });",
      "      }",
      "      for (const [fid, rows] of Object.entries(isObj(rec.showcase) ? rec.showcase : {})) {",
      "        if (fid.startsWith('_') || !Array.isArray(rows)) continue;",
      "        rows.forEach((r, i) => { if (isObj(r) && typeof r.strike === 'string') { used.add(r.strike); if (!(r.strike in prow)) err(RC, `/showcase/${esc(fid)}/${i}/strike`, 'recipes-pieces', `showcase strike \"${r.strike}\" has no row in pieces`); } });",
      "      }",
      "      for (const [id, row] of Object.entries(prow)) {",
      "        if (id.startsWith('_') || !isObj(row)) continue;",
      "        if (!used.has(id)) err(RC, `/pieces/${esc(id)}`, 'recipes-pieces', `\"${id}\" is in pieces but in no pool and no showcase row`, 'warning');",
      "        if (regsE.length && typeof row.target === 'string' && !regsE.includes(row.target)) err(RC, `/pieces/${esc(id)}/target`, 'recipes-pieces', `target \"${row.target}\" is not a region in sockets.json (${regsE.join(', ')})`);",
      "        if (live.has(id)) for (const s of pieces.get(id) || []) {",
      "          const base = String(s.limb).replace(/_[lr]$/, '');",
      "          if (typeof row.limb === 'string' && base !== row.limb) err(RC, `/pieces/${esc(id)}/limb`, 'recipes-pieces', `limb \"${row.limb}\" differs from its manifest row's \"${s.limb}\" (${s.id})`);",
      "          if (typeof row.target === 'string' && s.target !== row.target) err(RC, `/pieces/${esc(id)}/target`, 'recipes-pieces', `target \"${row.target}\" differs from its manifest row's \"${s.target}\" (${s.id})`);",
      "        }",
      "      }",
      "    }",
      "    // a blur pattern's steps [limb, target] are filled from the fighter's blur.base and blur.toward pieces that are not waiting; a step used k times needs k",
      "    const bp = isObj(rec.blurPatterns) ? rec.blurPatterns : {};",
      "    for (const [pname, steps] of Object.entries(bp)) {",
      "      if (pname.startsWith('_') || !Array.isArray(steps)) continue;",
      "      const need = new Map();",
      "      steps.forEach((st, si) => {",
      "        if (!Array.isArray(st) || st.length !== 2) return;",
      "        if (regsE.length && typeof st[1] === 'string' && !regsE.includes(st[1])) err(RC, `/blurPatterns/${esc(pname)}/${si}/1`, 'recipes-blur', `target \"${st[1]}\" is not a region in sockets.json (${regsE.join(', ')})`);",
      "        const key = `${st[0]}|${st[1]}`;",
      "        if (!need.has(key)) need.set(key, { st, first: si, n: 0 });",
      "        need.get(key).n++;",
      "      });",
      "      const gate = isObj(rec.patternGates) && isObj(rec.patternGates[pname]) ? rec.patternGates[pname] : null;",
      "      const forFighters = gate && Array.isArray(gate.fighters) ? fighters.filter((x) => gate.fighters.includes(x)) : fighters;",
      "      if (prow) for (const { st, first, n } of need.values()) for (const fid of forFighters) {",
      "        const fp = pools[fid];",
      "        const cand = new Map(); for (const e of [].concat(isObj(fp) && Array.isArray(fp['blur.base']) ? fp['blur.base'] : [], isObj(fp) && Array.isArray(fp['blur.toward']) ? fp['blur.toward'] : [])) if (isObj(e) && e.status !== 'waiting') cand.set(e.id, e);",
      "        if (!cand.size) continue;",
      "        const fits = [...cand.keys()].filter((id) => isObj(prow[id]) && (st[0] === 'own' || prow[id].limb === st[0]) && prow[id].target === st[1]).length;",
      "        if (fits < n) err(RC, `/blurPatterns/${esc(pname)}/${first}`, 'recipes-blur', n > 1 ? `step [${st[0]}, ${st[1]}] is used ${n} times in \"${pname}\" but fighter \"${fid}\" has ${fits} piece${fits === 1 ? '' : 's'} for it in blur.base and blur.toward` : `step ${first + 1} [${st[0]}, ${st[1]}] has no piece of fighter \"${fid}\" in blur.base or blur.toward to fill it`);",
      "      }",
      "    }",
    ].join('\n');
    t = t.slice(0, s) + block + t.slice(e);
    fs.writeFileSync(f, t);
  }
}

// ---- xref: the gates, and an upgrade for a tree where the first version ran ----
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (t.includes("'recipes-pieces'") && !t.includes("'recipes-gates'")) {
    const oldLoop = "      if (prow) for (const { st, first, n } of need.values()) for (const fid of fighters) {";
    if (t.includes(oldLoop)) {
      t = t.replace(oldLoop, () => [
        "      const gate = isObj(rec.patternGates) && isObj(rec.patternGates[pname]) ? rec.patternGates[pname] : null;",
        "      const forFighters = gate && Array.isArray(gate.fighters) ? fighters.filter((x) => gate.fighters.includes(x)) : fighters;",
        "      if (prow) for (const { st, first, n } of need.values()) for (const fid of forFighters) {",
      ].join('\n'));
    }
    const anchor = "    // a blur pattern's steps [limb, target] are filled from the fighter's blur.base";
    if (!t.includes(anchor)) throw new Error('gates anchor');
    t = t.replace(anchor, () => [
      "    for (const [gname, g] of Object.entries(isObj(rec.patternGates) ? rec.patternGates : {})) {",
      "      if (gname.startsWith('_') || !isObj(g)) continue;",
      "      if (!(isObj(rec.blurPatterns) && gname in rec.blurPatterns)) err(RC, `/patternGates/${esc(gname)}`, 'recipes-gates', `a gate for \"${gname}\", which is no pattern of blurPatterns`);",
      "      if (Array.isArray(g.fighters)) g.fighters.forEach((x, i) => { if (!fighters.includes(x)) err(RC, `/patternGates/${esc(gname)}/fighters/${i}`, 'recipes-gates', `gate fighter \"${x}\" is no key of pools (${fighters.join(', ')})`); });",
      "    }",
      anchor,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const R = 'data/combat/recipes.json';
  const fx = rj('tools/fixtures/virtual/data/combat/recipes.json');
  // a waiting piece the earlier case invents needs a row, now that every pool id has one
  for (const k of c.cases) {
    if (k.id !== 'combat-recipes-waiting-piece-unknown-ok') continue;
    for (const m of k.mutate || []) if (m.set && m.set['/pools/protagonist/power/0'] && !m.set['/pieces/strike.nowhere']) m.set['/pieces/strike.nowhere'] = { limb: 'hand', target: 'head' };
  }
  const x = (n, mut, expect) => ({ id: 'combat-recipes-' + n, schema: 'combat-recipes.schema.json', mutate: [{ file: R, ...mut }], expect });
  const jab = fx.pieces && fx.pieces['strike.jab'];
  const P = '/pieces/';
  const add = [
    x('pieces-required', { del: ['/pieces'] }, { rule: 'required', pointer: '' }),
    x('pieces-empty', { set: { '/pieces': {} } }, { rule: 'minProperties', pointer: '/pieces' }),
    x('pieces-note-ok', { set: { [P + '_note']: 'comment' } }, null),
    x('pieces-id-shape', { set: { [P + 'Strike Jab']: { limb: 'hand', target: 'head' } } }, { rule: 'propertyNames', pointer: P + 'Strike Jab' }),
    x('pieces-row-key-required', { del: [P + 'strike.jab/limb'] }, { rule: 'required', pointer: P + 'strike.jab' }),
    x('pieces-row-target-required', { del: [P + 'strike.jab/target'] }, { rule: 'required', pointer: P + 'strike.jab' }),
    x('pieces-row-unknown-key', { set: { [P + 'strike.jab/reach']: 90 } }, { rule: 'additionalProperties', pointer: P + 'strike.jab/reach' }),
    x('pieces-limb-enum', { set: { [P + 'strike.jab/limb']: 'tail' } }, { rule: 'enum', pointer: P + 'strike.jab/limb' }),
    x('pieces-target-shape', { set: { [P + 'strike.jab/target']: 'Head' } }, { rule: 'pattern', pointer: P + 'strike.jab/target' }),
    x('pieces-pool-id-without-row', { del: [P + 'strike.jab'] }, { rule: 'xref:recipes-pieces', pointerEndsWith: '/id' }),
    x('pieces-showcase-strike-without-row', { set: { '/showcase/rival/0/strike': 'strike.nowhere' } }, { rule: 'xref:recipes-pieces', pointer: '/showcase/rival/0/strike' }),
    x('pieces-unused-row-warns', { set: { [P + 'strike.unused']: { limb: 'hand', target: 'head' } } }, { rule: 'xref:recipes-pieces', pointer: P + 'strike.unused' }),
    x('pieces-target-not-a-socket', { set: { [P + 'strike.jab/target']: 'moon' } }, { rule: 'xref:recipes-pieces', pointer: P + 'strike.jab/target' }),
    x('pieces-limb-differs-from-manifest', { set: { [P + 'strike.jab/limb']: 'foot' } }, { rule: 'xref:recipes-pieces', pointer: P + 'strike.jab/limb' }),
    x('pieces-target-differs-from-manifest', { set: { [P + 'strike.jab/target']: 'gut' } }, { rule: 'xref:recipes-pieces', pointer: P + 'strike.jab/target' }),
    x('pieces-waiting-row-free-ok', { set: { [P + 'strike.tail_jab']: { limb: 'hand', target: 'head' } } }, null),
    x('gates-note-ok', { set: { '/patternGates/_note': 'comment' } }, null),
    x('gate-unknown-key', { set: { '/patternGates/inside/mood': 'calm' } }, { rule: 'additionalProperties', pointer: '/patternGates/inside/mood' }),
    x('gate-empty', { set: { '/patternGates/inside': {} } }, { rule: 'anyOf', pointer: '/patternGates/inside' }),
    x('gate-stick-constant', { set: { '/patternGates/inside/stick': 'away' } }, { rule: 'const', pointer: '/patternGates/inside/stick' }),
    x('gate-ground-constant', { set: { '/patternGates/reap/ground': false } }, { rule: 'const', pointer: '/patternGates/reap/ground' }),
    x('gate-fighters-empty', { set: { '/patternGates/breach/fighters': [] } }, { rule: 'minItems', pointer: '/patternGates/breach/fighters' }),
    x('gate-fighters-duplicate', { set: { '/patternGates/breach/fighters': ['protagonist', 'protagonist'] } }, { rule: 'uniqueItems', pointer: '/patternGates/breach/fighters/1' }),
    x('gate-fighters-type', { set: { '/patternGates/breach/fighters': 'protagonist' } }, { rule: 'type', pointer: '/patternGates/breach/fighters' }),
    x('gate-pattern-unknown', { set: { '/patternGates/nowhere': { ground: true } } }, { rule: 'xref:recipes-gates', pointer: '/patternGates/nowhere' }),
    x('gate-fighter-unknown', { set: { '/patternGates/breach/fighters': ['nobody'] } }, { rule: 'xref:recipes-gates', pointer: '/patternGates/breach/fighters/0' }),
    x('gate-both-keys-ok', { set: { '/patternGates/reap': { ground: true, stick: 'toward' } } }, null),
    x('gate-lifted-checks-both-fighters', { del: ['/patternGates/breach'] }, { rule: 'xref:recipes-blur', pointer: '/blurPatterns/breach/0' }),
    x('blur-step-repeated-needs-pieces', { set: { '/blurPatterns/ladder': [['hand', 'head'], ['hand', 'head'], ['hand', 'head'], ['hand', 'head'], ['hand', 'head']] } }, { rule: 'xref:recipes-blur', pointer: '/blurPatterns/ladder/0' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`pieces schema applied (${n} new cases)${jab ? '' : ' (note: the fixture has no strike.jab row)'}`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('recipes-pieces')) {
    const a = '`recipes-heavies`, `recipes-pool`, `recipes-piece`, `recipes-blur`, `recipes-showcase` |';
    if (!t.includes(a)) throw new Error('pieces README anchor');
    t = t.replace(a, () => '`recipes-heavies`, `recipes-pool`, `recipes-piece`, `recipes-pieces`, `recipes-blur`, `recipes-showcase` |');
    const line = t.split('\n').find((l) => l.includes('`recipes-pieces`'));
    t = t.replace(line, () => line.replace(/ \|$/, () => '; every pool id and showcase strike has a row in `pieces` (an unused row is a warning), a row\'s target is a socket and its limb and target equal its manifest rows\' (a blur step\'s fill reads the pieces, and a step used k times needs k pieces) |'));
    fs.writeFileSync(f, t);
  }
}
