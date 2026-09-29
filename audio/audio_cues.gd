class_name AudioCues
extends RefCounted
## Turns the sim's fx events into sound cues: which sound, which variant, how loud, how high, where. A cue is a request,
## not playback, so this runs headless and is tested without a sound card. The host feeds it the events it just drained
## from S.out.fx (before clearing them), and hands the cues it returns to AudioVoices.
##
## Rules, from docs/architecture/overview.md section 3 and docs/audio/direction.md:
##   * It reads the sim and never writes it.
##   * Its only randomness is its own stream, seeded from the match seed under the reserved id "audio", so a replay
##     picks the same variants and the sim's RNG is never touched.
##   * Sound follows the sim and never changes its timing; a cue is made in the tick the event happens.
##   * Every threshold and scale is in data/cues.json.

const CUES_PATH := "res://audio/data/cues.json"


class Cue:
	var sound: String = ""       # a bank id: "impact.light", "voice.protagonist.effort.heavy"
	var kind: String = "sfx"     # "sfx" or "voice"
	var variant: int = 0
	var x: float = 0.0           # world x, wrapped; the player turns it into a shortest-arc offset from the camera
	var y: float = 0.0           # world y, up, sea level 0
	var gain_db: float = 0.0
	var pitch: float = 1.0
	var priority: int = 0
	var bus: String = "Sfx"
	var group: String = ""       # a voice group replaces its own earlier voice ("voice.0" is fighter 0's mouth)
	var muffled: bool = false    # underwater: the player routes it through the low-pass bus
	var caption: String = ""     # for muted or deaf players; UI's captions read it


var cfg: Dictionary = {}
var bank: AudioBank
var _rng: SimRng
var _last_variant: Dictionary = {}    # sound id -> the variant played last
var _last_grunt: Dictionary = {}      # "fighter.gesture" -> sim time it last fired


func _init(p_bank: AudioBank = null) -> void:
	cfg = AudioBank.load_json(CUES_PATH)
	bank = p_bank if p_bank != null else AudioBank.new()
	reset(1)


## A new match: reseed the audio stream from the match seed and forget the history.
func reset(p_seed: int) -> void:
	_rng = SimRng.new(SimRng.deriveSeed(p_seed, "audio"))
	_last_variant.clear()
	_last_grunt.clear()


## One tick's events, in order. Returns the cues to play.
func consume(S: SimState, events: Array) -> Array:
	var out: Array = []
	for e in events:
		match e.type:
			"damage":
				_damage(S, e, out)
			"crater":
				_crater(S, e, out)
			"flash":
				# a cosmetic event from the flash prototype: {actor, id}; ignored until the event carries both
				if e.get("actor") != null and e.get("id") != null:
					var c: Cue = flash(S, int(e.get("actor")), String(e.get("id")))
					if c != null:
						out.append(c)
	return out


## The cue for a head flash starting on a fighter (docs/art/flash-prototype-spec.md), in that fighter's sound family.
## Null if the fighter, the flash or the family is unknown. Rendering may call this directly when its flash starts.
func flash(S: SimState, actor: int, flash_id: String) -> Cue:
	if actor < 0 or actor >= S.fighters.size():
		return null
	var f = S.fighters[actor]
	var fam: String = bank.family_of_voice(String(cfg.fighters.get(f.name, "")))
	var id: String = "flash.%s.%s" % [flash_id, fam]
	var meta: Dictionary = cfg.flash
	if fam == "" or not bank.has_sound(id) or not meta.rank.has(flash_id):
		return null
	var cue := Cue.new()
	cue.sound = id
	cue.variant = 0
	cue.x = f.x
	cue.y = f.y + 30.0
	cue.gain_db = float(meta.gain_db)
	_vary(cue)
	cue.priority = int(meta.priority_base) - int(meta.priority_step) * int(meta.rank[flash_id])
	cue.bus = String(meta.bus)
	cue.group = "flash.%d" % actor
	cue.caption = ""
	return cue


func _damage(S: SimState, e, out: Array) -> void:
	var d: Dictionary = cfg.damage
	var id: String = ""
	for c in d.classes:
		if e.amount < float(c.below):
			id = c.sound
			break
	if id == "":
		return
	out.append(make_sfx(S, id, e.x, e.y, e.amount, d))
	for rule in cfg.get("grunts", []):
		if rule.on == "damage" and e.amount >= float(rule.get("min_amount", 0.0)):
			_grunt(S, rule, e, out)


func _crater(S: SimState, e, out: Array) -> void:
	var c: Dictionary = cfg.crater
	if e.energy < float(c.min_energy):
		return
	out.append(make_sfx(S, c.sound, e.x, e.y, e.energy, c))


## A bank sound scaled by size: bigger means lower and louder (so a huge crater is a deep, long crash). S may be null
## (tools and the demo) when the sound is above sea level.
func make_sfx(S: SimState, id: String, x: float, y: float, size: float, scale: Dictionary) -> Cue:
	var s: float = maxf(size, 0.001) / float(scale.ref)
	var cue := Cue.new()
	var meta: Dictionary = cfg.sounds[id]
	cue.sound = id
	cue.variant = _pick_variant(id)
	cue.x = x
	cue.y = y
	cue.pitch = clampf(pow(s, float(scale.pitch_exp)), float(scale.pitch_min), float(scale.pitch_max))
	cue.gain_db = clampf(20.0 * float(scale.gain_exp) * log(s) / log(10.0), float(scale.gain_db_min), float(scale.gain_db_max))
	_vary(cue)
	cue.priority = int(meta.priority)
	cue.bus = String(meta.bus)
	cue.caption = String(meta.get("caption", ""))
	cue.muffled = _muffled(S, x, y)
	return cue


## A fighter's grunt for a rule, if the fighter has that gesture, is off cooldown and the dice allow it.
func _grunt(S: SimState, rule: Dictionary, e, out: Array) -> void:
	var idx: int = _victim(S, e.x, e.y)
	if idx < 0:
		return
	if rule.who == "attacker":
		idx = 1 - idx if S.fighters.size() == 2 else -1
	if idx < 0:
		return
	var f = S.fighters[idx]
	var voice: String = String(cfg.fighters.get(f.name, ""))
	# One shared cooldown per fighter and rule, so the pool does not stack grunts.
	var key: String = "%d.%s" % [idx, String(rule.get("gesture", "pool"))]
	if voice == "" or S.T - float(_last_grunt.get(key, -99.0)) < float(rule.cooldown_s):
		return
	if _rng.next() >= float(rule.chance):
		return
	var gesture: String = String(rule.gesture) if rule.has("gesture") else _from_pool(rule.pool)
	var id: String = "voice.%s.%s" % [voice, gesture]
	if not bank.has_sound(id):
		return
	_last_grunt[key] = S.T
	var cue := Cue.new()
	cue.sound = id
	cue.kind = "voice"
	cue.variant = _pick_variant(id)
	cue.x = f.x
	cue.y = f.y
	cue.gain_db = float(rule.gain_db)
	if rule.has("pitch_per_ln"):
		# the bigger the hit, the higher the cry
		cue.pitch = clampf(1.0 + float(rule.pitch_per_ln) * log(maxf(e.amount, 1.0) / float(rule.ref)), 0.85, 1.25)
	_vary(cue)
	cue.priority = int(rule.priority)
	cue.bus = "Voice"
	cue.group = "voice.%d" % idx
	cue.caption = String(_grunt_caption(voice, gesture))
	cue.muffled = _muffled(S, f.x, f.y)
	out.append(cue)


## The fighter nearest to a point along the shortest arc: in a 1v1 the one who was hit.
func _victim(S: SimState, x: float, y: float) -> int:
	var best: int = -1
	var bd: float = INF
	for i in range(S.fighters.size()):
		var f = S.fighters[i]
		var d: float = absf(SimWrap.sdx(f.x, x)) + 0.25 * absf(f.y - y)
		if d < bd:
			bd = d
			best = i
	return best


## A weighted draw from {gesture: weight} with the audio stream.
func _from_pool(pool: Dictionary) -> String:
	var total: float = 0.0
	for k in pool:
		total += float(pool[k])
	var r: float = _rng.next() * total
	for k in pool:
		r -= float(pool[k])
		if r <= 0.0:
			return String(k)
	return String(pool.keys()[0])


func _grunt_caption(voice: String, gesture: String) -> String:
	return bank.grunts.get("voices", {}).get(voice, {}).get("gestures", {}).get(gesture, {}).get("caption", "")


func _pick_variant(id: String) -> int:
	var n: int = bank.variants(id)
	var v: int = int(_rng.next() * n) % n
	if n > 1 and v == int(_last_variant.get(id, -1)):
		v = (v + 1) % n
	_last_variant[id] = v
	return v


## Small random spread in pitch and level, so the same sound never plays twice identically.
func _vary(cue: Cue) -> void:
	var v: Dictionary = cfg.variation
	cue.pitch *= 1.0 + float(v.pitch) * (_rng.next() * 2.0 - 1.0)
	cue.gain_db += float(v.gain_db) * (_rng.next() * 2.0 - 1.0)


func _muffled(S: SimState, x: float, y: float) -> bool:
	var m: Dictionary = cfg.muffle
	if y >= float(m.below_y):
		return false
	return not bool(m.over_sea_only) or WorldTerrain.seaAt(S, x)
