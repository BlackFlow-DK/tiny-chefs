class_name SettingsView
extends Control
## Graphics settings card (title screen "Settings" button and the pause menu). Every change is saved to
## user://settings.cfg (Quality) and applied live (QualityApply.apply_all), except the lightweight
## renderer, which needs a restart ("Restart now" on the title screen). Esc or Done closes it.

const ROW_H := 46

var _card: PanelContainer
var _done: Button
var _quality: Dictionary = {}     # choice id -> LobbyChoice
var _desc: Label
var _scale: LobbySlider
var _scale_lbl: Label
var _caps: Dictionary = {}        # fps cap -> LobbyChoice
var _fullscreen: LobbyChoice
var _vsync: LobbyChoice
var _show_fps: LobbyChoice
var _light: LobbyChoice
var _light_note: Label
var _restart: Button


func _init() -> void:
	UI.full_rect(self)
	visible = false
	add_child(UIKit.backdrop(0.7))
	var cv := UIKit.card(10)
	_card = cv[0]
	var v: VBoxContainer = cv[1]
	_card.custom_minimum_size = Vector2(760, 0)
	v.add_child(UIKit.title("Settings"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	# Quality preset + its one-line description.
	var qrow := _row()
	for id in Quality.CHOICES:
		var b := _choice(Quality.preset_name(id) if id != "auto" else "Auto")
		b.pressed.connect(_on_quality.bind(id))
		qrow.add_child(b)
		_quality[id] = b
	_add(grid, "Quality", qrow)
	_desc = UIKit.caption("")
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(1, 0)
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(grid, "", _desc)

	# Render scale 50..100 %.
	var srow := _row()
	_scale = LobbySlider.new()
	_scale.setup(50.0, 100.0, 5.0)
	_scale.value_changed.connect(_on_scale)
	srow.add_child(_scale)
	_scale_lbl = UIKit.body("100%")
	_scale_lbl.custom_minimum_size = Vector2(64, 0)
	_scale_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	srow.add_child(_scale_lbl)
	_add(grid, "Resolution", srow)

	# Frame cap.
	var crow := _row()
	for cap in Quality.FPS_CAPS:
		var b := _choice("Uncapped" if cap == 0 else "%d fps" % cap)
		b.pressed.connect(_on_cap.bind(cap))
		crow.add_child(b)
		_caps[cap] = b
	_add(grid, "Frame cap", crow)

	# Display toggles.
	var drow := _row()
	_fullscreen = _toggle("Fullscreen", "fullscreen")
	drow.add_child(_fullscreen)
	_vsync = _toggle("VSync", "vsync")
	drow.add_child(_vsync)
	_show_fps = _toggle("Show FPS", "show_fps")
	drow.add_child(_show_fps)
	_add(grid, "Display", drow)

	# Lightweight renderer (restart).
	var lrow := _row()
	_light = _choice("Lightweight renderer")
	_light.pressed.connect(_on_light)
	lrow.add_child(_light)
	_restart = UIKit.button("Restart now", _on_restart, "accent", 0)
	_restart.custom_minimum_size = Vector2(0, ROW_H)
	lrow.add_child(_restart)
	_add(grid, "Renderer", lrow)
	_light_note = UIKit.caption("")
	_light_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_light_note.custom_minimum_size = Vector2(1, 0)
	_light_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(grid, "", _light_note)

	_done = UIKit.button("Done", close, "primary", 0)
	v.add_child(_done)
	add_child(UI.centred(_card))


func open() -> void:
	visible = true
	_refresh()
	UIKit.pop_in(_card, 0.0, 0.16)
	_done.grab_focus.call_deferred()


func close() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- building blocks

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


func _add(grid: GridContainer, label: String, control: Control) -> void:
	var l := UIKit.body(label)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	grid.add_child(control)


func _choice(text: String) -> LobbyChoice:
	var b := LobbyChoice.new(Vector2(0, ROW_H))
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _toggle(text: String, key: String) -> LobbyChoice:
	var b := _choice(text)
	b.pressed.connect(func() -> void:
		Quality.set_value(key, not bool(Quality.get_value(key)))
		_apply())
	return b


# ---------------------------------------------------------------- state

func _refresh() -> void:
	var c := Quality.choice()
	for id in _quality:
		(_quality[id] as LobbyChoice).select(id == c)
	var lvl := Quality.active_preset()
	var p: Dictionary = Quality.PRESETS[lvl]
	if c == "auto":
		_desc.text = "Auto picked %s for %s. %s" % [p["name"], _short_gpu(), p["desc"]]
	else:
		_desc.text = str(p["desc"])
	var pct := roundi(Quality.render_scale() * 100.0)
	_scale.set_value_silent(pct)
	_scale_lbl.text = "%d%%" % pct
	var cap := int(Quality.get_value("fps_cap"))
	for k in _caps:
		(_caps[k] as LobbyChoice).select(k == cap)
	_fullscreen.select(bool(Quality.get_value("fullscreen")))
	_vsync.select(bool(Quality.get_value("vsync")))
	_show_fps.select(bool(Quality.get_value("show_fps")))
	var want := bool(Quality.get_value("lightweight"))
	_light.select(want)
	var differs := want != Quality.is_mobile_renderer()
	var in_menu := Net.phase == Net.Phase.MENU
	_restart.visible = differs and in_menu
	if differs:
		_light_note.text = "Restart to switch renderer." if in_menu else "Switches renderer the next time the game starts."
	elif want:
		_light_note.text = "On: simpler lighting that runs better on built-in graphics."
	else:
		_light_note.text = "Simpler lighting for built-in graphics (restarts the game)."


func _short_gpu() -> String:
	var n := Quality.adapter_name()
	return n if n.length() <= 34 else n.substr(0, 32) + "..."


func _apply() -> void:
	QualityApply.apply_all(get_tree())
	_refresh()


func _on_quality(id: String) -> void:
	Quality.set_value("quality", id)
	Quality.set_value("render_scale", -1.0)   # a new preset brings its own resolution
	_apply()


func _on_scale(v: float) -> void:
	Quality.set_value("render_scale", v / 100.0)
	_scale_lbl.text = "%d%%" % roundi(v)
	QualityApply.display(get_tree())


func _on_cap(cap: int) -> void:
	Quality.set_value("fps_cap", cap)
	_apply()


func _on_light() -> void:
	Quality.set_value("lightweight", not bool(Quality.get_value("lightweight")))
	_refresh()


func _on_restart() -> void:
	if Quality.relaunch("mobile" if bool(Quality.get_value("lightweight")) else "forward_plus"):
		get_tree().quit()
