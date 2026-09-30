class_name LobbyScreen
extends Control
## Lobby: players, the host's LAN address(es) to join, Start (host) and Leave.

var _list: VBoxContainer
var _info: Label
var _start: Button


func _ready() -> void:
	UI.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.28, 0.4)
	UI.full_rect(bg)
	add_child(bg)
	var pv := UI.panel(12)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	p.custom_minimum_size = Vector2(560, 0)
	add_child(UI.centred(p))
	v.add_child(UI.label("Kitchen lobby", 40, UI.YELLOW))
	v.add_child(UI.label("Chefs (up to 4):", 18, UI.DIM))
	_list = VBoxContainer.new()
	v.add_child(_list)
	_info = UI.label("", 17)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(520, 0)
	v.add_child(_info)
	_start = UI.button("Start the shift", func() -> void: Net.set_phase(Net.Phase.PLAYING, {}))
	v.add_child(_start)
	v.add_child(UI.button("Leave", func() -> void: Net.leave()))
	Net.players_changed.connect(refresh)
	visibility_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		var slot := Net.slot_of(id)
		var tag := "  (host)" if id == 1 else ""
		if id == Net.my_id():
			tag += "  (you)"
		_list.add_child(UI.label("  %s%s" % [Net.name_of(id), tag], 22, GameData.PLAYER_COLORS[slot]))
	_start.visible = Net.is_host
	if Net.is_host:
		var ips := Net.lan_addresses()
		var ip_text := ", ".join(ips) if not ips.is_empty() else "(no LAN address found; same-PC players use 127.0.0.1)"
		_info.text = "Friends on your network join with:  %s\nPort %d UDP. Allow the Windows Firewall prompt (private networks) if one appears.\nSame PC: start a second copy and join 127.0.0.1." % [ip_text, Tuning.PORT]
	else:
		_info.text = "Connected. Waiting for the host to start the shift..."
