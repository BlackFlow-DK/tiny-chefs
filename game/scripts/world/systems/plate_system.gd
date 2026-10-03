class_name PlateSystem
extends RefCounted
## Owns serving at the bell (match the plate against the orders, pay or penalise; an untidy stack pays
## Tuning.MESSY_PAY), bouncing raw/burnt/whole food off the plate, taking the top item back off (a grab
## aimed at the plate: take_candidate / take_top, chosen by CarrySystem through World) and scraping a plate
## (hold work on it, not at a bell, for Tuning.SCRAPE_HOLD). Host only, except take_candidate and
## scrape_target (the hint uses them). Snapping food onto the stack lives in stations/plate.gd.
## Any number of plate + bell pairs (world.plates/bells): a bell serves its own plate (Bell.plate); a closed
## (locked) bell only says which upgrade opens it, a closed plate can be neither taken from nor scraped.
## Reads/writes world.bells/plates, world.orders, world.shift. Calls world.toast, world.note_orders_changed, Net.

var world: World
var _total_served := 0
var _streak := 0          # combo_bell: serves in the current streak (each within COMBO_WINDOW of the last)
var _since_serve := INF   # s since the last good serve this shift
var _scrape: Dictionary = {}   # peer id -> [Plate, seconds held] (seconds -1 = spent until work is released)


func _init(w: World) -> void:
	world = w


## Combo bell pay multiplier for the streak-th serve in a row: 1 + value x min(streak - 1, COMBO_MAX_STEPS).
static func combo_mult(shift: ShiftManager, streak: int) -> float:
	var steps := clampi(streak - 1, 0, Tuning.COMBO_MAX_STEPS)
	return 1.0 + shift.upgrade_value("combo_bell", 0.0) * float(steps)


## Every tick, before the stations: refused/punched food may land on the plate again once this runs out;
## chefs holding work on a plate scrape it.
func tick(dt: float) -> void:
	for it in world.items.values():
		it.refuse_cooldown = maxf(0.0, it.refuse_cooldown - dt)
	if world.shift.running:
		_since_serve += dt
	else:
		_streak = 0
		_since_serve = INF
	_scrape_tick(dt)


# ---------------------------------------------------------------- take off (grab)

## Every peer: the plate whose top item a grab press by chef c would take, as [Plate, aim score], or []
## when none. Reach is to the plate footprint (as for working it). With aim: only a plate within
## GRAB_AIM_RADIUS of the aim point (score = its footprint distance + a little centre distance, the same
## scale as CarrySystem's loose food); without aim: the nearest plate in reach (score INF).
func take_candidate(c: Chef, inp: PlayerInput, reach: float) -> Array:
	var p := c.global_position
	var aim := inp.aim3()
	var best: Plate = null
	var bs := INF
	for pl in world.plates:
		if pl.stack.is_empty() or pl.is_locked() or pl.footprint_distance(p) > reach:
			continue
		var s := INF
		if inp.has_aim:
			var da := pl.footprint_distance(aim)
			if da > Tuning.GRAB_AIM_RADIUS:
				continue
			s = da + 0.05 * pl.centre_distance(aim)
		else:
			s = 1000.0 + pl.footprint_distance(p)
		if best == null or s < bs:
			best = pl
			bs = s
	if best == null:
		return []
	return [best, bs if inp.has_aim else INF]


## Host: chef c's grab took plate pl's top item: it becomes loose food at the top of the stack (the
## caller attaches it). Null when there is nothing to take.
func take_top(c: Chef, pl: Plate) -> Item:
	if pl.is_locked() or pl.stack.is_empty():
		return null
	var at := pl.top_position()
	var k := pl.take_top()
	var it := world.spawn_item(k, at)
	print("content: plate %d gave %s back to chef %d (%d left: %s)" % [world.plates.find(pl) + 1, k, c.peer_id,
		pl.stack.size(), str(pl.stack)])
	Net.metrics["plate_takes"] = int(Net.metrics.get("plate_takes", 0)) + 1
	return it


# ---------------------------------------------------------------- scrape (hold work)

## Every peer: the plate chef standing at p would scrape by holding work, or null. Holding work there
## must not mean anything else: no bell, dispenser or cutting board with food within its reach.
func scrape_target(p: Vector3) -> Plate:
	if bell_near(p) != null:
		return null
	for d in world.dispensers:
		if d.footprint_distance(p) <= Tuning.REACH:
			return null
	if world.board != null and world.board.has_food and world.board.footprint_distance(p) <= Tuning.REACH + 0.3:
		return null
	var best: Plate = null
	var bd := Tuning.REACH
	for pl in world.plates:
		if pl.stack.is_empty() or pl.is_locked():
			continue
		var d := pl.footprint_distance(p)
		if d <= bd:
			best = pl
			bd = d
	return best


func _scrape_tick(dt: float) -> void:
	for c: Chef in world.chefs.values():
		var id := c.peer_id
		var pl: Plate = null
		if c.work_held and c.holding == null and c.respawn_timer < 0.0:
			pl = scrape_target(c.global_position)
		if pl == null:
			_scrape.erase(id)
			continue
		var e: Array = _scrape.get(id, [pl, 0.0])
		if e[0] != pl:
			e = [pl, 0.0]
		if float(e[1]) >= 0.0:
			e[1] = float(e[1]) + dt
			if float(e[1]) >= Tuning.SCRAPE_HOLD:
				e[1] = -1.0
				_scrape_plate(c, pl)
		_scrape[id] = e
	for id in _scrape.keys():
		if not world.chefs.has(id):
			_scrape.erase(id)


func _scrape_plate(c: Chef, pl: Plate) -> void:
	var n := pl.stack.size()
	print("content: chef %d scraped plate %d %s (%d items wasted)" % [c.peer_id, world.plates.find(pl) + 1, str(pl.stack), n])
	world.stats.on_scraped(c, n)
	Net.metrics["scraped_items"] = int(Net.metrics.get("scraped_items", 0)) + n
	Net.metrics["scrapes"] = int(Net.metrics.get("scrapes", 0)) + 1
	pl.clear_stack()
	Net.event(str(world.plates.find(pl)), "scrape")   # swoosh + puff over that plate (IndicatorLayer)


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
	it.launch(dir.normalized() * 9.0 + Vector3.UP * 5.0, false)   # bounces, but a refused egg does not splat
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
		var tidy := plate.is_tidy_so_far(r)
		# x MESSY_PAY when untidy, then x tip_jar and x combo, then x VIP_PAY_MULT for a VIP order
		var pay := OrderManager.pay_for(o, shift, combo, tidy)
		shift.add_coins(pay)
		shift.served += 1
		world.stats.on_serve(c, pay, plate, tidy)
		orders.orders.remove_at(idx)
		world.note_orders_changed()
		_total_served += 1
		Net.metrics["orders_served"] = _total_served
		(Net.metrics["served_recipes"] as Array).append(r["name"])
		var key := "tidy_serves" if tidy else "messy_serves"
		Net.metrics[key] = int(Net.metrics.get(key, 0)) + 1
		print("content: served %s %s +%d %s (full pay %d)" % [r["id"], str(plate.stack), pay,
			"tidy" if tidy else "messy", OrderManager.pay_for(o, shift, combo)])
		Net.event("%s served! +%d" % [r["name"], pay], "serve")
		if combo > 1.0:
			print("upgrades: combo x%d pays x%.2f (+%d coins of %d)" % [_streak, combo,
				pay - OrderManager.pay_for(o, shift, 1.0, tidy), pay])
			Net.event("Combo x%d! +%d%%" % [_streak, int(round((combo - 1.0) * 100.0))], "combo")
		elif shift.has_upgrade("tip_jar"):
			print("upgrades: tip_jar pay %d (without %d)" % [pay, OrderManager.pay_for(o, null, 1.0, tidy)])
		if tidy:
			Net.event(str(world.plates.find(plate)), "tidy")   # "Tidy!" pop + sparkle over that plate
		else:
			Net.event("Messy plate! -%d%%" % roundi((1.0 - Tuning.MESSY_PAY) * 100.0), "messy")
		world.order_served(o, pay)
	else:
		shift.add_coins(-Tuning.WRONG_SERVE_PENALTY)
		Net.event("That matches no order! -%d" % Tuning.WRONG_SERVE_PENALTY, "buzz")
	plate.clear_stack()
