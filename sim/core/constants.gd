class_name SimConst
## Fixed timestep and planet constants: the twin of constants.js. NC is an int because it sizes and indexes arrays.

const DT: float = 1.0 / 60.0   # fixed simulation step in seconds
const W: float = 9600.0        # planet circumference; x wraps into [0, W)
const COL: float = 8.0         # terrain column width
const NC: int = 1200           # number of terrain columns (W / COL)
const HALF: float = 4800.0     # the largest shortest-arc separation
