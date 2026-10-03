class_name Vfx
extends Node3D
## Small pooled effects manager (created by World on every peer). It only OBSERVES state every peer already
## has, so nothing here is networked and nothing here touches gameplay:
##   items (World.items: spawn, kind change = cooked/burnt, cooking flag, carried flag, speed),
##   chefs (position -> speed, flags: punching / respawning, held_id), plates (stack), the cutting board and the
##   soda fountain (their replicated state), the order list (VIP) and Net.event_received (serve / wrong serve /
##   inspector fine, the same events that already play their sounds).
## Particle emitters, coins, "+N" labels and broom sweeps are built once (pools, round robin) and reused; the
## per-frame work is a few loops over the items and chefs. Particle counts follow Quality's "particles" scale.
## --no-vfx disables the whole thing (A/B for the perf numbers). --vfx-demo fires every family in a grid
## around the local chef every 1.6 s (dev scene for screenshots).

enum K { STEAM, PUFF, STAR, GLINT, SMOKE, EMBER, DROP, CHIP, BUBBLE, FOAM, CONFETTI, THUD, TRAIL, SWEAT, XMARK, CLIP, COUNT }

const COIN_POOL := 12
const LABEL_POOL := 3
const SWEEP_POOL := 3
const LINES_POOL := 4
const DEMO_SHOT_AT := [0.12, 0.3, 0.55, 0.9]
const TEX_N := 48
const SIZE := 2.1   # world metres per unit: chefs are ~1 m, food 1 to 4 m, the camera ~17 m away

static var _textures: Dictionary = {}
static var _materials: Dictionary = {}
static var _curves: Dictionary = {}
static var _ramps: Dictionary = {}

class Kind:
	var base := 0
	var count := 1
	var next := 0
	var life := 0.5
	var smin := 1.0
	var smax := 1.0
	var col := Color.WHITE
	var dir := Vector3.UP

class ItemTrack:
	var kind := ""
	var seen := 0
	var carried := false
	var cooking := false
	var pos := Vector3.ZERO
	var age := 0.0
	var steam_t := 0.0
	var smoke_t := 0.0
	var trail_t := 0.0
	var drop_t := -1.0

class ChefTrack:
	var seen := 0
	var pos := Vector3.ZERO
	var speed := 0.0
	var flags := 0
	var step_t := 0.0
	var sweat_t := 0.0
	var ok_y := 0.0
	var ok_pos := Vector3.ZERO
	var fell := false

class Coin:
	var node: MeshInstance3D
	var t := -1.0       # < 0: idle
	var delay := 0.0
	var dur := 0.9
	var start := Vector3.ZERO
	var lift := 3.0
	var depth := 20.0
	var spin := 0.0

var world: World
var _off := false
var _demo := false
var _demo_t := 0.0
var _demo_n := 0
var _demo_since := 0.0
var _demo_shots := 0
var _demo_shots_done := 0
var _now := 0.0
var _age := 0.0
var _frame := 0
var _quiet := true
var _pscale := 1.0
var _rng := RandomNumberGenerator.new()

var _kinds: Array[Kind] = []
var _slots: Array[CPUParticles3D] = []
var _exp := PackedFloat64Array()
var _hide_t := 0.0

var _itracks: Dictionary = {}
var _itrack_free: Array[ItemTrack] = []
var _gone: Array = []
var _ctracks: Dictionary = {}
var _cgone: Array = []

var _plate_n := PackedInt32Array()
var _plate_t := PackedFloat64Array()
var _vip_open := false
var _vip_check := 0.0
var _vip_t := 0.0
var _clip_i := 0

var _board_phase := 0
var _bfood_frame := -1
var _bfood_col := Color.WHITE
var _bfood_pos := Vector3.ZERO
var _pour_bub := 0.0
var _pour_foam := 0.0

var _coins: Array[Coin] = []
var _coin_screen := Vector2(0.11, 0.075)   # fraction of the viewport: the HUD coin chip (top-left)
var _labels: Array[Label3D] = []
var _label_t := PackedFloat32Array()
var _label_base := PackedVector3Array()
var _label_next := 0
var _sweeps: Array[MeshInstance3D] = []
var _sweep_t := PackedFloat32Array()
var _sweep_next := 0
var _lines: Array[MeshInstance3D] = []
var _line_t := PackedFloat32Array()
var _line_dir := PackedVector3Array()
var _line_p0 := PackedVector3Array()
var _line_next := 0
var _motes: CPUParticles3D
var _auto_dir := ""   # --vfx-auto-shot=<dir>: first time each family plays, save <dir>/<role>-<tag>.png 0.3 s later
var _auto_done: Dictionary = {}
var _auto_q: Array = []


func _init(w: World) -> void:
	world = w
	name = "Vfx"
	process_priority = 150   # after the camera driver (100): coins project with this frame's camera


func _ready() -> void:
	_off = Net.has_arg("no-vfx")
	if _off:
		set_process(false)
		return
	_demo = Net.has_arg("vfx-demo")
	_auto_dir = Net.arg_str("vfx-auto-shot", "")
	_demo_shots = 4 if Net.has_arg("vfx-demo-shot") else 0
	_rng.seed = 4242
	_pscale = float(Quality.preset().get("particles", 1.0))
	_build_kinds()
	_build_coins()
	_build_labels()
	_build_sweeps()
	_build_lines()
	_build_motes()
	_plate_n.resize(world.plates.size())
	_plate_t.resize(world.plates.size())
	Net.event_received.connect(_on_event)


func _exit_tree() -> void:
	if Net.event_received.is_connected(_on_event):
		Net.event_received.disconnect(_on_event)


# ================================================================ pools

func _build_kinds() -> void:
	_kinds.resize(K.COUNT)
	var cream := Color(UITheme.CREAM, 0.55)
	# id: pool, amount, life, tex, additive, flat | speed range, spread, dir | gravity, scale range, curve, ramp, colour
	_def(K.STEAM, 10, 3, 1.0, "soft", false, {"v": [0.5, 1.0], "spread": 25.0, "g": Vector3(0, 0.15, 0), "s": [0.55, 0.9],
		"curve": "grow", "ramp": "inout", "col": Color(0.97, 0.98, 1.0, 0.6), "expl": 0.5})
	_def(K.PUFF, 12, 5, 0.55, "soft", false, {"v": [0.8, 2.2], "spread": 80.0, "g": Vector3(0, 0.3, 0), "s": [0.35, 0.6],
		"curve": "grow", "ramp": "out", "col": Color(1.0, 0.98, 0.93, 0.85), "damp": [1.5, 2.5]})
	_def(K.STAR, 8, 6, 0.5, "star", true, {"v": [1.5, 3.5], "spread": 180.0, "g": Vector3.ZERO, "s": [0.35, 0.65],
		"curve": "pop", "ramp": "out", "col": Color(UITheme.MUSTARD, 1.0), "spin": 200.0, "damp": [2.0, 3.0]})
	_def(K.GLINT, 8, 1, 0.35, "star", true, {"v": [0.0, 0.0], "spread": 0.0, "g": Vector3.ZERO, "s": [0.7, 0.7],
		"curve": "pop", "ramp": "out", "col": Color(1.0, 0.98, 0.85, 1.0), "spin": 90.0})
	_def(K.SMOKE, 4, 3, 1.1, "soft", false, {"v": [0.8, 1.6], "spread": 25.0, "g": Vector3(0, 0.2, 0), "s": [0.55, 0.95],
		"curve": "grow", "ramp": "inout", "col": Color(0.15, 0.12, 0.14, 0.9), "expl": 0.6})
	_def(K.EMBER, 4, 5, 0.8, "dot", true, {"v": [2.0, 4.0], "spread": 45.0, "g": Vector3(0, -6.0, 0), "s": [0.1, 0.17],
		"curve": "shrink", "ramp": "out", "col": Color(1.0, 0.5, 0.15, 1.0)})
	_def(K.DROP, 4, 9, 0.65, "dot", false, {"v": [3.0, 5.5], "spread": 55.0, "g": Vector3(0, -14.0, 0), "s": [0.12, 0.2],
		"curve": "none", "ramp": "out", "col": Color(1.0, 0.8, 0.3, 1.0)})
	_def(K.CHIP, 8, 5, 0.6, "square", false, {"v": [3.0, 5.0], "spread": 55.0, "g": Vector3(0, -16.0, 0), "s": [0.12, 0.22],
		"curve": "none", "ramp": "out", "col": Color.WHITE, "spin": 500.0})
	_def(K.BUBBLE, 6, 4, 0.9, "ring", false, {"v": [0.5, 1.2], "spread": 18.0, "g": Vector3(0, 0.4, 0), "s": [0.12, 0.24],
		"curve": "none", "ramp": "out", "col": Color(1.0, 0.92, 0.8, 0.9)})
	_def(K.FOAM, 4, 3, 0.7, "soft", false, {"v": [0.3, 0.8], "spread": 30.0, "g": Vector3(0, 0.2, 0), "s": [0.3, 0.45],
		"curve": "grow", "ramp": "out", "col": Color(1.0, 0.96, 0.92, 0.85)})
	_def(K.CONFETTI, 3, 26, 1.1, "square", false, {"v": [4.0, 9.0], "spread": 70.0, "g": Vector3(0, -9.0, 0), "s": [0.15, 0.25],
		"curve": "none", "ramp": "out2", "col": Color.WHITE, "spin": 540.0, "damp": [1.0, 2.0], "confetti": true})
	_def(K.THUD, 6, 1, 0.38, "ring", false, {"v": [0.0, 0.0], "spread": 0.0, "g": Vector3.ZERO, "s": [1.0, 1.0],
		"curve": "grow2", "ramp": "out", "col": Color(1.0, 1.0, 1.0, 0.9), "flat": true})
	_def(K.TRAIL, 12, 1, 0.35, "soft", false, {"v": [0.0, 0.1], "spread": 0.0, "g": Vector3.ZERO, "s": [0.3, 0.3],
		"curve": "shrink", "ramp": "out", "col": cream})
	_def(K.SWEAT, 4, 1, 0.55, "dot", false, {"v": [1.5, 2.2], "spread": 30.0, "g": Vector3(0, -9.0, 0), "s": [0.13, 0.13],
		"curve": "none", "ramp": "out", "col": Color(UITheme.SKY, 1.0), "dir": Vector3(0.6, 1.0, 0.0)})
	_def(K.XMARK, 2, 1, 0.75, "xmark", false, {"v": [0.0, 0.0], "spread": 0.0, "g": Vector3.ZERO, "s": [1.7, 1.7],
		"curve": "pop2", "ramp": "out2", "col": Color(UITheme.TOMATO, 1.0)})
	_def(K.CLIP, 2, 1, 0.9, "clip", false, {"v": [0.7, 0.7], "spread": 0.0, "g": Vector3.ZERO, "s": [2.2, 2.2],
		"curve": "pop2", "ramp": "out2", "col": Color.WHITE})
	_exp.resize(_slots.size())


func _def(id: int, pool: int, amount: int, life: float, tex: String, additive: bool, o: Dictionary) -> void:
	var k := Kind.new()
	k.base = _slots.size()
	k.count = pool
	k.life = life
	var s: Array = o["s"]
	var flat0 := bool(o.get("flat", false))
	var mul := 1.0 if (flat0 or tex == "xmark" or tex == "clip") else SIZE
	k.smin = float(s[0]) * mul
	k.smax = float(s[1]) * mul
	k.col = o["col"]
	k.dir = o.get("dir", Vector3.UP)
	_kinds[id] = k
	var flat := bool(o.get("flat", false))
	var mesh: PrimitiveMesh
	if flat:
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		mesh = q
	else:
		mesh = QuadMesh.new()
	mesh.material = _material(tex, additive, not flat)
	var v: Array = o["v"]
	var damp: Array = o.get("damp", [0.0, 0.0])
	for i in pool:
		var p := CPUParticles3D.new()
		p.amount = maxi(1, int(round(float(amount) * _pscale)))
		p.lifetime = life
		p.one_shot = true
		p.emitting = false
		p.explosiveness = float(o.get("expl", 1.0))
		p.local_coords = false
		p.mesh = mesh
		p.direction = k.dir
		p.spread = float(o["spread"])
		p.gravity = o["g"]
		p.initial_velocity_min = float(v[0])
		p.initial_velocity_max = float(v[1])
		p.damping_min = float(damp[0])
		p.damping_max = float(damp[1])
		p.scale_amount_min = k.smin
		p.scale_amount_max = k.smax
		p.scale_amount_curve = _curve(str(o["curve"]))
		p.color_ramp = _ramp(str(o["ramp"]))
		p.color = k.col
		var spin := float(o.get("spin", 0.0))
		if spin > 0.0:
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -spin
			p.angular_velocity_max = spin
		if bool(o.get("confetti", false)):
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.5
			p.color_initial_ramp = _ramp("confetti")
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visible = false
		add_child(p)
		_slots.append(p)


func _fire(k: int, pos: Vector3, sc := 1.0, col := Color(0, 0, 0, 0), dir := Vector3.ZERO) -> void:
	var kd: Kind = _kinds[k]
	var idx := kd.base + kd.next
	kd.next = (kd.next + 1) % kd.count
	var p: CPUParticles3D = _slots[idx]
	p.position = pos
	p.color = col if col.a > 0.0 else kd.col
	p.direction = dir if dir != Vector3.ZERO else kd.dir
	p.scale_amount_min = kd.smin * sc
	p.scale_amount_max = kd.smax * sc
	p.visible = true
	p.restart()
	_exp[idx] = _now + kd.life + 0.15


func _auto(tag: String) -> void:
	if _auto_dir == "" or _auto_done.has(tag):
		return
	_auto_done[tag] = true
	_auto_q.append([tag, 0.3])


func _run_auto(dt: float) -> void:
	for e in _auto_q:
		e[1] = float(e[1]) - dt
		if float(e[1]) <= 0.0:
			var path := "%s/%s-%s.png" % [_auto_dir, "host" if world.is_host else "client", e[0]]
			get_viewport().get_texture().get_image().save_png(path)
			print("vfx: auto shot %s" % path)
	_auto_q = _auto_q.filter(func(e): return float(e[1]) > 0.0)


func _expire() -> void:
	for i in _slots.size():
		if _exp[i] > 0.0 and _now > _exp[i]:
			_exp[i] = 0.0
			_slots[i].visible = false


# ---------------------------------------------------------------- shared resources (built once per process)

static func _tex(n: String) -> ImageTexture:
	if _textures.has(n):
		return _textures[n]
	var img := Image.create(TEX_N, TEX_N, true, Image.FORMAT_RGBA8)
	for y in TEX_N:
		for x in TEX_N:
			var u := (float(x) + 0.5) / TEX_N * 2.0 - 1.0
			var v := (float(y) + 0.5) / TEX_N * 2.0 - 1.0
			img.set_pixel(x, y, _texel(n, u, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_textures[n] = t
	return t


static func _texel(n: String, u: float, v: float) -> Color:
	var r := sqrt(u * u + v * v)
	var a := 0.0
	match n:
		"soft":
			a = pow(clampf(1.0 - r, 0.0, 1.0), 0.75)
		"dot":
			a = 1.0 - smoothstep(0.7, 1.0, r)
		"star":
			var f := sqrt(absf(u)) + sqrt(absf(v))
			a = 1.0 - smoothstep(0.8, 1.05, f)
			a = maxf(a, pow(clampf(1.0 - r * 1.6, 0.0, 1.0), 2.0) * 0.9)
		"ring":
			a = smoothstep(0.62, 0.78, r) * (1.0 - smoothstep(0.86, 0.98, r))
			a = maxf(a, (1.0 - smoothstep(0.0, 0.8, r)) * 0.12)
		"square":
			a = 1.0 - smoothstep(0.82, 1.0, maxf(absf(u), absf(v)))
		"streak":
			a = (1.0 - smoothstep(0.2, 0.95, absf(u))) * smoothstep(-1.0, 0.1, v) * (1.0 - smoothstep(0.7, 1.0, v))
		"xmark":
			var d := minf(absf(u - v), absf(u + v)) * 0.7071
			a = (1.0 - smoothstep(0.17, 0.25, d)) * (1.0 - smoothstep(0.82, 0.95, maxf(absf(u), absf(v))))
		"clip":
			return _clip_texel(u, v)
		"lines":
			for vc in [-0.55, 0.0, 0.55]:
				var b := (1.0 - smoothstep(0.07, 0.13, absf(v - vc))) * smoothstep(-0.95, -0.1, u + vc * 0.4) * (1.0 - smoothstep(0.85, 1.0, u))
				a = maxf(a, b)
		"swoosh":
			var ang := atan2(v, u)
			var band := smoothstep(0.52, 0.66, r) * (1.0 - smoothstep(0.88, 0.99, r))
			var win := smoothstep(-1.0, 0.2, ang) * (1.0 - smoothstep(0.75, 1.0, ang))
			a = band * win * (0.45 + 0.55 * smoothstep(-1.0, 0.8, ang))
	return Color(1, 1, 1, a)


static func _clip_texel(u: float, v: float) -> Color:
	# Clipboard: tomato board with a clip, cream sheet, ink lines.
	var ink := UITheme.INK
	if absf(u) < 0.22 and v > -0.95 and v < -0.72:
		return ink
	if absf(u) < 0.72 and v > -0.8 and v < 0.95:
		if absf(u) > 0.55 or v > 0.82 or v < -0.7:
			return UITheme.TOMATO_DARK
		if v > -0.4 and fposmod(v + 0.4, 0.36) < 0.09 and absf(u) < 0.4:
			return ink
		return UITheme.CREAM
	return Color(1, 1, 1, 0)


static func _material(tex: String, additive: bool, billboard: bool) -> StandardMaterial3D:
	var key := "%s|%d|%d" % [tex, int(additive), int(billboard)]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_texture = _tex(tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	_materials[key] = m
	return m


static func _curve(n: String) -> Curve:
	if n == "none":
		return null
	if _curves.has(n):
		return _curves[n]
	var c := Curve.new()
	match n:
		"grow":
			c.add_point(Vector2(0, 0.35))
			c.add_point(Vector2(1, 1.25))
		"grow2":
			c.add_point(Vector2(0, 0.5))
			c.add_point(Vector2(1, 1.5))
		"shrink":
			c.add_point(Vector2(0, 1.0))
			c.add_point(Vector2(1, 0.15))
		"pop":
			c.add_point(Vector2(0, 0.2))
			c.add_point(Vector2(0.18, 1.0))
			c.add_point(Vector2(1, 0.25))
		"pop2":
			c.add_point(Vector2(0, 0.3))
			c.add_point(Vector2(0.16, 1.15))
			c.add_point(Vector2(0.35, 0.95))
			c.add_point(Vector2(1, 1.0))
	_curves[n] = c
	return c


static func _ramp(n: String) -> Gradient:
	if _ramps.has(n):
		return _ramps[n]
	var g := Gradient.new()
	match n:
		"out":
			g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		"out2":
			g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"inout":
			g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
			g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		"confetti":
			g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
			g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8])
			g.colors = PackedColorArray([UITheme.TOMATO, UITheme.MUSTARD, UITheme.LETTUCE, UITheme.SKY, UITheme.CREAM])
	_ramps[n] = g
	return g


func _build_coins() -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 0.08
	cyl.radial_segments = 14
	cyl.rings = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = UITheme.MUSTARD
	m.emission_enabled = true
	m.emission = UITheme.MUSTARD_DARK
	m.emission_energy_multiplier = 0.6
	m.metallic = 0.4
	m.roughness = 0.35
	cyl.material = m
	var n := maxi(4, int(round(COIN_POOL * clampf(_pscale, 0.5, 1.0))))
	for i in n:
		var c := Coin.new()
		c.node = MeshInstance3D.new()
		c.node.mesh = cyl
		c.node.visible = false
		c.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c.node)
		_coins.append(c)


func _build_labels() -> void:
	for i in LABEL_POOL:
		var l := Label3D.new()
		l.font = UITheme.font(true)
		l.font_size = 96
		l.pixel_size = 0.014
		l.outline_size = 26
		l.modulate = UITheme.MUSTARD
		l.outline_modulate = UITheme.INK
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.shaded = false
		l.render_priority = 20
		l.outline_render_priority = 19
		l.visible = false
		add_child(l)
		_labels.append(l)
	_label_t.resize(LABEL_POOL)
	_label_base.resize(LABEL_POOL)
	for i in LABEL_POOL:
		_label_t[i] = -1.0


func _build_sweeps() -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(1, 1)
	for i in SWEEP_POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _tex("swoosh")
		m.albedo_color = Color(UITheme.CREAM, 0.0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_sweeps.append(mi)
	_sweep_t.resize(SWEEP_POOL)
	for i in SWEEP_POOL:
		_sweep_t[i] = -1.0


func _build_lines() -> void:
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(1, 1)
	for i in LINES_POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _tex("lines")
		m.albedo_color = Color(1, 1, 1, 0)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(4.2, 1.0, 2.2)
		mi.visible = false
		add_child(mi)
		_lines.append(mi)
	_line_t.resize(LINES_POOL)
	_line_dir.resize(LINES_POOL)
	_line_p0.resize(LINES_POOL)
	for i in LINES_POOL:
		_line_t[i] = -1.0


## High only, diner window: a few dust motes drifting in the daylight shaft (see EnvRoom._shaft).
func _build_motes() -> void:
	if Quality.active_preset() != "high" or str(world.map.get("theme", "diner")) != "diner":
		return
	var b := GameData.surfaces_bounds(world.map["surfaces"])
	var d := EnvLook.SUN_DIR.normalized()
	var top := Vector3(-8.0, 18.0, b.position.y - 1.5)
	var mid := top + d * (9.0 / absf(d.y))
	_motes = CPUParticles3D.new()
	_motes.amount = 22
	_motes.lifetime = 7.0
	_motes.preprocess = 7.0
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(8.0, 5.0, 3.0)
	_motes.position = mid
	_motes.direction = Vector3(0.2, -1.0, 0.1)
	_motes.spread = 60.0
	_motes.initial_velocity_min = 0.1
	_motes.initial_velocity_max = 0.4
	_motes.gravity = Vector3.ZERO
	_motes.scale_amount_min = 0.1
	_motes.scale_amount_max = 0.22
	_motes.color = Color(1.0, 0.92, 0.75, 0.55)
	_motes.color_ramp = _ramp("inout")
	var q := QuadMesh.new()
	q.material = _material("soft", true, true)
	_motes.mesh = q
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


# ================================================================ frame

func _process(delta: float) -> void:
	var t := Prof.t0()
	var dt := maxf(delta, 0.001)
	_now += dt
	_age += dt
	_frame += 1
	_quiet = Net.phase != Net.Phase.PLAYING or _age < 1.5
	_track_items(dt)
	_track_chefs(dt)
	_track_plates(dt)
	_track_board(dt)
	_track_soda(dt)
	_update_coins(dt)
	_update_labels(dt)
	_update_sweeps(dt)
	_update_lines(dt)
	_hide_t -= dt
	if _hide_t <= 0.0:
		_hide_t = 0.1
		_expire()
	if _demo:
		_run_demo(dt)
	if not _auto_q.is_empty():
		_run_auto(dt)
	Prof.add(&"vfx", t)


# ---------------------------------------------------------------- items

func _track_items(dt: float) -> void:
	var items := world.items
	var griddle := world.griddle
	var fryer := world.fryer
	var board := world.board
	for id in items:
		var it: Item = items[id]
		if it.removed or not is_instance_valid(it):
			continue
		var p := it.global_position
		var tr: ItemTrack = _itracks.get(id)
		if tr == null:
			tr = _itrack_free.pop_back() if not _itrack_free.is_empty() else ItemTrack.new()
			tr.kind = it.kind
			tr.carried = it.carrier_count > 0
			tr.cooking = it.cooking
			tr.pos = p
			tr.age = 0.0
			tr.steam_t = _rng.randf() * 0.5
			tr.smoke_t = 0.0
			tr.trail_t = 0.0
			tr.drop_t = -1.0
			_itracks[id] = tr
			tr.seen = _frame
			if not _quiet:
				_on_spawn(it, p)
			continue
		tr.seen = _frame
		tr.age += dt
		var v := (p - tr.pos) / dt
		tr.pos = p
		var hspeed := Vector2(v.x, v.z).length()
		var carried := it.carrier_count > 0
		# kind change: cooked / burnt
		if it.kind != tr.kind:
			var old: Dictionary = GameData.ITEMS.get(tr.kind, {})
			tr.kind = it.kind
			if not _quiet and tr.age > 0.3:
				if it.kind.ends_with("_burnt"):
					_fx_burn(p + Vector3(0, it.size.y, 0), it.radius())
				elif old.has("cooks_to") or old.has("fries_to"):
					_fx_ding(p + Vector3(0, it.size.y + 0.1, 0), it.radius())
		# cooking: steam, splash when it enters the fryer
		var on_hot := it.cooking
		if on_hot and not tr.cooking and not _quiet and fryer != null and fryer.contains_xz(p):
			_fx_splash(p + Vector3(0, it.size.y, 0), it.radius())
		tr.cooking = on_hot
		if not _quiet:
			if on_hot:
				tr.steam_t -= dt
				if tr.steam_t <= 0.0:
					tr.steam_t = 0.8 + _rng.randf() * 0.2
					_auto("steam")
					_fire(K.STEAM, p + Vector3(_rng.randf_range(-0.4, 0.4) * it.radius(), it.size.y + 0.1,
						_rng.randf_range(-0.4, 0.4) * it.radius()), clampf(it.radius() * 0.6, 0.6, 1.4))
			elif it.kind.ends_with("_burnt") and ((griddle != null and griddle.contains_xz(p)) or (fryer != null and fryer.contains_xz(p))):
				tr.smoke_t -= dt
				if tr.smoke_t <= 0.0:
					tr.smoke_t = 0.9
					_fire(K.SMOKE, p + Vector3(0, it.size.y + 0.1, 0), 0.8)
		# the cutting board's food colour (for the chips)
		if board != null and it.def.has("chops_to") and not carried and board.contains_xz(p):
			_bfood_frame = _frame
			_bfood_col = it.def["color"]
			_bfood_pos = p
		# released: soft thud ring once it has settled
		if tr.carried and not carried:
			tr.drop_t = 0.0
		tr.carried = carried
		if tr.drop_t >= 0.0:
			tr.drop_t += dt
			if carried:
				tr.drop_t = -1.0
			elif tr.drop_t >= 0.16:
				tr.drop_t = -1.0
				if not _quiet and hspeed < 3.5 and p.y > -1.0:
					_fx_thud(Vector3(p.x, p.y + 0.04, p.z), clampf(it.radius() * 2.0, 0.9, 3.0))
		# launched food: a puff trail
		if not carried and not _quiet and hspeed > 4.5 and hspeed < 60.0:
			tr.trail_t -= dt
			if tr.trail_t <= 0.0:
				tr.trail_t = 0.04
				_auto("trail")
				_fire(K.TRAIL, p + Vector3(0, it.size.y * 0.5, 0), clampf(it.radius() * 0.7, 0.5, 1.3))
	# items that vanished
	_gone.clear()
	for id in _itracks:
		var tr: ItemTrack = _itracks[id]
		if tr.seen != _frame:
			_gone.append(id)
	for id in _gone:
		var tr: ItemTrack = _itracks[id]
		_itracks.erase(id)
		if not _quiet and board != null and GameData.ITEMS.has(tr.kind) and GameData.ITEMS[tr.kind].has("chops_to") \
				and board.contains_xz(tr.pos, 0.5):
			var d: Dictionary = GameData.ITEMS[tr.kind]
			_fx_slice(tr.pos + Vector3(0, 0.6, 0), d["color"])
		_itrack_free.append(tr)


func _on_spawn(it: Item, p: Vector3) -> void:
	_fx_pop(p + Vector3(0, it.size.y * 0.6, 0), it.radius())
	if it.kind == "soda_cup":
		_fx_fizz(p + Vector3(0, it.size.y, 0))


# ---------------------------------------------------------------- chefs

func _track_chefs(dt: float) -> void:
	for id in world.chefs:
		var c: Chef = world.chefs[id]
		var p := c.global_position
		var tr: ChefTrack = _ctracks.get(id)
		if tr == null:
			tr = ChefTrack.new()
			tr.pos = p
			tr.ok_y = p.y
			tr.ok_pos = p
			tr.flags = c.flags
			tr.step_t = _rng.randf() * 0.2
			_ctracks[id] = tr
		tr.seen = _frame
		var hv := p - tr.pos
		var vy := hv.y / dt
		hv.y = 0.0
		var spd := hv.length() / dt
		if spd > 30.0:
			spd = 0.0   # a teleport (respawn), not running
		tr.speed = lerpf(tr.speed, spd, 1.0 - exp(-12.0 * dt))
		var fl := c.flags
		var respawning := (fl & Chef.FLAG_RESPAWNING) != 0
		var fwd := Vector3(sin(c.rotation.y), 0.0, cos(c.rotation.y))
		# fall off the counter edge / respawn
		if not respawning and absf(vy) < 1.0 and p.y > tr.ok_y - 0.6:
			tr.ok_y = p.y
			tr.ok_pos = p
			tr.fell = false
		elif not respawning and not tr.fell and p.y < tr.ok_y - 1.2:
			tr.fell = true
			if not _quiet:
				_fx_fall(tr.ok_pos + Vector3(0, 0.5, 0))
		if (tr.flags & Chef.FLAG_RESPAWNING) != 0 and not respawning:
			tr.fell = false
			tr.ok_y = p.y
			tr.ok_pos = p
			if not _quiet:
				_fx_respawn(p)
		# punch
		if (fl & Chef.FLAG_PUNCHING) != 0 and (tr.flags & Chef.FLAG_PUNCHING) == 0 and not _quiet:
			_fx_punch(p + Vector3(0, 0.65, 0), fwd)
		tr.flags = fl
		tr.pos = p
		if _quiet or respawning or p.y < tr.ok_y - 0.4:
			continue
		# footsteps / hauling
		if tr.speed > 1.2:
			var s01 := clampf(tr.speed / Tuning.PLAYER_SPEED, 0.0, 1.0)
			var short := false
			if c.held_id >= 0:
				var held: Item = world.items.get(c.held_id)
				if held != null and is_instance_valid(held) and not held.removed:
					short = held.weight() > 1 and held.weight() - held.carrier_count > 0
			tr.step_t -= dt
			if tr.step_t <= 0.0:
				if short:
					_auto("haul")
					tr.step_t = 0.3
					_fire(K.PUFF, p - fwd * 0.1 + Vector3(0, 0.1, 0), 1.5, Color(0.8, 0.7, 0.58, 0.75))
					_fire(K.PUFF, p - fwd * 0.5 + Vector3(0, 0.1, 0), 1.1, Color(0.8, 0.7, 0.58, 0.6))
				else:
					_auto("dust")
					tr.step_t = lerpf(0.34, 0.17, s01)
					_fire(K.PUFF, p - fwd * 0.2 + Vector3(0, 0.08, 0), 0.5 + 0.4 * s01)
			if short:
				tr.sweat_t -= dt
				if tr.sweat_t <= 0.0:
					tr.sweat_t = 0.55
					_fire(K.SWEAT, p + Vector3(0.28, 1.4, 0.0) + fwd * 0.1)


# ---------------------------------------------------------------- plates (stack, VIP shimmer)

func _plate_top(pl: Plate) -> float:
	var y := 0.12
	for k in pl.stack:
		y += float((GameData.ITEMS[k]["size"] as Vector3).y) * 0.9
	return y


func _track_plates(dt: float) -> void:
	var plates := world.plates
	if _plate_n.size() != plates.size():
		_plate_n.resize(plates.size())
		_plate_t.resize(plates.size())
	for i in plates.size():
		var pl: Plate = plates[i]
		var n := pl.stack.size()
		var prev := _plate_n[i]
		if n > 0:
			_plate_t[i] = _now
		if n != prev and not _quiet:
			if n > prev:
				_fx_snap(pl.global_position + Vector3(0, _plate_top(pl), 0))
			elif n == 0:
				_fx_broom(pl)
		_plate_n[i] = n
	# VIP shimmer on the plates while a VIP order is open
	_vip_check -= dt
	if _vip_check <= 0.0:
		_vip_check = 0.3
		_vip_open = false
		for o in world.orders.orders:
			if bool(o.get("vip", false)):
				_vip_open = true
				break
	if _vip_open and not _quiet:
		_vip_t -= dt
		if _vip_t <= 0.0:
			_vip_t = 0.4
			for pl in plates:
				if pl.is_locked():
					continue
				_auto("vip")
				var a := _rng.randf() * TAU
				var r := _rng.randf() * (pl.half.x - 0.6)
				_fire(K.GLINT, pl.global_position + Vector3(cos(a) * r, _plate_top(pl) + 0.15, sin(a) * r), 0.8,
					Color(UITheme.MUSTARD, 0.9))


# ---------------------------------------------------------------- cutting board, soda fountain

func _track_board(_dt: float) -> void:
	var b := world.board
	if b == null:
		return
	var ph: int = b._last_phase
	if ph != _board_phase:
		_board_phase = ph
		if b.chopping and not _quiet:
			var col := _bfood_col if _bfood_frame >= _frame - 3 else Color(0.9, 0.9, 0.85)
			var pos := _bfood_pos if _bfood_frame >= _frame - 3 else b.global_position + b.food_local
			_fx_chop(pos + Vector3(0, 0.8, 0), col)
			_fire(K.GLINT, b._knife.global_position + Vector3(1.6, 0.1, 0), 0.9)


func _track_soda(dt: float) -> void:
	var s := world.soda
	if s == null or _quiet:
		return
	var pt: float = s._pour_t
	var hold := s.hold_time()
	if pt <= 0.0 or pt >= hold:
		_pour_bub = 0.0
		return
	var f := pt / hold
	var cup_h := 3.0 * clampf(0.15 + f, 0.15, 1.0)
	var top: Vector3 = s.to_global(Vector3(0, 0.12 + cup_h, s.size.z * 0.5 + SodaFountain.OUT_Z))
	_pour_bub -= dt
	if _pour_bub <= 0.0:
		_pour_bub = 0.16
		_fire(K.BUBBLE, top + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3)), 0.8)
	_pour_foam -= dt
	if _pour_foam <= 0.0 and f > 0.4:
		_pour_foam = 0.3
		_fire(K.FOAM, top + Vector3(0, 0.1, 0), 0.9)


# ---------------------------------------------------------------- Net events (the same ones that play sounds)

func _on_event(text: String, sfx: String) -> void:
	if _off or _quiet:
		return
	match sfx:
		"serve":
			var pl := _recent_plate()
			if pl != null:
				var i := text.rfind("+")
				_fx_serve(pl.global_position + Vector3(0, _plate_top(pl), 0), text.substr(i + 1).to_int() if i >= 0 else 0)
		"ev_vip_paid":
			var pl := _recent_plate()
			if pl != null:
				var p := pl.global_position + Vector3(0, 1.4, 0)
				_fire(K.CONFETTI, p, 1.2, Color(UITheme.MUSTARD, 1.0), Vector3.UP)
				_fire(K.STAR, p, 1.8, Color(UITheme.MUSTARD, 1.0))
				_spawn_coins(p, 8)
		"buzz":
			if text.begins_with("That matches no order"):
				var pl := _recent_plate()
				if pl != null:
					_fx_wrong(pl.global_position + Vector3(0, _plate_top(pl) + 1.4, 0))
		"fail":
			if text.begins_with("Inspector:"):
				_fx_clipboard(text.get_slice("! ", 0).trim_prefix("Inspector: "))


## The plate that was non-empty most recently (the one the bell just served or rejected).
func _recent_plate() -> Plate:
	var best: Plate = null
	var bt := -1.0
	for i in world.plates.size():
		var pl: Plate = world.plates[i]
		var t := _now if not pl.stack.is_empty() else _plate_t[i]
		if t > bt:
			bt = t
			best = pl
	return best if best != null and _now - bt < 2.0 else null


# ================================================================ effect recipes (also called by the demo)

func _fx_ding(p: Vector3, radius: float) -> void:
	_auto("ding")
	_fire(K.STAR, p + Vector3(0, 0.3, 0), clampf(radius * 0.7, 0.8, 1.6))
	_fire(K.GLINT, p + Vector3(0, 0.5, 0), 1.3, Color(1, 1, 0.9, 1))
	_fire(K.PUFF, p, clampf(radius * 0.6, 0.7, 1.4), Color(1.0, 0.97, 0.88, 0.55))


func _fx_burn(p: Vector3, radius: float) -> void:
	_auto("burn")
	var s := clampf(radius * 0.6, 0.8, 1.5)
	_fire(K.SMOKE, p, s)
	_fire(K.SMOKE, p + Vector3(0.3, 0.2, 0.1), s * 0.8)
	_fire(K.EMBER, p + Vector3(0, 0.1, 0), 1.0)
	_fire(K.EMBER, p + Vector3(0.2, 0.1, -0.2), 0.8)


func _fx_splash(p: Vector3, radius: float) -> void:
	_auto("splash")
	_fire(K.DROP, p, clampf(radius * 0.7, 0.8, 1.4))
	_fire(K.DROP, p + Vector3(0.2, 0, 0.2), 0.8)
	_fire(K.PUFF, p, 0.8, Color(1.0, 0.9, 0.55, 0.45))


func _fx_chop(p: Vector3, col: Color) -> void:
	_auto("chop")
	_fire(K.CHIP, p, 1.0, col)


func _fx_slice(p: Vector3, col: Color) -> void:
	_auto("slice")
	_fire(K.CHIP, p, 1.5, col)
	_fire(K.CHIP, p + Vector3(0.2, 0.1, 0), 1.3, col.lightened(0.15))
	_fire(K.STAR, p + Vector3(0, 0.4, 0), 1.0, Color(1, 1, 0.9, 1))


func _fx_pop(p: Vector3, radius: float) -> void:
	_auto("pop")
	_fire(K.STAR, p, clampf(radius * 0.5, 0.6, 1.2), Color(1.0, 0.95, 0.7, 1.0))
	_fire(K.PUFF, p - Vector3(0, 0.2, 0), clampf(radius * 0.5, 0.6, 1.2), Color(UITheme.CREAM, 0.6))


func _fx_fizz(p: Vector3) -> void:
	_auto("fizz")
	_fire(K.BUBBLE, p, 1.2)
	_fire(K.FOAM, p + Vector3(0, 0.1, 0), 1.0)


func _fx_thud(p: Vector3, diameter: float) -> void:
	_auto("thud")
	_fire(K.THUD, p, diameter)


func _fx_punch(p: Vector3, fwd: Vector3) -> void:
	_auto("punch")
	_fire(K.STAR, p + fwd * 1.0, 1.6, Color(1.0, 0.95, 0.6, 1.0))
	_fx_lines(p + fwd * 0.4, fwd)
	_fire(K.PUFF, p + fwd * 0.8, 0.9, Color(1, 1, 1, 0.55))


## Speed lines streaking along dir (flat decal just above the counter plane of the hit).
func _fx_lines(p: Vector3, dir: Vector3) -> void:
	_line_next = (_line_next + 1) % LINES_POOL
	var mi := _lines[_line_next]
	_line_p0[_line_next] = p
	_line_dir[_line_next] = dir
	_line_t[_line_next] = 0.0
	mi.rotation = Vector3(0, atan2(-dir.z, dir.x), 0)
	mi.position = p
	mi.visible = true


func _fx_snap(p: Vector3) -> void:
	_auto("snap")
	_fire(K.STAR, p + Vector3(0, 0.3, 0), 0.9, Color(1.0, 0.96, 0.75, 1.0))
	_fire(K.GLINT, p + Vector3(0, 0.4, 0), 1.0)


func _fx_serve(p: Vector3, pay: int) -> void:
	_auto("serve")
	var top := p + Vector3(0, 0.8, 0)
	_fire(K.CONFETTI, top, 1.0, Color.WHITE, Vector3.UP)
	_fire(K.STAR, top, 1.6, Color(UITheme.MUSTARD, 1.0))
	_fire(K.PUFF, p, 1.5, Color(UITheme.CREAM, 0.6))
	_spawn_coins(top, clampi(pay / 12, 3, 9))
	if pay > 0:
		_show_label("+%d" % pay, p + Vector3(0, 2.4, 0))


func _fx_wrong(p: Vector3) -> void:
	_auto("wrong")
	_fire(K.XMARK, p, 1.0)
	_fire(K.PUFF, p - Vector3(0, 0.6, 0), 1.6, Color(0.85, 0.3, 0.22, 0.7))


func _fx_fall(p: Vector3) -> void:
	_auto("fall")
	_fire(K.PUFF, p, 2.2, Color(0.95, 0.9, 0.8, 0.8))
	_fire(K.STAR, p + Vector3(0, 0.6, 0), 1.0, Color(1.0, 0.95, 0.6, 1.0))


func _fx_respawn(p: Vector3) -> void:
	_auto("respawn")
	_fire(K.THUD, p + Vector3(0, 0.05, 0), 3.0)
	_fire(K.STAR, p + Vector3(0, 0.9, 0), 1.4, Color(1.0, 0.97, 0.8, 1.0))
	_fire(K.PUFF, p + Vector3(0, 0.2, 0), 1.6, Color(UITheme.CREAM, 0.7))


func _fx_clipboard(label: String) -> void:
	_auto("clip")
	var targets: Array[Vector3] = []
	for id in world.items:
		var it: Item = world.items[id]
		if not it.removed and it.kind.ends_with("_burnt") and it.label_text() == label:
			targets.append(it.global_position + Vector3(0, it.size.y + 1.6, 0))
	var p: Vector3
	if targets.is_empty():
		var me := world.my_chef()
		p = (me.global_position if me != null else Vector3.ZERO) + Vector3(0, 3.0, 0)
	else:
		p = targets[_clip_i % targets.size()]
		_clip_i += 1
	_fire(K.CLIP, p, 1.0)
	_fire(K.GLINT, p + Vector3(0.5, 0.5, 0), 1.0, Color(UITheme.TOMATO, 1.0))


func _fx_broom(pl: Plate) -> void:
	_auto("broom")
	_sweep_next = (_sweep_next + 1) % SWEEP_POOL
	var mi := _sweeps[_sweep_next]
	var d := pl.half.x * 2.2
	mi.scale = Vector3(d, 1.0, d)
	mi.position = pl.global_position + Vector3(0, 0.25, 0)
	mi.rotation = Vector3(0, -1.2, 0)
	mi.visible = true
	_sweep_t[_sweep_next] = 0.0


# ---------------------------------------------------------------- coins, labels, sweeps

func _spawn_coins(p: Vector3, n: int) -> void:
	var cam := world.camera
	if cam == null or not cam.is_inside_tree():
		return
	var depth := maxf(1.0, (p - cam.global_position).dot(-cam.global_transform.basis.z))
	var made := 0
	for c in _coins:
		if made >= n:
			break
		if c.t >= 0.0:
			continue
		made += 1
		c.t = 0.0
		c.delay = _rng.randf() * 0.22
		c.dur = 0.62 + _rng.randf() * 0.2
		c.start = p + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))
		c.lift = 2.5 + _rng.randf() * 2.0
		c.depth = depth
		c.spin = _rng.randf_range(10.0, 18.0)
		c.node.position = c.start
		c.node.visible = false


func _update_coins(dt: float) -> void:
	var cam := world.camera
	var vp := get_viewport().get_visible_rect().size
	for c in _coins:
		if c.t < 0.0:
			continue
		c.t += dt
		var k := (c.t - c.delay) / c.dur
		if k < 0.0:
			continue
		if k >= 1.0 or cam == null:
			c.t = -1.0
			c.node.visible = false
			continue
		var end := cam.project_position(Vector2(vp.x * _coin_screen.x, vp.y * _coin_screen.y), c.depth)
		# quadratic bezier: up and out first, then in towards the HUD coin chip
		var ctrl := c.start + Vector3(0, c.lift, 0) + (end - c.start) * 0.1
		var e := k * k * (3.0 - 2.0 * k) * 0.5 + k * 0.5
		var a := c.start.lerp(ctrl, e)
		var b := ctrl.lerp(end, e)
		c.node.position = a.lerp(b, e)
		c.node.rotation = Vector3(c.t * c.spin, c.t * c.spin * 0.6, 0)
		var s := 1.0 if k < 0.75 else lerpf(1.0, 0.25, (k - 0.75) / 0.25)
		c.node.scale = Vector3(s, s, s)
		c.node.visible = true


func _show_label(text: String, p: Vector3) -> void:
	_label_next = (_label_next + 1) % LABEL_POOL
	var l := _labels[_label_next]
	l.text = text
	_label_base[_label_next] = p
	_label_t[_label_next] = 0.0
	l.position = p
	l.visible = true


func _update_labels(dt: float) -> void:
	for i in LABEL_POOL:
		var t := _label_t[i]
		if t < 0.0:
			continue
		t += dt
		_label_t[i] = t
		var l := _labels[i]
		if t > 1.1:
			_label_t[i] = -1.0
			l.visible = false
			continue
		# stamp: starts big and slams down with an overshoot, holds, then drifts up and fades
		var s := 1.0
		if t < 0.1:
			s = lerpf(2.4, 0.9, t / 0.1)
		elif t < 0.2:
			s = lerpf(0.9, 1.0, (t - 0.1) / 0.1)
		var fade := 1.0 - smoothstep(0.75, 1.1, t)
		l.scale = Vector3(s, s, s)
		l.position = _label_base[i] + Vector3(0, maxf(0.0, t - 0.5) * 1.2, 0)
		l.modulate.a = fade
		l.outline_modulate.a = fade


func _update_lines(dt: float) -> void:
	for i in LINES_POOL:
		var t := _line_t[i]
		if t < 0.0:
			continue
		t += dt
		_line_t[i] = t
		var mi := _lines[i]
		if t > 0.28:
			_line_t[i] = -1.0
			mi.visible = false
			continue
		var k := t / 0.28
		mi.position = _line_p0[i] + _line_dir[i] * (k * 1.3)
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, sin(k * PI) * 0.95)


func _update_sweeps(dt: float) -> void:
	for i in SWEEP_POOL:
		var t := _sweep_t[i]
		if t < 0.0:
			continue
		t += dt
		_sweep_t[i] = t
		var mi := _sweeps[i]
		if t > 0.45:
			_sweep_t[i] = -1.0
			mi.visible = false
			continue
		var k := t / 0.45
		mi.rotation.y = lerpf(-1.2, 1.9, k)
		var m := mi.material_override as StandardMaterial3D
		m.albedo_color = Color(UITheme.CREAM, sin(k * PI) * 0.85)


# ================================================================ dev demo

func _run_demo(dt: float) -> void:
	var me := world.my_chef()
	if me == null or _age < 3.0:
		return
	_demo_since += dt
	if _demo_shots > 0 and _demo_n >= 2 and _demo_shots_done < _demo_shots and _demo_since >= DEMO_SHOT_AT[_demo_shots_done]:
		_demo_shots_done += 1
		var path := Net.arg_str("vfx-demo-shot", "").replace(".png", "-%d.png" % _demo_shots_done)
		var img := get_viewport().get_texture().get_image()
		print("vfx: demo shot %s %s" % [path, str(img.save_png(path))])
		if _demo_shots_done >= _demo_shots:
			get_tree().quit()
	_demo_t -= dt
	if _demo_t > 0.0:
		return
	_demo_t = 1.6
	_demo_n += 1
	_demo_since = 0.0
	var o := me.global_position
	o.y = 0.0
	var row := Net.arg_int("vfx-row", -1)   # -1: all three rows at once
	if row < 0 or row == 0:
		_demo_row0(o + Vector3(-7.8, 0, -4.0 if row < 0 else -1.5), Vector3(2.6, 0, 0))
	if row < 0 or row == 1:
		_demo_row1(o + Vector3(-7.8, 0, -1.0 if row < 0 else -1.5), Vector3(2.6, 0, 0))
	if row < 0 or row == 2:
		_demo_row2(o + Vector3(-7.8, 0, 2.0 if row < 0 else -1.5), Vector3(2.6, 0, 0))


func _demo_row0(r: Vector3, s: Vector3) -> void:
	var food := Color(0.9, 0.2, 0.15)
	var up := Vector3(0, 0.8, 0)
	_fire(K.STEAM, r + up, 1.2)
	_fx_ding(r + s + up, 1.5)
	_fx_burn(r + s * 2.0 + up, 1.5)
	_fx_splash(r + s * 3.0 + up, 1.5)
	_fx_chop(r + s * 4.0 + up, food)
	_fx_slice(r + s * 5.0 + up, food)
	_fire(K.GLINT, r + s * 6.0 + up, 1.0)


func _demo_row1(r: Vector3, s: Vector3) -> void:
	var up := Vector3(0, 0.8, 0)
	_fx_pop(r + up, 1.5)
	_fx_fizz(r + s + up)
	_fire(K.PUFF, r + s * 2.0 + Vector3(0, 0.1, 0), 0.9)
	_fire(K.PUFF, r + s * 2.0 + Vector3(-0.5, 0.1, 0), 1.5, Color(0.8, 0.7, 0.58, 0.75))
	_fire(K.SWEAT, r + s * 2.0 + Vector3(0.28, 1.4, 0))
	_fx_thud(r + s * 3.0 + Vector3(0, 0.05, 0), 2.4)
	_fx_punch(r + s * 4.0 + up, Vector3(1, 0, 0))
	_fire(K.TRAIL, r + s * 5.5 + up, 1.0)
	_fire(K.TRAIL, r + s * 5.5 + Vector3(-0.8, 0.8, 0), 1.0)


func _demo_row2(r: Vector3, s: Vector3) -> void:
	var up := Vector3(0, 0.8, 0)
	_fx_snap(r + up)
	_fx_serve(r + s * 1.5 + Vector3(0, 0.5, 0), 45)
	_fx_wrong(r + s * 3.5 + Vector3(0, 1.0, 0))
	_fx_fall(r + s * 4.5 + Vector3(0, 0.5, 0))
	_fx_respawn(r + s * 5.5)
	_fire(K.CLIP, r + s * 6.5 + Vector3(0, 2.0, 0), 1.0)
	if not world.plates.is_empty():
		_fx_broom(world.plates[0])
