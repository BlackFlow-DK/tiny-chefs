class_name WardrobeIcons
extends RefCounted
## Wardrobe card thumbnails rendered from the real models, once each, cached (same scheme as ItemIcons: a
## throwaway SubViewport per icon, one at a time on a helper node, trimmed to the visible pixels).
##   hat / acc / beard: the model alone, front three-quarter view.   back: the model from behind.
##   outfit / body: a whole chef wearing it (an outfit alone is just a bib; "classic" = the built-in jacket).
## Keyed by item and player colour (HatTint / OutfitTint / ChefBody take the colour). texture() returns null
## until ready (ready_signal tells the cards); items without a model file draw a placeholder instead (Thumb).

const PX := 160
const ELEVATION := 16.0
const YAW := 28.0

static var _tex: Dictionary = {}       # key -> Texture2D
static var _failed: Dictionary = {}    # key -> true
static var _queue: Array[String] = []
static var _worker: _Worker
static var _bus: _Bus


static func ready_signal() -> Signal:
	if _bus == null:
		_bus = _Bus.new()
	return _bus.icon_ready


static func key(cat: String, id: String, color_idx: int) -> String:
	return "%s:%s|%d" % [cat, id, color_idx]


## True when this item gets a rendered icon (has a model file, or is drawn on a chef).
static func renders(cat: String, id: String) -> bool:
	if cat == "outfit" or cat == "body":
		return Models.has_model("chef") and not Cosmetics.model_missing(cat, id)
	var m := str(Cosmetics.item(cat, id).get("model", ""))
	return not m.is_empty() and Models.has_model(m)


static func texture(cat: String, id: String, color_idx: int, urgent := false) -> Texture2D:
	var k := key(cat, id, color_idx)
	if _tex.has(k):
		return _tex[k]
	request(k, urgent)
	return null


## Queue a render (urgent: to the front, e.g. the tab just opened).
static func request(k: String, urgent := false) -> void:
	if _tex.has(k) or _failed.has(k):
		return
	var parts := _parse(k)
	if not renders(parts[0], parts[1]):
		_failed[k] = true
		return
	if _queue.has(k):
		if not urgent:
			return
		_queue.erase(k)
	if urgent:
		_queue.push_front(k)
	else:
		_queue.append(k)
	_ensure_worker()


## key -> [cat, id, color index]
static func _parse(k: String) -> Array:
	var bar := k.split("|")
	var ci := bar[0].split(":")
	return [ci[0], ci[1] if ci.size() > 1 else "", int(bar[1]) if bar.size() > 1 else 0]


static func _ensure_worker() -> void:
	if _worker != null and is_instance_valid(_worker):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_worker = _Worker.new()
	tree.root.add_child.call_deferred(_worker)


static func _store(k: String, img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var r := img.get_used_rect()
	if r.size.x < 2 or r.size.y < 2:
		_failed[k] = true
		return
	var trimmed := img.get_region(r.grow(1).intersection(Rect2i(0, 0, img.get_width(), img.get_height())))
	_tex[k] = ImageTexture.create_from_image(trimmed)
	ready_signal().emit(k)


class _Bus extends RefCounted:
	signal icon_ready(key: String)


class _Worker extends Node:
	var _busy := false

	func _process(_d: float) -> void:
		if _busy or WardrobeIcons._queue.is_empty():
			return
		_busy = true
		_render(WardrobeIcons._queue.pop_front())

	func _build(cat: String, id: String, color: Color) -> Node3D:
		if cat == "outfit" or cat == "body":
			var chef := Models.load_model("chef")
			if chef != null:
				Chef.dress(chef, color, {cat: id})
			return chef
		var m := Models.load_model(str(Cosmetics.item(cat, id).get("model", "")))
		if m != null:
			Chef.tint(m, color)
		return m

	func _render(k: String) -> void:
		var p := WardrobeIcons._parse(k)
		var cat: String = p[0]
		var n := GameData.PLAYER_COLORS.size()
		var m := _build(cat, p[1], GameData.PLAYER_COLORS[posmod(int(p[2]), n)])
		if m == null:
			WardrobeIcons._failed[k] = true
			_busy = false
			return
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(WardrobeIcons.PX, WardrobeIcons.PX)
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1, 0.97, 0.92)
		env.ambient_light_energy = 0.7
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		sun.light_energy = 1.1
		vp.add_child(sun)
		var holder := Node3D.new()
		holder.rotation_degrees.y = (180.0 + WardrobeIcons.YAW) if cat == "back" else -WardrobeIcons.YAW
		holder.add_child(m)
		vp.add_child(holder)
		add_child(vp)
		var box := _box(m)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var centre := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.01)
		cam.size = radius * 2.0 * 1.04
		vp.add_child(cam)
		var pitch := deg_to_rad(WardrobeIcons.ELEVATION)
		cam.position = centre + Vector3(0, sin(pitch), cos(pitch)) * (radius * 4.0 + 2.0)
		cam.look_at_from_position(cam.position, centre, Vector3.UP)
		cam.near = 0.05
		cam.far = radius * 12.0 + 10.0
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		vp.queue_free()
		if img != null and not img.is_empty():
			WardrobeIcons._store(k, img)
		else:
			WardrobeIcons._failed[k] = true
		_busy = false

	func _box(m: Node3D) -> AABB:
		var box := AABB()
		var first := true
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		return box


## A card thumbnail: the rendered icon (fitted, centred), else a drawn stand-in: a "coming soon" hanger for an
## item whose model is not made yet, a crossed circle for "nothing", a colour swatch for the Colour tab.
class Thumb extends Control:
	var cat := ""
	var id := ""
	var color_idx := 0
	var _tex: Texture2D = null

	func _init(c := "", i := "", col := 0, px := Vector2(112, 92)) -> void:
		cat = c
		id = i
		color_idx = col
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		WardrobeIcons.ready_signal().connect(_on_ready_icon)
		refresh()

	func set_color(col: int) -> void:
		if col != color_idx:
			color_idx = col
			refresh()

	func refresh(urgent := false) -> void:
		_tex = null
		if cat != "color":
			_tex = WardrobeIcons.texture(cat, id, color_idx, urgent)
		queue_redraw()

	func _on_ready_icon(k: String) -> void:
		if k == WardrobeIcons.key(cat, id, color_idx):
			_tex = WardrobeIcons._tex.get(k)
			queue_redraw()

	func coming_soon() -> bool:
		return cat != "color" and Cosmetics.model_missing(cat, id)

	func _draw() -> void:
		var c := size / 2.0
		var u := minf(size.x, size.y) / 100.0
		if cat == "color":
			var col: Color = GameData.PLAYER_COLORS[posmod(color_idx, GameData.PLAYER_COLORS.size())]
			draw_circle(c + Vector2(0, 3) * u, 36 * u, UITheme.INK)
			draw_circle(c, 36 * u, UITheme.INK)
			draw_circle(c, 31 * u, col)
			draw_circle(c + Vector2(-12, -12) * u, 6 * u, Color(1, 1, 1, 0.55))
			return
		if _tex != null:
			var ts := _tex.get_size()
			var s := minf(size.x / ts.x, size.y / ts.y)
			s = minf(s, 2.4)
			var d := ts * s
			draw_texture_rect(_tex, Rect2(c - d / 2.0, d), false)
			return
		if coming_soon():
			_draw_soon(c, u)
			return
		if id == "none":
			draw_arc(c, 24 * u, 0, TAU, 32, UITheme.INK_SOFT, 5 * u, true)
			draw_line(c + Vector2(-17, 17) * u, c + Vector2(17, -17) * u, UITheme.INK_SOFT, 5 * u, true)
			return
		# Rendered icon on its way (or no chef model): a soft dot.
		draw_circle(c, 10 * u, UITheme.PAPER_OFF)

	## A coat hanger in a dashed frame with a "SOON" tag.
	func _draw_soon(c: Vector2, u: float) -> void:
		var r := Rect2(c - Vector2(40, 36) * u, Vector2(80, 72) * u)
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for k in 4:
			draw_dashed_line(pts[k], pts[k + 1], UITheme.PAPER_OFF_INK, 2.5 * u, 7 * u, true)
		var top := c + Vector2(0, -20) * u
		draw_arc(top + Vector2(0, -5) * u, 5 * u, PI * 0.9, TAU * 1.05, 12, UITheme.INK_SOFT, 3.5 * u, true)
		var tri := PackedVector2Array([top, c + Vector2(28, 10) * u, c + Vector2(-28, 10) * u, top])
		draw_polyline(tri, UITheme.INK_SOFT, 4 * u, true)
		var tag := Rect2(c + Vector2(-26, 16) * u, Vector2(52, 18) * u)
		draw_style_box(UITheme.box(UITheme.SKY, UITheme.INK, int(6 * u), maxi(1, int(2 * u))), tag)
		var f := UITheme.font(true)
		var fs := maxi(8, int(13 * u))
		var tw := f.get_string_size("SOON", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - tw / 2.0, tag.position.y + tag.size.y / 2.0 + fs * 0.36), "SOON",
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
