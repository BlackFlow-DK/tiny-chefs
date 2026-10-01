class_name Missions
extends RefCounted
## Campaign missions as DATA (docs/design/overnight-1.md section 6). ShiftPlan turns one into a ShiftDef;
## the objectives/events/star logic lives elsewhere (it reads the ShiftDef keys "objectives"/"events").
##
## Mission keys: id (= index), name, map (map id), difficulty (Difficulty preset id), modifiers (ids),
## recipes (recipe ids; the first one is always the first order), duration (s), interval (s between
## orders), patience (s), target (coins) -- all base values for ONE player at "normal", the difficulty
## preset and player-count scaling are applied on top by ShiftPlan -- objectives: up to two bonus
## objectives {type: no_burnt | no_expired | serve_n (recipe, n) | earn (n)} (target met = 1 star, each
## bonus objective met = +1), events: event ids (vip, inspector, cat_paw), blurb: one line for the UI.
## Recipe ids may name recipes that are not in GameData.RECIPES yet; ShiftPlan drops unknown ones.

const LIST := [
	# ---- diner: learn the kitchen
	{"id": 0, "name": "Training", "map": "diner", "difficulty": "easy", "modifiers": [],
		"recipes": ["cheeseburger"], "duration": 180.0, "interval": 50.0, "patience": 160.0, "target": 100,
		"objectives": [{"type": "serve_n", "recipe": "cheeseburger", "n": 2}], "events": [],
		"blurb": "Your first shift: grab, cook, stack, serve. Take your time."},
	{"id": 1, "name": "Lunch Rush", "map": "diner", "difficulty": "easy", "modifiers": [],
		"recipes": ["cheeseburger", "salad"], "duration": 210.0, "interval": 40.0, "patience": 115.0, "target": 180,
		"objectives": [{"type": "no_expired"}], "events": [],
		"blurb": "Burgers and salads. Keep the chopping board busy."},
	{"id": 2, "name": "Double Trouble", "map": "diner", "difficulty": "normal", "modifiers": [],
		"recipes": ["cheeseburger", "salad", "double", "hotdog"], "duration": 210.0, "interval": 32.0, "patience": 100.0, "target": 160,
		"objectives": [{"type": "serve_n", "recipe": "double", "n": 2}, {"type": "no_burnt"}], "events": ["cat_paw"],
		"blurb": "Two patties, two hands. And watch out for the cat."},
	# ---- food truck: the fryer and the soda fountain
	{"id": 3, "name": "Meals on Wheels", "map": "food_truck", "difficulty": "normal", "modifiers": [],
		"recipes": ["fries", "cheeseburger", "hotdog", "hotdog_meal"], "duration": 210.0, "interval": 34.0, "patience": 105.0, "target": 155,
		"objectives": [{"type": "serve_n", "recipe": "fries", "n": 3}], "events": [],
		"blurb": "The truck has a fryer. Hold on when it lurches."},
	{"id": 4, "name": "Onion Street", "map": "food_truck", "difficulty": "normal", "modifiers": [],
		"recipes": ["onion_rings", "cheeseburger", "fries", "loaded_hotdog", "burger_meal"], "duration": 210.0, "interval": 30.0, "patience": 100.0, "target": 165,
		"objectives": [{"type": "no_burnt"}, {"type": "serve_n", "recipe": "burger_meal", "n": 2}], "events": ["vip"],
		"blurb": "Onion rings and full meals. A VIP might stop by."},
	{"id": 5, "name": "Festival Queue", "map": "food_truck", "difficulty": "normal", "modifiers": ["rush_hour"],
		"recipes": ["bacon_cheeseburger", "fries", "onion_rings", "loaded_hotdog", "hotdog_meal", "burger_meal"], "duration": 240.0, "interval": 28.0, "patience": 95.0, "target": 210,
		"objectives": [{"type": "no_expired"}, {"type": "earn", "n": 280}], "events": ["vip", "inspector"],
		"blurb": "The festival crowd comes in waves. Bacon is on the menu."},
	# ---- picnic: wind and chicken
	{"id": 6, "name": "Sunday Picnic", "map": "picnic", "difficulty": "normal", "modifiers": [],
		"recipes": ["chicken_burger", "cheeseburger", "salad", "chicken_salad"], "duration": 210.0, "interval": 32.0, "patience": 105.0, "target": 165,
		"objectives": [{"type": "serve_n", "recipe": "chicken_salad", "n": 2}], "events": ["cat_paw"],
		"blurb": "Crispy chicken on a checkered cloth. Mind the gusts."},
	{"id": 7, "name": "Breakfast on the Grass", "map": "picnic", "difficulty": "hard", "modifiers": [],
		"recipes": ["breakfast_burger", "bacon_cheeseburger", "pickle_burger", "chicken_burger", "salad"], "duration": 210.0, "interval": 30.0, "patience": 100.0, "target": 110,
		"objectives": [{"type": "no_burnt"}], "events": ["vip", "cat_paw"],
		"blurb": "Eggs, bacon and pickles. Hungrier guests, hotter griddle."},
	{"id": 8, "name": "Gone with the Wind", "map": "picnic", "difficulty": "hard", "modifiers": ["slippery"],
		"recipes": ["pickle_burger", "chicken_salad", "chicken_burger", "breakfast_burger", "onion_rings"], "duration": 240.0, "interval": 28.0, "patience": 95.0, "target": 90,
		"objectives": [{"type": "no_expired"}, {"type": "serve_n", "recipe": "pickle_burger", "n": 3}], "events": ["inspector", "cat_paw"],
		"blurb": "The cloth is slick and the wind is up. Keep everything on the table."},
	# ---- twin islands: the plank
	{"id": 9, "name": "Bridge Crew", "map": "twin_islands", "difficulty": "hard", "modifiers": ["heavy_hands"],
		"recipes": ["double", "cheeseburger", "hotdog", "fries", "burger_meal"], "duration": 240.0, "interval": 30.0, "patience": 105.0, "target": 110,
		"objectives": [{"type": "serve_n", "recipe": "double", "n": 3}], "events": ["vip"],
		"blurb": "Everything is heavy and the plank is narrow. Carry together."},
	{"id": 10, "name": "Island Dinner Party", "map": "twin_islands", "difficulty": "hard", "modifiers": ["mystery_orders"],
		"recipes": ["the_works", "bacon_cheeseburger", "chicken_burger", "loaded_hotdog", "fries", "onion_rings"], "duration": 240.0, "interval": 28.0, "patience": 100.0, "target": 110,
		"objectives": [{"type": "no_burnt"}, {"type": "earn", "n": 150}], "events": ["vip", "inspector"],
		"blurb": "Tickets only say the dish name. Know your recipes."},
	{"id": 11, "name": "The Grand Opening", "map": "twin_islands", "difficulty": "chaos", "modifiers": ["rush_hour", "lights_out"],
		"recipes": ["the_works", "burger_meal", "hotdog_meal", "breakfast_burger", "chicken_salad", "pickle_burger", "onion_rings"], "duration": 270.0, "interval": 30.0, "patience": 110.0, "target": 120,
		"objectives": [{"type": "no_expired"}, {"type": "serve_n", "recipe": "the_works", "n": 2}], "events": ["vip", "inspector"],
		"blurb": "Everything, all at once, in the dark. Good luck, chefs."},
]


static func count() -> int:
	return LIST.size()


## Mission i (clamped into the list), as a deep copy.
static func get_mission(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)].duplicate(true)
