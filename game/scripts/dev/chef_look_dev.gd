extends Control
## Dev scene for chef looks (scenes/dev/chef_look.tscn). Env LOOK_VIEW:
##   panel (default): ChefCustomisePanel for the local player next to a LobbyChefView following it (offline).
##     LOOK_PICK=<color>,<hat>,<acc> presets the look (not saved to menu.cfg). LOOK_FAKE=1 adds a fake
##     second player "Bob" wearing green (shows the same-colour warning).
##   lineup: real Chef nodes at game camera distance; row 1 the four hats, row 2 the accessories,
##     all four colours.
##   close: the same eight chefs, closer.


func _ready() -> void:
	UI.full_rect(self)
	theme = UI.theme()
	var view := OS.get_environment("LOOK_VIEW")
	if view == "lineup" or view == "close":
		_lineup(view == "close")
	else:
		_panel()


func _panel() -> void:
	var pick := OS.get_environment("LOOK_PICK").split(",", false)
	if pick.size() == 3:
		Net.local_look = {"color": int(pick[0]), "hat": pick[1], "acc": pick[2]}
		Net.looks_changed.emit()
	if OS.get_environment("LOOK_FAKE") == "1":
		Net.players = {1: {"name": "You", "slot": 0}, 5: {"name": "Bob", "slot": 1, "color": 2, "hat": "paper", "acc": "none"}}
		Net.players[1].merge(Net.resolve_look(Net.local_look, 0), true)
	var bg := ColorRect.new()
	bg.color = UITheme.COUNTER
	UI.full_rect(bg)
	add_child(bg)
	var centre := CenterContainer.new()
	UI.full_rect(centre)
	add_child(centre)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	centre.add_child(h)
	# A lobby-sized card (188 px wide cell): stage with the turntable, name badge, the panel.
	var pv := UIKit.card(8)
	var card: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	card.custom_minimum_size = Vector2(188, 0)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UITheme.box(UIKit.player_color(0), UITheme.INK, 12, 3))
	stage.custom_minimum_size = Vector2(0, 104)
	var cv := LobbyChefView.new(Color.WHITE, Vector2i(100, 100))
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.add_child(cv)
	v.add_child(stage)
	var badge := UIKit.player_badge("You", 0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	var panel := ChefCustomisePanel.new()
	panel.setup(Net.my_id())
	v.add_child(panel)
	h.add_child(card)
	# A big turntable of the same look, to judge the models.
	var big := LobbyChefView.new(Color.WHITE, Vector2i(300, 300), Net.my_id())
	h.add_child(big)


func _lineup(close: bool) -> void:
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	UI.full_rect(vpc)
	add_child(vpc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-25), 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = Models.mat(UITheme.COUNTER)
	root.add_child(ground)
	var hats := ["toque", "beanie", "paper", "bandana"]
	var accs := ["none", "glasses", "moustache", "glasses"]
	for i in 8:
		var c := Chef.new()
		c.setup(100 + i, i % 4, "Chef", true, false)
		root.add_child(c)
		c.position = Vector3((i % 4 - 1.5) * 1.6, 0, 1.0 if i < 4 else -1.0)
		if i < 4:
			c.apply_look(i, hats[i], "none")
		else:
			c.apply_look(i % 4, "toque" if i == 4 else hats[i % 4], accs[i % 4] if i != 4 else "moustache")
	var cam := Camera3D.new()
	root.add_child(cam)
	var target := Vector3(0, 0.6, 0)
	if close:
		cam.fov = 30.0
		cam.position = Vector3(0, 3.2, 8.5)
	else:
		# Game camera (Tuning): pitch 50 deg, distance 19, fov 50.
		cam.fov = 50.0
		cam.position = target + Vector3(0, sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * 19.0
	cam.look_at(target, Vector3.UP)
	cam.current = true
