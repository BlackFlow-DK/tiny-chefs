class_name Hud
extends Control
## In-game HUD: order rail (top centre), coins + shift target (top-left), timer (top-right), toasts,
## controls help (bottom-left, H), context prompt (bottom-centre), shift banner, and world-space
## progress bars (cooking, chopping) drawn over the 3D view. Reads the same replicated state as
## before: world.shift, world.orders, world.plate.stack, world.hint_text, Net.event_received.

const CORNER := 12.0

var world: World = null

var _overlay: Control
var _rail: HudOrderRail
var _toasts: VBoxContainer
# top-left
var _stats: PanelContainer
var _shift_cap: Label
var _coins: UICoinChip
var _goal_bar: UIProgress
var _goal_lbl: Label
var _count_lbl: Label
# top-right
var _timer_card: PanelContainer
var _timer_lbl: Label
var _timer_bar: UIProgress
var _timer_sb_normal: StyleBoxFlat
var _timer_sb_urgent: StyleBoxFlat
var _timer_pulse: Tween
# bottom
var _prompt: PanelContainer
var _prompt_row: HBoxContainer
var _prompt_key := "\u0001"
var _help: PanelContainer
var _help_chip: PanelContainer
var _help_space: Control
var _help_shown := true
var _banner: Control

# tracking
var _shift_key := ""
var _max_time := 1.0
var _was_running := false   # a client's first frames have running=false, time_left=0 until the first snapshot
var _last_sec := -1
var _target_hit := false
var _last_served := 0
var _last_orders_key := ""
var _pay := 0
var _event_banner: HudEventBanner
var _mods: HudModChips   # difficulty + modifier chips under the coins card


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay = Control.new()
	UI.full_rect(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_rail = HudOrderRail.new()
	add_child(_rail)
	_build_stats()
	_mods = HudModChips.new()
	add_child(_mods)
	_build_timer()
	_build_toasts()
	_build_prompt()
	_build_help()
	add_child(HudObjectives.new(_stats))   # campaign: objectives card, mission intro, training prompts
	_event_banner = HudEventBanner.new()   # shift events: "ev_*" banners, inspector countdown
	add_child(_event_banner)
	Net.event_received.connect(_on_event)


# ================================================================ construction

func _hud_card(fill := UITheme.CREAM, mx := 14, my := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UITheme.box(fill, UITheme.INK, 14, 4, 5)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my + 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _build_stats() -> void:
	_stats = _hud_card()
	_stats.anchor_left = 0.0
	_stats.anchor_right = 0.0
	_stats.offset_left = CORNER
	_stats.offset_top = CORNER
	_stats.offset_right = CORNER
	_stats.custom_minimum_size = Vector2(216, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_stats.add_child(v)
	_shift_cap = UIKit.caption("")
	_shift_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # "Mission 12: The Grand Opening" wraps instead of clipping
	_shift_cap.custom_minimum_size = Vector2(1, 0)
	v.add_child(_shift_cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_coins = UIKit.coin_chip(0)
	row.add_child(_coins)
	var team := UIKit.caption("team coins")
	team.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(team)
	v.add_child(row)
	_goal_bar = UIKit.progress(0.0, 188, 16, false)
	_goal_bar.fill_color = UITheme.MUSTARD
	_goal_bar.set_fraction(0.0)
	v.add_child(_goal_bar)
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 6)
	_goal_lbl = UIKit.body("0 / 0")
	_goal_lbl.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	_goal_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nums.add_child(_goal_lbl)
	_count_lbl = UIKit.caption("")
	nums.add_child(_count_lbl)
	v.add_child(nums)
	add_child(_stats)


func _build_timer() -> void:
	_timer_card = _hud_card(UITheme.CREAM, 16, 8)
	_timer_card.anchor_left = 1.0
	_timer_card.anchor_right = 1.0
	_timer_card.offset_left = -CORNER
	_timer_card.offset_right = -CORNER
	_timer_card.offset_top = CORNER
	_timer_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_timer_card.custom_minimum_size = Vector2(132, 0)
	_timer_sb_normal = _timer_card.get_theme_stylebox("panel") as StyleBoxFlat
	_timer_sb_urgent = _timer_sb_normal.duplicate() as StyleBoxFlat
	_timer_sb_urgent.bg_color = UITheme.TOMATO
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_timer_card.add_child(v)
	var cap := UIKit.caption("TIME LEFT")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.name = "Cap"
	v.add_child(cap)
	_timer_lbl = UIKit.number("0:00")
	_timer_lbl.add_theme_font_size_override("font_size", UITheme.S_TITLE)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_timer_lbl)
	_timer_bar = UIKit.progress(1.0, 100, 10, true)
	v.add_child(_timer_bar)
	add_child(_timer_card)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -220
	_toasts.offset_right = 220
	_toasts.offset_top = _rail.rail_bottom() + 14
	add_child(_toasts)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.theme_type_variation = "ChipPanel"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_bottom = -26
	_prompt.offset_top = -26
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_row = HBoxContainer.new()
	_prompt_row.add_theme_constant_override("separation", 22)
	_prompt.add_child(_prompt_row)
	_prompt.visible = false
	add_child(_prompt)


func _key_row(key: String, text: String) -> HBoxContainer:
	var h := UIKit.key_hint(key, text)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	var cap := h.get_child(0) as Control
	cap.custom_minimum_size = Vector2(64, 28)
	(h.get_child(1) as Label).add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	return h


func _build_help() -> void:
	_help = _hud_card(UITheme.CREAM, 12, 8)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = CORNER
	_help.offset_right = CORNER
	_help.offset_top = -CORNER - 6
	_help.offset_bottom = -CORNER - 6
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_help.add_child(v)
	v.add_child(_key_row("WASD", "Move"))
	v.add_child(_key_row("LMB", "Grab / drop"))
	v.add_child(_key_row("RMB", "Work (hold)"))
	_help_space = _key_row("Space", "Punch")
	_help_space.visible = false
	v.add_child(_help_space)
	v.add_child(_key_row("MMB", "Ping"))
	v.add_child(_key_row("Esc", "Pause"))
	v.add_child(_key_row("H", "Hide help"))
	add_child(_help)

	_help_chip = PanelContainer.new()
	_help_chip.theme_type_variation = "ChipPanel"
	_help_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_chip.anchor_top = 1.0
	_help_chip.anchor_bottom = 1.0
	_help_chip.offset_left = CORNER
	_help_chip.offset_right = CORNER
	_help_chip.offset_top = -CORNER - 6
	_help_chip.offset_bottom = -CORNER - 6
	_help_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help_chip.add_child(UIKit.key_hint("H", "Help"))
	_help_chip.visible = false
	add_child(_help_chip)


func toggle_help() -> void:
	_help_shown = not _help_shown
	_help.visible = _help_shown
	_help_chip.visible = not _help_shown
	UIKit.pop_in(_help if _help_shown else _help_chip)


# ================================================================ events / toasts

func _on_event(text: String, sfx: String) -> void:
	if not visible:
		return
	if sfx == "serve":
		var m := RegEx.create_from_string("\\+(\\d+)").search(text)
		if m != null:
			_pay = int(m.get_string(1))
	if text.is_empty() or sfx == "start" or sfx == "order" or sfx == "ping":
		return
	if sfx.begins_with("ev_"):
		return   # shift events: HudEventBanner shows these
	var kind := "info"
	match sfx:
		"serve", "buy":
			kind = "success"
		"fail":
			kind = "error"
		"buzz":
			kind = "warn"
	_toast(text, kind)


func _toast(text: String, kind: String, seconds := 2.6) -> void:
	var t := UIKit.toast(_toasts, text, kind, seconds)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()


# ================================================================ per-frame

func _process(_delta: float) -> void:
	var t := Prof.t0()
	_frame(_delta)
	Prof.add(&"hud", t)


func _frame(_delta: float) -> void:
	# Results / shop have their own full-screen cards; the HUD behind them only clutters.
	modulate.a = 1.0 if Net.phase == Net.Phase.PLAYING else 0.0
	if world == null or not is_instance_valid(world):
		return
	_event_banner.world = world
	var s := world.shift
	var key := "%d:%d" % [world.get_instance_id(), s.index]
	var fresh := key != _shift_key or (s.running and not _was_running)
	_was_running = s.running
	if fresh:
		_new_shift(key, s)
	if s.time_left > _max_time:
		_max_time = s.time_left

	# Toasts hang under the tallest ticket (two chip rows are taller than one).
	_toasts.offset_top = lerpf(_toasts.offset_top, _rail.rail_bottom() + 14.0, 0.25)
	_update_stats(s)
	_update_mods(s)
	_update_timer(s)
	_update_prompt()
	if _help_space.visible != s.has_upgrade("gloves"):
		_help_space.visible = s.has_upgrade("gloves")

	var plate: Array = world.plate.stack if world.plate != null else []
	var served_delta := maxi(0, s.served - _last_served)
	_last_served = s.served
	var ords: Array = world.orders.orders
	_rail.sync_orders(ords, plate, served_delta, _pay, fresh)
	if served_delta > 0:
		_pay = 0
	_overlay.queue_redraw()


func _new_shift(key: String, s: ShiftManager) -> void:
	_shift_key = key
	_max_time = maxf(s.time_left, 1.0)
	_last_sec = -1
	_target_hit = s.target() > 0 and s.earned >= s.target()
	_last_served = s.served
	_kill_timer_pulse()
	if s.running and s.time_left > 0.0:
		_show_banner(s)


func _update_stats(s: ShiftManager) -> void:
	if str(s.def.get("mode", "")) == "campaign":
		_shift_cap.text = "Mission %d: %s" % [int(s.def.get("mission_id", 0)) + 1, s.shift_name()]
	else:
		_shift_cap.text = "Shift %d: %s" % [s.index + 1, s.shift_name()]
	_coins.set_amount(s.coins)
	var tgt := maxi(s.target(), 1)
	var frac := clampf(float(s.earned) / float(tgt), 0.0, 1.0)
	var reached := s.target() > 0 and s.earned >= s.target()
	_goal_bar.fill_color = UITheme.LETTUCE if reached else UITheme.MUSTARD
	_goal_bar.set_fraction(frac)
	_goal_lbl.text = "Goal reached!" if reached else "%d / %d" % [maxi(s.earned, 0), s.target()]
	var cnt := "%d served" % s.served
	if s.failed > 0:
		cnt += "  %d failed" % s.failed
	_count_lbl.text = cnt
	if reached and not _target_hit:
		_target_hit = true
		_celebrate()
	elif not reached:
		_target_hit = false


## Chips under the coins card (difficulty when not normal + active modifiers).
func _update_mods(s: ShiftManager) -> void:
	_mods.sync(s.def)
	_mods.custom_minimum_size.x = maxf(_stats.size.x, 216.0)
	_mods.size.x = _mods.custom_minimum_size.x
	_mods.position = Vector2(CORNER, _stats.position.y + _stats.size.y + 12.0)


## Y under the tallest order ticket (event cards and toasts stay below it).
func rail_bottom() -> float:
	return _rail.rail_bottom()


## Y of the bottom of the left-hand stack (coins card, then the chips); the objectives card sits under it.
func left_stack_bottom() -> float:
	if _mods != null and _mods.visible:
		return _mods.position.y + _mods.size.y
	return _stats.position.y + _stats.size.y


## One line naming the map's hazards ("Watch out: wind gusts"), or "" when it has none. Static so the
## campaign MissionIntro can show the same line.
static func hazard_hint(map: Dictionary, def: Dictionary) -> String:
	var texts: Array[String] = []
	var events: Array = def.get("events", [])
	for h in map.get("hazards", []):
		var id := str(h)
		if id == "cat_paw":
			if events.has("cat_paw"):
				texts.append("a sneaky cat paw")
		elif id == "wind":
			texts.append("wind gusts")
		elif id.contains("lurch"):
			texts.append("the truck lurches")
		else:
			texts.append(id.replace("_", " "))
	if texts.is_empty():
		return ""
	var line := ", ".join(texts)
	return "Watch out: " + line


func _celebrate() -> void:
	UIKit.punch(_stats, 0.06, 0.4)
	_toast("Shift target reached!", "success", 3.0)
	var origin := _goal_bar.global_position + _goal_bar.size * 0.5
	var cols := [UITheme.MUSTARD, UITheme.LETTUCE, UITheme.TOMATO, UITheme.SKY]
	for i in 18:
		var c := ColorRect.new()
		c.color = cols[i % cols.size()]
		c.size = Vector2(9, 9)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		c.global_position = origin
		c.pivot_offset = Vector2(4, 4)
		var ang := randf() * TAU
		var dist := randf_range(50.0, 130.0)
		var to := origin + Vector2(cos(ang), sin(ang) * 0.7) * dist + Vector2(0, 40)
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "global_position", to, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation", randf_range(-6.0, 6.0), 0.8)
		tw.tween_property(c, "modulate:a", 0.0, 0.3).set_delay(0.55)
		tw.chain().tween_callback(c.queue_free)


func _kill_timer_pulse() -> void:
	if _timer_pulse != null:
		_timer_pulse.kill()
		_timer_pulse = null
		_timer_card.scale = Vector2.ONE


func _update_timer(s: ShiftManager) -> void:
	_timer_lbl.text = UI.time_text(s.time_left)
	_timer_bar.set_fraction(s.time_left / _max_time)
	var sec := maxi(0, int(ceil(s.time_left)))
	var urgent := s.running and s.time_left < 30.0 and s.time_left > 0.0
	var cap := _timer_card.find_child("Cap", true, false) as Label
	var cur := _timer_card.get_theme_stylebox("panel")
	var want: StyleBoxFlat = _timer_sb_urgent if urgent else _timer_sb_normal
	if cur != want:
		_timer_card.add_theme_stylebox_override("panel", want)
		var tone := UITheme.CREAM if urgent else UITheme.INK
		_timer_lbl.add_theme_color_override("font_color", tone)
		cap.add_theme_color_override("font_color", UITheme.CREAM_DIM if urgent else UITheme.INK_SOFT)
		if not urgent:
			_kill_timer_pulse()
	if urgent and sec != _last_sec:
		if s.time_left <= 10.0:
			_kill_timer_pulse()
			UIKit.punch(_timer_card, 0.14, 0.3)
		elif _timer_pulse == null:
			_timer_pulse = UIKit.pulse(_timer_card, 0.04, 1.2)
	_last_sec = sec


# ================================================================ prompt

## world.hint_text (written by HintSystem in the old key wording, e.g. "E: grab Cheese     hold F: chop")
## -> [[key, text], ...] in the new scheme: grab/drop = LMB, work = RMB, punch = Space.
static func parse_hint(t: String) -> Array:
	var out: Array = []
	for part in t.split("     ", false):
		var p := part.strip_edges()
		if p.is_empty():
			continue
		var hold := false
		if p.begins_with("hold "):
			hold = true
			p = p.substr(5)
		var key := ""
		var rest := p
		var ci := p.find(": ")
		if ci > 0 and ci <= 3:
			match p.substr(0, ci):
				"E":
					key = "LMB"
				"F":
					key = "RMB"
				"Q":
					key = "Space"
				_:
					key = p.substr(0, ci)
			rest = p.substr(ci + 2).strip_edges()
		rest = rest.replace("   ", " ")
		if rest.is_empty():
			continue
		rest = rest.substr(0, 1).to_upper() + rest.substr(1)
		if hold:
			rest += " (hold)"
		out.append([key, rest])
	return out


func _update_prompt() -> void:
	var t := world.hint_text
	if t == _prompt_key:
		return
	_prompt_key = t
	for c in _prompt_row.get_children():
		_prompt_row.remove_child(c)
		c.queue_free()
	var parts := parse_hint(t)
	if parts.is_empty():
		_prompt.visible = false
		return
	for pr in parts:
		if str(pr[0]).is_empty():
			_prompt_row.add_child(UIKit.body(str(pr[1])))
		else:
			_prompt_row.add_child(UIKit.key_hint(str(pr[0]), str(pr[1])))
	if not _prompt.visible:
		_prompt.visible = true
		UIKit.pop_in(_prompt)


# ================================================================ banner

func _show_banner(s: ShiftManager) -> void:
	if str(s.def.get("mode", "")) == "campaign":
		return   # HudObjectives shows the MissionIntro card instead
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	var p := _hud_card(UITheme.CREAM, 34, 16)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.4
	p.anchor_bottom = 0.4
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UIKit.title("Shift %d" % (s.index + 1)))
	var h := UIKit.heading(s.shift_name())
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(UIKit.body("Earn"))
	row.add_child(UIKit.coin_chip(s.target()))
	v.add_child(row)
	var hz := hazard_hint(world.map, s.def) if world != null else ""
	if not hz.is_empty():
		var hl := UIKit.caption(hz)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.add_theme_color_override("font_color", UITheme.TOMATO_DARK)
		v.add_child(hl)
	add_child(p)
	_banner = p
	UIKit.pop_in(p, 0.0, 0.3)
	var tw := p.create_tween()
	tw.tween_interval(2.8)
	tw.tween_callback(func() -> void: UIKit.pop_out(p, true))


# ================================================================ world-space bars

## Cook/chop bars now live in IndicatorLayer (world/indicators/), projected under the HUD.
func _draw_overlay() -> void:
	pass
