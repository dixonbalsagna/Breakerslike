// Fighter simulation: the prototype's tierUp, impact, stepLaunched, stepRush and stepFighter.
import { wrap, sdx } from './wrap.js';
import { next, range } from './rng.js';
import { opp } from './roster.js';
import { P, banner, spark, ring, debris, dust, splash } from './fx.js';
import { feed } from './events.js';
import { hurt } from './damage.js';
import { updateHidden } from './hiding.js';
import { groundY, seaAt, crater } from '../world/terrain.js';
import { curH, damageBuilding, damageArea } from '../world/structures.js';

export function tierUp(S, f){
  banner(S, f.name + ' POWERS UP  TIER ' + f.tier, f.aura, 1.4);
  const g = groundY(S, f.x);
  ring(S, f.x, f.y + 34, 1300, f.aura, 0.8, 20); spark(S, f.x, f.y + 34, 20, f.aura, 700);
  S.fx.shake = Math.max(S.fx.shake, 14);
  if (f.y < g + 140){
    crater(S, f.x, 60 + f.tier*28, 12 + f.tier*7, f);
    damageArea(S, f.x, f.y, 130 + f.tier*60, 90 + f.tier*100, f);
    debris(S, f.x, g + 10, 10, '#6d6a66', 600); dust(S, f.x, g, 5);
  }
  feed(S, f.name + ' reaches tier ' + f.tier, f.y < g + 140 ? 'Ground-level power-up scarred the terrain.' : 'Airborne power-up, no ground damage.');
}
export function impact(S, f, g, sp){
  const by = f.launchBy || opp(S, f), tier = by.tier;
  if (sp > 350){
    const r = 28 + sp*0.05 + tier*12, dep = Math.min(90, sp*0.02 + tier*3.5);
    crater(S, f.x, r, dep, by);
    if (seaAt(S, f.x)) splash(S, f.x, g + 10, 14); else { debris(S, f.x, g + 8, 12, '#6d6a66', 500); dust(S, f.x, g, 4); }
    ring(S, f.x, g + 10, 700 + sp*0.2, '#ffffff', 0.45, 10);
    damageArea(S, f.x, g + 5, r*1.7, sp*(0.22 + 0.12*tier), by);
    S.fx.shake = Math.max(S.fx.shake, Math.min(30, sp*0.01)); S.dirS.stop = Math.max(S.dirS.stop, 0.06);
    hurt(S, f, sp*0.018, by);
  }
  f.y = groundY(S, f.x);
  if (sp > 700 && f.bounces < 2){ f.bounces++; f.vy = Math.abs(f.vy)*0.3; f.vx *= 0.75; }
  else { f.state = 'down'; f.stateT = 0; f.vx = 0; f.vy = 0; f.bounces = 0; f.launchBy = null; }
}
export function stepLaunched(S, f, dt){
  f.stateT += dt; f.vy -= 1000*dt; f.vx *= Math.pow(0.55, dt);
  const ox = f.x; f.x = wrap(f.x + f.vx*dt); f.y += f.vy*dt;
  f.rot += f.spin*dt;
  const g0 = groundY(S, f.x), inW = f.y < 0 && seaAt(S, f.x);   // g0 is never read (as in the prototype)
  if (inW && !f.wet){ f.wet = true; splash(S, f.x, 0, 12); ring(S, f.x, 0, 500, '#bfe6ff', 0.5, 10); }
  if (!inW && f.wet && f.y > 0) f.wet = false;
  if (inW){ f.vx *= Math.pow(0.05, dt); f.vy *= Math.pow(0.1, dt); if (Math.hypot(f.vx, f.vy) < 200 && f.stateT > 0.3){ f.state = 'free'; f.rot = 0; return; } }
  for (const b of S.buildings){
    if (!b.alive) continue;
    if (Math.abs(sdx(f.x, b.x)) < b.w/2 + 16){
      const gy = groundY(S, b.x);
      if (f.y < gy + curH(b) && f.y > gy - 10){
        const sp = Math.hypot(f.vx, f.vy), by = f.launchBy || opp(S, f);
        damageBuilding(S, b, sp*(0.55 + 0.25*by.tier), by);
        hurt(S, f, sp*0.006, by);
        debris(S, f.x, f.y + 20, 6, '#77808f', 500);
        f.vx *= 0.6; f.vy *= 0.85;
        if (b.alive){ f.vx = -Math.sign(f.vx || 1)*Math.abs(f.vx)*0.25; f.x = wrap(b.x + Math.sign(sdx(b.x, ox) || 1)*(b.w/2 + 18)); }
      }
    }
  }
  const g = groundY(S, f.x);
  if (f.y <= g) impact(S, f, g, Math.hypot(f.vx, f.vy));
  if (f.y > 2600){ f.y = 2600; f.vy = Math.min(f.vy, 0); }
}
export function stepRush(S, f, dt){
  const r = f.rush; if (!r) return;
  const tx = r.tgt ? r.tgt.x + r.off : r.px, ty = r.tgt ? r.tgt.y : r.py, rem = r.end - S.T;
  if (rem <= dt){ f.x = wrap(tx); f.y = Math.max(ty, groundY(S, tx)); f.rush = null; f.vx = 0; f.vy = 0; return; }
  const k = dt/rem;
  P(S, {type:'after', x:f.x, y:f.y, life:0.16, col:f.aura, face:f.face});
  f.x = wrap(f.x + sdx(f.x, tx)*k); f.y += (ty - f.y)*k;
}
export function stepFighter(S, f, dt){
  const o = opp(S, f), i = f.in;
  f.power = Math.min(100, f.power + 0.45*dt);
  const nt = 1 + (f.power >= 25) + (f.power >= 50) + (f.power >= 75);
  if (nt > f.tier){ f.tier = nt; tierUp(S, f); }
  let regen = 5 + (f.hidden ? 25 : 0);
  if (f.role === 'villain') regen += f.menace*0.03; else regen = Math.max(1, regen - f.anguish*0.025);
  if (f.role === 'hero') f.anguish = Math.max(0, f.anguish - 0.6*dt);
  if (f.state === 'free' || f.state === 'locked' || f.state === 'down') f.ki = Math.min(100, f.ki + regen*dt);
  if (f.hidden) f.hp = Math.min(f.maxhp, f.hp + 40*dt);
  if (f.state !== 'launched') f.rot *= Math.pow(0.001, dt);

  if (f.rush){ stepRush(S, f, dt); }
  else if (f.state === 'free'){
    const dxo = sdx(f.x, o.x); if (Math.abs(dxo) > 20) f.face = dxo > 0 ? 1 : -1;
    if (i.charge){ f.state = 'charging'; f.hidden = false; }
    else {
      let sp = 430*f.spd*(1 + 0.10*(f.tier - 1));
      if (f.stance === 2) sp *= 1.25; if (f.stance === 3) sp *= 1.35; if (f.stance === 1) sp *= 0.8;
      if (i.dash) sp *= 2.4;
      if (f.y < 0 && seaAt(S, f.x)) sp *= 0.55;
      const k = 1 - Math.pow(0.0008, dt);
      f.vx += (i.mx*sp - f.vx)*k; f.vy += (i.my*sp*0.85 - f.vy)*k;
      f.x = wrap(f.x + f.vx*dt); f.y += f.vy*dt;
      const g = groundY(S, f.x); if (f.y < g){ f.y = g; if (f.vy < 0) f.vy = 0; }
      if (f.y > 2600){ f.y = 2600; f.vy = 0; }
    }
  } else if (f.state === 'charging'){
    if (!i.charge) f.state = 'free';
    else {
      f.vx *= 0.85; f.vy *= 0.85; f.ki = Math.min(100, f.ki + 30*dt); f.power = Math.min(100, f.power + 9*dt);
      // Cosmetic draws (module-spec section 6): the spark chance and its four ranges, then the dust chance.
      if (next(S.rngFx) < 0.4) P(S, {type:'spark', x:f.x + range(S.rngFx, -40, 40), y:f.y + range(S.rngFx, 0, 70), vx:range(S.rngFx, -40, 40), vy:range(S.rngFx, 200, 500), life:0.4, col:f.aura, size:2});
      if (next(S.rngFx) < 0.06 && f.y < groundY(S, f.x) + 30) dust(S, f.x, groundY(S, f.x), 1);
    }
  } else if (f.state === 'down'){
    f.stateT += dt; f.y = groundY(S, f.x); if (f.stateT > 0.75){ f.state = 'free'; f.rot = 0; }
  } else if (f.state === 'launched'){
    stepLaunched(S, f, dt);
  } else if (f.state === 'locked'){
    f.vx *= Math.pow(0.03, dt); f.vy *= Math.pow(0.03, dt);
    f.x = wrap(f.x + f.vx*dt); f.y = Math.max(groundY(S, f.x), f.y + f.vy*dt);
  }
  if (!S.game.ko) updateHidden(S, f, dt);
}
