class_name ResultsView
extends Control
## "Shift complete!" / "Shift failed": hero title, a receipt card with counting coins, stars and a
## stamp, then one button to the shop (host) or a waiting note (clients).

var _built := false
var _button: Button
var _tween: Tween


func _init() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func stars_for(earned: int, target: int) -> int:
	if earned < target:
		return 0
	if target > 0 and earned >= int(target * 1.5):
		return 3
	if target > 0 and earned >= int(target * 1.25):
		return 2
	return 1


func _row(label: String, value: Label) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UIKit.body(label)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(value)
	return h


## Campaign: each objective's outcome (tick / cross), then what comes next: retry, the next mission and
## its map, or the end of the campaign.
func _add_mission_outcome(box: VBoxContainer, info: Dictionary, met: bool) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var objs: Array = info.get("objectives", [])
	for i in objs.size():
		var row := ObjectiveRow.new(170.0)
		row.set_entry(objs[i])
		row.modulate.a = 0.0
		UIKit.pop_in(row, 1.0 + 0.18 * i, 0.2)
		list.add_child(row)
	box.add_child(list)
	var nxt := int(info.get("next_mission", -1))
	var text := "Same mission again. You've got this."
	if met and nxt < 0:
		text = "Campaign complete! Every mission cleared."
	elif met:
		var m := Missions.get_mission(nxt)
		var map_def: Dictionary = GameData.MAPS.get(str(m["map"]), {})
		text = "Next mission: %s (%s)" % [m["name"], map_def.get("name", str(m["map"]).capitalize())]
	var l := UIKit.body(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(250, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _line() -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.PAPER_OFF
	r.custom_minimum_size = Vector2(0, 3)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Rebuilds the whole screen from the phase info and plays the reveal.
func show_results(info: Dictionary) -> void:
	if _tween != null:
		_tween.kill()
	for c in get_children():
		c.queue_free()
	var met := bool(info.get("met", false))
	var earned := int(info.get("earned", 0))
	var target := int(info.get("target", 0))
	var stars := stars_for(earned, target)
	var campaign := info.has("stars")   # campaign mission (ObjectiveSystem.finish): stars come from the objectives
	if campaign:
		stars = int(info["stars"])
	var accent := UITheme.LETTUCE if met else UITheme.TOMATO

	add_child(UIKit.backdrop(0.72))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var hero := Label.new()
	hero.text = "Shift complete!" if met else "Shift failed"
	if campaign:
		hero.text = "Mission complete!" if met else "Mission failed"
	hero.theme_type_variation = "HeroLabel"
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not met:
		hero.add_theme_color_override("font_color", UITheme.TOMATO)
	col.add_child(hero)

	var cv := UIKit.card(10)
	var card: PanelContainer = cv[0]
	var body: VBoxContainer = cv[1]
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 28)
	body.add_child(split)

	# Left: the receipt.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 8)
	left.add_child(UIKit.heading("Mission %d" % (int(info.get("mission", 0)) + 1) if campaign else "Shift %d" % (int(info.get("shift", 0)) + 1)))
	left.add_child(UIKit.caption(str(info.get("name", ""))))
	left.add_child(_line())
	var served := UIKit.number(str(int(info.get("served", 0))))
	var failed := UIKit.number(str(int(info.get("failed", 0))))
	if int(info.get("failed", 0)) > 0:
		failed.add_theme_color_override("font_color", UITheme.TOMATO_DARK)
	left.add_child(_row("Orders served", served))
	left.add_child(_row("Orders failed", failed))
	left.add_child(_line())
	var earn_row := HBoxContainer.new()
	earn_row.add_theme_constant_override("separation", 10)
	var earn_l := UIKit.body("Coins earned")
	earn_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	earn_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	earn_row.add_child(earn_l)
	earn_row.add_child(UIKit.dot(UITheme.MUSTARD, 30))
	var earn_n := UIKit.number("+0")
	earn_n.add_theme_font_size_override("font_size", UITheme.S_TITLE)
	earn_n.custom_minimum_size = Vector2(96, 0)
	earn_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	earn_row.add_child(earn_n)
	left.add_child(earn_row)
	left.add_child(_row("Target", UIKit.number(str(target))))
	left.add_child(_line())
	var wallet := HBoxContainer.new()
	var wl := UIKit.caption("Team wallet")
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet.add_child(wl)
	wallet.add_child(UIKit.coin_chip(int(info.get("coins", 0))))
	left.add_child(wallet)
	split.add_child(left)

	# Right: stars and the stamp.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 18)
	var star_row := HBoxContainer.new()
	star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	star_row.add_theme_constant_override("separation", 6)
	var star_nodes: Array = []
	for i in 3:
		var s := ResultsStar.new(64)
		star_nodes.append(s)
		star_row.add_child(s)
	right.add_child(star_row)
	var stamp_box := Control.new()
	stamp_box.custom_minimum_size = Vector2(250, 96)
	stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamp := PanelContainer.new()
	stamp.add_theme_stylebox_override("panel", UITheme.box(UITheme.CREAM_HI, accent, 12, 6))
	var st := UIKit.number("TARGET MET" if met else "MISSED")
	st.add_theme_color_override("font_color", accent.darkened(0.25))
	st.add_theme_font_size_override("font_size", 34)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_child(st)
	stamp_box.add_child(stamp)
	stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stamp.grow_vertical = Control.GROW_DIRECTION_BOTH
	right.add_child(stamp_box)
	if campaign:
		_add_mission_outcome(right, info, met)
	elif not met:
		right.add_child(UIKit.caption("Same shift again. You've got this."))
	else:
		right.add_child(UIKit.caption("On to the next shift!"))
	split.add_child(right)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var stats_info: Dictionary = info.get("stats", {})
	var mvp := _mvp_card(stats_info)
	var mid: Control = card
	if mvp != null:
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 20)
		cards.alignment = BoxContainer.ALIGNMENT_CENTER
		cards.add_child(card)
		cards.add_child(mvp)
		mid = cards
	col.add_child(mid)

	# Button / waiting note.
	var foot := CenterContainer.new()
	foot.custom_minimum_size = Vector2(0, 64)
	if Net.is_host:
		# no_shop (ModifierSystem): straight into the next shift.
		var label := "Start next shift" if ModifierSystem.skip_shop() else "Go to the shop"
		_button = UIKit.button(label, func() -> void: Net.set_phase(ModifierSystem.after_results_phase(), Net.phase_info), "primary", 320)
		foot.add_child(_button)
	else:
		_button = null
		var chip := PanelContainer.new()
		chip.theme_type_variation = "DarkChipPanel"
		chip.add_child(UIKit.body("Waiting for the host...", "dark"))
		foot.add_child(chip)
	col.add_child(foot)
	add_child(UI.centred(col))

	_agent_shot()

	# Reveal choreography.
	hero.modulate.a = 0.0
	card.modulate.a = 0.0
	foot.modulate.a = 0.0
	stamp.modulate.a = 0.0
	UIKit.pop_in(hero, 0.0, 0.3)
	UIKit.pop_in(card, 0.2, 0.2)
	if mvp != null:
		mvp.modulate.a = 0.0
		UIKit.pop_in(mvp, 0.45, 0.2)
	UIKit.pop_in(foot, 1.7, 0.2)
	if _button != null:
		_button.grab_focus.call_deferred()
	var count_time := clampf(0.4 + earned / 250.0, 0.6, 1.4)
	_tween = create_tween()
	_tween.tween_interval(0.55)
	var last := [-1]
	var step := maxf(1.0, earned / 12.0)
	_tween.tween_method(func(v: float) -> void:
		earn_n.text = "+%d" % int(v)
		var bucket := int(v / step)
		if bucket != last[0]:
			last[0] = bucket
			UIKit.punch(earn_n, 0.08, 0.1), 0.0, float(earned), count_time)
	_tween.tween_callback(func() -> void: earn_n.text = "+%d" % earned)
	for i in stars:
		_tween.tween_callback(func() -> void:
			var s: ResultsStar = star_nodes[i]
			s.filled = true
			UIKit.punch(s, 0.35, 0.28))
		_tween.tween_interval(0.16)
	_tween.tween_callback(func() -> void:
		stamp.modulate.a = 1.0
		stamp.pivot_offset = stamp.size / 2.0
		stamp.rotation = -0.13
		stamp.scale = Vector2(2.4, 2.4)
		var tw := stamp.create_tween()
		tw.tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: UIKit.punch(card, 0.025, 0.2)))


## Agent helper: --results-shot=<png> saves the viewport 2.8 s after the results appear ("{role}" -> host|client).
func _agent_shot() -> void:
	var path := Net.arg_str("results-shot", "")
	if path.is_empty():
		return
	path = path.replace("{role}", "host" if Net.is_host else "client")
	get_tree().create_timer(2.8).timeout.connect(func() -> void:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		print("screenshot: results saved %s (%s)" % [path, error_string(img.save_png(path))]))


# ---------------------------------------------------------------- MVP card (stats)

const AWARDS := [
	# [title, stat column in a player row, icon, colour, wink shown under the title]
	["Top server", 3, "server", UITheme.MUSTARD, "rang the bell"],
	["Pack mule", 4, "mule", UITheme.SKY, "carried the most"],
	["Team player", 5, "team", UITheme.LETTUCE, "carried together"],
	["Butterfingers", COL_DROPPED, "butter", UITheme.TOMATO, "it slipped, honest"],
]
## Player row: [id, name, slot, served, carried, assists, burnt, dropped, falls, punches, coins].
const COL_SERVED := 3
const COL_CARRIED := 4
const COL_DROPPED := 7
const COL_FALLS := 8


func _mvp_card(st: Dictionary) -> Control:
	var shift_rows: Array = st.get("players", [])
	var run_rows: Array = st.get("run", [])
	if run_rows.is_empty():
		return null
	var solo := run_rows.size() < 2
	var cv := UIKit.card(8)
	var card: PanelContainer = cv[0]
	var body: VBoxContainer = cv[1]
	body.custom_minimum_size = Vector2(0 if solo else 480, 0)
	body.add_child(UIKit.heading("Chef stats" if solo else "MVP"))
	if not solo:
		body.add_child(UIKit.caption("This shift"))
		for a in AWARDS:
			body.add_child(_award_row(a, shift_rows))
		body.add_child(_line())
	body.add_child(UIKit.caption("Whole run so far"))
	body.add_child(_run_table(run_rows))
	return card


## The colour the player picked in the lobby; a player who already left falls back to their slot colour.
## Player row: [id, name, slot, ...].
func _player_colour(r: Array) -> Color:
	var id := int(r[0])
	if Net.players.has(id):
		return Net.color_of(id)
	return UIKit.player_color(int(r[2]))


func _col(rows: Array, col: int) -> int:
	var best := -1
	var idx := -1
	for i in rows.size():
		var v := int(rows[i][col])
		if v > best:
			best = v
			idx = i
	return idx


func _award_row(a: Array, rows: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(StatsIcon.new(str(a[2]), 34, a[3]))
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.custom_minimum_size = Vector2(150, 0)
	t.add_child(UIKit.body(str(a[0])))
	t.add_child(UIKit.caption(str(a[4])))
	h.add_child(t)
	var who := Control.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.custom_minimum_size = Vector2(0, 1)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(who)
	var i := _col(rows, int(a[1]))
	if i < 0 or int(rows[i][int(a[1])]) <= 0:
		h.add_child(UIKit.caption("nobody" if int(a[1]) != COL_DROPPED else "clean hands!"))
		return h
	var r: Array = rows[i]
	h.add_child(UIKit.player_badge(str(r[1]), _player_colour(r)))
	var n := UIKit.number(str(int(r[int(a[1])])))
	n.custom_minimum_size = Vector2(48, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


func _run_table(rows: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 4)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(spacer)
	for h in ["Served", "Carried", "Dropped", "Falls"]:
		var l := UIKit.caption(h)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size = Vector2(72, 0)
		g.add_child(l)
	for r in rows:
		var b := UIKit.player_badge(str(r[1]), _player_colour(r))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		g.add_child(b)
		for c in [COL_SERVED, COL_CARRIED, COL_DROPPED, COL_FALLS]:
			var l := UIKit.body(str(int(r[c])))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.custom_minimum_size = Vector2(72, 0)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(l)
	return g
