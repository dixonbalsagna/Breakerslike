// Self-test: proves the other tests can fail. Each mutant is a copy of prototype/index.html with one deliberate bug;
// the named test file must exit non-zero against it. If a mutation target is no longer in index.html this test fails,
// so update the pattern here when the prototype code it points at is rewritten.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const t = require('../lib/check')('selftest');

const SRC = path.join(__dirname, '..', '..', 'prototype', 'index.html');
const html = fs.readFileSync(SRC, 'utf8');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'meridian-mutants-'));

const MUTANTS = [
  { name: 'shortest-arc distance without wrap', from: 'if (d > HALF) d -= W; else if (d < -HALF) d += W;', to: '', test: 'seam' },
  { name: 'position wrap lets negative x through', from: 'const wrap = x => ((x % W) + W) % W;', to: 'const wrap = x => x % W;', test: 'seam' },
  { name: 'RNG seeded from the clock even when a seed is given', from: 'rng = mulberry32(game.seed);', to: 'rng = mulberry32((Date.now() ^ (Math.random()*1e9)) | 0);', test: 'determinism' },
  { name: 'Math.random in the sim', from: 'const R = (a,b) => a + (b-a) * rng();', to: 'const R = (a,b) => a + (b-a) * Math.random();', test: 'determinism' },
  { name: 'NaN in fighter power', from: 'f.power = Math.min(100, f.power + 0.45*dt);', to: 'f.power = Math.min(100, f.power + 0.45*dt*(T > 20 ? NaN : 1));', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
  { name: 'casualties can exceed the population', from: 'world.casualties += n;', to: 'world.casualties += n*2;', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
  { name: 'buildings heal when hit hard', from: 'const before = b.hp; b.hp -= d;', to: 'const before = b.hp; b.hp -= d; if (d > 50) b.hp += 3*d;', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
];

for (const m of MUTANTS) {
  t.test(`${m.test} tests catch: ${m.name}`, () => {
    assert.ok(html.includes(m.from), `mutation target not found in prototype/index.html:\n${m.from}`);
    const file = path.join(tmp, m.test + '-' + m.name.replace(/\W+/g, '-') + '.html');
    fs.writeFileSync(file, html.replace(m.from, () => m.to));
    const r = spawnSync(process.execPath, [path.join(__dirname, m.test + '.test.js')], { env: { ...process.env, QA_HTML: file, ...(m.env || {}) }, encoding: 'utf8' });
    assert.notStrictEqual(r.status, 0, `${m.test}.test.js still passed against the mutant "${m.name}"`);
    return 'failed as it should';
  });
}
t.test('the unmutated prototype passes the same tests (control)', () => {
  for (const name of ['tables', 'seam', 'determinism']) {
    const r = spawnSync(process.execPath, [path.join(__dirname, name + '.test.js')], { env: { ...process.env, QA_HTML: SRC }, encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${name}.test.js fails on the real prototype:\n${r.stdout}`);
  }
});

fs.rmSync(tmp, { recursive: true, force: true });
t.done();
