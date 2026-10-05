class_name MenuScreen
extends Control
## Title screen: living kitchen backdrop, name, Host, Wardrobe (+ token wallet), Join, How to play, Settings,
## Quit. Remembers name + IP.
## "Join a friend's kitchen" turns the card to its join page: the LAN list (LanGameList, searching while the
## page is open) above the address field + Join button. Back / Esc returns. --join-screen opens it at start.

const CFG_PATH := "user://menu.cfg"
const JOIN_TIMEOUT := 9.0

var name_edit: LineEdit
var ip_edit: LineEdit
var lan_list: LanGameList
var _main_page: VBoxContainer
var _join_page: VBoxContainer
var _qrow: HBoxContainer
var _find_btn: Button      # main page: opens the join page
var _back_btn: Button
var _lan_dots: Control     # small "still searching" dots in the join page header (while rows are listed)
var _auto_focus := false   # the join page picked the focus itself; a first joinable row may take it over
var _auto_focus_until := 0  # ... only this soon after opening (msec)
var status_row: PanelContainer
var status_dot: Panel
var status_label: Label
var _host_btn: Button
var _join_btn: Button
var _cancel_btn: Button   # in the status row while connecting
var _quit_btn: Button
var _how_btn: Button
var _how: HowToPlay
var _settings_btn: Button
var _settings: SettingsView
var _wardrobe: WardrobeView
var _wardrobe_btn: Button
var _tokens: UITokenChip
var _join_row: Control
var _card: PanelContainer
var _timeout: SceneTreeTimer = null
var _connecting := false


func _ready() -> void:
	UI.full_rect(self)
	add_child(MenuDiorama.new())
	_build_column()
	_build_hints()
	_build_version()
	_how = HowToPlay.new()
	add_child(_how)
	_settings = SettingsView.new()
	add_child(_settings)
	_wardrobe = WardrobeView.new()
	_wardrobe.closed.connect(func() -> void:
		_tokens.set_amount(Progress.tokens(), false)
		if is_visible_in_tree():
			_wardrobe_btn.grab_focus.call_deferred())
	add_child(_wardrobe)
	_load_config()
	visibility_changed.connect(_on_visible)
	_on_visible.call_deferred()
	_agent_wardrobe.call_deferred()
	if Net.has_arg("join-screen"):
		_agent_join_screen()


## Agent helper: --join-screen opens the join page (LAN list) once the menu is laid out.
func _agent_join_screen() -> void:
	for i in 3:
		await get_tree().process_frame
	if Net.phase == Net.Phase.MENU and not _connecting:
		open_join_page()


## Agent helper: --wardrobe=<tab>[:<id>] opens the Wardrobe on that tab (hat, beard, acc, outfit, back, body,
## color), selecting that item.
func _agent_wardrobe() -> void:
	if not Net.has_arg("wardrobe") or Net.phase != Net.Phase.MENU:
		return
	var spec := Net.arg_str("wardrobe", "hat").split(":")
	_wardrobe.open(spec[0], spec[1] if spec.size() > 1 else "")


func _build_column() -> void:
	var margin := MarginContainer.new()
	UI.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 88)
	add_child(margin)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(500, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var title := UIKit.title("TINY CHEFS", UITheme.S_HERO)
	col.add_child(title)
	UIKit.pop_in(title, 0.0, 0.3)
	var tag := UIKit.body("Co-op kitchen chaos. The food is bigger than you!", "world")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	var pv := UIKit.card(UITheme.GAP)
	_card = pv[0]
	var cv: VBoxContainer = pv[1]
	col.add_child(_card)
	UIKit.pop_in(_card, 0.12, 0.2)
	_main_page = VBoxContainer.new()
	cv.add_child(_main_page)
	_join_page = VBoxContainer.new()
	_join_page.visible = false
	cv.add_child(_join_page)
	var v := _main_page

	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", UITheme.GAP)
	var nl := UIKit.body("Your name")
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nh.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.text = _default_name()
	name_edit.max_length = 16
	name_edit.placeholder_text = "Chef"
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(func(_t: String) -> void: _host_btn.grab_focus())
	nh.add_child(name_edit)
	v.add_child(nh)

	_host_btn = UIKit.button("Host a kitchen", _on_host, "primary")
	_host_btn.custom_minimum_size = Vector2(0, 60)
	v.add_child(_host_btn)
	var host_hint := UIKit.caption("Solo or LAN. Friends join with your address.")
	host_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(host_hint)

	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", UITheme.GAP)
	_wardrobe_btn = UIKit.button("Wardrobe", func() -> void: _wardrobe.open(), "accent")
	_wardrobe_btn.custom_minimum_size = Vector2(0, 48)
	_wardrobe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(_wardrobe_btn)
	_tokens = UIKit.token_chip(Progress.tokens())
	_tokens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tokens.tooltip_text = "Your wardrobe tokens"
	wrow.add_child(_tokens)
	v.add_child(wrow)

	v.add_child(HSeparator.new())

	_find_btn = UIKit.button("Join a friend's kitchen", open_join_page, "secondary")
	v.add_child(_find_btn)

	# Join page: header (Back + title), the LAN list, then the address field as before.
	v = _join_page
	var head := HBoxContainer.new()
	_back_btn = UIKit.button("Back", close_join_page, "secondary", 88)
	_back_btn.custom_minimum_size = Vector2(88, 40)
	_back_btn.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	head.add_child(_back_btn)
	var ht := UIKit.heading("Kitchens on your network")
	ht.add_theme_font_size_override("font_size", UITheme.S_BODY)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ht)
	_lan_dots = LanGameList.Dots.new(3.5)
	_lan_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lan_dots.tooltip_text = "Still looking for more"
	head.add_child(_lan_dots)
	v.add_child(head)
	lan_list = LanGameList.new()
	lan_list.join_requested.connect(_on_join_lan)
	lan_list.focus_needed.connect(func() -> void: ip_edit.grab_focus.call_deferred())
	Net.discovery.games_changed.connect(_on_lan_games, CONNECT_DEFERRED)   # after the list has its rows
	v.add_child(lan_list)
	var or_box := VBoxContainer.new()
	or_box.add_theme_constant_override("separation", 4)
	or_box.add_child(UIKit.caption("Or type the host's address"))
	v.add_child(or_box)
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", UITheme.GAP)
	_join_row = jh
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Host address, e.g. 192.168.1.20"
	ip_edit.custom_minimum_size = Vector2(0, 46)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.text_submitted.connect(func(_t: String) -> void: _on_join())
	ip_edit.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			_auto_focus = false)   # clicked into the field: it keeps the focus
	ip_edit.text_changed.connect(func(_t: String) -> void:
		_auto_focus = false   # typing: a row turning up must not take the focus away
		if not _connecting:
			_clear_status())
	jh.add_child(ip_edit)
	_join_btn = UIKit.button("Join", _on_join, "secondary", 110)
	jh.add_child(_join_btn)
	or_box.add_child(jh)

	# Inline status (join errors, "Connecting...").
	status_row = PanelContainer.new()
	status_row.theme_type_variation = "ChipPanel"
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	status_dot = UIKit.dot(UITheme.TOMATO, 18)
	sh.add_child(status_dot)
	status_label = UIKit.caption("")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(status_label)
	_cancel_btn = UIKit.button("Cancel", _on_cancel_join, "secondary", 96)
	_cancel_btn.custom_minimum_size = Vector2(96, 36)
	_cancel_btn.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	_cancel_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cancel_btn.visible = false
	sh.add_child(_cancel_btn)
	status_row.add_child(sh)
	status_row.visible = false
	cv.add_child(status_row)   # both pages: under the address field on the join page, above qrow on the main one

	var qrow := HBoxContainer.new()
	_qrow = qrow
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", UITheme.GAP)
	_how_btn = UIKit.button("How to play", func() -> void: _how.open(), "secondary", 150)
	_how_btn.custom_minimum_size = Vector2(150, 40)
	_how_btn.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	qrow.add_child(_how_btn)
	_settings_btn = UIKit.button("Settings", func() -> void: _settings.open(), "secondary", 120)
	_settings_btn.custom_minimum_size = Vector2(120, 40)
	_settings_btn.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	qrow.add_child(_settings_btn)
	_quit_btn = UIKit.button("Quit", func() -> void: get_tree().quit(), "secondary", 96)
	_quit_btn.custom_minimum_size = Vector2(96, 40)
	_quit_btn.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	qrow.add_child(_quit_btn)
	cv.add_child(qrow)


func _build_hints() -> void:
	var strip := PanelContainer.new()
	strip.theme_type_variation = "DarkChipPanel"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for h in [["WASD", "Move"], ["L-Click", "Grab / drop"], ["R-Click", "Hold to work"], ["Space", "Punch"], ["Esc", "Pause"]]:
		row.add_child(UIKit.key_hint(h[0], h[1], "dark"))
	vb.add_child(row)
	var cap := UIKit.caption("Keyboard alternatives: E grab, F work, Q punch. Gamepads work too.", "dark")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	strip.add_child(vb)
	add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip.position.y -= 20
	UIKit.pop_in(strip, 0.3)


## Small version caption in the bottom-right corner (project setting application/config/version).
func _build_version() -> void:
	var l := UIKit.caption("v" + str(ProjectSettings.get_setting("application/config/version", "")), "world")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.position.x -= 16
	l.position.y -= 10


func _on_visible() -> void:
	if not is_visible_in_tree():
		_show_page(false)   # stops the LAN search; the menu comes back on its main page
		_cancel_wait()
		_set_busy(false)
		_clear_status()
		_wardrobe.close()
		return
	_tokens.set_amount(Progress.tokens(), false)   # tokens earned in the run we just left
	# Start focus: host button (main page).
	if _host_btn != null and not _host_btn.disabled and not _join_page.visible:
		_host_btn.grab_focus.call_deferred()


# ---------------------------------------------------------------- join page

## Turn the card to the join page and start searching the LAN.
func open_join_page() -> void:
	if _join_page.visible or not is_visible_in_tree():
		return
	_show_page(true)
	UIKit.pop_in(_join_page, 0.0, 0.16)
	_auto_focus = true
	_auto_focus_until = Time.get_ticks_msec() + 3000
	_focus_join_page()


## Back to the main page (stops the search).
func close_join_page() -> void:
	if not _join_page.visible or _connecting:
		return
	_show_page(false)
	UIKit.pop_in(_main_page, 0.0, 0.16)
	_find_btn.grab_focus.call_deferred()


func _show_page(join: bool) -> void:
	if join:
		# Same card height as the main page (+ its bottom row), so the title does not jump; the list takes the rest.
		var sep := float(_main_page.get_parent().get_theme_constant("separation"))
		_join_page.custom_minimum_size.y = _main_page.size.y + _qrow.size.y + sep
	if _join_page.visible != join and not _connecting:
		_clear_status()   # "Join cancelled." / "No answer from ..." belong to the page that showed them
	_main_page.visible = not join
	_qrow.visible = not join
	_join_page.visible = join
	if join:
		if not _connecting:
			lan_list.start()
	else:
		lan_list.stop()
	_sync_lan_dots()


## Join page focus: the first row you can join, else the address field (type and press Enter, as before).
func _focus_join_page() -> void:
	var row := lan_list.first_joinable()
	if row != null:
		row.grab_focus.call_deferred()
	else:
		ip_edit.grab_focus.call_deferred()


## Discovery list changed (deferred: the list has its rows): a first joinable row takes over the focus the page
## picked itself.
func _on_lan_games(_games: Array) -> void:
	_sync_lan_dots()
	if not _auto_focus or not _join_page.visible or _connecting or Time.get_ticks_msec() > _auto_focus_until:
		return
	var row := lan_list.first_joinable()
	var fo := get_viewport().gui_get_focus_owner()
	if row != null and (fo == ip_edit or fo == null):
		_auto_focus = false
		row.grab_focus.call_deferred()


func _sync_lan_dots() -> void:
	_lan_dots.visible = _join_page.visible and lan_list.is_searching() and lan_list.row_count() > 0


func _on_join_lan(g: Dictionary) -> void:
	if _connecting:
		return
	var where := "%s's kitchen" % str(g["name"])
	var ip := str(g["address"])
	var gport := int(g["port"])
	_save_config()
	lan_list.stop(true)   # the rows stay on screen (locked) while connecting
	print("menu: joining %s at %s:%d from the LAN list (%s, %d/%d)" % [where, ip, gport, g["state"], g["players"], g["max_players"]])
	var err := Net.join(ip, name_edit.text, gport)
	if err != OK:
		set_status("Could not reach %s at %s (%s)." % [where, ip, error_string(err)])
		return
	_begin_connecting("%s (%s)" % [where, ip])


func _unhandled_input(event: InputEvent) -> void:
	if not _join_page.visible or not is_visible_in_tree():
		return
	var jb := event as InputEventJoypadButton
	var pad_b := jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B
	if event.is_action_pressed("ui_cancel") or pad_b:
		if _connecting:
			_on_cancel_join()
		else:
			close_join_page()
		get_viewport().set_input_as_handled()


func _default_name() -> String:
	var n := OS.get_environment("USERNAME")
	return n.substr(0, 16) if not n.is_empty() else "Chef"


# ---------------------------------------------------------------- persistence

func _skip_config() -> bool:
	return Net.has_arg("host") or Net.has_arg("join") or Net.has_arg("bot")


func _load_config() -> void:
	if _skip_config():
		return
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	var n := str(cf.get_value("menu", "name", ""))
	if not n.strip_edges().is_empty():
		name_edit.text = n.substr(0, 16)
	var ip := str(cf.get_value("menu", "ip", ""))
	if not ip.strip_edges().is_empty():
		ip_edit.text = ip


func _save_config() -> void:
	if _skip_config():
		return
	var cf := ConfigFile.new()
	cf.load(CFG_PATH)  # keep other sections (Net saves the chef look under [chef])
	cf.set_value("menu", "name", name_edit.text.strip_edges())
	cf.set_value("menu", "ip", ip_edit.text.strip_edges())
	cf.save(CFG_PATH)


# ---------------------------------------------------------------- status

func _show_status(msg: String, kind: String) -> void:
	if msg.is_empty():
		_clear_status()
		return
	var col: Color = UITheme.SKY if kind == "info" else (UITheme.MUSTARD if kind == "warn" else UITheme.TOMATO)
	status_dot.add_theme_stylebox_override("panel", UITheme.box(col, UITheme.INK, 9, 3))
	status_label.text = msg
	var was := status_row.visible
	status_row.visible = true
	if not was:
		UIKit.pop_in(status_row, 0.0, 0.15)


func _clear_status() -> void:
	status_row.visible = false


## Error/notice from outside (Net.session_ended, host failures). Re-enables the buttons.
func set_status(msg: String) -> void:
	_cancel_wait()
	_set_busy(false)
	if msg.is_empty():
		_clear_status()
		return
	_show_status(msg, "error")
	if _join_row != null and _join_row.is_visible_in_tree():
		UIKit.shake(_join_row)


func _set_busy(busy: bool) -> void:
	_connecting = busy
	for b in [_host_btn, _join_btn, _find_btn, _back_btn]:
		if b != null:
			b.disabled = busy
	if lan_list != null:
		lan_list.set_locked(busy)
		if not busy and _join_page.visible and is_visible_in_tree():
			lan_list.start()   # the join failed or was cancelled: look again
	if _cancel_btn != null:
		_cancel_btn.visible = busy
		if busy and is_visible_in_tree():
			_cancel_btn.grab_focus.call_deferred()
	if not busy and is_visible_in_tree() and _host_btn != null:
		var fo := get_viewport().gui_get_focus_owner()
		if fo == null or not fo.is_visible_in_tree() or (fo is BaseButton and (fo as BaseButton).disabled):
			if _join_page.visible:
				_focus_join_page()
			else:
				_host_btn.grab_focus.call_deferred()
	_sync_lan_dots()


func _cancel_wait() -> void:
	_timeout = null


## Cancel while "Connecting...": drop the attempt (and any --join retry window), back to the menu buttons.
func _on_cancel_join() -> void:
	if not _connecting:
		return
	print("menu: join cancelled")
	Net.cancel_join()
	_cancel_wait()
	_set_busy(false)
	_show_status("Join cancelled.", "warn")
	if _join_page.visible:
		_focus_join_page()
	else:
		_find_btn.grab_focus.call_deferred()


# ---------------------------------------------------------------- actions

func _on_host() -> void:
	_save_config()
	var err := Net.host(name_edit.text)
	if err != OK:
		set_status("Could not host on UDP port %d (%s). Is another game already hosting on this PC?" % [Net.port(), error_string(err)])


func _on_join() -> void:
	if _connecting:
		return
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
		ip_edit.text = ip
	_save_config()
	var err := Net.join(ip, name_edit.text)
	if err != OK:
		set_status("That address does not look right (%s). Try something like 192.168.1.20." % error_string(err))
		return
	_begin_connecting(ip)


## "Connecting to <where> ..." with Cancel, and the no-answer timeout. where: an address or "Anna's kitchen (ip)".
func _begin_connecting(where: String) -> void:
	lan_list.stop(true)   # no LAN search while joining; the rows stay (locked) in case it fails
	_show_status("Connecting to %s ..." % where, "info")
	_set_busy(true)
	var t := get_tree().create_timer(maxf(JOIN_TIMEOUT, Net.join_retry_left() + 1.0))   # --join runs retry longer
	_timeout = t
	t.timeout.connect(func() -> void:
		if _timeout != t or not _connecting:
			return
		_timeout = null
		Net.leave(false)
		set_status("No answer from %s. Is the host running, on the same network, and is the address right?" % where))
