'use strict';
const fs = require('node:fs');
const path = require('node:path');
const repoRoot = path.resolve(__dirname, '..', '..');
// Cross-reference rules between data files. Each rule runs only when the files it reads are
// present and parsed; problems inside a single file are the schema's job, not this file's.
// Findings are {level, file, line, pointer, rule, message} with rule "xref:<name>".

const FIN = 'data/combat/finishers.json';
const TPL = 'data/combat/templates.json';
const ART = 'data/art/flashes.json';
const CUES = 'audio/data/cues.json';
const FLASH_CUES = 'audio/data/flash_cues.json';
const GRUNTS = 'audio/data/grunts.json';
const MIX = 'audio/data/mix.json';
const IMPACTS = 'audio/data/impacts.json';
const TERMS = 'ui/data/terms.json';
const PROFILES = 'ui/data/readout_profiles.json';
const ROSTER = 'data/fighters/roster.json';
const EFFECTS = 'data/art/effects.json';
const HOWTO = 'ui/data/howto.json';
const GLYPHS = 'ui/data/glyphs.json';
const BABBLE = 'audio/data/babble.json';
const BABBLE_CAPTIONS = 'audio/data/babble_captions.json';
const OPTIONS = 'ui/data/options.json';
const SKETCH_COMMON = 'audio/data/sketch_common.json';

const esc = (t) => String(t).replace(/~/g, '~0').replace(/\//g, '~1');
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const plainKeys = (o) => (isObj(o) ? Object.keys(o).filter((k) => !k.startsWith('_')) : []);

function xref(docs, root = repoRoot) {
  const findings = [];
  const get = (rel) => (docs.has(rel) ? docs.get(rel).value : undefined);
  const err = (file, pointer, rule, message, level = 'error') => {
    const d = docs.get(file);
    let line;
    if (d) {
      let p = pointer;
      for (;;) {
        line = d.lineOf(p);
        if (line !== undefined || p === '') break;
        p = p.slice(0, p.lastIndexOf('/'));
      }
    }
    findings.push({ level, file, line, pointer, rule: `xref:${rule}`, message });
  };
  const dupes = (file, ids, base, rule, what) => {
    const seen = new Map();
    ids.forEach(({ id, pointer }) => {
      if (seen.has(id)) err(file, pointer, rule, `${what} "${id}" is already used at ${seen.get(id)}`);
      else seen.set(id, pointer);
    });
  };

  // ---- combat: templates ----
  const tpl = get(TPL);
  const fin = get(FIN);
  const vocab = new Set(isObj(fin) && isObj(fin.cues) ? plainKeys(fin.cues) : []);
  const beatLists = []; // [{file, pointer, beats}]
  if (isObj(tpl) && Array.isArray(tpl.templates)) {
    dupes(TPL, tpl.templates.map((t, i) => ({ id: t && t.id, pointer: `/templates/${i}/id` })), '', 'template-id', 'template id');
    tpl.templates.forEach((t, ti) => {
      if (!isObj(t) || !Array.isArray(t.branches)) return;
      const ids = new Set(t.branches.map((b) => b && b.id));
      dupes(TPL, t.branches.map((b, bi) => ({ id: b && b.id, pointer: `/templates/${ti}/branches/${bi}/id` })), '', 'branch-id', `branch id in template "${t.id}"`);
      const s = t.selector;
      if (isObj(s)) {
        const refs = [['branch', s.branch], ['ifBelow', s.ifBelow], ['else', s.else], ['ifGreater', s.ifGreater]];
        if (isObj(s.below)) refs.push(['below/branch', s.below.branch]);
        if (isObj(s.above)) refs.push(['above/branch', s.above.branch]);
        for (const [key, target] of refs) {
          if (target !== undefined && !ids.has(target)) err(TPL, `/templates/${ti}/selector/${key}`, 'selector-branch', `selector points at branch "${target}", but template "${t.id}" has only: ${[...ids].join(', ')}`);
        }
      }
      if (Array.isArray(t.shared && t.shared.spaced)) beatLists.push({ file: TPL, pointer: `/templates/${ti}/shared/spaced`, beats: t.shared.spaced, profile: 'spaced' });
      if (Array.isArray(t.shared && t.shared.dynamic)) beatLists.push({ file: TPL, pointer: `/templates/${ti}/shared/dynamic`, beats: t.shared.dynamic, profile: 'dynamic' });
      t.branches.forEach((b, bi) => {
        if (isObj(b) && Array.isArray(b.spaced)) beatLists.push({ file: TPL, pointer: `/templates/${ti}/branches/${bi}/spaced`, beats: b.spaced, profile: 'spaced' });
        if (isObj(b) && Array.isArray(b.dynamic)) beatLists.push({ file: TPL, pointer: `/templates/${ti}/branches/${bi}/dynamic`, beats: b.dynamic, profile: 'dynamic' });
        if (isObj(b) && tpl.profile === 'dynamic' && !Array.isArray(b.dynamic)) err(TPL, `/templates/${ti}/branches/${bi}`, 'dynamic-beats', 'the active profile is "dynamic", but this branch has no dynamic beats');
      });
    });
    if (isObj(tpl.chainLink) && Array.isArray(tpl.chainLink.spaced)) beatLists.push({ file: TPL, pointer: '/chainLink/spaced', beats: tpl.chainLink.spaced, profile: 'spaced' });
    if (isObj(tpl.chainLink) && Array.isArray(tpl.chainLink.dynamic)) beatLists.push({ file: TPL, pointer: '/chainLink/dynamic', beats: tpl.chainLink.dynamic, profile: 'dynamic' });
    if (tpl.profile === 'dynamic' && isObj(tpl.chainLink) && !Array.isArray(tpl.chainLink.dynamic)) err(TPL, '/chainLink', 'dynamic-beats', 'the active profile is "dynamic", but the chain link has no dynamic beats');
  }

  // ---- combat: finishers ----
  if (isObj(fin) && Array.isArray(fin.finishers)) {
    const finIds = new Set(fin.finishers.map((f) => f && f.id));
    dupes(FIN, fin.finishers.map((f, i) => ({ id: f && f.id, pointer: `/finishers/${i}/id` })), '', 'finisher-id', 'finisher id');
    if (isObj(fin.select)) {
      for (const [fighter, target] of Object.entries(fin.select.byFighter || {})) {
        if (!finIds.has(target)) err(FIN, `/select/byFighter/${esc(fighter)}`, 'finisher-key', `fighter ${fighter} selects finisher "${target}", which does not exist`);
      }
      if (fin.select.fallback !== undefined && !finIds.has(fin.select.fallback)) err(FIN, '/select/fallback', 'finisher-key', `fallback finisher "${fin.select.fallback}" does not exist`);
    }
    fin.finishers.forEach((f, i) => {
      if (!isObj(f)) return;
      if (Array.isArray(f.beats) && f.profile === 'authored') beatLists.push({ file: FIN, pointer: `/finishers/${i}/beats`, beats: f.beats });
      if (isObj(f.outcomes)) {
        for (const k of ['landed', 'survived']) {
          if (Array.isArray(f.outcomes[k])) beatLists.push({ file: FIN, pointer: `/finishers/${i}/outcomes/${k}`, beats: f.outcomes[k] });
        }
      }
      // A contestOpen beat names a struggle block that must exist.
      const all = [...(Array.isArray(f.beats) ? f.beats : [])];
      all.forEach((b, bi) => {
        if (isObj(b) && b.op === 'contestOpen' && isObj(b.args) && b.args.struggle !== undefined && b.args.struggle !== 'contest.struggle') {
          err(FIN, `/finishers/${i}/beats/${bi}/args/struggle`, 'struggle', `struggle "${b.args.struggle}" is not defined; only "contest.struggle" exists`);
        }
      });
    });
  }

  // Tempo names: a tick's add/sub names and a { ticks: name } duration must be keys of the profile's tempo.
  for (const { file, pointer, beats, profile } of beatLists) {
    const tempo = isObj(tpl) && isObj(tpl.profiles) && isObj(tpl.profiles[profile]) ? tpl.profiles[profile].tempo : undefined;
    if (file !== TPL || !isObj(tempo)) continue;
    const names = new Set(plainKeys(tempo));
    const bad = (pointerOf, name) => {
      if (typeof name === 'string' && !names.has(name)) err(file, pointerOf, 'tempo-name', `"${name}" is not in profiles.${profile}.tempo (${[...names].join(', ')})`);
    };
    beats.forEach((b, bi) => {
      if (!isObj(b)) return;
      if (isObj(b.tick)) {
        for (const key of ['add', 'sub']) if (Array.isArray(b.tick[key])) b.tick[key].forEach((n, ni) => bad(`${pointer}/${bi}/tick/${key}/${ni}`, n));
      }
      if (isObj(b.args) && isObj(b.args.dur) && typeof b.args.dur.ticks === 'string') bad(`${pointer}/${bi}/args/dur/ticks`, b.args.dur.ticks);
    });
  }

  // Every cue a beat plays exists in the cue vocabulary of finishers.json.
  if (vocab.size) {
    for (const { file, pointer, beats } of beatLists) {
      beats.forEach((b, bi) => {
        if (!isObj(b) || !isObj(b.args)) return;
        const cues = [];
        if (b.op === 'cue' || b.op === 'contestOpen') cues.push(['cue', b.args.cue]);
        for (const [key, cue] of cues) {
          if (typeof cue === 'string' && !vocab.has(cue)) err(file, `${pointer}/${bi}/args/${key}`, 'cue', `cue "${cue}" is not in the cue vocabulary (finishers.json "cues")`);
        }
      });
    }
  }
  // Parry rewards play cues too.
  if (isObj(tpl) && isObj(tpl.profiles && tpl.profiles.spaced && tpl.profiles.spaced.parry)) {
    // parry and clean_parry are render cues outside the finisher vocabulary; nothing to check yet.
  }

  // ---- art flashes <-> audio ----
  const art = get(ART);
  const flashCues = get(FLASH_CUES);
  const cues = get(CUES);
  const activeFlashes = isObj(art) ? plainKeys(art.flashes) : null;
  const heldFlashes = isObj(art) ? plainKeys(art.held) : [];
  if (activeFlashes) {
    for (const id of heldFlashes) if (activeFlashes.includes(id)) err(ART, `/held/${esc(id)}`, 'flash-held', `flash "${id}" is both active and held`);
    // Priorities of active flashes are unique (1 is highest): arbitration needs a strict order.
    const prio = new Map();
    for (const id of activeFlashes) {
      const p = art.flashes[id] && art.flashes[id].priority;
      if (typeof p !== 'number') continue;
      if (prio.has(p)) err(ART, `/flashes/${esc(id)}/priority`, 'flash-priority', `priority ${p} is already used by "${prio.get(p)}"; arbitration needs a strict order`);
      else prio.set(p, id);
    }
    // Pulse arithmetic (pulse_rule): total = count x on + (count - 1) x off + fade, stated three times.
    const near = (a, b) => Math.abs(a - b) < 1e-9;
    for (const [group, ptr] of [[art.flashes, 'flashes'], [art.held, 'held']]) {
      for (const [id, fl] of Object.entries(isObj(group) ? group : {})) {
        if (!isObj(fl) || !isObj(fl.pulse) || ![fl.pulse.count, fl.pulse.on, fl.pulse.off, fl.pulse.fade].every((n) => typeof n === 'number')) continue;
        const want = fl.pulse.count * fl.pulse.on + (fl.pulse.count - 1) * fl.pulse.off + fl.pulse.fade;
        for (const [where, total] of [['pulse/total', fl.pulse.total], ['total', fl.total]]) {
          if (typeof total === 'number' && !near(total, want)) err(ART, `/${ptr}/${esc(id)}/${where}`, 'flash-total', `total ${total} should be count x on + (count - 1) x off + fade = ${Number(want.toFixed(6))}`);
        }
      }
    }
    // Keep-out (Art's rule): every non-ground shape of an active flash sits between angle_min and angle_max
    // (facing frame). Held flashes are exempt.
    if (isObj(art.keep_out) && typeof art.keep_out.angle_min === 'number' && typeof art.keep_out.angle_max === 'number') {
      for (const [group, ptr] of [[art.flashes, 'flashes']]) {
        for (const [id, fl] of Object.entries(isObj(group) ? group : {})) {
          if (!isObj(fl) || !Array.isArray(fl.layout)) continue;
          fl.layout.forEach((l, i) => {
            if (isObj(l) && !l.ground && typeof l.a === 'number' && (l.a < art.keep_out.angle_min || l.a > art.keep_out.angle_max)) {
              err(ART, `/${ptr}/${esc(id)}/layout/${i}/a`, 'flash-keep-out', `angle ${l.a} is outside the keep-out range ${art.keep_out.angle_min} to ${art.keep_out.angle_max} that keep_out states`);
            }
          });
        }
      }
    }
    if (isObj(art.legal_rules)) {
      const all = new Set([...activeFlashes, ...heldFlashes]);
      for (const rule of ['round_tip', 'low_crest']) {
        const byFamily = art.legal_rules[rule];
        if (!isObj(byFamily)) continue;
        for (const [fam, ids] of Object.entries(byFamily)) {
          if (!Array.isArray(ids)) continue;
          ids.forEach((id, i) => {
            if (!all.has(id)) err(ART, `/legal_rules/${esc(rule)}/${esc(fam)}/${i}`, 'flash-id', `legal rule names flash "${id}", which does not exist`);
          });
        }
      }
    }
    if (isObj(flashCues) && isObj(flashCues.flashes)) {
      const audioIds = plainKeys(flashCues.flashes);
      const known = new Set([...activeFlashes, ...heldFlashes]);
      for (const id of activeFlashes) {
        if (!audioIds.includes(id)) err(FLASH_CUES, '/flashes', 'flash-audio', `active flash "${id}" (${ART}) has no audio cue in ${FLASH_CUES}`);
      }
      for (const id of audioIds) {
        if (!known.has(id)) err(FLASH_CUES, `/flashes/${esc(id)}`, 'flash-audio', `audio cue "${id}" matches no flash in ${ART} (active or held)`);
        else if (Boolean(flashCues.flashes[id] && flashCues.flashes[id].held) !== heldFlashes.includes(id)) {
          err(FLASH_CUES, `/flashes/${esc(id)}`, 'flash-held', heldFlashes.includes(id) ? `flash "${id}" is held in ${ART}, so its cue needs "held": true` : `cue "${id}" says held, but the flash is active in ${ART}`);
        }
      }
    }
    if (isObj(cues) && isObj(cues.flash) && isObj(cues.flash.rank)) {
      const rank = plainKeys(cues.flash.rank);
      for (const id of activeFlashes) {
        if (!rank.includes(id)) err(CUES, '/flash/rank', 'flash-rank', `active flash "${id}" has no rank in cues.json flash.rank`);
      }
      for (const id of rank) {
        if (!activeFlashes.includes(id)) err(CUES, `/flash/rank/${esc(id)}`, 'flash-rank', `rank names flash "${id}", which is not an active flash in ${ART}`);
      }
      // The ranks are copied from Art's priorities: the same numbers.
      for (const id of rank) {
        const p = art.flashes[id] && art.flashes[id].priority;
        if (p !== undefined && cues.flash.rank[id] !== p) err(CUES, `/flash/rank/${esc(id)}`, 'flash-rank', `rank ${cues.flash.rank[id]} differs from the art priority ${p} in ${ART}`);
      }
    }
    if (isObj(cues) && isObj(cues.flash) && Array.isArray(cues.flash.held)) {
      cues.flash.held.forEach((id, i) => { if (!heldFlashes.includes(id)) err(CUES, `/flash/held/${i}`, 'flash-held', `cues.json holds "${id}", which is not held in ${ART}`); });
    }
    // Audio pairs its cue with Art's pulses: the same pulse train and the same length (max_s = total).
    if (isObj(flashCues) && isObj(flashCues.flashes)) {
      for (const id of activeFlashes) {
        const a = art.flashes[id];
        const c = flashCues.flashes[id];
        if (!isObj(a) || !isObj(c)) continue;
        if (isObj(a.pulse) && isObj(c.pulse)) {
          for (const k of ['count', 'on', 'off', 'fade']) {
            if (c.pulse[k] !== a.pulse[k]) err(FLASH_CUES, `/flashes/${esc(id)}/pulse/${k}`, 'flash-pulse', `${k} is ${c.pulse[k]} but Art's pulse for "${id}" has ${a.pulse[k]}`);
          }
          if (Array.isArray(c.layers)) {
            c.layers.forEach((l, i) => {
              if (isObj(l) && Number.isInteger(l.at_pulse) && l.at_pulse >= c.pulse.count) err(FLASH_CUES, `/flashes/${esc(id)}/layers/${i}/at_pulse`, 'flash-pulse', `at_pulse ${l.at_pulse} is past the last pulse (count is ${c.pulse.count})`);
            });
          }
        }
        if (typeof a.total === 'number' && typeof c.max_s === 'number' && c.max_s !== a.total) err(FLASH_CUES, `/flashes/${esc(id)}/max_s`, 'flash-duration', `max_s is ${c.max_s} but Art's total for "${id}" is ${a.total}`);
      }
    }
    // Family names: art families {P: circles, ...} must match the audio families.
    if (isObj(art.families) && isObj(flashCues) && isObj(flashCues.families)) {
      const artNames = Object.values(art.families);
      for (const name of artNames) {
        if (!(name in flashCues.families)) err(FLASH_CUES, '/families', 'flash-family', `art family "${name}" has no entry in flash_cues.json families`);
      }
      for (const name of plainKeys(flashCues.families)) {
        if (!artNames.includes(name)) err(FLASH_CUES, `/families/${esc(name)}`, 'flash-family', `audio family "${name}" is not a family in ${ART}`);
      }
    }
  }

  // ---- art effects ----
  const fx = get(EFFECTS);
  if (isObj(fx)) {
    const swap = isObj(fx.lanes && fx.lanes.trail) ? fx.lanes.trail.fire_range_swap : undefined;
    if (isObj(swap) && typeof fx.haze === 'string' && typeof swap.rim === 'string' && swap.rim.toLowerCase() !== fx.haze.toLowerCase()) {
      err(EFFECTS, '/lanes/trail/fire_range_swap/rim', 'effects-haze', `the fire-range swap rim ${swap.rim} should be the haze neutral ${fx.haze}`);
    }
    if (isObj(swap) && Array.isArray(swap.applies_to) && isObj(art) && isObj(art.families)) {
      swap.applies_to.forEach((fam, i) => { if (!(fam in art.families)) err(EFFECTS, `/lanes/trail/fire_range_swap/applies_to/${i}`, 'effects-family', `family "${fam}" is not in ${ART} families`); });
    }
    // Art's stated lightness ranges (L*): glass light and mid above 80, steel mid and shadow below 40.
    const lstar = (hex) => {
      const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
      const y = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
      return y > 216 / 24389 ? 116 * Math.cbrt(y) - 16 : (24389 / 27) * y;
    };
    const lane = (name, steps, limit) => {
      const l = fx.lanes && fx.lanes[name];
      if (!isObj(l)) return;
      for (const step of steps) {
        if (typeof l[step] !== 'string' || !/^#[0-9a-fA-F]{6}$/.test(l[step])) continue;
        const v = lstar(l[step]);
        if (limit.above !== undefined && v <= limit.above) err(EFFECTS, `/lanes/${name}/${step}`, 'effects-lightness', `${name} ${step} ${l[step]} has L* ${v.toFixed(1)}; Art's rule needs above ${limit.above}`);
        if (limit.below !== undefined && v >= limit.below) err(EFFECTS, `/lanes/${name}/${step}`, 'effects-lightness', `${name} ${step} ${l[step]} has L* ${v.toFixed(1)}; Art's rule needs below ${limit.below}`);
      }
    };
    // Embers: Art's deuteranopia contrast table is recomputed from the hex values (Machado severity 1.0 on linear RGB,
    // WCAG relative luminance, best of the step and its rim against each ground) and must match, and must meet the 3.7 the
    // result line promises.
    const em = fx.lanes && fx.lanes.embers;
    if (isObj(em) && isObj(em.ramp) && isObj(em.deutan_check) && Array.isArray(em.deutan_check.grounds)) {
      const hexOf = (s) => { const m = /#[0-9a-fA-F]{6}/.exec(String(s)); return m ? m[0] : null; };
      const linear = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
      const M = [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.01182, 0.04294, 0.968881]];
      const lum = (h) => { const c = linear(h); const s = M.map((r) => Math.min(1, Math.max(0, r[0] * c[0] + r[1] * c[1] + r[2] * c[2]))); return 0.2126 * s[0] + 0.7152 * s[1] + 0.0722 * s[2]; };
      const ratio = (a, b) => { const x = lum(a); const y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
      const grounds = em.deutan_check.grounds.map(hexOf);
      const rows = [['core_with_rim', em.ramp.core, em.rim], ['hot_with_rim', em.ramp.hot, em.rim], ['warm_with_rim', em.ramp.warm, em.rim], ['char_with_light_rim', em.char, em.ramp.hot]];
      for (const [key, step, rim] of rows) {
        const listed = em.deutan_check[key];
        if (!Array.isArray(listed) || ![step, rim, ...grounds].every((h) => typeof h === 'string' && /^#[0-9a-fA-F]{6}$/.test(h))) continue;
        if (listed.length !== grounds.length) { err(EFFECTS, `/lanes/embers/deutan_check/${key}`, 'effects-deutan', `has ${listed.length} ratios for ${grounds.length} grounds`); continue; }
        grounds.forEach((g, i) => {
          const want = Math.max(ratio(step, g), ratio(rim, g));
          if (Math.abs(want - listed[i]) > 0.01) err(EFFECTS, `/lanes/embers/deutan_check/${key}/${i}`, 'effects-deutan', `listed ${listed[i]}, but the colours give ${want.toFixed(2)} against ${g}`);
          if (want < 3.7) err(EFFECTS, `/lanes/embers/${key === 'char_with_light_rim' ? 'char' : 'ramp'}`, 'effects-deutan', `contrast ${want.toFixed(2)} against ${g} is under the 3.7 that Art's result promises`);
        });
      }
    }
    lane('glass', ['light', 'mid'], { above: 80 });
    lane('steel', ['mid', 'shadow'], { below: 40 });
  }

  // ---- audio: voices and buses ----
  const grunts = get(GRUNTS);
  const voices = isObj(grunts) ? plainKeys(grunts.voices) : null;
  if (voices) {
    if (isObj(flashCues) && isObj(flashCues.families)) {
      for (const [name, fam] of Object.entries(flashCues.families)) {
        if (isObj(fam) && fam.voice !== undefined && !voices.includes(fam.voice)) err(FLASH_CUES, `/families/${esc(name)}/voice`, 'voice', `voice "${fam.voice}" is not in grunts.json voices yet (only ${voices.join(', ')} are synthesised)`, 'warning');
      }
    }
    if (isObj(cues) && isObj(cues.fighters)) {
      for (const [fighter, voice] of Object.entries(cues.fighters)) {
        if (!voices.includes(voice)) err(CUES, `/fighters/${esc(fighter)}`, 'voice', `fighter ${fighter} uses voice "${voice}", which does not exist in grunts.json voices`);
      }
    }
  }
  const mix = get(MIX);
  if (isObj(mix) && Array.isArray(mix.buses) && isObj(cues)) {
    const buses = new Set(mix.buses.map((b) => b && b.name));
    const busUse = [];
    if (isObj(cues.sounds)) for (const [id, s] of Object.entries(cues.sounds)) if (isObj(s)) busUse.push([`/sounds/${esc(id)}/bus`, s.bus]);
    if (isObj(cues.flash)) busUse.push(['/flash/bus', cues.flash.bus]);
    for (const [pointer, bus] of busUse) if (bus !== undefined && !buses.has(bus)) err(CUES, pointer, 'bus', `bus "${bus}" is not defined in mix.json buses (${[...buses].join(', ')})`);
  }
  const impacts = get(IMPACTS);
  if (isObj(impacts) && isObj(impacts.sounds) && isObj(cues)) {
    const known = new Set(plainKeys(impacts.sounds));
    const use = [];
    if (isObj(cues.damage) && Array.isArray(cues.damage.classes)) cues.damage.classes.forEach((c, i) => isObj(c) && use.push([`/damage/classes/${i}/sound`, c.sound]));
    if (isObj(cues.crater)) use.push(['/crater/sound', cues.crater.sound]);
    for (const [pointer, sound] of use) if (sound !== undefined && !known.has(sound)) err(CUES, pointer, 'sound', `sound "${sound}" is not synthesised in impacts.json`);
    if (isObj(cues.sounds)) for (const id of plainKeys(cues.sounds)) if (!known.has(id)) err(CUES, `/sounds/${esc(id)}`, 'sound', `cue sound "${id}" is not synthesised in impacts.json`);
  }

  // ---- ui ----
  const terms = get(TERMS);
  if (isObj(terms) && Array.isArray(terms.stance_ids) && isObj(terms.stance)) {
    for (const id of terms.stance_ids) if (!(id in terms.stance)) err(TERMS, '/stance', 'stance', `stance_ids lists "${id}" but stance has no text for it`);
    for (const id of plainKeys(terms.stance)) if (!terms.stance_ids.includes(id)) err(TERMS, `/stance/${esc(id)}`, 'stance', `stance text for "${id}", which is not in stance_ids`);
  }
  const options = get(OPTIONS);
  if (isObj(options) && isObj(options.options)) {
    for (const [name, o] of Object.entries(options.options)) {
      if (!isObj(o)) continue;
      const at = `/options/${esc(name)}`;
      if (Array.isArray(o.choices) && !o.choices.includes(o.default)) err(OPTIONS, `${at}/default`, 'option-default', `default ${JSON.stringify(o.default)} is not one of the choices ${JSON.stringify(o.choices)}`);
      if (typeof o.min === 'number' && typeof o.max === 'number') {
        if (o.min >= o.max) err(OPTIONS, `${at}/min`, 'option-range', `min ${o.min} must be below max ${o.max}`);
        if (typeof o.default === 'number' && (o.default < o.min || o.default > o.max)) err(OPTIONS, `${at}/default`, 'option-default', `default ${o.default} is outside ${o.min} to ${o.max}`);
      }
    }
  }
  if (isObj(terms) && Array.isArray(terms.places)) {
    let prev = 0;
    terms.places.forEach((p, i) => {
      if (!isObj(p)) return;
      if (p.x0 !== prev) err(TERMS, `/places/${i}/x0`, 'places', `region starts at ${p.x0} but the previous one ends at ${prev} (regions must tile the planet with no gap or overlap)`);
      if (p.x1 <= p.x0) err(TERMS, `/places/${i}/x1`, 'places', `region ends at ${p.x1}, not after its start ${p.x0}`);
      prev = p.x1;
    });
  }
  const common = get(SKETCH_COMMON);
  if (isObj(common) && Number.isInteger(common.bars)) {
    for (const key of ['chords', 'intensity', 'dynamics_db']) {
      if (Array.isArray(common[key]) && common[key].length !== common.bars) err(SKETCH_COMMON, `/${key}`, 'bars', `${key} has ${common[key].length} entries but bars is ${common.bars}`);
    }
    if (Array.isArray(common.tune)) {
      common.tune.forEach((n, i) => {
        if (Array.isArray(n) && n[0] >= common.bars) err(SKETCH_COMMON, `/tune/${i}`, 'bars', `note is in bar ${n[0]}, but the score has only ${common.bars} bars`);
      });
    }
  }
  const profiles = get(PROFILES);
  if (isObj(profiles) && isObj(profiles.aliases)) {
    const names = new Set(plainKeys(profiles).filter((k) => k !== 'schema' && k !== 'aliases' && k !== 'note'));
    for (const [alias, a] of Object.entries(profiles.aliases)) {
      if (isObj(a) && a.base !== undefined && !names.has(a.base)) err(PROFILES, `/aliases/${esc(alias)}/base`, 'profile', `alias "${alias}" uses profile "${a.base}", which does not exist`);
    }
  }

  // ---- audio: babble ----
  const babble = get(BABBLE);
  if (isObj(babble)) {
    const moods = new Set(isObj(babble.moods) ? plainKeys(babble.moods) : []);
    const timbres = new Set(isObj(babble.timbres) ? plainKeys(babble.timbres) : []);
    const onsets = new Set(isObj(babble.onsets) ? plainKeys(babble.onsets) : []);
    const vowels = new Set(isObj(babble.vowels) ? plainKeys(babble.vowels) : []);
    const syllables = new Set(isObj(babble.syllables) ? plainKeys(babble.syllables) : []);
    if (isObj(babble.syllables)) {
      for (const [name, s] of Object.entries(babble.syllables)) {
        if (!isObj(s)) continue;
        if (!onsets.has(s.onset)) err(BABBLE, `/syllables/${esc(name)}/onset`, 'babble-onset', `onset "${s.onset}" is not in onsets (${[...onsets].join(', ')})`);
        if (!vowels.has(s.vowel)) err(BABBLE, `/syllables/${esc(name)}/vowel`, 'babble-vowel', `vowel "${s.vowel}" is not in vowels (${[...vowels].join(', ')})`);
      }
    }
    if (isObj(babble.moods)) {
      for (const [name, m] of Object.entries(babble.moods)) {
        if (isObj(m) && !timbres.has(m.timbre)) err(BABBLE, `/moods/${esc(name)}/timbre`, 'babble-timbre', `timbre "${m.timbre}" is not in timbres (${[...timbres].join(', ')})`);
      }
    }
    if (isObj(babble.mood_map)) {
      for (const [tag, mood] of Object.entries(babble.mood_map)) {
        if (!moods.has(mood)) err(BABBLE, `/mood_map/${esc(tag)}`, 'babble-mood', `Narrative tag "${tag}" maps to "${mood}", which is not a babble mood (${[...moods].join(', ')})`);
        if (moods.has(tag)) err(BABBLE, `/mood_map/${esc(tag)}`, 'babble-mood', `"${tag}" is already a babble mood; a mapped tag must not shadow one`);
      }
    }
    // A voice's own laugh (the babble laugh, not a grunt clip) is a valid gesture target as well.
    const gestureNames = new Set(['laugh']);
    if (isObj(babble.voice_moods)) {
      for (const [vid, map] of Object.entries(babble.voice_moods)) {
        if (isObj(babble.voices) && !(vid in babble.voices)) err(BABBLE, `/voice_moods/${esc(vid)}`, 'voice', `voice_moods names "${vid}", which is not a voice in babble.json`);
        for (const [tag, mood] of Object.entries(isObj(map) ? map : {})) {
          if (!moods.has(mood)) err(BABBLE, `/voice_moods/${esc(vid)}/${esc(tag)}`, 'babble-mood', `"${vid}" maps "${tag}" to "${mood}", which is not a babble mood (${[...moods].join(', ')})`);
        }
      }
    }
    if (isObj(babble.styles)) {
      for (const [name, s] of Object.entries(babble.styles)) {
        if (isObj(s) && s.mood !== undefined && !moods.has(s.mood)) err(BABBLE, `/styles/${esc(name)}/mood`, 'babble-mood', `style "${name}" uses mood "${s.mood}", which is not a babble mood (${[...moods].join(', ')})`);
      }
    }
    if (isObj(grunts) && isObj(grunts.voices)) {
      for (const v of Object.values(grunts.voices)) {
        if (isObj(v) && isObj(v.gestures)) Object.keys(v.gestures).forEach((n) => gestureNames.add(n));
      }
    }
    if (isObj(babble.voices)) {
      for (const [vid, v] of Object.entries(babble.voices)) {
        if (voices && !voices.includes(vid)) err(BABBLE, `/voices/${esc(vid)}`, 'voice', `babble voice "${vid}" is not in grunts.json voices (${voices.join(', ')})`);
        if (isObj(v) && isObj(v.lexicon)) {
          for (const syl of Object.keys(v.lexicon)) if (!syllables.has(syl)) err(BABBLE, `/voices/${esc(vid)}/lexicon/${esc(syl)}`, 'babble-syllable', `lexicon uses syllable "${syl}", which is not in syllables`);
        }
      }
      if (voices) for (const vid of voices) if (!(vid in babble.voices)) err(BABBLE, '/voices', 'voice', `grunts.json has voice "${vid}", but babble.json has none for it`, 'warning');
    }
    if (gestureNames.size) {
      const pairs = [];
      if (isObj(babble.cue_map)) for (const [cue, g] of Object.entries(babble.cue_map)) pairs.push([`/cue_map/${esc(cue)}`, g]);
      if (isObj(babble.grunt_punctuation)) for (const [k, p] of Object.entries(babble.grunt_punctuation)) if (isObj(p)) pairs.push([`/grunt_punctuation/${esc(k)}/gesture`, p.gesture]);
      for (const [pointer, g] of pairs) if (typeof g === 'string' && !gestureNames.has(g)) err(BABBLE, pointer, 'babble-gesture', `gesture "${g}" is not defined by any voice in grunts.json`);
    }
    const caps = get(BABBLE_CAPTIONS);
    if (isObj(caps) && isObj(caps.captions)) {
      const known = new Set([...moods, ...(isObj(babble.mood_map) ? Object.keys(babble.mood_map) : []), ...Object.values(isObj(babble.voice_moods) ? babble.voice_moods : {}).flatMap((m) => (isObj(m) ? Object.keys(m) : []))]);
      for (const [vid, list] of Object.entries(caps.captions)) {
        if (isObj(babble.voices) && !(vid in babble.voices)) err(BABBLE_CAPTIONS, `/captions/${esc(vid)}`, 'voice', `captions for "${vid}", which is not a voice in babble.json`);
        (Array.isArray(list) ? list : []).forEach((c, i) => {
          if (isObj(c) && !known.has(c.mood)) err(BABBLE_CAPTIONS, `/captions/${esc(vid)}/${i}/mood`, 'babble-mood', `mood "${c.mood}" is neither a babble mood nor a Narrative tag in mood_map`);
        });
      }
    }
  }

  // ---- ui: how to play ----
  const howto = get(HOWTO);
  if (isObj(howto) && Array.isArray(howto.pages)) {
    const glyphs = get(GLYPHS);
    const actions = new Set(isObj(glyphs) && isObj(glyphs.actions) ? Object.keys(glyphs.actions) : []);
    const families = new Set([...(isObj(glyphs) && Array.isArray(glyphs.families) ? glyphs.families : []), 'touch']);
    const stances = new Set(isObj(terms) && Array.isArray(terms.stance_ids) ? terms.stance_ids : []);
    dupes(HOWTO, howto.pages.map((p, i) => ({ id: p && p.id, pointer: `/pages/${i}/id` })), '', 'howto-page', 'page id');
    howto.pages.forEach((p, pi) => {
      if (!isObj(p)) return;
      if (isObj(p.device_label) && families.size > 1) {
        for (const fam of Object.keys(p.device_label)) if (!families.has(fam)) err(HOWTO, `/pages/${pi}/device_label/${esc(fam)}`, 'howto-family', `device label for "${fam}", which is not a glyph family (${[...families].join(', ')})`);
      }
      for (const listName of ['items', 'touch_items']) {
        (Array.isArray(p[listName]) ? p[listName] : []).forEach((it, ii) => {
          if (!isObj(it)) return;
          const at = `/pages/${pi}/${listName}/${ii}`;
          const ids = [];
          if (typeof it.action === 'string') ids.push([`${at}/action`, it.action]);
          if (Array.isArray(it.actions)) it.actions.forEach((a, ai) => ids.push([`${at}/actions/${ai}`, a]));
          if (actions.size) for (const [pointer, a] of ids) if (!actions.has(a)) err(HOWTO, pointer, 'howto-action', `action "${a}" is not in glyphs.json actions`);
          if (stances.size && typeof it.stance === 'string' && !stances.has(it.stance)) err(HOWTO, `${at}/stance`, 'howto-stance', `stance "${it.stance}" is not in terms.json stance_ids (${[...stances].join(', ')})`);
          if (typeof it.heading === 'string' && (it.text !== undefined || it.icon !== undefined || it.action !== undefined || it.actions !== undefined)) err(HOWTO, at, 'howto-item', 'a heading item carries no other content');
          if (typeof it.action === 'string' && Array.isArray(it.actions)) err(HOWTO, at, 'howto-item', 'an item has action or actions, not both');
        });
      }
    });
  }

  // ---- fighters ----
  const fighterFiles = [...docs.keys()].filter((r) => /^data\/fighters\/[^/]+\/fighter\.json$/.test(r)).sort();
  const seenIds = new Map();
  const finIds = isObj(fin) && Array.isArray(fin.finishers) ? new Map(fin.finishers.map((f) => [f && f.id, f])) : null;
  for (const file of fighterFiles) {
    const f = get(file);
    if (!isObj(f)) continue;
    const folder = file.split('/')[2];
    if (f.id !== undefined) {
      if (f.id !== folder) err(file, '/id', 'fighter-id', `id "${f.id}" does not match its folder name "${folder}"`);
      if (seenIds.has(f.id)) err(file, '/id', 'fighter-id', `fighter id "${f.id}" is already used by ${seenIds.get(f.id)}`);
      else seenIds.set(f.id, file);
    }
    if (finIds && isObj(f.finishers)) {
      for (const [tier, key] of Object.entries(f.finishers)) {
        if (!finIds.has(key)) {
          err(file, `/finishers/${esc(tier)}`, 'finisher-key', `finisher "${key}" does not exist in ${FIN}`);
        } else {
          const owner = finIds.get(key).fighter;
          if (owner !== '*' && owner !== f.id) err(file, `/finishers/${esc(tier)}`, 'finisher-owner', `finisher "${key}" belongs to fighter ${owner}, not ${f.id}`, 'warning');
        }
      }
    }
  }
  const increasing = (arr) => Array.isArray(arr) && arr.every((n, i) => typeof n === 'number' && (i === 0 || n > arr[i - 1]));
  for (const [file] of docs) {
    const m = /^data\/fighters\/([^/]+)\/(wounds|ladder)\.json$/.exec(file);
    if (!m) continue;
    const d = get(file);
    if (!isObj(d)) continue;
    const key = m[2] === 'wounds' ? 'stageAt' : 'thresholds';
    if (Array.isArray(d[key]) && !increasing(d[key])) err(file, `/${key}`, 'increasing', `${key} must be strictly increasing (got ${JSON.stringify(d[key])})`);
    if (m[2] === 'wounds' && isObj(d.regions) && isObj(d.family)) {
      const n = plainKeys(d.regions).length;
      for (const [fam, w] of Object.entries(d.family)) {
        if (!fam.startsWith('_') && Array.isArray(w) && w.length !== n) err(file, `/family/${esc(fam)}`, 'family-weights', `has ${w.length} weights but the fighter has ${n} regions`);
      }
    }
  }
  for (const file of fighterFiles) {
    const sibling = file.replace(/fighter\.json$/, 'wounds.json');
    if (!docs.has(sibling) && !fs.existsSync(path.join(root, sibling))) err(file, '', 'fighter-files', `${file.split('/')[2]} has no wounds.json next to fighter.json (D1a defines both)`);
  }
  const roster = get(ROSTER);
  if (Array.isArray(roster)) {
    dupes(ROSTER, roster.map((id, i) => ({ id, pointer: `/${i}` })), '', 'roster-id', 'roster id');
    roster.forEach((id, i) => {
      if (fighterFiles.length && !seenIds.has(id)) err(ROSTER, `/${i}`, 'roster-id', `roster lists "${id}", but no data/fighters/${id}/fighter.json defines it`);
    });
  }
  return findings;
}

module.exports = { xref };
