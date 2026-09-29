// Headless harness for the browser prototype.
// Loads the <script> from ../index.html against a mock DOM so the simulation can be run without a browser.
// If @napi-rs/canvas is installed, render() draws to a real canvas so you can save PNG screenshots.
const fs = require('fs');
const path = require('path');

function load(opts = {}) {
  const width = opts.width || 1200, height = opts.height || 700;
  const html = fs.readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8');
  const code = /<script>([\s\S]*)<\/script>/.exec(html)[1];

  let canvas;
  try {
    canvas = require('@napi-rs/canvas').createCanvas(width, height);
  } catch (e) {
    const gradient = () => ({ addColorStop() {} });
    const ctx = new Proxy({}, {
      get: (t, k) => (k in t ? t[k] : (k === 'createRadialGradient' || k === 'createLinearGradient') ? gradient : () => {}),
      set: (t, k, v) => { t[k] = v; return true; }
    });
    canvas = { width, height, getContext: () => ctx, toBuffer: () => Buffer.alloc(0) };
  }
  canvas.getBoundingClientRect = () => ({ width, height });
  canvas.addEventListener = () => {}; canvas.focus = () => {};

  const listeners = {}, els = {}, feedLog = [];
  const mk = id => ({
    id, textContent: '', innerHTML: '', children: [], classList: { toggle() {}, add() {}, remove() {} },
    appendChild(c) { this.children.push(c); },
    insertBefore(c) { if (id === 'feed') feedLog.push(c.children.map(x => x.textContent)); this.children.unshift(c); },
    removeChild() { this.children.pop(); },
    get firstChild() { return this.children[0]; }, get lastChild() { return this.children[this.children.length - 1]; },
    set onclick(f) {}
  });
  const g = global;
  g.document = { getElementById: id => (id === 'cv' ? canvas : (els[id] = els[id] || mk(id))), createElement: () => mk('x') };
  g.window = g; g.devicePixelRatio = 1;
  g.addEventListener = (t, f) => { (listeners[t] = listeners[t] || []).push(f); };
  g.requestAnimationFrame = () => {};
  new Function(code)();
  return { wf: g.__wf, canvas, feedLog, listeners };
}
module.exports = { load };
