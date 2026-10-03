class_name OrderManager
extends RefCounted
## Open orders (host-authoritative, replicated as meta). Each: {"r": recipe index, "left": s, "patience": s},
## plus "vip": true on a VIP order (EventSystem's vip event; pays Tuning.VIP_PAY_MULT, gold ticket).

var orders: Array = []
var _timer := 0.0
var _spawned := 0
var last_spawned := 0   # orders added by the last update() (2-3 = a burst: ModifierSystem.bursts)
var patience_mult := 1.0   # host: new orders wait this much longer (friendly_service; set at shift start)
var _rng := RandomNumberGenerator.new()


func reset() -> void:
	orders.clear()
	_timer = Tuning.FIRST_ORDER_DELAY
	_spawned = 0
	_rng.randomize()


## Host tick. Returns the orders that expired this tick.
func update(dt: float, sdef: Dictionary) -> Array:
	_timer -= dt
	last_spawned = 0
	if orders.is_empty():
		_timer = minf(_timer, Tuning.EMPTY_ORDER_DELAY)
	if _timer <= 0.0 and orders.size() < Tuning.MAX_ORDERS:
		# Bursts (rush_hour / chaos): 2-3 at once, then a gap as long as that many intervals (same rate).
		var n := 1
		if _spawned > 0 and ModifierSystem.bursts(sdef):
			n = ModifierSystem.burst_size(_rng, Tuning.MAX_ORDERS - orders.size())
		for i in n:
			_spawn(sdef)
		last_spawned = n
		_timer = float(sdef["interval"]) * n
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
	var p := float(sdef["patience"]) * patience_mult
	orders.append({"r": GameData.recipe_index(id), "left": p, "patience": p})


## Host: a VIP order for a random allowed recipe with VIP_PATIENCE_MULT of the shift's patience.
## May exceed MAX_ORDERS by one (regular orders wait until there is room again).
func add_vip(sdef: Dictionary) -> Dictionary:
	var allowed: Array = sdef["recipes"]
	var id: String = allowed[_rng.randi_range(0, allowed.size() - 1)]
	var p := float(sdef["patience"]) * Tuning.VIP_PATIENCE_MULT * patience_mult
	var o := {"r": GameData.recipe_index(id), "left": p, "patience": p, "vip": true}
	orders.append(o)
	return o


## Patience multiplier for new orders: 1 + friendly_service value.
static func patience_mult_for(shift: ShiftManager) -> float:
	return 1.0 + shift.upgrade_value("friendly_service", 0.0)


## Coins for serving order o now: price + bonus scaled by patience left, then in this order:
## x Tuning.MESSY_PAY for an untidy plate (tidy = false), x (1 + tip_jar value) and x `extra`
## (combo_bell, PlateSystem.combo_mult) when shift is given, x VIP_PAY_MULT for a VIP.
static func pay_for(o: Dictionary, shift: ShiftManager = null, extra := 1.0, tidy := true) -> int:
	var r: Dictionary = GameData.RECIPES[int(o["r"])]
	var frac := clampf(float(o["left"]) / float(o["patience"]), 0.0, 1.0)
	var mult := 1.0 if tidy else Tuning.MESSY_PAY
	if shift != null:
		mult *= (1.0 + shift.upgrade_value("tip_jar", 0.0)) * extra
	if bool(o.get("vip", false)):
		mult *= Tuning.VIP_PAY_MULT
	return int(round((float(r["price"]) + round(float(r["bonus"]) * frac)) * mult))


## Coins lost when order o expires (VIPs cost VIP_EXPIRE_MULT times as much), x (1 - insurance value)
## when shift is given.
static func expire_penalty(o: Dictionary, shift: ShiftManager = null) -> int:
	var pen := Tuning.EXPIRE_PENALTY * (Tuning.VIP_EXPIRE_MULT if bool(o.get("vip", false)) else 1)
	if shift == null:
		return pen
	return int(round(float(pen) * maxf(0.0, 1.0 - shift.upgrade_value("insurance", 0.0))))


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
		a.append([int(o["r"]), float(o["left"]), float(o["patience"]), 1 if bool(o.get("vip", false)) else 0])
	return a


func from_meta(a: Array) -> void:
	orders.clear()
	for o in a:
		var d := {"r": int(o[0]), "left": float(o[1]), "patience": float(o[2])}
		if o.size() > 3 and int(o[3]) != 0:
			d["vip"] = true
		orders.append(d)
