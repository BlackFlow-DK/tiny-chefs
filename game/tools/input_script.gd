extends Node
## Agent input helper (autoload "AgentInput"). Inert unless the game is started with user args
## after "--" like (all repeatable, times in seconds after start):
##   --key=<start>@<key name>@<hold>            e.g. --key=2@W@1.5 --key=4@F@0.8 --key=5.2@E@0.1
##   --mouse=<start>@<x>,<y>                    move the cursor to window pixel x,y (1280x720 window)
##   --click=<start>@<left|right|middle>@<hold> press a mouse button at the last --mouse position
## Injects real InputEventKey / InputEventMouseMotion / InputEventMouseButton through
## Input.parse_input_event, so the game's normal path (GUI first, then InputMap / _unhandled_input)
## is exercised. The OS cursor is not moved. Key names as in OS.find_keycode_from_string().

var _pos := Vector2(640, 360)
var _mask := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--key="):
			var parts := arg.trim_prefix("--key=").split("@")
			if parts.size() != 3:
				printerr("input_script: bad --key spec: %s" % arg)
				continue
			var code := OS.find_keycode_from_string(parts[1])
			if code == KEY_NONE:
				printerr("input_script: unknown key: %s" % parts[1])
				continue
			process_mode = Node.PROCESS_MODE_ALWAYS
			_hold(parts[0].to_float(), code, parts[2].to_float())
		elif arg.begins_with("--mouse="):
			var parts := arg.trim_prefix("--mouse=").split("@")
			var xy := parts[1].split(",") if parts.size() == 2 else PackedStringArray()
			if xy.size() != 2:
				printerr("input_script: bad --mouse spec: %s" % arg)
				continue
			process_mode = Node.PROCESS_MODE_ALWAYS
			_move(parts[0].to_float(), Vector2(xy[0].to_float(), xy[1].to_float()))
		elif arg.begins_with("--click="):
			var parts := arg.trim_prefix("--click=").split("@")
			var buttons := {"left": MOUSE_BUTTON_LEFT, "right": MOUSE_BUTTON_RIGHT, "middle": MOUSE_BUTTON_MIDDLE}
			if parts.size() != 3 or not buttons.has(parts[1]):
				printerr("input_script: bad --click spec: %s" % arg)
				continue
			process_mode = Node.PROCESS_MODE_ALWAYS
			_click(parts[0].to_float(), buttons[parts[1]], parts[2].to_float())


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds), true, false, true).timeout


func _hold(start: float, code: Key, seconds: float) -> void:
	await _wait(start)
	_send(code, true)
	print("input_script: %s down at %.1f s" % [OS.get_keycode_string(code), start])
	await _wait(maxf(0.02, seconds))
	_send(code, false)


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _move(start: float, to: Vector2) -> void:
	await _wait(start)
	var e := InputEventMouseMotion.new()
	e.relative = to - _pos
	e.position = to
	e.global_position = to
	e.button_mask = _mask
	_pos = to
	Input.parse_input_event(e)
	print("input_script: mouse to %s at %.1f s" % [to, start])


func _click(start: float, button: MouseButton, seconds: float) -> void:
	await _wait(start)
	_button(button, true)
	print("input_script: mouse %d down at %s at %.1f s" % [button, _pos, start])
	await _wait(maxf(0.02, seconds))
	_button(button, false)


func _button(button: MouseButton, pressed: bool) -> void:
	var bit := 1 << (button - 1)
	_mask = (_mask | bit) if pressed else (_mask & ~bit)
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = _pos
	e.global_position = _pos
	e.button_mask = _mask
	Input.parse_input_event(e)
