class_name EndScreens
extends Control
## End of shift: the results card, then the shop (shared wallet). The host advances.
## Views live in results_view.gd / shop_view.gd.

var world: World = null

var _results: ResultsView
var _shop: ShopView


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results = ResultsView.new()
	add_child(_results)
	_shop = ShopView.new()
	add_child(_shop)
	show_phase(Net.phase)


func show_phase(ph: int) -> void:
	visible = ph == Net.Phase.RESULTS or ph == Net.Phase.SHOP
	_results.visible = ph == Net.Phase.RESULTS
	_shop.visible = ph == Net.Phase.SHOP
	if ph == Net.Phase.RESULTS:
		_results.show_results(Net.phase_info)
	elif ph == Net.Phase.SHOP:
		_shop.show_phase()


func _process(_delta: float) -> void:
	if visible and _shop.visible and world != null and is_instance_valid(world):
		_shop.update(world.shift)
