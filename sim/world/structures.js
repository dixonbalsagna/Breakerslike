// Buildings and civilians: collateral damage and casualties (prototype curH, casualty, damageBuilding, damageArea, explode, popNear, nearestBuilding).
import { sdx } from '../core/wrap.js';
import { clamp } from '../core/mathx.js';
import { groundY, crater } from './terrain.js';
import { spark, ring, debris, dust, fire, shake } from '../core/fx.js';

// Standing height shrinks with damage to 30 percent of full; a destroyed building leaves 9 units of rubble.
export function curH(b){ return b.alive ? b.h*(0.3 + 0.7*b.hp/b.maxhp) : 9; }

// Casualties feed the villain who caused them (menace, power) and the hero's anguish (more if the hero caused them).
export function casualty(S, n, cause){
  if (n <= 0) return;
  S.world.casualties += n;
  if (cause && cause.role === 'villain'){ cause.menace = Math.min(100, cause.menace + n*0.9); cause.power = Math.min(100, cause.power + n*0.09); }
  const hero = S.fighters.find(f => f.role === 'hero');   // QA-003: only the first hero in the list accrues anguish
  if (hero) hero.anguish = Math.min(100, hero.anguish + n*(cause === hero ? 0.9 : 0.5));
}

export function damageBuilding(S, b, d, cause){
  if (!b.alive || d <= 0) return;
  const before = b.hp; b.hp -= d;
  const frac = Math.min(before, d) / b.maxhp;
  const dead = Math.min(b.popAlive, b.pop*frac*1.3);
  b.popAlive -= dead; casualty(S, dead, cause);
  const gy = groundY(S, b.x);
  if (b.hp <= 0){
    b.alive = false; S.world.structuresLost++;
    casualty(S, b.popAlive, cause); b.popAlive = 0;
    debris(S, b.x, gy + b.h*0.5, 14, b.kind === 'tower' ? '#77808f' : '#8a6a4a', 620);
    dust(S, b.x, gy, 5, '#a89f92');
    if (b.h > 200) shake(S, 10);
  } else {
    debris(S, b.x, gy + curH(b), 4, '#77808f', 300);
  }
}

// Standing buildings whose footprint is within r and whose top reaches y - 0.6 r take dmg, falling to 30 percent at r.
// Trees within 0.7 r are destroyed when y is less than r above their ground.
export function damageArea(S, x, y, r, dmg, cause){
  for (const b of S.buildings){
    if (!b.alive) continue;
    const d = Math.abs(sdx(x,b.x)) - b.w/2;
    if (d > r) continue;
    const top = groundY(S, b.x) + curH(b);
    if (y - r*0.6 > top) continue;
    damageBuilding(S, b, dmg * (1 - clamp(d/r,0,1)*0.7), cause);
  }
  for (const t of S.trees){ if (t.alive && Math.abs(sdx(x,t.x)) < r*0.7 && y < groundY(S, t.x)+r){ t.alive = false; fire(S, t.x, groundY(S, t.x), 2); } }
}

export function explode(S, x, y, r, cause){
  spark(S, x,y,26,'#fff1b5',900); ring(S, x,y,r*2.6,'#ffe2a0',0.5,20); ring(S, x,y,r*1.5,'#ff8a3d',0.7,10);
  fire(S, x,y,10); debris(S, x,y,10,'#6d6a66',700);
  damageArea(S, x,y,r*1.8,130 + cause.tier*110,cause);
  if (y < groundY(S, x) + r) crater(S, x, r*0.9, 18 + cause.tier*8, cause);
  shake(S, 16); S.dirS.stop = Math.max(S.dirS.stop, 0.08);
}

// Living civilians in standing buildings centred within r of x, scaled so 70 or more reads 1.
export function popNear(S, x, r){
  let s = 0;
  for (const b of S.buildings) if (b.alive && Math.abs(sdx(x,b.x)) < r) s += b.popAlive;
  return clamp(s/70, 0, 1);
}

// Nearest standing building on one side (sign), more than 60 and less than maxD away, whose top is above y - 40.
export function nearestBuilding(S, x, sign, maxD, y){
  let best = null, bd = 1e9;
  for (const b of S.buildings){
    if (!b.alive) continue;
    const d = sdx(x, b.x)*sign;
    if (d > 60 && d < maxD && d < bd && y < groundY(S, b.x) + curH(b) + 40){ bd = d; best = b; }
  }
  return best ? {b:best, d:bd} : null;
}
