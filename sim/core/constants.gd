class_name SimConst
## Fixed timestep and planet constants. NC is an int because it sizes and indexes arrays.
##
## World scale (docs/world/scale.md): the world is grown against the fighters, which stay as they are (a fighter is
## about 75 units tall). Three knobs, all in this file:
##  WS  feature scale. Buildings, trees, terrain relief, craters, scorch and the world's damage radii are multiplied by it.
##  PS  planet scale. The planet's length, and the biome spans and settlements laid along it, are multiplied by it.
##  TRAV_FREE and TRAV_LAUNCH  traversal factors. Free-flight dash and the horizontal part of a launch are multiplied
##  by these, so fighters cross the bigger world at anime speed while melee stays at fighter scale.
## The original planet is WS = PS = 1 with both traversal factors 1.

const DT: float = 1.0 / 60.0   # fixed simulation step in seconds
const WS: float = 8.0          # feature scale
const PS: float = 16.0         # planet scale: 9,600 x 16 = 153,600 units, about 2,050 fighter heights around
const MS: float = 12.0         # mountain relief scale (mountains are taller than a skyscraper)
const TRAV_FREE: float = 10.0  # dash speed multiplier at long range: a lap takes about 15 s flat out
const TRAV_LAUNCH: float = 6.0 # horizontal launch speed multiplier (impact damage and energy use the unboosted speed)
const BOOST_NEAR: float = 1500.0   # free-flight boost starts when the opponent is farther than this ...
const BOOST_FAR: float = 12000.0   # ... and is full at this separation
const W: float = 9600.0 * PS   # planet circumference; x wraps into [0, W)
const COL: float = 32.0        # terrain column width (0.43 fighter heights)
const NC: int = 4800           # number of terrain columns (W / COL)
const HALF: float = W / 2.0    # the largest shortest-arc separation
const CEILING: float = 24000.0 # flight ceiling (was 2,600): above the tallest building
const START_X: float = 5600.0 * PS   # where the first fighter starts: open ground at the desert's west edge, clear of every town (balance-targets.md §4b ruling 3; was 2150 x PS, the plains by the city); the second is 750 units on
const START_GAP: float = 750.0
