class_name CarrySystem
extends RefCounted
## Owns grabbing and releasing food, how carried food moves, and carry speed by weight (plus the
## patty solo/duo speed test metrics). Host only, except grab_candidate() (the hint uses it too).
## Reads world.items, world.input_of(). Calls Item.attach/detach, Net.event/metrics.
##
## Solo (one carrier): the chef is the pivot and holds the item out in front along hold_yaw; the
## item swings round with the chef (towards the cursor with aim, else the move direction) at
## CARRY_TURN_RATE / weight. Group (2+): the item moves along the AVERAGE of the carriers' inputs
## (opposite inputs cancel), carriers keep their places round it and face its centre.
## Either way item + carriers move as one unit that is swept against the world and other chefs
## (Jolt test motion): a blocked move slides, a blocked swing stops. A carrier past the counter
## edge lets go (and falls); food whose centre leaves the counter is dropped by BoundsSystem.
## Speed = PLAYER_SPEED * move_mult (shoes) * clamp((carriers + protein_shake) / weight, CARRY_MIN_FACTOR, 1).
## --carry-log prints every carried item's mode, swing rate and whether a carrier is inside scenery.
## --carry-spawn=<kind>:<x>:<z>[,...] (agent tests) drops that food on the counter when play starts.

const CAST_MARGIN := 0.02
const CARRIER_LIFT := 0.06        # sweep carriers this far above the counter so the floor never counts
const CARRIER_MASK := Tuning.LAYER_WORLD | Tuning.LAYER_PLAYERS
const WALK_MASK := Tuning.LAYER_WORLD | Tuning.LAYER_PLAYERS | Tuning.LAYER_ITEMS

var world: World
var _carry_track: Dictionary = {}
var _params := PhysicsTestMotionParameters3D.new()
var _result := PhysicsTestMotionResult3D.new()
var _log := false
var _log_t := 0.0
var _turned: Dictionary = {}      # --carry-log: peer id -> radians swung since the last line
var _probe: PhysicsShapeQueryParameters3D
var _spawn_spec := ""


func _init(w: World) -> void:
	world = w
	_log = Net.has_arg("carry-log")
	_params.margin = CAST_MARGIN
	_spawn_spec = Net.arg_str("carry-spawn", "")


## Every peer: the food chef c would grab now (null when the press takes a plate's top item instead, see
## grab_choice). Shared by the host grab, the hint ring and bots.
func grab_candidate(c: Chef, inp: PlayerInput) -> Item:
	return grab_choice(c, inp) as Item


## Every peer: what a grab press by chef c takes: an Item (loose or carried food), a Plate (its top item
## comes off, World.plate_take_candidate) or null. A plate wins only when it is the aimed thing: with aim,
## the aim point is nearer it than any loose food (same score scale); without aim, no food is in reach.
## Loose food picking (_loose_candidate) is unchanged by plates.
func grab_choice(c: Chef, inp: PlayerInput) -> Object:
	var pick := _loose_candidate(c, inp)
	var take: Array = world.plate_take_candidate(c, inp)
	if not take.is_empty():
		if inp.has_aim and float(take[1]) < float(pick[1]):
			return take[0]
		if not inp.has_aim and pick[0] == null:
			return take[0]
	return pick[0]


## [item, aim score (INF when not picked by aim)].
## With aim: the item in reach under (or within GRAB_AIM_RADIUS of) the cursor, nearest to it wins.
## Otherwise the nearest in reach, preferring items in front (towards the cursor with aim, else
## the way the chef faces): one right behind needs to be GRAB_FRONT_BIAS nearer to win.
func _loose_candidate(c: Chef, inp: PlayerInput) -> Array:
	var p := c.global_position
	var reach := grab_reach()
	var fwd := Vector3(sin(c.rotation.y), 0.0, cos(c.rotation.y))
	var aim := inp.aim3()
	if inp.has_aim:
		var ta := _flat(aim - p)
		if ta.length() > Chef.AIM_MIN_DIST:
			fwd = ta.normalized()
	var by_aim: Item = null
	var ba := INF
	var best: Item = null
	var bs := INF
	for it in world.items.values():
		if it.removed or absf(it.global_position.y - p.y) > 3.0:
			continue
		if it.footprint_distance(p) > reach:
			continue
		if inp.has_aim:
			var da: float = it.footprint_distance(aim)
			if da <= Tuning.GRAB_AIM_RADIUS:
				var sa: float = da + 0.05 * _flat(aim - it.global_position).length()
				if sa < ba:
					by_aim = it
					ba = sa
		var to := _flat(it.global_position - p)
		var front := 1.0 if to.length() < 0.05 else to.normalized().dot(fwd)
		var s: float = it.grab_score(p) + Tuning.GRAB_FRONT_BIAS * (1.0 - front) * 0.5
		if s < bs:
			best = it
			bs = s
	return [by_aim, ba] if by_aim != null else [best, INF]


## Every peer: how far (m, chef centre to food footprint) a chef can grab: Tuning.REACH x (1 + tongs value).
func grab_reach() -> float:
	return Tuning.REACH * (1.0 + world.shift.upgrade_value("tongs", 0.0))


## Carry speed factor for n carriers on food of weight w: clamp((n + protein_shake value) / w, MIN, 1).
## The shake only adds a fractional carrier here (speed), never above the unloaded speed; carrier pips,
## swing rate and grab rules still count real chefs.
static func speed_factor(n: int, w: int, shift: ShiftManager) -> float:
	var extra := shift.upgrade_value("protein_shake", 0.0) if shift != null else 0.0
	return clampf((float(n) + extra) / float(w), Tuning.CARRY_MIN_FACTOR, 1.0)


## A fresh grab press: drop what the chef holds, else grab the best candidate.
func on_grab_pressed(c: Chef) -> void:
	if c.respawn_timer < 0.0:
		if c.holding != null:
			release(c, true)
		else:
			_try_grab(c)


func _try_grab(c: Chef) -> void:
	var choice := grab_choice(c, world.input_of(c.peer_id))
	var best: Item = null
	if choice is Plate:
		best = world.take_from_plate(c, choice as Plate)   # its top item, now loose food; carried as any other
	else:
		best = choice as Item
	if best == null:
		return
	var reach_used: float = best.footprint_distance(c.global_position)
	if reach_used > Tuning.REACH and not (choice is Plate):
		print("upgrades: tongs grab %s at %.2fm (base reach %.2f, now %.2f)" % [best.kind, reach_used, Tuning.REACH, grab_reach()])
	best.attach(c)
	c.holding = best
	c.held_id = best.item_id
	c.walk_vel = Vector3.ZERO
	c.knock = Vector3.ZERO
	c.collision_mask = CARRIER_MASK
	if best.carriers.size() == 1:
		_enter_solo(c, best)
	# 2+: group mode keeps everyone where they are; move_carried turns them to face the item.
	world.stats.on_grab(c, best)
	Net.event("", "grab", c.peer_id)
	Net.metrics["grabs"] = int(Net.metrics.get("grabs", 0)) + 1


func release(c: Chef, sound := false) -> void:
	var it := c.holding
	c.holding = null
	c.held_id = -1
	c.collision_mask = WALK_MASK
	if it != null and is_instance_valid(it):
		it.detach(c)
		if it.carriers.size() == 1:
			_enter_solo(it.carriers[0], it)
		elif it.carriers.is_empty():
			_toss(c, it)
		if sound:
			Net.event("", "drop", c.peer_id)


## The last carrier let go: moving, the food flies on with the carrier's velocity / sqrt(weight) (capped at
## Tuning.TOSS_MAX_SPEED) plus a small pop; standing, it just drops (Item.detach armed its one bounce).
func _toss(c: Chef, it: Item) -> void:
	var v := _flat(c.velocity)
	if v.length() < Tuning.TOSS_MIN_SPEED:
		return
	var tv := (v / sqrt(float(it.weight()))).limit_length(Tuning.TOSS_MAX_SPEED)
	it.launch(tv + Vector3.UP * Tuning.TOSS_POP)
	if it.long_kind:
		# Spin about y by how sideways it flies: (long axis x direction).y, normalised.
		var ax := _flat(it.global_transform.basis.x).normalized()
		it.angular_velocity = Vector3(0, Tuning.TOSS_LONG_SPIN * ax.cross(tv.normalized()).y, 0)
	if _log or Net.has_arg("physics-log"):
		print("carry: chef %d tossed %s %d at %.2f m/s (carrier %.2f m/s)" % [c.peer_id, it.kind, it.item_id,
			tv.length(), v.length()])


func detach_all(it: Item) -> void:
	for c in it.carriers.duplicate():
		c.holding = null
		c.held_id = -1
		c.collision_mask = WALK_MASK
		it.detach(c)


## The item is gone: drop its carry-speed tracking.
func forget_item(id: int) -> void:
	_carry_track.erase(id)


## One tick of every carried item (host, after the chefs walked).
func move_carried(dt: float, mult: float, playing: bool) -> void:
	if playing and not _spawn_spec.is_empty():
		for spec in _spawn_spec.split(","):
			var f := spec.split(":")
			if f.size() == 3 and GameData.ITEMS.has(f[0]):
				world.spawn_item(f[0], Vector3(f[1].to_float(), 0.3, f[2].to_float()))
		_spawn_spec = ""
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var sum := Vector3.ZERO
		for c in it.carriers:
			sum += world.input_of(c.peer_id).move3() if playing else Vector3.ZERO
		var n: int = it.carriers.size()
		var avg := sum / float(n)
		var factor := speed_factor(n, it.weight(), world.shift)
		var moved := _translate_unit(it, avg * Tuning.PLAYER_SPEED * mult * factor * dt)
		if n == 1:
			var c: Chef = it.carriers[0]
			_solo_swing(c, it, world.input_of(c.peer_id), avg, playing, dt)
			_solo_ease(c, it, dt)
		else:
			for c in it.carriers:
				_face_item(c, it, dt)
		for c in it.carriers:
			c.velocity = moved / dt
		_drop_off_edge(it)
		if str(it.kind).begins_with("patty"):
			_track_carry(it.item_id, n, moved.length(), dt)
	if _log:
		_log_tick(dt)


# ---------------------------------------------------------------- solo

## One carrier left (grab, or a group shrank to one): hold the item out in front, easing from where it is.
func _enter_solo(c: Chef, it: Item) -> void:
	var to := _flat(it.global_position - c.global_position)
	if to.length() < 0.05:
		to = c.facing
	var dir := to.normalized()
	c.hold_yaw = atan2(dir.x, dir.z)
	c.hold_dist = to.length()
	c.hold_rel_yaw = _yaw(it) - c.hold_yaw
	c.hold_goal = Chef.RADIUS + _half_along(it, dir) + Tuning.CARRY_HOLD_GAP
	c.facing = dir


## Turn towards the cursor (aim) or the move direction at CARRY_TURN_RATE / weight; the item swings
## round the chef. A swing the item cannot make (scenery, another chef) stops where it touches.
func _solo_swing(c: Chef, it: Item, inp: PlayerInput, mv: Vector3, playing: bool, dt: float) -> void:
	var target := c.hold_yaw
	if playing and inp.has_aim:
		var ta := _flat(inp.aim3() - c.global_position)
		if ta.length() > Chef.AIM_MIN_DIST:
			target = atan2(ta.x, ta.z)
	elif mv.length() > 0.1:
		target = atan2(mv.x, mv.z)
	var rate := Tuning.CARRY_TURN_RATE / float(it.weight())
	var want := rotate_toward(c.hold_yaw, target, rate * dt)
	var d := angle_difference(c.hold_yaw, want)
	if absf(d) > 0.0001:
		var to := _solo_pose(c, it, c.hold_yaw + d, c.hold_dist)
		var f := _sweep_item(it, to)
		if f > 0.0:
			var yaw := wrapf(c.hold_yaw + d * f, -PI, PI)
			var pose := _solo_pose(c, it, yaw, c.hold_dist)
			if f >= 1.0 or _is_round(it) or _depth(it, pose) <= _depth(it, it.global_transform) + 0.005:
				if _log:
					_turned[c.peer_id] = float(_turned.get(c.peer_id, 0.0)) + absf(angle_difference(c.hold_yaw, yaw))
				c.hold_yaw = yaw
				it.global_transform = pose
	c.facing = Vector3(sin(c.hold_yaw), 0.0, cos(c.hold_yaw))
	c.rotation.y = rotate_toward(c.rotation.y, c.hold_yaw, Tuning.CARRY_FACE_RATE * dt)


## After a grab the item slides from where it lay to the held spot (collision-checked; the chef stays put).
func _solo_ease(c: Chef, it: Item, dt: float) -> void:
	if absf(c.hold_dist - c.hold_goal) < 0.002:
		return
	var nd := lerpf(c.hold_dist, c.hold_goal, 1.0 - exp(-Tuning.CARRY_HOLD_EASE * dt))
	if absf(nd - c.hold_goal) < 0.01:
		nd = c.hold_goal
	var f := _sweep_item(it, _solo_pose(c, it, c.hold_yaw, nd))
	if f > 0.0:
		c.hold_dist = lerpf(c.hold_dist, nd, f)
		it.global_transform = _solo_pose(c, it, c.hold_yaw, c.hold_dist)


func _solo_pose(c: Chef, it: Item, yaw: float, dist: float) -> Transform3D:
	var o := Vector3(c.global_position.x, it.global_position.y, c.global_position.z)
	o += Vector3(sin(yaw), 0.0, cos(yaw)) * dist
	return Transform3D(Basis(Vector3.UP, yaw + c.hold_rel_yaw), o)


## Distance from the item's centre to its footprint edge along world direction dir.
func _half_along(it: Item, dir: Vector3) -> float:
	var shape := str(it.def["shape"])
	if shape != "box" and shape != "capsule_x":
		return it.size.x * 0.5
	var l := dir.rotated(Vector3.UP, -_yaw(it))
	var tx := it.size.x * 0.5 / absf(l.x) if absf(l.x) > 0.0001 else INF
	var tz := it.size.z * 0.5 / absf(l.z) if absf(l.z) > 0.0001 else INF
	return minf(tx, tz)


func _is_round(it: Item) -> bool:
	var shape := str(it.def["shape"])
	return shape != "box" and shape != "capsule_x"


# ---------------------------------------------------------------- group

func _face_item(c: Chef, it: Item, dt: float) -> void:
	var to := _flat(it.global_position - c.global_position)
	if to.length() < 0.05:
		return
	c.facing = to.normalized()
	c.rotation.y = rotate_toward(c.rotation.y, atan2(to.x, to.z), Tuning.CARRY_FACE_RATE * dt)


# ---------------------------------------------------------------- the unit vs the world

## Move item + carriers by motion, as far as the first thing any of them would hit, then slide the
## rest along that surface (up to 3 times). Returns the distance actually moved.
func _translate_unit(it: Item, motion: Vector3) -> Vector3:
	var total := Vector3.ZERO
	var m := motion
	for _i in 3:
		if m.length_squared() < 0.00000001:
			break
		var f := 1.0
		var nrm := Vector3.ZERO
		var ex := _unit_rids(it)
		var hit := _cast(it, it.global_transform, m, ex)
		if hit[0] < f:
			f = hit[0]
			nrm = hit[1]
		for c in it.carriers:
			hit = _cast(c, c.global_transform.translated(Vector3(0, CARRIER_LIFT, 0)), m, ex)
			if hit[0] < f:
				f = hit[0]
				nrm = hit[1]
		var step := m * f
		it.global_position += step
		for c in it.carriers:
			c.global_position += step
		total += step
		if f >= 1.0:
			break
		nrm.y = 0.0
		if nrm.length_squared() < 0.000001:
			break
		m = (m - step).slide(nrm.normalized())
	return total


## Sweep the carried item alone from where it is to pose (the new rotation applied at the start):
## the fraction of the way it can go.
func _sweep_item(it: Item, pose: Transform3D) -> float:
	var from := Transform3D(pose.basis, it.global_position)
	var hit := _cast(it, from, pose.origin - it.global_position, _unit_rids(it))
	return hit[0]


## [safe fraction 0..1, contact normal] for body swept from `from` by motion. Only contacts that
## oppose the motion count, so sliding along a wall never sticks. The fraction comes from the travel
## (which includes Jolt's depenetration), not the safe fraction of the cast alone: a body resting
## against a wall then gets ~0, where the cast fraction would let it creep a little deeper every tick.
func _cast(body: PhysicsBody3D, from: Transform3D, motion: Vector3, exclude: Array[RID]) -> Array:
	var len2 := motion.length_squared()
	if len2 < 0.00000001:
		return [1.0, Vector3.ZERO]
	_params.from = from
	_params.motion = motion
	_params.exclude_bodies = exclude
	_params.recovery_as_collision = false
	if PhysicsServer3D.body_test_motion(body.get_rid(), _params, _result):
		var n := _result.get_collision_normal()
		if n.dot(motion) < -0.0001 * sqrt(len2):
			var f := minf(_result.get_collision_safe_fraction(), _result.get_travel().dot(motion) / len2)
			return [clampf(f, 0.0, 1.0), n]
	return [1.0, Vector3.ZERO]


## How deep the item would sit in scenery / other chefs at pose (0 when clear).
func _depth(it: Item, pose: Transform3D) -> float:
	_params.from = pose
	_params.motion = Vector3.ZERO
	_params.exclude_bodies = _unit_rids(it)
	_params.recovery_as_collision = true
	var d := 0.0
	if PhysicsServer3D.body_test_motion(it.get_rid(), _params, _result):
		d = _result.get_collision_depth()
	_params.recovery_as_collision = false
	return d


func _unit_rids(it: Item) -> Array[RID]:
	var out: Array[RID] = [it.get_rid()]
	for c in it.carriers:
		out.append(c.get_rid())
	return out


## A carrier whose centre left the counter top lets go (Chef.host_move then drops it off).
func _drop_off_edge(it: Item) -> void:
	for c in it.carriers.duplicate():
		var p: Vector3 = c.global_position
		if not world.on_counter(Vector2(p.x, p.z)):
			release(c)


func _yaw(it: Item) -> float:
	return it.global_transform.basis.get_euler().y


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------- metrics + log

## Speed test metric: the unit's translation only (swinging the item round does not count).
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


func _log_tick(dt: float) -> void:
	_log_t += dt
	if _log_t < 0.25:
		return
	var span := _log_t
	_log_t = 0.0
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var n: int = it.carriers.size()
		for c in it.carriers:
			var turned := float(_turned.get(c.peer_id, 0.0))
			print("carry: item %d %s w%d %s chef %d pos %s item %s hold_yaw %.0f yaw %.0f swing %.0f deg/s dist %.2f/%.2f inside %s" % [
				it.item_id, it.kind, it.weight(), "solo" if n == 1 else "group%d" % n, c.peer_id,
				c.global_position.snapped(Vector3.ONE * 0.01), it.global_position.snapped(Vector3.ONE * 0.01),
				rad_to_deg(c.hold_yaw), rad_to_deg(c.rotation.y), rad_to_deg(turned / span),
				c.hold_dist, c.hold_goal, _inside_world(c)])
	_turned.clear()


## --carry-log: the scenery a carrier's body overlaps by more than a few cm ("-" when none).
func _inside_world(c: Chef) -> String:
	if _probe == null:
		var cap := CapsuleShape3D.new()
		cap.radius = Chef.RADIUS - 0.04
		cap.height = 1.2
		_probe = PhysicsShapeQueryParameters3D.new()
		_probe.shape = cap
		_probe.collision_mask = Tuning.LAYER_WORLD
	_probe.transform = Transform3D(Basis.IDENTITY, c.global_position + Vector3(0, 0.75, 0))
	var hits := c.get_world_3d().direct_space_state.intersect_shape(_probe, 4)
	var names := PackedStringArray()
	for h in hits:
		var o: Object = h["collider"]
		names.append(str((o as Node).get_parent().name) if o is Node else "?")
	return "-" if names.is_empty() else ",".join(names)
