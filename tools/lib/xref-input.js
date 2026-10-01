'use strict';
// Cross-reference rules for data/input/ (docs/controls/input-schema.md, ADR 0008): the action list, the layout presets and the
// timing table. Called from xref.js with its helpers: get(rel), err(file, pointer, rule, message, level), esc, isObj.

const ACTIONS = 'data/input/actions.json';
const LAYOUTS = 'data/input/layouts.json';
const TIMING = 'data/input/timing.json';

const KB_RESERVED = new Set(['kb:KeyN', 'kb:KeyT', 'kb:KeyY', 'kb:KeyP', 'kb:Escape']);
const LAYERABLE = /^(special[0-9]+|special_auto|signature|upgrade_[a-z]+)$/;
// Actions every preset must bind for its device. Two documented relaxations (see docs/tools/README.md):
// the Simple presets reach the heavy and the signature through the upgrade gestures, and a keyboard preset has no
// pause binding because its pause keys (P, Escape) are reserved for the system.
const SATISFIES = { heavy: ['heavy', 'upgrade_heavy'], signature: ['signature', 'upgrade_sig'] };

function xrefInput({ get, err, esc, isObj }) {
  const actionsDoc = get(ACTIONS);
  const layoutsDoc = get(LAYOUTS);
  const timing = get(TIMING);
  const actionIds = new Set();

  if (isObj(actionsDoc) && Array.isArray(actionsDoc.actions)) {
    const seen = new Map();
    actionsDoc.actions.forEach((a, i) => {
      if (!isObj(a)) return;
      if (seen.has(a.id)) err(ACTIONS, `/actions/${i}/id`, 'actions-id', `action id "${a.id}" is already used at ${seen.get(a.id)}`);
      else seen.set(a.id, `/actions/${i}`);
      actionIds.add(a.id);
      if ((a.kind === 'layer' || a.kind === 'gesture') && a.value === undefined) err(ACTIONS, `/actions/${i}`, 'actions-value', `a ${a.kind} action needs a value`);
      if (a.kind === 'layer' && a.layer === undefined) err(ACTIONS, `/actions/${i}`, 'actions-layer', 'a layer action names its layer');
    });
  }

  if (isObj(layoutsDoc) && Array.isArray(layoutsDoc.presets)) {
    const presets = layoutsDoc.presets.filter(isObj);
    const byId = new Map(presets.map((p) => [p.id, p]));
    const controlsOf = (p) => new Set((Array.isArray(p.bindings) ? p.bindings : []).flatMap((b) => (isObj(b) && Array.isArray(b.controls) ? b.controls : [])));

    layoutsDoc.presets.forEach((p, pi) => {
      if (!isObj(p) || !Array.isArray(p.bindings)) return;
      const at = `/presets/${pi}`;
      const bindings = p.bindings.filter(isObj);
      const slot = isObj(p.slot) ? p.slot : {};

      // layout-action
      if (actionIds.size) {
        p.bindings.forEach((b, bi) => {
          if (isObj(b) && typeof b.action === 'string' && !actionIds.has(b.action)) err(LAYOUTS, `${at}/bindings/${bi}/action`, 'layout-action', `action "${b.action}" is not in actions.json`);
        });
      }
      // layout-device
      p.bindings.forEach((b, bi) => {
        if (!isObj(b) || !Array.isArray(b.controls)) return;
        b.controls.forEach((c, ci) => {
          if (typeof c === 'string' && c.split(':')[0] !== p.device) err(LAYOUTS, `${at}/bindings/${bi}/controls/${ci}`, 'layout-device', `control "${c}" does not belong to a ${p.device} preset`);
        });
      });
      // layout-required
      const bound = new Set(bindings.map((b) => b.action));
      const need = ['move', 'light', 'heavy', 'signature', 'guard', 'dodge', 'power', 'context', 'transform'];
      if (p.device !== 'kb') need.push('pause');
      if (slot.autoMode !== true) need.push('mode');
      if (slot.specialPick === 'auto') need.push('special_auto');
      else need.push('special1', 'special2', 'special3');
      for (const a of need) {
        const ok = (SATISFIES[a] || [a]).some((x) => bound.has(x));
        if (!ok) err(LAYOUTS, at, 'layout-required', `preset "${p.id}" does not bind the required action "${a}"`);
      }
      // layout-conflict: one action per control per layer (gestures and chord parts are exempt)
      const byControl = new Map();
      bindings.forEach((b, bi) => {
        if (b.gesture !== undefined || !Array.isArray(b.controls)) return;
        const single = b.controls.length === 1 || (b.action === 'move' && Array.isArray(b.axis));
        if (!single) return;
        for (const c of b.controls) {
          const key = `${b.layer || 'base'}|${c}`;
          const prev = byControl.get(key);
          if (prev && prev.action !== b.action) err(LAYOUTS, `${at}/bindings/${bi}`, 'layout-conflict', `control "${c}" is bound to "${prev.action}" and to "${b.action}" on the ${b.layer || 'base'} layer`);
          else if (!prev) byControl.set(key, { action: b.action, index: bi });
        }
      });
      // layout-layer
      const layered = bindings.filter((b) => b.layer === 'power');
      if (layered.length && !bindings.some((b) => b.action === 'power' && b.layer === undefined)) err(LAYOUTS, at, 'layout-layer', `preset "${p.id}" has power-layer bindings but does not bind "power"`);
      p.bindings.forEach((b, bi) => {
        if (isObj(b) && b.layer === 'power' && typeof b.action === 'string' && !LAYERABLE.test(b.action)) err(LAYOUTS, `${at}/bindings/${bi}/action`, 'layout-layer', `"${b.action}" cannot be layered; only special*, signature and upgrade* may be`);
      });
      // layout-pair
      if (typeof p.pair === 'string') {
        const other = byId.get(p.pair);
        if (!other) err(LAYOUTS, `${at}/pair`, 'layout-pair', `pair "${p.pair}" is not a preset`);
        else {
          if (other.players !== 2 || p.players !== 2) err(LAYOUTS, `${at}/pair`, 'layout-pair', 'a pair is two presets with players: 2');
          if (other.pair !== p.id) err(LAYOUTS, `${at}/pair`, 'layout-pair', `"${p.pair}" does not point back at "${p.id}"`);
          const mine = controlsOf(p);
          const shared = [...controlsOf(other)].filter((c) => mine.has(c));
          if (shared.length) err(LAYOUTS, `${at}/pair`, 'layout-pair', `"${p.id}" and "${p.pair}" share ${shared.join(', ')}`);
        }
      }
      // layout-reserved
      if (p.device === 'kb') {
        p.bindings.forEach((b, bi) => {
          if (!isObj(b) || !Array.isArray(b.controls)) return;
          b.controls.forEach((c, ci) => {
            if (KB_RESERVED.has(c) || /^kb:F[0-9]+$/.test(c)) err(LAYOUTS, `${at}/bindings/${bi}/controls/${ci}`, 'layout-reserved', `"${c}" is reserved for the system (N, T, Y, P, Escape and the F-keys)`);
          });
        });
      }
      // layout-axis
      p.bindings.forEach((b, bi) => {
        if (isObj(b) && p.device === 'kb' && b.action === 'move' && !(Array.isArray(b.axis) && b.axis.length === 4 && Array.isArray(b.controls) && b.controls.length === 4)) {
          err(LAYOUTS, `${at}/bindings/${bi}`, 'layout-axis', 'a keyboard move binding needs four controls and an axis of four directions');
        }
      });
    });

    // layout-default: exactly one default per device
    const devices = [...new Set(presets.map((p) => p.device))];
    for (const dev of devices) {
      const ofDev = layoutsDoc.presets.map((p, i) => [p, i]).filter(([p]) => isObj(p) && p.device === dev);
      const defaults = ofDev.filter(([p]) => p.default === true);
      if (defaults.length !== 1) err(LAYOUTS, `/presets/${ofDev[0][1]}`, 'layout-default', `${dev} presets have ${defaults.length} defaults; exactly one is needed`);
    }
    const ids = new Map();
    layoutsDoc.presets.forEach((p, i) => {
      if (!isObj(p)) return;
      if (ids.has(p.id)) err(LAYOUTS, `/presets/${i}/id`, 'layout-id', `preset id "${p.id}" is already used at ${ids.get(p.id)}`);
      else ids.set(p.id, `/presets/${i}`);
    });
  }

  if (isObj(timing)) {
    const th = isObj(timing.tapHold) ? timing.tapHold : {};
    const pb = isObj(timing.perfectBlock) ? timing.perfectBlock : {};
    const aq = isObj(timing.attackQueue) ? timing.attackQueue : {};
    const st = isObj(timing.stick) ? timing.stick : {};
    const hs = isObj(timing.hitstopTicks) ? timing.hitstopTicks : {};
    if (typeof st.triggerOff === 'number' && typeof st.triggerOn === 'number' && !(st.triggerOff < st.triggerOn)) err(TIMING, '/stick/triggerOff', 'timing-order', `triggerOff ${st.triggerOff} must be below triggerOn ${st.triggerOn}`);
    if (Number.isInteger(pb.lightWindow) && pb.lightWindow > 15) err(TIMING, '/perfectBlock/lightWindow', 'timing-perfect', `lightWindow ${pb.lightWindow} is above 15, the authored tell`);
    if (Number.isInteger(pb.heavyWindow) && pb.heavyWindow > 20) err(TIMING, '/perfectBlock/heavyWindow', 'timing-perfect', `heavyWindow ${pb.heavyWindow} is above 20, the authored tell`);
    if (Number.isInteger(th.encoreConfirm) && Number.isInteger(th.transformConfirm) && th.encoreConfirm > th.transformConfirm) err(TIMING, '/tapHold/encoreConfirm', 'timing-hold', `encoreConfirm ${th.encoreConfirm} must not exceed transformConfirm ${th.transformConfirm}`);
    if (Number.isInteger(th.transformConfirm) && Number.isInteger(th.encoreOffer) && !(th.transformConfirm < th.encoreOffer)) err(TIMING, '/tapHold/encoreOffer', 'timing-hold', `transformConfirm ${th.transformConfirm} must be below encoreOffer ${th.encoreOffer}`);
    if (Number.isInteger(aq.signatureUnfundedExpiry) && aq.signatureUnfundedExpiry < 180) err(TIMING, '/attackQueue/signatureUnfundedExpiry', 'timing-queue', `signatureUnfundedExpiry ${aq.signatureUnfundedExpiry} must be at least 180 ticks`);
    for (const [chain, label] of [[['light', 'chain', 'heavy', 'guardBreak', 'parry'], 'light <= chain <= heavy <= guardBreak <= parry'], [['beamConnect', 'beamClash', 'finalBlow'], 'beamConnect <= beamClash <= finalBlow']]) {
      for (let i = 0; i + 1 < chain.length; i++) {
        const a = hs[chain[i]];
        const b = hs[chain[i + 1]];
        if (Number.isInteger(a) && Number.isInteger(b) && a > b) err(TIMING, `/hitstopTicks/${chain[i]}`, 'timing-hitstop-order', `${chain[i]} (${a}) should not exceed ${chain[i + 1]} (${b}); the impact hierarchy is ${label}`, 'warning');
      }
    }
    for (const [k, v] of Object.entries(hs)) {
      if (!k.startsWith('_') && Number.isInteger(v) && v > 30) err(TIMING, `/hitstopTicks/${esc(k)}`, 'timing-hitstop-budget', `${k} is ${v} ticks; more than 30 reads as a hang`);
    }
  }
}

module.exports = { xrefInput };
