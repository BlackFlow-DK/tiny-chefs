class_name LobbyIcon
extends Control
## Small drawn pictures for the lobby settings: mode icons, map previews, stars, padlock.
## kind: "campaign" | "endless" | "custom" | "map" | "star" | "lock". For "map", `arg` is the map id.

var kind := "star"
var arg := ""
var filled := false  # star: earned
var _pic_tex: Texture2D = null   # map: the card picture, if the map has one (see map_image)
var _pic: TextureRect = null


func _init(k := "star", px := Vector2(40, 40), a := "") -> void:
	kind = k
	arg = a
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind == "map":
		_pic_tex = map_image(arg)
		if _pic_tex != null:
			_make_picture()


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
## Map card picture: res://assets/ui/maps/<id>.png if it exists (--map-thumbs=<name> loads <id>_<name>.png
## instead, for comparing candidates), else null and the drawn shapes below are used.
static func map_image(map_id: String) -> Texture2D:
	var sfx := Net.arg_str("map-thumbs", "")
	var path := "res://assets/ui/maps/%s%s.png" % [map_id, "_" + sfx if sfx != "" else ""]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


const _ROUND_SHADER := "shader_type canvas_item;
uniform vec2 box_size;
uniform float radius = 11.0;
void fragment() {
	vec2 q = abs(UV * box_size - box_size * 0.5) - (box_size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.5, 0.5, d);
}"


## Cover-fit picture with rounded corners (a child TextureRect; _draw adds the ink outline on top).
func _make_picture() -> void:
	_pic = TextureRect.new()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = _ROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	_pic.material = m
	add_child(_pic)
	var frame := StyleBoxFlat.new()   # ink outline over the picture (a child draws after its parent's _draw)
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
	resized.connect(_fit_picture)
	_fit_picture()


func _fit_picture() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var ts := _pic_tex.get_size()
	var k := maxf(size.x / ts.x, size.y / ts.y)
	var src_size := size / k
	var at := AtlasTexture.new()
	at.atlas = _pic_tex
	at.region = Rect2((ts - src_size) / 2.0, src_size)
	_pic.texture = at
	(_pic.material as ShaderMaterial).set_shader_parameter("box_size", size)


func _map() -> void:
	if _pic != null:
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
