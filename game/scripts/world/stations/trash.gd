class_name Trash
extends Station
## Food dragged (or knocked) onto the drain disappears.


func build() -> void:
	var v := Models.load_model("trash_drain")
	if v == null:
		v = Node3D.new()
		v.add_child(cyl(half.x, size.y, Color(0.35, 0.37, 0.4), Vector3.ZERO))
		v.add_child(cyl(half.x - 0.5, size.y + 0.01, Color(0.06, 0.06, 0.07), Vector3.ZERO))
		for i in 5:
			v.add_child(box(Vector3(size.x - 1.2, 0.02, 0.15), Color(0.45, 0.47, 0.5), Vector3(0, size.y, -1.2 + i * 0.6)))
	add_flat_visual(v)
	add_label("Trash", Vector3(0, 1.5, -half.y - 0.6))


func host_update(_dt: float) -> void:
	for it in world.items.values():
		if it.removed:
			continue
		if centre_distance(it.global_position) < half.x - 0.3 and it.global_position.y < 3.0:
			world.remove_item(it)
			Net.event("", "trash")
