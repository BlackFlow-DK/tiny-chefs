class_name HudTicket
extends Control
## One order ticket hanging from the HUD rail: pin, number tag, dish name, ingredient chips (with
## doubles badges and plate ticks), patience bar. Tilts 1-2 degrees, shakes under 25% patience.
## Positioned by HudOrderRail. Local to the HUD (the design system's UIOrderTicket has no chip state).
## VIP (shift event): gold paper, thick gold frame, "VIP: <dish>", a gold star badge on the top-right corner.

const W := 208.0
const PIN := Vector2(W * 0.5, 2.0)
const COL_GAP := 6.0
const STACK_H := 88.0     # target height of the stack; zoom scales short stacks up to it

var recipe := 0
var vip := false
var left := 0.0
var patience := 1.0
var tilt := 0.0        # resting rotation (radians)
var base_x := 0.0
var fx_offset := Vector2.ZERO   # entrance offset, tweened
var _card: PanelContainer
var _sb: StyleBoxFlat
var _bar: UIProgress
var _chips: Array[HudChip] = []
var _root: Control      # card + flash + pin, scaled as one by the rail's fit factor
var _overlay: Control   # ticks, count badges, 1st/last tags: drawn over every layer
var _tops: Array[HudChip] = []   # the top layer of each column
var _fit := 1.0
var _two_cols := false
var _col_split := 0
var _flash: Panel
var _flash_sb: StyleBoxFlat
var _urgent: Tween
var _urgent_state := false
var _border := UITheme.INK


func setup(recipe_idx: int, number_text: String, tilt_deg: float, is_vip := false) -> void:
	recipe = recipe_idx
	vip = is_vip
	tilt = deg_to_rad(tilt_deg)
	rotation = tilt
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rec: Dictionary = GameData.RECIPES[recipe_idx]

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(W, 0)
	_border = UITheme.MUSTARD_DARK if vip else UITheme.INK
	_sb = UITheme.box(Color("#FFE8A3") if vip else UITheme.CREAM, _border, 12, 6 if vip else 4, 5)
	_sb.content_margin_left = 12
	_sb.content_margin_right = 12
	_sb.content_margin_top = 16
	_sb.content_margin_bottom = 11
	_card.add_theme_stylebox_override("panel", _sb)
	_root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var tag := PanelContainer.new()
	var tsb := UITheme.box(UITheme.MUSTARD, UITheme.INK, 8, 3)
	tsb.content_margin_left = 6
	tsb.content_margin_right = 6
	tsb.content_margin_top = 0
	tsb.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", tsb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := UIKit.number(number_text)
	tl.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	tag.add_child(tl)
	head.add_child(tag)
	var name_l := UIKit.heading(("VIP: %s" % rec["name"]) if vip else rec["name"])
	name_l.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(0, 24)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	v.add_child(head)

	# The mini stack: layers bottom-to-top; runs of one kind merge into a layer with a "2x" badge.
	var groups: Array = []
	for k in rec["items"]:
		if not groups.is_empty() and groups[-1][0] == k:
			groups[-1][1] += 1
		else:
			groups.append([k, 1])
	var stack := _build_stack(groups)
	v.add_child(stack)
	if ModifierSystem.is_active("mystery_orders"):
		stack.visible = false   # layers still tick internally (set_plate), just hidden
		v.add_child(_mystery_row())

	_bar = UIKit.progress(1.0, 150, 14, true)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_bar)

	_flash_sb = UITheme.box(Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), 12, 0)
	_flash = Panel.new()
	_flash.add_theme_stylebox_override("panel", _flash_sb)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_root.add_child(_flash)

	var pin := Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.draw.connect(func() -> void:
		pin.draw_circle(PIN + Vector2(0, 3), 10.0, UITheme.INK)
		pin.draw_circle(PIN, 9.0, UITheme.INK)
		pin.draw_circle(PIN, 6.5, UITheme.TOMATO)
		pin.draw_circle(PIN + Vector2(-2, -2), 2.2, UITheme.CREAM)
		if vip:
			_draw_star(pin, Vector2(W - 10, 6), 17.0))
	_root.add_child(pin)

	_card.resized.connect(_on_card_resized)
	_on_card_resized.call_deferred()


## Columns of layers. Up to 5 layers: one column. Longer: two columns, split after the bun top when a
## meal has sides after the burger (Burger Meal: burger | fries, soda), else in half; the second column
## continues where the first ends (small arrow between them).
func _build_stack(groups: Array) -> Control:
	var n := groups.size()
	_col_split = n
	if n > 5:
		_col_split = (n + 1) / 2
		for i in n - 1:
			if groups[i][0] == "bun_top" and i + 1 >= 2:
				_col_split = i + 1
				break
	var cols: Array = [groups.slice(0, _col_split)]
	if _col_split < n:
		cols.append(groups.slice(_col_split))
	_two_cols = cols.size() > 1
	var area_w := W - 24.0
	var col_w := (area_w - COL_GAP * (cols.size() - 1)) / cols.size()
	var labelled := not _two_cols
	# Zoom: short stacks get bigger icons. Measure at zoom 1 first.
	var h1 := 0.0
	for col in cols:
		var hh := 0.0
		for i in col.size():
			var probe := HudChip.new()
			probe.setup(str(col[i][0]), int(col[i][1]), 1.0, col_w, labelled)
			hh += probe.h_box if i == col.size() - 1 else probe.step
			probe.free()
		h1 = maxf(h1, hh)
	var zoom := clampf(STACK_H / h1, 0.8, 1.1)
	var col_h: Array = []
	for col in cols:
		var hh := 0.0
		for i in col.size():
			var c := HudChip.new()
			c.setup(str(col[i][0]), int(col[i][1]), zoom, col_w, labelled)
			col[i] = c
			hh += c.h_box if i == col.size() - 1 else c.step
		col_h.append(hh)
	var total_h: float = maxf(col_h[0], col_h[-1])
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.custom_minimum_size = Vector2(area_w, total_h + 2.0)
	for ci in cols.size():
		var col: Array = cols[ci]
		var bottom := total_h + 1.0
		var cx := ci * (col_w + COL_GAP)
		for i in col.size():
			var c: HudChip = col[i]
			c.position = Vector2(cx, bottom - c.h_box)
			stack.add_child(c)
			_chips.append(c)
			bottom -= c.step
		_tops.append(col[-1])
	if n > 1:
		_chips[0].tag = "1st"
		_chips[-1].tag = "last"
		if _two_cols:
			_chips[_col_split].tag = "cont"
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	stack.add_child(_overlay)
	return stack


func _draw_overlay() -> void:
	for c in _chips:
		c.draw_marks(_overlay, _tops.has(c))


## mystery_orders: a row of "?" chips in place of the ingredients.
func _mystery_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i in 3:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.box(UITheme.CREAM_HI, UITheme.INK, 8, 3))
		p.custom_minimum_size = Vector2(32, 30)
		var q := UIKit.number("?")
		q.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(q)
		row.add_child(p)
	return row


## Gold VIP star with an ink outline and a highlight, centred on c.
static func _draw_star(ci: CanvasItem, c: Vector2, r: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.46
		outer.append(c + Vector2(cos(a), sin(a)) * (rr + 3.5))
		inner.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(outer, UITheme.INK)
	ci.draw_colored_polygon(inner, UITheme.MUSTARD)
	ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.25), r * 0.14, UITheme.CREAM)


## Height of the paper itself at its natural size (the Control's own size can stay larger after a tall layout pass).
func natural_height() -> float:
	return _card.size.y + 5.0


## Height on screen (natural height times the rail's fit factor).
func body_height() -> float:
	return natural_height() * _fit


func width() -> float:
	return W * _fit


## Uniform shrink so a rail full of tall tickets stays under its share of the screen.
func set_fit(f: float) -> void:
	_fit = f
	_root.scale = Vector2(f, f)
	_on_card_resized()


func _on_card_resized() -> void:
	size = Vector2(W, natural_height()) * _fit
	custom_minimum_size = size
	_flash.position = Vector2.ZERO
	_flash.size = _card.size
	pivot_offset = PIN * _fit


func set_progress(left_s: float, patience_s: float) -> void:
	left = left_s
	patience = patience_s
	var f := clampf(left_s / maxf(patience_s, 0.01), 0.0, 1.0)
	_bar.set_fraction(f)
	_set_urgent(f < 0.25 and f > 0.0)


func set_plate(stack: Array) -> void:
	var left := {}
	for k in stack:
		left[k] = int(left.get(k, 0)) + 1
	for c in _chips:
		var n := mini(int(left.get(c.kind, 0)), c.need)
		left[c.kind] = int(left.get(c.kind, 0)) - n
		c.set_have(n)
	if _overlay != null:
		_overlay.queue_redraw()


func flash(col: Color, hold := 0.5) -> void:
	_flash_sb.bg_color = Color(col.r, col.g, col.b, 0.8)
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.25, hold)


func stop_urgent() -> void:
	_set_urgent(false)


func _set_urgent(on: bool) -> void:
	if on == _urgent_state:
		return
	_urgent_state = on
	if _urgent != null:
		_urgent.kill()
		_urgent = null
	if on and is_inside_tree():
		_sb.border_color = UITheme.TOMATO
		# heartbeat + little shake around the pin
		_urgent = create_tween().set_loops()
		_urgent.tween_property(self, "scale", Vector2.ONE * 1.05, 0.2).set_trans(Tween.TRANS_SINE)
		_urgent.parallel().tween_property(self, "rotation", tilt + 0.035, 0.1)
		_urgent.tween_property(self, "rotation", tilt - 0.035, 0.1)
		_urgent.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
		_urgent.parallel().tween_property(self, "rotation", tilt, 0.25)
		_urgent.tween_interval(0.35)
	else:
		_sb.border_color = _border
		scale = Vector2.ONE
		rotation = tilt
