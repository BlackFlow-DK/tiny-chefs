class_name WardrobeView
extends Control
## The Wardrobe (menu "Wardrobe" button and the lobby): spend tokens on cosmetics and wear them.
## Left: a big live chef (turntable, idle animation, drag to spin) wearing the equipped look plus the item
## being previewed. Right: category tabs, a grid of item cards (rendered thumbnail, name, price / Owned /
## Wearing; "SOON" placeholder while a model is still being made), the token wallet, and one primary button:
## "Buy (N)" (disabled "Need N more" when short), "Wear", "Take off". Buying also wears the item.
## Catalogue: Cosmetics. Wallet + ownership: Progress (local). Wearing: Net.set_look (saves the equipped look
## and sends it to the host when connected, so every peer sees it).
## Keys / pad: arrows move between cards (focus previews), accept on a card = the primary action,
## Q / E or LB / RB switch tabs, Esc / B closes. Agent arg: --wardrobe=<tab>[:<id>] opens it from the menu.

signal closed

const TABS := [["hat", "Hats"], ["beard", "Beards"], ["acc", "Face"], ["outfit", "Outfits"], ["back", "Back"],
	["body", "Body"], ["color", "Colour"]]
const COLUMNS := 5
const CARD := Vector2(130, 162)
const THUMB := Vector2(112, 86)

var _panel: PanelContainer
var _view: LobbyChefView
var _stage: PanelContainer
var _wallet: UITokenChip
var _tabs: Dictionary = {}        # cat -> LobbyChoice
var _scroll: ScrollContainer
var _grid: GridContainer
var _name: Label
var _status: Label
var _action: Button
var _done: Button
var _cat := "hat"
var _sel := ""                    # selected id in _cat ("0".."3" on the Colour tab)
var _cards: Dictionary = {}       # id -> {"btn": LobbyChoice, "thumb": WardrobeIcons.Thumb, "state": Label}
var _mouse_down := false


func _init() -> void:
	UI.full_rect(self)
	visible = false
	add_child(UIKit.backdrop(0.74))
	var pv := UIKit.card(0)
	_panel = pv[0]
	_panel.custom_minimum_size = Vector2(1200, 660)
	var body: VBoxContainer = pv[1]
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(_build_left())
	cols.add_child(_build_right())
	add_child(UI.centred(_panel))


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(370, 0)
	left.add_theme_constant_override("separation", 8)
	_stage = PanelContainer.new()
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_stage)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.custom_minimum_size = Vector2(320, 460)
	_stage.add_child(stack)
	# Floor shadow under the chef, then the chef itself (fills the stage).
	var floor_disc := _FloorDisc.new()
	stack.add_child(floor_disc)
	floor_disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = LobbyChefView.new(Color.WHITE, Vector2i(320, 460))
	_view.turntable = true
	stack.add_child(_view)
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint := UIKit.caption("Drag to spin")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(hint)
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -4)
	var t := UIKit.title("Wardrobe")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(t)
	titles.add_child(UIKit.caption("Tokens come from shifts: 1 per %d coins, %d per new campaign star. Yours to keep."
		% [Progress.COINS_PER_TOKEN, Progress.TOKENS_PER_STAR]))
	head.add_child(titles)
	_wallet = UIKit.token_chip(0, true, "Your tokens", true)
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_wallet)
	right.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for tab: Array in TABS:
		var b := LobbyChoice.new(Vector2(0, 46))
		b.text = str(tab[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_open_tab.bind(str(tab[0]), true))
		tabs.add_child(b)
		_tabs[str(tab[0])] = b
	right.add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	var pad := MarginContainer.new()   # room for the hard shadows and focus rings
	for side in ["left", "top"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_theme_constant_override("margin_right", 6)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	pad.add_child(_grid)
	right.add_child(_scroll)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	_name = UIKit.heading("")
	info.add_child(_name)
	_status = UIKit.caption("")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(1, 0)
	info.add_child(_status)
	foot.add_child(info)
	_action = UIKit.button("Wear", _do_action, "primary", 220)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_action)
	_done = UIKit.button("Done", close, "secondary", 120)
	_done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_done)
	right.add_child(foot)
	return right


# ---------------------------------------------------------------- open / close

## Open on a tab (default: the last one), selecting an item of it (default: the one worn).
func open(cat := "", id := "") -> void:
	visible = true
	if not Net.looks_changed.is_connected(_on_looks_changed):
		Net.looks_changed.connect(_on_looks_changed)
	_wallet.set_amount(Progress.tokens(), false)
	UIKit.pop_in(_panel, 0.0, 0.18)
	_open_tab(cat if _tabs.has(cat) else _cat, false, id)


func close() -> void:
	if not visible:
		return
	visible = false
	if Net.looks_changed.is_connected(_on_looks_changed):
		Net.looks_changed.disconnect(_on_looks_changed)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or _pad(event, JOY_BUTTON_B):
		close()
	elif _key(event, KEY_Q) or _pad(event, JOY_BUTTON_LEFT_SHOULDER):
		_step_tab(-1)
	elif _key(event, KEY_E) or _pad(event, JOY_BUTTON_RIGHT_SHOULDER):
		_step_tab(1)
	else:
		return
	get_viewport().set_input_as_handled()


static func _key(e: InputEvent, k: Key) -> bool:
	return e is InputEventKey and e.is_pressed() and not e.is_echo() and (e as InputEventKey).keycode == k


static func _pad(e: InputEvent, b: JoyButton) -> bool:
	return e is InputEventJoypadButton and e.is_pressed() and (e as InputEventJoypadButton).button_index == b


func _step_tab(d: int) -> void:
	var i := 0
	for k in TABS.size():
		if TABS[k][0] == _cat:
			i = k
	_open_tab(str(TABS[posmod(i + d, TABS.size())][0]), true)


func _on_looks_changed() -> void:
	_refresh_cards()
	_refresh_preview()
	_refresh_footer()


# ---------------------------------------------------------------- my look

## My own look, resolved (immediate: the local pick, not the host's echo).
func _mine() -> Dictionary:
	return Net.resolve_look(Net.local_look, Net.slot_of(Net.my_id()))


func _worn_id(cat: String) -> String:
	var l := _mine()
	return str(int(l["color"])) if cat == "color" else str(l.get(cat, ""))


func _owns(cat: String, id: String) -> bool:
	return cat == "color" or Progress.owns(cat, id)


func _price(cat: String, id: String) -> int:
	return 0 if cat == "color" else Cosmetics.price(cat, id)


func _item_name(cat: String, id: String) -> String:
	if cat == "color":
		return "%s jacket" % GameData.COLOR_NAMES[posmod(int(id), GameData.COLOR_NAMES.size())]
	return Cosmetics.item_name(cat, id)


func _ids(cat: String) -> Array:
	if cat == "color":
		var out: Array = []
		for i in GameData.PLAYER_COLORS.size():
			out.append(str(i))
		return out
	return Cosmetics.items(cat).map(func(e: Dictionary) -> String: return str(e["id"]))


# ---------------------------------------------------------------- tabs + cards

## Show a category (focus lands on the selected card: want, else the worn item).
func _open_tab(cat: String, _from_tab := false, want := "") -> void:
	_cat = cat
	for k: String in _tabs:
		(_tabs[k] as LobbyChoice).select(k == cat)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cards.clear()
	var my_color := int(_mine()["color"])
	var ids := _ids(cat)
	for id: String in ids:
		_grid.add_child(_make_card(cat, id, my_color))
	# Render this tab's thumbnails first (urgent requests go to the front, so queue them back to front).
	for i in range(ids.size() - 1, -1, -1):
		(_cards[ids[i]]["thumb"] as WardrobeIcons.Thumb).refresh(true)
	var pick := want if ids.has(want) else _worn_id(cat)
	if not ids.has(pick):
		pick = str(ids[0])
	_select(pick)
	var b: LobbyChoice = _cards[pick]["btn"]
	_focus_later(b)
	_scroll_to(b)


## Deferred focus that survives the card being replaced first (fast tab switching).
func _focus_later(c: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
		c.grab_focus()


## Scroll the picked card's row to the top once the grid is laid out. Uses grid-local positions (the panel may
## still be scaled by its pop-in, which would skew ensure_control_visible's global rects).
func _scroll_to(c: Control) -> void:
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(c) and c.get_parent() == _grid:
		_scroll.scroll_vertical = int(c.position.y)


func _make_card(cat: String, id: String, my_color: int) -> Control:
	var b := LobbyChoice.new(CARD)
	b.focus_mode = Control.FOCUS_ALL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var thumb := WardrobeIcons.Thumb.new(cat, id, int(id) if cat == "color" else my_color, THUMB)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(thumb)
	var nm := UIKit.caption(_item_name(cat, id))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(CARD.x - 16, 0)
	b.track_label(nm, UITheme.INK)
	v.add_child(nm)
	var state_row := HBoxContainer.new()
	state_row.alignment = BoxContainer.ALIGNMENT_CENTER
	state_row.add_theme_constant_override("separation", 5)
	var tok := TokenIcon.new(18)
	state_row.add_child(tok)
	var st := UIKit.body("")
	st.add_theme_font_override("font", UITheme.font(true))
	state_row.add_child(st)
	v.add_child(state_row)
	b.set_body(v, 8)
	b.tooltip_text = _item_name(cat, id)
	b.button_down.connect(func() -> void: _mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	b.pressed.connect(_on_card_pressed.bind(id))
	b.focus_entered.connect(_on_card_focus.bind(id))
	_cards[id] = {"btn": b, "thumb": thumb, "state": st, "token": tok}
	_style_card(id)
	return b


## Keyboard / pad focus previews the card; a mouse click selects (the button does the rest).
func _on_card_focus(id: String) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and id != _sel:
		_select(id)


func _on_card_pressed(id: String) -> void:
	if _mouse_down or id != _sel:
		_mouse_down = false
		_select(id)
		return
	_do_action()   # accept on the selected card (keyboard / pad)


func _select(id: String) -> void:
	_sel = id
	for k: String in _cards:
		(_cards[k]["btn"] as LobbyChoice).select(k == id)
	_refresh_preview()
	_refresh_footer()


func _refresh_cards() -> void:
	var my_color := int(_mine()["color"])
	for id: String in _cards:
		_style_card(id)
		if _cat != "color":
			(_cards[id]["thumb"] as WardrobeIcons.Thumb).set_color(my_color)
		(_cards[id]["btn"] as LobbyChoice).select(id == _sel)


## The card's state line: price (with a token; red when short), "Owned", "Wearing" (green), "Free".
func _style_card(id: String) -> void:
	var c: Dictionary = _cards[id]
	var st: Label = c["state"]
	var tok: Control = c["token"]
	var worn := _worn_id(_cat) == id
	var owned := _owns(_cat, id)
	tok.visible = not owned
	st.remove_theme_color_override("font_color")
	if worn:
		st.text = "Wearing"
		st.add_theme_color_override("font_color", UITheme.LETTUCE.darkened(0.35))
	elif owned:
		st.text = "Free" if _cat == "color" or Cosmetics.is_free(_cat, id) else "Owned"
		st.add_theme_color_override("font_color", UITheme.INK_SOFT)
	else:
		var p := _price(_cat, id)
		st.text = str(p)
		if p > Progress.tokens():
			st.add_theme_color_override("font_color", UITheme.TOMATO_DARK)


# ---------------------------------------------------------------- preview + footer

func _refresh_preview() -> void:
	var l := _mine()
	if _cat == "color":
		l["color"] = int(_sel)
	elif _sel != "":
		l[_cat] = _sel
	_view.show_look(l)
	_view.face(_cat == "back")
	var col: Color = GameData.PLAYER_COLORS[posmod(int(l["color"]), GameData.PLAYER_COLORS.size())]
	var sb := UITheme.box(col.lerp(UITheme.CREAM_HI, 0.72), UITheme.INK, UITheme.R_CARD, UITheme.B_BTN, 4)
	sb.set_content_margin_all(6)
	_stage.add_theme_stylebox_override("panel", sb)


func _refresh_footer() -> void:
	if _sel == "":
		return
	var cat := _cat
	var id := _sel
	_name.text = _item_name(cat, id)
	var worn := _worn_id(cat) == id
	var owned := _owns(cat, id)
	var p := _price(cat, id)
	var have := Progress.tokens()
	var lines := PackedStringArray()
	_action.disabled = false
	_action.theme_type_variation = "PrimaryButton"
	if worn:
		var can_off := cat != "color" and id != str(Cosmetics.EMPTY.get(cat, id))
		_action.text = "Take off" if can_off else "Wearing"
		_action.theme_type_variation = "SecondaryButton" if can_off else "PrimaryButton"
		_action.disabled = not can_off
		lines.append("You are wearing this.")
	elif owned:
		_action.text = "Wear"
		_action.theme_type_variation = "GoButton"
		lines.append("Free for everyone." if p == 0 else "Yours. Wear it any time.")
	elif have >= p:
		_action.text = "Buy (%d)" % p
		lines.append("Costs %d tokens. You have %d." % [p, have])
	else:
		_action.text = "Need %d more" % (p - have)
		_action.disabled = true
		lines.append("Costs %d tokens. Finish shifts to earn more." % p)
	if cat != "color" and Cosmetics.model_missing(cat, id):
		lines.append("Model coming soon: until then it shows nothing.")
	_status.text = " ".join(lines)


func _do_action() -> void:
	if _sel == "":
		return
	var cat := _cat
	var id := _sel
	var card: Control = _cards[id]["btn"] if _cards.has(id) else null
	if _worn_id(cat) == id:
		var off := str(Cosmetics.EMPTY.get(cat, ""))
		if cat == "color" or off == id or off == "":
			return
		Net.set_look({cat: off})
		_select(off)
		_refresh_cards()
		return
	if not _owns(cat, id):
		var p := _price(cat, id)
		if not Progress.buy(cat, id):
			UIKit.shake(_wallet)
			UIKit.toast(self, "Need %d more tokens for the %s." % [p - Progress.tokens(), _item_name(cat, id)], "warn", 1.8)
			return
		_wallet.set_amount(Progress.tokens())
		print("wardrobe: bought %s:%s for %d, wallet %d" % [cat, id, p, Progress.tokens()])
		UIKit.toast(self, "%s is yours!" % _item_name(cat, id), "success", 1.8)
	if card != null:
		UIKit.punch(card, 0.14, 0.26)
	Net.set_look({cat: int(id)} if cat == "color" else {cat: id})
	_refresh_cards()
	_refresh_footer()
	_refresh_preview()


## A soft floor ellipse under the preview chef.
class _FloorDisc extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y * 0.86)
		var pts := PackedVector2Array()
		for k in 32:
			var a := TAU * k / 32.0
			pts.append(c + Vector2(cos(a) * size.x * 0.3, sin(a) * size.x * 0.07))
		draw_colored_polygon(pts, Color(UITheme.INK, 0.14))
