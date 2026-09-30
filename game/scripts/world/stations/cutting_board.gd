class_name CuttingBoard
extends Station
## Any food with "chops_to" lying on the board (tomato, onion, potato) is chopped while chefs stand at the
## board holding work; CuttingBoardSystem turns it into its chop_count pieces.
## Rate: one chef = CHOP_TIME seconds, each extra chef adds the same rate; Sharp Knife doubles it.

var progress := 0.0
var chopping := false
var food_local := Vector3.ZERO
var has_food := false
var has_tomato: bool:    # old name (bot, hint): any choppable food, not only tomatoes
	get:
		return has_food
var _food_id := -1
var _knife: Node3D
var _t := 0.0
var _last_phase := 0


func build() -> void:
	var v := Models.load_model("cutting_board")
	if v == null:
		v = Node3D.new()
		v.add_child(box(size, Color(0.6, 0.42, 0.25), Vector3.ZERO))
		v.add_child(box(Vector3(size.x - 0.6, 0.02, size.z - 0.6), Color(0.88, 0.72, 0.5), Vector3(0, size.y - 0.01, 0)))
	add_flat_visual(v)
	_knife = Models.load_model("knife")
	if _knife == null:
		_knife = Node3D.new()
		_knife.add_child(box(Vector3(5.0, 0.3, 1.4), Color(0.82, 0.84, 0.88), Vector3(1.0, 0, 0)))
		_knife.add_child(box(Vector3(2.0, 0.35, 0.6), Color(0.08, 0.08, 0.08), Vector3(-2.5, 0, 0)))
	add_child(_knife)
	_rest_knife()
	add_label("Cutting board", Vector3(0, 1.5, -half.y - 0.8))


func _rest_knife() -> void:
	_knife.position = Vector3(0, 0.05, half.y - 1.0)
	_knife.rotation = Vector3.ZERO


func host_update(dt: float) -> void:
	var food: Item = null
	for it in world.items.values():
		if it.removed or it.is_carried() or not it.def.has("chops_to"):
			continue
		if contains_xz(it.global_position) and it.global_position.y < 3.0:
			if food == null or it.item_id == _food_id:
				food = it
	if food == null:
		progress = 0.0
		chopping = false
		has_food = false
		_food_id = -1
		return
	if food.item_id != _food_id:
		progress = 0.0
		_food_id = food.item_id
	has_food = true
	var n := workers(0.3).size()
	chopping = n > 0
	food_local = food.global_position - global_position
	if chopping:
		var mult := Tuning.KNIFE_MULT if world.shift.has_upgrade("knife") else 1.0
		progress += dt * float(n) * mult / Tuning.CHOP_TIME
	food.bar = progress
	food.bar_kind = Item.Bar.CHOP
	if progress >= 1.0:
		world.chop(food)
		progress = 0.0
		chopping = false
		has_food = false
		_food_id = -1


func reset() -> void:
	progress = 0.0
	chopping = false
	has_food = false
	_food_id = -1


func state() -> Variant:
	return [progress, chopping, food_local, has_food]


func apply_state(s: Variant) -> void:
	if s is Array and s.size() >= 4:
		progress = s[0]
		chopping = s[1]
		food_local = s[2]
		has_food = s[3]


func work_hint() -> String:
	return "hold F: chop" if has_food else ""


func _process(delta: float) -> void:
	if chopping:
		_t += delta * 13.0
		var lift := absf(sin(_t))
		_knife.position = food_local + Vector3(0.8, 0.9 + lift * 2.6, 0)
		_knife.rotation = Vector3(PI * 0.5, 0, 0)
		var ph := int(_t / PI)
		if ph != _last_phase:
			_last_phase = ph
			Sfx.play("chop")
	else:
		_rest_knife()
