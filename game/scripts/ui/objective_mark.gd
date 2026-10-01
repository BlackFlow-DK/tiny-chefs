class_name ObjectiveMark
extends Control
## Objective status disc: hollow ring (in progress), lettuce disc with a tick (met), tomato disc with a cross (failed).

var state := 0:
	set(v):
		state = v
		queue_redraw()


func _init(px := 22.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.5 - 1.5
	var w := maxf(2.5, r * 0.28)
	match state:
		ObjectiveSystem.MET:
			draw_circle(c, r, UITheme.LETTUCE)
			draw_arc(c, r, 0.0, TAU, 32, UITheme.INK, 2.5, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.45, 0.02) * r, c + Vector2(-0.12, 0.36) * r,
				c + Vector2(0.48, -0.34) * r]), UITheme.CREAM, w, true)
		ObjectiveSystem.FAILED:
			draw_circle(c, r, UITheme.TOMATO)
			draw_arc(c, r, 0.0, TAU, 32, UITheme.INK, 2.5, true)
			var k := r * 0.36
			draw_line(c + Vector2(-k, -k), c + Vector2(k, k), UITheme.CREAM, w, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), UITheme.CREAM, w, true)
		_:
			draw_circle(c, r, UITheme.CREAM_HI)
			draw_arc(c, r - 1.0, 0.0, TAU, 32, UITheme.INK_SOFT, 3.0, true)
