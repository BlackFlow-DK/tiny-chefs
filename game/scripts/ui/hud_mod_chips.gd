class_name HudModChips
extends HFlowContainer
## Row of small dark chips under the HUD coins card: the difficulty ("Hard", only when it is not normal)
## and every active modifier (ModifierSystem.active_ids, labels from Difficulty.label), each with a tiny
## drawn icon. Hidden when the shift has neither. Hud positions it; HudObjectives sits under it.

const ICON := 18.0

var _key := "\u0001"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 6)
	add_theme_constant_override("v_separation", 6)
	visible = false


## Rebuilds only when the set of chips changes. def = world.shift.def.
func sync(def: Dictionary) -> void:
	var ids: Array = []
	var diff := str(def.get("difficulty", "normal"))
	if diff != "normal" and Difficulty.has_preset(diff):
		ids.append(diff)
	for m in ModifierSystem.active_ids():
		ids.append(m)
	var key := ",".join(ids)
	if key == _key:
		return
	_key = key
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for id in ids:
		add_child(_chip(str(id)))
	visible = not ids.is_empty()
	if visible:
		UIKit.pop_in(self, 0.0, 0.2)


func _chip(id: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = Difficulty.desc(id)
	var sb := UITheme.box(UITheme.INK, UITheme.INK_LIGHT, 999, 3, 3, 0, Color(0, 0, 0, 0.4))
	sb.content_margin_left = 8
	sb.content_margin_right = 11
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := _Icon.new()
	ic.kind = id
	ic.custom_minimum_size = Vector2(ICON, ICON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UIKit.caption(Difficulty.label(id), "dark")
	l.add_theme_color_override("font_color", UITheme.CREAM)
	h.add_child(l)
	p.add_child(h)
	return p


## Icon shapes on an 18 px square (ink-outlined flat colours like the rest of the HUD).
class _Icon extends Control:
	var kind := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _p(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		var u := size.x / 18.0
		for v: Vector2 in pts:
			out.append(v * u)
		return out

	func _shape(pts: Array, fill: Color) -> void:
		var p := _p(pts)
		draw_colored_polygon(p, fill)
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, UITheme.INK, 1.5, true)

	func _draw() -> void:
		var u := size.x / 18.0
		var c := size * 0.5
		match kind:
			"rush_hour":   # lightning bolt
				_shape([Vector2(10, 0.5), Vector2(3, 10), Vector2(8, 10), Vector2(6.5, 17.5), Vector2(15, 7), Vector2(10, 7)], UITheme.MUSTARD)
			"heavy_hands":   # kettlebell weight
				draw_arc(Vector2(9, 5.5) * u, 4.2 * u, PI, TAU, 12, UITheme.CREAM, 2.2 * u, true)
				_shape([Vector2(3, 17), Vector2(15, 17), Vector2(16, 10), Vector2(11, 6.5), Vector2(7, 6.5), Vector2(2, 10)], UITheme.SKY)
			"slippery":   # water drop
				_shape([Vector2(9, 0.5), Vector2(14.5, 9), Vector2(14.5, 12.5), Vector2(12, 16.5), Vector2(6, 16.5), Vector2(3.5, 12.5), Vector2(3.5, 9)], UITheme.SKY)
				draw_circle(Vector2(7, 11.5) * u, 1.6 * u, UITheme.CREAM)
			"mystery_orders":   # question mark on a ticket
				_shape([Vector2(2.5, 1), Vector2(15.5, 1), Vector2(15.5, 17), Vector2(2.5, 17)], UITheme.CREAM)
				draw_string(UITheme.font(true), Vector2(0, 14.5 * u), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, int(15 * u), UITheme.INK)
			"no_shop":   # coin with a slash
				draw_circle(c, 7.2 * u, UITheme.MUSTARD)
				draw_arc(c, 7.2 * u, 0, TAU, 20, UITheme.INK, 1.5, true)
				draw_line(Vector2(3, 15) * u, Vector2(15, 3) * u, UITheme.INK, 4.0 * u, true)
				draw_line(Vector2(3, 15) * u, Vector2(15, 3) * u, UITheme.TOMATO, 2.0 * u, true)
			"lights_out":   # crescent moon
				draw_circle(c, 7.5 * u, UITheme.MUSTARD)
				draw_circle(c + Vector2(3.6, -2.6) * u, 6.3 * u, UITheme.INK)
				draw_arc(c, 7.5 * u, 0.9, 5.2, 16, UITheme.INK_LIGHT, 1.2, true)
			"easy":   # leaf
				_shape([Vector2(2, 16), Vector2(3, 7), Vector2(9, 1.5), Vector2(16, 2), Vector2(15.5, 9), Vector2(10, 15.5)], UITheme.LETTUCE)
			"hard":   # flame
				_shape([Vector2(9, 0.5), Vector2(13, 6), Vector2(15, 11), Vector2(12.5, 16.5), Vector2(5.5, 16.5), Vector2(3, 11), Vector2(6, 7.5), Vector2(7, 4)], UITheme.TOMATO)
				_shape([Vector2(9, 9), Vector2(11.5, 13), Vector2(9, 16), Vector2(6.5, 13)], UITheme.MUSTARD)
			"chaos":   # spiky burst
				var pts: Array = []
				for i in 12:
					var a := TAU * i / 12.0
					var r := 8.5 if i % 2 == 0 else 4.4
					pts.append(Vector2(9 + cos(a) * r, 9 + sin(a) * r))
				_shape(pts, UITheme.TOMATO)
				draw_circle(c, 2.0 * u, UITheme.MUSTARD)
			_:
				draw_circle(c, 6.0 * u, UITheme.SKY)
