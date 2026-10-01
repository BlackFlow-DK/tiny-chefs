class_name LobbySettingsPanel
extends PanelContainer
## The lobby's game-settings card. The host picks mode (Campaign / Endless / Custom), map, difficulty,
## modifiers and, for Custom, the shift numbers; clients see the same card read-only and it follows
## `Net.settings_changed` live. All changes go through Net.change_setting (the host; clients are ignored there).

const SLIDERS := [
	# key, label, min, max, step, key step
	["duration", "Shift length", 60.0, 600.0, 15.0, 15.0],
	["interval", "Order every", 8.0, 120.0, 1.0, 2.0],
	["patience", "Customer patience", 30.0, 300.0, 5.0, 10.0],
	["target", "Coin target (solo)", 0.0, 5000.0, 5.0, 25.0],
]
const MODE_INFO := {
	"campaign": {"name": "Campaign", "blurb": "Missions and stars"},
	"endless": {"name": "Endless", "blurb": "Ever harder shifts"},
	"custom": {"name": "Custom", "blurb": "Set every number"},
}
const DIFF_TONES := {"easy": UITheme.LETTUCE, "normal": UITheme.SKY, "hard": UITheme.MUSTARD, "chaos": UITheme.TOMATO}

var _editable := true
var _note: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _mode_btns := {}
var _sec_campaign: VBoxContainer
var _sec_pick: VBoxContainer
var _sec_custom: VBoxContainer
var _mission_scroll: ScrollContainer
var _mission_btns: Array = []
var _mission_detail: Label
var _map_btns := {}
var _diff_btns := {}
var _diff_desc: Label
var _mod_btns := {}
var _mod_desc: Label
var _hover_mod := ""
var _sliders := {}
var _slider_vals := {}
var _dish_btns := {}
var _dish_count: Label
var _pending := {}
var _timer: Timer
var _last_mode := ""
var _last_mission := -1


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	head.add_child(UIKit.heading("Shift settings"))
	_note = UIKit.caption("")
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_note)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	_build_modes(_content)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 120)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_style_scroll(_scroll)
	_content.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 10)
	_scroll.add_child(pad)
	var sections := VBoxContainer.new()
	sections.add_theme_constant_override("separation", 14)
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(sections)
	_build_campaign(sections)
	_build_pick(sections)
	_build_custom(sections)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.15
	_timer.timeout.connect(_flush)
	add_child(_timer)
	Net.settings_changed.connect(_sync)
	_sync()


## Pop-in when the lobby opens (the lobby is built hidden at startup).
func replay_intro() -> void:
	_sync()
	UIKit.pop_in(self, 0.1, 0.22)


# ---------------------------------------------------------------- building

static func _h(text: String) -> Label:
	var l := UIKit.heading(text)
	l.add_theme_font_size_override("font_size", UITheme.S_BODY)
	return l


static func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _style_scroll(sc: ScrollContainer) -> void:
	for bar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		var b: ScrollBar = bar
		var track := UITheme.box(Color(UITheme.INK, 0.12), Color(0, 0, 0, 0), 999, 0)
		track.set_content_margin_all(7)  # without margins the bar collapses to zero width
		b.add_theme_stylebox_override("scroll", track)
		for g in ["grabber", "grabber_highlight", "grabber_pressed"]:
			b.add_theme_stylebox_override(g, UITheme.box(UITheme.INK_SOFT, UITheme.INK, 999, 2))


func _build_modes(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	for id in GameSettings.MODES:
		var info: Dictionary = MODE_INFO[id]
		var b := LobbyChoice.new(Vector2(0, 92))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(LobbyIcon.new(id, Vector2(46, 46)))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(UIKit.heading(str(info["name"])))
		var blurb := str(info["blurb"])
		if id == "campaign":
			blurb = "%d missions, stars" % Missions.count()
		var bl := _wrap(UIKit.caption(blurb))
		b.track_label(bl, UITheme.INK_SOFT)
		col.add_child(bl)
		h.add_child(col)
		b.set_body(h, 10)
		b.pressed.connect(_on_mode.bind(id))
		row.add_child(b)
		_mode_btns[id] = b


func _build_campaign(parent: Control) -> void:
	_sec_campaign = VBoxContainer.new()
	_sec_campaign.add_theme_constant_override("separation", 8)
	parent.add_child(_sec_campaign)
	_sec_campaign.add_child(_h("Mission (the run plays on from your pick)"))
	_mission_scroll = ScrollContainer.new()
	_mission_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mission_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_mission_scroll.follow_focus = true
	_mission_scroll.custom_minimum_size = Vector2(0, LobbyMissionCard.SIZE.y + 34)
	_style_scroll(_mission_scroll)
	_sec_campaign.add_child(_mission_scroll)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_left", 6)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	_mission_scroll.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)
	for i in Missions.count():
		var unlocked := _is_unlocked(i)
		var b := LobbyMissionCard.make(i, _stars(i), not unlocked)
		b.pressed.connect(_on_mission.bind(i))
		row.add_child(b)
		_mission_btns.append(b)
	_mission_detail = _wrap(UIKit.caption(""))
	_sec_campaign.add_child(_mission_detail)


func _build_pick(parent: Control) -> void:
	_sec_pick = VBoxContainer.new()
	_sec_pick.add_theme_constant_override("separation", 8)
	parent.add_child(_sec_pick)
	_sec_pick.add_child(_h("Map"))
	var maps := GridContainer.new()   # 3 per row, each card shares the row width so the blurbs wrap in 3-4 lines
	maps.columns = 3
	maps.add_theme_constant_override("h_separation", 12)
	maps.add_theme_constant_override("v_separation", 14)
	_sec_pick.add_child(maps)
	for id in GameData.map_ids():
		var info := GameData.map(str(id))
		var b := LobbyChoice.new(Vector2(0, 236))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		var pv := LobbyIcon.new("map", Vector2(0, 84), str(id))
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(pv)
		v.add_child(_wrap(UIKit.body(str(info.get("name", id)))))
		var bl := _wrap(UIKit.caption(str(info.get("blurb", ""))))
		b.track_label(bl, UITheme.INK_SOFT)
		v.add_child(bl)
		b.set_body(v, 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_map.bind(str(id)))
		maps.add_child(b)
		_map_btns[str(id)] = b

	_sec_pick.add_child(_h("Difficulty"))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 10)
	_sec_pick.add_child(drow)
	for id in Difficulty.PRESET_IDS:
		var b := LobbyChoice.new(Vector2(0, 50), DIFF_TONES.get(id, UITheme.MUSTARD))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UIKit.heading(Difficulty.label(id))
		l.add_theme_font_size_override("font_size", UITheme.S_BODY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.set_body(l, 6)
		b.pressed.connect(_on_difficulty.bind(str(id)))
		drow.add_child(b)
		_diff_btns[str(id)] = b
	_diff_desc = _wrap(UIKit.caption(""))
	_sec_pick.add_child(_diff_desc)

	_sec_pick.add_child(_h("Modifiers"))
	var mods := HFlowContainer.new()
	mods.add_theme_constant_override("h_separation", 10)
	mods.add_theme_constant_override("v_separation", 14)
	_sec_pick.add_child(mods)
	for id in Difficulty.MODIFIER_IDS:
		var b := LobbyChoice.new(Vector2(0, 46), UITheme.LETTUCE)
		var l := UIKit.body(Difficulty.label(id))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.set_body(l, 8)
		b.custom_minimum_size.x = l.get_minimum_size().x + 36
		b.pressed.connect(_on_modifier.bind(str(id)))
		b.mouse_entered.connect(_hover.bind(str(id)))
		b.mouse_exited.connect(_hover.bind(""))
		b.focus_entered.connect(_hover.bind(str(id)))
		b.focus_exited.connect(_hover.bind(""))
		mods.add_child(b)
		_mod_btns[str(id)] = b
	_mod_desc = _wrap(UIKit.caption(""))
	_sec_pick.add_child(_mod_desc)


func _build_custom(parent: Control) -> void:
	_sec_custom = VBoxContainer.new()
	_sec_custom.add_theme_constant_override("separation", 8)
	parent.add_child(_sec_custom)
	_sec_custom.add_child(_h("Shift numbers"))
	for def in SLIDERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var l := UIKit.body(str(def[1]))
		l.custom_minimum_size = Vector2(232, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var s := LobbySlider.new()
		s.setup(def[2], def[3], def[4], def[5])
		s.value_changed.connect(_on_slider.bind(str(def[0])))
		row.add_child(s)
		var vl := UIKit.heading("")
		vl.add_theme_font_size_override("font_size", UITheme.S_BODY)
		vl.custom_minimum_size = Vector2(110, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(vl)
		_sec_custom.add_child(row)
		_sliders[str(def[0])] = s
		_slider_vals[str(def[0])] = vl
	_sec_custom.add_child(_h("Dishes on the menu"))
	var dishes := HFlowContainer.new()
	dishes.add_theme_constant_override("h_separation", 10)
	dishes.add_theme_constant_override("v_separation", 14)
	_sec_custom.add_child(dishes)
	for r in GameData.RECIPES:
		var id := str(r["id"])
		var b := LobbyChoice.new(Vector2(0, 46), UITheme.LETTUCE)
		var l := UIKit.body(str(r["name"]))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.set_body(l, 8)
		b.custom_minimum_size.x = l.get_minimum_size().x + 36
		b.pressed.connect(_on_dish.bind(id))
		dishes.add_child(b)
		_dish_btns[id] = b
	_dish_count = _wrap(UIKit.caption(""))
	_sec_custom.add_child(_dish_count)


# ---------------------------------------------------------------- Progress (local campaign stars)

func _is_unlocked(i: int) -> bool:
	return Progress.is_unlocked(i)


func _stars(i: int) -> int:
	return Progress.get_stars(i)


# ---------------------------------------------------------------- input (host only)

func _on_mode(id: String) -> void:
	if _editable:
		Net.change_setting("mode", id)
	_sync()


func _on_mission(i: int) -> void:
	if _editable:
		if _is_unlocked(i):
			Net.change_setting("mission", i)
		else:
			UIKit.shake(_mission_btns[i])
	_sync()


func _on_map(id: String) -> void:
	if _editable:
		Net.change_setting("map", id)
	_sync()


func _on_difficulty(id: String) -> void:
	if _editable:
		Net.change_setting("difficulty", id)
	_sync()


func _on_modifier(id: String) -> void:
	if _editable:
		var mods: Array = Array(Net.settings.modifiers)
		if mods.has(id):
			mods.erase(id)
		else:
			mods.append(id)
		var ordered: Array = []
		for m in Difficulty.MODIFIER_IDS:
			if mods.has(m):
				ordered.append(m)
		Net.change_setting("modifiers", ordered)
	_sync()


func _on_dish(id: String) -> void:
	if _editable:
		var have: Array = Array(Net.settings.recipes)
		if have.has(id):
			if have.size() <= 1:
				UIKit.shake(_dish_btns[id])
				_sync()
				return
			have.erase(id)
		else:
			have.append(id)
		var ordered: Array = []
		for r in GameData.RECIPES:
			if have.has(str(r["id"])):
				ordered.append(str(r["id"]))
		Net.change_setting("recipes", ordered)
	_sync()


func _on_slider(v: float, key: String) -> void:
	_update_slider_label(key, v)
	if not _editable:
		return
	_pending[key] = int(v) if key == "target" else v
	_timer.start()


func _flush() -> void:
	var keys := _pending.keys()
	var vals := _pending.duplicate()
	_pending.clear()
	for k in keys:
		Net.change_setting(str(k), vals[k])
	_sync()


func _hover(id: String) -> void:
	_hover_mod = id
	_update_mod_desc()


# ---------------------------------------------------------------- sync from Net.settings

func _sync() -> void:
	if not is_inside_tree() or _mode_btns.is_empty():
		return
	var s := Net.settings
	var edit := Net.can_edit_settings()
	if edit != _editable or _note.text.is_empty():
		_editable = edit
		_apply_editable()
	for id in _mode_btns:
		(_mode_btns[id] as LobbyChoice).select(id == s.mode)
	_sec_campaign.visible = s.mode == "campaign"
	_sec_pick.visible = s.mode != "campaign"
	_sec_custom.visible = s.mode == "custom"
	for i in _mission_btns.size():
		(_mission_btns[i] as LobbyChoice).select(i == s.mission)
	for id in _map_btns:
		(_map_btns[id] as LobbyChoice).select(id == s.map)
	for id in _diff_btns:
		(_diff_btns[id] as LobbyChoice).select(id == s.difficulty)
	_diff_desc.text = Difficulty.desc(s.difficulty)
	for id in _mod_btns:
		(_mod_btns[id] as LobbyChoice).select(s.modifiers.has(id))
	_update_mod_desc()
	var dict := s.to_dict()
	for k in _sliders:
		var sl: LobbySlider = _sliders[k]
		if _pending.has(k) or sl.dragging:
			continue
		sl.set_value_silent(float(dict[k]))
		_update_slider_label(k, sl.value)
	for id in _dish_btns:
		(_dish_btns[id] as LobbyChoice).select(s.recipes.has(id))
	_dish_count.text = "%d of %d dishes on the menu." % [s.recipes.size(), GameData.RECIPES.size()]
	_mission_detail.text = _mission_text(s.mission)
	if s.mode != _last_mode:
		if not _last_mode.is_empty():
			UIKit.pop_in(_sec_campaign if s.mode == "campaign" else _sec_pick, 0.0, 0.18)
			if s.mode == "custom":
				UIKit.pop_in(_sec_custom, 0.05, 0.18)
			_scroll.scroll_vertical = 0
		_last_mode = s.mode
	if s.mode == "campaign" and s.mission != _last_mission:
		_last_mission = s.mission
		_reveal_mission.call_deferred(s.mission)


func _reveal_mission(i: int) -> void:
	if i >= 0 and i < _mission_btns.size() and _mission_scroll.is_visible_in_tree():
		_mission_scroll.ensure_control_visible(_mission_btns[i])


func _apply_editable() -> void:
	_note.text = "You choose; everyone sees it live." if _editable else "Host is choosing..."
	_content.modulate = Color.WHITE if _editable else Color(1, 1, 1, 0.72)
	for group in [_mode_btns.values(), _mission_btns, _map_btns.values(), _diff_btns.values(), _mod_btns.values(), _dish_btns.values()]:
		for b in group:
			(b as LobbyChoice).set_editable(_editable)
	for sl in _sliders.values():
		(sl as LobbySlider).set_editable(_editable)


func _update_mod_desc() -> void:
	if _mod_desc == null:
		return
	if _hover_mod != "":
		_mod_desc.text = "%s: %s" % [Difficulty.label(_hover_mod), Difficulty.desc(_hover_mod)]
		return
	var on: Array = []
	for m in Net.settings.modifiers:
		on.append("%s (%s)" % [Difficulty.label(m), Difficulty.desc(m).trim_suffix(".")])
	if on.is_empty():
		_mod_desc.text = "No modifiers. Toggle any to change the rules." if _editable else "No modifiers."
	else:
		_mod_desc.text = "On: " + "; ".join(on)


func _update_slider_label(key: String, v: float) -> void:
	var l: Label = _slider_vals.get(key)
	if l == null:
		return
	match key:
		"duration":
			l.text = "%d:%02d" % [int(v) / 60, int(v) % 60]
		"target":
			l.text = "%d coins" % int(v)
		_:
			l.text = "%d s" % int(v)


static func objective_text(o: Dictionary) -> String:
	match str(o.get("type", "")):
		"no_burnt":
			return "Burn nothing"
		"no_expired":
			return "No orders expire"
		"earn":
			return "Earn %d coins" % int(o.get("n", 0))
		"serve_n":
			var idx := GameData.recipe_index(str(o.get("recipe", "")))
			var nm := str(GameData.RECIPES[idx]["name"]) if idx >= 0 else str(o.get("recipe", "?"))
			return "Serve %d %s" % [int(o.get("n", 0)), nm]
	return ""


func _mission_text(i: int) -> String:
	var m := Missions.get_mission(i)
	var goals: Array = ["%d coins" % int(m.get("target", 0))]
	for o in m.get("objectives", []):
		var t := objective_text(o)
		if not t.is_empty():
			goals.append(t)
	return "%s  Stars: %s" % [str(m.get("blurb", "")), "  |  ".join(goals)]


## One line for the lobby: "Endless · Picnic · Hard · Wind, Heavy hands".
static func summary(s: GameSettings) -> String:
	var parts: Array = []
	match s.mode:
		"campaign":
			var m := Missions.get_mission(s.mission)
			parts = ["Campaign", "Mission %d: %s" % [s.mission + 1, str(m.get("name", "?"))], LobbyMissionCard.map_name(str(m.get("map", "diner"))), Difficulty.label(str(m.get("difficulty", "normal")))]
			var mm: Array = []
			for x in m.get("modifiers", []):
				mm.append(Difficulty.label(str(x)))
			if not mm.is_empty():
				parts.append(", ".join(mm))
		_:
			parts = [s.mode.capitalize(), LobbyMissionCard.map_name(s.map), Difficulty.label(s.difficulty)]
			var ml: Array = []
			for x in s.modifiers:
				ml.append(Difficulty.label(x))
			if not ml.is_empty():
				parts.append(", ".join(ml))
			if s.mode == "custom":
				parts.append("%d:%02d, %d dishes" % [int(s.duration) / 60, int(s.duration) % 60, s.recipes.size()])
	return " · ".join(parts)

