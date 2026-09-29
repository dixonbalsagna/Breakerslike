class_name SimControl
## Per-fighter input step, run once per fighter per tick in the tick's random order: the twin of control.js.


## intent: the host's intent for a human fighter (keyboard, replay or network). AI fighters ignore it; null leaves f neutral.
static func control(S: SimState, f, intent) -> void:
	var i: SimIntent = f.input
	SimIntent.clearIntent(i)
	if S.game.ko != null:
		return
	if f.ai != null:
		DirAI.aiInput(S, f)
	elif intent != null:
		SimIntent.applyIntent(i, intent)
	if i.stance >= 0.0:
		f.stance = i.stance
	if i.light or i.heavy:
		f.lastAtkT = S.T
	if i.light:
		DirExchange.requestAttack(S, f, "light")
	elif i.heavy:
		DirExchange.requestAttack(S, f, "heavy")
	elif i.sig:
		DirExchange.requestAttack(S, f, "sig")
