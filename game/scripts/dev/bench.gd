class_name Bench
extends Node
## GPU/CPU benchmark (Main adds it with `--bench`). Run it as a solo bot host, e.g.
##   -- --host --autostart --bot --mode=endless --map=diner --port=7971 --bench=low [--bench-stress]
## (tools/bench.ps1 does this for every preset x map). Sizes the window to 1920x1080, turns vsync and the
## frame cap off, waits for the shift to start plus a warm-up, then records every frame for
## --bench-seconds (20): frame time (wall clock between frames), GPU and CPU render time of the main
## viewport (RenderingServer.viewport_get_measured_render_time_*), draw calls / objects / primitives.
## Prints one line `bench: {json}` and quits. --bench-stress doubles the 3D render scale (capped at 2.0)
## to amplify fill-rate cost, standing in for a weak GPU.

const SIZE := Vector2i(1920, 1080)

var _seconds := 20.0
var _warmup := 4.0
var _state := 0            # 0 waiting for the shift, 1 warm-up, 2 measuring
var _t := 0.0
var _last_us := 0
var _frame := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _cpu := PackedFloat32Array()
var _draws := PackedFloat32Array()
var _objs := PackedFloat32Array()
var _prims := PackedFloat32Array()
var _scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_seconds = Net.arg_float("bench-seconds", 20.0)
	_warmup = Net.arg_float("bench-warmup", 4.0)
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	win.size = SIZE
	win.position = Vector2i.ZERO
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if Net.has_arg("bench-stress"):
		_stress.call_deferred()


## After Main applied the quality preset: double whatever render scale it chose.
func _stress() -> void:
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = minf(vp.scaling_3d_scale * 2.0, 2.0)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt_ms := (now - _last_us) / 1000.0
	_last_us = now
	match _state:
		0:
			if Net.phase == Net.Phase.PLAYING and Net.world != null:
				_state = 1
				_t = 0.0
		1:
			_t += delta
			if _t >= _warmup:
				_state = 2
				_t = 0.0
				_scale = get_viewport().scaling_3d_scale
		2:
			_t += delta
			var rid := get_viewport().get_viewport_rid()
			_frame.append(dt_ms)
			_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
			_draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			_objs.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
			_prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			if _t >= _seconds:
				_report()
				_state = 3


func _report() -> void:
	var vp := get_viewport()
	var d := {
		"bench": Net.arg_str("bench", "?"),
		"preset": Quality.active_preset(),
		"map": str(Net.world.map.get("id", "?")) if Net.world != null else "?",
		"stress": Net.has_arg("bench-stress"),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": "%dx%d" % [get_window().size.x, get_window().size.y],
		"msaa": vp.msaa_3d,
		"fxaa": vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,
		"render_scale": snappedf(_scale, 0.01),
		"frames": _frame.size(),
		"fps": snappedf(1000.0 / maxf(_mean(_frame), 0.001), 0.1),
		"avg_ms": snappedf(_mean(_frame), 0.01),
		"low1_ms": snappedf(_worst1(_frame), 0.01),
		"gpu_ms": snappedf(_mean(_gpu), 0.01),
		"gpu_low1_ms": snappedf(_worst1(_gpu), 0.01),
		"cpu_render_ms": snappedf(_mean(_cpu), 0.01),
		"draw_calls": roundi(_mean(_draws)),
		"objects": roundi(_mean(_objs)),
		"primitives_k": roundi(_mean(_prims) / 1000.0),
	}
	print("bench: " + JSON.stringify(d))
	Net.finish_test()


static func _mean(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


## Mean of the slowest 1% (the "1% low", as a frame time).
static func _worst1(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	var n := maxi(1, int(ceil(s.size() * 0.01)))
	var sum := 0.0
	for i in n:
		sum += s[s.size() - 1 - i]
	return sum / n
