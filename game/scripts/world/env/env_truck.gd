class_name EnvTruck
extends RefCounted
## Theme "truck": the inside of a food truck around a map's counter. A brushed-steel worktop with
## stainless cabinets under it down to a tread-plate floor a short drop below (falls still count:
## chefs land there and respawn, food is gone before it gets there); cream riveted steel walls close on
## the back and both ends; a long serving hatch in the back wall (aluminium frame, steel ledge outside,
## propped awning, ticket rail, an order sign over the plates) looking down onto a street (kerb,
## pavement slabs with drifting cloud shadows, a lamp post, an A-board, a bench, a bin, a bike,
## pigeons, shopfronts with awnings); a chalk menu board and swags of string lights on the back wall;
## a register shelf, certificate, poster, fan and clock on the right end; the rear doors with portholes,
## an extinguisher and a first-aid box on the left end. Cool daylight comes in through the hatch (the
## shadow-casting key light; walls cast no shadows), warm light from the bulbs and an LED strip under
## the toe kick (omni lights).
## Builds the floor and end-wall colliders (Kitchen builds the counter and back wall ones).
## Swinging props (string lights, order sign) are pivots in group SWING_GROUP: LurchHazard rocks them.
## Deterministic: fixed seeds only.

const FLOOR_Y := -8.0        # truck floor (top), a short drop below the counter
const WALL_Z := -8.5         # inner face of the back wall (Kitchen's wall collider is right behind it)
const WALL_T := 1.4          # wall thickness (hatch reveal depth)
const END_X := 36.0          # inner faces of the end walls
const ROOF_Y := 30.0
const FRONT_Z := 44.0        # where the cutaway floor ends (behind the camera)
const HATCH := Rect2(-17.0, 4.0, 50.0, 12.0)   # x, y of the serving hatch opening in the back wall
const SPLASH_TOP := 4.0      # tread-plate backsplash height
const STREET_Y := -36.0      # the street outside, well below the truck floor
const CURB_Z := -44.0
const FACADE_Z := -150.0
const SWING_GROUP := &"truck_swing"

## Direction the key (daylight) travels: in through the hatch from the back-left, high.
const SUN_DIR := Vector3(0.6, -0.72, 0.34)

const STAINLESS := Color(0.76, 0.77, 0.78)
const CREAM := Color(0.93, 0.89, 0.8)
const PAINT := Color(0.42, 0.7, 0.84)        # truck body (sky blue, like the lobby icon)
const STRIPE := Color(0.9, 0.33, 0.24)       # tomato accent
const ALU := Color(0.82, 0.84, 0.86)
const WARM := Color(1.0, 0.72, 0.42)


static func build(root: Node3D, map: Dictionary) -> void:
	var surfaces: Array = map["surfaces"]
	var b := GameData.surfaces_bounds(surfaces)
	look(root)
	for r: Rect2 in surfaces:
		counter(root, r)
	var shell_n := EnvUtil.node(root, "TruckShell")
	_floor(shell_n, b)
	_back_wall(shell_n)
	_end_walls(shell_n)
	_ceiling(shell_n)
	_no_shadows(shell_n)
	var dress := EnvUtil.node(root, "TruckDressing")
	_hatch(dress)
	_menu_and_lights(dress)
	_right_end(dress)
	_left_end(dress)
	_no_shadows(dress)
	street(root)
	_colliders(root)


# ================================================================ light

static func look(root: Node3D) -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(EnvUtil.SHADER_DIR + "picnic_sky.gdshader")
	sky_mat.set_shader_parameter("zenith", Color(0.38, 0.6, 0.9))
	sky_mat.set_shader_parameter("horizon", Color(0.78, 0.86, 0.94))
	sky_mat.set_shader_parameter("haze", Color(0.96, 0.9, 0.82))
	sky_mat.set_shader_parameter("ground", Color(0.5, 0.5, 0.52))
	sky_mat.set_shader_parameter("cloud_cover", 0.42)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(1.0, 0.86, 0.7)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.7
	env.ssao_power = 1.5
	env.ssao_detail = 0.7
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.95
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.8, 0.86, 0.93)
	env.fog_density = 0.3
	env.fog_depth_begin = 160.0
	env.fog_depth_end = 1400.0
	env.fog_depth_curve = 1.3
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.07
	env.adjustment_contrast = 1.04
	var off := EnvLook._debug_off()
	env.ssil_enabled = not off.has("ssil")
	env.ssao_enabled = not off.has("ssao")
	env.glow_enabled = not off.has("glow")
	env.fog_enabled = not off.has("fog")
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 70.0
	attr.dof_blur_far_transition = 60.0
	attr.dof_blur_amount = 0.035
	if not off.has("dof"):
		we.camera_attributes = attr
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "HatchDaylight"
	sun.transform = Transform3D(Basis.looking_at(SUN_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(0.9, 0.95, 1.0)
	sun.light_energy = 1.0
	sun.light_specular = 0.7
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.7
	sun.shadow_blur = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.3
	sun.directional_shadow_split_2 = 0.5
	sun.directional_shadow_split_3 = 0.72
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)

	# Warm fill from the cab side (the camera side): the bulbs' bounce off the cream walls.
	var fill := DirectionalLight3D.new()
	fill.name = "WarmFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.3, -0.55, -0.78).normalized(), Vector3.UP), Vector3.ZERO)
	fill.light_color = Color(1.0, 0.84, 0.64)
	fill.light_energy = 0.5
	fill.light_specular = 0.2
	fill.shadow_enabled = false
	root.add_child(fill)


# ================================================================ the counter

static func steel_top() -> ShaderMaterial:
	return EnvUtil.shader_mat("truck_steel", {"base_color": Color(0.66, 0.67, 0.68), "metal": 0.45, "rough": 0.42,
		"grain": 0.13, "panel": Vector2(24.0, 0.0), "rivet_step": 0.0, "smudge": 0.07})


static func steel_panel(grain_axis := 1.0, panel := Vector2.ZERO) -> ShaderMaterial:
	return EnvUtil.shader_mat("truck_steel", {"base_color": STAINLESS, "metal": 0.72, "rough": 0.33,
		"grain": 0.06, "grain_axis": grain_axis, "panel": panel, "rivet_step": 0.0, "smudge": 0.04})


## Worktop slab (rounded front edge) + apron + stainless cabinets down to the floor, toe kick.
static func counter(root: Node3D, r: Rect2) -> void:
	var n := EnvUtil.node(root, "TruckCounter")
	var top := steel_top()
	var er := 0.4
	var t := 0.9
	var x0 := r.position.x
	var x1 := r.end.x
	var zf := r.end.y
	var zb := WALL_Z
	EnvUtil.box_mm(n, Vector3(x0, -er, zb), Vector3(x1, 0.0, zf - er), top)
	EnvUtil.box_mm(n, Vector3(x0, -t, zb), Vector3(x1, -er, zf), top)
	EnvUtil.cyl(n, er, er, x1 - x0, Vector3((x0 + x1) * 0.5, -er, zf - er), top, "x", 20)
	# Apron band under the edge with a dark shadow line.
	var apron := steel_panel(0.0)
	EnvUtil.box_mm(n, Vector3(x0, -t - 1.3, zf - 0.35), Vector3(x1, -t, zf - 0.05), apron)
	EnvUtil.box_mm(n, Vector3(x0, -t - 1.42, zf - 0.6), Vector3(x1, -t - 1.3, zf - 0.3), EnvUtil.mat(Color(0.12, 0.12, 0.13), 0.7), false)
	# Cabinets: carcass set back, toe kick.
	var y_top := -t - 1.42
	var kick := FLOOR_Y + 1.4
	var cz := zf - 0.7
	EnvUtil.box_mm(n, Vector3(x0, kick, zb), Vector3(x1, y_top, cz), EnvUtil.mat(Color(0.5, 0.51, 0.52), 0.5, 0.6))
	EnvUtil.box_mm(n, Vector3(x0, FLOOR_Y, zb), Vector3(x1, kick, cz - 1.0), EnvUtil.mat(Color(0.09, 0.09, 0.1), 0.8))
	var face := EnvUtil.node(n, "Cabinets", Vector3(0, 0, cz))
	var bay := 8.0
	var count := int(floor((x1 - x0) / bay))
	var w := (x1 - x0) / count
	var door_mat := steel_panel(1.0)
	var drawer_mat := steel_panel(0.0)
	var handle := EnvUtil.mat(Color(0.86, 0.87, 0.88), 0.2, 0.95)
	var gasket := EnvUtil.mat(Color(0.08, 0.08, 0.09), 0.6)
	var h := y_top - kick
	for i in count:
		var cx := x0 + (i + 0.5) * w
		var kind: int = [0, 1, 2, 0, 3, 1, 2, 0, 1][i % 9]
		var ww := w - 0.35
		match kind:
			0:   # double doors, vertical bar handles in the middle
				for s in [-1.0, 1.0]:
					var dcx: float = cx + s * (ww * 0.25 + 0.06)
					EnvUtil.box(face, Vector3(ww * 0.5 - 0.12, h - 0.4, 0.3), Vector3(dcx, kick + h * 0.5, 0.15), door_mat)
					EnvUtil.cyl(face, 0.2, 0.2, 3.6, Vector3(cx + s * 0.75, kick + h * 0.62 - 1.8, 0.85), handle, "y", 10)
					for k in [-1.0, 1.0]:
						EnvUtil.cyl(face, 0.12, 0.12, 0.6, Vector3(cx + s * 0.75, kick + h * 0.62 + k * 1.5, 0.55), handle, "z", 8)
			1:   # two drawers, long horizontal handles
				var dh := (h - 0.6) * 0.5
				for k in 2:
					var cy := kick + 0.25 + dh * 0.5 + k * (dh + 0.1)
					EnvUtil.box(face, Vector3(ww, dh, 0.3), Vector3(cx, cy, 0.15), drawer_mat)
					EnvUtil.cyl(face, 0.2, 0.2, ww * 0.6, Vector3(cx, cy + dh * 0.3, 0.85), handle, "x", 10)
			2:   # fridge door: gasket outline, full-width handle, a little blue thermometer display
				EnvUtil.box(face, Vector3(ww, h - 0.3, 0.12), Vector3(cx, kick + h * 0.5, 0.06), gasket)
				EnvUtil.box(face, Vector3(ww - 0.3, h - 0.6, 0.4), Vector3(cx, kick + h * 0.5, 0.32), door_mat)
				EnvUtil.box(face, Vector3(ww - 1.6, 0.35, 0.5), Vector3(cx, kick + h - 1.0, 0.75), handle)
				EnvUtil.box(face, Vector3(1.6, 0.7, 0.1), Vector3(cx + ww * 0.3, kick + h - 2.2, 0.56), gasket, false)
				EnvUtil.box(face, Vector3(1.3, 0.45, 0.05), Vector3(cx + ww * 0.3, kick + h - 2.2, 0.62), EnvUtil.emissive(Color(0.35, 0.8, 1.0), 1.6), false)
			3:   # louvred vent panel (the generator compartment)
				EnvUtil.box(face, Vector3(ww, h - 0.4, 0.3), Vector3(cx, kick + h * 0.5, 0.15), drawer_mat)
				var slats := 9
				for k in slats:
					var sl := EnvUtil.box(face, Vector3(ww - 2.0, 0.25, 0.5), Vector3(cx, kick + 1.2 + k * (h - 2.4) / (slats - 1), 0.45), gasket, false)
					sl.rotation.x = -0.5
	# Contact shadow on the floor along the cabinets.
	var ao := EnvUtil.shader_mat("counter_decal", {"kind": 4, "opacity": 0.6})
	EnvUtil.plane(n, Vector2(x1 - x0 + 2.0, 8.0), Vector3((x0 + x1) * 0.5, FLOOR_Y + 0.06, zf + 0.4), ao)


# ================================================================ the shell

static func _wall_mat() -> ShaderMaterial:
	return EnvUtil.shader_mat("truck_steel", {"base_color": CREAM, "metal": 0.0, "rough": 0.55, "grain": 0.015,
		"grain_axis": 1.0, "panel": Vector2(12.0, 0.0), "rivet_step": 1.5, "smudge": 0.05})


static func _tread_mat(c := ALU, scale := 1.3) -> ShaderMaterial:
	return EnvUtil.shader_mat("truck_steel", {"kind": 1, "base_color": c, "metal": 0.55, "rough": 0.5, "tread_scale": scale, "smudge": 0.08})


static func _floor(n: Node3D, b: Rect2) -> void:
	EnvUtil.box_mm(n, Vector3(-END_X, FLOOR_Y - 0.6, WALL_Z), Vector3(END_X, FLOOR_Y, FRONT_Z), _tread_mat(Color(0.74, 0.76, 0.78), 1.6))
	# Rubber anti-fatigue mats along the cook's aisle, with nubs (tread pattern, matte), slightly askew.
	var mat := EnvUtil.shader_mat("truck_steel", {"kind": 1, "base_color": Color(0.2, 0.25, 0.27), "metal": 0.0, "rough": 0.85, "tread_scale": 0.9, "smudge": 0.1})
	var mats := [[-20.0, 26.0, 0.02], [10.0, 28.0, -0.03]]
	for m in mats:
		var mn := EnvUtil.node(n, "Mat", Vector3(m[0], FLOOR_Y, b.end.y + 8.0))
		mn.rotation.y = m[2]
		EnvUtil.box(mn, Vector3(m[1], 0.25, 11.0), Vector3(0, 0.125, 0), mat)
	# Warm LED strip under the counter's toe kick, lighting the floor of the aisle.
	EnvUtil.box_mm(n, Vector3(b.position.x + 0.5, FLOOR_Y + 1.2, b.end.y - 1.85), Vector3(b.end.x - 0.5, FLOOR_Y + 1.38, b.end.y - 1.6),
		EnvUtil.emissive(Color(1.0, 0.75, 0.45), 3.0))
	for lx in [-24.0, 0.0, 24.0]:
		var o := OmniLight3D.new()
		o.position = Vector3(lx, FLOOR_Y + 3.0, b.end.y + 3.0)
		o.light_color = WARM
		o.light_energy = 1.4
		o.omni_range = 24.0
		o.omni_attenuation = 1.6
		o.light_specular = 0.2
		n.add_child(o)
	# Cut edge of the floor (we look into the truck through its missing side wall).
	EnvUtil.box_mm(n, Vector3(-END_X - WALL_T, FLOOR_Y - 3.0, FRONT_Z - 0.01), Vector3(END_X + WALL_T, FLOOR_Y, FRONT_Z + 0.6), EnvUtil.mat(Color(0.22, 0.23, 0.25), 0.7))


## The back wall around the hatch: tread-plate splash behind the counter, cream riveted panels above,
## the truck's outside skin (blue with a tomato stripe) a wall-thickness behind.
static func _back_wall(n: Node3D) -> void:
	var wall := Rect2(-END_X, FLOOR_Y, END_X * 2.0, ROOF_Y - FLOOR_Y)
	var splash := Rect2(-END_X, -1.0, END_X * 2.0, SPLASH_TOP + 1.0)
	var paint := _wall_mat()
	var tread := _tread_mat(Color(0.78, 0.8, 0.82), 1.1)
	for rc in EnvUtil.rects_minus(EnvUtil.rect_minus(wall, splash), HATCH):
		_wall_quad(n, rc, paint, WALL_Z)
	for rc in EnvUtil.rect_minus(splash, HATCH):
		_wall_quad(n, rc, tread, WALL_Z + 0.02)
	# Capping strip on top of the splash (either side of the hatch sill).
	var cap := EnvUtil.mat(ALU, 0.4, 0.55)
	EnvUtil.box_mm(n, Vector3(-END_X, SPLASH_TOP - 0.1, WALL_Z), Vector3(HATCH.position.x, SPLASH_TOP + 0.45, WALL_Z + 0.4), cap)
	EnvUtil.box_mm(n, Vector3(HATCH.end.x, SPLASH_TOP - 0.1, WALL_Z), Vector3(END_X, SPLASH_TOP + 0.45, WALL_Z + 0.4), cap)
	# Outside skin, seen past the hatch reveal.
	var zo := WALL_Z - WALL_T
	var outside := Rect2(-END_X - 20.0, STREET_Y + 8.0, END_X * 2.0 + 40.0, ROOF_Y + 6.0 - STREET_Y - 8.0)
	var skin := EnvUtil.mat(PAINT, 0.45)
	for rc in EnvUtil.rect_minus(outside, HATCH):
		var q := EnvUtil.quad(n, rc.size, Vector3(rc.get_center().x, rc.get_center().y, zo), skin)
		q.rotation.y = PI
	var stripe := EnvUtil.mat(STRIPE, 0.45)
	for seg in [Vector2(-END_X - 20.0, HATCH.position.x), Vector2(HATCH.end.x, END_X + 20.0)]:
		EnvUtil.box_mm(n, Vector3(seg.x, 1.0, zo - 0.1), Vector3(seg.y, 3.4, zo), stripe)


static func _wall_quad(parent: Node3D, rc: Rect2, material: Material, z: float) -> void:
	EnvUtil.quad(parent, rc.size, Vector3(rc.get_center().x, rc.get_center().y, z), material)


static func _end_walls(n: Node3D) -> void:
	var paint := _wall_mat()
	var tread := _tread_mat(Color(0.78, 0.8, 0.82), 1.1)
	var depth := FRONT_Z - WALL_Z
	var kick := 3.0
	for sx in [-1.0, 1.0]:
		var x: float = sx * END_X
		# Painted panels everywhere but a tread kick plate at the floor and the splash behind the counter.
		var q := EnvUtil.quad(n, Vector2(depth, ROOF_Y - FLOOR_Y - kick), Vector3(x, (ROOF_Y + FLOOR_Y + kick) * 0.5, (FRONT_Z + WALL_Z) * 0.5), paint)
		q.rotation.y = -sx * PI * 0.5
		var lo := EnvUtil.quad(n, Vector2(depth, kick), Vector3(x + sx * -0.02, FLOOR_Y + kick * 0.5, (FRONT_Z + WALL_Z) * 0.5), tread)
		lo.rotation.y = -sx * PI * 0.5
		var sp := EnvUtil.quad(n, Vector2(8.0 - WALL_Z, SPLASH_TOP + 1.0), Vector3(x - sx * 0.03, (SPLASH_TOP - 1.0) * 0.5, (8.0 + WALL_Z) * 0.5), tread)
		sp.rotation.y = -sx * PI * 0.5
		# Cut edge of the wall at the open side.
		EnvUtil.box_mm(n, Vector3(minf(x, x + sx * WALL_T), FLOOR_Y - 3.0, FRONT_Z), Vector3(maxf(x, x + sx * WALL_T), ROOF_Y, FRONT_Z + 0.6),
			EnvUtil.mat(Color(0.22, 0.23, 0.25), 0.7))
	# Corner trim where the walls meet.
	var trim := EnvUtil.mat(ALU, 0.4, 0.55)
	for sx in [-1.0, 1.0]:
		EnvUtil.box_mm(n, Vector3(sx * END_X - 0.5, SPLASH_TOP, WALL_Z), Vector3(sx * END_X + 0.5, ROOF_Y, WALL_Z + 0.5), trim)


static func _ceiling(n: Node3D) -> void:
	var q := EnvUtil.plane(n, Vector2(END_X * 2.0, FRONT_Z - WALL_Z), Vector3(0, ROOF_Y, (FRONT_Z + WALL_Z) * 0.5), _wall_mat())
	q.rotation.x = PI
	# Roof vent hood and an LED batten.
	EnvUtil.box_mm(n, Vector3(-22.0, ROOF_Y - 2.0, WALL_Z), Vector3(-6.0, ROOF_Y, WALL_Z + 9.0), steel_panel(0.0))
	EnvUtil.box_mm(n, Vector3(-4.0, ROOF_Y - 0.6, 6.0), Vector3(30.0, ROOF_Y, 7.2), EnvUtil.emissive(Color(1.0, 0.95, 0.88), 1.2))


# ================================================================ the hatch

static func _hatch(n: Node3D) -> void:
	var h := HATCH
	var zi := WALL_Z
	var zo := WALL_Z - WALL_T
	var reveal := EnvUtil.mat(PAINT, 0.45)
	var alu := EnvUtil.mat(ALU, 0.4, 0.55)
	# Reveal (wall thickness) on the sides and head.
	EnvUtil.box_mm(n, Vector3(h.position.x - 0.3, h.position.y, zo), Vector3(h.position.x, h.end.y, zi), reveal)
	EnvUtil.box_mm(n, Vector3(h.end.x, h.position.y, zo), Vector3(h.end.x + 0.3, h.end.y, zi), reveal)
	EnvUtil.box_mm(n, Vector3(h.position.x - 0.3, h.end.y, zo), Vector3(h.end.x + 0.3, h.end.y + 0.3, zi), reveal)
	# Aluminium frame on the inside face.
	var f := 0.8
	EnvUtil.box_mm(n, Vector3(h.position.x - f, h.position.y, zi), Vector3(h.position.x, h.end.y + f, zi + 0.35), alu)
	EnvUtil.box_mm(n, Vector3(h.end.x, h.position.y, zi), Vector3(h.end.x + f, h.end.y + f, zi + 0.35), alu)
	EnvUtil.box_mm(n, Vector3(h.position.x, h.end.y, zi), Vector3(h.end.x, h.end.y + f, zi + 0.35), alu)
	# Sill: a steel shelf from inside the frame out to a ledge over the pavement, on brackets.
	var ledge := steel_top()
	var lz := zo - 1.6
	EnvUtil.box_mm(n, Vector3(h.position.x - 1.0, h.position.y - 0.45, lz), Vector3(h.end.x + 1.0, h.position.y, zi), ledge)
	EnvUtil.box_mm(n, Vector3(h.position.x - 1.0, h.position.y - 0.45, lz - 0.25), Vector3(h.end.x + 1.0, h.position.y + 0.35, lz), alu)
	var x := h.position.x + 3.0
	while x < h.end.x:
		var br := EnvUtil.box(n, Vector3(0.4, 0.4, 2.2), Vector3(x, h.position.y - 1.1, zo - 0.75), alu)
		br.rotation.x = -0.7
		x += 12.0
	# Sliding window pane parked at the left end (open), and its track.
	EnvUtil.box_mm(n, Vector3(h.position.x, h.end.y - 0.4, zi - 0.7), Vector3(h.end.x, h.end.y, zi - 0.4), alu)
	var pane := EnvUtil.node(n, "Pane", Vector3(h.position.x + 6.5, h.get_center().y, zi - 0.55))
	EnvUtil.box(pane, Vector3(12.0, h.size.y - 0.6, 0.12), Vector3.ZERO, EnvUtil.mat(Color(0.82, 0.92, 1.0, 0.16), 0.05, 0.2), false)
	for s in [-1.0, 1.0]:
		EnvUtil.box(pane, Vector3(0.5, h.size.y - 0.6, 0.3), Vector3(s * 5.75, 0, 0), alu)
		EnvUtil.box(pane, Vector3(12.0, 0.5, 0.3), Vector3(0, s * (h.size.y * 0.5 - 0.55), 0), alu)
	# Awning flap, hinged above the hatch on the outside and propped up and out on two struts.
	var aw := EnvUtil.node(n, "Awning", Vector3(h.get_center().x, h.end.y + 1.2, zo))
	aw.rotation.x = deg_to_rad(-62.0)   # flap points outwards (-Z) and up
	var aw_len := 15.0
	EnvUtil.box_mm(aw, Vector3(-h.size.x * 0.5 - 1.5, 0, -0.3), Vector3(h.size.x * 0.5 + 1.5, aw_len, 0.0), reveal)
	var stripe := EnvUtil.mat(STRIPE, 0.5)
	var cream := EnvUtil.mat(Color(0.98, 0.95, 0.88), 0.5)
	var k := 0
	var sx := -h.size.x * 0.5 - 1.5
	while sx < h.size.x * 0.5 + 1.5:
		EnvUtil.box_mm(aw, Vector3(sx, 0.4, 0.0), Vector3(minf(sx + 3.5, h.size.x * 0.5 + 1.5), aw_len, 0.06), stripe if k % 2 == 0 else cream)
		sx += 3.5
		k += 1
	for s in [-1.0, 1.0]:
		var top := Vector3(h.get_center().x + s * (h.size.x * 0.5 - 2.0), h.end.y + 1.2, zo) + Basis(Vector3.RIGHT, deg_to_rad(-62.0)) * Vector3(0, aw_len * 0.75, 0)
		_rod(n, Vector3(top.x, h.position.y + 1.0, zo - 0.3), top, 0.22, alu)
	# Ticket rail under the hatch head with a few order slips clipped on.
	var rail_y := h.end.y - 1.6
	EnvUtil.box_mm(n, Vector3(h.position.x + 2.0, rail_y - 0.25, zi + 0.35), Vector3(h.position.x + 26.0, rail_y + 0.25, zi + 0.85), alu)
	var paper := EnvUtil.mat(Color(0.98, 0.97, 0.92), 0.9)
	var ink := EnvUtil.mat(Color(0.25, 0.25, 0.3), 0.9)
	for i in 6:
		var tx := h.position.x + 4.0 + i * 3.9
		var slip := EnvUtil.node(n, "Ticket", Vector3(tx, rail_y, zi + 0.9))
		slip.rotation.z = (float(i % 3) - 1.0) * 0.06
		EnvUtil.box(slip, Vector3(2.6, 3.4, 0.05), Vector3(0, -1.6, 0), paper)
		for l in 3:
			EnvUtil.box(slip, Vector3(1.6 - l * 0.3, 0.12, 0.02), Vector3(-0.2, -0.9 - l * 0.6, 0.04), ink)
	# Order / pick-up sign hanging on two chains from the hatch head, over the plates.
	var pv := _swing_pivot(n, "OrderSign", Vector3(25.0, h.end.y - 0.1, zi + 1.0))
	for s in [-1.0, 1.0]:
		EnvUtil.box(pv, Vector3(0.12, 0.9, 0.12), Vector3(s * 2.3, -0.45, 0), alu)
	var sign := Models.load_model("truck_order_bell_sign")
	if sign != null:
		sign.position = Vector3(0, -4.4, 0)
		pv.add_child(sign)


# ================================================================ wall dressing

## Hanging thing that LurchHazard rocks: a pivot at the hanging point, the model below/around it.
static func _swing_pivot(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var p := EnvUtil.node(parent, name, at)
	p.add_to_group(SWING_GROUP)
	return p


static func _menu_and_lights(n: Node3D) -> void:
	var menu := Models.load_model("truck_menu_board")
	if menu != null:
		menu.position = Vector3(-27.0, 6.0, WALL_Z + 0.05)
		n.add_child(menu)
	# Swags of string lights: one over the menu board, two across the hatch at different heights.
	var strands := [[Vector3(-21.0, 15.6, WALL_Z + 0.5), "LightsMenu"], [Vector3(-2.0, 14.6, WALL_Z + 0.9), "LightsHatchA"],
		[Vector3(18.0, 13.4, WALL_Z + 1.3), "LightsHatchB"]]
	for s in strands:
		var at: Vector3 = s[0]
		var pv := _swing_pivot(n, str(s[1]), at + Vector3(0, 1.2, 0))
		var sl := Models.load_model("truck_string_lights")
		if sl == null:
			sl = EnvUtil.node(pv, "Fallback")
			for i in 13:
				EnvUtil.sphere(sl, 0.3, Vector3(-13.2 + i * 2.2, 0.4, 0), EnvUtil.emissive(WARM, 4.0), Vector3.ONE, false, 8)
		else:
			pv.add_child(sl)
		sl.position = Vector3(0, -1.2, 0)
		for lx in [-8.0, 8.0]:
			var o := OmniLight3D.new()
			o.position = at + Vector3(lx, 0.0, 2.0)
			o.light_color = WARM
			o.light_energy = 2.4
			o.omni_range = 32.0
			o.omni_attenuation = 1.4
			o.shadow_enabled = false
			o.light_specular = 0.4
			n.add_child(o)


## Right end wall: a shelf with the cash register, the order sign on an arm, a clock.
static func _right_end(n: Node3D) -> void:
	var x := END_X
	var alu := EnvUtil.mat(ALU, 0.4, 0.55)
	var shelf_y := 7.6
	EnvUtil.box_mm(n, Vector3(x - 6.0, shelf_y - 0.4, -8.2), Vector3(x, shelf_y, -1.4), steel_top())
	for z in [-7.0, -2.6]:
		var br := EnvUtil.box(n, Vector3(0.4, 0.4, 5.0), Vector3(x - 2.4, shelf_y - 2.0, z), alu)
		br.rotation.y = PI * 0.5
		br.rotation.z = -0.6
	var reg := Models.load_model("truck_cash_register")
	if reg != null:
		reg.position = Vector3(x - 3.0, shelf_y, -4.8)
		reg.rotation.y = -PI * 0.5
		reg.scale = Vector3.ONE * 0.85
		n.add_child(reg)
	# Over the soda: a framed hygiene certificate, a fries poster and a little wall fan.
	var wall := EnvUtil.node(n, "RightWall", Vector3(x, 0, 0))
	wall.rotation.y = -PI * 0.5   # local +Z = world -X (into the truck), local +X = world +Z
	var frame := EnvUtil.mat(Color(0.3, 0.2, 0.12), 0.6)
	var paper := EnvUtil.mat(Color(0.97, 0.95, 0.88), 0.9)
	var gold := EnvUtil.mat(Color(0.9, 0.7, 0.25), 0.4, 0.5)
	var ink := EnvUtil.mat(Color(0.3, 0.3, 0.34), 0.9)
	var cert := Vector3(6.0, 16.0, 0.15)
	EnvUtil.box(wall, Vector3(4.4, 5.6, 0.3), cert, frame)
	EnvUtil.box(wall, Vector3(3.6, 4.8, 0.1), cert + Vector3(0, 0, 0.18), paper, false)
	EnvUtil.cyl(wall, 0.6, 0.6, 0.1, cert + Vector3(0.9, -1.4, 0.26), gold, "z", 16, false)
	for l in 4:
		EnvUtil.box(wall, Vector3(2.6 - (l % 2) * 0.8, 0.14, 0.05), cert + Vector3(-0.2, 1.6 - l * 0.6, 0.25), ink, false)
	var poster := Vector3(1.6, 12.0, 0.1)
	EnvUtil.box(wall, Vector3(5.2, 7.0, 0.1), poster, EnvUtil.mat(Color(0.98, 0.82, 0.3), 0.8), false)
	EnvUtil.box(wall, Vector3(3.0, 2.6, 0.1), poster + Vector3(0, -0.8, 0.08), EnvUtil.mat(Color(0.86, 0.25, 0.2), 0.7), false)
	for i in 6:
		var fry := EnvUtil.box(wall, Vector3(0.35, 2.4, 0.08), poster + Vector3(-1.1 + i * 0.44, 1.0 + (i % 2) * 0.3, 0.12), EnvUtil.mat(Color(1.0, 0.92, 0.55), 0.7), false)
		fry.rotation.z = (i - 2.5) * 0.07
	EnvUtil.box(wall, Vector3(4.0, 0.5, 0.06), poster + Vector3(0, 2.8, 0.12), EnvUtil.mat(Color(0.86, 0.25, 0.2), 0.7), false)
	var fan := EnvUtil.node(wall, "Fan", Vector3(5.0, 24.0, 1.6))
	var cage := EnvUtil.mat(Color(0.85, 0.86, 0.87), 0.35, 0.6)
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.25
	torus.rings = 32
	torus.ring_segments = 6
	var ring := EnvUtil.mesh(fan, torus, cage, Vector3.ZERO)
	ring.rotation.x = PI * 0.5
	for i in 4:
		var bar := EnvUtil.box(fan, Vector3(4.2, 0.12, 0.12), Vector3(0, 0, 0.3), cage, false)
		bar.rotation.z = i * PI * 0.25
	for i in 3:
		var blade := EnvUtil.sphere(fan, 1.0, Vector3(cos(i * TAU / 3.0) * 1.0, sin(i * TAU / 3.0) * 1.0, 0), EnvUtil.mat(Color(0.45, 0.7, 0.85), 0.4), Vector3(1.1, 0.5, 0.1), false, 10)
		blade.rotation.z = i * TAU / 3.0
	EnvUtil.cyl(fan, 0.5, 0.5, 1.6, Vector3(0, 0, -0.8), cage, "z", 12)
	EnvUtil.box(fan, Vector3(1.0, 3.0, 0.6), Vector3(0, -2.6, -1.3), cage)
	# Clock over the shelf.
	var clock := EnvUtil.node(n, "Clock", Vector3(x, 20.0, -4.0))
	clock.rotation.y = -PI * 0.5
	EnvRoom._clock(clock, Vector3.ZERO)


## Left end wall (the rear doors side): porthole window, extinguisher, first-aid box, paper towel roll.
static func _left_end(n: Node3D) -> void:
	var x := -END_X
	var face := EnvUtil.node(n, "LeftEnd", Vector3(x, 0, 0))
	face.rotation.y = PI * 0.5   # local +Z = world +X (into the truck), local +X = world -Z
	var alu := EnvUtil.mat(ALU, 0.4, 0.55)
	# Rear doors outline (the wall is the inside of the two rear doors), with a porthole in each.
	var seam := EnvUtil.mat(Color(0.35, 0.34, 0.32), 0.6)
	EnvUtil.box(face, Vector3(0.25, ROOF_Y - 2.0 - SPLASH_TOP, 0.1), Vector3(-1.0, (ROOF_Y - 2.0 + SPLASH_TOP) * 0.5, 0.05), seam, false)
	for lz in [-8.0, 6.0]:
		var c := Vector3(lz, 18.5, 0.0)
		EnvUtil.cyl(face, 3.3, 3.3, 0.5, c + Vector3(0, 0, 0.25), alu, "z", 32)
		EnvUtil.cyl(face, 2.7, 2.7, 0.2, c + Vector3(0, 0, 0.55), EnvUtil.emissive(Color(0.75, 0.88, 1.0), 1.4), "z", 32, false)
	# Door handle bar.
	EnvUtil.box(face, Vector3(0.5, 7.0, 0.5), Vector3(0.0, 12.0, 0.7), alu)
	# Extinguisher on a bracket, above the eggs.
	var red := EnvUtil.mat(Color(0.82, 0.12, 0.1), 0.35)
	var black := EnvUtil.mat(Color(0.1, 0.1, 0.1), 0.6)
	var ex := Vector3(7.0, 7.2, 1.6)
	EnvUtil.cyl(face, 1.1, 1.1, 5.2, ex, red, "y", 18)
	EnvUtil.sphere(face, 1.1, ex + Vector3(0, 5.2, 0), red, Vector3(1, 0.5, 1), true, 16)
	EnvUtil.cyl(face, 0.35, 0.35, 0.9, ex + Vector3(0, 5.6, 0), black, "y", 10)
	EnvUtil.box(face, Vector3(1.6, 0.3, 0.4), ex + Vector3(0.4, 6.6, 0), black)
	var hose := EnvUtil.cyl(face, 0.18, 0.18, 4.0, ex + Vector3(1.2, 4.0, 0.3), black, "y", 8)
	hose.rotation.z = -0.15
	EnvUtil.box(face, Vector3(2.6, 0.5, 1.4), ex + Vector3(0, 1.5, -0.7), alu)
	# First-aid box (white, green cross), high over the eggs.
	var fa := Vector3(2.5, 12.5, 0.6)
	EnvUtil.box(face, Vector3(3.6, 2.8, 1.2), fa, EnvUtil.mat(Color(0.96, 0.95, 0.92), 0.5))
	EnvUtil.box(face, Vector3(3.7, 0.3, 1.25), fa + Vector3(0, 0.6, 0), EnvUtil.mat(Color(0.75, 0.76, 0.76), 0.5))
	var green := EnvUtil.mat(Color(0.15, 0.6, 0.35), 0.5)
	EnvUtil.box(face, Vector3(1.5, 0.45, 0.1), fa + Vector3(0, -0.25, 0.62), green, false)
	EnvUtil.box(face, Vector3(0.45, 1.5, 0.1), fa + Vector3(0, -0.25, 0.62), green, false)


# ================================================================ the street

## Everything outside the hatch, on the street far below: road with a kerb, pavement slabs, a lamp
## post, an A-board, a hydrant, a planter, pigeons, and a row of shopfronts across the pavement.
static func street(root: Node3D) -> void:
	var n := EnvUtil.node(root, "Street")
	var road := EnvUtil.shader_mat("truck_street", {"kind": 0, "curb_z": CURB_Z})
	var pave := EnvUtil.shader_mat("truck_street", {"kind": 1, "curb_z": CURB_Z, "concrete": Color(0.66, 0.63, 0.58)})
	EnvUtil.plane(n, Vector2(1600, 700), Vector3(0, STREET_Y, CURB_Z + 350.0), road)
	EnvUtil.box_mm(n, Vector3(-800, STREET_Y, FACADE_Z), Vector3(800, STREET_Y + 4.5, CURB_Z), pave)
	EnvUtil.box_mm(n, Vector3(-800, STREET_Y, CURB_Z - 0.01), Vector3(800, STREET_Y + 4.5, CURB_Z + 4.0), EnvUtil.mat(Color(0.66, 0.65, 0.62), 0.85))
	var ground := STREET_Y + 4.5
	_lamp(n, Vector3(-8.0, ground, -62.0))
	_aboard(n, Vector3(30.0, ground, -78.0))
	_hydrant(n, Vector3(-58.0, ground, -54.0))
	_planter(n, Vector3(70.0, ground, -112.0))
	_bench(n, Vector3(-46.0, ground, -118.0))
	_bin(n, Vector3(-30.0, ground, -56.0))
	_bike(n, Vector3(58.0, ground, -98.0))
	_pigeons(n, ground)
	_shops(n)
	_no_shadows(n)


static func _lamp(n: Node3D, at: Vector3) -> void:
	var green := EnvUtil.mat(Color(0.16, 0.27, 0.24), 0.45, 0.5)
	EnvUtil.cyl(n, 3.6, 4.4, 10.0, at, green, "y", 16)
	EnvUtil.cyl(n, 1.7, 2.2, 190.0, at, green, "y", 14)
	EnvUtil.sphere(n, 3.0, at + Vector3(0, 190.0, 0), green, Vector3.ONE, true, 12)
	var arm := EnvUtil.box(n, Vector3(1.4, 1.4, 28.0), at + Vector3(0, 186.0, 13.0), green)
	arm.rotation.x = 0.06
	var lamp := EnvUtil.node(n, "Lantern", at + Vector3(0, 176.0, 26.0))
	EnvUtil.cyl(lamp, 4.5, 2.6, 9.0, Vector3.ZERO, EnvUtil.mat(Color(0.98, 0.94, 0.8, 0.55), 0.2), "y", 12)
	EnvUtil.cyl(lamp, 1.0, 5.6, 3.0, Vector3(0, 9.0, 0), green, "y", 12)


## Chalk A-board for the truck, standing on the pavement.
static func _aboard(n: Node3D, at: Vector3) -> void:
	var a := EnvUtil.node(n, "ABoard", at)
	a.rotation.y = -0.25
	var wood := EnvUtil.mat(Color(0.55, 0.36, 0.2), 0.7)
	var slate := EnvUtil.mat(Color(0.14, 0.17, 0.16), 0.9)
	var chalk := EnvUtil.mat(Color(0.95, 0.93, 0.86), 0.9)
	var col := [EnvUtil.mat(Color(1.0, 0.82, 0.3), 0.9), EnvUtil.mat(Color(0.95, 0.45, 0.4), 0.9), chalk, EnvUtil.mat(Color(0.5, 0.85, 0.75), 0.9)]
	for s in [-1.0, 1.0]:
		var leaf := EnvUtil.node(a, "Leaf", Vector3(0, 0, 0))
		leaf.rotation.x = s * 0.2
		EnvUtil.box(leaf, Vector3(22.0, 32.0, 1.2), Vector3(0, 16.0, s * 1.0), wood)
		EnvUtil.box(leaf, Vector3(18.5, 27.0, 0.3), Vector3(0, 16.5, s * 1.7), slate)
		if s > 0.0:
			for l in 6:
				var w := 13.0 - (l % 3) * 2.5
				EnvUtil.box(leaf, Vector3(w, 1.2, 0.2), Vector3(-1.0, 27.0 - l * 3.6, 1.9), col[l % col.size()])


static func _hydrant(n: Node3D, at: Vector3) -> void:
	var red := EnvUtil.mat(Color(0.85, 0.2, 0.15), 0.4, 0.3)
	EnvUtil.cyl(n, 6.0, 6.5, 2.0, at, red, "y", 16)
	EnvUtil.cyl(n, 4.2, 4.6, 16.0, at + Vector3(0, 2.0, 0), red, "y", 16)
	EnvUtil.sphere(n, 4.4, at + Vector3(0, 18.0, 0), red, Vector3(1, 0.7, 1), true, 14)
	EnvUtil.cyl(n, 1.4, 1.4, 12.0, at + Vector3(0, 12.0, 0), red, "x", 10)
	EnvUtil.cyl(n, 2.0, 2.0, 3.0, at + Vector3(0, 12.0, 5.2), EnvUtil.mat(Color(0.75, 0.7, 0.6), 0.4, 0.8), "z", 10)


static func _planter(n: Node3D, at: Vector3) -> void:
	var wood := EnvUtil.mat(Color(0.48, 0.33, 0.22), 0.8)
	EnvUtil.box(n, Vector3(70.0, 22.0, 26.0), at + Vector3(0, 11.0, 0), wood)
	EnvUtil.box(n, Vector3(66.0, 1.0, 22.0), at + Vector3(0, 21.6, 0), EnvUtil.mat(Color(0.25, 0.18, 0.12), 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var leaf := [EnvUtil.mat(Color(0.3, 0.52, 0.24), 0.8), EnvUtil.mat(Color(0.36, 0.58, 0.28), 0.8)]
	var bloom := [EnvUtil.mat(Color(0.95, 0.4, 0.45), 0.6), EnvUtil.mat(Color(1.0, 0.8, 0.25), 0.6), EnvUtil.mat(Color(0.95, 0.95, 0.9), 0.6)]
	for i in 16:
		var p := at + Vector3(rng.randf_range(-30, 30), 22.0 + rng.randf_range(0, 6), rng.randf_range(-9, 9))
		EnvUtil.sphere(n, rng.randf_range(5.0, 8.0), p, leaf[i % 2], Vector3(1, 0.8, 1), true, 10)
	for i in 14:
		var p := at + Vector3(rng.randf_range(-30, 30), 30.0 + rng.randf_range(0, 5), rng.randf_range(-9, 9))
		EnvUtil.sphere(n, rng.randf_range(2.0, 3.0), p, bloom[i % 3], Vector3.ONE, true, 8)


## Park bench against the shopfronts, facing the truck.
static func _bench(n: Node3D, at: Vector3) -> void:
	var b := EnvUtil.node(n, "Bench", at)
	var wood := [EnvUtil.mat(Color(0.62, 0.4, 0.22), 0.7), EnvUtil.mat(Color(0.56, 0.35, 0.19), 0.7)]
	var iron := EnvUtil.mat(Color(0.12, 0.13, 0.13), 0.5, 0.4)
	for i in 4:
		EnvUtil.box(b, Vector3(52.0, 1.6, 3.4), Vector3(0, 14.0, -5.0 + i * 3.8), wood[i % 2])
	for i in 3:
		var sl := EnvUtil.box(b, Vector3(52.0, 3.4, 1.6), Vector3(0, 20.0 + i * 4.2, -8.6 - i * 0.6), wood[i % 2])
		sl.rotation.x = -0.18
	for sx in [-22.0, 22.0]:
		EnvUtil.box(b, Vector3(1.6, 14.0, 2.0), Vector3(sx, 7.0, 6.0), iron)
		EnvUtil.box(b, Vector3(1.6, 30.0, 2.0), Vector3(sx, 15.0, -8.0), iron)
		EnvUtil.box(b, Vector3(1.6, 1.6, 16.0), Vector3(sx, 13.0, -1.0), iron)


static func _bin(n: Node3D, at: Vector3) -> void:
	var green := EnvUtil.mat(Color(0.2, 0.38, 0.3), 0.5, 0.3)
	EnvUtil.cyl(n, 9.0, 8.0, 28.0, at, green, "y", 20)
	EnvUtil.cyl(n, 9.6, 9.6, 2.0, at + Vector3(0, 28.0, 0), green, "y", 20)
	EnvUtil.cyl(n, 5.0, 5.0, 0.4, at + Vector3(0, 30.0, 0), EnvUtil.mat(Color(0.08, 0.08, 0.08), 0.8), "y", 16)
	for i in 6:
		var a := i * TAU / 6.0
		EnvUtil.box(n, Vector3(1.2, 24.0, 0.6), at + Vector3(cos(a) * 8.6, 13.0, sin(a) * 8.6), EnvUtil.mat(Color(0.17, 0.32, 0.25), 0.5, 0.3))


## A bicycle leaning on a stand, side-on to the truck.
static func _bike(n: Node3D, at: Vector3) -> void:
	var b := EnvUtil.node(n, "Bike", at)
	b.rotation.y = 0.12
	var tyre := EnvUtil.mat(Color(0.1, 0.1, 0.1), 0.8)
	var frame := EnvUtil.mat(Color(0.95, 0.55, 0.2), 0.35, 0.3)
	var chrome := EnvUtil.mat(Color(0.8, 0.82, 0.84), 0.25, 0.8)
	var r := 11.0
	for wx in [-17.0, 17.0]:
		var t := TorusMesh.new()
		t.inner_radius = r - 1.2
		t.outer_radius = r
		t.rings = 32
		t.ring_segments = 8
		var w := EnvUtil.mesh(b, t, tyre, Vector3(wx, r, 0))
		w.rotation.x = PI * 0.5
		EnvUtil.cyl(b, 0.6, 0.6, 1.2, Vector3(wx, r, 0), chrome, "z", 10)
	var hub_l := Vector3(-17.0, r, 0)
	var hub_r := Vector3(17.0, r, 0)
	var seat := Vector3(-6.0, r + 15.0, 0)
	var head := Vector3(12.0, r + 15.0, 0)
	var crank := Vector3(-2.0, r, 0)
	for pair in [[hub_l, seat], [hub_l, crank], [crank, seat], [seat, head], [crank, head], [head, hub_r]]:
		_rod(b, pair[0], pair[1], 0.7, frame)
	EnvUtil.box(b, Vector3(6.0, 1.4, 2.4), seat + Vector3(-0.5, 1.8, 0), tyre)
	_rod(b, head, head + Vector3(-1.5, 5.0, 0), 0.6, chrome)
	_rod(b, head + Vector3(-1.5, 5.0, -6.0), head + Vector3(-1.5, 5.0, 6.0), 0.5, chrome)
	EnvUtil.cyl(b, 2.4, 2.4, 0.6, crank, chrome, "z", 14)


static func _pigeons(n: Node3D, ground: float) -> void:
	var grey := EnvUtil.mat(Color(0.55, 0.57, 0.62), 0.8)
	var dark := EnvUtil.mat(Color(0.3, 0.32, 0.38), 0.8)
	var neck := EnvUtil.mat(Color(0.35, 0.5, 0.45), 0.5, 0.3)
	var beak := EnvUtil.mat(Color(0.85, 0.7, 0.5), 0.6)
	var spots := [[Vector3(4.0, 0, -58.0), 0.6], [Vector3(14.0, 0, -66.0), 2.4], [Vector3(-22.0, 0, -88.0), -1.1]]
	for s in spots:
		var p := EnvUtil.node(n, "Pigeon", Vector3(s[0].x, ground, s[0].z))
		p.rotation.y = s[1]
		EnvUtil.sphere(p, 4.0, Vector3(0, 4.5, 0), grey, Vector3(1.0, 0.8, 1.6), true, 12)
		EnvUtil.sphere(p, 2.8, Vector3(0, 5.6, -1.5), dark, Vector3(1.05, 0.6, 1.5), true, 10)
		EnvUtil.sphere(p, 2.0, Vector3(0, 7.6, 4.4), neck, Vector3.ONE, true, 10)
		EnvUtil.sphere(p, 1.7, Vector3(0, 9.4, 5.4), grey, Vector3.ONE, true, 10)
		EnvUtil.cyl(p, 0.2, 0.55, 1.4, Vector3(0, 9.2, 7.2), beak, "z", 6)
		EnvUtil.box(p, Vector3(2.4, 0.8, 4.0), Vector3(0, 4.6, -6.6), dark)
		for side in [-1.0, 1.0]:
			EnvUtil.cyl(p, 0.3, 0.3, 2.0, Vector3(side * 1.0, 0, 0.6), EnvUtil.mat(Color(0.85, 0.45, 0.45), 0.6), "y", 6)


## Row of shopfronts across the pavement: box bodies with a facade shader front, cornices, awnings.
static func _shops(n: Node3D) -> void:
	var specs := [
		# width, storeys, kind, wall, sign, awning
		[230.0, 3, 0, Color(0.68, 0.36, 0.28), Color(0.16, 0.34, 0.38), Color(0.2, 0.45, 0.5)],
		[190.0, 4, 1, Color(0.93, 0.84, 0.66), Color(0.55, 0.2, 0.18), Color(0.85, 0.3, 0.25)],
		[210.0, 3, 1, Color(0.62, 0.78, 0.74), Color(0.2, 0.22, 0.26), Color(0.95, 0.75, 0.3)],
		[240.0, 4, 0, Color(0.58, 0.3, 0.24), Color(0.12, 0.22, 0.4), Color(0.25, 0.4, 0.7)],
		[200.0, 3, 1, Color(0.95, 0.9, 0.8), Color(0.3, 0.45, 0.25), Color(0.4, 0.62, 0.32)],
		[220.0, 4, 0, Color(0.74, 0.44, 0.32), Color(0.45, 0.18, 0.4), Color(0.75, 0.35, 0.6)],
	]
	var total := 0.0
	for s in specs:
		total += float(s[0]) + 6.0
	var x := -total * 0.5 + 40.0
	var y0 := STREET_Y + 4.5
	var ground_h := 130.0
	var floor_h := 100.0
	for i in specs.size():
		var s: Array = specs[i]
		var w: float = s[0]
		var height: float = ground_h + floor_h * int(s[1]) + 20.0
		var body := EnvUtil.mat((s[3] as Color).darkened(0.25), 0.9)
		EnvUtil.box_mm(n, Vector3(x, y0, FACADE_Z - 160.0), Vector3(x + w, y0 + height, FACADE_Z - 0.2), body)
		var fm := EnvUtil.shader_mat("truck_facade", {"kind": s[2], "wall": s[3], "sign_col": s[4], "x0": x, "y0": y0,
			"width": w, "ground_h": ground_h, "floor_h": floor_h, "bay_w": 48.0 if w < 215.0 else 52.0, "seed": float(i) * 1.37})
		EnvUtil.quad(n, Vector2(w, height), Vector3(x + w * 0.5, y0 + height * 0.5, FACADE_Z), fm)
		# Cornice + parapet.
		var trim := EnvUtil.mat(Color(0.93, 0.9, 0.84), 0.7)
		EnvUtil.box_mm(n, Vector3(x - 2.0, y0 + height - 14.0, FACADE_Z), Vector3(x + w + 2.0, y0 + height - 6.0, FACADE_Z + 8.0), trim)
		EnvUtil.box_mm(n, Vector3(x - 2.0, y0 + ground_h - 2.0, FACADE_Z), Vector3(x + w + 2.0, y0 + ground_h + 4.0, FACADE_Z + 5.0), trim)
		# Striped awning over the shop window, sloping out over the pavement.
		var aw := EnvUtil.node(n, "ShopAwning", Vector3(x + w * 0.5, y0 + ground_h - 30.0, FACADE_Z))
		aw.rotation.x = deg_to_rad(28.0)
		var cream := EnvUtil.mat(Color(0.97, 0.95, 0.9), 0.7)
		var colm := EnvUtil.mat(s[5], 0.7)
		var stripes := 9
		var sw := (w - 16.0) / stripes
		for k in stripes:
			var sx := -w * 0.5 + 8.0 + k * sw
			EnvUtil.box_mm(aw, Vector3(sx, -1.0, 0.0), Vector3(sx + sw, 0.0, 44.0), colm if k % 2 == 0 else cream)
			# Scalloped valance.
			EnvUtil.box_mm(aw, Vector3(sx, -7.0, 43.0), Vector3(sx + sw, 0.0, 44.0), colm if k % 2 == 0 else cream)
		x += w + 6.0


# ================================================================ colliders + helpers

## Floor (chefs who fall land here and wait to respawn) and the two end walls.
static func _colliders(root: Node3D) -> void:
	var depth := FRONT_Z - WALL_Z
	_solid(root, Vector3(END_X * 2.0 + 4.0, 2.0, depth), Vector3(0, FLOOR_Y - 2.0, (FRONT_Z + WALL_Z) * 0.5))
	for sx in [-1.0, 1.0]:
		_solid(root, Vector3(2.0, ROOF_Y - FLOOR_Y + 2.0, depth + 2.0), Vector3(sx * (END_X + 1.0), FLOOR_Y - 2.0, (FRONT_Z + WALL_Z) * 0.5 - 1.0))


## Cylinder from a to b.
static func _rod(n: Node3D, a: Vector3, b: Vector3, r: float, material: Material) -> MeshInstance3D:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var mi := EnvUtil.cyl(n, r, r, d.length(), Vector3.ZERO, material, "y", 8)
	mi.transform = Transform3D(Basis(x, y, z), (a + b) * 0.5)
	return mi


static func _solid(root: Node3D, sz: Vector3, base: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Tuning.LAYER_WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	cs.shape = bs
	cs.position = base + Vector3(0, sz.y * 0.5, 0)
	sb.add_child(cs)
	root.add_child(sb)


static func _no_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadows(c)
