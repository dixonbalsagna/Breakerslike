// Biome layout of the wrapped planet: SEG and biomeAt from the prototype's "world (wrapped planet)" section.
import { wrap } from '../core/wrap.js';

// [start, end, biome] spans of world x, in order, covering [0, W). Static data, never written.
export const SEG = [[0,1200,'ocean'],[1200,1800,'village'],[1800,2350,'plains'],[2350,3850,'city'],[3850,4500,'village'],[4500,5500,'forest'],[5500,6500,'desert'],[6500,7600,'mountains'],[7600,8000,'village'],[8000,8300,'plains'],[8300,9600,'ocean']];

export function biomeAt(x){ x = wrap(x); for (const s of SEG) if (x >= s[0] && x < s[1]) return s[2]; return 'plains'; }
