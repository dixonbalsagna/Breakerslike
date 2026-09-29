class_name EvacMock
extends RefCounted
## A stand-in for World's evacuation (docs/world/collateral-caps.md sections 5 and 7) until the sim emits `evacuate`
## (after Encounter's S2): main's --mock-evac, and the flight tools. It never writes the sim. Each tick, after the
## step, it reads what changed and makes the events World plans to send, in the same tick, in World's shape
## {b, x, z, n, cx, reason, owner}:
## - a share (SHARE) of each building's losses this tick is reported as fled. The sim still counts them dead; only
##   the picture changes;
## - for FLIGHT_S after a blow that cost lives, the standing buildings within EVAC_R of it empty at EVAC_RATE of their
##   remaining people a second. These leave on the render side only: the planet view shows popAlive less `extra`.
## A blow's fled share is reported in the same tick, however small: the figures it spares must run from that tick,
## and a figure hidden as a casualty can't come back as a runner (asked of World through the EP). The district
## flight is reported in lots once a building's fled people reach EVAC_MIN, at most EVAC_MAX_PER_TICK a tick, as
## World plans; the planet view runs those figures as they vanish, before their lot is reported.
## The numbers are World's planned ones (EVAC_R, EVAC_RATE, EVAC_MIN, EVAC_MAX_PER_TICK) or the mock's own (SHARE,
## FLIGHT_S). Delete this file, main's flag and PlanetView.crowd_extra when World's evacuation lands.

const SHARE: float = 0.6
const FLIGHT_S: float = 5.0
const EVAC_R: float = 3000.0 * SimConst.WS / 8.0
const EVAC_RATE: float = 0.30
const EVAC_MIN: float = 0.5
const EVAC_MAX_PER_TICK: int = 12

## World's planned event record.
class EvacEvent:
	var type: String = "evacuate"
	var b: int = -1
	var x: float = 0.0
	var z: float = 0.0
	var n: float = 0.0
	var cx: float = 0.0
	var reason: String = "budget"
	var owner: float = -1.0
	var tick: int = 0

var extra: Array = []                 # per building: people this mock took out on the render side (shared with PlanetView)
var _seen := PackedFloat64Array()     # per building: popAlive after the last tick
var _acc := PackedFloat64Array()      # per building: fled people not yet reported
var _blow_x: float = 0.0
var _blow_owner: float = -1.0
var _flight_until: float = -1.0


func reset(S: SimState) -> void:
	var nb: int = S.buildings.size()
	extra.resize(nb)
	extra.fill(0.0)
	_seen.resize(nb)
	_acc.resize(nb)
	_acc.fill(0.0)
	for bi in range(nb):
		_seen[bi] = S.buildings[bi].popAlive
	_flight_until = -1.0


## The events this tick adds, given the tick's fx events.
func step(S: SimState, events: Array) -> Array:
	var blows: Array = []
	for e in events:
		if e.type == "crater" or e.type == "scorch" or e.type == "ring":
			blows.append(e)
	var out: Array = []
	for bi in range(S.buildings.size()):
		var b = S.buildings[bi]
		var seen: float = _seen[bi]
		var lost: float = seen - b.popAlive
		_seen[bi] = b.popAlive
		if lost <= 0.0:
			continue
		# The sim's popAlive still holds the people this mock sent off; its losses fall on them and on the crowd
		# shown alike, and only the crowd's part is new in the picture.
		var off: float = lost * clampf(float(extra[bi]) / seen, 0.0, 1.0) if seen > 0.0 else 0.0
		extra[bi] = float(extra[bi]) - off
		lost -= off
		var blow = _nearest(blows, b.x)
		var cx: float = blow.x if blow != null else b.x
		_blow_x = cx
		_blow_owner = blow.owner if blow != null and "owner" in blow else -1.0
		_flight_until = S.T + FLIGHT_S
		out.append(_ev(S, bi, b, lost * SHARE, cx))
	var lots: int = 0
	if S.T < _flight_until:
		for bi in range(S.buildings.size()):
			var b = S.buildings[bi]
			var left: float = b.popAlive - float(extra[bi])
			if not b.alive or left <= 0.0 or absf(SimWrap.sdx(_blow_x, b.x)) > EVAC_R:
				continue
			var take: float = left * EVAC_RATE * S.dt
			extra[bi] = float(extra[bi]) + take
			_acc[bi] += take
			if _acc[bi] >= EVAC_MIN and lots < EVAC_MAX_PER_TICK:
				out.append(_ev(S, bi, b, _acc[bi], _blow_x))
				_acc[bi] = 0.0
				lots += 1
	return out


func _ev(S: SimState, bi: int, b, n: float, cx: float) -> EvacEvent:
	var e := EvacEvent.new()
	e.b = bi
	e.x = b.x
	e.n = n
	e.cx = cx
	e.owner = _blow_owner
	e.tick = S.tick
	return e


static func _nearest(blows: Array, x: float):
	var best = null
	var bd: float = INF
	for e in blows:
		var d: float = absf(SimWrap.sdx(x, e.x))
		if d < bd:
			bd = d
			best = e
	return best
