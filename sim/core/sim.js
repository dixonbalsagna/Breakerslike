// The state object and the fixed-step tick: createSim, and the prototype's newMatch, step and toggleAI.
import { DT, NC } from './constants.js';
import { createRng, next } from './rng.js';
import { wrap, sdx } from './wrap.js';
import { clamp } from './mathx.js';
import { ROSTER, createFighter } from './roster.js';
import { spark, stepParts } from './fx.js';
import { stepFighter } from './fighter.js';
import { genWorld } from '../world/terrain.js';
import { control } from '../input/control.js';
import { dirUpdate } from '../director/exchange.js';
import { beamStep } from '../director/beam.js';

// Only 'shared' exists: cosmetics draw from S.rng, as in the prototype. 'split' (its own stream) comes later (QA-002).
function checkFxRng(mode){
  if (mode !== 'shared') throw new Error("fxRng must be 'shared' (the only mode so far), got " + String(mode));
}

// An empty state shaped as module-spec section 2. Call newMatch before the first step.
export function createSim(opts = {}){
  const fxRng = opts.fxRng === undefined ? 'shared' : opts.fxRng;
  checkFxRng(fxRng);
  const rng = createRng(7);   // the prototype's stream before its first newMatch
  return {
    opts: { fxRng },
    T: 0,
    dt: 0,
    rng,
    rngFx: rng,
    game: { ko: null, koT: 0, ts: 1, clash: null, seed: 1 },
    dirS: { ex: null, cool: 0, stop: 0, lastLaunch: '', lastLaunch2: '' },
    fighters: [],
    world: null,   // genWorld fills it
    base: new Float32Array(NC),
    deform: new Float32Array(NC),
    buildings: [],
    trees: [],
    beams: [],
    fx: { parts: [], floats: [], banner: null, shake: 0 },
    out: { feed: [] },
  };
}

// The seed must be an integer: picking one from the clock is the host's job. ai is {p1, p2}; a missing entry keeps the
// previous fighter's setting, or true when there are no fighters yet, as the prototype does.
export function newMatch(S, seed, ai){
  if (!Number.isInteger(seed)) throw new TypeError('newMatch needs an integer seed, got ' + String(seed));
  checkFxRng(S.opts.fxRng);
  S.game.seed = seed >>> 0;
  S.rng = createRng(S.game.seed);
  S.rngFx = S.rng;
  genWorld(S);
  const p1ai = ai && ai.p1 != null ? !!ai.p1 : S.fighters.length ? !!S.fighters[0].ai : true;
  const p2ai = ai && ai.p2 != null ? !!ai.p2 : S.fighters.length ? !!S.fighters[1].ai : true;
  S.fighters = [createFighter(ROSTER[0], 2150, 'p1', p1ai), createFighter(ROSTER[1], 2900, 'p2', p2ai)];
  S.fighters[0].y = 60; S.fighters[1].y = 60; S.fighters[1].face = -1;
  S.fighters[0].stance = 0; S.fighters[1].stance = 0;
  S.fx.parts.length = 0; S.beams.length = 0; S.fx.floats.length = 0; S.T = 0;
  S.game.ko = null; S.game.koT = 0; S.game.ts = 1; S.fx.banner = null; S.game.clash = null;
  S.dirS.ex = null; S.dirS.cool = 0.6; S.dirS.stop = 0;
  S.dirS.lastLaunch = ''; S.dirS.lastLaunch2 = '';   // launch-variety history must not carry over from the previous match
  S.fx.shake = 0;   // the prototype carries cam.shake into the next match; a seed alone must reproduce the state
  S.out.feed.length = 0;
  S.dt = 0;
}

// One fixed step. inputs is [intent|null, intent|null] or undefined (AI fighters ignore it). Returns false during
// hit-stop (no input was consumed; the host keeps its key presses for the next tick), true otherwise.
export function step(S, inputs){
  const dtReal = DT;
  const dt = dtReal*S.game.ts;
  S.dt = dt;
  if (S.dirS.stop > 0){ S.dirS.stop -= dtReal; stepParts(S, dt*0.1); S.fx.shake *= Math.pow(0.02, dt); return false; }
  S.T += dt;
  if (S.game.ko){ S.game.koT += dt; if (S.game.koT > 2.2) S.game.ts = 1; }
  const ord = next(S.rng) < 0.5 ? [0, 1] : [1, 0];
  for (const k of ord) control(S, S.fighters[k], inputs ? inputs[k] : null);
  for (const f of S.fighters) stepFighter(S, f, dt);
  dirUpdate(S, dt);
  beamStep(S, dt); stepParts(S, dt);
  if (S.game.clash){
    const c = S.game.clash, p = clamp((S.T - c.t0)/c.dur, 0, 1);
    const mid = 0.5 + (c.aw ? 1 : -1)*0.35*p, ax = c.A.x, dx = sdx(ax, c.D.x);
    spark(S, wrap(ax + dx*mid), (c.A.y + (c.D.y - c.A.y)*mid) + 38, 3, '#ffffff', 700);
    S.fx.shake = Math.max(S.fx.shake, 7);
  }
  if (S.fx.banner){ S.fx.banner.t += dt; if (S.fx.banner.t > S.fx.banner.dur) S.fx.banner = null; }
  S.fx.shake *= Math.pow(0.02, dt);   // the shake decay from the prototype's camStep; the camera follow is the host's
  return true;
}

export function toggleAI(S, idx){ const f = S.fighters[idx]; f.ai = f.ai ? null : {t:0.5, atk:1.2, sT:0, sOff:0}; }
