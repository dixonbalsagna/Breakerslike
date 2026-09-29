// The state object and the fixed-step tick: createSim, and the prototype's newMatch, step and toggleAI.
import { DT, NC } from './constants.js';
import { createRng, next } from './rng.js';
import { wrap, sdx } from './wrap.js';
import { clamp } from './mathx.js';
import { ROSTER, createFighter } from './roster.js';
import { spark, shake, tickMark } from './fx.js';
import { stepFighter } from './fighter.js';
import { genWorld } from '../world/terrain.js';
import { DET, NATIVE } from './detmath.js';
import { control } from '../input/control.js';
import { dirUpdate } from '../director/exchange.js';
import { beamStep } from '../director/beam.js';

// fxRng: 'split' (the canonical rule: cosmetics never touch the gameplay stream; the render side has its own streams)
// or 'shared' (prototype parity: the effect emitters make the prototype's draws on S.rng; see core/fx.js).
function checkFxRng(mode){
  if (mode !== 'split' && mode !== 'shared') throw new Error("fxRng must be 'split' or 'shared', got " + String(mode));
}

// An empty state shaped as module-spec section 2. Call newMatch before the first step.
// opts.math: 'det' (core/detmath.js: the same bits in every language; parity with the GDScript port) or 'native'
// (Math.sin and friends, as the prototype). The defaults, det and split, are the game's rules; prototype parity needs
// {math: 'native', fxRng: 'shared'}. See docs/architecture/determinism.md.
export function createSim(opts = {}){
  const fxRng = opts.fxRng === undefined ? 'split' : opts.fxRng;
  checkFxRng(fxRng);
  const math = opts.math === undefined ? 'det' : opts.math;
  if (math !== 'native' && math !== 'det') throw new Error("math must be 'native' or 'det', got " + String(math));
  const rng = createRng(7);   // the prototype's stream before its first newMatch
  return {
    opts: { fxRng, math },
    m: math === 'det' ? DET : NATIVE,   // sin, cos, pow, hypot
    T: 0,
    dt: 0,
    rng,
    game: { ko: null, koT: 0, ts: 1, clash: null, seed: 1 },
    dirS: { ex: null, cool: 0, stop: 0, lastLaunch: '', lastLaunch2: '' },
    fighters: [],
    world: null,   // genWorld fills it
    base: new Float32Array(NC),
    deform: new Float32Array(NC),
    buildings: [],
    trees: [],
    beams: [],
    out: { feed: [], fx: [] },   // this tick's feed lines and cosmetic events; the host drains both
  };
}

// Break the references between a match's objects (fighters point at each other through launchBy and rush.tgt).
// JavaScript's garbage collector frees such cycles anyway; the GDScript twin needs this, and newMatch calls it in both.
export function dispose(S){
  for (const f of S.fighters){ f.launchBy = null; f.rush = null; }
  S.game.ko = null; S.game.clash = null; S.dirS.ex = null; S.beams.length = 0;
}

// The seed must be an integer: picking one from the clock is the host's job. ai is {p1, p2}; a missing entry keeps the
// previous fighter's setting, or true when there are no fighters yet, as the prototype does.
export function newMatch(S, seed, ai){
  if (!Number.isInteger(seed)) throw new TypeError('newMatch needs an integer seed, got ' + String(seed));
  checkFxRng(S.opts.fxRng);
  S.game.seed = seed >>> 0;
  S.rng = createRng(S.game.seed);
  genWorld(S);
  const p1ai = ai && ai.p1 != null ? !!ai.p1 : S.fighters.length ? !!S.fighters[0].ai : true;
  const p2ai = ai && ai.p2 != null ? !!ai.p2 : S.fighters.length ? !!S.fighters[1].ai : true;
  dispose(S);
  S.fighters = [createFighter(ROSTER[0], 2150, 'p1', p1ai), createFighter(ROSTER[1], 2900, 'p2', p2ai)];
  S.fighters[0].y = 60; S.fighters[1].y = 60; S.fighters[1].face = -1;
  S.fighters[0].stance = 0; S.fighters[1].stance = 0;
  S.beams.length = 0; S.T = 0;
  S.game.ko = null; S.game.koT = 0; S.game.ts = 1; S.game.clash = null;
  S.dirS.ex = null; S.dirS.cool = 0.6; S.dirS.stop = 0;
  S.dirS.lastLaunch = ''; S.dirS.lastLaunch2 = '';   // launch-variety history must not carry over from the previous match
  S.out.feed.length = 0; S.out.fx.length = 0;
  S.dt = 0;
}

// One fixed step. inputs is [intent|null, intent|null] or undefined (AI fighters ignore it). Returns false during
// hit-stop (no input was consumed; the host keeps its key presses for the next tick), true otherwise.
export function step(S, inputs){
  const dtReal = DT;
  const dt = dtReal*S.game.ts;
  S.dt = dt;
  if (S.dirS.stop > 0){ S.dirS.stop -= dtReal; tickMark(S, dt, true); return false; }
  S.T += dt;
  if (S.game.ko){ S.game.koT += dt; if (S.game.koT > 2.2) S.game.ts = 1; }
  const ord = next(S.rng) < 0.5 ? [0, 1] : [1, 0];
  for (const k of ord) control(S, S.fighters[k], inputs ? inputs[k] : null);
  for (const f of S.fighters) stepFighter(S, f, dt);
  dirUpdate(S, dt);
  beamStep(S, dt); tickMark(S, dt, false);
  if (S.game.clash){
    const c = S.game.clash, p = clamp((S.T - c.t0)/c.dur, 0, 1);
    const mid = 0.5 + (c.aw ? 1 : -1)*0.35*p, ax = c.A.x, dx = sdx(ax, c.D.x);
    spark(S, wrap(ax + dx*mid), (c.A.y + (c.D.y - c.A.y)*mid) + 38, 3, '#ffffff', 700);
    shake(S, 7);
  }
  return true;
}

export function toggleAI(S, idx){ const f = S.fighters[idx]; f.ai = f.ai ? null : {t:0.5, atk:1.2, sT:0, sOff:0}; }
