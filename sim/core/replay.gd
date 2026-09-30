class_name SimReplay
extends RefCounted
## Replays: a seed, the AI flags and the intents the host passed to step() reproduce a match bit for bit. The GDScript
## twin of replay.js, format v2. A replay is plain JSON-able data:
##   {format, v, data, seed, ai, ticks, inputs, toggles, checkpoints, final}
##   data         dataHash(): the combat data and the roster data the match ran on (S4, D1a). It plays back only on the
##                same data.
##   setup        newMatch's setup (D1a): {"slots", "names", "flip"}, {} for the default match; absent in older files.
##   inputs       [tick, slot, intent dictionary or null], only where a slot's intent changed from its previous one
##   toggles      [tick, slot]: toggleAI before that tick
##   checkpoints  [tick, gameplay hash] every CHECK_EVERY ticks; final: the gameplay hash at the end
## Intents, not raw keys, are recorded, so a replay does not depend on the key mapping. v1 (replay.js) had a `sim`
## modes field instead of `data`; the GDScript sim has one mode.

const FORMAT: String = "meridian-replay"
const V: int = 2
const CHECK_EVERY: int = 60
const INTENT: Array = ["mx", "my", "dash", "charge", "light", "heavy", "sig", "stance"]

var S: SimState
var replay: Dictionary
var _last: Array = [null, null]


## Start recording a match: runs newMatch(S, seed, ai). Use rec.step and rec.toggle instead of SimCore.step and toggleAI.
static func recorder(S_: SimState, seed: int, ai: Dictionary = {}, setup: Dictionary = {}) -> SimReplay:
	SimCore.newMatch(S_, seed, ai, setup)
	var rec := SimReplay.new()
	rec.S = S_
	rec.replay = {"format": FORMAT, "v": V, "data": dataHash(), "seed": seed, "setup": setup.duplicate(true),
		"ai": {"p1": S_.fighters[0].ai != null, "p2": S_.fighters[1].ai != null},
		"ticks": 0, "inputs": [], "toggles": [], "checkpoints": [], "final": ""}
	return rec


## One recorded step. inputs: [SimIntent or null, SimIntent or null], or null, as for SimCore.step.
func step(inputs = null) -> bool:
	for k in range(2):
		var d = _dict(inputs[k] if inputs != null else null)
		if not _same(d, _last[k]):
			_last[k] = d
			replay.inputs.append([replay.ticks, k, d.duplicate() if d != null else null])
	var r: bool = SimCore.step(S, inputs)
	replay.ticks += 1
	if replay.ticks % CHECK_EVERY == 0:
		replay.checkpoints.append([replay.ticks, SimHash.stateHash(S).gameplay])
	return r


func toggle(idx: int) -> void:
	replay.toggles.append([replay.ticks, idx])
	SimCore.toggleAI(S, idx)


func finish() -> Dictionary:
	replay.final = SimHash.stateHash(S).gameplay
	return replay


## Re-run a replay and verify it. Returns {ok, firstBadTick (-1 if ok), reason, final}. reason is "" when ok, "data" when
## the replay was recorded on other combat data (it is not run), "checkpoint" or "final" otherwise.
static func play(rp: Dictionary) -> Dictionary:
	if rp.get("format", "") != FORMAT or int(rp.get("v", 0)) != V:
		return {"ok": false, "firstBadTick": -1, "reason": "format", "final": ""}
	if rp.get("data", "") != dataHash():
		return {"ok": false, "firstBadTick": -1, "reason": "data", "final": ""}
	var S_ := SimCore.createSim()
	SimCore.newMatch(S_, int(rp.seed), rp.ai, rp.get("setup", {}))
	var checks := {}
	for c in rp.checkpoints:
		checks[int(c[0])] = c[1]
	var cur: Array = [null, null]
	var ii: int = 0
	var ti: int = 0
	var out := {"ok": true, "firstBadTick": -1, "reason": "", "final": ""}
	for t in range(int(rp.ticks)):
		while ti < rp.toggles.size() and int(rp.toggles[ti][0]) == t:
			SimCore.toggleAI(S_, int(rp.toggles[ti][1]))
			ti += 1
		while ii < rp.inputs.size() and int(rp.inputs[ii][0]) == t:
			cur[int(rp.inputs[ii][1])] = _intent(rp.inputs[ii][2])
			ii += 1
		SimCore.step(S_, cur)
		if checks.has(t + 1) and checks[t + 1] != SimHash.stateHash(S_).gameplay:
			out = {"ok": false, "firstBadTick": t + 1, "reason": "checkpoint", "final": ""}
			break
	out.final = SimHash.stateHash(S_).gameplay
	if out.ok and rp.final != "" and out.final != rp.final:
		out = {"ok": false, "firstBadTick": int(rp.ticks), "reason": "final", "final": out.final}
	SimCore.dispose(S_)
	return out


## The data a replay depends on: Combat's data (DirData) and the roster (FighterData), one hash.
static func dataHash() -> String:
	var h := SimHash.Hasher.new()
	h.text(DirData.dataHash())
	h.text(FighterData.dataHash())
	return h.hex()


static func _dict(i):
	if i == null:
		return null
	var d := {}
	for k in INTENT:
		d[k] = i.get(k)
	return d


static func _same(a, b) -> bool:
	if a == null or b == null:
		return a == b
	for k in INTENT:
		if a[k] != b[k]:
			return false
	return true


static func _intent(d):
	if d == null:
		return null
	var i := SimIntent.new()
	i.mx = float(d.mx); i.my = float(d.my); i.dash = bool(d.dash); i.charge = bool(d.charge)
	i.light = bool(d.light); i.heavy = bool(d.heavy); i.sig = bool(d.sig); i.stance = float(d.stance)
	return i
