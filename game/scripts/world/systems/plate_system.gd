class_name PlateSystem
extends RefCounted
## Owns serving at the bell (match the plate against the orders, pay or penalise) and bouncing
## raw/burnt/whole food off the plate. Host only. Snapping food onto the stack lives in stations/plate.gd.
## Reads/writes world.plate, world.orders, world.shift. Calls world.toast, world.note_orders_changed, Net.

var world: World
var _total_served := 0


func _init(w: World) -> void:
	world = w


## Every tick, before the stations: refused/punched food may land on the plate again once this runs out.
func tick(dt: float) -> void:
	for it in world.items.values():
		it.refuse_cooldown = maxf(0.0, it.refuse_cooldown - dt)


## A fresh work press: next to the bell with empty hands, serve the plate.
func on_work_pressed(c: Chef) -> void:
	if c.holding == null and c.respawn_timer < 0.0 and world.bell.footprint_distance(c.global_position) <= Tuning.REACH:
		_serve(c)


func refuse_from_plate(it: Item, p: Station) -> void:
	var dir := it.global_position - p.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	it.linear_velocity = dir.normalized() * 9.0 + Vector3.UP * 5.0
	it.refuse_cooldown = 1.2
	var k := str(it.kind)
	var msg := "Chop it on the cutting board first!"
	if k.ends_with("_burnt"):
		msg = "Burnt food can't be served. Trash it!"
	elif it.def.has("fries_to"):
		msg = "Raw! Fry it in the fryer first."
	elif it.def.has("cooks_to"):
		msg = "Raw! Cook it on the griddle first."
	world.toast(msg, "buzz")


func _serve(c: Chef) -> void:
	var plate := world.plate
	var orders := world.orders
	var shift := world.shift
	if plate.stack.is_empty():
		Net.event("Put food on the plate first!", "buzz", c.peer_id)
		return
	var idx := orders.match_plate(plate.stack)
	if idx >= 0:
		var o: Dictionary = orders.orders[idx]
		var r: Dictionary = GameData.RECIPES[int(o["r"])]
		var frac := clampf(float(o["left"]) / float(o["patience"]), 0.0, 1.0)
		var pay := int(r["price"]) + int(round(float(r["bonus"]) * frac))
		shift.add_coins(pay)
		shift.served += 1
		orders.orders.remove_at(idx)
		world.note_orders_changed()
		_total_served += 1
		Net.metrics["orders_served"] = _total_served
		(Net.metrics["served_recipes"] as Array).append(r["name"])
		print("content: served %s %s +%d" % [r["id"], str(plate.stack), pay])
		Net.event("%s served! +%d" % [r["name"], pay], "serve")
	else:
		shift.add_coins(-Tuning.WRONG_SERVE_PENALTY)
		Net.event("That matches no order! -%d" % Tuning.WRONG_SERVE_PENALTY, "buzz")
	plate.clear_stack()
