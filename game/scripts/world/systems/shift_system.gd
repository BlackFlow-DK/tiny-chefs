class_name ShiftSystem
extends RefCounted
## Owns the shift flow (host): start/end, the clock, order expiry and "new order" announcements, the
## shop (try_buy), --upgrades, --recipes, --quit-after-shift. Data lives in world.shift / world.orders.
## Reads world.chefs/items and the stations to reset them. Calls world.remove_item, world.release, Net.

## Upgrades whose only effect is opening a station that carries "upgrade": <id> (Station.is_locked).
const STATION_UPGRADES := ["second_plate"]

var world: World
var _last_order_count := 0


func _init(w: World) -> void:
	world = w


## Testing: --upgrades=id:level,... (bare id = max level; old ids like knife work; clamped to 1..max) and
## --coins=<n> (start wallet, e.g. for shop screenshots). --upgrade-table prints every line's effect.
func apply_test_upgrades() -> void:
	for spec in Net.arg_str("upgrades", "").split(",", false):
		var f := spec.strip_edges().split(":")
		var id := GameData.upgrade_id(f[0])
		if GameData.upgrade(id).is_empty():
			push_warning("--upgrades: unknown upgrade '%s'" % f[0])
			continue
		var mx := GameData.upgrade_max_level(id)
		var lv := clampi(int(f[1]), 1, mx) if f.size() > 1 else mx
		world.shift.set_upgrade_level(id, maxi(lv, world.shift.upgrade_level(id)))
	if Net.has_arg("coins") and int(Net.metrics["coins_start"]) < 0:   # once per run (not on a map rebuild)
		world.shift.coins = Net.arg_int("coins", 0)
	for c in world.chefs.values():
		c.set_gloves(world.shift.has_upgrade("gloves"))
	if Net.has_arg("upgrade-table"):
		_print_table()


func start_shift() -> void:
	var shift := world.shift
	for it in world.items.values():
		world.remove_item(it)
	world.stats.begin_shift()
	for p in world.plates:
		p.clear_stack()
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
	world.orders.patience_mult = OrderManager.patience_mult_for(shift)
	_last_order_count = 0
	if int(Net.metrics["coins_start"]) < 0:
		Net.metrics["coins_start"] = shift.coins
	_log_upgrades()
	Net.event("Shift %d: %s. Earn %d coins!" % [shift.index + 1, shift.shift_name(), shift.target()], "start")


## Every host tick, after the stations.
func tick(dt: float, playing: bool) -> void:
	var shift := world.shift
	var orders := world.orders
	if playing and shift.running:
		shift.time_left -= dt
		for o in orders.update(dt, shift.def):
			var pen := OrderManager.expire_penalty(o, shift)   # VIPs cost double, insurance less
			if shift.has_upgrade("insurance"):
				print("upgrades: insurance expiry penalty %d (without %d)" % [pen, OrderManager.expire_penalty(o)])
			shift.add_coins(-pen)
			shift.failed += 1
			Net.event("%s%s order expired! -%d" % ["VIP " if o.get("vip", false) else "", GameData.RECIPES[int(o["r"])]["name"], pen], "fail")
			world.order_expired(o)
		if orders.last_spawned >= 2:
			Net.event("Rush! %d orders at once!" % orders.last_spawned, "order")
		elif orders.orders.size() > _last_order_count:
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
	info["stats"] = world.stats.results()   # replicated to clients with the phase info
	info["new_best"] = _save_best(shift)
	info.merge(world.finish_objectives())   # campaign: mission, objectives, stars (saved), next_mission
	Net.metrics["shifts_finished"] = int(Net.metrics["shifts_finished"]) + 1
	Net.metrics["result"] = info   # balance harness: shift, name, served, failed, earned, target, met, coins
	Net.set_phase(Net.Phase.RESULTS, info)
	if Net.has_arg("quit-after-shift"):
		# A SceneTree timer, not a World one: it survives Main rebuilding the World on a map change.
		var secs := 4.5 if Net.has_arg("results-shot") else 2.0   # let --results-shot (2.8 s) fire first
		Net.get_tree().create_timer(secs, true, false, true).timeout.connect(Net.finish_test)


## Host: best coins (this shift) per map + difficulty and per campaign mission. True when a new best.
func _save_best(shift: ShiftManager) -> bool:
	var earned := maxi(0, shift.earned)
	var fresh := Progress.set_best(str(shift.def.get("map", "")), str(shift.def.get("difficulty", "")), earned)
	var mid := int(shift.def.get("mission_id", -1))
	if mid >= 0:
		fresh = Progress.set_best_coins(mid, earned) or fresh
	return fresh and earned > 0


## Host, every shift start: every upgrade hook's value in force (no upgrades = the base numbers), so runs
## with and without upgrades compare line by line.
func _log_upgrades() -> void:
	print("upgrades: owned [%s] | %s" % [world.shift.upgrades_text(), _effects()])


## One line of every hook's current effect (reads the real hooks).
func _effects() -> String:
	var shift := world.shift
	var g := world.griddle
	var fr := world.fryer
	var disp: Dispenser = null
	for d in world.dispensers:
		if not d is SodaFountain:
			disp = d
			break
	var soda: Dispenser = world.soda
	var o := {"r": 0, "left": 1.0, "patience": 1.0}
	return ("griddle cook %.2fs burn %.2fs slots %d | fryer %s | chop %.2fs | dispense %s soda %s | move %.2f m/s | " +
		"patty solo %.2f duo %.2f m/s | reach %.2fm | patience x%.2f | pay %d (combo x5 %d) | expiry -%d | punch x%.2f | plates open %d/%d") % [
		Tuning.COOK_TIME / g.cook_speed(), Tuning.BURN_TIME * g.burn_scale(), g.slots(),
		"none" if fr == null else "fry %.2fs burn %.2fs slots %d" % [Tuning.FRY_TIME / fr.cook_speed(), Tuning.FRY_BURN_TIME * fr.burn_scale(), fr.slots()],
		Tuning.CHOP_TIME / world.board.chop_mult(),
		"none" if disp == null else "%.3fs" % disp.hold_time(), "none" if soda == null else "%.3fs" % soda.hold_time(),
		Tuning.PLAYER_SPEED * world.move_mult(),
		Tuning.PLAYER_SPEED * world.move_mult() * CarrySystem.speed_factor(1, 3, shift),
		Tuning.PLAYER_SPEED * world.move_mult() * CarrySystem.speed_factor(2, 3, shift),
		world.grab_reach(), OrderManager.patience_mult_for(shift),
		OrderManager.pay_for(o, shift), OrderManager.pay_for(o, shift, PlateSystem.combo_mult(shift, 5)),
		OrderManager.expire_penalty(o, shift), PunchSystem.launch_mult(shift),
		world.plates.filter(func(p: Plate) -> bool: return not p.is_locked()).size(), world.plates.size()]


## --upgrade-table: for every line, the hooks' effect line at level 1 and at max (requires owned too),
## then the owned levels are restored. Evidence for docs/upgrades.md.
func _print_table() -> void:
	var shift := world.shift
	var saved := shift.upgrades.duplicate()
	for id in GameData.upgrade_ids():
		var parts := PackedStringArray()
		for lv in [1, GameData.upgrade_max_level(id)]:
			shift.upgrades = {}
			var req := GameData.upgrade_requires(id)
			if not req.is_empty():
				shift.set_upgrade_level(str(req[0]), int(req[1]))
			shift.set_upgrade_level(id, lv)
			parts.append("L%d (%s): %s" % [lv, GameData.upgrade_value_text(id, lv), _effect_of(id)])
		print("upgrades: table %s | %s" % [id, " || ".join(parts)])
	shift.upgrades = saved


## The hook value one line changes (read through the real hook).
func _effect_of(id: String) -> String:
	var shift := world.shift
	var g := world.griddle
	var o := {"r": 0, "left": 1.0, "patience": 1.0}
	match id:
		"hot_griddle":
			return "griddle cook %.2fs, fryer %s" % [Tuning.COOK_TIME / g.cook_speed(),
				"-" if world.fryer == null else "%.2fs" % (Tuning.FRY_TIME / world.fryer.cook_speed())]
		"oven_mitts":
			return "griddle burn %.2fs" % (Tuning.BURN_TIME * g.burn_scale())
		"big_griddle":
			return "griddle slots %d (base %d, fit %d)" % [g.slots(), g.base_slots(), g.slot_fit()]
		"big_fryer":
			if world.fryer == null:
				return "no fryer on this map"
			return "fryer slots %d (base %d, fit %d)" % [world.fryer.slots(), world.fryer.base_slots(), world.fryer.slot_fit()]
		"sharp_knife":
			return "chop %.2fs" % (Tuning.CHOP_TIME / world.board.chop_mult())
		"quick_hands":
			var s := PackedStringArray()
			for d in world.dispensers:
				if not d is SodaFountain and s.size() < 2:
					s.append("%s %.3fs" % [d.def["label"], d.hold_time()])
			if world.soda != null:
				s.append("soda %.3fs" % world.soda.hold_time())
			return ", ".join(s)
		"shoes":
			return "move %.2f m/s, patty solo %.2f m/s" % [Tuning.PLAYER_SPEED * world.move_mult(),
				Tuning.PLAYER_SPEED * world.move_mult() * CarrySystem.speed_factor(1, 3, shift)]
		"protein_shake":
			return "patty (w3) solo %.2f duo %.2f m/s, bun (w1) %.2f m/s" % [Tuning.PLAYER_SPEED * CarrySystem.speed_factor(1, 3, shift),
				Tuning.PLAYER_SPEED * CarrySystem.speed_factor(2, 3, shift), Tuning.PLAYER_SPEED * CarrySystem.speed_factor(1, 1, shift)]
		"tongs":
			return "reach %.2fm" % world.grab_reach()
		"second_plate", "gloves":
			return "plates open %d/%d, punch %s" % [world.plates.filter(func(p: Plate) -> bool: return not p.is_locked()).size(),
				world.plates.size(), "on" if shift.has_upgrade("gloves") else "off"]
		"friendly_service":
			return "patience x%.2f" % OrderManager.patience_mult_for(shift)
		"tip_jar":
			return "cheeseburger pay %d (base %d)" % [OrderManager.pay_for(o, shift), OrderManager.pay_for(o)]
		"insurance":
			return "expiry penalty %d (base %d)" % [OrderManager.expire_penalty(o, shift), OrderManager.expire_penalty(o)]
		"combo_bell":
			return "pay x%.2f at step 1, x%.2f at step 5" % [PlateSystem.combo_mult(shift, 2), PlateSystem.combo_mult(shift, 6)]
		"heavy_gloves":
			return "punch launch x%.2f (food %.1f m/s)" % [PunchSystem.launch_mult(shift), Tuning.PUNCH_ITEM_SPEED * PunchSystem.launch_mult(shift)]
	return "?"


## Host: buy the NEXT level of a line (old ids work). Refused at max, when `requires` is not owned, when the
## station it opens is not on the next map, or when the wallet is short.
func try_buy(raw_id: String) -> void:
	var shift := world.shift
	if Net.phase != Net.Phase.SHOP and Net.phase != Net.Phase.RESULTS:
		return
	if ModifierSystem.skip_shop():
		return
	var id := GameData.upgrade_id(raw_id)
	var u := GameData.upgrade(id)
	if u.is_empty():
		return
	var lv := shift.upgrade_level(id) + 1
	var price := GameData.upgrade_price(id, lv)
	if price < 0:
		return   # already at max
	if not shift.requires_met(id):
		var req := GameData.upgrade_requires(id)
		Net.event("%s needs %s first." % [u["name"], GameData.upgrade_title(str(req[0]), int(req[1]))], "buzz")
		return
	if not upgrade_available(id, shift.next_index):
		Net.event("%s: not available on this kitchen." % u["name"], "buzz")
		return
	if shift.coins < price:
		Net.event("Not enough coins for %s." % GameData.upgrade_title(id, lv), "buzz")
		return
	shift.coins -= price
	shift.set_upgrade_level(id, lv)
	print("upgrades: bought %s level %d for %d (wallet %d) -> owned [%s]" % [id, lv, price, shift.coins, shift.upgrades_text()])
	Net.event("Bought %s!" % GameData.upgrade_title(id, lv), "buy")
	if id == "gloves":
		for c in world.chefs.values():
			c.set_gloves(true)


## False for an upgrade that only opens a station (MapDef station "upgrade", e.g. second_plate) when the
## next shift's map has no such station. Every peer (ShopView greys the card out with the same rule).
static func upgrade_available(id: String, next_index: int) -> bool:
	if not STATION_UPGRADES.has(id):
		return true
	for st in GameData.map(ShiftPlan.map_for(Net.settings, next_index)).get("stations", []):
		if str((st as Dictionary).get("upgrade", "")) == id:
			return true
	return false
