// Determinism and replays: same seed, same match; several sims in one process never share state; a recorded match
// (human input included) replays bit for bit from its JSON; a tampered replay is caught at the right checkpoint.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createSim, newMatch, step } from '../sim.js';
import { stateHash } from '../hash.js';
import { recorder, play, CHECK_EVERY } from '../replay.js';
import { createRng, next } from '../rng.js';
import { createIntent } from '../../input/intent.js';

function trace(seed, ticks) {
  const S = createSim(); newMatch(S, seed);
  const out = [];
  for (let i = 0; i < ticks; i++) { step(S); const h = stateHash(S); out.push(h.gameplay + h.presentation); }
  return out;
}

test('the same seed gives the same match, tick by tick, in both lanes', () => {
  for (const s of [1, 42]) assert.deepEqual(trace(s, 2500), trace(s, 2500));
  assert.notDeepEqual(trace(1, 300), trace(2, 300));
});

test('two sims stepped alternately match two sims run alone (no shared state)', () => {
  const A = createSim(), B = createSim();
  newMatch(A, 5); newMatch(B, 6);
  const ha = [], hb = [];
  for (let i = 0; i < 2500; i++) { step(A); step(B); ha.push(stateHash(A).gameplay); hb.push(stateHash(B).gameplay); }
  const alone = seed => { const S = createSim(); newMatch(S, seed); const h = []; for (let i = 0; i < 2500; i++) { step(S); h.push(stateHash(S).gameplay); } return h; };
  assert.deepEqual(ha, alone(5)); assert.deepEqual(hb, alone(6));
});

// A scripted human for P1 against the AI: moves, dashes, charges, switches stance and presses attacks.
function scriptedMatch(seed, ticks) {
  const S = createSim(), rec = recorder(S, seed, { p1: false, p2: true }), r = createRng(seed ^ 0x51ed);
  const held = createIntent();
  for (let t = 0; t < ticks; t++) {
    if (next(r) < 0.05) held.mx = [-1, 0, 1][Math.floor(next(r) * 3)];
    if (next(r) < 0.05) held.my = [-1, 0, 1][Math.floor(next(r) * 3)];
    if (next(r) < 0.02) held.dash = !held.dash;
    if (next(r) < 0.01) held.charge = !held.charge;
    const i = { ...held, light: next(r) < 0.03, heavy: next(r) < 0.015, sig: next(r) < 0.008, stance: next(r) < 0.004 ? Math.floor(next(r) * 4) : -1 };
    if (t === 1500) rec.toggle(1);           // P2 handed to a (silent) human for a while
    if (t === 2100) rec.toggle(1);
    rec.step([i, null]);
  }
  return rec.finish();
}

test('a recorded human-vs-AI match replays bit for bit from JSON', () => {
  for (const seed of [11, 12]) {
    const rp = JSON.parse(JSON.stringify(scriptedMatch(seed, 4000)));
    assert.ok(rp.checkpoints.length === Math.floor(4000 / CHECK_EVERY) && rp.inputs.length > 50);
    const r = play(rp);
    assert.equal(r.ok, true, `seed ${seed}: first bad tick ${r.firstBadTick}`);
    assert.deepEqual(r.final, rp.final);
  }
});

test('a tampered replay is caught by a checkpoint soon after the change', () => {
  const rp = JSON.parse(JSON.stringify(scriptedMatch(13, 3000)));
  // Reverse P1's horizontal input for 300 ticks from tick 900 (one tick alone may fall while P1 cannot move).
  const t = 900;
  for (const e of rp.inputs) if (e[1] === 0 && e[0] >= t && e[0] < t + 300 && e[2]) e[2].mx = -e[2].mx;
  const r = play(rp);
  assert.equal(r.ok, false);
  assert.ok(r.firstBadTick > t && r.firstBadTick <= t + 300 + CHECK_EVERY, `tampered from ${t}, caught at ${r.firstBadTick}`);
  const clean = play(JSON.parse(JSON.stringify(scriptedMatch(13, 3000))));
  assert.equal(clean.ok, true);
});
