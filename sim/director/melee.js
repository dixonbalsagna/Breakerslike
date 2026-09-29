// Melee exchanges: template selection by attack versus defender stance, strikes, parries, launches and the clash shockwave (prototype planMelee and the closures it scheduled, clashWave, strike, launchBeat).
import { wrap, sdx } from '../core/wrap.js';
import { clamp } from '../core/mathx.js';
import { next, range } from '../core/rng.js';
import { hit } from '../core/damage.js';
import { feed } from '../core/events.js';
import { banner, spark, ring, afterimage, shake } from '../core/fx.js';
import { groundY, crater } from '../world/terrain.js';
import { damageArea } from '../world/structures.js';
import { schedule } from './exchange.js';
import { chooseLaunch, doLaunch } from './launch.js';

// Beat helpers name the fighters 'A' (attacker) and 'D' (defender); runBeat resolves them from ex when the beat runs.
export function planMelee(S, ex){
  const A = ex.A, D = ex.D, heavy = ex.kind === 'heavy';
  const dist = Math.abs(sdx(A.x, D.x)), rt = clamp(dist/2600, 0.18, 0.65);
  const ds = D.dPrev === 'charging' ? 4 : D.stance, as = A.stance;
  const rush = (t, off, dur) => schedule(ex, t, 'rush', {off, dur});
  const R0 = () => rush(0, 58, rt);
  const wind = t => schedule(ex, t, 'wind');
  const STRIKE = (t, a, d, dmg, o = null) => schedule(ex, t, 'strike', {a, d, dmg, o});   // the prototype's local S()
  const LAUNCH = (t, force, who) => schedule(ex, t, 'launch', {force, rev: who === 'D'});
  const WIN = t => schedule(ex, t, 'window');
  const NOP = t => schedule(ex, t, 'nop');
  const base = heavy ? 66 : 26;
  const t = rt;

  if (ds === 4){
    R0(); ex.tag = 'CHARGE INTERRUPT';
    STRIKE(t, 'A', 'D', base*1.4, {noParry:true, ignoreStance:true, big:true});
    LAUNCH(t + 0.05, heavy ? 1500 : 900); WIN(t + 0.32); return;
  }
  if (ds === 3){
    const pEsc = clamp(0.5 + 0.07*(D.tier - A.tier) + (dist > 800 ? 0.12 : 0) - (A.ambush ? 1 : 0), 0.05, 0.88);
    if (next(S.rng) < pEsc){
      ex.tag = 'PURSUIT — TARGET SLIPS AWAY';
      rush(0, 260, rt*0.8);
      schedule(ex, rt*0.55, 'slip');
      NOP(rt + 0.5); return;
    }
    R0(); ex.tag = 'PURSUIT — CAUGHT';
    STRIKE(t, 'A', 'D', base*1.2, {noParry:true});
    if (heavy) LAUNCH(t + 0.05, 1500); else LAUNCH(t + 0.05, 800);
    WIN(t + 0.3); return;
  }
  if (ds === 2){
    R0();
    const pRead = A.ambush ? 1 : clamp(0.42 + 0.08*(A.tier - D.tier) + (as === 0 ? 0.08 : 0) - (A.ki < 12 ? 0.12 : 0) - (heavy ? 0.05 : 0), 0.15, 0.8);
    const read = next(S.rng) < pRead;
    ex.tag = read ? 'DODGE & READ' : 'DODGE & COUNTER';
    wind(t - 0.12);
    schedule(ex, t, 'dodge');
    if (read){
      STRIKE(t + 0.22, 'A', 'D', base, {noParry:true});
      if (heavy) LAUNCH(t + 0.27, 1400);
      WIN(t + 0.5);
    } else {
      STRIKE(t + 0.24, 'D', 'A', base*0.9, {noParry:true});
      LAUNCH(t + 0.3, 900, 'D'); NOP(t + 0.6);
    }
    return;
  }
  if (ds === 1){
    R0();
    if (!heavy){
      ex.tag = 'PRESSURE — GUARD HOLDS';
      wind(t - 0.1);
      STRIKE(t, 'A', 'D', 26, {kb:120}); STRIKE(t + 0.16, 'A', 'D', 26, {kb:120, noParry:true}); STRIKE(t + 0.32, 'A', 'D', 26, {kb:120, noParry:true});
      if (D.ki > 25 && next(S.rng) < 0.4){ ex.tag += ' → COUNTER'; STRIKE(t + 0.55, 'D', 'A', 24, {noParry:true, ignoreStance:true}); NOP(t + 0.8); }
      else WIN(t + 0.42);
    } else {
      ex.tag = 'GUARD BREAK';
      wind(t - 0.1);
      STRIKE(t, 'A', 'D', 45, {kb:150}); STRIKE(t + 0.2, 'A', 'D', 45, {kb:150, noParry:true});
      schedule(ex, t + 0.4, 'guardBreak');
      STRIKE(t + 0.42, 'A', 'D', base*1.15, {noParry:true, ignoreStance:true, stop:0.12, shake:12, big:true});
      LAUNCH(t + 0.46, 1700); WIN(t + 0.72);
    }
    return;
  }
  // aggressive defender
  R0();
  if (!heavy){
    ex.tag = 'TRADE BLOWS';
    const sc = (f, o) => f.tier + f.ki/70 + range(S.rng, 0, 1.6) + (f.hp > o.hp ? 0.3 : 0);
    const aw = sc(A, D) > sc(D, A);
    wind(t - 0.1);
    STRIKE(t, 'A', 'D', 24); STRIKE(t + 0.17, 'D', 'A', 20, {noParry:true}); STRIKE(t + 0.34, 'A', 'D', 24, {noParry:true}); STRIKE(t + 0.51, 'D', 'A', 20, {noParry:true});
    if (aw){ STRIKE(t + 0.72, 'A', 'D', 34, {noParry:true, stop:0.1}); LAUNCH(t + 0.76, 1000); WIN(t + 0.98); }
    else { STRIKE(t + 0.72, 'D', 'A', 32, {noParry:true, stop:0.1}); LAUNCH(t + 0.76, 1000, 'D'); NOP(t + 1.0); }
  } else {
    const p = clamp(0.5 + 0.09*(A.tier - D.tier) + (A.ki > D.ki ? 0.05 : -0.05), 0.2, 0.8), r = next(S.rng);
    wind(t - 0.05);
    if (r < p - 0.12){ ex.tag = 'HEAVY CLASH — WON'; STRIKE(t + 0.28, 'A', 'D', base + 8, {stop:0.12, shake:12, ignoreStance:true, big:true}); LAUNCH(t + 0.32, 1800); WIN(t + 0.58); }
    else if (r > p + 0.12){ ex.tag = 'HEAVY CLASH — COUNTERED'; STRIKE(t + 0.28, 'D', 'A', base, {noParry:true, stop:0.12, shake:12, ignoreStance:true, big:true}); LAUNCH(t + 0.32, 1600, 'D'); NOP(t + 0.6); }
    else { ex.tag = 'CLASH SHOCKWAVE'; schedule(ex, t + 0.28, 'clashWave'); NOP(t + 0.7); }
  }
}

// Beat 'wind': the parry window opens; an AI defender may time a parry press.
export function opWind(S, ex, args){
  const D = ex.D;
  ex.windowStart = S.T;
  if (D.ai && next(S.rng) < (D.stance === 1 ? 0.5 : D.stance === 0 ? 0.3 : 0.12)) schedule(ex, ex.t + range(S.rng, 0.05, 0.16), 'press', {who:'D'});
}
// Beat 'slip': the escaping defender breaks away from the pursuit.
export function opSlip(S, ex, args){
  const A = ex.A, D = ex.D;
  afterimage(S, D); D.state = 'free'; D.vx = Math.sign(sdx(A.x, D.x))*(1500 + D.tier*200); D.vy = range(S.rng, -150, 300);
  banner(S, 'SLIPPED AWAY', '#9fe0b0', 0.8); A.ki = Math.max(0, A.ki - 3);
}
// Beat 'dodge': the evasive defender blinks behind the attacker.
export function opDodge(S, ex, args){
  const A = ex.A, D = ex.D;
  afterimage(S, D); D.x = wrap(A.x - A.face*74); D.y = Math.max(groundY(S, D.x), A.y + range(S.rng, -30, 70)); D.vx = 0; D.vy = 0; ring(S, D.x, D.y+34, 500, '#9fe0ff', 0.3, 8);
}
// Beat 'guardBreak': the defensive guard shatters.
export function opGuardBreak(S, ex, args){
  const D = ex.D;
  if (ex.cancel) return; D.ki = Math.max(0, D.ki - 25); banner(S, 'GUARD BREAK', '#ffd45a', 0.8); shake(S, 12);
}

export function clashWave(S, ex){
  const A = ex.A, D = ex.D, mx = wrap(A.x + sdx(A.x, D.x)/2), my = (A.y + D.y)/2 + 34;
  ring(S, mx, my, 1400, '#ffffff', 0.6, 20); ring(S, mx, my, 800, '#ffd45a', 0.8, 10); spark(S, mx, my, 30, '#fff3c0', 900);
  A.vx = -A.face*900; D.vx = A.face*900;
  hit(S, ex, A, D, 18, {ignoreStance:true, stop:0.1}); hit(S, ex, D, A, 18, {ignoreStance:true, stop:0.02});
  const tier = Math.max(A.tier, D.tier);
  if (my < groundY(S, mx) + 200) crater(S, mx, 60 + tier*16, 10 + tier*4, A);
  damageArea(S, mx, my, 160 + tier*40, 110 + tier*80, A);
  banner(S, 'CLASH', '#ffffff', 0.7); shake(S, 18);
}

export function strike(S, ex, a, d, dmg, o){
  o = o || {};
  if (ex.cancel || S.game.ko || d.hp <= 0 || a.hp <= 0) return;
  a.face = Math.sign(sdx(a.x, d.x)) || a.face;
  if (a === ex.A && !o.noParry && ex.windowStart >= 0 && d.lastAtkT >= ex.windowStart){
    ex.cancel = true;
    hit(S, ex, d, a, 18, {ignoreStance:true, stop:0.12, shake:9});
    ring(S, a.x + a.face*30, a.y + 34, 700, '#9fe0ff', 0.4, 10); banner(S, 'PARRY', '#9fe0ff', 0.8);
    a.vx = -a.face*520; d.ki = Math.min(100, d.ki + 8);
    feed(S, d.name + ' PARRIES', 'Timed the wind-up. Rest of the exchange cancelled.');
    return;
  }
  if (d.state === 'launched' || d.state === 'down'){ d.state = 'locked'; d.vx *= 0.1; d.vy *= 0.1; }
  hit(S, ex, a, d, dmg, o);
  d.vx += a.face*(o.kb || 220);
}
export function launchBeat(S, ex, att, tgt, force){
  if (ex.cancel || S.game.ko || tgt.hp <= 0) return;
  const r = chooseLaunch(S, att, tgt);
  doLaunch(S, att, tgt, r.best, force);
  S.dirS.lastLaunch2 = S.dirS.lastLaunch; S.dirS.lastLaunch = r.best.name;
  feed(S, 'LAUNCH: ' + r.best.name, r.top.map(k => k.name + ' ' + Math.round(k.s)).join('  |  '));
}
