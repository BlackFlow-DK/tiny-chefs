class_name Plate
extends Station
## Finished food dropped on the plate snaps onto a visible stack (any order; serving an untidy one pays
## Tuning.MESSY_PAY, see tidy()). Raw, burnt or whole food bounces off. A map may have several plates
## (World.plates); one with an "upgrade" in its def is closed (lid + sign, everything bounces off) until
## that upgrade is owned. PlateSystem takes the top item back off (grab) and scrapes it (hold work).

const BASES := ["bun_bottom", "hotdog_bun"]   # a recipe holding one of these must start with it

var stack: Array = []  # item kinds, bottom first
var _stack_root: Node3D
var _shown: Array = []
var _cover: Node3D     # lid + "CLOSED" sign, shown while is_locked()
var _sway_t := 99.0    # visual: seconds since food last landed on the stack (damped wobble, every peer)
var _sway_dir := Vector2.RIGHT
var _top: Node3D       # the newest model on the stack (squashes as it lands)


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


func _process(delta: float) -> void:
	if _cover != null:
		_cover.visible = is_locked()
	if _sway_t < 2.0:
		_sway_t += delta
		var e := exp(-Tuning.PLATE_SWAY_RATE * _sway_t)
		var a := deg_to_rad(Tuning.PLATE_SWAY_DEG) * e * sin(Tuning.PLATE_SWAY_FREQ * _sway_t)
		if _sway_t >= 2.0:
			a = 0.0
		_stack_root.rotation = Vector3(a * _sway_dir.y, 0.0, -a * _sway_dir.x)
		if _top != null and is_instance_valid(_top):
			var s := 0.25 * e * cos(Tuning.PLATE_SWAY_FREQ * 1.6 * _sway_t) if _sway_t < 2.0 else 0.0
			_top.scale = Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5)


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
			print("content: plate took %s #%d (%d on the plate) at (%.1f, %.1f) v %.1f" % [it.kind, it.item_id,
				stack.size(), it.global_position.x, it.global_position.z, it.linear_velocity.length()])
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


## Host: pop the top kind off the stack ("" when empty). PlateSystem spawns it as loose food.
func take_top() -> String:
	if stack.is_empty():
		return ""
	var k: String = stack.pop_back()
	_refresh()
	return k


# ---------------------------------------------------------------- stack order (every peer)

## The item a recipe's stack must start with: its bun when it has one, else its first item.
static func base_kind(items: Array) -> String:
	for b in BASES:
		if items.has(b):
			return b
	return str(items[0]) if not items.is_empty() else ""


## True when stack (bottom first, a sub-multiset of items) is tidy for a recipe with these items: the
## base first, and a bun_top only on top of every item the recipe lists before it (items after it, like
## a meal's fries and soda, and inner items are free).
static func tidy(st: Array, items: Array) -> bool:
	if st.is_empty() or items.is_empty():
		return true
	if str(st[0]) != base_kind(items):
		return false
	var ti := items.find("bun_top")
	var si := st.find("bun_top")
	if ti >= 0 and si >= 0:
		var below := st.slice(0, si)
		for k in items.slice(0, ti):
			var j := below.find(k)
			if j < 0:
				return false
			below.remove_at(j)
	return true


## True when stack is a sub-multiset of items (more food could still make it that recipe).
static func fits(st: Array, items: Array) -> bool:
	var w := items.duplicate()
	for k in st:
		var j := w.find(k)
		if j < 0:
			return false
		w.remove_at(j)
	return true


func is_tidy_so_far(recipe: Dictionary) -> bool:
	return Plate.tidy(stack, recipe["items"])


## Every peer: a gentle warning ("" when none) when the stack could still become one of the open
## orders, but none of them tidily. orders: OrderManager.orders.
func order_warning(orders: Array) -> String:
	if stack.is_empty():
		return ""
	var why := ""
	for o in orders:
		var items: Array = GameData.RECIPES[int(o["r"])]["items"]
		if not Plate.fits(stack, items):
			continue
		if Plate.tidy(stack, items):
			return ""
		if why.is_empty():
			var base := Plate.base_kind(items)
			if str(stack[0]) != base:
				var label := "bun" if BASES.has(base) else str(GameData.ITEMS[base]["label"]).to_lower()
				why = "Wrong order: %s first!" % label
			else:
				why = "Wrong order: bun top goes last!"
	return why


## Height above the plate node of the base of stack item i, as drawn by _refresh().
func item_base_y(i: int) -> float:
	var y := 0.05
	for j in mini(i, stack.size()):
		y += (GameData.ITEMS[stack[j]]["size"] as Vector3).y * 0.9
	return y


## World position of the top item's base centre (the plate centre when empty).
func top_position() -> Vector3:
	return global_position + Vector3(0, item_base_y(stack.size() - 1) if not stack.is_empty() else 0.05, 0)


# ---------------------------------------------------------------- effects (every peer)

## A one-shot burst over the plate: "sparkle" (tidy serve) or "puff" (scraped).
func burst(kind: String) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = half.x * 0.5
	p.direction = Vector3.UP
	p.spread = 70.0
	var m := SphereMesh.new()
	if kind == "sparkle":
		p.amount = 22
		p.lifetime = 0.8
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -4.0, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		m.radius = 0.12
		m.height = 0.24
		m.material = Models.mat(UITheme.MUSTARD.lightened(0.35), true)
	else:
		p.amount = 18
		p.lifetime = 0.6
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.5
		p.gravity = Vector3(0, 1.5, 0)
		p.damping_min = 2.0
		p.damping_max = 3.0
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.6
		m.radius = 0.22
		m.height = 0.44
		m.material = Models.mat(Color(0.93, 0.9, 0.86), false)
	p.mesh = m
	p.position = Vector3(0, 0.6, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


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
		if st != stack and Net.has_arg("plate-log"):
			print("plate: client sees plate %d stack %s" % [world.plates.find(self) + 1, str(st)])
		stack = st
		_refresh()


func _refresh() -> void:
	if _shown == stack:
		return
	var grew := stack.size() > _shown.size()
	_shown = stack.duplicate()
	_top = null
	for c in _stack_root.get_children():
		c.queue_free()
	var y := 0.0
	for k in stack:
		var d: Dictionary = GameData.ITEMS[k]
		var sz: Vector3 = d["size"]
		var m := Models.make(k, sz, d["color"], d["shape"])
		m.position = Vector3(0, y, 0)
		_stack_root.add_child(m)
		_top = m
		y += sz.y * 0.9
	if grew:
		# Visual only: the stack wobbles about the plate centre, a different way each time.
		_sway_t = 0.0
		var ang := float(stack.size()) * 2.4
		_sway_dir = Vector2(cos(ang), sin(ang))
	elif stack.is_empty():
		_sway_t = 99.0
		_stack_root.rotation = Vector3.ZERO
