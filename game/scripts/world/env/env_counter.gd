class_name EnvCounter
extends RefCounted
## The giant worktop island: terrazzo slab with a rounded top edge (and a hole for the sink basin),
## a walnut trim band under it, and painted shaker cabinets (drawers, doors, brass handles, toe
## kick) on the front and both ends so looking over the edge sells the height. Visual only: the
## counter collider stays the plain box built by Kitchen.

const EDGE_R := 0.35         # rounded top edge radius
const SLAB_T := 1.0          # worktop thickness
const TRIM_H := 0.6          # walnut band under the slab
const OVERHANG := 0.8        # cabinet fronts sit this far behind the slab edge
const KICK_H := 2.8          # toe kick height
const KICK_IN := 2.6         # toe kick recess

const CABINET := Color(0.20, 0.36, 0.40)   # deep teal paint
const WALNUT := Color(0.34, 0.22, 0.14)
const BRASS := Color(0.86, 0.66, 0.36)


## One island for surface (x, z, w, h); holes: XZ Rect2s cut out of the slab (sink basins).
## Built in local coordinates centred on the surface.
static func build(root: Node3D, surface: Rect2, holes: Array) -> void:
	var cw := surface.size.x
	var cd := surface.size.y
	var ch := GameData.COUNTER_HEIGHT
	var hx := cw * 0.5
	var hz := cd * 0.5
	var c := surface.get_center()
	var n := EnvUtil.node(root, "CounterVisual", Vector3(c.x, 0, c.y))
	var top := EnvUtil.shader_mat("counter_terrazzo")
	var r := EDGE_R

	# Slab: inset upper band (next to the rounded edge) + full lower band, both minus the holes.
	var upper := [Rect2(-hx + r, -hz, cw - 2.0 * r, cd - r)]
	var lower := [Rect2(-hx, -hz, cw, cd)]
	for hole: Rect2 in holes:
		var local := Rect2(hole.position - c, hole.size)
		upper = EnvUtil.rects_minus(upper, local)
		lower = EnvUtil.rects_minus(lower, local)
	for rc in upper:
		EnvUtil.box_mm(n, Vector3(rc.position.x, -r, rc.position.y), Vector3(rc.end.x, 0.0, rc.end.y), top)
	for rc in lower:
		EnvUtil.box_mm(n, Vector3(rc.position.x, -SLAB_T, rc.position.y), Vector3(rc.end.x, -r, rc.end.y), top)
	# Rounded top edge: front + both ends, spheres at the front corners.
	EnvUtil.cyl(n, r, r, cw - 2.0 * r, Vector3(0, -r, hz - r), top, "x", 20)
	for sx in [-1.0, 1.0]:
		EnvUtil.cyl(n, r, r, cd - r, Vector3(sx * (hx - r), -r, -r * 0.5), top, "z", 20)
		EnvUtil.sphere(n, r, Vector3(sx * (hx - r), -r, hz - r), top, Vector3.ONE, true, 16)

	# Walnut trim band, a little recessed.
	var walnut := EnvUtil.mat(WALNUT, 0.45)
	EnvUtil.box_mm(n, Vector3(-hx + 0.15, -SLAB_T - TRIM_H, -hz), Vector3(hx - 0.15, -SLAB_T, hz - 0.15), walnut)
	# Thin brass inlay line between slab and trim.
	var brass := EnvUtil.mat(BRASS, 0.3, 0.9)
	EnvUtil.box_mm(n, Vector3(-hx + 0.08, -SLAB_T - 0.12, -hz), Vector3(hx - 0.08, -SLAB_T + 0.02, hz - 0.08), brass, false)

	# Carcass and toe kick.
	var paint := EnvUtil.mat(CABINET, 0.55)
	var top_y := -SLAB_T - TRIM_H
	EnvUtil.box_mm(n, Vector3(-hx + OVERHANG, -ch + KICK_H, -hz), Vector3(hx - OVERHANG, top_y, hz - OVERHANG), paint)
	EnvUtil.box_mm(n, Vector3(-hx + KICK_IN, -ch, -hz), Vector3(hx - KICK_IN, -ch + KICK_H, hz - KICK_IN),
		EnvUtil.mat(Color(0.1, 0.1, 0.11), 0.8))

	# Front: three bays, each a wide drawer over a pair of doors.
	var front := EnvUtil.node(n, "Front", Vector3(0, 0, hz - OVERHANG))
	var span := cw - 2.0 * OVERHANG - 0.6
	var bays := 3
	var bw := span / bays
	var gap := 0.35
	var y_top := top_y - 0.35
	var y_bot := -ch + KICK_H + 0.35
	var drawer_h := 5.4
	for b in bays:
		var x0 := -span * 0.5 + b * bw
		var cx := x0 + bw * 0.5
		var dy := y_top - drawer_h * 0.5
		_drawer(front, Vector2(cx, dy), Vector2(bw - gap, drawer_h), paint, brass)
		var door_top := y_top - drawer_h - gap
		var dh := door_top - y_bot
		var dw := (bw - gap) * 0.5 - gap * 0.5
		for side in [-1.0, 1.0]:
			var dcx: float = cx + side * (dw * 0.5 + gap * 0.5)
			_door(front, Vector2(dcx, y_bot + dh * 0.5), Vector2(dw, dh), paint, brass, -side)

	# Ends: one big framed panel each (normal +-X).
	for sx in [-1.0, 1.0]:
		var e := EnvUtil.node(n, "End", Vector3(sx * (hx - OVERHANG), 0, 0))
		e.rotation.y = sx * PI * 0.5
		# local x runs along world -Z on the +X end and +Z on the -X end.
		var lz: float = -sx * (-OVERHANG * 0.5)
		var w := cd - OVERHANG - 1.2
		_panel(e, Vector2(lz, (y_top + y_bot) * 0.5), Vector2(w, y_top - y_bot), paint)


## Shaker panel on a local face (normal +Z): back plate + raised frame.
static func _panel(face: Node3D, c: Vector2, size: Vector2, paint: Material) -> void:
	var t := 0.3
	EnvUtil.box(face, Vector3(size.x, size.y, t), Vector3(c.x, c.y, t * 0.5), paint)
	var fw := clampf(minf(size.x, size.y) * 0.13, 0.9, 2.2)
	var z := t + t * 0.5
	var inner := EnvUtil.mat(CABINET.darkened(0.06), 0.6)
	EnvUtil.box(face, Vector3(size.x - fw * 2.0, size.y - fw * 2.0, 0.05), Vector3(c.x, c.y, t + 0.025), inner, false)
	EnvUtil.box(face, Vector3(size.x, fw, t), Vector3(c.x, c.y + size.y * 0.5 - fw * 0.5, z), paint)
	EnvUtil.box(face, Vector3(size.x, fw, t), Vector3(c.x, c.y - size.y * 0.5 + fw * 0.5, z), paint)
	EnvUtil.box(face, Vector3(fw, size.y - fw * 2.0, t), Vector3(c.x - size.x * 0.5 + fw * 0.5, c.y, z), paint)
	EnvUtil.box(face, Vector3(fw, size.y - fw * 2.0, t), Vector3(c.x + size.x * 0.5 - fw * 0.5, c.y, z), paint)


static func _door(face: Node3D, c: Vector2, size: Vector2, paint: Material, brass: Material, handle_side: float) -> void:
	_panel(face, c, size, paint)
	var hx := c.x + handle_side * (size.x * 0.5 - 1.3)
	var hy := c.y + size.y * 0.5 - 4.2
	_handle(face, Vector2(hx, hy), 5.0, true, brass)


static func _drawer(face: Node3D, c: Vector2, size: Vector2, paint: Material, brass: Material) -> void:
	EnvUtil.box(face, Vector3(size.x, size.y, 0.45), Vector3(c.x, c.y, 0.225), paint)
	# Shallow routed groove near the edges.
	var groove := EnvUtil.mat(CABINET.darkened(0.25), 0.7)
	var inset := 0.7
	EnvUtil.box(face, Vector3(size.x - inset * 2.0, 0.08, 0.02), Vector3(c.x, c.y + size.y * 0.5 - inset, 0.455), groove, false)
	EnvUtil.box(face, Vector3(size.x - inset * 2.0, 0.08, 0.02), Vector3(c.x, c.y - size.y * 0.5 + inset, 0.455), groove, false)
	_handle(face, c, 6.5, false, brass)


## Brass bar handle on two standoffs. vertical: along local Y, else along local X.
static func _handle(face: Node3D, c: Vector2, length: float, vertical: bool, brass: Material) -> void:
	var z := 0.45 + 0.75
	if vertical:
		EnvUtil.cyl(face, 0.24, 0.24, length, Vector3(c.x, c.y - length * 0.5, z), brass, "y", 12)
		for s in [-1.0, 1.0]:
			EnvUtil.cyl(face, 0.16, 0.16, 0.8, Vector3(c.x, c.y + s * (length * 0.5 - 0.5), z - 0.4), brass, "z", 10)
	else:
		EnvUtil.cyl(face, 0.24, 0.24, length, Vector3(c.x, c.y, z), brass, "x", 12)
		for s in [-1.0, 1.0]:
			EnvUtil.cyl(face, 0.16, 0.16, 0.8, Vector3(c.x + s * (length * 0.5 - 0.5), c.y, z - 0.4), brass, "z", 10)
