class_name Controls
extends RefCounted
## Builds the input map in code (keyboard, mouse, gamepad) so project.godot stays tiny.
## Mouse buttons live in the map too, but InputSystem only counts a press that the GUI did not
## take (_unhandled_input), so clicking a menu button never grabs / works / punches.
## Aim (mouse cursor or right stick) is read by InputSystem, see PlayerInput.aim_point.

const DEADZONE := 0.25


static func setup() -> void:
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action("grab", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_E), _joy(JOY_BUTTON_A)])
	_action("work", [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_F), _joy(JOY_BUTTON_X)])
	_action("punch", [_key(KEY_SPACE), _key(KEY_Q), _joy(JOY_BUTTON_B)])
	_action("ping", [_mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_Y)])
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
