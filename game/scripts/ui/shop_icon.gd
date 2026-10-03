class_name ShopIcon
extends PanelContainer
## Upgrade icon tile: the real model spinning in a small SubViewport when one exists (the upgrade's
## "icon" in GameData.UPGRADES, e.g. boxing_glove, knife), otherwise a bold emblem drawn from shapes in the
## upgrade colour (one per upgrade line, see EMBLEMS; a generic coin for anything else). `flat` forces the
## emblem (small tiles such as the owned strip skip the spinning 3D model).

## Visible height at the camera distance is 1.82 m; leave a margin for the tilt.
const FILL := 1.85
const MODELS := {"gloves": "boxing_glove", "sharp_knife": "knife"}   # fallback when an upgrade has no "icon"

## Lines with their own drawn emblem (anything else uses the data's "emblem" key, then the generic coin).
const EMBLEMS := ["shoes", "second_plate", "hot_griddle", "oven_mitts", "tongs", "big_griddle", "big_fryer", "sharp_knife",
	"quick_hands", "protein_shake", "friendly_service", "tip_jar", "insurance", "combo_bell", "gloves", "heavy_gloves"]

var _pivot: Node3D
var _emblem: Control


func _init(upgrade_id := "", color := UITheme.MUSTARD, px := 116, flat := false) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UITheme.box(color.lightened(0.55), UITheme.INK, 14, 3))
	var model_name := str(GameData.upgrade(upgrade_id).get("icon", MODELS.get(upgrade_id, "")))
	if upgrade_id == "heavy_gloves":
		model_name = ""   # same glove model as Boxing Gloves: the drawn emblem tells them apart
	if not flat and model_name != "" and Models.has_model(model_name):
		_build_view(model_name, px)
	else:
		_emblem = _Emblem.new()
		var cid := GameData.upgrade_id(upgrade_id)
		_emblem.set("kind", cid if cid in EMBLEMS else str(GameData.upgrade(upgrade_id).get("emblem", cid)))
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
			"big_griddle":
				# A wide griddle with patties on it and a "+" badge.
				_poly(c, u, PackedVector2Array([Vector2(-40, 8), Vector2(40, 8), Vector2(36, 34), Vector2(-36, 34)]), UITheme.INK.lightened(0.15))
				for px in [-22.0, 0.0, 22.0]:
					_disc(c, u, Vector2(px, 4), 11.0, color.darkened(0.15))
				_plus_badge(c, u, Vector2(26, -26))
			"big_fryer":
				# A fry basket piled with fries, and a "+" badge.
				for i in 5:
					var fx := -22.0 + i * 11.0
					var ft := -34.0 + (i % 2) * 6.0
					_poly(c, u, PackedVector2Array([Vector2(fx - 4, ft), Vector2(fx + 4, ft), Vector2(fx + 4, 0), Vector2(fx - 4, 0)]), UITheme.MUSTARD)
				_poly(c, u, PackedVector2Array([Vector2(-32, -4), Vector2(32, -4), Vector2(24, 34), Vector2(-24, 34)]), UITheme.CREAM_HI)
				for i in 3:
					draw_line(c + Vector2(-26 + i * 6, 2) * u, c + Vector2(-19 + i * 19, 32) * u, color.darkened(0.3), 2.5 * u, true)
				draw_line(c + Vector2(-32, -4) * u, c + Vector2(-46, -14) * u, UITheme.INK, 5.0 * u, true)
				_plus_badge(c, u, Vector2(28, -28))
			"sharp_knife":
				# A chef's knife on the diagonal with a glint.
				var blade := _rot(PackedVector2Array([Vector2(-9, -40), Vector2(10, -28), Vector2(10, 8), Vector2(-9, 8)]), 0.55)
				var handle := _rot(PackedVector2Array([Vector2(-8, 8), Vector2(10, 8), Vector2(10, 38), Vector2(-8, 38)]), 0.55)
				_poly(c, u, blade, UITheme.CREAM_HI)
				_poly(c, u, handle, UITheme.TOMATO.darkened(0.15))
				var g := c + Vector2(-26, -24) * u
				draw_line(g + Vector2(-9, 0) * u, g + Vector2(9, 0) * u, color.darkened(0.2), 3.0 * u, true)
				draw_line(g + Vector2(0, -9) * u, g + Vector2(0, 9) * u, color.darkened(0.2), 3.0 * u, true)
			"quick_hands":
				# An open hand with speed lines.
				for i in 3:
					draw_line(c + Vector2(-44, -10 + i * 14) * u, c + Vector2(-26 + i * 3, -10 + i * 14) * u, UITheme.INK, 3.5 * u, true)
				for i in 4:
					var fx := -10.0 + i * 11.0
					var tip := -34.0 + (6.0 if i == 0 or i == 3 else 0.0)
					draw_line(c + Vector2(fx, 0) * u, c + Vector2(fx, tip) * u, UITheme.INK, 13.0 * u, true)
					draw_circle(c + Vector2(fx, tip) * u, 6.5 * u, UITheme.INK)
				for i in 4:
					var fx2 := -10.0 + i * 11.0
					var tip2 := -34.0 + (6.0 if i == 0 or i == 3 else 0.0)
					draw_line(c + Vector2(fx2, 0) * u, c + Vector2(fx2, tip2) * u, color, 7.0 * u, true)
					draw_circle(c + Vector2(fx2, tip2) * u, 3.5 * u, color)
				_poly(c, u, PackedVector2Array([Vector2(-16, -2), Vector2(26, -2), Vector2(28, 18), Vector2(14, 34), Vector2(-8, 34), Vector2(-18, 22)]), color)
				_poly(c, u, PackedVector2Array([Vector2(-18, 12), Vector2(-34, 2), Vector2(-28, -6), Vector2(-14, 4)]), color)
			"protein_shake":
				# A shaker bottle with a lid and a lightning bolt.
				_poly(c, u, PackedVector2Array([Vector2(-20, -18), Vector2(20, -18), Vector2(24, 36), Vector2(-24, 36)]), UITheme.CREAM_HI)
				_poly(c, u, PackedVector2Array([Vector2(-21, 6), Vector2(21, 6), Vector2(24, 36), Vector2(-24, 36)]), color)
				_poly(c, u, PackedVector2Array([Vector2(-24, -30), Vector2(24, -30), Vector2(24, -18), Vector2(-24, -18)]), UITheme.TOMATO)
				_poly(c, u, PackedVector2Array([Vector2(-8, -38), Vector2(8, -38), Vector2(8, -30), Vector2(-8, -30)]), UITheme.INK_LIGHT)
				_poly(c, u, PackedVector2Array([Vector2(4, -10), Vector2(-8, 14), Vector2(0, 14), Vector2(-4, 30), Vector2(10, 6), Vector2(2, 6)]), UITheme.MUSTARD)
			"friendly_service":
				# A smiling face with rosy cheeks.
				_disc(c, u, Vector2(0, 0), 36.0, UITheme.MUSTARD)
				draw_circle(c + Vector2(-14, -8) * u, 5 * u, UITheme.INK)
				draw_circle(c + Vector2(14, -8) * u, 5 * u, UITheme.INK)
				draw_circle(c + Vector2(-23, 8) * u, 6 * u, UITheme.TOMATO.lightened(0.35))
				draw_circle(c + Vector2(23, 8) * u, 6 * u, UITheme.TOMATO.lightened(0.35))
				draw_arc(c + Vector2(0, 4) * u, 17 * u, 0.35, PI - 0.35, 20, UITheme.INK, 4.5 * u, true)
			"tip_jar":
				# A glass jar of coins with a lid.
				_poly(c, u, PackedVector2Array([Vector2(-26, -22), Vector2(26, -22), Vector2(30, 34), Vector2(-30, 34)]), UITheme.CREAM_HI)
				for k in [Vector2(-14, 26), Vector2(10, 26), Vector2(-3, 14), Vector2(-18, 14), Vector2(16, 12)]:
					draw_circle(c + k * u, 9 * u, UITheme.MUSTARD)
					draw_arc(c + k * u, 9 * u, 0, TAU, 20, UITheme.INK, 2.5, true)
				_poly(c, u, PackedVector2Array([Vector2(-30, -36), Vector2(30, -36), Vector2(30, -22), Vector2(-30, -22)]), color)
			"insurance":
				# A shield with a check mark.
				_poly(c, u, PackedVector2Array([Vector2(-30, -30), Vector2(0, -40), Vector2(30, -30), Vector2(30, -2), Vector2(18, 22), Vector2(0, 38), Vector2(-18, 22), Vector2(-30, -2)]), color)
				draw_polyline(_pts(c, u, PackedVector2Array([Vector2(-14, -2), Vector2(-4, 10), Vector2(16, -14)])), UITheme.CREAM_HI, 7.0 * u, true)
			"combo_bell":
				# A service bell with chain dashes underneath.
				var dome := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					dome.append(Vector2(cos(a) * 34.0, sin(a) * 34.0 + 14.0))
				_poly(c, u, dome, UITheme.MUSTARD)
				_poly(c, u, PackedVector2Array([Vector2(-40, 14), Vector2(40, 14), Vector2(40, 24), Vector2(-40, 24)]), color)
				_disc(c, u, Vector2(0, -24), 6.0, UITheme.CREAM_HI)
				draw_arc(c + Vector2(0, 14) * u, 22 * u, PI + 0.5, PI + 1.1, 8, UITheme.CREAM_HI, 4.0 * u, true)
				for i in 3:
					var x := -26.0 + i * 26.0
					draw_line(c + Vector2(x, 34) * u, c + Vector2(x + 10, 34) * u, UITheme.INK, 3.5 * u, true)
			"gloves":
				_glove(c, u, UITheme.TOMATO)
			"heavy_gloves":
				_glove(c, u, UITheme.INK_LIGHT)
				for i in 2:
					var x := -44.0 + i * 8.0
					draw_polyline(_pts(c, u, PackedVector2Array([Vector2(x, -26), Vector2(x + 8, -18), Vector2(x, -10)])), UITheme.MUSTARD, 4.0 * u, true)
				draw_line(c + Vector2(-17, 24) * u, c + Vector2(13, 24) * u, UITheme.MUSTARD, 4.0 * u, true)
			_:
				draw_circle(c, 34 * u, color)
				draw_arc(c, 34 * u, 0, TAU, 40, UITheme.INK, 4.0, true)
				draw_arc(c, 20 * u, 0, TAU, 32, UITheme.INK, 3.0, true)

	func _disc(c: Vector2, u: float, at: Vector2, r: float, fill: Color) -> void:
		draw_circle(c + at * u, r * u, fill)
		draw_arc(c + at * u, r * u, 0, TAU, 32, UITheme.INK, 4.0, true)

	func _plus_badge(c: Vector2, u: float, at: Vector2) -> void:
		_disc(c, u, at, 13.0, UITheme.LETTUCE)
		draw_line(c + (at + Vector2(-6, 0)) * u, c + (at + Vector2(6, 0)) * u, UITheme.CREAM_HI, 4.0 * u, true)
		draw_line(c + (at + Vector2(0, -6)) * u, c + (at + Vector2(0, 6)) * u, UITheme.CREAM_HI, 4.0 * u, true)

	func _rot(pts: PackedVector2Array, ang: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(p.rotated(ang))
		return out

	## Boxing glove: thumb, fist, cuff with laces.
	func _glove(c: Vector2, u: float, col: Color) -> void:
		_disc(c, u, Vector2(-26, 6), 12.0, col)
		_disc(c, u, Vector2(-2, -8), 28.0, col)
		_poly(c, u, PackedVector2Array([Vector2(-18, 18), Vector2(14, 18), Vector2(16, 38), Vector2(-20, 38)]), UITheme.CREAM_HI)
		draw_arc(c + Vector2(-8, -16) * u, 16 * u, PI + 0.3, PI + 1.3, 10, col.lightened(0.45), 4.0 * u, true)
		for i in 2:
			draw_line(c + Vector2(-14, 25 + i * 7) * u, c + Vector2(10, 25 + i * 7) * u, UITheme.INK, 2.5 * u, true)

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
