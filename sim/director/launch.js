// Launch planner: scores launch candidates with noise, a variety penalty and a personality term, then launches (prototype chooseLaunch, doLaunch).
import { range } from '../core/rng.js';
import { ring, shake } from '../core/fx.js';
import { groundY, seaAt } from '../world/terrain.js';
import { biomeAt } from '../world/biomes.js';
import { popNear, nearestBuilding } from '../world/structures.js';

export function chooseLaunch(S, A, D){
  const g = groundY(S, D.x), alt = D.y - g, bio = biomeAt(D.x), f = A.face, c = [];
  c.push({name:'UPPERCUT', ux:0.25*f, uy:1.0, s:14 + (alt < 120 ? 14 : 0)});
  c.push({name:'SLAM DOWN', ux:0.2*f, uy:-1.25, s:(alt > 140 ? 24 : 6) + A.tier*4 + (bio === 'ocean' ? 12 : 0) + (bio === 'city' ? 16 : 0) + (bio === 'forest' ? 8 : 0)});
  c.push({name:'SMASH ACROSS', ux:f, uy:0.18, s:16});
  for (const sign of [-1, 1]){
    const nb = nearestBuilding(S, D.x, sign, 1100, D.y);
    if (nb) c.push({name:'BUILDING SMASH', ux:sign, uy:0.12, s:12 + nb.b.h/32 + A.tier*3 + (sign === f ? 6 : -4), land:D.x + sign*nb.d});
    if (biomeAt(D.x + sign*520) === 'mountains') c.push({name:'MOUNTAINSIDE', ux:sign, uy:0.05, s:24, land:D.x + sign*520});
  }
  for (const k of c){
    const lx = k.land !== undefined ? k.land : D.x + k.ux*500;
    k.s += range(S.rng, 0, 8) + (-A.care) * 34 * popNear(S, lx, 700);
    if (k.name === S.dirS.lastLaunch) k.s -= 14; if (k.name === S.dirS.lastLaunch2) k.s -= 5;
  }
  c.sort((a,b) => b.s - a.s);
  return {best:c[0], top:c.slice(0,3)};
}
export function doLaunch(S, att, tgt, plan, force){
  const f = force*(1 + 0.16*(att.tier-1));
  tgt.state = 'launched'; tgt.launchBy = att; tgt.bounces = 0; tgt.stateT = 0; tgt.rush = null;
  tgt.hidden = false; tgt.wet = (tgt.y < 0 && seaAt(S, tgt.x));
  tgt.vx = plan.ux*f; tgt.vy = plan.uy*f; tgt.spin = (plan.ux >= 0 ? 1 : -1)*range(S.rng, 8, 16);
  ring(S, tgt.x, tgt.y+34, 600, '#ffffff', 0.3, 20);
  shake(S, 10);
}
