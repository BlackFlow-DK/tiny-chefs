class_name StatsIcon
extends Control
## Small award icon for the results MVP rows: "server" (bell), "mule" (crate), "team" (two linked dots),
## "butter" (falling drop). Flat fill + ink outline, like the rest of the kit.

var kind := "server"
var fill := UITheme.MUSTARD


func _init(k := "server", px := 34, c := UITheme.MUSTARD) -> void:
	kind = k
	fill = c
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _shape(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, UITheme.INK, 2.5, true)


func _draw() -> void:
	var s := size.x
	match kind:
		"server":   # bell: dome + rim + knob
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(Vector2(s * 0.5 + cos(a) * s * 0.4, s * 0.72 + sin(a) * s * 0.5))
			_shape(dome, fill)
			_shape(PackedVector2Array([Vector2(s * 0.06, s * 0.72), Vector2(s * 0.94, s * 0.72),
				Vector2(s * 0.94, s * 0.86), Vector2(s * 0.06, s * 0.86)]), UITheme.CREAM_HI)
			draw_circle(Vector2(s * 0.5, s * 0.16), s * 0.08, UITheme.INK)
		"mule":     # crate with a strap
			_shape(PackedVector2Array([Vector2(s * 0.1, s * 0.25), Vector2(s * 0.9, s * 0.25),
				Vector2(s * 0.9, s * 0.88), Vector2(s * 0.1, s * 0.88)]), fill)
			draw_line(Vector2(s * 0.1, s * 0.5), Vector2(s * 0.9, s * 0.5), UITheme.INK, 2.5)
			draw_line(Vector2(s * 0.3, s * 0.25), Vector2(s * 0.3, s * 0.08), UITheme.INK, 2.5)
			draw_line(Vector2(s * 0.7, s * 0.25), Vector2(s * 0.7, s * 0.08), UITheme.INK, 2.5)
			draw_line(Vector2(s * 0.3, s * 0.08), Vector2(s * 0.7, s * 0.08), UITheme.INK, 2.5)
		"team":     # two dots joined by a bar
			draw_line(Vector2(s * 0.25, s * 0.5), Vector2(s * 0.75, s * 0.5), UITheme.INK, 9.0)
			draw_line(Vector2(s * 0.25, s * 0.5), Vector2(s * 0.75, s * 0.5), fill, 4.0)
			for x in [0.25, 0.75]:
				draw_circle(Vector2(s * x, s * 0.5), s * 0.22, UITheme.INK)
				draw_circle(Vector2(s * x, s * 0.5), s * 0.16, fill)
		_:          # butter: a drop that is slipping away
			draw_circle(Vector2(s * 0.5, s * 0.66), s * 0.3, UITheme.INK)
			_shape(PackedVector2Array([Vector2(s * 0.5, s * 0.04), Vector2(s * 0.8, s * 0.6), Vector2(s * 0.2, s * 0.6)]), fill)
			draw_circle(Vector2(s * 0.5, s * 0.66), s * 0.24, fill)
