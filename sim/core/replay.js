// Replays: a seed, the AI flags and the intents the host passed to step() reproduce a match bit for bit. A replay is plain
// JSON: {format, v, seed, ai, ticks, inputs, toggles, checkpoints, final}.
//   inputs       [tick, slot, intent|null], only where a slot's intent changed from its previous one
//   toggles      [tick, slot]: toggleAI before that tick
//   checkpoints  [tick, gameplay hash] every CHECK_EVERY ticks; final: both lane hashes at the end
// Intents, not raw keys, are recorded, so a replay does not depend on the key mapping.
import { createSim, newMatch, step, toggleAI } from './sim.js';
import { stateHash } from './hash.js';

export const CHECK_EVERY = 60;
const INTENT = ['mx', 'my', 'dash', 'charge', 'light', 'heavy', 'sig', 'stance'];
const copy = i => (i ? Object.fromEntries(INTENT.map(k => [k, i[k]])) : null);
const same = (a, b) => (!a || !b ? a === b : INTENT.every(k => a[k] === b[k]));

// Start recording a match on a fresh newMatch(S, seed, ai). Use rec.step and rec.toggle instead of step and toggleAI.
export function recorder(S, seed, ai = {}) {
  newMatch(S, seed, ai);
  const rp = { format: 'meridian-replay', v: 1, seed, ai: { p1: !!S.fighters[0].ai, p2: !!S.fighters[1].ai }, ticks: 0, inputs: [], toggles: [], checkpoints: [], final: null };
  const last = [null, null];
  return {
    replay: rp,
    step(inputs) {
      for (let k = 0; k < 2; k++) { const i = inputs ? inputs[k] || null : null; if (!same(i, last[k])) { last[k] = copy(i); rp.inputs.push([rp.ticks, k, copy(i)]); } }
      const r = step(S, inputs);
      if (++rp.ticks % CHECK_EVERY === 0) rp.checkpoints.push([rp.ticks, stateHash(S).gameplay]);
      return r;
    },
    toggle(idx) { rp.toggles.push([rp.ticks, idx]); toggleAI(S, idx); },
    finish() { rp.final = stateHash(S); return rp; },
  };
}

// Re-run a replay and verify it. Returns {ok, firstBadTick (null if ok), final} where final is the replayed end state's hashes.
export function play(rp, opts = {}) {
  if (rp.format !== 'meridian-replay' || rp.v !== 1) throw new Error('not a meridian-replay v1');
  const S = createSim(opts);
  newMatch(S, rp.seed, rp.ai);
  const cur = [null, null], checks = new Map(rp.checkpoints);
  let ii = 0, ti = 0;
  for (let t = 0; t < rp.ticks; t++) {
    while (ti < rp.toggles.length && rp.toggles[ti][0] === t) toggleAI(S, rp.toggles[ti++][1]);
    while (ii < rp.inputs.length && rp.inputs[ii][0] === t) { cur[rp.inputs[ii][1]] = rp.inputs[ii][2]; ii++; }
    step(S, cur);
    const want = checks.get(t + 1);
    if (want !== undefined && want !== stateHash(S).gameplay) return { ok: false, firstBadTick: t + 1, final: stateHash(S) };
  }
  const final = stateHash(S);
  const ok = !rp.final || (final.gameplay === rp.final.gameplay && final.presentation === rp.final.presentation);
  return { ok, firstBadTick: ok ? null : rp.ticks, final };
}
