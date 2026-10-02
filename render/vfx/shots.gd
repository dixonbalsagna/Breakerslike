class_name VfxShots
extends RefCounted
## Energy blasts on screen (Encounter's slice 5, Simulation's docs/architecture/shots.md): the state behind what shots_view.gd draws.
## The shots themselves are drawn every frame straight from S.shots (position and velocity, interpolated; see the view). This keeps the
## rest: the short effects the shot events call for, and the charge on the hand while a charged shot is held.
##
##   shot_fire   a small muzzle flash (a ring) at the point of leaving
##   shot_hit    by outcome: hit (a flash and a ring), guard (a splash that fans back toward the shooter), deflect (a bigger ring in the
##               DEFLECTOR's colour: the shot itself is seen turning, because S.shots changes its owner and it flies back), shrug and
##               stop (a smaller flash), dodge (nothing at him: the shot flies on, and its end on the ground is the miss)
##   shot_clash  a trade: two rings, one in each fighter's colour, and a burst of eight short lines
##   shot_end    cause ground or water: the miss's puff of dust or a ring on the water (World's crater event, if any, comes by itself);
##               cause life: a small fading ring; hit and clash have their own
##   cue         blast_charge (a charged shot's charge starts, on the hand), blast_full (it is complete), blast_cancel, charge_stopped (gone)
##
## The charge on the hand is each fighter's own look and never a sphere in a palm, hands at a hip or a two-hand push (Legal, the first
## energy slice): the Anti-hero (a villain) has plates stacking along the forearm, one more each fifth of the charge; the others have thin
## rings stacking along the forearm. Both are in the lane colour (VfxAura.lane_color: never white, gold or red), at the forearm of the arm
## toward the rival, and fade when the shot leaves or is cancelled.
## On top of that (Orb, 2026-10-02: the blasts should "erupt into flame and smoke, explosive particles"): a shot's hits and ends are
## explosions (explode.gd: flame, sparks, smoke, thrown chunks, a flat ring and a smouldering scorch, by the shot's power and by where it
## goes off), a shot that has been knocked loose (`deflected` above zero) tumbles and trails smoke, and the mines of concept
## (hovering or on the ground; look only, no sim behind them yet) are kept here for the view to draw.
## Presentation only: it reads events and the fighters and draws no random number of its own (the pool's cosmetic streams do).

const DEFAULTS: Dictionary = {
	"shots": {"charge_ticks": 30.0, "charge_ease": 0.25, "charge_fade": 8.0, "charge_timeout": 90.0, "muzzle_life": 6.0, "hit_life": 9.0, "clash_life": 14.0,
		"end_life": 8.0, "rad_k": 1.1, "rad_power": 0.1, "tail_k": 4.5, "tail_power": 1.0, "arc_bh": 0.1, "arc_min": 0.5, "arc_max": 3.0, "alpha": 0.95},
}
const KIND_R: Dictionary = {"bolt": 14.0, "shard": 10.0, "arc": 20.0, "charged": 30.0, "lob": 24.0}
const KIND_POWER: Dictionary = {"bolt": 1.0, "shard": 1.0, "arc": 2.0, "charged": 3.0, "lob": 3.0}
const MINE_ARM_TICKS: float = 30.0     # a mine arms over this many ticks (agency-pass.md 15.5: dim, then bright)
const MINE_FUSE_TICKS: float = 30.0    # and shows it is about to go for this many
const TRAIL_MAX: int = 6               # knocked-loose shots that trail smoke at once

## A mine, as far as there is one: look only (no sim behind it yet), placed by the tools or, one day, by events (docs/vfx/shots-plan.md).
class Mine:
	var id: int = 0
	var owner: int = 0
	var x: float = 0.0
	var y: float = 0.0            # the centre (a ground mine sits on the ground, a hovering one is up)
	var z: float = 0.0
	var mode: String = "hover"    # hover or ground
	var state: String = "armed"   # arming, armed or trigger (the fuse: about to go)
	var age: float = 0.0          # ticks in the state
	var radius: float = 150.0     # its blast radius (2 bh), for the fuse's warning ring

class Fx:
	var kind: String = "flash"      # flash, ring, splash, burst
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var dx: float = 1.0             # a splash's direction
	var dy: float = 0.0
	var age: float = 0.0            # ticks
	var life: float = 8.0
	var size: float = 60.0          # world units, the radius it reaches
	var col: Color = Color.WHITE
	var col2: Color = Color.WHITE

class Charge:
	var on: bool = false
	var t: float = 0.0              # ticks since the charge began (unfrozen)
	var full: bool = false
	var lvl: float = 0.0            # eased 0..1 (what is drawn)
	var prev: float = 0.0
	var fade: float = 0.0           # ticks of fade left after it ended
	var pulse: float = 0.0          # ticks since blast_full, for the pulse ring
	var look: String = "rings"      # plates (the Anti-hero) or rings

var fx: Array = []                 # Fx, oldest first
var charges: Array = [Charge.new(), Charge.new()]
var last_frozen: bool = false      # the last tick was a hit-stop or a pause: the shots stood still, so they are drawn where they are
var clock: int = 0                 # unfrozen ticks
var fired: int = 0                 # counters for the tests
var hits: int = 0
var clashes: int = 0
var ends: int = 0
var charges_started: int = 0
var by_outcome: Dictionary = {}
var explode_enabled: bool = true      # the explosions and the knocked-loose look (hub.explosions_enabled)
var mines: Array = []                 # Mine
var explosions: int = 0               # explosions asked for (the tests)
var last_radius: float = 0.0          # the radius of the last one (the tests)
var _known: Dictionary = {}           # shot id -> [owner, damage]: shot_end carries no owner, so it is remembered from S.shots
var trails: int = 0                   # smoke puffs left behind knocked-loose shots

static var _data: Dictionary = {}
static var _loaded: bool = false


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/shots.json"
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
	charges = [Charge.new(), Charge.new()]
	last_frozen = false
	clock = 0
	fired = 0
	hits = 0
	clashes = 0
	ends = 0
	charges_started = 0
	by_outcome = {}
	mines = []
	explosions = 0
	last_radius = 0.0
	_known = {}
	trails = 0
	warm()


## The radius of a kind's contact circle (data/fight/shots.json, the sim's), for how big it is drawn.
static func kind_r(kind: String) -> float:
	return float(KIND_R.get(kind, 14.0))


## What the shot looks like: its drawn radius, its tail length and its halo, from the kind, its power and (a charged shot) its charge.
static func look_of(sh) -> Dictionary:
	var r: float = kind_r(String(sh.kind))
	var power: float = float(sh.power)
	var rad: float = r * (p("shots", "rad_k") + p("shots", "rad_power") * power)
	if String(sh.kind) == "charged":
		rad *= 0.75 + 0.25 * clampf(float(sh.dmg) / 66.0, 0.0, 1.0)     # a tap is smaller than a full charge
	return {"rad": rad, "tail": rad * (p("shots", "tail_k") + p("shots", "tail_power") * (power - 1.0)), "halo": power >= 2.0}


static func lane_of(S: SimState, slot: int) -> Color:
	if slot >= 0 and slot < S.fighters.size():
		return VfxAura.lane_color(String(S.fighters[slot].aura))
	return VfxAura.lane_color("#8fd6ff")


func _add(kind: String, x: float, y: float, z: float, size: float, life: float, col: Color, col2: Color = Color.WHITE, dx: float = 1.0, dy: float = 0.0) -> Fx:
	var e := Fx.new()
	e.kind = kind
	e.x = SimWrap.wrap(x)
	e.y = y
	e.z = z
	e.size = size
	e.life = life
	e.col = col
	e.col2 = col2 if col2 != Color.WHITE else col
	e.dx = dx
	e.dy = dy
	fx.append(e)
	while fx.size() > 48:
		fx.pop_front()
	return e


## One tick's events (all ticks, hit-stops too). debris and water: the shared pools, for a miss on the ground or the water.
func on_events(S: SimState, events: Array, debris: VfxDebris, water: VfxWater, quality: int, reduced: bool) -> void:
	for sh0 in S.shots:
		_known[int(sh0.id)] = [int(sh0.owner), float(sh0.dmg)]
	if _known.size() > 160:
		_known.clear()
	for e in events:
		match e.type:
			"shot_fire":
				fired += 1
				var power: float = float(VfxHub._g(e, "amount", 1.0))
				_add("ring", float(e.x), float(e.y), float(VfxHub._g(e, "z", 0.0)), 24.0 + 14.0 * power, p("shots", "muzzle_life"), lane_of(S, int(e.actor)))
			"shot_hit":
				hits += 1
				var oc: String = String(VfxHub._g(e, "outcome", "hit"))
				by_outcome[oc] = int(by_outcome.get(oc, 0)) + 1
				_on_hit(S, e, oc, debris)
			"shot_clash":
				clashes += 1
				var pw: float = float(VfxHub._g(e, "amount", 1.0))
				var z: float = float(VfxHub._g(e, "z", 0.0))
				var sz: float = 60.0 + 25.0 * pw
				_add("burst", float(e.x), float(e.y), z, sz, p("shots", "clash_life"), lane_of(S, 0), lane_of(S, 1))
			"shot_end":
				ends += 1
				_on_end(S, e, debris, water, quality, reduced)
			"cue":
				_on_cue(S, e)
			"mine_place":
				add_mine(int(VfxHub._g(e, "id", 0)), int(VfxHub._g(e, "actor", 0)), float(e.x), float(e.y), float(VfxHub._g(e, "z", 0.0)), String(VfxHub._g(e, "mode", "hover")))
			"mine_armed":
				_mine_state(int(VfxHub._g(e, "id", 0)), "armed")
			"mine_fuse":
				_mine_state(int(VfxHub._g(e, "id", 0)), "trigger")
			"mine_end":
				var mi: Mine = _mine_find(int(VfxHub._g(e, "id", 0)))
				if mi != null:
					mine_blast(S, mi, debris, quality, reduced)
	# A charged shot leaving ends its charge.
	for e in events:
		if e.type == "shot_fire" and String(VfxHub._g(e, "kind", "")) == "charged":
			_end_charge(int(e.actor), true)


func add_mine(id: int, owner: int, x: float, y: float, z: float, mode: String) -> Mine:
	var m := Mine.new()
	m.id = id
	m.owner = owner
	m.x = SimWrap.wrap(x)
	m.y = y
	m.z = z
	m.mode = mode
	m.state = "arming"
	mines.append(m)
	while mines.size() > 24:
		mines.pop_front()
	return m


func _mine_find(id: int) -> Mine:
	for m in mines:
		if m.id == id:
			return m
	return null


func _mine_state(id: int, st: String) -> void:
	var m: Mine = _mine_find(id)
	if m != null:
		m.state = st
		m.age = 0.0


## A mine goes off: a power-2 explosion at its place (on the ground if it sits there, in the air if it hovers), and it is gone.
func mine_blast(S: SimState, m: Mine, debris: VfxDebris, quality: int, reduced: bool) -> void:
	mines.erase(m)
	if debris == null:
		return
	explosions += 1
	var on_ground: bool = m.mode == "ground"
	var rad: float = VfxExplode.radius_for("charged", 66.0, VfxReact.tier_of(S.fighters[m.owner]) if m.owner < S.fighters.size() else 1)
	last_radius = rad
	VfxExplode.at(S, debris, m.x, m.y, m.z, rad, "ground" if on_ground else "fighter")
	_add("ring", m.x, m.y, m.z, m.radius * 0.85, p("shots", "hit_life") * 1.4, lane_of(S, m.owner))


func _on_hit(S: SimState, e, oc: String, debris: VfxDebris) -> void:
	var x: float = float(e.x)
	var y: float = float(e.y)
	var z: float = float(VfxHub._g(e, "z", 0.0))
	var owner: int = int(e.actor)
	var victim: int = int(VfxHub._g(e, "victim", -1))
	var amt: float = float(VfxHub._g(e, "amount", 8.0))
	var life: float = p("shots", "hit_life")
	var col: Color = lane_of(S, owner)
	var back: float = 1.0
	if victim >= 0 and victim < S.fighters.size() and owner >= 0 and owner < S.fighters.size():
		back = 1.0 if SimWrap.sdx(S.fighters[victim].x, S.fighters[owner].x) >= 0.0 else -1.0
	var kn: String = String(VfxHub._g(e, "kind", "bolt"))
	var info = _known.get(int(VfxHub._g(e, "id", -1)))
	var dmg: float = float(info[1]) if info != null else (66.0 if kn == "charged" else float(VfxHub._g(e, "amount", 8.0)))
	if explode_enabled and debris != null and oc != "dodge":
		explosions += 1
		last_radius = VfxExplode.radius_for(kn, dmg, VfxReact.tier_of(S.fighters[owner]) if owner >= 0 and owner < S.fighters.size() else 1)
		VfxExplode.at(S, debris, x, y, z, last_radius, "fighter", "burst" if (oc == "hit" or oc == "stop") else "spark")
	match oc:
		"guard":
			_add("splash", x, y, z, 80.0, life, col, col, back, 0.0)
			_add("ring", x, y, z, 50.0, life * 0.8, col)
		"deflect":
			var dcol: Color = lane_of(S, victim)
			_add("flash", x, y, z, 70.0, life, dcol)
			_add("ring", x, y, z, 130.0, life * 1.2, dcol, col)
		"shrug", "stop":
			_add("flash", x, y, z, 45.0, life * 0.8, col)
			_add("ring", x, y, z, 70.0, life * 0.8, col)
		"dodge":
			pass
		_:
			var sz: float = clampf(40.0 + amt * 1.3, 45.0, 130.0)
			_add("flash", x, y, z, sz, life, col)
			_add("ring", x, y, z, sz * 1.6, life * 1.1, col)


func _on_end(S: SimState, e, debris: VfxDebris, water: VfxWater, quality: int, reduced: bool) -> void:
	var cause: String = String(VfxHub._g(e, "cause", ""))
	var x: float = float(e.x)
	var y: float = float(e.y)
	var z: float = float(VfxHub._g(e, "z", 0.0))
	var kind: String = String(VfxHub._g(e, "kind", "bolt"))
	var info = _known.get(int(VfxHub._g(e, "id", -1)))
	var own: int = int(info[0]) if info != null else int(VfxHub._g(e, "actor", 0))
	var dmg: float = float(info[1]) if info != null else (66.0 if kind == "charged" else 8.0)
	var rad: float = VfxExplode.radius_for(kind, dmg, VfxReact.tier_of(S.fighters[own]) if own >= 0 and own < S.fighters.size() else 1)
	var big: float = 1.0 if kind == "bolt" or kind == "shard" else 1.8
	match cause:
		"ground":
			# A shot that missed and met the ground: with the explosions on it is the explosion (flame, sparks, smoke, chunks, a flat
			# ring, a smouldering scorch; World's crater comes by its own event); without them, dust and a few chunks.
			if explode_enabled and debris != null:
				explosions += 1
				last_radius = rad
				VfxExplode.at(S, debris, x, y, z, rad, "ground")
			elif debris != null:
				var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
				var biome: String = VfxPalette.biome_key(x)
				var tones: Array = VfxEarth.tones_for_surface("soil", x)
				var rd: SimRng = debris._rd
				for i in range(int(round(5.0 * big))):
					var side: float = 1.0 if i % 2 == 0 else -1.0
					var sz: float = rd.range_(30.0, 55.0) * big
					var keep: bool = rd.next() < q
					var vx: float = side * rd.range_(120.0, 380.0)
					var vy: float = rd.range_(60.0, 240.0)
					if keep:
						debris.dust_puff(biome, x, y + rd.range_(0.0, 14.0), z + rd.range_(2.0, 20.0), vx, vy, sz * 0.6, sz * 1.9, rd.range_(0.8, 1.4), i % 3)
				for i in range(int(round(3.0 * big))):
					var vx2: float = rd.range_(-1.0, 1.0) * 300.0
					var vy2: float = rd.range_(300.0, 700.0)
					var sz2: float = rd.range_(7.0, 14.0)
					var keep2: bool = rd.next() < q
					if keep2:
						debris.chunk(x + rd.range_(-20.0, 20.0), y + 6.0, z + 6.0, vx2, vy2, sz2, rd.range_(0.9, 1.5), tones, 2, 8.0)
			_add("ring", x, y + 4.0, z, 60.0 * big, p("shots", "end_life"), lane_of(S, own))
		"water":
			if water != null:
				water.plunge(S, x, y, int(10.0 * big))
			if explode_enabled and debris != null:
				explosions += 1
				last_radius = rad
				VfxExplode.at(S, debris, x, y, z, rad, "water")
		"life":
			_add("ring", x, y, z, 30.0, p("shots", "end_life") * 0.7, lane_of(S, own))
		_:
			pass


func _on_cue(S: SimState, e) -> void:
	var slot: int = int(e.actor)
	if slot < 0 or slot >= 2:
		return
	var name: String = String(e.kind)
	var c: Charge = charges[slot]
	match name:
		"blast_charge":
			if not c.on:
				charges_started += 1
			c.on = true
			c.t = 0.0
			c.full = false
			c.pulse = 99.0
			c.fade = 0.0
			c.look = "plates" if String(S.fighters[slot].role) == "villain" else "rings"
		"blast_full":
			if c.on:
				c.full = true
				c.pulse = 0.0
		"blast_cancel", "charge_stopped":
			_end_charge(slot, false)


func _end_charge(slot: int, released: bool) -> void:
	if slot < 0 or slot >= 2:
		return
	var c: Charge = charges[slot]
	if c.on:
		c.on = false
		c.fade = p("shots", "charge_fade") * (0.5 if released else 1.0)


## Once per unfrozen tick: age the effects and run the charges. Called with every tick for the effects (hit-stops too, so a flash
## plays through one) and with frozen = false for the charge clock.
func step(S: SimState, frozen: bool, debris: VfxDebris = null) -> void:
	last_frozen = frozen
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
	for m in mines:
		m.age += 1.0
		if m.state == "arming" and m.age >= MINE_ARM_TICKS:
			m.state = "armed"
			m.age = 0.0
	# A shot that has been knocked loose (the sim has changed its owner or sent it off) tumbles and trails smoke: a puff behind it
	# each tick (every other at low quality), and the odd ember.
	if explode_enabled and debris != null:
		var live: int = 0
		for sh in S.shots:
			if int(sh.deflected) <= 0 or live >= TRAIL_MAX:
				continue
			live += 1
			var rd: SimRng = debris._rd
			var sz: float = rd.range_(26.0, 40.0) * (0.7 + 0.15 * float(KIND_POWER.get(String(sh.kind), 1.0)))
			var life: float = rd.range_(0.9, 1.5)
			var jitter: float = rd.range_(-10.0, 10.0)
			if (clock + int(sh.id)) % 2 == 0 or debris.quality > VfxLook.Q_LOW:
				if rd.next() < (0.5 if debris.reduced else 1.0):
					debris.smoke(sh.x - sh.vx * SimConst.DT * 0.5, sh.y + jitter, float(sh.z) - 1.0, sz, life)
					trails += 1
	for s in range(2):
		var c: Charge = charges[s]
		c.prev = c.lvl
		if c.on:
			c.t += 1.0
			c.pulse += 1.0
			var target: float = clampf(c.t / p("shots", "charge_ticks"), 0.0, 1.0)
			c.lvl += (target - c.lvl) * p("shots", "charge_ease")
			if c.t > p("shots", "charge_timeout"):
				_end_charge(s, false)
		else:
			if c.fade > 0.0:
				c.fade -= 1.0
				c.lvl = maxf(c.lvl - 1.0 / maxf(p("shots", "charge_fade"), 1.0), 0.0)
			else:
				c.lvl = 0.0
