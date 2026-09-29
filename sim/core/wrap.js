// Wrapped-planet math. The world is a circle of circumference W: there is no edge, only a seam at x = 0 = W.
import { W, HALF } from './constants.js';

// Any real x mapped into [0, W).
export const wrap = x => ((x % W) + W) % W;

// Signed shortest-arc displacement from a to b, in [-HALF, HALF]. Every distance and direction in the sim uses it.
export const sdx = (a, b) => { let d = (b - a) % W; if (d > HALF) d -= W; else if (d < -HALF) d += W; return d; };
