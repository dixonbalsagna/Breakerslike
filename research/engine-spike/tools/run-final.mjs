// Final timed runs for the engine spike. Every configuration runs one after another (never in parallel).
//   node research/engine-spike/tools/run-final.mjs [--runs 3] [--only <substring>] [--skip <substring>] [--dry] [--label <text>]
// For each run it records the concurrent load (CPU % and counts of other heavy processes), the GPU the run actually used
// (and checks it is the intended one), the driver, vsync flags and power plan. Raw per-frame times are saved as CSV.
// Outputs: results/final/raw/<config>-r<n>.{json,csv} and results/final/summary.{json,md} (median of runs).
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const SPIKE = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const GODOT_DIR = 'C:\\Users\\itsha\\AppData\\Local\\Programs\\Godot\\4.7.2';
const GODOT = join(GODOT_DIR, 'Godot_v4.7.2-stable_win64.exe');
const GODOT_CON = join(GODOT_DIR, 'Godot_v4.7.2-stable_win64_console.exe');
const RELEASE = join(SPIKE, 'godot', 'build', 'win', 'spike.exe');
const PORT = 8631, BASE = `http://127.0.0.1:${PORT}`;
const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : d; };
const RUNS = Number(opt('--runs', 3)), ONLY = opt('--only', ''), SKIP = opt('--skip', ''), DRY = argv.includes('--dry');
// Godot --gpu-index values from `--verbose` on this machine (D3D12 and Vulkan agree): #0 RTX 5070 Ti, #1 AMD Radeon iGPU.
const DGPU_INDEX = opt('--dgpu-index', '0'), IGPU_INDEX = opt('--igpu-index', '1');
const LABEL = opt('--label', 'quiet window (EP, 2026-09-29: most sessions idle); load recorded per run');
const OUT = join(SPIKE, 'results', 'final'), RAW = join(OUT, 'raw');
mkdirSync(RAW, { recursive: true });

const godotArgs = (method, driver, extra = []) => ['--resolution', '1920x1080', '--disable-vsync', '--max-fps', '0',
  '--rendering-method', method, ...(driver ? ['--rendering-driver', driver] : []), ...extra];
const bench = out => ['--', '--bench', '--scene', 'worst', '--out', out];
const dg = ['--gpu-index', DGPU_INDEX], ig = ['--gpu-index', IGPU_INDEX];
const WEB_URL = `${BASE}/web/index.html?bench=1&scene=worst`, GWEB_URL = `${BASE}/godot/build/web/index.html?bench=1&scene=worst`;

// Primary runs force the discrete GPU (Godot --gpu-index 0; Chrome/Edge --force_high_performance_gpu). OpenGL
// (Compatibility) cannot take --gpu-index; its adapter is whatever the driver picks for the display, and is recorded.
// The integrated Radeon (2 CUs) is the minimum-spec stand-in. Every run's reported GPU string is checked; a run that
// did not land on the intended GPU is flagged in the summary, not silently counted.
const CONFIGS = [
  { name: 'godot-release-forward_plus-d3d12', kind: 'proc', exe: RELEASE, args: o => [...godotArgs('forward_plus', 'd3d12', dg), ...bench(o)] },
  { name: 'godot-release-forward_plus-vulkan', kind: 'proc', exe: RELEASE, args: o => [...godotArgs('forward_plus', 'vulkan', dg), ...bench(o)] },
  { name: 'godot-release-compat-opengl3', kind: 'proc', exe: RELEASE, args: o => [...godotArgs('gl_compatibility', 'opengl3'), ...bench(o)] },
  { name: 'godot-release-mobile-vulkan', kind: 'proc', exe: RELEASE, args: o => [...godotArgs('mobile', 'vulkan', dg), ...bench(o)] },
  { name: 'godot-editor-forward_plus-d3d12', kind: 'proc', exe: GODOT, args: o => ['--path', join(SPIKE, 'godot'), ...godotArgs('forward_plus', 'd3d12', dg), ...bench(o)] },
  { name: 'godot-web-chrome', kind: 'browser', url: GWEB_URL, browser: 'chrome', flags: ['--force_high_performance_gpu'] },
  { name: 'web-chrome', kind: 'browser', url: WEB_URL, browser: 'chrome', flags: ['--force_high_performance_gpu'] },
  { name: 'web-edge', kind: 'browser', url: WEB_URL, browser: 'edge', flags: ['--force_high_performance_gpu'] },
  { name: 'igpu-godot-release-forward_plus-d3d12', kind: 'proc', exe: RELEASE, igpu: true, args: o => [...godotArgs('forward_plus', 'd3d12', ig), ...bench(o)] },
  { name: 'igpu-godot-release-forward_plus-vulkan', kind: 'proc', exe: RELEASE, igpu: true, args: o => [...godotArgs('forward_plus', 'vulkan', ig), ...bench(o)] },
  { name: 'igpu-godot-release-mobile-vulkan', kind: 'proc', exe: RELEASE, igpu: true, args: o => [...godotArgs('mobile', 'vulkan', ig), ...bench(o)] },
  { name: 'igpu-godot-web-chrome', kind: 'browser', url: GWEB_URL, browser: 'chrome', igpu: true, flags: ['--force_low_power_gpu'] },
  { name: 'igpu-web-chrome', kind: 'browser', url: WEB_URL, browser: 'chrome', igpu: true, flags: ['--force_low_power_gpu'] },
];
const SIMBENCH = [
  { name: 'simbench-node', cmd: process.execPath, args: [join(SPIKE, 'shared', 'test-ref.mjs'), '--bench'], parse: 'SIMBENCH ' },
  { name: 'simbench-gdscript-editor', cmd: GODOT_CON, args: ['--headless', '--path', join(SPIKE, 'godot'), '-s', 'res://tests/run_tests.gd', '--', '--bench'], parse: 'SIMBENCH ' },
  { name: 'simbench-gdscript-release', cmd: RELEASE, args: ['--headless', '--', '--simbench', '--out', '@OUT'], parse: '@FILE' },
  { name: 'simbench-dotnet', cmd: 'dotnet', args: ['run', '-c', 'Release', '--project', join(SPIKE, 'csharp', 'SimPort'), '--', '--bench'], parse: 'SIMBENCH ' },
];

// PowerShell exits non-zero when e.g. Get-Process finds no process for one of several names; keep stdout anyway.
function ps(cmd) {
  const r = spawnSync('powershell', ['-NoProfile', '-Command', cmd], { encoding: 'utf8', timeout: 30000 });
  const s = (r.stdout || '').trim();
  return s.length ? s : null;
}
function cpuLoad() {
  const s = ps("(Get-Counter '\\Processor(_Total)\\% Processor Time' -SampleInterval 1 -MaxSamples 3).CounterSamples | Measure-Object CookedValue -Average | % { [math]::Round($_.Average,1) }");
  return s === null ? null : Number(s);
}
function loadSnapshot() {
  const counts = ps("Get-Process node,Godot*,spike,chrome,msedge,dotnet,claude -ErrorAction SilentlyContinue | Group-Object ProcessName | % { $_.Name + '=' + $_.Count }");
  return { cpuPercent: cpuLoad(), processes: counts ? counts.split(/\r?\n/) : [] };
}
function sysInfo() {
  const gpus = ps("Get-CimInstance Win32_VideoController | % { $_.Name + ' | driver ' + $_.DriverVersion }");
  return {
    cpu: ps('(Get-CimInstance Win32_Processor).Name'),
    gpus: gpus ? gpus.split(/\r?\n/) : null,
    powerPlan: ps('powercfg /getactivescheme'),
    os: ps("(Get-CimInstance Win32_OperatingSystem).Caption + ' ' + (Get-CimInstance Win32_OperatingSystem).Version"),
    node: process.version,
    vsync: 'off: Godot --disable-vsync --max-fps 0 (project vsync_mode=0); browsers --disable-gpu-vsync --disable-frame-rate-limit',
  };
}
function run(cmd, args, timeoutMs, opts = {}) {
  return new Promise(res => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'], ...opts });
    let out = '', err = '';
    p.stdout.on('data', d => out += d); p.stderr.on('data', d => err += d);
    const t = setTimeout(() => { p.kill(); err += '\nTIMEOUT'; }, timeoutMs);
    p.on('close', code => { clearTimeout(t); res({ code, out, err }); });
  });
}
const med = a => { const s = a.filter(v => typeof v === 'number' && isFinite(v)).sort((x, y) => x - y); return s.length ? s[(s.length - 1) >> 1] : null; };

let server = null;
async function ensureServer() {
  if (server) return;
  server = spawn(process.execPath, [join(SPIKE, 'tools', 'serve.mjs'), '--port', String(PORT)], { stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 800));
}

const want = n => (!ONLY || n.includes(ONLY)) && (!SKIP || !n.includes(SKIP));
const summary = { when: new Date().toISOString(), runs: RUNS, label: LABEL, system: sysInfo(), configs: {}, simbench: {} };
console.log(JSON.stringify(summary.system));

for (const c of CONFIGS) {
  if (!want(c.name)) continue;
  const rec = [];
  for (let r = 1; r <= RUNS; r++) {
    const out = join(RAW, `${c.name}-r${r}.json`);
    const load = loadSnapshot();
    console.log(`[${c.name} r${r}] load before: ${load.cpuPercent}% cpu; ${load.processes.join(' ')}`);
    if (DRY) continue;
    let res;
    if (c.kind === 'proc') {
      if (!existsSync(c.exe)) { console.log('  missing ' + c.exe); break; }
      res = await run(c.exe, c.args(out), 300000);
    } else {
      await ensureServer();
      const flags = (c.flags || []).flatMap(f => ['--flag', f]);
      res = await run(process.execPath, [join(SPIKE, 'tools', 'bench-browser.mjs'), '--url', c.url, '--out', out, '--browser', c.browser, '--timeout', '300', ...flags], 360000);
    }
    let j = null;
    try { j = JSON.parse(readFileSync(out, 'utf8')); } catch { console.log('  no result: ' + ((res && (res.err || res.out)) || '').slice(-600)); }
    if (!j) continue;
    j.loadBefore = load; j.cpuLoadBefore = load.cpuPercent; j.label = LABEL;
    j.runArgs = c.kind === 'proc' ? c.args('<out>') : (c.flags || []);
    const gs = String(j.gpu || '');
    j.gpuCheck = c.igpu ? /AMD|Radeon/i.test(gs) : /NVIDIA|RTX/i.test(gs);
    if (!j.gpuCheck) console.log(`  WARNING: expected ${c.igpu ? 'the iGPU' : 'the RTX'} but the run reports "${gs}"`);
    const ft = j.frameTimesMs || null;
    if (Array.isArray(ft)) {
      const csv = out.replace(/\.json$/, '.csv');
      writeFileSync(csv, 'frame,ms\n' + ft.map((v, i) => `${i},${v}`).join('\n') + '\n');
      delete j.frameTimesMs; j.frameTimesCsv = csv.split(/[\\/]/).pop();
    } else console.log('  WARNING: result has no frameTimesMs array');
    writeFileSync(out, JSON.stringify(j, null, 2));
    rec.push(j);
    console.log(`  avg ${j.frameMs.avg.toFixed(3)} ms  p95 ${j.frameMs.p95.toFixed(3)}  p99 ${j.frameMs.p99.toFixed(3)}  fps ${Math.round(j.fps)}  hash ${j.hashMatch}  gpu ${gs}`);
  }
  if (rec.length) summary.configs[c.name] = {
    runs: rec.length, gpu: rec[0].gpu, driver: rec[0].driver || rec[0].renderingDriver || null, renderer: rec[0].renderer,
    build: rec[0].build, browser: rec[0].browser || null,
    avgMs: med(rec.map(j => j.frameMs.avg)), p50Ms: med(rec.map(j => j.frameMs.p50)), p95Ms: med(rec.map(j => j.frameMs.p95)),
    p99Ms: med(rec.map(j => j.frameMs.p99)), maxMs: med(rec.map(j => j.frameMs.max)), fps: med(rec.map(j => j.fps)),
    gpuMs: med(rec.map(j => j.subMs && j.subMs.gpu ? j.subMs.gpu.avg : null)),
    simMs: med(rec.map(j => j.subMs && j.subMs.sim ? j.subMs.sim.avg : null)),
    uploadMs: med(rec.map(j => j.subMs && j.subMs.upload ? j.subMs.upload.avg : null)),
    particlesLiveAvg: med(rec.map(j => j.particles ? j.particles.liveAvg : null)),
    hashMatchAll: rec.every(j => j.hashMatch === true), gpuCheckAll: rec.every(j => j.gpuCheck === true),
    cpuLoadBefore: rec.map(j => j.cpuLoadBefore), processesBefore: rec.map(j => j.loadBefore.processes.join(' ')),
    runAvgMs: rec.map(j => +j.frameMs.avg.toFixed(3)), runP95Ms: rec.map(j => +j.frameMs.p95.toFixed(3)),
  };
}

for (const s of SIMBENCH) {
  if (!want(s.name) || DRY) continue;
  const rec = [];
  for (let r = 1; r <= RUNS; r++) {
    const out = join(RAW, `${s.name}-r${r}.json`);
    if (s.cmd === RELEASE && !existsSync(RELEASE)) { console.log('  missing ' + RELEASE); break; }
    const load = loadSnapshot();
    const res = await run(s.cmd, s.args.map(a => a === '@OUT' ? out : a), 900000, { cwd: SPIKE });
    let j = null;
    if (s.parse === '@FILE') { try { j = JSON.parse(readFileSync(out, 'utf8')); } catch {} }
    else { const line = (res.out || '').split(/\r?\n/).find(l => l.startsWith(s.parse)); if (line) j = JSON.parse(line.slice(s.parse.length)); }
    if (j) { j.loadBefore = load; writeFileSync(out, JSON.stringify(j, null, 2)); rec.push(j); console.log(`[${s.name} r${r}] ${JSON.stringify(j)}`); }
    else console.log(`[${s.name} r${r}] no result: ${(res.err || res.out).slice(-400)}`);
  }
  if (rec.length) summary.simbench[s.name] = { runs: rec.length, stack: rec[0].stack, worstTickUs: med(rec.map(j => j.worstTickUs)), terrainGenMs: med(rec.map(j => j.terrainGenMs)), cpuLoadBefore: rec.map(j => j.loadBefore.cpuPercent) };
}
if (server) server.kill();
if (DRY) process.exit(0);

// Merge with any earlier summary so partial reruns (--only) keep the other rows.
const SJ = join(OUT, 'summary.json');
let prev = {};
try { prev = JSON.parse(readFileSync(SJ, 'utf8')); } catch {}
const merged = { ...prev, when: summary.when, runs: RUNS, label: LABEL, system: summary.system,
  configs: { ...(prev.configs || {}), ...summary.configs }, simbench: { ...(prev.simbench || {}), ...summary.simbench } };
writeFileSync(SJ, JSON.stringify(merged, null, 2) + '\n');
const f = v => v === null || v === undefined ? 'n/a' : (+v).toFixed(2);
let md = `# Final timed runs (worst-case scene, 1920x1080, vsync off)\n\nConditions: ${merged.label}.\n\nSystem: ${merged.system.cpu}; ${(merged.system.gpus || []).join('; ')}; ${merged.system.os}; ${merged.system.powerPlan}; vsync ${merged.system.vsync}.\n\n`;
md += `Median of ${RUNS} runs per configuration. Each run: 3 s warm-up, then every frame while sim ticks 181 to 1980 (30 s of sim time). Frame time = interval between frame starts. Generated by tools/run-final.mjs, ${merged.when}. Rerun one row: \`node research/engine-spike/tools/run-final.mjs --only <configuration>\`. Raw per-frame times: results/final/raw/<configuration>-r<run>.csv.\n\n`;
md += '| Configuration | GPU used (check) | avg ms | p95 ms | p99 ms | max ms | fps | GPU ms | hash ok | CPU % before runs |\n|---|---|---|---|---|---|---|---|---|---|\n';
for (const [k, v] of Object.entries(merged.configs)) md += `| ${k} | ${v.gpu || ''} (${v.gpuCheckAll ? 'ok' : 'NOT intended'}) | ${f(v.avgMs)} | ${f(v.p95Ms)} | ${f(v.p99Ms)} | ${f(v.maxMs)} | ${v.fps ? Math.round(v.fps) : 'n/a'} | ${f(v.gpuMs)} | ${v.hashMatchAll ? 'yes' : 'NO'} | ${(v.cpuLoadBefore || []).join(', ')} |\n`;
md += '\n## Sim throughput (worst scene, no rendering)\n\n| Runtime | µs per tick | terrain generation ms |\n|---|---|---|\n';
for (const [k, v] of Object.entries(merged.simbench)) md += `| ${k} (${v.stack}) | ${f(v.worstTickUs)} | ${f(v.terrainGenMs)} |\n`;
writeFileSync(join(OUT, 'summary.md'), md);
console.log(md);
