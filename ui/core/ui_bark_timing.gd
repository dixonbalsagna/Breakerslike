class_name UiBarkTiming
## How a bark's text reveals (docs/narrative/line-system.md section 4): the text speed follows the line's intensity,
## and punctuation gives the pauses. Pure functions of (text, intensity, age): the same line reveals identically on
## every run, and a replay seek that lands mid-line shows the right number of characters.

const BASE_CPS := 30.0
const CPS_PER_INTENSITY := 11.0


static func cps(intensity: int) -> float:
	return BASE_CPS + CPS_PER_INTENSITY * float(clampi(intensity, 0, 3))


static func _pause(ch: String) -> float:
	match ch:
		",", ";", ":":
			return 0.14
		".", "?", "!":
			return 0.26
		"—", "-":
			return 0.18
		"…":
			return 0.30
	return 0.0


## Seconds from the start of the line until character index `idx` (0-based) is on screen.
static func time_for_char(text: String, idx: int, intensity: int) -> float:
	var per: float = 1.0 / cps(intensity)
	var t := 0.0
	var n: int = mini(idx, text.length())
	for i in range(n):
		t += per + _pause(text[i])
	return t


static func reveal_total(text: String, intensity: int) -> float:
	return time_for_char(text, text.length(), intensity)


## How many characters are showing at `age` seconds.
static func reveal_count(text: String, age: float, intensity: int) -> int:
	var per: float = 1.0 / cps(intensity)
	var t := 0.0
	for i in range(text.length()):
		t += per + _pause(text[i])
		if t > age:
			return i
	return text.length()
