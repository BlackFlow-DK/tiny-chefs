class_name Hud
extends Control
## In-game HUD: wallet/target, shift clock, order tickets, context hint, controls help (H),
## toasts, and world-space progress bars (cooking, chopping) drawn over the 3D view.

var world: World = null

var _status: Label
var _clock: Label
var _tickets: HBoxContainer
var _ticket_key := ""
var _ticket_bars: Array = []
var _hint: Label
var _help: PanelContainer
var _toasts: VBoxContainer
var _overlay: Control


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = Control.new()
	UI.full_rect(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	var tl := UI.panel(2)
	var tlp: PanelContainer = tl[0]
	tlp.position = Vector2(12, 12)
	_status = UI.label("", 18)
	(tl[1] as VBoxContainer).add_child(_status)
	add_child(tlp)

	var tr := UI.panel(0)
	var trp: PanelContainer = tr[0]
	trp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	trp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	trp.position = Vector2(-12, 12)
	_clock = UI.label("0:00", 40, Color.WHITE)
	(tr[1] as VBoxContainer).add_child(_clock)
	add_child(trp)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 10
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tickets = HBoxContainer.new()
	_tickets.add_theme_constant_override("separation", 8)
	_tickets.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_tickets)
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(_toasts)
	add_child(top)

	_hint = UI.label("", 22, UI.YELLOW)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position.y -= 18
	add_child(_hint)

	var hp := UI.panel(0)
	_help = hp[0]
	(hp[1] as VBoxContainer).add_child(UI.label(UI.controls_text(), 14, UI.DIM))
	_help.anchor_left = 0.0
	_help.anchor_right = 0.0
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 12.0
	_help.offset_right = 12.0
	_help.offset_top = -12.0
	_help.offset_bottom = -12.0
	_help.grow_horizontal = Control.GROW_DIRECTION_END
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_help)

	Net.event_received.connect(_on_event)


func toggle_help() -> void:
	_help.visible = not _help.visible


func _on_event(text: String, _sfx: String) -> void:
	if text.is_empty() or not visible:
		return
	var l := UI.label(text, 22, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _process(_delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var s := world.shift
	var col := UI.GREEN if s.earned >= s.target() else Color.WHITE
	_status.text = "Shift %d: %s\nTeam coins: %d\nThis shift: %d / %d target\nServed %d   Failed %d" % [
		s.index + 1, s.shift_name(), s.coins, s.earned, s.target(), s.served, s.failed]
	_status.add_theme_color_override("font_color", col)
	_clock.text = UI.time_text(s.time_left)
	_clock.add_theme_color_override("font_color", UI.RED if s.time_left < 30.0 and s.running else Color.WHITE)
	_hint.text = world.hint_text
	_update_tickets()
	_overlay.queue_redraw()


func _update_tickets() -> void:
	var os: Array = world.orders.orders
	var key := ""
	for o in os:
		key += "%d," % int(o["r"])
	if key != _ticket_key:
		_ticket_key = key
		_ticket_bars.clear()
		for c in _tickets.get_children():
			c.queue_free()
		for o in os:
			_tickets.add_child(_make_ticket(int(o["r"])))
	for i in mini(os.size(), _ticket_bars.size()):
		var frac := clampf(float(os[i]["left"]) / float(os[i]["patience"]), 0.0, 1.0)
		var bar: ColorRect = _ticket_bars[i]
		bar.size.x = 180.0 * frac
		bar.color = Color(1.0, 0.3, 0.25).lerp(Color(0.35, 0.95, 0.4), frac)


func _make_ticket(r: int) -> Control:
	var rec: Dictionary = GameData.RECIPES[r]
	var pv := UI.panel(4)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	p.custom_minimum_size = Vector2(208, 0)
	var nl := UI.label(rec["name"], 17, UI.YELLOW)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(180, 0)
	v.add_child(nl)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 3)
	var counts := {}
	var order: Array = []
	for k in rec["items"]:
		var d: Dictionary = GameData.ITEMS[k]
		var shape := str(d["shape"])
		icons.add_child(UI.swatch(d["color"], shape == "cyl" or shape == "sphere" or shape == "dome"))
		if not counts.has(k):
			order.append(k)
		counts[k] = int(counts.get(k, 0)) + 1
	v.add_child(icons)
	var parts := PackedStringArray()
	for k in order:
		var lbl := str(GameData.ITEMS[k]["label"])
		parts.append(("%dx %s" % [counts[k], lbl]) if int(counts[k]) > 1 else lbl)
	var il := UI.label(", ".join(parts), 12, UI.DIM)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.custom_minimum_size = Vector2(180, 0)
	v.add_child(il)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.custom_minimum_size = Vector2(180, 8)
	var fill := ColorRect.new()
	fill.size = Vector2(180, 8)
	bg.add_child(fill)
	v.add_child(bg)
	_ticket_bars.append(fill)
	return p


func _draw_overlay() -> void:
	if world == null or not is_instance_valid(world) or world.camera == null:
		return
	var cam := world.camera
	for it in world.items.values():
		if it.bar_kind == Item.Bar.NONE or not is_instance_valid(it):
			continue
		var wp: Vector3 = it.global_position + Vector3(0, it.size.y + 1.2, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var w := 70.0
		var rect := Rect2(sp - Vector2(w * 0.5, 6), Vector2(w, 12))
		_overlay.draw_rect(rect.grow(2), Color(0, 0, 0, 0.75))
		var c := Color(0.35, 0.95, 0.4)
		if it.bar_kind == Item.Bar.BURN:
			c = Color(0.95, 0.85, 0.2).lerp(Color(1.0, 0.15, 0.1), it.bar)
		elif it.bar_kind == Item.Bar.CHOP:
			c = Color(0.35, 0.75, 1.0)
		_overlay.draw_rect(Rect2(rect.position, Vector2(w * clampf(it.bar, 0.0, 1.0), 12)), c)
