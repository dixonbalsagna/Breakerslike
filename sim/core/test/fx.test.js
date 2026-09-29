// The QA-002 split: cosmetics are events the sim emits and the render side consumes. The sim state holds only gameplay
// data, emitting events never changes it, no cosmetic draw advances the gameplay stream (split mode), and the reference
// consumer is deterministic. (Prototype parity in 'shared' mode is checked by parity.test.js.)
import test from 'node:test';
import assert from 'node:assert/strict';
import { createSim, newMatch, step } from '../sim.js';
import { stateHash, FX_FIELDS, viewHash } from '../hash.js';
import { createFxView, consumeFx } from '../view/fx.js';

function run(seed, { drop = false, consumer = null, ticks = 3000 } = {}) {
  const S = createSim(); newMatch(S, seed);
  if (drop) S.out.fx = { push() {}, length: 0 };            // events vanish: no emitter may depend on them
  const V = consumer === null ? null : createFxView(consumer);
  const hs = [], types = new Set();
  for (let i = 0; i < ticks && !(S.game.ko && S.game.koT > 3); i++) {
    step(S);
    if (!drop) { for (const e of S.out.fx) types.add(e.type); if (V) consumeFx(V, S, S.out.fx); S.out.fx.length = 0; }
    S.out.feed.length = 0;
    hs.push(stateHash(S).gameplay);
  }
  return { hs, types, S, V };
}

test('the sim state has no cosmetic lane', () => {
  const S = createSim(); newMatch(S, 1);
  for (const k of ['fx', 'rngFx']) assert.ok(!(k in S), `S.${k} still exists`);
  assert.deepEqual(Object.keys(S.out).sort(), ['feed', 'fx']);
});

test('emitting fx events never changes gameplay (the events can be dropped)', () => {
  for (const seed of [1, 2, 3]) assert.deepEqual(run(seed, { drop: true }).hs, run(seed).hs, `seed ${seed}`);
});

test('a consumer cannot feed back: gameplay is the same with or without one, whatever its seed', () => {
  for (const seed of [4, 5]) {
    const bare = run(seed).hs;
    assert.deepEqual(run(seed, { consumer: seed }).hs, bare);
    assert.deepEqual(run(seed, { consumer: 12345 }).hs, bare);
  }
});

test('every emitted event type is documented and consumed', () => {
  const all = new Set();
  for (let seed = 1; seed <= 12; seed++) for (const t of run(seed, { consumer: seed, ticks: 18000 }).types) all.add(t);
  for (const t of all) assert.ok(FX_FIELDS[t], `event type ${t} has no FX_FIELDS entry (docs/architecture/fx-events.md)`);
  for (const t of ['spark', 'ring', 'debris', 'dust', 'fire', 'after', 'damage', 'banner', 'shake', 'tick']) assert.ok(all.has(t), `no ${t} event in 12 matches`);
});

test('the reference consumer is deterministic', () => {
  const a = run(7, { consumer: 7 }), b = run(7, { consumer: 7 });
  assert.equal(viewHash(a.S, a.V), viewHash(b.S, b.V));
  assert.ok(a.V.parts.length + a.V.floats.length > 0 || a.V.banner !== null || a.V.shake > 0, 'the consumer produced nothing');
});
