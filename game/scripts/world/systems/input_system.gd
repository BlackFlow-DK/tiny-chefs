class_name InputSystem
extends RefCounted
## Owns this peer's own input: keyboard/pad (Controls actions) or the --bot driver, into world.local_input.
## Every peer. Reads Net.phase, world.input_blocked (pause menu), window focus.
## Calls Bot.update. The host copies local_input into its own chef's slot; clients Net.send_input it.

var world: World
var bot: Bot = null


func _init(w: World) -> void:
	world = w
	if Net.has_arg("bot"):
		bot = Bot.new(w)


func collect(dt: float) -> void:
	var local_input := world.local_input
	if bot != null:
		bot.update(dt, local_input)
		return
	var active := Net.phase == Net.Phase.PLAYING and not world.input_blocked and world.get_window().has_focus()
	if not active:
		local_input.move = Vector2.ZERO
		local_input.work = false
		return
	local_input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	local_input.work = Input.is_action_pressed("work")
	if Input.is_action_just_pressed("grab"):
		local_input.grab_seq += 1
	if Input.is_action_just_pressed("punch"):
		local_input.punch_seq += 1
	if Input.is_action_just_pressed("work"):
		local_input.work_seq += 1
