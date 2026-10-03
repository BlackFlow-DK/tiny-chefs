class_name Cosmetics
extends RefCounted
## THE wardrobe catalogue (docs/design/cosmetics.md): every cosmetic per category with its display name,
## token price (0 = free starter) and model name (res://assets/models/<model>.glb; "" = no model by design:
## "none", the built-in "classic" jacket, body shapes). GameData.HATS / ACCESSORIES / BEARDS / OUTFITS /
## BACKS / BODY_SHAPES ARE these lists (one source of truth), so Net look validation accepts every id here.
## First entry of each list = the default. A model file that does not exist yet is fine: the item still shows
## (the Wardrobe draws a "coming soon" card) and Chef.dress simply attaches nothing.
## Ownership and the token wallet live in Progress (local file); see there.

const CATEGORIES := ["hat", "beard", "acc", "outfit", "back", "body"]
const TITLES := {"hat": "Hats", "beard": "Beards", "acc": "Face", "outfit": "Outfits", "back": "Back", "body": "Body"}
const PREFIX := {"hat": "hat_", "beard": "beard_", "acc": "acc_", "outfit": "outfit_", "back": "back_", "body": ""}
## What "Take off" puts back per category (hats have no bald option: the toque).
const EMPTY := {"hat": "toque", "beard": "none", "acc": "none", "outfit": "classic", "back": "none", "body": "standard"}
## Retired ids still sent by older saves / peers: [category, id] -> look patch.
const RETIRED := {"acc:moustache": {"acc": "none", "beard": "handlebar"}}

const HATS := [
	{"id": "toque", "name": "Toque", "price": 0, "model": "hat_toque"},   # built into chef.glb; the .glb is for the icon
	{"id": "beanie", "name": "Beanie", "price": 0, "model": "hat_beanie"},
	{"id": "paper", "name": "Paper hat", "price": 10, "model": "hat_paper"},
	{"id": "bandana", "name": "Bandana", "price": 10, "model": "hat_bandana"},
	{"id": "cowboy", "name": "Cowboy hat", "price": 20, "model": "hat_cowboy"},
	{"id": "crown", "name": "Crown", "price": 60, "model": "hat_crown"},
	{"id": "viking", "name": "Viking helmet", "price": 40, "model": "hat_viking"},
	{"id": "top_hat", "name": "Top hat", "price": 30, "model": "hat_top_hat"},
	{"id": "propeller", "name": "Propeller cap", "price": 25, "model": "hat_propeller"},
	{"id": "sombrero", "name": "Sombrero", "price": 35, "model": "hat_sombrero"},
	{"id": "pirate", "name": "Pirate hat", "price": 35, "model": "hat_pirate"},
	{"id": "wizard", "name": "Wizard hat", "price": 45, "model": "hat_wizard"},
	{"id": "pot", "name": "Cooking pot", "price": 15, "model": "hat_pot"},
	{"id": "cone", "name": "Traffic cone", "price": 20, "model": "hat_cone"},
	{"id": "party", "name": "Party hat", "price": 15, "model": "hat_party"},
	{"id": "fez", "name": "Fez", "price": 20, "model": "hat_fez"},
	{"id": "beret", "name": "Beret", "price": 15, "model": "hat_beret"},
	{"id": "cap", "name": "Baseball cap", "price": 15, "model": "hat_cap"},
	{"id": "santa", "name": "Santa hat", "price": 30, "model": "hat_santa"},
	{"id": "headphones", "name": "Headphones", "price": 30, "model": "hat_headphones"},
	{"id": "frog", "name": "Frog hood", "price": 40, "model": "hat_frog"},
	{"id": "halo", "name": "Halo", "price": 50, "model": "hat_halo"},
]
const BEARDS := [
	{"id": "moustache", "name": "Moustache", "price": 0, "model": "beard_moustache"},
	{"id": "none", "name": "Clean shaven", "price": 0, "model": ""},
	{"id": "handlebar", "name": "Handlebar", "price": 15, "model": "beard_handlebar"},
	{"id": "full", "name": "Full beard", "price": 20, "model": "beard_full"},
	{"id": "goatee", "name": "Goatee", "price": 15, "model": "beard_goatee"},
	{"id": "mutton", "name": "Mutton chops", "price": 20, "model": "beard_mutton"},
	{"id": "wizard", "name": "Wizard beard", "price": 40, "model": "beard_wizard"},
	{"id": "stubble", "name": "Stubble", "price": 10, "model": "beard_stubble"},
	{"id": "soul_patch", "name": "Soul patch", "price": 10, "model": "beard_soul_patch"},
	{"id": "walrus", "name": "Walrus", "price": 25, "model": "beard_walrus"},
]
const ACCESSORIES := [
	{"id": "none", "name": "Nothing", "price": 0, "model": ""},
	{"id": "glasses", "name": "Glasses", "price": 10, "model": "acc_glasses"},
	{"id": "sunglasses", "name": "Sunglasses", "price": 15, "model": "acc_sunglasses"},
	{"id": "monocle", "name": "Monocle", "price": 25, "model": "acc_monocle"},
	{"id": "eyepatch", "name": "Eyepatch", "price": 20, "model": "acc_eyepatch"},
	{"id": "clown_nose", "name": "Clown nose", "price": 15, "model": "acc_clown_nose"},
	{"id": "goggles", "name": "Goggles", "price": 20, "model": "acc_goggles"},
	{"id": "mask", "name": "Hero mask", "price": 25, "model": "acc_mask"},
	{"id": "3d_glasses", "name": "3D glasses", "price": 15, "model": "acc_3d_glasses"},
]
const OUTFITS := [
	{"id": "classic", "name": "Classic whites", "price": 0, "model": ""},   # the built-in jacket + apron
	{"id": "stripes", "name": "Striped apron", "price": 15, "model": "outfit_stripes"},
	{"id": "tuxedo", "name": "Tuxedo", "price": 40, "model": "outfit_tuxedo"},
	{"id": "overalls", "name": "Overalls", "price": 25, "model": "outfit_overalls"},
	{"id": "hero", "name": "Hero suit", "price": 45, "model": "outfit_hero"},
	{"id": "bbq", "name": "BBQ apron", "price": 20, "model": "outfit_bbq"},
	{"id": "knight", "name": "Knight armour", "price": 50, "model": "outfit_knight"},
	{"id": "scarf", "name": "Winter scarf", "price": 15, "model": "outfit_scarf"},
	{"id": "hawaiian", "name": "Hawaiian", "price": 25, "model": "outfit_hawaiian"},
	{"id": "sash", "name": "Winner's sash", "price": 35, "model": "outfit_sash"},
]
const BACKS := [
	{"id": "none", "name": "Nothing", "price": 0, "model": ""},
	{"id": "cape", "name": "Cape", "price": 30, "model": "back_cape"},
	{"id": "backpack", "name": "Backpack", "price": 20, "model": "back_backpack"},
	{"id": "wings", "name": "Wings", "price": 60, "model": "back_wings"},
	{"id": "jetpack", "name": "Jetpack", "price": 70, "model": "back_jetpack"},
	{"id": "guitar", "name": "Guitar", "price": 35, "model": "back_guitar"},
	{"id": "shell", "name": "Turtle shell", "price": 40, "model": "back_shell"},
	{"id": "pan", "name": "Frying pan", "price": 15, "model": "back_pan"},
	{"id": "balloon", "name": "Balloon", "price": 25, "model": "back_balloon"},
	{"id": "sword", "name": "Spatula sword", "price": 30, "model": "back_sword"},
]
## Body shapes (code, no models): per-part scales applied by ChefAnim.shape() on every peer; collider and
## gameplay size never change. body: Body scale (keep x == z so head turns stay shear-free), head: Head scale
## (uniform, world), hands / feet: uniform scale, legs: LegL/LegR length (the body rides up or down with them),
## arm_out: extra hand spread in metres. Tallest (with a toque) stays under the 1.7 m name badge.
const BODY := [
	{"id": "standard", "name": "Standard", "price": 0, "model": "", "body": Vector3(1, 1, 1), "head": 1.0, "hands": 1.0, "feet": 1.0, "legs": 1.0, "arm_out": 0.0},
	{"id": "stout", "name": "Stout", "price": 0, "model": "", "body": Vector3(1.3, 0.88, 1.3), "head": 1.04, "hands": 1.15, "feet": 1.18, "legs": 0.75, "arm_out": 0.02},
	{"id": "tall", "name": "Tall", "price": 20, "model": "", "body": Vector3(0.94, 1.2, 0.94), "head": 0.97, "hands": 1.0, "feet": 1.0, "legs": 1.7, "arm_out": 0.0},
	{"id": "long_legs", "name": "Long legs", "price": 25, "model": "", "body": Vector3(1, 1, 1), "head": 1.0, "hands": 1.0, "feet": 1.05, "legs": 2.6, "arm_out": 0.0},
	{"id": "tiny", "name": "Tiny", "price": 30, "model": "", "body": Vector3(0.8, 0.78, 0.8), "head": 0.9, "hands": 0.85, "feet": 0.85, "legs": 0.55, "arm_out": 0.0},
	{"id": "big_head", "name": "Big head", "price": 30, "model": "", "body": Vector3(0.94, 0.9, 0.94), "head": 1.36, "hands": 1.0, "feet": 1.05, "legs": 0.85, "arm_out": 0.0},
	{"id": "big_arms", "name": "Big arms", "price": 40, "model": "", "body": Vector3(1.1, 1.0, 1.1), "head": 0.96, "hands": 1.85, "feet": 1.0, "legs": 1.0, "arm_out": 0.03},
]

const _TABLES := {"hat": HATS, "beard": BEARDS, "acc": ACCESSORIES, "outfit": OUTFITS, "back": BACKS, "body": BODY}


static func categories() -> Array:
	return CATEGORIES


## Every item of a category ({id, name, price, model}), catalogue order; [] for an unknown category.
static func items(cat: String) -> Array:
	return _TABLES.get(cat, [])


## One item, or {} when the category or id is unknown.
static func item(cat: String, id: String) -> Dictionary:
	for e: Dictionary in items(cat):
		if e["id"] == id:
			return e
	return {}


static func has_item(cat: String, id: String) -> bool:
	return not item(cat, id).is_empty()


static func default_id(cat: String) -> String:
	var l := items(cat)
	return str(l[0]["id"]) if not l.is_empty() else ""


static func item_name(cat: String, id: String) -> String:
	return str(item(cat, id).get("name", id.capitalize()))


## Token price (0 for free starters and unknown items).
static func price(cat: String, id: String) -> int:
	return int(item(cat, id).get("price", 0))


static func is_free(cat: String, id: String) -> bool:
	return price(cat, id) <= 0


## res:// path of the item's model ("" when the item has no model by design). The file may not exist yet.
static func model_path(cat: String, id: String) -> String:
	var m := str(item(cat, id).get("model", ""))
	return "" if m.is_empty() else Models.MODEL_DIR + m + ".glb"


## The item is meant to have a model but its .glb is not there (yet): show "coming soon", attach nothing.
static func model_missing(cat: String, id: String) -> bool:
	var m := str(item(cat, id).get("model", ""))
	return not m.is_empty() and not Models.has_model(m)
