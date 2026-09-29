// Cosmetic effects leave the sim as events (QA-002; docs/architecture/fx-events.md). Each function below appends one
// event to S.out.fx and changes no sim state. The render side (core/view/fx.js is the reference consumer) turns the
// events into particles, damage numbers, the banner and camera shake, with its own cosmetic random streams.
//
// Prototype parity: with createSim({fxRng: 'shared'}) each emitter also makes exactly the random draws the prototype's
// effect made on the gameplay stream, at the same point, so the gameplay stream advances as it did in the prototype
// and the port stays tick-identical to it. With 'split' (the default) no emitter draws anything.
import { next } from './rng.js';

const emit = (S, ev) => { S.out.fx.push(ev); };
// Burn k draws of the gameplay stream (parity mode only).
const burn = (S, k) => { if (S.opts.fxRng === 'shared') for (let i = 0; i < k; i++) next(S.rng); };

// Draws per particle in the prototype's effect functions.
const DRAWS = { spark: 4, debris: 6, dust: 6, splash: 5, fire: 7 };

export function spark(S, x, y, n, col, spd){ emit(S, {type:'spark', x, y, n, col: col || '#fff3c0', spd: spd || 500}); burn(S, n*DRAWS.spark); }
export function ring(S, x, y, gr, col, life, r0){ emit(S, {type:'ring', x, y, gr, col: col || '#ffffff', life: life || 0.5, r0: r0 || 10}); }
export function debris(S, x, y, n, col, spd){ emit(S, {type:'debris', x, y, n, col: col || '#6d6a66', spd: spd || 500}); burn(S, n*DRAWS.debris); }
export function dust(S, x, y, n, col){ emit(S, {type:'dust', x, y, n, col: col || '#9b8f7e'}); burn(S, n*DRAWS.dust); }
export function splash(S, x, y, n){ emit(S, {type:'splash', x, y, n}); burn(S, n*DRAWS.splash); }
export function fire(S, x, y, n){ emit(S, {type:'fire', x, y, n}); burn(S, n*DRAWS.fire); }
// An afterimage of f: 0.45 s for a dodge or escape, 0.16 s for each tick of a rush trail.
export function afterimage(S, f, life = 0.45){ emit(S, {type:'after', x: f.x, y: f.y, life, col: f.aura, face: f.face}); }
export function banner(S, text, col, dur){ emit(S, {type:'banner', text, col: col || '#ffffff', dur: dur || 1.3}); }
// A damage number; the consumer prints String(Math.round(amount)).
export function damageNumber(S, x, y, amount, col){ emit(S, {type:'damage', x, y, amount, col}); }
// Camera shake request: the consumer keeps shake = max(shake, k) and decays it at the end of the tick.
export function shake(S, k){ emit(S, {type:'shake', k}); }

// A charging fighter's aura, once per charging tick. The prototype rolled 40% for a spark and 6% for a dust puff when
// the fighter was within 30 of the ground; the consumer rolls those now.
export function chargeFx(S, f, ground){
  emit(S, {type:'charge', x: f.x, y: f.y, col: f.aura, ground});
  if (S.opts.fxRng === 'shared'){
    if (next(S.rng) < 0.4) burn(S, 4);
    if (next(S.rng) < 0.06 && f.y < ground + 30) burn(S, DRAWS.dust);
  }
}
// A beam sample low over water. The prototype rolled 60% for a splash of 3; the consumer rolls it now.
export function beamSplash(S, x){
  emit(S, {type:'beamSplash', x});
  if (S.opts.fxRng === 'shared' && next(S.rng) < 0.6) burn(S, 3*DRAWS.splash);
}
// End of the sim's part of a tick: where the prototype stepped its particles (dt, or dt*0.1 during hit-stop).
export function tickMark(S, dt, frozen){ emit(S, {type:'tick', dt, frozen}); }
