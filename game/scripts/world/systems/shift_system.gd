class_name ShiftSystem
extends RefCounted
## Owns the shift flow (host): start/end, the clock, order expiry and "new order" announcements, the
## shop (try_buy), --upgrades, --recipes, --quit-after-shift. Data lives in world.shift / world.orders.
## Reads world.chefs/items and the stations to reset them. Calls world.remove_item, world.release, Net.

var world: World
var _last_order_count := 0
var _quit_timer := -1.0


func _init(w: World) -> void:
	world = w


## --upgrades=gloves,knife,shoes (testing).
func apply_test_upgrades() -> void:
	for u in Net.arg_str("upgrades", "").split(",", false):
		if not GameData.upgrade(u).is_empty() and not world.shift.has_upgrade(u):
			world.shift.upgrades.append(u)


func start_shift() -> void:
	var shift := world.shift
	for it in world.items.values():
		world.remove_item(it)
	world.plate.clear_stack()
	world.board.reset()
	world.griddle.reset()
	if world.fryer != null:
		world.fryer.reset()
	for c in world.chefs.values():
		world.release(c)
		c.respawn()
	if int(Net.metrics["coins_start"]) < 0:   # first start of the run: --start-shift=<n> (balance harness)
		shift.next_index = Net.arg_int("start-shift", shift.next_index)
	shift.begin(shift.next_index, maxi(1, world.chefs.size()), Net.arg_float("shift-seconds", 0.0))
	Net.metrics["players"] = maxi(1, world.chefs.size())
	# --recipes=<id,...> (agent tests): this shift orders only these recipes (first one first).
	var only: Array = []
	for id in Net.arg_str("recipes", "").split(",", false):
		if GameData.recipe_index(id) >= 0:
			only.append(id)
	if not only.is_empty():
		shift.def["recipes"] = only
	world.orders.reset()
	_last_order_count = 0
	if int(Net.metrics["coins_start"]) < 0:
		Net.metrics["coins_start"] = shift.coins
	Net.event("Shift %d: %s. Earn %d coins!" % [shift.index + 1, shift.shift_name(), shift.target()], "start")


## Every host tick, after the stations.
func tick(dt: float, playing: bool) -> void:
	var shift := world.shift
	var orders := world.orders
	if playing and shift.running:
		shift.time_left -= dt
		for o in orders.update(dt, shift.def):
			var pen := OrderManager.expire_penalty(o)   # VIPs cost double
			shift.add_coins(-pen)
			shift.failed += 1
			Net.event("%s%s order expired! -%d" % ["VIP " if o.get("vip", false) else "", GameData.RECIPES[int(o["r"])]["name"], pen], "fail")
			world.order_expired(o)
		if orders.orders.size() > _last_order_count:
			var newest: Dictionary = orders.orders[orders.orders.size() - 1]
			Net.event("New order: %s" % GameData.RECIPES[int(newest["r"])]["name"], "order")
		_last_order_count = orders.orders.size()
		if shift.time_left <= 0.0:
			shift.time_left = 0.0
			_end_shift()
	Net.metric_max("coins_max", shift.coins)
	Net.metrics["coins_final"] = shift.coins


## An order left the list outside tick() (served): keep the count in step so the next new one is announced.
func sync_order_count() -> void:
	_last_order_count = world.orders.orders.size()


func _end_shift() -> void:
	var shift := world.shift
	shift.running = false
	var met := shift.earned >= shift.target()
	shift.next_index = shift.index + 1 if met else shift.index
	world.orders.orders.clear()
	for c in world.chefs.values():
		world.release(c)
	var info := {"shift": shift.index, "name": shift.shift_name(), "served": shift.served, "failed": shift.failed,
		"earned": shift.earned, "target": shift.target(), "met": met, "coins": shift.coins}
	Net.metrics["shifts_finished"] = int(Net.metrics["shifts_finished"]) + 1
	Net.metrics["result"] = info   # balance harness: shift, name, served, failed, earned, target, met, coins
	Net.set_phase(Net.Phase.RESULTS, info)
	if Net.has_arg("quit-after-shift"):
		_quit_timer = 2.0


func try_buy(id: String) -> void:
	var shift := world.shift
	if Net.phase != Net.Phase.SHOP and Net.phase != Net.Phase.RESULTS:
		return
	var u := GameData.upgrade(id)
	if u.is_empty() or shift.has_upgrade(id):
		return
	if shift.coins < int(u["price"]):
		Net.event("Not enough coins for %s." % u["name"], "buzz")
		return
	shift.coins -= int(u["price"])
	shift.upgrades.append(id)
	Net.event("Bought %s!" % u["name"], "buy")
	if id == "gloves":
		for c in world.chefs.values():
			c.set_gloves(true)


## Every frame on every peer (only ever armed on the host): --quit-after-shift countdown.
func process_quit(delta: float) -> void:
	if _quit_timer > 0.0:
		_quit_timer -= delta
		if _quit_timer <= 0.0:
			Net.finish_test()
