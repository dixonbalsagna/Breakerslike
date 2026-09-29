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
  { name: 'newMatch forgets to reset the launch history', from: "dirS.lastLaunch = ''; dirS.lastLaunch2 = '';", to: '', test: 'determinism' },
  { name: 'NaN in fighter power', from: 'f.power = Math.min(100, f.power + 0.45*dt);', to: 'f.power = Math.min(100, f.power + 0.45*dt*(T > 20 ? NaN : 1));', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
  { name: 'casualties can exceed the population', from: 'world.casualties += n;', to: 'world.casualties += n*2;', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
  { name: 'buildings heal when hit hard', from: 'const before = b.hp; b.hp -= d;', to: 'const before = b.hp; b.hp -= d; if (d > 50) b.hp += 3*d;', test: 'soak', env: { QA_SOAK_MATCHES: '10' } },
];

// Each confirmed known bug, "fixed" in a scratch copy, must make its own known-bugs check fail with "KB-00x appears fixed".
const FIXES = [
  { id: 'KB-001', from: "0.5 - 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)) ? 'HIT' : 'ESCAPE'", to: "0.5 + 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)) ? 'HIT' : 'ESCAPE'" },
  { id: 'KB-002', from: "S(t, A, D, base*1.4, {noParry:true, ignoreStance:true, big:true});", to: "S(t, A, D, base*1.4, {noParry:true, big:true});" },
  { id: 'KB-003', from: 'function openWindow(ex){', to: 'function openWindow(ex){ if (ex.cancel) return;' },
  { id: 'KB-004', from: '{noParry:true, ignoreStance:true, big:true, stop:0.08}', to: '{noParry:true, big:true, stop:0.08}' },
  { id: 'KB-005', from: "afterimage(D); D.y += 300; D.vx = 0; D.vy = 0; banner('DODGED'", to: "afterimage(D); banner('DODGED'" },
  { id: 'KB-006', from: 'f.y += (ty - f.y)*k;', to: 'f.y = Math.max(f.y + (ty - f.y)*k, groundY(f.x));' },
];
for (const m of FIXES) {
  t.test(`known-bugs check ${m.id} notices when the bug is fixed`, () => {
    assert.ok(html.includes(m.from), `fix target not found in prototype/index.html:
${m.from}`);
    const file = path.join(tmp, 'fix-' + m.id + '.html');
    fs.writeFileSync(file, html.replace(m.from, () => m.to));
    const r = spawnSync(process.execPath, [path.join(__dirname, 'known-bugs.test.js')], { env: { ...process.env, QA_HTML: file, QA_KB_ONLY: m.id }, encoding: 'utf8' });
    assert.notStrictEqual(r.status, 0, `${m.id} check still passed against a prototype with the bug fixed`);
    assert.ok(r.stdout.includes(m.id + ' appears fixed'), `${m.id} check failed, but not with "appears fixed":
${r.stdout}`);
    return 'reports "appears fixed"';
  });
}

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
  for (const name of ["tables", "seam", "determinism", "known-bugs"]) {
    const r = spawnSync(process.execPath, [path.join(__dirname, name + '.test.js')], { env: { ...process.env, QA_HTML: SRC }, encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${name}.test.js fails on the real prototype:\n${r.stdout}`);
  }
});

fs.rmSync(tmp, { recursive: true, force: true });
t.done();
