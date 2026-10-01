# The mood's form impulse (spec-wounds.md section 9: a transformation adds to the mood). It is given at the break, by a
# call, and not read from the tier_up event: on a full or short version the break lands on a frozen tick inside the pause,
# where the mood does not tick and so reads no event. Usage: python mood_form.py <repo root> [value]
# The value is impulses.form in data/fight/mood.json (QA's 900 by default). A behaviour change: regenerate the goldens.
import os, sys, json, collections
os.chdir(sys.argv[1])
value=int(sys.argv[2]) if len(sys.argv)>2 else 900
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

edit('sim/core/mood.gd', [
('''static func onForm(S: SimState) -> void:
	_ensure()
	if formSteps:
		S.mood.cause = CAUSES.find("form")
''','''static func onForm(S: SimState, f = null) -> void:
	_ensure()
	if formSteps:
		S.mood.cause = CAUSES.find("form")
	# The form impulse (spec-wounds.md section 9), given here and not from the tier_up event: the break of a full or short
	# transformation lands on a frozen tick, where tick() does not run and so reads no event.
	S.mood.v = clampi(S.mood.v + _imp(S.fighters, "form", S.fighters.find(f)), 0, mood.range)
'''),
])
edit('sim/core/fighter.gd', [
('''	SimMood.onForm(S)   # Q10: a form step may raise the act''','''	SimMood.onForm(S, f)   # a form step may raise the act, and it adds the mood's form impulse'''),
])
p="data/fight/mood.json"
d=json.load(open(p,encoding='utf-8'),object_pairs_hook=collections.OrderedDict)
d["impulses"]["form"]=value
open(p,'w',encoding='utf-8',newline='\n').write(json.dumps(d,indent=2,ensure_ascii=False)+"\n")

p='sim/core/tools/parity.gd'
s=open(p,encoding='utf-8').read()
a='''	check("the break", _formBreak())
'''
assert s.count(a)==1
s=s.replace(a,a+'''	check("the form impulse", _formImpulse())
''')
a='''## The break (moveset-rules.md section 10.8):'''
assert s.count(a)==1
s=s.replace(a,'''## The mood's form impulse: a transformation's break adds impulses.form to the mood, by a call (SimMood.onForm) and not
## from the tier_up event, so it is also given when the break lands on a frozen tick inside a full pause.
func _formImpulse() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5)
	var a = S.fighters[0]
	a.stance = 1.0   # not AGGRESSIVE: the plain impulse
	var want: int = SimMood.imp["form"][0]
	if want <= 0:
		return "mood.json impulses.form is 0"
	a.power = a.ld.thresholds[0] + 1.0
	a.act.formReady = true
	a.y = 20000.0
	S.pause.bank = SimPause.bankMax
	var r: Dictionary = SimPause.request(S, SimPause.TRANSFORM, 0)
	SimFighter.transform(S, a)
	if r.version != SimPause.FULL:
		return "the set-up did not give a full pause"
	var v0: int = S.mood.v
	var g: int = SimPause.gather[SimPause.FULL]
	for t in range(1, g + 1):
		if SimCore.step(S, null):
			return "tick %d of the pause was live" % t
		if S.mood.v != (v0 + want if t == g else v0):
			return "at paused tick %d the mood is %d (it was %d; the impulse is %d and the gather %d)" % [t, S.mood.v, v0, want, g]
	SimCore.dispose(S)
	return ""


## The break (moveset-rules.md section 10.8):''')
open(p,'w',encoding='utf-8',newline='\n').write(s)
print("form impulse applied:", value)
