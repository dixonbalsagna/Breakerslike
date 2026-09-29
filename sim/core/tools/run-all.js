#!/usr/bin/env node
// The port's whole test suite as one command. From the repo root:   npm test --prefix sim
// (or from sim/:  npm test,  or directly:  node sim/core/tools/run-all.js)
//   1. unit and integration tests (node:test): rng, wrap math, seam crossing, replays, quick parity
//   2. full parity against the prototype: every tick of every match in the default plan, QA records, golden hashes
//   3. the 1000-match soak (P0 exit criterion), timed
//   4. golden: sim/core/test/golden-gd.json (the GDScript port's targets) is current with the JS core
//   5. godot: the GDScript parity check, headless, if Godot is found (GODOT env var or the default install path);
//      skipped with a notice otherwise
// Options: --quick (parity --quick and a 100-match soak), --only=unit,parity,soak,golden,godot
// Node built-ins only. Exit code 0 only if every stage passes; each stage runs in its own process.
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

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
  { name: 'golden', cmd: [process.execPath, path.join(here, 'golden.js'), '--check'] },
];
const GODOT = process.env.GODOT || 'C:/Users/itsha/AppData/Local/Programs/Godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe';
if (fs.existsSync(GODOT)) STAGES.push({ name: 'godot', pre: [GODOT, '--headless', '--path', path.resolve(simDir, '..'), '--import'], cmd: [GODOT, '--headless', '--path', path.resolve(simDir, '..'), '--script', 'res://sim/core/tools/parity.gd'] });
else console.log(`note: Godot not found at ${GODOT} (set GODOT to run the GDScript parity stage)`);

console.log(`Meridian sim suite   node ${process.version}${quick ? '   (quick)' : ''}`);
const rows = [];
for (const st of STAGES) {
  if (only && !only.includes(st.name)) continue;
  console.log(`\n== ${st.name}: ${st.cmd.slice(1).map(a => path.basename(a)).join(' ')}`);
  const t0 = performance.now();
  // A fresh clone has no Godot class cache yet: the import pass registers every class_name script first.
  if (st.pre) spawnSync(st.pre[0], st.pre.slice(1), { cwd: simDir, stdio: 'ignore' });
  const r = spawnSync(st.cmd[0], st.cmd.slice(1), { cwd: simDir, stdio: 'inherit', env: { ...process.env, ...(st.env || {}) } });
  rows.push({ name: st.name, ok: r.status === 0, s: (performance.now() - t0) / 1000, why: r.error ? String(r.error) : r.status === null ? 'killed (' + r.signal + ')' : '' });
}
console.log('\nsummary');
for (const r of rows) console.log(`  ${r.ok ? 'PASS' : 'FAIL'}  ${r.name.padEnd(8)} ${r.s.toFixed(1)}s ${r.why}`);
const failed = rows.filter(r => !r.ok).length;
console.log(failed ? `\n${failed} of ${rows.length} stages FAILED` : `\nall ${rows.length} stages passed`);
process.exit(failed ? 1 : 0);
