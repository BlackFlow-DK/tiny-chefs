class_name LobbyIcon
extends Control
## Small drawn pictures for the lobby settings: mode icons, map previews, stars, padlock.
## kind: "campaign" | "endless" | "custom" | "map" | "star" | "lock". For "map", `arg` is the map id.

var kind := "star"
var arg := ""
var filled := false  # star: earned
## Map pictures (res://assets/ui/maps/<map_id>_<n>.webp|jpg|png, n = 1..): they crossfade every
## `cycle_every` s (0.6 s fade); `cycle_phase` s delays the first switch so cards do not change together.
## A map without pictures draws the old flat shapes. Paused while the icon is not visible.
const PIC_DIR := "res://assets/ui/maps/"
const PIC_EXT := ["webp", "jpg", "png"]
const PIC_ASPECT := 2.0       # pictures are 2:1; the icon's height follows its width
const FADE := 0.6
var cycle_every := 10.0
var cycle_phase := 0.0
var _frames: Array[Texture2D] = []
var _shown := 0
var _clock := 0.0
var _front: TextureRect = null
var _back: TextureRect = null


func _init(k := "star", px := Vector2(40, 40), a := "") -> void:
	kind = k
	arg = a
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind == "map":
		_frames = map_images(arg)
		if not _frames.is_empty():
			_make_pictures()
			_clock = -cycle_phase


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
## Every numbered picture the map has, in order (empty: the map draws the flat shapes).
static func map_images(map_id: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for n in range(1, 9):
		var tex: Texture2D = null
		for ext in PIC_EXT:
			var path := "%s%s_%d.%s" % [PIC_DIR, map_id, n, ext]
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				break
		if tex == null:
			break
		out.append(tex)
	return out


## Two stacked TextureRects inside a rounded, clipping panel, and the ink outline over them.
func _make_pictures() -> void:
	var clip := Panel.new()
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_corner_radius_all(10)
	fill.anti_aliasing = true
	clip.add_theme_stylebox_override("panel", fill)
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(clip)
	_back = _make_rect(clip)
	_front = _make_rect(clip)
	_front.texture = _frames[0]
	var frame := StyleBoxFlat.new()   # a later child draws over the clipped pictures
	frame.draw_center = false
	frame.border_color = UITheme.INK
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(10)
	frame.anti_aliasing = true
	var outline := Panel.new()
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.add_theme_stylebox_override("panel", frame)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outline)
	resized.connect(_on_resized)
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())


func _make_rect(parent: Control) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	return r


## The height follows the width (the container decides the width).
func _on_resized() -> void:
	var h := roundf(size.x / PIC_ASPECT)
	if absf(custom_minimum_size.y - h) > 0.5 and size.x > 1.0:
		custom_minimum_size.y = h


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_clock += delta
	if _clock >= cycle_every:
		_clock = 0.0
		_shown = (_shown + 1) % _frames.size()
		_back.texture = _frames[_shown]
		var tw := create_tween()
		tw.tween_property(_front, "modulate:a", 0.0, FADE)
		tw.tween_callback(func() -> void:
			_front.texture = _frames[_shown]
			_front.modulate.a = 1.0)


func _map() -> void:
	if not _frames.is_empty():
		return
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
