class_name EndScreens
extends Control
## End of shift: the results card, then the shop (shared wallet). The host advances.

var world: World = null

var _results: PanelContainer
var _res_text: Label
var _res_verdict: Label
var _res_button: Button
var _res_wait: Label
var _shop: PanelContainer
var _shop_coins: Label
var _shop_rows: Array = []  # [upgrade id, Button]
var _shop_next: Label
var _shop_button: Button
var _shop_wait: Label


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(dim)
	add_child(dim)

	var rv := UI.panel(10)
	_results = rv[0]
	var v: VBoxContainer = rv[1]
	_results.custom_minimum_size = Vector2(480, 0)
	v.add_child(UI.label("Shift over!", 40, UI.YELLOW))
	_res_text = UI.label("", 20)
	v.add_child(_res_text)
	_res_verdict = UI.label("", 26)
	v.add_child(_res_verdict)
	_res_button = UI.button("Go to the shop", func() -> void: Net.set_phase(Net.Phase.SHOP, Net.phase_info))
	_res_button.focus_mode = Control.FOCUS_NONE
	v.add_child(_res_button)
	_res_wait = UI.label("Waiting for the host...", 16, UI.DIM)
	v.add_child(_res_wait)
	add_child(UI.centred(_results))

	var sv := UI.panel(10)
	_shop = sv[0]
	var s: VBoxContainer = sv[1]
	_shop.custom_minimum_size = Vector2(620, 0)
	s.add_child(UI.label("Chef shop", 40, UI.YELLOW))
	s.add_child(UI.label("Shared team wallet. Upgrades help everyone for the rest of the run.", 15, UI.DIM))
	_shop_coins = UI.label("", 24, UI.GREEN)
	s.add_child(_shop_coins)
	for u in GameData.UPGRADES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := UI.label("%s\n%s" % [u["name"], u["desc"]], 16)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size = Vector2(380, 0)
		row.add_child(info)
		var id: String = u["id"]
		var b := UI.button("", func() -> void: Net.buy(id), 170)
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)
		s.add_child(row)
		_shop_rows.append([id, b])
	_shop_next = UI.label("", 18)
	s.add_child(_shop_next)
	_shop_button = UI.button("Start next shift", func() -> void: Net.set_phase(Net.Phase.PLAYING, {}))
	_shop_button.focus_mode = Control.FOCUS_NONE
	s.add_child(_shop_button)
	_shop_wait = UI.label("Anyone can buy. Waiting for the host to start the next shift...", 16, UI.DIM)
	s.add_child(_shop_wait)
	add_child(UI.centred(_shop))
	show_phase(Net.phase)


func show_phase(ph: int) -> void:
	visible = ph == Net.Phase.RESULTS or ph == Net.Phase.SHOP
	_results.visible = ph == Net.Phase.RESULTS
	_shop.visible = ph == Net.Phase.SHOP
	if ph == Net.Phase.RESULTS:
		var i := Net.phase_info
		_res_text.text = "Shift %d: %s\nOrders served: %d\nOrders failed: %d\nCoins earned: %d  (target %d)\nTeam wallet: %d coins" % [
			int(i.get("shift", 0)) + 1, str(i.get("name", "")), int(i.get("served", 0)), int(i.get("failed", 0)),
			int(i.get("earned", 0)), int(i.get("target", 0)), int(i.get("coins", 0))]
		var met := bool(i.get("met", false))
		_res_verdict.text = "TARGET MET! On to the next shift." if met else "Target missed. The shift will be retried."
		_res_verdict.add_theme_color_override("font_color", UI.GREEN if met else UI.RED)
		_res_button.visible = Net.is_host
		_res_wait.visible = not Net.is_host
	_shop_button.visible = Net.is_host
	_shop_wait.visible = not Net.is_host


func _process(_delta: float) -> void:
	if not visible or not _shop.visible or world == null or not is_instance_valid(world):
		return
	var sm := world.shift
	_shop_coins.text = "Team wallet: %d coins" % sm.coins
	for row in _shop_rows:
		var u := GameData.upgrade(row[0])
		var b: Button = row[1]
		if sm.has_upgrade(row[0]):
			b.text = "Owned"
			b.disabled = true
		else:
			b.text = "Buy (%d)" % int(u["price"])
			b.disabled = sm.coins < int(u["price"])
	var nd := GameData.shift_def(sm.next_index, maxi(1, Net.players.size()))
	if sm.next_index == sm.index:
		_shop_next.text = "Next: retry shift %d, %s (target %d)" % [sm.next_index + 1, nd["name"], nd["target"]]
	else:
		_shop_next.text = "Next: shift %d, %s (target %d)" % [sm.next_index + 1, nd["name"], nd["target"]]
