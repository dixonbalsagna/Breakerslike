#!/usr/bin/env node
// Soak: many seeded AI-vs-AI matches on the port with QA's per-tick rule checks (P0 exit criterion: 1000 matches, no NaN,
// no crash), timed.   node sim/core/tools/soak.js [N=1000] [--base=1] [--arm=default] [--compare]
// A failure prints the seed; replay it with --base=<seed> 1. --compare also times the prototype on the same seeds.
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { QA, createPlainHarness } from './proto-harness.js';
import { createPortHarness } from './port-harness.js';

export function soak(h, n, base, arm) {
  let ticks = 0, timeouts = 0;
  const t0 = performance.now();
  for (let i = 0; i < n; i++) {
    const seed = base + i;
    let r;
    try { r = QA.runMatch(h, seed, { arm, invariants: true }); }
    catch (e) { throw new Error(`crash at ${arm} seed ${seed}: ${e && e.stack || e}`); }
    if (r.nan) throw new Error(`NaN in ${r.nan.fighter}.${r.nan.key} at ${r.nan.t.toFixed(2)}s, ${arm} seed ${seed}`);
    if (r.xBad) throw new Error(`a fighter left [0, W) in ${arm} seed ${seed}`);
    if (r.violations.length) throw new Error(`rule violation in ${arm} seed ${seed}: ${r.violations.join('; ')}`);
    ticks += r.steps; if (r.timeout) timeouts++;
  }
  const s = (performance.now() - t0) / 1000;
  if (timeouts > Math.ceil(n * 0.01)) throw new Error(`${timeouts} of ${n} matches hit the 300 s cap without a KO`);
  return { n, ticks, timeouts, s };
}

const line = (who, r) => `${who}: ${r.n} matches, ${r.ticks} ticks in ${r.s.toFixed(1)} s  (${(r.s * 1000 / r.n).toFixed(1)} ms/match, ${Math.round(r.ticks / r.s)} ticks/s, ${(r.s * 1e6 / r.ticks).toFixed(1)} us/tick incl. QA checks), ${r.timeouts} timeouts`;

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), val = k => { const a = args.find(x => x.startsWith('--' + k + '=')); return a ? a.split('=')[1] : null; };
  const n = parseInt(args.find(a => !a.startsWith('--')) || '1000', 10), base = parseInt(val('base') || '1', 10), arm = val('arm') || 'default';
  if (!Number.isInteger(n) || n < 1 || !QA.ARMS[arm]) { console.error('usage: node sim/core/tools/soak.js [N=1000] [--base=1] [--arm=NAME] [--compare]'); process.exit(2); }
  try {
    const port = soak(createPortHarness(), n, base, arm);
    console.log('ok    soak, ' + line('port', port));
    if (args.includes('--compare')) { const proto = soak(createPlainHarness(), n, base, arm); console.log('      ' + line('prototype', proto) + `; port/prototype time ${(port.s / proto.s).toFixed(2)}`); }
  } catch (e) { console.log('FAIL  soak: ' + e.message + `\n      replay: node sim/core/tools/soak.js 1 --base=<seed> --arm=${arm}`); process.exit(1); }
}
