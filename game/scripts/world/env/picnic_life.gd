class_name PicnicLife
extends Node3D
## Decorative life for the picnic theme, animated in code on every peer (no collision, no sync):
## a bee lazily looping over the far edge, a line of ants marching along the far edge of the table
## (up over the back edge, along the top, down the other end), and a few leaves drifting through the
## air on the prevailing breeze. Uses the bee / ant / leaf models (primitive fallback without them).
## Built by EnvPicnic; `bounds` is the map's surface rect.

const ANTS := 6
const ANT_SPEED := 2.2          # m/s
const DRIFT_LEAVES := 9
const BREEZE := Vector3(1.0, 0.0, 0.35)   # the calm-weather drift (from the west-north-west)

var bounds := Rect2(-28, -20, 56, 40)

var _t := 0.0
var _bee: Node3D
var _wings: Array = []
var _ants: Array = []
var _ant_path: Curve3D
var _leaves: Array = []    # [node, phase, speed, height, lane]


func _ready() -> void:
	_bee = _model("bee", Vector3(1.4, 1.0, 1.6), Color(0.95, 0.75, 0.2))
	_bee.name = "Bee"
	add_child(_bee)
	for c in _bee.find_children("*", "MeshInstance3D", true, false):
		if str(c.name).to_lower().contains("wing"):
			_wings.append(c)
	_build_ant_path()
	for i in ANTS:
		var a := _model("ant", Vector3(1.2, 0.6, 2.0), Color(0.18, 0.12, 0.1))
		a.name = "Ant%d" % i
		add_child(a)
		_ants.append(a)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in DRIFT_LEAVES:
		var lf := _model("leaf", Vector3(1.5, 0.2, 2.5), Color(0.5, 0.62, 0.24))
		lf.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
		add_child(lf)
		_leaves.append([lf, rng.randf(), rng.randf_range(2.2, 3.6), rng.randf_range(2.0, 14.0), rng.randf_range(-1.0, 1.0),
			Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized()])
	_update(0.0)


func _model(name_: String, size: Vector3, color: Color) -> Node3D:
	var m := Models.load_model(name_)
	if m == null:
		m = Models.primitive("sphere", size, color)
	return m


## Ants: up the back face at the left of the cloth, along the top just inside the far edge, down
## the back face at the right end. Positions in world space.
func _build_ant_path() -> void:
	_ant_path = Curve3D.new()
	var z := bounds.position.y
	var x0 := bounds.get_center().x - EnvPicnic.CLOTH_HX + 1.5
	var x1 := bounds.get_center().x + EnvPicnic.CLOTH_HX - 1.5
	var out := z - EnvPicnic.ROLL_R - 0.45
	_ant_path.add_point(Vector3(x0, -6.0, out - 0.2))
	_ant_path.add_point(Vector3(x0 + 0.4, -0.9, out))
	_ant_path.add_point(Vector3(x0 + 0.8, 0.05, z + 0.25))
	_ant_path.add_point(Vector3(x0 + 2.0, 0.02, z + 0.7))
	var n := 10
	for i in n:
		var x := lerpf(x0 + 4.0, x1 - 4.0, float(i) / (n - 1))
		_ant_path.add_point(Vector3(x, 0.02, z + 0.7 + sin(i * 1.7) * 0.2))
	_ant_path.add_point(Vector3(x1 - 2.0, 0.02, z + 0.7))
	_ant_path.add_point(Vector3(x1 - 0.8, 0.05, z + 0.25))
	_ant_path.add_point(Vector3(x1 - 0.4, -0.9, out))
	_ant_path.add_point(Vector3(x1, -6.0, out - 0.2))
	_ant_path.bake_interval = 0.25


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


func _update(_delta: float) -> void:
	var c := bounds.get_center()
	# Bee: a slow figure-of-eight over the far edge, bobbing, nose along its path.
	var bt := _t * 0.22
	var bee_z := bounds.position.y + 6.0     # just in front of the far-edge dispenser row
	var bp := Vector3(c.x + sin(bt) * 15.0, 5.2 + sin(_t * 0.9) * 0.8 + sin(_t * 7.0) * 0.12, bee_z + sin(bt * 2.0) * 3.0)
	var nt := bt + 0.05
	var ahead := Vector3(c.x + sin(nt) * 15.0, bp.y, bee_z + sin(nt * 2.0) * 3.0)
	_bee.position = bp
	if ahead.distance_to(bp) > 0.01:
		_bee.look_at(ahead, Vector3.UP, true)
	_bee.rotate_object_local(Vector3.FORWARD, sin(_t * 1.3) * 0.2)
	for w in _wings:
		(w as Node3D).scale = Vector3(1.0, 1.0, 0.6 + 0.4 * absf(sin(_t * 60.0)))
	# Ants along the path, spaced out, wrapping.
	var length := _ant_path.get_baked_length()
	for i in _ants.size():
		var a: Node3D = _ants[i]
		var s := fposmod(_t * ANT_SPEED + i * (length / _ants.size()) + (i % 2) * 0.8, length)
		var p := _ant_path.sample_baked(s)
		var q := _ant_path.sample_baked(minf(s + 0.3, length))
		a.position = p + Vector3(0, absf(sin(_t * 14.0 + i)) * 0.04, 0)
		var dir := q - p
		if dir.length() > 0.001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.8 else Vector3(0, 0, 1)
			a.look_at(a.global_position + dir, up, true)
	# Leaves: drift along the breeze over a wide band, tumbling, and loop around.
	var span := 140.0
	var side := Vector3(-BREEZE.z, 0, BREEZE.x).normalized()
	var bz := BREEZE.normalized()
	for l in _leaves:
		var node: Node3D = l[0]
		var ph: float = l[1]
		var sp: float = l[2]
		var d := fposmod(_t * sp + ph * span, span) - span * 0.5
		var p := Vector3(c.x, 0, c.y) + bz * d + side * float(l[4]) * 30.0
		p.y = float(l[3]) + sin(_t * 0.8 + ph * 9.0) * 1.5
		p += side * sin(_t * 1.1 + ph * 5.0) * 1.2
		node.position = p
		node.basis = Basis(l[5], _t * (0.9 + ph) + ph * 6.0).scaled(node.basis.get_scale())
