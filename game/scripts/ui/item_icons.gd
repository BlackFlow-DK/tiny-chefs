class_name ItemIcons
extends RefCounted
## Small transparent thumbnails of the food models for the order tickets. Each item kind's .glb is
## rendered ONCE (96 px, 3/4 top-down, soft light, fitted to the frame from its AABB) in a throwaway
## SubViewport, read back, trimmed to its visible pixels and cached as two textures (normal and a
## washed-out "done" variant). Rendering is lazy (first request) and runs one kind at a time on a helper node,
## so nothing hitches. Uses only an unshaded-friendly ambient + one light: fine on Low and the Mobile renderer.
## texture(kind) returns null until the icon is ready (callers fall back to the coloured chip and are
## told through `ready_signal`).

const PX := 96
const ELEVATION := 52.0   # camera pitch above the table, degrees
const YAW := 28.0

static var _tex: Dictionary = {}       # kind -> Texture2D (trimmed)
static var _tex_done: Dictionary = {}  # kind -> Texture2D (desaturated)
static var _failed: Dictionary = {}    # kind -> true (no model: stay on the fallback)
static var _queue: Array[String] = []
static var _worker: _Worker
static var _bus: _Bus


## Emits (kind) when an icon becomes available.
static func ready_signal() -> Signal:
	if _bus == null:
		_bus = _Bus.new()
	return _bus.icon_ready


static func texture(kind: String, done := false) -> Texture2D:
	if _tex.has(kind):
		return _tex_done[kind] if done else _tex[kind]
	request(kind)
	return null


static func request(kind: String) -> void:
	if _tex.has(kind) or _failed.has(kind) or _queue.has(kind):
		return
	if not Models.has_model(kind):
		_failed[kind] = true
		return
	_queue.append(kind)
	_ensure_worker()


static func _ensure_worker() -> void:
	if _worker != null and is_instance_valid(_worker):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_worker = _Worker.new()
	tree.root.add_child.call_deferred(_worker)


class _Bus extends RefCounted:
	signal icon_ready(kind: String)


## Renders queued kinds one after another (a few frames each).
class _Worker extends Node:
	var _busy := false

	func _process(_d: float) -> void:
		if _busy:
			return
		if ItemIcons._queue.is_empty():
			return
		_busy = true
		_render(ItemIcons._queue.pop_front())

	func _render(kind: String) -> void:
		var m := Models.load_model(kind)
		if m == null:
			ItemIcons._failed[kind] = true
			_busy = false
			return
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(ItemIcons.PX, ItemIcons.PX)
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(1, 0.97, 0.92)
		env.ambient_light_energy = 0.8
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, 25, 0)
		sun.light_energy = 1.0
		vp.add_child(sun)
		var holder := Node3D.new()
		holder.rotation_degrees.y = ItemIcons.YAW
		holder.add_child(m)
		vp.add_child(holder)
		add_child(vp)
		# Frame from the AABB (once the meshes have a transform): orthographic, centred, sphere-fitted.
		var box := _box(m)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var centre := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.01)
		cam.size = radius * 2.0 * 1.06
		vp.add_child(cam)
		var pitch := deg_to_rad(ItemIcons.ELEVATION)
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
			ItemIcons._store(kind, img)
		else:
			ItemIcons._failed[kind] = true
		_busy = false

	func _box(m: Node3D) -> AABB:
		var box := AABB()
		var first := true
		for n in m.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var b := mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		return box


static func _store(kind: String, img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var r := img.get_used_rect()
	if r.size.x < 2 or r.size.y < 2:
		_failed[kind] = true
		return
	var trimmed := img.get_region(r.grow(1).intersection(Rect2i(0, 0, img.get_width(), img.get_height())))
	var done := trimmed.duplicate() as Image
	for y in done.get_height():
		for x in done.get_width():
			var c := done.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var l := c.get_luminance()
			var g := Color(lerpf(c.r, l, 0.6), lerpf(c.g, l, 0.6), lerpf(c.b, l, 0.6), c.a * 0.92)
			done.set_pixel(x, y, g.lerp(Color(1, 0.98, 0.92, g.a), 0.1))
	var t := ImageTexture.create_from_image(trimmed)
	_tex[kind] = t
	_tex_done[kind] = ImageTexture.create_from_image(done)
	ready_signal().emit(kind)
