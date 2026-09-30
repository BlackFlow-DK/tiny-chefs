extends Node
## Agent input helper (autoload "AgentInput"). Inert unless the game is started with user args
## after "--" like:  --key=<start seconds>@<key name>@<hold seconds>   (repeatable)
## e.g. --key=2@W@1.5 --key=4@F@0.8 --key=5.2@E@0.1
## Injects real InputEventKey presses (physical keycodes), so the game's normal keyboard path
## (InputMap -> Input polling) is exercised. Key names as in OS.find_keycode_from_string().


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--key="):
			continue
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


func _hold(start: float, code: Key, seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, start), true, false, true).timeout
	_send(code, true)
	print("input_script: %s down at %.1f s" % [OS.get_keycode_string(code), start])
	await get_tree().create_timer(maxf(0.02, seconds), true, false, true).timeout
	_send(code, false)


func _send(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
