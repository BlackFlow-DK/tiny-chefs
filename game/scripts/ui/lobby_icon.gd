class_name LobbyIcon
extends Control
## Small drawn pictures for the lobby settings: mode icons, map previews, stars, padlock.
## kind: "campaign" | "endless" | "custom" | "map" | "star" | "lock". For "map", `arg` is the map id.

var kind := "star"
var arg := ""
var filled := false  # star: earned


func _init(k := "star", px := Vector2(40, 40), a := "") -> void:
	kind = k
	arg = a
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_filled(on: bool) -> void:
	filled = on
	queue_redraw()


func _draw() -> void:
	match kind:
		"campaign":
			_flag()
		"endless":
			_loop()
		"custom":
			_sliders()
		"map":
			_map()
		"star":
			_star(size / 2.0, minf(size.x, size.y) * 0.5, filled)
		"lock":
			_lock()


func _outline_poly(pts: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, UITheme.INK, 3.0, true)


func _flag() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	draw_line(o + Vector2(s * 0.22, s * 0.92), o + Vector2(s * 0.22, s * 0.1), UITheme.INK, 5.0, true)
	_outline_poly(PackedVector2Array([o + Vector2(s * 0.22, s * 0.12), o + Vector2(s * 0.88, s * 0.3), o + Vector2(s * 0.22, s * 0.56)]), UITheme.TOMATO)


func _loop() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.22
	var off := s * 0.2
	for dx in [-off, off]:
		draw_arc(c + Vector2(dx, 0), r, 0.0, TAU, 28, UITheme.INK, 9.0, true)
		draw_arc(c + Vector2(dx, 0), r, 0.0, TAU, 28, UITheme.LETTUCE, 4.0, true)


func _sliders() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var ys := [0.25, 0.52, 0.79]
	var ks := [0.65, 0.3, 0.55]
	for i in 3:
		var y: float = o.y + s * ys[i]
		draw_line(Vector2(o.x + s * 0.08, y), Vector2(o.x + s * 0.92, y), UITheme.INK, 5.0, true)
		var kp := Vector2(o.x + s * (0.08 + 0.84 * ks[i]), y)
		draw_circle(kp, s * 0.12, UITheme.INK)
		draw_circle(kp, s * 0.072, UITheme.MUSTARD)


func _star(c: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	var closed := pts.duplicate()
	closed.append(pts[0])
	if on:
		draw_colored_polygon(pts, UITheme.MUSTARD)
		draw_polyline(closed, UITheme.INK, 2.5, true)
	else:
		draw_colored_polygon(pts, Color(UITheme.INK, 0.12))
		draw_polyline(closed, Color(UITheme.INK_SOFT, 0.7), 2.0, true)


func _lock() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	draw_arc(o + Vector2(s * 0.5, s * 0.4), s * 0.22, PI, TAU, 16, UITheme.INK, 4.0, true)
	draw_line(o + Vector2(s * 0.28, s * 0.4), o + Vector2(s * 0.28, s * 0.5), UITheme.INK, 4.0)
	draw_line(o + Vector2(s * 0.72, s * 0.4), o + Vector2(s * 0.72, s * 0.5), UITheme.INK, 4.0)
	draw_style_box(UITheme.box(UITheme.MUSTARD, UITheme.INK, 4, 3), Rect2(o + Vector2(s * 0.16, s * 0.48), Vector2(s * 0.68, s * 0.42)))


# ---- map preview: the real surfaces from the map data on a themed backdrop
func _map() -> void:
	var t := _theme_colors(arg)
	draw_style_box(UITheme.box(t[0], UITheme.INK, 10, 3), Rect2(Vector2.ZERO, size))
	var surfaces: Array = []
	if GameData.MAPS.has(arg):
		surfaces = (GameData.MAPS[arg] as Dictionary).get("surfaces", [])
	var rects: Array[Rect2] = []
	for r in surfaces:
		if r is Rect2:
			rects.append(r)
	if rects.is_empty():
		rects.append(Rect2(-30, -18, 60, 36))
	var box := rects[0]
	for r in rects:
		box = box.merge(r)
	var inner := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	var k := minf(inner.size.x / maxf(box.size.x, 1.0), inner.size.y / maxf(box.size.y, 1.0))
	var origin := inner.position + (inner.size - box.size * k) / 2.0 - box.position * k
	for r in rects:
		var pr := Rect2(origin + r.position * k, r.size * k)
		draw_rect(Rect2(pr.position + Vector2(0, 3), pr.size), UITheme.INK)
		draw_rect(pr, t[1])
		draw_rect(pr, UITheme.INK, false, 2.0)
		_decor(pr, t)


func _decor(pr: Rect2, t: Array) -> void:
	# A few counter blocks so each theme reads differently at a glance.
	var u := minf(pr.size.x, pr.size.y) * 0.16
	match arg:
		"food_truck":
			draw_rect(Rect2(pr.position + Vector2(0, -0.0), Vector2(pr.size.x, u * 0.8)), t[2])
			for i in 5:
				if i % 2 == 0:
					draw_rect(Rect2(pr.position + Vector2(pr.size.x * i / 5.0, 0), Vector2(pr.size.x / 5.0, u * 0.8)), UITheme.CREAM)
		"picnic":
			var n := 4
			for ix in n:
				for iy in 3:
					if (ix + iy) % 2 == 0:
						var cell := Vector2(pr.size.x / n, pr.size.y / 3.0)
						draw_rect(Rect2(pr.position + Vector2(ix * cell.x, iy * cell.y), cell), t[2])
		_:
			draw_rect(Rect2(pr.position + Vector2(u, u), Vector2(u * 2.2, u * 1.2)), t[2])
			draw_rect(Rect2(pr.position + Vector2(pr.size.x - u * 3.4, pr.size.y - u * 2.4), Vector2(u * 2.2, u * 1.2)), t[2])


## [background, surface, accent] for a map id.
static func _theme_colors(map_id: String) -> Array:
	var th := map_id
	if GameData.MAPS.has(map_id):
		th = str((GameData.MAPS[map_id] as Dictionary).get("theme", map_id))
	if map_id == "food_truck" or th == "food_truck":
		return [Color("#7FB8D8"), Color("#E9D6A8"), UITheme.TOMATO]
	if map_id == "picnic" or th == "picnic":
		return [Color("#8FD06A"), Color("#FFF6E0"), UITheme.TOMATO]
	if map_id == "twin_islands" or th == "twin_islands":
		return [Color("#3E6FA8"), Color("#C9AE86"), UITheme.MUSTARD]
	return [Color("#3E3349"), Color("#C9AE86"), Color("#8FB8A0")]
