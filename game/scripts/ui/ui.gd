class_name UI
extends RefCounted
## Tiny helpers for building plain, readable UI in code.

const YELLOW := UITheme.MUSTARD
const GREEN := UITheme.LETTUCE
const RED := UITheme.TOMATO
const DIM := UITheme.CREAM_DIM


## The one Theme for the whole game (see UITheme / UIKit and docs/ui-style.md).
static func theme() -> Theme:
	return UITheme.build()


## Legacy label. Default/DIM text becomes ink with a cream halo (readable on cards AND over the
## world); coloured text gets an ink outline. New code should use UIKit.title/heading/body/caption.
static func label(text: String, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	var halo := UITheme.INK
	if color == Color.WHITE:
		color = UITheme.INK
		halo = UITheme.CREAM
	elif color == DIM:
		color = UITheme.INK_SOFT
		halo = UITheme.CREAM
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", halo)
	l.add_theme_constant_override("outline_size", 8 if size >= 40 else (6 if size >= 20 else 4))
	return l


static func button(text: String, cb: Callable, min_width := 220) -> Button:
	return UIKit.button(text, cb, "primary", min_width)


static func panel(sep := 10) -> Array:
	return UIKit.card(sep)


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
	p.add_theme_stylebox_override("panel", UITheme.box(color, UITheme.INK, px / 2 if round_shape else 5, 2))
	return p


static func time_text(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


static func controls_text() -> String:
	return "\n".join([
		"WASD: move",
		"Left click: grab or let go (grab together for heavy food!)",
		"Right click (hold): work: dispense, chop, ring the bell",
		"Space: punch (needs Boxing Gloves)",
		"Esc: pause menu     H: hide the help",
	])
