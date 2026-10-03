class_name Bot
extends RefCounted
## --bot: plays the game through the exact PlayerInput a human produces (move vector, held work, grab/work
## press counters, aim point), reading only the world view every peer has (so it works on clients too).
## What to do comes from bot_planner.gd (recipes + GameData.route data: any recipe, any station set), how to
## get there from bot_nav.gd (surface graph, gates/planks, obstacle steering, edge guard). This file runs
## the chosen job: fetch/help (grab with the aim on the food, carry it to its spot, let go), dispense (hold
## work at the stand spot), chop (hold work beside the board until the food is cut), bell (press work), wait.
## Re-plans every second while empty-handed (a higher-priority job preempts: burning food, a ready plate);
## no progress for 6 s = drop what it holds, ignore that food for a while, re-plan. --bot-log prints plans,
## claims, jobs and route hops.

const Planner := preload("res://scripts/game/bot_planner.gd")
const Nav := preload("res://scripts/game/bot_nav.gd")
const STUCK_TIME := 6.0
const REPLAN_EVERY := 1.0
const SETTLE_TIME := 0.2  # s standing still with the food at its spot before letting go

var world: World
var planner: Planner
var nav: Nav
var _job: Dictionary = {}
var _job_time := 0.0
var _replan_t := 0.0
var _press_wait := 0.0
var _work_timer := 0.0
var _idle := 0.0        # seconds with nothing but waiting to do
var _pause := 0.0       # after letting go, so we do not grab the same food again
var _aside_t := 0.0     # dragging a wrongly grabbed item out of the way
var _settle := 0.0      # arrived with food: stand still this long before letting go (a moving release tosses it)
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _sidestep := 0.0
var _side_dir := Vector3.ZERO
var _prog_best := INF
var _prog_t := 0.0
var _rng := RandomNumberGenerator.new()
var _log := false
var _last_log := ""
var _tag := "bot"
var _clock := 0.0       # game seconds since this bot started playing (log time stamps)


func _init(w: World) -> void:
	world = w
	_rng.randomize()
	_log = Net.has_arg("bot-log")


func update(dt: float, inp: PlayerInput) -> void:
	inp.move = Vector2.ZERO
	inp.work = false
	inp.has_aim = false
	_press_wait = maxf(0.0, _press_wait - dt)
	var me := world.my_chef()
	if Net.phase != Net.Phase.PLAYING or me == null or (me.flags & Chef.FLAG_RESPAWNING) != 0:
		_job = {}
		return
	if nav == null:
		nav = Nav.new(world)
		planner = Planner.new(world)
		planner._nav = nav
		_tag = "bot %d" % me.peer_id
		if _log:
			nav.log_prefix = _tag
			print("%s: map %s, %d surfaces, links %s, %d solid boxes" % [_tag, world.map.get("id", "?"), nav.surfs.size(), str(nav.adj), nav.boxes.size()])
	_clock += dt
	if _pause > 0.0:
		_pause -= dt
		return
	_job_time += dt
	_replan_t -= dt
	if _job.is_empty() or _job_time > 30.0 or (_replan_t <= 0.0 and me.held_id < 0):
		_replan(me)
	if _job.is_empty() or str(_job["type"]) == "wait":
		_idle += dt
	else:
		_idle = 0.0
	if _log and Engine.get_physics_frames() % 120 == 0:
		print("%s: %.1fs   at %s held %d job %s" % [_tag, _clock, _v(me.global_position), me.held_id, _describe(_job)])
	if _job.is_empty():
		return
	_track_progress(me, dt)
	if _job.is_empty():
		return
	match str(_job["type"]):
		"fetch", "help":
			_do_fetch(me, inp, dt)
		"drop":
			if me.held_id >= 0:
				_let_go(inp)
			else:
				_job = {}
		"dispense":
			_do_dispense(me, inp, dt)
		"chop":
			_do_chop(me, inp, dt)
		"bell":
			_do_bell(me, inp, dt)
		"scrape":
			_do_scrape(me, inp, dt)
		"wait":
			_walk_to(me, _job["pos"], inp, dt, null)


# ---------------------------------------------------------------- planning

func _replan(me: Chef) -> void:
	_replan_t = REPLAN_EVERY
	var next := planner.choose(me, _idle)
	if not _job.is_empty() and _job_time <= 30.0 and not _should_switch(next):
		return
	_set_job(next)


## Keep the current job unless the new one ranks higher, the current one is waiting, or its kind is no
## longer needed (order served/expired).
func _should_switch(next: Dictionary) -> bool:
	var cur_pri := int(_job.get("pri", 0))
	if next.is_empty():
		return str(_job.get("type", "")) == "wait"
	if int(next.get("pri", 0)) > cur_pri:
		# Do not abandon a dispense/chop mid-hold for anything but burning food or a ready plate.
		if _work_timer > 0.0 and int(next.get("pri", 0)) < int(Planner.PRI["bell"]):
			return false
		return true
	if str(_job["type"]) == "wait":
		return str(next["type"]) != "wait" or _flat(next["pos"] - _job["pos"]).length() > 2.0
	if _job.has("k") and str(_job.get("why", "unit")) == "unit" and int(planner.need.get(str(_job["k"]), 0)) == 0:
		return true
	return false


func _set_job(j: Dictionary) -> void:
	_job = j
	_job_time = 0.0
	_work_timer = 0.0
	_aside_t = 0.0
	_settle = 0.0
	_prog_best = INF
	_prog_t = 0.0
	if _log:
		var line := _describe(_job)
		if line != _last_log:
			_last_log = line
			var me := world.my_chef()
			print("%s: %.1fs plan %s" % [_tag, _clock, planner.summary()])
			print("%s: %.1fs job %s | pos %s" % [_tag, _clock, line, _v(me.global_position) if me != null else "?"])


## No progress towards the job's goal for STUCK_TIME: drop what we hold, ignore that food, re-plan.
func _track_progress(me: Chef, dt: float) -> void:
	var t := str(_job["type"])
	if t == "drop" or t == "wait" or _work_timer > 0.0:
		_prog_t = 0.0
		return
	var d := INF
	if _job.has("id"):
		var it: Item = world.items.get(int(_job["id"]))
		if it == null:
			return
		if me.held_id == it.item_id:
			d = _flat(_job["dest"] - it.global_position).length()
		else:
			d = it.footprint_distance(me.global_position) + 100.0  # grabbing counts as progress
	elif t == "dispense":
		d = _flat((_job["disp"] as Dispenser).stand_spot() - me.global_position).length()
	elif t == "chop":
		d = _flat(_job["spot"] - me.global_position).length()
	elif t == "bell":
		d = (_job["bell"] as Bell).footprint_distance(me.global_position)
	elif t == "scrape":
		d = (_job["plate"] as Plate).footprint_distance(me.global_position)
	if d < _prog_best - 0.5:
		_prog_best = d
		_prog_t = 0.0
		return
	_prog_t += dt
	if _prog_t < STUCK_TIME:
		return
	if _log:
		var extra := ""
		if _job.has("id") and world.items.has(int(_job["id"])):
			var it: Item = world.items[int(_job["id"])]
			var gc := world.grab_candidate(me, world.local_input)
			extra = " (food at %s y %.1f, reach gap %.2f, carriers %d, grab candidate %s)" % [_v(it.global_position), it.global_position.y,
				it.footprint_distance(me.global_position), it.carrier_count, gc.kind if gc != null else "none"]
		print("%s: stuck on %s for %.0f s at %s%s, re-planning" % [_tag, _describe(_job), STUCK_TIME, _v(me.global_position), extra])
	if _job.has("id"):
		planner.blacklist[int(_job["id"])] = Time.get_ticks_msec() + 12000
	_job = {}
	_prog_t = 0.0
	if me.held_id >= 0 and _press_wait <= 0.0:
		world.local_input.grab_seq += 1  # let go of it
		_press_wait = 0.45
		_pause = 0.6


# ---------------------------------------------------------------- acting

func _end(reason: String) -> void:
	if _log:
		var extra := ""
		if _job.has("id"):
			var it: Item = world.items.get(int(_job["id"]))
			extra = " (food at %s y %.1f)" % [_v(it.global_position), it.global_position.y] if it != null else ""
		print("%s: %.1fs end %s: %s%s" % [_tag, _clock, _describe(_job), reason, extra])
	_job = {}


func _do_fetch(me: Chef, inp: PlayerInput, dt: float) -> void:
	var it: Item = world.items.get(int(_job["id"]))
	if it == null or it.removed:
		_end("food gone")
		return
	var help := str(_job["type"]) == "help"
	if me.held_id == it.item_id:
		_carry(me, it, inp, dt, help)
		return
	if me.held_id >= 0:
		# Grabbed the wrong food: drag it aside a moment, then let go (keep the job).
		var held: Item = world.items.get(me.held_id)
		_aside_t += dt
		if held != null and _aside_t < 0.9:
			var away := _flat(held.global_position - it.global_position)
			if away.length() < 0.1:
				away = Vector3(1, 0, 0)
			away = nav.guard(me.global_position, away.normalized(), 1.2)
			away = nav.guard(held.global_position, away, 1.2)
			inp.move = Vector2(away.x, away.z)
		else:
			_press_grab(inp)
		return
	_aside_t = 0.0
	if not help and it.carrier_count > 0:
		_end("taken by a teammate")  # re-plan (maybe help)
		return
	if help and (it.carrier_count == 0 or _job_time > 10.0):
		_end("no one to help")
		return
	var reach: float = world.call("grab_reach") if world.has_method("grab_reach") else Tuning.REACH
	inp.has_aim = true
	inp.aim_point = Vector2(it.global_position.x, it.global_position.z)
	if it.footprint_distance(me.global_position) <= reach - 0.2:
		if world.grab_candidate(me, inp) == it:
			_press_grab(inp)
			return
		var d := nav.guard(me.global_position, _unstick(me, _flat(it.global_position - me.global_position).normalized() * 0.6, dt), 0.6)
		inp.move = Vector2(d.x, d.z)
		return
	_walk_to(me, _approach(me, it, help), inp, dt, it)


## Where to stand to grab it: behind it (seen from where it goes) so it ends up in front; a helper beside
## it (in front of it on multi-surface maps, where a side helper would stand off a plank). Falls back to the
## side facing us when that spot is off the counter or inside scenery.
func _approach(me: Chef, it: Item, help: bool) -> Vector3:
	var dest: Vector3 = _job["dest"]
	var to_dest := _flat(dest - it.global_position)
	var fwd := to_dest.normalized() if to_dest.length() > 0.1 else Vector3(0, 0, 1)
	var gap := 0.8   # m outside the food's footprint edge (long food is narrow across)
	var cands: Array = []
	if help:
		var perp := Vector3(-fwd.z, 0, fwd.x)
		if perp.dot(me.global_position - it.global_position) < 0.0:
			perp = -perp
		if nav.surfs.size() > 1:
			cands.append(fwd)
		cands.append_array([perp, -perp, fwd, -fwd])
	elif it.weight() >= Planner.HEAVY:
		cands.append(-fwd)  # heavy food swings round slowly: start behind it
	else:
		gap = 0.7  # light food: straight at it (walking round it pushes round food away)
	var mine := _flat(me.global_position - it.global_position)
	cands.append(mine.normalized() if mine.length() > 0.1 else Vector3(0, 0, 1))
	for c in cands:
		var p: Vector3 = it.global_position + c * (_edge_along(it, c) + gap)
		p.y = 0.0
		if nav.inside(p, 0.6) and not nav.blocked(p, 0.3):
			return p
	return nav.clamp_in(it.global_position + cands[-1] * (_edge_along(it, cands[-1]) + gap), 0.6)


## Distance from the food's centre to its footprint edge along unit direction d.
func _edge_along(it: Item, d: Vector3) -> float:
	var e := 0.0
	while e < it.radius() and it.footprint_distance(it.global_position + d * (e + 0.1)) <= 0.0:
		e += 0.1
	return e


## Carrying it (alone or with others) towards the job's spot; let go there.
func _carry(me: Chef, it: Item, inp: PlayerInput, dt: float, help: bool) -> void:
	var dest: Vector3 = _job["dest"]
	var to := _flat(dest - it.global_position)
	if help and it.carrier_count <= 1 and _job_time > 1.0:
		_let_go(inp)  # the carrier let go (arrived): so do we
		return
	var st: Station = _job.get("station")
	var arrived := to.length() <= float(_job["r"])
	if arrived and st != null and not (st is Plate) and not st.contains_xz(it.global_position, -0.2):
		arrived = false
	if arrived:
		# Stop first: letting go while walking tosses the food (CarrySystem._toss), which could slide it off
		# the station or splat an egg.
		_settle += dt
		if _settle >= SETTLE_TIME:
			_let_go(inp)
		return
	_settle = 0.0
	var group := it.carrier_count >= 2
	var origin := it.global_position if group else me.global_position
	var via := nav.waypoint(origin, dest, false)
	var dir: Vector3
	if via != dest:
		dir = nav.steer(origin, via, it.radius(), null, it) * 0.8
	elif to.length() < 2.5:
		dir = to.normalized() * clampf(to.length() / 2.0, 0.5, 1.0)  # close: straight in, no bending
	else:
		dir = nav.steer(it.global_position, dest, it.radius() * 0.5, null, it) * clampf(to.length() / 2.0, 0.5, 1.0)
	var look := minf(1.2, _flat(via - origin).length())
	if look > 0.3:
		dir = nav.guard(me.global_position, dir, look)
		dir = nav.guard(it.global_position, dir, look)
	dir = _unstick(me, dir, dt)
	inp.move = Vector2(dir.x, dir.z)


func _do_dispense(me: Chef, inp: PlayerInput, dt: float) -> void:
	var d: Dispenser = _job["disp"]
	var spot := d.stand_spot()
	var hold: float = d.call("hold_time") if d.has_method("hold_time") else Tuning.DISPENSE_HOLD
	if _work_timer > 0.0 or (d.footprint_distance(me.global_position) <= Tuning.REACH - 0.1 and _flat(spot - me.global_position).length() < 1.6):
		inp.work = true
		_work_timer += dt
		if _work_timer > hold + 0.35:
			inp.work = false
			_job = {}
			_pause = 0.15  # release work so the next hold starts a new batch
		return
	_walk_to(me, spot, inp, dt, null)


func _do_chop(me: Chef, inp: PlayerInput, dt: float) -> void:
	var b := world.board
	if b == null or not planner.board_has(str(_job["kind"])) or _job_time > 20.0:
		_end("chopped")
		return
	var spot: Vector3 = _job["spot"]
	if b.footprint_distance(me.global_position) <= Tuning.REACH - 0.15 and _flat(spot - me.global_position).length() < 1.0:
		inp.work = true
		_work_timer += dt
		return
	_walk_to(me, spot, inp, dt, null)


func _do_bell(me: Chef, inp: PlayerInput, dt: float) -> void:
	var p: Plate = _job["plate"]
	var b: Bell = _job["bell"]
	if p.stack.is_empty() or p.stack != _job["stack"] or _job_time > 15.0:
		_end("plate changed")
		return
	if b.footprint_distance(me.global_position) <= Tuning.REACH - 0.25:
		if _press_wait <= 0.0:
			inp.work_seq += 1
			_press_wait = 0.8
			if _log:
				print("%s: ring bell %s for %s (%s)" % [_tag, b.def.get("label", ""), str(p.stack), _job.get("why", "")])
		return
	var from := _flat(me.global_position - b.global_position)
	var side := from.normalized() if from.length() > 0.1 else Vector3(0, 0, 1)
	var spot := nav.clamp_in(b.global_position + side * (maxf(b.half.x, b.half.y) + 0.8), 0.6)
	_walk_to(me, spot, inp, dt, null)


## Hold work beside the plate (a spot where that means scraping it) until it is empty.
func _do_scrape(me: Chef, inp: PlayerInput, dt: float) -> void:
	var p: Plate = _job["plate"]
	if p.stack.is_empty() or p.stack != _job["stack"] or _job_time > 12.0:
		_end("scraped" if p.stack.is_empty() else "plate changed")
		_pause = 0.15   # release work
		return
	if not _job.has("spot"):
		_job["spot"] = planner.work_spot(p, me, true)
	if _work_timer > 0.0 or world.scrape_target(me.global_position) == p:
		inp.work = true
		if _work_timer == 0.0:
			inp.work_seq += 1   # a scrape hold must start with a fresh press at the plate (PlateSystem)
			if _log:
				print("%s: scrape plate %s %s (%s)" % [_tag, p.def.get("label", ""), str(p.stack), _job.get("why", "")])
		_work_timer += dt
		if _work_timer > Tuning.SCRAPE_HOLD + 1.0:
			_work_timer = 0.0   # no luck (moved off?): walk back and hold again
		return
	_walk_to(me, _job["spot"], inp, dt, null)


func _let_go(inp: PlayerInput) -> void:
	if _press_wait > 0.0:
		return
	inp.grab_seq += 1
	_press_wait = 0.45
	_job = {}
	_pause = 0.6


func _press_grab(inp: PlayerInput) -> void:
	if _press_wait > 0.0:
		return
	inp.grab_seq += 1
	_press_wait = 0.45


# ---------------------------------------------------------------- movement

func _walk_to(me: Chef, target: Vector3, inp: PlayerInput, dt: float, avoid_item: Item) -> void:
	var via := nav.waypoint(me.global_position, target)
	var to := _flat(via - me.global_position)
	if to.length() < 0.12:
		return
	var dir := nav.steer(me.global_position, via, 0.0, avoid_item)
	if via == target:
		dir *= clampf(to.length() / 1.2, 0.35, 1.0)
	var look := minf(1.2, to.length())
	if look > 0.3:
		dir = nav.guard(me.global_position, dir, look)
	dir = _unstick(me, dir, dt)
	inp.move = Vector2(dir.x, dir.z)


## If we have not moved for a while, sidestep for a moment.
func _unstick(me: Chef, dir: Vector3, dt: float) -> Vector3:
	if _sidestep > 0.0:
		_sidestep -= dt
		return nav.guard(me.global_position, (_side_dir + dir * 0.3).normalized(), 0.8)
	_stuck_t += dt
	if _stuck_t >= 0.8:
		var moved := _flat(me.global_position - _stuck_pos).length()
		_stuck_pos = me.global_position
		_stuck_t = 0.0
		if moved < 0.35 and dir.length() > 0.2:
			_side_dir = Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
			_sidestep = 0.6
	return dir


func _describe(j: Dictionary) -> String:
	if j.is_empty():
		return "idle"
	var t := str(j["type"])
	var why := " (%s)" % j["why"] if j.has("why") else ""
	if j.has("id"):
		var it: Item = world.items.get(int(j["id"]))
		return "%s %s%s -> %s" % [t, it.kind if it != null else "?", why, _v(j["dest"])]
	if j.has("disp"):
		return "%s %s for %s" % [t, str(j["disp"].gives), j.get("k", "?")]
	if t == "chop":
		return "chop %s for %s" % [j["kind"], j.get("k", "?")]
	if t == "wait":
		return "wait at %s %s" % [j.get("at", ""), _v(j["pos"])]
	return t + why


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
