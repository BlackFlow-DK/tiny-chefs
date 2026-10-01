extends RefCounted
## MapDef "twin_islands": two 26 x 30 counter islands with a big double sink between them, joined only
## by a 5 m wide cutting-board plank at z = 0. The left island is the pantry (every raw ingredient that
## needs the griddle, fryer or board), the right island the line (griddle, fryer, board, soda, plate,
## bell and the ready-to-plate dispensers), so raw food, heavy patties included, is hauled over the plank.
## Registered in GameData.MAPS; read it only through GameData.map("twin_islands").
##
## Layout notes (5 x 5 dispenser footprints, models ~5.9 wide, output 4.7 m in front):
## - 13 dispensers do not fit on the left island with their outputs clear, so the 4 ready-to-plate
##   ones (buns, cheese, lettuce, hot dog buns) stand on the right island's back row. Long food
##   (sausage, bacon, hot dog bun) spawns lying along X, so it comes from yaw-0 dispensers only.
## - The plank board spans the 8 m gap (x -4..4) and its lips rest 2 m on each island. Its SURFACE
##   rect runs on as an approach lane 8 m onto each island (x -12..12, same 5 m width), for the bots:
##   Bot._route takes the Rect2 intersection of two surfaces as the gate (exactly touching rects give
##   an empty rect at the origin, so bots head for (0, 0) and cut the corner), and two chefs carrying
##   one patty from opposite sides of a short overlap both aim for the same lead-in point and stall
##   there. Inside the lane both carriers already count as on the plank and aim for the far side
##   together. The lane lies on the islands, so it changes nothing about where food or chefs can be.
##   The strips in front of both plank ends are kept free.
## - surface_styles (parallel to surfaces): "counter" (terrazzo slab + cabinets, the default) or
##   "plank" (wooden board, thin collider, nothing under it; where it overlaps a counter it is drawn
##   as a thin lip resting on it). decor "island_sink" builds the double sink in the gap under the
##   plank, "islands_clutter" the layout's crumbs and puddles (EnvIslands).

const DEF := {
	"id": "twin_islands", "name": "Twin Islands",
	"blurb": "Two islands, one plank over the sink. Haul the raw food across and cook on the far side.",
	"theme": "diner",
	"surfaces": [Rect2(-30, -15, 26, 30), Rect2(4, -15, 26, 30), Rect2(-12, -2.5, 24, 5)],
	"surface_styles": ["counter", "counter", "plank"],
	"stations": [
		# Left island: back row (facing the camera), long food only here.
		{"type": "dispenser", "model": "dispenser_sausages", "pos": Vector3(-26.6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["sausage_raw"], "label": "Sausages"},
		{"type": "dispenser", "model": "dispenser_bacon", "pos": Vector3(-20.6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["bacon_raw"], "label": "Bacon"},
		{"type": "dispenser", "model": "dispenser_chicken", "pos": Vector3(-14.6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["chicken_raw"], "label": "Chicken"},
		{"type": "dispenser", "model": "dispenser_patties", "pos": Vector3(-8.6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["patty_raw"], "label": "Patties"},
		# Left island: outer end, facing the island centre.
		{"type": "dispenser", "model": "dispenser_tomatoes", "pos": Vector3(-27, 0, -2.6), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["tomato"], "label": "Tomatoes"},
		{"type": "dispenser", "model": "dispenser_onions", "pos": Vector3(-27, 0, 3.4), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["onion"], "label": "Onions"},
		{"type": "dispenser", "model": "dispenser_pickles", "pos": Vector3(-27, 0, 9.4), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["pickle_slice"], "label": "Pickles"},
		# Left island: one mid-island (outputs towards the plank lane) and one by the plank, facing in.
		{"type": "dispenser", "model": "dispenser_potatoes", "pos": Vector3(-16, 0, 3.4), "yaw": 90.0, "size": Vector3(5, 4, 5), "gives": ["potato"], "label": "Potatoes"},
		{"type": "dispenser", "model": "dispenser_eggs", "pos": Vector3(-7, 0, 9.4), "yaw": -90.0, "size": Vector3(5, 4, 5), "gives": ["egg"], "label": "Eggs"},
		{"type": "trash", "model": "trash_drain", "pos": Vector3(-17, 0, 12.2), "size": Vector3(4, 0.2, 4), "label": "Trash"},
		# Right island: ready-to-plate dispensers along the back.
		# (Cheese first: its single output lands furthest from the sink edge; buns give two.)
		{"type": "dispenser", "model": "dispenser_cheese", "pos": Vector3(9.6, 0, -12), "size": Vector3(5, 4, 5), "gives": ["cheese_slice"], "label": "Cheese"},
		{"type": "dispenser", "model": "dispenser_buns", "pos": Vector3(15.5, 0, -12), "size": Vector3(5, 4, 5), "gives": ["bun_bottom", "bun_top"], "label": "Buns"},
		{"type": "dispenser", "model": "dispenser_lettuce", "pos": Vector3(21.45, 0, -12), "size": Vector3(5, 4, 5), "gives": ["lettuce_leaf"], "label": "Lettuce"},
		{"type": "dispenser", "model": "dispenser_hotdog_buns", "pos": Vector3(27.4, 0, -12), "size": Vector3(5, 4, 5), "gives": ["hotdog_bun"], "label": "Hot dog buns"},
		# Right island: the line. The griddle starts just past the plank end.
		{"type": "griddle", "model": "griddle", "pos": Vector3(11, 0, -1), "size": Vector3(9, 0.5, 7), "label": "Griddle"},
		{"type": "fryer", "model": "fryer", "pos": Vector3(21.5, 0, -1), "size": Vector3(7, 0.5, 6), "label": "Fryer"},
		{"type": "soda", "model": "soda_fountain", "pos": Vector3(27.5, 0, 4), "size": Vector3(4, 5, 3), "gives": ["soda_cup"], "label": "Soda"},
		{"type": "board", "model": "cutting_board", "pos": Vector3(10, 0, 8.5), "size": Vector3(9, 0.4, 6), "label": "Cutting board"},
		{"type": "plate", "model": "plate", "pos": Vector3(19.5, 0, 7.5), "size": Vector3(7, 0.4, 7), "label": "Plate"},
		{"type": "bell", "model": "service_bell", "pos": Vector3(25, 0, 8.5), "size": Vector3(2, 1.6, 2), "label": "Serve"},
	],
	"scenery": [
		{"model": "salt_shaker", "pos": Vector3(28.4, 0, -3.0), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.9, 0.93, 0.95)},
		{"model": "pepper_shaker", "pos": Vector3(28.4, 0, 0.4), "size": Vector3(3, 7, 3), "shape": "cyl", "color": Color(0.25, 0.25, 0.27)},
		{"model": "spice_jar_a", "pos": Vector3(28.6, 0, 13.3), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.78, 0.3, 0.16)},
		{"model": "spice_jar_b", "pos": Vector3(26.5, 0, 13.7), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.9, 0.7, 0.2)},
		# A low prop on the right island's front edge doubles as a bumper between the board and the plate.
		{"model": "rolling_pin", "pos": Vector3(16, 0, 14.0), "size": Vector3(10, 1.4, 1.4), "shape": "capsule_x", "color": Color(0.85, 0.68, 0.46), "yaw": 4.0},
		{"model": "dish_sponge", "pos": Vector3(-12.5, 0, 13.5), "size": Vector3(5, 1.5, 3), "shape": "box", "color": Color(0.98, 0.84, 0.3), "yaw": -4.0},
		{"model": "spice_jar_c", "pos": Vector3(-22.0, 0, 13.6), "size": Vector3(2, 3, 2), "shape": "cyl", "color": Color(0.4, 0.55, 0.28)},
	],
	# One per player slot, alternating islands: slot 0 left, slot 1 right, ...
	"spawn_points": [Vector3(-12, 0, -3), Vector3(8.5, 0, 4.2), Vector3(-19.5, 0, -3), Vector3(16.8, 0, 3.2)],
	"hazards": [],
	"decor": ["island_sink", "islands_clutter"],
	# Menu backdrop (MenuDiorama): drifting camera focus and where the burger plate stands.
	"menu": {"focus": Vector3(0.6, 0.4, 0.6), "plate": Vector3(8.0, 0, 6.0), "height": 4.2},
}


static func def() -> Dictionary:
	return DEF
