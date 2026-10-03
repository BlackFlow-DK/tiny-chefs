class_name ShopView
extends Control
## "Chef shop": big team-wallet chip, one card per upgrade (icon, effect, price, Buy / OWNED)
## and a footer with what comes next. Same calls as before: Net.buy(id), Net.set_phase(PLAYING).

## Card colour per upgrade category (GameData.UPGRADE_CATEGORIES).
const COLORS := {"cooking": UITheme.MUSTARD, "prep": UITheme.SKY, "movement": UITheme.LETTUCE,
	"service": UITheme.SKY, "chaos": UITheme.TOMATO}
## Stop-gap layout for the tiered tree (a dedicated shop rebuild replaces it): a grid of small cards in
## GameData.UPGRADES order, each showing the NEXT level (title, effect, price) or MAX.
const COLUMNS := 8
const CARD_W := 136
const ICON_PX := 48

var _cards: Dictionary = {}     # id -> {card, button, price, chip, badge, name, level, desc, state "<st>:<level>", cost}
var _wallet_lbl: Label
var _wallet_chip: PanelContainer
var _wallet_shown := -1.0
var _wallet_tween: Tween
var _next_lbl: Label
var _start: Button
var _wait_chip: PanelContainer
var _wait_lbl: Label
var _primed := false            # false until one state was seen (no toasts for the initial sync)
var _panel: PanelContainer


func _init() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UIKit.backdrop(0.66))

	var pv := UIKit.card(14)
	_panel = pv[0]
	var v: VBoxContainer = pv[1]

	# Header: title left, wallet right.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 0)
	var t := UIKit.title("Chef shop", UITheme.S_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(t)
	titles.add_child(UIKit.caption("One shared wallet. Upgrades last for the whole run."))
	head.add_child(titles)
	head.add_child(_make_wallet())
	v.add_child(head)

	var cards := GridContainer.new()
	cards.columns = mini(COLUMNS, GameData.UPGRADES.size())
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	for u in GameData.UPGRADES:
		cards.add_child(_make_card(u))
	# Scrolls when the grid is taller than the window allows (gamepad focus follows).
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(COLUMNS * (CARD_W + 8), 520)
	scroll.add_child(cards)
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
	_start.custom_minimum_size.y = 64
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


func _make_card(u: Dictionary) -> Control:
	var id: String = u["id"]
	var col: Color = COLORS.get(str(u.get("category", "")), UITheme.MUSTARD)
	var cv := UIKit.card(2)
	var card: PanelContainer = cv[0]
	var v: VBoxContainer = cv[1]
	var sb := UITheme.box(UITheme.CREAM, UITheme.INK, 12, 3, 3)
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_wrap := CenterContainer.new()
	var icon_area := Control.new()
	icon_area.custom_minimum_size = Vector2(CARD_W - 12, ICON_PX + 2)
	icon_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ShopIcon.new(id, col, ICON_PX)
	icon_area.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	# MAX ribbon, tilted across the icon.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.LETTUCE, UITheme.INK, 8, 3, 4))
	var bl := UIKit.number("MAX")
	bl.add_theme_font_size_override("font_size", UITheme.S_BODY)
	badge.add_child(bl)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_area.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.position.y += 12
	badge.rotation = -0.2
	icon_wrap.add_child(icon_area)
	v.add_child(icon_wrap)

	var nm := UIKit.body(str(u["name"]))
	nm.add_theme_font_size_override("font_size", 18)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(CARD_W - 12, 0)
	v.add_child(nm)
	var desc := UIKit.caption("")
	desc.add_theme_font_size_override("font_size", 14)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_W - 12, 54)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	# Level + price on one row.
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 6)
	var lvl := UIKit.caption("")
	lvl.add_theme_font_size_override("font_size", 14)
	lvl.add_theme_color_override("font_color", col.darkened(0.5))
	lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(lvl)
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	ph.add_child(UIKit.dot(UITheme.MUSTARD, 18))
	var price := UIKit.number("0")
	price.add_theme_font_size_override("font_size", UITheme.S_BODY)
	ph.add_child(price)
	chip.add_child(ph)
	price_row.add_child(chip)
	v.add_child(price_row)

	var btn := UIKit.button("Buy", func() -> void: _on_buy(id), "accent", CARD_W - 40)
	btn.custom_minimum_size.y = 36
	btn.add_theme_font_size_override("font_size", 18)
	v.add_child(btn)
	var active := UIKit.body("Maxed out")
	active.add_theme_color_override("font_color", UITheme.LETTUCE.darkened(0.45))
	active.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active.custom_minimum_size = Vector2(0, 36)
	active.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	active.visible = false
	v.add_child(active)
	var na := UIKit.caption("Not available on this kitchen")
	na.add_theme_color_override("font_color", UITheme.TOMATO_DARK)
	na.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	na.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	na.custom_minimum_size = Vector2(CARD_W - 12, 36)
	na.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	na.visible = false
	v.add_child(na)
	_cards[id] = {"card": card, "button": btn, "price": price, "chip": price_row, "badge": badge, "active": active, "na": na,
		"name": nm, "level": lvl, "desc": desc, "state": "", "cost": 0}
	return card


## Shorter effect line for the cards (key hints live in the pause menu and the guide).
func _short_desc(id: String, level: int) -> String:
	if id == "gloves":
		return "Unlocks punching. Launch food, shove friends."
	if id == "second_plate":
		return "Unlocks the second plate and bell."
	return GameData.upgrade_desc(id, level)


func _on_buy(id: String) -> void:
	var c: Dictionary = _cards[id]
	var st := str(c["state"])
	if st.begins_with("poor"):
		UIKit.shake(c["card"], 7.0)
		var need := int(c["cost"]) - int(_wallet_shown)
		UIKit.toast(self, "Need %d more coins" % maxi(need, 1), "error", 1.6)
	elif st.begins_with("buy"):
		Net.buy(id)


func show_phase() -> void:
	_primed = false
	_wallet_shown = -1.0
	for id in _cards:
		_cards[id]["state"] = ""
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
	var focus_lost := false
	for u in GameData.UPGRADES:
		var id: String = u["id"]
		var c: Dictionary = _cards[id]
		var btn: Button = c["button"]
		var lv := sm.upgrade_level(id)
		var mx := GameData.upgrade_max_level(id)
		var price := sm.next_price(id)
		var st := "max" if price < 0 else ("buy" if sm.coins >= price else "poor")
		if st != "max" and not ShiftSystem.upgrade_available(id, sm.next_index):
			st = "na"   # e.g. Second Plate on a kitchen without a second plate
		elif st != "max" and not sm.requires_met(id):
			st = "locked"   # e.g. Heavy Gloves before Boxing Gloves
		var key := "%s:%d" % [st, lv]
		if key == c["state"]:
			continue
		var prev: String = c["state"]
		c["state"] = key
		c["cost"] = price
		var maxed := st == "max"
		var na := st == "na" or st == "locked"
		(c["name"] as Label).text = GameData.upgrade_title(id, mini(lv + 1, mx))
		(c["level"] as Label).text = ("Lv %d/%d" % [lv, mx]) if mx > 1 else ""
		(c["desc"] as Label).text = _short_desc(id, mini(lv + 1, mx))
		(c["price"] as Label).text = str(maxi(price, 0))
		if st == "locked":
			var req := GameData.upgrade_requires(id)
			(c["na"] as Label).text = "Needs %s" % GameData.upgrade_title(str(req[0]), int(req[1]))
		elif st == "na":
			(c["na"] as Label).text = "Not available on this kitchen"
		btn.text = "Upgrade" if lv > 0 else "Buy"
		btn.visible = not maxed and not na
		(c["chip"] as Control).visible = not maxed and not na
		(c["na"] as Control).visible = na
		(c["card"] as Control).modulate = Color(1, 1, 1, 0.6) if na else Color.WHITE
		if (na or maxed) and btn.has_focus():
			focus_lost = true
		(c["badge"] as Control).visible = maxed
		(c["active"] as Control).visible = maxed
		(c["price"] as Label).add_theme_color_override("font_color", UITheme.TOMATO_DARK if st == "poor" else UITheme.INK)
		btn.theme_type_variation = "SecondaryButton" if st == "poor" else "AccentButton"
		btn.modulate = Color(1, 1, 1, 0.7) if st == "poor" else Color.WHITE
		if prev != "" and _primed and lv > int(prev.get_slice(":", 1)):
			UIKit.punch(c["card"], 0.07, 0.3)
			if maxed:
				UIKit.punch(c["badge"], 0.5, 0.35)
			UIKit.toast(self, "Bought %s!" % GameData.upgrade_title(id, lv), "success", 2.0)
	if not _primed:
		_primed = true
		_focus_start()
	elif focus_lost:
		_focus_start()
	_next_lbl.text = _next_text(sm)
	_start.text = ("Retry mission" if sm.next_index == sm.index else "Start next mission") if Net.settings.mode == "campaign" else "Start next shift"


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


## First affordable Buy button, otherwise the host's Start button.
func _focus_start() -> void:
	for u in GameData.UPGRADES:
		var c: Dictionary = _cards[u["id"]]
		if str(c["state"]).begins_with("buy"):
			(c["button"] as Button).grab_focus.call_deferred()
			return
	if Net.is_host:
		_start.grab_focus.call_deferred()
	else:
		for u in GameData.UPGRADES:
			var c: Dictionary = _cards[u["id"]]
			if str(c["state"]).begins_with("poor"):
				(c["button"] as Button).grab_focus.call_deferred()
				return


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
