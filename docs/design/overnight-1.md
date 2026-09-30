# Tiny Chefs: overnight content plan (2026-09-30)

Owner's brief: more dishes, maps, difficulties, customisable shifts, game balance. Movement feels good: do not
change carry/input feel. This document is the contract every agent in this round builds against. Sizes are
Godot metres X x Y x Z (Y up), origin base centre, same conventions as `docs/asset-contract.md`.

## 1. New ingredients (add to `GameData.ITEMS`; append kinds to `ITEM_KINDS` in this order)
| kind | label | size | shape | weight | plate | transforms |
|---|---|---|---|---|---|---|
| bacon_raw | Raw bacon | 4.0 x 0.3 x 1.2 | capsule_x | 1 | no | cooks_to bacon_cooked |
| bacon_cooked | Bacon | 4.0 x 0.3 x 1.2 | capsule_x | 1 | yes | cooks_to bacon_burnt |
| bacon_burnt | Burnt bacon | 4.0 x 0.3 x 1.2 | capsule_x | 1 | no | |
| egg | Egg | 1.8 x 2.2 x 1.8 | sphere | 1 | no | cooks_to fried_egg (the griddle "cracks" it) |
| fried_egg | Fried egg | 3.0 x 0.4 x 3.0 | cyl | 1 | yes | cooks_to egg_burnt |
| egg_burnt | Burnt egg | 3.0 x 0.4 x 3.0 | cyl | 1 | no | |
| onion | Onion | 2.4 x 2.4 x 2.4 | sphere | 2 | no | chops_to onion_slice (x3) |
| onion_slice | Onion slice | 2.2 x 0.3 x 2.2 | cyl | 1 | yes | fries_to onion_rings |
| onion_rings | Onion rings | 2.6 x 0.8 x 2.6 | cyl | 1 | yes | fries_to onion_rings_burnt |
| onion_rings_burnt | Burnt rings | 2.6 x 0.8 x 2.6 | cyl | 1 | no | |
| pickle_slice | Pickle | 1.6 x 0.25 x 1.6 | cyl | 1 | yes | |
| potato | Potato | 2.6 x 2.0 x 2.0 | sphere | 2 | no | chops_to fries_raw (x1) |
| fries_raw | Cut potato | 2.8 x 1.2 x 2.8 | box | 2 | no | fries_to fries |
| fries | Fries | 2.8 x 2.5 x 2.8 | box | 1 | yes | fries_to fries_burnt |
| fries_burnt | Burnt fries | 2.8 x 2.5 x 2.8 | box | 1 | no | |
| chicken_raw | Raw chicken | 3.0 x 0.7 x 3.0 | cyl | 3 | no | fries_to chicken_cooked |
| chicken_cooked | Crispy chicken | 3.0 x 0.7 x 3.0 | cyl | 3 | yes | fries_to chicken_burnt |
| chicken_burnt | Burnt chicken | 3.0 x 0.7 x 3.0 | cyl | 3 | no | |
| soda_cup | Soda | 2.2 x 3.0 x 2.2 | cyl | 1 | yes | made at the soda fountain |

`chops_to` gains an optional `chop_count` (default 3; potato 1). `fries_to` is the fryer's equivalent of `cooks_to`
(fry time then burn time from `Tuning.FRY_TIME` / `Tuning.FRY_BURN_TIME`, same bar and events as the griddle).

## 2. New stations
| type | model | size | behaviour |
|---|---|---|---|
| fryer | fryer | 7 x 0.5 x 6 | flat, sunk like the griddle; 3 slots; applies `fries_to`; oil bubbles/sizzle |
| soda | soda_fountain | 4 x 5 x 3 | solid; hold work about 2 s to spawn a `soda_cup` beside it (a dispenser with a longer hold and a pour animation) |
| dispenser | dispenser_bacon, dispenser_eggs, dispenser_onions, dispenser_pickles, dispenser_potatoes, dispenser_chicken | 5 x 4 x 5 | as existing dispensers; give bacon_raw, egg, onion, pickle_slice, potato, chicken_raw |
| plate (2nd) | plate | 7 x 0.4 x 7 | a map may list two plates + two bells; "Second Plate" upgrade enables the second one on maps that define it |

## 3. New recipes (`GameData.RECIPES`; price / bonus)
- bacon_cheeseburger "Bacon Cheeseburger": bun_bottom, patty_cooked, cheese_slice, bacon_cooked, bun_top (55/25)
- breakfast_burger "Breakfast Burger": bun_bottom, patty_cooked, fried_egg, bacon_cooked, bun_top (60/25)
- chicken_burger "Crispy Chicken Burger": bun_bottom, chicken_cooked, lettuce_leaf, bun_top (50/20)
- pickle_burger "Pickle Burger": bun_bottom, patty_cooked, cheese_slice, pickle_slice, pickle_slice, bun_top (50/20)
- the_works "The Works": bun_bottom, patty_cooked, patty_cooked, cheese_slice, bacon_cooked, onion_slice, tomato_slice, lettuce_leaf, bun_top (110/40)
- fries "Fries": fries (20/10)
- onion_rings "Onion Rings": onion_rings (25/10)
- loaded_hotdog "Loaded Hot Dog": hotdog_bun, sausage_cooked, onion_slice (45/20)
- chicken_salad "Chicken Salad": lettuce_leaf, lettuce_leaf, chicken_cooked, tomato_slice (55/20)
- burger_meal "Burger Meal": bun_bottom, patty_cooked, cheese_slice, bun_top, fries, soda_cup (85/35)
- hotdog_meal "Hot Dog Meal": hotdog_bun, sausage_cooked, fries, soda_cup (75/30)

## 4. Maps (`GameData.MAPS`, id -> MapDef)
MapDef: `id, name, blurb, theme, surfaces: [Rect2 (x, z, w, h) on y=0], stations: [...], scenery: [...], spawn_points,
hazards: [ids], camera_bounds (optional)`. Kitchen, bounds, spawn and the HUD read the map through
`World.map` (a MapDef dictionary); nothing may read `GameData.STATIONS/SCENERY/COUNTER_SIZE` directly any more.
- **diner** (existing layout and theme, one surface 60 x 36).
- **food_truck**: one surface 72 x 16; dispensers along the back wall; griddle + fryer at the left end, board in
  the middle, plate + bell + soda at the right end by a serving hatch; theme "truck" (steel walls, hatch window
  onto a street, menu board, string lights). Hazard `lurch`: every 35 to 55 s the truck lurches: loose food slides
  about 2 m in a random direction, a camera shake and a "Hold on!" toast 1 s before.
- **picnic**: one surface 56 x 40 wooden table with a checkered cloth; theme "picnic" (grass far below, sky, trees,
  a picnic basket, lemonade jug, watermelon). Hazard `wind`: gusts every 20 to 40 s push loose weight-1 food
  3 to 5 m downwind (shown by leaves/particles and a warning icon); carried food is safe.
- **twin_islands**: two surfaces 26 x 30 at x = -17 and x = +17 joined by a 5 m wide, 8 m long plank
  (a third surface) in the middle; all dispensers on the left island, griddle + fryer + board split across both,
  plate + bell + soda on the right island. Falling into the gap = the usual fall. Theme "diner" with a sink between.

## 5. Difficulty and modifiers (`data/difficulty.gd`)
Difficulty presets scale a ShiftDef: easy (interval x1.3, patience x1.3, target x0.7, burn window x1.5),
normal (x1), hard (interval x0.8, patience x0.85, target x1.3, burn window x0.8), chaos (interval x0.65,
patience x0.7, target x1.6, burn window x0.6, orders in bursts). Modifiers are independent toggles:
`rush_hour` (orders arrive in bursts of 2 to 3), `heavy_hands` (every weight +1), `slippery` (loose food slides
far, chefs have low friction), `mystery_orders` (tickets show only the dish name), `no_shop`, `lights_out`
(dim room, each chef carries a lamp).

## 6. Modes and settings (`data/game_settings.gd`, host-owned, replicated to clients in the lobby)
`mode: campaign | endless | custom`, `map`, `difficulty`, `modifiers: [ids]`, and for custom: `duration`,
`recipes: [ids]`, `target`. Campaign = a mission list (`data/missions.gd`): each mission names a map, a
ShiftDef, a difficulty, modifiers, and objectives: `target` coins plus up to two bonus objectives
(`no_burnt`, `no_expired`, `serve_n <recipe> <n>`, `earn <n>`) giving 1 to 3 stars. Progress (stars, best coins)
saved on the host in `user://progress.cfg`. Mission 0 "Training" is a gentle first shift with step prompts.
Endless = pick a map, shifts keep getting harder. Custom = the host picks everything.

## 7. Events (during a shift; `systems/event_system.gd`), enabled by mission/settings
- `vip`: a gold VIP ticket worth 3x with 60% patience.
- `inspector`: "Health inspector in 15 s!" banner; when the timer hits, every burnt item on the counter costs coins.
- `cat_paw` (diner, picnic): a giant cat paw sweeps across one lane, knocking loose food aside (telegraphed).

## 8. More upgrades (`GameData.UPGRADES`)
second_plate (needs a map with a second plate) 90, oven_mitts (burn window +50%) 70, hot_griddle (cook and fry
30% faster) 90, tongs (grab reach +50%) 60. Plus a free ping: middle mouse / pad Y drops a 3 s marker at the
cursor that every player sees.

## 9. Chef customisation (lobby)
Each player picks a colour (default by join order) and a hat: toque (default), beanie, paper_hat, bandana,
and one face accessory: none, glasses, big_moustache. Replicated via the roster; models `hat_*.glb`,
`acc_*.glb` attach to the chef head.

## 10. Stats
Per run and per player: served, burnt, dropped off the edge, items carried, coins earned; end-of-run screen
with an MVP line per category. Best scores per map/difficulty saved with progress.

## 11. Balance
A harness (`tools/balance.ps1`) runs bot shifts at 1 to 4 players over maps and difficulties and writes a table
(served, coins, target met). Targets are tuned so a bot team meets the target at roughly 70 to 80% of its
throughput on normal; humans are faster than bots, so this leaves room.
