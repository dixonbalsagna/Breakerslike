// Quick parity against the prototype (the full plan is node sim/core/tools/parity.js): a handful of matches compared on
// every tick, one keyboard-driven match per scenario, the golden hashes, and a negative control proving the comparison
// catches a single extra random draw.
import test from 'node:test';
import assert from 'node:assert/strict';
import { lockstep, keyLockstep, KEY_SCENARIOS, run } from '../tools/parity.js';
import { createProtoHarness } from '../tools/proto-harness.js';
import { createPortHarness } from '../tools/port-harness.js';

test('AI vs AI: every tick identical to the prototype', () => {
  const P = createProtoHarness(), Q = createPortHarness();
  for (const [arm, s] of [['default', 1], ['default', 2], ['default', 3], ['swap', 1], ['mirror-hero', 2], ['mirror-villain-flip', 3]]) lockstep(P, Q, arm, s);
});

test('keyboard-driven matches: every tick identical to the prototype', () => {
  for (const sc of KEY_SCENARIOS) keyLockstep(sc, sc.seeds[0]);
});

test('golden hashes and QA records (one match per arm)', () => {
  const msgs = [];
  const r = run({ seeds: 1 }, m => msgs.push(m));
  assert.equal(r.failures, 0, msgs.join('\n'));
});

test('negative control: one extra draw in the prototype spark() is caught', () => {
  const P = createProtoHarness([['function spark(x,y,n,col,spd){', 'function spark(x,y,n,col,spd){ rng();']]), Q = createPortHarness();
  assert.throws(() => lockstep(P, Q, 'default', 1), /differs at tick \d+/);
});
