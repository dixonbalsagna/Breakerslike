// Loads the browser prototype for parity checks, through QA's headless harness, with two read-only probes added so the
// whole simulation state can be compared (the prototype only exposes part of it on window.__wf). The repo file is never
// touched: the instrumented copy goes to the OS temp folder. If a probe target is missing (the prototype changed), this
// throws, so the parity check cannot silently compare less than it claims to.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');
export const PROTO_HTML = path.join(ROOT, 'prototype', 'index.html');
export const QA = require(path.join(ROOT, 'prototype', 'tools', 'match-runner.js'));   // createHarness, runMatch, ARMS, ...

const MULBERRY = 'function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}';
const PROBES = [
  // (a) the same generator, which also reports its state
  [MULBERRY, 'function mulberry32(a){const __f=function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};__f.__state=()=>a|0;return __f;}'],
  // (b) read access to the state window.__wf does not expose
  ['window.__wf = {', 'window.__wf = {__int: () => ({rngState: rng.__state(), deform, base, trees, parts, beams, floats}), '],
];

let instrumented = null;
export function instrumentedPath(extra = []) {
  if (instrumented && !extra.length) return instrumented;
  let html = fs.readFileSync(PROTO_HTML, 'utf8');
  for (const [from, to] of [...PROBES, ...extra]) {
    if (!html.includes(from)) throw new Error('parity probe target not found in prototype/index.html:\n  ' + from);
    html = html.replace(from, () => to);
  }
  const file = path.join(os.tmpdir(), `meridian-parity-${process.pid}-${extra.length ? 'mut' + Date.now() : 'probe'}.html`);
  fs.writeFileSync(file, html);
  if (!extra.length) instrumented = file;
  return file;
}

// A QA harness ({wf, feedLog, listeners, bind}) on the instrumented prototype. `extra` adds replacements (negative controls).
export function createProtoHarness(extra = []) { return QA.createHarness({ html: instrumentedPath(extra) }); }
export function createPlainHarness() { return QA.createHarness({ html: PROTO_HTML }); }

// The prototype's state in the shape hash.js's collect() walks.
export function protoSrc(h) {
  const wf = h.wf, it = wf.__int();
  return { T: wf.T(), rngState: it.rngState, rngFxState: null, game: wf.game, banner: wf.game.banner, shake: wf.cam.shake, dirS: wf.dirS,
    fighters: wf.fighters(), world: wf.world(), buildings: wf.buildings(), trees: it.trees, deform: it.deform, beams: it.beams,
    parts: it.parts, floats: it.floats, beatDetail: false };
}
export const protoCam = h => ({ x: h.wf.cam.x, y: h.wf.cam.y, z: h.wf.cam.z });
