class_name HintSystem
extends RefCounted
## Owns the local interaction feedback: the highlight outline on the grab/work target and world.hint_text
## (shown by the HUD, now only for carrying states and punch: the target prompts are key chips floating
## over the target, drawn by IndicatorLayer); writes world.grab_target / world.work_target.
## Every peer, from replicated state only.
## Reads world.my_chef(), world.items, world.bell/dispensers/board, world.shift. Calls world.grab_candidate.

var world: World
var _grab_ring: HighlightRing
var _work_ring: HighlightRing
var _layer: IndicatorLayer
var _t := 0.0


func _init(w: World) -> void:
	world = w
	_grab_ring = HighlightRing.new()
	_work_ring = HighlightRing.new()
	world.add_child(_grab_ring)
	world.add_child(_work_ring)
	_layer = IndicatorLayer.new(w)
	world.add_child(_layer)


func update() -> void:
	world.grab_target = null
	world.work_target = null
	world.hint_text = ""
	_t += world.get_process_delta_time()
	var me := world.my_chef()
	if me == null or Net.phase != Net.Phase.PLAYING or (me.flags & Chef.FLAG_RESPAWNING) != 0:
		_grab_ring.hide_ring()
		_work_ring.hide_ring()
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
		if bell.footprint_distance(p) <= Tuning.REACH:
			work_target = bell
		else:
			for s in world.dispensers:
				if s.footprint_distance(p) <= Tuning.REACH:
					work_target = s
			if work_target == null and board.has_tomato and board.footprint_distance(p) <= Tuning.REACH + 0.3:
				work_target = board
	if world.shift.has_upgrade("gloves"):
		parts.append("Q: punch")
	world.grab_target = grab_target
	world.work_target = work_target
	world.hint_text = "     ".join(parts)
	var color: Color = me.color
	if grab_target != null:
		var shape := str(grab_target.def["shape"])
		var m := 0.3
		var yaw := grab_target.global_transform.basis.get_euler().y
		if shape == "box" or shape == "capsule_x":
			var hx := grab_target.size.x * 0.5 + m
			var hz := grab_target.size.z * 0.5 + m
			_grab_ring.show_at(grab_target.global_position, hx, hz, yaw, minf(0.7, minf(hx, hz)), color, _t)
		else:
			var r := grab_target.radius() + m
			_grab_ring.show_at(grab_target.global_position, r, r, 0.0, r, color, _t)
	else:
		_grab_ring.hide_ring()
	if work_target != null:
		var m2 := 0.35
		var hx2 := work_target.half.x + m2
		var hz2 := work_target.half.y + m2
		var y := 0.05 if work_target.size.y < 1.0 else 0.0
		_work_ring.show_at(work_target.global_position + Vector3(0, y, 0), hx2, hz2, 0.0, 0.8, color, _t)
	else:
		_work_ring.hide_ring()
