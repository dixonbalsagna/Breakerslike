// View-layer camera follow: the prototype's camStep without its shake (the cosmetic consumer, view/fx.js, keeps shake).
// The host calls camStep after each tick with S.dt. It reads S and never writes it.
import { wrap, sdx } from '../wrap.js';
import { clamp } from '../mathx.js';

// The values the prototype's newMatch gives the camera.
export function createCamera(){ return {x:2500, y:100, z:0.45}; }
export function resetCamera(cam){ cam.x = 2500; cam.y = 100; cam.z = 0.45; }

export function camStep(cam, S, dt, vw, vh){
  const a = S.fighters[0], b = S.fighters[1], d = sdx(a.x, b.x), mx = a.x + d/2, my = (a.y + b.y)/2;
  const spanX = Math.abs(d) + 700, spanY = Math.abs(a.y - b.y) + 500;
  let z = Math.min(vw/spanX, (vh*0.8)/spanY, 1.15);
  z *= 1 - 0.06*(Math.max(a.tier, b.tier) - 1);
  z = clamp(z, 0.06, 1.15);
  const k = 1 - S.m.pow(0.02, dt);
  cam.z += (z - cam.z)*k; cam.x = wrap(cam.x + sdx(cam.x, mx)*k);
  cam.y += (clamp(my + 40, -180, 2400) - cam.y)*k;
}
