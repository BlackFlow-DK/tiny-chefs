class_name ShopIcon
extends PanelContainer
## Upgrade icon tile: the real model spinning in a small SubViewport when one exists (the upgrade's
## "icon" in GameData.UPGRADES, e.g. boxing_glove, knife), otherwise a bold emblem drawn from shapes in the
## upgrade colour (shoes, second_plate, oven_mitts, hot_griddle, tongs; a generic coin for anything else).

## Visible height at the camera distance is 1.82 m; leave a margin for the tilt.
const FILL := 1.85
const MODELS := {"gloves": "boxing_glove", "sharp_knife": "knife"}   # fallback when an upgrade has no "icon"

var _pivot: Node3D
var _emblem: Control


func _init(upgrade_id := "", color := UITheme.MUSTARD, px := 116) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.box(color.lightened(0.55), UITheme.INK, 14, 3))
	var model_name := str(GameData.upgrade(upgrade_id).get("icon", MODELS.get(upgrade_id, "")))
	if model_name != "" and Models.has_model(model_name):
		_build_view(model_name, px)
	else:
		_emblem = _Emblem.new()
		_emblem.set("kind", str(GameData.upgrade(upgrade_id).get("emblem", GameData.upgrade_id(upgrade_id))))
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


## Fills the tile: the model's AABB decides the scale (so a long thin knife is as big on screen as a chunky
## glove) and a long, thin model is stood up on the diagonal so its length uses the tile's height.
func _fit(holder: Node3D, m: Node3D) -> void:
	if not is_instance_valid(holder):
		return
	m.transform = Transform3D.IDENTITY
	var box := _box_in(holder, m)
	if box.size == Vector3.ZERO:
		return
	var sz := box.size
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var dims := [sz.x, sz.y, sz.z]
	var long_i := 0
	for k in 3:
		if dims[k] > dims[long_i]:
			long_i = k
	var others := 0.0
	for k in 3:
		if k != long_i:
			others = maxf(others, dims[k])
	var q := Quaternion.IDENTITY
	if dims[long_i] > others * 1.8:
		# Elongated (knife, tongs): long axis up and leaning 25 degrees, so the Y-spin keeps its height.
		var target := Vector3(sin(deg_to_rad(25.0)), cos(deg_to_rad(25.0)), 0.0)
		q = Quaternion(axes[long_i], target)
	m.basis = Basis(q)
	box = _box_in(holder, m)
	# Silhouette that matters while spinning: height, and the radius of the footprint.
	var need := maxf(box.size.y, Vector2(box.size.x, box.size.z).length())
	var s := FILL / maxf(need, 0.0001)
	m.basis = Basis(q).scaled(Vector3.ONE * s)
	m.position = -(box.position + box.size / 2.0) * s


## AABB of every mesh under m, in holder space.
func _box_in(holder: Node3D, m: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var rel := holder.global_transform.affine_inverse() * mi.global_transform
		var b := rel * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


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
			"second_plate":
				# Two plates side by side, the second one with a little bell.
				for p in [[Vector2(-14, -8), 26.0], [Vector2(14, 10), 26.0]]:
					var pc: Vector2 = c + (p[0] as Vector2) * u
					var pr: float = p[1] * u
					draw_circle(pc, pr, UITheme.CREAM_HI)
					draw_arc(pc, pr, 0, TAU, 40, UITheme.INK, 4.0, true)
					draw_arc(pc, pr * 0.66, 0, TAU, 32, color.darkened(0.2), 3.0 * u, true)
				var bc := c + Vector2(34, -22) * u
				draw_circle(bc + Vector2(0, 4) * u, 12 * u, UITheme.MUSTARD)
				draw_rect(Rect2(bc + Vector2(-15, 4) * u, Vector2(30, 6) * u), UITheme.MUSTARD.darkened(0.3))
				draw_arc(bc + Vector2(0, 4) * u, 12 * u, PI, TAU, 20, UITheme.INK, 3.0, true)
				draw_line(bc + Vector2(-15, 10) * u, bc + Vector2(15, 10) * u, UITheme.INK, 3.0, true)
			"hot_griddle":
				# A griddle plate with glowing bars and flames rising off it.
				var slab := PackedVector2Array([Vector2(-38, 4), Vector2(38, 4), Vector2(34, 30), Vector2(-34, 30)])
				_poly(c, u, slab, UITheme.INK.lightened(0.15))
				for i in 3:
					var y := 11.0 + i * 7.0
					draw_line(c + Vector2(-26 + i * 1.5, y) * u, c + Vector2(26 - i * 1.5, y) * u, UITheme.TOMATO.lightened(0.2), 3.0 * u, true)
				for fx in [-20.0, 0.0, 20.0]:
					var h := 30.0 if fx == 0.0 else 22.0
					var flame := PackedVector2Array([Vector2(fx - 9, 0), Vector2(fx - 6, -h * 0.6), Vector2(fx, -h),
						Vector2(fx + 6, -h * 0.6), Vector2(fx + 9, 0)])
					_poly(c, u, flame, color)
					var core := PackedVector2Array([Vector2(fx - 4, -1), Vector2(fx, -h * 0.5), Vector2(fx + 4, -1)])
					draw_colored_polygon(_pts(c, u, core), UITheme.TOMATO)
			"oven_mitts":
				# A puffy mitt: thumb, palm, cuff, quilting.
				var thumb := PackedVector2Array([Vector2(-30, -2), Vector2(-38, -14), Vector2(-34, -24), Vector2(-24, -20), Vector2(-16, -6)])
				var palm := PackedVector2Array([
					Vector2(-22, 22), Vector2(-24, -14), Vector2(-16, -32), Vector2(0, -38), Vector2(16, -32),
					Vector2(24, -14), Vector2(22, 22)])
				_poly(c, u, thumb, color)
				_poly(c, u, palm, color)
				_poly(c, u, PackedVector2Array([Vector2(-26, 20), Vector2(26, 20), Vector2(26, 36), Vector2(-26, 36)]), UITheme.CREAM_HI)
				for i in 3:
					var x := -10.0 + i * 10.0
					draw_line(c + Vector2(x, -24) * u, c + Vector2(x, 12) * u, color.darkened(0.3), 3.0 * u, true)
			"tongs":
				# Two long arms hinged at the top, gripping a little tomato.
				var l := PackedVector2Array([Vector2(-4, -38), Vector2(4, -38), Vector2(-8, 20), Vector2(-20, 32), Vector2(-24, 28), Vector2(-15, 18)])
				var r := PackedVector2Array([Vector2(-4, -38), Vector2(4, -38), Vector2(15, 18), Vector2(24, 28), Vector2(20, 32), Vector2(8, 20)])
				draw_circle(c + Vector2(0, 30) * u, 12 * u, UITheme.TOMATO)
				draw_arc(c + Vector2(0, 30) * u, 12 * u, 0, TAU, 28, UITheme.INK, 3.0, true)
				_poly(c, u, l, color)
				_poly(c, u, r, color)
				draw_circle(c + Vector2(0, -36) * u, 7 * u, UITheme.CREAM_HI)
				draw_arc(c + Vector2(0, -36) * u, 7 * u, 0, TAU, 20, UITheme.INK, 3.0, true)
			_:
				draw_circle(c, 34 * u, color)
				draw_arc(c, 34 * u, 0, TAU, 40, UITheme.INK, 4.0, true)
				draw_arc(c, 20 * u, 0, TAU, 32, UITheme.INK, 3.0, true)

	func _pts(c: Vector2, u: float, pts: PackedVector2Array) -> PackedVector2Array:
		var p := PackedVector2Array()
		for v in pts:
			p.append(c + v * u)
		return p

	func _poly(c: Vector2, u: float, pts: PackedVector2Array, fill: Color) -> void:
		var p := PackedVector2Array()
		for v in pts:
			p.append(c + v * u)
		draw_colored_polygon(p, fill)
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, UITheme.INK, 4.0, true)
