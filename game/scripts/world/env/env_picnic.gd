class_name EnvPicnic
extends RefCounted
## Theme "picnic": the whole outdoor set around a map's surfaces. A summer sky (picnic_sky shader,
## soft clouds) with a warm, fairly low sun for long soft shadows; a honey-pine picnic table (plank
## top whose surface is the play area, A-frame legs, bench on both long sides) standing on a lawn
## 29 m below; a rose gingham cloth over the middle of the table that rolls over the front and back
## edges and hangs in folds; grass blades, daisies, dandelions and fallen leaves around the legs;
## stylised trees and a hedge at the horizon; PicnicLife (bee, ants, drifting leaves). Visual only:
## Kitchen builds the colliders. Deterministic: fixed seeds only.

## Direction the sun light travels: from the back-left, about 30 degrees up, so shadows run long
## towards the front-right where the camera sees them.
const SUN_DIR := Vector3(0.62, -0.5, 0.42)
const TOP_T := 1.4          # table top thickness
const PLANKS := 8
const GAP := 0.22           # between top planks
const CLOTH_HX := 21.0      # the cloth covers x -21..21 (the ends stay bare wood)
const DRAPE := 6.8          # how far the cloth hangs below the top
const ROLL_R := 0.4         # cloth roll radius over the edge
const LEG_INSET := 9.0      # A-frames this far in from the table ends
const BENCH_TOP := -11.6    # bench seat height (real proportions: 45 of 76 cm)
const BENCH_IN := 5.0       # bench inner edge this far out from the table edge
const BENCH_W := 9.2

const WOOD_LIGHT := Color(0.80, 0.60, 0.40)
const WOOD_DARK := Color(0.60, 0.41, 0.25)
const IRON := Color(0.22, 0.21, 0.2)

static var _wood_mats: Dictionary = {}


static func build(root: Node3D, map: Dictionary) -> void:
	var surfaces: Array = map["surfaces"]
	var b := GameData.surfaces_bounds(surfaces)
	look(root)
	for r: Rect2 in surfaces:
		table(root, r)
	ground(root, b)
	horizon(root)
	var life := PicnicLife.new()
	life.name = "PicnicLife"
	life.bounds = b
	root.add_child(life)
	if (map.get("decor", []) as Array).has("picnic_clutter"):
		clutter(root, b)


# ================================================================ light + sky

static func look(root: Node3D) -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(EnvUtil.SHADER_DIR + "picnic_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_color = Color(0.9, 0.93, 0.98)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.5
	env.ssao_power = 1.5
	env.ssao_detail = 0.7
	env.ssao_light_affect = 0.1
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.74, 0.85, 0.96)
	env.fog_density = 0.5
	env.fog_depth_begin = 80.0
	env.fog_depth_end = 900.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	var off := EnvLook._debug_off()
	env.ssil_enabled = not off.has("ssil")
	env.ssao_enabled = not off.has("ssao")
	env.glow_enabled = not off.has("glow")
	env.fog_enabled = not off.has("fog")
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 60.0
	attr.dof_blur_far_transition = 40.0
	attr.dof_blur_amount = 0.05
	if not off.has("dof"):
		we.camera_attributes = attr
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(SUN_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.45
	sun.light_angular_distance = 1.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_split_1 = 0.18
	sun.directional_shadow_split_2 = 0.34
	sun.directional_shadow_split_3 = 0.6
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.6, -0.7).normalized(), Vector3.UP), Vector3.ZERO)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.28
	fill.light_specular = 0.1
	fill.shadow_enabled = false
	root.add_child(fill)


# ================================================================ the table

## Wood material for a board of this size (half_size drives the worn edges).
static func wood(size: Vector3) -> ShaderMaterial:
	var key := "%.2f|%.2f|%.2f" % [size.x, size.y, size.z]
	if _wood_mats.has(key):
		return _wood_mats[key]
	var m := EnvUtil.shader_mat("picnic_wood", {"half_size": size * 0.5, "wood_light": WOOD_LIGHT, "wood_dark": WOOD_DARK})
	_wood_mats[key] = m
	return m


## A board: a box whose long side (local X) runs along `along` (grain follows it), `thick_axis` is the
## direction of its thin side. size = (length, width, thickness).
static func board(parent: Node3D, size: Vector3, center: Vector3, along := Vector3.RIGHT, thick_axis := Vector3.UP) -> MeshInstance3D:
	var mi := EnvUtil.box(parent, size, Vector3.ZERO, wood(size))
	var x := along.normalized()
	var z := thick_axis - x * thick_axis.dot(x)
	z = z.normalized()
	var y := z.cross(x)
	# Box local axes: X = length, Y = width, Z = thickness.
	mi.transform = Transform3D(Basis(x, y, z), center)
	return mi


static func table(root: Node3D, r: Rect2) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var c := r.get_center()
	var hx := r.size.x * 0.5
	var hz := r.size.y * 0.5
	var n := EnvUtil.node(root, "PicnicTable", Vector3(c.x, 0, c.y))

	# Top: planks along X with small gaps. (Width along Z = local Y via thick_axis UP.)
	var pw := (r.size.y - GAP * (PLANKS - 1)) / PLANKS
	for i in PLANKS:
		var z0 := -hz + i * (pw + GAP) + pw * 0.5
		board(n, Vector3(r.size.x, pw, TOP_T), Vector3(0, -TOP_T * 0.5, z0), Vector3.RIGHT, Vector3.UP)
	# Dark backing under the gaps so they read as gaps, not holes to the lawn.
	EnvUtil.box_mm(n, Vector3(-hx + 0.4, -TOP_T - 0.05, -hz + 0.4), Vector3(hx - 0.4, -TOP_T * 0.6, hz - 0.4),
		EnvUtil.mat(Color(0.2, 0.14, 0.09), 0.9), false)

	# Cleats under the top (along Z) at the frames and the middle.
	var fx := hx - LEG_INSET
	for x in [-fx, 0.0, fx]:
		board(n, Vector3(r.size.y - 3.0, 1.8, 1.5), Vector3(x, -TOP_T - 0.9, 0), Vector3.BACK, Vector3.RIGHT)

	var bench_y := BENCH_TOP
	var beam_y := bench_y - TOP_T - 1.5
	var reach := hz + BENCH_IN + BENCH_W       # bench outer edge from the centre line
	var iron := EnvUtil.mat(IRON, 0.45, 0.6)
	for sx in [-1.0, 1.0]:
		var x: float = sx * fx
		# A-frame: two legs from under the top out to the lawn.
		for sz in [-1.0, 1.0]:
			var top := Vector3(x + sx * 1.6, -TOP_T - 1.0, sz * 3.2)
			var bot := Vector3(x + sx * 1.6, -ch, sz * (hz + BENCH_IN * 0.4))
			var dir := bot - top
			board(n, Vector3(dir.length() + 1.2, 3.6, 1.5), (top + bot) * 0.5, dir, Vector3.RIGHT)
			# Bolt where the leg meets the bench beam.
			var t := (beam_y - top.y) / dir.y
			var at := top + dir * t
			EnvUtil.cyl(n, 0.45, 0.45, 0.5, at + Vector3(sx * 2.6, 0, 0), iron, "x", 12)
		# Bench beam across both benches, on the outside of the legs.
		board(n, Vector3(reach * 2.0 - 1.0, 3.0, 1.5), Vector3(x + sx * 3.1, beam_y, 0), Vector3.BACK, Vector3.RIGHT)
		# Diagonal brace from the beam's middle up to the middle cleat.
		var b0 := Vector3(x + sx * 1.0, beam_y + 1.0, 0)
		var b1 := Vector3(sx * 4.0, -TOP_T - 1.6, 0)
		board(n, Vector3((b1 - b0).length(), 2.4, 1.3), (b0 + b1) * 0.5, b1 - b0, Vector3.BACK)
		for sz in [-1.0, 1.0]:
			EnvUtil.cyl(n, 0.4, 0.4, 0.5, Vector3(x + sx * 3.9, beam_y, sz * (hz + BENCH_IN + BENCH_W * 0.5)), iron, "x", 12)
	# Benches: two planks each, both long sides.
	var bpw := (BENCH_W - GAP) * 0.5
	for sz in [-1.0, 1.0]:
		for i in 2:
			var z: float = sz * (hz + BENCH_IN + bpw * 0.5 + i * (bpw + GAP))
			board(n, Vector3(r.size.x - 2.0, bpw, TOP_T), Vector3(0, bench_y - TOP_T * 0.5, z), Vector3.RIGHT, Vector3.UP)

	_cloth(n, hz)


## Gingham cloth: flat on the top between x = +-CLOTH_HX, rolling over the front and back edges and
## hanging DRAPE m in soft folds. UV2 = fabric metres for the gingham shader.
static func _cloth(n: Node3D, hz: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 84
	var y0 := 0.006
	# Top: a coarse grid (flat).
	var rows := 20
	for j in rows:
		for i in cols:
			var xa := lerpf(-CLOTH_HX, CLOTH_HX, float(i) / cols)
			var xb := lerpf(-CLOTH_HX, CLOTH_HX, float(i + 1) / cols)
			var za := lerpf(-hz, hz, float(j) / rows)
			var zb := lerpf(-hz, hz, float(j + 1) / rows)
			_quad(st, [Vector3(xa, y0, za), Vector3(xb, y0, za), Vector3(xb, y0, zb), Vector3(xa, y0, zb)],
				[Vector2(xa, za), Vector2(xb, za), Vector2(xb, zb), Vector2(xa, zb)], Vector3.UP)
	# Drapes: rows along the profile (roll over the edge, then the hang).
	for side in [1.0, -1.0]:
		var prof: Array = []   # [out, down, arc] per row
		var arc := 0.0
		var prev := Vector2(0, 0)
		var steps := 22
		for k in steps + 1:
			var p: Vector2
			if k <= 5:
				var a := float(k) / 5.0 * PI * 0.5
				p = Vector2(sin(a) * ROLL_R, -(1.0 - cos(a)) * ROLL_R)
			else:
				var v := float(k - 5) / float(steps - 5)
				p = Vector2(ROLL_R + v * 0.35, -ROLL_R - v * (DRAPE - ROLL_R))
			arc += p.distance_to(prev) if k > 0 else 0.0
			prev = p
			prof.append([p.x, p.y, arc])
		for k in steps:
			for i in cols:
				var q: Array = []
				var uv: Array = []
				for corner in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
					var x := lerpf(-CLOTH_HX, CLOTH_HX, float(corner[0]) / cols)
					var pr: Array = prof[corner[1]]
					var drop := clampf(-float(pr[1]) / DRAPE, 0.0, 1.0)
					var fold := (sin(x * 0.55 + 0.7) * 0.6 + sin(x * 1.37 + 2.1) * 0.22 + sin(x * 0.21 + side) * 0.35) * pow(drop, 1.3)
					var hem := 1.0 if corner[1] < steps else 1.0 + 0.04 * sin(x * 0.43 + side * 2.0)
					var out := float(pr[0]) + fold * 0.9 + drop * 0.2
					var y := float(pr[1]) * hem
					# Ends of the drape fall a little outwards (the cloth corners).
					var edge := clampf((absf(x) - (CLOTH_HX - 3.0)) / 3.0, 0.0, 1.0)
					out += edge * edge * drop * 0.6
					q.append(Vector3(x, y0 + y, side * (hz + out)))
					uv.append(Vector2(x, side * (hz + float(pr[2]))))
				if side < 0.0:
					q = [q[1], q[0], q[3], q[2]]
					uv = [uv[1], uv[0], uv[3], uv[2]]
				_quad(st, q, uv, Vector3.ZERO)
	st.generate_normals()
	var mesh := st.commit()
	var mi := EnvUtil.mesh(n, mesh, EnvUtil.shader_mat("gingham"), Vector3.ZERO)
	mi.name = "Cloth"
	# Hemmed side edges on the top (a hair of thickness).
	var hem_mat := EnvUtil.mat(Color(0.93, 0.88, 0.8), 0.9)
	for sx in [-1.0, 1.0]:
		EnvUtil.box(n, Vector3(0.35, 0.06, hz * 2.0 + 0.6), Vector3(sx * (CLOTH_HX - 0.1), y0 + 0.03, 0), hem_mat, false)


## Two triangles (a, b, c, d counter-clockwise seen from the front). uv2 = fabric metres.
static func _quad(st: SurfaceTool, v: Array, uv: Array, _nrm: Vector3) -> void:
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[idx] / 10.0)
		st.set_uv2(uv[idx])
		st.add_vertex(v[idx])


# ================================================================ the lawn

static func ground(root: Node3D, b: Rect2) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var n := EnvUtil.node(root, "Lawn", Vector3(0, -ch, 0))
	var g := EnvUtil.plane(n, Vector2(1600, 1600), Vector3(b.get_center().x, 0, b.get_center().y), EnvUtil.shader_mat("picnic_grass"))
	g.name = "Grass"
	_blades(n, b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var c := b.get_center()
	_flowers(n, b, rng)
	_lost_things(n, b)
	# Fallen leaves lying in the grass.
	for i in 14:
		var lf := Models.load_model("leaf")
		if lf == null:
			break
		lf.position = Vector3(c.x + rng.randf_range(-70, 70), 0.3, c.y + rng.randf_range(-50, 70))
		lf.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		lf.scale = Vector3.ONE * rng.randf_range(1.2, 2.2)
		n.add_child(lf)


## Things people dropped on the lawn beside the table (seen over the edges): a frisbee, a soda can.
static func _lost_things(n: Node3D, b: Rect2) -> void:
	var c := b.get_center()
	var fr := EnvUtil.node(n, "Frisbee", Vector3(c.x - b.size.x * 0.5 - 12.0, 0, c.y + b.size.y * 0.5 + 22.0))
	fr.rotation = Vector3(0.06, 0.4, -0.04)
	var red := EnvUtil.mat(Color(0.9, 0.3, 0.2), 0.35)
	EnvUtil.cyl(fr, 5.0, 5.2, 0.5, Vector3(0, 0.3, 0), red, "y", 40)
	var rim := TorusMesh.new()
	rim.inner_radius = 4.8
	rim.outer_radius = 5.6
	rim.rings = 40
	rim.ring_segments = 10
	var rm := EnvUtil.mesh(fr, rim, red, Vector3(0, 0.5, 0))
	rm.scale = Vector3(1, 0.6, 1)
	EnvUtil.cyl(fr, 3.0, 3.0, 0.05, Vector3(0, 0.82, 0), EnvUtil.mat(Color(0.98, 0.9, 0.8), 0.4), "y", 32, false)
	var can := EnvUtil.node(n, "SodaCan", Vector3(c.x + b.size.x * 0.5 + 8.0, 2.4, c.y + b.size.y * 0.5 + 14.0))
	can.rotation = Vector3(0, -0.7, 0)
	var tin := EnvUtil.mat(Color(0.2, 0.55, 0.85), 0.3, 0.6)
	var alu := EnvUtil.mat(Color(0.82, 0.83, 0.85), 0.25, 0.9)
	EnvUtil.cyl(can, 2.3, 2.3, 7.4, Vector3.ZERO, tin, "x", 28)
	EnvUtil.cyl(can, 2.35, 2.35, 3.0, Vector3(0.2, 0, 0), EnvUtil.mat(Color(0.97, 0.95, 0.9), 0.4), "x", 28)
	for sx in [-1.0, 1.0]:
		EnvUtil.cyl(can, 1.9, 2.3, 0.5, Vector3(sx * 3.9, 0, 0), alu, "x", 28)


static func _under_table(p: Vector3, b: Rect2) -> bool:
	var reach := b.size.y * 0.5 + BENCH_IN + BENCH_W + 2.0
	return absf(p.x - b.get_center().x) < b.size.x * 0.5 + 3.0 and absf(p.z - b.get_center().y) < reach


## Grass blades around the table: a MultiMesh of curved tapering blades in tufts (grass_blade
## shader, per-blade tint in custom data). At this scale a lawn blade is a few metres tall.
static func _blades(n: Node3D, b: Rect2) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	var tufts := 1700
	var per := 9
	mm.instance_count = tufts * per
	var rng := RandomNumberGenerator.new()
	rng.seed = 1618
	var c := b.get_center()
	var i := 0
	for t in tufts:
		var tc := Vector3(c.x + rng.randf_range(-90, 90), 0, c.y + rng.randf_range(-75, 90))
		var th := rng.randf_range(0.7, 1.3)
		var tint := Color(1, 1, 1).lerp(Color(1.15, 1.1, 0.8), rng.randf() * 0.6) * rng.randf_range(0.8, 1.1)
		for k in per:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 1.6
			var p := tc + Vector3(cos(a) * r, 0, sin(a) * r)
			var h := rng.randf_range(2.0, 4.2) * th
			var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			basis = basis.scaled(Vector3(rng.randf_range(0.8, 1.3), h, h * 0.5))
			mm.set_instance_transform(i, Transform3D(basis, p))
			mm.set_instance_custom_data(i, tint)
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Blades"
	mmi.multimesh = mm
	mmi.material_override = EnvUtil.shader_mat("grass_blade")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mmi)


## One blade, 1 m tall: a tapering strip bending towards +Z, UV.y 0 at the root to 1 at the tip.
static func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [0.0, 0.3, 0.6, 0.85]
	var pts: Array = []
	for y in levels:
		var w: float = 0.2 * pow(1.0 - y, 0.7)
		var z: float = 0.9 * y * y
		pts.append([Vector3(-w, y, z), Vector3(w, y, z), y])
	var tip := Vector3(0, 1.0, 0.9)
	for k in levels.size():
		var a: Array = pts[k]
		var v0: Vector3 = a[0]
		var v1: Vector3 = a[1]
		if k == levels.size() - 1:
			for v in [[v0, a[2]], [v1, a[2]], [tip, 1.0]]:
				st.set_uv(Vector2(0, v[1]))
				st.set_normal(Vector3(0, 0.3, -1).normalized())
				st.add_vertex(v[0])
			continue
		var bb: Array = pts[k + 1]
		for v in [[v0, a[2]], [v1, a[2]], [bb[1], bb[2]], [v0, a[2]], [bb[1], bb[2]], [bb[0], bb[2]]]:
			st.set_uv(Vector2(0, v[1]))
			st.set_normal(Vector3(0, 0.3, -1).normalized())
			st.add_vertex(v[0])
	return st.commit()


## Daisies (white petals round a yellow eye) and dandelions on the lawn, off the table's footprint.
## Three MultiMeshes: stems, petals, flower heads.
static func _flowers(n: Node3D, b: Rect2, rng: RandomNumberGenerator) -> void:
	var c := b.get_center()
	var heads: Array = []   # [pos, tilt basis, daisy?]
	var tries := 0
	while heads.size() < 46 and tries < 600:
		tries += 1
		var p := Vector3(c.x + rng.randf_range(-95, 95), 0, c.y + rng.randf_range(-75, 95))
		if _under_table(p, b):
			continue
		var h := rng.randf_range(4.0, 7.0)
		var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.1, 0.45))
		heads.append([p, h, tilt, rng.randf() < 0.72])
	var stem := CylinderMesh.new()
	stem.top_radius = 0.1
	stem.bottom_radius = 0.14
	stem.height = 1.0
	stem.radial_segments = 5
	stem.rings = 1
	var petal := SphereMesh.new()
	petal.radius = 0.5
	petal.height = 1.0
	petal.radial_segments = 8
	petal.rings = 4
	var eye := SphereMesh.new()
	eye.radius = 0.5
	eye.height = 1.0
	eye.radial_segments = 12
	eye.rings = 6
	var m_stem := _mm(stem, heads.size())
	var m_eye := _mm(eye, heads.size(), true)
	var petals_per := 13
	var m_pet := _mm(petal, heads.size() * petals_per, true)
	for i in heads.size():
		var p: Vector3 = heads[i][0]
		var h: float = heads[i][1]
		var tilt: Basis = heads[i][2]
		var daisy: bool = heads[i][3]
		var top := p + tilt * Vector3(0, h, 0)
		m_stem.set_instance_transform(i, Transform3D(tilt.scaled(Vector3(1, h, 1)), p + tilt * Vector3(0, h * 0.5, 0)))
		var er := 0.55 if daisy else 1.0
		m_eye.set_instance_transform(i, Transform3D(tilt * Basis.from_scale(Vector3(er * 2.0, er * (1.0 if daisy else 1.3), er * 2.0)), top))
		m_eye.set_instance_color(i, Color(1.0, 0.78, 0.15) if daisy else Color(1.0, 0.84, 0.2))
		for k in petals_per:
			var a := k * TAU / petals_per
			var pb := tilt * Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, 0.18)
			var at := top + pb * Vector3(0.95 if daisy else 0.6, 0.02, 0)
			var sc := Vector3(1.5, 0.12, 0.42) if daisy else Vector3(0.9, 0.3, 0.45)
			m_pet.set_instance_transform(i * petals_per + k, Transform3D(pb * Basis.from_scale(sc), at))
			m_pet.set_instance_color(i * petals_per + k, Color(0.98, 0.97, 0.93) if daisy else Color(1.0, 0.8, 0.18))
	var green := EnvUtil.mat(Color(0.3, 0.52, 0.2), 0.8)
	var vc := StandardMaterial3D.new()
	vc.vertex_color_use_as_albedo = true
	vc.roughness = 0.7
	for pair in [[m_stem, green], [m_eye, vc], [m_pet, vc]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = pair[0]
		mmi.material_override = pair[1]
		n.add_child(mmi)


static func _mm(mesh: Mesh, count: int, colors := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	return mm


# ================================================================ the horizon

## Stylised trees (trunk + clustered canopy puffs), a hedge line and soft hills, far behind the table
## (the camera always looks towards -Z).
static func horizon(root: Node3D) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var n := EnvUtil.node(root, "Horizon", Vector3(0, -ch, 0))
	_tree(n, Vector3(-150, 0, -185), 1.0, 11)
	_tree(n, Vector3(165, 0, -250), 1.25, 12)
	_tree(n, Vector3(-330, 0, -300), 1.1, 13)
	# Behind the camera side too (only the menu backdrop looks that way).
	_tree(n, Vector3(-260, 0, 290), 1.15, 14)
	_tree(n, Vector3(330, 0, 380), 1.0, 15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var hedge := [EnvUtil.mat(Color(0.25, 0.42, 0.2), 0.9), EnvUtil.mat(Color(0.3, 0.47, 0.22), 0.9)]
	for side in [-1.0, 1.0]:
		for i in 34:
			var x := -520.0 + i * 32.0 + rng.randf_range(-8, 8)
			var r := rng.randf_range(24, 38)
			var z: float = -430.0 if side < 0.0 else 760.0
			EnvUtil.sphere(n, r, Vector3(x * (1.0 if side < 0.0 else 1.6), r * 0.35, z + rng.randf_range(-20, 20)), hedge[i % 2], Vector3(1.3, 0.8, 1.0), false, 14)
	var hill := EnvUtil.mat(Color(0.42, 0.58, 0.32), 0.95)
	EnvUtil.sphere(n, 600, Vector3(-500, -380, -1300), hill, Vector3(1.6, 1.0, 1.0), false, 32)
	EnvUtil.sphere(n, 700, Vector3(700, -500, -1500), hill, Vector3(1.5, 1.0, 1.0), false, 32)


static func _tree(n: Node3D, at: Vector3, s: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := EnvUtil.mat(Color(0.42, 0.3, 0.2), 0.9)
	var leaves := [Color(0.3, 0.5, 0.22), Color(0.36, 0.56, 0.25), Color(0.26, 0.45, 0.2), Color(0.42, 0.6, 0.28)]
	var t := EnvUtil.node(n, "Tree", at)
	t.scale = Vector3.ONE * s
	EnvUtil.cyl(t, 5.5, 9.0, 105.0, Vector3.ZERO, bark, "y", 10, false)
	for k in 3:
		var br := EnvUtil.cyl(t, 2.0, 4.0, 40.0, Vector3(0, 70 + k * 10, 0), bark, "y", 8, false)
		br.rotation = Vector3(0, k * 2.2, 0.8)
		br.position += Vector3(0, 12, 0)
	var puffs := 9
	for k in puffs:
		var a := k * TAU / puffs + rng.randf_range(-0.3, 0.3)
		var rr := rng.randf_range(20, 42)
		var r := rng.randf_range(30, 46)
		var y := rng.randf_range(115, 165)
		EnvUtil.sphere(t, r, Vector3(cos(a) * rr, y, sin(a) * rr * 0.8), EnvUtil.mat(leaves[k % leaves.size()], 0.85),
			Vector3(1.0, 0.85, 1.0), false, 14)
	EnvUtil.sphere(t, 48, Vector3(0, 175, 0), EnvUtil.mat(leaves[3], 0.85), Vector3(1.1, 0.8, 1.0), false, 16)
	# Soft shade on the grass under it.
	EnvUtil.plane(t, Vector2(150, 150), Vector3(12, 0.2, 10), EnvUtil.shader_mat("counter_decal", {"kind": 4, "opacity": 0.25}))


# ================================================================ table clutter

## Non-colliding dressing on the table (map decor "picnic_clutter"): leaves that blew in, a paper
## napkin, crumbs by the buns, a lemonade ring by the jug.
static func clutter(root: Node3D, b: Rect2) -> void:
	var n := EnvUtil.node(root, "PicnicClutter")
	var spots := [[Vector3(16.5, 0.03, 7.0), 0.6, 1.4], [Vector3(-3.5, 0.03, -8.5), 2.2, 1.2], [Vector3(-22.8, 0.03, -2.6), 4.0, 1.5]]
	for s in spots:
		var lf := Models.load_model("leaf")
		if lf == null:
			break
		lf.position = s[0]
		lf.rotation.y = s[1]
		lf.scale = Vector3(s[2], 0.5, s[2])
		n.add_child(lf)
	# Folded paper napkin, front-centre.
	var napkin := EnvUtil.node(n, "Napkin", Vector3(0.5, 0, b.end.y - 3.2))
	napkin.rotation.y = 0.35
	var paper := EnvUtil.mat(Color(0.98, 0.97, 0.94), 0.95)
	EnvUtil.box(napkin, Vector3(4.2, 0.06, 4.2), Vector3(0, 0.04, 0), paper, false)
	var flap := EnvUtil.box(napkin, Vector3(2.9, 0.05, 2.9), Vector3(0.4, 0.1, 0.4), EnvUtil.mat(Color(0.94, 0.93, 0.9), 0.95), false)
	flap.rotation.y = PI * 0.25
	EnvProps._scatter(n, Vector3(1.5, 0, -12.2), 2.2, 22, 21, Color(0.78, 0.55, 0.28), Vector3(0.2, 0.09, 0.16), Vector3(0.08, 0.04, 0.07))
	EnvProps._scatter(n, Vector3(-9.0, 0, 16.5), 1.8, 12, 22, Color(0.96, 0.9, 0.72), Vector3(0.16, 0.06, 0.09), Vector3(0.1, 0.04, 0.06))
	EnvProps._decal(n, 1, Vector3(21.0, 0, -18.2), Vector2(3.6, 3.6), Color(0.85, 0.7, 0.2), 0.35, 8.0, 0.0)
