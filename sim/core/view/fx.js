// Reference cosmetic consumer (render side): turns the sim's fx events (docs/architecture/fx-events.md) into particles,
// damage numbers, the banner and camera shake. It reads the sim (terrain height, the math table) and never writes it.
// The spawn and step code is the prototype's P, spark, ring, debris, dust, splash, fire and stepParts, moved out of the
// sim; its random numbers come from cosmetic streams seeded from the match seed, one per effect class (the canonical
// RNG rule in overview.md section 3). The GDScript twin is view/fx.gd.
import { createRng, next, range, deriveSeed } from '../rng.js';
import { wrap } from '../wrap.js';
import { groundY } from '../../world/terrain.js';

export const STREAMS = ['vfx.spark', 'vfx.debris', 'vfx.dust', 'vfx.splash', 'vfx.fire', 'vfx.charge', 'vfx.water'];

export function createFxView(seed) {
  const V = { parts: [], floats: [], banner: null, shake: 0, rng: {} };
  resetFxView(V, seed);
  return V;
}
// A new match: empty the view and reseed every stream from the match seed.
export function resetFxView(V, seed) {
  V.parts.length = 0; V.floats.length = 0; V.banner = null; V.shake = 0;
  for (const id of STREAMS) V.rng[id] = createRng(deriveSeed(seed, id));
}

function P(V, o) {
  if (V.parts.length > 2400) return;
  V.parts.push(Object.assign({life:1,age:0,grav:0,drag:0,size:3,col:'#fff',type:'dot',vx:0,vy:0,r:0,gr:0}, o));
}
function spark(V, S, x, y, n, col, spd, r) {
  for (let i = 0; i < n; i++){ const a = range(r, 0,6.283), s = range(r, 0.3,1)*spd;
    P(V, {type:'spark',x,y,vx:S.m.cos(a)*s,vy:S.m.sin(a)*s,life:range(r, 0.15,0.4),col,size:range(r, 1.5,3)}); }
}
function debris(V, S, x, y, n, col, spd, r) {
  for (let i = 0; i < n; i++){ const a = range(r, 0.2,2.9); const s = range(r, 0.2,1)*spd;
    P(V, {type:'deb',x:x+range(r, -20,20),y,vx:S.m.cos(a)*s*(next(r)<0.5?-1:1),vy:S.m.sin(a)*s,grav:900,life:range(r, 0.8,1.8),col,size:range(r, 3,9)}); }
}
function dust(V, x, y, n, col, r) {
  for (let i = 0; i < n; i++) P(V, {type:'dust',x:x+range(r, -40,40),y:y+range(r, 0,20),vx:range(r, -90,90),vy:range(r, 20,140),life:range(r, 0.8,1.8),col,size:range(r, 14,34),drag:0.02});
}
function splash(V, x, y, n, r) {
  for (let i = 0; i < n; i++) P(V, {type:'splash',x:x+range(r, -30,30),y,vx:range(r, -160,160),vy:range(r, 250,900),grav:1200,life:range(r, 0.7,1.5),col:'#bfe6ff',size:range(r, 2,5)});
}
function fire(V, x, y, n, r) {
  for (let i = 0; i < n; i++) P(V, {type:'flame',x:x+range(r, -25,25),y:y+range(r, 0,30),vx:range(r, -30,30),vy:range(r, 60,200),life:range(r, 0.5,1.3),col:next(r)<0.5?'#ff9a2e':'#ffd45a',size:range(r, 6,16)});
}

// Particles (swap-remove when expired), then the damage numbers.
function stepParts(V, S, dt) {
  const parts = V.parts, floats = V.floats;
  for (let i = parts.length - 1; i >= 0; i--){
    const p = parts[i]; p.age += dt;
    if (p.age >= p.life){ parts[i] = parts[parts.length-1]; parts.pop(); continue; }
    p.vy -= p.grav*dt;
    if (p.drag){ const d = S.m.pow(1 - p.drag, dt*60); p.vx *= d; p.vy *= d; }
    p.x = wrap(p.x + p.vx*dt); p.y += p.vy*dt;
    if (p.type === 'ring') p.r += p.gr*dt;
    if (p.type === 'deb'){ const g = groundY(S, p.x); if (p.y < g){ p.y = g; p.vy *= -0.3; p.vx *= 0.6; } }
  }
  for (let i = floats.length - 1; i >= 0; i--){ const f = floats[i]; f.t += dt; f.y += 60*dt; if (f.t > 0.9) floats.splice(i, 1); }
}

// Consume one tick's events, in order. The 'tick' event steps the particles where the prototype did; the banner timer
// and the shake decay run at the end of the tick, as the prototype's did.
export function consumeFx(V, S, events) {
  let dt = 0, frozen = true;
  const R = V.rng;
  for (const e of events) {
    switch (e.type) {
      case 'spark': spark(V, S, e.x, e.y, e.n, e.col, e.spd, R['vfx.spark']); break;
      case 'debris': debris(V, S, e.x, e.y, e.n, e.col, e.spd, R['vfx.debris']); break;
      case 'dust': dust(V, e.x, e.y, e.n, e.col, R['vfx.dust']); break;
      case 'splash': splash(V, e.x, e.y, e.n, R['vfx.splash']); break;
      case 'fire': fire(V, e.x, e.y, e.n, R['vfx.fire']); break;
      case 'ring': P(V, {type:'ring', x:e.x, y:e.y, r:e.r0, gr:e.gr, life:e.life, col:e.col}); break;
      case 'after': P(V, {type:'after', x:e.x, y:e.y, life:e.life, col:e.col, face:e.face}); break;
      case 'charge': {
        const r = R['vfx.charge'];
        if (next(r) < 0.4) P(V, {type:'spark', x:e.x + range(r, -40, 40), y:e.y + range(r, 0, 70), vx:range(r, -40, 40), vy:range(r, 200, 500), life:0.4, col:e.col, size:2});
        if (next(r) < 0.06 && e.y < e.ground + 30) dust(V, e.x, e.ground, 1, '#9b8f7e', R['vfx.dust']);
        break;
      }
      case 'beamSplash': if (next(R['vfx.water']) < 0.6) splash(V, e.x, 0, 3, R['vfx.splash']); break;
      case 'damage': V.floats.push({x:e.x, y:e.y, txt:String(Math.round(e.amount)), t:0, col:e.col}); break;
      case 'banner': V.banner = {text:e.text, col:e.col, t:0, dur:e.dur}; break;
      case 'shake': V.shake = Math.max(V.shake, e.k); break;
      case 'tick': dt = e.dt; frozen = e.frozen; stepParts(V, S, frozen ? dt*0.1 : dt); break;
      default: throw new Error('consumeFx: unknown event ' + e.type);
    }
  }
  if (!frozen && V.banner){ V.banner.t += dt; if (V.banner.t > V.banner.dur) V.banner = null; }
  V.shake *= S.m.pow(0.02, dt);
}
