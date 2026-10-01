class_name MapFoodTruck
extends RefCounted
## MapDef "food_truck" (docs/design/overnight-1.md section 4): one long 72 x 16 steel counter inside a
## food truck, theme "truck" (EnvTruck: steel walls close on every side, a serving hatch along the back
## wall onto a street, menu board, string lights, the truck floor a short drop below), hazard "lurch"
## (world/hazards/lurch_hazard.gd). Registered in GameData.MAPS. Pure data: no reads of GameData here.
##
## Counter x -36..36, z -8..8 (the camera looks towards -Z, so -Z is the back wall with the hatch).
## Dispensers are 5 x 5 footprints with ~5.9 m wide models and drop food 4.7 m in front of them, so
## 13 of them cannot all stand along 72 m: 9 stand along the back wall (6 m apart like the diner's, so a
## chef working one is out of reach of its neighbour; x -24..24) and 2 + 2 stand against the end walls,
## turned to face along the counter. Each end pair leaves a 4 m pocket between it and the back row
## where its food lands (x +-27..30.9). Long food (sausage, bacon, hot dog bun) spawns lying along X,
## so it only comes from the back row.
## Every output lands on the counter, clear of the other stations: the back row's at z = -0.8, the end
## ones at x = +-28.7 (z -5.1 and 1.4). A free lane (z -3..1) runs the whole length between the outputs and the front
## stations (fryer + griddle left, board middle, trash, two plate + bell pairs right, the soda fountain
## at the right end facing the end wall); the flat stations can be walked over, so nothing is a dead
## end. Where a chef stands to pour a soda is out of reach of every dispenser and bell.

const SURFACE := Rect2(-36, -8, 72, 16)
const DISP := Vector3(5, 4, 5)
const BACK_Z := -5.5        # back-row dispensers (bodies z -8..-3)
const STEP := 6.0           # back-row spacing (models are ~5.9 wide)
const END_X := 33.4         # end dispensers (bodies x +-30.9..35.9, food lands at x +-28.7)
const END_BACK_Z := -5.1    # end pair: back one (z -8.05..-2.15) ...
const END_FRONT_Z := 1.4    # ... and front one (z -1.55..4.35); 6.5 m apart, so working one never works the other
const FRONT_Z := 4.5        # front stations (7 deep ones span z 1..8)


static func def() -> Dictionary:
	return {
		"id": "food_truck", "name": "The Food Truck", "blurb": "A long, narrow kitchen on wheels. Hold on when it lurches!",
		"theme": "truck", "surfaces": [SURFACE], "stations": stations(), "scenery": scenery(),
		"spawn_points": [Vector3(-3, 0, -1.2), Vector3(3, 0, -1.2), Vector3(-9, 0, -1.2), Vector3(9, 0, -1.2)],
		"hazards": ["lurch"],
		"target_scale": 0.9,   # long counter + lurches: endless targets a little lower (docs/balance.md)
		# Menu backdrop: from the lane, looking down the length of the truck towards the serving end
		# (dispensers and the hatch on the left, the front stations on the right).
		"menu_view": {"focus": Vector3(-4.0, 1.0, -0.5), "yaw": -90.0, "lift": 1.6},
	}


static func _disp(model: String, pos: Vector3, gives: Array, label: String, yaw := 0.0) -> Dictionary:
	var d := {"type": "dispenser", "model": model, "pos": pos, "size": DISP, "gives": gives, "label": label}
	if yaw != 0.0:
		d["yaw"] = yaw
	return d


static func _back(i: int) -> Vector3:
	return Vector3(-4.0 * STEP + i * STEP, 0, BACK_Z)


static func stations() -> Array:
	return [
		# Back row, left to right: griddle food over the griddle, board food over the board, buns right
		# behind the plate. A chef working a dispenser stands on its -X side, close enough that a sloppy
		# stop also works the left neighbour, whose food then lands right behind the front stations; so
		# the two right of the buns (whose strays would land behind the plates) are the rarely used
		# onions and bacon, and the buns' own left neighbour (cheese) drops by the trash and bell.
		_disp("dispenser_hotdog_buns", _back(0), ["hotdog_bun"], "Hot dog buns"),
		_disp("dispenser_sausages", _back(1), ["sausage_raw"], "Sausages"),
		_disp("dispenser_patties", _back(2), ["patty_raw"], "Patties"),
		_disp("dispenser_potatoes", _back(3), ["potato"], "Potatoes"),
		_disp("dispenser_tomatoes", _back(4), ["tomato"], "Tomatoes"),
		_disp("dispenser_cheese", _back(5), ["cheese_slice"], "Cheese"),
		_disp("dispenser_buns", _back(6), ["bun_bottom", "bun_top"], "Buns"),
		_disp("dispenser_onions", _back(7), ["onion"], "Onions"),
		_disp("dispenser_bacon", _back(8), ["bacon_raw"], "Bacon"),
		# Left end wall (face +X): eggs for the griddle, chicken for the fryer.
		_disp("dispenser_eggs", Vector3(-END_X, 0, END_BACK_Z), ["egg"], "Eggs", 90.0),
		_disp("dispenser_chicken", Vector3(-END_X, 0, END_FRONT_Z), ["chicken_raw"], "Chicken", 90.0),
		# Right end wall (face -X): ready-to-plate food by the plates.
		_disp("dispenser_lettuce", Vector3(END_X, 0, END_BACK_Z), ["lettuce_leaf"], "Lettuce", -90.0),
		_disp("dispenser_pickles", Vector3(END_X, 0, END_FRONT_Z), ["pickle_slice"], "Pickles", -90.0),
		# Front, left to right.
		{"type": "fryer", "model": "fryer", "pos": Vector3(-23.0, 0, FRONT_Z), "size": Vector3(7, 0.5, 6), "label": "Fryer"},
		{"type": "griddle", "model": "griddle", "pos": Vector3(-13.0, 0, 4.4), "size": Vector3(9, 0.5, 7), "label": "Griddle"},
		{"type": "board", "model": "cutting_board", "pos": Vector3(-2.5, 0, FRONT_Z), "size": Vector3(9, 0.4, 6), "label": "Cutting board"},
		{"type": "trash", "model": "trash_drain", "pos": Vector3(4.6, 0, 6.0), "size": Vector3(4, 0.2, 4), "label": "Trash"},
		{"type": "bell", "model": "service_bell", "pos": Vector3(8.0, 0, 4.0), "size": Vector3(2, 1.6, 2), "label": "Serve"},
		{"type": "plate", "model": "plate", "pos": Vector3(12.8, 0, FRONT_Z), "size": Vector3(7, 0.4, 7), "label": "Plate"},
		# Second plate + bell: closed until the "second_plate" upgrade is bought. The bell stands behind
		# the plate's right corner, clear of the hot dog bun landing spot and the soda pouring spot.
		{"type": "plate", "model": "plate", "pos": Vector3(20.8, 0, FRONT_Z), "size": Vector3(7, 0.4, 7), "label": "Plate 2", "upgrade": "second_plate"},
		{"type": "bell", "model": "service_bell", "pos": Vector3(25.3, 0, 1.9), "size": Vector3(2, 1.6, 2), "label": "Serve 2", "upgrade": "second_plate"},
		# Facing the right end wall: the cup lands at (29.35, 6.0); the pourer stands near (28.55, 4.3).
		{"type": "soda", "model": "soda_fountain", "pos": Vector3(26.5, 0, 6.0), "yaw": 90.0, "size": Vector3(4, 5, 3), "gives": ["soda_cup"], "label": "Soda"},
	]


## Truck props on the counter (solid, like the diner's scenery), all low or in a corner. The cash
## register lives on the right end wall's shelf (EnvTruck, visual only).
static func scenery() -> Array:
	return [
		{"model": "truck_sauce_bottles", "pos": Vector3(-33.4, 0, 6.6), "size": Vector3(5, 5, 2.5), "shape": "box", "color": Color(0.85, 0.2, 0.15)},
		{"model": "truck_napkin_dispenser", "pos": Vector3(-28.6, 0, 6.3), "size": Vector3(3, 4, 3), "shape": "box", "color": Color(0.8, 0.82, 0.85), "yaw": 12.0},
		{"model": "truck_tip_jar", "pos": Vector3(33.6, 0, 6.4), "size": Vector3(2.5, 3.5, 2.5), "shape": "cyl", "color": Color(0.85, 0.92, 0.95)},
	]
