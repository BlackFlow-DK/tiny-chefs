class_name GameData
extends RefCounted
## Content tables for Tiny Chefs: items (sizes from docs/asset-contract.md), kitchen layout,
## recipes, shifts and shop upgrades. Numbers you tune while balancing live in tuning.gd.
## Models: res://assets/models/<model>.glb is used when it exists, otherwise a coloured
## primitive of the contract size. Colliders always come from the sizes here.

## shape: cyl | box | sphere | dome | capsule_x   (fallback primitive + collider)
## weight: carriers needed for full carry speed. plate: may go on the serving plate.
## cooks_to: what the griddle turns it into. chops_to: what the cutting board makes (chop_count pieces,
## default Tuning.CHOP_SLICES). fries_to: what the fryer turns it into. A cooks_to/fries_to whose target
## changes again is the cook stage (COOK_TIME / FRY_TIME, CRACK_TIME when "crack"); the last is the burn stage.
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
	# Overnight content (docs/design/overnight-1.md section 1).
	"bacon_raw": {"label": "Raw bacon", "size": Vector3(4.0, 0.3, 1.2), "shape": "capsule_x", "color": Color(0.94, 0.55, 0.55), "weight": 1, "plate": false, "cooks_to": "bacon_cooked"},
	"bacon_cooked": {"label": "Bacon", "size": Vector3(4.0, 0.3, 1.2), "shape": "capsule_x", "color": Color(0.72, 0.3, 0.17), "weight": 1, "plate": true, "cooks_to": "bacon_burnt"},
	"bacon_burnt": {"label": "Burnt bacon", "size": Vector3(4.0, 0.3, 1.2), "shape": "capsule_x", "color": Color(0.15, 0.1, 0.08), "weight": 1, "plate": false},
	"egg": {"label": "Egg", "size": Vector3(1.8, 2.2, 1.8), "shape": "sphere", "color": Color(0.97, 0.94, 0.86), "weight": 1, "plate": false, "cooks_to": "fried_egg", "crack": true},
	"fried_egg": {"label": "Fried egg", "size": Vector3(3.0, 0.4, 3.0), "shape": "cyl", "color": Color(1.0, 0.9, 0.55), "weight": 1, "plate": true, "cooks_to": "egg_burnt"},
	"egg_burnt": {"label": "Burnt egg", "size": Vector3(3.0, 0.4, 3.0), "shape": "cyl", "color": Color(0.3, 0.23, 0.14), "weight": 1, "plate": false},
	"onion": {"label": "Onion", "size": Vector3(2.4, 2.4, 2.4), "shape": "sphere", "color": Color(0.84, 0.66, 0.4), "weight": 2, "plate": false, "chops_to": "onion_slice"},
	"onion_slice": {"label": "Onion slice", "size": Vector3(2.2, 0.3, 2.2), "shape": "cyl", "color": Color(0.9, 0.78, 0.92), "weight": 1, "plate": true, "fries_to": "onion_rings"},
	"onion_rings": {"label": "Onion rings", "size": Vector3(2.6, 0.8, 2.6), "shape": "cyl", "color": Color(0.9, 0.62, 0.26), "weight": 1, "plate": true, "fries_to": "onion_rings_burnt"},
	"onion_rings_burnt": {"label": "Burnt rings", "size": Vector3(2.6, 0.8, 2.6), "shape": "cyl", "color": Color(0.2, 0.14, 0.1), "weight": 1, "plate": false},
	"pickle_slice": {"label": "Pickle", "size": Vector3(1.6, 0.25, 1.6), "shape": "cyl", "color": Color(0.42, 0.62, 0.2), "weight": 1, "plate": true},
	"potato": {"label": "Potato", "size": Vector3(2.6, 2.0, 2.0), "shape": "sphere", "color": Color(0.72, 0.55, 0.34), "weight": 2, "plate": false, "chops_to": "fries_raw", "chop_count": 1},
	"fries_raw": {"label": "Cut potato", "size": Vector3(2.8, 1.2, 2.8), "shape": "box", "color": Color(0.97, 0.91, 0.68), "weight": 2, "plate": false, "fries_to": "fries"},
	"fries": {"label": "Fries", "size": Vector3(2.8, 2.5, 2.8), "shape": "box", "color": Color(0.97, 0.63, 0.15), "weight": 1, "plate": true, "fries_to": "fries_burnt"},
	"fries_burnt": {"label": "Burnt fries", "size": Vector3(2.8, 2.5, 2.8), "shape": "box", "color": Color(0.28, 0.19, 0.1), "weight": 1, "plate": false},
	"chicken_raw": {"label": "Raw chicken", "size": Vector3(3.0, 0.7, 3.0), "shape": "cyl", "color": Color(0.98, 0.78, 0.7), "weight": 3, "plate": false, "fries_to": "chicken_cooked"},
	"chicken_cooked": {"label": "Crispy chicken", "size": Vector3(3.0, 0.7, 3.0), "shape": "cyl", "color": Color(0.8, 0.5, 0.18), "weight": 3, "plate": true, "fries_to": "chicken_burnt"},
	"chicken_burnt": {"label": "Burnt chicken", "size": Vector3(3.0, 0.7, 3.0), "shape": "cyl", "color": Color(0.2, 0.13, 0.08), "weight": 3, "plate": false},
	"soda_cup": {"label": "Soda", "size": Vector3(2.2, 3.0, 2.2), "shape": "cyl", "color": Color(0.88, 0.18, 0.24), "weight": 1, "plate": true},
}

## Fixed index order for network snapshots. Append only.
const ITEM_KINDS := [
	"bun_bottom", "bun_top", "patty_raw", "patty_cooked", "patty_burnt", "cheese_slice",
	"lettuce_leaf", "tomato", "tomato_slice", "sausage_raw", "sausage_cooked", "sausage_burnt", "hotdog_bun",
	"bacon_raw", "bacon_cooked", "bacon_burnt", "egg", "fried_egg", "egg_burnt",
	"onion", "onion_slice", "onion_rings", "onion_rings_burnt", "pickle_slice",
	"potato", "fries_raw", "fries", "fries_burnt", "chicken_raw", "chicken_cooked", "chicken_burnt", "soda_cup",
]

## Counter tops are the map's "surfaces" (see MAPS), all at y = 0. The camera looks towards -Z.
const COUNTER_HEIGHT := 29.0  # floor far below

## The diner layout below (STATIONS, SCENERY, SPAWN_POINTS) is MAPS.diner's data. Read layouts only
## through GameData.map(id) / World.map, never these constants directly.

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
	# Second plate + bell: closed until the "second_plate" upgrade is bought.
	{"type": "plate", "model": "plate", "pos": Vector3(-8, 0, 8), "size": Vector3(7, 0.4, 7), "label": "Plate 2", "upgrade": "second_plate"},
	{"type": "bell", "model": "service_bell", "pos": Vector3(-14, 0, 8), "size": Vector3(2, 1.6, 2), "label": "Serve 2", "upgrade": "second_plate"},
	# Overnight content. Optional "yaw" (degrees) turns a station; the end dispensers face the counter centre.
	{"type": "dispenser", "model": "dispenser_bacon", "pos": Vector3(-27.4, 0, 5.5), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["bacon_raw"], "label": "Bacon"},
	{"type": "dispenser", "model": "dispenser_eggs", "pos": Vector3(-27.4, 0, 10.5), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["egg"], "label": "Eggs"},
	{"type": "dispenser", "model": "dispenser_onions", "pos": Vector3(-27.4, 0, 15.5), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["onion"], "label": "Onions"},
	{"type": "dispenser", "model": "dispenser_pickles", "pos": Vector3(27.4, 0, -4.3), "yaw": -90.0, "size": Vector3(5, 4, 5), "gives": ["pickle_slice"], "label": "Pickles"},
	{"type": "dispenser", "model": "dispenser_potatoes", "pos": Vector3(27.4, 0, 10.0), "yaw": -90.0, "size": Vector3(5, 4, 5), "gives": ["potato"], "label": "Potatoes"},
	{"type": "dispenser", "model": "dispenser_chicken", "pos": Vector3(27.4, 0, 15.3), "yaw": -90.0, "size": Vector3(5, 4, 5), "gives": ["chicken_raw"], "label": "Chicken"},
	{"type": "fryer", "model": "fryer", "pos": Vector3(0, 0, -3.5), "size": Vector3(7, 0.5, 6), "label": "Fryer"},
	{"type": "soda", "model": "soda_fountain", "pos": Vector3(12, 0, 8), "size": Vector3(4, 5, 3), "gives": ["soda_cup"], "label": "Soda"},
]

## Big props for scale. Solid. "collider" overrides the box used for collision (sink tap arches over).
## Optional "yaw" (degrees) turns the prop and its collider. Tall props sit at the back and ends so
## they never hide stations from the camera; the front strip only gets low ones.
## sink_basin is built in code (Kitchen cuts the counter there); its collider is the whole footprint.
const SCENERY := [
	{"model": "salt_shaker", "pos": Vector3(9, 0, -16.3), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.9, 0.93, 0.95)},
	{"model": "pepper_shaker", "pos": Vector3(15, 0, -16.3), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.25, 0.25, 0.27)},
	{"model": "ketchup_bottle", "pos": Vector3(-9, 0, -16.25), "size": Vector3(3.5, 10, 3.5), "shape": "cyl", "color": Color(0.84, 0.17, 0.12)},
	{"model": "utensil_pot", "pos": Vector3(25, 0, -12), "size": Vector3(6, 14, 6), "shape": "cyl", "color": Color(0.44, 0.56, 0.69)},
	{"model": "sink_tap", "pos": Vector3(-25, 0, -14), "size": Vector3(6, 12, 8), "shape": "box", "color": Color(0.75, 0.78, 0.8), "collider": Vector3(3, 12, 3), "collider_offset": Vector3(0, 0, -2.5)},
	{"model": "sink_basin", "pos": Vector3(-25, 0, -10.5), "size": Vector3(6, 1.0, 6), "shape": "box", "color": Color(0.78, 0.8, 0.83)},
	{"model": "oil_bottle", "pos": Vector3(-28.6, 0, -16.7), "size": Vector3(2.5, 9, 2.5), "shape": "cyl", "color": Color(0.86, 0.68, 0.2)},
	{"model": "dish_sponge", "pos": Vector3(-8.0, 0, 16.0), "size": Vector3(5, 1.5, 3), "shape": "box", "color": Color(0.98, 0.84, 0.3), "yaw": 10.0},
	{"model": "kettle", "pos": Vector3(-26.6, 0, 0.0), "size": Vector3(6, 6.5, 5), "shape": "cyl", "color": Color(0.55, 0.78, 0.74)},
	{"model": "paper_towel_roll", "pos": Vector3(-15.0, 0, -16.0), "size": Vector3(4, 9, 4), "shape": "cyl", "color": Color(0.97, 0.97, 0.95)},
	{"model": "cookbook_stack", "pos": Vector3(-16.0, 0, 14.6), "size": Vector3(8, 3.5, 6), "shape": "box", "color": Color(0.76, 0.28, 0.22), "yaw": 10.0},
	{"model": "rolling_pin", "pos": Vector3(12, 0, 15.4), "size": Vector3(10, 1.4, 1.4), "shape": "capsule_x", "color": Color(0.85, 0.68, 0.46), "yaw": 18.0},
	{"model": "coffee_mug", "pos": Vector3(18, 0, 13), "size": Vector3(4.5, 4.5, 4), "shape": "cyl", "color": Color(0.9, 0.42, 0.3), "yaw": -30.0},
	{"model": "toaster", "pos": Vector3(-25.5, 0, -5.2), "size": Vector3(8, 6, 5), "shape": "box", "color": Color(0.62, 0.82, 0.78)},
	{"model": "fruit_bowl", "pos": Vector3(24.6, 0, 3.0), "size": Vector3(9, 4.5, 9), "shape": "cyl", "color": Color(0.93, 0.9, 0.84)},
	{"model": "spice_jar_a", "pos": Vector3(21.8, 0, -16.6), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.78, 0.3, 0.16)},
	{"model": "spice_jar_b", "pos": Vector3(23.9, 0, -16.9), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.9, 0.7, 0.2)},
	{"model": "spice_jar_c", "pos": Vector3(28.9, 0, -16.4), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.4, 0.55, 0.28)},
	{"model": "hob", "pos": Vector3(-25.2, 0, 0.5), "size": Vector3(9, 0.05, 7), "flat": true},
]

const SPAWN_POINTS := [Vector3(-2, 0, 1), Vector3(2, 0, 1), Vector3(-2, 0, -3), Vector3(2, 0, -3)]

## Maps: id -> MapDef. Kitchen, bounds, spawns, camera and bots read the chosen one through World.map.
##   name, blurb: String (menu text). theme: String room/props look ("diner", "picnic"; unknown -> diner).
##   dev: bool (optional) hidden from players, only via --map=<id>.
##   surfaces: Array of Rect2(x, z, w, h) counter tops at y = 0 (overlap them to join; a point is on
##     the counter when it is inside any of them). Each gets a slab, trim, cabinets and a collider.
##   stations: Array of station dicts (format of STATIONS). Exactly one griddle, board and trash per map
##     (World keeps one of each), any number of dispensers. One or more plate + bell pairs: each bell serves
##     its nearest plate (World.plates/bells, first = World.plate/bell). Optional "upgrade": "<id>" on any
##     plate/bell keeps it closed (lid, refuses food and serving) until that upgrade is owned, e.g. a second
##     pair with "upgrade": "second_plate".
##   scenery: Array of prop dicts (format of SCENERY). "flat": true = decoration without collider
##     ("hob" is built in code); "sink_basin" cuts a hole in the surface under it.
##   spawn_points: Array of Vector3, one per player slot (wraps). hazards: Array of hazard ids.
##   decor: Array (optional) theme dressing tied to this layout ("diner_clutter", "picnic_clutter", "island_sink", "islands_clutter").
##   camera_bounds: Rect2 (optional) camera focus clamp instead of the surfaces' bounds.
##   target_scale: float (optional, default 1.0) endless shift targets x this on maps with longer hauls
##     (ShiftPlan.target_scale; campaign missions set their own targets). See docs/balance.md.
##   surface_styles: Array (optional, parallel to surfaces) "counter" (default) or "plank" (Kitchen.surface_style).
##   menu_view: Dictionary (optional) menu backdrop camera: "focus" Vector3, "yaw" degrees, "lift" m (MenuDiorama).
##   menu: Dictionary (optional) menu backdrop framing: "focus" Vector3, "plate" Vector3, "height" m (MenuDiorama;
##     merged with menu_view, so a map may use either or both).
## A static var (not const) so bigger maps can live in their own file (data/maps/map_<id>.gd, def()).
static var MAPS := {
	"diner": {
		"id": "diner", "name": "The Diner", "blurb": "The classic kitchen island: everything within a few steps.",
		"theme": "diner", "surfaces": [Rect2(-30, -18, 60, 36)], "stations": STATIONS, "scenery": SCENERY,
		"spawn_points": SPAWN_POINTS, "hazards": ["cat_paw"], "decor": ["diner_clutter"],
	},
	"test_islands": {
		"id": "test_islands", "name": "Test Islands", "blurb": "Dev map: two islands and a plank.", "dev": true,
		"theme": "diner",
		"surfaces": [Rect2(-23, -10, 20, 20), Rect2(3, -10, 20, 20), Rect2(-4, -2, 8, 4)],
		"stations": [
			{"type": "dispenser", "model": "dispenser_buns", "pos": Vector3(-19, 0, -6), "size": Vector3(5, 4, 5), "gives": ["bun_bottom", "bun_top"], "label": "Buns"},
			{"type": "dispenser", "model": "dispenser_patties", "pos": Vector3(-13, 0, -6), "size": Vector3(5, 4, 5), "gives": ["patty_raw"], "label": "Patties"},
			{"type": "dispenser", "model": "dispenser_cheese", "pos": Vector3(-7, 0, -6), "size": Vector3(5, 4, 5), "gives": ["cheese_slice"], "label": "Cheese"},
			{"type": "trash", "model": "trash_drain", "pos": Vector3(-19, 0, 6), "size": Vector3(4, 0.2, 4), "label": "Trash"},
			{"type": "griddle", "model": "griddle", "pos": Vector3(8, 0, -5), "size": Vector3(9, 0.5, 7), "label": "Griddle"},
			{"type": "board", "model": "cutting_board", "pos": Vector3(18, 0, -5), "size": Vector3(9, 0.4, 6), "label": "Cutting board"},
			{"type": "plate", "model": "plate", "pos": Vector3(8, 0, 5), "size": Vector3(7, 0.4, 7), "label": "Plate"},
			{"type": "bell", "model": "service_bell", "pos": Vector3(14.5, 0, 5), "size": Vector3(2, 1.6, 2), "label": "Serve"},
		],
		"scenery": [],
		"spawn_points": [Vector3(-9, 0, 2), Vector3(-15, 0, 2), Vector3(-8, 0, 0), Vector3(-15, 0, 6)],
		"hazards": [],
	},
	"picnic": MapPicnic.def(),
	"twin_islands": preload("res://scripts/data/maps/map_twin_islands.gd").DEF,
}

## Player colours: blue, red, green, yellow. A player's default is its join slot; any can be picked
## in the lobby (duplicates allowed). The chosen index lives in Net.players[id]["color"].
const PLAYER_COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]
const COLOR_NAMES := ["Blue", "Red", "Green", "Yellow"]

## Chef looks (lobby customisation). Hat model: hat_<id>.glb at Chef.HAT_ANCHOR, except "toque", which is
## the Toque mesh built into chef.glb. Accessory model: acc_<id>.glb at Chef.FACE_ANCHOR ("none" = nothing).
## First entry = default.
const HATS := [
	{"id": "toque", "label": "Toque"},
	{"id": "beanie", "label": "Beanie"},
	{"id": "paper", "label": "Paper hat"},
	{"id": "bandana", "label": "Bandana"},
]
const ACCESSORIES := [
	{"id": "none", "label": "None"},
	{"id": "glasses", "label": "Glasses"},
	{"id": "moustache", "label": "Moustache"},
]


static func has_hat(id: String) -> bool:
	return HATS.any(func(h: Dictionary) -> bool: return h["id"] == id)


static func has_accessory(id: String) -> bool:
	return ACCESSORIES.any(func(a: Dictionary) -> bool: return a["id"] == id)

## Recipes. Plate contents must match "items" exactly as a multiset (stacking order is free).
## price is paid on serve, plus up to "bonus" scaled by the patience left.
const RECIPES := [
	{"id": "cheeseburger", "name": "Cheeseburger", "items": ["bun_bottom", "patty_cooked", "cheese_slice", "bun_top"], "price": 45, "bonus": 20},
	{"id": "salad", "name": "Garden Salad", "items": ["lettuce_leaf", "lettuce_leaf", "tomato_slice", "tomato_slice"], "price": 35, "bonus": 15},
	{"id": "double", "name": "Double Beef Cheeseburger", "items": ["bun_bottom", "patty_cooked", "patty_cooked", "cheese_slice", "cheese_slice", "bun_top"], "price": 75, "bonus": 30},
	{"id": "hotdog", "name": "Hot Dog", "items": ["hotdog_bun", "sausage_cooked"], "price": 40, "bonus": 15},
	{"id": "bacon_cheeseburger", "name": "Bacon Cheeseburger", "items": ["bun_bottom", "patty_cooked", "cheese_slice", "bacon_cooked", "bun_top"], "price": 60, "bonus": 25},
	{"id": "breakfast_burger", "name": "Breakfast Burger", "items": ["bun_bottom", "patty_cooked", "fried_egg", "bacon_cooked", "bun_top"], "price": 65, "bonus": 25},
	{"id": "chicken_burger", "name": "Crispy Chicken Burger", "items": ["bun_bottom", "chicken_cooked", "lettuce_leaf", "bun_top"], "price": 60, "bonus": 25},
	{"id": "pickle_burger", "name": "Pickle Burger", "items": ["bun_bottom", "patty_cooked", "cheese_slice", "pickle_slice", "pickle_slice", "bun_top"], "price": 60, "bonus": 25},
	{"id": "the_works", "name": "The Works", "items": ["bun_bottom", "patty_cooked", "patty_cooked", "cheese_slice", "bacon_cooked", "onion_slice", "tomato_slice", "lettuce_leaf", "bun_top"], "price": 120, "bonus": 45},
	{"id": "fries", "name": "Fries", "items": ["fries"], "price": 30, "bonus": 10},
	{"id": "onion_rings", "name": "Onion Rings", "items": ["onion_rings"], "price": 25, "bonus": 10},
	{"id": "loaded_hotdog", "name": "Loaded Hot Dog", "items": ["hotdog_bun", "sausage_cooked", "onion_slice"], "price": 50, "bonus": 20},
	{"id": "chicken_salad", "name": "Chicken Salad", "items": ["lettuce_leaf", "lettuce_leaf", "chicken_cooked", "tomato_slice"], "price": 55, "bonus": 20},
	{"id": "burger_meal", "name": "Burger Meal", "items": ["bun_bottom", "patty_cooked", "cheese_slice", "bun_top", "fries", "soda_cup"], "price": 90, "bonus": 35},
	{"id": "hotdog_meal", "name": "Hot Dog Meal", "items": ["hotdog_bun", "sausage_cooked", "fries", "soda_cup"], "price": 80, "bonus": 30},
]

## Shifts (base values for ONE player; see Tuning.SCALE_* for more players).
## interval: seconds between new orders. patience: seconds an order waits. target: coins to earn.
const SHIFTS := [
	{"name": "Lunch Warm-up", "recipes": ["cheeseburger", "salad"], "interval": 40.0, "patience": 110.0, "duration": 210.0, "target": 190},
	{"name": "Double Trouble", "recipes": ["cheeseburger", "salad", "double"], "interval": 34.0, "patience": 105.0, "duration": 210.0, "target": 300},
	{"name": "Hot Dog Rush", "recipes": ["cheeseburger", "salad", "double", "hotdog"], "interval": 28.0, "patience": 95.0, "duration": 210.0, "target": 310},
]

## Shared team wallet; upgrades last for the run. icon: model spun on the shop card (ShopIcon); "" = an
## emblem drawn for the id (flat models like the plate read badly in the small tilted view).
const UPGRADES := [
	{"id": "gloves", "name": "Boxing Gloves", "desc": "Unlocks punching (Space / Q / pad B). Launch food, shove friends.", "price": 200, "icon": "boxing_glove"},
	{"id": "knife", "name": "Sharp Knife", "desc": "Chopping is twice as fast.", "price": 200, "icon": "knife"},
	{"id": "shoes", "name": "Running Shoes", "desc": "+20% move and carry speed.", "price": 300, "icon": ""},
	{"id": "second_plate", "name": "Second Plate", "desc": "Enables the second plate and bell on kitchens that have one.", "price": 300, "icon": ""},
	{"id": "oven_mitts", "name": "Oven Mitts", "desc": "Food takes 50% longer to burn.", "price": 250, "icon": ""},
	{"id": "hot_griddle", "name": "Hot Griddle", "desc": "Griddle and fryer cook 30% faster.", "price": 300, "icon": ""},
	{"id": "tongs", "name": "Long Tongs", "desc": "Grab food from 50% further away.", "price": 200, "icon": ""},
]


## MapDef for id (unknown ids fall back to the diner).
static func map(id: String) -> Dictionary:
	if not MAPS.has(id):
		push_warning("GameData.map: unknown map '%s', using diner" % id)
		return MAPS["diner"]
	return MAPS[id]


## Map ids players may pick (dev maps only with include_dev).
static func map_ids(include_dev := false) -> Array:
	var out: Array = []
	for id in MAPS:
		if include_dev or not bool(MAPS[id].get("dev", false)):
			out.append(id)
	return out


## Bounding rect (x, z) of a map's surfaces.
static func surfaces_bounds(surfaces: Array) -> Rect2:
	var b: Rect2 = surfaces[0]
	for r in surfaces:
		b = b.merge(r)
	return b


## True when xz lies on (or exactly at the edge of) any surface.
static func surfaces_contain(surfaces: Array, xz: Vector2) -> bool:
	for r: Rect2 in surfaces:
		if xz.x >= r.position.x and xz.x <= r.end.x and xz.y >= r.position.y and xz.y <= r.end.y:
			return true
	return false


static func item(kind: String) -> Dictionary:
	return ITEMS[kind]


static func kind_index(kind: String) -> int:
	return ITEM_KINDS.find(kind)


## Map key per transforming station type.
const TRANSFORM_KEYS := {"griddle": "cooks_to", "fryer": "fries_to", "board": "chops_to"}


## The station type ("griddle" | "fryer" | "board") that changes this kind into something else, or "".
## Note a finished kind (patty_cooked) still answers "griddle": leaving it there burns it.
static func transform_station(kind: String) -> String:
	var d: Dictionary = ITEMS.get(kind, {})
	for st in TRANSFORM_KEYS:
		if d.has(TRANSFORM_KEYS[st]):
			return st
	return ""


## How to make kind from dispensed food, first step first. Each step is {"station": type, "kind": input kind}:
## "dispenser" (any Dispenser/SodaFountain whose gives has it), then "griddle" / "fryer" / "board" steps.
## route("fries") -> [dispenser potato, board potato, fryer fries_raw]. Burnt kinds route like their source.
static func route(kind: String) -> Array:
	for k in ITEMS:
		for st in TRANSFORM_KEYS:
			if str(ITEMS[k].get(TRANSFORM_KEYS[st], "")) == kind:
				var steps := route(k)
				steps.append({"station": st, "kind": k})
				return steps
	return [{"station": "dispenser", "kind": kind}]


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
