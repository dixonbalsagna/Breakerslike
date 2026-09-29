class_name SimKeyboard
## Keyboard bindings and key state to intent, host side: the twin of keyboard.js (KEYS, intentFromKeys).
## held and edges are Dictionaries used as sets of key codes (key -> true).

const KEYS: Dictionary = {
	"p1": {"l": "KeyA", "r": "KeyD", "u": "KeyW", "d": "KeyS", "dash": "Space", "light": "KeyF", "heavy": "KeyG", "sig": "KeyR", "charge": "KeyQ", "st": ["Digit1", "Digit2", "Digit3", "Digit4"]},
	"p2": {"l": "ArrowLeft", "r": "ArrowRight", "u": "ArrowUp", "d": "ArrowDown", "dash": "Enter", "light": "Comma", "heavy": "Period", "sig": "Slash", "charge": "Semicolon", "st": ["Digit7", "Digit8", "Digit9", "Digit0"]},
}


static func intentFromKeys(k: Dictionary, held: Dictionary, edges: Dictionary) -> SimIntent:
	var i := SimIntent.new()
	i.mx = (1.0 if held.has(k.r) else 0.0) - (1.0 if held.has(k.l) else 0.0)
	i.my = (1.0 if held.has(k.u) else 0.0) - (1.0 if held.has(k.d) else 0.0)
	i.dash = held.has(k.dash)
	i.charge = held.has(k.charge)
	i.light = edges.has(k.light)
	i.heavy = edges.has(k.heavy)
	i.sig = edges.has(k.sig)
	for s in range(4):
		if edges.has(k.st[s]):
			i.stance = float(s)
	return i
