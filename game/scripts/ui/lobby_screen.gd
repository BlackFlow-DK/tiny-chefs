class_name LobbyScreen
extends Control
## Lobby: left column = host address + four chef cards; right column = the game-settings card
## (LobbySettingsPanel), Start (host) / Leave and a one-line summary of the chosen run.

var _addr_panel: PanelContainer
var _addr_label: Label
var _addr_more: Label
var _addr_hint: Label
var _copy_btn: Button
var _slots_grid: GridContainer
var _summary: Label
var _settings: LobbySettingsPanel
var _reason: Label
var _slot_nodes: Array = []
var _slot_keys: Array = ["", "", "", ""]
var _start: Button
var _wait: Label
var _leave: Button
var _copy_tween: Tween = null
var _primary_ip := ""

const CELL := Vector2(188, 196)
const CUSTOMISE_PANEL := "res://scripts/ui/chef_customise_panel.gd"


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
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)

	# ---- left: title, address, chef cards
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(CELL.x * 2 + 14, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(left)
	var title := UIKit.title("Kitchen lobby", UITheme.S_TITLE)
	left.add_child(title)
	UIKit.pop_in(title, 0.0, 0.25)
	_build_address(left)
	var slot_scroll := ScrollContainer.new()
	slot_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	slot_scroll.follow_focus = true
	left.add_child(slot_scroll)
	_slots_grid = GridContainer.new()
	_slots_grid.columns = 2
	_slots_grid.add_theme_constant_override("h_separation", 14)
	_slots_grid.add_theme_constant_override("v_separation", 14)
	var sg_pad := MarginContainer.new()  # room for the hard shadows and focus rings
	sg_pad.add_theme_constant_override("margin_bottom", 10)
	sg_pad.add_theme_constant_override("margin_right", 6)
	slot_scroll.add_child(sg_pad)
	sg_pad.add_child(_slots_grid)
	for i in 4:
		var holder := Control.new()  # fixed-size cell so a pop-in never re-lays the grid
		holder.custom_minimum_size = CELL
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots_grid.add_child(holder)
		_slot_nodes.append(holder)

	# ---- right: settings card, buttons, summary
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(right)
	_settings = LobbySettingsPanel.new()
	right.add_child(_settings)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	right.add_child(bottom)
	_leave = UIKit.button("Leave", func() -> void: Net.leave(), "secondary", 140)
	bottom.add_child(_leave)
	_start = UIKit.button("Start shift", func() -> void: Net.set_phase(Net.Phase.PLAYING, {}), "go", 300)
	_start.custom_minimum_size = Vector2(300, 64)
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_start)
	_wait = UIKit.body("Waiting for the host to start...", "world")
	_wait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(_wait)
	_summary = UIKit.body("", "world")
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(1, 0)
	right.add_child(_summary)
	_reason = UIKit.caption("", "world")
	_reason.add_theme_color_override("font_color", UITheme.MUSTARD)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size = Vector2(1, 0)
	right.add_child(_reason)

	Net.settings_changed.connect(_refresh_summary)
	Net.players_changed.connect(refresh)
	visibility_changed.connect(_on_visible)
	refresh()


func _build_address(col: VBoxContainer) -> void:
	var pv := UIKit.card(4, true)
	_addr_panel = pv[0]
	var v: VBoxContainer = pv[1]
	col.add_child(_addr_panel)
	_addr_hint = UIKit.caption("Friends on your network type this", "dark")
	v.add_child(_addr_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_addr_label = UIKit.number("", "dark", UITheme.MUSTARD)
	_addr_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_addr_label)
	_copy_btn = UIKit.button("Copy", _on_copy, "accent", 100)
	_copy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_copy_btn)
	_addr_more = UIKit.caption("", "dark")
	_addr_more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_addr_more.custom_minimum_size = Vector2(1, 0)
	v.add_child(_addr_more)


func _on_visible() -> void:
	if not is_visible_in_tree():
		return
	_slot_keys = ["", "", "", ""]  # replay the pop-ins when the lobby opens
	refresh()
	_refresh_summary()
	_settings.replay_intro()
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
	_refresh_summary()


## Summary line under Start; Start is disabled, with the reason, if the settings needed fixing.
func _refresh_summary() -> void:
	if _summary == null:
		return
	_summary.text = LobbySettingsPanel.summary(Net.settings)
	var fixes := Net.settings.copy().validate()
	_start.disabled = not fixes.is_empty()
	_reason.text = "" if fixes.is_empty() else "Can't start yet: %s" % "; ".join(fixes)
	_reason.visible = not fixes.is_empty()


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
			_addr_hint.text = "Friends on your network type this"
			var more := Array(ips).slice(1)
			var port_note := "Port %d UDP. Allow the Firewall prompt." % Net.port()
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
		holder.custom_minimum_size.y = CELL.y
		if card.has_meta("fit"):
			_fit_holder(holder, card)
		UIKit.pop_in(card, i * 0.05, 0.2)
		if id != null and not was_empty:
			pass


func _make_slot(i: int, id: Variant) -> Control:
	var col := UIKit.player_color(i)
	if id == null:
		var pv := UIKit.card(8, true)
		var p: PanelContainer = pv[0]
		var v: VBoxContainer = pv[1]
		_tighten(p, true)
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
	var pv := UIKit.card(8)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	_tighten(p, false)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UITheme.box(col, UITheme.INK, 12, 3))
	stage.custom_minimum_size = Vector2(0, 104)
	stage.size_flags_horizontal = Control.SIZE_FILL
	if Models.has_model("chef"):
		var cv := LobbyChefView.new(Color.WHITE.lerp(col, 1.0), Vector2i(100, 100))
		cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stage.add_child(cv)
	else:
		var d := UIKit.dot(col, 70)
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
	if id == Net.my_id():
		var cz := _customise_slot(int(id))
		v.add_child(cz)
		p.set_meta("fit", true)  # the customise panel makes this card taller than a plain one
	return p


## Grow a cell to its card once the content has been laid out (customise panel under the local chef).
func _fit_holder(holder: Control, card: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(holder) and is_instance_valid(card):
		holder.custom_minimum_size.y = maxf(CELL.y, card.get_combined_minimum_size().y)


## Smaller card padding than the theme default so four chefs fit beside the settings.
func _tighten(p: PanelContainer, dark: bool) -> void:
	var sb: StyleBoxFlat
	if dark:
		sb = UITheme.box(UITheme.INK, UITheme.INK_LIGHT, UITheme.R_CARD, UITheme.B_CARD, UITheme.SHADOW, 0, Color(0, 0, 0, 0.45))
	else:
		sb = UITheme.box(UITheme.CREAM, UITheme.INK, UITheme.R_CARD, UITheme.B_CARD, UITheme.SHADOW)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)


## Slot for the chef customisation panel (another agent's ui/chef_customise_panel.gd, Control with
## setup(peer_id)). Until that file exists this is a 0-height placeholder.
func _customise_slot(peer_id: int) -> Control:
	if ResourceLoader.exists(CUSTOMISE_PANEL):
		var scr: Variant = load(CUSTOMISE_PANEL)
		if scr is GDScript and (scr as GDScript).can_instantiate():
			var n: Variant = (scr as GDScript).new()
			if n is Control:
				if (n as Control).has_method("setup"):
					(n as Control).call("setup", peer_id)
				return n
	var ph := Control.new()
	ph.name = "CustomisePlaceholder"
	ph.custom_minimum_size = Vector2.ZERO
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ph
