class_name EnvDebug
extends Node
## Agent-only review helpers for the environment, inert unless their user args are present:
##   --env-cam=x,y,z,pitch_deg,yaw_deg[,fov]   fixed review camera (overrides the follow camera)
##   --env-fps[=seconds]                        vsync off, uncapped; after a 3 s warm-up prints the
##                                              average frame time and GPU time as "env-fps: ..."

##   --env-tour=<abs dir>                       saves env-<view>.png for each preset view, then quits

## name: [look-at target, distance, pitch deg, yaw deg] (follow-camera style framing).
const TOUR := [
	["mid", Vector3(0, 0, 2), 19.0, 50.0, 0.0],
	["left-end", Vector3(-27, 0, 0), 19.0, 50.0, 0.0],
	["right-end", Vector3(27, 0, 0), 19.0, 50.0, 0.0],
	["front-edge", Vector3(0, 0, 17), 19.0, 50.0, 0.0],
	["front-left-corner", Vector3(-28, 0, 16), 19.0, 50.0, 0.0],
	["back-wall", Vector3(-4, 0, -15), 19.0, 45.0, 0.0],
	["back-right-corner", Vector3(28, 0, -15), 19.0, 45.0, 0.0],
	["overview", Vector3(0, 0, 0), 23.0, 50.0, 0.0],
	["far-overview", Vector3(0, 0, -2), 48.0, 42.0, 0.0],
	["low-back", Vector3(-4, 3, -10), 16.0, 12.0, 0.0],
]

var _cam: Camera3D
var _tour_dir := ""
var _tour_i := -1
var _tour_t := 0.0
var _fps_window := 0.0
var _t := 0.0
var _frames := 0
var _acc_gpu := 0.0
var _acc_cpu := 0.0


static func wanted() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--env-cam=") or arg.begins_with("--env-fps") or arg.begins_with("--env-tour="):
			return true
	return false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--env-cam="):
			var v := arg.trim_prefix("--env-cam=").split(",")
			if v.size() >= 5:
				_cam = Camera3D.new()
				_cam.position = Vector3(v[0].to_float(), v[1].to_float(), v[2].to_float())
				_cam.rotation = Vector3(deg_to_rad(-v[3].to_float()), deg_to_rad(v[4].to_float()), 0)
				_cam.fov = v[5].to_float() if v.size() >= 6 else Tuning.CAMERA_FOV
				_cam.far = 500.0
				add_child(_cam)
		elif arg.begins_with("--env-tour="):
			_tour_dir = arg.trim_prefix("--env-tour=")
			_cam = Camera3D.new()
			_cam.fov = Tuning.CAMERA_FOV
			_cam.far = 500.0
			add_child(_cam)
		elif arg.begins_with("--env-fps"):
			_fps_window = 6.0
			if arg.contains("="):
				_fps_window = maxf(1.0, arg.get_slice("=", 1).to_float())
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(delta: float) -> void:
	if _cam != null and not _cam.current:
		_cam.make_current()
	if _tour_dir != "":
		_tour_step(delta)
	if _fps_window <= 0.0:
		return
	_t += delta
	if _t < 3.0:
		return
	var rid := get_viewport().get_viewport_rid()
	_frames += 1
	_acc_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_acc_cpu += delta
	if _t >= 3.0 + _fps_window:
		var ms := _acc_cpu / _frames * 1000.0
		var win := DisplayServer.window_get_size()
		print("env-fps: %.1f fps avg, frame %.2f ms, gpu %.2f ms over %d frames (window %dx%d)" % [
			1000.0 / ms, ms, _acc_gpu / _frames, _frames, win.x, win.y])
		_fps_window = 0.0


func _tour_step(delta: float) -> void:
	_tour_t += delta
	var hold := 3.0 if _tour_i < 0 else 1.2
	if _tour_t < hold:
		return
	_tour_t = 0.0
	if _tour_i >= 0:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _tour_dir.path_join("env-%s.png" % TOUR[_tour_i][0])
		DirAccess.make_dir_recursive_absolute(_tour_dir)
		img.save_png(path)
		print("env-tour: saved ", path)
	_tour_i += 1
	if _tour_i >= TOUR.size():
		get_tree().quit(0)
		return
	var v: Array = TOUR[_tour_i]
	var pitch := deg_to_rad(float(v[3]))
	var yaw := deg_to_rad(float(v[4]))
	var back := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw)
	_cam.position = v[1] + back * float(v[2])
	_cam.rotation = Vector3(-pitch, yaw, 0)
