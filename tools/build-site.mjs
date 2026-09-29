// Assembles the GitHub Pages site. Node built-ins only; deterministic (no clock, no random).
//   node tools/build-site.mjs --web <dir with the Godot web export> --out <site dir>
// Layout of <site dir>:
//   index.html               landing page linking to the two builds
//   prototype/index.html     the single-file browser prototype (a stable URL Orb shares)
//   play/                    the Godot web export (index.html, .js, .wasm, .pck, ...)
// Docs: docs/tools/README.md
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const web = opt('--web');
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
cpSync(protoHtml, join(outDir, 'prototype', 'index.html'));
cpSync(webDir, join(outDir, 'play'), { recursive: true });

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
console.log(`site built in ${outDir}: /, /prototype/, /play/ (${files} entries)`);
