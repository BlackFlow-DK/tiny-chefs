extends RefCounted
## Bot navigation (used by bot.gd), built once per map from World.map:
## - surfaces graph: the map's counter rectangles, joined where they overlap or touch (a shared edge or strip
##   at least MIN_GATE wide). waypoint() walks straight on one surface, else to the next surface through the
##   joining rectangle ("gate"): first a lead-in point lined up with the gate (so carried food does not swing
##   over the edge), then straight across along the gate's centre line (planks) and EDGE m past it.
## - steering: an AStarGrid2D per clearance (CELL m cells; off-counter cells and solid boxes of dispensers,
##   soda, bells and scenery colliders grown by the walker's / carried food's radius are solid; the trash too
##   while carrying food that is not going there), followed to the farthest path point in sight; then a local
##   sampled turn around moving things (the food we approach, loose food when carrying), and an edge guard.

const EDGE := 1.0          # m to stay inside surface edges at gates / clamped targets
const EDGE_GUARD := 0.5    # m the next step must stay inside the counter
const MIN_GATE := 1.0      # m: a joint narrower than this is not a passage
const LEAD := 3.0          # m before a gate where the bot lines up with it
const LANE := 0.9          # m off a narrow gate's centre line, to the side set by the crossing direction
const LOOK := 4.0          # m of path ahead that local steering keeps clear of loose food
const STEER_TRIES := [15.0, 30.0, 45.0, 60.0, 75.0, 90.0]
const CELL := 0.5          # m per A* grid cell
const WALK_CLEAR := 0.75   # m a walking chef keeps from solid things
const WALK_EDGE := 0.6     # m a walking chef keeps from counter edges
const CARRY_EDGE := 0.5    # m carried food (or its carrier) keeps from counter edges

var world: World
var surfs: Array = []      # Rect2 (x, z, w, h)
var adj: Array = []        # per surface: neighbour indices
var gates: Dictionary = {} # Vector2i(i, j) -> Rect2 (overlap / shared edge)
var boxes: Array = []      # solid footprints: [Vector3 centre, half x, half z, yaw]
var _bounds := Rect2()
var _grids: Dictionary = {}     # "edge/clear/trash" -> AStarGrid2D
var _path: PackedVector2Array = PackedVector2Array()
var _path_key := ""
var _path_frame := -100
var log_prefix := ""       # "bot <id>" when --bot-log, else "" (no route logging)
var _last_hop := ""
var _logged_hop := ""
var _steer_sign := 1.0


func _init(w: World) -> void:
	world = w
	surfs = (w.map["surfaces"] as Array).duplicate()
	for i in surfs.size():
		adj.append([])
	for i in surfs.size():
		for j in surfs.size():
			if i == j:
				continue
			var g := _gate(surfs[i], surfs[j])
			if g.size.x >= MIN_GATE or g.size.y >= MIN_GATE:
				if g.size.x >= 0.0 and g.size.y >= 0.0:
					adj[i].append(j)
					gates[Vector2i(i, j)] = g
	for s in w.stations:
		if s is Dispenser or s is Bell:
			boxes.append([_flat(s.global_position), s.half.x, s.half.y, 0.0])
	for s in w.map.get("scenery", []):
		if bool(s.get("flat", false)):
			continue
		var sz: Vector3 = s.get("collider", s["size"])
		var yaw := deg_to_rad(float(s.get("yaw", 0.0)))
		var off: Vector3 = s.get("collider_offset", Vector3.ZERO)
		boxes.append([_flat(s["pos"] + off.rotated(Vector3.UP, yaw)), sz.x * 0.5, sz.z * 0.5, yaw])
	_bounds = GameData.surfaces_bounds(surfs) if not surfs.is_empty() else Rect2()


## Distance from p to a solid box's footprint (0 inside).
static func _box_dist(b: Array, p: Vector3) -> float:
	var l := _flat(p - b[0]).rotated(Vector3.UP, -float(b[3]))
	var dx := maxf(absf(l.x) - float(b[1]), 0.0)
	var dz := maxf(absf(l.z) - float(b[2]), 0.0)
	return sqrt(dx * dx + dz * dz)


## Overlap of two rects, including a shared edge (size 0 on that axis); negative size when apart.
static func _gate(a: Rect2, b: Rect2) -> Rect2:
	var p := Vector2(maxf(a.position.x, b.position.x), maxf(a.position.y, b.position.y))
	var e := Vector2(minf(a.end.x, b.end.x), minf(a.end.y, b.end.y))
	return Rect2(p, e - p)


## The surfaces p is at least EDGE inside, else the one it is deepest inside (so a unit only counts as on the
## next surface once it is well onto it, not while its edge touches the overlap).
func _depth_surfaces(p: Vector3) -> Array:
	var out: Array = []
	var best := -1
	var bd := -INF
	for i in surfs.size():
		var r: Rect2 = surfs[i]
		var d := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.z - r.position.y, r.end.y - p.z))
		if d >= EDGE:
			out.append(i)
		if d > bd:
			bd = d
			best = i
	if out.is_empty() and bd >= 0.0:
		out.append(best)
	return out


func surfaces_at(p: Vector3) -> Array:
	var out: Array = []
	for i in surfs.size():
		var r: Rect2 = surfs[i]
		if p.x >= r.position.x and p.x <= r.end.x and p.z >= r.position.y and p.z <= r.end.y:
			out.append(i)
	return out


## True when p is on the counter at least margin m inside some surface.
func inside(p: Vector3, margin: float) -> bool:
	for r: Rect2 in surfs:
		if p.x >= r.position.x + margin and p.x <= r.end.x - margin and p.z >= r.position.y + margin and p.z <= r.end.y - margin:
			return true
	return false


## True when p is within pad m of a joint between surfaces (standing there blocks the way across).
func near_gate(p: Vector3, pad: float) -> bool:
	for g: Rect2 in gates.values():
		if g.grow(pad).has_point(Vector2(p.x, p.z)):
			return true
	return false


## True when p lies within pad m of a solid footprint.
func blocked(p: Vector3, pad := 0.0) -> bool:
	for b in boxes:
		if _box_dist(b, p) < pad:
			return true
	return false


## p moved into the surface it is on (or the nearest one), margin m inside its edges.
func clamp_in(p: Vector3, margin := EDGE) -> Vector3:
	if inside(p, margin):
		return p
	var best := p
	var bd := INF
	for r: Rect2 in surfs:
		var m := minf(margin, minf(r.size.x, r.size.y) * 0.5)
		var q := Vector3(clampf(p.x, r.position.x + m, r.end.x - m), p.y, clampf(p.z, r.position.y + m, r.end.y - m))
		var d := _flat(q - p).length()
		if d < bd:
			bd = d
			best = q
	return best


## Where to head for on the way from -> to (to itself when one surface holds both). lane: walkers keep to
## a side on narrow gates; carried food goes along the centre line.
func waypoint(from: Vector3, to: Vector3, lane := true) -> Vector3:
	if surfs.size() < 2:
		return to
	var a := _depth_surfaces(from)
	var b := surfaces_at(to)
	if a.is_empty() or b.is_empty():
		return to
	for i in a:
		if b.has(i):
			return to
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
		for j in adj[i]:
			if not prev.has(j):
				prev[j] = i
				queue.append(j)
	if found < 0:
		return to
	var hop := found
	while not a.has(prev[hop]):
		hop = prev[hop]
	var here: int = prev[hop]
	var g: Rect2 = gates[Vector2i(here, hop)]
	var hr: Rect2 = surfs[here]
	var nr: Rect2 = surfs[hop]
	# Cross along the gate's thin axis, towards the next surface.
	var along_x := g.size.x <= g.size.y
	var c := g.get_center()
	var sgn := signf((nr.get_center() - hr.get_center()).x if along_x else (nr.get_center() - hr.get_center()).y)
	if sgn == 0.0:
		sgn = 1.0
	var axis := Vector2(sgn, 0) if along_x else Vector2(0, sgn)
	var lat_lo := g.position.y if along_x else g.position.x
	var lat_hi := g.end.y if along_x else g.end.x
	var f2 := Vector2(from.x, from.z)
	var lat := (lat_lo + lat_hi) * 0.5
	if lat_hi - lat_lo >= 6.0:  # wide joint: cross where we are, EDGE+ inside it; narrow (plank): centre line
		lat = clampf(f2.y if along_x else f2.x, lat_lo + EDGE + 0.5, lat_hi - EDGE - 0.5)
	else:  # narrow: keep to one side by travel direction, so two chefs crossing opposite ways pass
		var off_c := minf(LANE, (lat_hi - lat_lo) * 0.5 - 1.2)
		if lane and off_c > 0.0:
			lat += off_c * (axis.x if along_x else -axis.y)
	var cross := Vector2(c.x, lat) if along_x else Vector2(lat, c.y)
	var off := f2 - cross
	var lateral := absf(off.y if along_x else off.x)
	var before := -(off.dot(axis))  # m still to go along the axis
	var half_g := (g.size.x if along_x else g.size.y) * 0.5
	var lead := cross - axis * (half_g + LEAD)
	var exit := cross + axis * (half_g + EDGE + 0.5)
	var target := exit
	var step := "exit"
	# Hysteresis: once lined up (exit), only a big drift sends us back to the lead-in, and the reverse.
	var key := "%d->%d" % [here, hop]
	var was_lead := _last_hop == key + " lead-in"
	var need_lat := 0.3 if was_lead else (1.2 if _last_hop == key + " exit" else 0.4)
	if lateral > need_lat and before > half_g + 0.5 and hr.has_point(lead):
		target = lead
		step = "lead-in"
	var hop_s := "%s %s" % [key, step]
	if hop_s != _last_hop:
		_last_hop = hop_s
	if log_prefix != "" and hop_s != _logged_hop:
		_logged_hop = hop_s
		print("%s: route surface %s at (%.1f, %.1f) towards (%.1f, %.1f)" % [log_prefix, hop_s, target.x, target.y, to.x, to.z])
	return Vector3(target.x, 0, target.y)


## Rough walking length from a to b: straight on one surface, else through the gate centres of the
## shortest surface chain (for time estimates only).
func path_len(a: Vector3, b: Vector3) -> float:
	var direct := _flat(b - a).length()
	if surfs.size() < 2:
		return direct
	var sa := surfaces_at(a)
	var sb := surfaces_at(b)
	if sa.is_empty() or sb.is_empty() or sa.any(func(i: int) -> bool: return sb.has(i)):
		return direct
	var prev := {}
	var queue: Array = sa.duplicate()
	for i in sa:
		prev[i] = -1
	var found := -1
	while not queue.is_empty():
		var i: int = queue.pop_front()
		if sb.has(i):
			found = i
			break
		for j in adj[i]:
			if not prev.has(j):
				prev[j] = i
				queue.append(j)
	if found < 0:
		return direct
	var pts: Array = [b]
	var hop := found
	while int(prev[hop]) >= 0:
		var g: Rect2 = gates[Vector2i(prev[hop], hop)]
		pts.push_front(Vector3(g.get_center().x, 0, g.get_center().y))
		hop = prev[hop]
	var total := 0.0
	var at := a
	for p in pts:
		total += _flat(p - at).length()
		at = p
	return total


## Unit direction from `from` towards target: along the A* path (grid for a walker, or for carried food of
## that size), then turned a little round moving things: avoid (the food we walk up to) and, when carrying,
## loose food within 8 m (instead of shoving it along).
func steer(from: Vector3, target: Vector3, _extra := 0.0, avoid: Item = null, carrying: Item = null) -> Vector3:
	var to := _flat(target - from)
	if to.length() < 0.01:
		return Vector3.ZERO
	var g: AStarGrid2D
	if carrying == null:
		g = _grid(WALK_EDGE, WALK_CLEAR, false)
	else:
		var near_trash: bool = world.trash != null and _flat(target - world.trash.global_position).length() <= world.trash.half.x + 1.0
		# Carried food is swept and slides along scenery, so a modest margin; a full radius closes pockets.
		g = _grid(CARRY_EDGE, maxf(WALK_CLEAR, snappedf(carrying.radius() * 0.7, 0.25)), not near_trash)
	var sub := _follow(g, from, target)
	var dir := _flat(sub - from)
	if dir.length() < 0.01:
		dir = to
	dir = dir.normalized()
	var f := _flat(from)
	var t2 := _flat(target)
	var rings: Array = []
	if avoid != null:
		rings.append([_flat(avoid.global_position), avoid.radius() + 0.45])
	if carrying != null:
		for it in world.items.values():
			if it == carrying or it.removed or it.carrier_count > 0:
				continue
			var p := _flat(it.global_position)
			if _flat(p - f).length() < 8.0 and _flat(p - t2).length() > it.radius() + 1.0:
				rings.append([p, it.radius() * 0.8 + carrying.radius() * 0.5 + 0.3])
	if rings.is_empty():
		return dir
	for ring in rings:  # a ring holding the target shrinks so the target stays reachable
		var dt := _flat(t2 - ring[0]).length()
		if dt < float(ring[1]):
			ring[1] = maxf(0.3, dt - 0.2)
	var look := minf(to.length(), LOOK)
	if _clear(f, dir, look, rings):
		return dir
	for deg in STEER_TRIES:
		for sgn in [_steer_sign, -_steer_sign]:
			var d := dir.rotated(Vector3.UP, deg_to_rad(deg * sgn))
			if _clear(f, d, look, rings) and _los(g, f, f + d * minf(look, 1.5)):
				_steer_sign = sgn
				return d
	return dir


## The A* grid for this clearance: off-counter cells (edge m inside) and solid footprints grown by clear m are
## solid; with trash, also the trash drain (it eats carried food). Built once per key, then cached.
func _grid(edge: float, clear: float, trash: bool) -> AStarGrid2D:
	var key := "%.2f/%.2f/%s" % [edge, clear, trash]
	if _grids.has(key):
		return _grids[key]
	var g := AStarGrid2D.new()
	var w := ceili(_bounds.size.x / CELL) + 1
	var h := ceili(_bounds.size.y / CELL) + 1
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2(CELL, CELL)
	g.offset = _bounds.position
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for x in w:
		for y in h:
			if not inside(_cell_pos(Vector2i(x, y)), edge):
				g.set_point_solid(Vector2i(x, y), true)
	var solids: Array = boxes.duplicate()
	if trash and world.trash != null:
		var th: float = world.trash.half.x
		solids.append([_flat(world.trash.global_position), th, th, 0.0])
	for b in solids:
		var reach := maxf(float(b[1]), float(b[2])) * 1.5 + clear
		var c0 := _cell_of(b[0] - Vector3(reach, 0, reach))
		var c1 := _cell_of(b[0] + Vector3(reach, 0, reach))
		for x in range(maxi(c0.x, 0), mini(c1.x, w - 1) + 1):
			for y in range(maxi(c0.y, 0), mini(c1.y, h - 1) + 1):
				if _box_dist(b, _cell_pos(Vector2i(x, y))) < clear:
					g.set_point_solid(Vector2i(x, y), true)
	_grids[key] = g
	return g


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - _bounds.position.x) / CELL), roundi((p.z - _bounds.position.y) / CELL))


func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(_bounds.position.x + c.x * CELL, 0, _bounds.position.y + c.y * CELL)


func _free(g: AStarGrid2D, c: Vector2i) -> bool:
	return g.is_in_boundsv(c) and not g.is_point_solid(c)


## Nearest free cell to c (rings out to 8 cells), or c itself.
func _free_near(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if _free(g, c):
		return c
	for r in range(1, 9):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q in [Vector2i(c.x + dx, c.y + dy), Vector2i(c.x + dy, c.y + dx)]:
					if _free(g, q) and Vector2(q - c).length() < bd:
						bd = Vector2(q - c).length()
						best = q
		if best.x >= 0:
			return best
	return c


## True when the straight line a -> b crosses no solid cell.
func _los(g: AStarGrid2D, a: Vector3, b: Vector3) -> bool:
	var d := _flat(b - a)
	var n := maxi(1, ceili(d.length() / (CELL * 0.5)))
	for i in range(1, n + 1):
		var c := _cell_of(a + d * (float(i) / n))
		if g.is_in_boundsv(c) and g.is_point_solid(c):
			return false
	return true


## The point to head for now: the target when in plain sight, else the farthest point of the A* path
## (recomputed every 10 frames or on a new target) that is in sight.
func _follow(g: AStarGrid2D, from: Vector3, target: Vector3) -> Vector3:
	if _los(g, from, target):
		return target
	var sc := _free_near(g, _cell_of(from))
	var tc := _free_near(g, _cell_of(target))
	var key := "%d|%s" % [g.get_instance_id(), str(tc)]
	var frame := Engine.get_physics_frames()
	if key != _path_key or frame - _path_frame >= 10:
		_path = g.get_point_path(sc, tc, true)
		_path_key = key
		_path_frame = frame
	if _path.size() < 2 or _path[_path.size() - 1].distance_to(Vector2(_cell_pos(tc).x, _cell_pos(tc).z)) > CELL * 1.5:
		return target  # no full path (boxed in by the margins): head straight, the physics sweep slides us
	var near := 0
	var nd := INF
	for i in _path.size():
		var d := Vector2(from.x, from.z).distance_squared_to(_path[i])
		if d < nd:
			nd = d
			near = i
	var start := from if _free(g, _cell_of(from)) else _cell_pos(sc)
	for i in range(mini(_path.size() - 1, near + 16), near, -1):
		var p := Vector3(_path[i].x, 0, _path[i].y)
		if _los(g, start, p):
			if i == _path.size() - 1 and _flat(target - p).length() < 1.5:
				return target
			return p
	var nxt: Vector2 = _path[mini(near + 1, _path.size() - 1)]
	return Vector3(nxt.x, 0, nxt.y)


## True when the segment f -> f + d * len stays out of every ring (one we are already inside only blocks
## moving further into it).
static func _clear(f: Vector3, d: Vector3, len: float, rings: Array) -> bool:
	for ring in rings:
		var oc: Vector3 = ring[0] - f
		var c := float(ring[1])
		var ol := oc.length()
		if ol < c:
			if oc.dot(d) > 0.2 * ol:
				return false
			continue
		var t := clampf(oc.dot(d), 0.0, len)
		if (oc - d * t).length() < c:
			return false
	return true


## Keep the next step on the counter: when pos + dir * look leaves it, turn dir by the smallest angle that
## stays EDGE_GUARD inside (or return dir unchanged when nothing works).
func guard(pos: Vector3, dir: Vector3, look := 1.2) -> Vector3:
	if dir.length() < 0.01 or surfs.is_empty():
		return dir
	var l := dir.length()
	var u := dir / l
	var m := EDGE_GUARD if inside(pos, EDGE_GUARD) else 0.0
	if inside(pos + u * look, m):
		return dir
	for deg in [25.0, -25.0, 50.0, -50.0, 75.0, -75.0, 100.0, -100.0]:
		var v := u.rotated(Vector3.UP, deg_to_rad(deg))
		if inside(pos + v * look, m):
			return v * l
	return dir


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
