// Cosmetic lane (S.fx): the prototype's banner, P, spark, ring, debris, dust, splash, fire, afterimage and stepParts.
// Every random draw here is cosmetic and uses S.rngFx (module-spec section 6); in the parity build it is S.rng itself.
// Gameplay code never reads S.fx.
import { wrap } from './wrap.js';
import { next, range } from './rng.js';
import { groundY } from '../world/terrain.js';

export function banner(S, text, col, dur){ S.fx.banner = {text, col: col || '#ffffff', t: 0, dur: dur || 1.3}; }

// Particle spawn. Callers build the object (and make its draws) before P runs, so draws happen even at the cap.
export function P(S, o){
  if (S.fx.parts.length > 2400) return;
  S.fx.parts.push(Object.assign({life:1,age:0,grav:0,drag:0,size:3,col:'#fff',type:'dot',vx:0,vy:0,r:0,gr:0}, o));
}
export function spark(S, x,y,n,col,spd){
  for (let i = 0; i < n; i++){ const a = range(S.rngFx, 0,6.283), s = range(S.rngFx, 0.3,1)*(spd||500);
    P(S, {type:'spark',x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s,life:range(S.rngFx, 0.15,0.4),col:col||'#fff3c0',size:range(S.rngFx, 1.5,3)}); }
}
export function ring(S, x,y,gr,col,life,r0){ P(S, {type:'ring',x,y,r:r0||10,gr,life:life||0.5,col:col||'#ffffff'}); }
export function debris(S, x,y,n,col,spd){
  for (let i = 0; i < n; i++){ const a = range(S.rngFx, 0.2,2.9); const s = range(S.rngFx, 0.2,1)*(spd||500);
    P(S, {type:'deb',x:x+range(S.rngFx, -20,20),y,vx:Math.cos(a)*s*(next(S.rngFx)<0.5?-1:1),vy:Math.sin(a)*s,grav:900,life:range(S.rngFx, 0.8,1.8),col:col||'#6d6a66',size:range(S.rngFx, 3,9)}); }
}
export function dust(S, x,y,n,col){
  for (let i = 0; i < n; i++) P(S, {type:'dust',x:x+range(S.rngFx, -40,40),y:y+range(S.rngFx, 0,20),vx:range(S.rngFx, -90,90),vy:range(S.rngFx, 20,140),life:range(S.rngFx, 0.8,1.8),col:col||'#9b8f7e',size:range(S.rngFx, 14,34),drag:0.02});
}
export function splash(S, x,y,n){
  for (let i = 0; i < n; i++) P(S, {type:'splash',x:x+range(S.rngFx, -30,30),y,vx:range(S.rngFx, -160,160),vy:range(S.rngFx, 250,900),grav:1200,life:range(S.rngFx, 0.7,1.5),col:'#bfe6ff',size:range(S.rngFx, 2,5)});
}
export function fire(S, x,y,n){
  for (let i = 0; i < n; i++) P(S, {type:'flame',x:x+range(S.rngFx, -25,25),y:y+range(S.rngFx, 0,30),vx:range(S.rngFx, -30,30),vy:range(S.rngFx, 60,200),life:range(S.rngFx, 0.5,1.3),col:next(S.rngFx)<0.5?'#ff9a2e':'#ffd45a',size:range(S.rngFx, 6,16)});
}
export function afterimage(S, f){ P(S, {type:'after',x:f.x,y:f.y,life:0.45,col:f.aura,face:f.face}); }

// Particles (swap-remove when expired), then the damage numbers.
export function stepParts(S, dt){
  const parts = S.fx.parts, floats = S.fx.floats;
  for (let i = parts.length - 1; i >= 0; i--){
    const p = parts[i]; p.age += dt;
    if (p.age >= p.life){ parts[i] = parts[parts.length-1]; parts.pop(); continue; }
    p.vy -= p.grav*dt;
    if (p.drag){ const d = Math.pow(1 - p.drag, dt*60); p.vx *= d; p.vy *= d; }
    p.x = wrap(p.x + p.vx*dt); p.y += p.vy*dt;
    if (p.type === 'ring') p.r += p.gr*dt;
    if (p.type === 'deb'){ const g = groundY(S, p.x); if (p.y < g){ p.y = g; p.vy *= -0.3; p.vx *= 0.6; } }
  }
  for (let i = floats.length - 1; i >= 0; i--){ const f = floats[i]; f.t += dt; f.y += 60*dt; if (f.t > 0.9) floats.splice(i, 1); }
}
