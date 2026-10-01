class_name MissionIntro
extends PanelContainer
## Campaign shift start: a centred card with the mission number, name, blurb, map and objectives.
## Pops out after SECONDS or when clicked. Replaces the plain shift banner in campaign mode.

const SECONDS := 3.0

var _closing := false


func _init(s: ShiftManager) -> void:
	var sb := UITheme.box(UITheme.CREAM, UITheme.INK, 16, 4, 6)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.42
	anchor_bottom = 0.42
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var d := s.def
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var id := int(d.get("mission_id", 0))
	var cap := UIKit.caption("MISSION %d OF %d" % [id + 1, Missions.count()])
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	v.add_child(UIKit.title(str(d.get("name", ""))))
	var blurb := UIKit.body(str(d.get("blurb", "")))
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(440, 0)
	v.add_child(blurb)
	var map_id := str(d.get("map", ""))
	var m: Dictionary = GameData.MAPS.get(map_id, {})
	var map_lbl := UIKit.caption("Map: %s" % str(m.get("name", map_id.capitalize())))
	map_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(map_lbl)
	var line := ColorRect.new()
	line.color = UITheme.PAPER_OFF
	line.custom_minimum_size = Vector2(0, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var goals := VBoxContainer.new()
	goals.add_theme_constant_override("separation", 6)
	goals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for e in s.objectives:
		var row := ObjectiveRow.new(0.0, UITheme.S_BODY)
		row.set_entry(e)
		row.prog_lbl.text = ""
		goals.add_child(row)
	var stars := HBoxContainer.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", 14)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_child(goals)
	v.add_child(stars)
	var hint := UIKit.caption("Each objective is a star. Click to close.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _ready() -> void:
	UIKit.pop_in(self, 0.0, 0.3)
	var tw := create_tween()
	tw.tween_interval(SECONDS)
	tw.tween_callback(close)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.pop_out(self, true)
