#!/usr/bin/env node
// One-command regression suite. From the repo root:   node qa/run-all.js
//   --quick            soak with 100 matches instead of 1000 (about 3 seconds of soak)
//   --only=a,b         run only the named tests (tables, determinism, seam, soak, diff, selftest)
//   --update-golden    rewrite qa/golden-hashes.json after an intended simulation change (runs determinism only)
// Each test file runs in its own process (the prototype installs globals). Exit code is 0 only if every test passes.
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const flag = n => args.includes('--' + n);
const val = n => { const a = args.find(x => x.startsWith('--' + n + '=')); return a ? a.split('=')[1] : null; };

const dir = path.join(__dirname, 'tests');
let names = fs.readdirSync(dir).filter(f => f.endsWith('.test.js')).map(f => f.replace('.test.js', '')).sort();
const order = ['tables', 'determinism', 'seam', 'soak', 'diff', 'selftest'];
const rank = n => (order.includes(n) ? order.indexOf(n) : order.length);
names.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));
if (val('only')) names = val('only').split(',');
if (flag('update-golden')) names = ['determinism'];

const env = { ...process.env };
if (flag('quick')) env.QA_SOAK_MATCHES = env.QA_SOAK_MATCHES || '100';
if (flag('update-golden')) env.QA_UPDATE_GOLDEN = '1';

console.log(`Meridian regression suite   node ${process.version}   ${new Date().toISOString().slice(0, 10)}`);
const rows = [];
for (const n of names) {
  const file = path.join(dir, n + '.test.js');
  if (!fs.existsSync(file)) { console.error('no such test: ' + n); process.exit(2); }
  const t0 = Date.now();
  const r = spawnSync(process.execPath, [file], { stdio: 'inherit', env });
  rows.push({ n, ok: r.status === 0, s: (Date.now() - t0) / 1000, why: r.status === null ? 'killed (' + r.signal + ')' : '' });
  console.log('');
}
console.log('summary');
for (const r of rows) console.log(`  ${r.ok ? 'PASS' : 'FAIL'}  ${r.n.padEnd(12)} ${r.s.toFixed(1)}s ${r.why}`);
const failed = rows.filter(r => !r.ok).length;
console.log(failed ? `\n${failed} of ${rows.length} test files FAILED` : `\nall ${rows.length} test files passed`);
process.exit(failed ? 1 : 0);
