class_name IndicatorParts
extends RefCounted
## Small Control pieces for the in-world indicators (design-system look, built locally because the
## UIKit versions are sized for the HUD): floating Tag wrapper, WorldBar, ChefPips, and builders for
## the station pill, key chip, name badge, and "DONE!" style pops.

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = UITheme.build()
	return _theme


## Positions a content Control so its bottom centre sits on a screen point. Scale/alpha are per frame.
class Tag extends Control:
	var content: Control
	var pop := 0.0   # 1 -> 0 after bump(): a short scale kick
	var a := 0.0     # eased alpha owned by the layer

	func _init(c: Control) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		content = c
		add_child(c)

	func bump() -> void:
		pop = 1.0

	## Ease `a` toward target and place. p = screen point for the bottom centre.
	func show_at(p: Vector2, target: float, delta: float, s := 1.0, rate := 6.0) -> void:
		a = move_toward(a, target, delta * rate)
		place(p, a, s)

	func _process(delta: float) -> void:
		pop = move_toward(pop, 0.0, delta * 3.5)

	func place(p: Vector2, alpha: float, s := 1.0) -> void:
		if alpha <= 0.01:
			visible = false
			return
		var sz := content.get_combined_minimum_size()
		content.size = sz
		size = sz
		pivot_offset = Vector2(sz.x * 0.5, sz.y)
		position = (p - pivot_offset).round()
		var k := s * (1.0 + 0.28 * sin(pop * PI) * pop)
		scale = Vector2(k, k)
		modulate.a = alpha
		visible = true


## Rounded bar with a dark outline. flash (0..1) tints the outline tomato for the burn warning.
class WorldBar extends Control:
	const W := 76.0
	const H := 16.0
	var fraction := 0.0
	var color := UITheme.LETTUCE
	var flash := 0.0
	var _bg := UITheme.box(Color("#3E3349"), UITheme.INK, 999, 3, 3)
	var _fill := UITheme.box(UITheme.LETTUCE, UITheme.LETTUCE, 999, 0)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(W, H + 3)

	func set_state(f: float, c: Color, fl := 0.0) -> void:
		if is_equal_approx(f, fraction) and c == color and is_equal_approx(fl, flash):
			return
		fraction = f
		color = c
		flash = fl
		queue_redraw()

	func _draw() -> void:
		_bg.border_color = UITheme.INK.lerp(UITheme.TOMATO, flash)
		_bg.bg_color = Color("#3E3349").lerp(UITheme.TOMATO_DARK, flash * 0.6)
		draw_style_box(_bg, Rect2(0, 0, W, H))
		var f := clampf(fraction, 0.0, 1.0)
		if f > 0.005:
			var inner := W - 6.0
			var fw := maxf(H - 6.0, inner * f)
			_fill.bg_color = color
			_fill.border_color = color
			draw_style_box(_fill, Rect2(3, 3, fw, H - 6.0))


## Row of little chef icons: `filled` of `total` lit. Full crew turns green.
class ChefPips extends Control:
	const CELL := 26.0
	const CREAM_OFF := Color(0.85, 0.82, 0.76)
	var total := 1
	var filled := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_counts(t: int, f: int) -> void:
		if t == total and f == filled:
			return
		total = t
		filled = f
		custom_minimum_size = Vector2(CELL * total, CELL)
		queue_redraw()

	func _draw() -> void:
		var k := CELL / 22.0
		for i in total:
			var on := i < filled
			var x := float(i) * CELL
			var fill := UITheme.LETTUCE if filled >= total else UITheme.MUSTARD
			var body_col := fill if on else Color(UITheme.INK_SOFT, 0.35)
			var line := UITheme.INK if on else Color(UITheme.INK_SOFT, 0.75)
			draw_style_box(UITheme.box(body_col, line, int(5 * k), 2), Rect2(x + 3 * k, 11 * k, CELL - 6 * k, 10 * k))
			var c := Vector2(x + CELL * 0.5, 8.0 * k)
			draw_circle(c, 6.0 * k, line)
			draw_circle(c, 4.2 * k, body_col if on else CREAM_OFF)
			if on:
				draw_rect(Rect2(x + 6 * k, 0.5 * k, CELL - 12 * k, 3.5 * k), UITheme.CREAM)


# ---------------------------------------------------------------- builders

static func _pill(fill := UITheme.CREAM, ml := 10, mt := 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UITheme.box(fill, UITheme.INK, 999, 3, 3)
	sb.content_margin_left = ml
	sb.content_margin_right = ml
	sb.content_margin_top = mt
	sb.content_margin_bottom = mt
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _text(t: String, size := UITheme.S_CAPTION, color := UITheme.INK, heavy := true) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UITheme.font(heavy))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Station name marker: cream pill with the station's name.
static func station_pill(text: String) -> PanelContainer:
	var p := _pill(UITheme.CREAM, 14, 3)
	p.add_child(_text(text, UITheme.S_BODY))
	return p


## One or two "[LMB] Grab" keycaps in a pill, plus optional crew pips (grab a heavy thing).
static func key_chip(pairs: Array, crew := 0) -> PanelContainer:
	var p := _pill(UITheme.CREAM, 8, 3)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	for pr in pairs:
		var g := HBoxContainer.new()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_theme_constant_override("separation", 6)
		var cap := PanelContainer.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UITheme.box(UITheme.CREAM_HI, UITheme.INK, 7, 2, 2)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 0
		sb.content_margin_bottom = 2
		cap.add_theme_stylebox_override("panel", sb)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cap.add_child(_text(str(pr[0]), UITheme.S_CAPTION - 2))
		g.add_child(cap)
		g.add_child(_text(str(pr[1]), UITheme.S_CAPTION))
		h.add_child(g)
	if crew > 1:
		var pips := ChefPips.new()
		pips.set_counts(crew, 0)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pips)
	p.add_child(h)
	return p


## Colour dot + name pill (player_badge look at a quieter size).
static func name_badge(player_name: String, color: Color) -> PanelContainer:
	var p := _pill(UITheme.CREAM, 9, 1)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	var d := UIKit.dot(color, 14)
	d.add_theme_stylebox_override("panel", UITheme.box(color, UITheme.INK, 7, 2))
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	h.add_child(_text(player_name, UITheme.S_CAPTION, UITheme.INK, true))
	p.add_child(h)
	return p


## Little "DONE!" style pop: coloured pill.
static func pop_pill(text: String, fill: Color, ink_text := true) -> PanelContainer:
	var p := _pill(fill, 12, 2)
	p.add_child(_text(text, UITheme.S_BODY, UITheme.INK if ink_text else UITheme.CREAM))
	return p


## Ping marker: a map pin in the player's colour (ink outline, cream dot) pointing down at its bottom
## centre. The layer bounces it; `fade` 0..1 shrinks the drop shadow as it rises.
class PingPin extends Control:
	const W := 34.0
	const H := 46.0
	var color := UITheme.SKY
	var lift := 0.0   # px the pin floats above its point (drawn shadow stays at the point)

	func _init(c: Color) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		color = c
		custom_minimum_size = Vector2(W, H + 6)

	func set_lift(px: float) -> void:
		if not is_equal_approx(px, lift):
			lift = px
			queue_redraw()

	func _draw() -> void:
		var tip := Vector2(W * 0.5, H)
		# Shadow on the ground under the tip, smaller the higher the pin floats.
		var k := clampf(1.0 - lift / 30.0, 0.45, 1.0)
		draw_set_transform(tip + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 9.0 * k, Color(UITheme.INK, 0.35))
		draw_set_transform(Vector2(0, -lift))
		var r := W * 0.5 - 3.0
		var c := Vector2(W * 0.5, r + 3.0)
		var pts := PackedVector2Array()
		var a0 := deg_to_rad(35.0)
		for i in 25:   # round head: from lower right, over the top, to lower left
			var a := PI * 0.5 - a0 - (TAU - 2.0 * a0) * float(i) / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		pts.append(tip - Vector2(0, 2))
		draw_colored_polygon(pts, color)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, UITheme.INK, 3.0, true)
		draw_circle(c, r * 0.42, UITheme.CREAM)
		draw_arc(c, r * 0.42, 0.0, TAU, 20, UITheme.INK, 2.0, true)
