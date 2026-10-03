class_name FoodPhysicsSystem
extends RefCounted
## Owns how loose food feels (docs/design/polish-2.md section 2). Host only; runs in World._simulate after
## carrying and the edge check, before the stations. Jolt does the rigid-body work (item-item collisions,
## piles, sliding); this adds what Jolt should not decide on its own:
##   landing   a drop of more than LAND_MIN_SPEED: one scripted bounce (if armed by a drop, toss or launch),
##             a squash on every peer (Item.on_landed -> replicated landing counter), egg splat
##   rolling   round food glides on low friction and slows by ROLL_DECEL, settling below ROLL_STOP;
##             its visual tumble follows the motion (replicated), carried round food rights itself
##   grip      food on a griddle / fryer / cutting board loses horizontal speed fast, so a gentle toss
##             onto a station stays there (a chef walking into it still shoves it off)
##   pile cap  loose food that was not launched never moves faster than PILE_MAX_SPEED (overlap pops)
## Reads world.items, world.stations. Calls Item.on_landed/host_tumble/set_kind, Net.event.
## --physics-log: landings, bounces, splats. --physics-test=<pile|toss|egg|griddle|cheese|sway|long>:
## a scripted scene (FoodPhysicsTest) for screenshots and logs.

var world: World
var _grip: Array = []          # stations food grips on (griddle, fryer, board)
var _grip_ready := false
var _log := Net.has_arg("physics-log")


func _init(w: World) -> void:
	world = w
	if Net.has_arg("physics-test") or Net.has_arg("physics-shots") or Net.has_arg("physics-shot"):
		var t: Node = preload("res://scripts/world/systems/food_physics_test.gd").new()
		t.call("setup", w)
		w.add_child.call_deferred(t)


func host_tick(dt: float) -> void:
	if not _grip_ready:
		_grip_ready = true
		for s in world.stations:
			if s is Griddle or s is CuttingBoard:
				_grip.append(s)
	for it: Item in world.items.values():
		if it.removed:
			continue
		if it.is_carried() or it.freeze:
			it.host_tumble(Vector3.ZERO, dt, true)
			it.prev_vel = Vector3.ZERO
			continue
		var v := it.linear_velocity
		var v0 := v
		var pv := it.prev_vel
		var st := _grip_station(it)
		if pv.y < -Tuning.LAND_MIN_SPEED and v.y > pv.y * 0.4:
			v = _land(it, pv, v, st)
			if it.removed or not is_instance_valid(it):
				continue
		var grounded := absf(v.y) < 0.4
		if it.round_kind:
			_round_grip(it)
		if it.round_kind and grounded:
			var h := Vector3(v.x, 0.0, v.z)
			var sp := h.length()
			if sp > 0.0:
				var ns := maxf(sp - Tuning.ROLL_DECEL * dt, 0.0)
				if ns < Tuning.ROLL_STOP:
					ns = 0.0
				v.x *= ns / sp
				v.z *= ns / sp
		if st != null and grounded:
			var k := exp(-Tuning.STATION_GRIP * dt)
			v.x *= k
			v.z *= k
		if not it.launched and v.length() > Tuning.PILE_MAX_SPEED:
			v = v.limit_length(Tuning.PILE_MAX_SPEED)
		if not v.is_equal_approx(v0):
			it.linear_velocity = v
		it.host_tumble(v, dt, false)
		it.prev_vel = v


## Round food glides on the counter but grips on a pile (so it settles instead of creeping off it).
## Under slippery the ModifierSystem friction stays.
func _round_grip(it: Item) -> void:
	var pm := it.physics_material_override
	if pm == null or bool(it.get_meta("slip", false)):
		return
	var f := Tuning.ROUND_GROUND_FRICTION if it.global_position.y < 0.15 else Tuning.ROUND_FRICTION
	if not is_equal_approx(pm.friction, f):
		pm.friction = f


## The station a grounded loose item is lying on and should grip it (null when none).
func _grip_station(it: Item) -> Station:
	if it.global_position.y > 0.4:
		return null
	for s: Station in _grip:
		if s.contains_xz(it.global_position) and not s.is_locked():
			return s
	return null


## It just hit something below it (pv: velocity last tick, v: now). Returns the velocity to keep.
func _land(it: Item, pv: Vector3, v: Vector3, st: Station) -> Vector3:
	var impact := pv.length()
	var power := clampf(-pv.y / Tuning.SQUASH_FULL_SPEED, 0.0, 1.0)
	it.on_landed(power)
	if it.kind == "egg" and it.launched and impact > Tuning.EGG_SPLAT_SPEED:
		_splat(it, impact)
		it.launched = false
		it.bounce_armed = false
		return Vector3(v.x * 0.3, minf(v.y, 0.0), v.z * 0.3)
	var bounced := 0.0
	if it.bounce_armed:
		it.bounce_armed = false
		bounced = clampf(-pv.y * Tuning.BOUNCE_KEEP, Tuning.BOUNCE_MIN_UP, Tuning.BOUNCE_MAX_UP)
		v.y = bounced
	if st != null:
		v.x *= Tuning.STATION_LAND_KEEP
		v.z *= Tuning.STATION_LAND_KEEP
	if _log:
		print("physics: item %d %s landed at %.2f m/s (down %.2f) bounce %.2f%s pos %s" % [it.item_id, it.kind, impact,
			-pv.y, bounced, " on %s" % st.type if st != null else "", it.global_position.snapped(Vector3.ONE * 0.01)])
	it.launched = false
	return v


func _splat(it: Item, impact: float) -> void:
	it.set_kind("egg_splat")
	print("content: egg splat (item %d landed at %.2f m/s) at %s" % [it.item_id, impact, it.global_position.snapped(Vector3.ONE * 0.01)])
	Net.event("Splat! That egg is waste now.", "crack")
	Net.metrics["egg_splats"] = int(Net.metrics.get("egg_splats", 0)) + 1
