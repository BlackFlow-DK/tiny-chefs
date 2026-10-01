class_name EnvIslands
extends RefCounted
## Twin-islands dressing (map decor "island_sink" / "islands_clutter", surface style "plank"):
## - plank(): a thick butcher-block cutting board bridging the gap, top flush with the counters,
##   thin rebated lips resting on both islands, nothing under it. Visual only: Kitchen builds its
##   thin collider (PLANK_T).
## - double_sink(): a big stainless double sink filling the gap between the islands under the plank:
##   steel walls recessed under the slab ends, an apron front, a divider under the plank, deep opaque
##   soapy water (so anything that drops off the plank goes "into the sink"), suds, a rubber duck,
##   dishes, a wall-mounted gooseneck tap in front of the window, and a sink-base cabinet below.
##   No colliders: falls work exactly as off any other edge.
## - clutter(): flat decals / crumbs placed for the twin_islands layout.
## _SinkFx (a child node) animates the tap drip + water rings and the duck, and splashes where food
## or a chef drops into the water (reads World.items / World.chefs; host and clients alike).

const PLANK_T := 1.4          # board thickness under the walking surface (and its collider)
const PLANK_TOP := 0.1        # the visual board top sits this far above y = 0 (lips resting on the slab)
const LIP := 2.0              # how far the board rests on each island
const WATER_Y := -3.3         # just under BoundsSystem's -3.0 removal line, so food vanishes at the surface
const FLOOR_Y := -9.6         # basin floor (under the opaque water) = top of the sink-base cabinet
const RIM_Y := -0.25
const WALL_IN := 0.1          # steel side walls sit this far under the slab ends
const STEEL := Color(0.80, 0.82, 0.85)
const CHROME := Color(0.9, 0.91, 0.93)


# ---------------------------------------------------------------- plank

## Board for surface r (x, z, w, h); the long axis runs along X. gap: the X span (x0, x1) of r that
## no counter holds up (the board hangs there, full thickness, centred on the gap); on each side a
## thin lip rests LIP on the counter. Where r reaches further onto a counter (a bot approach lane)
## nothing more is drawn.
static func plank(root: Node3D, r: Rect2, gap: Vector2) -> void:
	var c := Vector2((gap.x + gap.y) * 0.5, r.get_center().y)
	var hz := r.size.y * 0.5
	var g0 := gap.x - c.x
	var g1 := gap.y - c.x
	var l0 := g0 - LIP
	var l1 := g1 + LIP
	var n := EnvUtil.node(root, "Plank", Vector3(c.x, 0, c.y))
	var top := PLANK_TOP
	var mat := EnvUtil.shader_mat("plank_wood", {"half_size": Vector2(maxf(-l0, l1), hz)})
	# Body across the gap (reaching a little under the slab edges, hidden there).
	var bt := 0.14
	var bb := 0.28
	var body := PackedVector2Array([Vector2(-hz, -PLANK_T + bb), Vector2(-hz + bb, -PLANK_T), Vector2(hz - bb, -PLANK_T),
		Vector2(hz, -PLANK_T + bb), Vector2(hz, top - bt), Vector2(hz - bt, top), Vector2(-hz + bt, top), Vector2(-hz, top - bt)])
	_prism(n, g0 - 0.3, g1 + 0.3, body, mat)
	# Rebated lips resting on each island, ends rounded off by a bevel.
	var lb := 0.05
	var lip := PackedVector2Array([Vector2(-hz, 0.0), Vector2(hz, 0.0), Vector2(hz, top - lb), Vector2(hz - lb, top),
		Vector2(-hz + lb, top), Vector2(-hz, top - lb)])
	_prism(n, l0, g0, lip, mat)
	_prism(n, g1, l1, lip, mat)
	# Soft contact shadow where the lips sit on the terrazzo.
	var ao := EnvUtil.shader_mat("counter_decal", {"kind": 4, "opacity": 0.35})
	for span in [Vector2(l0, g0), Vector2(g1, l1)]:
		var p := EnvUtil.plane(n, Vector2(r.size.y + 0.8, span.y - span.x + 0.9), Vector3((span.x + span.y) * 0.5, 0.012, 0), ao)
		p.rotation.y = PI * 0.5


## Flat-shaded prism along local X (x0..x1) with a convex cross-section poly (z, y), capped.
static func _prism(n: Node3D, x0: float, x1: float, poly: PackedVector2Array, mat: Material, shadows := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := poly.size()
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(m)
	for i in m:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % m]
		var nrm := Vector3(0, -(b.x - a.x), b.y - a.y).normalized()
		var mid := (a + b) * 0.5 - cen
		if Vector3(0, mid.y, mid.x).dot(nrm) < 0.0:
			nrm = -nrm
		var p0 := Vector3(x0, a.y, a.x)
		var p1 := Vector3(x1, a.y, a.x)
		var p2 := Vector3(x1, b.y, b.x)
		var p3 := Vector3(x0, b.y, b.x)
		_tri(st, p0, p1, p2, nrm)
		_tri(st, p0, p2, p3, nrm)
	for side in [[x0, Vector3(-1, 0, 0)], [x1, Vector3(1, 0, 0)]]:
		var x: float = side[0]
		var cc := Vector3(x, cen.y, cen.x)
		for i in m:
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % m]
			_tri(st, cc, Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), side[1])
	return EnvUtil.mesh(n, st.commit(), mat, Vector3.ZERO, shadows)


## One triangle facing along nrm (Godot front faces wind clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3) -> void:
	if (b - a).cross(c - a).dot(nrm) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(v)


# ---------------------------------------------------------------- sink

## Double sink filling gap (x, z, w, h: the strip between the islands, full counter depth).
## wall_z: the room's back wall face (the tap is mounted on it).
static func double_sink(root: Node3D, gap: Rect2, wall_z: float) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var hx := gap.size.x * 0.5
	var z0 := gap.position.y
	var z1 := gap.end.y
	var n := EnvUtil.node(root, "DoubleSink", Vector3(gap.get_center().x, 0, 0))
	var steel := EnvUtil.mat(STEEL, 0.26, 0.9)
	var inner := EnvUtil.mat(Color(0.64, 0.67, 0.7), 0.34, 0.85)
	var wx := hx + WALL_IN
	var ov := EnvCounter.OVERHANG
	var apron_z := z1 - ov + 0.6       # flush with the cabinet door frames
	var apron_bot := FLOOR_Y

	# Basin walls: sides under the slab ends, back against the wall, divider under the plank.
	for s in [-1.0, 1.0]:
		EnvUtil.box_mm(n, Vector3(minf(s * wx, s * (wx + 0.15)), FLOOR_Y, z0), Vector3(maxf(s * wx, s * (wx + 0.15)), -EnvCounter.SLAB_T, apron_z), inner)
	EnvUtil.box_mm(n, Vector3(-wx, FLOOR_Y, z0), Vector3(wx, RIM_Y, z0 + 0.15), inner)
	EnvUtil.cyl(n, 0.16, 0.16, hx * 2.0, Vector3(0, RIM_Y, z0 + 0.12), steel, "x", 12)
	EnvUtil.box_mm(n, Vector3(-wx, FLOOR_Y, -0.3), Vector3(wx, -2.4, 0.3), inner)
	EnvUtil.cyl(n, 0.3, 0.3, wx * 2.0, Vector3(0, -2.4, 0), steel, "x", 16)

	# Apron front (farmhouse style) with a rolled rim and two pressed lines, then the base cabinet.
	EnvUtil.box_mm(n, Vector3(-hx - ov, apron_bot, apron_z - 0.3), Vector3(hx + ov, RIM_Y, apron_z), steel)
	EnvUtil.cyl(n, 0.22, 0.22, hx * 2.0, Vector3(0, RIM_Y, apron_z - 0.15), steel, "x", 16)
	var line := EnvUtil.mat(STEEL.darkened(0.25), 0.3, 0.9)
	for y in [RIM_Y - 1.1, apron_bot + 0.9]:
		EnvUtil.box(n, Vector3((hx + ov) * 2.0 - 1.2, 0.12, 0.05), Vector3(0, y, apron_z + 0.02), line, false)
	EnvUtil.box_mm(n, Vector3(-hx - ov, apron_bot - 0.25, apron_z - 0.4), Vector3(hx + ov, apron_bot, apron_z + 0.05),
		EnvUtil.mat(EnvCounter.WALNUT, 0.45))
	_base_cabinet(n, hx, z0, z1, apron_bot - 0.25, ch)

	# Water, suds and what's in it.
	var water := EnvUtil.shader_mat("island_sink_water", {
		"bowl": Vector4(gap.get_center().x - wx, z0 + 0.15, gap.get_center().x + wx, apron_z - 0.3),
		"drip_pos": Vector2(gap.get_center().x, wall_z + 6.8)})
	var wz0 := z0 + 0.15
	var wz1 := apron_z - 0.3
	var wp := EnvUtil.plane(n, Vector2(wx * 2.0, wz1 - wz0), Vector3(0, WATER_Y, (wz0 + wz1) * 0.5), water)
	wp.name = "Water"
	_suds(n, wx, wz0, wz1)
	var duck := _duck(n, Vector3(-1.7, WATER_Y, 8.2))
	_dishes(n)
	var drop := _tap(n, wall_z)
	_towel(n, Vector3(2.3, RIM_Y, apron_z - 0.15))

	var fx := _SinkFx.new()
	fx.name = "SinkFx"
	fx.water = water
	fx.duck = duck
	fx.drop = drop
	fx.drop_top = drop.position.y
	fx.area = Rect2(gap.position.x - WALL_IN, z0, gap.size.x + WALL_IN * 2.0, apron_z - z0)
	fx.world = root as World
	n.add_child(fx)


## Painted sink-base cabinet under the apron (two doors), continuing the islands' cabinet line.
static func _base_cabinet(n: Node3D, hx: float, z0: float, z1: float, top_y: float, ch: float) -> void:
	var ov := EnvCounter.OVERHANG
	var paint := EnvUtil.mat(EnvCounter.CABINET, 0.55)
	var brass := EnvUtil.mat(EnvCounter.BRASS, 0.3, 0.9)
	var face_z := z1 - ov
	EnvUtil.box_mm(n, Vector3(-hx - ov, -ch + EnvCounter.KICK_H, z0), Vector3(hx + ov, top_y, face_z), paint)
	EnvUtil.box_mm(n, Vector3(-hx - EnvCounter.KICK_IN, -ch, z0), Vector3(hx + EnvCounter.KICK_IN, -ch + EnvCounter.KICK_H, z1 - EnvCounter.KICK_IN),
		EnvUtil.mat(Color(0.1, 0.1, 0.11), 0.8))
	var front := EnvUtil.node(n, "SinkFront", Vector3(0, 0, face_z))
	var span := (hx + ov) * 2.0 - 0.6
	var gap := 0.35
	var y_top := top_y - 0.35
	var y_bot := -ch + EnvCounter.KICK_H + 0.35
	var dw := (span - gap) * 0.5
	for side in [-1.0, 1.0]:
		var cx: float = side * (dw * 0.5 + gap * 0.5)
		EnvCounter._door(front, Vector2(cx, (y_top + y_bot) * 0.5), Vector2(dw, y_top - y_bot), paint, brass, -side)


static func _suds(n: Node3D, wx: float, wz0: float, wz1: float) -> void:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	var spots: Array = []   # [centre, radius, count]
	for zc in [wz0 + 0.6, -0.9, 0.9, wz1 - 0.6]:
		for xs in [-1.0, 1.0]:
			spots.append([Vector2(xs * (wx - 0.6), zc), 1.1, 12])
	spots.append([Vector2(-2.5, wz0 + 2.0), 1.8, 30])   # a mound in the back bowl
	spots.append([Vector2(0.6, -8.4), 1.2, 12])        # around the drip
	spots.append([Vector2(2.6, 5.2), 1.1, 12])
	spots.append([Vector2(-2.9, 12.6), 1.0, 10])
	var total := 0
	for sp in spots:
		total += int(sp[2])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = s
	mm.instance_count = total
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var i := 0
	for sp in spots:
		var c: Vector2 = sp[0]
		var rad: float = sp[1]
		for k in int(sp[2]):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * rad
			var p := c + Vector2(cos(a), sin(a)) * d
			p.x = clampf(p.x, -wx + 0.2, wx - 0.2)
			p.y = clampf(p.y, wz0 + 0.2, wz1 - 0.2)
			var size := rng.randf_range(0.12, 0.42) * (1.0 - d / rad * 0.5)
			var h := size * rng.randf_range(0.45, 0.8) * (1.0 + (1.0 - d / rad) * 0.6)
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(size, h, size) * 2.0), Vector3(p.x, WATER_Y + h * 0.25, p.y)))
			i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Suds"
	mmi.multimesh = mm
	mmi.material_override = EnvUtil.mat(Color(0.97, 0.97, 0.98), 0.6)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mmi)


static func _duck(n: Node3D, at: Vector3) -> Node3D:
	var d := EnvUtil.node(n, "RubberDuck", at)
	d.rotation.y = 0.7
	var yellow := EnvUtil.mat(Color(1.0, 0.8, 0.12), 0.35)
	var orange := EnvUtil.mat(Color(0.98, 0.45, 0.1), 0.4)
	var black := EnvUtil.mat(Color(0.05, 0.05, 0.05), 0.2)
	EnvUtil.sphere(d, 0.8, Vector3(0, 0.2, 0), yellow, Vector3(1.3, 0.75, 1.0), true, 18)
	EnvUtil.sphere(d, 0.35, Vector3(-0.95, 0.55, 0), yellow, Vector3(1.0, 0.8, 0.9), true, 10)
	EnvUtil.sphere(d, 0.5, Vector3(0.62, 0.95, 0), yellow, Vector3.ONE, true, 16)
	EnvUtil.sphere(d, 0.26, Vector3(1.08, 0.88, 0), orange, Vector3(1.3, 0.45, 1.0), true, 10)
	for s in [-1.0, 1.0]:
		EnvUtil.sphere(d, 0.075, Vector3(0.95, 1.08, s * 0.24), black, Vector3.ONE, false, 8)
	return d


static func _dishes(n: Node3D) -> void:
	# Two plates leaning in the back bowl, half under the suds.
	var china := EnvUtil.mat(Color(0.95, 0.95, 0.92), 0.25)
	var blue := EnvUtil.mat(Color(0.3, 0.5, 0.66), 0.3)
	for k in 2:
		var pl := EnvUtil.node(n, "SoakingPlate", Vector3(1.2 + k * 0.5, WATER_Y + 0.25, -6.4 + k * 0.7))
		pl.rotation = Vector3(0.55 + k * 0.1, 0.35 - k * 0.25, 0.1)
		EnvUtil.cyl(pl, 1.55, 1.0, 0.28, Vector3.ZERO, china, "y", 28)
		var band := TorusMesh.new()
		band.inner_radius = 1.3
		band.outer_radius = 1.45
		band.rings = 28
		var bm := EnvUtil.mesh(pl, band, blue, Vector3(0, 0.29, 0), false)
		bm.scale = Vector3(1, 0.25, 1)
	# A teal mixing bowl bobbing low in the front bowl, suds inside, a wooden spoon leaning out.
	var bowl := EnvUtil.node(n, "MixingBowl", Vector3(2.0, WATER_Y - 0.55, 10.6))
	bowl.rotation = Vector3(0.22, 0.4, -0.15)
	var hemi := SphereMesh.new()
	hemi.radius = 1.6
	hemi.height = 1.6
	hemi.is_hemisphere = true
	hemi.radial_segments = 28
	hemi.rings = 10
	var bm2 := EnvUtil.mesh(bowl, hemi, EnvUtil.mat(Color(0.33, 0.62, 0.62), 0.3), Vector3(0, 1.1, 0))
	bm2.rotation.x = PI
	bm2.scale = Vector3(1, 0.7, 1)
	var lip := TorusMesh.new()
	lip.inner_radius = 1.48
	lip.outer_radius = 1.68
	lip.rings = 28
	EnvUtil.mesh(bowl, lip, EnvUtil.mat(Color(0.93, 0.91, 0.85), 0.3), Vector3(0, 1.1, 0))
	EnvUtil.cyl(bowl, 1.4, 1.4, 0.05, Vector3(0, 0.75, 0), EnvUtil.mat(Color(0.97, 0.97, 0.98), 0.7), "y", 24, false)
	var wood := EnvUtil.mat(Color(0.72, 0.52, 0.32), 0.6)
	var a := bowl.transform * Vector3(-0.4, 0.8, 0.2)
	var b := a + Vector3(-0.9, 2.6, 1.1)
	_tube(n, [a, b], 0.13, wood, 8)
	EnvUtil.sphere(n, 0.42, a + (a - b).normalized() * 0.2, wood, Vector3(1.0, 1.0, 0.5), true, 10)


## Wall-mounted gooseneck bridge tap arching over the back bowl. Returns the drip droplet.
static func _tap(n: Node3D, wall_z: float) -> MeshInstance3D:
	var chrome := EnvUtil.mat(CHROME, 0.18, 0.7)
	var base_y := 2.6
	var riser_z := wall_z + 2.0
	var top_y := 9.5
	var arc_r := 2.4
	var pts: Array = [Vector3(0, base_y, wall_z), Vector3(0, base_y, wall_z + 1.3)]
	for i in range(1, 7):
		var a := float(i) / 6.0 * PI * 0.5
		pts.append(Vector3(0, base_y + 0.7 - 0.7 * cos(a), wall_z + 1.3 + 0.7 * sin(a)))
	pts.append(Vector3(0, top_y, riser_z))
	var zc := riser_z + arc_r
	for i in range(1, 19):
		var a := float(i) / 18.0 * PI
		pts.append(Vector3(0, top_y + arc_r * sin(a), zc - arc_r * cos(a)))
	var tip_y := top_y - 1.0
	pts.append(Vector3(0, tip_y, zc + arc_r))
	_tube(n, pts, 0.3, chrome)
	EnvUtil.cyl(n, 0.4, 0.4, 0.45, Vector3(0, tip_y - 0.35, zc + arc_r), chrome, "y", 16)
	EnvUtil.cyl(n, 0.3, 0.3, 0.06, Vector3(0, tip_y - 0.38, zc + arc_r), EnvUtil.mat(Color(0.3, 0.3, 0.32), 0.5), "y", 12, false)
	# Escutcheon on the tiles, a mixing body on the riser with two cross handles.
	EnvUtil.cyl(n, 0.85, 0.85, 0.25, Vector3(0, base_y, wall_z + 0.12), chrome, "z", 24)
	var hy := 5.2
	EnvUtil.cyl(n, 0.42, 0.42, 1.2, Vector3(0, hy - 0.6, riser_z), chrome, "y", 16)
	EnvUtil.cyl(n, 0.22, 0.22, 2.6, Vector3(0, hy, riser_z), chrome, "x", 12)
	var porcelain := EnvUtil.mat(Color(0.97, 0.96, 0.93), 0.3)
	var tint := [EnvUtil.mat(Color(0.8, 0.2, 0.18), 0.3), EnvUtil.mat(Color(0.2, 0.42, 0.8), 0.3)]
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hub := Vector3(s * 1.35, hy, riser_z)
		EnvUtil.cyl(n, 0.3, 0.3, 0.5, hub + Vector3(0, -0.05, 0), chrome, "y", 12)
		for k in [0, 2]:
			var arm := EnvUtil.cyl(n, 0.1, 0.1, 1.3, hub + Vector3(0, 0.3, 0), chrome, "x", 8)
			arm.rotation = Vector3(0, float(k) * PI * 0.25, PI * 0.5)
			for e in [-1.0, 1.0]:
				EnvUtil.sphere(n, 0.14, hub + Vector3(e * cos(k * PI * 0.25) * 0.65, 0.3, -e * sin(k * PI * 0.25) * 0.65), chrome, Vector3.ONE, true, 8)
		EnvUtil.cyl(n, 0.22, 0.22, 0.14, hub + Vector3(0, 0.42, 0), porcelain, "y", 12)
		EnvUtil.cyl(n, 0.12, 0.12, 0.05, hub + Vector3(0, 0.56, 0), tint[i], "y", 10, false)
	var water_drop := EnvUtil.mat(Color(0.8, 0.9, 0.97, 0.7), 0.05)
	var drop := EnvUtil.sphere(n, 0.12, Vector3(0, tip_y - 0.5, zc + arc_r), water_drop, Vector3(1, 1.4, 1), false, 8)
	drop.name = "Drip"
	return drop


## Round tube swept along pts (the path lies in the local YZ plane), end caps as spheres.
static func _tube(n: Node3D, pts: Array, r: float, mat: Material, seg := 14) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var norms: Array = []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var t: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector3(1, 0, 0)
		var up := t.cross(side).normalized()
		var ring: Array = []
		var nr: Array = []
		for k in seg:
			var a := float(k) / seg * TAU
			var d := side * cos(a) + up * sin(a)
			ring.append(p + d * r)
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in pts.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i + 1][k]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i][k2]
			var na: Vector3 = norms[i][k]
			var nb: Vector3 = norms[i + 1][k]
			var nc: Vector3 = norms[i + 1][k2]
			var nd: Vector3 = norms[i][k2]
			var face: Vector3 = (na + nb + nc + nd).normalized()
			for tri in [[a, na, b, nb, c, nc], [a, na, c, nc, d, nd]]:
				var v0: Vector3 = tri[0]
				var v1: Vector3 = tri[2]
				var v2: Vector3 = tri[4]
				var order := [0, 2, 4] if (v1 - v0).cross(v2 - v0).dot(face) < 0.0 else [0, 4, 2]
				for o in order:
					st.set_normal(tri[o + 1])
					st.add_vertex(tri[o])
	EnvUtil.mesh(n, st.commit(), mat, Vector3.ZERO, true)
	EnvUtil.sphere(n, r, pts[pts.size() - 1], mat, Vector3.ONE, true, 12)


## Striped tea towel hung over the apron rim.
static func _towel(n: Node3D, rim: Vector3) -> void:
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x in 16:
		var col := Color(0.96, 0.94, 0.88)
		if x in [2, 3, 12, 13]:
			col = Color(0.24, 0.42, 0.52)
		elif x in [6, 9]:
			col = Color(0.78, 0.26, 0.2)
		img.set_pixel(x, 0, col)
		img.set_pixel(x, 1, col)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 5.0, 1.0 / 5.0, 1.0 / 5.0)
	var t := EnvUtil.node(n, "SinkTowel", rim)
	t.rotation.y = -0.04
	var w := 5.0
	var th := 0.14
	var r := 0.22 + th
	var bend := EnvUtil.cyl(t, r, r, w, Vector3.ZERO, m, "x", 14)
	bend.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	EnvUtil.box_mm(t, Vector3(-w * 0.5, -7.8, 0.15), Vector3(w * 0.5, 0.0, 0.15 + th), m)
	EnvUtil.box_mm(t, Vector3(-w * 0.5, -1.6, -0.4 - th), Vector3(w * 0.5, 0.0, -0.4), m)
	EnvUtil.box_mm(t, Vector3(-w * 0.5, -8.4, 0.1), Vector3(w * 0.5, -7.8, 0.2 + th + 0.05), EnvUtil.mat(Color(0.96, 0.94, 0.88), 0.95))


# ---------------------------------------------------------------- clutter

## Flat, non-colliding clutter for the twin_islands layout (decor "islands_clutter").
static func clutter(root: Node3D) -> void:
	var n := EnvUtil.node(root, "IslandsClutter")
	EnvProps._decal(n, 0, Vector3(-19.2, 0, -5.4), Vector2(5.0, 3.8), Color(0.98, 0.97, 0.94), 0.4, 1.0, 0.3)
	EnvProps._decal(n, 0, Vector3(-22.4, 0, 12.8), Vector2(3.4, 2.8), Color(0.98, 0.97, 0.94), 0.4, 2.0, -0.4)
	EnvProps._decal(n, 2, Vector3(-5.6, 0, -6.2), Vector2(3.0, 2.4), Color(0.55, 0.62, 0.68), 0.35, 5.0, 0.4)
	EnvProps._decal(n, 2, Vector3(5.5, 0, 13.3), Vector2(2.8, 2.6), Color(0.55, 0.62, 0.68), 0.35, 6.0, -0.2)
	EnvProps._decal(n, 2, Vector3(5.2, 0, -5.8), Vector2(2.2, 1.8), Color(0.55, 0.62, 0.68), 0.3, 7.0, 0.0)
	EnvProps._decal(n, 1, Vector3(24.6, 0, -5.2), Vector2(3.2, 3.2), Color(0.42, 0.26, 0.15), 0.4, 3.0, 0.0)
	EnvProps._decal(n, 1, Vector3(26.8, 0, 11.4), Vector2(2.6, 2.6), Color(0.6, 0.15, 0.1), 0.3, 4.0, 0.0)
	EnvProps._scatter(n, Vector3(15.5, 0, -5.4), 2.2, 30, 21, Color(0.96, 0.9, 0.72), Vector3(0.16, 0.06, 0.09), Vector3(0.1, 0.04, 0.06))
	EnvProps._scatter(n, Vector3(15.4, 0, 12.9), 2.0, 30, 22, Color(0.74, 0.5, 0.26), Vector3(0.22, 0.1, 0.18), Vector3(0.1, 0.05, 0.08))
	EnvProps._scatter(n, Vector3(-13.2, 0, 1.2), 2.4, 16, 23, Color(0.55, 0.4, 0.24), Vector3(0.2, 0.1, 0.16), Vector3(0.1, 0.05, 0.08))


# ---------------------------------------------------------------- fx

## Tap drip + rings, a bobbing duck, and splashes where food or chefs drop into the water.
class _SinkFx extends Node3D:
	const PERIOD := 2.8
	const FALL := 0.55
	var water: ShaderMaterial
	var duck: Node3D
	var drop: MeshInstance3D
	var drop_top := 0.0
	var area := Rect2()
	var world: World
	var _t := 0.0
	var _seen: Dictionary = {}       # item id -> last global position while over the sink
	var _chef_y: Dictionary = {}     # peer id -> last y
	var _splashes: Array = []        # [node, age, droplets: Array of [mesh, velocity]]

	func _process(delta: float) -> void:
		_t += delta
		var ph := fmod(_t, PERIOD)
		if ph < FALL:
			var f := ph / FALL
			drop.visible = true
			drop.position.y = lerpf(drop_top, EnvIslands.WATER_Y, f * f)
			water.set_shader_parameter("drip_t", 0.0)
		else:
			drop.visible = false
			water.set_shader_parameter("drip_t", clampf((ph - FALL) / 1.8, 0.0, 1.0))
		if duck != null:
			duck.position.y = EnvIslands.WATER_Y - 0.05 + sin(_t * 1.4) * 0.07
			duck.rotation.z = sin(_t * 1.1) * 0.05
			duck.rotation.y = 0.7 + sin(_t * 0.23) * 0.4
		if world != null:
			_watch_world()
		_step_splashes(delta)

	func _watch_world() -> void:
		var local := Vector3(global_position.x, 0, 0)
		var still: Dictionary = {}
		for id in world.items:
			var it: Variant = world.items[id]
			if not is_instance_valid(it):
				continue
			var p: Vector3 = (it as Node3D).global_position
			if area.has_point(Vector2(p.x, p.z)) and p.y < 0.4:
				still[id] = p
		for id in _seen:
			if not still.has(id) and not world.items.has(id):
				var p: Vector3 = _seen[id]
				if p.y < -0.8:
					_splash(Vector3(p.x, EnvIslands.WATER_Y, p.z) - local, 1.0)
		_seen = still
		for pid in world.chefs:
			var c: Variant = world.chefs[pid]
			if not is_instance_valid(c):
				continue
			var p: Vector3 = (c as Node3D).global_position
			var prev: float = _chef_y.get(pid, p.y)
			if prev >= EnvIslands.WATER_Y and p.y < EnvIslands.WATER_Y and area.has_point(Vector2(p.x, p.z)):
				_splash(Vector3(p.x, EnvIslands.WATER_Y, p.z) - local, 1.6)
			_chef_y[pid] = p.y

	func _splash(at: Vector3, size: float) -> void:
		var root := Node3D.new()
		root.position = at + Vector3(0, 0.03, 0)
		add_child(root)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.8
		ring.outer_radius = 1.0
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.98, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = m
		mi.scale = Vector3(0.4, 0.25, 0.4) * size
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var drops: Array = []
		var dm := EnvUtil.mat(Color(0.9, 0.95, 1.0, 0.85), 0.1)
		for k in 10:
			var a := float(k) / 10.0 * TAU + randf() * 0.4
			var s := SphereMesh.new()
			s.radius = randf_range(0.1, 0.2) * size
			s.height = s.radius * 2.0
			s.radial_segments = 8
			s.rings = 4
			var d := MeshInstance3D.new()
			d.mesh = s
			d.material_override = dm
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(d)
			drops.append([d, Vector3(cos(a) * randf_range(1.5, 3.0), randf_range(4.0, 7.0), sin(a) * randf_range(1.5, 3.0)) * sqrt(size)])
		_splashes.append([root, 0.0, drops, mi, m, size])

	func _step_splashes(delta: float) -> void:
		for i in range(_splashes.size() - 1, -1, -1):
			var s: Array = _splashes[i]
			s[1] = float(s[1]) + delta
			var age: float = s[1]
			var size: float = s[5]
			var ring: MeshInstance3D = s[3]
			var k := age / 0.9
			ring.scale = Vector3(0.4 + k * 2.6, 0.25, 0.4 + k * 2.6) * size
			(s[4] as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.85 * (1.0 - k))
			for d in s[2]:
				var mi: MeshInstance3D = d[0]
				var v: Vector3 = d[1]
				v.y -= 20.0 * delta
				d[1] = v
				mi.position += v * delta
				mi.visible = mi.position.y > -0.05
			if age > 0.9:
				(s[0] as Node).queue_free()
				_splashes.remove_at(i)
