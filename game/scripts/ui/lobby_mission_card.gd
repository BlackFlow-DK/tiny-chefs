class_name LobbyMissionCard
extends RefCounted
## Builds one campaign mission card (a LobbyChoice) and the small chips it uses.

const SIZE := Vector2(176, 212)
const DIFF_COLORS := {"easy": UITheme.LETTUCE, "normal": UITheme.SKY, "hard": UITheme.MUSTARD, "chaos": UITheme.TOMATO}


## Display name of a map id; maps that are not in GameData.MAPS yet show a prettified id (no warning).
static func map_name(id: String) -> String:
	if GameData.MAPS.has(id):
		return str((GameData.MAPS[id] as Dictionary).get("name", id))
	return id.replace("_", " ").capitalize()


## Pill with ink outline; `col` = fill. Text is caption sized.
static func chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.box(col, UITheme.INK, 999, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := UIKit.caption(text)
	l.add_theme_color_override("font_color", UITheme.INK)
	p.add_child(l)
	return p


static func difficulty_chip(id: String) -> PanelContainer:
	return chip(Difficulty.label(id), DIFF_COLORS.get(id, UITheme.SKY))


## i = mission index; stars 0..3 earned (0 when Progress does not exist yet); locked = cosmetic padlock look.
static func make(i: int, stars: int, locked: bool) -> LobbyChoice:
	var m := Missions.get_mission(i)
	var b := LobbyChoice.new(SIZE)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var num := UIKit.heading("#%d" % (i + 1))
	num.add_theme_font_size_override("font_size", UITheme.S_BODY)
	head.add_child(num)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if locked:
		head.add_child(LobbyIcon.new("lock", Vector2(26, 26)))
	v.add_child(head)
	var name := UIKit.body(str(m.get("name", "?")))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(1, 50)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name)
	var mname := map_name(str(m.get("map", "diner")))
	var mc := UIKit.caption(mname)
	b.track_label(mc, UITheme.INK_SOFT)
	v.add_child(mc)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 4)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.add_child(difficulty_chip(str(m.get("difficulty", "normal"))))
	for mod in m.get("modifiers", []):
		chips.add_child(chip(Difficulty.label(str(mod)), UITheme.CREAM))
	v.add_child(chips)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grow)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 4)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in 3:
		var star := LobbyIcon.new("star", Vector2(28, 28))
		star.set_filled(s < stars)
		st.add_child(star)
	v.add_child(st)
	b.set_body(v, 10)
	if locked:
		b.modulate = Color(1, 1, 1, 0.55)
	return b
