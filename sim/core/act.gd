class_name SimAct
## I2a (intent v2, docs/architecture/intent-v2.md §3): what a fighter's presses mean now, derived from the intent record
## and the fight. The state is Fighter.act (SimState.ActState), integers and bools, hashed. This file holds the container's
## rules that are the sim's own: the stance from the held states, the bookkeeping of guard, dodge, mode and the burst
## flag, and the request queue's primitives. Controls owns the numbers and the input rules (sim/input), Encounter reads
## the state in the director.
##
## Nothing here runs for a fighter whose act.v2 is false, so today's intents (the keyboard, the touch bridge, the AI)
## play exactly as before. A slot is v2 when the match setup says so ("v2": [bool, bool]) or when its writer sets
## f.act.v2 (the AI, in I2b). The flag goes with stance, dash and charge in I3.

const NEVER: int = -100000
## Setup "assists" names, as bit flags in act.assist: they let the sim act where an input is absent (Simple layout, mobile).
const ASSISTS: Array = ["autoBurst", "specialAuto", "perfectBlockAssist"]
## Request weights in the queue.
const LIGHT: int = 0
const HEAVY: int = 1
const SIG: int = 2

## Controls' numbers (docs/controls/input-scheme.md), set from its data in I2c; these are that document's values.
static var dodgeWindow: int = 12     # ticks a dodge reads as the Dodge state
static var awayDead: float = 0.3     # the stick beyond this, away from the opponent, with sprint: Escape
static var queueMax: int = 3         # requests the queue holds


## A new match: each fighter's act state, with v2 and the assists from the setup.
static func setup(S: SimState, su: Dictionary) -> void:
	var v2 = su.get("v2", [])
	var assists = su.get("assists", [])
	for k in range(S.fighters.size()):
		var a := SimState.ActState.new()
		a.v2 = k < v2.size() and v2[k] == true
		if k < assists.size():
			for name in assists[k]:
				var bit: int = ASSISTS.find(name)
				if bit >= 0:
					a.assist |= 1 << bit
		S.fighters[k].act = a


static func assisted(f, name: String) -> bool:
	return (f.act.assist & (1 << ASSISTS.find(name))) != 0


## Once per tick for a v2 fighter, from SimControl.control after the intent is in and gated: the cooldowns count down, and
## guard, dodge, mode and the burst flag follow the record. S.tick stamps the times (control does not run on a frozen
## tick, so a cooldown counts live ticks).
static func update(S: SimState, f, i: SimIntent) -> void:
	var a = f.act
	if a.dodgeCool > 0:
		a.dodgeCool -= 1
	if a.burstCool > 0:
		a.burstCool -= 1
	if i.guard:
		if a.guardSince < 0:
			a.guardSince = S.tick
	else:
		a.guardSince = -1
	if i.dodge:
		a.dodgeTick = S.tick
	if i.mode >= 0:
		a.mode = i.mode
	if i.powerPress:
		a.burstFired = false


## The stance the held states stand for, read by the director at exchange start as before: Guard (guard held), Escape
## (sprint, moving away from the opponent), Dodge (a dodge inside its window), otherwise Press. Neutral reads as Press
## until Combat and Game Design give it its own column.
static func stance(S: SimState, f, i: SimIntent) -> float:
	if i.guard:
		return 1.0
	if i.sprint and i.mx * SimMathx.jsign(SimWrap.sdx(f.x, SimRoster.opp(S, f).x)) < -awayDead:
		return 3.0
	if S.tick - f.act.dodgeTick < dodgeWindow:
		return 2.0
	return 0.0


## The burst, for the director: a power press while threatened fires it at once; otherwise a completed power tap fires it,
## unless this press already did (Controls' flag). The director decides "threatened" and applies the cost and cooldown.
static func wantsBurst(f, i: SimIntent, threatened: bool) -> bool:
	if i.powerPress and threatened:
		f.act.burstFired = true
		return true
	if i.powerTap and not f.act.burstFired:
		return true
	return false


# ---------------------------------------------------------------- the request queue

## A request joins the queue: [weight, mode, entry, tick]. False when the queue is full (the press is ignored).
static func push(f, weight: int, mode: int, entry: int, tick: int) -> bool:
	if f.act.queue.size() >= queueMax:
		return false
	f.act.queue.append([weight, mode, entry, tick])
	return true


## An upgrade (the layout saw the hold or the swipe): the newest queued request takes the heavier weight. False when the
## queue is empty (the director already started it: the caller queues a new request instead).
static func upgrade(f, weight: int) -> bool:
	if f.act.queue.is_empty():
		return false
	f.act.queue[f.act.queue.size() - 1][0] = weight
	return true


## Requests older than life ticks leave (the signature's longer wait is the caller's: pass its own life).
static func expire(f, tick: int, life: int) -> void:
	while not f.act.queue.is_empty() and tick - f.act.queue[0][3] > life:
		f.act.queue.pop_front()


## The oldest request, or an empty array.
static func peek(f) -> Array:
	return f.act.queue[0] if not f.act.queue.is_empty() else []


static func pop(f) -> Array:
	return f.act.queue.pop_front() if not f.act.queue.is_empty() else []


static func clear(f) -> void:
	f.act.queue.clear()
