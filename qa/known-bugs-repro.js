#!/usr/bin/env node
// Print what each known-bug scenario observes on the prototype: node qa/known-bugs-repro.js [KB-001 ...]
// The steps behind each scenario are in qa/known-bugs.md; the code is in qa/lib/probes.js.
const { createHarness } = require('../prototype/tools/match-runner');
const { instrumentedHarness } = require('./lib/instrument');
const P = require('./lib/probes');

const want = process.argv.slice(2).map(a => a.toUpperCase());
const run = {
  'KB-001': () => [{ aTier: 4, dTier: 1 }, { aTier: 2, dTier: 2 }, { aTier: 1, dTier: 4 }].map(c => { const r = P.beamVsEscape(createHarness(), { ...c, trials: 500 }); return `attacker tier ${c.aTier} vs defender tier ${c.dTier}: HIT ${(r.rate * 100).toFixed(1)}% of ${r.n} (seeds 1..500)`; }),
  'KB-002': () => ['light', 'sig'].map(k => ({ kind: k, ...P.chargingStrike(createHarness(), k) })),
  'KB-003': () => [P.parryThenChain(createHarness())],
  'KB-004': () => [P.guardChain(createHarness())],
  'KB-005': () => [P.dodgeFreeze(createHarness())],
  'KB-006': () => { const h = instrumentedHarness(); return [{ where: 'mountains', ...P.rushThrough(h, { ax: 6200, bx: 7800 }) }, { where: 'city', ...P.rushThrough(h, { ax: 2100, bx: 4000 }) }, { where: 'flat control', ...P.rushThrough(h, { ax: 1500, bx: 1900 }) }]; },
};
for (const id of want.length ? want : Object.keys(run)) {
  if (!run[id]) { console.error('unknown bug ' + id + ' (KB-001 to KB-006)'); process.exit(2); }
  console.log('== ' + id);
  for (const o of run[id]()) console.log('  ' + (typeof o === 'string' ? o : JSON.stringify(o)));
}
