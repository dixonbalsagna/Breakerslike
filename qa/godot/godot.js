// Runs the GDScript sim's QA record producer (qa/godot/records.gd) in headless Godot, in parallel, and returns the records.
// Node is only glue here: no dependencies, all sim work happens in Godot. Match i of an arm uses seed base+i, and the
// records come back in seed order, so a run is reproducible whatever the job count.
const { spawn, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// QA_GODOT_ROOT points the runner at another checkout of the project (for example a git archive of an earlier commit) to compare sims.
const ROOT = process.env.QA_GODOT_ROOT ? path.resolve(process.env.QA_GODOT_ROOT) : path.join(__dirname, '..', '..');

// $GODOT, then godot / godot4 on PATH, then the usual Windows install folders (docs/tools/README.md).
function findGodot() {
  const cands = [];
  if (process.env.GODOT) cands.push(process.env.GODOT);
  cands.push('godot', 'godot4');
  if (process.platform === 'win32' && process.env.LOCALAPPDATA) {
    const base = path.join(process.env.LOCALAPPDATA, 'Programs', 'Godot');
    if (fs.existsSync(base)) for (const d of fs.readdirSync(base).filter(n => /^4\.7/.test(n) && !/mono/.test(n)).sort().reverse()) {
      for (const f of fs.readdirSync(path.join(base, d))) if (/console\.exe$/.test(f) && !/mono/i.test(f)) cands.push(path.join(base, d, f));
    }
  }
  for (const c of cands) {
    const r = spawnSync(c, ['--version'], { encoding: 'utf8' });
    if (!r.error && r.status === 0 && /^4\./.test((r.stdout || '').trim())) return { exe: c, version: r.stdout.trim() };
  }
  return null;
}

let cached;
const godot = () => (cached === undefined ? (cached = findGodot()) : cached);

// Run `count` matches of `arm` from `base` over `jobs` Godot processes. Resolves to the records in seed order.
function runRecords({ arm = 'default', base = 1, count = 100, jobs = Math.max(1, Math.min(6, os.cpus().length - 1)), capSec = 900, quiet = false }) {
  const g = godot();
  if (!g) return Promise.reject(new Error('Godot 4.7 not found. Set GODOT to the console executable, e.g. C:\\...\\Godot_v4.7.2-stable_win64_console.exe'));
  jobs = Math.max(1, Math.min(jobs, count));
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'meridian-qa-godot-'));
  const blocks = [];
  let start = base;
  for (let j = 0; j < jobs; j++) { const n = Math.floor(count / jobs) + (j < count % jobs ? 1 : 0); blocks.push({ n, start, out: path.join(dir, `rec_${j}.json`) }); start += n; }
  const t0 = Date.now();
  return Promise.all(blocks.map(b => new Promise((resolve, reject) => {
    const args = ['--headless', '--path', ROOT, '--script', 'res://qa/godot/records.gd', '--', String(b.n), String(b.start), `--arm=${arm}`, `--out=${b.out.replace(/\\/g, '/')}`, `--capsec=${capSec}`];
    const p = spawn(g.exe, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let err = '';
    p.stdout.on('data', d => { err += d; }); p.stderr.on('data', d => { err += d; });
    p.on('error', reject);
    p.on('close', code => (code === 0 && fs.existsSync(b.out) ? resolve() : reject(new Error(`records.gd exited ${code} for seeds ${b.start}..${b.start + b.n - 1}\n${err.split('\n').filter(l => !/^Godot Engine/.test(l)).join('\n').slice(0, 2000)}`))));
  }))).then(() => {
    const recs = blocks.flatMap(b => JSON.parse(fs.readFileSync(b.out, 'utf8')));
    fs.rmSync(dir, { recursive: true, force: true });
    if (!quiet) process.stderr.write(`  ${arm}: ${count} matches from seed ${base} in ${((Date.now() - t0) / 1000).toFixed(0)} s (${jobs} jobs)\n`);
    return recs;
  }, e => { fs.rmSync(dir, { recursive: true, force: true }); throw e; });
}

module.exports = { findGodot, godot, runRecords, ROOT };
