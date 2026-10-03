extends RefCounted
## Bot planning from data (used by bot.gd). Reads only the world view every peer has.
## analyse(): every open plate gets the most urgent open order its stack still fits; what is missing on it
##   is the "need". For each needed kind K, GameData.route(K) gives the chain dispenser -> (board) ->
##   (griddle | fryer) -> plate; food of that chain that is being carried, lies on its station or is being
##   dispensed (a teammate holding work at the dispenser) counts as "in flight" for K (times the pieces a later
##   chop makes). Needed minus in flight = the "units" still to start, slow (long route) kinds first.
## choose(): the job for this bot, in priority order: deliver what it holds; take finished food off the
##   griddle/fryer before it burns; ring a bell whose plate matches an order; scrape a plate holding food no
##   order wants or an unfinished stack in the wrong order (after 3 s);
## Stack order: food goes on a plate only when it keeps the stack tidy (Plate.tidy: base first, bun top
##   last); until then it waits beside the plate (plate_dest -> stage_dest) or where it lies.
##   help a teammate drag heavy food (weight >= 3); its claimed unit (index = rank among chefs, stride =
##   chef count) then, after 2 s without work, any unit; trash burnt food; stand by the cooking station.
## A unit job walks the route backwards: the finished kind lying loose -> plate; else for each station step
##   from the last: its input on the board -> chop, loose elsewhere -> carry it to the station; else dispense.

const PRI := {"deliver": 6, "rescue": 5, "bell": 4, "help": 3, "unit": 2, "cleanup": 1, "wait": 0}
const HEAVY := 3

var world: World
var active: Array = []    # [{plate, bell, order (index in world.orders.orders or -1), missing: Array, stale: bool}]
var need: Dictionary = {}  # kind -> count missing over the active plates
var units: Array = []      # kinds still to start (repeats allowed), claim order
var rank := 0
var team := 1
var blacklist: Dictionary = {}  # item id -> msec until which the bot ignores it
var _stale_since: Dictionary = {}  # plate instance id -> msec the stack first matched no order
var _routes: Dictionary = {}    # kind -> GameData.route(kind)
var _feasible: Dictionary = {}  # recipe index -> this map can make it
var deadline := INF             # s until needed food cooking on a station must be picked up (this bot minds it)
var watch: Station = null       # that station
var _nav: RefCounted = null      # bot_nav.gd instance, set by Bot (spot checks)


func _init(w: World) -> void:
	world = w


# ---------------------------------------------------------------- data helpers

func route(k: String) -> Array:
	if not _routes.has(k):
		_routes[k] = GameData.route(k)
	return _routes[k]


## Station node for a route step type, or null when the map lacks it.
func station(type: String) -> Station:
	match type:
		"griddle":
			return world.griddle
		"fryer":
			return world.fryer
		"board":
			return world.board
	return null


static func key_of(type: String) -> String:
	return str(GameData.TRANSFORM_KEYS.get(type, ""))


## Burnt (or otherwise useless) food: not servable and nothing turns it into anything.
static func is_junk(k: String) -> bool:
	return not bool(GameData.ITEMS[k]["plate"]) and GameData.transform_station(k) == ""


## True when kind k lying on its own transform station is finished: the next change is the burn stage.
static func is_done_stage(k: String) -> bool:
	var st := GameData.transform_station(k)
	if st == "":
		return false
	var key := key_of(st)
	var nxt := str(GameData.ITEMS[k].get(key, ""))
	return nxt != "" and not GameData.ITEMS[nxt].has(key)


func locked(s: Object) -> bool:
	return s != null and s.has_method("is_locked") and bool(s.call("is_locked"))


func plates() -> Array:
	var ps: Variant = world.get("plates")
	var out: Array = []
	if ps is Array and not (ps as Array).is_empty():
		for p in ps:
			if p != null and not locked(p):
				out.append(p)
	elif world.plate != null:
		out.append(world.plate)
	return out


func bell_for(p: Plate) -> Bell:
	var bs: Variant = world.get("bells")
	var list: Array = bs if bs is Array and not (bs as Array).is_empty() else [world.bell]
	var best: Bell = null
	var bd := INF
	for b in list:
		if b == null or locked(b):
			continue
		if b.get("plate") == p:
			return b
		var d: float = b.centre_distance(p.global_position)
		if d < bd:
			bd = d
			best = b
	return best


## True when this map can make every item of recipe index ri (its stations and dispensers exist).
func feasible(ri: int) -> bool:
	if _feasible.has(ri):
		return _feasible[ri]
	var ok := true
	for k in GameData.RECIPES[ri]["items"]:
		var r := route(k)
		var first := str(r[0]["kind"])
		if not world.dispensers.any(func(d: Dispenser) -> bool: return d.gives.has(first)):
			ok = false
		for i in range(1, r.size()):
			if station(str(r[i]["station"])) == null:
				ok = false
	_feasible[ri] = ok
	return ok


static func minus(want: Array, have: Array) -> Variant:
	var w := want.duplicate()
	for k in have:
		var i := w.find(k)
		if i < 0:
			return null
		w.remove_at(i)
	return w


func on_station(it: Item, s: Station) -> bool:
	return s != null and s.contains_xz(it.global_position) and it.global_position.y < 2.5


func is_blacklisted(it: Item) -> bool:
	return int(blacklist.get(it.item_id, 0)) > Time.get_ticks_msec()


## Loose food the bot may take: on the counter, low, not carried, not ignored.
func loose(it: Item) -> bool:
	if it.removed or it.carrier_count > 0 or is_blacklisted(it):
		return false
	var p := it.global_position
	return p.y > -1.0 and p.y < 2.0 and world.on_counter(Vector2(p.x, p.z))


# ---------------------------------------------------------------- analysis

func analyse(me: Chef) -> void:
	var ids: Array = world.chefs.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		var sa: int = world.chefs[a].slot
		var sb: int = world.chefs[b].slot
		return sa < sb or (sa == sb and a < b))
	team = maxi(1, ids.size())
	rank = maxi(0, ids.find(me.peer_id))
	var open: Array = []
	for i in world.orders.orders.size():
		open.append(i)
	open.sort_custom(func(a: int, b: int) -> bool:
		return float(world.orders.orders[a]["left"]) < float(world.orders.orders[b]["left"]))
	var max_active := maxi(1, (team + 1) / 2)
	active = []
	var used := {}
	for p in plates():
		var st: Array = p.stack
		if st.is_empty() and active.size() >= max_active:
			continue
		var e := {"plate": p, "bell": bell_for(p), "order": -1, "missing": [], "stale": false, "untidy": false}
		# The most urgent order the stack still fits tidily; else the most urgent it fits at all (untidy).
		var messy := -1
		var messy_rem: Variant = null
		for oi in open:
			if used.has(oi) or not feasible(int(world.orders.orders[oi]["r"])):
				continue
			var items: Array = GameData.RECIPES[int(world.orders.orders[oi]["r"])]["items"]
			var rem: Variant = minus(items, st)
			if rem == null:
				continue
			if not Plate.tidy(st, items):
				if messy < 0:
					messy = oi
					messy_rem = rem
				continue
			e["order"] = oi
			e["missing"] = rem
			break
		if int(e["order"]) < 0 and messy >= 0:
			e["order"] = messy
			e["missing"] = messy_rem
			e["untidy"] = true
		if int(e["order"]) >= 0:
			used[int(e["order"])] = true
		if int(e["order"]) < 0:
			if st.is_empty():
				continue
			e["stale"] = true
		active.append(e)
	need = {}
	var kinds: Array = []
	for e in active:
		for k in e["missing"]:
			need[k] = int(need.get(k, 0)) + 1
			if not kinds.has(k):
				kinds.append(k)
	# Slow (long route) kinds first, recipe order otherwise.
	var order: Array = []
	for i in kinds.size():
		order.append([-route(kinds[i]).size(), i, kinds[i]])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	units = []
	for o in order:
		var k: String = o[2]
		for _n in maxi(0, int(need[k]) - in_flight(k)):
			units.append(k)
	_find_deadline(me)


## deadline/watch: the needed food cooking soonest-to-burn on the griddle/fryer (remaining cook time + most of
## the burn window), minded only by the chef nearest that station, so it is back in time to take it off.
func _find_deadline(me: Chef) -> void:
	deadline = INF
	watch = null
	for s in [world.griddle, world.fryer]:
		if s == null:
			continue
		var key := key_of("fryer" if s == world.fryer else "griddle")
		var burn := (Tuning.FRY_BURN_TIME if s == world.fryer else Tuning.BURN_TIME) * float(world.shift.def.get("burn_scale", 1.0))
		if world.shift.has_upgrade("oven_mitts"):
			burn *= 1.5
		for it in world.items.values():
			if it.removed or it.carrier_count > 0 or not on_station(it, s) or not it.def.has(key) or is_done_stage(it.kind):
				continue
			if not _feeds_need(it.kind):
				continue
			var cook := Tuning.FRY_TIME if s == world.fryer else (Tuning.CRACK_TIME if bool(it.def.get("crack", false)) else Tuning.COOK_TIME)
			var t := (1.0 - clampf(it.bar, 0.0, 1.0)) * cook + burn * 0.6
			if t < deadline:
				deadline = t
				watch = s
	if watch == null:
		return
	var mine := _flat(watch.global_position - me.global_position).length()
	for c in world.chefs.values():
		if c != me and (c.flags & Chef.FLAG_RESPAWNING) == 0 and _flat(watch.global_position - c.global_position).length() < mine - 0.5:
			deadline = INF  # a teammate is nearer: they take it off
			watch = null
			return


## Seconds job j would keep me away (to the food, carry it, back to the watched station).
func job_time(me: Chef, j: Dictionary) -> float:
	if watch == null or j.is_empty():
		return 0.0
	var walk := Tuning.PLAYER_SPEED
	var back := watch.global_position
	match str(j["type"]):
		"fetch", "help":
			var it: Item = world.items.get(int(j["id"]))
			if it == null:
				return 0.0
			var carry := walk * clampf(1.0 / float(it.weight()), Tuning.CARRY_MIN_FACTOR, 1.0)
			var t_get: float = _nav.path_len(me.global_position, it.global_position) / walk
			return t_get + _nav.path_len(it.global_position, j["dest"]) / carry + _nav.path_len(j["dest"], back) / walk
		"dispense":
			var d: Dispenser = j["disp"]
			var k := str(j.get("k", ""))
			var r := route(k) if k != "" else []
			var next: Vector3 = plate_dest(k)["pos"] if r.size() < 2 or station(str(r[1]["station"])) == null else station(str(r[1]["station"])).global_position
			var w := float(GameData.ITEMS[str(r[0]["kind"])]["weight"]) if not r.is_empty() else 1.0
			var carry := walk * clampf(1.0 / w, Tuning.CARRY_MIN_FACTOR, 1.0)
			var hold: float = d.call("hold_time") if d.has_method("hold_time") else Tuning.DISPENSE_HOLD
			var t_go: float = _nav.path_len(me.global_position, d.stand_spot()) / walk + hold + 1.0
			return t_go + _nav.path_len(d.stand_spot(), next) / carry + _nav.path_len(next, back) / walk
		"chop":
			return _nav.path_len(me.global_position, j["spot"]) / walk + Tuning.CHOP_TIME + _nav.path_len(j["spot"], back) / walk
	return 0.0


## A job this bot may take now: it is back at the watched station before the food there burns.
func fits(me: Chef, j: Dictionary) -> bool:
	return j.is_empty() or watch == null or job_time(me, j) <= deadline


## Food on its way to becoming kind k (see the header): carried k, chain inputs carried or on their
## station, and teammates holding work at a dispenser of the chain's first kind.
func in_flight(k: String) -> int:
	var r := route(k)
	var chain: Array = []   # [kind, station type, yield]
	var yld := 1
	for i in range(r.size() - 1, 0, -1):
		var ck := str(r[i]["kind"])
		if str(r[i]["station"]) == "board":
			yld *= int(GameData.ITEMS[ck].get("chop_count", Tuning.CHOP_SLICES))
		chain.append([ck, str(r[i]["station"]), yld])
	# Food on the board only moves on while someone chops: count it when a teammate is at it.
	var board_worked := false
	if world.board != null:
		for c in world.chefs.values():
			if c.peer_id != world.my_id and (c.flags & Chef.FLAG_WORKING) != 0 and c.held_id < 0 					and world.board.footprint_distance(c.global_position) <= Tuning.REACH + 0.3:
				board_worked = true
	var n := 0
	for it in world.items.values():
		if it.removed:
			continue
		if it.kind == k:
			if it.carrier_count > 0:
				n += 1
			continue
		for c in chain:
			if it.kind != c[0]:
				continue
			if it.carrier_count > 0 or (on_station(it, station(c[1])) and (c[1] != "board" or board_worked)):
				n += int(c[2])
				break
	var first := str(r[0]["kind"])
	for c in world.chefs.values():
		if c.peer_id == world.my_id or (c.flags & Chef.FLAG_WORKING) == 0 or c.held_id >= 0:
			continue
		for d in world.dispensers:
			if d.gives.has(first) and d.footprint_distance(c.global_position) <= Tuning.REACH:
				n += yld
				break
	return n


# ---------------------------------------------------------------- choosing

## The job for chef me. idle: seconds this bot has had nothing but waiting to do (claims lapse after 2 s).
func choose(me: Chef, idle: float) -> Dictionary:
	analyse(me)
	if me.held_id >= 0:
		var held: Item = world.items.get(me.held_id)
		if held == null:
			return {"type": "drop", "pri": PRI["deliver"]}
		var d := dest_for(held)
		if d.is_empty():
			return {"type": "drop", "pri": PRI["deliver"]}
		return _fetch(held, d, "fetch", "deliver", held.kind)
	var j := _rescue(me)
	if not j.is_empty():
		return j
	j = _bell_job()
	if not j.is_empty():
		return j
	j = _help_job(me)
	if not j.is_empty() and fits(me, j):
		return j
	if world.items.size() >= Tuning.MAX_LOOSE_ITEMS - 3:
		j = _cleanup(me, true)
		if not j.is_empty():
			return j
	if not units.is_empty():
		var mine: Array = []
		for i in units.size():
			if i % team == rank:
				mine.append(units[i])
		for k in mine:
			j = unit_job(me, k)
			if not j.is_empty() and fits(me, j):
				return j
		if mine.is_empty() or idle >= 2.0:
			for k in units:
				j = unit_job(me, k)
				if not j.is_empty() and fits(me, j):
					return j
	j = _cleanup(me, false)
	if not j.is_empty() and fits(me, j):
		return j
	return _wait_job(me)


## Finished food on the griddle/fryer that a plate needs: off before it burns (nearest first).
func _rescue(me: Chef) -> Dictionary:
	var best: Item = null
	var bd := INF
	for it in world.items.values():
		if not loose(it) or int(need.get(it.kind, 0)) <= _carried(it.kind) or not is_done_stage(it.kind):
			continue
		if not on_station(it, station(GameData.transform_station(it.kind))):
			continue
		var d := _flat(it.global_position - me.global_position).length()
		if d < bd:
			bd = d
			best = it
	if best == null:
		return {}
	return _fetch(best, plate_dest(best.kind), "fetch", "rescue", best.kind)


func _bell_job() -> Dictionary:
	var now := Time.get_ticks_msec()
	for e in active:
		var p: Plate = e["plate"]
		var key := p.get_instance_id()
		if p.stack.is_empty() or e["bell"] == null:
			_stale_since.erase(key)
			continue
		# A stack no order wants, or an unfinished one in the wrong order: scrape it and start again (a
		# finished untidy dish is still served, at Tuning.MESSY_PAY). 3 s grace: a teammate may fix it.
		var bad := bool(e["stale"]) or (bool(e["untidy"]) and not (e["missing"] as Array).is_empty())
		if bad:
			if not _stale_since.has(key):
				_stale_since[key] = now
			if now - int(_stale_since[key]) < 3000:
				continue
			return {"type": "scrape", "plate": p, "stack": p.stack.duplicate(), "pri": PRI["bell"],
				"why": "stale" if bool(e["stale"]) else "untidy"}
		_stale_since.erase(key)
		if not (e["missing"] as Array).is_empty():
			continue
		return {"type": "bell", "bell": e["bell"], "plate": p, "stack": p.stack.duplicate(), "pri": PRI["bell"], "why": "serve"}
	return {}


func _help_job(me: Chef) -> Dictionary:
	for it in world.items.values():
		if it.removed or it.carrier_count < 1 or it.carrier_count >= it.weight() or it.weight() < HEAVY:
			continue
		if me.held_id == it.item_id:
			continue
		var dest := dest_for(it)
		if dest.is_empty():
			continue
		if _flat(dest["pos"] - it.global_position).length() > 6.0 and _flat(it.global_position - me.global_position).length() < 16.0:
			return _fetch(it, dest, "help", "help", it.kind)
	return {}


## The next step towards one more kind k (see header); {} when it only needs waiting (or is impossible).
func unit_job(me: Chef, k: String) -> Dictionary:
	# 1. The finished kind lying loose (finished food on its cook station first). One that may not go on
	#    its plate yet (stack order) waits where it lies: it is this unit, so nothing new is started.
	var best: Item = null
	var bd := INF
	for it in world.items.values():
		if it.kind != k or not loose(it):
			continue
		var ts := GameData.transform_station(k)
		var d := _flat(it.global_position - me.global_position).length()
		if ts != "" and on_station(it, station(ts)):
			if not is_done_stage(k):
				continue  # being turned into something else (onion slice in the fryer)
			d -= 100.0
		if d < bd:
			bd = d
			best = it
	if best != null:
		var dest := plate_dest(k)
		var ts := GameData.transform_station(k)
		if bool(dest.get("stage", false)) and not (ts != "" and on_station(best, station(ts))):
			return {}   # waits where it lies until the stack is ready for it (food on the griddle is still taken off)
		return _fetch(best, dest, "fetch", "unit", k)
	# 2. Walk the route backwards.
	var r := route(k)
	for i in range(r.size() - 1, 0, -1):
		var st := str(r[i]["station"])
		var ck := str(r[i]["kind"])
		var s := station(st)
		if s == null or locked(s):
			return {}
		if st == "board" and board_has(ck):
			return {"type": "chop", "kind": ck, "spot": work_spot(s, me, true), "pri": PRI["unit"], "k": k}
		var src: Item = null
		var sd := INF
		for it in world.items.values():
			if it.kind != ck or not loose(it) or on_station(it, s):
				continue
			var d := _flat(it.global_position - me.global_position).length()
			if d < sd:
				sd = d
				src = it
		if src != null:
			return _fetch(src, station_dest(s, src), "fetch", "unit", k)
	# 3. Dispense the first kind.
	var first := str(r[0]["kind"])
	var disp: Dispenser = null
	var dd := INF
	for d in world.dispensers:
		if not d.gives.has(first) or locked(d):
			continue
		var dist := _flat(d.stand_spot() - me.global_position).length()
		if dist < dd:
			dd = dist
			disp = d
	if disp == null:
		return {}
	if world.items.size() + disp.gives.size() > Tuning.MAX_LOOSE_ITEMS:
		return _cleanup(me, true)
	return {"type": "dispense", "disp": disp, "pri": PRI["unit"], "k": k}


## Trash burnt food; with force also food no plate needs (the counter is nearly full).
func _cleanup(me: Chef, force: bool) -> Dictionary:
	if world.trash == null:
		return {}
	var useful := {}
	for k in need:
		useful[k] = true
		for s in route(k):
			useful[str(s["kind"])] = true
	var best: Item = null
	var bd := INF
	for it in world.items.values():
		if not loose(it):
			continue
		var junk := is_junk(it.kind)
		if not junk and (not force or useful.has(it.kind)):
			continue
		var d := _flat(it.global_position - me.global_position).length() + (0.0 if junk else 50.0)
		if d < bd:
			bd = d
			best = it
	if best == null:
		return {}
	return _fetch(best, {"pos": world.trash.global_position, "r": maxf(0.6, world.trash.half.x - 1.0)}, "fetch", "cleanup", best.kind)


## Nothing to start: stand by a station where needed food cooks, else by the first open plate.
func _wait_job(me: Chef) -> Dictionary:
	for s in [world.griddle, world.fryer, world.board]:
		if s == null:
			continue
		for it in world.items.values():
			if not it.removed and on_station(it, s) and it.carrier_count == 0 and _feeds_need(it.kind):
				return {"type": "wait", "pos": work_spot(s, me, false), "pri": PRI["wait"], "at": s.def.get("label", "")}
	var p: Station = active[0]["plate"] if not active.is_empty() else world.plate
	if p == null:
		return {}
	return {"type": "wait", "pos": work_spot(p, me, false), "pri": PRI["wait"], "at": "plate"}


func _feeds_need(kind: String) -> bool:
	for k in need:
		if k == kind:
			return true
		for s in route(k):
			if str(s["kind"]) == kind:
				return true
	return false


# ---------------------------------------------------------------- destinations

## Where food of this item's kind goes (the same rule on every bot, so helpers push the carrier's way):
## junk -> trash; a kind a plate misses -> that plate; an input of a needed kind's route -> that station.
func dest_for(it: Item) -> Dictionary:
	var k: String = it.kind
	if is_junk(k):
		return {} if world.trash == null else {"pos": world.trash.global_position, "r": maxf(0.6, world.trash.half.x - 1.0)}
	if int(need.get(k, 0)) > 0 and bool(it.def["plate"]):
		return plate_dest(k)
	for nk in need:
		var r := route(nk)
		for i in range(1, r.size()):
			if str(r[i]["kind"]) == k:
				var s := station(str(r[i]["station"]))
				if s != null:
					return station_dest(s, it)
	return {}


## Where kind k goes: the plate missing it; a spot beside that plate ("stage": true) while k may not go on
## yet because the stack must stay tidy (base first, bun top last: Plate.tidy).
func plate_dest(k: String) -> Dictionary:
	var p: Plate = null
	var pe: Dictionary = {}
	for e in active:
		if (e["missing"] as Array).has(k):
			p = e["plate"]
			pe = e
			break
	if p == null:
		p = active[0]["plate"] if not active.is_empty() else world.plate
	if not pe.is_empty() and not allowed_now(pe, k):
		return stage_dest(p, k)
	return {"pos": p.global_position, "r": maxf(0.8, p.half.x - 1.2), "station": p}


## True when kind k may go on active entry e's plate now and keep the stack tidy for its order.
func allowed_now(e: Dictionary, k: String) -> bool:
	if int(e["order"]) < 0:
		return true
	var items: Array = GameData.RECIPES[int(world.orders.orders[int(e["order"])]["r"])]["items"]
	var st: Array = (e["plate"] as Plate).stack.duplicate()
	st.append(k)
	return Plate.tidy(st, items)


## A spot on the counter beside plate p for food of kind k to wait at (off the plate, off every station,
## clear of other loose food where possible).
func stage_dest(p: Plate, k: String) -> Dictionary:
	var sz: Vector3 = GameData.ITEMS[k]["size"]
	var rad := maxf(sz.x, sz.z) * 0.5
	var dist := maxf(p.half.x, p.half.y) + rad + 0.8
	var best := p.global_position + Vector3(0, 0, -dist)
	var bs := -INF
	for i in 8:
		var a := TAU * float(i) / 8.0
		var c := p.global_position + Vector3(sin(a), 0, -cos(a)) * dist
		if _nav != null and (not _nav.inside(c, rad + 0.3) or _nav.blocked(c, rad + 0.3)):
			continue
		var clear := true
		for s in world.stations:
			if s.contains_xz(c, rad + 0.4):
				clear = false
				break
		if not clear:
			continue
		var score := 20.0 - float(i) * 0.01   # behind the plate first, then round
		for o in world.items.values():
			if o.removed or o.carrier_count > 0 or o.kind == k:
				continue
			score = minf(score, _flat(o.global_position - c).length() - o.radius() - rad)
		if score > bs:
			bs = score
			best = c
	return {"pos": best, "r": 0.7, "stage": true}


## A free spot on station s for item it: a 3 x 2 grid inset by the item's radius, the one farthest from
## other food lying there (the board and small stations: the centre).
func station_dest(s: Station, it: Item) -> Dictionary:
	var pos := s.global_position
	var rad := it.radius()
	var ix := s.half.x - rad - 0.3
	var iz := s.half.y - rad - 0.3
	if s != world.board and ix > 0.5:
		var best_score := -INF
		for gx in [-1.0, 0.0, 1.0]:
			for gz in [-1.0, 1.0]:
				var c := s.global_position + Vector3(gx * ix, 0, gz * maxf(0.0, iz) * 0.5)
				var score := 20.0
				for o in world.items.values():
					if o == it or o.removed or o.carrier_count > 0 or not on_station(o, s):
						continue
					score = minf(score, _flat(o.global_position - c).length() - o.radius())
				score -= 0.01 * _flat(c - s.global_position).length()
				if score > best_score:
					best_score = score
					pos = c
	return {"pos": pos, "r": 0.9, "station": s}


## Food that the board would chop, of kind k, lying on it.
func board_has(k: String) -> bool:
	if world.board == null:
		return false
	for it in world.items.values():
		if it.kind == k and not it.removed and it.carrier_count == 0 and world.board.contains_xz(it.global_position) and it.global_position.y < 3.0:
			return true
	return false


## A spot beside station s to stand at (within reach of it), on the counter, clear of solid things; with
## working, also out of reach of every dispenser and bell (holding work there would dispense / count as
## the bell, not scrape a plate). Nearest to me.
func work_spot(s: Station, me: Chef, working: bool) -> Vector3:
	var nav = _nav
	var best := s.global_position + Vector3(0, 0, s.half.y + 0.7)
	var bd := INF
	var hx := s.half.x + 0.7
	var hz := s.half.y + 0.7
	var cands: Array = []
	for f in [-0.6, 0.0, 0.6]:
		cands.append(Vector3(f * s.half.x, 0, hz))
		cands.append(Vector3(f * s.half.x, 0, -hz))
		cands.append(Vector3(hx, 0, f * s.half.y))
		cands.append(Vector3(-hx, 0, f * s.half.y))
	for c in cands:
		var p: Vector3 = s.global_position + c
		if nav != null and (not nav.inside(p, 0.7) or nav.blocked(p, 0.5) or nav.near_gate(p, 3.0)):
			continue
		if working:
			var near_disp := false
			for d in world.dispensers:
				if d.footprint_distance(p) <= Tuning.REACH + 0.3:
					near_disp = true
					break
			for b in world.bells:
				if b.footprint_distance(p) <= Tuning.REACH + 0.3:
					near_disp = true
					break
			if near_disp:
				continue
		var d := _flat(p - me.global_position).length()
		if d < bd:
			bd = d
			best = p
	return best


func _fetch(it: Item, dest: Dictionary, type: String, why: String, k: String) -> Dictionary:
	var j := {"type": type, "id": it.item_id, "dest": dest["pos"], "r": dest["r"], "pri": PRI[why], "why": why, "k": k}
	if dest.has("station"):
		j["station"] = dest["station"]
	return j


func _carried(k: String) -> int:
	var n := 0
	for it in world.items.values():
		if it.kind == k and it.carrier_count > 0:
			n += 1
	return n


## One line for --bot-log.
func summary() -> String:
	var parts: Array = []
	for e in active:
		var p: Plate = e["plate"]
		var o := int(e["order"])
		var rid := "stale" if bool(e["stale"]) else str(GameData.RECIPES[int(world.orders.orders[o]["r"])]["id"])
		if bool(e.get("untidy", false)):
			rid += "(untidy)"
		parts.append("%s:%s stack %s missing %s" % [p.def.get("label", "plate"), rid, str(p.stack), str(e["missing"])])
	var ords: Array = []
	for o in world.orders.orders:
		ords.append("%s %.0fs" % [GameData.RECIPES[int(o["r"])]["id"], float(o["left"])])
	var w := "" if watch == null else " watch %s %.1fs" % [watch.def.get("label", "?"), deadline]
	return "orders [%s] plates [%s] units %s claim %d/%d%s" % [", ".join(ords), ", ".join(parts), str(units), rank, team, w]


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
