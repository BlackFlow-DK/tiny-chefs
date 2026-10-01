class_name MapPicnic
extends RefCounted
## MapDef "picnic" (docs/design/overnight-1.md section 4): one 56 x 40 wooden picnic table outdoors,
## a gingham cloth over its middle (the ends stay bare planks), theme "picnic" (EnvPicnic: grass far
## below, sky, trees, bee, ants, drifting leaves), hazard "wind" (world/hazards/wind_hazard.gd).
## Registered in GameData.MAPS. Pure data: no reads of GameData here (it builds MAPS from this).
##
## Flow: dispensers on the far edge (7) and both ends (3 + 3, turned to face the middle), griddle +
## fryer on the left, cutting board on the right, two plate + bell pairs front-centre, trash on the
## left end, soda on the right end. Tall props sit in the back corners and the front corners only.
## Table x -28..28, z -20..20 (the camera looks towards -Z, so -Z is the far edge / "north").

const SURFACE := Rect2(-28, -20, 56, 40)
const DISP := Vector3(5, 4, 5)
const BACK_Z := -16.0      # far-edge dispenser row (1.5 m strip behind it for the ants)
const END_X := 25.4        # end dispensers (turned 90 degrees)


static func def() -> Dictionary:
	return {
		"id": "picnic", "name": "The Picnic", "blurb": "A picnic table in the park. Mind the wind!",
		"theme": "picnic", "surfaces": [SURFACE], "stations": stations(), "scenery": scenery(),
		"spawn_points": [Vector3(-2, 0, 3), Vector3(2, 0, 3), Vector3(-2, 0, -1), Vector3(2, 0, -1)],
		"hazards": ["wind", "cat_paw"], "decor": ["picnic_clutter"],
		# Menu backdrop: from the far side towards the front edge, so the lawn, trees and sky show.
		"menu_view": {"focus": Vector3(0.0, 1.0, 13.5), "yaw": 180.0, "lift": 1.1},
	}


static func _disp(model: String, pos: Vector3, gives: Array, label: String, yaw := 0.0) -> Dictionary:
	var d := {"type": "dispenser", "model": model, "pos": pos, "size": DISP, "gives": gives, "label": label}
	if yaw != 0.0:
		d["yaw"] = yaw
	return d


static func stations() -> Array:
	return [
		# Far edge, left to right: griddle food on the griddle side, salad food on the board side.
		_disp("dispenser_patties", Vector3(-18, 0, BACK_Z), ["patty_raw"], "Patties"),
		_disp("dispenser_sausages", Vector3(-12, 0, BACK_Z), ["sausage_raw"], "Sausages"),
		_disp("dispenser_bacon", Vector3(-6, 0, BACK_Z), ["bacon_raw"], "Bacon"),
		_disp("dispenser_buns", Vector3(0, 0, BACK_Z), ["bun_bottom", "bun_top"], "Buns"),
		_disp("dispenser_cheese", Vector3(6, 0, BACK_Z), ["cheese_slice"], "Cheese"),
		_disp("dispenser_lettuce", Vector3(12, 0, BACK_Z), ["lettuce_leaf"], "Lettuce"),
		_disp("dispenser_tomatoes", Vector3(18, 0, BACK_Z), ["tomato"], "Tomatoes"),
		# Left end (face +X): eggs for the griddle, chicken for the fryer, hot dog buns.
		_disp("dispenser_eggs", Vector3(-END_X, 0, -5.5), ["egg"], "Eggs", 90.0),
		_disp("dispenser_chicken", Vector3(-END_X, 0, 0.5), ["chicken_raw"], "Chicken", 90.0),
		_disp("dispenser_hotdog_buns", Vector3(-END_X, 0, 6.5), ["hotdog_bun"], "Hot dog buns", 90.0),
		# Right end (face -X): board food and pickles.
		_disp("dispenser_onions", Vector3(END_X, 0, -5.5), ["onion"], "Onions", -90.0),
		_disp("dispenser_potatoes", Vector3(END_X, 0, 0.5), ["potato"], "Potatoes", -90.0),
		_disp("dispenser_pickles", Vector3(END_X, 0, 6.5), ["pickle_slice"], "Pickles", -90.0),
		{"type": "griddle", "model": "griddle", "pos": Vector3(-12, 0, -3), "size": Vector3(9, 0.5, 7), "label": "Griddle"},
		{"type": "fryer", "model": "fryer", "pos": Vector3(-12, 0, 6.5), "size": Vector3(7, 0.5, 6), "label": "Fryer"},
		{"type": "board", "model": "cutting_board", "pos": Vector3(12, 0, -3), "size": Vector3(9, 0.4, 6), "label": "Cutting board"},
		# Two plate + bell pairs, front-centre (World keeps the last pair until plates generalise to N).
		{"type": "plate", "model": "plate", "pos": Vector3(-6, 0, 12.5), "size": Vector3(7, 0.4, 7), "label": "Plate"},
		{"type": "bell", "model": "service_bell", "pos": Vector3(-10.5, 0, 12.5), "size": Vector3(2, 1.6, 2), "label": "Serve"},
		{"type": "plate", "model": "plate", "pos": Vector3(6, 0, 12.5), "size": Vector3(7, 0.4, 7), "label": "Plate"},
		{"type": "bell", "model": "service_bell", "pos": Vector3(10.5, 0, 12.5), "size": Vector3(2, 1.6, 2), "label": "Serve"},
		{"type": "trash", "model": "trash_drain", "pos": Vector3(-24.5, 0, 14.5), "size": Vector3(4, 0.2, 4), "label": "Trash"},
		{"type": "soda", "model": "soda_fountain", "pos": Vector3(25.6, 0, 14.0), "yaw": -90.0, "size": Vector3(4, 5, 3), "gives": ["soda_cup"], "label": "Soda"},
	]


## Picnic props (solid, like the diner's scenery). Tall ones in the back corners and at the front
## corners only, so they never hide the stations from the camera.
static func scenery() -> Array:
	return [
		{"model": "picnic_basket", "pos": Vector3(-24.4, 0, -14.4), "size": Vector3(9, 6, 6), "shape": "box", "color": Color(0.72, 0.52, 0.3), "yaw": 90.0},
		{"model": "lemonade_jug", "pos": Vector3(24.6, 0, -16.2), "size": Vector3(5, 8, 5), "shape": "cyl", "color": Color(0.98, 0.9, 0.45)},
		{"model": "watermelon_slice", "pos": Vector3(24.2, 0, -10.6), "size": Vector3(7, 4, 2), "shape": "box", "color": Color(0.9, 0.3, 0.32), "yaw": -8.0},
		{"model": "daisy_flower", "pos": Vector3(25.9, 0, 18.2), "size": Vector3(3, 6, 3), "shape": "cyl", "color": Color(0.96, 0.96, 0.9)},
		{"model": "paper_plates_stack", "pos": Vector3(-18.0, 0, 16.4), "size": Vector3(6, 2, 6), "shape": "cyl", "color": Color(0.97, 0.96, 0.92), "yaw": 12.0},
	]
