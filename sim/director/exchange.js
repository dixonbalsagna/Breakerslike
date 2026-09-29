// Exchange director: exchanges, the data-beat scheduler and its op dispatch (prototype STN, newEx, B, requestAttack, openWindow, chain, endEx, dirUpdate).
import { sdx } from '../core/wrap.js';
import { clamp } from '../core/mathx.js';
import { next, range } from '../core/rng.js';
import { feed } from '../core/events.js';
import { banner } from '../core/fx.js';
import { opp } from '../core/roster.js';
import { planMelee, strike, launchBeat, clashWave, opWind, opSlip, opDodge, opGuardBreak } from './melee.js';
import { planBeam, opBeamCharge, opBeamFire, opBeamImpact, opBeamDodge, opBeamEscape, opClashResolve } from './beam.js';

export const STN = ['AGGRESSIVE','DEFENSIVE','EVASIVE','ESCAPE'];

export function newEx(A, D, kind){ return {A, D, kind, t:0, beats:[], combo:1, tag:'', ext:null, windowStart:-1, cancel:false}; }
// The prototype's B(ex, t, fn). The stable sort after every push keeps beats with equal t in scheduling order.
export function schedule(ex, t, op, args = null){ ex.beats.push({t, op, args, done:false}); ex.beats.sort((a,b) => a.t - b.t); }

export function requestAttack(S, A, kind){
  if (S.dirS.ex || S.dirS.cool > 0 || S.game.ko) return;
  const D = opp(S, A);
  if (A.state !== 'free' && A.state !== 'charging') return;
  if (D.state === 'launched' || D.state === 'locked' || D.hp <= 0) return;
  if (kind === 'sig' && A.ki < 45){ if (!A.ai) banner(S, 'NEED 45 KI', '#9fb4ff', 0.6); return; }
  if (kind === 'heavy' && A.ki < 4) kind = 'light';
  if (D.hidden){
    A.ki = Math.max(0, A.ki - 2); S.dirS.cool = 0.5;
    if (!A.ai) banner(S, 'LOCK LOST — TARGET HIDDEN', '#9fb4ff', 0.9);
    return;
  }
  if (A.hidden){ A.hidden = false; if (A.hiddenFor > 1.8) A.ambushUntil = S.T + 1; }
  if (S.T < A.ambushUntil){ A.ambush = true; A.ambushUntil = 0; banner(S, 'AMBUSH FROM COVER', '#ffd45a', 1.1); }
  A.hideT = 0; A.state = 'free';
  if (kind === 'heavy') A.ki -= 4;
  if (kind === 'sig') A.ki -= 45;
  const ex = newEx(A, D, kind);
  A.face = Math.sign(sdx(A.x, D.x)) || A.face;
  D.face = -A.face;
  const dState = D.state;
  A.state = 'locked'; D.state = 'locked'; D.dPrev = dState;
  S.dirS.ex = ex;
  if (kind === 'sig') planBeam(S, ex); else planMelee(S, ex);
  const stanceLabel = dState === 'charging' ? 'CHARGING' : STN[D.stance];
  feed(S, A.name + ' ' + kind.toUpperCase() + ' vs ' + stanceLabel, ex.tag + (A.ambush ? '  (ambush)' : ''));
}

// Runs one beat: the body of the closure the prototype scheduled (module-spec section 4). Fighters are read from ex when the beat runs.
export function runBeat(S, ex, b){
  const A = ex.A, D = ex.D, a = b.args;
  switch (b.op){
    case 'rush': A.rush = {tgt:D, off:-A.face*a.off, end:S.T + a.dur}; return;
    case 'wind': opWind(S, ex, a); return;
    case 'press': (a.who === 'A' ? A : D).lastAtkT = S.T; return;
    case 'strike': strike(S, ex, a.a === 'A' ? A : D, a.d === 'A' ? A : D, a.dmg, a.o); return;
    case 'launch': launchBeat(S, ex, a.rev ? D : A, a.rev ? A : D, a.force); return;
    case 'window': openWindow(S, ex); return;
    case 'nop': return;
    case 'slip': opSlip(S, ex, a); return;
    case 'dodge': opDodge(S, ex, a); return;
    case 'guardBreak': opGuardBreak(S, ex, a); return;
    case 'clashWave': clashWave(S, ex); return;
    case 'chainStrike': strike(S, ex, A, D, 52 + ex.combo*7, {noParry:true, ignoreStance:true, big:true, stop:0.08}); return;
    case 'beamCharge': opBeamCharge(S, ex, a); return;
    case 'beamFire': opBeamFire(S, ex, a); return;
    case 'beamImpact': opBeamImpact(S, ex, a); return;
    case 'beamDodge': opBeamDodge(S, ex, a); return;
    case 'beamEscape': opBeamEscape(S, ex, a); return;
    case 'clashResolve': opClashResolve(S, ex, a); return;
    default: throw new Error('runBeat: unknown op ' + b.op);
  }
}

export function openWindow(S, ex){
  ex.ext = {start:S.T, until:S.T + 0.6};
  if (ex.A.ai && next(S.rng) < clamp(0.62 - 0.14*ex.combo, 0.05, 0.6)) schedule(ex, ex.t + range(S.rng, 0.12, 0.35), 'press', {who:'A'});
}
export function chain(S, ex){
  const A = ex.A;
  ex.combo++; ex.ext = null; A.ki -= 6;
  const t = ex.t;
  banner(S, ex.combo + ' HIT CHAIN', '#ffd45a', 0.7);
  schedule(ex, t, 'rush', {off:60, dur:0.24});
  schedule(ex, t + 0.26, 'chainStrike');                  // damage reads ex.combo when the beat runs
  schedule(ex, t + 0.3, 'launch', {force:1500, rev:false});
  schedule(ex, t + 0.55, 'window');
}
export function endEx(S, ex){
  if (ex.A.state === 'locked') ex.A.state = 'free';
  if (ex.D.state === 'locked') ex.D.state = 'free';
  ex.A.rush = null; ex.A.beamCharge = null; ex.A.ambush = false;
  if (ex.D.dPrev) ex.D.dPrev = null;
  S.game.clash = null;
  if (ex.combo > 1) feed(S, 'CHAIN x' + ex.combo + ' ended', ex.A.name + ' landed ' + ex.combo + ' linked exchanges');
  S.dirS.ex = null; S.dirS.cool = 0.22;
}
export function dirUpdate(S, dt){
  if (S.dirS.cool > 0) S.dirS.cool -= dt;
  const ex = S.dirS.ex; if (!ex) return;
  ex.t += dt;
  for (let i = 0; i < ex.beats.length; i++){ const b = ex.beats[i]; if (!b.done && b.t <= ex.t){ b.done = true; runBeat(S, ex, b); if (S.dirS.ex !== ex) return; } }
  if (ex.ext && S.T < ex.ext.until){
    const A = ex.A;
    if (A.lastAtkT >= ex.ext.start && ex.combo < 5 && A.ki >= 6 && A.hp > 0 && ex.D.hp > 0) chain(S, ex);
  }
  const pending = ex.beats.some(b => !b.done);
  if (!pending && !(ex.ext && S.T < ex.ext.until)) endEx(S, ex);
}
