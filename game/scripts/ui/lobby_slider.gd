class_name LobbySlider
extends Control
## Chunky lobby slider (the stock HSlider can't take the design-system look). Mouse drag or left/right keys
## (gamepad d-pad). Emits `value_changed(v)` on every change made by the player; `set_value_silent` does not.

signal value_changed(v: float)

var min_value := 0.0
var max_value := 100.0
var step := 1.0
var key_step := 1.0
var value := 0.0
var editable := true
var dragging := false

const TRACK_H := 16.0
const KNOB_R := 15.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func setup(lo: float, hi: float, st: float, key_st := -1.0) -> void:
	min_value = lo
	max_value = hi
	step = st
	key_step = st if key_st < 0.0 else key_st
	value = clampf(value, lo, hi)
	queue_redraw()


func set_value_silent(v: float) -> void:
	value = _snap(v)
	queue_redraw()


func set_editable(on: bool) -> void:
	editable = on
	focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	queue_redraw()


func fraction() -> float:
	return 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)


func _snap(v: float) -> float:
	var s := snappedf(v - min_value, step) + min_value
	return clampf(s, min_value, max_value)


func _change(v: float) -> void:
	var n := _snap(v)
	if is_equal_approx(n, value):
		return
	value = n
	queue_redraw()
	value_changed.emit(value)


func _from_x(x: float) -> float:
	var f := clampf((x - KNOB_R) / maxf(size.x - KNOB_R * 2.0, 1.0), 0.0, 1.0)
	return min_value + f * (max_value - min_value)


func _gui_input(event: InputEvent) -> void:
	if not editable:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dragging = (event as InputEventMouseButton).pressed
		if dragging:
			grab_focus()
			_change(_from_x((event as InputEventMouseButton).position.x))
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_change(_from_x((event as InputEventMouseMotion).position.x))
		accept_event()
	elif event.is_action_pressed("ui_left", true):
		_change(value - key_step)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		_change(value + key_step)
		accept_event()


func _draw() -> void:
	var cy := size.y / 2.0
	var track := Rect2(KNOB_R, cy - TRACK_H / 2.0, maxf(size.x - KNOB_R * 2.0, 1.0), TRACK_H)
	var bg := UITheme.box(Color("#3E3349"), UITheme.INK, 999, 3)
	draw_style_box(bg, track)
	var fw := track.size.x * fraction()
	if fw > 1.0:
		var fill := UITheme.box(UITheme.MUSTARD if editable else UITheme.PAPER_OFF_INK, UITheme.INK, 999, 3)
		draw_style_box(fill, Rect2(track.position, Vector2(maxf(fw, TRACK_H), TRACK_H)))
	var kx := KNOB_R + (size.x - KNOB_R * 2.0) * fraction()
	draw_circle(Vector2(kx, cy + 3), KNOB_R, UITheme.INK)
	draw_circle(Vector2(kx, cy), KNOB_R, UITheme.INK)
	draw_circle(Vector2(kx, cy), KNOB_R - 3.5, UITheme.CREAM if not dragging else UITheme.CREAM_DIM)
	if has_focus():
		draw_arc(Vector2(kx, cy), KNOB_R + 5, 0.0, TAU, 40, UITheme.SKY, 4.0, true)
