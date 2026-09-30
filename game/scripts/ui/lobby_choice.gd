class_name LobbyChoice
extends Button
## Lobby pick button: a toggle with the design-system look (cream paper; mustard and sunk when picked).
## Optional content (icon + labels, a card body) is added as children and laid out with margins.
## The owner keeps the selection: set it with `select(bool)`; a click only emits `pressed`.

var selected_color := UITheme.MUSTARD
var _subs: Array = []  # [Label, selected tone, idle tone]
var _body: MarginContainer = null


func _init(min_size := Vector2(0, 52), fill_color := UITheme.MUSTARD) -> void:
	selected_color = fill_color
	custom_minimum_size = min_size
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_styles()
	UIKit.attach_press_squash(self)


## Put `content` inside the button with `margin` px around it. Content must ignore the mouse.
func set_body(content: Control, margin := 12) -> void:
	if _body != null:
		_body.queue_free()
	_body = MarginContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, margin)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	_body.add_child(content)
	_ignore_mouse(content)


## A label that turns ink when the button is picked (muted tones lose contrast on mustard).
func track_label(l: Label, idle: Color) -> void:
	_subs.append([l, UITheme.INK, idle])
	l.add_theme_color_override("font_color", idle)


func select(on: bool) -> void:
	set_pressed_no_signal(on)
	for s in _subs:
		(s[0] as Label).add_theme_color_override("font_color", s[1] if on else s[2])


## Read-only: no hover, no focus, clicks fall through (so the scroll wheel still works).
func set_editable(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _apply_styles() -> void:
	var idle := UITheme.box(UITheme.CREAM_HI, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 4)
	var hover := UITheme.box(UITheme.CREAM, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 7, 3)
	var on := UITheme.box(selected_color, UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 0, -3)
	var on_hover := UITheme.box(selected_color.lightened(0.12), UITheme.INK, UITheme.R_BTN, UITheme.B_BTN, 0, -3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UITheme.SKY
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(UITheme.R_BTN + 4)
	focus.set_expand_margin_all(6)
	focus.anti_aliasing = true
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", on)
	add_theme_stylebox_override("hover_pressed", on_hover)
	add_theme_stylebox_override("disabled", idle)
	add_theme_stylebox_override("focus", focus)
	add_theme_font_override("font", UITheme.font(true))
	add_theme_font_size_override("font_size", UITheme.S_BODY)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(c, UITheme.INK)


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
