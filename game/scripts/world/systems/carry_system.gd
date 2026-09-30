class_name CarrySystem
extends RefCounted
## Owns grabbing and releasing food, carrier offsets, averaged-input carry movement and carry speed
## by weight (plus the patty solo/duo speed test metrics). Host only, except grab_candidate().
## Reads world.items, world.input_of(). Calls Item.attach/detach/carry_step, Net.event/metrics.

var world: World
var _carry_track: Dictionary = {}


func _init(w: World) -> void:
	world = w


## The food a chef at p would grab: in reach, best grab_score. Shared with the hint and bots.
func grab_candidate(p: Vector3) -> Item:
	var best: Item = null
	var bs := INF
	for it in world.items.values():
		if it.removed or absf(it.global_position.y - p.y) > 3.0:
			continue
		if it.footprint_distance(p) > Tuning.REACH:
			continue
		var s: float = it.grab_score(p)
		if s < bs:
			best = it
			bs = s
	return best


## A fresh grab press: drop what the chef holds, else grab the best candidate.
func on_grab_pressed(c: Chef) -> void:
	if c.respawn_timer < 0.0:
		if c.holding != null:
			release(c, true)
		else:
			_try_grab(c)


func _try_grab(c: Chef) -> void:
	var best := grab_candidate(c.global_position)
	if best == null:
		return
	best.attach(c)
	c.holding = best
	c.held_id = best.item_id
	c.hold_offset = c.global_position - best.global_position
	c.hold_offset.y = 0.0
	c.walk_vel = Vector3.ZERO
	Net.event("", "grab", c.peer_id)
	Net.metrics["grabs"] = int(Net.metrics.get("grabs", 0)) + 1


func release(c: Chef, sound := false) -> void:
	var it := c.holding
	c.holding = null
	c.held_id = -1
	if it != null and is_instance_valid(it):
		it.detach(c)
		if sound:
			Net.event("", "drop", c.peer_id)


func detach_all(it: Item) -> void:
	for c in it.carriers.duplicate():
		c.holding = null
		c.held_id = -1
		it.detach(c)


## The item is gone: drop its carry-speed tracking.
func forget_item(id: int) -> void:
	_carry_track.erase(id)


## Carried food moves with the AVERAGE of its carriers' inputs (opposite inputs cancel) at
## PLAYER_SPEED * clamp(carriers / weight, CARRY_MIN_FACTOR, 1); carriers keep their offsets.
func move_carried(dt: float, mult: float, playing: bool) -> void:
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var sum := Vector3.ZERO
		for c in it.carriers:
			var inp: PlayerInput = world.input_of(c.peer_id)
			var mv := inp.move3() if playing else Vector3.ZERO
			sum += mv
			if mv.length() > 0.1:
				c.face(mv, dt)
		var n: int = it.carriers.size()
		var avg := sum / float(n)
		var factor := clampf(float(n) / float(it.weight()), Tuning.CARRY_MIN_FACTOR, 1.0)
		var before: Vector3 = it.global_position
		it.carry_step(avg * Tuning.PLAYER_SPEED * mult * factor * dt)
		var moved: Vector3 = it.global_position - before
		moved.y = 0.0
		for c in it.carriers:
			var p: Vector3 = it.global_position + c.hold_offset
			p.y = c.global_position.y
			c.global_position = p
			c.velocity = moved / dt
		if str(it.kind).begins_with("patty"):
			_track_carry(it.item_id, n, moved.length(), dt)


func _track_carry(id: int, n: int, dist: float, dt: float) -> void:
	var tr: Dictionary = _carry_track.get(id, {"n": n, "t": 0.0, "d": 0.0})
	if int(tr["n"]) != n:
		tr = {"n": n, "t": 0.0, "d": 0.0}
	tr["t"] = float(tr["t"]) + dt
	tr["d"] = float(tr["d"]) + dist
	if float(tr["t"]) >= 0.5:
		var spd := float(tr["d"]) / float(tr["t"])
		if n == 1:
			Net.metric_max("patty_solo_speed", spd)
		elif spd > 0.5:
			Net.metric_max("patty_duo_speed", spd)
			Net.metrics["patty_duo_seconds"] = float(Net.metrics["patty_duo_seconds"]) + float(tr["t"])
		tr["t"] = 0.0
		tr["d"] = 0.0
	_carry_track[id] = tr
