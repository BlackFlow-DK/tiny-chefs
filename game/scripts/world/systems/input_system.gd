class_name InputSystem
extends RefCounted
## Owns this peer's own input: keyboard/mouse/pad (Controls actions) or the --bot driver, into
## world.local_input. Every peer. Reads Net.phase, world.input_blocked (pause menu), window focus,
## the current camera (viewport.get_camera_3d() at call time). Calls Bot.update.
## The host copies local_input into its own chef's slot; clients Net.send_input it.
##
## Presses (grab/work/punch) are counted from _unhandled_input, so a click the GUI takes (pause
## menu, shop, results buttons) never reaches the game. Movement is polled.
## Aim: see PlayerInput.aim_point / has_aim. The mouse is the active device after it moves or
## clicks; a pad button or stick makes the pad active. Keyboard does not switch device.
## --input-log prints counted presses and (every 0.5 s) every chef's aim + facing on the host.
## Injected agent input (--key/--mouse/--click) skips the window-focus check.

const AIM_PLANE_Y := 0.0          # counter top
const PAD_AIM_DISTANCE := 3.0     # metres from the chef along the right stick
const PAD_SWITCH_AXIS := 0.5      # stick deflection that makes the pad the active device

var world: World
var bot: Bot = null
var _mouse_active := false
var _mouse_pos := Vector2.ZERO    # viewport coordinates, from the last mouse event
var _work_armed := false          # work held and its press started in the game, not on the GUI
var _log := false
var _ignore_focus := false


class Events extends Node:
	var sys: InputSystem

	func _input(event: InputEvent) -> void:
		sys._on_event(event)

	func _unhandled_input(event: InputEvent) -> void:
		sys._on_unhandled(event)


func _init(w: World) -> void:
	world = w
	_log = Net.has_arg("input-log")
	_ignore_focus = Net.has_arg("key") or Net.has_arg("mouse") or Net.has_arg("click")
	if Net.has_arg("bot"):
		bot = Bot.new(w)
		return
	var ev := Events.new()
	ev.name = "InputEvents"
	ev.sys = self
	w.add_child(ev)


func _active() -> bool:
	return Net.phase == Net.Phase.PLAYING and not world.input_blocked \
		and (_ignore_focus or world.get_window().has_focus())


func collect(dt: float) -> void:
	var local_input := world.local_input
	if bot != null:
		bot.update(dt, local_input)
	elif not _active():
		local_input.move = Vector2.ZERO
		local_input.work = false
		_work_armed = false
	else:
		local_input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if not Input.is_action_pressed("work"):
			_work_armed = false
		local_input.work = _work_armed
		_update_aim(local_input)
	if _log and Engine.get_physics_frames() % 30 == 0:
		_log_aim()


## Every event, before the GUI: which device is active, and where the cursor is.
func _on_event(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_pos = (event as InputEventMouse).position
		_mouse_active = true
	elif event is InputEventJoypadButton and event.pressed:
		_mouse_active = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > PAD_SWITCH_AXIS:
		_mouse_active = false


## Events the GUI did not take: count presses.
func _on_unhandled(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or bot != null or not _active():
		return
	var inp := world.local_input
	if event.is_action_pressed("grab"):
		inp.grab_seq += 1
		_note("grab", inp.grab_seq, event)
	if event.is_action_pressed("punch"):
		inp.punch_seq += 1
		_note("punch", inp.punch_seq, event)
	if event.is_action_pressed("work"):
		inp.work_seq += 1
		_work_armed = true
		_note("work", inp.work_seq, event)


func _update_aim(inp: PlayerInput) -> void:
	if _mouse_active:
		var cam := world.get_viewport().get_camera_3d()
		if cam == null:
			inp.has_aim = false
			return
		var o := cam.project_ray_origin(_mouse_pos)
		var d := cam.project_ray_normal(_mouse_pos)
		if d.y > -0.001:
			return  # cursor above the horizon: keep the last aim
		var p := o + d * ((AIM_PLANE_Y - o.y) / d.y)
		inp.aim_point = Vector2(p.x, p.z)
		inp.has_aim = true
		return
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var me := world.my_chef()
	if stick.length() > 0.2 and me != null:
		inp.aim_point = Vector2(me.global_position.x, me.global_position.z) + stick.normalized() * PAD_AIM_DISTANCE
		inp.has_aim = true
	else:
		inp.has_aim = false


func _note(what: String, n: int, event: InputEvent) -> void:
	if _log:
		print("input: %s #%d from %s (aim %s has_aim %s)" % [what, n, event.as_text(),
			world.local_input.aim_point.snapped(Vector2.ONE * 0.01), world.local_input.has_aim])


func _log_aim() -> void:
	if not world.is_host:
		var li := world.local_input
		print("input: local aim %s has_aim %s" % [li.aim_point.snapped(Vector2.ONE * 0.01), li.has_aim])
		return
	for id in world.chefs.keys():
		var c: Chef = world.chefs[id]
		var inp := world.input_of(id)
		var to := inp.aim3() - Vector3(c.global_position.x, 0.0, c.global_position.z)
		print("input: host chef %d pos %s has_aim %s aim %s yaw %.0f deg aim_yaw %.0f deg held %d work %s items %d" % [id,
			c.global_position.snapped(Vector3.ONE * 0.01), inp.has_aim, inp.aim_point.snapped(Vector2.ONE * 0.01),
			rad_to_deg(c.rotation.y), rad_to_deg(atan2(to.x, to.z)), c.held_id, inp.work, world.items.size()])
