// Terrain heightfield: world generation, ground height, sea test and craters (prototype genWorld, groundY, seaAt, crater).
import { COL, NC } from '../core/constants.js';
import { createRng, next } from '../core/rng.js';
import { wrap, sdx } from '../core/wrap.js';
import { clamp } from '../core/mathx.js';
import { biomeAt } from './biomes.js';
import { debris } from '../core/fx.js';

// Terrain, buildings and trees. The layout draws from its own stream seeded 4242, never from S.rng,
// so every match is played on the same planet whatever its seed.
export function genWorld(S){
  const r = createRng(4242), Rw = (a,b) => a + (b-a) * next(r);
  S.deform.fill(0);
  const t = new Float32Array(NC);
  for (let i = 0; i < NC; i++){
    const x = i*COL, b = biomeAt(x);
    const n = S.m.sin(x*0.0021)*0.5 + S.m.sin(x*0.0057+1.3)*0.3 + S.m.sin(x*0.013+2.1)*0.2;
    if (b === 'ocean') t[i] = -340 + n*35;
    else if (b === 'mountains'){
      const k = clamp((x-6500)/1100, 0, 1), env = S.m.sin(Math.PI*k);
      t[i] = env * (330 + 560*Math.abs(S.m.sin(x*0.0042+0.7))*(0.55+0.45*S.m.sin(x*0.013)));
    }
    else if (b === 'desert') t[i] = n*28;
    else if (b === 'plains') t[i] = n*16;
    else if (b === 'forest') t[i] = 10 + n*22;
    else t[i] = 0;
  }
  // Four wrapped 25-column box blurs. The two float32 buffers swap each pass, so a ends as t again.
  let a = t, bf = new Float32Array(NC);
  for (let p = 0; p < 4; p++){
    for (let i = 0; i < NC; i++){ let s = 0; for (let k = -12; k <= 12; k++) s += a[(i+k+NC)%NC]; bf[i] = s/25; }
    const tmp = a; a = bf; bf = tmp;
  }
  S.base.set(a);
  S.buildings.length = 0; S.trees.length = 0;
  let pop = 0;
  const row = (x0, x1, kind) => {
    let x = x0;
    while (x < x1){
      let w, h, b;
      if (kind === 'tower'){
        w = Rw(30,64); const cx = x + w/2, mid = 1 - Math.abs((cx-3100)/760);
        h = Rw(120,280) + Math.max(0,mid)*Rw(80,380);
        b = {x:cx,w,h,maxhp:h*6,hp:h*6,alive:true,kind:'tower',pop:Math.round(w*h/1200),seed:next(r)};
        x += w + Rw(4,16);
      } else {
        w = Rw(28,50); h = Rw(36,72);
        b = {x:x+w/2,w,h,maxhp:h*3,hp:h*3,alive:true,kind:'house',pop:Math.round(Rw(2,6)),seed:next(r)};
        x += w + Rw(16,70);
      }
      b.popAlive = b.pop; S.buildings.push(b); pop += b.pop;
    }
  };
  S.buildings.length = 0; S.trees.length = 0;
  row(1260, 1760, 'house'); row(2370, 3830, 'tower'); row(3880, 4480, 'house'); row(7640, 7960, 'house');
  let x = 4530;
  while (x < 5470){ S.trees.push({x,h:Rw(46,110),alive:true,burn:0}); x += Rw(16,40); }
  S.world = {pop0:pop, casualties:0, structuresLost:0, craters:0};
}

// Ground height at any x: linear between column samples of generated base plus crater deformation.
export function groundY(S, x){
  const c = wrap(x)/COL, i = Math.floor(c), f = c - i, j = (i+1) % NC;
  const a = S.base[i] + S.deform[i], b = S.base[j] + S.deform[j];
  return a + (b-a)*f;
}

// Water only where the generated base is below -30: craters never flood.
export function seaAt(S, x){ return S.base[Math.floor(wrap(x)/COL)] < -30; }

// Cosine-profiled dent of radius r (accumulated depth capped at 260) that fells trees within 1.05 r. cause is unused.
export function crater(S, x, r, depth, cause){
  const c0 = Math.floor(wrap(x)/COL), n = Math.ceil(r/COL);
  for (let k = -n; k <= n; k++){
    const i = (c0 + k + NC) % NC, f = S.m.cos(clamp(Math.abs(k*COL)/r, 0, 1) * Math.PI/2);
    S.deform[i] = Math.max(S.deform[i] - depth*f*f, -260);
  }
  for (const t of S.trees) if (t.alive && Math.abs(sdx(x,t.x)) < r*1.05){ t.alive = false; debris(S, t.x, groundY(S, t.x)+10, 3, '#2f4a25', 300); }
  S.world.craters++;
}
