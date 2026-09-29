// Signature beams: biome variants, outcomes by defender stance, the beam clash and beam sweeps that carve terrain (prototype planBeam and the closures it scheduled, startClash, fireBeam, sampleBeam, beamStep).
import { wrap, sdx } from '../core/wrap.js';
import { clamp } from '../core/mathx.js';
import { next, range } from '../core/rng.js';
import { hit } from '../core/damage.js';
import { banner, spark, ring, afterimage, dust, splash, fire } from '../core/fx.js';
import { groundY, seaAt, crater } from '../world/terrain.js';
import { biomeAt } from '../world/biomes.js';
import { damageArea, explode } from '../world/structures.js';
import { schedule } from './exchange.js';
import { doLaunch } from './launch.js';

export function planBeam(S, ex){
  const A = ex.A, D = ex.D, dist = Math.abs(sdx(A.x, D.x)), ds = D.dPrev === 'charging' ? 4 : D.stance;
  const bio = biomeAt(D.x);
  const variant = {ocean:'HORIZON CLEAVE', city:'BOULEVARD RAZE', village:'BOULEVARD RAZE', forest:'FIRESTORM', mountains:'RIDGE BORE', desert:'GLASS TRENCH', plains:'MERIDIAN SCAR'}[bio];
  let out;
  if (ds === 0 && D.ki >= 40 && !A.ambush) out = 'CLASH';
  else if (ds === 1) out = 'GUARD';
  else if (ds === 2) out = (next(S.rng) < clamp(0.55 - 0.06*(A.tier - D.tier), 0.2, 0.8) && !A.ambush) ? 'DODGE' : 'HIT';
  else if (ds === 3) out = (next(S.rng) < clamp(0.5 - 0.05*(A.tier - D.tier) + (dist < 500 ? 0.3 : 0), 0.15, 0.9)) ? 'HIT' : 'ESCAPE';
  else out = 'HIT';
  ex.tag = A.sigName + ' over ' + bio + ' (' + variant + ') → ' + out;
  const rise = clamp(dist*0.22, 90, 300);
  schedule(ex, 0, 'beamCharge', {rise});
  schedule(ex, 0.8, 'beamFire', {out, variant, dist});
}

// Beat 'beamCharge': the attacker rises above the defender and charges.
export function opBeamCharge(S, ex, args){
  const A = ex.A, D = ex.D;
  A.beamCharge = S.T; banner(S, A.sigName.toUpperCase(), A.aura, 1.1);
  A.rush = {px:A.x, py:Math.min(2400, D.y + args.rise), end:S.T + 0.55};
  ring(S, A.x, A.y + 40, 260, A.aura, 0.8, 10);
}
// Beat 'beamFire': fire, or start a beam clash; the outcome was decided when the beam was planned.
export function opBeamFire(S, ex, args){
  const A = ex.A, D = ex.D, out = args.out, variant = args.variant, dist = args.dist;
  A.beamCharge = null;
  if (D.hp <= 0 || A.hp <= 0) return;
  const len = Math.min(4200, dist + 2000 + A.tier*400);
  const ox = A.x, oy = A.y + 38, aimY = D.y + 36;
  if (out === 'CLASH'){ D.ki -= 40; startClash(S, ex, variant); return; }
  const dxs = sdx(ox, D.x), dyy = aimY - oy, L = S.m.hypot(dxs, dyy) || 1, ux = dxs/L, uy = dyy/L;
  fireBeam(S, A, ox, oy, ux, uy, len, variant);
  const reach = Math.min(0.2, dist/len*0.22);
  if (out === 'HIT' || out === 'GUARD'){
    schedule(ex, ex.t + reach, 'beamImpact', {out, ux, uy});
  } else if (out === 'DODGE'){
    schedule(ex, ex.t + 0.02, 'beamDodge');
  } else {
    schedule(ex, ex.t + 0.02, 'beamEscape');
  }
  schedule(ex, ex.t + 0.9, 'nop');
}
// Beat 'beamImpact': the beam connects (HIT) or is blocked (GUARD).
export function opBeamImpact(S, ex, args){
  const A = ex.A, D = ex.D, out = args.out;
  if (D.hp <= 0) return;
  if (D.state === 'locked') D.state = 'free';
  hit(S, ex, A, D, out === 'GUARD' ? 200 : 230, {ignoreStance: out !== 'GUARD', stop:0.14, shake:16, big:true});
  explode(S, D.x, D.y + 30, 60 + A.tier*30, A);
  if (D.hp > 0){ D.state = 'locked'; doLaunch(S, A, D, {ux:args.ux, uy:args.uy*0.6 + 0.12}, out === 'GUARD' ? 1300 : 2600); }
}
// Beat 'beamDodge'.
export function opBeamDodge(S, ex, args){
  const D = ex.D;
  afterimage(S, D); D.y += 300; D.vx = 0; D.vy = 0; banner(S, 'DODGED', '#9fe0ff', 0.7);
}
// Beat 'beamEscape'.
export function opBeamEscape(S, ex, args){
  const A = ex.A, D = ex.D;
  afterimage(S, D); D.state = 'free'; D.vx = Math.sign(sdx(A.x, D.x))*1600; D.vy = range(S.rng, -100, 300); banner(S, 'ESCAPED', '#9fe0b0', 0.7);
}

export function startClash(S, ex, variant){
  const A = ex.A, D = ex.D;
  const sc = f => f.tier*10 + f.ki*0.35 + range(S.rng, 0, 16) + (f.role === 'villain' ? f.menace*0.08 : 0);
  const aw = sc(A) > sc(D);
  S.game.clash = {A, D, t0:S.T, dur:1.6, aw};
  banner(S, 'BEAM CLASH', '#ffffff', 1.2);
  schedule(ex, ex.t + 1.6, 'clashResolve', {aw, variant});
  schedule(ex, ex.t + 2.6, 'nop');
}
// Beat 'clashResolve': the clash winner's beam overpowers the loser.
export function opClashResolve(S, ex, args){
  const A = ex.A, D = ex.D, variant = args.variant, Wn = args.aw ? A : D, Ls = args.aw ? D : A;
  S.game.clash = null;
  if (Ls.hp <= 0 || Wn.hp <= 0) return;
  const dxs = sdx(Wn.x, Ls.x), dyy = (Ls.y + 36) - (Wn.y + 38), L = S.m.hypot(dxs, dyy) || 1;
  const ux = dxs/L, uy = dyy/L, len = Math.min(4200, L + 2000 + Wn.tier*400);
  fireBeam(S, Wn, Wn.x, Wn.y + 38, ux, uy, len, variant);
  Ls.state = 'locked';
  hit(S, ex, Wn, Ls, 260, {ignoreStance:true, stop:0.16, shake:18, big:true});
  explode(S, Ls.x, Ls.y + 30, 70 + Wn.tier*32, Wn);
  if (Ls.hp > 0) doLaunch(S, Wn, Ls, {ux:ux, uy:uy*0.6 + 0.12}, 2600);
}
export function fireBeam(S, A, ox, oy, ux, uy, len, variant){
  S.beams.push({A, ox, oy, ux, uy, len, p:0, t:0, life:0.95, w:24 + A.tier*9, variant, col:A.aura});
  S.fx.shake = Math.max(S.fx.shake, 14);
}
export function sampleBeam(S, b, s){
  const A = b.A, tier = A.tier, x = wrap(b.ox + b.ux*s), y = b.oy + b.uy*s, g = groundY(S, x);
  if (y < g + 40 + tier*12){
    crater(S, x, 20 + tier*7, (b.variant === 'RIDGE BORE' ? 9 : 5) + tier*2.2, A);
    dust(S, x, g + 8, 1, b.variant === 'GLASS TRENCH' ? '#e6c47a' : '#9b8f7e');
    if (b.variant === 'GLASS TRENCH') spark(S, x, g + 6, 2, '#ffd98a', 300);
  }
  damageArea(S, x, y, 26 + tier*8, 110 + tier*75, A);
  if (y < 30 && seaAt(S, x) && next(S.rngFx) < 0.6) splash(S, x, 0, 3);   // cosmetic draw (module-spec section 6)
  if (b.variant === 'FIRESTORM' && y < g + 140) fire(S, x, g, 1);
}
export function beamStep(S, dt){
  for (let i = S.beams.length - 1; i >= 0; i--){
    const b = S.beams[i]; b.t += dt;
    const np = Math.min(1, b.t/0.22), s0 = b.p*b.len, s1 = np*b.len; b.p = np;
    for (let s = s0; s < s1; s += 36) sampleBeam(S, b, s);
    if (b.t > b.life) S.beams.splice(i, 1);
  }
}
