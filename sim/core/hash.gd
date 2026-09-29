class_name SimHash
## Canonical state walk and hash: the twin of hash.js. It emits the same values in the same order, with the same type
## tags, so a GDScript state and a JS state hash identically exactly when they are identical bit for bit.

const MASK: int = 0xFFFFFFFF
const FIGHTER: Array = ["name", "title", "role", "col", "aura", "hair", "care", "dmgMul", "spd", "maxhp", "sigName", "hp", "x", "y", "vx", "vy", "face", "ki", "power", "tier", "stance", "state", "stateT",
	"hidden", "hideT", "hiddenFor", "menace", "anguish", "ambush", "rot", "spin", "bounces", "lastAtkT", "hurtT", "keys", "beamCharge", "wet", "ambushUntil", "dPrev"]
const INTENT: Array = ["mx", "my", "dash", "charge", "light", "heavy", "sig", "stance"]
const BUILDING: Array = ["x", "w", "h", "maxhp", "hp", "alive", "kind", "pop", "seed", "popAlive"]
const TREE: Array = ["x", "h", "alive", "burn"]
const BEAM: Array = ["ox", "oy", "ux", "uy", "len", "p", "t", "life", "w", "variant", "col"]
const PART: Array = ["type", "x", "y", "vx", "vy", "life", "age", "grav", "drag", "size", "col", "r", "gr", "face"]
const FLOAT: Array = ["x", "y", "txt", "t", "col"]


## Two 32-bit lanes over the raw IEEE-754 bits of every value (hash.js Hasher). Lanes are kept unsigned.
class Hasher:
	var a: int = 0x811c9dc5
	var b: int = 0x9e3779b9
	var _buf := PackedByteArray()

	func _init() -> void:
		_buf.resize(8)

	func u(w: int) -> void:
		a = SimRng.imul((a ^ w) & MASK, 16777619)
		var x: int = SimRng.imul(((b ^ w) + 0x7f4a7c15) & MASK, 0x85ebca6b)
		b = (x ^ (x >> 13)) & MASK

	func num(x: float) -> void:
		_buf.encode_double(0, x)
		u(_buf.decode_u32(0))
		u(_buf.decode_u32(4))

	func text(s: String) -> void:
		for i in range(s.length()):
			u(s.unicode_at(i))   # the sim's strings are all in the BMP, where code points are UTF-16 units
		u(0xff)

	func hex() -> String:
		return "%08x%08x" % [a, b]


static func _idx(fs: Array, f) -> float:
	return -1.0 if f == null else float(fs.find(f))


static func _obj(out: Array, o, fields: Array) -> void:
	if o == null:
		out.append(null)
		return
	for k in fields:
		out.append(o.get(k))


static func _args(out: Array, v) -> void:
	if not (v is Dictionary):
		out.append(v)
		return
	var keys: Array = v.keys()
	keys.sort()
	out.append(float(keys.size()))
	for k in keys:
		out.append(k)
		_args(out, v[k])


## hash.js collect() for the GDScript state. lane is "gameplay" (the sim S) or "presentation" (the cosmetic view V).
static func collect(S: SimState, lane: String, beatDetail: bool = true, V: SimFxView = null) -> Array:
	var out: Array = []
	var fs: Array = S.fighters
	if lane == "presentation":
		out.append(V.shake if V != null else 0.0)
		_obj(out, V.banner if V != null else null, ["text", "col", "t", "dur"])
		var floats: Array = V.floats if V != null else []
		var parts: Array = V.parts if V != null else []
		out.append(float(floats.size()))
		for f in floats:
			_obj(out, f, FLOAT)
		out.append(float(parts.size()))
		for p in parts:
			_obj(out, p, PART)
		return out
	out.append(S.T)
	out.append(float(S.rng.state_i32()))
	var g := S.game
	out.append(_idx(fs, g.ko))
	_obj(out, g, ["koT", "ts", "seed"])
	if g.clash != null:
		out.append(_idx(fs, g.clash.A))
		out.append(_idx(fs, g.clash.D))
		_obj(out, g.clash, ["t0", "dur", "aw"])
	else:
		out.append(null)
	var d := S.dirS
	_obj(out, d, ["cool", "stop", "lastLaunch"])
	out.append(d.lastLaunch2)
	var ex = d.ex
	if ex != null:
		out.append(_idx(fs, ex.A))
		out.append(_idx(fs, ex.D))
		_obj(out, ex, ["kind", "t", "combo", "tag", "windowStart", "cancel"])
		_obj(out, ex.ext, ["start", "until"])
		out.append(float(ex.beats.size()))
		for b in ex.beats:
			_obj(out, b, ["t", "done"])
			if beatDetail:
				out.append(b.op)
				_args(out, b.args)
	else:
		out.append(null)
	for f in fs:
		_obj(out, f, FIGHTER)
		var r = f.rush
		if r == null:
			out.append(null)
		elif r.tgt != null:
			out.append("tgt"); out.append(_idx(fs, r.tgt)); out.append(r.off); out.append(r.end)
		else:
			out.append("pt"); out.append(r.px); out.append(r.py); out.append(r.end)
		out.append(_idx(fs, f.launchBy))
		_obj(out, f.ai, ["t", "atk", "sT", "sOff"])
		_obj(out, f.lastSeen, ["x", "y"])
		_obj(out, f.input, INTENT)
	_obj(out, S.world, ["pop0", "casualties", "structuresLost", "craters"])
	out.append(float(S.buildings.size()))
	for b in S.buildings:
		_obj(out, b, BUILDING)
	out.append(float(S.trees.size()))
	for t in S.trees:
		_obj(out, t, TREE)
	out.append(float(S.beams.size()))
	for b in S.beams:
		out.append(_idx(fs, b.A))
		_obj(out, b, BEAM)
	for i in range(S.deform.size()):
		out.append(S.deform[i])
	return out


## hash.js hashValues(): tag every value by type, numbers by their float64 bits.
static func hashValues(vals: Array) -> String:
	var h := Hasher.new()
	for v in vals:
		match typeof(v):
			TYPE_FLOAT:
				h.u(1); h.num(v)
			TYPE_INT:
				h.u(1); h.num(float(v))
			TYPE_STRING:
				h.u(2); h.text(v)
			TYPE_BOOL:
				h.u(4 if v else 3)
			TYPE_NIL:
				h.u(5)
			_:
				push_error("hashValues: unexpected value type %d" % typeof(v))
	return h.hex()


## hash.js stateHash(S): the sim state.
static func stateHash(S: SimState) -> Dictionary:
	return {"gameplay": hashValues(collect(S, "gameplay"))}


## hash.js viewHash(S, V): a cosmetic view.
static func viewHash(S: SimState, V: SimFxView) -> String:
	return hashValues(collect(S, "presentation", true, V))


## hash.js FX_FIELDS and hashFx: fold fx events into a Hasher, fields in the canonical order of their type.
const FX_FIELDS: Dictionary = {
	"spark": ["x", "y", "n", "col", "spd"], "ring": ["x", "y", "gr", "col", "life", "r0"], "debris": ["x", "y", "n", "col", "spd"],
	"dust": ["x", "y", "n", "col"], "splash": ["x", "y", "n"], "fire": ["x", "y", "n"], "after": ["x", "y", "life", "col", "face"],
	"charge": ["x", "y", "col", "ground"], "beamSplash": ["x"], "damage": ["x", "y", "amount", "col"], "banner": ["text", "col", "dur"],
	"shake": ["k"], "tick": ["dt", "frozen"],
}


static func hashFx(h: Hasher, events: Array) -> void:
	for e in events:
		h.text(e.type)
		for k in FX_FIELDS[e.type]:
			var v = e.get(k)
			match typeof(v):
				TYPE_FLOAT:
					h.num(v)
				TYPE_INT:
					h.num(float(v))
				TYPE_STRING:
					h.text(v)
				TYPE_BOOL:
					h.u(4 if v else 3)
