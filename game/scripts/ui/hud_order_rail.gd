class_name HudOrderRail
extends Control
## The order rail: a thin rail across the top centre with HudTickets hanging from it. Diffs the
## replicated order list each frame to slide new tickets in, fly served ones off (green, +coins)
## and drop expired ones (red). Tick marks come from the replicated plate stack.

const GAP := 12.0
const TICKET_Y := 16.0
const RAIL_Y := 12.0
const RAIL_H := 12.0

var _tickets: Array[HudTicket] = []
var _spawned := 0
var _fit := 1.0

## Share of the screen height the rail may cover (tickets shrink uniformly past it).
const MAX_SHARE := 0.28
## Screen margins the rail keeps clear: the stats card on the left, the timer card on the right (1280 logical px design).
const LEFT_RESERVED := 236.0
const RIGHT_RESERVED := 151.0
const RAIL_PAD := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 220


## Y under the tickets, for stacking toasts beneath.
func rail_bottom() -> float:
	var h := 120.0   # the shortest ticket (a mystery / one-item order)
	for t in _tickets:
		h = maxf(h, t.body_height() + 8.0)
	return TICKET_Y + h


func clear_all() -> void:
	for t in _tickets:
		t.queue_free()
	_tickets.clear()


## orders: world.orders.orders. served_delta: orders served since the last call; pay: coins for the last serve.
func sync_orders(orders: Array, plate: Array, served_delta: int, pay: int, instant: bool) -> void:
	if instant:
		clear_all()
	var same_shape := orders.size() == _tickets.size()
	if same_shape:
		for i in orders.size():
			if int(orders[i]["r"]) != _tickets[i].recipe or bool(orders[i].get("vip", false)) != _tickets[i].vip:
				same_shape = false
				break
	if not same_shape:
		var idx := 0
		var gone: Array[HudTicket] = []
		var keep: Array[HudTicket] = []
		for t in _tickets:
			if idx < orders.size() and int(orders[idx]["r"]) == t.recipe and bool(orders[idx].get("vip", false)) == t.vip \
					and absf(float(orders[idx]["left"]) - t.left) < 2.5:
				keep.append(t)
				idx += 1
			else:
				gone.append(t)
		_tickets = keep
		var n_served := served_delta
		for t in gone:
			var was_served := n_served > 0
			if was_served:
				n_served -= 1
			_leave(t, was_served, pay if was_served else 0)
		while idx < orders.size():
			_add(int(orders[idx]["r"]), bool(orders[idx].get("vip", false)))
			idx += 1
	for i in mini(orders.size(), _tickets.size()):
		_tickets[i].set_progress(float(orders[i]["left"]), float(orders[i]["patience"]))
		_tickets[i].set_plate(plate)


func _add(recipe: int, vip := false) -> void:
	_spawned += 1
	var t := HudTicket.new()
	var sgn := 1.0 if _spawned % 2 == 0 else -1.0
	t.setup(recipe, "#%d" % _spawned, 1.6 * sgn, vip)
	add_child(t)
	t.set_fit(_fit)
	_tickets.append(t)
	t.base_x = _target_x(_tickets.size() - 1)
	t.position = Vector2(t.base_x, TICKET_Y - 150.0)
	t.modulate.a = 0.0
	t.fx_offset = Vector2(0, -150)
	var tw := t.create_tween().set_parallel(true)
	tw.tween_property(t, "fx_offset", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 1.0, 0.15)


func _leave(t: HudTicket, served: bool, pay: int) -> void:
	t.stop_urgent()
	var p := t.position
	var tw := t.create_tween().set_parallel(true)
	if served:
		t.flash(UITheme.LETTUCE, 0.5)
		tw.tween_property(t, "position", p + Vector2(50, -210), 0.55).set_delay(0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "rotation", t.tilt + 0.5, 0.55).set_delay(0.16)
		tw.tween_property(t, "modulate:a", 0.0, 0.25).set_delay(0.45)
		if pay > 0:
			_float_text("+%d" % pay, p + Vector2(t.width() * 0.5, 110))
	else:
		t.flash(UITheme.TOMATO, 0.5)
		tw.tween_property(t, "position", p + Vector2(-20, 320), 0.6).set_delay(0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "rotation", t.tilt - 0.45, 0.6).set_delay(0.18)
		tw.tween_property(t, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(t.queue_free)


func _float_text(text: String, at: Vector2) -> void:
	var l := UIKit.number(text, "world", UITheme.LETTUCE)
	l.add_theme_font_size_override("font_size", UITheme.S_TITLE)
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.position = at - Vector2(40, 30)
	l.pivot_offset = Vector2(40, 30)
	l.scale = Vector2(0.5, 0.5)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", at.y - 55.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)


func _target_x(i: int) -> float:
	var w := HudTicket.W * _fit
	return _left_edge(_tickets.size()) + i * (w + GAP * _fit)


## Left x of a row of n tickets: centred on the screen, nudged to stay between the HUD's corner cards.
func _left_edge(n: int) -> float:
	var w := HudTicket.W * _fit
	var total := n * w + maxi(0, n - 1) * (GAP * _fit)
	var lo := LEFT_RESERVED
	var hi := maxf(lo, size.x - RIGHT_RESERVED - total)
	return clampf((size.x - total) * 0.5, lo, hi)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	_update_fit(k)
	for i in _tickets.size():
		var t := _tickets[i]
		t.base_x = lerpf(t.base_x, _target_x(i), k)
		t.position = Vector2(t.base_x, TICKET_Y) + t.fx_offset
	queue_redraw()


## One uniform factor for all tickets: the tallest natural ticket must fit under MAX_SHARE of the screen.
func _update_fit(k: float) -> void:
	var tallest := 100.0
	for t in _tickets:
		tallest = maxf(tallest, t.natural_height())
	var room := get_viewport_rect().size.y * MAX_SHARE - TICKET_Y - 4.0
	var target := clampf(room / tallest, 0.5, 1.0)
	# Width: a full house (or the VIP extra) must fit between the corner cards.
	var n := maxi(Tuning.MAX_ORDERS, _tickets.size())
	var avail := size.x - LEFT_RESERVED - RIGHT_RESERVED - 2.0 * RAIL_PAD
	target = minf(target, clampf(avail / (n * HudTicket.W + (n - 1) * GAP), 0.5, 1.0))
	if absf(target - _fit) < 0.002:
		return
	_fit = lerpf(_fit, target, k)
	for t in _tickets:
		t.set_fit(_fit)


func _draw() -> void:
	# The rail: a chunky ink bar with a highlight, long enough for the tickets that hang from it.
	var n := maxi(Tuning.MAX_ORDERS, _tickets.size())
	var inner := (n * HudTicket.W + (n - 1) * GAP) * _fit
	var full := inner + 2.0 * RAIL_PAD
	var r := Rect2(_left_edge(n) - RAIL_PAD, RAIL_Y, full, RAIL_H)
	draw_style_box(UITheme.box(UITheme.INK_LIGHT, UITheme.INK, 6, 3, 4), r)
	draw_line(r.position + Vector2(10, 4.5), r.position + Vector2(full - 10, 4.5), UITheme.INK_SOFT, 2.0)
	for x in [r.position.x + 9.0, r.end.x - 9.0]:
		draw_circle(Vector2(x, r.position.y + RAIL_H * 0.5), 3.5, UITheme.MUSTARD)
