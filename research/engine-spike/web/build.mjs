// Build for the web spike, no dependencies: strip TypeScript types with Node's own node:module stripTypeScriptTypes
// (whitespace replacement, so line and column numbers in dist/ match src/) and rewrite relative ".ts" import specifiers
// to ".js". src/*.ts -> dist/*.js. The sim and camera are not built: dist/ imports ../../shared/*.mjs as they are.
//   node research/engine-spike/web/build.mjs
// Node 24 prints an ExperimentalWarning for stripTypeScriptTypes; that is expected.
import { stripTypeScriptTypes } from 'node:module';
import { readdirSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const SRC = join(here, 'src'), DIST = join(here, 'dist');

// from './x.ts' | import './x.ts' | import('./x.ts')  ->  .js   (relative specifiers only)
const SPEC_RE = /(\bfrom\s*|\bimport\s*\(\s*|\bimport\s+)(['"])(\.{1,2}\/[^'"\n]+?)\.ts\2/g;
const LEFT_RE = /(['"])\.{1,2}\/[^'"\n]+\.ts\1/;

const t0 = performance.now();
// Compile everything first; dist/ is replaced only when every file built, so a failed build keeps the last good one.
const outs = [];
let bytes = 0;
for (const f of readdirSync(SRC).filter(f => f.endsWith('.ts')).sort()) {
  const src = readFileSync(join(SRC, f), 'utf8');
  let js;
  try { js = stripTypeScriptTypes(src, { mode: 'strip' }); }
  catch (e) { console.error(`build: ${f}: ${e.message}`); process.exit(1); }
  js = js.replace(SPEC_RE, (_, pre, q, p) => `${pre}${q}${p}.js${q}`);
  if (LEFT_RE.test(js)) { console.error(`build: ${f}: a relative .ts specifier was not rewritten`); process.exit(1); }
  outs.push([f.replace(/\.ts$/, '.js'), js + `\n//# sourceURL=src/${f}\n`]);
  bytes += Buffer.byteLength(js);
}
rmSync(DIST, { recursive: true, force: true });
mkdirSync(DIST, { recursive: true });
for (const [name, js] of outs) writeFileSync(join(DIST, name), js);
console.log(`build: ${outs.length} files, ${bytes} bytes -> ${DIST} in ${(performance.now() - t0).toFixed(0)} ms`);
