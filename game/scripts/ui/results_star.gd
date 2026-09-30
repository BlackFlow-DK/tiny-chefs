class_name ResultsStar
extends Control
## A chunky five-point star (filled mustard or empty paper) with an ink outline.

var filled := false:
	set(v):
		filled = v
		queue_redraw()


func _init(px := 56) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(a), sin(a)) * rr + Vector2(0, 2))
	var fill := UITheme.MUSTARD if filled else UITheme.PAPER_OFF
	var line := UITheme.INK if filled else UITheme.PAPER_OFF_INK
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, 4.0, true)
