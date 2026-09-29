// Hiding cover: nearby trees, the cover a fighter is in and the nearest cover biome (prototype nearTree, coverAt, nearestCover).
import { sdx } from '../core/wrap.js';
import { groundY } from './terrain.js';
import { biomeAt } from './biomes.js';

export function nearTree(S, x){ for (const t of S.trees) if (t.alive && Math.abs(sdx(x, t.x)) < 120) return true; return false; }

// Deep water, low among standing forest trees, or low on a mountain; null when the fighter is in the open.
export function coverAt(S, f){
  const g = groundY(S, f.x), b = biomeAt(f.x);
  if (b === 'ocean' && f.y < -60 && g < -100) return 'submerged';
  if (b === 'forest' && f.y < g + 70 && nearTree(S, f.x)) return 'canopy';
  if (b === 'mountains' && f.y < g + 40) return 'ridge';
  return null;
}

// Nearest cover biome in 100-unit steps out to 4000, right before left. It reads only the static biome layout,
// not whether the forest still has trees or the water is deep enough to submerge in.
export function nearestCover(x){
  for (let off = 0; off <= 4000; off += 100){
    for (const s of (off ? [1, -1] : [1])){ const b = biomeAt(x + s*off); if (b === 'ocean' || b === 'forest' || b === 'mountains') return {off:s*off, b}; }
  }
  return null;
}
