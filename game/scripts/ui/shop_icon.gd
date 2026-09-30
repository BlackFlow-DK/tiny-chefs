class_name ShopIcon
extends PanelContainer
## Upgrade icon tile: the real model spinning in a small SubViewport when one exists
## (boxing_glove, knife), otherwise a bold emblem drawn from shapes in the upgrade colour.

const MODELS := {"gloves": "boxing_glove", "knife": "knife"}

var _pivot: Node3D
var _emblem: Control


func _init(upgrade_id := "", color := UITheme.MUSTARD, px := 116) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.box(color.lightened(0.55), UITheme.INK, 14, 3))
	var model_name: String = MODELS.get(upgrade_id, "")
	if model_name != "" and Models.has_model(model_name):
		_build_view(model_name, px)
	else:
		_emblem = _Emblem.new()
		_emblem.set("kind", upgrade_id)
		_emblem.set("color", color)
		_emblem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_emblem.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_emblem)


func _build_view(model_name: String, px: int) -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(px, px)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.96, 0.9)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0, 3.4)
	vp.add_child(cam)
	_pivot = Node3D.new()
	_pivot.rotation.x = 0.35
	vp.add_child(_pivot)
	var m := Models.load_model(model_name)
	if m != null:
		var holder := Node3D.new()
		holder.add_child(m)
		_pivot.add_child(holder)
		# Centre and fit once the model has a world transform.
		holder.ready.connect(func() -> void: _fit.call_deferred(holder, m))
	add_child(svc)


func _fit(holder: Node3D, m: Node3D) -> void:
	if not is_instance_valid(holder):
		return
	var box := AABB()
	var first := true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var rel := m.global_transform.affine_inverse() * mi.global_transform
		var b := rel * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var s := 1.75 / maxf(box.size.length(), 0.001)
	m.scale = Vector3.ONE * s
	m.position = -(box.position + box.size / 2.0) * s


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y += delta * 1.1


class _Emblem extends Control:
	var kind := ""
	var color := UITheme.MUSTARD

	func _draw() -> void:
		var c := size / 2.0
		var u := minf(size.x, size.y) / 100.0
		match kind:
			"shoes":
				# A chunky sneaker: sole, upper, toe cap, laces.
				var sole := PackedVector2Array([Vector2(-38, 22), Vector2(42, 22), Vector2(44, 32), Vector2(-38, 32)])
				var upper := PackedVector2Array([
					Vector2(-36, 22), Vector2(-36, -22), Vector2(-14, -26), Vector2(-4, -6),
					Vector2(20, 4), Vector2(38, 10), Vector2(42, 22)])
				_poly(c, u, upper, color)
				_poly(c, u, sole, UITheme.CREAM_HI)
				for i in 3:
					var y := -14.0 + i * 8.0
					draw_line(c + Vector2(-10 + i * 6, y) * u, c + Vector2(-2 + i * 6, y + 3) * u, UITheme.INK, 3.0 * u, true)
				draw_line(c + Vector2(-36, 12) * u, c + Vector2(-8, 14) * u, color.darkened(0.35), 3.0 * u, true)
			_:
				draw_circle(c, 34 * u, color)
				draw_arc(c, 34 * u, 0, TAU, 40, UITheme.INK, 4.0, true)
				draw_arc(c, 20 * u, 0, TAU, 32, UITheme.INK, 3.0, true)

	func _poly(c: Vector2, u: float, pts: PackedVector2Array, fill: Color) -> void:
		var p := PackedVector2Array()
		for v in pts:
			p.append(c + v * u)
		draw_colored_polygon(p, fill)
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, UITheme.INK, 4.0, true)
