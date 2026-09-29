// baseline-diff: the comparison maths, and end to end that it flags a real balance change and stays quiet for a
// change that only reshuffles random numbers.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { compareMetrics } = require('../baseline-diff');
const t = require('../lib/check')('diff');

const ROOT = path.join(__dirname, '..', '..');
const DIFF = path.join(__dirname, '..', 'baseline-diff.js');
const SRC = fs.readFileSync(path.join(ROOT, 'prototype', 'index.html'), 'utf8');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'meridian-diff-'));
const run = (args, env = {}) => spawnSync(process.execPath, [DIFF, ...args], { encoding: 'utf8', env: { ...process.env, ...env } });
const mutant = (name, from, to) => {
  assert.ok(SRC.includes(from), `mutation target not found in prototype/index.html:\n${from}`);
  const f = path.join(tmp, name + '.html'); fs.writeFileSync(f, SRC.replace(from, () => to)); return f;
};

t.test('compareMetrics: equal values give z = 0', () => {
  const rows = compareMetrics({ a: { v: 0.5, se: 0.02 }, b: { v: 3, se: 0.1 } }, { a: { v: 0.5, se: 0.02 }, b: { v: 3, se: 0.1 } });
  assert.ok(rows.every(r => r.z === 0));
});
t.test('compareMetrics: z uses both standard errors', () => {
  const [r] = compareMetrics({ a: { v: 0.50, se: 0.03 } }, { a: { v: 0.60, se: 0.04 } });
  assert.ok(Math.abs(r.z - 2) < 1e-9, `z ${r.z}, expected 0.1 / 0.05 = 2`);
});
t.test('compareMetrics: metrics that appear or vanish are flagged, and exact changes with no spread are infinite', () => {
  const rows = Object.fromEntries(compareMetrics({ gone: { v: 0.1, se: 0.01 }, same: { v: 1, se: 0 }, moved: { v: 1, se: 0 } }, { fresh: { v: 0.2, se: 0.01 }, same: { v: 1, se: 0 }, moved: { v: 2, se: 0 } }).map(r => [r.name, r]));
  assert.strictEqual(rows.gone.note, 'gone'); assert.strictEqual(rows.fresh.note, 'new');
  assert.ok(Math.abs(rows.gone.z) > 3 && Math.abs(rows.fresh.z) > 3);
  assert.strictEqual(rows.same.z, 0); assert.strictEqual(rows.moved.z, Infinity);
});

t.test('a run bit-identical to the baseline compares nothing and exits 0', () => {
  const base = path.join(ROOT, 'qa', 'baseline-p0.json');
  const r = run([`--current=${base}`, '--fail']);
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
  assert.ok(/bit-identical/.test(r.stdout), r.stdout);
});
t.test('an unchanged simulation, re-run on the first 100 seeds of each arm, raises no strict flag', () => {
  const r = run(['--arms=default,swap', '--matches=100', '--fail']);
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
  return (r.stdout.match(/(\d+) MOVED and (\d+) moved of (\d+)/) || [])[0];
});
t.test('a real balance change (VORR damage x1.5) is flagged, including the win rate, and --fail exits 1', () => {
  const html = mutant('vorr-damage', 'dmgMul:1.0, spd:0.95', 'dmgMul:1.5, spd:0.95');
  const r = run(['--arms=default', '--matches=150', '--fail'], { QA_HTML: html });
  assert.strictEqual(r.status, 1, 'expected exit 1\n' + r.stdout + r.stderr);
  assert.ok(/default\s+win\.p1\s.*MOVED/.test(r.stdout), 'win.p1 was not flagged MOVED\n' + r.stdout);
});
t.test('a change that only reshuffles random numbers (one extra draw per spark) raises no strict flag', () => {
  const html = mutant('spark-draw', 'for (let i = 0; i < n; i++){ const a = R(0,6.283), s = R(0.3,1)*(spd||500);', 'for (let i = 0; i < n; i++){ R(0,1); const a = R(0,6.283), s = R(0.3,1)*(spd||500);');
  const r = run(['--arms=default,swap', '--matches=300', '--fail'], { QA_HTML: html });
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
  assert.ok(!/identical: same seeds/.test(r.stdout), 'the trajectories should have changed');
});
t.test('a baseline without per-metric data is refused with instructions', () => {
  const old = JSON.parse(fs.readFileSync(path.join(ROOT, 'qa', 'baseline-p0.json'), 'utf8'));
  for (const a of Object.values(old.arms)) delete a.metrics;
  const f = path.join(tmp, 'old-schema.json'); fs.writeFileSync(f, JSON.stringify(old));
  const r = run([`--baseline=${f}`, '--arms=default', '--matches=10']);
  assert.strictEqual(r.status, 2); assert.ok(/balance-report/.test(r.stderr), r.stderr);
});

fs.rmSync(tmp, { recursive: true, force: true });
t.done();
