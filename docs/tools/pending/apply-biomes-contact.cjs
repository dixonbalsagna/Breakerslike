// Schema for World's ground-contact data, G2 (docs/world/ground-contact.md; the draft is docs/world/scratch-build/contact.json,
// `schema` "biomes.contact/1").
// NOT run by CI, the validator or the sim. Run once from the repo root, in the commit where World copies the draft to data/biomes/contact.json:
//     node docs/tools/pending/apply-biomes-contact.cjs
// It adds tools/schemas/biomes-contact.schema.json, the map entry, the xref rules (contact-order, contact-surface), a validator fixture
// (tools/fixtures/virtual/data/biomes/contact.json, from the live file if it is there and from the draft if not; a fixture wins over
// the live file in the self-test) and the cases. It does NOT copy the data into data/; World does. Re-runnable (a second run changes
// nothing). See README.md next to this file.
const fs = require('fs');
const rj = (f) => JSON.parse(fs.readFileSync(f, 'utf8'));
const wj = (f, o) => fs.writeFileSync(f, JSON.stringify(o, null, 2) + '\n');
const closed = { additionalProperties: false, patternProperties: { '^_': true } };
const obj = (props, description) => Object.assign({ type: 'object', required: Object.keys(props), properties: props }, description ? { description } : {}, closed);
const nn = { type: 'number', minimum: 0 };
const pos = { type: 'number', exclusiveMinimum: 0 };
const unit = { type: 'number', minimum: 0, maximum: 1 };
const BIOMES = ['ocean', 'village', 'plains', 'city', 'forest', 'desert', 'mountains'];
const SURFACES = ['paving', 'rock', 'soil', 'sand', 'rubble'];
const arr = (n, item) => ({ type: 'array', minItems: n, maxItems: n, items: item });

// =============================== schema ===============================
wj('tools/schemas/biomes-contact.schema.json', {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'meridian/biomes-contact',
  title: 'biomes.contact/1',
  description: 'data/biomes/contact.json: how a launched body meets and leaves the ground (docs/world/ground-contact.md; balance-targets.md section 20), read by sim/world/contact.gd. Speeds are the sim\'s normalised units. enabled false keeps the old slide model bit for bit. Version field: schema. Policy: every key required, objects closed except keys starting with an underscore. Orders and references (nothingBelow below tumbleBelow; skidSin2 below slamSin2; each bounce keeps less than the one before; per-tier arrays do not fall; every biomeSurface value is one of the surfaces; every paving biome has a biomeSurface) are checked by tools/lib/xref-fight.js (contact-order, contact-surface).',
  type: 'object',
  required: ['schema', 'enabled', 'bands', 'leave', 'bounce', 'tumble', 'journey', 'wear', 'spin', 'surfaces', 'water', 'biomeSurface', 'paving', 'rubbleMin'],
  properties: {
    schema: { const: 'biomes.contact/1' },
    enabled: { type: 'boolean', description: 'false keeps the old slide model.' },
    bands: obj({
      nothingBelow: Object.assign({ description: 'Below this speed a contact does nothing.' }, nn),
      tumbleBelow: Object.assign({ description: 'Below this speed a contact tumbles rather than skids.' }, nn),
      skidToTumble: Object.assign({ description: 'The speed at which a skid becomes a tumble.' }, nn),
      skidSin2: Object.assign({ description: 'sin^2 of the contact angle below which the body skids.' }, unit),
      slamSin2: Object.assign({ description: 'sin^2 of the contact angle above which the body slams.' }, unit),
    }),
    leave: obj({ clear: nn, lipLift: nn, wall: nn, stop: nn }, 'How the body leaves the ground.'),
    bounce: obj({
      perTier: Object.assign({ description: 'Bounces per power tier 1 to 4.' }, arr(4, { type: 'integer', minimum: 0 })),
      vertKeep: Object.assign({ description: 'The share of the vertical speed each bounce keeps.' }, { type: 'array', minItems: 1, items: unit }),
      tangentKeep: unit,
      hopSpeed: pos,
      hopLift: nn,
    }),
    tumble: obj({ brakeMul: pos, maxSeconds: pos, cappedTail: unit }),
    journey: obj({ maxContacts: { type: 'integer', minimum: 1 }, maxSeconds: pos }, 'The cap on a launch\'s whole ground journey.'),
    wear: obj({ touch: nn, perSpeed: nn }),
    spin: obj({
      capTurns: Object.assign({ description: 'The most turns a body spins, per power tier 1 to 4.' }, arr(4, nn)),
      halfLife: pos,
      bodyR: pos,
    }),
    surfaces: obj(Object.fromEntries(SURFACES.map((s) => [s, obj({ brake: pos, tumble: { type: 'boolean' } })])), 'The five ground surfaces: how hard each brakes a slide, and whether a body tumbles on it.'),
    water: obj({ skimMinSpeed: nn, skimMaxTan: nn, skimLift: nn, skimKeep: unit, skimMax: { type: 'integer', minimum: 0 }, sinkBelow: nn }, 'Skimming across water and sinking.'),
    biomeSurface: obj(Object.fromEntries(BIOMES.map((b) => [b, { enum: SURFACES }])), 'The surface of each biome.'),
    paving: obj({ biomes: { type: 'array', uniqueItems: true, items: { enum: BIOMES } }, dugBelow: { type: 'number' } }, 'Biomes with paving, and how far the ground must be dug below its base before the paving is gone.'),
    rubbleMin: nn,
  },
  additionalProperties: false,
  patternProperties: { '^_': true },
});

// =============================== map ===============================
{
  const f = 'tools/schemas/map.json';
  const m = rj(f);
  if (!m.rules.some((r) => r.match === 'data/biomes/contact.json')) {
    const i = m.rules.findIndex((r) => r.match === 'data/biomes/settlements.json');
    m.rules.splice(i >= 0 ? i + 1 : m.rules.length, 0, { match: 'data/biomes/contact.json', schema: 'biomes-contact.schema.json' });
    wj(f, m);
  }
}

// =============================== xref ===============================
{
  const f = 'tools/lib/xref-fight.js';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes("'contact-order'")) {
    const marker = '  // ---- fighter ladder: the beam tables never decrease with the tier ----';
    if (!t.includes(marker)) throw new Error('xref marker');
    t = t.replace(marker, () => [
      '  // ---- biomes contact: orders and references ----',
      "  const gc = get('data/biomes/contact.json');",
      '  if (isObj(gc)) {',
      "    const GC = 'data/biomes/contact.json';",
      '    const b = isObj(gc.bands) ? gc.bands : {};',
      "    if (typeof b.nothingBelow === 'number' && typeof b.tumbleBelow === 'number' && b.nothingBelow >= b.tumbleBelow) err(GC, '/bands/nothingBelow', 'contact-order', `nothingBelow ${b.nothingBelow} is not below tumbleBelow ${b.tumbleBelow}`);",
      "    if (typeof b.skidSin2 === 'number' && typeof b.slamSin2 === 'number' && b.skidSin2 >= b.slamSin2) err(GC, '/bands/skidSin2', 'contact-order', `skidSin2 ${b.skidSin2} is not below slamSin2 ${b.slamSin2}`);",
      "    if (typeof b.nothingBelow === 'number' && typeof b.tumbleBelow === 'number' && typeof b.skidToTumble === 'number' && (b.skidToTumble < b.nothingBelow || b.skidToTumble > b.tumbleBelow)) err(GC, '/bands/skidToTumble', 'contact-order', `skidToTumble ${b.skidToTumble} is outside nothingBelow ${b.nothingBelow} to tumbleBelow ${b.tumbleBelow}`, 'warning');",
      '    const vk = isObj(gc.bounce) ? gc.bounce.vertKeep : undefined;',
      "    if (Array.isArray(vk)) for (let i = 1; i < vk.length; i++) if (typeof vk[i] === 'number' && typeof vk[i - 1] === 'number' && vk[i] > vk[i - 1]) err(GC, `/bounce/vertKeep/${i}`, 'contact-order', `bounce ${i + 1} keeps ${vk[i]}, more than bounce ${i} (${vk[i - 1]}); a body loses energy on each bounce`);",
      "    const rising = (a, pointer, what) => { if (Array.isArray(a)) for (let i = 1; i < a.length; i++) if (typeof a[i] === 'number' && typeof a[i - 1] === 'number' && a[i] < a[i - 1]) err(GC, `${pointer}/${i}`, 'contact-order', `${what} falls from ${a[i - 1]} to ${a[i]} at tier ${i + 1}; it must not fall with the tier`, 'warning'); };",
      "    rising(isObj(gc.bounce) ? gc.bounce.perTier : undefined, '/bounce/perTier', 'bounces per tier');",
      "    rising(isObj(gc.spin) ? gc.spin.capTurns : undefined, '/spin/capTurns', 'spin cap');",
      "    const surfaces = isObj(gc.surfaces) ? Object.keys(gc.surfaces).filter((k) => !k.startsWith('_')) : [];",
      '    const bs = isObj(gc.biomeSurface) ? gc.biomeSurface : {};',
      "    for (const [biome, s] of Object.entries(bs)) if (!biome.startsWith('_') && surfaces.length && typeof s === 'string' && !surfaces.includes(s)) err(GC, `/biomeSurface/${esc(biome)}`, 'contact-surface', `biome \"${biome}\" uses surface \"${s}\", which is not in surfaces (${surfaces.join(', ')})`);",
      "    if (isObj(gc.paving) && Array.isArray(gc.paving.biomes)) gc.paving.biomes.forEach((bn, i) => { if (typeof bn === 'string' && !(bn in bs)) err(GC, `/paving/biomes/${i}`, 'contact-surface', `paving biome \"${bn}\" has no entry in biomeSurface`); });",
      '  }',
      '',
      marker,
    ].join('\n'));
    fs.writeFileSync(f, t);
  }
}

// =============================== fixture ===============================
{
  const dst = 'tools/fixtures/virtual/data/biomes/contact.json';
  const src = fs.existsSync('data/biomes/contact.json') ? 'data/biomes/contact.json' : 'docs/world/scratch-build/contact.json';
  if (!fs.existsSync(dst)) {
    fs.mkdirSync('tools/fixtures/virtual/data/biomes', { recursive: true });
    const o = rj(src);
    delete o._about;
    wj(dst, Object.assign({ _about: 'Validator fixture, not game data: the shape docs/world/ground-contact.md describes, with the numbers of World\'s draft.' }, o));
  }
}

// =============================== cases ===============================
{
  const cf = 'tools/fixtures/cases.json';
  const c = rj(cf);
  const G = 'data/biomes/contact.json';
  const k = (n, mut, expect) => ({ id: 'biomes-contact-' + n, schema: 'biomes-contact.schema.json', mutate: [{ file: G, ...mut }], expect });
  const add = [
    k('valid', { set: { '/enabled': true } }, null),
    k('key-required', { del: ['/water'] }, { rule: 'required', pointer: '' }),
    k('unknown-key', { set: { '/extra': 1 } }, { rule: 'additionalProperties', pointer: '/extra' }),
    k('underscore-key-ok', { set: { '/bands/_why': 'comment' } }, null),
    k('schema-version', { set: { '/schema': 'biomes.contact/2' } }, { rule: 'const', pointer: '/schema' }),
    k('enabled-type', { set: { '/enabled': 'no' } }, { rule: 'type', pointer: '/enabled' }),
    k('bands-key-required', { del: ['/bands/slamSin2'] }, { rule: 'required', pointer: '/bands' }),
    k('bands-negative', { set: { '/bands/nothingBelow': -1 } }, { rule: 'minimum', pointer: '/bands/nothingBelow' }),
    k('bands-sin2-range', { set: { '/bands/slamSin2': 1.5 } }, { rule: 'maximum', pointer: '/bands/slamSin2' }),
    k('bands-nothing-above-tumble', { set: { '/bands/nothingBelow': 950 } }, { rule: 'xref:contact-order', pointer: '/bands/nothingBelow' }),
    k('bands-skid-above-slam', { set: { '/bands/skidSin2': 0.9 } }, { rule: 'xref:contact-order', pointer: '/bands/skidSin2' }),
    k('bands-skid-to-tumble-outside-warns', { set: { '/bands/skidToTumble': 100 } }, { rule: 'xref:contact-order', pointer: '/bands/skidToTumble' }),
    k('leave-key-required', { del: ['/leave/stop'] }, { rule: 'required', pointer: '/leave' }),
    k('bounce-per-tier-length', { set: { '/bounce/perTier': [1, 2, 3] } }, { rule: 'minItems', pointer: '/bounce/perTier' }),
    k('bounce-per-tier-integer', { set: { '/bounce/perTier': [1, 2, 3.5, 3] } }, { rule: 'type', pointer: '/bounce/perTier/2' }),
    k('bounce-per-tier-falls-warns', { set: { '/bounce/perTier': [1, 3, 2, 3] } }, { rule: 'xref:contact-order', pointer: '/bounce/perTier/2' }),
    k('bounce-keep-range', { set: { '/bounce/vertKeep': [0.45, 1.2] } }, { rule: 'maximum', pointer: '/bounce/vertKeep/1' }),
    k('bounce-keep-rises', { set: { '/bounce/vertKeep': [0.25, 0.35, 0.45] } }, { rule: 'xref:contact-order', pointer: '/bounce/vertKeep/1' }),
    k('bounce-tangent-range', { set: { '/bounce/tangentKeep': 2 } }, { rule: 'maximum', pointer: '/bounce/tangentKeep' }),
    k('bounce-hop-positive', { set: { '/bounce/hopSpeed': 0 } }, { rule: 'exclusiveMinimum', pointer: '/bounce/hopSpeed' }),
    k('tumble-tail-range', { set: { '/tumble/cappedTail': 1.5 } }, { rule: 'maximum', pointer: '/tumble/cappedTail' }),
    k('tumble-seconds-positive', { set: { '/tumble/maxSeconds': 0 } }, { rule: 'exclusiveMinimum', pointer: '/tumble/maxSeconds' }),
    k('journey-contacts-integer', { set: { '/journey/maxContacts': 8.5 } }, { rule: 'type', pointer: '/journey/maxContacts' }),
    k('journey-contacts-positive', { set: { '/journey/maxContacts': 0 } }, { rule: 'minimum', pointer: '/journey/maxContacts' }),
    k('wear-negative', { set: { '/wear/perSpeed': -1 } }, { rule: 'minimum', pointer: '/wear/perSpeed' }),
    k('spin-caps-length', { set: { '/spin/capTurns': [1.5, 3] } }, { rule: 'minItems', pointer: '/spin/capTurns' }),
    k('spin-caps-fall-warns', { set: { '/spin/capTurns': [3, 1.5, 3, 3] } }, { rule: 'xref:contact-order', pointer: '/spin/capTurns/1' }),
    k('spin-half-life-positive', { set: { '/spin/halfLife': 0 } }, { rule: 'exclusiveMinimum', pointer: '/spin/halfLife' }),
    k('surface-missing', { del: ['/surfaces/rubble'] }, { rule: 'required', pointer: '/surfaces' }),
    k('surface-unknown', { set: { '/surfaces/ice': { brake: 0.5, tumble: false } } }, { rule: 'additionalProperties', pointer: '/surfaces/ice' }),
    k('surface-brake-positive', { set: { '/surfaces/soil/brake': 0 } }, { rule: 'exclusiveMinimum', pointer: '/surfaces/soil/brake' }),
    k('surface-tumble-type', { set: { '/surfaces/rubble/tumble': 'yes' } }, { rule: 'type', pointer: '/surfaces/rubble/tumble' }),
    k('water-keep-range', { set: { '/water/skimKeep': 1.5 } }, { rule: 'maximum', pointer: '/water/skimKeep' }),
    k('water-skim-max-integer', { set: { '/water/skimMax': 6.5 } }, { rule: 'type', pointer: '/water/skimMax' }),
    k('biome-surface-missing', { del: ['/biomeSurface/desert'] }, { rule: 'required', pointer: '/biomeSurface' }),
    k('biome-surface-unknown-biome', { set: { '/biomeSurface/tundra': 'soil' } }, { rule: 'additionalProperties', pointer: '/biomeSurface/tundra' }),
    k('biome-surface-enum', { set: { '/biomeSurface/forest': 'ice' } }, { rule: 'enum', pointer: '/biomeSurface/forest' }),
    k('biome-surface-not-in-surfaces', { del: ['/surfaces/sand'] }, { rule: 'xref:contact-surface', pointer: '/biomeSurface/desert' }),
    k('paving-biome-enum', { set: { '/paving/biomes': ['city', 'tundra'] } }, { rule: 'enum', pointer: '/paving/biomes/1' }),
    k('paving-biome-duplicate', { set: { '/paving/biomes': ['city', 'city'] } }, { rule: 'uniqueItems', pointer: '/paving/biomes/1' }),
    k('paving-dug-type', { set: { '/paving/dugBelow': 'deep' } }, { rule: 'type', pointer: '/paving/dugBelow' }),
    k('rubble-min-negative', { set: { '/rubbleMin': -1 } }, { rule: 'minimum', pointer: '/rubbleMin' }),
  ];
  let n = 0;
  for (const x of add) if (!c.cases.some((y) => y.id === x.id)) { c.cases.push(x); n++; }
  wj(cf, c);
  console.log(`biomes-contact schema applied (${n} new cases)`);
}

// =============================== docs ===============================
{
  const f = 'docs/tools/README.md';
  let t = fs.readFileSync(f, 'utf8');
  if (!t.includes('contact-surface')) {
    const line = t.split('\n').find((l) => l.includes('`launch-order`'));
    t = t.replace(line, () => line + '\n| `contact-order`, `contact-surface` | data/biomes/contact.json: nothingBelow below tumbleBelow; skidSin2 below slamSin2; each bounce keeps less than the one before; bounces and spin caps do not fall with the tier (warnings); every biomeSurface value is a surface and every paving biome has a biomeSurface |');
    fs.writeFileSync(f, t);
  }
}
