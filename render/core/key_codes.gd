class_name RenderKeys
## Godot key events to the KeyboardEvent.code names that SimKeyboard.KEYS uses. Physical keycodes, so the bindings
## follow key positions on any layout, as the prototype's e.code did.

const NAMED: Dictionary = {
	KEY_SPACE: "Space", KEY_ENTER: "Enter", KEY_KP_ENTER: "NumpadEnter", KEY_ESCAPE: "Escape",
	KEY_LEFT: "ArrowLeft", KEY_RIGHT: "ArrowRight", KEY_UP: "ArrowUp", KEY_DOWN: "ArrowDown",
	KEY_COMMA: "Comma", KEY_PERIOD: "Period", KEY_SLASH: "Slash", KEY_SEMICOLON: "Semicolon",
	KEY_SHIFT: "Shift", KEY_CTRL: "Control", KEY_ALT: "Alt", KEY_META: "Meta", KEY_TAB: "Tab",
}


static func code(e: InputEventKey) -> String:
	var k: int = e.physical_keycode
	if k == KEY_NONE:
		k = e.keycode
	if k >= KEY_A and k <= KEY_Z:
		return "Key" + char(k)
	if k >= KEY_0 and k <= KEY_9:
		return "Digit" + char(k)
	if k >= KEY_F1 and k <= KEY_F12:
		return "F%d" % (k - KEY_F1 + 1)
	return NAMED.get(k, OS.get_keycode_string(k))
