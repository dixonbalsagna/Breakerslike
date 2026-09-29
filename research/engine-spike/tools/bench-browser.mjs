// Chrome/Edge benchmark driver over the DevTools protocol. No dependencies (Node 24: global WebSocket and fetch).
// Generic: it drives any page that publishes a result object on window (the web spike, and the Godot web export).
//   node research/engine-spike/tools/bench-browser.mjs --url <url> --out <json> [--browser chrome|edge]
//        [--width 1920 --height 1080] [--timeout 240] [--shot <png>] [--wait-for __benchResult|__testResult|__shotResult]
//        [--flag <extra browser flag>]... [--browser-path <exe>]
// It launches the browser with a fresh temporary profile (never the user's), vsync and frame-rate limits off and
// background throttling off, sets the viewport to width x height at deviceScaleFactor 1, navigates, polls
// window[<wait-for>] (or window.__spikeError), then adds the browser version, the unmasked WebGL renderer string, the
// browser's GPU list and the canvas size, optionally captures a PNG, and always closes the browser and deletes the
// temporary profile. GPU selection is left to the flags (for example --flag --force_high_performance_gpu).
// Exit code: 0 on a result (and hashMatch/pass not false), 1 otherwise.
import { spawn, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir, cpus, version as osVersion, release as osRelease, platform } from 'node:os';
import { join, dirname, resolve, basename } from 'node:path';

const argv = process.argv.slice(2);
const opt = (n, d) => { const i = argv.indexOf(n); return i >= 0 && i + 1 < argv.length ? argv[i + 1] : d; };
const extraFlags = [];
for (let i = 0; i < argv.length; i++) if (argv[i] === '--flag' && i + 1 < argv.length) extraFlags.push(argv[++i]);

const URL_ = opt('--url'), OUT = opt('--out'), SHOT = opt('--shot');
const BROWSER = opt('--browser', 'chrome'), WIDTH = Number(opt('--width', 1920)), HEIGHT = Number(opt('--height', 1080));
const TIMEOUT_S = Number(opt('--timeout', 240)), WAIT_FOR = opt('--wait-for', '__benchResult');
if (!URL_ || !OUT) {
  console.error('usage: node bench-browser.mjs --url <url> --out <json> [--browser chrome|edge] [--width 1920 --height 1080] ' +
    '[--timeout 240] [--shot <png>] [--wait-for __benchResult] [--flag <browser flag>]... [--browser-path <exe>]');
  process.exit(2);
}
if (!/^__\w+$/.test(WAIT_FOR)) { console.error('--wait-for must be a window property like __benchResult'); process.exit(2); }

const EXES = {
  win32: {
    chrome: ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'],
    edge: ['C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe', 'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'],
  },
  darwin: {
    chrome: ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'],
    edge: ['/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'],
  },
  linux: { chrome: ['/usr/bin/google-chrome', '/usr/bin/chromium'], edge: ['/usr/bin/microsoft-edge'] },
};
const exe = opt('--browser-path') || ((EXES[platform()] || EXES.linux)[BROWSER] || []).find(p => existsSync(p));
if (!exe) { console.error(`no ${BROWSER} executable found; pass --browser-path`); process.exit(2); }

const sleep = ms => new Promise(r => setTimeout(r, ms));
const log = m => console.log(`[bench-browser] ${m}`);
// Same rule as web/src/bench.ts angleBackend(): the ANGLE backend named in the unmasked renderer string, else null.
const angleBackend = s => {
  if (!/^ANGLE \(/.test(s || '')) return null;
  const m = /,\s*(D3D11on12|D3D11|D3D9|Vulkan|OpenGL ES|OpenGL|Metal|SwiftShader)[^,()]*\)\s*$/.exec(s);
  if (m) return m[1];
  for (const k of ['Metal', 'Vulkan', 'SwiftShader', 'D3D11', 'OpenGL']) if (s.includes(k)) return k;
  return 'unknown';
};

// ------------------------------------------------------------------ minimal CDP client over a WebSocket
class Cdp {
  constructor(url) { this.url = url; this.id = 0; this.wait = new Map(); this.handlers = []; this.closed = false; }
  open() {
    return new Promise((res, rej) => {
      const ws = this.ws = new WebSocket(this.url);
      ws.onopen = () => res(this);
      ws.onerror = e => rej(new Error('CDP socket error: ' + (e.message || e.type)));
      ws.onclose = () => { this.closed = true; for (const [, w] of this.wait) w.rej(new Error('CDP socket closed')); this.wait.clear(); };
      ws.onmessage = ev => {
        const m = JSON.parse(typeof ev.data === 'string' ? ev.data : Buffer.from(ev.data).toString());
        if (m.id !== undefined) {
          const w = this.wait.get(m.id); if (!w) return; this.wait.delete(m.id);
          if (m.error) w.rej(new Error(`${w.method}: ${m.error.message}`)); else w.res(m.result);
        } else for (const h of this.handlers) h(m);
      };
    });
  }
  send(method, params = {}, timeoutMs = 30000) {
    const id = ++this.id;
    return new Promise((res, rej) => {
      const t = setTimeout(() => { this.wait.delete(id); rej(new Error(method + ': timed out')); }, timeoutMs);
      this.wait.set(id, { method, res: v => { clearTimeout(t); res(v); }, rej: e => { clearTimeout(t); rej(e); } });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }
  on(fn) { this.handlers.push(fn); }
  close() { try { this.ws.close(); } catch {} }
}

// ------------------------------------------------------------------ run
const profile = mkdtempSync(join(tmpdir(), 'spike-cdp-'));
const flags = [
  `--user-data-dir=${profile}`, '--remote-debugging-port=0',
  '--disable-gpu-vsync', '--disable-frame-rate-limit',
  '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows',
  '--no-first-run', '--no-default-browser-check', '--disable-extensions', '--disable-sync', '--disable-component-update',
  '--window-size=1940,1200', '--window-position=0,0',
  ...extraFlags, 'about:blank',
];
const t0 = Date.now();
log(`${BROWSER}: ${exe}`);
log(`flags: ${flags.slice(1).join(' ')}`);
// Edge's msedge.exe (and sometimes Chrome) hands off to a new browser process and exits, so the launcher PID is not the
// browser. The browser is tracked by its unique temporary profile path instead (see profilePids).
const proc = spawn(exe, flags, { stdio: 'ignore', detached: false });
let launcherExited = false;
proc.on('exit', () => { launcherExited = true; });
// Parses one PID per whitespace-separated token; anything that is not a positive integer is dropped.
const parsePids = s => (s || '').split(/\s+/).filter(Boolean).map(Number).filter(n => Number.isInteger(n) && n > 0);
function profilePids() {
  if (platform() !== 'win32') {
    const r = spawnSync('pgrep', ['-f', profile], { encoding: 'utf8', timeout: 10000 });
    return parsePids(r.stdout);
  }
  const needle = profile.replace(/'/g, "''"), exeName = basename(exe).replace(/'/g, "''");
  const r = spawnSync('powershell', ['-NoProfile', '-Command',
    `Get-CimInstance Win32_Process | Where-Object { $_.Name -eq '${exeName}' -and $_.CommandLine -and $_.CommandLine.Contains('${needle}') } | ForEach-Object { $_.ProcessId }`],
    { encoding: 'utf8', timeout: 30000 });
  if (r.error || r.status !== 0) log(`WARNING: the process query failed (${r.error ? r.error.message : 'exit ' + r.status}); the count may be wrong`);
  return parsePids(r.stdout);
}
let browser = null, page = null, code = 1;
const consoleLines = [];

async function cleanup() {
  log(`browser processes on the temp profile before close: ${profilePids().length}`);
  try { if (browser) await browser.send('Browser.close', {}, 5000).catch(() => {}); } catch {}
  if (page) page.close();
  if (browser) browser.close();
  let left = [];
  for (let i = 0; i < 10; i++) { left = profilePids(); if (!left.length) break; await sleep(300); }
  if (left.length) {
    log(`force-killing ${left.length} browser process(es) still using the temp profile: ${left.join(' ')}`);
    for (const pid of left) {
      if (platform() === 'win32') spawnSync('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore', timeout: 15000 });
      else try { process.kill(pid, 'SIGKILL'); } catch {}
    }
    await sleep(500);
    left = profilePids();
  }
  if (!launcherExited) try { proc.kill(); } catch {}
  const exited = left.length === 0;
  // Chrome's helper processes can hold profile files for a moment after the main process exits.
  for (let i = 0; i < 20; i++) {
    try { rmSync(profile, { recursive: true, force: true }); break; } catch { await sleep(250); }
  }
  log(`browser ${exited ? 'closed' : 'NOT confirmed closed'}; temp profile ${existsSync(profile) ? 'NOT removed: ' + profile : 'removed'}`);
}

const hardStop = setTimeout(async () => { log('hard timeout'); await cleanup(); process.exit(1); }, (TIMEOUT_S + 60) * 1000);

try {
  // Chrome writes the chosen debugging port to <profile>/DevToolsActivePort.
  const portFile = join(profile, 'DevToolsActivePort');
  let port = null;
  for (let i = 0; i < 200 && !port; i++) {
    if (existsSync(portFile)) { const s = readFileSync(portFile, 'utf8').split(/\r?\n/); if (s[0]) port = Number(s[0]); }
    if (!port) await sleep(100);
  }
  if (!port) throw new Error('no DevToolsActivePort after 20 s');
  const base = `http://127.0.0.1:${port}`;
  const ver = await (await fetch(`${base}/json/version`)).json();
  browser = await new Cdp(ver.webSocketDebuggerUrl).open();
  let target = null;
  for (let i = 0; i < 50 && !target; i++) {
    const list = await (await fetch(`${base}/json/list`)).json();
    target = list.find(t => t.type === 'page');
    if (!target) await sleep(100);
  }
  if (!target) throw new Error('no page target');
  page = await new Cdp(target.webSocketDebuggerUrl).open();
  page.on(m => {
    if (m.method === 'Runtime.exceptionThrown') consoleLines.push('exception: ' + (m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text));
    if (m.method === 'Runtime.consoleAPICalled' && (m.params.type === 'error' || m.params.type === 'warning'))
      consoleLines.push(`${m.params.type}: ` + m.params.args.map(a => a.value ?? a.description ?? '').join(' '));
  });
  await page.send('Runtime.enable');
  await page.send('Page.enable');
  await page.send('Emulation.setDeviceMetricsOverride', { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1, mobile: false });
  log(`${ver.Browser}; viewport ${WIDTH}x${HEIGHT} @1x; navigating to ${URL_}`);
  await page.send('Page.navigate', { url: URL_ });

  const evaluate = async expr => {
    const r = await page.send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true }, 60000);
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
    return r.result.value;
  };
  // Poll cheaply (a typeof check every 500 ms), then fetch the result once.
  const deadline = Date.now() + TIMEOUT_S * 1000;
  let state = null;
  while (Date.now() < deadline) {
    try { state = await evaluate(`(window.${WAIT_FOR} !== undefined) ? 'result' : (window.__spikeError !== undefined ? 'error' : '')`); }
    catch { state = ''; }                    // the context is being replaced during navigation
    if (state) break;
    if (page.closed) throw new Error('the page connection closed (browser crashed or was closed)');
    await sleep(500);
  }
  if (!state) throw new Error(`timed out after ${TIMEOUT_S} s waiting for window.${WAIT_FOR}` + (consoleLines.length ? '\n' + consoleLines.join('\n') : ''));
  if (state === 'error') throw new Error('page error: ' + (await evaluate('String(window.__spikeError)')));
  const result = JSON.parse(await evaluate(`JSON.stringify(window.${WAIT_FOR})`));

  // Metadata: unmasked WebGL renderer (a fresh context in the same page and GPU process), canvas size, GPU list.
  const gl = await evaluate(`(() => { try { const c = document.createElement('canvas'); const g = c.getContext('webgl2') || c.getContext('webgl');
    if (!g) return null; const d = g.getExtension('WEBGL_debug_renderer_info');
    const r = { renderer: d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) : g.getParameter(g.RENDERER),
      vendor: d ? g.getParameter(d.UNMASKED_VENDOR_WEBGL) : g.getParameter(g.VENDOR), version: g.getParameter(g.VERSION),
      unmasked: !!d }; const l = g.getExtension('WEBGL_lose_context'); if (l) l.loseContext(); return r; } catch (e) { return { error: String(e) }; } })()`);
  const canvas = await evaluate(`(() => { const c = document.querySelector('canvas'); return c ? { width: c.width, height: c.height,
    cssWidth: c.clientWidth, cssHeight: c.clientHeight, devicePixelRatio: window.devicePixelRatio,
    crossOriginIsolated: window.crossOriginIsolated === true } : null; })()`);
  let gpuDevices = null;
  try {
    const si = await browser.send('SystemInfo.getInfo');
    gpuDevices = (si.gpu.devices || []).map(d => ({ vendorString: d.vendorString, deviceString: d.deviceString,
      vendorId: d.vendorId, deviceId: d.deviceId, driverVendor: d.driverVendor, driverVersion: d.driverVersion }));
  } catch (e) { gpuDevices = { error: e.message }; }

  if (SHOT) {
    const shot = await page.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false }, 60000);
    mkdirSync(dirname(resolve(SHOT)), { recursive: true });
    writeFileSync(SHOT, Buffer.from(shot.data, 'base64'));
    log(`screenshot -> ${SHOT}`);
  }

  const unmasked = gl && gl.renderer ? String(gl.renderer) : null;
  const out = { ...result };
  out.browser = ver.Browser;
  out.userAgent = ver['User-Agent'];
  if (!out.gpu) out.gpu = unmasked;
  if (out.driver === undefined || out.driver === null) out.driver = angleBackend(unmasked);
  if (!out.cpu) out.cpu = (cpus()[0] || {}).model || '';
  if (!out.os) out.os = `${osVersion()} ${osRelease()}`;
  out.gpuRendererUnmasked = unmasked;
  out.gpuVendorUnmasked = gl ? gl.vendor : null;
  out.browserGpuDevices = gpuDevices;
  out.canvas = canvas;
  out.benchDriver = { tool: 'research/engine-spike/tools/bench-browser.mjs', browserName: BROWSER, browserPath: exe,
    flags: flags.slice(1, -1), url: URL_, viewport: { width: WIDTH, height: HEIGHT, deviceScaleFactor: 1 }, waitFor: WAIT_FOR,
    wallMs: Date.now() - t0, pageWarnings: consoleLines.slice(0, 20) };
  mkdirSync(dirname(resolve(OUT)), { recursive: true });
  writeFileSync(OUT, JSON.stringify(out, null, 2) + '\n');

  const size = canvas ? `${canvas.width}x${canvas.height}` : 'no canvas';
  if (canvas && (canvas.width !== WIDTH || canvas.height !== HEIGHT)) log(`WARNING: canvas is ${size}, not ${WIDTH}x${HEIGHT}`);
  if (result.frameMs) log(`frames ${result.frames}  avg ${result.frameMs.avg} ms  p95 ${result.frameMs.p95}  p99 ${result.frameMs.p99}  fps ${result.fps}  hashMatch ${result.hashMatch}`);
  if (result.pass !== undefined) log(`checks: ${result.pass ? 'all passed' : result.failed + ' failed'} (${result.total} checks)`);
  log(`gpu: ${out.gpu}; canvas ${size}; wrote ${OUT}`);
  code = result.hashMatch === false || result.pass === false ? 1 : 0;
} catch (e) {
  console.error('[bench-browser] ' + (e.stack || e.message));
  if (consoleLines.length) console.error(consoleLines.join('\n'));
  code = 1;
}
clearTimeout(hardStop);
await cleanup();
process.exit(code);
