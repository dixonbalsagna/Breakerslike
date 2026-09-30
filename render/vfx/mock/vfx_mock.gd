class_name VfxMock
extends RefCounted
## Stand-ins for the events World's B2 will send (docs/world/buildings-in-depth.md sections 4b and 5), so the burst-through
## and collapse effects can be built and judged now. The events carry B2's field names and units; when B2 lands the hub
## reads the real ones and this file and its flag go. It writes nothing to the sim: a scenario only builds event objects.
## The tools that play a scenario (render/vfx/tools/mock_shots.gd) also set the buildings' state on their own fixture, the
## way shots.gd stages craters, so the planet view draws them fallen.

## An event with any fields: reading a field it does not have gives null, like the hub's _g() expects.
class Ev:
	extends RefCounted
	var d: Dictionary = {}

	func _get(prop):
		return d.get(prop)

	func _set(prop, value) -> bool:
		d[prop] = value
		return true


static func ev(type: String, fields: Dictionary) -> Ev:
	var e := Ev.new()
	e.d = fields.duplicate()
	e.d["type"] = type
	return e


## Standing towers in the front row, in order along x, for a scenario to pick from around x.
static func towers_near(S: SimState, x: float, span: float) -> Array:
	var out: Array = []
	for i in range(S.buildings.size()):
		var b = S.buildings[i]
		if b.alive and b.kind == "tower" and absf(SimWrap.sdx(x, b.x)) <= span:
			out.append(i)
	out.sort_custom(func(a, c): return SimWrap.sdx(x, S.buildings[a].x) < SimWrap.sdx(x, S.buildings[c].x))
	return out


## B2's building_hit for a launched fighter arriving at building bi travelling along (dx, dy) at speed sp.
static func building_hit(S: SimState, bi: int, dx: float, dy: float, sp: float, link: int, n: int, outcome: String, victim: int) -> Ev:
	var b = S.buildings[bi]
	var g: float = WorldTerrain.groundY(S, b.x)
	var sgn: float = 1.0 if dx >= 0.0 else -1.0
	return ev("building_hit", {
		"b": bi, "x": b.x - sgn * b.w * 0.5, "y": g + b.h * 0.42, "z": b.z, "damage": sp * 1.8, "ratio": 1.4 if outcome == "collapse" else 0.7,
		"outcome": outcome, "owner": 1 - victim, "victim": victim, "link": link, "n": n, "spd": sp, "keep": 0.6, "ux": dx, "uy": dy, "kind": b.kind, "w": b.w, "h": b.h,
	})


## B2's chain_link: the segment from building `from` to building `to`.
static func chain_link(S: SimState, from: int, to: int, sp: float, link: int) -> Ev:
	var a = S.buildings[from]
	var b = S.buildings[to]
	var ga: float = WorldTerrain.groundY(S, a.x)
	var gb: float = WorldTerrain.groundY(S, b.x)
	var sgn: float = signf(SimWrap.sdx(a.x, b.x))
	return ev("chain_link", {
		"from": from, "to": to, "x": a.x + sgn * a.w * 0.5, "y": ga + a.h * 0.42, "z": a.z, "x1": b.x - sgn * b.w * 0.5, "y1": gb + b.h * 0.42, "z1": b.z, "owner": 1, "victim": 0,
		"dur": absf(SimWrap.sdx(a.x, b.x)) / maxf(sp, 1.0), "link": link,
	})


## The sim's building_fall (it exists in World's B1): implode with a ripple delay, or a burst.
static func building_fall(S: SimState, bi: int, mode: String, delay: float, cx: float) -> Ev:
	var b = S.buildings[bi]
	return ev("building_fall", {
		"b": bi, "x": b.x, "y": b.z, "w": b.w, "depth": b.h, "mode": mode, "delay": delay, "cx": cx, "rubble": clampf(b.h * 0.1, 40.0, 4000.0), "n": 1,
	})


## The folded summary of an implode past the event cap: b -1 and n the count.
static func district_fall(x: float, n: int) -> Ev:
	return ev("building_fall", {"b": -1, "x": x, "y": 0.0, "w": 0.0, "depth": 0.0, "mode": "implode", "delay": 0.0, "cx": x, "rubble": 0.0, "n": n})
