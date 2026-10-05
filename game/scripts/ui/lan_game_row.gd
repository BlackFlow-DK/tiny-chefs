class_name LanGameRow
extends Button
## One game in the join page's LAN list: map picture, "<host>'s kitchen", map + mode, "2/4" and a state chip.
## The whole row is the join button. set_game(g) updates it in place (g = a Net.discovery game).
## States: "lobby" (joinable, chip "In the lobby"), "cooking" (shift running, joinable: late joiners get a
## chef at once, chip "Cooking now"), "full" and "version" (dimmed, not clickable).

signal join_requested(game: Dictionary)

const ROW_H := 62
const THUMB := Vector2(72, 36)   # map pictures are 2:1

var game: Dictionary = {}
var state := ""
var _locked := false   # the menu is busy connecting: every row waits
var _dim: Array[Control] = []
var _thumb_host: Control
var _thumb_map := "?"
var _name: Label
var _sub: Label
var _count: Label
var _chip: PanelContainer
var _chip_label: Label
var _chip_styles: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(0, ROW_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styles()
	UIKit.attach_press_squash(self)
	pressed.connect(func() -> void:
		if is_joinable():
			join_requested.emit(game.duplicate()))

	var body := MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 6)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(body)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", UITheme.GAP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(h)
	_thumb_host = Control.new()
	_thumb_host.custom_minimum_size = THUMB
	_thumb_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_thumb_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_thumb_host)

	# Two lines: "<host>'s kitchen" + players on top, map + mode + state chip below.
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(top)
	_name = UIKit.body("")
	_name.add_theme_font_override("font", UITheme.font(true))
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size = Vector2(1, 0)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	_count = UIKit.number("0/4")
	_count.add_theme_font_size_override("font_size", UITheme.S_BODY)
	top.add_child(_count)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(bottom)
	_sub = UIKit.caption("")
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.custom_minimum_size = Vector2(1, 0)
	_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_sub)
	_chip = PanelContainer.new()
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_label = UIKit.caption("")
	_chip_label.add_theme_font_override("font", UITheme.font(true))
	_chip_label.add_theme_color_override("font_color", UITheme.INK)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chip.add_child(_chip_label)
	bottom.add_child(_chip)
	# Everything but the chip dims on rows you cannot join; the chip stays readable.
	_dim = [_thumb_host, _name, _count, _sub]
	for k: String in ["lobby", "cooking", "full", "version"]:
		var fill: Color = {"lobby": UITheme.LETTUCE.lightened(0.45), "cooking": UITheme.MUSTARD,
			"full": UITheme.CREAM_DIM, "version": UITheme.CREAM_DIM}[k]
		var sb := UITheme.box(fill, UITheme.INK, 999, 2, 2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		_chip_styles[k] = sb


## Show this game (same host: only the changed bits move). g: {address, port, name, players, max_players,
## map, mode, state, version, compatible, ...}.
func set_game(g: Dictionary) -> void:
	game = g.duplicate()
	var players := int(g.get("players", 0))
	var max_players := maxi(1, int(g.get("max_players", 4)))
	var st := "lobby"
	if not bool(g.get("compatible", false)):
		st = "version"
	elif players >= max_players:
		st = "full"
	elif str(g.get("state", "lobby")) == "playing":
		st = "cooking"
	state = st

	var map_id := str(g.get("map", ""))
	if not GameData.MAPS.has(map_id):
		map_id = ""   # an unknown map (other version): flat picture, never a path built from network text
	if map_id != _thumb_map:
		_thumb_map = map_id
		for c in _thumb_host.get_children():
			c.queue_free()
		var icon := LobbyIcon.new("map", THUMB, map_id)
		icon.cycle_every = 1.0e9   # the first picture only: a list should sit still
		_thumb_host.add_child(icon)

	_name.text = "%s's kitchen" % str(g.get("name", "Chef"))
	var parts: PackedStringArray = []
	parts.append(str(GameData.MAPS[map_id]["name"]) if map_id != "" else str(g.get("map", "")).capitalize())
	var mode := str(g.get("mode", ""))
	if GameSettings.MODES.has(mode):
		parts.append(mode.capitalize())
	_sub.text = " · ".join(parts)
	_count.text = "%d/%d" % [players, max_players]
	_chip_label.text = {"lobby": "In the lobby", "cooking": "Cooking now", "full": "Full",
		"version": "Needs v%s" % str(g.get("version", "?"))}[st]
	_chip.add_theme_stylebox_override("panel", _chip_styles[st])
	tooltip_text = "%s:%d" % [str(g.get("address", "")), int(g.get("port", 0))]
	_refresh()


func is_joinable() -> bool:
	return (state == "lobby" or state == "cooking") and not _locked


## Busy connecting: rows stay put but cannot be clicked.
func set_locked(on: bool) -> void:
	_locked = on
	_refresh()


func _refresh() -> void:
	var open := state == "lobby" or state == "cooking"
	disabled = not is_joinable()
	focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
	for c in _dim:
		c.modulate = Color(1, 1, 1, 1.0 if open else 0.5)
	_chip.modulate = Color(1, 1, 1, 1.0 if open else 0.8)


func _apply_styles() -> void:
	var idle := UITheme.box(UITheme.CREAM, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 4)
	var hover := UITheme.box(UITheme.CREAM_HI, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 7, 3)
	var down := UITheme.box(UITheme.CREAM_DIM, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 0, -3)
	var off := UITheme.box(UITheme.CREAM, UITheme.PAPER_OFF_INK, UITheme.R_BTN, UITheme.B_BTN, 0)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UITheme.SKY
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(UITheme.R_BTN + 4)
	focus.set_expand_margin_all(6)
	focus.anti_aliasing = true
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
	add_theme_stylebox_override("disabled", off)
	add_theme_stylebox_override("focus", focus)
