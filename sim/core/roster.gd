class_name SimRoster
## Fighter construction: the twin of roster.js (mkF and opp). D1a: the definitions are data (data/fighters/, loaded by
## FighterData); a def is FighterData.def(id).

## roster.js createFighter: mkF's fields and initial values (the class defaults in state.gd hold the constants). def is a
## FighterData def: its scalars are copied, and f.wd points at its WoundsDef.
static func createFighter(def: Dictionary, x: float, keys: String, ai: bool) -> SimState.Fighter:
	var f := SimState.Fighter.new()
	f.id = def.id
	f.name = def.name
	f.title = def.title
	f.role = def.role
	f.col = def.col
	f.aura = def.aura
	f.hair = def.hair
	f.care = def.care
	f.dmgMul = def.dmgMul
	f.spd = def.spd
	f.maxhp = def.maxhp
	f.sigName = def.sigName
	f.canHide = def.get("canHide", false)
	f.hasAnguish = def.get("anguish", false)
	f.hasMenace = def.get("menace", false)
	f.rally = def.get("rally", "")
	f.wd = def.wd
	f.finisher = def.get("finisher", "")
	f.hp = def.maxhp
	f.x = x
	f.keys = keys
	f.ai = SimState.AiState.new() if ai else null
	return f


## The other fighter: anything that is not fighters[0] gets fighters[0], as in the prototype.
static func opp(S: SimState, f) -> SimState.Fighter:
	return S.fighters[1] if S.fighters[0] == f else S.fighters[0]
