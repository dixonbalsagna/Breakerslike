// Wave generator (the review pipeline, docs/animation/review-plan.md): turns a wave spec (render/anim/tools/waves/waveN.mjs: one
// contact pose or a derivation per strike) and Combat's parked strike data into the wave's pose and key-set files:
//   data/anim/waves/waveN.poses.json, waveN.keysets.json, waveN.manifest.json (Combat's row, the poses and the distance of each).
// The chamber comes from a per-limb template of the existing authored chambers, then the spec's own overrides; the follow-through is the
// contact blended toward the guard stance (0.45, or the spec's follow_t), then the spec's overrides. Nothing is played in live
// matches: AnimData bakes the wave files only with --waves (tools). Run from the repo root:
//   node render/anim/tools/wave_gen.mjs wave1 [--project DIR] [--out DIR]
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const argv = process.argv.slice(2);
const wave = argv[0] || 'wave1';
const opt = (n, d) => { const i = argv.indexOf('--' + n); return i >= 0 ? argv[i + 1] : d; };
const project = resolve(opt('project', '.'));
const outDir = resolve(opt('out', join(project, 'data/anim/waves')));
const prefix = wave.replace('wave', 'w');   // w1

const poses = JSON.parse(readFileSync(join(project, 'data/anim/poses.json'), 'utf8')).poses;
const combat = JSON.parse(readFileSync(resolve(opt('combat', join(project, 'docs/combat/pending/strikes.antihero.' + wave + '.json'))), 'utf8'));
const { strikes: spec } = await import(pathToFileURL(resolve(project, 'render/anim/tools/waves/' + wave + '.mjs')).href);

const clone = o => JSON.parse(JSON.stringify(o));
const isObj = v => v && typeof v === 'object' && !Array.isArray(v);
function merge(a, b) {
  const r = clone(a);
  for (const k of Object.keys(b || {})) r[k] = isObj(b[k]) && isObj(r[k]) ? merge(r[k], b[k]) : clone(b[k]);
  return r;
}
const strip = o => { const r = clone(o); for (const k of Object.keys(r)) if (k.startsWith('_')) delete r[k]; return r; };
const P = id => { if (!poses[id]) throw new Error('missing base pose ' + id); return strip(poses[id]); };

const GUARD = P('stance.aggressive');
const TEMPLATE = {
  hand: P('strike.cross.chamber'),
  elbow: P('strike.elbow.chamber'),
  foot: P('strike.kick.chamber'),
  knee: P('strike.knee.chamber'),
  head: P('strike.headbutt.chamber'),
  shoulder: merge(P('strike.cross.chamber'), { lean: -4, spine: { lean: 0, twist: -26 }, hand_r: [10, 54, 10], hand_l: [14, 54, -8] }),
  two_hand: merge(P('strike.cross.chamber'), { lean: 6, spine: { lean: 4, twist: 0 }, hand_r: [8, 58, 12], hand_l: [8, 58, -12] }),
};
const open = h => ({ hands: { r: 'open', l: 'open' }, ...h });

function lerpVal(a, b, t) {
  if (Array.isArray(a) && Array.isArray(b)) return a.map((x, i) => x + (b[i] - x) * t);
  if (typeof a === 'number' && typeof b === 'number') return a + (b - a) * t;
  return a;
}
function blendToGuard(c, t) {
  const r = clone(c);
  for (const k of ['lean', 'hip_twist']) r[k] = lerpVal(c[k] ?? 0, GUARD[k] ?? 0, t);
  for (const k of ['hips', 'hand_r', 'hand_l', 'foot_r', 'foot_l']) if (c[k] && GUARD[k]) r[k] = lerpVal(c[k], GUARD[k], t).map(x => Math.round(x * 2) / 2);
  for (const g of ['spine', 'head']) {
    r[g] = {};
    const keys = new Set([...Object.keys(c[g] || {}), ...Object.keys(GUARD[g] || {})]);
    for (const k of keys) r[g][k] = Math.round(lerpVal(c[g]?.[k] ?? 0, GUARD[g]?.[k] ?? 0, t) * 2) / 2;
  }
  r.lean = Math.round(r.lean * 2) / 2;
  if (r.hip_twist !== undefined) r.hip_twist = Math.round(r.hip_twist * 2) / 2;
  if (c.family === 'upright_lunge') r.family = 'upright';
  return r;
}

const SIDE = { hand: 'hand_r', elbow: 'elbow_r', foot: 'foot_r', knee: 'knee_r', head: 'head', shoulder: 'shoulder_r' };
const opposite = l => l.endsWith('_r') ? l.slice(0, -1) + 'l' : l.slice(0, -1) + 'r';

const outPoses = {};
const outKeysets = {};
const manifest = [];
const skipped = [];
for (const row of combat.strikes) {
  const name = row.id.replace('strike.', '');
  const sp = spec[name];
  if (!sp) { skipped.push(name + (row.pose === 'held' ? ' (held)' : ' (no spec)')); continue; }
  const id = `${prefix}.${name}`;
  let ch, ct, fo;
  if (sp.from) {
    const b = k => P(`strike.${sp.from}.${k}`);
    const o = sp.over || {};
    ch = merge(merge(b('chamber'), o.all || {}), o.chamber || {});
    ct = merge(merge(b('contact'), o.all || {}), o.contact || {});
    fo = merge(merge(b('follow'), o.all || {}), o.follow || {});
    if (sp.contact) ct = merge(ct, sp.contact);   // a new contact over a derived family (the backfist, the overhand)
    if (sp.chamber) ch = merge(ch, sp.chamber);
    if (sp.follow) fo = merge(fo, sp.follow);
  } else {
    ct = clone(sp.contact);
    const tpl = TEMPLATE[sp.kind];
    if (!tpl) throw new Error('no chamber template for ' + sp.kind);
    ch = merge(tpl, sp.chamber || {});
    ch.hands = ct.hands || ch.hands;
    fo = merge(blendToGuard(ct, sp.follow_t ?? 0.45), sp.follow || {});
  }
  if (sp.from && sp.contact) fo = fo;   // derived follow is the base's
  const L = row.limb === 'own' ? null : SIDE[row.limb];
  if (!L) { skipped.push(name + ' (own limb)'); continue; }
  const two = (row.uses?.arms === 2 || row.uses?.legs === 2);
  const ks = { limb: L, target: sp.target || row.target, weight: row.weight };
  if (two) ks.limb2 = sp.limb2 || opposite(L);
  if (sp.step_max !== undefined) ks.step_max = sp.step_max;
  ks._combat = row.id;
  ks._wave = wave;
  const parts = { chamber: ch, contact: ct, follow: fo };
  ks.keys = [];
  for (const [role, part] of [['load', 'chamber'], ['contact', 'contact'], ['follow', 'follow']]) {
    const pid = `${id}.${part}`;
    const p = parts[part];
    p._orig = sp.orig + (part === 'chamber' ? ' (the wind-up)' : part === 'follow' ? ' (the follow-through)' : '');
    if (sp.legal) p._legal = sp.legal;
    outPoses[pid] = p;
    ks.keys.push({ role, pose: pid });
  }
  outKeysets[id] = ks;
  if (sp.alt) {   // the B version of an A/B pair: the same strike with the alternative's overrides
    const idb = id + '~b';
    const ksb = clone(ks);
    ksb._variant = 'b';
    ksb._alt = sp.alt.label;
    ksb.keys = [];
    for (const [role, part] of [['load', 'chamber'], ['contact', 'contact'], ['follow', 'follow']]) {
      const pb = merge(merge(parts[part], sp.alt.all || {}), sp.alt[part] || {});
      pb._orig = sp.orig + ` (version B: ${sp.alt.label})`;
      outPoses[`${idb}.${part}`] = pb;
      ksb.keys.push({ role, pose: `${idb}.${part}` });
    }
    outKeysets[idb] = ksb;
  }
  manifest.push({ id, combat: row.id, name, weight: row.weight, target: ks.target, limb: L, limb2: ks.limb2 || null,
    offset: row.range.offset, reach: row.range.reach, band: row.range.band, ticks: row.ticks, ground: row.ground, uses: row.uses,
    from: sp.from || null, legal: sp.legal || [], look: row.look, orig: sp.orig, poses: ks.keys.map(k => k.pose), alt: sp.alt ? sp.alt.label : null });
}
mkdirSync(outDir, { recursive: true });
const hdr = (kind) => ({ schema: `anim.wave.${kind}/1`, _about: `${wave}: ${kind} of the Anti-hero's key strikes, generated by render/anim/tools/wave_gen.mjs from render/anim/tools/waves/${wave}.mjs and docs/combat/pending/strikes.antihero.${wave}.json. Parked: baked only with --waves, no live match plays them. Render only, outside the sim's data hash.` });
const wr = (n, o) => writeFileSync(join(outDir, n), JSON.stringify(o, null, 1).replace(/\[\n\s+([^\[\]{}]*?)\n\s+\]/g, (m, inner) => '[' + inner.replace(/\n\s+/g, ' ') + ']'));
const poseLines = Object.entries(outPoses).map(([k, v]) => `  ${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(',\n');
writeFileSync(join(outDir, wave + '.poses.json'), JSON.stringify(hdr('poses')).slice(0, -1) + `,\n "poses": {\n${poseLines}\n }}\n`);
const ksLines = Object.entries(outKeysets).map(([k, v]) => `  ${JSON.stringify(k)}: ${JSON.stringify(v)}`).join(',\n');
writeFileSync(join(outDir, wave + '.keysets.json'), JSON.stringify(hdr('keysets')).slice(0, -1) + `,\n "keysets": {\n${ksLines}\n }}\n`);
writeFileSync(join(outDir, wave + '.manifest.json'), JSON.stringify({ wave, strikes: manifest, skipped }, null, 1));
console.log(`[wave_gen] ${wave}: ${manifest.length} strikes, ${Object.keys(outPoses).length} poses (${manifest.filter(m => !m.from).length} new contacts, ${manifest.filter(m => m.from).length} derived), skipped: ${skipped.join(', ')}`);
