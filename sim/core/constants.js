// Fixed timestep and planet constants, exactly as the prototype has them (prototype/index.html at 7233c96).
// Numbers move into data files later, with Tools' schemas.
export const DT = 1 / 60;      // fixed simulation step in seconds
export const W = 9600;         // planet circumference in world units; x wraps into [0, W)
export const COL = 8;          // terrain column width
export const NC = W / COL;     // number of terrain columns (1200)
export const HALF = W / 2;     // the largest shortest-arc separation
