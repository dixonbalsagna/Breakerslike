class_name SimAim
extends RefCounted
## The stick as an aim (docs/controls/agency-input.md 1b): the 8-sector snap and the latch of the stick's launch direction,
## for the fight alchemist (the recipe's pool, the launch's direction, a juggle's return blow). Pure functions over plain
## data: no state of its own, no engine, no clock, no RNG, and no trig (comparisons and multiplications only), so a replay and
## a peer read the same sector from the same intent. The latch is a small Dictionary the director keeps per fighter
## ({sector, tick}, two integers, hashed with the rest of its state).
##
## Sectors are screen-absolute, counter-clockwise from the right, as flight is steered (stick right flies right):
##   0 right, 1 up-right, 2 up, 3 up-left, 4 left, 5 down-left, 6 down, 7 down-right, and NONE (-1) inside the dead zone.
## `my` is up, as in the intent. A keyboard has only these eight directions; the stick is quantised to the same eight, so
## neither device is at an advantage, and the director snaps the sector to a real target (`snap`), so the tilt never has to
## be exact. All numbers are data (timing.json, the `aim` block).

const NONE: int = -1
const RIGHT: int = 0
const UP_RIGHT: int = 1
const UP: int = 2
const UP_LEFT: int = 3
const LEFT: int = 4
const DOWN_LEFT: int = 5
const DOWN: int = 6
const DOWN_RIGHT: int = 7

## tan(22.5 degrees): a direction is on an axis while its minor component is below this fraction of its major one.
const TAN_22_5: float = 0.4142135623730951

## The unit step of each sector, x then y: (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1).
const STEP_X: Array = [1, 1, 0, -1, -1, -1, 0, 1]
const STEP_Y: Array = [0, 1, 1, 1, 0, -1, -1, -1]

const DEFAULTS: Dictionary = {
	"deadZone": 0.35,     # the stick must pass this fraction of full deflection to aim (the move dead zone is 0.2)
	"latchTicks": 12,     # the latest aim within this many ticks of the launch decision still counts
	"snapMax": 1,         # the director snaps to a target within this many sectors (1 is 45 degrees)
}


## The numbers, from data over the defaults.
static func params() -> Dictionary:
	var p: Dictionary = DEFAULTS.duplicate()
	p["deadZone"] = SimInputData.tf(["aim", "deadZone"], float(DEFAULTS["deadZone"]))
	p["latchTicks"] = SimInputData.ti(["aim", "latchTicks"], int(DEFAULTS["latchTicks"]))
	p["snapMax"] = SimInputData.ti(["aim", "snapMax"], int(DEFAULTS["snapMax"]))
	return p


## The sector of a stick position: NONE inside the dead zone (a circle of radius `deadZone`), else 0 to 7. A direction within
## 22.5 degrees of an axis is that axis; the rest are the diagonals. Exact on the boundary: an angle of exactly 22.5 degrees
## reads as the diagonal.
static func sector(mx: float, my: float, dead_zone: float = -1.0) -> int:
	var dz: float = dead_zone if dead_zone >= 0.0 else float(params()["deadZone"])
	if mx * mx + my * my <= dz * dz:
		return NONE
	var ax: float = absf(mx)
	var ay: float = absf(my)
	if ay < ax * TAN_22_5:
		return RIGHT if mx > 0.0 else LEFT
	if ax < ay * TAN_22_5:
		return UP if my > 0.0 else DOWN
	if mx > 0.0:
		return UP_RIGHT if my > 0.0 else DOWN_RIGHT
	return UP_LEFT if my > 0.0 else DOWN_LEFT


## The sector an intent's stick is in.
static func of_intent(i: SimIntent, dead_zone: float = -1.0) -> int:
	return sector(i.mx, i.my, dead_zone)


## The unit step (x, y) of a sector as integers, (0, 0) for NONE. y is up.
static func step_x(s: int) -> int:
	return int(STEP_X[s]) if s >= 0 and s < 8 else 0


static func step_y(s: int) -> int:
	return int(STEP_Y[s]) if s >= 0 and s < 8 else 0


## A fresh latch: nothing aimed.
static func new_latch() -> Dictionary:
	return {"sector": NONE, "tick": -1000000}


## Feed the stick once a tick: a sample beyond the dead zone becomes the latch (the newest wins); a sample inside it changes
## nothing, so releasing the stick as the last button goes down keeps the aim. Returns the latch (mutated in place).
static func update(latch: Dictionary, mx: float, my: float, tick: int, opts: Dictionary = {}) -> Dictionary:
	var s: int = sector(mx, my, float(opts.get("deadZone", -1.0)))
	if s != NONE:
		latch["sector"] = s
		latch["tick"] = tick
	return latch


## The aim at the launch decision on `tick`: the latched sector if it is at most `latchTicks` old, else NONE.
static func read(latch: Dictionary, tick: int, opts: Dictionary = {}) -> int:
	var n: int = int(opts.get("latchTicks", params()["latchTicks"]))
	if int(latch["sector"]) != NONE and tick - int(latch["tick"]) <= n:
		return int(latch["sector"])
	return NONE


## Forget the aim (a new exchange, or the launch has used it).
static func clear(latch: Dictionary) -> void:
	latch["sector"] = NONE
	latch["tick"] = -1000000


## How many sectors apart two sectors are, 0 to 4 (a half turn is 4). NONE is not near anything: 99.
static func distance(a: int, b: int) -> int:
	if a < 0 or b < 0:
		return 99
	var d: int = absi(a - b) % 8
	return mini(d, 8 - d)


## The director's snap: of `candidates` (sectors a real target or launch lies in, listed most dramatic first), the index of the
## one nearest `aim` within `snapMax` sectors, the earlier one on a tie; -1 if there is no aim or none is near enough. With
## no aim the director picks freely, as agency-pass.md says.
static func snap(aim: int, candidates: Array, opts: Dictionary = {}) -> int:
	if aim < 0:
		return -1
	var max_d: int = int(opts.get("snapMax", params()["snapMax"]))
	var best: int = -1
	var best_d: int = 99
	for k in range(candidates.size()):
		var d: int = distance(aim, int(candidates[k]))
		if d <= max_d and d < best_d:
			best = k
			best_d = d
	return best


## The pool the stick picks relative to the rival: "toward" (the horizontal part points at him), "away", or "level" (straight
## up or down, or no aim). `opp_sign` is +1 when the rival is to the right on the shortest arc, -1 to the left
## (`jsign(sdx(f.x, opp.x))`). A diagonal counts by its horizontal part.
static func pool(aim: int, opp_sign: int) -> String:
	var sx: int = step_x(aim) * (1 if opp_sign >= 0 else -1)
	if sx > 0:
		return "toward"
	if sx < 0:
		return "away"
	return "level"
