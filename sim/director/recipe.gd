class_name DirRecipe
## The recipes (docs/director/alchemy-plan.md A2; docs/design/agency-pass.md section 2; Combat's data/combat/recipes.json).
## The heavies among a fighter's last five presses pick his style (blur, combo, power). The style, the press's weight and
## the stick pick a pool of Combat's pieces, and each strike the director plans is given one piece from it. The recipe is
## a mapping: the pick is a keyed draw on the match seed, the exchange and the press, so no stream shifts and a replay
## matches. A piece is a name on the strike's beat (args.piece) for the renderer; the strike's numbers stay the
## template's until Combat's rows go live.
## Pieces marked `waiting` are skipped; `posed` and `live` are drawn alike. With no recipes file, or the switch off
## (data/director/alchemy.json recipes.enabled), strikes carry no piece and the style is still read for the feed.

const PATH: String = "res://data/combat/recipes.json"
const CFG_PATH: String = "res://data/director/alchemy.json"
const STYLES: Array = [{"id": "blur", "heaviesInFive": [0, 0]}, {"id": "combo", "heaviesInFive": [1, 3]}, {"id": "power", "heaviesInFive": [4, 5]}]

static var _rec = null
static var _cfg = null
static var _text: String = ""


static func _ensure() -> void:
	if _cfg != null:
		return
	var ct: String = FileAccess.get_file_as_string(CFG_PATH) if FileAccess.file_exists(CFG_PATH) else ""
	var rt: String = FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else ""
	var c = JSON.parse_string(ct) if ct != "" else null
	var r = JSON.parse_string(rt) if rt != "" else null
	_cfg = c if c is Dictionary else {}
	_rec = r if r is Dictionary else {}
	_text = ct + rt


## The two files' text, for DirData.dataHash() (the replay header).
static func dataText() -> String:
	_ensure()
	return _text


static func cfg() -> Dictionary:
	_ensure()
	return _cfg


## Combat's recipes (data/combat/recipes.json); {} when the file is not there.
static func rec() -> Dictionary:
	_ensure()
	return _rec


## True when strikes are given pieces: the dynamic profile, the switch on, and Combat's pools loaded.
static func on() -> bool:
	_ensure()
	return DirInterrupt.on() and _cfg.get("recipes", {}).get("enabled", false) and _rec.get("pools") is Dictionary


## The style row his window calls for: by the heavies among his last five presses still alive.
static func _row(S: SimState, f) -> Dictionary:
	_ensure()
	var h: int = 0
	for p in DirAlchemy.window(S, f):
		h += p & 1
	var rows = _rec.get("styles", STYLES)
	# Section 20: the style goes by the share of heavies among the presses in the window, and Controls' classifier
	# reads it (none is blur, up to its powerShare combo, over it power; a lone heavy is power).
	var want: String = String(DirAlchemy.read(S, f).get("recipe", ""))
	for st in rows:
		if String(st.id) == ("blur" if want == "none" else want):
			return st
	for st in rows:
		if h >= int(st.heaviesInFive[0]) and h <= int(st.heaviesInFive[1]):
			return st
	return rows[1]


## His style now: blur, combo or power.
static func style(S: SimState, f) -> String:
	return String(_row(S, f).id)


## The pool a strike of his is drawn from: by his style, the weight of the press behind it, whether he held toward the
## rival, and whether it is the string's last blow. A light press in the power style takes the combo's link.
static func poolName(S: SimState, f, weight: int, toward: bool, last: bool) -> String:
	var st: Dictionary = _row(S, f)
	var base: Dictionary = st.get("base", {})
	var id: String = String(st.id)
	if id == "blur":
		if last and st.get("timed", {}).get("ender") != null:
			return String(st.timed.ender)
		return String(base.get("towardPool", "blur.toward")) if toward else String(base.get("pool", "blur.base"))
	if id == "power" and weight == SimAct.HEAVY:
		return String(base.get("lastPool", "power.last")) if last else String(base.get("pool", "power"))
	var combo: Dictionary = base if id == "combo" else _rec.get("styles", STYLES)[1].get("base", {})
	return String(combo.get("accentPool", "combo.accent")) if weight == SimAct.HEAVY else String(combo.get("linkPool", "combo.link"))


## The pools' key for a fighter: alchemy.json recipes.fighters by his roster id, else the id in lower case.
static func poolKey(f) -> String:
	return String(cfg().get("recipes", {}).get("fighters", {}).get(String(f.id), String(f.id).to_lower()))


## One piece from a pool of his: a keyed draw picks where the walk starts, and it steps past pieces that are waiting and
## past his last two picks. "" when the pool is missing or empty.
static func pick(S: SimState, f, pool: String, salt: int) -> String:
	var list = _rec.pools.get(poolKey(f), {}).get(pool)
	if not (list is Array):
		return ""
	var ok: Array = []
	for row in list:
		if String(row.get("status", "live")) != "waiting":
			ok.append(String(row.id))
	if ok.is_empty():
		return ""
	var n: int = f.act.dirI[DirAlchemy.COUNT]
	var start: int = int(SimRng.keyed(int(S.game.seed), "alchemy.piece", S.dirS.exN * 4096 + n * 16 + salt) * float(ok.size()))
	var id: String = ok[start % ok.size()]
	for step in range(ok.size()):
		id = ok[(start + step) % ok.size()]
		var hsh: int = id.hash() & 0x7fffffff
		if hsh != f.act.dirI[DirAlchemy.PIECE_1] and hsh != f.act.dirI[DirAlchemy.PIECE_2]:
			break
	f.act.dirI[DirAlchemy.PIECE_2] = f.act.dirI[DirAlchemy.PIECE_1]
	f.act.dirI[DirAlchemy.PIECE_1] = id.hash() & 0x7fffffff
	return id


## Gives every strike the exchange has pending, and has not dressed yet, its piece (after a plan: the opener, a link, the
## blur's own ender). Each fighter's strikes draw on his own style and his newest press. blurEnder: this link is the
## blur's closing blow.
static func dress(S: SimState, ex, blurEnder: bool = false) -> void:
	if not on() or ex.kind == "sig" or DirExchange.finisherPlanned(ex) or ex.tpl == DirBury.TPL:
		return
	var lastA = null   # the attacker's last pending strike: the string's last blow so far
	for b in ex.beats:
		if not b.done and (b.op == "chainStrike" or (b.op == "strike" and b.args != null and String(b.args.get("a", "A")) == "A")):
			lastA = b
	var salt: int = 0
	var picked: PackedStringArray = []
	for b in ex.beats:
		if b.done or (b.op != "strike" and b.op != "chainStrike"):
			continue
		if b.args != null and b.args.has("piece"):
			continue
		var who = ex.A if (b.op == "chainStrike" or b.args == null or String(b.args.get("a", "A")) == "A") else ex.D
		var p: int = DirInterrupt.gi(ex.A, DirInterrupt.PHRASE_P) if who == ex.A else DirAlchemy.last(S, who)
		var weight: int = (p & 1) if p >= 0 else (SimAct.HEAVY if ex.kind == "heavy" else SimAct.LIGHT)
		var toward: bool = p >= 0 and ((p >> 2) & 3) == 2
		# A blur string's blows follow its pattern, and its closing blow lands where its last light did.
		var closing: bool = who == ex.A and weight == SimAct.LIGHT and b == lastA and DirBlur.live(S, who) and (blurEnder or DirInterrupt.gi(who, DirInterrupt.LANDED) >= int(DirLaunch.data().get("blur", {}).get("enderAfter", 99)))
		var id: String = ""
		if closing:
			id = DirBlur.ender(S, who)
		elif who == ex.A and weight == SimAct.LIGHT:
			id = DirBlur.piece(S, who, toward)
		if id == "":
			id = pick(S, who, poolName(S, who, weight, toward, b == lastA and (closing or blurEnder or weight == SimAct.HEAVY)), salt)
		salt += 1
		if id == "":
			continue
		if b.args == null:
			b.args = {}
		b.args["piece"] = id
		picked.append(who.name + " " + id)
	if not picked.is_empty():
		SimEvents.feed(S, "PIECES", ", ".join(picked) + "  (" + ex.A.name + ": " + style(S, ex.A) + "; " + ex.D.name + ": " + style(S, ex.D) + ")")
