class_name HintSystem
extends RefCounted
## Owns the local interaction feedback: grab/work target rings and world.hint_text (shown by the HUD);
## writes world.grab_target / world.work_target. Every peer, from replicated state only.
## Reads world.my_chef(), world.items, world.bell/dispensers/board, world.shift. Calls world.grab_candidate.

var world: World
var _grab_ring: MeshInstance3D
var _work_ring: MeshInstance3D


func _init(w: World) -> void:
	world = w
	_grab_ring = _make_ring(Color(1.0, 0.88, 0.2))
	_work_ring = _make_ring(Color(0.3, 0.9, 1.0))


func _make_ring(color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 3
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi


func update() -> void:
	world.grab_target = null
	world.work_target = null
	world.hint_text = ""
	var me := world.my_chef()
	if me == null or Net.phase != Net.Phase.PLAYING or (me.flags & Chef.FLAG_RESPAWNING) != 0:
		_grab_ring.visible = false
		_work_ring.visible = false
		return
	var grab_target: Item = null
	var work_target: Station = null
	var bell := world.bell
	var board := world.board
	var parts := PackedStringArray()
	var p := me.global_position
	if me.held_id >= 0:
		var held: Item = world.items.get(me.held_id)
		var t := "E: drop"
		if held != null and held.carrier_count < held.weight():
			t += "   (heavy: %d/%d chefs for full speed)" % [held.carrier_count, held.weight()]
		parts.append(t)
	else:
		grab_target = world.grab_candidate(me, world.local_input)  # the exact item a grab press takes
		if grab_target != null:
			var w := grab_target.weight()
			parts.append("E: grab %s%s" % [grab_target.label_text(), (" (%d chefs for full speed)" % w) if w > 1 else ""])
		if bell.footprint_distance(p) <= Tuning.REACH:
			work_target = bell
		else:
			for s in world.dispensers:
				if s.footprint_distance(p) <= Tuning.REACH:
					work_target = s
			if work_target == null and board.has_tomato and board.footprint_distance(p) <= Tuning.REACH + 0.3:
				work_target = board
		if work_target != null:
			parts.append(work_target.work_hint())
	if world.shift.has_upgrade("gloves"):
		parts.append("Q: punch")
	world.grab_target = grab_target
	world.work_target = work_target
	world.hint_text = "     ".join(parts)
	_grab_ring.visible = grab_target != null
	if grab_target != null:
		var r := grab_target.radius() + 0.4
		_grab_ring.global_position = grab_target.global_position + Vector3(0, 0.1, 0)
		_grab_ring.scale = Vector3(r, 1, r)
	_work_ring.visible = work_target != null
	if work_target != null:
		var r2 := maxf(work_target.half.x, work_target.half.y) + 0.5
		_work_ring.global_position = work_target.global_position + Vector3(0, 0.12, 0)
		_work_ring.scale = Vector3(r2, 1, r2)
