class_name SimPressRead
extends RefCounted
## The press reader for the "fight alchemist" (docs/controls/agency-input.md, 1a): from a short log of a fighter's attack
## presses it says whether the player is holding, tapping in time with the blows, mashing, or tapping deliberately, and
## what the running mix of attack types is. Pure functions over plain data: no state, no engine, no clock, no RNG, so the
## sim, the AI, QA and the tests all read a log the same way and a replay reproduces it. The log itself is the sim's state
## (Encounter and Simulation own it); this file only builds and reads it.
##
## A log is an Array of entries, oldest first, at most `logSize` long (5: the alchemist reads the last five presses):
##   {kind: int (LIGHT, HEAVY, SIG), mode: int (0 physical, 1 energy), down: int tick, up: int tick or -1 while held,
##    beat: int}
## `beat` is the signed distance in ticks from the press to the nearest blow contact of the running exchange (negative:
## early), or NO_BEAT outside one. All numbers are data (timing.json, the `read` block), whole ticks at 60 a second.

const LIGHT: int = 0
const HEAVY: int = 1
const SIG: int = 2
const NO_BEAT: int = 32767

const DEFAULTS: Dictionary = {
	"logSize": 5,         # presses kept: the alchemist's read
	"holdTicks": 12,      # a button down this long is a hold (the number sprint and the channel use: tapHold.holdStart)
	"beatHalf": 4,        # a press within this many ticks of a blow's contact is on the beat (8-tick window)
	"touchBeatHalf": 5,   # the same on touch (10 ticks)
	"rhythmOf": 3,        # the last N presses ...
	"rhythmNeed": 2,      # ... of which this many on the beat are rhythm
	"mashPresses": 4,     # this many presses ...
	"mashGap": 10,        # ... with every gap this many ticks or fewer are a mash
	"mashClear": 20,      # a mash is over after this many ticks without a press
	"staleTicks": 60,     # a log older than this reads as nothing
	"mixShort": 3,        # the short mix window
	"assistFactor": 2,    # accessibility: the beat window doubles
}


## The numbers, from data over the defaults.
static func params() -> Dictionary:
	var p: Dictionary = DEFAULTS.duplicate()
	for k in DEFAULTS:
		p[k] = SimInputData.ti(["read", k], int(DEFAULTS[k]))
	p["holdTicks"] = SimInputData.ti(["read", "holdTicks"], SimInputData.ti(["tapHold", "holdStart"], int(DEFAULTS["holdTicks"])))
	return p


## A new press at `tick`. Trims the log to `logSize` and returns it. `beat_offset` is NO_BEAT outside an exchange.
static func push(log: Array, kind: int, mode: int, tick: int, beat_offset: int = NO_BEAT, size: int = -1) -> Array:
	var n: int = size if size > 0 else SimInputData.ti(["read", "logSize"], int(DEFAULTS["logSize"]))
	log.append({"kind": kind, "mode": mode, "down": tick, "up": -1, "beat": beat_offset})
	while log.size() > n:
		log.pop_front()
	return log


## The button of `kind` was released at `tick`: closes the latest still-held entry of that kind.
static func release(log: Array, kind: int, tick: int) -> void:
	for k in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[k]
		if int(e["kind"]) == kind and int(e["up"]) < 0:
			e["up"] = tick
			return


## Signed distance from `tick` to the nearest of `blows` (contact ticks), tick minus blow, NO_BEAT if there are none.
static func beat_offset(tick: int, blows: Array) -> int:
	var best: int = NO_BEAT
	for b in blows:
		var d: int = tick - int(b)
		if best == NO_BEAT or absi(d) < absi(best):
			best = d
	return best


## Read a log at tick `now`. `opts`: touch (bool, the wider beat window), assist (bool, the doubled one), offset (int, the
## player's timing offset in ticks, -6 to 6: it shifts where the beat is for them), p (a params dictionary, for tests).
## Returns {style, hold_ticks, on_beat, presses, mix_short, mix_long, rate}:
##   style: "none" (nothing recent), "hold", "rhythm", "mash" or "taps";
##   hold_ticks: how long the held button has been down (0 if none held);
##   on_beat: how many of the last `rhythmOf` presses were on the beat;
##   mix_short / mix_long: {light, heavy, sig, energy} counts over the last `mixShort` and `logSize` presses;
##   rate: presses a second over the log (0 with fewer than two).
## Precedence: hold, then rhythm, then mash, then taps. A mash that lands on the blows is rhythm.
static func classify(log: Array, now: int, opts: Dictionary = {}) -> Dictionary:
	var p: Dictionary = opts.get("p", params())
	var out: Dictionary = {"style": "none", "hold_ticks": 0, "on_beat": 0, "presses": log.size(), "mix_short": _mix(log, int(p["mixShort"])), "mix_long": _mix(log, int(p["logSize"])), "rate": 0.0}
	if log.is_empty():
		return out
	var last: Dictionary = log[log.size() - 1]
	# A held button is a hold from holdTicks on, however old the log is.
	for k in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[k]
		if int(e["up"]) < 0:
			var held: int = now - int(e["down"])
			out["hold_ticks"] = held
			if held >= int(p["holdTicks"]):
				out["style"] = "hold"
				return out
			break
	if now - int(last["down"]) > int(p["staleTicks"]):
		return out
	out["rate"] = _rate(log)
	# Rhythm: the player is watching the blows.
	var half: int = int(p["touchBeatHalf"]) if opts.get("touch", false) else int(p["beatHalf"])
	if opts.get("assist", false):
		half *= int(p["assistFactor"])
	var shift: int = int(opts.get("offset", 0))
	var of: int = mini(int(p["rhythmOf"]), log.size())
	var on: int = 0
	for k in range(log.size() - of, log.size()):
		var b: int = int(log[k]["beat"])
		if b != NO_BEAT and absi(b - shift) <= half:
			on += 1
	out["on_beat"] = on
	if on >= int(p["rhythmNeed"]):
		out["style"] = "rhythm"
		return out
	# Mash: the last mashPresses presses all close together, and still going.
	var need: int = int(p["mashPresses"])
	if log.size() >= need and now - int(last["down"]) <= int(p["mashClear"]):
		var fast: bool = true
		for k in range(log.size() - need + 1, log.size()):
			if int(log[k]["down"]) - int(log[k - 1]["down"]) > int(p["mashGap"]):
				fast = false
				break
		if fast:
			out["style"] = "mash"
			return out
	out["style"] = "taps"
	return out


static func _mix(log: Array, n: int) -> Dictionary:
	var m: Dictionary = {"light": 0, "heavy": 0, "sig": 0, "energy": 0}
	for k in range(maxi(0, log.size() - n), log.size()):
		match int(log[k]["kind"]):
			LIGHT: m["light"] += 1
			HEAVY: m["heavy"] += 1
			SIG: m["sig"] += 1
		if int(log[k]["mode"]) == 1:
			m["energy"] += 1
	return m


static func _rate(log: Array) -> float:
	if log.size() < 2:
		return 0.0
	var span: int = int(log[log.size() - 1]["down"]) - int(log[0]["down"])
	if span <= 0:
		return 0.0
	return float(log.size() - 1) * 60.0 / float(span)
