class_name UI
extends RefCounted
## Tiny helpers for building plain, readable UI in code.

const YELLOW := Color(1.0, 0.85, 0.3)
const GREEN := Color(0.45, 0.95, 0.45)
const RED := Color(1.0, 0.45, 0.4)
const DIM := Color(0.8, 0.82, 0.88)


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.13, 0.88)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(14)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2)
	t.set_stylebox("panel", "PanelContainer", sb)
	return t


static func label(text: String, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5 if size >= 20 else 3)
	return l


static func button(text: String, cb: Callable, min_width := 220) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 42)
	b.pressed.connect(cb)
	return b


static func panel(sep := 10) -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	p.add_child(v)
	return [p, v]


## A full-rect Control that centres one child.
static func centred(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func swatch(color: Color, round_shape: bool, px := 20) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(px / 2 if round_shape else 3)
	sb.border_color = Color(0, 0, 0, 0.6)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func time_text(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


static func controls_text() -> String:
	return "\n".join([
		"WASD / arrows / left stick: move",
		"E / Space / pad A: grab or let go (grab together for heavy food!)",
		"F / left mouse / pad X (hold): work: dispense, chop, ring the bell",
		"Q / right mouse / pad B: punch (needs Boxing Gloves)",
		"Esc: pause menu     H: hide this help",
	])
