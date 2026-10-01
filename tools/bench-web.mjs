// Web frame-time bench with an "old laptop" range. Node 24 built-ins only (global fetch and WebSocket).
//
//   node tools/bench-web.mjs --dir <built site dir> [options]     serve the site (from tools/build-site.mjs) and bench /bench/
//   node tools/bench-web.mjs --url <bench page url> [options]     bench a page that is already served (for example the deployed /bench/)
//
//   --cpu-throttle 4,6     CPU slowdown factors to run, each in a fresh browser (default 4,6; 1 is the baseline, always run first)
//   --floor                also run once with software rendering (SwiftShader): a GPU-free floor, not a laptop
//   --no-baseline          skip the unthrottled run
//   --query "nosplit&novfx"  page query string (the /bench/ page reads nosplit, novfx, noragdoll, noclouds,
//                          anim-quality=high|medium|low|minimal and frames=N)
//   --frames N             shorthand for frames=N in the query
//   --width 1366 --height 768   viewport (default: a common laptop screen)
//   --path /bench/         page path when --dir is used
//   --browser chrome|edge  --browser-path <exe>   --timeout 600 (seconds per run)
//   --out <file.json>      write every run's full result (no clock in it, so equal runs give equal files)
//
// Each run launches the browser with a fresh temporary profile (never yours), applies Chrome's CPU throttle
// (Emulation.setCPUThrottlingRate), loads the bench page, waits for window.__benchResult, and always closes the
// browser and deletes the profile. Exit code 0 when every run produced a result, 1 otherwise, 2 on bad usage.
//
// Read the output as a RANGE, not a measurement. The throttle slows the browser's CPU work (the wasm simulation, and
// the engine building each frame's draw calls), which is the likely limit for this game, but it does not model a slow
// integrated GPU, memory or a thermally limited laptop. SwiftShader is a pessimistic GPU-free floor. The real number
// is the /bench/ page run on an actual old laptop. Docs: docs/tools/README.md
import { spawn, spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir, platform, cpus } from 'node:os';
import { join, extname, resolve, sep } from 'node:path';

const argv = process.argv.slice(2);
const opt = (n, d) => {
  const i = argv.indexOf(n);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : d;
};
const has = (n) => argv.includes(n);
const usage = () => {
  console.error('usage: node tools/bench-web.mjs (--dir <site dir> | --url <bench page url>) [--cpu-throttle 4,6] [--floor] [--no-baseline]\n' +
    '       [--query "nosplit&novfx"] [--frames N] [--width 1366 --height 768] [--path /bench/] [--browser chrome|edge]\n' +
    '       [--browser-path <exe>] [--timeout 600] [--out <file.json>]');
  process.exit(2);
};
const known = new Set(['--dir', '--url', '--cpu-throttle', '--floor', '--no-baseline', '--query', '--frames', '--width', '--height', '--path', '--browser', '--browser-path', '--timeout', '--out']);
for (const a of argv) if (a.startsWith('--') && !known.has(a)) { console.error(`unknown option ${a}`); usage(); }

const DIR = opt('--dir'), URL_ = opt('--url');
if ((!DIR && !URL_) || (DIR && URL_)) usage();
const throttles = String(opt('--cpu-throttle', '4,6')).split(',').map((s) => Number(s.trim())).filter((n) => n > 1);
if (String(opt('--cpu-throttle', '4,6')).split(',').some((s) => !(Number(s) >= 1))) { console.error('--cpu-throttle takes numbers of 1 or more, like 4,6'); usage(); }
const WIDTH = Number(opt('--width', 1366)), HEIGHT = Number(opt('--height', 768));
const TIMEOUT_S = Number(opt('--timeout', 600));
const OUT = opt('--out');
let query = opt('--query', '');
if (opt('--frames')) query += `${query ? '&' : ''}frames=${Number(opt('--frames'))}`;

const EXES = {
  win32: {
    chrome: ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'],
    edge: ['C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe', 'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'],
  },
  darwin: {
    chrome: ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'],
    edge: ['/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'],
  },
  linux: { chrome: ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'], edge: ['/usr/bin/microsoft-edge'] },
};
const BROWSER = opt('--browser', 'chrome');
const exe = opt('--browser-path') || ((EXES[platform()] || EXES.linux)[BROWSER] || []).find((p) => existsSync(p));
if (!exe) { console.error(`no ${BROWSER} executable found; pass --browser-path`); process.exit(2); }

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (m) => console.log(`[bench-web] ${m}`);

// ---------------------------------------------------------------- a tiny static server for --dir
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.json': 'application/json', '.pck': 'application/octet-stream' };
function serve(root) {
  const base = resolve(root);
  const server = createServer((req, res) => {
    let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (p.endsWith('/')) p += 'index.html';
    const file = resolve(join(base, p));
    if (!(file === base || file.startsWith(base + sep)) || !existsSync(file) || !statSync(file).isFile()) {
      res.writeHead(404);
      res.end('not found');
      return;
    }
    res.writeHead(200, { 'content-type': MIME[extname(file)] || 'application/octet-stream' });
    res.end(readFileSync(file));
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok(server)));
}

// ---------------------------------------------------------------- a minimal DevTools protocol client
class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener('message', (e) => {
      const m = JSON.parse(e.data);
      if (m.id && this.pending.has(m.id)) {
        const { ok, fail } = this.pending.get(m.id);
        this.pending.delete(m.id);
        if (m.error) fail(new Error(`${m.error.message}`)); else ok(m.result);
      }
    });
  }
  static open(url) {
    return new Promise((ok, fail) => {
      const ws = new WebSocket(url);
      ws.addEventListener('open', () => ok(new Cdp(ws)));
      ws.addEventListener('error', () => fail(new Error('DevTools socket error')));
    });
  }
  send(method, params = {}) {
    const id = ++this.id;
    return new Promise((ok, fail) => {
      this.pending.set(id, { ok, fail });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  async eval(expression) {
    const r = await this.send('Runtime.evaluate', { expression, returnByValue: true });
    return r.result ? r.result.value : undefined;
  }
  close() { try { this.ws.close(); } catch { /* already closed */ } }
}

// ---------------------------------------------------------------- one run
async function oneRun(run, url) {
  const profile = mkdtempSync(join(tmpdir(), 'bench-web-'));
  const flags = [
    `--user-data-dir=${profile}`, '--remote-debugging-port=0',
    '--disable-gpu-vsync', '--disable-frame-rate-limit',
    '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows',
    '--no-first-run', '--no-default-browser-check', '--disable-extensions', '--disable-sync', '--disable-component-update',
    `--window-size=${WIDTH + 20},${HEIGHT + 140}`, '--window-position=0,0',
    ...run.flags, 'about:blank',
  ];
  const child = spawn(exe, flags, { stdio: 'ignore', detached: false });
  const cleanup = () => {
    try {
      if (platform() === 'win32') spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore', timeout: 15000 });
      else child.kill('SIGKILL');
    } catch { /* already gone */ }
    for (let i = 0; i < 5; i++) {
      try { rmSync(profile, { recursive: true, force: true }); break; } catch { spawnSync(process.execPath, ['-e', 'setTimeout(()=>{},400)']); }
    }
  };
  let page;
  try {
    const portFile = join(profile, 'DevToolsActivePort');
    let port;
    for (let i = 0; i < 100 && !port; i++) {
      if (existsSync(portFile)) port = Number(readFileSync(portFile, 'utf8').split('\n')[0]);
      else await sleep(200);
    }
    if (!port) throw new Error('the browser did not open a DevTools port in 20 s');
    let target;
    for (let i = 0; i < 50 && !target; i++) {
      try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === 'page'); } catch { /* not up yet */ }
      if (!target) await sleep(200);
    }
    if (!target) throw new Error('no page target');
    page = await Cdp.open(target.webSocketDebuggerUrl);
    await page.send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false });
    await page.send('Emulation.setCPUThrottlingRate', { rate: run.throttle });
    await page.send('Page.navigate', { url });
    const deadline = Date.now() + TIMEOUT_S * 1000;
    let result = null;
    while (Date.now() < deadline) {
      await sleep(1000);
      const s = await page.eval('JSON.stringify(window.__benchResult || null)').catch(() => null);
      if (s && s !== 'null') { result = JSON.parse(s); break; }
    }
    if (!result) throw new Error(`no result within ${TIMEOUT_S} s`);
    const info = await page.eval(`(() => { let r = 'unavailable'; try { const gl = document.createElement('canvas').getContext('webgl2'); const e = gl && gl.getExtension('WEBGL_debug_renderer_info'); if (e) r = gl.getParameter(e.UNMASKED_RENDERER_WEBGL); } catch (e) {} return { browser: navigator.userAgent, cores: navigator.hardwareConcurrency, renderer: r }; })()`);
    return { result, info };
  } finally {
    if (page) page.close();
    cleanup();
  }
}

// "mean 3.419  p50 2.500  p95 4.700  p99 6.500  max 744.600" -> { mean, p50, p95, p99, max }
function stats(text) {
  const out = {};
  for (const m of String(text || '').matchAll(/(mean|p50|p95|p99|max)\s+([0-9.]+)/g)) out[m[1]] = Number(m[2]);
  return out;
}

// ---------------------------------------------------------------- main
const swiftshader = ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
const runs = [];
if (!has('--no-baseline')) runs.push({ name: 'baseline (no throttle)', throttle: 1, flags: [] });
for (const t of throttles) runs.push({ name: `CPU x${t}`, throttle: t, flags: [] });
if (has('--floor')) runs.push({ name: 'SwiftShader (no GPU), no throttle', throttle: 1, flags: swiftshader, floor: true });
if (!runs.length) { console.error('nothing to run'); usage(); }

let server;
let pageUrl = URL_;
if (DIR) {
  server = await serve(DIR);
  pageUrl = `http://127.0.0.1:${server.address().port}${opt('--path', '/bench/')}`;
}
if (query) pageUrl += (pageUrl.includes('?') ? '&' : '?') + query;
log(`page ${pageUrl}; ${WIDTH}x${HEIGHT}; ${cpus()[0].model.trim()}; ${runs.length} run${runs.length === 1 ? '' : 's'}`);

const done = [];
let failed = false;
try {
  for (const run of runs) {
    log(`running: ${run.name}`);
    try {
      const { result, info } = await oneRun(run, pageUrl);
      done.push({ run, frame: stats(result['frame ms (vsync off)']), result, info });
    } catch (e) {
      failed = true;
      log(`FAILED ${run.name}: ${e.message}`);
      done.push({ run, error: e.message });
    }
  }
} finally {
  if (server) server.close();
}

const ok = done.filter((d) => !d.error);
const row = (d) => `${d.run.name.padEnd(34)} ${String(d.frame.mean ?? '?').padStart(8)} ${String(d.frame.p50 ?? '?').padStart(7)} ${String(d.frame.p95 ?? '?').padStart(7)} ${String(d.frame.p99 ?? '?').padStart(7)} ${String(d.frame.max ?? '?').padStart(9)}`;
console.log('');
console.log(`${'frame ms (vsync off)'.padEnd(34)} ${'mean'.padStart(8)} ${'p50'.padStart(7)} ${'p95'.padStart(7)} ${'p99'.padStart(7)} ${'max'.padStart(9)}`);
for (const d of ok) console.log(row(d));
for (const d of done.filter((x) => x.error)) console.log(`${d.run.name.padEnd(34)} FAILED: ${d.error}`);

const hashes = new Set(ok.map((d) => d.result.hash));
if (hashes.size > 1) console.log(`\nWARNING: the gameplay hash differs between runs (${[...hashes].join(', ')}); the runs did not play the same match.`);
const byName = (n) => ok.find((d) => d.run.name === n);
const lo = byName(`CPU x${throttles[0]}`);
const hi = byName(`CPU x${throttles[throttles.length - 1]}`);
const floor = ok.find((d) => d.run.floor);
console.log('');
if (lo && hi) {
  console.log(`Old-laptop range (CPU side only): mean ${lo.frame.mean} to ${hi.frame.mean} ms, p95 ${lo.frame.p95} to ${hi.frame.p95} ms, p99 ${lo.frame.p99} to ${hi.frame.p99} ms, at CPU x${throttles[0]} to x${throttles[throttles.length - 1]}.`);
  const budget = 1000 / 60;
  console.log(`  A 60 fps frame is ${budget.toFixed(1)} ms: the slower end's p95 ${hi.frame.p95 <= budget ? 'fits' : 'does NOT fit'} it.`);
}
if (floor) console.log(`GPU-free floor (SwiftShader software rendering): mean ${floor.frame.mean} ms, p95 ${floor.frame.p95} ms. Pessimistic: no real laptop GPU is this slow.`);
console.log('This is a proxy, not a measurement: it does not model a slow integrated GPU or memory. The real number is the /bench/ page run on an old laptop.');

if (OUT) {
  writeFileSync(OUT, `${JSON.stringify({ page: pageUrl, viewport: [WIDTH, HEIGHT], runs: done.map((d) => ({ name: d.run.name, throttle: d.run.throttle, floor: Boolean(d.run.floor), error: d.error, frame: d.frame, info: d.info, result: d.result })) }, null, 2)}\n`);
  log(`wrote ${OUT}`);
}
process.exit(failed ? 1 : 0);
