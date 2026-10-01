'use strict';
// Cross-reference rules for the fight-level data: combat styles, input feel, fight mood and fight style.
// Called from xref.js with its helpers: get(rel), err(file, pointer, rule, message, level), esc, isObj, plainKeys.

const STYLES = 'data/combat/styles.json';
const TPL = 'data/combat/templates.json';
const FIN = 'data/combat/finishers.json';
const FEEL = 'data/input/feel.json';
const MOOD = 'data/fight/mood.json';
const STYLE = 'data/fight/style.json';

// The per-second counters a style label may measure (docs/architecture/mood-style.md section 2), plus the derived total.
const MEASURES = new Set(['stance0', 'stance1', 'stance2', 'stance3', 'light', 'heavy', 'sig', 'closing', 'opened', 'charge', 'chargeCut', 'sigLanded', 'stanceTotal']);

function xrefFight({ get, err, esc, isObj, plainKeys, docsFor }) {
  // ---- combat styles ----
  const styles = get(STYLES);
  if (isObj(styles)) {
    const tpl = get(TPL);
    const fin = get(FIN);
    const templateIds = new Set(isObj(tpl) && Array.isArray(tpl.templates) ? tpl.templates.map((t) => t && t.id) : []);
    if (Array.isArray(styles.styles)) {
      const seen = new Map();
      styles.styles.forEach((s, i) => {
        if (!isObj(s)) return;
        if (seen.has(s.id)) err(STYLES, `/styles/${i}/id`, 'style-id', `style id "${s.id}" is already used at ${seen.get(s.id)}`);
        else seen.set(s.id, `/styles/${i}`);
        if (templateIds.size && Array.isArray(s.appliesTo)) {
          s.appliesTo.forEach((t, ti) => {
            if (!templateIds.has(t)) err(STYLES, `/styles/${i}/appliesTo/${ti}`, 'style-template', `style "${s.id}" applies to template "${t}", which is not in ${TPL} (${[...templateIds].join(', ')})`);
          });
        }
      });
    }
    // Selector ranges tile: each band starts where the previous one ends.
    const sel = styles.selectors;
    if (isObj(sel)) {
      const tile = (group, names, at) => {
        if (!isObj(group)) return;
        for (let i = 0; i + 1 < names.length; i++) {
          const a = group[names[i]];
          const b = group[names[i + 1]];
          if (isObj(a) && isObj(b) && typeof a.below === 'number' && typeof b.from === 'number' && a.below !== b.from) {
            err(STYLES, `${at}/${names[i + 1]}/from`, 'style-bands', `${names[i + 1]} starts at ${b.from}, but ${names[i]} ends at ${a.below} (bands must tile with no gap or overlap)`);
          }
        }
      };
      tile(sel.altitudeBands, ['ground', 'lowAir', 'highAir'], '/selectors/altitudeBands');
      tile(sel.mood, ['Calm', 'Tense', 'Frenzied'], '/selectors/mood');
      if (isObj(sel.traits)) {
        const known = new Set();
        if (isObj(fin) && isObj(fin.select) && isObj(fin.select.byFighter)) Object.keys(fin.select.byFighter).forEach((k) => known.add(k));
        if (isObj(fin) && isObj(fin.shapes)) plainKeys(fin.shapes).forEach((k) => known.add(k));
        if (known.size) {
          for (const who of plainKeys(sel.traits)) {
            if (!known.has(who)) err(STYLES, `/selectors/traits/${esc(who)}`, 'style-fighter', `traits for "${who}", which is neither a fighter in ${FIN} select.byFighter nor one of its shapes (${[...known].join(', ')})`);
          }
        }
      }
    }
    // The clash order lists every shape exactly once.
    const bc = styles.beamClash;
    if (isObj(bc) && Array.isArray(bc.order) && isObj(bc.shapes)) {
      const shapes = new Set(plainKeys(bc.shapes));
      bc.order.forEach((n, i) => { if (!shapes.has(n)) err(STYLES, `/beamClash/order/${i}`, 'style-clash-order', `order names shape "${n}", which is not in shapes`); });
      for (const n of shapes) if (!bc.order.includes(n)) err(STYLES, `/beamClash/shapes/${esc(n)}`, 'style-clash-order', `shape "${n}" is not in order, so it can never be chosen`);
    }
    // Telegraph kinds name real finishers (or the four fighter shapes) and every kind has a cue.
    const tg = isObj(styles.telegraphs) ? styles.telegraphs.finishers : undefined;
    if (isObj(tg)) {
      const finisherIds = new Set(isObj(fin) && Array.isArray(fin.finishers) ? fin.finishers.map((f) => f && f.id) : []);
      const shapeIds = new Set(isObj(fin) && isObj(fin.shapes) ? plainKeys(fin.shapes) : []);
      for (const key of ['kinds', 'futureKinds']) {
        for (const [who, kind] of Object.entries(isObj(tg[key]) ? tg[key] : {})) {
          if (who.startsWith('_')) continue;
          if (finisherIds.size && !finisherIds.has(who) && !shapeIds.has(who)) err(STYLES, `/telegraphs/finishers/${key}/${esc(who)}`, 'style-finisher', `"${who}" is neither a finisher id nor a fighter shape in ${FIN}`);
          if (isObj(tg.cues) && !(kind in tg.cues)) err(STYLES, `/telegraphs/finishers/${key}/${esc(who)}`, 'style-finisher', `kind "${kind}" has no cue in telegraphs.finishers.cues`);
        }
      }
    }
    // Tempo names used in beats (and by the chain cadence) exist in styles.tempo or the dynamic profile's tempo.
    const names = new Set(isObj(styles.tempo) ? plainKeys(styles.tempo) : []);
    const dyn = isObj(tpl) && isObj(tpl.profiles) && isObj(tpl.profiles.dynamic) && isObj(tpl.profiles.dynamic.tempo) ? plainKeys(tpl.profiles.dynamic.tempo) : [];
    dyn.forEach((n) => names.add(n));
    const bad = (pointer, name) => {
      if (typeof name === 'string' && names.size && !names.has(name)) err(STYLES, pointer, 'style-tempo-name', `"${name}" is not a tempo name (${[...names].join(', ')})`);
    };
    const walk = (node, pointer) => {
      if (Array.isArray(node)) node.forEach((x, i) => walk(x, `${pointer}/${i}`));
      else if (isObj(node)) {
        if (isObj(node.tick)) for (const k of ['add', 'sub']) if (Array.isArray(node.tick[k])) node.tick[k].forEach((n, i) => bad(`${pointer}/tick/${k}/${i}`, n));
        if (typeof node.ticks === 'string') bad(`${pointer}/ticks`, node.ticks);
        for (const [k, v] of Object.entries(node)) if (!k.startsWith('_')) walk(v, `${pointer}/${esc(k)}`);
      }
    };
    walk(styles.styles, '/styles');
    walk(styles.chains, '/chains');
    if (isObj(styles.chains)) {
      if (isObj(styles.chains.blitz)) bad('/chains/blitz/gap', styles.chains.blitz.gap);
      if (isObj(styles.chains.cadence)) bad('/chains/cadence/linkGap', styles.chains.cadence.linkGap);
    }
  }

  // ---- input feel ----
  const feel = get(FEEL);
  if (isObj(feel)) {
    const h = isObj(feel.hold) ? feel.hold : {};
    const s = isObj(feel.signature) ? feel.signature : {};
    const hs = isObj(feel.hitstopTicks) ? feel.hitstopTicks : {};
    if (typeof h.triggerOff === 'number' && typeof h.triggerOn === 'number' && !(h.triggerOff < h.triggerOn)) {
      err(FEEL, '/hold/triggerOff', 'feel-order', `triggerOff ${h.triggerOff} must be below triggerOn ${h.triggerOn} (hysteresis needs a gap)`);
    }
    if (Number.isInteger(s.maxWaitFunded) && Number.isInteger(s.unfundedExpiry) && s.maxWaitFunded > s.unfundedExpiry) {
      err(FEEL, '/signature/maxWaitFunded', 'feel-cap', `a funded signature (${s.maxWaitFunded} ticks) must not outlive an unfunded one (${s.unfundedExpiry})`);
    }
    if (Number.isInteger(h.encoreConfirm) && Number.isInteger(h.confirmTicks) && h.encoreConfirm > h.confirmTicks) {
      err(FEEL, '/hold/encoreConfirm', 'feel-encore', `encoreConfirm ${h.encoreConfirm} must not exceed confirmTicks ${h.confirmTicks}`);
    }
    if (Number.isInteger(h.encoreConfirm) && Number.isInteger(h.encoreOffer) && !(h.encoreConfirm < h.encoreOffer)) {
      err(FEEL, '/hold/encoreOffer', 'feel-encore', `encoreConfirm ${h.encoreConfirm} must fit inside encoreOffer ${h.encoreOffer}`);
    }
    // The impact hierarchy of docs/controls/rulings.md section 5: a warning, not an error.
    const chain1 = ['light', 'chain', 'heavy', 'guardBreak', 'parry'];
    for (let i = 0; i + 1 < chain1.length; i++) {
      const a = hs[chain1[i]];
      const b = hs[chain1[i + 1]];
      if (Number.isInteger(a) && Number.isInteger(b) && a > b) err(FEEL, `/hitstopTicks/${chain1[i]}`, 'feel-hitstop-order', `${chain1[i]} (${a}) should not exceed ${chain1[i + 1]} (${b}); the impact hierarchy is light <= chain <= heavy <= guardBreak <= parry`, 'warning');
    }
    const chain2 = ['beamConnect', 'beamClash', 'finalBlow'];
    for (let i = 0; i + 1 < chain2.length; i++) {
      const a = hs[chain2[i]];
      const b = hs[chain2[i + 1]];
      if (Number.isInteger(a) && Number.isInteger(b) && a > b) err(FEEL, `/hitstopTicks/${chain2[i]}`, 'feel-hitstop-order', `${chain2[i]} (${a}) should not exceed ${chain2[i + 1]} (${b}); the hierarchy is beamConnect <= beamClash <= finalBlow`, 'warning');
    }
    for (const [k, v] of Object.entries(hs)) {
      if (!k.startsWith('_') && Number.isInteger(v) && v > 30) err(FEEL, `/hitstopTicks/${esc(k)}`, 'feel-hitstop-budget', `${k} is ${v} ticks; more than 30 reads as a hang`);
    }
    const walk = (node, pointer) => {
      if (Array.isArray(node)) node.forEach((x, i) => walk(x, `${pointer}/${i}`));
      else if (isObj(node)) {
        for (const [k, v] of Object.entries(node)) {
          if (/(Seconds|Sec)$/.test(k)) err(FEEL, `${pointer}/${esc(k)}`, 'feel-ticks-only', `key "${k}" is in seconds; this file is in ticks`);
          walk(v, `${pointer}/${esc(k)}`);
        }
      }
    };
    walk(feel, '');
  }

  // ---- ui control hints ----
  const hints = get('ui/data/hints.json');
  if (isObj(hints) && isObj(hints.schemes)) {
    const glyphsDoc = get('ui/data/glyphs.json');
    // Hint rows name either a glyph action (today's scheme) or an input action (ADR 0008 layouts): both are valid.
    const glyphActions = new Set(isObj(glyphsDoc) && isObj(glyphsDoc.actions) ? Object.keys(glyphsDoc.actions) : []);
    const inputActionsDoc = get('data/input/actions.json');
    if (isObj(inputActionsDoc) && Array.isArray(inputActionsDoc.actions)) for (const x of inputActionsDoc.actions) if (isObj(x) && typeof x.id === 'string') glyphActions.add(x.id);
    for (const [name, sc] of Object.entries(hints.schemes)) {
      if (!isObj(sc) || !Array.isArray(sc.rows)) continue;
      sc.rows.forEach((row, ri) => {
        if (!isObj(row)) return;
        const ids = [];
        if (typeof row.action === 'string') ids.push([`/schemes/${esc(name)}/rows/${ri}/action`, row.action]);
        if (Array.isArray(row.actions)) row.actions.forEach((a, ai) => ids.push([`/schemes/${esc(name)}/rows/${ri}/actions/${ai}`, a]));
        if (glyphActions.size) for (const [pointer, a] of ids) if (!glyphActions.has(a)) err('ui/data/hints.json', pointer, 'hints-action', 'action "' + a + '" is in neither glyphs.json actions nor data/input/actions.json');
      });
    }
    const opts = get('ui/data/options.json');
    const cs = isObj(opts) && isObj(opts.options) ? opts.options.control_scheme : undefined;
    if (isObj(cs) && Array.isArray(cs.choices)) {
      cs.choices.forEach((ch, i) => { if (!(ch in hints.schemes)) err('ui/data/options.json', '/options/control_scheme/choices/' + i, 'hints-scheme', 'control_scheme choice "' + ch + '" has no scheme in hints.json'); });
    }
  }

  // ---- ui feedback panel ----
  const fb = get('ui/data/feedback.json');
  if (isObj(fb) && Array.isArray(fb.tags)) {
    const seenTag = new Map();
    fb.tags.forEach((tag, i) => {
      if (!isObj(tag)) return;
      if (seenTag.has(tag.id)) err('ui/data/feedback.json', '/tags/' + i + '/id', 'feedback-tag', 'tag id "' + tag.id + '" is already used at ' + seenTag.get(tag.id));
      else seenTag.set(tag.id, '/tags/' + i);
    });
  }

  // ---- ui reads and tutorial hints ----
  const reads = get('ui/data/reads.json');
  if (isObj(reads)) {
    const terms = get('ui/data/terms.json');
    const stances = new Set(isObj(terms) && Array.isArray(terms.stance_ids) ? terms.stance_ids : []);
    if (isObj(reads.finisher_counter) && stances.size) {
      for (const [kind, stance] of Object.entries(reads.finisher_counter)) {
        if (!stances.has(stance)) err('ui/data/reads.json', `/finisher_counter/${esc(kind)}`, 'reads-stance', `the counter to a ${kind} finisher is "${stance}", which is not in terms.json stance_ids (${[...stances].join(', ')})`);
      }
    }
    const styles2 = get(STYLES);
    const kinds = isObj(styles2) && isObj(styles2.telegraphs) && isObj(styles2.telegraphs.finishers) && isObj(styles2.telegraphs.finishers.cues) ? Object.keys(styles2.telegraphs.finishers.cues) : [];
    if (isObj(reads.finisher_counter) && kinds.length) {
      for (const k of kinds) if (!(k in reads.finisher_counter)) err('ui/data/reads.json', '/finisher_counter', 'reads-kind', `finisher kind "${k}" (combat styles telegraphs) has no counter here`);
    }
    const beats = Array.isArray(reads.beat_ids) ? reads.beat_ids : [];
    if (isObj(reads.hints)) {
      for (const [key, text] of Object.entries(reads.hints)) {
        const beat = key.split('.')[0];
        if (beats.length && !beats.includes(beat)) err('ui/data/reads.json', `/hints/${esc(key)}`, 'reads-beat', `hint "${key}" belongs to beat "${beat}", which is not in beat_ids`);
        const words = typeof text === 'string' ? text.trim().split(/\s+/).length : 0;
        if (words > 14) err('ui/data/reads.json', `/hints/${esc(key)}`, 'reads-length', `${words} words; the note says at most about ten`, 'warning');
      }
      for (const beat of beats) {
        if (!(`${beat}.hint` in reads.hints)) err('ui/data/reads.json', '/hints', 'reads-beat', `beat "${beat}" has no "${beat}.hint" line`);
      }
    }
  }

  // ---- animation data (render only) ----
  const poses = get('data/anim/poses.json');
  const keysets = get('data/anim/keysets.json');
  const profiles = get('data/anim/profiles.json');
  const animCues = get('data/anim/cues.json');
  const poseNames = new Set(isObj(poses) && isObj(poses.poses) ? Object.keys(poses.poses) : []);
  const bones = new Set(isObj(profiles) && isObj(profiles.bone_lag) ? Object.keys(profiles.bone_lag) : []);
  if (isObj(poses) && isObj(poses.poses) && bones.size) {
    for (const [name, p] of Object.entries(poses.poses)) {
      if (!isObj(p) || !isObj(p.fk)) continue;
      for (const bone of Object.keys(p.fk)) if (!bones.has(bone)) err('data/anim/poses.json', '/poses/' + esc(name) + '/fk/' + esc(bone), 'anim-bone', 'bone "' + bone + '" is not in profiles.json bone_lag');
    }
  }
  if (isObj(keysets)) {
    const sets = isObj(keysets.keysets) ? keysets.keysets : {};
    for (const [name, k] of Object.entries(sets)) {
      if (!isObj(k) || !Array.isArray(k.keys)) continue;
      const roles = new Set();
      k.keys.forEach((key, i) => {
        if (!isObj(key)) return;
        if (poseNames.size && !poseNames.has(key.pose)) err('data/anim/keysets.json', '/keysets/' + esc(name) + '/keys/' + i + '/pose', 'anim-pose', 'pose "' + key.pose + '" is not in poses.json');
        if (roles.has(key.role)) err('data/anim/keysets.json', '/keysets/' + esc(name) + '/keys/' + i + '/role', 'anim-role', 'role "' + key.role + '" appears twice in key set "' + name + '"');
        roles.add(key.role);
      });
    }
    for (const which of ['light', 'heavy']) {
      const list = isObj(keysets.picks) && Array.isArray(keysets.picks[which]) ? keysets.picks[which] : [];
      list.forEach((n, i) => { if (!(n in sets)) err('data/anim/keysets.json', '/picks/' + which + '/' + i, 'anim-pick', 'pick "' + n + '" is not a key set'); });
    }
  }
  if (isObj(profiles) && isObj(profiles.profiles) && typeof profiles.default === 'string' && !(profiles.default in profiles.profiles)) {
    err('data/anim/profiles.json', '/default', 'anim-profile', 'default profile "' + profiles.default + '" is not in profiles (' + Object.keys(profiles.profiles).join(', ') + ')');
  }
  if (isObj(animCues) && isObj(animCues.cues)) {
    const fin2 = get('data/combat/finishers.json');
    const vocab = new Set(isObj(fin2) && isObj(fin2.cues) ? plainKeys(fin2.cues) : []);
    for (const [cue, pose] of Object.entries(animCues.cues)) {
      if (vocab.size && !vocab.has(cue)) err('data/anim/cues.json', '/cues/' + esc(cue), 'anim-cue', 'cue "' + cue + '" is not in the cue vocabulary of finishers.json');
      if (poseNames.size && !poseNames.has(pose)) err('data/anim/cues.json', '/cues/' + esc(cue), 'anim-pose', 'pose "' + pose + '" is not in poses.json');
    }
  }

  // ---- fighter wounds: the guard wear split sums to 1 ----
  for (const rel of docsFor(/^data\/fighters\/[^/]+\/wounds\.json$/)) {
    const w = get(rel);
    const g = isObj(w) ? w.guardWearSplit : undefined;
    if (isObj(g) && typeof g.arms === 'number' && typeof g.legs === 'number' && Math.abs(g.arms + g.legs - 1) > 1e-9) {
      err(rel, '/guardWearSplit', 'guard-split', 'arms ' + g.arms + ' + legs ' + g.legs + ' = ' + (g.arms + g.legs) + ', but the two shares must sum to 1');
    }
  }

  // ---- settlements (mirrors sim/world/settlements.gd _validate) ----
  const st = get('data/biomes/settlements.json');
  if (isObj(st)) {
    const F = 'data/biomes/settlements.json';
    const shapes = new Set(Array.isArray(st.shapes) ? st.shapes : []);
    const eps = 0.001;
    const asc = (pair, pointer) => { if (Array.isArray(pair) && pair.length === 2 && typeof pair[0] === 'number' && typeof pair[1] === 'number' && pair[0] > pair[1]) err(F, pointer, 'settle-range', '[' + pair[0] + ', ' + pair[1] + '] is not ascending'); };
    const hdist = (h, pointer) => {
      if (!isObj(h) || ![h.median, h.spread, h.min, h.max].every((n) => typeof n === 'number')) return;
      if (h.min > h.max || h.median < h.min || h.median > h.max) err(F, pointer, 'settle-height', 'needs min <= median <= max (got ' + h.min + ', ' + h.median + ', ' + h.max + ')');
    };
    const seenLm = new Set();
    (Array.isArray(st.landmarks) ? st.landmarks : []).forEach((l, i) => {
      if (!isObj(l)) return;
      if (seenLm.has(l.key)) err(F, '/landmarks/' + i + '/key', 'settle-landmark', 'landmark key "' + l.key + '" is repeated');
      seenLm.add(l.key);
      if (shapes.size && !shapes.has(l.shape)) err(F, '/landmarks/' + i + '/shape', 'settle-shape', 'unknown shape "' + l.shape + '"');
    });
    const ids = new Set();
    let popTotal = 0;
    (Array.isArray(st.settlements) ? st.settlements : []).forEach((s, si) => {
      if (!isObj(s)) return;
      const at = '/settlements/' + si;
      if (ids.has(s.id)) err(F, at + '/id', 'settle-id', 'settlement id "' + s.id + '" is repeated');
      ids.add(s.id);
      asc(s.span, at + '/span');
      if (typeof s.pop_share === 'number') popTotal += s.pop_share;
      let shareSum = 0;
      const names = new Set();
      (Array.isArray(s.districts) ? s.districts : []).forEach((d, di) => {
        if (!isObj(d)) return;
        const dat = at + '/districts/' + di;
        if (names.has(d.name)) err(F, dat + '/name', 'settle-district', 'district name "' + d.name + '" is repeated in ' + s.id);
        names.add(d.name);
        if (typeof d.share === 'number') shareSum += d.share;
        const rows = Array.isArray(d.rows) ? d.rows : [];
        let wsum = 0;
        (Array.isArray(d.kinds) ? d.kinds : []).forEach((k, ki) => {
          if (!isObj(k)) return;
          if (typeof k.weight === 'number') wsum += k.weight;
          if (shapes.size && !shapes.has(k.shape)) err(F, dat + '/kinds/' + ki + '/shape', 'settle-shape', 'unknown shape "' + k.shape + '"');
          hdist(k.height_bh, dat + '/kinds/' + ki + '/height_bh');
          asc(k.width_bh, dat + '/kinds/' + ki + '/width_bh');
        });
        if (Array.isArray(d.kinds) && d.kinds.length && wsum <= 0) err(F, dat + '/kinds', 'settle-weights', 'kind weights sum to zero');
        hdist(d.height_bh, dat + '/height_bh');
        for (const k of ['width_bh', 'depth_aspect', 'gap_bh', 'block_bh', 'avenue_bh']) asc(d[k], dat + '/' + k);
        (Array.isArray(d.landmarks) ? d.landmarks : []).forEach((lm, li) => {
          if (!isObj(lm)) return;
          if (!seenLm.has(lm.key)) err(F, dat + '/landmarks/' + li + '/key', 'settle-landmark', 'unknown landmark key "' + lm.key + '"');
          if (!rows.includes(lm.row)) err(F, dat + '/landmarks/' + li + '/row', 'settle-row', 'the landmark\'s row ' + lm.row + ' is not one of the district\'s rows ' + JSON.stringify(rows));
        });
      });
      if (Array.isArray(s.districts) && s.districts.length && Math.abs(shareSum - 1) > eps) err(F, at + '/districts', 'settle-share', 'district shares sum to ' + shareSum.toFixed(3) + ', not 1');
    });
    if (Array.isArray(st.settlements) && st.settlements.length && Math.abs(popTotal - 1) > eps) err(F, '/settlements', 'settle-share', 'pop_share sums to ' + popTotal.toFixed(3) + ', not 1');
  }

  // ---- fighter ladder: the beam tables never decrease with the tier ----
  for (const rel of docsFor(/^data\/fighters\/[^/]+\/ladder\.json$/)) {
    const lad = get(rel);
    const bm = isObj(lad) ? lad.beam : undefined;
    if (!isObj(bm)) continue;
    for (const key of ['levelCapShare', 'overshoot']) {
      const arr = bm[key];
      if (!Array.isArray(arr)) continue;
      for (let i = 1; i < arr.length; i++) {
        if (typeof arr[i] === 'number' && typeof arr[i - 1] === 'number' && arr[i] < arr[i - 1]) err(rel, '/beam/' + key + '/' + i, 'ladder-beam-order', key + ' falls from ' + arr[i - 1] + ' to ' + arr[i] + ' at tier ' + (i + 1) + '; it must not decrease with the tier');
      }
    }
  }

  // ---- fighter meters ----
  for (const rel of [...docsFor(/^data\/fighters\/[^/]+\/meters\.json$/)]) {
    const doc = get(rel);
    if (!isObj(doc) || !isObj(doc.meters)) continue;
    for (const [name, m] of Object.entries(doc.meters)) {
      if (!isObj(m) || !Array.isArray(m.range) || m.range.length !== 2) continue;
      const at = '/meters/' + esc(name);
      if (!(m.range[0] < m.range[1])) err(rel, at + '/range', 'meter-range', 'range ' + JSON.stringify(m.range) + ' must run from low to high');
      if (typeof m.start === 'number' && (m.start < m.range[0] || m.start > m.range[1])) err(rel, at + '/start', 'meter-range', 'start ' + m.start + ' is outside the range ' + JSON.stringify(m.range));
    }
  }

  // ---- fight mood ----
  const mood = get(MOOD);
  if (isObj(mood)) {
    const bd = isObj(mood.bands) ? mood.bands : {};
    if (Number.isInteger(bd.tense) && Number.isInteger(bd.frenzied) && bd.tense >= bd.frenzied) err(MOOD, '/bands/frenzied', 'mood-bands', 'frenzied ' + bd.frenzied + ' must be above tense ' + bd.tense);
    if (Number.isInteger(mood.range)) {
      for (const k of ['tense', 'frenzied']) if (Number.isInteger(bd[k]) && bd[k] > mood.range) err(MOOD, '/bands/' + k, 'mood-bands', k + ' ' + bd[k] + ' is above the range ' + mood.range);
    }
    if (Array.isArray(mood.actFloors)) {
      if (isObj(mood.act) && Number.isInteger(mood.act.max) && mood.actFloors.length !== mood.act.max) err(MOOD, '/actFloors', 'mood-acts', 'actFloors has ' + mood.actFloors.length + ' entries, but act.max is ' + mood.act.max + ' (one floor per act)');
      mood.actFloors.forEach((v, i) => {
        if (i > 0 && Number.isInteger(v) && Number.isInteger(mood.actFloors[i - 1]) && v <= mood.actFloors[i - 1]) err(MOOD, '/actFloors/' + i, 'mood-acts', 'act floor ' + v + ' must be above the previous ' + mood.actFloors[i - 1]);
        if (Number.isInteger(v) && Number.isInteger(mood.range) && v > mood.range) err(MOOD, '/actFloors/' + i, 'mood-acts', 'act floor ' + v + ' is above the range ' + mood.range);
      });
      if (Number.isInteger(mood.actFloors[0]) && mood.actFloors[0] !== 0) err(MOOD, '/actFloors/0', 'mood-acts', 'the first act starts at 0');
    }
    if (isObj(mood.aggression) && Number.isInteger(mood.aggression.base) && Number.isInteger(mood.aggression.max) && mood.aggression.max < mood.aggression.base) err(MOOD, '/aggression/max', 'mood-aggression', 'max ' + mood.aggression.max + ' is below base ' + mood.aggression.base);
  }
  // ---- fight style ----
  const style = get(STYLE);
  if (isObj(style) && isObj(style.labels)) {
    const labels = plainKeys(style.labels);
    if (Array.isArray(style.priority)) {
      style.priority.forEach((n, i) => { if (!labels.includes(n)) err(STYLE, `/priority/${i}`, 'style-priority', `priority names "${n}", which is not in labels`); });
      for (const n of labels) if (!style.priority.includes(n)) err(STYLE, `/labels/${esc(n)}`, 'style-priority', `label "${n}" is not in priority, so it can never win a tie`);
    }
    for (const [name, l] of Object.entries(style.labels)) {
      if (name.startsWith('_') || !isObj(l)) continue;
      const at = `/labels/${esc(name)}`;
      if (Number.isInteger(l.enterPct) && Number.isInteger(l.leavePct) && l.leavePct >= l.enterPct) err(STYLE, `${at}/leavePct`, 'style-hysteresis', `leavePct ${l.leavePct} must be below enterPct ${l.enterPct} (otherwise the label flickers)`);
      for (const k of ['enterHoldS', 'leaveHoldS']) {
        if (Number.isInteger(l[k]) && Number.isInteger(style.windowS) && l[k] > style.windowS) err(STYLE, `${at}/${k}`, 'style-window', `${k} ${l[k]} s is longer than the ${style.windowS} s window`);
      }
      if (typeof l.measure === 'string') {
        for (const id of l.measure.match(/[A-Za-z][A-Za-z0-9]*/g) || []) {
          if (!MEASURES.has(id)) err(STYLE, `${at}/measure`, 'style-measure', `"${id}" in the measure is not a known counter (${[...MEASURES].join(', ')})`);
        }
      }
    }
    if (Number.isInteger(style.minWindowFillS) && Number.isInteger(style.windowS) && style.minWindowFillS > style.windowS) err(STYLE, '/minWindowFillS', 'style-window', `minWindowFillS ${style.minWindowFillS} is longer than windowS ${style.windowS}`);
  }
}

module.exports = { xrefFight };
