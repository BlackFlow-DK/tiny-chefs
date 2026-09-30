class_name OutlineMesh
extends RefCounted
## Flat (XZ plane) outline meshes for the in-world indicators: a rounded-rectangle ring that hugs a
## footprint (highlight), and the thin player ring with a facing chevron (ground marker).
## Every mesh has two surfaces: 0 = ink outline (dark), 1 = colour. Give each its own material.

const ARC_STEPS := 8


## Points along a rounded rectangle (half extents hx, hz, corner radius r), pushed out by `d` metres.
static func _loop(hx: float, hz: float, r: float, d: float) -> PackedVector3Array:
	r = clampf(r, 0.01, minf(hx, hz))
	var pts := PackedVector3Array()
	var centres := [Vector2(hx - r, hz - r), Vector2(-(hx - r), hz - r), Vector2(-(hx - r), -(hz - r)), Vector2(hx - r, -(hz - r))]
	for k in 4:
		var c: Vector2 = centres[k]
		var a0 := float(k) * PI * 0.5
		for i in ARC_STEPS + 1:
			var a := a0 + float(i) / float(ARC_STEPS) * PI * 0.5
			var rad := maxf(r + d, 0.001)
			pts.append(Vector3(c.x + cos(a) * rad, 0.0, c.y + sin(a) * rad))
	return pts


static func _strip(st: SurfaceTool, inner: PackedVector3Array, outer: PackedVector3Array, y: float, close := true) -> void:
	var n := inner.size()
	var last := n if close else n - 1
	for i in last:
		var j := (i + 1) % n
		var a := inner[i] + Vector3(0, y, 0)
		var b := outer[i] + Vector3(0, y, 0)
		var c := inner[j] + Vector3(0, y, 0)
		var e := outer[j] + Vector3(0, y, 0)
		for v in [a, b, c, c, b, e]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, y: float) -> void:
	for v in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v + Vector3(0, y, 0))


static func _finish(ink: SurfaceTool, col: SurfaceTool) -> ArrayMesh:
	var m := ArrayMesh.new()
	ink.commit(m)
	col.commit(m)
	return m


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Highlight ring hugging a rounded rectangle of half extents (hx, hz). width = coloured band, ink = outline each side.
static func rounded_ring(hx: float, hz: float, corner: float, width: float, ink: float) -> ArrayMesh:
	var s_ink := _new_st()
	var s_col := _new_st()
	_strip(s_ink, _loop(hx, hz, corner, -width * 0.5 - ink), _loop(hx, hz, corner, width * 0.5 + ink), 0.0)
	_strip(s_col, _loop(hx, hz, corner, -width * 0.5), _loop(hx, hz, corner, width * 0.5), 0.012)
	return _finish(s_ink, s_col)


## Player ground marker: thin circle of radius r plus a chevron on the ring pointing along +Z.
static func player_ring(r: float, width: float, ink: float, chevron := true) -> ArrayMesh:
	var s_ink := _new_st()
	var s_col := _new_st()
	var n := 48
	var ri := PackedVector3Array()
	var ro := PackedVector3Array()
	var rii := PackedVector3Array()
	var roo := PackedVector3Array()
	for i in n:
		var a := float(i) / float(n) * TAU
		var d := Vector3(cos(a), 0, sin(a))
		ri.append(d * (r - width * 0.5))
		ro.append(d * (r + width * 0.5))
		rii.append(d * (r - width * 0.5 - ink))
		roo.append(d * (r + width * 0.5 + ink))
	_strip(s_ink, rii, roo, 0.0)
	_strip(s_col, ri, ro, 0.012)
	if chevron:
		# Arrow head just outside the ring, tip forward (+Z).
		var base := r + width * 0.5 + ink + 0.02
		var tip := base + 0.36
		var hw := 0.24
		var k := ink * 1.6
		_tri(s_ink, Vector3(-hw - k, 0, base - k * 0.6), Vector3(hw + k, 0, base - k * 0.6), Vector3(0, 0, tip + k * 1.5), 0.0)
		_tri(s_col, Vector3(hw, 0, base), Vector3(-hw, 0, base), Vector3(0, 0, tip), 0.012)
	return _finish(s_ink, s_col)


## Opaque (depth-written) so the colour surface, raised 1 cm, always wins over the ink surface.
static func flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m
