extends Node
## Agent screenshot helper (autoload "AgentScreenshot"). Inert unless the game is
## started with user args after "--":
##   --screenshot=<abs path.png> [--frames=N] [--timeout=SECONDS]
## Waits N frames, saves the root viewport to PNG and quits.
## Exit codes: 0 saved, 1 save failed, 2 timed out.
## Driven by tools/godot-screenshot.ps1; needs a windowed run (headless cannot render).

## Also: any number of --shot=<seconds>@<abs path.png> saves a PNG that many seconds after
## start WITHOUT quitting (for captures in the middle of a longer automated run).

var _out := ""
var _frames := 60
var _timeout := 30.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_out = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--frames="):
			_frames = maxi(1, arg.trim_prefix("--frames=").to_int())
		elif arg.begins_with("--timeout="):
			_timeout = maxf(1.0, arg.trim_prefix("--timeout=").to_float())
		elif arg.begins_with("--shot="):
			var spec := arg.trim_prefix("--shot=")
			var at := spec.find("@")
			if at > 0:
				process_mode = Node.PROCESS_MODE_ALWAYS
				_timed_shot(spec.substr(0, at).to_float(), spec.substr(at + 1))
	if _out.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(_timeout, true, false, true).timeout.connect(_on_timeout)
	_capture()


func _capture() -> void:
	for i in _frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var err := img.save_png(_out)
	if err != OK:
		printerr("screenshot: save_png failed (%s): %s" % [error_string(err), _out])
		get_tree().quit(1)
		return
	print("screenshot: saved %dx%d after %d frames to %s" % [img.get_width(), img.get_height(), _frames, _out])
	get_tree().quit(0)


func _timed_shot(seconds: float, path: String) -> void:
	await get_tree().create_timer(maxf(0.1, seconds), true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("screenshot: no image for %s (headless?)" % path)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) == OK:
		print("screenshot: saved %s at %.1f s" % [path, seconds])
	else:
		printerr("screenshot: save_png failed: %s" % path)


func _on_timeout() -> void:
	printerr("screenshot: timed out after %.1f s" % _timeout)
	get_tree().quit(2)
