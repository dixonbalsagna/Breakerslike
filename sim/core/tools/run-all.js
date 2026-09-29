#!/usr/bin/env node
// The port's whole test suite as one command. From the repo root:   npm test --prefix sim
// (or from sim/:  npm test,  or directly:  node sim/core/tools/run-all.js)
//   1. unit and integration tests (node:test): rng, wrap math, seam crossing, replays, quick parity
//   2. full parity against the prototype: every tick of every match in the default plan, QA records, golden hashes
//   3. the 1000-match soak (P0 exit criterion), timed
// Options: --quick (parity --quick and a 100-match soak), --only=unit,parity,soak
// Node built-ins only. Exit code 0 only if every stage passes; each stage runs in its own process.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const simDir = path.resolve(here, '..', '..');
const args = process.argv.slice(2);
const quick = args.includes('--quick');
const onlyArg = args.find(a => a.startsWith('--only='));
const only = onlyArg ? onlyArg.slice(7).split(',') : null;

const STAGES = [
  { name: 'unit', cmd: [process.execPath, '--test'] },
  { name: 'parity', cmd: [process.execPath, path.join(here, 'parity.js'), ...(quick ? ['--quick'] : [])] },
  { name: 'soak', cmd: [process.execPath, path.join(here, 'soak.js'), quick ? '100' : '1000'] },
];

console.log(`Meridian sim suite   node ${process.version}${quick ? '   (quick)' : ''}`);
const rows = [];
for (const st of STAGES) {
  if (only && !only.includes(st.name)) continue;
  console.log(`\n== ${st.name}: ${st.cmd.slice(1).map(a => path.basename(a)).join(' ')}`);
  const t0 = performance.now();
  const r = spawnSync(st.cmd[0], st.cmd.slice(1), { cwd: simDir, stdio: 'inherit', env: { ...process.env, ...(st.env || {}) } });
  rows.push({ name: st.name, ok: r.status === 0, s: (performance.now() - t0) / 1000, why: r.error ? String(r.error) : r.status === null ? 'killed (' + r.signal + ')' : '' });
}
console.log('\nsummary');
for (const r of rows) console.log(`  ${r.ok ? 'PASS' : 'FAIL'}  ${r.name.padEnd(8)} ${r.s.toFixed(1)}s ${r.why}`);
const failed = rows.filter(r => !r.ok).length;
console.log(failed ? `\n${failed} of ${rows.length} stages FAILED` : `\nall ${rows.length} stages passed`);
process.exit(failed ? 1 : 0);
