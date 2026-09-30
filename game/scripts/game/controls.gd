class_name Controls
extends RefCounted
## Builds the input map in code (keyboard, mouse, gamepad) so project.godot stays tiny.

const DEADZONE := 0.25


static func setup() -> void:
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("grab", [_key(KEY_E), _key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_action("work", [_key(KEY_F), _mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_X)])
	_action("punch", [_key(KEY_Q), _mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_B)])
	_action("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])
	_action("toggle_hints", [_key(KEY_H), _joy(JOY_BUTTON_BACK)])


static func _action(name: String, events: Array) -> void:
	if InputMap.has_action(name):
		InputMap.erase_action(name)
	InputMap.add_action(name, DEADZONE)
	for e in events:
		InputMap.action_add_event(name, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e
