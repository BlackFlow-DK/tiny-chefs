class_name ShopView
extends Control
## "Chef shop": team wallet + the owned strip on top, one tab per upgrade category (Cooking, Prep, Movement, Service,
## Chaos), one ShopRow per upgrade LINE, and the footer with what comes next. A tab shows a lettuce count of the
## lines the team can afford right now, so nothing needs hunting. Purchases: Net.buy(id); Net.set_phase(PLAYING).
## Q / E (or the shoulder buttons) switch tabs; up/down walk the rows.

## Colour per upgrade category (GameData.UPGRADE_CATEGORIES).
const COLORS := {"cooking": UITheme.MUSTARD, "prep": UITheme.SKY, "movement": UITheme.LETTUCE,
	"service": UITheme.SKY, "chaos": UITheme.TOMATO}
const ROW_GAP := 8

var _rows: Dictionary = {}       # id -> ShopRow
var _pages: Array = []           # [{id, page: VBoxContainer, tab: Button, badge: PanelContainer, badge_lbl: Label, rows: [ShopRow]}]
var _tab := -1
var _strip: ShopOwnedStrip
var _wallet_lbl: Label
var _wallet_chip: PanelContainer
var _wallet_shown := -1.0
var _wallet_tween: Tween
var _next_lbl: Label
var _start: Button
var _wait_chip: PanelContainer
var _wait_lbl: Label
var _primed := false             # false until one state was seen (no toasts for the initial sync)
var _panel: PanelContainer


func _init() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UIKit.backdrop(0.66))

	var pv := UIKit.card(10)
	_panel = pv[0]
	_panel.custom_minimum_size = Vector2(1180, 0)
	var v: VBoxContainer = pv[1]

	# Header: title left, owned strip in the middle, wallet right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var titles := VBoxContainer.new()
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 0)
	var t := UIKit.title("Chef shop", UITheme.S_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(t)
	titles.add_child(UIKit.caption("One shared wallet. Upgrades last for the whole run."))
	head.add_child(titles)
	head.add_child(_make_owned())
	head.add_child(_make_wallet())
	v.add_child(head)

	# Tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", ROW_GAP)
	var max_rows := 1
	var cats := GameData.upgrade_categories()
	for ci in cats.size():
		var cat: Dictionary = cats[ci]
		var col: Color = COLORS.get(str(cat["id"]), UITheme.MUSTARD)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", ROW_GAP)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rows: Array = []
		for uid in cat["upgrades"]:
			var r := ShopRow.new(str(uid), col)
			r.pressed.connect(_on_row_pressed.bind(r))
			r.bought.connect(_on_bought)
			page.add_child(r)
			_rows[str(uid)] = r
			rows.append(r)
		max_rows = maxi(max_rows, rows.size())
		var tab := UIKit.button(str(cat["name"]), func() -> void: _select_tab(ci, false), "secondary", 0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 50)
		tab.add_theme_font_size_override("font_size", UITheme.S_BODY)
		var bg := PanelContainer.new()
		bg.add_theme_stylebox_override("panel", UITheme.box(UITheme.LETTUCE, UITheme.INK, 12, 3, 2))
		(bg.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(1)
		(bg.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
		(bg.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
		var bl := UIKit.number("0")
		bl.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
		bg.add_child(bl)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.visible = false
		tab.add_child(bg)
		bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
		bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		bg.position.y = -10
		tabs.add_child(tab)
		stack.add_child(page)
		_pages.append({"id": str(cat["id"]), "page": page, "tab": tab, "badge": bg, "badge_lbl": bl, "rows": rows})
	var hint := UIKit.caption("Q / E: switch tab")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(hint)

	# Scrolls only if a window is too short for the tallest page (gamepad focus follows).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(0, max_rows * (ShopRow.ROW_H + ROW_GAP) - ROW_GAP + 10)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	v.add_child(scroll)

	# Footer.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	_next_lbl = UIKit.body("")
	_next_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_lbl.custom_minimum_size = Vector2(300, 0)
	foot.add_child(_next_lbl)
	_start = UIKit.button("Start next shift", func() -> void: Net.set_phase(Net.Phase.PLAYING, {}), "go", 300)
	_start.custom_minimum_size.y = 60
	_start.add_theme_font_size_override("font_size", UITheme.S_HEADING)
	foot.add_child(_start)
	_wait_chip = PanelContainer.new()
	_wait_chip.theme_type_variation = "DarkChipPanel"
	_wait_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wait_lbl = UIKit.body("", "dark")
	_wait_chip.add_child(_wait_lbl)
	foot.add_child(_wait_chip)
	v.add_child(foot)
	add_child(UI.centred(_panel))
	_select_tab(0, false)


func _make_owned() -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "DarkChipPanel"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var cap := UIKit.caption("Owned", "dark")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(cap)
	_strip = ShopOwnedStrip.new(true)
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_strip)
	chip.add_child(hb)
	return chip


func _make_wallet() -> Control:
	_wallet_chip = PanelContainer.new()
	_wallet_chip.theme_type_variation = "DarkChipPanel"
	_wallet_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var cap := VBoxContainer.new()
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	cap.add_theme_constant_override("separation", 0)
	cap.add_child(UIKit.caption("Team wallet", "dark"))
	_wallet_lbl = UIKit.number("0", "dark", UITheme.MUSTARD)
	_wallet_lbl.add_theme_font_size_override("font_size", UITheme.S_TITLE)
	_wallet_lbl.custom_minimum_size = Vector2(90, 0)
	cap.add_child(_wallet_lbl)
	h.add_child(UIKit.dot(UITheme.MUSTARD, 46))
	h.add_child(cap)
	_wallet_chip.add_child(h)
	return _wallet_chip


# ---------------------------------------------------------------- tabs

func _select_tab(i: int, focus_tab: bool) -> void:
	i = clampi(i, 0, _pages.size() - 1)
	if i != _tab:
		_tab = i
		for k in _pages.size():
			var e: Dictionary = _pages[k]
			(e["page"] as Control).visible = k == i
			(e["tab"] as Button).theme_type_variation = "AccentButton" if k == i else "SecondaryButton"
		var pg: Control = _pages[i]["page"]
		UIKit.punch(pg, 0.015, 0.2)
	if focus_tab:
		(_pages[i]["tab"] as Button).grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _pages.is_empty():
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			step = -1
		elif event.keycode == KEY_E:
			step = 1
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	if step != 0:
		_select_tab((_tab + step + _pages.size()) % _pages.size(), true)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- buying

func _on_row_pressed(_id: String, row: ShopRow) -> void:
	match row.state:
		"buy":
			Net.buy(row.id)
		"poor":
			UIKit.shake(row, 7.0)
			UIKit.toast(self, "Need %d more coins" % maxi(row.cost - int(_wallet_shown), 1), "error", 1.6)
		"locked":
			UIKit.shake(row, 5.0)
			var req := GameData.upgrade_requires(row.id)
			UIKit.toast(self, "Buy %s first" % GameData.upgrade_title(str(req[0]), int(req[1])), "warn", 1.8)
		"na":
			UIKit.shake(row, 5.0)
			UIKit.toast(self, "Not available on the next kitchen", "warn", 1.8)


func _on_bought(id: String, level: int) -> void:
	UIKit.toast(self, "Bought %s!" % GameData.upgrade_title(id, level), "success", 2.0)
	UIKit.punch(_wallet_chip, 0.1, 0.3)


func show_phase() -> void:
	_primed = false
	_wallet_shown = -1.0
	_start.visible = Net.is_host
	_wait_chip.visible = not Net.is_host
	var who := "the host"
	if Net.players.has(1):
		who = "%s (host)" % str(Net.players[1]["name"])
	_wait_lbl.text = "Waiting for %s..." % who
	UIKit.pop_in(_panel, 0.0, 0.22)


func update(sm: ShiftManager) -> void:
	if sm == null:
		return
	_set_wallet(sm.coins)
	_strip.refresh(sm)
	var rec := _recommended(sm)
	for id in _rows:
		(_rows[id] as ShopRow).refresh(sm, rec.has(id), _primed)
	for e in _pages:
		var n := 0
		for r in e["rows"]:
			if (r as ShopRow).state == "buy":
				n += 1
		(e["badge"] as Control).visible = n > 0
		(e["badge_lbl"] as Label).text = str(n)
	if not _primed:
		_primed = true
		# Open on the first tab that has something to buy.
		var first := 0
		for k in _pages.size():
			if (_pages[k]["badge"] as Control).visible:
				first = k
				break
		_tab = -1
		_select_tab(first, false)
		_focus_start()
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and not f.is_visible_in_tree():
			_focus_start()
	_next_lbl.text = _next_text(sm)
	_start.text = ("Retry mission" if sm.next_index == sm.index else "Start next mission") if Net.settings.mode == "campaign" else "Start next shift"


## Shift 1 shop: the cheapest affordable first-level line of each category (ids), so every tab has a hint.
func _recommended(sm: ShiftManager) -> Array:
	var out: Array = []
	if sm.index > 0:
		return out
	for e in _pages:
		var best := ""
		var best_price := 1 << 30
		for r in e["rows"]:
			var id: String = (r as ShopRow).id
			var price := sm.next_price(id)
			if sm.upgrade_level(id) == 0 and price >= 0 and sm.coins >= price and price < best_price 					and sm.requires_met(id) and ShiftSystem.upgrade_available(id, sm.next_index):
				best = id
				best_price = price
		if best != "":
			out.append(best)
	return out


## Footer line: campaign names the next mission and its map, endless / custom the next shift.
func _next_text(sm: ShiftManager) -> String:
	var nd := ShiftPlan.build(Net.settings, sm.next_index, maxi(1, Net.players.size()))
	var retry := sm.next_index == sm.index
	if Net.settings.mode == "campaign":
		var map_id := str(nd.get("map", ""))
		var map_name := str(GameData.MAPS.get(map_id, {}).get("name", map_id.capitalize()))
		if map_name.begins_with("The "):
			map_name = map_name.substr(4)
		return "%s: %s on %s, target %d" % ["Retry mission" if retry else "Next mission", nd["name"], map_name, nd["target"]]
	if retry:
		return "Retry shift %d: %s, target %d" % [sm.next_index + 1, nd["name"], nd["target"]]
	return "Next: Shift %d: %s, target %d" % [sm.next_index + 1, nd["name"], nd["target"]]


## First affordable Buy button on the open tab; otherwise the host's Start button, or the tab for clients.
func _focus_start() -> void:
	for r in _pages[_tab]["rows"]:
		if (r as ShopRow).state == "buy":
			(r as ShopRow).button.grab_focus.call_deferred()
			return
	if Net.is_host:
		_start.grab_focus.call_deferred()
	else:
		for r in _pages[_tab]["rows"]:
			if (r as ShopRow).button.visible:
				(r as ShopRow).button.grab_focus.call_deferred()
				return
		(_pages[_tab]["tab"] as Button).grab_focus.call_deferred()


func _set_wallet(coins: int) -> void:
	if _wallet_shown >= 0.0 and int(_wallet_shown) == coins:
		return
	if _wallet_shown < 0.0:
		_wallet_shown = coins
		_wallet_lbl.text = str(coins)
		return
	var from := _wallet_shown
	_wallet_shown = coins
	if _wallet_tween != null:
		_wallet_tween.kill()
	_wallet_tween = create_tween()
	_wallet_tween.tween_method(func(x: float) -> void: _wallet_lbl.text = str(int(round(x))), from, float(coins), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	UIKit.punch(_wallet_chip, 0.1, 0.3)
