// A facade over the port with the same shape as QA's prototype harness ({wf, feedLog, listeners, bind}), so QA's own
// runMatch() and ARMS run on the port unchanged. It plays the host's part: picks a clock seed when none is given, keeps
// each slot's AI flag between matches, runs the view camera after every tick (1200x700, the headless canvas size) and
// formats feed lines the way the prototype's DOM feed did, turns key events into intents with the prototype's
// keyboard rules (listeners.keydown / keyup take the same event objects QA's tests send to the prototype), and feeds
// each tick's fx events to the reference cosmetic consumer (view/fx.js), which holds the banner and camera shake the
// prototype kept in its game and cam objects. Its default mode is prototype parity: {math: 'native', fxRng: 'shared'}.
import { createSim, newMatch, step, toggleAI } from '../sim.js';
import { KEYS, intentFromKeys } from '../../input/keyboard.js';
import { createCamera, resetCamera, camStep } from '../view/camera.js';
import { createFxView, resetFxView, consumeFx } from '../view/fx.js';
import { DT } from '../constants.js';

export function createPortHarness(opts = {}) {
  const S = createSim({ math: 'native', fxRng: 'shared', ...opts }), cam = createCamera(), feedLog = [];
  const V = createFxView(1);
  const vw = opts.width || 1200, vh = opts.height || 700;
  let paused = false, started = false;
  const held = new Set(), edges = new Set();
  const game = {
    get ko() { return S.game.ko; }, get koT() { return S.game.koT; }, get ts() { return S.game.ts; },
    get seed() { return S.game.seed; }, get clash() { return S.game.clash; }, get banner() { return V.banner; },
    get paused() { return paused; }, set paused(v) { paused = v; },
  };
  const camFacade = { get x() { return cam.x; }, get y() { return cam.y; }, get z() { return cam.z; }, get shake() { return V.shake; } };
  const drain = () => {
    for (const e of S.out.feed) feedLog.push(e.sub ? [e.t.toFixed(1) + 's', e.tag, e.sub] : [e.t.toFixed(1) + 's', e.tag]);
    S.out.feed.length = 0;
  };
  const wf = {
    newMatch(seed) {
      newMatch(S, Number.isInteger(seed) ? seed : (Date.now() & 0xffffff) | 1);
      resetCamera(cam);
      resetFxView(V, S.game.seed);
    },
    step(dt) {
      if (dt !== DT) throw new Error('the port runs a fixed tick of 1/60 s; got dt ' + dt);
      const inputs = S.fighters.map(f => (f.ai ? null : intentFromKeys(KEYS[f.keys], held, edges)));
      const consumed = step(S, inputs);
      if (consumed) edges.clear();                   // the prototype cleared key presses only in ticks that ran control()
      consumeFx(V, S, S.out.fx); S.out.fx.length = 0;
      camStep(cam, S, S.dt, vw, vh);
      drain();
      return consumed;
    },
    T: () => S.T, fighters: () => S.fighters, world: () => S.world, buildings: () => S.buildings,
    game, dirS: null, cam: camFacade,
    toggleAI: idx => toggleAI(S, idx),
    render() {}, resize() {}, setSize() {},
  };
  Object.defineProperty(wf, 'dirS', { get: () => S.dirS });
  // The prototype's key listeners: the first key hands P1 to the player; N, T, Y and P are system keys; other keys are
  // presses (edges, once per physical press) and held keys.
  const keydown = e => {
    if (!started && !e.metaKey && !e.ctrlKey) { started = true; if (S.fighters[0].ai) toggleAI(S, 0); }
    if (!e.repeat) {
      if (e.code === 'KeyN') { wf.newMatch(); return; }
      if (e.code === 'KeyT') { toggleAI(S, 1); return; }
      if (e.code === 'KeyY') { toggleAI(S, 0); return; }
      if (e.code === 'KeyP') { paused = !paused; return; }
      edges.add(e.code);
    }
    held.add(e.code);
  };
  const listeners = { keydown: [keydown], keyup: [e => held.delete(e.code)], blur: [() => held.clear()] };
  game.start = () => { started = true; };          // like setting the prototype's game.started (skips the takeover)
  return { wf, feedLog, listeners, bind() {}, S, cam, V };
}
