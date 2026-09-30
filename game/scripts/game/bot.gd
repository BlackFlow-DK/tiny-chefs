class_name Bot
extends RefCounted
## --bot: plays the game through the exact PlayerInput a human produces (move vector, held
## work, grab/work press counters), reading only the world view every peer has (so it works
## on clients too). Strategy: build the most urgent order; help teammates carrying heavy food.

var world: World
var _job: Dictionary = {}
var _job_time := 0.0
var _press_wait := 0.0
var _work_timer := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _sidestep := 0.0
var _side_dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _last_log := ""
var _idle_t := 0.0
var _aside_t := 0.0  # dragging a wrongly grabbed item out of the way  # pause after letting go, so we do not grab the same food again


func _init(w: World) -> void:
	world = w
	_rng.randomize()


func update(dt: float, inp: PlayerInput) -> void:
	inp.move = Vector2.ZERO
	inp.work = false
	_press_wait = maxf(0.0, _press_wait - dt)
	var me := world.my_chef()
	if Net.phase != Net.Phase.PLAYING or me == null or (me.flags & Chef.FLAG_RESPAWNING) != 0:
		_job = {}
		return
	if _idle_t > 0.0:
		_idle_t -= dt
		return
	_job_time += dt
	if _job.is_empty() or _job_time > 20.0:
		_job = _choose(me)
		_job_time = 0.0
		_work_timer = 0.0
		if Net.has_arg("bot-log") and _describe(_job) != _last_log:
			_last_log = _describe(_job)
			print("bot %d: %.1fs %s | plate %s | pos %s" % [me.peer_id, Time.get_ticks_msec() / 1000.0, _describe(_job), world.plate.stack, me.global_position.snapped(Vector3.ONE * 0.1)])
	if Net.has_arg("bot-log") and Engine.get_physics_frames() % 60 == 0:
		var jt := ""
		if _job.has("id") and world.items.has(int(_job["id"])):
			var ji: Item = world.items[int(_job["id"])]
			jt = "item %s at %s carriers %d fd %.2f" % [ji.kind, ji.global_position.snapped(Vector3.ONE * 0.1), ji.carrier_count, ji.footprint_distance(me.global_position)]
		print("bot %d:   at %s held %d job %s %s" % [me.peer_id, me.global_position.snapped(Vector3.ONE * 0.1), me.held_id, _describe(_job), jt])
	if _job.is_empty():
		var idle := Vector3(-2, 0, 3.5)
		if not world.on_counter(Vector2(idle.x, idle.z)):
			idle = world.map["spawn_points"][0]
		_walk_to(me, idle, inp, dt, null)
		if world.shift.has_upgrade("gloves") and _press_wait <= 0.0:
			inp.punch_seq += 1  # idle: show off the gloves
			_press_wait = 1.5
		return
	match str(_job["type"]):
		"fetch", "help":
			_do_fetch(me, inp, dt)
		"drop":
			_let_go(inp)
		"dispense":
			_do_dispense(me, inp, dt)
		"chop":
			_do_chop(me, inp, dt)
		"bell":
			_do_bell(me, inp, dt)


# ---------------------------------------------------------------- planning

func _choose(me: Chef) -> Dictionary:
	if me.held_id >= 0:
		var held: Item = world.items.get(me.held_id)
		if held != null:
			var dest := _dest_for(held.kind)
			if not dest.is_empty():
				return _fetch(held, dest, "fetch")
		return {"type": "drop"}
	# Help a teammate dragging something heavy.
	for it in world.items.values():
		if it.carrier_count >= 1 and it.carrier_count < it.weight():
			var dest := _dest_for(it.kind)
			if dest.is_empty():
				continue
			if _flat(dest["pos"] - it.global_position).length() > 6.0 and _flat(it.global_position - me.global_position).length() < 16.0:
				return _fetch(it, dest, "help")
	var plan := _needs()
	var need: Array = plan["need"]
	if need.is_empty():
		if not world.plate.stack.is_empty():
			return {"type": "bell"}
		return _cleanup_job()
	var kinds: Array = []
	for k in need:
		if not kinds.has(k):
			kinds.append(k)
	# Things that take time first (cooking, chopping); spread the rest between bots by slot.
	var slow: Array = kinds.filter(func(k: String) -> bool: return k.ends_with("_cooked") or k == "tomato_slice")
	var fast: Array = kinds.filter(func(k: String) -> bool: return not (k.ends_with("_cooked") or k == "tomato_slice"))
	if me.slot % 2 == 1:
		fast.reverse()
	for k in slow + fast:
		var job := _job_for_kind(me, k, need.count(k))
		if not job.is_empty():
			return job
	return _cleanup_job()


## Remaining ingredients for the most urgent order the plate still fits into.
func _needs() -> Dictionary:
	var stack: Array = world.plate.stack
	var open: Array = world.orders.orders.duplicate()
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["left"]) < float(b["left"]))
	for o in open:
		var want: Array = GameData.RECIPES[int(o["r"])]["items"].duplicate()
		var ok := true
		for k in stack:
			var i := want.find(k)
			if i < 0:
				ok = false
				break
			want.remove_at(i)
		if ok:
			return {"need": want}
	return {"need": []}


func _job_for_kind(me: Chef, k: String, count: int) -> Dictionary:
	var plate_dest := {"pos": world.plate.global_position, "r": 1.4}
	if _carried_count(k) >= count:
		return {}  # teammates are already bringing enough of these
	var loose := _loose_of(me, k, true)
	if loose != null:
		return _fetch(loose, plate_dest, "fetch")
	if k.ends_with("_cooked"):
		var raw := k.replace("_cooked", "_raw")
		var cooking := 0
		for it in world.items.values():
			if it.kind == raw and world.griddle.contains_xz(it.global_position):
				cooking += 1
		if cooking >= count:
			return {}
		var r := _loose_of(me, raw, false)
		if r != null:
			return _fetch(r, {"pos": world.griddle.global_position, "r": 2.0}, "fetch")
		if _carried_count(raw) > 0:
			return {}
		return _dispense_job(raw)
	if k == "tomato_slice":
		if world.board.has_tomato:
			return {"type": "chop"}
		var t := _loose_of(me, "tomato", false)
		if t != null:
			return _fetch(t, {"pos": world.board.global_position, "r": 1.5}, "fetch")
		if _carried_count("tomato") > 0:
			return {}
		return _dispense_job("tomato")
	return _dispense_job(k)


func _cleanup_job() -> Dictionary:
	for it in world.items.values():
		if str(it.kind).ends_with("_burnt") and it.carrier_count == 0:
			return _fetch(it, {"pos": world.trash.global_position, "r": 1.0}, "fetch")
	return {}


func _fetch(it: Item, dest: Dictionary, type: String) -> Dictionary:
	return {"type": type, "id": it.item_id, "dest": dest["pos"], "r": dest["r"]}


func _dispense_job(k: String) -> Dictionary:
	for d in world.dispensers:
		if d.gives.has(k):
			return {"type": "dispense", "disp": d}
	return {}


## Where a kind of food belongs (same rule on every bot, so helpers agree with carriers).
func _dest_for(k: String) -> Dictionary:
	var d: Dictionary = GameData.ITEMS[k]
	if k.ends_with("_raw"):
		return {"pos": world.griddle.global_position, "r": 2.0}
	if d.has("chops_to"):
		return {"pos": world.board.global_position, "r": 1.5}
	if k.ends_with("_burnt"):
		return {"pos": world.trash.global_position, "r": 1.0}
	if bool(d["plate"]):
		return {"pos": world.plate.global_position, "r": 1.4}
	return {}


## Nearest uncarried item of kind k (optionally excluding food lying on its source station).
func _loose_of(me: Chef, k: String, _any_place: bool) -> Item:
	var best: Item = null
	var bd := INF
	for it in world.items.values():
		if it.kind != k or it.carrier_count > 0 or it.removed:
			continue
		if k.ends_with("_raw") and world.griddle.contains_xz(it.global_position):
			continue
		if k == "tomato" and world.board.contains_xz(it.global_position):
			continue
		var d := _flat(it.global_position - me.global_position).length()
		if d < bd:
			bd = d
			best = it
	return best


func _carried_count(k: String) -> int:
	var n := 0
	for it in world.items.values():
		if it.kind == k and it.carrier_count > 0:
			n += 1
	return n


# ---------------------------------------------------------------- acting

func _do_fetch(me: Chef, inp: PlayerInput, dt: float) -> void:
	var it: Item = world.items.get(int(_job["id"]))
	if it == null:
		_job = {}
		return
	var dest: Vector3 = _job["dest"]
	var help := str(_job["type"]) == "help"
	if me.held_id == it.item_id:
		var to := _flat(dest - it.global_position)
		var alone_helper := help and it.carrier_count <= 1 and _job_time > 1.0
		if to.length() <= float(_job["r"]) or alone_helper:
			_let_go(inp)
			return
		var dir := to.normalized() * clampf(to.length() / 2.0, 0.5, 1.0)
		var via := _route(me.global_position, dest)
		if via != dest:  # another surface: carry it over the joining surface first
			dir = _flat(via - me.global_position).normalized() * 0.7
		dir = _unstick(me, dir, dt)
		inp.move = Vector2(dir.x, dir.z)
		return
	if me.held_id >= 0:
		# Grabbed the wrong food: drag it aside a moment, then let go (keep the job).
		var held: Item = world.items.get(me.held_id)
		_aside_t += dt
		if held != null and _aside_t < 0.9:
			var away := _flat(held.global_position - it.global_position)
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			away = away.normalized()
			inp.move = Vector2(away.x, away.z)
		else:
			_press_grab(inp)
		return
	_aside_t = 0.0
	if not help and it.carrier_count > 0:
		_job = {}  # someone else took it; re-plan (maybe help)
		return
	if help and (it.carrier_count == 0 or _job_time > 8.0):
		_job = {}
		return
	if it.footprint_distance(me.global_position) <= Tuning.REACH - 0.2:
		if world.grab_candidate(me, inp) == it:
			_press_grab(inp)
			return
		# Something else is nearer: squeeze in towards our food.
		var d := _unstick(me, _flat(it.global_position - me.global_position).normalized() * 0.6, dt)
		inp.move = Vector2(d.x, d.z)
		return
	var to_dest := _flat(dest - it.global_position)
	var fwd := to_dest.normalized() if to_dest.length() > 0.1 else Vector3(0, 0, 1)
	var approach: Vector3
	if help:
		var perp := Vector3(-fwd.z, 0, fwd.x)
		if perp.dot(me.global_position - it.global_position) < 0.0:
			perp = -perp
		approach = it.global_position + perp * (it.radius() + 0.8)
	else:
		approach = it.global_position - fwd * (it.radius() + 0.8)
	_walk_to(me, approach, inp, dt, it)


func _do_dispense(me: Chef, inp: PlayerInput, dt: float) -> void:
	var d: Dispenser = _job["disp"]
	var spot := d.stand_spot()
	if d.footprint_distance(me.global_position) <= Tuning.REACH - 0.1 and _flat(spot - me.global_position).length() < 1.6:
		inp.work = true
		_work_timer += dt
		if _work_timer > Tuning.DISPENSE_HOLD + 0.4:
			inp.work = false
			_job = {}
		return
	_walk_to(me, spot, inp, dt, null)


func _do_chop(me: Chef, inp: PlayerInput, dt: float) -> void:
	if not world.board.has_tomato or _job_time > 15.0:
		_job = {}
		return
	var spot := world.board.global_position + Vector3(-2.0, 0, world.board.half.y + 0.7)
	if world.board.footprint_distance(me.global_position) <= Tuning.REACH:
		inp.work = true
		return
	_walk_to(me, spot, inp, dt, null)


func _do_bell(me: Chef, inp: PlayerInput, dt: float) -> void:
	if world.plate.stack.is_empty():
		_job = {}
		return
	var spot := world.bell.global_position + Vector3(-1.6, 0, 0)
	if world.bell.footprint_distance(me.global_position) <= Tuning.REACH - 0.2:
		if _press_wait <= 0.0:
			inp.work_seq += 1
			_press_wait = 0.8
		return
	_walk_to(me, spot, inp, dt, null)


func _let_go(inp: PlayerInput) -> void:
	if _press_wait > 0.0:
		return
	inp.grab_seq += 1
	_press_wait = 0.45
	_job = {}
	_idle_t = 0.6


func _press_grab(inp: PlayerInput) -> void:
	if _press_wait > 0.0:
		return
	inp.grab_seq += 1
	_press_wait = 0.45


# ---------------------------------------------------------------- movement

func _walk_to(me: Chef, target: Vector3, inp: PlayerInput, dt: float, avoid_item: Item) -> void:
	target = _route(me.global_position, target)
	var to := _flat(target - me.global_position)
	if to.length() < 0.12:
		return
	var dir := _steer(me.global_position, target, avoid_item)
	dir *= clampf(to.length() / 1.2, 0.35, 1.0)
	dir = _unstick(me, dir, dt)
	inp.move = Vector2(dir.x, dir.z)


## Straight line, bending around the first solid obstacle (dispensers, bell, props, the target food).
func _steer(from: Vector3, target: Vector3, avoid_item: Item) -> Vector3:
	var to := _flat(target - from)
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	var dir := to / dist
	var obstacles: Array = []
	for d in world.dispensers:
		obstacles.append([d.global_position, 3.0])
	obstacles.append([world.bell.global_position, 1.1])
	for s in world.map["scenery"]:
		if bool(s.get("flat", false)):
			continue
		var sz: Vector3 = s.get("collider", s["size"])
		var off: Vector3 = s.get("collider_offset", Vector3.ZERO)
		obstacles.append([s["pos"] + off, maxf(sz.x, sz.z) * 0.6])
	if avoid_item != null:
		obstacles.append([avoid_item.global_position, avoid_item.radius()])
	var best_t := INF
	var out := dir
	for ob in obstacles:
		var oc := _flat(ob[0] - from)
		var t := oc.dot(dir)
		if t <= 0.0 or t >= dist + float(ob[1]) or t >= best_t:
			continue
		var closest := oc - dir * t
		var clearance := float(ob[1]) + 0.7
		if closest.length() < clearance:
			var side := -closest.normalized() if closest.length() > 0.05 else Vector3(-dir.z, 0, dir.x)
			var tangent: Vector3 = _flat(ob[0]) + side * clearance
			var nd := _flat(tangent - from)
			if nd.length() > 0.05:
				best_t = t
				out = nd.normalized()
	return out


## Multi-surface maps: where to head for on the way from -> target. The target itself when one
## surface holds both (surfaces are rectangles, so the straight line stays on it) or either point is
## off the counter; otherwise the next hop of a breadth-first search over overlapping surfaces: first
## a lead-in point lined up with the overlap (so carried food does not swing over the edge), then the
## middle of the overlap.
func _route(from: Vector3, target: Vector3) -> Vector3:
	var surfs: Array = world.map["surfaces"]
	if surfs.size() < 2:
		return target
	var a := _surfaces_at(surfs, from)
	var b := _surfaces_at(surfs, target)
	if a.is_empty() or b.is_empty():
		return target
	for i in a:
		if b.has(i):
			return target
	var prev := {}
	var queue: Array = a.duplicate()
	for i in a:
		prev[i] = -1
	var found := -1
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if b.has(i):
			found = i
			break
		for j in surfs.size():
			if not prev.has(j) and (surfs[i] as Rect2).intersects(surfs[j], true):
				prev[j] = i
				queue.append(j)
	if found < 0:
		return target
	var hop := found
	while not a.has(prev[hop]):
		hop = prev[hop]
	var here: Rect2 = surfs[prev[hop]]
	var next: Rect2 = surfs[hop]
	var gate := here.intersection(next)
	var g := gate.get_center()
	var d := next.get_center() - here.get_center()
	var axis := Vector2(signf(d.x), 0) if absf(d.x) >= absf(d.y) else Vector2(0, signf(d.y))
	var off := Vector2(from.x, from.z) - g
	var lateral := absf(off.x * axis.y - off.y * axis.x)
	var lead := g - axis * 3.0
	if lateral > 0.4 and here.has_point(lead):
		return Vector3(lead.x, 0, lead.y)
	return Vector3(g.x, 0, g.y)


func _surfaces_at(surfs: Array, p: Vector3) -> Array:
	var out: Array = []
	for i in surfs.size():
		if GameData.surfaces_contain([surfs[i]], Vector2(p.x, p.z)):
			out.append(i)
	return out


## If we have not moved for a while, sidestep for a moment.
func _unstick(me: Chef, dir: Vector3, dt: float) -> Vector3:
	if _sidestep > 0.0:
		_sidestep -= dt
		return (_side_dir + dir * 0.3).normalized()
	_stuck_t += dt
	if _stuck_t >= 0.8:
		var moved := _flat(me.global_position - _stuck_pos).length()
		_stuck_pos = me.global_position
		_stuck_t = 0.0
		if moved < 0.35 and dir.length() > 0.2:
			_side_dir = Vector3(-dir.z, 0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
			_sidestep = 0.6
	return dir


func _describe(j: Dictionary) -> String:
	if j.is_empty():
		return "idle"
	var t := str(j["type"])
	if j.has("id"):
		var it: Item = world.items.get(int(j["id"]))
		return "%s %s" % [t, it.kind if it != null else "?"]
	if j.has("disp"):
		return "%s %s" % [t, j["disp"].gives]
	return t


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
