class_name EnvProps
extends RefCounted
## Scenery visuals: primitive stand-ins for the map's scenery props whose .glb is not present
## (roughly the contract shapes, at the data size), the built-in sink basin, the flat hob, and small
## non-colliding clutter (flour, rings, a puddle, crumbs, sesame seeds, a tea towel).
## Deterministic: fixed seeds only.

const STEEL := Color(0.78, 0.8, 0.83)


## Fallback visual for a scenery entry (base-centre origin, facing +Z).
static func fallback(model: String, sz: Vector3, color: Color) -> Node3D:
	var n := Node3D.new()
	var r := sz.x * 0.5
	var c := EnvUtil.mat(color, 0.5)
	var white := EnvUtil.mat(Color(0.95, 0.95, 0.94), 0.5)
	var steel := EnvUtil.mat(STEEL, 0.25, 0.9)
	var dark := EnvUtil.mat(Color(0.14, 0.13, 0.13), 0.6)
	match model:
		"sink_basin":
			sink_basin(n, sz)
		"sink_tap":
			EnvUtil.cyl(n, 1.2, 1.5, sz.y - 1.0, Vector3(0, 0, -2.5), c)
			EnvUtil.box(n, Vector3(1.4, 1.2, 6.5), Vector3(0, sz.y - 1.0, 0.4), c)
			EnvUtil.cyl(n, 0.5, 0.5, 2.0, Vector3(0, sz.y - 3.2, 3.3), c)
		"ketchup_bottle":
			EnvUtil.cyl(n, r * 0.85, r, sz.y * 0.8, Vector3.ZERO, c)
			EnvUtil.cyl(n, r * 0.35, r * 0.8, sz.y * 0.2, Vector3(0, sz.y * 0.8, 0), white)
		"utensil_pot":
			EnvUtil.cyl(n, r, r * 0.85, sz.y * 0.5, Vector3.ZERO, c)
			EnvUtil.box(n, Vector3(0.5, sz.y * 0.5, 1.2), Vector3(-1.0, sz.y * 0.75, 0), steel)
			EnvUtil.box(n, Vector3(0.5, sz.y * 0.45, 1.6), Vector3(1.0, sz.y * 0.72, 0.5), EnvUtil.mat(Color(0.35, 0.25, 0.18), 0.6))
			EnvUtil.box(n, Vector3(1.8, 0.4, 1.4), Vector3(-1.0, sz.y - 0.2, 0), steel)
		"toaster":
			EnvUtil.box(n, Vector3(sz.x, sz.y * 0.88, sz.z), Vector3(0, sz.y * 0.44, 0), c)
			EnvUtil.box(n, Vector3(sz.x * 0.94, sz.y * 0.1, sz.z * 0.94), Vector3(0, sz.y * 0.91, 0), c)
			for s in [-1.0, 1.0]:
				EnvUtil.box(n, Vector3(sz.x * 0.7, 0.1, 0.9), Vector3(0, sz.y * 0.965, s * sz.z * 0.2), dark)
			EnvUtil.box(n, Vector3(0.9, 0.5, 1.4), Vector3(sz.x * 0.5 + 0.3, sz.y * 0.7, 0), dark)
			EnvUtil.box(n, Vector3(sz.x * 0.9, 0.3, sz.z * 0.9), Vector3(0, 0.15, 0), dark)
		"coffee_mug":
			var mr := sz.z * 0.5
			EnvUtil.cyl(n, mr, mr * 0.95, sz.y, Vector3(-0.25, 0, 0), c, "y", 28)
			EnvUtil.cyl(n, mr * 0.85, mr * 0.85, 0.1, Vector3(-0.25, sz.y - 0.5, 0), EnvUtil.mat(Color(0.28, 0.16, 0.1), 0.15), "y", 28)
			var t := TorusMesh.new()
			t.inner_radius = sz.y * 0.18
			t.outer_radius = sz.y * 0.28
			var h := EnvUtil.mesh(n, t, c, Vector3(mr - 0.1, sz.y * 0.52, 0))
			h.rotation.x = PI * 0.5
		"cookbook_stack":
			var cols := [Color(0.76, 0.28, 0.22), Color(0.22, 0.42, 0.52), Color(0.9, 0.78, 0.4)]
			var y := 0.0
			for i in 3:
				var bh := sz.y / 3.0
				var bk := EnvUtil.box(n, Vector3(sz.x * (0.95 - i * 0.07), bh, sz.z * (0.95 - i * 0.05)), Vector3(0, y + bh * 0.5, 0), EnvUtil.mat(cols[i], 0.7))
				bk.rotation.y = (i - 1) * 0.12
				var pages := EnvUtil.box(n, Vector3(sz.x * (0.93 - i * 0.07), bh * 0.8, sz.z * (0.95 - i * 0.05) + 0.1), Vector3(0.15, y + bh * 0.5, 0), white)
				pages.rotation.y = (i - 1) * 0.12
				y += bh
		"rolling_pin":
			var rr := sz.y * 0.5
			EnvUtil.cyl(n, rr, rr, sz.x * 0.66, Vector3(0, rr, 0), c, "x", 20)
			for s in [-1.0, 1.0]:
				EnvUtil.cyl(n, rr * 0.4, rr * 0.4, sz.x * 0.17, Vector3(s * sz.x * 0.415, rr, 0), c, "x", 12)
		"spice_jar_a", "spice_jar_b", "spice_jar_c":
			EnvUtil.cyl(n, r * 0.85, r * 0.85, sz.y * 0.72, Vector3.ZERO, c, "y", 16)
			EnvUtil.cyl(n, r, r, sz.y * 0.78, Vector3.ZERO, EnvUtil.mat(Color(0.88, 0.94, 0.96, 0.3), 0.05), "y", 16, false)
			EnvUtil.cyl(n, r * 1.02, r * 1.02, sz.y * 0.22, Vector3(0, sz.y * 0.78, 0), dark, "y", 16)
		"kettle":
			var kr := sz.z * 0.5
			EnvUtil.cyl(n, kr * 0.7, kr, sz.y * 0.62, Vector3.ZERO, c, "y", 28)
			EnvUtil.sphere(n, kr * 0.7, Vector3(0, sz.y * 0.62, 0), c, Vector3(1, 0.35, 1), true, 20)
			EnvUtil.sphere(n, 0.4, Vector3(0, sz.y * 0.62 + kr * 0.28, 0), dark, Vector3.ONE, true, 10)
			var arch := TorusMesh.new()
			arch.inner_radius = kr * 0.55
			arch.outer_radius = kr * 0.7
			var hm := EnvUtil.mesh(n, arch, dark, Vector3(0, sz.y * 0.64, 0))
			hm.rotation.x = PI * 0.5
			hm.scale = Vector3(1, 1, 0.9)
			var sp := EnvUtil.cyl(n, 0.3, 0.55, sz.x * 0.35, Vector3(kr + 0.7, sz.y * 0.35, 0), c, "y", 12)
			sp.rotation.z = -0.9
		"oil_bottle":
			EnvUtil.cyl(n, r, r, sz.y * 0.62, Vector3.ZERO, EnvUtil.mat(Color(color, 0.85), 0.08), "y", 20)
			EnvUtil.cyl(n, r * 0.35, r, sz.y * 0.2, Vector3(0, sz.y * 0.62, 0), EnvUtil.mat(Color(color, 0.85), 0.08), "y", 20)
			EnvUtil.cyl(n, r * 0.4, r * 0.4, sz.y * 0.18, Vector3(0, sz.y * 0.82, 0), dark, "y", 12)
		"fruit_bowl":
			var bowl := SphereMesh.new()
			bowl.radius = r
			bowl.height = r
			bowl.is_hemisphere = true
			var bm := EnvUtil.mesh(n, bowl, c, Vector3(0, sz.y * 0.55, 0))
			bm.rotation.x = PI
			bm.scale = Vector3(1, sz.y * 0.55 / r, sz.z / sz.x)
			var fr := [[Vector3(-1.6, 0, -1.0), 1.7, Color(0.96, 0.55, 0.12)], [Vector3(1.5, 0, -1.3), 1.6, Color(0.96, 0.58, 0.14)],
				[Vector3(0.2, 0, 1.4), 1.6, Color(0.78, 0.15, 0.14)], [Vector3(-1.9, 0, 1.6), 1.4, Color(0.55, 0.75, 0.25)],
				[Vector3(0.1, 1.5, -0.2), 1.5, Color(0.95, 0.6, 0.15)]]
			for f in fr:
				EnvUtil.sphere(n, f[1], f[0] + Vector3(0, sz.y * 0.55 + float(f[1]) * 0.55, 0), EnvUtil.mat(f[2], 0.45), Vector3.ONE, true, 14)
			var ban := EnvUtil.mesh(n, CapsuleMesh.new(), EnvUtil.mat(Color(0.98, 0.85, 0.3), 0.6), Vector3(2.2, sz.y * 0.9, 1.2))
			(ban.mesh as CapsuleMesh).radius = 0.6
			(ban.mesh as CapsuleMesh).height = 5.0
			ban.rotation = Vector3(0.2, 0.6, PI * 0.5 - 0.25)
		"dish_sponge":
			EnvUtil.box(n, Vector3(sz.x, sz.y * 0.7, sz.z), Vector3(0, sz.y * 0.35, 0), EnvUtil.mat(Color(0.98, 0.84, 0.3), 0.95))
			EnvUtil.box(n, Vector3(sz.x, sz.y * 0.3, sz.z), Vector3(0, sz.y * 0.85, 0), EnvUtil.mat(Color(0.3, 0.62, 0.35), 0.95))
		"paper_towel_roll":
			var wood := EnvUtil.mat(Color(0.62, 0.43, 0.27), 0.55)
			EnvUtil.cyl(n, r, r, 0.4, Vector3.ZERO, wood, "y", 24)
			EnvUtil.cyl(n, r * 0.85, r * 0.85, sz.y * 0.86, Vector3(0, 0.4, 0), EnvUtil.mat(Color(0.97, 0.97, 0.95), 0.9), "y", 24)
			EnvUtil.cyl(n, r * 0.3, r * 0.3, 0.05, Vector3(0, 0.4 + sz.y * 0.86, 0), EnvUtil.mat(Color(0.6, 0.48, 0.34), 0.9), "y", 12)
			EnvUtil.cyl(n, 0.2, 0.2, sz.y, Vector3.ZERO, wood, "y", 8)
			EnvUtil.sphere(n, 0.45, Vector3(0, sz.y, 0), wood, Vector3.ONE, true, 8)
		_:
			EnvUtil.cyl(n, r, r, sz.y * 0.8, Vector3.ZERO, c)
			EnvUtil.cyl(n, r * 0.9, r, sz.y * 0.2, Vector3(0, sz.y * 0.8, 0), EnvUtil.mat(Color(0.72, 0.74, 0.78), 0.4))
	return n


## Stainless basin sunk into the counter (the slab has a matching hole): raised rim, deep bowl walls,
## soapy water with foam and a dish poking out. The collider (from the data) covers the whole
## footprint up to the foam, so it is a solid obstacle, never a hole.
static func sink_basin(n: Node3D, sz: Vector3) -> void:
	var steel := EnvUtil.mat(STEEL, 0.22, 0.95)
	var inner := EnvUtil.mat(Color(0.7, 0.72, 0.75), 0.35, 0.5)
	var hx := sz.x * 0.5
	var hz := sz.z * 0.5
	var rim := 0.55
	var rh := 0.35
	EnvUtil.box_mm(n, Vector3(-hx, 0, -hz), Vector3(hx, rh, -hz + rim), steel)
	EnvUtil.box_mm(n, Vector3(-hx, 0, hz - rim), Vector3(hx, rh, hz), steel)
	EnvUtil.box_mm(n, Vector3(-hx, 0, -hz + rim), Vector3(-hx + rim, rh, hz - rim), steel)
	EnvUtil.box_mm(n, Vector3(hx - rim, 0, -hz + rim), Vector3(hx, rh, hz - rim), steel)
	var depth := 3.0
	var t := 0.12
	var ix := hx - rim
	var iz := hz - rim
	EnvUtil.box_mm(n, Vector3(-ix, -depth, -iz), Vector3(ix, 0, -iz + t), inner)
	EnvUtil.box_mm(n, Vector3(-ix, -depth, iz - t), Vector3(ix, 0, iz), inner)
	EnvUtil.box_mm(n, Vector3(-ix, -depth, -iz), Vector3(-ix + t, 0, iz), inner)
	EnvUtil.box_mm(n, Vector3(ix - t, -depth, -iz), Vector3(ix, 0, iz), inner)
	EnvUtil.box_mm(n, Vector3(-ix, -depth - 0.1, -iz), Vector3(ix, -depth, iz), inner)
	EnvUtil.plane(n, Vector2(ix * 2.0, iz * 2.0), Vector3(0, -0.55, 0), EnvUtil.shader_mat("sink_water"))
	# Suds: clusters of small flattened bubbles (fixed seed).
	var foam := EnvUtil.mat(Color(0.97, 0.97, 0.97), 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 16:
		var c := Vector3(rng.randf_range(-ix + 0.5, ix - 0.5), -0.55, rng.randf_range(-iz + 0.5, iz - 0.5))
		if c.x > 0.2 and c.z > -0.4:
			continue  # keep a patch of open water under the dish
		EnvUtil.sphere(n, rng.randf_range(0.25, 0.55), c, foam, Vector3(1.0, 0.6, 1.0), false, 8)
	# A small plate leaning in the suds.
	var dish := EnvUtil.cyl(n, 1.1, 1.1, 0.14, Vector3(0.9, -0.35, 0.8), EnvUtil.mat(Color(0.93, 0.93, 0.9), 0.3), "y", 24)
	dish.rotation = Vector3(0.7, 0.4, 0.15)


## Flat glass-ceramic hob (decoration: no collider, chefs walk over it like the griddle).
static func hob(root: Node3D, center: Vector3, size: Vector2) -> void:
	var n := EnvUtil.node(root, "Hob", center)
	EnvUtil.box(n, Vector3(size.x + 0.3, 0.05, size.y + 0.3), Vector3(0, 0.02, 0), EnvUtil.mat(STEEL, 0.25, 0.9), false)
	var glass := EnvUtil.shader_mat("hob_glass", {"size": size, "ring_a": Vector4(-1.3, -1.6, 1.9, 0.0),
		"ring_b": Vector4(2.3, 1.7, 1.6, 1.0), "ring_c": Vector4(-2.6, 2.1, 1.1, 0.0)})
	var p := EnvUtil.plane(n, size, Vector3(0, 0.055, 0), glass)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Small non-colliding clutter for the diner layout (map decor "diner_clutter"). Positions avoid
## station footprints. bounds: the map's surface bounds (the tea towel hangs over the front edge).
static func clutter(root: Node3D, bounds: Rect2) -> void:
	var n := EnvUtil.node(root, "Clutter")
	_decal(n, 0, Vector3(16.6, 0, -3.4), Vector2(5.5, 4.2), Color(0.98, 0.97, 0.94), 0.45, 1.0, 0.4)
	_decal(n, 0, Vector3(-3.2, 0, -6.2), Vector2(3.2, 2.6), Color(0.98, 0.97, 0.94), 0.45, 2.0, -0.3)
	_decal(n, 1, Vector3(15.2, 0, 10.4), Vector2(3.4, 3.4), Color(0.42, 0.26, 0.15), 0.45, 3.0, 0.0)
	_decal(n, 1, Vector3(21.5, 0, 16.2), Vector2(2.6, 2.6), Color(0.42, 0.26, 0.15), 0.3, 4.0, 0.0)
	_decal(n, 2, Vector3(-21.8, 0, -5.4), Vector2(4.8, 3.6), Color(0.55, 0.62, 0.68), 0.35, 5.0, 0.5)
	_decal(n, 1, Vector3(-28.0, 0, 10.2), Vector2(2.6, 2.6), Color(0.6, 0.15, 0.1), 0.35, 6.0, 0.0)
	# Crumbs by the toaster and the bun dispenser; sesame seeds by the buns and near the plate.
	_scatter(n, Vector3(22.8, 0, -1.8), 2.6, 45, 11, Color(0.74, 0.5, 0.26), Vector3(0.22, 0.1, 0.18), Vector3(0.1, 0.05, 0.08))
	_scatter(n, Vector3(-4.0, 0, -6.4), 2.0, 18, 12, Color(0.78, 0.55, 0.28), Vector3(0.2, 0.09, 0.16), Vector3(0.08, 0.04, 0.07))
	_scatter(n, Vector3(-7.0, 0, -6.8), 3.2, 40, 13, Color(0.96, 0.9, 0.72), Vector3(0.16, 0.06, 0.09), Vector3(0.1, 0.04, 0.06))
	_scatter(n, Vector3(-4.6, 0, 11.6), 2.4, 14, 14, Color(0.96, 0.9, 0.72), Vector3(0.16, 0.06, 0.09), Vector3(0.1, 0.04, 0.06))
	_towel(n, Vector3(-8.5, 0, bounds.end.y))


static func _decal(n: Node3D, kind: int, at: Vector3, size: Vector2, tint: Color, opacity: float, seed: float, yaw: float) -> void:
	var p := EnvUtil.plane(n, size, at + Vector3(0, 0.015, 0),
		EnvUtil.shader_mat("counter_decal", {"kind": kind, "tint": tint, "opacity": opacity, "seed": seed}))
	p.rotation.y = yaw


## Many tiny flattened ellipsoids in one MultiMesh.
static func _scatter(n: Node3D, center: Vector3, radius: float, count: int, seed: int, color: Color,
		size_max: Vector3, size_min: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 6
	s.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = s
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var sc := Vector3(rng.randf_range(size_min.x, size_max.x), rng.randf_range(size_min.y, size_max.y), rng.randf_range(size_min.z, size_max.z))
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(sc)
		mm.set_instance_transform(i, Transform3D(b, center + Vector3(cos(a) * d, sc.y * 0.35, sin(a) * d)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = EnvUtil.mat(color, 0.8)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mmi)


## Striped tea towel lying on the counter and hanging over the front edge.
static func _towel(n: Node3D, edge: Vector3) -> void:
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x in 16:
		var col := Color(0.96, 0.94, 0.88)
		if x in [2, 3, 12, 13]:
			col = Color(0.78, 0.26, 0.2)
		elif x in [5, 10]:
			col = Color(0.24, 0.42, 0.52)
		img.set_pixel(x, 0, col)
		img.set_pixel(x, 1, col)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0)
	var t := EnvUtil.node(n, "TeaTowel", edge)
	t.rotation.y = 0.05
	var w := 6.0
	var th := 0.14
	EnvUtil.box_mm(t, Vector3(-w * 0.5, 0.0, -3.2), Vector3(w * 0.5, th, EnvCounter.EDGE_R * -0.2), m, false)
	var bend := EnvUtil.cyl(t, EnvCounter.EDGE_R + th, EnvCounter.EDGE_R + th, w, Vector3(0, -EnvCounter.EDGE_R, -EnvCounter.EDGE_R), m, "x", 12)
	bend.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	EnvUtil.box_mm(t, Vector3(-w * 0.5, -9.5, 0.0), Vector3(w * 0.5, -EnvCounter.EDGE_R, th), m)
	EnvUtil.box_mm(t, Vector3(-w * 0.5, -10.2, -0.1), Vector3(w * 0.5, -9.5, th + 0.05), EnvUtil.mat(Color(0.96, 0.94, 0.88), 0.95))
