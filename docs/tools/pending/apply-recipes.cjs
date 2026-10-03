// Schema for Combat's alchemist recipes, data/combat/recipes.json (combat.recipes/1; docs/combat/alchemist-recipes.md section 5;
// the draft is docs/combat/pending/recipes.alchemist.json, which becomes data/combat/recipes.json as it stands).
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit where the draft lands as data/combat/recipes.json:
//     node docs/tools/pending/apply-recipes.cjs
// It adds tools/schemas/combat-recipes.schema.json, the map entry, a validator fixture (tools/fixtures/virtual/data/combat/recipes.json, from the live
// file if it is there and from the draft if not; a fixture wins over the live file in the self-test), the xref rules (recipes-heavies, recipes-pool,
// recipes-piece, recipes-blur) and the cases. It does NOT copy the data into data/. Re-runnable (a second run changes nothing).
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, opts = {}) => Object.assign({ type: 'object', required: opts.required === undefined ? Object.keys(props) : opts.required, properties: props }, opts.description ? { description: opts.description } : {}, closed);
const text = { type: 'string', minLength: 1 };
const poolName = { anyOf: [{ type: 'string', pattern: '^[a-z][a-z0-9_]*([.][a-z0-9_]+)*$' }, { type: 'null' }] };
const pieceId = { type: 'string', pattern: '^[a-z][a-z0-9_]*([.][a-z0-9_]+)*$' };
const LIMBS = ['hand', 'foot', 'elbow', 'knee', 'shoulder', 'head', 'own'];
const POOLS = ['pool', 'towardPool', 'linkPool', 'accentPool', 'lastPool', 'ender'];
const STATUS = ['live', 'posed', 'waiting'];
const SENDS = ['across', 'up', 'down', 'turned', 'behind'];

const poolRefs = Object.fromEntries(POOLS.map((k) => [k, poolName]));

wj('tools/schemas/combat-recipes.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/combat-recipes',
  title: 'combat.recipes/1',
  description: 'data/combat/recipes.json: the alchemist recipes (docs/combat/alchemist-recipes.md section 5; docs/director/alchemy-plan.md): the three styles (blur, combo, power) with the read that picks the base or timed version and the pools they draw from, the flow and direction rules, the blur patterns, the last-press endings, and per fighter the pools of pieces with their status. The director\'s own numbers are not here (Encounter\'s data/director/alchemy.json). Version field: schema. Policy: closed except keys starting with an underscore. Cross-references (the styles\' heaviesInFive cover 0 to 5 with no overlap; every pool a style names exists for every fighter; every pool id is a strike of a wave manifest unless it is waiting, and no waiting id is in one; a blur step can be filled by a piece of the fighter\'s blur pools) are checked by tools/lib/xref-fight.js (recipes-*).',
  type: 'object',
  required: ['schema', 'styles', 'flow', 'direction', 'blurPatterns', 'patternRule', 'lastPress', 'pools'],
  properties: {
    schema: { const: 'combat.recipes/1' },
    styles: {
      type: 'array',
      minItems: 3,
      maxItems: 3,
      items: obj({
        id: { enum: ['blur', 'combo', 'power'] },
        heaviesInFive: { type: 'array', minItems: 2, maxItems: 2, items: { type: 'integer', minimum: 0, maximum: 5 }, description: 'The least and most heavies in a string of five this style takes.' },
        base: Object.assign({ type: 'object', required: ['read'], description: 'The base version: the read that picks it and the pools it draws from.', properties: Object.assign({ read: text }, poolRefs) }, closed),
        timed: Object.assign({ type: 'object', required: ['read'], description: 'The timed version.', properties: Object.assign({ read: text, plays: text, endsIn: text }, poolRefs) }, closed),
      }),
    },
    flow: Object.assign({ type: 'object', minProperties: 1, additionalProperties: text, propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' }, patternProperties: { '^_': true } }),
    direction: Object.assign({ type: 'object', minProperties: 1, additionalProperties: text, propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' }, patternProperties: { '^_': true } }),
    blurPatterns: {
      type: 'object',
      minProperties: 1,
      propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
      additionalProperties: { type: 'array', minItems: 5, maxItems: 5, items: { type: 'array', minItems: 2, maxItems: 2, prefixItems: [{ enum: LIMBS }, { type: 'string', pattern: '^[a-z][a-z_]*$' }], items: false, description: '[limb, target]: the limb (hand, foot, elbow, knee, shoulder, head or own) and a socket of data/anim/sockets.json.' }, description: 'Five steps.' },
      patternProperties: { '^_': true },
    },
    patternRule: text,
    lastPress: Object.assign({
      type: 'object',
      required: ['light', 'heavy'],
      properties: {
        light: { type: 'array', uniqueItems: true, items: pieceId, description: 'Ending ids after a light last press.' },
        heavy: { type: 'array', uniqueItems: true, items: pieceId, description: 'Ending ids after a heavy last press.' },
      },
    }, closed),
    showcase: {
      type: 'object',
      propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
      description: 'Optional. Fighter to the showcase enders the flow\'s top ending can play: a row is open when its strike is the string\'s ender, the launch goes its way (sends) and, where given, clearAboveBh of open air is above the pair.',
      additionalProperties: { type: 'array', items: obj({ id: pieceId, strike: pieceId, sends: { enum: SENDS, description: 'Where the launch must go for the row to open.' }, clearAboveBh: { type: 'number', exclusiveMinimum: 0, description: 'Open air above the pair, in body heights.' }, status: { enum: STATUS } }, { required: ['id', 'strike', 'sends', 'status'] }) },
      patternProperties: { '^_': true },
    },
    pools: {
      type: 'object',
      minProperties: 1,
      propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*)$' },
      description: 'Fighter to pool name to a list of {id, status}.',
      additionalProperties: {
        type: 'object',
        minProperties: 1,
        propertyNames: { pattern: '^(_.*|[a-z][a-z0-9_]*([.][a-z0-9_]+)*)$' },
        additionalProperties: { type: 'array', minItems: 1, items: obj({ id: pieceId, status: { enum: STATUS, description: 'live: plays in live matches today; posed: posed in one of Animation\'s packs and parked; waiting: not posed yet.' } }) },
        patternProperties: { '^_': true },
      },
      patternProperties: { '^_': true },
    },
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/combat/recipes.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/combat/styles.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/combat/recipes.json', schema: 'combat-recipes.schema.json' });
    wj(f, m);
  }
}

// =============================== fixture ===============================
{
  const dst = 'tools/fixtures/virtual/data/combat/recipes.json';
  const src = fs.existsSync('data/combat/recipes.json') ? 'data/combat/recipes.json' : 'docs/combat/pending/recipes.alchemist.json';
  if (!fs.existsSync(dst)) {
    fs.mkdirSync('tools/fixtures/virtual/data/combat', { recursive: true });
    const o = rj(src);
    const out = {};
    for (const k of Object.keys(o)) if (!['_target', '_status', '_counts'].includes(k)) out[k] = o[k];
    out._about = 'Validator fixture, not game data: Combat\'s alchemist recipes (docs/combat/alchemist-recipes.md section 5).';
    wj(dst, out);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'recipes-pool'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- combat recipes: the styles cover the heavies, the pools exist, the pieces are real, the blur steps can be filled ----',
      "  const rec = get('data/combat/recipes.json');",
      '  if (isObj(rec)) {',
      "    const RC = 'data/combat/recipes.json';",
      '    const styles = Array.isArray(rec.styles) ? rec.styles : [];',
      '    const cover = new Array(6).fill(0);',
      '    styles.forEach((s, i) => {',
      "      if (!isObj(s) || !Array.isArray(s.heaviesInFive) || s.heaviesInFive.length !== 2) return;",
      '      const [lo, hi] = s.heaviesInFive;',
      "      if (!Number.isInteger(lo) || !Number.isInteger(hi)) return;",
      "      if (lo > hi) err(RC, `/styles/${i}/heaviesInFive`, 'recipes-heavies', `heaviesInFive runs from ${lo} down to ${hi}`);",
      '      else for (let k = lo; k <= hi && k <= 5; k++) if (k >= 0) cover[k]++;',
      '    });',
      "    if (styles.length && styles.every((s) => isObj(s) && Array.isArray(s.heaviesInFive))) for (let k = 0; k <= 5; k++) { if (cover[k] === 0) err(RC, '/styles', 'recipes-heavies', `no style takes a string of five with ${k} heavies`); else if (cover[k] > 1) err(RC, '/styles', 'recipes-heavies', `${cover[k]} styles take a string of five with ${k} heavies`); }",
      '    // the pieces: every strike of every wave manifest, by its Combat id',
      '    const pieces = new Map();',
      '    for (const rel of docsFor(/^data\\/anim\\/waves\\/[^/]+\\.manifest\\.json$/)) { const md = get(rel); if (isObj(md) && Array.isArray(md.strikes)) for (const s of md.strikes) if (isObj(s) && typeof s.combat === \'string\') { if (!pieces.has(s.combat)) pieces.set(s.combat, []); pieces.get(s.combat).push(s); } }',
      '    const pools = isObj(rec.pools) ? rec.pools : {};',
      "    const fighters = Object.keys(pools).filter((k) => !k.startsWith('_'));",
      "    const named = new Set(); styles.forEach((s) => { if (isObj(s)) for (const v of ['base', 'timed']) if (isObj(s[v])) for (const k of ['pool', 'towardPool', 'linkPool', 'accentPool', 'lastPool', 'ender']) if (typeof s[v][k] === 'string') named.add(s[v][k]); });",
      '    for (const fid of fighters) {',
      '      const fp = pools[fid];',
      '      if (!isObj(fp)) continue;',
      "      for (const n of named) if (!(n in fp)) err(RC, `/pools/${esc(fid)}`, 'recipes-pool', `fighter \"${fid}\" has no pool \"${n}\", which a style names`);",
      '      for (const [pn, list] of Object.entries(fp)) {',
      "        if (pn.startsWith('_') || !Array.isArray(list)) continue;",
      '        const seen = new Set();',
      '        list.forEach((e, i) => {',
      "          if (!isObj(e) || typeof e.id !== 'string') return;",
      '          const at = `/pools/${esc(fid)}/${esc(pn)}/${i}`;',
      "          if (seen.has(e.id)) err(RC, `${at}/id`, 'recipes-piece', `\"${e.id}\" is in pool \"${pn}\" twice`); else seen.add(e.id);",
      "          if (pieces.size && e.status === 'posed' && !pieces.has(e.id)) err(RC, `${at}/id`, 'recipes-piece', `\"${e.id}\" is posed but is no strike of any wave manifest`);",
      "          if (pieces.size && e.status === 'waiting' && pieces.has(e.id)) err(RC, `${at}/status`, 'recipes-piece', `\"${e.id}\" is posed in a wave manifest, so it is not waiting`, 'warning');",
      '        });',
      '      }',
      '    }',
      '    // the showcase rows: the fighter has pools, the strike is one of its pieces, no id twice',
      '    const sc = isObj(rec.showcase) ? rec.showcase : {};',
      '    const scIds = new Set();',
      '    for (const [fid, rows] of Object.entries(sc)) {',
      "      if (fid.startsWith('_') || !Array.isArray(rows)) continue;",
      "      if (!fighters.includes(fid)) { err(RC, `/showcase/${esc(fid)}`, 'recipes-showcase', `showcase rows for \"${fid}\", who has no pools`); continue; }",
      "      const mine = new Map(); for (const list of Object.values(pools[fid])) if (Array.isArray(list)) for (const e of list) if (isObj(e) && typeof e.id === 'string') mine.set(e.id, e);",
      '      rows.forEach((r, i) => {',
      '        if (!isObj(r)) return;',
      '        const at = `/showcase/${esc(fid)}/${i}`;',
      "        if (typeof r.id === 'string') { if (scIds.has(r.id)) err(RC, `${at}/id`, 'recipes-showcase', `showcase id \"${r.id}\" is used twice`); else scIds.add(r.id); }",
      "        if (typeof r.strike === 'string' && !mine.has(r.strike)) err(RC, `${at}/strike`, 'recipes-showcase', `strike \"${r.strike}\" is in none of ${fid}'s pools`);",
      "        else if (typeof r.strike === 'string' && r.status !== 'waiting' && mine.get(r.strike).status === 'waiting') err(RC, `${at}/status`, 'recipes-showcase', `the row is ${r.status} but its strike \"${r.strike}\" is waiting in ${fid}'s pools`, 'warning');",
      '      });',
      '    }',
      '    // a blur step [limb, target] can be filled by a posed piece of the fighter\'s blur pools',
      "    const sockE = get('data/anim/sockets.json');",
      "    const regsE = isObj(sockE) && isObj(sockE.regions) ? Object.keys(sockE.regions).filter((k) => !k.startsWith('_')) : [];",
      '    const bp = isObj(rec.blurPatterns) ? rec.blurPatterns : {};',
      '    for (const [pname, steps] of Object.entries(bp)) {',
      "      if (pname.startsWith('_') || !Array.isArray(steps)) continue;",
      '      steps.forEach((st, si) => {',
      '        if (!Array.isArray(st) || st.length !== 2) return;',
      "        if (regsE.length && typeof st[1] === 'string' && !regsE.includes(st[1])) err(RC, `/blurPatterns/${esc(pname)}/${si}/1`, 'recipes-blur', `target \"${st[1]}\" is not a region in sockets.json (${regsE.join(', ')})`);",
      '        for (const fid of fighters) {',
      '          const fp = pools[fid];',
      '          const cand = [].concat(isObj(fp) && Array.isArray(fp[\'blur.base\']) ? fp[\'blur.base\'] : [], isObj(fp) && Array.isArray(fp[\'blur.toward\']) ? fp[\'blur.toward\'] : []).filter((e) => isObj(e) && e.status !== \'waiting\');',
      '          const ok = cand.some((e) => (pieces.get(e.id) || []).some((s) => (st[0] === \'own\' || String(s.limb).replace(/_[lr]$/, \'\') === st[0]) && s.target === st[1]));',
      "          if (pieces.size && cand.length && !ok) err(RC, `/blurPatterns/${esc(pname)}/${si}`, 'recipes-blur', `step ${si + 1} [${st[0]}, ${st[1]}] has no light of fighter \"${fid}\" in blur.base or blur.toward to fill it`);",
      '        }',
      '      });',
      '    }',
      '  }',
      '',
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const R = 'data/combat/recipes.json';
  const x = (n, mut, expect) => ({ id: 'combat-recipes-' + n, schema: 'combat-recipes.schema.json', mutate: [{ file: R, ...mut }], expect });
  const add = [
    x('live-valid', { set: { '/schema': 'combat.recipes/1' } }, null),
    x('key-required', { del: ['/pools'] }, { rule: 'required', pointer: '' }),
    x('schema-version', { set: { '/schema': 'combat.recipes/2' } }, { rule: 'const', pointer: '/schema' }),
    x('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    x('underscore-key-ok', { set: { '/_why': 'comment' } }, null),
    x('styles-length', { set: { '/styles': [] } }, { rule: 'minItems', pointer: '/styles' }),
    x('style-id-enum', { set: { '/styles/0/id': 'burst' } }, { rule: 'enum', pointer: '/styles/0/id' }),
    x('style-key-required', { del: ['/styles/0/timed'] }, { rule: 'required', pointer: '/styles/0' }),
    x('style-unknown-key', { set: { '/styles/0/extra': 1 } }, { rule: 'additionalProperties', pointer: '/styles/0/extra' }),
    x('heavies-length', { set: { '/styles/1/heaviesInFive': [1] } }, { rule: 'minItems', pointer: '/styles/1/heaviesInFive' }),
    x('heavies-range', { set: { '/styles/1/heaviesInFive': [1, 6] } }, { rule: 'maximum', pointer: '/styles/1/heaviesInFive/1' }),
    x('heavies-integer', { set: { '/styles/1/heaviesInFive': [1, 2.5] } }, { rule: 'type', pointer: '/styles/1/heaviesInFive/1' }),
    x('heavies-inverted', { set: { '/styles/1/heaviesInFive': [3, 1] } }, { rule: 'xref:recipes-heavies', pointer: '/styles/1/heaviesInFive' }),
    x('heavies-gap', { set: { '/styles/1/heaviesInFive': [1, 2] } }, { rule: 'xref:recipes-heavies', pointer: '/styles' }),
    x('heavies-overlap', { set: { '/styles/2/heaviesInFive': [3, 5] } }, { rule: 'xref:recipes-heavies', pointer: '/styles' }),
    x('version-read-required', { del: ['/styles/0/base/read'] }, { rule: 'required', pointer: '/styles/0/base' }),
    x('version-unknown-key', { set: { '/styles/0/base/mix': 'x' } }, { rule: 'additionalProperties', pointer: '/styles/0/base/mix' }),
    x('pool-name-shape', { set: { '/styles/0/base/pool': 'Blur Base' } }, { rule: 'anyOf', pointer: '/styles/0/base/pool' }),
    x('ender-null-ok', { set: { '/styles/0/base/ender': null } }, null),
    x('pool-not-for-fighter', { set: { '/styles/1/base/linkPool': 'combo.nowhere' } }, { rule: 'xref:recipes-pool', pointer: '/pools/rival' }),
    x('showcase-optional-ok', { del: ['/showcase'] }, null),
    x('showcase-fighter-type', { set: { '/showcase/rival': 'hammer' } }, { rule: 'type', pointer: '/showcase/rival' }),
    x('showcase-empty-list-ok', { set: { '/showcase/rival': [] } }, null),
    x('showcase-row-key-required', { del: ['/showcase/rival/0/sends'] }, { rule: 'required', pointer: '/showcase/rival/0' }),
    x('showcase-row-unknown-key', { set: { '/showcase/rival/0/weight': 2 } }, { rule: 'additionalProperties', pointer: '/showcase/rival/0/weight' }),
    x('showcase-sends-enum', { set: { '/showcase/rival/0/sends': 'sideways' } }, { rule: 'enum', pointer: '/showcase/rival/0/sends' }),
    x('showcase-status-enum', { set: { '/showcase/rival/0/status': 'ready' } }, { rule: 'enum', pointer: '/showcase/rival/0/status' }),
    x('showcase-id-shape', { set: { '/showcase/rival/0/id': 'Overhead Hammer' } }, { rule: 'pattern', pointer: '/showcase/rival/0/id' }),
    x('showcase-clear-zero', { set: { '/showcase/rival/1/clearAboveBh': 0 } }, { rule: 'exclusiveMinimum', pointer: '/showcase/rival/1/clearAboveBh' }),
    x('showcase-clear-optional-ok', { del: ['/showcase/rival/1/clearAboveBh'] }, null),
    x('showcase-note-ok', { set: { '/showcase/_note': 'comment' } }, null),
    x('showcase-id-twice', { set: { '/showcase/rival/1/id': 'showcase.overhead_hammer' } }, { rule: 'xref:recipes-showcase', pointer: '/showcase/rival/1/id' }),
    x('showcase-fighter-without-pools', { set: { '/showcase/nobody': [] } }, { rule: 'xref:recipes-showcase', pointer: '/showcase/nobody' }),
    x('showcase-strike-not-a-piece', { set: { '/showcase/rival/0/strike': 'strike.nowhere' } }, { rule: 'xref:recipes-showcase', pointer: '/showcase/rival/0/strike' }),
    x('showcase-posed-row-on-waiting-strike-warns', { set: { '/showcase/rival/0/strike': 'strike.tail_jab', '/showcase/rival/0/status': 'posed' } }, { rule: 'xref:recipes-showcase', pointer: '/showcase/rival/0/status' }),
    x('showcase-waiting-row-on-waiting-strike-ok', { set: { '/showcase/rival/0/strike': 'strike.tail_jab' } }, null),
    x('flow-value-type', { set: { '/flow/under3': 3 } }, { rule: 'type', pointer: '/flow/under3' }),
    x('flow-empty', { set: { '/flow': {} } }, { rule: 'minProperties', pointer: '/flow' }),
    x('direction-value-type', { set: { '/direction/toward': 3 } }, { rule: 'type', pointer: '/direction/toward' }),
    x('pattern-length', { set: { '/blurPatterns/ladder': [['hand', 'gut']] } }, { rule: 'minItems', pointer: '/blurPatterns/ladder' }),
    x('pattern-limb-enum', { set: { '/blurPatterns/ladder/0/0': 'tail' } }, { rule: 'enum', pointer: '/blurPatterns/ladder/0/0' }),
    x('pattern-step-length', { set: { '/blurPatterns/ladder/0': ['hand'] } }, { rule: 'minItems', pointer: '/blurPatterns/ladder/0' }),
    x('pattern-target-shape', { set: { '/blurPatterns/ladder/0/1': 'Gut' } }, { rule: 'pattern', pointer: '/blurPatterns/ladder/0/1' }),
    x('pattern-target-not-a-socket', { set: { '/blurPatterns/ladder/0/1': 'tail' } }, { rule: 'xref:recipes-blur', pointer: '/blurPatterns/ladder/0/1' }),
    x('pattern-own-ok', { set: { '/blurPatterns/ladder/0/0': 'own' } }, null),
    x('pattern-name-shape', { set: { '/blurPatterns/Bad Name': [['hand', 'gut'], ['hand', 'gut'], ['hand', 'gut'], ['hand', 'gut'], ['hand', 'gut']] } }, { rule: 'propertyNames', pointer: '/blurPatterns/Bad Name' }),
    x('pattern-step-unfillable', { set: { '/blurPatterns/ladder/0': ['shoulder', 'jaw'] } }, { rule: 'xref:recipes-blur', pointer: '/blurPatterns/ladder/0' }),
    x('pattern-rule-empty', { set: { '/patternRule': '' } }, { rule: 'minLength', pointer: '/patternRule' }),
    x('last-press-key-required', { del: ['/lastPress/heavy'] }, { rule: 'required', pointer: '/lastPress' }),
    x('last-press-duplicate', { set: { '/lastPress/light': ['level.shove_off', 'level.shove_off'] } }, { rule: 'uniqueItems', pointer: '/lastPress/light/1' }),
    x('last-press-id-shape', { set: { '/lastPress/light': ['Level Shove'] } }, { rule: 'pattern', pointer: '/lastPress/light/0' }),
    x('pools-empty', { set: { '/pools': {} } }, { rule: 'minProperties', pointer: '/pools' }),
    x('pool-status-enum', { set: { '/pools/protagonist/power/0/status': 'ready' } }, { rule: 'enum', pointer: '/pools/protagonist/power/0/status' }),
    x('pool-entry-key-required', { set: { '/pools/protagonist/power/0': { id: 'strike.uppercut' } } }, { rule: 'required', pointer: '/pools/protagonist/power/0' }),
    x('pool-entry-unknown-key', { set: { '/pools/protagonist/power/0/weight': 2 } }, { rule: 'additionalProperties', pointer: '/pools/protagonist/power/0/weight' }),
    x('pool-empty', { set: { '/pools/protagonist/power': [] } }, { rule: 'minItems', pointer: '/pools/protagonist/power' }),
    x('pool-missing-for-fighter', { del: ['/pools/protagonist/power.last'] }, { rule: 'xref:recipes-pool', pointer: '/pools/protagonist' }),
    x('pool-id-twice', { set: { '/pools/protagonist/power/1/id': 'strike.uppercut' } }, { rule: 'xref:recipes-piece', pointer: '/pools/protagonist/power/1/id' }),
    x('posed-piece-not-a-strike', { set: { '/pools/protagonist/power/0/id': 'strike.nowhere' } }, { rule: 'xref:recipes-piece', pointer: '/pools/protagonist/power/0/id' }),
    x('waiting-piece-unknown-ok', { set: { '/pools/protagonist/power/0': { id: 'strike.nowhere', status: 'waiting' } } }, null),
    x('waiting-piece-is-posed-warns', { set: { '/pools/protagonist/power/0/status': 'waiting' } }, { rule: 'xref:recipes-piece', pointer: '/pools/protagonist/power/0/status' }),
  ];
  let n = 0;
  for (const k of add) if (!c.cases.some((y) => y.id === k.id)) { c.cases.push(k); n++; }
  wj(cf, c);
  console.log(`recipes schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('recipes-heavies')) {
    const line = t.split('\n').find((l) => l.includes('`fighters-shape`')) || t.split('\n').find((l) => l.includes('`flight-order`'));
    t = t.replace(line, () => line + '\n| `recipes-heavies`, `recipes-pool`, `recipes-piece`, `recipes-blur`, `recipes-showcase` | data/combat/recipes.json: the styles\' heaviesInFive cover 0 to 5 with no gap or overlap; every pool a style names exists for every fighter; a posed pool id is a strike of a wave manifest (a waiting id that is posed is a warning) and no id is in a pool twice; a blur step [limb, target] names a socket of sockets.json and can be filled by a piece of each fighter\'s blur.base or blur.toward; a showcase row belongs to a fighter with pools, names one of that fighter\'s pieces as its strike (a posed or live row on a waiting strike is a warning) and no showcase id is used twice |');
    fs.writeFileSync(f, t);
  }
}
