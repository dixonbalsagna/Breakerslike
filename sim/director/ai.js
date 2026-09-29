// Opponent AI: timed weighted stance picks, movement by stance, and attack timing: the prototype's pickW and aiInput.
import { DT } from '../core/constants.js';
import { next, range } from '../core/rng.js';
import { sdx } from '../core/wrap.js';
import { opp } from '../core/roster.js';
import { groundY } from '../world/terrain.js';
import { popNear } from '../world/structures.js';
import { nearestCover } from '../world/cover.js';

// Index drawn with probability proportional to its weight. One draw from S.rng.
export function pickW(S, w){ let s = 0; for (const v of w) s += v; let r = next(S.rng)*s; for (let k = 0; k < w.length; k++){ r -= w[k]; if (r <= 0) return k; } return 0; }

// Writes f.in (already cleared by control) and f.ai timers; changes f.stance only while f is free.
// Timers count down by the fixed DT: control never reaches here during hit-stop or KO slow motion.
export function aiInput(S, f){
  const o = opp(S, f), i = f.in, a = f.ai, d = sdx(f.x, o.x), dist = Math.abs(d), hpF = f.hp/f.maxhp;
  a.t -= DT; a.atk -= DT;
  if (a.t <= 0){
    a.t = range(S.rng, 0.7, 1.6);
    let w = [hpF > 0.35 ? 2.4 : 1.0, hpF < 0.55 ? 1.6 : 0.7, 1.2, hpF < 0.3 ? 3.2 : (f.ki < 25 ? 1.2 : 0.25)];
    if (o.hidden) w = [3, 0.3, 0.3, 0.1];
    if (f.hidden && (hpF < 0.85 || f.ki < 85)) w = [0, 0, 0, 1];
    if (f.state === 'free') f.stance = pickW(S, w);
  }
  const free = f.state === 'free' || f.state === 'charging';
  if (!free) return;
  const st = f.stance;
  // The hero leads fights out of populated areas, steering away from the city centre (x 3100).
  const lure = f.role === 'hero' && st !== 3 && popNear(S, f.x, 900) > 0.2;
  if (lure){ i.mx = Math.sign(sdx(3100, f.x)) || 1; i.dash = true; i.my = 0; }
  else if (st === 0 && o.hidden && o.lastSeen){
    // Hunt: sweep random offsets around the last known position, re-rolled every 1.2 to 2.4 s.
    a.sT -= DT; if (a.sT <= 0){ a.sT = range(S.rng, 1.2, 2.4); a.sOff = range(S.rng, -1700, 1700); }
    const tx = o.lastSeen.x + a.sOff, sd = sdx(f.x, tx);
    i.mx = Math.abs(sd) > 60 ? Math.sign(sd) : 0; i.dash = Math.abs(sd) > 1500; i.my = -1;
  } else if (st === 0){
    i.mx = dist > 130 ? Math.sign(d) : 0; i.dash = dist > 700;
    const dy = o.y - f.y; i.my = Math.abs(dy) > 40 ? Math.sign(dy) : 0;
  } else if (st === 1){
    i.mx = 0; if (f.ki < 55 && dist > 350) i.charge = true;
  } else if (st === 2){
    i.mx = dist < 500 ? -Math.sign(d) : Math.sign(d)*0.5; i.my = S.m.sin(S.T*1.7 + f.x*0.01);
  } else {
    // Escape: head for the nearest cover biome, then sink into it.
    const c = nearestCover(f.x);
    if (c && Math.abs(c.off) > 60){ i.mx = Math.sign(c.off); i.dash = Math.abs(c.off) > 300; }
    else { i.mx = 0; const g = groundY(S, f.x); if (c && c.b === 'ocean') i.my = f.y > -110 ? -1 : 0; else i.my = f.y > g + 20 ? -1 : 0; }
  }
  if (a.atk <= 0 && !o.hidden && st !== 3 && !S.dirS.ex){
    const r = next(S.rng);
    if (f.ki >= 50 && r < 0.2) i.sig = true; else if (r < 0.5) i.heavy = true; else i.light = true;
    a.atk = st === 0 ? range(S.rng, 0.35, 1.0) : st === 1 ? range(S.rng, 1.2, 2.5) : range(S.rng, 0.9, 1.8);
  } else if (a.atk <= 0) a.atk = 0.3;
}
