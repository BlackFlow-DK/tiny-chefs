class_name Griddle
extends Station
## Food lying on it cooks: raw -> cooked after COOK_TIME, cooked -> burnt after BURN_TIME x the
## ShiftDef's burn_scale (difficulty) more.
## Keeps cooking (also while held above it) until dragged off. At most GRIDDLE_SLOTS at once.

var _ids: Array = []  # item ids on the griddle, in arrival order


func build() -> void:
	var v := Models.load_model("griddle")
	if v == null:
		v = Node3D.new()
		v.add_child(box(size, Color(0.18, 0.18, 0.2), Vector3.ZERO))
		var hot := StandardMaterial3D.new()
		hot.albedo_color = Color(1.0, 0.45, 0.1)
		hot.emission_enabled = true
		hot.emission = Color(1.0, 0.35, 0.05)
		hot.emission_energy_multiplier = 1.5
		for i in 5:
			var line := box(Vector3(size.x - 1.2, 0.03, 0.22), Color.WHITE, Vector3(0, size.y, -2.4 + i * 1.2))
			line.material_override = hot
			v.add_child(line)
	add_flat_visual(v)
	add_label("Griddle", Vector3(0, 1.5, -half.y - 0.8))


func host_update(dt: float) -> void:
	var on: Dictionary = {}
	for it in world.items.values():
		if it.removed or not it.def.has("cooks_to") and not str(it.kind).ends_with("_burnt"):
			continue
		if contains_xz(it.global_position) and it.global_position.y < 2.5:
			on[it.item_id] = it
	for id in _ids.duplicate():
		if not on.has(id):
			_ids.erase(id)
			var gone: Item = world.items.get(id)
			if gone != null and gone.bar_kind != Item.Bar.CHOP:
				gone.set_cooking(false)
				gone.bar_kind = Item.Bar.NONE
	for id in on.keys():
		if not _ids.has(id):
			_ids.append(id)
	var slot := 0
	var burn_time := Tuning.BURN_TIME * float(world.shift.def.get("burn_scale", 1.0))  # difficulty burn window
	for id in _ids:
		var it: Item = on[id]
		if not it.def.has("cooks_to"):
			it.set_cooking(false)
			it.bar_kind = Item.Bar.NONE
			continue
		if slot >= Tuning.GRIDDLE_SLOTS:
			it.set_cooking(false)
			continue
		slot += 1
		it.set_cooking(true)
		it.cook_time += dt
		var raw := str(it.kind).ends_with("_raw")
		var limit := Tuning.COOK_TIME if raw else burn_time
		if it.cook_time >= limit:
			it.cook_time = 0.0
			world.change_kind(it, str(it.def["cooks_to"]))
			raw = str(it.kind).ends_with("_raw")
			if not it.def.has("cooks_to"):
				it.set_cooking(false)
				it.bar_kind = Item.Bar.NONE
				continue
			limit = Tuning.COOK_TIME if raw else burn_time
		it.bar = it.cook_time / limit
		it.bar_kind = Item.Bar.COOK if raw else Item.Bar.BURN


func reset() -> void:
	_ids.clear()
