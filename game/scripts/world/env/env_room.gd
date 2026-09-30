class_name EnvRoom
extends RefCounted
## The room around the counter: oak floor far below with a runner rug, the back wall (glossy subway
## tiles behind the counter, warm paint above) with a daylight window + light shaft, a shelf, a
## utensil rail and a clock, side walls, and tall furniture beside the counter (fridge, pantry) so
## no camera position shows void. Walls cast no shadows (the key light comes through them).

const WALL_Z := -18.5       # front face of the back wall (the collider Kitchen builds is behind it)
const ROOM_HX := 92.0       # side walls
const ROOM_TOP := 75.0
const ROOM_FRONT := 75.0
const TILE_TOP := 18.0
const WINDOW := Rect2(-19.0, 6.0, 22.0, 24.0)   # x, y on the back wall
const PAINT := Color(0.95, 0.85, 0.67)
const TRIM := Color(0.97, 0.95, 0.9)


## surfaces: the map's counter tops (Rect2 x, z, w, h). The room is laid out for the diner's
## 60 x 36 island: the back wall sits just behind the back-most edge (the whole room shifts in Z),
## the tiles and side furniture follow the widest X extent (assumes a layout centred on X = 0).
static func build(root: Node3D, surfaces: Array) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var b := GameData.surfaces_bounds(surfaces)
	var hx := maxf(-b.position.x, b.end.x)
	var n := EnvUtil.node(root, "Room", Vector3(0, 0, b.position.y - (WALL_Z + 0.5)))
	var floor_y := -ch

	# Floor + rug + soft contact darkening along each counter base.
	EnvUtil.plane(n, Vector2(ROOM_HX * 2.0, ROOM_FRONT - WALL_Z), Vector3(0, floor_y, (ROOM_FRONT + WALL_Z) * 0.5),
		EnvUtil.shader_mat("wood_floor"))
	EnvUtil.plane(n, Vector2(76, 22), Vector3(0, floor_y + 0.05, 34), EnvUtil.shader_mat("rug", {"size": Vector2(76, 22)}))
	var ao := EnvUtil.shader_mat("counter_decal", {"kind": 4, "opacity": 0.55})
	var base := EnvUtil.node(root, "CounterShadow")
	for r: Rect2 in surfaces:
		var c := r.get_center()
		var rx := r.size.x * 0.5
		EnvUtil.plane(base, Vector2(r.size.x + 4.0, 14.0), Vector3(c.x, floor_y + 0.08, r.end.y - 2.6), ao)
		for sx in [-1.0, 1.0]:
			var side := EnvUtil.plane(base, Vector2(r.size.y + 4.0, 14.0), Vector3(c.x + sx * (rx - 2.6), floor_y + 0.08, c.y), ao)
			side.rotation.y = PI * 0.5

	# Back wall: tiles behind the counter, paint elsewhere, window hole through both.
	var wall_rect := Rect2(-ROOM_HX, floor_y, ROOM_HX * 2.0, ROOM_TOP - floor_y)
	var tile_rect := Rect2(-hx, -1.5, hx * 2.0, TILE_TOP + 1.5)
	var paint := EnvUtil.mat(PAINT, 0.88)
	var tiles := EnvUtil.shader_mat("subway_tile")
	for rc in EnvUtil.rects_minus(EnvUtil.rect_minus(wall_rect, tile_rect), WINDOW):
		_wall_quad(n, rc, paint)
	for rc in EnvUtil.rect_minus(tile_rect, WINDOW):
		_wall_quad(n, rc, tiles)
	var trim := EnvUtil.mat(TRIM, 0.35)
	# Bullnose cap on top of the tiles (either side of the window), skirting boards on the floor.
	for seg in [Vector2(-hx, WINDOW.position.x), Vector2(WINDOW.end.x, hx)]:
		EnvUtil.box_mm(n, Vector3(seg.x, TILE_TOP - 0.3, WALL_Z), Vector3(seg.y, TILE_TOP + 0.4, WALL_Z + 0.45), trim, false)
	for seg in [Vector2(-ROOM_HX, -hx), Vector2(hx, ROOM_HX)]:
		EnvUtil.box_mm(n, Vector3(seg.x, floor_y, WALL_Z), Vector3(seg.y, floor_y + 3.2, WALL_Z + 0.7), trim, false)
	# Side walls + their skirting.
	for sx in [-1.0, 1.0]:
		var q := EnvUtil.quad(n, Vector2(ROOM_FRONT - WALL_Z, ROOM_TOP - floor_y),
			Vector3(sx * ROOM_HX, (ROOM_TOP + floor_y) * 0.5, (ROOM_FRONT + WALL_Z) * 0.5), paint)
		q.rotation.y = -sx * PI * 0.5
		EnvUtil.box_mm(n, Vector3(sx * ROOM_HX - 0.35, floor_y, WALL_Z), Vector3(sx * ROOM_HX + 0.35, floor_y + 3.2, ROOM_FRONT), trim, false)

	# Wall-mounted things cast no shadows either: the key light comes "through" the wall, so their
	# shadows would land as stray blobs mid-counter.
	var wall_decor := EnvUtil.node(n, "WallDecor")
	_window(wall_decor)
	_shelf(wall_decor)
	_rail(wall_decor)
	_clock(wall_decor, Vector3(-25.0, 25.5, WALL_Z))
	_no_shadows(wall_decor)
	_fridge(n, -hx - 14.0 - 25.0, floor_y)
	_pantry(n, hx + 14.0 + 24.0, floor_y)
	_floor_plant(n, Vector3(-44.0, floor_y, 24.0))


static func _no_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadows(c)


static func _wall_quad(parent: Node3D, rc: Rect2, material: Material) -> void:
	EnvUtil.quad(parent, rc.size, Vector3(rc.get_center().x, rc.get_center().y, WALL_Z), material)


static func _window(n: Node3D) -> void:
	var w := WINDOW
	var trim := EnvUtil.mat(TRIM, 0.35)
	var depth := 2.2
	var zb := WALL_Z - depth
	# Reveal (the wall thickness inside the opening).
	EnvUtil.box_mm(n, Vector3(w.position.x - 0.4, w.position.y, zb), Vector3(w.position.x, w.end.y, WALL_Z), trim, false)
	EnvUtil.box_mm(n, Vector3(w.end.x, w.position.y, zb), Vector3(w.end.x + 0.4, w.end.y, WALL_Z), trim, false)
	EnvUtil.box_mm(n, Vector3(w.position.x - 0.4, w.end.y, zb), Vector3(w.end.x + 0.4, w.end.y + 0.4, WALL_Z), trim, false)
	# Sill, proud of the wall.
	EnvUtil.box_mm(n, Vector3(w.position.x - 1.2, w.position.y - 0.7, zb), Vector3(w.end.x + 1.2, w.position.y, WALL_Z + 1.3), trim)
	# Casing around the opening.
	var c := 1.0
	EnvUtil.box_mm(n, Vector3(w.position.x - c, w.position.y, WALL_Z), Vector3(w.position.x, w.end.y + c, WALL_Z + 0.35), trim, false)
	EnvUtil.box_mm(n, Vector3(w.end.x, w.position.y, WALL_Z), Vector3(w.end.x + c, w.end.y + c, WALL_Z + 0.35), trim, false)
	EnvUtil.box_mm(n, Vector3(w.position.x, w.end.y, WALL_Z), Vector3(w.end.x, w.end.y + c, WALL_Z + 0.35), trim, false)
	# Sash: frame + mullions, set back in the reveal.
	var zs := WALL_Z - depth * 0.6
	var f := 0.8
	EnvUtil.box_mm(n, Vector3(w.position.x, w.position.y, zs - 0.3), Vector3(w.position.x + f, w.end.y, zs + 0.3), trim, false)
	EnvUtil.box_mm(n, Vector3(w.end.x - f, w.position.y, zs - 0.3), Vector3(w.end.x, w.end.y, zs + 0.3), trim, false)
	EnvUtil.box_mm(n, Vector3(w.position.x, w.end.y - f, zs - 0.3), Vector3(w.end.x, w.end.y, zs + 0.3), trim, false)
	EnvUtil.box_mm(n, Vector3(w.position.x, w.position.y, zs - 0.3), Vector3(w.end.x, w.position.y + f, zs + 0.3), trim, false)
	var cx := w.get_center().x
	var cy := w.position.y + w.size.y * 0.55
	EnvUtil.box(n, Vector3(0.55, w.size.y, 0.5), Vector3(cx, w.get_center().y, zs), trim, false)
	EnvUtil.box(n, Vector3(w.size.x, 0.55, 0.5), Vector3(cx, cy, zs), trim, false)
	# Faint glass for a glint.
	EnvUtil.quad(n, w.size, Vector3(cx, w.get_center().y, zs + 0.05), EnvUtil.mat(Color(0.85, 0.92, 1.0, 0.07), 0.05))
	# The outside, a few metres behind the opening (big enough for steep views through it).
	var vw := w.size.x + 20.0
	var vh := w.size.y + 26.0
	EnvUtil.quad(n, Vector2(vw, vh), Vector3(cx, w.get_center().y - 4.0, WALL_Z - 7.0),
		EnvUtil.shader_mat("window_view", {"aspect": vw / vh}))
	# Herb pot on the sill.
	var pot := EnvUtil.mat(Color(0.74, 0.4, 0.27), 0.8)
	var leaf := EnvUtil.mat(Color(0.33, 0.56, 0.28), 0.7)
	var px := w.end.x - 4.0
	EnvUtil.cyl(n, 1.3, 1.0, 2.4, Vector3(px, w.position.y, WALL_Z - 0.2), pot, "y", 16)
	for i in 7:
		var a := i * 2.4
		var r := 0.5 + (i % 3) * 0.35
		EnvUtil.sphere(n, 0.75, Vector3(px + cos(a) * r, w.position.y + 3.0 + (i % 2) * 0.9, WALL_Z - 0.2 + sin(a) * r * 0.6), leaf,
			Vector3(1, 1.3, 0.8), true, 10)
	# Daylight shaft from the opening along the key light direction down to the counter top.
	_shaft(n, w)


## Additive light sheets from the window rectangle to where the key light meets y = 0, plus a warm
## patch on the counter where it lands.
static func _shaft(n: Node3D, w: Rect2) -> void:
	var d := EnvLook.SUN_DIR.normalized()
	var corners := [Vector3(w.position.x, w.position.y, WALL_Z - 1.0), Vector3(w.end.x, w.position.y, WALL_Z - 1.0),
		Vector3(w.end.x, w.end.y, WALL_Z - 1.0), Vector3(w.position.x, w.end.y, WALL_Z - 1.0)]
	var ends: Array = []
	for c in corners:
		ends.append(c + d * (-c.y / d.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var a2: Vector3 = ends[i]
		var b2: Vector3 = ends[(i + 1) % 4]
		var nrm := (b - a).cross(a2 - a).normalized()
		for v in [[a, Vector2(0, 0)], [b, Vector2(1, 0)], [b2, Vector2(1, 1)], [a, Vector2(0, 0)], [b2, Vector2(1, 1)], [a2, Vector2(0, 1)]]:
			st.set_normal(nrm)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	var mi := EnvUtil.mesh(n, st.commit(), EnvUtil.shader_mat("light_shaft", {"strength": 0.05}), Vector3.ZERO, false)
	mi.name = "LightShaft"
	# Patch: parallelogram of the four end points, as a sheared plane.
	var e0: Vector3 = ends[0]
	var e1: Vector3 = ends[1]
	var e3: Vector3 = ends[3]
	var centre: Vector3 = (ends[0] + ends[2]) * 0.5
	var patch := EnvUtil.plane(n, Vector2(2, 2), Vector3.ZERO,
		EnvUtil.shader_mat("counter_decal", {"kind": 3, "tint": Color(1.0, 0.85, 0.6), "opacity": 0.16}))
	patch.transform = Transform3D(Basis((e1 - e0) * 0.5, Vector3.UP, (e3 - e0) * 0.5), Vector3(centre.x, 0.012, centre.z))
	patch.name = "SunPatch"


static func _shelf(n: Node3D) -> void:
	var wood := EnvUtil.mat(Color(0.62, 0.43, 0.27), 0.55)
	var y := 21.0
	EnvUtil.box_mm(n, Vector3(6.0, y, WALL_Z), Vector3(28.0, y + 0.8, WALL_Z + 3.6), wood)
	for bx in [8.5, 25.5]:
		EnvUtil.box_mm(n, Vector3(bx - 0.35, y - 3.0, WALL_Z), Vector3(bx + 0.35, y, WALL_Z + 0.7), wood)
		EnvUtil.box_mm(n, Vector3(bx - 0.35, y - 0.7, WALL_Z), Vector3(bx + 0.35, y, WALL_Z + 3.0), wood)
	var top := y + 0.8
	var zc := WALL_Z + 1.8
	var glass := EnvUtil.mat(Color(0.85, 0.92, 0.95, 0.35), 0.08)
	var lid := EnvUtil.mat(Color(0.72, 0.52, 0.32), 0.6)
	var fills := [Color(0.95, 0.78, 0.35), Color(0.62, 0.25, 0.2), Color(0.45, 0.58, 0.3)]
	for i in 3:
		var x := 9.5 + i * 2.9
		var h := 4.0 - i * 0.5
		EnvUtil.cyl(n, 1.05, 1.05, h * 0.7, Vector3(x, top, zc), EnvUtil.mat(fills[i], 0.85), "y", 16)
		EnvUtil.cyl(n, 1.2, 1.2, h, Vector3(x, top, zc), glass, "y", 16, false)
		EnvUtil.cyl(n, 1.3, 1.3, 0.5, Vector3(x, top + h, zc), lid, "y", 16)
	# Stack of bowls.
	var bowl := EnvUtil.mat(Color(0.93, 0.9, 0.84), 0.35)
	for i in 3:
		EnvUtil.cyl(n, 2.1, 1.3, 0.9, Vector3(19.0, top + i * 0.75, zc), bowl, "y", 20)
	EnvUtil.cyl(n, 2.1, 1.3, 0.9, Vector3(19.0, top + 2.25, zc), EnvUtil.mat(Color(0.35, 0.55, 0.62), 0.35), "y", 20)
	# Trailing plant.
	var pot := EnvUtil.mat(Color(0.9, 0.88, 0.82), 0.5)
	var leaf := EnvUtil.mat(Color(0.3, 0.55, 0.3), 0.7)
	EnvUtil.cyl(n, 1.5, 1.1, 2.6, Vector3(24.5, top, zc), pot, "y", 16)
	for i in 9:
		var t := float(i) / 8.0
		EnvUtil.sphere(n, 0.8 - t * 0.3, Vector3(24.5 + 1.6 + t * 0.6, top + 2.2 - t * 7.0, zc + 1.1), leaf, Vector3(1, 0.8, 0.7), true, 8)
	for i in 5:
		var a := i * 1.3
		EnvUtil.sphere(n, 0.8, Vector3(24.5 + cos(a) * 0.8, top + 3.0, zc + sin(a) * 0.6), leaf, Vector3.ONE, true, 8)


## Steel rail with hanging utensils (behind the right-hand dispensers).
static func _rail(n: Node3D) -> void:
	var steel := EnvUtil.mat(Color(0.78, 0.8, 0.83), 0.25, 0.9)
	var dark := EnvUtil.mat(Color(0.18, 0.17, 0.17), 0.5)
	var wood := EnvUtil.mat(Color(0.55, 0.37, 0.22), 0.6)
	var y := 15.5
	var z := WALL_Z + 1.2
	EnvUtil.cyl(n, 0.2, 0.2, 14.0, Vector3(12.0, y, z), steel, "x", 10)
	for x in [5.4, 18.6]:
		EnvUtil.cyl(n, 0.3, 0.3, 1.2, Vector3(x, y, WALL_Z + 0.6), steel, "z", 10)
	# Ladle
	_hook(n, Vector3(7.0, y, z), steel)
	EnvUtil.box(n, Vector3(0.35, 6.0, 0.2), Vector3(7.0, y - 3.6, z), steel)
	var ladle := EnvUtil.sphere(n, 1.2, Vector3(7.0, y - 6.9, z + 0.3), steel, Vector3(1, 0.7, 1), true, 14)
	ladle.rotation.x = 0.4
	# Spatula
	_hook(n, Vector3(10.4, y, z), steel)
	EnvUtil.box(n, Vector3(0.45, 3.6, 0.3), Vector3(10.4, y - 2.4, z), dark)
	EnvUtil.box(n, Vector3(2.2, 2.6, 0.12), Vector3(10.4, y - 5.4, z), steel)
	# Whisk
	_hook(n, Vector3(13.6, y, z), steel)
	EnvUtil.cyl(n, 0.3, 0.3, 2.8, Vector3(13.6, y - 3.4, z), wood, "y", 8)
	var wh := EnvUtil.sphere(n, 1.1, Vector3(13.6, y - 5.0, z), EnvUtil.mat(Color(0.82, 0.84, 0.86, 0.6), 0.3), Vector3(0.9, 1.9, 0.9), false, 10)
	wh.name = "Whisk"
	# Wooden spoon
	_hook(n, Vector3(16.8, y, z), steel)
	EnvUtil.box(n, Vector3(0.4, 5.0, 0.25), Vector3(16.8, y - 3.1, z), wood)
	EnvUtil.sphere(n, 0.9, Vector3(16.8, y - 6.1, z), wood, Vector3(1, 1.4, 0.45), true, 10)


static func _hook(n: Node3D, at: Vector3, steel: Material) -> void:
	EnvUtil.cyl(n, 0.12, 0.12, 0.9, at - Vector3(0, 0.9, 0), steel, "y", 6)


static func _clock(n: Node3D, at: Vector3) -> void:
	var rim := EnvUtil.mat(Color(0.2, 0.36, 0.4), 0.4)
	var face := EnvUtil.mat(Color(0.98, 0.96, 0.9), 0.6)
	var hand := EnvUtil.mat(Color(0.15, 0.14, 0.14), 0.5)
	EnvUtil.cyl(n, 3.6, 3.6, 0.7, at + Vector3(0, 0, 0.35), rim, "z", 32)
	EnvUtil.cyl(n, 3.1, 3.1, 0.2, at + Vector3(0, 0, 0.75), face, "z", 32, false)
	for i in 12:
		var a := i * TAU / 12.0
		var tick := EnvUtil.box(n, Vector3(0.18, 0.55 if i % 3 == 0 else 0.3, 0.05), at + Vector3(sin(a) * 2.6, cos(a) * 2.6, 0.88), hand, false)
		tick.rotation.z = -a
	var hh := EnvUtil.box(n, Vector3(0.3, 1.7, 0.08), Vector3.ZERO, hand, false)
	hh.transform = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-100)), at + Vector3(0, 0, 0.95)).translated_local(Vector3(0, 0.7, 0))
	var mh := EnvUtil.box(n, Vector3(0.2, 2.5, 0.08), Vector3.ZERO, hand, false)
	mh.transform = Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(-215)), at + Vector3(0, 0, 1.0)).translated_local(Vector3(0, 1.1, 0))
	EnvUtil.cyl(n, 0.25, 0.25, 0.3, at + Vector3(0, 0, 1.05), EnvUtil.mat(Color(0.86, 0.3, 0.2), 0.4), "z", 12, false)


## Tall cream fridge to the left of the counter (x0 = its left side).
static func _fridge(n: Node3D, x0: float, floor_y: float) -> void:
	var body := EnvUtil.mat(Color(0.93, 0.9, 0.84), 0.3)
	var chrome := EnvUtil.mat(Color(0.85, 0.86, 0.88), 0.18, 1.0)
	var w := 25.0
	var zf := WALL_Z + 24.0
	var top := floor_y + 64.0
	EnvUtil.box_mm(n, Vector3(x0, floor_y + 1.5, WALL_Z), Vector3(x0 + w, top, zf - 1.0), body)
	var split := floor_y + 44.0
	EnvUtil.box_mm(n, Vector3(x0 + 0.2, floor_y + 2.0, zf - 1.0), Vector3(x0 + w - 0.2, split - 0.3, zf), body)
	EnvUtil.box_mm(n, Vector3(x0 + 0.2, split + 0.3, zf - 1.0), Vector3(x0 + w - 0.2, top - 0.3, zf), body)
	EnvUtil.box_mm(n, Vector3(x0 + 1.0, floor_y, WALL_Z + 2.0), Vector3(x0 + w - 1.0, floor_y + 1.5, zf - 2.0), EnvUtil.mat(Color(0.12, 0.12, 0.12), 0.8))
	EnvUtil.cyl(n, 0.5, 0.5, 14.0, Vector3(x0 + 2.2, split - 18.0, zf + 1.3), chrome, "y", 12)
	EnvUtil.cyl(n, 0.5, 0.5, 9.0, Vector3(x0 + 2.2, split + 2.0, zf + 1.3), chrome, "y", 12)
	for yy in [split - 4.5, split - 17.5, split + 2.5, split + 10.5]:
		EnvUtil.cyl(n, 0.3, 0.3, 1.3, Vector3(x0 + 2.2, yy, zf + 0.65), chrome, "z", 8)
	# Magnets and a child's drawing.
	var mags := [Color(0.9, 0.3, 0.25), Color(0.25, 0.55, 0.9), Color(0.98, 0.8, 0.2), Color(0.3, 0.75, 0.4)]
	for i in 4:
		EnvUtil.cyl(n, 0.9, 0.9, 0.4, Vector3(x0 + 9.0 + i * 3.6, split - 6.0 - (i % 2) * 3.0, zf + 0.2), EnvUtil.mat(mags[i], 0.4), "z", 12)
	var paper := EnvUtil.box(n, Vector3(7.0, 9.0, 0.1), Vector3(x0 + 15.0, split - 17.0, zf + 0.06), EnvUtil.mat(Color(0.98, 0.97, 0.93), 0.9), false)
	paper.rotation.z = 0.06
	EnvUtil.sphere(n, 1.6, Vector3(x0 + 14.0, split - 16.0, zf + 0.13), EnvUtil.mat(Color(0.98, 0.78, 0.2), 0.9), Vector3(1, 1, 0.02), false)
	EnvUtil.box(n, Vector3(5.0, 1.2, 0.05), Vector3(x0 + 15.0, split - 20.0, zf + 0.13), EnvUtil.mat(Color(0.35, 0.7, 0.35), 0.9), false)
	EnvUtil.cyl(n, 0.9, 0.9, 0.4, Vector3(x0 + 15.0, split - 12.8, zf + 0.25), EnvUtil.mat(mags[0], 0.4), "z", 12)


## Tall painted pantry cabinet to the right of the counter (x1 = its right side).
static func _pantry(n: Node3D, x1: float, floor_y: float) -> void:
	var paint := EnvUtil.mat(EnvCounter.CABINET, 0.55)
	var brass := EnvUtil.mat(EnvCounter.BRASS, 0.3, 0.9)
	var w := 24.0
	var zf := WALL_Z + 21.0
	var top := floor_y + 62.0
	EnvUtil.box_mm(n, Vector3(x1 - w, floor_y + EnvCounter.KICK_H, WALL_Z), Vector3(x1, top, zf), paint)
	EnvUtil.box_mm(n, Vector3(x1 - w + 1.0, floor_y, WALL_Z), Vector3(x1 - 1.0, floor_y + EnvCounter.KICK_H, zf - 2.0), EnvUtil.mat(Color(0.1, 0.1, 0.11), 0.8))
	EnvUtil.box_mm(n, Vector3(x1 - w - 0.6, top, WALL_Z), Vector3(x1 + 0.6, top + 1.2, zf + 0.8), paint)
	var face := EnvUtil.node(n, "PantryFront", Vector3(0, 0, zf))
	var dw := w * 0.5 - 0.4
	var y0 := floor_y + EnvCounter.KICK_H + 0.5
	var y1 := top - 0.5
	for i in 2:
		var cx := x1 - w + 0.25 + dw * 0.5 + i * (dw + 0.3)
		EnvCounter._panel(face, Vector2(cx, (y0 + y1) * 0.5), Vector2(dw, y1 - y0), paint)
		var hx := cx + (1.0 if i == 0 else -1.0) * (dw * 0.5 - 1.4)
		EnvCounter._handle(face, Vector2(hx, floor_y + 32.0), 8.0, true, brass)


static func _floor_plant(n: Node3D, at: Vector3) -> void:
	var pot := EnvUtil.mat(Color(0.74, 0.42, 0.28), 0.8)
	var leaf := EnvUtil.mat(Color(0.28, 0.5, 0.27), 0.65)
	EnvUtil.cyl(n, 5.5, 4.2, 9.0, at, pot, "y", 20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.5, 4.5)
		var h := rng.randf_range(10.0, 24.0)
		var lf := EnvUtil.sphere(n, rng.randf_range(2.2, 3.4), at + Vector3(cos(a) * r, h, sin(a) * r), leaf,
			Vector3(1.6, 0.35, 0.8), true, 10)
		lf.rotation = Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.6, 0.6))
