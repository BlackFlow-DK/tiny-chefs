class_name LanGameList
extends PanelContainer
## The join page's "Kitchens on your network" tray: one LanGameRow per game Net.discovery hears, kept in the
## discovery's order (sorted by name) and updated in place, so rows never jump under the cursor. Scrolls
## inside the tray when there are more games than fit. Empty: "Looking for kitchens on your network" with
## bobbing dots, plus a calm hint after HINT_AFTER s. start() / stop() own the search (menu calls them).

signal join_requested(game: Dictionary)
signal focus_needed   ## the focused row went away and no other row can take the focus

const HINT_AFTER := 5.0
const SHOW_ROWS := 3     # the tray is at least this many rows tall (more scroll inside it)
const ROW_GAP := 10
const PAD_TOP := 10      # room for the hover lift, shadows and the focus ring (the scroll clips)
const PAD_BOTTOM := 12

var _scroll: ScrollContainer
var _rows_box: VBoxContainer
var _rows: Dictionary = {}   # game key -> LanGameRow
var _empty: CenterContainer
var _hint: Label
var _searching := false
var _locked := false
var _empty_for := 0.0


func _init() -> void:
	var tray := UITheme.box(Color(UITheme.INK, 0.07), Color(UITheme.INK, 0.18), UITheme.R_INPUT, 3)
	tray.set_content_margin_all(3)
	add_theme_stylebox_override("panel", tray)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Fixed floor (empty or listing), so the card never changes height when the first game turns up.
	custom_minimum_size = Vector2(0, SHOW_ROWS * LanGameRow.ROW_H + (SHOW_ROWS - 1) * ROW_GAP + PAD_TOP + PAD_BOTTOM + 6)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	LobbySettingsPanel._style_scroll(_scroll)
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", PAD_TOP)
	pad.add_theme_constant_override("margin_bottom", PAD_BOTTOM)
	_scroll.add_child(pad)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", ROW_GAP)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_rows_box)

	_empty = CenterContainer.new()
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 8)
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_child(ev)
	var dots := Dots.new(6.0)
	dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ev.add_child(dots)
	var look := UIKit.body("Looking for kitchens on your network")
	look.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(look)
	_hint = UIKit.caption("No luck yet? Ask the host for their address and type it below.")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(340, 0)
	_hint.modulate.a = 0.0   # keeps its space: the empty state does not shift when it appears
	ev.add_child(_hint)
	_sync_empty()
	set_process(false)


## Start searching the LAN (no-op while searching). The list empties first: the search starts fresh.
func start() -> void:
	if _searching:
		return
	_searching = true
	_empty_for = 0.0
	_hint.modulate.a = 0.0
	Net.discovery.games_changed.connect(_on_games)
	Net.discovery.start_search()
	_on_games(Net.discovery.get_games())
	set_process(true)


## Stop searching. keep_rows: leave the rows on screen (a join is starting from them); else clear the list.
func stop(keep_rows := false) -> void:
	if not _searching:
		if not keep_rows:
			_on_games([])
		return
	_searching = false
	set_process(false)
	if Net.discovery.games_changed.is_connected(_on_games):
		Net.discovery.games_changed.disconnect(_on_games)
	Net.discovery.stop_search()
	if not keep_rows:
		_on_games([])


func is_searching() -> bool:
	return _searching


func set_locked(on: bool) -> void:
	_locked = on
	for r: LanGameRow in _rows.values():
		r.set_locked(on)


## The first row you can join, or null.
func first_joinable() -> LanGameRow:
	for r in _rows_box.get_children():
		if r is LanGameRow and (r as LanGameRow).is_joinable():
			return r
	return null


func row_count() -> int:
	return _rows.size()


static func key_of(g: Dictionary) -> String:
	var id := str(g.get("id", ""))
	return id if not id.is_empty() else "%s:%d" % [str(g.get("address", "")), int(g.get("port", 0))]


func _on_games(games: Array) -> void:
	var want: Array[String] = []
	for g: Dictionary in games:
		var k := key_of(g)
		if not want.has(k):
			want.append(k)
	# Gone: free the row (focus moves to a neighbour first so keyboard/gamepad users are not dropped).
	for k: String in _rows.keys():
		if want.has(k):
			continue
		var row: LanGameRow = _rows[k]
		_rows.erase(k)
		if row.has_focus():
			_refocus_from(row)
		_rows_box.remove_child(row)
		row.queue_free()
	# New and changed rows, in the discovery's order; existing rows are updated, never rebuilt.
	var i := 0
	for g: Dictionary in games:
		var k := key_of(g)
		var row: LanGameRow = _rows.get(k)
		if row == null:
			row = LanGameRow.new()
			row.join_requested.connect(func(game: Dictionary) -> void: join_requested.emit(game))
			_rows[k] = row
			_rows_box.add_child(row)
			row.set_game(g)
			row.set_locked(_locked)
			UIKit.pop_in(row, 0.0, 0.18)
		else:
			row.set_game(g)
		if row.get_index() != i:
			_rows_box.move_child(row, i)
		i += 1
	_sync_empty()


func _refocus_from(row: LanGameRow) -> void:
	var kids := _rows_box.get_children()
	var at := kids.find(row)
	for d in range(1, kids.size()):
		for j in [at + d, at - d]:
			if j >= 0 and j < kids.size() and kids[j] is LanGameRow and (kids[j] as LanGameRow).is_joinable():
				(kids[j] as Control).grab_focus.call_deferred()
				return
	focus_needed.emit()   # no other row: the menu picks its fallback (the address field)


func _sync_empty() -> void:
	var empty := _rows.is_empty()
	_empty.visible = empty
	_scroll.visible = not empty
	if not empty:
		_hint.modulate.a = 0.0


func _process(delta: float) -> void:
	if not _rows.is_empty():
		_empty_for = 0.0
		return
	_empty_for += delta
	if _empty_for >= HINT_AFTER and _hint.modulate.a == 0.0:
		_hint.modulate.a = 0.01
		var tw := _hint.create_tween()
		tw.tween_property(_hint, "modulate:a", 1.0, 0.6)


## Three bobbing ink-outlined dots (tomato, mustard, lettuce): "still looking". Drawn, so no layout churn.
class Dots extends Control:
	var r := 6.0
	var _t := 0.0

	func _init(radius := 6.0) -> void:
		r = radius
		custom_minimum_size = Vector2(r * 9.0, r * 4.4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var cols := [UITheme.TOMATO, UITheme.MUSTARD, UITheme.LETTUCE]
		for i in 3:
			var ph := fposmod(_t * 1.6 - i * 0.18, 1.0)
			var hop := sin(clampf(ph / 0.45, 0.0, 1.0) * PI) * r * 1.4   # hop, then rest
			var c := Vector2(size.x / 2.0 + (i - 1) * r * 3.0, size.y - r - 2.0 - hop)
			draw_circle(c, r + 1.5, UITheme.INK)
			draw_circle(c, r - 1.0, cols[i])
