class_name SimRoster
## Fighter definitions and construction: the twin of roster.js (the prototype's ROSTER, mkF and opp).

const ROSTER: Array = [
	{"name": "KAI", "title": "Meridian Warden", "role": "hero", "col": "#3d8fdc", "aura": "#8fd6ff", "hair": "#22c7a9", "care": 1.0, "dmgMul": 1.0, "spd": 1.0, "maxhp": 1600.0, "sigName": "Meridian Lance"},
	{"name": "VORR", "title": "Calamity Sovereign", "role": "villain", "col": "#a52a2a", "aura": "#ff5a3c", "hair": "#181818", "care": -0.8, "dmgMul": 1.0, "spd": 0.95, "maxhp": 1600.0, "sigName": "Calamity Wave"},
]


## roster.js createFighter: mkF's fields and initial values (the class defaults in state.gd hold the constants).
static func createFighter(def: Dictionary, x: float, keys: String, ai: bool) -> SimState.Fighter:
	var f := SimState.Fighter.new()
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
	f.hp = def.maxhp
	f.x = x
	f.keys = keys
	f.ai = SimState.AiState.new() if ai else null
	return f


## The other fighter: anything that is not fighters[0] gets fighters[0], as in the prototype.
static func opp(S: SimState, f) -> SimState.Fighter:
	return S.fighters[1] if S.fighters[0] == f else S.fighters[0]
