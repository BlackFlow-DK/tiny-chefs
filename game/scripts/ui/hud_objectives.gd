class_name HudObjectives
extends Control
## Campaign HUD layer (mounted by Hud, every peer): the objectives card under the coins card (live from
## world.shift.objectives, replicated in the shift meta), the MissionIntro card when a campaign shift starts,
## and the Training step prompt (mission 0) above the context prompt. Inert outside campaign shifts.

var _anchor: Control          # Hud's coins card; the objectives card sits under it
var _card: PanelContainer
var _list: VBoxContainer
var _rows: Array = []         # ObjectiveRow per entry
var _sig := ""
var _intro: MissionIntro = null
var _was_running := false
var _world_id := 0
var _train: Training = null
var _train_card: PanelContainer
var _train_step := -1


func _init(anchor: Control) -> void:
	_anchor = anchor


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	var sb := UITheme.box(UITheme.CREAM, UITheme.INK, 14, 4, 5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", sb)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_card.add_child(v)
	v.add_child(UIKit.caption("OBJECTIVES"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	v.add_child(_list)
	_card.visible = false
	add_child(_card)

	_train_card = PanelContainer.new()
	var tsb := UITheme.box(UITheme.CREAM, UITheme.SKY, 14, 4, 5)
	tsb.content_margin_left = 16
	tsb.content_margin_right = 16
	tsb.content_margin_top = 8
	tsb.content_margin_bottom = 10
	_train_card.add_theme_stylebox_override("panel", tsb)
	_train_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_train_card.anchor_left = 0.5
	_train_card.anchor_right = 0.5
	_train_card.anchor_top = 1.0
	_train_card.anchor_bottom = 1.0
	_train_card.offset_top = -92
	_train_card.offset_bottom = -92
	_train_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_train_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_train_card.visible = false
	add_child(_train_card)


func _process(_delta: float) -> void:
	var hud := get_parent() as Hud
	var w: World = hud.world if hud != null else null
	if w == null or not is_instance_valid(w) or Net.phase != Net.Phase.PLAYING:
		_card.visible = false
		_train_card.visible = false
		_was_running = false
		return
	var s := w.shift
	var fresh := s.running and (not _was_running or w.get_instance_id() != _world_id)
	_was_running = s.running
	_world_id = w.get_instance_id()
	if fresh and not s.objectives.is_empty():
		_show_intro(s)
		_train = Training.new() if Training.active(w) else null
		_train_step = -1
	_update_card(s, hud)
	_update_training(w)


func _show_intro(s: ShiftManager) -> void:
	if _intro != null and is_instance_valid(_intro):
		_intro.queue_free()
	_intro = MissionIntro.new(s)
	add_child(_intro)


func _update_card(s: ShiftManager, hud: Hud) -> void:
	var objs := s.objectives
	if objs.is_empty():
		_card.visible = false
		_sig = ""
		return
	var sig := JSON.stringify(objs.map(func(e: Array) -> Array: return [e[0], e[1], e[2]]))
	if sig != _sig:
		_sig = sig
		for r in _rows:
			r.queue_free()
		_rows.clear()
		var width := maxf(_anchor.size.x, 216.0) - 24.0 - 30.0 - 44.0
		for e in objs:
			var row := ObjectiveRow.new(width)
			_list.add_child(row)
			row.set_entry(e)
			_rows.append(row)
		if not _card.visible:
			_card.visible = true
			UIKit.pop_in(_card)
	for i in mini(objs.size(), _rows.size()):
		var row: ObjectiveRow = _rows[i]
		if row.set_entry(objs[i]) and int(objs[i][4]) != ObjectiveSystem.PENDING:
			UIKit.punch(row.mark, 0.4, 0.3)
	_card.custom_minimum_size.x = maxf(_anchor.size.x, 216.0)
	_card.position = Vector2(_anchor.position.x, hud.left_stack_bottom() + 10.0)


func _update_training(w: World) -> void:
	if _train == null:
		_train_card.visible = false
		return
	var st := _train.update(w)
	if st == _train_step:
		return
	_train_step = st
	for c in _train_card.get_children():
		c.queue_free()
	if st >= Training.STEPS.size():
		_train_card.visible = false
		_train = null
		return
	var step: Dictionary = Training.STEPS[st]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var cap := UIKit.caption("TRAINING  %d / %d" % [st + 1, Training.STEPS.size()])
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	if str(step["key"]).is_empty():
		var l := UIKit.body(str(step["text"]))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	else:
		v.add_child(UIKit.key_hint(str(step["key"]), str(step["text"])))
	_train_card.add_child(v)
	_train_card.visible = true
	UIKit.pop_in(_train_card)
	print("training: step %d %s" % [st + 1, step["text"]])
