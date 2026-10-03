# Tiny Chefs: upgrade tree (data contract for the shop UI and balance agents)

Source of truth: `GameData.UPGRADES` in `game/scripts/data/game_data.gd`. This table mirrors it; if they
disagree, the code wins. Prices are placeholders (balance agent sets them; first levels cheap, ~x1.6 per level).

## Data shape
```
{"id", "name", "category", "desc" (with {value}), "icon" (model name or ""), "emblem"? (ShopIcon emblem id),
 "unit": "pct" | "int" | "num" | "none", "stack": "add" (default) | "mult",
 "levels": [{"price": int, "value": float}, ...], "requires"?: "<id>" or "<id>:<level>"}
```
- `value` is the PER-LEVEL step. The effect at owned level L is the sum of the first L values (`stack: "add"`,
  every line today) or their product (`stack: "mult"`, supported, unused). The effect in the table below is
  that cumulative value; hooks apply it as written in the "hook" column.
- `unit` only formats `{value}` in `desc`: pct -> "45%", int -> "2", num -> "0.68", none -> "".
- Old ids keep working everywhere (`--upgrades`, `has_upgrade`, `try_buy`): `knife` -> `sharp_knife`
  (`GameData.UPGRADE_ALIASES`). `shoes`, `gloves`, `oven_mitts`, `hot_griddle`, `tongs`, `second_plate` kept their ids.

## API
- `GameData.upgrade(id)` (aliases ok), `upgrade_ids()`, `upgrade_categories()` -> `[{id, name, upgrades: [ids]}]`
  in shop order, `upgrade_id(id)` (alias -> canonical), `upgrade_max_level(id)`, `upgrade_price(id, level)`
  (price of that level, 1-based; -1 past max), `upgrade_total(id, level)` (cumulative effect),
  `upgrade_desc(id, level)` (desc with the value at that level), `upgrade_title(id, level)` ("Hot Griddle III";
  one-level lines get no numeral), `upgrade_requires(id)` -> `[id, level]` or `[]`.
- `ShiftManager` (`world.shift`, every peer): `upgrades` = `{id: level}` (only owned ids), `upgrade_level(id)`,
  `upgrade_value(id, default)` (cumulative effect at the owned level, `default` when not owned),
  `has_upgrade(id)` (= level > 0), `requires_met(id)`, `next_price(id)` (-1 at max).
- Buying: `Net.buy(id)` -> host `ShiftSystem.try_buy(id)`: buys the NEXT level when affordable, `requires` met
  and the station exists on the next map; refuses at max. Replicated in the shift meta (index 8) as the dict.
- Tests: `--upgrades=id:level,...` (bare id = max level; clamped to 1..max), `--coins=<n>` (host start wallet),
  `--upgrade-table` (host prints one `upgrades: table` line per upgrade with its hook's effect at level 1 and max).
  The host always logs `upgrades: effects ...` at shift start (all hooks' current values).

## Table
| id | name | category | levels | step | effect at I .. max | hook |
|---|---|---|---|---|---|---|
| hot_griddle | Hot Griddle | cooking | 5 | +15% | +15 / 30 / 45 / 60 / 75% cook + fry speed | `Griddle.cook_speed()` = 1 + v (cook stage time / it) |
| oven_mitts | Oven Mitts | cooking | 3 | +25% | +25 / 50 / 75% burn window | `Griddle.burn_scale()` x (1 + v), griddle + fryer |
| big_griddle | Big Griddle | cooking | 2 | +1 | 5 / 6 griddle slots | `Griddle.slots()` = GRIDDLE_SLOTS + v, capped by `slot_fit()` |
| big_fryer | Big Fryer | cooking | 1 | +1 | 4 fryer slots (a 7x6 fryer fits 4) | `Fryer.slots()` = FRYER_SLOTS + v, capped by `slot_fit()` |
| sharp_knife | Sharp Knife | prep | 4 | +25% | +25 / 50 / 75 / 100% chop speed | `CuttingBoard.chop_mult()` = 1 + v |
| quick_hands | Quick Hands | prep | 3 | +20% | +20 / 40 / 60% dispense + soda speed | `Dispenser.hold_time()` / (1 + v) (SodaFountain too) |
| shoes | Running Shoes | movement | 4 | +7% | +7 / 14 / 21 / 28% move + carry speed | `World.move_mult()` = 1 + v |
| protein_shake | Protein Shake | movement | 3 | +0.34 | +0.34 / 0.68 / 1.02 carrier | `CarrySystem.speed_factor()`: clamp((n + v) / weight, MIN, 1) (speed only, never above the unloaded max) |
| tongs | Long Tongs | movement | 2 | +25% | +25 / 50% grab reach | `CarrySystem.grab_reach()` x (1 + v) |
| second_plate | Second Plate | service | 1 | - | opens the second plate + bell | `Station.is_locked()` |
| friendly_service | Friendly Service | service | 4 | +10% | +10 / 20 / 30 / 40% order patience | `OrderManager.patience_mult` = 1 + v (regular + VIP orders) |
| tip_jar | Tip Jar | service | 4 | +8% | +8 / 16 / 24 / 32% pay | `OrderManager.pay_for(o, shift, combo, tidy)`: x MESSY_PAY if untidy, then x (1 + v) x combo, then x VIP |
| insurance | Insurance | service | 3 | 25% | -25 / 50 / 75% expiry penalty | `OrderManager.expire_penalty(o, shift)` x (1 - v) |
| combo_bell | Combo Bell | service | 3 | +5% | +5 / 10 / 15% pay per streak step (max 5 steps) | `PlateSystem.combo_mult(shift, streak)`; streak = serves each within `Tuning.COMBO_WINDOW` (20 s) of the last; toast "Combo xN!" |
| gloves | Boxing Gloves | chaos | 1 | - | unlocks punching | `PunchSystem` gate |
| heavy_gloves | Heavy Gloves | chaos | 2 | +40% | +40 / 80% punch launch (food + chef shove) | `PunchSystem.launch_mult(shift)` = 1 + v; requires gloves |

## Notes for the shop UI agent
- Build cards from `GameData.upgrade_categories()`; per card read `shift.upgrade_level(id)`,
  `GameData.upgrade_max_level(id)`, `shift.next_price(id)` (-1 = MAX), `GameData.upgrade_desc(id, level)`
  (current or next level), `shift.requires_met(id)` and `ShiftSystem.upgrade_available(id, shift.next_index)`.
- The current `ShopView` is a stop-gap: an 8-column grid (2 rows at 1280x720, in a ScrollContainer) of small
  cards, each showing the next level's title, desc and price with "Lv n/max", "Upgrade" once owned, a MAX
  ribbon + "Maxed out" when done, "Needs <line>" when `requires` is unmet, "Not available on this kitchen"
  for second_plate on maps without one. Card state key is "<st>:<level>" so every bought level refreshes it.
- Emblems: ShopIcon draws `emblem` (default the id) when `icon` is "" or missing; only shoes, second_plate,
  oven_mitts, hot_griddle, tongs have real emblems, the rest show the generic coin.
