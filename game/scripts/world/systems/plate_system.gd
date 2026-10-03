class_name PlateSystem
extends RefCounted
## Owns serving at the bell (match the plate against the orders, pay or penalise) and bouncing
## raw/burnt/whole food off the plate. Host only. Snapping food onto the stack lives in stations/plate.gd.
## Any number of plate + bell pairs (world.plates/bells): a bell serves its own plate (Bell.plate); a closed
## (locked) bell only says which upgrade opens it.
## Reads/writes world.bells/plates, world.orders, world.shift. Calls world.toast, world.note_orders_changed, Net.

var world: World
var _total_served := 0
var _streak := 0          # combo_bell: serves in the current streak (each within COMBO_WINDOW of the last)
var _since_serve := INF   # s since the last good serve this shift


func _init(w: World) -> void:
	world = w


## Combo bell pay multiplier for the streak-th serve in a row: 1 + value x min(streak - 1, COMBO_MAX_STEPS).
static func combo_mult(shift: ShiftManager, streak: int) -> float:
	var steps := clampi(streak - 1, 0, Tuning.COMBO_MAX_STEPS)
	return 1.0 + shift.upgrade_value("combo_bell", 0.0) * float(steps)


## Every tick, before the stations: refused/punched food may land on the plate again once this runs out.
func tick(dt: float) -> void:
	for it in world.items.values():
		it.refuse_cooldown = maxf(0.0, it.refuse_cooldown - dt)
	if world.shift.running:
		_since_serve += dt
	else:
		_streak = 0
		_since_serve = INF


## A fresh work press: next to a bell with empty hands, serve that bell's plate.
func on_work_pressed(c: Chef) -> void:
	if c.holding != null or c.respawn_timer >= 0.0:
		return
	var b := bell_near(c.global_position)
	if b == null:
		return
	if b.is_locked() or b.plate == null or b.plate.is_locked():
		Net.event("Closed! Buy %s in the shop." % b.unlock_name(), "buzz", c.peer_id)
		return
	_serve(c, b)


## Every peer: the bell within reach of p (nearest), or null.
func bell_near(p: Vector3) -> Bell:
	var best: Bell = null
	var bd := Tuning.REACH
	for b in world.bells:
		var d := b.footprint_distance(p)
		if d <= bd:
			best = b
			bd = d
	return best


## msg overrides the kind-based message (closed plate).
func refuse_from_plate(it: Item, p: Station, msg := "") -> void:
	var dir := it.global_position - p.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	it.linear_velocity = dir.normalized() * 9.0 + Vector3.UP * 5.0
	it.refuse_cooldown = 1.2
	var k := str(it.kind)
	if msg.is_empty():
		msg = "Chop it on the cutting board first!"
		if k.ends_with("_burnt"):
			msg = "Burnt food can't be served. Trash it!"
		elif it.def.has("fries_to"):
			msg = "Raw! Fry it in the fryer first."
		elif it.def.has("cooks_to"):
			msg = "Raw! Cook it on the griddle first."
	world.toast(msg, "buzz")


func _serve(c: Chef, b: Bell) -> void:
	var plate := b.plate
	var orders := world.orders
	var shift := world.shift
	b.ring()
	if world.plates.size() > 1:
		print("plate: serve at bell %d (%s) -> plate %d, stack %s" % [world.bells.find(b) + 1, b.def["label"],
			world.plates.find(plate) + 1, str(plate.stack)])
	if plate.stack.is_empty():
		Net.event("Put food on the plate first!", "buzz", c.peer_id)
		return
	var idx := orders.match_plate(plate.stack)
	if idx >= 0:
		var o: Dictionary = orders.orders[idx]
		var r: Dictionary = GameData.RECIPES[int(o["r"])]
		_streak = _streak + 1 if _since_serve <= Tuning.COMBO_WINDOW else 1
		_since_serve = 0.0
		var combo := combo_mult(shift, _streak)
		var pay := OrderManager.pay_for(o, shift, combo)   # x VIP_PAY_MULT for a VIP order, x tip_jar, x combo
		shift.add_coins(pay)
		shift.served += 1
		world.stats.on_serve(c, pay, plate)
		orders.orders.remove_at(idx)
		world.note_orders_changed()
		_total_served += 1
		Net.metrics["orders_served"] = _total_served
		(Net.metrics["served_recipes"] as Array).append(r["name"])
		print("content: served %s %s +%d" % [r["id"], str(plate.stack), pay])
		Net.event("%s served! +%d" % [r["name"], pay], "serve")
		if combo > 1.0:
			print("upgrades: combo x%d pays x%.2f (+%d coins of %d)" % [_streak, combo, pay - OrderManager.pay_for(o, shift), pay])
			Net.event("Combo x%d! +%d%%" % [_streak, int(round((combo - 1.0) * 100.0))], "combo")
		elif shift.has_upgrade("tip_jar"):
			print("upgrades: tip_jar pay %d (without %d)" % [pay, OrderManager.pay_for(o)])
		world.order_served(o, pay)
	else:
		shift.add_coins(-Tuning.WRONG_SERVE_PENALTY)
		Net.event("That matches no order! -%d" % Tuning.WRONG_SERVE_PENALTY, "buzz")
	plate.clear_stack()
