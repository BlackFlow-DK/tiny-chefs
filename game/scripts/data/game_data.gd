class_name GameData
extends RefCounted
## Content tables for Tiny Chefs: items (sizes from docs/asset-contract.md), kitchen layout,
## recipes, shifts and shop upgrades. Numbers you tune while balancing live in tuning.gd.
## Models: res://assets/models/<model>.glb is used when it exists, otherwise a coloured
## primitive of the contract size. Colliders always come from the sizes here.

## shape: cyl | box | sphere | dome | capsule_x   (fallback primitive + collider)
## weight: carriers needed for full carry speed. plate: may go on the serving plate.
## cooks_to: what the griddle turns it into. chops_to: what the cutting board makes.
const ITEMS := {
	"bun_bottom": {"label": "Bun bottom", "size": Vector3(3.2, 0.7, 3.2), "shape": "cyl", "color": Color(0.79, 0.55, 0.25), "weight": 2, "plate": true},
	"bun_top": {"label": "Bun top", "size": Vector3(3.2, 1.1, 3.2), "shape": "dome", "color": Color(0.85, 0.58, 0.26), "weight": 2, "plate": true},
	"patty_raw": {"label": "Raw patty", "size": Vector3(3.0, 0.6, 3.0), "shape": "cyl", "color": Color(0.85, 0.39, 0.42), "weight": 3, "plate": false, "cooks_to": "patty_cooked"},
	"patty_cooked": {"label": "Cooked patty", "size": Vector3(3.0, 0.6, 3.0), "shape": "cyl", "color": Color(0.42, 0.23, 0.12), "weight": 3, "plate": true, "cooks_to": "patty_burnt"},
	"patty_burnt": {"label": "Burnt patty", "size": Vector3(3.0, 0.6, 3.0), "shape": "cyl", "color": Color(0.12, 0.1, 0.09), "weight": 3, "plate": false},
	"cheese_slice": {"label": "Cheese", "size": Vector3(3.0, 0.15, 3.0), "shape": "box", "color": Color(1.0, 0.82, 0.2), "weight": 1, "plate": true},
	"lettuce_leaf": {"label": "Lettuce", "size": Vector3(3.2, 0.35, 3.2), "shape": "cyl", "color": Color(0.36, 0.79, 0.23), "weight": 1, "plate": true},
	"tomato": {"label": "Tomato", "size": Vector3(2.2, 2.2, 2.2), "shape": "sphere", "color": Color(0.9, 0.2, 0.15), "weight": 2, "plate": false, "chops_to": "tomato_slice"},
	"tomato_slice": {"label": "Tomato slice", "size": Vector3(2.0, 0.3, 2.0), "shape": "cyl", "color": Color(0.95, 0.35, 0.3), "weight": 1, "plate": true},
	"sausage_raw": {"label": "Raw sausage", "size": Vector3(4.5, 0.8, 0.8), "shape": "capsule_x", "color": Color(0.95, 0.66, 0.63), "weight": 3, "plate": false, "cooks_to": "sausage_cooked"},
	"sausage_cooked": {"label": "Sausage", "size": Vector3(4.5, 0.8, 0.8), "shape": "capsule_x", "color": Color(0.66, 0.28, 0.16), "weight": 3, "plate": true, "cooks_to": "sausage_burnt"},
	"sausage_burnt": {"label": "Burnt sausage", "size": Vector3(4.5, 0.8, 0.8), "shape": "capsule_x", "color": Color(0.16, 0.11, 0.09), "weight": 3, "plate": false},
	"hotdog_bun": {"label": "Hot dog bun", "size": Vector3(5.0, 1.0, 1.6), "shape": "box", "color": Color(0.85, 0.63, 0.36), "weight": 2, "plate": true},
}

## Fixed index order for network snapshots. Append only.
const ITEM_KINDS := [
	"bun_bottom", "bun_top", "patty_raw", "patty_cooked", "patty_burnt", "cheese_slice",
	"lettuce_leaf", "tomato", "tomato_slice", "sausage_raw", "sausage_cooked", "sausage_burnt", "hotdog_bun",
]

## Counter top: X from -30 to 30, Z from -18 to 18, surface at y = 0. The camera looks towards -Z.
const COUNTER_SIZE := Vector2(60.0, 36.0)
const COUNTER_HEIGHT := 29.0  # floor far below

## Stations. Flat ones (griddle, board, plate, trash) are sunk into the counter and have no collider,
## so chefs and food slide over them. Dispensers and the bell are solid.
const STATIONS := [
	{"type": "dispenser", "model": "dispenser_sausages", "pos": Vector3(-18, 0, -12), "size": Vector3(5, 4, 5), "gives": ["sausage_raw"], "label": "Sausages"},
	{"type": "dispenser", "model": "dispenser_patties", "pos": Vector3(-12, 0, -12), "size": Vector3(5, 4, 5), "gives": ["patty_raw"], "label": "Patties"},
	{"type": "dispenser", "model": "dispenser_buns", "pos": Vector3(-6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["bun_bottom", "bun_top"], "label": "Buns"},
	{"type": "dispenser", "model": "dispenser_cheese", "pos": Vector3(0, 0, -12), "size": Vector3(5, 4, 5), "gives": ["cheese_slice"], "label": "Cheese"},
	{"type": "dispenser", "model": "dispenser_lettuce", "pos": Vector3(6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["lettuce_leaf"], "label": "Lettuce"},
	{"type": "dispenser", "model": "dispenser_tomatoes", "pos": Vector3(12, 0, -12), "size": Vector3(5, 4, 5), "gives": ["tomato"], "label": "Tomatoes"},
	{"type": "dispenser", "model": "dispenser_hotdog_buns", "pos": Vector3(18, 0, -12), "size": Vector3(5, 4, 5), "gives": ["hotdog_bun"], "label": "Hot dog buns"},
	{"type": "griddle", "model": "griddle", "pos": Vector3(-10, 0, 0), "size": Vector3(9, 0.5, 7), "label": "Griddle"},
	{"type": "board", "model": "cutting_board", "pos": Vector3(10, 0, 0), "size": Vector3(9, 0.4, 6), "label": "Cutting board"},
	{"type": "plate", "model": "plate", "pos": Vector3(0, 0, 8), "size": Vector3(7, 0.4, 7), "label": "Plate"},
	{"type": "bell", "model": "service_bell", "pos": Vector3(6.5, 0, 8), "size": Vector3(2, 1.6, 2), "label": "Serve"},
	{"type": "trash", "model": "trash_drain", "pos": Vector3(-18, 0, 8), "size": Vector3(4, 0.2, 4), "label": "Trash"},
]

## Big props for scale. Solid. "collider" overrides the box used for collision (sink tap arches over).
## Optional "yaw" (degrees) turns the prop and its collider. Tall props sit at the back and ends so
## they never hide stations from the camera; the front strip only gets low ones.
## sink_basin is built in code (Kitchen cuts the counter there); its collider is the whole footprint.
const SCENERY := [
	{"model": "salt_shaker", "pos": Vector3(24, 0, 10), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.9, 0.93, 0.95)},
	{"model": "pepper_shaker", "pos": Vector3(27, 0, 14), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.25, 0.25, 0.27)},
	{"model": "ketchup_bottle", "pos": Vector3(-26, 0, 13), "size": Vector3(3.5, 10, 3.5), "shape": "cyl", "color": Color(0.84, 0.17, 0.12)},
	{"model": "utensil_pot", "pos": Vector3(25, 0, -12), "size": Vector3(6, 14, 6), "shape": "cyl", "color": Color(0.44, 0.56, 0.69)},
	{"model": "sink_tap", "pos": Vector3(-25, 0, -14), "size": Vector3(6, 12, 8), "shape": "box", "color": Color(0.75, 0.78, 0.8), "collider": Vector3(3, 12, 3), "collider_offset": Vector3(0, 0, -2.5)},
	{"model": "sink_basin", "pos": Vector3(-25, 0, -10.5), "size": Vector3(6, 1.0, 6), "shape": "box", "color": Color(0.78, 0.8, 0.83)},
	{"model": "oil_bottle", "pos": Vector3(-28.6, 0, -16.7), "size": Vector3(2.5, 9, 2.5), "shape": "cyl", "color": Color(0.86, 0.68, 0.2)},
	{"model": "dish_sponge", "pos": Vector3(-24.8, 0, -5.5), "size": Vector3(5, 1.5, 3), "shape": "box", "color": Color(0.98, 0.84, 0.3), "yaw": 10.0},
	{"model": "kettle", "pos": Vector3(-26.6, 0, -1.1), "size": Vector3(6, 6.5, 5), "shape": "cyl", "color": Color(0.55, 0.78, 0.74), "yaw": -20.0},
	{"model": "paper_towel_roll", "pos": Vector3(28.0, 0, 9.3), "size": Vector3(4, 9, 4), "shape": "cyl", "color": Color(0.97, 0.97, 0.95)},
	{"model": "cookbook_stack", "pos": Vector3(-19.5, 0, 14.6), "size": Vector3(8, 3.5, 6), "shape": "box", "color": Color(0.76, 0.28, 0.22), "yaw": 10.0},
	{"model": "rolling_pin", "pos": Vector3(12, 0, 15.4), "size": Vector3(10, 1.4, 1.4), "shape": "capsule_x", "color": Color(0.85, 0.68, 0.46), "yaw": 18.0},
	{"model": "coffee_mug", "pos": Vector3(18, 0, 13), "size": Vector3(4.5, 4.5, 4), "shape": "cyl", "color": Color(0.9, 0.42, 0.3), "yaw": -30.0},
	{"model": "toaster", "pos": Vector3(26, 0, -4.6), "size": Vector3(8, 6, 5), "shape": "box", "color": Color(0.62, 0.82, 0.78), "yaw": -8.0},
	{"model": "fruit_bowl", "pos": Vector3(24.6, 0, 3.0), "size": Vector3(9, 4.5, 9), "shape": "cyl", "color": Color(0.93, 0.9, 0.84)},
	{"model": "spice_jar_a", "pos": Vector3(21.8, 0, -16.6), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.78, 0.3, 0.16)},
	{"model": "spice_jar_b", "pos": Vector3(23.9, 0, -16.9), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.9, 0.7, 0.2)},
	{"model": "spice_jar_c", "pos": Vector3(28.9, 0, -16.4), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.4, 0.55, 0.28)},
]

const SPAWN_POINTS := [Vector3(-2, 0, 1), Vector3(2, 0, 1), Vector3(-2, 0, -3), Vector3(2, 0, -3)]

## Player colours in join order: blue, red, green, yellow.
const PLAYER_COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]

## Recipes. Plate contents must match "items" exactly as a multiset (stacking order is free).
## price is paid on serve, plus up to "bonus" scaled by the patience left.
const RECIPES := [
	{"id": "cheeseburger", "name": "Cheeseburger", "items": ["bun_bottom", "patty_cooked", "cheese_slice", "bun_top"], "price": 40, "bonus": 20},
	{"id": "salad", "name": "Garden Salad", "items": ["lettuce_leaf", "lettuce_leaf", "tomato_slice", "tomato_slice"], "price": 35, "bonus": 15},
	{"id": "double", "name": "Double Beef Cheeseburger", "items": ["bun_bottom", "patty_cooked", "patty_cooked", "cheese_slice", "cheese_slice", "bun_top"], "price": 75, "bonus": 30},
	{"id": "hotdog", "name": "Hot Dog", "items": ["hotdog_bun", "sausage_cooked"], "price": 35, "bonus": 15},
]

## Shifts (base values for ONE player; see Tuning.SCALE_* for more players).
## interval: seconds between new orders. patience: seconds an order waits. target: coins to earn.
const SHIFTS := [
	{"name": "Lunch Warm-up", "recipes": ["cheeseburger", "salad"], "interval": 40.0, "patience": 110.0, "duration": 210.0, "target": 80},
	{"name": "Double Trouble", "recipes": ["cheeseburger", "salad", "double"], "interval": 34.0, "patience": 105.0, "duration": 210.0, "target": 120},
	{"name": "Hot Dog Rush", "recipes": ["cheeseburger", "salad", "double", "hotdog"], "interval": 28.0, "patience": 95.0, "duration": 210.0, "target": 160},
]

## Shared team wallet; upgrades last for the run.
const UPGRADES := [
	{"id": "gloves", "name": "Boxing Gloves", "desc": "Unlocks punching (Q / right mouse / pad B). Launch food, shove friends.", "price": 60},
	{"id": "knife", "name": "Sharp Knife", "desc": "Chopping is twice as fast.", "price": 50},
	{"id": "shoes", "name": "Running Shoes", "desc": "+20% move and carry speed.", "price": 80},
]


static func item(kind: String) -> Dictionary:
	return ITEMS[kind]


static func kind_index(kind: String) -> int:
	return ITEM_KINDS.find(kind)


static func recipe_index(id: String) -> int:
	for i in RECIPES.size():
		if RECIPES[i]["id"] == id:
			return i
	return -1


static func upgrade(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}


## ShiftDef for shift i (0-based) of the current run, scaled for the player count: ShiftPlan.build with
## the session's settings (Net.settings). Kept for existing callers; new code calls ShiftPlan.build.
## (The endless ramp over SHIFTS lives in ShiftPlan._endless_base.)
static func shift_def(i: int, players: int, settings: GameSettings = null) -> Dictionary:
	if settings == null:
		# Looked up by path, not the Net identifier, so data scripts compile without the autoloads.
		var net := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Net")
		if net != null:
			settings = net.get("settings")
	return ShiftPlan.build(settings, i, players)
