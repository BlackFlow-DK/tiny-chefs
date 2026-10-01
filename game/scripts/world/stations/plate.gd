class_name Plate
extends Station
## Finished food dropped on the plate snaps onto a visible stack (any order).
## Raw, burnt or whole food bounces off. A map may have several plates (World.plates); one with an
## "upgrade" in its def is closed (lid + sign, everything bounces off) until that upgrade is owned.

var stack: Array = []  # item kinds, bottom first
var _stack_root: Node3D
var _shown: Array = []
var _cover: Node3D     # lid + "CLOSED" sign, shown while is_locked()


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
	if def.has("upgrade"):
		_build_cover()


func _build_cover() -> void:
	_cover = Node3D.new()
	var r := half.x - 0.15
	_cover.add_child(cyl(r, 0.3, Color(0.6, 0.4, 0.24), Vector3(0, 0.03, 0)))
	_cover.add_child(cyl(r - 0.35, 0.33, Color(0.7, 0.49, 0.3), Vector3(0, 0.03, 0)))
	for a in [-45.0, 45.0]:   # crossed tape
		var tape := box(Vector3(r * 2.0 - 0.3, 0.06, 0.55), UITheme.TOMATO, Vector3(0, 0.34, 0))
		tape.rotation.y = deg_to_rad(a)
		_cover.add_child(tape)
	var plaque := closed_sign(3.4)
	plaque.position = Vector3(0, 0.45, 0.4)
	_cover.add_child(plaque)
	_cover.visible = false
	add_child(_cover)


func _process(_delta: float) -> void:
	if _cover != null:
		_cover.visible = is_locked()


func host_update(_dt: float) -> void:
	var locked := is_locked()
	for it in world.items.values():
		if it.removed or it.is_carried() or it.refuse_cooldown > 0.0:
			continue
		if centre_distance(it.global_position) > half.x - 0.4 or it.global_position.y > 2.5:
			continue
		if locked:
			world.refuse_from_plate(it, self, "This plate is closed. Buy %s in the shop!" % unlock_name())
		elif bool(it.def["plate"]) and stack.size() < Tuning.PLATE_MAX_STACK:
			stack.append(it.kind)
			world.stats.on_plated(it, self)
			print("content: plate took %s (%d on the plate)" % [it.kind, stack.size()])
			world.remove_item(it)
			Net.event("", "plop")
		else:
			world.refuse_from_plate(it, self)
	_refresh()


func clear_stack() -> void:
	stack.clear()
	if world.is_host:
		world.stats.on_plate_cleared(self)
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
