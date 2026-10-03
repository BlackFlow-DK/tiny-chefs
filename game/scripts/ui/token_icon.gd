class_name TokenIcon
extends Control
## The wardrobe token: a blue hexagon (sky face, darker inset hexagon, ink outline, a little shine), so it
## never reads as a gold team coin. Size = custom_minimum_size (square); scales with the control.

func _init(px := 26) -> void:
	custom_minimum_size = Vector2(px, px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func hexagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := TAU * k / 6.0 - PI / 2.0   # pointy top
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var bw := maxf(2.0, r * 0.2)
	draw_colored_polygon(hexagon(c + Vector2(0, bw * 0.45), r), UITheme.INK)   # hard shadow / outline
	draw_colored_polygon(hexagon(c, r), UITheme.INK)
	draw_colored_polygon(hexagon(c, r - bw), UITheme.SKY)
	draw_colored_polygon(hexagon(c, (r - bw) * 0.55), UITheme.SKY.darkened(0.28))
	var hi := hexagon(c, (r - bw) * 0.55)
	draw_line(hi[5], hi[0], UITheme.CREAM_HI, maxf(1.5, r * 0.1), true)   # shine on the inset's upper-left edge
	draw_circle(c + Vector2(-r * 0.36, -r * 0.3), maxf(1.2, r * 0.1), Color(1, 1, 1, 0.8))
