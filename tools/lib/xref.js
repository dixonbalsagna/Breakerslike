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
