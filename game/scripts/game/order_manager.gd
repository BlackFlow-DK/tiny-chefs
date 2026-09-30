class_name OrderManager
extends RefCounted
## Open orders (host-authoritative, replicated as meta). Each: {"r": recipe index, "left": s, "patience": s}.

var orders: Array = []
var _timer := 0.0
var _spawned := 0
var _rng := RandomNumberGenerator.new()


func reset() -> void:
	orders.clear()
	_timer = Tuning.FIRST_ORDER_DELAY
	_spawned = 0
	_rng.randomize()


## Host tick. Returns the orders that expired this tick.
func update(dt: float, sdef: Dictionary) -> Array:
	_timer -= dt
	if orders.is_empty():
		_timer = minf(_timer, Tuning.EMPTY_ORDER_DELAY)
	if _timer <= 0.0 and orders.size() < Tuning.MAX_ORDERS:
		_spawn(sdef)
		_timer = float(sdef["interval"])
	var expired: Array = []
	for o in orders:
		o["left"] = float(o["left"]) - dt
		if float(o["left"]) <= 0.0:
			expired.append(o)
	for o in expired:
		orders.erase(o)
	return expired


func _spawn(sdef: Dictionary) -> void:
	var allowed: Array = sdef["recipes"]
	# The first order of a shift is always the first listed recipe (Cheeseburger on shift 1).
	var id: String = allowed[0] if _spawned == 0 else allowed[_rng.randi_range(0, allowed.size() - 1)]
	_spawned += 1
	var p := float(sdef["patience"])
	orders.append({"r": GameData.recipe_index(id), "left": p, "patience": p})


## Index of the open order whose recipe equals the plate contents (as a multiset), or -1.
## Prefers the order closest to expiring.
func match_plate(stack: Array) -> int:
	var have := stack.duplicate()
	have.sort()
	var best := -1
	for i in orders.size():
		var want: Array = GameData.RECIPES[int(orders[i]["r"])]["items"].duplicate()
		want.sort()
		if want == have and (best < 0 or float(orders[i]["left"]) < float(orders[best]["left"])):
			best = i
	return best


func to_meta() -> Array:
	var a: Array = []
	for o in orders:
		a.append([int(o["r"]), float(o["left"]), float(o["patience"])])
	return a


func from_meta(a: Array) -> void:
	orders.clear()
	for o in a:
		orders.append({"r": int(o[0]), "left": float(o[1]), "patience": float(o[2])})
