// Instrumented copy of prototype/index.html for the known-bug checks. Never edits the prototype: it builds a scratch
// copy in the OS temp folder with no-op hooks added at a few points, and exposes groundY. Hooks do nothing unless a
// probe is installed on `global`, and none of them touches simulation state or the RNG, so a match plays out
// bit-for-bit as in the real file (qa/tests/known-bugs.test.js checks that).
//
// Probes (set on `global` before running matches):
//   __hitProbe(ex, A, D, dmg, o)   at the start of hit(); D.state, D.stance and D.dPrev are as the hit sees them
//   __hurtProbe(f, amt, by)        at the start of hurt(); amt is the damage about to be applied
//   __chainProbe(ex)               at the start of chain(); ex.cancel is true after a parry
//   __rushProbe(f, dt, ground)     at the start of stepRush(); ground is the terrain height under f.x right now
//   __beamProbe(ex)                at the start of planBeam(); ex.tag holds the outcome once planBeam returns
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createHarness } = require('../../prototype/tools/match-runner');

const SRC = path.join(__dirname, '..', '..', 'prototype', 'index.html');
const EDITS = [
  ['function hurt(f, amt, by){', 'function hurt(f, amt, by){ if (window.__hurtProbe) window.__hurtProbe(f, amt, by);'],
  ['function hit(ex, A, D, dmg, o){', 'function hit(ex, A, D, dmg, o){ if (window.__hitProbe) window.__hitProbe(ex, A, D, dmg, o);'],
  ['function chain(ex){', 'function chain(ex){ if (window.__chainProbe) window.__chainProbe(ex);'],
  ['function stepRush(f, dt){', 'function stepRush(f, dt){ if (window.__rushProbe) window.__rushProbe(f, dt, groundY(f.x));'],
  ['function planBeam(ex){', 'function planBeam(ex){ if (window.__beamProbe) window.__beamProbe(ex);'],
  ['window.__wf = {buildings: () => buildings,', 'window.__wf = {groundY, curH, buildings: () => buildings,'],
];

let file = null;
function instrumentedPath() {
  if (file && fs.existsSync(file)) return file;
  let html = fs.readFileSync(process.env.QA_HTML || SRC, 'utf8');
  for (const [from, to] of EDITS) {
    const at = html.indexOf(from);
    if (at < 0 || html.indexOf(from, at + 1) >= 0) throw new Error(`instrumentation point not found exactly once in prototype/index.html:\n  ${from}\nUpdate EDITS in qa/lib/instrument.js.`);
    html = html.slice(0, at) + to + html.slice(at + from.length);
  }
  file = path.join(os.tmpdir(), `meridian-qa-instrumented-${process.pid}.html`);
  fs.writeFileSync(file, html);
  process.on('exit', () => { try { fs.unlinkSync(file); } catch (e) { /* already gone */ } });
  return file;
}

const instrumentedHarness = () => createHarness({ html: instrumentedPath() });
module.exports = { instrumentedHarness, instrumentedPath };
