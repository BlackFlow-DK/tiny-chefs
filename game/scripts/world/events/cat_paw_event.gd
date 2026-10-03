class_name CatPawEvent
extends ShiftEvent
## "cat_paw" (maps whose hazards include "cat_paw"): a giant orange paw (cat_paw.glb + a code-built arm)
## lands on a lane, a Tuning.PAW_LANE_WIDTH strip along X or Z through a random chef, PAW_SWEEP_LEN/2 before
## that chef, sweeps PAW_SWEEP_LEN m through it in PAW_SWEEP s (clamped to the counter) and lifts away. Telegraph: shadow disc + lane strip + meow + banner.
## Host: loose food it touches is launched along the sweep; chefs are shoved out of the lane, clamped so
## they end at least PAW_EDGE_MARGIN inside their counter surface (the paw never pushes anyone off).
## Every peer animates it from (t, params) replicated in the snapshot ("e"), so clients see the same paw.

enum Stage { TELEGRAPH, DESCEND, SWEEP, LIFT, GONE }

const ARM_DIR := Vector3(0.0, 0.876, -0.482)   # wrist -> up and back, where the cat is
const ARM_LEN := 60.0
const ARM_RADIUS := 2.8

var axis := 0          # 0: sweeps along X (lane is a Z strip), 1: sweeps along Z (lane is an X strip)
var lane := 0.0        # across-axis centre of the lane
var from := 0.0        # along-axis start / end of the sweep
var to := 0.0

var _rng := RandomNumberGenerator.new()
var _hit: Dictionary = {}      # host: instance id -> true, once per sweep
var _root: Node3D
var _paw: Node3D
var _shadow: MeshInstance3D
var _shadow_core: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _shadow_core_mat: StandardMaterial3D
var _lane: MeshInstance3D
var _lane_mat: StandardMaterial3D
var _stage := -1


func _init(w: World) -> void:
	super(w)
	id = "cat_paw"
	period = Tuning.PAW_PERIOD
	lead = Tuning.PAW_LEAD
	_rng.randomize()


func active_time() -> float:
	return Tuning.PAW_DESCEND + Tuning.PAW_SWEEP + Tuning.PAW_LIFT


# ================================================================ host

func telegraph() -> void:
	_hit.clear()
	var b := world.surface_bounds()
	axis = _rng.randi_range(0, 1)
	var focus := b.get_center()
	var alive: Array = world.chefs.values().filter(func(c: Chef) -> bool: return c.respawn_timer < 0.0)
	if not alive.is_empty():
		var c: Chef = alive[_rng.randi_range(0, alive.size() - 1)]
		focus = Vector2(c.global_position.x, c.global_position.z)
	var half := Tuning.PAW_LANE_WIDTH * 0.5
	var a_min := b.position.y if axis == 0 else b.position.x
	var a_max := b.end.y if axis == 0 else b.end.x
	var l_min := b.position.x if axis == 0 else b.position.y
	var l_max := b.end.x if axis == 0 else b.end.y
	var f := (focus.y if axis == 0 else focus.x) + _rng.randf_range(-2.0, 2.0)
	lane = clampf(f, a_min + half, a_max - half) if a_max - a_min > 2.0 * half else (a_min + a_max) * 0.5
	# Land PAW_SWEEP_LEN/2 before the focus (on screen, near the chefs) and sweep through it, inside the ends.
	var fa := (focus.x if axis == 0 else focus.y) + _rng.randf_range(-2.0, 2.0)
	var sgn := 1.0 if _rng.randf() < 0.5 else -1.0
	var lo := l_min + 3.0
	var hi := maxf(lo, l_max - 3.0)
	from = clampf(fa - sgn * Tuning.PAW_SWEEP_LEN * 0.5, lo, hi)
	to = clampf(from + sgn * Tuning.PAW_SWEEP_LEN, lo, hi)
	if absf(to - from) < Tuning.PAW_SWEEP_LEN * 0.5:   # near an end: sweep the other way
		sgn = -sgn
		to = clampf(from + sgn * Tuning.PAW_SWEEP_LEN, lo, hi)
	_stage = -1
	Net.event("Here, kitty kitty... A giant CAT PAW! Watch the shadow!", "ev_paw")
	print("events: cat paw lane axis=%s lane=%.1f from %.1f to %.1f" % ["x" if axis == 0 else "z", lane, from, to])


func host_tick(_dt: float, t: float) -> void:
	var s := t - lead
	if s < Tuning.PAW_DESCEND * 0.8 or s > Tuning.PAW_DESCEND + Tuning.PAW_SWEEP:
		return
	var p := paw_pos(t)
	var dir := _along_axis() * signf(to - from)
	for it: Item in world.items.values():
		if it.removed or it.is_carried() or it.freeze or _hit.has(it.get_instance_id()):
			continue
		var rel := it.global_position - p
		if not _in_zone(rel) or it.global_position.y > 6.0:
			continue
		_hit[it.get_instance_id()] = true
		world.detach_all(it)
		var w := sqrt(float(it.weight()))
		var out := _across_axis() * _side(rel)
		it.launch(dir * (Tuning.PAW_ITEM_SPEED / w) + out * 3.0 + Vector3.UP * (Tuning.PAW_ITEM_UP / w))
		it.angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-10, 10), _rng.randf_range(-3, 3))
		it.refuse_cooldown = 0.5
		world.events.note_paw_hit(it)
	for c: Chef in world.chefs.values():
		if c.respawn_timer >= 0.0 or _hit.has(c.get_instance_id()):
			continue
		var rel := c.global_position - p
		if not _in_zone(rel):
			continue
		_hit[c.get_instance_id()] = true
		_shove(c, rel, dir)
		world.events.note_paw_hit(c)


## Shove chef c out of the lane (and a little along the sweep), never past PAW_EDGE_MARGIN from the edge
## of the counter surface it stands on. knock decays at KNOCK_DECAY, so speed = sqrt(2 * decay * distance).
func _shove(c: Chef, rel: Vector3, dir: Vector3) -> void:
	world.release(c)
	var across := rel.dot(_across_axis())
	var pos := c.global_position
	var dist := Tuning.PAW_LANE_WIDTH * 0.5 - absf(across) + Tuning.PAW_SHOVE_EXTRA
	var target := pos + _across_axis() * _side(rel) * dist + dir * 1.0
	var xz := _clamp_inside(Vector2(pos.x, pos.z), Vector2(target.x, target.z))
	var d := Vector3(xz.x - pos.x, 0.0, xz.y - pos.z)
	if d.length() > 0.05:
		c.knock = d.normalized() * sqrt(2.0 * Tuning.KNOCK_DECAY * d.length())


## target clamped into the surface under from (or the nearest one), shrunk by PAW_EDGE_MARGIN.
func _clamp_inside(from_xz: Vector2, target: Vector2) -> Vector2:
	var best: Rect2 = world.map["surfaces"][0]
	var best_d := INF
	for r: Rect2 in world.map["surfaces"]:
		var q := Vector2(clampf(from_xz.x, r.position.x, r.end.x), clampf(from_xz.y, r.position.y, r.end.y))
		var dd := q.distance_to(from_xz)
		if dd < best_d:
			best_d = dd
			best = r
	var m := Tuning.PAW_EDGE_MARGIN
	var lo := best.position + Vector2(m, m)
	var hi := best.end - Vector2(m, m)
	return Vector2(clampf(target.x, lo.x, maxf(lo.x, hi.x)), clampf(target.y, lo.y, maxf(lo.y, hi.y)))


func _in_zone(rel: Vector3) -> bool:
	return absf(rel.dot(_along_axis())) <= Tuning.PAW_REACH and absf(rel.dot(_across_axis())) <= Tuning.PAW_LANE_WIDTH * 0.5


func _side(rel: Vector3) -> float:
	var a := rel.dot(_across_axis())
	if absf(a) < 0.05:
		return 1.0 if _rng.randf() < 0.5 else -1.0
	return signf(a)


# ================================================================ shared geometry

func _along_axis() -> Vector3:
	return Vector3.RIGHT if axis == 0 else Vector3.BACK


func _across_axis() -> Vector3:
	return Vector3.BACK if axis == 0 else Vector3.RIGHT


func _point(along: float, across: float, y: float) -> Vector3:
	return Vector3(along, y, across) if axis == 0 else Vector3(across, y, along)


func _stage_at(t: float) -> int:
	var s := t - lead
	if s < 0.0:
		return Stage.TELEGRAPH
	if s < Tuning.PAW_DESCEND:
		return Stage.DESCEND
	if s < Tuning.PAW_DESCEND + Tuning.PAW_SWEEP:
		return Stage.SWEEP
	if s < active_time():
		return Stage.LIFT
	return Stage.GONE


## Paw base-centre position at time t (s since the telegraph).
func paw_pos(t: float) -> Vector3:
	var s := t - lead
	var h := Tuning.PAW_HEIGHT
	match _stage_at(t):
		Stage.TELEGRAPH:
			return _point(from, lane, h)
		Stage.DESCEND:
			var u := s / Tuning.PAW_DESCEND
			return _point(from, lane, h * (1.0 - u * u))
		Stage.SWEEP:
			var u := (s - Tuning.PAW_DESCEND) / Tuning.PAW_SWEEP
			return _point(lerpf(from, to, smoothstep(0.0, 1.0, u)), lane, 0.0)
		Stage.LIFT:
			var u := (s - Tuning.PAW_DESCEND - Tuning.PAW_SWEEP) / Tuning.PAW_LIFT
			return _point(to, lane, h * u * u)
	return _point(to, lane, h)


func params() -> Array:
	return [float(axis), lane, from, to]


func apply_params(p: Array) -> void:
	if p.size() < 4:
		return
	axis = int(p[0])
	lane = float(p[1])
	from = float(p[2])
	to = float(p[3])


# ================================================================ visuals (every peer)

func visuals(t: float) -> void:
	_ensure_nodes()
	_root.visible = true
	var st := _stage_at(t)
	if st != _stage:
		if st == Stage.SWEEP:
			Sfx.play("paw_swoosh")
		elif st == Stage.DESCEND:
			Sfx.play("paw_whoosh")
		_stage = st
	var p := paw_pos(t)
	# Lane strip: pulses during the telegraph, fades out as the paw passes.
	var length := absf(to - from) + 6.0
	_lane.scale = Vector3(length, 1.0, Tuning.PAW_LANE_WIDTH) if axis == 0 else Vector3(Tuning.PAW_LANE_WIDTH, 1.0, length)
	_lane.position = _point((from + to) * 0.5, lane, 0.05)
	var la := 0.0
	if st == Stage.TELEGRAPH:
		la = 0.10 + 0.12 * (0.5 + 0.5 * sin(t * 9.0))
	elif st == Stage.DESCEND or st == Stage.SWEEP:
		la = 0.10
	_lane.visible = la > 0.0
	_lane_mat.albedo_color.a = la
	# Shadow disc: grows and darkens as the paw comes, follows it, shrinks as it lifts.
	var k := clampf(1.0 - p.y / Tuning.PAW_HEIGHT, 0.0, 1.0)
	var grow := k
	if st == Stage.TELEGRAPH:
		grow = clampf(t / lead, 0.0, 1.0) * 0.6
		k = grow
	var sc := 0.45 + 0.55 * grow
	_shadow.position = Vector3(p.x, 0.07, p.z)
	_shadow.scale = Vector3(sc, 1.0, sc)
	_shadow_mat.albedo_color.a = 0.25 + 0.3 * k
	_shadow_core_mat.albedo_color.a = 0.2 + 0.4 * k
	_shadow.visible = st != Stage.GONE
	_paw.visible = st != Stage.TELEGRAPH and st != Stage.GONE
	_paw.position = p


func finish() -> void:
	if _root != null:
		_root.visible = false
	_stage = -1
	_hit.clear()


func _ensure_nodes() -> void:
	if _root != null:
		return
	_root = Node3D.new()
	_root.name = "CatPaw"
	world.add_child(_root)
	_lane_mat = _clear_mat(Color(1.0, 0.55, 0.15, 0.2))
	_lane = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.02, 1.0)
	_lane.mesh = bm
	_lane.material_override = _lane_mat
	_root.add_child(_lane)
	_shadow_mat = _clear_mat(Color(0.05, 0.03, 0.08, 0.3))
	_shadow_core_mat = _clear_mat(Color(0.05, 0.03, 0.08, 0.3))
	_shadow = _disc(7.0, _shadow_mat)
	_shadow_core = _disc(4.6, _shadow_core_mat)
	_shadow_core.position.y = 0.01
	_shadow.add_child(_shadow_core)
	_root.add_child(_shadow)
	_paw = Node3D.new()
	var m := Models.load_model("cat_paw")
	if m == null:
		m = Models.primitive("box", Vector3(12, 4, 10), Color(0.95, 0.55, 0.16))
	_paw.add_child(m)
	# The arm, up and back to where the cat sits, with tabby bands.
	var fur := Models.mat(Color(0.95, 0.55, 0.16))
	var stripe := Models.mat(Color(0.76, 0.34, 0.1))
	var wrist := Vector3(0.0, 3.6, -2.4)   # model toes face +Z, the wrist stub is at the back
	var arm := CylinderMesh.new()
	arm.top_radius = ARM_RADIUS
	arm.bottom_radius = ARM_RADIUS * 1.1
	arm.height = ARM_LEN
	arm.radial_segments = 24
	var tilt := Vector3(atan2(ARM_DIR.z, ARM_DIR.y), 0.0, 0.0)
	var am := Models.mesh_node(arm, Color(0.95, 0.55, 0.16), wrist + ARM_DIR * ARM_LEN * 0.5)
	am.material_override = fur
	am.rotation = tilt
	_paw.add_child(am)
	for i in 6:
		var band := CylinderMesh.new()
		band.top_radius = ARM_RADIUS * 1.08
		band.bottom_radius = ARM_RADIUS * 1.1
		band.height = 1.1
		band.radial_segments = 24
		var bn := Models.mesh_node(band, Color(0.76, 0.34, 0.1), wrist + ARM_DIR * (4.0 + i * 3.2))
		bn.material_override = stripe
		bn.rotation = tilt
		_paw.add_child(bn)
	_root.add_child(_paw)
	_root.visible = false


func _disc(r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _clear_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
