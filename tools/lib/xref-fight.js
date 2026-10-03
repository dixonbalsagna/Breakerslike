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
    // The blitz chance cap should not sit below the chances it caps (it would silently clip them).
    const bl = isObj(styles.chains) && isObj(styles.chains.blitz) ? styles.chains.blitz.chance : undefined;
    if (isObj(bl) && typeof bl.cap === 'number') {
      for (const k of ['Tense', 'Frenzied']) {
        if (typeof bl[k] === 'number' && bl[k] > bl.cap) err(STYLES, '/chains/blitz/chance/' + k, 'style-blitz-cap', k + ' chance ' + bl[k] + ' is above the cap ' + bl.cap + ', so it is always clipped', 'warning');
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
  if (isObj(profiles) && isObj(profiles.by_part) && isObj(profiles.profiles)) {
    for (const [part, p] of Object.entries(profiles.by_part)) {
      if (!part.startsWith('_') && !(p in profiles.profiles)) err('data/anim/profiles.json', '/by_part/' + esc(part), 'anim-by-part', 'part class "' + part + '" uses profile "' + p + '", which is not in profiles (' + Object.keys(profiles.profiles).join(', ') + ')');
    }
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
    const ls = isObj(w) ? w.lastStand : undefined;
    if (isObj(ls) && typeof ls.windowS === 'number' && Math.abs(ls.windowS * 60 - Math.round(ls.windowS * 60)) > 1e-6) err(rel, '/lastStand/windowS', 'wounds-last-stand', `${ls.windowS} s is not a whole number of ticks (60 a second)`);
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

  // ---- fight pause: orders and whole ticks (the loader checks both) ----
  const pause = get('data/fight/pause.json');
  if (isObj(pause)) {
    const PF = 'data/fight/pause.json';
    const n = (g, k) => (isObj(pause[g]) && typeof pause[g][k] === 'number' ? pause[g][k] : undefined);
    for (const g of ['bank', 'full', 'short', 'live', 'timeCap']) {
      if (!isObj(pause[g])) continue;
      for (const [k, v] of Object.entries(pause[g])) {
        if (!k.startsWith('_') && !k.endsWith('Ticks') && typeof v === 'number' && Math.abs(v * 60 - Math.round(v * 60)) > 1e-6) err(PF, `/${g}/${k}`, 'pause-ticks', `${v} s is not a whole number of ticks (60 a second)`);
      }
    }
    const lt = (ga, ka, gb, kb, strict) => { const x = n(ga, ka); const y = n(gb, kb); if (x !== undefined && y !== undefined && (strict ? x >= y : x > y)) err(PF, `/${ga}/${ka}`, 'pause-order', `${ga}.${ka} ${x} must be ${strict ? 'below' : 'at most'} ${gb}.${kb} ${y}`); };
    lt('bank', 'startS', 'bank', 'maxS', false);
    lt('short', 'lengthS', 'full', 'lengthS', true);
    lt('full', 'lengthS', 'full', 'finalLengthS', false);
    lt('short', 'gapS', 'full', 'gapS', false);
    const cap = n('bank', 'maxS');
    if (cap !== undefined) for (const [g, k] of [['short', 'lengthS'], ['full', 'lengthS']]) { const v = n(g, k); if (v !== undefined && v > cap) err(PF, `/${g}/${k}`, 'pause-order', `${g}.${k} ${v} is above the bank's maxS ${cap}, so the bank can never cover it`, 'warning'); }
  }

  // ---- anim forms: poses exist, hold fits the settle, full and short add up to the pause ----
  const forms = get('data/anim/forms.json');
  if (isObj(forms)) {
    const FF = 'data/anim/forms.json';
    const posesDoc = get('data/anim/poses.json');
    const poseNames = new Set(isObj(posesDoc) && isObj(posesDoc.poses) ? Object.keys(posesDoc.poses) : []);
    if (isObj(forms.poses) && poseNames.size) for (const [beat, id] of Object.entries(forms.poses)) if (!beat.startsWith('_') && typeof id === 'string' && !poseNames.has(id)) err(FF, `/poses/${esc(beat)}`, 'forms-pose', `beat "${beat}" uses pose "${id}", which is not in poses.json`);
    const vs = isObj(forms.versions) ? forms.versions : {};
    for (const [name, v] of Object.entries(vs)) if (isObj(v) && typeof v.hold === 'number' && typeof v.settle === 'number' && v.hold > v.settle) err(FF, `/versions/${esc(name)}/hold`, 'forms-hold', `${name} hold ${v.hold} is longer than its settle ${v.settle}`);
    const pz = get('data/fight/pause.json');
    if (isObj(pz)) for (const [name, len] of [['full', isObj(pz.full) ? pz.full.lengthS : undefined], ['short', isObj(pz.short) ? pz.short.lengthS : undefined]]) {
      const v = vs[name];
      if (isObj(v) && typeof len === 'number' && [v.gather, v.break, v.settle].every((n) => typeof n === 'number')) {
        const sum = v.gather + v.break + v.settle;
        if (sum !== Math.round(len * 60)) err(FF, `/versions/${name}`, 'forms-pause-sum', `${name}: gather + break + settle is ${sum} ticks, but the pause is ${len} s (${Math.round(len * 60)} ticks) in data/fight/pause.json`);
      }
    }
  }

  // ---- dynamic strikes: each is scheduled at least 6 ticks after its list starts (Animation needs the lead to blend into the contact pose) ----
  const tpl6 = get('data/combat/templates.json');
  if (isObj(tpl6) && Array.isArray(tpl6.templates) && isObj(tpl6.profiles) && isObj(tpl6.profiles.dynamic) && isObj(tpl6.profiles.dynamic.tempo)) {
    const tp = tpl6.profiles.dynamic.tempo;
    const ap = tpl6.profiles.dynamic.approach;
    // c is the approach in ticks: at least approach.min seconds (the sim rounds it to whole ticks)
    const cMin = isObj(ap) && typeof ap.min === 'number' ? Math.round(ap.min * 60) : 0;
    tpl6.templates.forEach((tm, ti) => {
      if (!isObj(tm) || !Array.isArray(tm.branches)) return;
      tm.branches.forEach((br, bi) => {
        if (!isObj(br) || !Array.isArray(br.dynamic)) return;
        br.dynamic.forEach((be, bei) => {
          if (!isObj(be) || be.op !== 'strike' || be.tick === undefined) return;
          let v;
          if (typeof be.tick === 'number') v = be.tick;
          else if (isObj(be.tick)) {
            v = (be.tick.at === 'c' ? cMin * (typeof be.tick.times === 'number' ? be.tick.times : 1) : 0) + (typeof be.tick.step === 'number' && typeof tp.step === 'number' ? be.tick.step * tp.step : 0);
            for (const n of Array.isArray(be.tick.add) ? be.tick.add : []) if (typeof tp[n] === 'number') v += tp[n];
            for (const n of Array.isArray(be.tick.sub) ? be.tick.sub : []) if (typeof tp[n] === 'number') v -= tp[n];
          }
          if (typeof v === 'number' && v < 6) err('data/combat/templates.json', `/templates/${ti}/branches/${bi}/dynamic/${bei}/tick`, 'strike-lead', `strike in ${tm.id}/${br.id} is scheduled ${v} ticks after its list starts (at the shortest approach); it needs at least 6`);
        });
      });
    });
  }

  // ---- anim ragdoll: ids, bones, orders ----
  const rag = get('data/anim/ragdoll.json');
  if (isObj(rag)) {
    const RG = 'data/anim/ragdoll.json';
    const lagDoc = get('data/anim/profiles.json');
    const bones = new Set(isObj(lagDoc) && isObj(lagDoc.bone_lag) ? Object.keys(lagDoc.bone_lag) : []);
    const seenIds = new Map();
    (Array.isArray(rag.dofs) ? rag.dofs : []).forEach((d, i) => {
      if (!isObj(d)) return;
      const at = `/dofs/${i}`;
      if (typeof d.id === 'string') { if (seenIds.has(d.id)) err(RG, `${at}/id`, 'ragdoll-id', `dof id "${d.id}" is already used at /dofs/${seenIds.get(d.id)}`); else seenIds.set(d.id, i); }
      if (bones.size) for (const k of ['bone', 'bone2']) if (typeof d[k] === 'string' && !bones.has(d[k])) err(RG, `${at}/${k}`, 'ragdoll-bone', `${k} "${d[k]}" is not in profiles.json bone_lag`);
      if (d.share !== undefined && d.bone2 === undefined) err(RG, `${at}/share`, 'ragdoll-bone', 'share has no bone2 to share with');
      if (d.bone2 !== undefined && d.share === undefined) err(RG, at, 'ragdoll-bone', 'bone2 needs a share');
      if (typeof d.lo === 'number' && typeof d.hi === 'number' && d.lo >= d.hi) err(RG, `${at}/lo`, 'ragdoll-limits', `lo ${d.lo} is not below hi ${d.hi}`);
      if (typeof d.k_loose === 'number' && typeof d.k_stiff === 'number' && d.k_loose > d.k_stiff) err(RG, `${at}/k_loose`, 'ragdoll-limits', `k_loose ${d.k_loose} is above k_stiff ${d.k_stiff}; a loose body should be softer than a posed one`);
      if (typeof d.lo === 'number' && typeof d.hi === 'number') for (const k of ['tsg', 'tuck', 'brace']) if (typeof d[k] === 'number' && (d[k] < d.lo || d[k] > d.hi)) err(RG, `${at}/${k}`, 'ragdoll-limits', `${k} ${d[k]} is outside the limits ${d.lo} to ${d.hi}, so the spring would be clipped`, 'warning');
    });
    const dr = rag.drive;
    if (isObj(dr) && typeof dr.a0 === 'number' && typeof dr.a_max === 'number' && dr.a0 > dr.a_max) err(RG, '/drive/a0', 'ragdoll-limits', `a0 ${dr.a0} is above a_max ${dr.a_max}`);
    const rg = rag.regimes;
    if (isObj(rg)) for (const k of ['tuck_spin', 'brace_time']) if (Array.isArray(rg[k]) && rg[k].length === 2 && rg[k][0] > rg[k][1]) err(RG, `/regimes/${k}`, 'ragdoll-limits', `${k} runs from ${rg[k][0]} down to ${rg[k][1]}; it must rise`);
  }

  // ---- director launch: the drive angle and height orders, CRATER SLAM goes down ----
  const launch = get('data/director/launch.json');
  if (isObj(launch)) {
    const LF = 'data/director/launch.json';
    const d = launch.drive;
    if (isObj(d) && typeof d.lowDeg === 'number' && typeof d.highDeg === 'number' && d.lowDeg > d.highDeg) err(LF, '/drive/lowDeg', 'launch-order', `lowDeg ${d.lowDeg} is above highDeg ${d.highDeg}`);
    if (isObj(d) && typeof d.lowBh === 'number' && typeof d.highBh === 'number' && d.lowBh >= d.highBh) err(LF, '/drive/lowBh', 'launch-order', `lowBh ${d.lowBh} is not below highBh ${d.highBh}, so the angle has no range to rise over`);
    const up = launch.uppercut;
    if (isObj(up) && typeof up.uy === 'number' && up.uy <= 0) err(LF, '/uppercut/uy', 'launch-direction', `uppercut.uy ${up.uy} is not upward (positive is up), so UPPERCUT would not lift`);
    const kb = launch.knockBack;
    for (const key of ['distBh', 'skidSpeed']) if (isObj(kb) && Array.isArray(kb[key])) for (let i = 1; i < kb[key].length; i++) if (typeof kb[key][i] === 'number' && typeof kb[key][i - 1] === 'number' && kb[key][i] < kb[key][i - 1]) err(LF, `/knockBack/${key}/${i}`, 'launch-order', `knockBack ${key} falls from ${kb[key][i - 1]} to ${kb[key][i]} at tier ${i + 1}; it must not fall with the tier`, 'warning');
    const stw = isObj(launch.setup) && isObj(launch.setup.weight) ? launch.setup.weight : undefined;
    if (stw) for (const k of Object.keys(stw)) if (!k.startsWith('_') && !['default', 'blurPlain', 'barragePlain', 'launch', 'clash', 'guard_break', 'interrupt', 'knockback', 'beam', 'beam_clash', 'blast', 'barrage'].includes(k)) err(LF, `/setup/weight/${esc(k)}`, 'launch-setup', `weight "${k}" is not a decisive kind (launch, clash, guard_break, interrupt, knockback, beam, beam_clash, blast, barrage), default, blurPlain or barragePlain, so it would never be read`, 'warning');
    const cs = launch.craterSlam;
    if (isObj(cs) && typeof cs.uy === 'number' && cs.uy >= 0) err(LF, '/craterSlam/uy', 'launch-direction', `uy ${cs.uy} is not downward (negative is down), so CRATER SLAM would not slam`, 'warning');
  }

  // ---- fight pause: the gather ends before the pause does, and it matches the figure's gather beat ----
  const pzg = get('data/fight/pause.json');
  const fmg = get('data/anim/forms.json');
  if (isObj(pzg)) {
    for (const g of ['full', 'short', 'live']) {
      const o = pzg[g];
      if (!isObj(o) || typeof o.gatherTicks !== 'number') continue;
      if (typeof o.lengthS === 'number' && o.gatherTicks >= Math.round(o.lengthS * 60)) err('data/fight/pause.json', `/${g}/gatherTicks`, 'pause-gather', `${g} gatherTicks ${o.gatherTicks} is not under the length ${Math.round(o.lengthS * 60)} ticks, so the tier-up would land after the pause`);
      const fg = isObj(fmg) && isObj(fmg.versions) && isObj(fmg.versions[g]) ? fmg.versions[g].gather : undefined;
      if (typeof fg === 'number' && fg !== o.gatherTicks) err('data/fight/pause.json', `/${g}/gatherTicks`, 'pause-gather', `${g} gatherTicks ${o.gatherTicks} differs from the gather beat ${fg} in data/anim/forms.json; the tier-up would not land on the break`, 'warning');
    }
  }

  // ---- anim ragdoll motion: arrays follow ragdoll.json, fighters name shapes ----
  const motion = get('data/anim/ragdoll_motion.json');
  const rgd = get('data/anim/ragdoll.json');
  if (isObj(motion)) {
    const MO = 'data/anim/ragdoll_motion.json';
    const dofs = isObj(rgd) && Array.isArray(rgd.dofs) ? rgd.dofs.filter(isObj) : [];
    const n = dofs.length;
    const len = (arr, pointer, what) => { if (n && Array.isArray(arr) && arr.length !== n) err(MO, pointer, 'ragdoll-motion-dofs', `${what} has ${arr.length} numbers but ragdoll.json has ${n} dofs`); };
    if (isObj(motion.shapes)) for (const [sk, sh] of Object.entries(motion.shapes)) {
      if (sk.startsWith('_') || !isObj(sh)) continue;
      for (const set of ['tuck', 'brace', 'skid', 'crumple']) {
        len(sh[set], `/shapes/${esc(sk)}/${set}`, `shape ${sk} ${set}`);
        if (n && Array.isArray(sh[set]) && sh[set].length === n) sh[set].forEach((a, i) => { const d = dofs[i]; if (typeof a === 'number' && typeof d.lo === 'number' && typeof d.hi === 'number' && (a < d.lo - 1e-9 || a > d.hi + 1e-9)) err(MO, `/shapes/${esc(sk)}/${set}/${i}`, 'ragdoll-motion-limits', `shape ${sk} ${set} for ${d.id} is ${a}, outside its limits ${d.lo} to ${d.hi}`, 'warning'); });
      }
    }
    if (isObj(motion.flail)) { len(motion.flail.amp, '/flail/amp', 'flail amp'); len(motion.flail.hz, '/flail/hz', 'flail hz'); }
    if (isObj(motion.fighters)) {
      for (const [fid, key] of Object.entries(motion.fighters)) {
        if (fid.startsWith('_')) continue;
        if (isObj(motion.shapes) && typeof key === 'string' && !(key in motion.shapes)) err(MO, `/fighters/${esc(fid)}`, 'ragdoll-motion-shape', `fighter "${fid}" uses shape "${key}", which is not in shapes (${Object.keys(motion.shapes).filter((k) => !k.startsWith('_')).join(', ')})`);
      }
    }
    const hd = isObj(motion.hit) && Array.isArray(motion.hit.dofs) ? motion.hit.dofs : undefined;
    if (hd && n) {
      if (hd.length !== n) err(MO, '/hit/dofs', 'ragdoll-motion-dofs', `hit.dofs has ${hd.length} entries but ragdoll.json has ${n} dofs`);
      hd.forEach((h, i) => { if (isObj(h) && i < n && h.id !== dofs[i].id) err(MO, `/hit/dofs/${i}/id`, 'ragdoll-motion-dofs', `hit dof ${i} is "${h.id}" but ragdoll.json dof ${i} is "${dofs[i].id}" (same order)`); });
    }
  }

  // ---- anim quality: each level switches off at least what the level above does ----
  const quality = get('data/anim/quality.json');
  if (isObj(quality) && isObj(quality.levels)) {
    const order = ['high', 'medium', 'low', 'minimal'];
    for (let i = 1; i < order.length; i++) {
      const above = quality.levels[order[i - 1]];
      const here = quality.levels[order[i]];
      if (!Array.isArray(above) || !Array.isArray(here)) continue;
      const missing = above.filter((l) => !here.includes(l));
      if (missing.length) err('data/anim/quality.json', `/levels/${order[i]}`, 'quality-order', `${order[i]} does not switch off ${missing.join(', ')}, which ${order[i - 1]} already does; a lower level must lose at least what the level above loses`);
    }
  }

  // ---- anim personality: a higher tier is calmer ----
  const pers = get('data/anim/personality.json');
  if (isObj(pers) && Array.isArray(pers.tiers)) {
    for (const [k, dir] of [['sway', -1], ['hz', -1], ['bounce', -1], ['breath_hz', -1], ['breath_amp', 1]]) {
      for (let i = 1; i < pers.tiers.length; i++) {
        const a = pers.tiers[i - 1]; const b = pers.tiers[i];
        if (isObj(a) && isObj(b) && typeof a[k] === 'number' && typeof b[k] === 'number' && (b[k] - a[k]) * dir < 0) err('data/anim/personality.json', `/tiers/${i}/${k}`, 'personality-tiers', `tier ${i + 1} ${k} ${b[k]} ${dir < 0 ? 'rises above' : 'falls below'} tier ${i} ${a[k]}; higher forms are calmer, slower and deeper`, 'warning');
      }
    }
  }

  // ---- anim winner: end keys are ragdoll shape keys ----
  const winner = get('data/anim/winner.json');
  const motionDoc = get('data/anim/ragdoll_motion.json');
  if (isObj(winner) && isObj(winner.end) && isObj(motionDoc) && isObj(motionDoc.shapes)) {
    const shapes = Object.keys(motionDoc.shapes).filter((k) => !k.startsWith('_'));
    for (const k of Object.keys(winner.end)) {
      if (k === 'default' || k.startsWith('_')) continue;
      if (!shapes.includes(k)) err('data/anim/winner.json', `/end/${esc(k)}`, 'winner-shape', `end names shape "${k}", which is not in ragdoll_motion.json shapes (${shapes.join(', ')})`);
    }
  }

  // ---- anim: moments, lint exceptions, effectors, sockets (poses and bones exist; Legal's stacking limit) ----
  const poseDoc = get('data/anim/poses.json');
  const poseSet = new Set(isObj(poseDoc) && isObj(poseDoc.poses) ? Object.keys(poseDoc.poses) : []);
  const boneDoc = get('data/anim/profiles.json');
  const boneSet = new Set(isObj(boneDoc) && isObj(boneDoc.bone_lag) ? Object.keys(boneDoc.bone_lag) : []);
  const moments = get('data/anim/moments.json');
  if (isObj(moments) && Array.isArray(moments.moments)) {
    const MM = 'data/anim/moments.json';
    const seenM = new Map();
    moments.moments.forEach((m, i) => {
      if (!isObj(m)) return;
      const at = `/moments/${i}`;
      if (typeof m.id === 'string') { if (seenM.has(m.id)) err(MM, `${at}/id`, 'moments-id', `moment id "${m.id}" is already used at /moments/${seenM.get(m.id)}`); else seenM.set(m.id, i); }
      if (poseSet.size && Array.isArray(m.poses)) m.poses.forEach((p, j) => { if (typeof p === 'string' && !poseSet.has(p)) err(MM, `${at}/poses/${j}`, 'moments-pose', `pose "${p}" is not in poses.json`); });
      const marks = isObj(m.marks) ? Object.keys(m.marks).filter((k) => !k.startsWith('_')).length : 0;
      if (marks > 2) err(MM, `${at}/marks`, 'moments-marks', `moment "${m.id}" shows ${marks} of the seven marks; Legal's rule allows at most two`);
      else if (marks === 2) err(MM, `${at}/marks`, 'moments-marks', `moment "${m.id}" is at two of the seven marks: no room left for another`, 'warning');
    });
  }
  const allow = get('data/anim/lint_allow.json');
  if (isObj(allow)) {
    const LA = 'data/anim/lint_allow.json';
    if (poseSet.size && Array.isArray(allow.pairs)) allow.pairs.forEach((p, i) => { if (Array.isArray(p)) for (const j of [0, 1]) if (typeof p[j] === 'string' && !poseSet.has(p[j])) err(LA, `/pairs/${i}/${j}`, 'lint-allow-pose', `pose "${p[j]}" is not in poses.json`); });
    if (poseSet.size && Array.isArray(allow.overlay)) allow.overlay.forEach((pre, i) => { if (typeof pre === 'string' && ![...poseSet].some((p) => p.startsWith(pre))) err(LA, `/overlay/${i}`, 'lint-allow-pose', `overlay prefix "${pre}" matches no pose in poses.json`, 'warning'); });
  }
  const eff = get('data/anim/effectors.json');
  if (isObj(eff) && isObj(eff.poses) && poseSet.size) for (const p of Object.keys(eff.poses)) if (!p.startsWith('_') && !poseSet.has(p)) err('data/anim/effectors.json', `/poses/${esc(p)}`, 'effector-pose', `pose "${p}" is not in poses.json`);
  const sockets = get('data/anim/sockets.json');
  if (isObj(sockets)) {
    const SK = 'data/anim/sockets.json';
    const hasBone = (b) => boneSet.has(b) || boneSet.has(b + '_l') || boneSet.has(b + '_r');
    const needBone = (b, pointer) => { if (boneSet.size && typeof b === 'string' && !hasBone(b)) err(SK, pointer, 'sockets-bone', `bone "${b}" is not in profiles.json bone_lag (nor with an _l or _r suffix)`); };
    if (isObj(sockets.regions)) for (const [k, r] of Object.entries(sockets.regions)) if (!k.startsWith('_') && isObj(r)) needBone(r.bone, `/regions/${esc(k)}/bone`);
    if (isObj(sockets.limbs)) for (const [k, l] of Object.entries(sockets.limbs)) {
      if (k.startsWith('_') || !isObj(l)) continue;
      const at = `/limbs/${esc(k)}`;
      if (Array.isArray(l.chain)) l.chain.forEach((b, i) => needBone(b, `${at}/chain/${i}`));
      needBone(l.bone, `${at}/bone`); needBone(l.tip, `${at}/tip`);
      if (typeof l.lunge_max === 'number' && typeof l.step_max === 'number' && l.lunge_max > l.step_max) err(SK, `${at}/lunge_max`, 'sockets-reach', `lunge_max ${l.lunge_max} is above step_max ${l.step_max}; the hips carry the reach first, then the whole body`);
    }
    const ks = get('data/anim/keysets.json');
    if (isObj(ks) && isObj(ks.keysets)) {
      const regs = isObj(sockets.regions) ? Object.keys(sockets.regions).filter((k) => !k.startsWith('_')) : [];
      const lims = isObj(sockets.limbs) ? Object.keys(sockets.limbs).filter((k) => !k.startsWith('_')) : [];
      for (const [name, k] of Object.entries(ks.keysets)) {
        if (name.startsWith('_') || !isObj(k)) continue;
        if (typeof k.target === 'string' && regs.length && !regs.includes(k.target)) err('data/anim/keysets.json', `/keysets/${esc(name)}/target`, 'anim-target', `target "${k.target}" is not a region in sockets.json (${regs.join(', ')})`);
        if (typeof k.limb === 'string' && lims.length && !lims.includes(k.limb.replace(/_[lr]$/, ''))) err('data/anim/keysets.json', `/keysets/${esc(name)}/limb`, 'anim-limb', `limb "${k.limb}" is not a limb in sockets.json (${lims.join(', ')}, with a side suffix)`);
      }
    }
  }

  // ---- anim shapes: keys are ragdoll shape keys ----
  const shp = get('data/anim/shapes.json');
  const mot = get('data/anim/ragdoll_motion.json');
  if (isObj(shp) && isObj(shp.shapes) && isObj(mot) && isObj(mot.shapes)) {
    const have = Object.keys(mot.shapes).filter((k) => !k.startsWith('_'));
    for (const k of Object.keys(shp.shapes)) if (!k.startsWith('_') && !have.includes(k)) err('data/anim/shapes.json', `/shapes/${esc(k)}`, 'shapes-key', `shape "${k}" is not in ragdoll_motion.json shapes (${have.join(', ')})`);
    for (const k of have) if (!(k in shp.shapes)) err('data/anim/shapes.json', '/shapes', 'shapes-key', `ragdoll_motion.json has shape "${k}" but shapes.json has no idle and hit tuning for it`, 'warning');
  }

  // ---- anim waves (parked): key sets, poses and the manifest agree with each other and with sockets.json ----
  {
    const sockWave = get('data/anim/sockets.json');
    const regs = isObj(sockWave) && isObj(sockWave.regions) ? Object.keys(sockWave.regions).filter((k) => !k.startsWith('_')) : [];
    const lims = isObj(sockWave) && isObj(sockWave.limbs) ? Object.keys(sockWave.limbs).filter((k) => !k.startsWith('_')) : [];
    const waves = new Map();
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.(poses|keysets|manifest)\.json$/)) {
      const m = /^data\/anim\/waves\/([^/.]+)\.(poses|keysets|manifest)\.json$/.exec(rel);
      if (!m) continue;
      if (!waves.has(m[1])) waves.set(m[1], {});
      waves.get(m[1])[m[2]] = rel;
    }
    for (const [wname, w] of waves) {
      const pd = w.poses ? get(w.poses) : undefined;
      const poseSet = new Set(isObj(pd) && isObj(pd.poses) ? Object.keys(pd.poses) : []);
      const kd = w.keysets ? get(w.keysets) : undefined;
      const sets = isObj(kd) && isObj(kd.keysets) ? kd.keysets : {};
      const side = (l) => l.replace(/_[lr]$/, '');
      if (isObj(kd) && isObj(kd.keysets)) for (const [name, k] of Object.entries(kd.keysets)) {
        if (name.startsWith('_') || !isObj(k)) continue;
        const at = `/keysets/${esc(name)}`;
        const roles = new Set();
        (Array.isArray(k.keys) ? k.keys : []).forEach((key, i) => {
          if (!isObj(key)) return;
          if (poseSet.size && typeof key.pose === 'string' && !poseSet.has(key.pose)) err(w.keysets, `${at}/keys/${i}/pose`, 'wave-pose', `pose "${key.pose}" is not in ${w.poses}`);
          if (roles.has(key.role)) err(w.keysets, `${at}/keys/${i}/role`, 'wave-pose', `role "${key.role}" appears twice in key set "${name}"`); else roles.add(key.role);
        });
        if (typeof k.target === 'string' && regs.length && !regs.includes(k.target)) err(w.keysets, `${at}/target`, 'anim-target', `target "${k.target}" is not a region in sockets.json (${regs.join(', ')})`);
        for (const lk of ['limb', 'limb2']) if (typeof k[lk] === 'string' && lims.length && !lims.includes(side(k[lk]))) err(w.keysets, `${at}/${lk}`, 'anim-limb', `${lk} "${k[lk]}" is not a limb in sockets.json (${lims.join(', ')}, with a side suffix)`);
      }
      const md = w.manifest ? get(w.manifest) : undefined;
      if (isObj(md) && Array.isArray(md.strikes)) {
        const seen = new Map();
        md.strikes.forEach((s, i) => {
          if (!isObj(s)) return;
          const at = `/strikes/${i}`;
          if (typeof s.id === 'string') { if (seen.has(s.id)) err(w.manifest, `${at}/id`, 'wave-manifest', `strike id "${s.id}" is already used at /strikes/${seen.get(s.id)}`); else seen.set(s.id, i); }
          if (md.wave !== undefined && md.wave !== wname) err(w.manifest, '/wave', 'wave-manifest', `wave "${md.wave}" does not match the file name "${wname}"`);
          if (w.keysets && isObj(kd)) {
            const k = sets[s.id];
            if (!isObj(k)) err(w.manifest, `${at}/id`, 'wave-keyset', `strike "${s.id}" is not a key set in ${w.keysets}`);
            else {
              for (const f2 of ['limb', 'target', 'weight']) if (s[f2] !== undefined && k[f2] !== undefined && s[f2] !== k[f2]) err(w.manifest, `${at}/${f2}`, 'wave-manifest', `${f2} "${s[f2]}" differs from the key set\'s "${k[f2]}"`);
              if ((s.limb2 || undefined) !== (k.limb2 || undefined)) err(w.manifest, `${at}/limb2`, 'wave-manifest', `limb2 "${s.limb2}" differs from the key set\'s "${k.limb2}"`);
            }
          }
          if (poseSet.size && Array.isArray(s.poses)) s.poses.forEach((p, j) => { if (typeof p === 'string' && !poseSet.has(p)) err(w.manifest, `${at}/poses/${j}`, 'wave-pose', `pose "${p}" is not in ${w.poses}`); });
          if (typeof s.offset === 'number' && typeof s.reach === 'number' && s.offset > s.reach) err(w.manifest, `${at}/offset`, 'wave-reach', `offset ${s.offset} is above reach ${s.reach}`);
        });
      }
    }
  }

  // ---- anim waves (parked): entries, their map and the wave's poses agree ----
  {
    const waves2 = new Map();
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.(poses|entries|entrymap)\.json$/)) {
      const m = /^data\/anim\/waves\/([^/.]+)\.(poses|entries|entrymap)\.json$/.exec(rel);
      if (!m) continue;
      if (!waves2.has(m[1])) waves2.set(m[1], {});
      waves2.get(m[1])[m[2]] = rel;
    }
    for (const [wname, w] of waves2) {
      const pd = w.poses ? get(w.poses) : undefined;
      const poseSet = new Set(isObj(pd) && isObj(pd.poses) ? Object.keys(pd.poses) : []);
      const ed = w.entries ? get(w.entries) : undefined;
      const entries = isObj(ed) && isObj(ed.entries) ? ed.entries : {};
      if (w.entries && isObj(ed.entries)) for (const [name, e] of Object.entries(entries)) {
        if (name.startsWith('_') || !isObj(e)) continue;
        (Array.isArray(e.phases) ? e.phases : []).forEach((p, i) => { if (isObj(p) && poseSet.size && typeof p.pose === 'string' && !poseSet.has(p.pose)) err(w.entries, `/entries/${esc(name)}/phases/${i}/pose`, 'wave-pose', `pose "${p.pose}" is not in ${w.poses}`); });
      }
      const md = w.entrymap ? get(w.entrymap) : undefined;
      if (isObj(md) && Array.isArray(md.entries)) {
        const seen = new Map();
        if (md.wave !== undefined && md.wave !== wname) err(w.entrymap, '/wave', 'wave-entry', `wave "${md.wave}" does not match the file name "${wname}"`);
        md.entries.forEach((r, i) => {
          if (!isObj(r)) return;
          const at = `/entries/${i}`;
          if (typeof r.id === 'string') { if (seen.has(r.id)) err(w.entrymap, `${at}/id`, 'wave-entry', `entry id "${r.id}" is already used at /entries/${seen.get(r.id)}`); else seen.set(r.id, i); }
          if (Array.isArray(r.poses) && poseSet.size) r.poses.forEach((p, j) => { if (typeof p === 'string' && !poseSet.has(p)) err(w.entrymap, `${at}/poses/${j}`, 'wave-pose', `pose "${p}" is not in ${w.poses}`); });
          if (Array.isArray(r.poses) && Array.isArray(r.phases) && r.poses.length !== r.phases.length) err(w.entrymap, `${at}/phases`, 'wave-entry', `${r.phases.length} phase names for ${r.poses.length} poses`);
          if (!w.entries || !isObj(ed) || !isObj(ed.entries)) return;
          const e = entries[r.id];
          if (!isObj(e)) { err(w.entrymap, `${at}/id`, 'wave-entry', `entry "${r.id}" is not in ${w.entries}`); return; }
          for (const f2 of ['direction', 'ground', 'path']) if (r[f2] !== undefined && e[f2] !== undefined && r[f2] !== e[f2]) err(w.entrymap, `${at}/${f2}`, 'wave-entry', `${f2} "${r[f2]}" differs from the entry\'s "${e[f2]}"`);
          const ep = (Array.isArray(e.phases) ? e.phases : []).map((p) => (isObj(p) ? p.pose : undefined));
          if (Array.isArray(r.poses) && (r.poses.length !== ep.length || r.poses.some((p, j) => p !== ep[j]))) err(w.entrymap, `${at}/poses`, 'wave-entry', `poses differ from the entry\'s phases in ${w.entries}`);
          if (isObj(r.ticks) && r.ticks.travel === 'c' && Array.isArray(e.phases) && Array.isArray(r.phases)) for (const ph of ['start', 'arrive']) { const j = r.phases.indexOf(ph); const p = j >= 0 ? e.phases[j] : undefined; if (isObj(p) && typeof p.ticks === 'number' && typeof r.ticks[ph] === 'number' && p.ticks !== r.ticks[ph]) err(w.entrymap, `${at}/ticks/${ph}`, 'wave-entry', `${ph} is ${r.ticks[ph]} ticks here but ${p.ticks} in the entry\'s phase`); }
        });
        if (w.entries && isObj(ed) && isObj(ed.entries)) for (const name of Object.keys(entries)) if (!name.startsWith('_') && !name.includes('~') && !md.entries.some((r) => isObj(r) && r.id === name)) err(w.entries, `/entries/${esc(name)}`, 'wave-entry', `entry "${name}" has no row in ${w.entrymap}`, 'warning');
      }
    }
  }

  // ---- director ai: the level exists, the levels get harder, the old beamAnswer is the medium level's ----
  const dai = get('data/director/ai.json');
  if (isObj(dai)) {
    const AI = 'data/director/ai.json';
    const lv = isObj(dai.levels) ? dai.levels : {};
    if (typeof dai.level === 'string' && isObj(dai.levels) && !(dai.level in lv)) err(AI, '/level', 'ai-level', `level "${dai.level}" is not in levels (${Object.keys(lv).filter((k) => !k.startsWith('_')).join(', ')})`);
    const order = ['easy', 'medium', 'hard'];
    for (const key of ['beamAnswer', 'perfectBlockMul', 'punish', 'breakGuard', 'guardRepeat', 'launchIntent', 'heldHeavy', 'earnerUse', 'buriedFollowUp', 'barrageGuard', 'beamDodge', 'beamWade', 'beamLate']) {
      for (let i = 1; i < order.length; i++) {
        const a = isObj(lv[order[i - 1]]) ? lv[order[i - 1]][key] : undefined; const b = isObj(lv[order[i]]) ? lv[order[i]][key] : undefined;
        if (typeof a === 'number' && typeof b === 'number' && b < a) err(AI, `/levels/${order[i]}/${key}`, 'ai-levels-order', `${order[i]} ${key} ${b} is below ${order[i - 1]} ${a}; a harder level should not play worse`, 'warning');
      }
    }
    for (const name of order) { const ar = isObj(lv[name]) ? lv[name].approachReact : undefined; if (Array.isArray(ar) && ar.every((x) => typeof x === 'number') && ar.reduce((s2, x) => s2 + x, 0) > 1 + 1e-9) err(AI, `/levels/${name}/approachReact`, 'ai-approach-react', `the three chances sum to ${ar.reduce((s2, x) => s2 + x, 0).toFixed(3)}, more than 1`); }
    if (isObj(dai.beamLook) && Object.entries(dai.beamLook).filter(([k]) => !k.startsWith('_')).every(([, v]) => typeof v === 'number') && Object.entries(dai.beamLook).filter(([k]) => !k.startsWith('_')).reduce((s2, [, v]) => s2 + v, 0) <= 0) err(AI, '/beamLook', 'ai-beam-look', 'the three weights of beamLook sum to 0, so a perfect block against a beam has no look to draw');
    const med = isObj(lv.medium) ? lv.medium.beamAnswer : undefined;
    if (typeof dai.beamAnswer === 'number' && typeof med === 'number' && dai.beamAnswer !== med) err(AI, '/beamAnswer', 'ai-level-beam', `beamAnswer ${dai.beamAnswer} differs from the medium level's ${med} (it is kept for readers of the old shape)`, 'warning');
  }

  // ---- director interrupts: orders and the windows against the wind-ups ----
  const itr = get('data/director/interrupts.json');
  if (isObj(itr)) {
    const IT = 'data/director/interrupts.json';
    const pb = isObj(itr.perfectBlock) ? itr.perfectBlock : {};
    const w = isObj(pb.windows) ? pb.windows : {};
    for (const cls of ['opener', 'blast']) if (isObj(w[cls]) && typeof w[cls].light === 'number' && typeof w[cls].heavy === 'number' && w[cls].light > w[cls].heavy) err(IT, `/perfectBlock/windows/${cls}/light`, 'interrupts-order', `${cls} light window ${w[cls].light} is longer than its heavy window ${w[cls].heavy}`);
    if (typeof pb.oneArmedOff === 'number') {
      const all = [['opener/light', isObj(w.opener) ? w.opener.light : undefined], ['opener/heavy', isObj(w.opener) ? w.opener.heavy : undefined], ['heavy', w.heavy], ['ender', w.ender], ['blast/light', isObj(w.blast) ? w.blast.light : undefined], ['blast/heavy', isObj(w.blast) ? w.blast.heavy : undefined], ['return', w.return], ['beam', w.beam]];
      for (const [name, v] of all) if (typeof v === 'number' && v > 0 && v <= pb.oneArmedOff) err(IT, `/perfectBlock/oneArmedOff`, 'interrupts-order', `oneArmedOff ${pb.oneArmedOff} leaves no window for ${name} (${v} ticks)`);
    }
    const bpl = itr.beamPlays;
    if (isObj(bpl)) {
      if (isObj(bpl.walk) && typeof bpl.walk.minTicks === 'number' && typeof bpl.walk.maxTicks === 'number' && bpl.walk.minTicks > bpl.walk.maxTicks) err(IT, '/beamPlays/walk/minTicks', 'beamplays-order', `walk minTicks ${bpl.walk.minTicks} is above maxTicks ${bpl.walk.maxTicks}`);
      if (isObj(bpl.split)) for (const k of ['widthMul', 'powerMul']) if (typeof bpl.split[k] === 'number' && bpl.split[k] > 1) err(IT, `/beamPlays/split/${k}`, 'beamplays-split', `the split beams' ${k} ${bpl.split[k]} is above 1; they are meant to be lesser than the beam`, 'warning');
    }
    const dcI = itr.dodgeCancel;
    if (isObj(dcI) && typeof dcI.freeGapTicks === 'number' && typeof dcI.cooldownTicks === 'number' && dcI.freeGapTicks > dcI.cooldownTicks) err(IT, '/dodgeCancel/freeGapTicks', 'interrupts-order', `freeGapTicks ${dcI.freeGapTicks} is longer than cooldownTicks ${dcI.cooldownTicks}, so the free cancel would cost more than a paid one`, 'warning');
    const bd = itr.bands;
    if (isObj(bd)) {
      if (typeof bd.closeBh === 'number' && typeof bd.midBh === 'number' && bd.closeBh >= bd.midBh) err(IT, '/bands/closeBh', 'bands-order', `closeBh ${bd.closeBh} is not below midBh ${bd.midBh}, so there would be no mid band`);
      if (isObj(bd.charge) && isObj(bd.charge.light) && isObj(bd.charge.heavy) && typeof bd.charge.light.holdTicks === 'number' && typeof bd.charge.heavy.holdTicks === 'number' && bd.charge.light.holdTicks >= bd.charge.heavy.holdTicks) err(IT, '/bands/charge/light/holdTicks', 'bands-order', `the light charge's holdTicks ${bd.charge.light.holdTicks} is not below the heavy's ${bd.charge.heavy.holdTicks}`);
      if (typeof bd.engageBh === 'number' && typeof bd.closeBh === 'number' && bd.engageBh > bd.closeBh) err(IT, '/bands/engageBh', 'bands-order', `engageBh ${bd.engageBh} is above closeBh ${bd.closeBh}, so an approach would end outside the close band`);
      for (const [path, o] of [['lunge', bd.lunge], ['far/light', isObj(bd.far) ? bd.far.light : undefined], ['far/heavy', isObj(bd.far) ? bd.far.heavy : undefined], ['charge/light', isObj(bd.charge) ? bd.charge.light : undefined], ['charge/heavy', isObj(bd.charge) ? bd.charge.heavy : undefined], ['meet', bd.meet]]) if (isObj(o) && typeof o.minTicks === 'number' && typeof o.maxTicks === 'number' && o.minTicks > o.maxTicks) err(IT, `/bands/${path}/minTicks`, 'bands-order', `minTicks ${o.minTicks} is above maxTicks ${o.maxTicks}`);
    }
    const bl2 = itr.blast;
    if (isObj(bl2)) {
      const shotsI = get('data/fight/shots.json');
      const kindsI = isObj(shotsI) && isObj(shotsI.kinds) ? shotsI.kinds : undefined;
      for (const w of ['light', 'heavy']) if (isObj(bl2[w]) && typeof bl2[w].kind === 'string' && kindsI && !(bl2[w].kind in kindsI)) err(IT, `/blast/${w}/kind`, 'blast-shot-kind', `${w} blast kind "${bl2[w].kind}" is not a kind of data/fight/shots.json (${Object.keys(kindsI).filter((k) => !k.startsWith('_')).join(', ')})`);
      if (isObj(bl2.heavy) && typeof bl2.heavy.holdMaxTicks === 'number' && typeof bl2.heavy.chargeTicks === 'number' && bl2.heavy.holdMaxTicks < bl2.heavy.chargeTicks) err(IT, '/blast/heavy/holdMaxTicks', 'interrupts-order', `holdMaxTicks ${bl2.heavy.holdMaxTicks} is below chargeTicks ${bl2.heavy.chargeTicks}, so the charge could never finish`);
      if (kindsI && isObj(bl2.light) && isObj(bl2.heavy) && isObj(kindsI[bl2.light.kind]) && isObj(kindsI[bl2.heavy.kind]) && typeof kindsI[bl2.light.kind].power === 'number' && typeof kindsI[bl2.heavy.kind].power === 'number' && kindsI[bl2.heavy.kind].power < kindsI[bl2.light.kind].power) err(IT, '/blast/heavy/kind', 'blast-shot-kind', `the heavy blast "${bl2.heavy.kind}" trades with less power (${kindsI[bl2.heavy.kind].power}) than the light "${bl2.light.kind}" (${kindsI[bl2.light.kind].power})`, 'warning');
    }
    const bu = itr.buried;
    const embedC = get('data/biomes/contact.json');
    if (isObj(bu) && isObj(embedC) && isObj(embedC.embed) && typeof embedC.embed.ticks === 'number') for (const k of ['guardFromTick', 'burstFromTick']) if (typeof bu[k] === 'number' && bu[k] > embedC.embed.ticks) err(IT, `/buried/${k}`, 'buried-order', `${k} ${bu[k]} is after the burial ends (embed.ticks ${embedC.embed.ticks} in data/biomes/contact.json), so it could never happen`);
    if (isObj(bu) && typeof bu.landByTick === 'number') for (const k of ['guardFromTick', 'burstFromTick']) if (typeof bu[k] === 'number' && bu[k] > bu.landByTick) err(IT, `/buried/${k}`, 'buried-order', `${k} ${bu[k]} is after landByTick ${bu.landByTick}`);
    const rv = itr.reversal;
    if (isObj(rv) && typeof rv.kiPatient === 'number' && typeof rv.ki === 'number' && rv.kiPatient > rv.ki) err(IT, '/reversal/kiPatient', 'interrupts-order', `kiPatient ${rv.kiPatient} is above ki ${rv.ki}; patience should be cheaper`);
    const st = itr.stale;
    if (isObj(st)) { if (typeof st.windupMax === 'number' && typeof st.windupPerRepeat === 'number' && st.windupMax < st.windupPerRepeat) err(IT, '/stale/windupMax', 'interrupts-order', `windupMax ${st.windupMax} is below one repeat's ${st.windupPerRepeat}`); if (typeof st.windowMax === 'number' && typeof st.windowPerRepeat === 'number' && st.windowMax < st.windowPerRepeat) err(IT, '/stale/windowMax', 'interrupts-order', `windowMax ${st.windowMax} is below one repeat's ${st.windowPerRepeat}`); }
    const tpl7 = get('data/combat/templates.json');
    const tmp = isObj(tpl7) && isObj(tpl7.profiles) && isObj(tpl7.profiles.dynamic) && isObj(tpl7.profiles.dynamic.tempo) ? tpl7.profiles.dynamic.tempo : undefined;
    if (tmp) {
      const pairs = [['/perfectBlock/windows/opener/light', isObj(w.opener) ? w.opener.light : undefined, 'windup'], ['/perfectBlock/windows/opener/heavy', isObj(w.opener) ? w.opener.heavy : undefined, 'heavyWindup'], ['/perfectBlock/windows/heavy', w.heavy, 'heavyWindup'], ['/perfectBlock/windows/ender', w.ender, 'enderWindup']];
      for (const [pointer, v, k] of pairs) if (typeof v === 'number' && typeof tmp[k] === 'number' && v > tmp[k]) err(IT, pointer, 'interrupts-window', `window ${v} ticks is longer than the ${k} ${tmp[k]} ticks it is the end of`, 'warning');
    }
  }

  // ---- biomes contact: orders and references ----
  const gc = get('data/biomes/contact.json');
  if (isObj(gc)) {
    const GC = 'data/biomes/contact.json';
    const b = isObj(gc.bands) ? gc.bands : {};
    if (typeof b.nothingBelow === 'number' && typeof b.tumbleBelow === 'number' && b.nothingBelow >= b.tumbleBelow) err(GC, '/bands/nothingBelow', 'contact-order', `nothingBelow ${b.nothingBelow} is not below tumbleBelow ${b.tumbleBelow}`);
    if (typeof b.skidSin2 === 'number' && typeof b.slamSin2 === 'number' && b.skidSin2 >= b.slamSin2) err(GC, '/bands/skidSin2', 'contact-order', `skidSin2 ${b.skidSin2} is not below slamSin2 ${b.slamSin2}`);
    if (typeof b.nothingBelow === 'number' && typeof b.tumbleBelow === 'number' && typeof b.skidToTumble === 'number' && (b.skidToTumble < b.nothingBelow || b.skidToTumble > b.tumbleBelow)) err(GC, '/bands/skidToTumble', 'contact-order', `skidToTumble ${b.skidToTumble} is outside nothingBelow ${b.nothingBelow} to tumbleBelow ${b.tumbleBelow}`, 'warning');
    const ar = isObj(gc.area) ? gc.area : {};
    if (typeof ar.slam === 'number' && typeof ar.touch === 'number' && ar.touch > ar.slam) err(GC, '/area/touch', 'contact-area', `touch ${ar.touch} is above slam ${ar.slam}; a slam should pay at least what a touch does`, 'warning');
    const vk = isObj(gc.bounce) ? gc.bounce.vertKeep : undefined;
    if (Array.isArray(vk)) for (let i = 1; i < vk.length; i++) if (typeof vk[i] === 'number' && typeof vk[i - 1] === 'number' && vk[i] > vk[i - 1]) err(GC, `/bounce/vertKeep/${i}`, 'contact-order', `bounce ${i + 1} keeps ${vk[i]}, more than bounce ${i} (${vk[i - 1]}); a body loses energy on each bounce`);
    const rising = (a, pointer, what) => { if (Array.isArray(a)) for (let i = 1; i < a.length; i++) if (typeof a[i] === 'number' && typeof a[i - 1] === 'number' && a[i] < a[i - 1]) err(GC, `${pointer}/${i}`, 'contact-order', `${what} falls from ${a[i - 1]} to ${a[i]} at tier ${i + 1}; it must not fall with the tier`, 'warning'); };
    rising(isObj(gc.bounce) ? gc.bounce.perTier : undefined, '/bounce/perTier', 'bounces per tier');
    rising(isObj(gc.spin) ? gc.spin.capTurns : undefined, '/spin/capTurns', 'spin cap');
    const surfaces = isObj(gc.surfaces) ? Object.keys(gc.surfaces).filter((k) => !k.startsWith('_')) : [];
    const bs = isObj(gc.biomeSurface) ? gc.biomeSurface : {};
    for (const [biome, s] of Object.entries(bs)) if (!biome.startsWith('_') && surfaces.length && typeof s === 'string' && !surfaces.includes(s)) err(GC, `/biomeSurface/${esc(biome)}`, 'contact-surface', `biome "${biome}" uses surface "${s}", which is not in surfaces (${surfaces.join(', ')})`);
    if (isObj(gc.paving) && Array.isArray(gc.paving.biomes)) gc.paving.biomes.forEach((bn, i) => { if (typeof bn === 'string' && !(bn in bs)) err(GC, `/paving/biomes/${i}`, 'contact-surface', `paving biome "${bn}" has no entry in biomeSurface`); });
  }

  // ---- anim waves (parked): the go-live lists name key sets of the wave ----
  for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.live\.json$/)) {
    const lv = get(rel);
    const wn = /^data\/anim\/waves\/([^/.]+)\.live\.json$/.exec(rel);
    if (!isObj(lv) || !wn) continue;
    const kdoc = get(`data/anim/waves/${wn[1]}.keysets.json`);
    const sets = isObj(kdoc) && isObj(kdoc.keysets) ? kdoc.keysets : undefined;
    const mot2 = get('data/anim/ragdoll_motion.json');
    if (Array.isArray(lv.shapes) && isObj(mot2) && isObj(mot2.shapes)) lv.shapes.forEach((s, i) => { if (typeof s === 'string' && !(s in mot2.shapes)) err(rel, `/shapes/${i}`, 'wave-live-shape', `shape "${s}" is not in ragdoll_motion.json shapes (${Object.keys(mot2.shapes).filter((k) => !k.startsWith('_')).join(', ')})`); });
    if (!sets) continue;
    const fits = (name, weight) => { const k = sets[name]; return isObj(k) && (k.weight === weight || k.weight === 'any'); };
    const gatedNames = new Set((Array.isArray(lv.gated) ? lv.gated : []).filter(isObj).map((g) => g.keyset));
    if (isObj(lv.picks)) for (const weight of ['light', 'heavy']) (Array.isArray(lv.picks[weight]) ? lv.picks[weight] : []).forEach((name, i) => {
      if (typeof name !== 'string') return;
      const at = `/picks/${weight}/${i}`;
      if (!(name in sets)) err(rel, at, 'wave-live-keyset', `key set "${name}" is not in data/anim/waves/${wn[1]}.keysets.json`);
      else if (!fits(name, weight)) err(rel, at, 'wave-live-weight', `key set "${name}" is ${sets[name].weight}, but it is in the ${weight} list`);
      if (gatedNames.has(name)) err(rel, at, 'wave-live-weight', `key set "${name}" is both picked and gated; a gated key set joins only while its gate is open`, 'warning');
    });
    (Array.isArray(lv.gated) ? lv.gated : []).forEach((g, i) => {
      if (!isObj(g)) return;
      if (typeof g.keyset === 'string' && !(g.keyset in sets)) err(rel, `/gated/${i}/keyset`, 'wave-live-keyset', `key set "${g.keyset}" is not in data/anim/waves/${wn[1]}.keysets.json`);
      else if (typeof g.keyset === 'string' && typeof g.weight === 'string' && !fits(g.keyset, g.weight)) err(rel, `/gated/${i}/weight`, 'wave-live-weight', `key set "${g.keyset}" is ${sets[g.keyset].weight}, but it is gated into the ${g.weight} list`);
    });
  }

  // ---- anim waves (parked): sequences, cues and their map agree ----
  {
    const waves3 = new Map();
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.(poses|sequences|cues|seqmap)\.json$/)) {
      const m = /^data\/anim\/waves\/([^/.]+)\.(poses|sequences|cues|seqmap)\.json$/.exec(rel);
      if (!m) continue;
      if (!waves3.has(m[1])) waves3.set(m[1], {});
      waves3.get(m[1])[m[2]] = rel;
    }
    for (const [wname, w] of waves3) {
      const pd = w.poses ? get(w.poses) : undefined;
      const poseSet = new Set(isObj(pd) && isObj(pd.poses) ? Object.keys(pd.poses) : []);
      const sd = w.sequences ? get(w.sequences) : undefined;
      const seqs = isObj(sd) && isObj(sd.sequences) ? sd.sequences : undefined;
      if (seqs) for (const [name, s] of Object.entries(seqs)) {
        if (name.startsWith('_') || !isObj(s)) continue;
        const at = `/sequences/${esc(name)}`;
        const phases = Array.isArray(s.phases) ? s.phases : [];
        phases.forEach((p, i) => { if (isObj(p) && poseSet.size && typeof p.pose === 'string' && !poseSet.has(p.pose)) err(w.sequences, `${at}/phases/${i}/pose`, 'wave-pose', `pose "${p.pose}" is not in ${w.poses}`); });
        const fixed = phases.reduce((a, p) => a + (isObj(p) && typeof p.ticks === 'number' ? p.ticks : 0), 0);
        if (typeof s.dur === 'number' && fixed > s.dur) err(w.sequences, `${at}/dur`, 'wave-seq-dur', `the phases' fixed ticks add up to ${fixed}, more than dur ${s.dur}`);
      }
      const cd = w.cues ? get(w.cues) : undefined;
      if (seqs && isObj(cd) && isObj(cd.cues)) for (const [kind, c] of Object.entries(cd.cues)) {
        if (kind.startsWith('_') || !isObj(c)) continue;
        for (const [slot, id] of Object.entries(c)) if (!slot.startsWith('_') && typeof id === 'string' && !(id in seqs)) err(w.cues, `/cues/${esc(kind)}/${esc(slot)}`, 'wave-cue-seq', `sequence "${id}" is not in ${w.sequences}`);
      }
      const md = w.seqmap ? get(w.seqmap) : undefined;
      if (isObj(md)) {
        if (md.wave !== undefined && md.wave !== wname) err(w.seqmap, '/wave', 'wave-seq-map', `wave "${md.wave}" does not match the file name "${wname}"`);
        if (isObj(cd) && isObj(md.cues) && JSON.stringify(md.cues) !== JSON.stringify(cd.cues)) err(w.seqmap, '/cues', 'wave-seq-map', `the cues differ from ${w.cues}`);
        const seen = new Map();
        (Array.isArray(md.sequences) ? md.sequences : []).forEach((r, i) => {
          if (!isObj(r)) return;
          const at = `/sequences/${i}`;
          if (typeof r.id === 'string') { if (seen.has(r.id)) err(w.seqmap, `${at}/id`, 'wave-seq-map', `sequence id "${r.id}" is already used at /sequences/${seen.get(r.id)}`); else seen.set(r.id, i); }
          if (Array.isArray(r.poses) && poseSet.size) r.poses.forEach((p, j) => { if (typeof p === 'string' && !poseSet.has(p)) err(w.seqmap, `${at}/poses/${j}`, 'wave-pose', `pose "${p}" is not in ${w.poses}`); });
          if (Array.isArray(r.poses) && Array.isArray(r.phases) && (r.poses.length !== r.phases.length || r.poses.some((p, j) => typeof p === 'string' && p.split('.').pop() !== r.phases[j]))) err(w.seqmap, `${at}/phases`, 'wave-seq-map', 'the phase names do not match the last part of each pose id');
          if (!seqs) return;
          const s = seqs[r.id];
          if (!isObj(s)) { err(w.seqmap, `${at}/id`, 'wave-seq-map', `sequence "${r.id}" is not in ${w.sequences}`); return; }
          if (typeof r.dur === 'number' && typeof s.dur === 'number' && r.dur !== s.dur) err(w.seqmap, `${at}/dur`, 'wave-seq-map', `dur ${r.dur} differs from the sequence's ${s.dur}`);
          const sp = (Array.isArray(s.phases) ? s.phases : []).map((p) => (isObj(p) ? p.pose : undefined));
          if (Array.isArray(r.poses) && (r.poses.length !== sp.length || r.poses.some((p, j) => p !== sp[j]))) err(w.seqmap, `${at}/poses`, 'wave-seq-map', `poses differ from the sequence's phases in ${w.sequences}`);
        });
        if (seqs) for (const name of Object.keys(seqs)) if (!name.startsWith('_') && !name.includes('~') && !(Array.isArray(md.sequences) && md.sequences.some((r) => isObj(r) && r.id === name))) err(w.sequences, `/sequences/${esc(name)}`, 'wave-seq-map', `sequence "${name}" has no row in ${w.seqmap}`, 'warning');
      }
    }
  }

  // ---- anim ground: a multiplier for every surface World knows, and the order of them ----
  const gnd = get('data/anim/ground.json');
  const gct = get('data/biomes/contact.json');
  if (isObj(gnd) && isObj(gnd.surface)) {
    const GD = 'data/anim/ground.json';
    if (isObj(gct) && isObj(gct.surfaces)) {
      const known = Object.keys(gct.surfaces).filter((k) => !k.startsWith('_'));
      for (const k of known) if (!(k in gnd.surface)) err(GD, '/surface', 'ground-surface', `surface "${k}" of data/biomes/contact.json has no multiplier`);
      for (const k of Object.keys(gnd.surface)) if (!k.startsWith('_') && k !== 'water' && !known.includes(k)) err(GD, `/surface/${esc(k)}`, 'ground-surface', `surface "${k}" is not one of contact.json surfaces (${known.join(', ')}) nor water`);
    }
    const hd = gnd.hold;
    if (isObj(hd) && typeof hd.slow_speed === 'number' && typeof hd.fast_speed === 'number' && hd.slow_speed >= hd.fast_speed) err('data/anim/ground.json', '/hold/slow_speed', 'ground-hold', `slow_speed ${hd.slow_speed} is not below fast_speed ${hd.fast_speed}`);
    if (isObj(hd) && typeof hd.slow_k === 'number' && typeof hd.fast_k === 'number' && hd.slow_k < hd.fast_k) err('data/anim/ground.json', '/hold/slow_k', 'ground-hold', `slow_k ${hd.slow_k} is below fast_k ${hd.fast_k}; the brace should be firmer at low speed`, 'warning');
    const s = gnd.surface;
    if (typeof s.soil === 'number') {
      for (const k of ['paving', 'rock']) if (typeof s[k] === 'number' && s[k] < s.soil) err(GD, `/surface/${k}`, 'ground-order', `${k} ${s[k]} is below soil ${s.soil}; hard ground should be livelier than soil`, 'warning');
      for (const k of ['sand', 'rubble']) if (typeof s[k] === 'number' && s[k] > s.soil) err(GD, `/surface/${k}`, 'ground-order', `${k} ${s[k]} is above soil ${s.soil}; soft ground should be deader than soil`, 'warning');
    }
  }

  // ---- anim intro: beats name shapes and sequences that exist ----
  const intro = get('data/anim/intro.json');
  if (isObj(intro) && isObj(intro.beats)) {
    const IN = 'data/anim/intro.json';
    const motI = get('data/anim/ragdoll_motion.json');
    const seqI = get('data/anim/waves/intro1.sequences.json');
    const shapesI = isObj(motI) && isObj(motI.shapes) ? Object.keys(motI.shapes).filter((k) => !k.startsWith('_')) : [];
    const seqsI = isObj(seqI) && isObj(seqI.sequences) ? seqI.sequences : undefined;
    for (const [k, b] of Object.entries(intro.beats)) {
      if (k.startsWith('_') || !isObj(b)) continue;
      if (shapesI.length && !shapesI.includes(k)) err(IN, `/beats/${esc(k)}`, 'intro-shape', `beat shape "${k}" is not in ragdoll_motion.json shapes (${shapesI.join(', ')})`);
      if (seqsI && typeof b.seq === 'string' && !(b.seq in seqsI)) err(IN, `/beats/${esc(k)}/seq`, 'intro-seq', `sequence "${b.seq}" is not in data/anim/waves/intro1.sequences.json`);
    }
  }

  // ---- fight intro: the timeline runs in order; the animation's opening fits its staredown ----
  const fint = get('data/fight/intro.json');
  if (isObj(fint) && isObj(fint.ticks)) {
    const IT2 = 'data/fight/intro.json';
    const k = fint.ticks;
    const lt = (a, b, strict) => { if (typeof k[a] === 'number' && typeof k[b] === 'number' && (strict ? k[a] >= k[b] : k[a] > k[b])) err(IT2, `/ticks/${a}`, 'intro-order', `${a} ${k[a]} must be ${strict ? 'before' : 'at most'} ${b} ${k[b]}`); };
    lt('fallA', 'landA', true); lt('fallB', 'landB', true); lt('landA', 'landB', false); lt('landB', 'staredown', false); lt('staredown', 'clock', true); lt('skipFrom', 'clock', true);
    const aint = get('data/anim/intro.json');
    if (isObj(aint) && typeof k.staredown === 'number' && typeof k.clock === 'number') {
      const len = (k.clock - k.staredown) / 60;
      if (typeof aint.tense_lead === 'number' && aint.tense_lead > len) err('data/anim/intro.json', '/tense_lead', 'intro-staredown', `tense_lead ${aint.tense_lead} s is longer than the ${len.toFixed(2)} s staredown (data/fight/intro.json)`, 'warning');
      const seqs = get('data/anim/waves/intro1.sequences.json');
      if (isObj(aint.beats)) for (const [shape, b] of Object.entries(aint.beats)) {
        if (shape.startsWith('_') || !isObj(b) || typeof b.at !== 'number') continue;
        const dur = isObj(seqs) && isObj(seqs.sequences) && isObj(seqs.sequences[b.seq]) && typeof seqs.sequences[b.seq].dur === 'number' ? seqs.sequences[b.seq].dur / 60 : 0;
        if (b.at + dur > len) err('data/anim/intro.json', `/beats/${esc(shape)}/at`, 'intro-staredown', `beat "${b.seq}" for ${shape} ends at ${(b.at + dur).toFixed(2)} s, after the ${len.toFixed(2)} s staredown`, 'warning');
      }
    }
  }

  // ---- anim last stand: ready keys are shapes, sequences exist ----
  const lsd = get('data/anim/laststand.json');
  if (isObj(lsd) && isObj(lsd.ready)) {
    const LS = 'data/anim/laststand.json';
    const motL = get('data/anim/ragdoll_motion.json');
    const seqL = get('data/anim/waves/laststand1.sequences.json');
    const shapesL = isObj(motL) && isObj(motL.shapes) ? Object.keys(motL.shapes).filter((k) => !k.startsWith('_')) : [];
    const seqsL = isObj(seqL) && isObj(seqL.sequences) ? seqL.sequences : undefined;
    for (const [k, id] of Object.entries(lsd.ready)) {
      if (k.startsWith('_')) continue;
      if (k !== 'default' && shapesL.length && !shapesL.includes(k)) err(LS, `/ready/${esc(k)}`, 'laststand-shape', `ready key "${k}" is not default nor a shape in ragdoll_motion.json shapes (${shapesL.join(', ')})`);
      if (seqsL && typeof id === 'string' && !(id in seqsL)) err(LS, `/ready/${esc(k)}`, 'laststand-seq', `sequence "${id}" is not in data/anim/waves/laststand1.sequences.json`);
    }
    if (seqsL && !('ls.slump' in seqsL)) err(LS, '/ready', 'laststand-seq', 'the expired end plays ls.slump, which is not in data/anim/waves/laststand1.sequences.json');
  }

  // ---- anim joints: bones exist and are in one joint, the orders, the shape scales ----
  const jts = get('data/anim/joints.json');
  if (isObj(jts)) {
    const JT = 'data/anim/joints.json';
    const prJ = get('data/anim/profiles.json');
    const boneJ = new Set(isObj(prJ) && isObj(prJ.bone_lag) ? Object.keys(prJ.bone_lag) : []);
    const seenB = new Map();
    for (const [group, defs] of [['hinges', jts.hinges], ['balls', jts.balls]]) {
      if (!isObj(defs)) continue;
      for (const [name, d] of Object.entries(defs)) {
        if (name.startsWith('_') || !isObj(d)) continue;
        const at = `/${group}/${esc(name)}`;
        (Array.isArray(d.bones) ? d.bones : []).forEach((b, i) => {
          if (typeof b !== 'string') return;
          if (boneJ.size && !boneJ.has(b)) err(JT, `${at}/bones/${i}`, 'joints-bone', `bone "${b}" is not in profiles.json bone_lag`);
          if (seenB.has(b)) err(JT, `${at}/bones/${i}`, 'joints-bone', `bone "${b}" is already a joint at ${seenB.get(b)}`); else seenB.set(b, at);
        });
        if (group === 'hinges' && typeof d.min_deg === 'number' && typeof d.max_deg === 'number') {
          if (d.min_deg >= d.max_deg) err(JT, `${at}/min_deg`, 'joints-order', `min_deg ${d.min_deg} is not below max_deg ${d.max_deg}`);
          if (typeof jts.give_deg === 'number' && Math.abs(d.min_deg + jts.give_deg) > 1e-9) err(JT, `${at}/min_deg`, 'joints-order', `min_deg ${d.min_deg} is not -give_deg (${-jts.give_deg}); the give past straight is one number`, 'warning');
        }
        if (group === 'balls') {
          for (const k of ['twist_deg', 'straight_twist_deg']) if (Array.isArray(d[k]) && d[k].length === 2 && d[k][0] >= d[k][1]) err(JT, `${at}/${k}`, 'joints-order', `${k} runs from ${d[k][0]} to ${d[k][1]}; it must rise`);
          if (Array.isArray(d.twist_deg) && Array.isArray(d.straight_twist_deg) && d.twist_deg.length === 2 && d.straight_twist_deg.length === 2 && (d.straight_twist_deg[0] > d.twist_deg[0] || d.straight_twist_deg[1] < d.twist_deg[1])) err(JT, `${at}/straight_twist_deg`, 'joints-order', `straight_twist_deg ${JSON.stringify(d.straight_twist_deg)} is narrower than twist_deg ${JSON.stringify(d.twist_deg)}; a straight limb may twist further, not less`);
        }
      }
    }
    if (typeof jts.straight_below_deg === 'number' && typeof jts.bent_above_deg === 'number' && jts.straight_below_deg >= jts.bent_above_deg) err(JT, '/straight_below_deg', 'joints-order', `straight_below_deg ${jts.straight_below_deg} is not below bent_above_deg ${jts.bent_above_deg}`);
    const motJ = get('data/anim/ragdoll_motion.json');
    if (isObj(jts.shapes) && isObj(motJ) && isObj(motJ.shapes)) {
      const known = Object.keys(motJ.shapes).filter((k) => !k.startsWith('_'));
      for (const k of Object.keys(jts.shapes)) if (!k.startsWith('_') && k !== 'default' && !known.includes(k)) err(JT, `/shapes/${esc(k)}`, 'joints-shape', `shape "${k}" is not in ragdoll_motion.json shapes (${known.join(', ')})`);
      for (const k of known) if (!(k in jts.shapes)) err(JT, '/shapes', 'joints-shape', `ragdoll_motion.json has shape "${k}" but joints.json has no scale for it (default applies)`, 'warning');
    }
  }

  // ---- fight shots: a lobbed kind has both its numbers; a kind that trades with more power does not do less damage ----
  const shotsD = get('data/fight/shots.json');
  if (isObj(shotsD) && isObj(shotsD.kinds)) {
    const SH = 'data/fight/shots.json';
    const kinds = Object.entries(shotsD.kinds).filter(([k, v]) => !k.startsWith('_') && isObj(v));
    for (const [name, k] of kinds) {
      if ((k.lobTicks === undefined) !== (k.lobArc === undefined)) err(SH, `/kinds/${esc(name)}`, 'shots-lob', `kind "${name}" has ${k.lobTicks === undefined ? 'lobArc but no lobTicks' : 'lobTicks but no lobArc'}; a lobbed shot needs both`);
      if (typeof k.lobTicks === 'number' && typeof k.lifeTicks === 'number' && k.lobTicks > k.lifeTicks) err(SH, `/kinds/${esc(name)}/lobTicks`, 'shots-lob', `lobTicks ${k.lobTicks} is longer than lifeTicks ${k.lifeTicks}`, 'warning');
    }
    const byPower = kinds.filter(([, k]) => typeof k.power === 'number' && typeof k.dmg === 'number').sort((a, b) => a[1].power - b[1].power);
    for (let i = 1; i < byPower.length; i++) if (byPower[i][1].power > byPower[i - 1][1].power && byPower[i][1].dmg < byPower[i - 1][1].dmg) err(SH, `/kinds/${esc(byPower[i][0])}/dmg`, 'shots-order', `"${byPower[i][0]}" trades with more power (${byPower[i][1].power}) than "${byPower[i - 1][0]}" (${byPower[i - 1][1].power}) but does less damage (${byPower[i][1].dmg} against ${byPower[i - 1][1].dmg})`, 'warning');
  }

  // ---- fight shots: the deflect's bands are ordered; a mine chains at least as far as it blasts and a shot sets it off no later than a body ----
  if (isObj(shotsD)) {
    const SH = 'data/fight/shots.json';
    const dfl = shotsD.deflect;
    if (isObj(dfl)) {
      if (typeof dfl.nearMin === 'number' && typeof dfl.nearMax === 'number' && dfl.nearMin > dfl.nearMax) err(SH, '/deflect/nearMin', 'shots-deflect', `nearMin ${dfl.nearMin} is above nearMax ${dfl.nearMax}`);
      if (typeof dfl.farMin === 'number' && typeof dfl.farMax === 'number' && dfl.farMin > dfl.farMax) err(SH, '/deflect/farMin', 'shots-deflect', `farMin ${dfl.farMin} is above farMax ${dfl.farMax}`);
      if (typeof dfl.nearMax === 'number' && typeof dfl.farMin === 'number' && dfl.nearMax > dfl.farMin) err(SH, '/deflect/farMin', 'shots-deflect', `the near band reaches ${dfl.nearMax} but the far band starts at ${dfl.farMin}; the bands overlap`, 'warning');
      if (typeof dfl.arcNear === 'number' && typeof dfl.arcFar === 'number' && dfl.arcFar < dfl.arcNear) err(SH, '/deflect/arcFar', 'shots-deflect', `arcFar ${dfl.arcFar} is below arcNear ${dfl.arcNear}; a far deflect should arc at least as high`, 'warning');
    }
    for (const [name, k] of Object.entries(isObj(shotsD.kinds) ? shotsD.kinds : {})) {
      if (name.startsWith('_') || !isObj(k) || !isObj(k.mine)) continue;
      const m = k.mine;
      if (typeof m.chainR === 'number' && typeof m.blastR === 'number' && m.chainR < m.blastR) err(SH, `/kinds/${esc(name)}/mine/chainR`, 'shots-mine', `chainR ${m.chainR} is below blastR ${m.blastR}; a blast would reach mines it cannot set off`, 'warning');
      if (typeof m.fuseShotTicks === 'number' && typeof m.fuseBodyTicks === 'number' && m.fuseShotTicks > m.fuseBodyTicks) err(SH, `/kinds/${esc(name)}/mine/fuseShotTicks`, 'shots-mine', `a shot sets the mine off after ${m.fuseShotTicks} ticks, later than a body (${m.fuseBodyTicks})`, 'warning');
    }
  }

  // ---- biomes blast: every shot kind has an entry; the tier multipliers do not fall ----
  const bl = get('data/biomes/blast.json');
  if (isObj(bl)) {
    const BL = 'data/biomes/blast.json';
    const shotsB = get('data/fight/shots.json');
    if (isObj(bl.kinds) && isObj(shotsB) && isObj(shotsB.kinds)) {
      const missing = Object.keys(shotsB.kinds).filter((k) => !k.startsWith('_') && !(k in bl.kinds));
      for (const k of missing) err(BL, '/kinds', 'blast-kind', `shot kind "${k}" of data/fight/shots.json has no entry in kinds (${Object.keys(bl.kinds).filter((x) => !x.startsWith('_')).join(', ')})`, 'warning');
      for (const [name, sk] of Object.entries(shotsB.kinds)) if (!name.startsWith('_') && isObj(sk) && isObj(sk.mine) && isObj(bl.kinds[name]) && bl.kinds[name].areaShare === undefined) err(BL, `/kinds/${esc(name)}`, 'blast-kind', `shot kind "${name}" is a mine (it has a mine block in data/fight/shots.json) but its blast row has no areaShare`, 'warning');
    }
    for (const [name, k] of Object.entries(isObj(bl.kinds) ? bl.kinds : {})) {
      if (name.startsWith('_') || !isObj(k)) continue;
      if (typeof k.fullDamage === 'number' && typeof k.damage === 'number' && k.fullDamage < k.damage) err(BL, `/kinds/${esc(name)}/fullDamage`, 'blast-full', `fullDamage ${k.fullDamage} is below the tap's damage ${k.damage}`, 'warning');
      if (typeof k.fullRadius === 'number' && typeof k.radius === 'number' && k.fullRadius < k.radius) err(BL, `/kinds/${esc(name)}/fullRadius`, 'blast-full', `fullRadius ${k.fullRadius} is below the tap's radius ${k.radius}`, 'warning');
      if (typeof k.craterETap === 'number' && typeof k.craterE === 'number' && k.craterETap > k.craterE) err(BL, `/kinds/${esc(name)}/craterETap`, 'blast-full', `craterETap ${k.craterETap} is above the full charge's craterE ${k.craterE}`, 'warning');
    }
    for (const key of ['tierEnergy', 'tierDamage', 'tierRadius']) if (Array.isArray(bl[key])) for (let i = 1; i < bl[key].length; i++) if (typeof bl[key][i] === 'number' && typeof bl[key][i - 1] === 'number' && bl[key][i] < bl[key][i - 1]) err(BL, `/${key}/${i}`, 'blast-tier', `${key} falls from ${bl[key][i - 1]} to ${bl[key][i]} at tier ${i + 1}; it must not fall with the tier`, 'warning');
  }

  // ---- anim targets: poses exist; a blow's limb is not retargeted in its contact pose ----
  const tg = get('data/anim/targets.json');
  if (isObj(tg) && isObj(tg.poses)) {
    const TG = 'data/anim/targets.json';
    const mainP = get('data/anim/poses.json');
    const known = new Set(isObj(mainP) && isObj(mainP.poses) ? Object.keys(mainP.poses) : []);
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.poses\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) known.add(k); }
    const keysetDocs = [get('data/anim/keysets.json')];
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.keysets\.json$/)) keysetDocs.push(get(rel));
    const contactLimbs = new Map();
    for (const kd of keysetDocs) if (isObj(kd) && isObj(kd.keysets)) for (const [name, k] of Object.entries(kd.keysets)) {
      if (name.startsWith('_') || !isObj(k) || !Array.isArray(k.keys)) continue;
      const c = k.keys.find((x) => isObj(x) && x.role === 'contact');
      if (!c || typeof c.pose !== 'string') continue;
      for (const l of [k.limb, k.limb2]) if (typeof l === 'string' && /^(hand|foot)_[lr]$/.test(l)) { if (!contactLimbs.has(c.pose)) contactLimbs.set(c.pose, new Set()); contactLimbs.get(c.pose).add(l); }
    }
    for (const [pose, o] of Object.entries(tg.poses)) {
      if (pose.startsWith('_') || !isObj(o)) continue;
      if (known.size && !known.has(pose)) err(TG, `/poses/${esc(pose)}`, 'targets-pose', `pose "${pose}" is not in data/anim/poses.json nor a wave's poses file`);
      const lm = contactLimbs.get(pose);
      if (lm) for (const l of lm) if (l in o) err(TG, `/poses/${esc(pose)}/${l}`, 'targets-limb', `${l} lands the blow of a key set whose contact pose this is; it is never changed here`, 'warning');
    }
  }

  // ---- anim agency and target poles: poses and sequences exist ----
  {
    const allPoses = new Set();
    const mainA = get('data/anim/poses.json');
    if (isObj(mainA) && isObj(mainA.poses)) for (const k of Object.keys(mainA.poses)) allPoses.add(k);
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.poses\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) allPoses.add(k); }
    const allSeqs = new Set();
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.sequences\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.sequences)) for (const k of Object.keys(d.sequences)) allSeqs.add(k); }
    const ag = get('data/anim/agency.json');
    if (isObj(ag)) {
      const AG = 'data/anim/agency.json';
      const needPose = (id, pointer) => { if (allPoses.size && typeof id === 'string' && !allPoses.has(id)) err(AG, pointer, 'agency-pose', `pose "${id}" is not in poses.json nor a wave's poses file`); };
      const needSeq = (id, pointer) => { if (allSeqs.size && typeof id === 'string' && !allSeqs.has(id)) err(AG, pointer, 'agency-seq', `sequence "${id}" is not in a wave's sequences file`); };
      if (isObj(ag.knockback)) for (const [k, v] of Object.entries(ag.knockback)) if (!k.startsWith('_') && isObj(v)) needPose(v.hold, `/knockback/${esc(k)}/hold`);
      if (isObj(ag.charge)) for (const [k, v] of Object.entries(ag.charge)) if (!k.startsWith('_') && isObj(v)) needPose(v.hold, `/charge/${esc(k)}/hold`);
      if (isObj(ag.embed)) needSeq(ag.embed.seq, '/embed/seq');
      if (isObj(ag.taunt)) needSeq(ag.taunt.seq, '/taunt/seq');
    }
    const pl = get('data/anim/target_poles.json');
    if (isObj(pl) && isObj(pl.poses) && allPoses.size) for (const p of Object.keys(pl.poses)) if (!p.startsWith('_') && !allPoses.has(p)) err('data/anim/target_poles.json', `/poses/${esc(p)}`, 'poles-pose', `pose "${p}" is not in poses.json nor a wave\'s poses file`);
  }

  // ---- anim flight: each (from, to) pair rises ----
  const fl = get('data/anim/flight.json');
  if (isObj(fl)) for (const k of ['speed', 'spin', 'steep', 'lay']) {
    const p = fl[k];
    if (Array.isArray(p) && p.length === 2 && typeof p[0] === 'number' && typeof p[1] === 'number' && p[0] >= p[1]) err('data/anim/flight.json', `/${k}/0`, 'flight-order', `${k} runs from ${p[0]} to ${p[1]}; the lead needs a range that rises`);
  }

  // ---- anim fighters: the shape, the wave and the timing profiles exist ----
  const afs = get('data/anim/fighters.json');
  if (isObj(afs) && isObj(afs.fighters)) {
    const AF = 'data/anim/fighters.json';
    const motF = get('data/anim/ragdoll_motion.json');
    const prF = get('data/anim/profiles.json');
    const shapesF = isObj(motF) && isObj(motF.shapes) ? Object.keys(motF.shapes).filter((k) => !k.startsWith('_')) : [];
    const profsF = isObj(prF) && isObj(prF.profiles) ? Object.keys(prF.profiles) : [];
    for (const [id, fd] of Object.entries(afs.fighters)) {
      if (id.startsWith('_') || !isObj(fd)) continue;
      const at = `/fighters/${esc(id)}`;
      if (typeof fd.shape === 'string' && shapesF.length && !shapesF.includes(fd.shape)) err(AF, `${at}/shape`, 'fighters-shape', `shape "${fd.shape}" is not in ragdoll_motion.json shapes (${shapesF.join(', ')})`);
      if (isObj(fd.waves)) for (const [kind, w] of Object.entries(fd.waves)) {
        if (kind.startsWith('_') || typeof w !== 'string') continue;
        if (!get(`data/anim/waves/${w}.poses.json`)) err(AF, `${at}/waves/${kind}`, 'fighters-wave', `${kind} wave "${w}" has no data/anim/waves/${w}.poses.json`);
        else if (kind === 'strikes' && !get(`data/anim/waves/${w}.keysets.json`)) err(AF, `${at}/waves/${kind}`, 'fighters-wave', `strikes wave "${w}" has no data/anim/waves/${w}.keysets.json`);
      }
      if (isObj(fd.waves) && Array.isArray(fd.waves.more)) fd.waves.more.forEach((w, i) => {
        if (typeof w !== 'string') return;
        if (!get(`data/anim/waves/${w}.poses.json`)) err(AF, `${at}/waves/more/${i}`, 'fighters-wave', `more wave "${w}" has no data/anim/waves/${w}.poses.json`);
        else if (['strikes', 'entries', 'energy'].some((k) => fd.waves[k] === w)) err(AF, `${at}/waves/more/${i}`, 'fighters-wave', `wave "${w}" is already named as ${['strikes', 'entries', 'energy'].find((k) => fd.waves[k] === w)}; it need not be in more`, 'warning');
      });
      if (isObj(fd.timing)) for (const k of ['light', 'heavy']) if (typeof fd.timing[k] === 'string' && profsF.length && !profsF.includes(fd.timing[k])) err(AF, `${at}/timing/${k}`, 'fighters-timing', `timing ${k} "${fd.timing[k]}" is not a profile of profiles.json (${profsF.join(', ')})`);
    }
  }

  // ---- anim pair live: the fighters and waves exist; every sequence and pose a role names exists; gated strikes and shot kinds are real ----
  const plv = get('data/anim/pair_live.json');
  if (isObj(plv)) {
    const PL = 'data/anim/pair_live.json';
    const fgs = get('data/anim/fighters.json');
    const fids = isObj(fgs) && isObj(fgs.fighters) ? Object.keys(fgs.fighters).filter((k) => !k.startsWith('_')) : [];
    if (fids.length) {
      if (isObj(plv.roles)) for (const k of Object.keys(plv.roles)) if (!k.startsWith('_') && !fids.includes(k)) err(PL, `/roles/${esc(k)}`, 'pairlive-fighter', `roles for "${k}", who is not a fighter of fighters.json (${fids.join(', ')})`);
      if (isObj(plv.aliases)) for (const [k, v] of Object.entries(plv.aliases)) if (!k.startsWith('_') && typeof v === 'string' && !fids.includes(v)) err(PL, `/aliases/${esc(k)}`, 'pairlive-fighter', `alias "${k}" names "${v}", who is not a fighter of fighters.json (${fids.join(', ')})`);
    }
    if (Array.isArray(plv.shared)) plv.shared.forEach((w, i) => { if (typeof w === 'string' && !get(`data/anim/waves/${w}.poses.json`)) err(PL, `/shared/${i}`, 'pairlive-wave', `shared wave "${w}" has no data/anim/waves/${w}.poses.json`); });
    const poseSet = new Set(); const seqSet = new Set(); const strikeNames = new Set();
    const mainPl = get('data/anim/poses.json');
    if (isObj(mainPl) && isObj(mainPl.poses)) for (const k of Object.keys(mainPl.poses)) poseSet.add(k);
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.poses\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.poses)) for (const k of Object.keys(d.poses)) poseSet.add(k); }
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.sequences\.json$/)) { const d = get(rel); if (isObj(d) && isObj(d.sequences)) for (const k of Object.keys(d.sequences)) seqSet.add(k); }
    for (const rel of docsFor(/^data\/anim\/waves\/[^/]+\.manifest\.json$/)) { const d = get(rel); if (isObj(d) && Array.isArray(d.strikes)) for (const s of d.strikes) if (isObj(s) && typeof s.name === 'string') strikeNames.add(s.name); }
    const needSeq = (v, at) => { if (seqSet.size && typeof v === 'string' && !seqSet.has(v)) err(PL, at, 'pairlive-ref', `sequence "${v}" is not in a wave's sequences file`); };
    const needPose = (v, at) => { if (poseSet.size && typeof v === 'string' && !poseSet.has(v)) err(PL, at, 'pairlive-ref', `pose "${v}" is not in poses.json nor a wave's poses file`); };
    const needEither = (v, at) => { if ((poseSet.size || seqSet.size) && typeof v === 'string' && !poseSet.has(v) && !seqSet.has(v)) err(PL, at, 'pairlive-ref', `"${v}" is neither a pose nor a sequence of the wave files`); };
    for (const [fid, r] of Object.entries(isObj(plv.roles) ? plv.roles : {})) {
      if (fid.startsWith('_') || !isObj(r)) continue;
      for (const [role, v] of Object.entries(r)) {
        if (role.startsWith('_')) continue;
        const at = `/roles/${esc(fid)}/${esc(role)}`;
        if (role === 'taunts') { if (Array.isArray(v)) v.forEach((x, i) => needEither(x, `${at}/${i}`)); }
        else if (role === 'taunt_first') { needEither(v, at); if (Array.isArray(r.taunts) && typeof v === 'string' && !r.taunts.includes(v)) err(PL, at, 'pairlive-ref', `taunt_first "${v}" is not one of ${fid}'s taunts`, 'warning'); }
        else if (!isObj(v)) continue;
        else if (role === 'charged') { needEither(v.charge, `${at}/charge`); needEither(v.full, `${at}/full`); if (isObj(v.release)) needPose(v.release.pose, `${at}/release/pose`); }
        else if (typeof v.seq === 'string') needSeq(v.seq, `${at}/seq`);
        else if (typeof v.pose === 'string') needPose(v.pose, `${at}/pose`);
      }
    }
    if (Array.isArray(plv.gated) && strikeNames.size) plv.gated.forEach((g, i) => { if (isObj(g) && typeof g.strike === 'string' && !strikeNames.has(g.strike)) err(PL, `/gated/${i}/strike`, 'pairlive-gated', `gated strike "${g.strike}" is no strike of any wave manifest`); });
    const shotsPl = get('data/fight/shots.json');
    if (isObj(shotsPl) && isObj(shotsPl.kinds) && isObj(plv.kinds)) for (const k of Object.keys(shotsPl.kinds)) if (!k.startsWith('_') && !(k in plv.kinds)) err(PL, '/kinds', 'pairlive-kind', `shot kind "${k}" of data/fight/shots.json has no energy role in kinds`, 'warning');
  }

  // ---- fighter ladder: the beam tables never decrease with the tier ----
  for (const rel of docsFor(/^data\/fighters\/[^/]+\/ladder\.json$/)) {
    const lad = get(rel);
    const rs = isObj(lad) && isObj(lad.reach) ? lad.reach.structure : undefined;
    if (Array.isArray(rs)) for (let i = 1; i < rs.length; i++) if (typeof rs[i] === 'number' && typeof rs[i - 1] === 'number' && rs[i] < rs[i - 1]) err(rel, '/reach/structure/' + i, 'ladder-reach-order', 'structure reach falls from ' + rs[i - 1] + ' to ' + rs[i] + ' at tier ' + (i + 1) + '; it must not fall with the tier', 'warning');
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
