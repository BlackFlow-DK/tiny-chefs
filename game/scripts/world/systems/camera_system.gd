class_name CameraSystem
extends RefCounted
## Owns the follow camera: creates world.camera (a normal perspective Camera3D, always current)
## and eases it after the local chef every frame: smoothed focus with look-ahead, wheel / pad
## shoulder zoom, a gentle pull-back while carrying. Fixed yaw (looks towards -Z).
## Every peer. Reads world.my_chef(), Tuning.CAMERA_*. The HUD and mouse aiming read world.camera.
## Debug args: --cam-log (jitter stats), --cam-zoom=<0..1> starts at that point between the close and far limits, --cam-look=<x>,<z> pins the focus there.

var world: World
var _cam_ready := false
var _focus := Vector3(0, 0, 2)     # smoothed point the camera looks at
var _vel := Vector3.ZERO           # smoothed focus velocity (look-ahead source)
var _prev_target := Vector3.ZERO
var _zoom_want := Tuning.CAMERA_DISTANCE
var _zoom := Tuning.CAMERA_DISTANCE
var _carry := 0.0                  # 0..1 pull-back blend
var _zoom_v := 0.0
var _carry_v := 0.0
var _focus_v := Vector3.ZERO
var _look_override := Vector2.INF   # --cam-look=<x>,<z>: fixed focus point (screenshots of one spot)
var _log := OS.get_cmdline_user_args().has("--cam-log")
var _log_prev := Vector3.ZERO
var _log_prev_v := Vector3.ZERO
var _log_n := 0
var _log_t := 0.0
var _log_maxv := 0.0
var _log_maxdv := 0.0


## Child of the camera: catches the wheel, and drives the camera AFTER every chef has eased this
## frame (process_priority 100), so the camera never lags the chef by a frame of varying length.
class _Driver extends Node:
	const PAN_PER_NOTCH := 1.0
	var target: CameraSystem

	func _init() -> void:
		process_priority = 100

	func _process(delta: float) -> void:
		var t := Prof.t0()
		target.step(delta)
		Prof.add(&"camera", t)

	var _pan := 0.0   # trackpad scroll not yet spent on a zoom notch

	func _unhandled_input(event: InputEvent) -> void:
		# macOS trackpad two-finger scroll arrives as a pan gesture, not wheel buttons (a mouse wheel still
		# sends buttons): one notch per PAN_PER_NOTCH, negative delta.y = wheel up.
		var pg := event as InputEventPanGesture
		if pg != null:
			_pan += pg.delta.y
			while absf(_pan) >= PAN_PER_NOTCH:
				target.zoom_notch(1 if _pan < 0.0 else -1)
				_pan -= signf(_pan) * PAN_PER_NOTCH
			return
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target.zoom_notch(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target.zoom_notch(-1)


func _init(w: World) -> void:
	world = w
	var camera := Camera3D.new()
	camera.fov = Tuning.CAMERA_FOV
	camera.far = 500.0
	w.add_child(camera)
	camera.current = true
	w.camera = camera
	var catcher := _Driver.new()
	catcher.target = self
	camera.add_child(catcher)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam-look="):
			var xz := a.trim_prefix("--cam-look=").split(",")
			if xz.size() == 2:
				_look_override = Vector2(xz[0].to_float(), xz[1].to_float())
		if a.begins_with("--cam-zoom="):
			var f := clampf(a.trim_prefix("--cam-zoom=").to_float(), 0.0, 1.0)
			_zoom_want = lerpf(Tuning.CAMERA_DISTANCE_MIN, Tuning.CAMERA_DISTANCE_MAX, f)
			_zoom = _zoom_want


## Positive = zoom in.
func zoom_notch(dir: int) -> void:
	_zoom_want = clampf(_zoom_want * pow(Tuning.CAMERA_ZOOM_STEP, dir),
			Tuning.CAMERA_DISTANCE_MIN, Tuning.CAMERA_DISTANCE_MAX)


## World calls this early in its _process; the real work runs later, in the _Driver.
func update(_delta: float) -> void:
	pass


func step(delta: float) -> void:
	var camera := world.camera
	var target := Vector3(0, 0, 2)
	var me := world.my_chef()
	var carrying := false
	if me != null:
		target = me.global_position
		target.y = clampf(target.y, -1.0, 1.0)
		carrying = me.held_id >= 0

	# Pad shoulders zoom continuously (the wheel is handled by _Driver).
	var pad := 0.0
	if Input.is_joy_button_pressed(-1, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		pad += 1.0
	if Input.is_joy_button_pressed(-1, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		pad -= 1.0
	if pad != 0.0:
		_zoom_want = clampf(_zoom_want * exp(-pad * Tuning.CAMERA_ZOOM_PAD_RATE * delta),
				Tuning.CAMERA_DISTANCE_MIN, Tuning.CAMERA_DISTANCE_MAX)
	# Critically damped springs (not plain exponential easing): velocity starts and ends smoothly,
	# so a wheel notch or picking something up never gives the camera an instant kick.
	var d := minf(delta, 0.1)
	var sz := _damp(_zoom, _zoom_v, _zoom_want, Tuning.CAMERA_ZOOM_SMOOTH, d)
	_zoom = sz.x
	_zoom_v = sz.y
	var sc := _damp(_carry, _carry_v, 1.0 if carrying else 0.0, Tuning.CAMERA_CARRY_SMOOTH, d)
	_carry = sc.x
	_carry_v = sc.y

	var dist := _zoom * lerpf(1.0, Tuning.CAMERA_CARRY_PULLBACK, _carry)
	var far01 := clampf(inverse_lerp(Tuning.CAMERA_DISTANCE_MIN, Tuning.CAMERA_DISTANCE_MAX, _zoom), 0.0, 1.0)
	var pitch := deg_to_rad(lerpf(Tuning.CAMERA_PITCH_DEG, Tuning.CAMERA_PITCH_FAR_DEG, far01))

	# Two-stage smoothing: velocity from the (already eased) chef position, then a focus that
	# leads it. The 30 Hz snapshot steps are removed by the puppet easing plus this low-pass.
	if not _cam_ready:
		_focus = target + Vector3(0, 0, Tuning.CAMERA_FOCUS_Z)
		_prev_target = target
		_vel = Vector3.ZERO
	else:
		var raw_v := (target - _prev_target) / maxf(delta, 0.0001)
		raw_v.y = 0.0
		if raw_v.length() > 40.0:   # teleport (respawn): no look-ahead spike
			raw_v = Vector3.ZERO
		_vel = _vel.lerp(raw_v, 1.0 - exp(-4.0 * delta))
		_prev_target = target
	var lead := _vel * Tuning.CAMERA_LOOKAHEAD_SEC
	if lead.length() > Tuning.CAMERA_LOOKAHEAD_MAX:
		lead = lead.normalized() * Tuning.CAMERA_LOOKAHEAD_MAX
	var want_focus := target + lead + Vector3(0, 0, Tuning.CAMERA_FOCUS_Z)
	# Keep the void beyond the side edges of the counter from filling half the screen.
	var cb: Rect2 = world.map.get("camera_bounds", world.surface_bounds())
	var xmin := cb.position.x + Tuning.CAMERA_EDGE_MARGIN
	var xmax := maxf(xmin, cb.end.x - Tuning.CAMERA_EDGE_MARGIN)
	want_focus.x = clampf(want_focus.x, xmin, xmax)
	if _look_override != Vector2.INF:
		want_focus = Vector3(_look_override.x, 0, _look_override.y)
	if _cam_ready:
		if _focus.distance_to(want_focus) > 30.0:
			_focus = want_focus
			_focus_v = Vector3.ZERO
		else:
			var e := exp(-Tuning.CAMERA_SMOOTH * d)
			var x := _focus - want_focus
			var tmp := (_focus_v + x * Tuning.CAMERA_SMOOTH) * d
			_focus_v = (_focus_v - tmp * Tuning.CAMERA_SMOOTH) * e
			_focus = want_focus + (x + tmp) * e
	_cam_ready = me != null

	camera.global_position = _focus + Vector3(0, sin(pitch), cos(pitch)) * dist
	camera.rotation = Vector3(-pitch, 0, 0)
	if _log:
		_log_stats(camera.global_position, delta, carrying)


## --cam-log: every 2 s print the camera's peak speed and peak per-frame speed change (jitter shows
## up as speed changes far larger than the follow easing explains) plus the mean frame time.
func _log_stats(p: Vector3, delta: float, carrying: bool) -> void:
	var v := (p - _log_prev) / maxf(delta, 0.0001)
	if _log_n > 0:
		_log_maxv = maxf(_log_maxv, v.length())
		_log_maxdv = maxf(_log_maxdv, (v - _log_prev_v).length())
	_log_prev = p
	_log_prev_v = v
	_log_n += 1
	_log_t += delta
	if _log_t >= 2.0:
		print("cam-log: frames=%d peak_speed=%.2f peak_dv=%.2f carrying=%s dist=%.1f" % [_log_n, _log_maxv, _log_maxdv, carrying, _zoom])
		_log_t = 0.0
		_log_n = 0
		_log_maxv = 0.0
		_log_maxdv = 0.0


## Critically damped spring step. Returns Vector2(new value, new velocity).
static func _damp(cur: float, vel: float, goal: float, omega: float, dt: float) -> Vector2:
	var e := exp(-omega * dt)
	var x := cur - goal
	var tmp := (vel + omega * x) * dt
	return Vector2(goal + (x + tmp) * e, (vel - omega * tmp) * e)
