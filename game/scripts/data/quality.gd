class_name Quality
extends RefCounted
## Graphics quality: the presets (data), the player's display settings (user://settings.cfg) and the
## Auto rule. QualityApply turns a preset into renderer state; SettingsView edits the settings.
## Args: --quality=auto|low|medium|high overrides the saved preset for this run (not saved).
## docs/performance.md has the numbers behind each preset.

const CFG_PATH := "user://settings.cfg"
const CHOICES := ["auto", "low", "medium", "high"]
const LEVELS := ["low", "medium", "high"]   # step-down order is right to left
const FPS_CAPS := [60, 120, 0]              # 0 = uncapped
const PROBE_MIN_FPS := 50.0

## One entry per level. High is the look the game was tuned with (nothing is touched).
## ssao_quality: RenderingServer.EnvironmentSSAOQuality; -1 keeps the project setting.
## msaa: Viewport.MSAA (-1 keeps the project setting, 4x). shadow_splits: directional cascades (1, 2 or 4; 0 = shadows off). shadow_size: directional atlas px.
## (Low keeps one hard cascade: a shadowless Low with blob shadows under the chefs was tried; stations and
## food looked like they float, for ~0.4 ms saved under stress. See docs/performance.md.)
## grass: fraction of picnic grass blades drawn. life: "full" | "cheap" (picnic bee/ants/leaves at 30 Hz,
## no drifting leaves). diorama_*: the menu/lobby backdrop.
const PRESETS := {
	"low": {
		"name": "Low", "desc": "For laptops with built-in graphics. Simple light and shadows, 75% resolution.",
		"ssao": false, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "ssil": false, "glow": false, "dof": false,
		"shadow_splits": 1, "shadow_size": 1024, "shadow_soft": false,
		"render_scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "lod_threshold": 2.0,
		"particles": 0.5, "grass": 0.35, "life": "cheap",
		"diorama_scale": 0.5, "diorama_fps": 30, "diorama_dof": false,
	},
	"medium": {
		"name": "Medium", "desc": "For gaming laptops. Soft shadows and glow, lighter shading.",
		"ssao": true, "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssil": false, "glow": true, "dof": false,
		"shadow_splits": 2, "shadow_size": 2048, "shadow_soft": true,
		"render_scale": 1.0, "msaa": Viewport.MSAA_2X, "fxaa": false, "lod_threshold": 1.0,
		"particles": 1.0, "grass": 0.7, "life": "full",
		"diorama_scale": 1.0, "diorama_fps": 0, "diorama_dof": true,
	},
	"high": {
		"name": "High", "desc": "The full look: soft shadows, ambient light, glow and depth blur.",
		"ssao": true, "ssao_quality": -1, "ssil": true, "glow": true, "dof": true,
		"shadow_splits": 4, "shadow_size": -1, "shadow_soft": true,
		"render_scale": 1.0, "msaa": -1, "fxaa": false, "lod_threshold": 1.0,
		"particles": 1.0, "grass": 1.0, "life": "full",
		"diorama_scale": 1.0, "diorama_fps": 0, "diorama_dof": true,
	},
}

const DEFAULTS := {
	"quality": "auto",       # CHOICES
	"render_scale": -1.0,    # 0.5..1.0; -1 = the preset's own
	"vsync": true,
	"fps_cap": 0,            # FPS_CAPS
	"fullscreen": false,
	"show_fps": false,
	"lightweight": false,    # relaunch with --rendering-method mobile
	"auto_level": "",        # what Auto settled on (detect + probe), saved after the first launch
	"auto_adapter": "",      # the adapter that was probed (a new GPU re-runs Auto)
}

static var settings: Dictionary = {}
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	settings = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) == OK:
		for k in DEFAULTS:
			settings[k] = cf.get_value("graphics", k, DEFAULTS[k])
	if not CHOICES.has(str(settings.quality)):
		settings.quality = "auto"
	if not FPS_CAPS.has(int(settings.fps_cap)):
		settings.fps_cap = 0


static func save() -> void:
	if is_test_run():
		return   # automated runs never touch the player's file
	var cf := ConfigFile.new()
	cf.load(CFG_PATH)
	for k in DEFAULTS:
		cf.set_value("graphics", k, settings[k])
	cf.save(CFG_PATH)


static func get_value(key: String) -> Variant:
	load_settings()
	return settings.get(key, DEFAULTS.get(key))


static func set_value(key: String, v: Variant) -> void:
	load_settings()
	settings[key] = v
	save()


## The saved choice ("auto" | level), or --quality=<x> when given.
static func choice() -> String:
	load_settings()
	var arg := _arg("quality")
	if CHOICES.has(arg):
		return arg
	return str(settings.quality)


## The level in use right now ("low" | "medium" | "high").
static func active_preset() -> String:
	var c := choice()
	if c != "auto":
		return c
	var saved := str(settings.get("auto_level", ""))
	if LEVELS.has(saved) and str(settings.get("auto_adapter", "")) == adapter_name():
		return saved
	return detect()


## The active level's preset. Agent A/B switch: --quality-set=key:value,... overrides single entries
## (e.g. --quality-set=shadow_splits:0,ssao:true).
static func preset() -> Dictionary:
	var p: Dictionary = PRESETS[active_preset()]
	var over := _arg("quality-set")
	if over == "":
		return p
	p = p.duplicate()
	for kv in over.split(",", false):
		var pair := kv.split(":")
		if pair.size() == 2 and p.has(pair[0]):
			var v: Variant = pair[1]
			if pair[1] == "true" or pair[1] == "false":
				v = pair[1] == "true"
			elif pair[1].is_valid_float():
				v = pair[1].to_float() if pair[1].contains(".") else pair[1].to_int()
			p[pair[0]] = v
	return p


static func preset_name(level: String) -> String:
	return str(PRESETS[level]["name"]) if PRESETS.has(level) else "Auto"


## Picks a preset from the GPU. Integrated / software GPUs -> low; laptop discrete GPUs -> medium; else high.
static func detect() -> String:
	return detect_for(adapter_name(), RenderingServer.get_video_adapter_type())


static func detect_for(adapter: String, type: int) -> String:
	var n := adapter.to_lower()
	if type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or type == RenderingDevice.DEVICE_TYPE_CPU:
		return "low"
	for soft in ["llvmpipe", "swiftshader", "basic render", "microsoft basic"]:
		if n.contains(soft):
			return "low"
	# Integrated by name (the compatibility renderer reports no device type): Intel HD/UHD/Iris, AMD APU
	# "Radeon(TM) Graphics" / "Vega N" without a discrete RX/R9/Pro model number.
	if n.contains("intel") and not n.contains("arc"):
		return "low"
	if (n.contains("amd") or n.contains("radeon")) and not RegEx.create_from_string("\\b(rx|r9|r7|pro|vii)\\b").search(n):
		if n.contains("graphics") or n.contains("vega"):
			return "low"
	if RegEx.create_from_string("(laptop|max-q|mobile|\\bmx\\s?\\d|\\brx\\s?\\d{3,4}m\\b)").search(n):
		return "medium"
	return "high"


static func adapter_name() -> String:
	return RenderingServer.get_video_adapter_name()


## Auto runs a frame-time probe once per GPU (first launch, or a new adapter).
static func needs_probe() -> bool:
	if choice() != "auto" or is_test_run():
		return false
	return not LEVELS.has(str(settings.get("auto_level", ""))) or str(settings.get("auto_adapter", "")) != adapter_name()


## The probe's verdict: avg fps over 2 s at the detected level. Under PROBE_MIN_FPS steps down one level.
static func finish_probe(fps: float) -> String:
	var lvl := detect()
	if fps < PROBE_MIN_FPS:
		lvl = LEVELS[maxi(0, LEVELS.find(lvl) - 1)]
	settings.auto_level = lvl
	settings.auto_adapter = adapter_name()
	save()
	print("quality: auto probe %.1f fps on '%s' -> %s" % [fps, adapter_name(), lvl])
	return lvl


## Render scale in use: the slider when set, else the preset's own.
static func render_scale() -> float:
	var s := float(get_value("render_scale"))
	if _arg("render-scale") != "":
		s = _arg("render-scale").to_float()
	if s <= 0.0:
		return float(preset()["render_scale"])
	return clampf(s, 0.5, 1.0)


static func is_mobile_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "mobile"


## Lightweight renderer saved on: relaunch this executable with --rendering-method mobile when the game runs on
## the project's own renderer (anything else means the command line chose one, or Godot fell back to
## Compatibility: leave it). Turning it off needs no relaunch: a normal start is Forward+. Returns true when a new
## process was started (the caller quits). Never in automated runs, never twice in a row (--relaunched).
static func relaunch_if_needed() -> bool:
	if is_test_run() or _arg("relaunched") != "" or not bool(get_value("lightweight")):
		return false
	if RenderingServer.get_current_rendering_method() != str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")):
		return false
	return relaunch("mobile")


## Engine args Godot consumed (--path, --windowed ...) are not in OS.get_cmdline_args(); an exported game needs
## none (the pack is embedded), an editor-binary run gets --path back.
static func relaunch(method: String) -> bool:
	var a := PackedStringArray()
	if not OS.has_feature("template"):
		a.append_array(["--path", ProjectSettings.globalize_path("res://")])
	var cmd := OS.get_cmdline_args()
	var i := 0
	while i < cmd.size():
		if cmd[i] == "--rendering-method":
			i += 2
			continue
		a.append(cmd[i])
		i += 1
	a.append_array(["--rendering-method", method, "--"])
	for u in OS.get_cmdline_user_args():
		if u != "--relaunched":
			a.append(u)
	a.append("--relaunched")
	var pid := OS.create_process(OS.get_executable_path(), a)
	print("quality: relaunch with %s -> pid %d" % [method, pid])
	return pid > 0


static func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + key:
			return "true"
		if a.begins_with("--" + key + "="):
			return a.trim_prefix("--" + key + "=")
	return ""


## Agent/bot/bench runs: keep the player's settings file untouched and skip the probe/relaunch.
static func is_test_run() -> bool:
	for k in ["bot", "bench", "profile", "quality", "screenshot", "test-report", "autostart"]:
		if _arg(k) != "":
			return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			return true
	return false
