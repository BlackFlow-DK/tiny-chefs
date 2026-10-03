extends Node3D
## Dev preview of chef.glb (rig v2) / boxing_glove.glb. Env vars:
##   CHEF_VIEW  = front | back | side | three | top | game | glove (default three)
##   CHEF_TINTS = indices into the player colours, e.g. "0123" (default all four; close views use the first)
##   CHEF_GLOVE = 1 shows the boxing gloves on the hands
##   CHEF_HAT   = hat id (GameData.HATS), CHEF_ACC = accessory id, CHEF_BEARD / CHEF_BACK / CHEF_OUTFIT / CHEF_BODY
##                = the other look ids (Chef.dress; defaults = the default look)
##   CHEF_CLOSE = 1 frames the head (use with front / back / three / side)
##   CHEF_DUMP  = 1 prints the node tree of chef.glb and boxing_glove.glb
##   CHEF_ANIM  = an animation filmstrip: CHEF_FRAMES (default 6) copies side by side, each posed by ChefAnim
##                at a later time of the same scripted run (idle, walk, carry_solo, carry_duo, chop, dispense,
##                soda, bell, punch, toss, fall, celebrate, fail, ping, strain);
##              = shapes: every GameData.BODY_SHAPES entry side by side (with the look env vars);
##              = cycle: every body shape, live, cycling through all animations (label shows which).
##   CHEF_YAW   = degrees the filmstrip chefs turn (default 35)
##   CHEF_COMPARE = 1: old (v1) vs new rig: filmstrips get a second row behind with the frozen v1 animator +
##                chef_v1.glb (assets/models/dev); static views show v1 (left) and new (right) side by side.
##                Use CHEF_VIEW=game for the real game camera (Tuning distance / pitch / fov).
##   CHEF_POSE  = <mode>@<s>: pose the shapes lineup with that animation at that time (arm close-ups)
## Extra filmstrip modes: carry_light (weight 1 food), vip (celebration + spin), fidget (long idle).

const COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]
const ANIMS := ["idle", "walk", "carry_solo", "carry_light", "carry_duo", "chop", "dispense", "soda", "bell", "punch",
	"toss", "fall", "celebrate", "vip", "fail", "ping", "strain", "fidget"]
const CYCLE_SECS := 2.6
const DT := 1.0 / 60.0

var _live: Array = []      # [ChefAnim, Node3D chef, yaw] driven every frame (cycle mode)
var _label: Label3D
var _cycle_t := 0.0


func _ready() -> void:
	var view: String = _env("CHEF_VIEW", "three")
	var mode := _env("CHEF_ANIM", "")
	if OS.get_environment("CHEF_DUMP") == "1":
		for path in ["chef", "boxing_glove"]:
			var root := Models.load_model(path)
			add_child(root)
			_dump(root, 0)
			root.queue_free()
	if mode == "shapes":
		_shapes(view)
		return
	if mode == "cycle":
		_cycle()
		return
	if mode != "":
		_filmstrip(mode, view)
		return
	_static(view)


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.has_environment(k) else d


func _look(body := "") -> Dictionary:
	return {"hat": _env("CHEF_HAT", "toque"), "acc": _env("CHEF_ACC", "none"), "beard": _env("CHEF_BEARD", "moustache"),
		"back": _env("CHEF_BACK", "none"), "outfit": _env("CHEF_OUTFIT", "classic"), "body": body if body != "" else _env("CHEF_BODY", "standard")}


func _chef(color: Color, body := "", v1 := false) -> Node3D:
	var inst := Models.load_model("dev/chef_v1" if v1 else "chef")
	Chef.dress(inst, color, _look(body))
	return inst


## The animator for a chef from _chef (v1: the frozen pre-arms ChefAnimV1).
func _anim_for(inst: Node3D, seed_value: int, v1: bool) -> Object:
	return ChefAnimV1.new(inst, seed_value) if v1 else ChefAnim.new(inst, seed_value)


# ---------------------------------------------------------------- static views (the old preview)
func _static(view: String) -> void:
	var tints: String = _env("CHEF_TINTS", "0123")
	if view in ["three", "front", "back", "side"] and not OS.has_environment("CHEF_TINTS"):
		tints = "0"
	var n: int = tints.length()
	var compare := OS.get_environment("CHEF_COMPARE") == "1"
	if compare:
		n = 2
	for i in n:
		var inst := _chef(COLORS[0 if compare else tints[i].to_int()], "", compare and i == 0)
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * 1.5, 0, 0)
		if compare:
			_tag("v1" if i == 0 else "new", inst.position + Vector3(0, -0.12, 0.6))
		inst.rotation.y = {"back": PI, "side": PI / 2, "three": deg_to_rad(35)}.get(view, 0.0)
		if OS.get_environment("CHEF_GLOVE") == "1":
			for hn in ["HandL", "HandR"]:
				var h := inst.find_child(hn, true, false) as Node3D
				var g := Models.load_model("boxing_glove")
				h.add_child(g)
				g.position = Vector3(0, -0.25, 0)
	if view == "glove":
		for c in get_children():
			c.queue_free()
		var g := Models.load_model("boxing_glove")
		add_child(g)
		g.rotation.y = deg_to_rad(_env("CHEF_ROT", "-40").to_float())
	_stage(view, n, 1.5)


# ---------------------------------------------------------------- body shapes lineup
func _shapes(view: String) -> void:
	var n := GameData.BODY_SHAPES.size()
	var spacing := 1.15
	for i in n:
		var id := str(GameData.BODY_SHAPES[i]["id"])
		var inst := _chef(COLORS[i % 4], id)
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, 0)
		inst.rotation.y = {"back": PI, "side": PI / 2, "three": deg_to_rad(25)}.get(view, 0.0)
		_tag(id, inst.position + Vector3(0, -0.12, 0.6))
		var pose := _env("CHEF_POSE", "")
		if pose.contains("@"):
			var mode := pose.get_slice("@", 0)
			var a := ChefAnim.new(inst, 3)
			var t := 0.0
			while t < pose.get_slice("@", 1).to_float():
				_drive(a.state, mode, t, inst.rotation.y, 0)
				a.update(DT)
				t += DT
	_stage(view, n, spacing)


# ---------------------------------------------------------------- filmstrips
func _filmstrip(mode: String, view: String) -> void:
	var n := int(_env("CHEF_FRAMES", "6"))
	var yaw := deg_to_rad(_env("CHEF_YAW", "35").to_float())
	var duo := mode == "carry_duo"
	var carry := mode in ["carry_solo", "carry_duo", "strain", "carry_light"]
	var spacing := (6.0 if duo else 4.6) if carry else 1.25
	var times := _times(mode, n)
	var rows := 2 if OS.get_environment("CHEF_COMPARE") == "1" else 1
	for row in rows:
		var v1 := row == 1
		var row_z := -(3.4 if carry else 2.2) * row
		_filmstrip_row(mode, n, spacing, times, yaw, duo, carry, v1, row_z)
		if rows > 1:
			_tag("v1" if v1 else "new", Vector3(-(n * 0.5 + 0.2) * spacing, 0.0, row_z + 0.3))
	_stage(view, n, spacing, carry)


func _filmstrip_row(mode: String, n: int, spacing: float, times: Array, yaw: float, duo: bool, carry: bool, v1: bool,
		row_z: float) -> void:
	for i in n:
		var group := Node3D.new()
		add_child(group)
		group.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, row_z)
		var chefs := 2 if duo else 1
		for k in chefs:
			var inst := _chef(COLORS[k], "", v1)
			group.add_child(inst)
			var cyaw := yaw
			if duo:  # both at the rim, facing the patty (as group carriers do)
				inst.position = Vector3(-2.16 if k == 0 else 2.16, 0, 0)
				cyaw = PI / 2 if k == 0 else -PI / 2
			elif carry:
				inst.position = -Vector3(sin(yaw), 0, cos(yaw)) * 1.0
			inst.rotation.y = cyaw
			var a: Object = _anim_for(inst, 7 + k, v1)
			var t := 0.0
			while t < times[i]:
				_drive(a.get("state"), mode, t, cyaw, k)
				a.call("update", DT)
				t += DT
		if carry:
			var light := mode == "carry_light"
			var food := Models.load_model("tomato_slice" if light else "patty_raw")
			if food != null:
				group.add_child(food)
				# solo: the near edge just beyond the hands (rest z 0.11 + reach + 0.1 margin)
				var rad := 1.0 if light else 1.5
				var reach := 0.3 if light else 0.45
				food.position = Vector3(0, 0.32, 0) if duo else Vector3(sin(yaw), 0, cos(yaw)) * (0.21 + reach + rad - 1.0) + Vector3(0, 0.45 if light else 0.32, 0)
		if not v1:
			_tag("%s %.2fs" % [mode, times[i]], group.position + Vector3(0, -0.1, 0.9 if not carry else 1.6))


## Sample times (s since the scripted run started) for each frame of a filmstrip.
func _times(mode: String, n: int) -> Array:
	var out: Array = []
	var t0 := 0.05
	var span := 1.0
	match mode:
		"walk":
			t0 = 1.0
			span = TAU / 16.0   # one full stride cycle at full speed
		"idle":
			t0 = 0.5
			span = 9.0
		"punch":
			t0 = 0.02
			span = 0.4
		"toss":
			t0 = 0.02
			span = 0.4
		"bell":
			t0 = 0.02
			span = 0.45
		"fall":
			t0 = 0.4
			span = 1.0
		"celebrate", "vip":
			t0 = 0.03
			span = 1.3
		"fidget":
			t0 = 3.2
			span = 6.0
		"fail":
			t0 = 0.15
			span = 1.3
		"ping":
			t0 = 0.05
			span = 0.9
		_:
			t0 = 1.0
			span = 1.0
	for i in n:
		out.append(t0 + span * float(i) / float(maxi(1, n if mode == "walk" else n - 1)))
	return out


## Scripted state for each mode at time t (s). chef k of a group, facing yaw.
func _drive(st: Object, mode: String, t: float, yaw: float, k: int) -> void:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	st.yaw = yaw
	match mode:
		"walk":
			st.vel = fwd * Tuning.PLAYER_SPEED
		"carry_solo", "strain":
			st.carrying = true
			st.weight = 3
			st.carriers = 1
			st.hold = Vector3(0, 0.05, 0.45)
			st.vel = fwd * Tuning.PLAYER_SPEED * 0.35 if mode == "carry_solo" else Vector3.ZERO
		"carry_light":
			st.carrying = true
			st.weight = 1
			st.carriers = 1
			st.hold = Vector3(0, 0.0, 0.3)
			st.vel = fwd * Tuning.PLAYER_SPEED
		"carry_duo":
			st.carrying = true
			st.weight = 3
			st.carriers = 2
			st.hold = Vector3(0, 0.05, 0.3)
			st.vel = Vector3(0, 0, Tuning.PLAYER_SPEED * 0.5)
		"chop":
			st.working = true
			st.work_kind = ChefAnim.Work.CHOP
		"dispense":
			st.working = true
			st.work_kind = ChefAnim.Work.DISPENSE
		"soda":
			st.working = true
			st.work_kind = ChefAnim.Work.SODA
		"bell":
			st.slap = t < DT
		"punch":
			st.punching = t < 0.25
		"toss":
			st.toss = t < DT
		"fall":
			st.falling = t < 1.0
			st.vy = -6.0 if t < 1.0 else (-3.0 if t < 1.05 else 0.0)
		"celebrate":
			st.celebrate = t < DT
		"vip":
			st.celebrate = t < DT
			if "vip" in st:
				st.vip = t < DT
		"fail":
			st.fail = t < DT
		"ping":
			st.ping = t < DT
			st.ping_dir = Vector3(1, 0, 1)


# ---------------------------------------------------------------- live cycle
func _cycle() -> void:
	var n := GameData.BODY_SHAPES.size()
	var spacing := 1.2
	for i in n:
		var id := str(GameData.BODY_SHAPES[i]["id"])
		var inst := _chef(COLORS[i % 4], id)
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, 0)
		var yaw := deg_to_rad(25)
		inst.rotation.y = yaw
		_live.append([ChefAnim.new(inst, i), inst, yaw])
		_tag(id, inst.position + Vector3(0, -0.12, 0.6))
	_label = Label3D.new()
	_label.font_size = 96
	_label.pixel_size = 0.004
	_label.position = Vector3(0, 2.0, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_stage("three", n, spacing)


func _process(delta: float) -> void:
	if _live.is_empty():
		return
	_cycle_t += delta
	var idx := int(_cycle_t / CYCLE_SECS) % ANIMS.size()
	var mode: String = ANIMS[idx]
	var t := fmod(_cycle_t, CYCLE_SECS)
	_label.text = mode
	for e: Array in _live:
		var a: ChefAnim = e[0]
		var st := a.state
		if t < delta:  # new animation: reset the held states
			st.vel = Vector3.ZERO
			st.carrying = false
			st.working = false
			st.punching = false
			st.falling = false
			st.vy = 0.0
		_drive(st, mode, t, e[2], 0)
		a.update(delta)


# ---------------------------------------------------------------- staging
func _tag(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.004
	l.modulate = Color(0.15, 0.12, 0.1)
	l.outline_size = 0
	l.rotation.x = -PI / 2 + 0.6
	l.position = at
	add_child(l)


func _stage(view: String, n: int, spacing: float, wide := false) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-25), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.74, 0.66, 0.55)
	gm.roughness = 0.9
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	var target := Vector3(0, 0.7, 0)
	var fov := 30.0
	var pos := Vector3(0, 0.9, 3.6)
	match view:
		"front", "back", "side":
			pos = Vector3(0, 0.95, 3.8)
		"three":
			pos = Vector3(0, 1.5, 3.4)
		"top":
			target = Vector3(0, 0.5, 0)
			pos = Vector3(0, 6.0, 3.5)
			fov = 35.0
		"game":
			# the real game camera at its default zoom (CameraSystem: pitch from the zoom, Tuning fov);
			# chefs face +Z (the camera)
			fov = Tuning.CAMERA_FOV
			var far01 := clampf(inverse_lerp(Tuning.CAMERA_DISTANCE_MIN, Tuning.CAMERA_DISTANCE_MAX, Tuning.CAMERA_DISTANCE), 0.0, 1.0)
			var pitch := deg_to_rad(lerpf(Tuning.CAMERA_PITCH_DEG, Tuning.CAMERA_PITCH_FAR_DEG, far01))
			target = Vector3(0, 0.6, -0.8 if OS.get_environment("CHEF_COMPARE") == "1" else 0.0)
			pos = target + Vector3(0, sin(pitch), cos(pitch)) * Tuning.CAMERA_DISTANCE
		"glove":
			target = Vector3(0, 0.25, 0)
			pos = Vector3(0.0, 1.1, 1.5)
	if OS.get_environment("CHEF_CLOSE") == "1" and view in ["front", "back", "side", "three"]:
		target = Vector3(0, 1.0, 0)
		pos = Vector3(0, 1.12, 1.55)
		n = 1
	if view in ["front", "back", "side", "three"] and (n > 1 or wide):
		# fit the row: width n * spacing at a 34 deg fov
		var width := n * spacing + 0.4 if not wide else (n - 1) * spacing + 5.0
		var dist := width * 0.5 / tan(deg_to_rad(17.0)) / 1.9
		fov = 34.0
		pos = Vector3(0, pos.y + dist * 0.18, dist + (1.0 if wide else 0.0))
		target = Vector3(0, 0.65, 0.4 if wide else 0.0)
		if OS.get_environment("CHEF_COMPARE") == "1" and OS.has_environment("CHEF_ANIM"):
			# two rows (new in front, v1 behind): look down on both
			target.z = -1.6 if wide else -1.1
			pos = Vector3(0, dist * 0.5, dist * 0.95 + target.z)
	cam.fov = fov
	cam.far = 500.0
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true


func _dump(n: Node, depth: int) -> void:
	var line := "%s%s (%s)" % ["  ".repeat(depth), n.name, n.get_class()]
	if n is Node3D:
		line += " pos=%s" % (n as Node3D).position
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		var mats: Array = []
		var tris := 0
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			mats.append(m.resource_name if m != null else "-")
			tris += mi.mesh.surface_get_array_index_len(i) / 3
		line += " size=%s tris=%d mats=%s" % [b.size, tris, mats]
	print("DUMP ", line)
	for c in n.get_children():
		_dump(c, depth + 1)
