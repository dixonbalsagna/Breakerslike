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

function xrefFight({ get, err, esc, isObj, plainKeys }) {
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

  // ---- fight mood ----
  const mood = get(MOOD);
  if (isObj(mood) && isObj(mood.bands)) {
    const b = mood.bands;
    if (Number.isInteger(b.calmBelow) && Number.isInteger(b.tenseAt) && b.calmBelow > b.tenseAt) err(MOOD, '/bands/calmBelow', 'mood-bands', `calmBelow ${b.calmBelow} must not exceed tenseAt ${b.tenseAt} (Tense falls back below the level it rose at)`);
    if (Number.isInteger(b.tenseBelow) && Number.isInteger(b.frenziedAt) && b.tenseBelow > b.frenziedAt) err(MOOD, '/bands/tenseBelow', 'mood-bands', `tenseBelow ${b.tenseBelow} must not exceed frenziedAt ${b.frenziedAt}`);
    if (Number.isInteger(b.tenseAt) && Number.isInteger(b.frenziedAt) && b.tenseAt >= b.frenziedAt) err(MOOD, '/bands/frenziedAt', 'mood-bands', `frenziedAt ${b.frenziedAt} must be above tenseAt ${b.tenseAt}`);
    if (Number.isInteger(b.calmBelow) && Number.isInteger(b.tenseBelow) && b.calmBelow >= b.tenseBelow) err(MOOD, '/bands/tenseBelow', 'mood-bands', `tenseBelow ${b.tenseBelow} must be above calmBelow ${b.calmBelow}`);
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
