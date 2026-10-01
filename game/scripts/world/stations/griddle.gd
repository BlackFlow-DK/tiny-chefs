class_name Griddle
extends Station
## Food lying on it cooks along its "cooks_to" chain: the cook stage (raw -> cooked after COOK_TIME, or
## CRACK_TIME for items marked "crack", like the egg) then the burn stage (cooked -> burnt after BURN_TIME).
## A stage is the cook stage when its result changes again. Keeps cooking (also while held above it) until
## dragged off. At most _slots() at once. The Fryer subclass reuses all of this with "fries_to".

var _ids: Array = []  # item ids on the station, in arrival order


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


# ---------------------------------------------------------------- overridden by Fryer

## ITEMS key this station follows.
func key() -> String:
	return "cooks_to"


func _slots() -> int:
	return Tuning.GRIDDLE_SLOTS


## Seconds for the stage an item of this def is in.
## Difficulty burn window (ShiftDef burn_scale) x Tuning.OVEN_MITTS_MULT with the oven_mitts upgrade.
func _burn_scale() -> float:
	if world == null or world.shift == null:
		return 1.0
	var k := float(world.shift.def.get("burn_scale", 1.0))
	if world.shift.has_upgrade("oven_mitts"):
		k *= Tuning.OVEN_MITTS_MULT
	return k


## Burn-window multiplier in force (difficulty x upgrades).
func burn_scale() -> float:
	return _burn_scale()


## Cook-stage speed multiplier: Tuning.HOT_GRIDDLE_MULT with the hot_griddle upgrade (griddle and fryer).
func cook_speed() -> float:
	return Tuning.HOT_GRIDDLE_MULT if world != null and world.shift != null and world.shift.has_upgrade("hot_griddle") else 1.0


## Stage time with the cook speed applied (the burn stage already carries _burn_scale()).
func _limit(d: Dictionary, cook_stage: bool) -> float:
	var t := _stage_time(d, cook_stage)
	return t / cook_speed() if cook_stage else t


func _stage_time(d: Dictionary, cook_stage: bool) -> float:
	if not cook_stage:
		return Tuning.BURN_TIME * _burn_scale()
	return Tuning.CRACK_TIME if bool(d.get("crack", false)) else Tuning.COOK_TIME


func _cook_bar() -> int:
	return Item.Bar.COOK


## Host: the stage finished; change the food through the owning system.
func _transform(it: Item, k: String) -> void:
	world.change_kind(it, k)


## Host: a new item started cooking here (hook for sounds).
func _started(_it: Item) -> void:
	pass


# ----------------------------------------------------------------

## True when kind k's next change (along key()) is a cook stage, false for the burn stage.
func is_cook_stage(k: String) -> bool:
	var d: Dictionary = GameData.ITEMS[k]
	var nxt := str(d.get(key(), ""))
	return nxt != "" and GameData.ITEMS[nxt].has(key())


func host_update(dt: float) -> void:
	var k := key()
	var on: Dictionary = {}
	for it in world.items.values():
		if it.removed or not it.def.has(k) and not str(it.kind).ends_with("_burnt"):
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
			if on[id].def.has(k):
				_started(on[id])
	var slot := 0
	for id in _ids:
		var it: Item = on[id]
		if not it.def.has(k):
			it.set_cooking(false)
			it.bar_kind = Item.Bar.NONE
			continue
		if slot >= _slots():
			it.set_cooking(false)
			continue
		slot += 1
		it.set_cooking(true)
		it.cook_time += dt
		var cook := is_cook_stage(it.kind)
		var limit := _limit(it.def, cook)
		if it.cook_time >= limit:
			if world.shift.has_upgrade("hot_griddle") or world.shift.has_upgrade("oven_mitts"):
				print("upgrades: %s %s stage done after %.2fs" % [type, it.kind, limit])
			it.cook_time = 0.0
			_transform(it, str(it.def[k]))
			if not it.def.has(k):
				it.set_cooking(false)
				it.bar_kind = Item.Bar.NONE
				continue
			cook = is_cook_stage(it.kind)
			limit = _limit(it.def, cook)
		it.bar = it.cook_time / limit
		it.bar_kind = _cook_bar() if cook else Item.Bar.BURN


func reset() -> void:
	_ids.clear()
