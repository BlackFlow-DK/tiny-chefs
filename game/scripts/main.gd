extends Node
## Root of Tiny Chefs: shows the menu / lobby / in-game UI for the current Net phase and owns
## the World while a run is going. Handles the automation args (--host, --join, --autostart).

var world: World = null
var menu: MenuScreen
var lobby: LobbyScreen
var hud: Hud
var ends: EndScreens
var pause: PauseMenu
var _auto_timer := -1.0
var _autostarted := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	UI.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	layer.add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	ends = EndScreens.new()
	root.add_child(ends)
	menu = MenuScreen.new()
	root.add_child(menu)
	lobby = LobbyScreen.new()
	root.add_child(lobby)
	pause = PauseMenu.new()
	root.add_child(pause)
	Net.phase_changed.connect(_on_phase)
	Net.session_ended.connect(func(reason: String) -> void: menu.set_status(reason))
	Net.players_changed.connect(_check_autostart)
	_on_phase(Net.phase)
	_handle_args()


func _handle_args() -> void:
	var n := Net.arg_str("name", "")
	if not n.is_empty():
		menu.name_edit.text = n
	get_window().title = "Tiny Chefs - %s" % menu.name_edit.text
	if Net.has_arg("host"):
		var err := Net.host(menu.name_edit.text)
		if err != OK:
			menu.set_status("Could not host on UDP port %d (%s)." % [Tuning.PORT, error_string(err)])
	elif Net.has_arg("join"):
		menu.ip_edit.text = Net.arg_str("join", "127.0.0.1")
		menu._on_join()


func _on_phase(ph: int) -> void:
	menu.visible = ph == Net.Phase.MENU
	lobby.visible = ph == Net.Phase.LOBBY
	if ph >= Net.Phase.PLAYING and world == null:
		world = World.new()
		add_child(world)
		move_child(world, 0)
	elif ph <= Net.Phase.LOBBY and world != null:
		Net.world = null
		world.queue_free()
		world = null
	hud.world = world
	ends.world = world
	hud.visible = ph >= Net.Phase.PLAYING
	ends.show_phase(ph)
	if ph != Net.Phase.PLAYING or world == null:
		pause.close()
	_auto_timer = -1.0
	if Net.is_host and Net.has_arg("autostart"):
		if ph == Net.Phase.RESULTS:
			_auto_timer = Tuning.AUTO_RESULTS_SECONDS
		elif ph == Net.Phase.SHOP:
			_auto_timer = Tuning.AUTO_SHOP_SECONDS
	if ph == Net.Phase.LOBBY:
		_check_autostart()


func _check_autostart() -> void:
	if Net.is_host and Net.phase == Net.Phase.LOBBY and Net.has_arg("autostart") and not _autostarted:
		if Net.players.size() >= Net.arg_int("players", 1):
			_autostarted = true
			Net.set_phase.call_deferred(Net.Phase.PLAYING, {})


func _process(delta: float) -> void:
	if _auto_timer > 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			if Net.phase == Net.Phase.RESULTS:
				Net.set_phase(ModifierSystem.after_results_phase(), Net.phase_info)
			elif Net.phase == Net.Phase.SHOP:
				Net.set_phase(Net.Phase.PLAYING, {})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and Net.phase >= Net.Phase.PLAYING:
		if pause.visible:
			pause.close()
		else:
			pause.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_hints") and Net.phase >= Net.Phase.PLAYING:
		hud.toggle_help()
