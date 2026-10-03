class_name SimPressRead
extends RefCounted
## The press reader for the "fight alchemist" (docs/controls/agency-input.md, 1a): from a short log of a fighter's attack
## presses it says whether the player is holding, tapping in time with the blows, mashing, or tapping deliberately, and
## what the running mix of attack types is. Pure functions over plain data: no state, no engine, no clock, no RNG, so the
## sim, the AI, QA and the tests all read a log the same way and a replay reproduces it. The log itself is the sim's state
## (Encounter and Simulation own it); this file only builds and reads it.
##
## A log is an Array of entries, oldest first, at most `logSize` long (20: the running mix; the recipe reads the latest `mixShort`, 5):
##   {kind: int (LIGHT, HEAVY, SIG), mode: int (0 physical, 1 energy), down: int tick, up: int tick or -1 while held,
##    beat: int}
## `beat` is the signed distance in ticks from the press to the nearest blow contact of the running exchange (negative:
## early), or NO_BEAT outside one. A charged press (a hold at range or close) also carries `flash`: the tick the sim's
## charge flashed, or NO_FLASH; releasing on the flash is the timed release. The director stamps the PLANNED flash tick when
## the charge begins (a tick that may still be ahead), so a release before it reads as "early" rather than as no grade. All numbers are data (timing.json, the `read`
## block), whole ticks at 60 a second.
##
## Timing grades (docs/controls/agency-input.md 1a): a press or a release is "perfect" within beatHalf ticks of its mark, "good"
## within 2 * beatHalf, otherwise "off". A style's top level comes from perfect timing: a steady mash, three perfect presses in
## a row, or a hold released on the flash. The sim reads the grade; the damage, the blur and the guard break are Game Design's.

const LIGHT: int = 0
const HEAVY: int = 1
const SIG: int = 2
const NO_BEAT: int = 32767
const NO_FLASH: int = 32767

const DEFAULTS: Dictionary = {
	"logSize": 20,        # presses kept: the running mix reads 20, the recipe the latest 5 (agency-pass.md section 2)
	"holdTicks": 12,      # a button down this long is a hold (the number sprint and the channel use: tapHold.holdStart)
	"beatHalf": 4,        # a press within this many ticks of a blow's contact is on the beat (8-tick window)
	"touchBeatHalf": 5,   # the same on touch (10 ticks)
	"rhythmOf": 3,        # the last N presses ...
	"rhythmNeed": 2,      # ... of which this many on the beat are rhythm
	"mashPresses": 4,     # this many presses ...
	"mashGap": 10,        # ... with every gap this many ticks or fewer are a mash
	"mashClear": 20,      # a mash is over after this many ticks without a press
	"staleTicks": 60,     # a log older than this reads as nothing
	"mixShort": 5,        # the short mix window: the latest presses the recipe reads
	"expireTicks": 90,    # a press older than this no longer counts in either mix
	"assistFactor": 2,    # accessibility: the beat window doubles
	"steadyJitter": 3,    # a mash is steady when its gaps differ by this many ticks or fewer
	"perfectStreak": 3,   # this many perfect presses in a row make a timed string
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
	log.append({"kind": kind, "mode": mode, "down": tick, "up": -1, "beat": beat_offset, "flash": NO_FLASH})
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


## The charge of the latest still-held entry of `kind` flashes at `tick`: the sim's planned tick, stamped when the charge begins.
static func set_flash(log: Array, kind: int, tick: int) -> void:
	for k in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[k]
		if int(e["kind"]) == kind and int(e["up"]) < 0:
			e["flash"] = tick
			return


## The grade of a distance from a mark: "perfect" within the window's half, "good" within twice that, else "off". `opts` as
## classify's (touch, assist, offset, p).
static func grade_of(distance: int, opts: Dictionary = {}) -> String:
	var p: Dictionary = opts.get("p", params())
	var half: int = _half(p, opts)
	var d: int = absi(distance - int(opts.get("offset", 0)))
	if d <= half:
		return "perfect"
	if d <= half * 2:
		return "good"
	return "off"


## How a charged press was let go: "perfect" released on the flash, "good" near it, "early" before the good window, "late"
## after it, "held" if the button is still down, "none" if the entry has no flash. The beat window and its touch, assist
## and offset rules apply; the release is measured from the flash, so a player's offset shifts it like any press.
static func release_grade(entry: Dictionary, opts: Dictionary = {}) -> String:
	if int(entry.get("flash", NO_FLASH)) == NO_FLASH:
		return "none"
	if int(entry["up"]) < 0:
		return "held"
	var d: int = int(entry["up"]) - int(entry["flash"])
	var g: String = grade_of(d, opts)
	if g != "off":
		return g
	return "early" if d - int(opts.get("offset", 0)) < 0 else "late"


static func _half(p: Dictionary, opts: Dictionary) -> int:
	var half: int = int(p["touchBeatHalf"]) if opts.get("touch", false) else int(p["beatHalf"])
	if opts.get("assist", false):
		half *= int(p["assistFactor"])
	return half


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
##   timing: "perfect" (a timed string: a steady mash, a run of perfect presses, or the last release on the flash), "good" (some
##     timing: a perfect press or a good release) or "none";
##   streak: perfect presses in a row ending at the latest; steady: whether the mash's gaps are within steadyJitter;
##   release: the grade of the latest released charge ("none" if there is none);
##   hold_ticks: how long the held button has been down (0 if none held);
##   on_beat: how many of the last `rhythmOf` presses were on the beat;
##   mix_short / mix_long: {light, heavy, sig, energy} counts over the last `mixShort` and `logSize` presses, leaving out any
##     press older than `expireTicks` (90);
##   rate: presses a second over the log (0 with fewer than two).
## Precedence: hold, then rhythm, then mash, then taps. A mash that lands on the blows is rhythm.
static func classify(log: Array, now: int, opts: Dictionary = {}) -> Dictionary:
	var p: Dictionary = opts.get("p", params())
	var out: Dictionary = {"style": "none", "timing": "none", "streak": 0, "steady": false, "release": "none", "hold_ticks": 0, "on_beat": 0, "presses": log.size(), "mix_short": _mix(log, int(p["mixShort"]), now, int(p["expireTicks"])), "mix_long": _mix(log, int(p["logSize"]), now, int(p["expireTicks"])), "rate": 0.0}
	if log.is_empty():
		return out
	var last: Dictionary = log[log.size() - 1]
	# The latest released charge's grade, whatever its age (the sim reads it at the release).
	for k in range(log.size() - 1, -1, -1):
		var g: String = release_grade(log[k], opts)
		if g != "none" and g != "held":
			out["release"] = g
			break
	# A held button is a hold from holdTicks on, however old the log is.
	for k in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[k]
		if int(e["up"]) < 0:
			var held: int = now - int(e["down"])
			out["hold_ticks"] = held
			if held >= int(p["holdTicks"]):
				out["style"] = "hold"
				out["timing"] = "perfect" if out["release"] == "perfect" else ("good" if out["release"] == "good" else "none")
				return out
			break
	if now - int(last["down"]) > int(p["staleTicks"]):
		return out
	out["rate"] = _rate(log)
	# Rhythm: the player is watching the blows.
	var half: int = _half(p, opts)
	var shift: int = int(opts.get("offset", 0))
	var of: int = mini(int(p["rhythmOf"]), log.size())
	var on: int = 0
	for k in range(log.size() - of, log.size()):
		var b: int = int(log[k]["beat"])
		if b != NO_BEAT and absi(b - shift) <= half:
			on += 1
	out["on_beat"] = on
	# Perfect presses in a row, from the latest back.
	var streak: int = 0
	for k in range(log.size() - 1, -1, -1):
		var b2: int = int(log[k]["beat"])
		if b2 != NO_BEAT and absi(b2 - shift) <= half:
			streak += 1
		else:
			break
	out["streak"] = streak
	var any_perfect: bool = false
	for k in range(maxi(0, log.size() - of), log.size()):
		var b3: int = int(log[k]["beat"])
		if b3 != NO_BEAT and absi(b3 - shift) <= half:
			any_perfect = true
	if on >= int(p["rhythmNeed"]):
		out["style"] = "rhythm"
		out["timing"] = "perfect" if streak >= int(p["perfectStreak"]) else "good"
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
			var lo: int = 1 << 30
			var hi: int = 0
			for k in range(log.size() - need + 1, log.size()):
				var gap: int = int(log[k]["down"]) - int(log[k - 1]["down"])
				lo = mini(lo, gap)
				hi = maxi(hi, gap)
			out["steady"] = hi - lo <= int(p["steadyJitter"])
			out["timing"] = "perfect" if out["steady"] else ("good" if any_perfect else "none")
			return out
	out["style"] = "taps"
	out["timing"] = "good" if any_perfect else "none"
	return out


static func _mix(log: Array, n: int, now: int, expire: int) -> Dictionary:
	var m: Dictionary = {"light": 0, "heavy": 0, "sig": 0, "energy": 0}
	for k in range(maxi(0, log.size() - n), log.size()):
		if now - int(log[k]["down"]) > expire:
			continue
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
