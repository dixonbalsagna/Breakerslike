class_name SimReplay
extends RefCounted
## Replays: a seed, the AI flags and the intents the host passed to step() reproduce a match bit for bit. The GDScript
## twin of replay.js, format v3 (I1, intent v2). A replay is plain JSON-able data:
##   {format, v, intent, data, seed, setup, ai, ticks, inputs, toggles, checkpoints, final}
##   intent       SimIntent.VERSION: the intent schema the inputs are packed in. Another version is refused.
##   data         dataHash(): the combat data and the roster data the match ran on (S4, D1a). It plays back only on the
##                same data.
##   setup        newMatch's setup (D1a): {"slots", "names", "flip"}, {} for the default match.
##   inputs       [tick, slot, packed intent or null], only where a slot's intent changed from its previous one. Packed is
##                SimIntent.pack(): one integer for the whole record.
##   toggles      [tick, slot]: toggleAI before that tick
##   checkpoints  [tick, gameplay hash] every CHECK_EVERY ticks; final: the gameplay hash at the end
## Intents, not raw keys, are recorded, so a replay does not depend on the key mapping or the layout. The recorder steps
## the sim with the canonical form of each intent (SimIntent.canon: the stick on its 1 / 127 grid), so what it records
## is exactly what was played.
## v1 (replay.js) had a `sim` modes field; v2 stored each intent as a dictionary of eight fields.

const FORMAT: String = "meridian-replay"
const V: int = 3
const CHECK_EVERY: int = 60

var S: SimState
var replay: Dictionary
var _last: Array = [-1, -1]   # the last packed intent per slot; -1 for none (null)


## Start recording a match: runs newMatch(S, seed, ai). Use rec.step and rec.toggle instead of SimCore.step and toggleAI.
static func recorder(S_: SimState, seed: int, ai: Dictionary = {}, setup: Dictionary = {}) -> SimReplay:
	SimCore.newMatch(S_, seed, ai, setup)
	var rec := SimReplay.new()
	rec.S = S_
	rec.replay = {"format": FORMAT, "v": V, "intent": SimIntent.VERSION, "data": dataHash(), "seed": seed, "setup": setup.duplicate(true),
		"ai": {"p1": S_.fighters[0].ai != null, "p2": S_.fighters[1].ai != null},
		"ticks": 0, "inputs": [], "toggles": [], "checkpoints": [], "final": ""}
	return rec


## One recorded step. inputs: [SimIntent or null, SimIntent or null], or null, as for SimCore.step. The sim is stepped
## with each intent's canonical form.
func step(inputs = null) -> bool:
	var cur: Array = [null, null]
	for k in range(2):
		var i = inputs[k] if inputs != null else null
		var p: int = SimIntent.pack(i) if i != null else -1
		if i != null:
			cur[k] = SimIntent.unpack(p)
		if p != _last[k]:
			_last[k] = p
			replay.inputs.append([replay.ticks, k, p if p >= 0 else null])
	var r: bool = SimCore.step(S, cur if inputs != null else null)
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


## Re-run a replay and verify it. Returns {ok, firstBadTick (-1 if ok), reason, final}. reason is "" when ok; "format" for
## another format, version or intent schema, or an input that is not a valid packed intent (it is not run); "data" when it
## was recorded on other data (not run); "checkpoint" or "final" otherwise.
static func play(rp: Dictionary) -> Dictionary:
	var refuse := {"ok": false, "firstBadTick": -1, "reason": "format", "final": ""}
	if rp.get("format", "") != FORMAT or int(rp.get("v", 0)) != V or int(rp.get("intent", 0)) != SimIntent.VERSION:
		return refuse
	var packed: Array = []
	for inp in rp.get("inputs", []):
		var it = null
		if inp[2] != null:
			var f: float = float(inp[2])
			it = SimIntent.unpack(int(f)) if f == floor(f) else null
			if it == null:
				return refuse
		packed.append(it)
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
			cur[int(rp.inputs[ii][1])] = packed[ii]
			ii += 1
		SimCore.step(S_, cur)
		if checks.has(t + 1) and checks[t + 1] != SimHash.stateHash(S_).gameplay:
			out = {"ok": false, "firstBadTick": t + 1, "reason": "checkpoint", "final": ""}
			break
		S_.out.fx.clear()   # playback is its own host: it drains the event and feed lists
		S_.out.feed.clear()
	out.final = SimHash.stateHash(S_).gameplay
	if out.ok and rp.final != "" and out.final != rp.final:
		out = {"ok": false, "firstBadTick": int(rp.ticks), "reason": "final", "final": out.final}
	SimCore.dispose(S_)
	return out


## The data a replay depends on: Combat's data (DirData), the roster (FighterData) and the fight's mood and style data
## (SimMood, M1), one hash.
static func dataHash() -> String:
	var h := SimHash.Hasher.new()
	h.text(DirData.dataHash())
	h.text(FighterData.dataHash())
	h.text(SimMood.dataHash())
	h.text(SimPause.dataHash())   # Q10: data/fight/pause.json
	return h.hex()
