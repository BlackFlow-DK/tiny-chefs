class_name LobbyScreen
extends Control
## Lobby: the host's LAN address (big, copyable), four chef slots, Start (host) and Leave.

var _addr_panel: PanelContainer
var _addr_label: Label
var _addr_more: Label
var _addr_hint: Label
var _copy_btn: Button
var _slots_row: HBoxContainer
var _slot_nodes: Array = []
var _slot_keys: Array = ["", "", "", ""]
var _start: Button
var _wait: Label
var _leave: Button
var _copy_tween: Tween = null
var _primary_ip := ""


func _ready() -> void:
	UI.full_rect(self)
	add_child(MenuDiorama.new())
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(860, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	var title := UIKit.title("Kitchen lobby", UITheme.S_TITLE)
	col.add_child(title)
	UIKit.pop_in(title, 0.0, 0.25)

	_build_address(col)

	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 14)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_slots_row)
	for i in 4:
		var holder := Control.new()  # fixed-size cell so a pop-in never re-lays the row
		holder.custom_minimum_size = Vector2(200, 272)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots_row.add_child(holder)
		_slot_nodes.append(holder)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)
	_leave = UIKit.button("Leave", func() -> void: Net.leave(), "secondary", 140)
	bottom.add_child(_leave)
	_start = UIKit.button("Start shift", func() -> void: Net.set_phase(Net.Phase.PLAYING, {}), "go", 300)
	_start.custom_minimum_size = Vector2(300, 64)
	bottom.add_child(_start)
	_wait = UIKit.body("Waiting for the host to start...", "world")
	_wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_wait)

	Net.players_changed.connect(refresh)
	visibility_changed.connect(_on_visible)
	refresh()


func _build_address(col: VBoxContainer) -> void:
	var pv := UIKit.card(6, true)
	_addr_panel = pv[0]
	var v: VBoxContainer = pv[1]
	col.add_child(_addr_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_addr_hint = UIKit.caption("Friends on your network type this to join", "dark")
	left.add_child(_addr_hint)
	_addr_label = UIKit.number("", "dark", UITheme.MUSTARD)
	left.add_child(_addr_label)
	_addr_more = UIKit.caption("", "dark")
	_addr_more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_addr_more.custom_minimum_size = Vector2(600, 0)
	left.add_child(_addr_more)
	_copy_btn = UIKit.button("Copy", _on_copy, "accent", 130)
	_copy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_copy_btn)


func _on_visible() -> void:
	if not is_visible_in_tree():
		return
	_slot_keys = ["", "", "", ""]  # replay the pop-ins when the lobby opens
	refresh()
	var target: Button = _start if Net.is_host else _leave
	target.grab_focus.call_deferred()


func _on_copy() -> void:
	if _primary_ip.is_empty():
		return
	DisplayServer.clipboard_set(_primary_ip)
	_copy_btn.text = "Copied!"
	UIKit.punch(_copy_btn)
	if _copy_tween != null:
		_copy_tween.kill()
	_copy_tween = create_tween()
	_copy_tween.tween_interval(1.6)
	_copy_tween.tween_callback(func() -> void: _copy_btn.text = "Copy")


func refresh() -> void:
	if not is_inside_tree() or _slot_nodes.is_empty():
		return
	_refresh_address()
	_refresh_slots()
	_start.visible = Net.is_host
	_wait.visible = not Net.is_host


func _refresh_address() -> void:
	if Net.is_host:
		var ips := Net.lan_addresses()
		_copy_btn.visible = true
		if ips.is_empty():
			_primary_ip = ""
			_addr_label.text = "No LAN address found"
			_addr_hint.text = "Same-PC players type 127.0.0.1 to join"
			_addr_more.text = ""
			_copy_btn.disabled = true
		else:
			_primary_ip = ips[0]
			_addr_label.text = ips[0]
			_addr_hint.text = "Friends on your network type this to join"
			var more := Array(ips).slice(1)
			var port_note := "Port %d UDP. Allow the Windows Firewall prompt (private networks)." % Net.port()
			_addr_more.text = ("Also: %s. " % ", ".join(more) if not more.is_empty() else "") + port_note
			_copy_btn.disabled = false
	else:
		_primary_ip = Net.join_ip
		_copy_btn.visible = false
		_addr_hint.text = "You are connected to"
		_addr_label.text = Net.join_ip if not Net.join_ip.is_empty() else "the host"
		_addr_more.text = ""


func _refresh_slots() -> void:
	var by_slot := {}
	for id in Net.players.keys():
		by_slot[Net.slot_of(id)] = id
	for i in 4:
		var id: Variant = by_slot.get(i, null)
		var key := "" if id == null else "%d:%s" % [id, Net.name_of(id)]
		var mine: bool = id != null and id == Net.my_id()
		if id != null:
			key += ":me" if mine else ""
		if key == _slot_keys[i] and _slot_nodes[i].get_child_count() > 0:
			continue
		var was_empty: bool = _slot_keys[i] == ""
		_slot_keys[i] = key
		var holder: Control = _slot_nodes[i]
		for c in holder.get_children():
			c.queue_free()
		var card := _make_slot(i, id)
		holder.add_child(card)
		UI.full_rect(card)
		UIKit.pop_in(card, i * 0.05, 0.2)
		if id != null and not was_empty:
			pass


func _make_slot(i: int, id: Variant) -> Control:
	var col := UIKit.player_color(i)
	if id == null:
		var pv := UIKit.card(8, true)
		var p: PanelContainer = pv[0]
		var v: VBoxContainer = pv[1]
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var d := UIKit.dot(col.darkened(0.25), 44)
		d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(d)
		var l := UIKit.body("Waiting for a chef...", "dark")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		var tw := p.create_tween().set_loops()
		tw.tween_property(v, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(v, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		return p
	var pv := UIKit.card(10)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UITheme.box(col, UITheme.INK, 12, 3))
	stage.custom_minimum_size = Vector2(0, 150)
	stage.size_flags_horizontal = Control.SIZE_FILL
	if Models.has_model("chef"):
		var cv := LobbyChefView.new(Color.WHITE.lerp(col, 1.0), Vector2i(150, 150))
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stage.add_child(cv)
	else:
		var d := UIKit.dot(col, 90)
		d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stage.add_child(d)
	v.add_child(stage)
	var badge := UIKit.player_badge(Net.name_of(id), i)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	var tag := "Host" if id == 1 else "Chef"
	if id == Net.my_id():
		tag += " (you)"
	var c := UIKit.caption(tag)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	return p
