class_name SimInputNames
## The names a control goes by in the data (docs/controls/input-schema.md section 2), shared by the host's event handler
## and the remap screen's "press a key or button" capture, so they cannot disagree. A control id is "kb:<code>" (the
## KeyboardEvent.code, as render/core/key_codes.gd gives it), "pad:<position>" or "touch:<widget>".

## A pad button by its Godot index to its position name. Positions, not labels: the layouts are the same on every pad.
const PAD_BUTTONS: Dictionary = {
	JOY_BUTTON_A: "south", JOY_BUTTON_B: "east", JOY_BUTTON_X: "west", JOY_BUTTON_Y: "north",
	JOY_BUTTON_BACK: "back", JOY_BUTTON_START: "start", JOY_BUTTON_LEFT_STICK: "l3", JOY_BUTTON_RIGHT_STICK: "r3",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb", JOY_BUTTON_DPAD_UP: "dpad_up",
	JOY_BUTTON_DPAD_DOWN: "dpad_down", JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}

## The analog triggers by axis to their control names.
const PAD_TRIGGERS: Dictionary = {JOY_AXIS_TRIGGER_LEFT: "lt", JOY_AXIS_TRIGGER_RIGHT: "rt"}


static func kb(code: String) -> String:
	return "kb:" + code


static func pad(name: String) -> String:
	return "pad:" + name


## The control id a pad event stands for, or "": a button press, or a trigger pulled past the data's triggerOn. The remap
## screen's capture uses it; a stick or a release is not a binding.
static func pad_control_from_event(e: InputEvent) -> String:
	if e is InputEventJoypadButton and e.pressed and PAD_BUTTONS.has(e.button_index):
		return pad(PAD_BUTTONS[e.button_index])
	if e is InputEventJoypadMotion and PAD_TRIGGERS.has(e.axis) and e.axis_value >= SimInputData.tf(["stick", "triggerOn"], 0.35):
		return pad(PAD_TRIGGERS[e.axis])
	return ""
