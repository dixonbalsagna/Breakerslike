// Assembles the GitHub Pages site. Node built-ins only; deterministic (no clock, no random).
//   node tools/build-site.mjs --web <dir with the Godot web export> --out <site dir> [--commit <sha>]
// Layout of <site dir>:
//   index.html               landing page linking to the two builds
//   prototype/index.html     the single-file browser prototype (a stable URL Orb shares)
//   play/                    the Godot web export (index.html, .js, .wasm, .pck, ...)
//   bench/index.html         a one-click benchmark: the same export (loaded from ../play/) with the bench arguments
//                            baked in, a results panel and a "copy result" button. Not linked from the landing page.
// Docs: docs/tools/README.md
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const web = opt('--web');
const commit = (opt('--commit') || 'unknown').slice(0, 7);
const out = opt('--out');
if (!web || !out) {
  console.error('usage: node tools/build-site.mjs --web <godot web export dir> --out <site dir>');
  process.exit(2);
}
const webDir = resolve(web);
const outDir = resolve(out);
const protoHtml = join(root, 'prototype', 'index.html');

if (!existsSync(join(webDir, 'index.html')) || !readdirSync(webDir).some((f) => f.endsWith('.wasm'))) {
  console.error(`error: ${webDir} does not look like a Godot web export (needs index.html and a .wasm)`);
  process.exit(1);
}
if (!existsSync(protoHtml)) {
  console.error(`error: ${protoHtml} is missing`);
  process.exit(1);
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(join(outDir, 'prototype'), { recursive: true });
mkdirSync(join(outDir, 'bench'), { recursive: true });
cpSync(protoHtml, join(outDir, 'prototype', 'index.html'));
cpSync(webDir, join(outDir, 'play'), { recursive: true });

// ---- /bench/: the exported page, retargeted at ../play/ and given the bench arguments and a results panel ----
function replaceOnce(text, from, to) {
  if (!text.includes(from)) {
    console.error(`error: the Godot page no longer contains ${JSON.stringify(from)}; update tools/build-site.mjs`);
    process.exit(1);
  }
  return text.replace(from, () => to);
}
let bench = readFileSync(join(webDir, 'index.html'), 'utf8');
for (const file of ['index.icon.png', 'index.apple-touch-icon.png', 'index.png', 'index.js']) bench = replaceOnce(bench, `"${file}"`, `"../play/${file}"`);
bench = replaceOnce(bench, '"executable":"index"', '"executable":"../play/index"');
bench = replaceOnce(bench, '"args":[]', '"args":benchArgs()');
bench = replaceOnce(bench, '<title>Orb Combat EX</title>', '<title>Orb Combat EX bench</title>\n\t\t<meta name="robots" content="noindex">');
bench = replaceOnce(bench, '<script src="../play/index.js"></script>', `<script src="../play/index.js"></script>
		<script>
// Bench arguments: fixed 60 Hz steps, seed 4, 2400 frames, vsync off. Add ?nosplit and/or ?novfx to the URL to
// switch the split screen or the VFX off, and ?frames=N to change the length.
function benchArgs() {
  const q = new URLSearchParams(location.search);
  const frames = Math.max(300, Math.min(20000, parseInt(q.get('frames') || '2400', 10) || 2400));
  const args = ['--fixed-fps', '60', '--', '--seed=4', '--frames=' + frames, '--bench'];
  if (q.has('nosplit')) args.push('--nosplit');
  if (q.has('novfx')) args.push('--novfx');
  return args;
}
</script>`);
bench = replaceOnce(bench, '</body>', `		<div id="bench-panel" style="position:fixed;left:12px;bottom:12px;max-width:min(560px,calc(100vw - 24px));padding:10px 12px;background:rgba(20,22,28,.92);color:#e8ecf2;font:13px/1.4 system-ui,sans-serif;border:1px solid #4a5160;border-radius:8px;z-index:10">
			<div id="bench-status">Benchmark running. Keep this tab visible and wait; a slow computer can take a few minutes.</div>
			<textarea id="bench-text" readonly rows="12" style="display:none;width:100%;box-sizing:border-box;margin-top:8px;font:12px/1.35 ui-monospace,monospace"></textarea>
			<button id="bench-copy" style="display:none;margin-top:8px;padding:6px 12px;font:inherit;cursor:pointer">Copy result</button>
		</div>
		<script>
(function () {
  const BUILD = ${JSON.stringify(commit)};
  function machine() {
    const out = [];
    let renderer = 'unavailable', vendor = 'unavailable';
    try {
      const gl = document.createElement('canvas').getContext('webgl2') || document.createElement('canvas').getContext('webgl');
      const ext = gl && gl.getExtension('WEBGL_debug_renderer_info');
      if (ext) { renderer = gl.getParameter(ext.UNMASKED_RENDERER_WEBGL); vendor = gl.getParameter(ext.UNMASKED_VENDOR_WEBGL); }
    } catch (e) { /* keep the defaults */ }
    out.push('browser: ' + navigator.userAgent);
    out.push('cores: ' + navigator.hardwareConcurrency);
    out.push('memory (GB, rounded down by the browser): ' + (navigator.deviceMemory === undefined ? 'unavailable' : navigator.deviceMemory));
    out.push('screen: ' + screen.width + 'x' + screen.height + ' at device pixel ratio ' + window.devicePixelRatio);
    out.push('window: ' + window.innerWidth + 'x' + window.innerHeight);
    out.push('webgl renderer: ' + renderer);
    out.push('webgl vendor: ' + vendor);
    return out;
  }
  function report(result) {
    const lines = ['Orb Combat EX web bench', 'build: ' + BUILD, 'page arguments: ' + (location.search || '(default)'), '', '--- result'];
    for (const k of Object.keys(result)) lines.push(k + ': ' + (typeof result[k] === 'object' ? JSON.stringify(result[k]) : result[k]));
    lines.push('', '--- this computer', ...machine());
    return lines.join('\\n');
  }
  const status = document.getElementById('bench-status');
  const box = document.getElementById('bench-text');
  const copy = document.getElementById('bench-copy');
  const started = performance.now();
  const timer = setInterval(function () {
    if (window.__benchResult) {
      clearInterval(timer);
      box.value = report(window.__benchResult);
      box.style.display = 'block';
      copy.style.display = 'inline-block';
      status.textContent = 'Done. Press "Copy result" and paste the text into your message.';
    } else if (performance.now() - started > 300000) {
      status.textContent = 'Still running after 5 minutes. This computer is slow: keep waiting, or close the tab and say so.';
    }
  }, 500);
  copy.addEventListener('click', function () {
    box.select();
    const done = function () { copy.textContent = 'Copied'; };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(box.value).then(done, function () { document.execCommand('copy'); done(); });
    else { document.execCommand('copy'); done(); }
  });
})();
		</script>
	</body>`);
writeFileSync(join(outDir, 'bench', 'index.html'), bench);

writeFileSync(
  join(outDir, 'index.html'),
  `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Orb Combat EX</title>
<style>
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 34rem; margin: 3rem auto; padding: 0 1rem; }
  li { margin: .5rem 0; }
</style>
</head>
<body>
<h1>Orb Combat EX</h1>
<p>Free and open source. Both builds run in your browser.</p>
<ul>
  <li><a href="play/">Play the Godot build</a> (work in progress)</li>
  <li><a href="prototype/">Play the original prototype</a></li>
</ul>
<p><a href="https://github.com/dixonbalsagna/orb-combat-ex">Source code</a></p>
</body>
</html>
`,
);

const files = readdirSync(outDir, { recursive: true }).length;
console.log(`site built in ${outDir}: /, /prototype/, /play/, /bench/ (${files} entries)`);
