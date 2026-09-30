class_name Plate
extends Station
## Finished food dropped on the plate snaps onto a visible stack (any order).
## Raw, burnt or whole food bounces off.

var stack: Array = []  # item kinds, bottom first
var _stack_root: Node3D
var _shown: Array = []


func build() -> void:
	var v := Models.load_model("plate")
	if v == null:
		v = Node3D.new()
		v.add_child(cyl(half.x, size.y, Color(0.82, 0.84, 0.86), Vector3.ZERO))
		v.add_child(cyl(half.x - 0.5, size.y + 0.01, Color(0.98, 0.98, 0.97), Vector3.ZERO))
	add_flat_visual(v)
	_stack_root = Node3D.new()
	_stack_root.position = Vector3(0, 0.05, 0)
	add_child(_stack_root)
	add_label("Plate", Vector3(0, 1.5, -half.y - 0.8))


func host_update(_dt: float) -> void:
	for it in world.items.values():
		if it.removed or it.is_carried() or it.refuse_cooldown > 0.0:
			continue
		if centre_distance(it.global_position) > half.x - 0.4 or it.global_position.y > 2.5:
			continue
		if bool(it.def["plate"]) and stack.size() < Tuning.PLATE_MAX_STACK:
			stack.append(it.kind)
			print("content: plate took %s (%d on the plate)" % [it.kind, stack.size()])
			world.remove_item(it)
			Net.event("", "plop")
		else:
			world.refuse_from_plate(it, self)
	_refresh()


func clear_stack() -> void:
	stack.clear()
	_refresh()


func state() -> Variant:
	var a := PackedInt32Array()
	for k in stack:
		a.append(GameData.kind_index(k))
	return a


func apply_state(s: Variant) -> void:
	if s is PackedInt32Array:
		var st: Array = []
		for i in s:
			st.append(GameData.ITEM_KINDS[i])
		stack = st
		_refresh()


func _refresh() -> void:
	if _shown == stack:
		return
	_shown = stack.duplicate()
	for c in _stack_root.get_children():
		c.queue_free()
	var y := 0.0
	for k in stack:
		var d: Dictionary = GameData.ITEMS[k]
		var sz: Vector3 = d["size"]
		var m := Models.make(k, sz, d["color"], d["shape"])
		m.position = Vector3(0, y, 0)
		_stack_root.add_child(m)
		y += sz.y * 0.9
