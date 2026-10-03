class_name VfxBeamPlay
extends RefCounted
## The beam plays on screen (Encounter's slice 8, docs/director/agency-slice-8.md): a signature leaves at the fire beat and reaches the defender
## 20 ticks later, and what he does decides what the meeting looks like. The beam itself, and the extra beams a swat or a split adds, are in
## S.beams and are drawn by Rendering's BeamView; this adds what makes each play read, driven by the cues:
##
##   crossing    (while a beam's front is still travelling) a hard-edged wedge at the beam's head pointing along it, a thin narrow ring across it
##               (the air it pushes), and a thin ring left behind every few ticks that fades: the beam is seen to cross, not to appear
##   beam_fire   (the attacker) a launch: a wedge and a ring at the muzzle
##   beam_swat   (the defender) a slash: a wedge sweeping from the incoming line round to the swatted beam's own line, with echoes behind it
##   beam_split  (the defender) the parting: two wedges sliding apart along the forks' lines and a ring across him
##   beam_walk   (the defender) while he walks: a clean bow wave in front of him (a tall thin ring) with the beam parting round him in two long wedges
##   beam_wade   (the defender) while he wades: the same shape, rougher: a half ring of a guard in front of him, jittering short wedges, spray of
##               sparks back along the beam and dust off his feet
##   beam_arrive (the defender) the end of the walk or wade: a flat ring on the ground and a puff of dust where he lands against the attacker
##   beam_late   (the defender) the beam is cut where it had got to: a burst of lines there, and his answer is seen to run out to meet it
##
## Every effect is hard-edged (a flat wedge or a thin ring: Legal's blade language and RL-041/050's looks of a perfect block), in the lane colour
## of the fighter whose it is, never white, gold or red; none is a flame or a body aura. Presentation only: it reads S.beams, the fighters and the
## cues, and draws no random number of its own.

const DEFAULTS: Dictionary = {
	"beamplay": {"head_len": 90.0, "head_w": 38.0, "head_ring": 70.0, "trail_every": 3.0, "trail_max": 7.0, "trail_life": 16.0, "launch_life": 10.0, "sweep_life": 9.0, "part_life": 12.0,
		"arrive_life": 14.0, "cut_life": 12.0, "answer_life": 8.0, "walk_timeout": 70.0, "wave_h": 170.0, "wave_w": 52.0, "alpha": 0.9},
}

class Fx:
	var kind: String = ""
	var x: float = 0.0              # wrapped world x, y of its centre
	var y: float = 0.0
	var z: float = 0.0
	var dx: float = 1.0             # its direction (unit)
	var dy: float = 0.0
	var a0: float = 0.0             # a sweep's angles (radians): from the incoming line to the swatted one
	var a1: float = 0.0
	var x1: float = 0.0             # an answer's target
	var y1: float = 0.0
	var age: float = 0.0            # ticks
	var life: float = 10.0
	var size: float = 100.0
	var col: Color = Color.WHITE
	var col2: Color = Color.WHITE
	var slot: int = 0

class Walk:
	var on: bool = false
	var look: String = "walk"       # walk or wade
	var t: float = 0.0              # ticks
	var fade: float = 0.0           # ticks of fade left after it ended

var fx: Array = []                  # Fx, oldest first
var walks: Array = [Walk.new(), Walk.new()]
var heads: Array = [null, null]     # per attacker slot: [x, y, ux, uy, p] of his main beam's head (also after the beam has gone, for a cut)
var made: Dictionary = {}           # counters by kind, for the tests
var clock: int = 0
var _trail_clock := [0, 0]

static var _data: Dictionary = {}
static var _loaded: bool = false


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/beamplay.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


static func p(group: String, key: String) -> float:
	warm()
	var g = _data.get(group)
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS[group][key])


func reset() -> void:
	fx.clear()
	walks = [Walk.new(), Walk.new()]
	heads = [null, null]
	made = {}
	clock = 0
	_trail_clock = [0, 0]
	warm()


static func lane_of(S: SimState, slot: int) -> Color:
	if slot >= 0 and slot < S.fighters.size():
		return VfxAura.lane_color(String(S.fighters[slot].aura))
	return VfxAura.lane_color("#8fd6ff")


## A beam's head in the world: where its front has got to (the same layout BeamView uses: from the origin along its direction).
static func head_of(b) -> Vector2:
	var s: float = float(b.p) * float(b.len)
	return Vector2(float(b.ox) + float(b.ux) * s, float(b.oy) + float(b.uy) * s)


## Is this beam still crossing? Its front has not reached its full length (the 20-tick travel, then the last of its own run).
static func crossing(b) -> bool:
	return float(b.p) < 0.999 and float(b.t) < 1.0


func _add(kind: String, x: float, y: float, z: float, dx: float, dy: float, size: float, life: float, col: Color, col2: Color = Color.WHITE, slot: int = 0) -> Fx:
	var e := Fx.new()
	e.kind = kind
	e.x = SimWrap.wrap(x)
	e.y = y
	e.z = z
	var l: float = sqrt(dx * dx + dy * dy)
	e.dx = dx / l if l > 1e-4 else 1.0
	e.dy = dy / l if l > 1e-4 else 0.0
	e.size = size
	e.life = life
	e.col = col
	e.col2 = col2 if col2 != Color.WHITE else col
	e.slot = slot
	fx.append(e)
	made[kind] = int(made.get(kind, 0)) + 1
	while fx.size() > 40:
		fx.pop_front()
	return e


## Once per consume(): age the effects, remember each attacker's main beam head, and leave the thin rings behind a crossing head.
func step(S: SimState, frozen: bool, debris: VfxDebris = null) -> void:
	var i: int = 0
	while i < fx.size():
		var e: Fx = fx[i]
		e.age += 1.0
		if e.age >= e.life:
			fx.remove_at(i)
		else:
			i += 1
	if frozen:
		return
	clock += 1
	var seen := [false, false]
	for b in S.beams:
		var slot: int = S.fighters.find(b.A)
		if slot < 0 or slot > 1 or seen[slot]:
			continue
		seen[slot] = true          # the attacker's main beam is his first
		var hd: Vector2 = head_of(b)
		heads[slot] = [hd.x, hd.y, float(b.ux), float(b.uy), float(b.p)]
		if crossing(b) and clock - int(_trail_clock[slot]) >= int(p("beamplay", "trail_every")):
			_trail_clock[slot] = clock
			var live: int = 0
			for e in fx:
				if e.kind == "wake" and e.slot == slot:
					live += 1
			if live < int(p("beamplay", "trail_max")):
				_add("wake", hd.x, hd.y, float(b.oz), float(b.ux), float(b.uy), p("beamplay", "head_ring") * 0.8, p("beamplay", "trail_life"), lane_of(S, slot), Color.WHITE, slot)
	for s in range(2):
		var w: Walk = walks[s]
		if w.on:
			w.t += 1.0
			if w.look == "wade" and debris != null and int(w.t) % 3 == 0:
				var f = S.fighters[s]
				var gy: float = WorldTerrain.groundY(S, f.x)
				if f.y - gy < 1.2 * VfxLook.BH:
					# Dust off his feet as he wades (the pool's own cosmetic stream).
					var rd: SimRng = debris._rd
					var back: float = -1.0 if SimWrap.sdx(f.x, S.fighters[1 - s].x) >= 0.0 else 1.0
					debris.dust_puff(VfxPalette.biome_key(f.x), f.x, gy + 8.0, f.z, back * rd.range_(120.0, 300.0), rd.range_(20.0, 80.0), 24.0, 56.0, rd.range_(0.6, 1.0), 1)
			if w.t > p("beamplay", "walk_timeout"):
				w.on = false
				w.fade = 6.0
		elif w.fade > 0.0:
			w.fade -= 1.0


## One tick's events: the cues of the plays.
func on_events(S: SimState, events: Array, debris: VfxDebris) -> void:
	for e in events:
		if e.type != "cue":
			continue
		var name: String = String(e.kind)
		if not name.begins_with("beam_"):
			continue
		var slot: int = int(e.actor)
		if slot < 0 or slot > 1:
			continue
		var f = S.fighters[slot]
		var o: int = 1 - slot
		var lane: Color = lane_of(S, slot)
		var other: Color = lane_of(S, o)
		var chest: float = f.y + VfxLook.CHEST_Y
		match name:
			"beam_fire":
				# The attacker's muzzle: toward the defender.
				var dxs: float = SimWrap.sdx(f.x, S.fighters[o].x)
				var dys: float = (S.fighters[o].y + VfxLook.CHEST_Y) - chest
				var l: float = maxf(sqrt(dxs * dxs + dys * dys), 1.0)
				_add("launch", f.x, chest, f.z, dxs / l, dys / l, 150.0, p("beamplay", "launch_life"), lane, Color.WHITE, slot)
			"beam_swat":
				# From the incoming line (the attacker's beam toward him) round to the swatted beam's own line (the new beam of his).
				var inb = _main_of(S, S.fighters[o])
				var outb = _newest_of(S, f)
				var a_in: float = atan2(float(inb.uy) if inb != null else 0.0, float(inb.ux) if inb != null else -1.0)
				var a_out: float = atan2(float(outb.uy) if outb != null else 0.5, float(outb.ux) if outb != null else 1.0)
				# Take the shorter way round.
				var d: float = fposmod(a_out - a_in + PI, TAU) - PI
				var sw := _add("sweep", f.x, chest, f.z, cos(a_in), sin(a_in), 190.0, p("beamplay", "sweep_life"), lane, other, slot)
				sw.a0 = a_in
				sw.a1 = a_in + d
				# He is no longer walking or waded through anything.
				walks[slot].on = false
			"beam_split":
				var inb2 = _main_of(S, S.fighters[o])
				var ux: float = float(inb2.ux) if inb2 != null else 1.0
				var uy: float = float(inb2.uy) if inb2 != null else 0.0
				_add("part", f.x, chest, f.z, ux, uy, 170.0, p("beamplay", "part_life"), other, lane, slot)
			"beam_walk", "beam_wade":
				var w: Walk = walks[slot]
				w.on = true
				w.look = "wade" if name == "beam_wade" else "walk"
				w.t = 0.0
				w.fade = 0.0
				made[name] = int(made.get(name, 0)) + 1
			"beam_arrive":
				var w2: Walk = walks[slot]
				var was: String = w2.look
				w2.on = false
				w2.fade = 6.0
				var gy: float = WorldTerrain.groundY(S, f.x)
				_add("land", f.x, gy + 12.0, f.z, 1.0, 0.0, 130.0 if was == "wade" else 100.0, p("beamplay", "arrive_life"), lane, other, slot)
				if debris != null:
					var rd: SimRng = debris._rd
					for k in range(7 if was == "wade" else 4):
						var side: float = 1.0 if k % 2 == 0 else -1.0
						debris.dust_puff(VfxPalette.biome_key(f.x), f.x + side * rd.range_(10.0, 60.0), gy + 8.0, f.z + rd.range_(0.0, 16.0), side * rd.range_(100.0, 320.0), rd.range_(10.0, 60.0), 30.0, 66.0, rd.range_(0.7, 1.2), k % 3)
			"beam_late":
				# The beam is cut where it had got to, and his answer is seen to run out to it.
				var h = heads[o]
				var hx: float = float(h[0]) if h != null else f.x
				var hy: float = float(h[1]) if h != null else chest
				var hux: float = float(h[2]) if h != null else 1.0
				var huy: float = float(h[3]) if h != null else 0.0
				_add("cut", hx, hy, f.z, -hux, -huy, 160.0, p("beamplay", "cut_life"), other, lane, o)
				var an := _add("answer", f.x, chest, f.z, 1.0, 0.0, 150.0, p("beamplay", "answer_life"), lane, other, slot)
				an.x1 = SimWrap.wrap(hx)
				an.y1 = hy


## The attacker's main beam (his first in the state), or null.
func _main_of(S: SimState, A):
	for b in S.beams:
		if b.A == A:
			return b
	return null


## The swatter's newest beam: the one that came off him.
func _newest_of(S: SimState, A):
	var out = null
	for b in S.beams:
		if b.A == A:
			out = b
	return out
