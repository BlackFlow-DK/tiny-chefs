# Tiny Chefs system map

Brief agents from this. One row per system. "May edit" is the file set an agent owning that system
may change; anything else goes through the owner (or the World API). Paths are under `game/scripts/`.

Rules: host-authoritative. ALL RPCs live in `net/net.gd` and forward to `World` (`receive_input`,
`apply_snapshot`, `try_buy`). `World` is the thin owner of shared state; systems get the World,
never call each other, and talk through World-level methods. Host tick order (`World._simulate`):
chef actions (carry grab, punch, plate serve) + `Chef.host_move` -> carry -> bounds edge ->
plate cooldowns -> every `Station.host_update` -> bounds falls -> shift. Snapshot every 2nd tick.

## World and its systems (`world/`)

| System | Owns | Public API | May edit |
|---|---|---|---|
| World (`world/world.gd`) | shared state (chefs, items, inputs, stations, shift, orders, camera, hint_text), the map (`map`: MapDef from `GameData.MAPS`, id from `Net.phase_info.map`, which the host stamps into every `set_phase` from `World.map_id_for_session()` = `--map=<id>`, default diner), system creation, tick order, item spawn/remove, toast cooldown | Net targets above; `map, map_id_for_session, on_counter(xz), surface_bounds, start_shift, input_of, grab_candidate, release, detach_all, spawn_item, remove_item, dispense, change_kind, chop, refuse_from_plate, toast, note_orders_changed, my_chef` | tick order / new world-level forwarders only (coordinate) |
| Carry (`systems/carry_system.gd`) | grab/release and which item a grab takes (cursor first, then nearest in front), solo carry (item held in front, swings with the chef at `CARRY_TURN_RATE`/weight), group carry (averaged inputs, carriers face the item), item + carriers swept as one unit against scenery/chefs, carrier off the edge lets go, speed by weight, patty speed metrics; `--carry-log`, `--carry-spawn` | `grab_candidate(chef, input), on_grab_pressed, release, detach_all, forget_item, move_carried` | it, `world/item.gd` carry section, `world/chef.gd` hold_* vars + carry visuals |
| Punch (`systems/punch_system.gd`) | gloves gate, cooldown, target pick, launch food / shove chef | `on_punch_pressed` | it |
| Bounds (`systems/bounds_system.gd`) | carried food off every map surface (`world.on_counter`) is let go; fallen food removed; `--map-log` | `drop_over_edge, remove_fallen` | it (chef fall/respawn: `world/chef.gd host_move/respawn`) |
| Dispenser (`systems/dispenser_system.gd` + `world/stations/dispenser.gd`) | hold timer (station), loose-food cap and batch spawn (system) | `dispense`; `Dispenser.output_spots, stand_spot` | both |
| Griddle (`systems/griddle_system.gd` + `world/stations/griddle.gd`) | slots, cook/burn timers (burn = `BURN_TIME` x ShiftDef `burn_scale`), bars (station); kind change + ding/burnt events (system) | `change_kind`; `Griddle.reset` | both |
| Cutting board (`systems/cutting_board_system.gd` + `world/stations/cutting_board.gd`) | chop progress, workers, knife anim, state (station); whole -> slices (system) | `chop`; `CuttingBoard.reset, state, apply_state, has_tomato` | both |
| Bounds (`systems/bounds_system.gd`) | carried food over the counter edge is let go; fallen food removed | `drop_over_edge, remove_fallen` | it (chef fall/respawn: `world/chef.gd host_move/respawn`) |
| Dispenser (`systems/dispenser_system.gd` + `world/stations/dispenser.gd`) | hold timer (station, `hold_time()`), loose-food cap and batch spawn (system); optional station `"yaw"` turns output/stand spots | `dispense`; `Dispenser.output_spots, stand_spot, hold_time` | both |
| Soda fountain (`world/stations/soda_fountain.gd`, logic in the Dispenser system) | `SodaFountain extends Dispenser`: solid, `Tuning.SODA_HOLD` hold, gives `soda_cup` under its nozzle, pour animation (stream + filling cup, every peer from chefs' `FLAG_WORKING`), fizz on spawn; listed in `world.dispensers` and `world.soda` | as Dispenser | it |
| Griddle (`systems/griddle_system.gd` + `world/stations/griddle.gd`) | slots, cook/burn timers along `cooks_to`, bars (station; cook stage = the result changes again, `CRACK_TIME` for `"crack"` items); kind change + ding/crack/burnt events (system) | `change_kind`; `Griddle.reset, is_cook_stage, key` | both |
| Fryer (`systems/fryer_system.gd` + `world/stations/fryer.gd`) | `Fryer extends Griddle` along `fries_to`: `FRY_TIME`/`FRY_BURN_TIME`, `FRYER_SLOTS`, `Item.Bar.FRY` bar, oil bubbles (station); kind change + ding/burnt events (system). Flat, no collider; `world.fryer` may be null | `world.fry`; `Fryer.reset` | both |
| Cutting board (`systems/cutting_board_system.gd` + `world/stations/cutting_board.gd`) | chop progress of any `chops_to` food, workers, knife anim, state (station); whole -> `chop_count` pieces (system) | `chop`; `CuttingBoard.reset, state, apply_state, has_food` (`has_tomato` = old alias) | both |
| Plate + bell (`systems/plate_system.gd` + `world/stations/plate.gd`, `bell.gd`) | stack snapping (station); serve at bell, pay/penalty, raw/burnt/whole refusal, refuse cooldown (system) | `on_work_pressed, refuse_from_plate, tick`; `Plate.stack, clear_stack, state`; `Bell.ring` | all three |
| Trash (`world/stations/trash.gd`) | food on the drain disappears (no system file needed) | `host_update` | it |
| Shift (`systems/shift_system.gd`) | shift start/end, clock, order expiry + "new order" events, shop buy, --upgrades, --quit-after-shift | `start_shift, tick, sync_order_count, try_buy, apply_test_upgrades, process_quit` | it, `game/shift_manager.gd`, `game/order_manager.gd` |
| Roster (`systems/roster_system.gd`) | host adds/removes chefs + input slots on join/leave; client name refresh | `sync` | it |
| Snapshot (`systems/snapshot_system.gd`) | replicated wire format: build (host), apply (client) | `build, apply` | it + matching `state()/apply_state()`; format change needs both peers |
| Input (`systems/input_system.gd`) | local keyboard/mouse/pad or `--bot` into `world.local_input`: move (polled), presses via `_unhandled_input` (GUI clicks never leak), aim = cursor ray on the counter plane (camera read from the viewport at call time) or right stick; active-device switch; `--input-log` | `collect` | it, `game/controls.gd` |
| Camera (`systems/camera_system.gd`) | creates and follows `world.camera` | `update` | it |
| Hazards (`systems/hazard_system.gd` + `world/hazards/<id>_hazard.gd`) | one `Hazard` per id in `world.map.hazards` (ids without a script are skipped); `setup(world)` every peer, `host_tick(dt)` from `_simulate` after the stations while PLAYING, `client_tick(dt)` every frame on every peer; hazards reach clients through `Net.event` + snapshots only. `wind` (picnic): gust every 20-40 s from a compass direction, 2 s telegraph (`Net.event("", "gust:<0..7>")` -> leaves + streaks, whoosh, arrow toast), then 2 s steering loose weight-1 food 3-5 m downwind; debug `--wind-at= --wind-every= --wind-dir= --wind-log` | `HazardSystem.host_tick, client_tick`; `Hazard.setup, host_tick, client_tick` | them |
| Hint (`systems/hint_system.gd`) | grab/work rings, `hint_text`, `grab_target/work_target` | `update` | it |
| Station base (`world/stations/station.gd`) | setup, footprint helpers, `workers()`, state hooks | `contains_xz, footprint_distance, centre_distance, workers, host_update, state, apply_state, work_hint` | shared: coordinate |
| Chef (`world/chef.gd`) | chef body, walk, fall/respawn, puppet easing, animation | `setup, host_move, face, aim_at, respawn, host_flags, set_target, set_gloves, set_player_name` (not carrying + `has_aim`: `host_move` turns to `aim_point` at 14 rad/s, else faces movement; while carrying CarrySystem turns it) | it |
| Item (`world/item.gd`) | food body, kind, carry attach/detach, puppet easing, bars | `setup, set_kind, weight, attach, detach, set_target, set_cooking` | it |
| Kitchen / Models (`world/kitchen.gd`, `world/models.gd`) | static scenery for a MapDef: one collider per surface; look by theme: "diner" (`EnvLook` + `EnvCounter` + `EnvRoom` + back-wall collider), "picnic" (`EnvPicnic`: sky, plank table + gingham cloth, lawn, trees, `PicnicLife` bee/ants/leaves; no back wall), unknown -> diner; scenery props (`hob` and `flat` ones have no collider), decor; .glb-or-primitive factory | `Kitchen.build(root, map)`; `Models.make, load_model, mesh_node, label` | them |

## Everything else

| System | Owns | Public API | May edit |
|---|---|---|---|
| Net (`net/net.gd`, autoload) | ENet session, players, phases, args, ALL RPCs, metrics, test report; the live `settings` (GameSettings, host-owned, replicated by `_sync_settings` on every change and on join) | signals `players_changed, phase_changed, session_ended, event_received, settings_changed`; `host, join, leave, set_phase, event, send_snapshot, send_input, buy, arg_*, metric_max, finish_test`; settings: `settings, can_edit_settings, change_setting(key, value), set_settings(s)` (host or offline menu, MENU/LOBBY only; clients ignored) | it (RPC names are wire format) |
| Game settings (`data/game_settings.gd`) | run setup: `mode` campaign/endless/custom, `map`, `difficulty`, `modifiers`, `mission`, custom `duration/recipes/target/interval/patience` | `to_dict, from_dict, copy, equals, validate, describe, map_ids`; `MODES`, `*_RANGE` | settings owner |
| Difficulty (`data/difficulty.gd`) | presets (interval/patience/target/burn multipliers, chaos bursts) and modifier ids with UI label + desc | `apply(shift_def, preset_id)`, `preset, label, desc, has_preset, has_modifier`; `PRESET_IDS, MODIFIER_IDS` | settings owner |
| Missions (`data/missions.gd`) | campaign DATA: 12 missions over diner/food_truck/picnic/twin_islands (map, difficulty, modifiers, recipes, numbers, objectives, events, blurb) | `LIST, count, get_mission` | settings owner (objective logic lives elsewhere) |
| Shift plan (`data/shift_plan.gd`) | GameSettings + shift index + players -> ShiftDef (Dictionary: name, index, mode, mission_id, map, difficulty, modifiers, events, objectives, blurb, recipes, duration, interval, patience, target, burn_scale, bursts); endless ramp | `build(settings, shift_index, players), map_for(settings, shift_index), describe(def)`. Host: `world.shift.def`; clients rebuild it from `Net.settings` in `ShiftManager.from_meta` | settings owner |
| Main (`main.gd`) | root: UI screens, creates/frees World per phase, --autostart/--join | none | it |
| Bot (`game/bot.gd`) | `--bot` player: reads world view, writes PlayerInput | `update` | it |
| PlayerInput / Controls (`game/player_input.gd`, `game/controls.gd`) | input packet shape (move, work, grab/punch/work seqs, `aim_point: Vector2` world XZ + `has_aim: bool`); input map | `copy_from, move3, aim3`; `Controls.setup`. Host reads a player's aim as `world.input_of(peer_id).aim_point/has_aim` | them (packet shape = wire format: `Net._rpc_input` + `World.receive_input`) |
| Shift/Order data (`game/shift_manager.gd`, `game/order_manager.gd`) | wallet, clock, upgrades; open orders (replicated as meta) | `begin, add_coins, has_upgrade, to_meta/from_meta`; `reset, update, match_plate` | Shift owner |
| Data (`data/tuning.gd`, `data/game_data.gd`) | every tunable; items, recipes, shifts, upgrades; maps (`MAPS`: id -> MapDef, fields documented above `MAPS` in game_data.gd) | constants; `GameData.item, kind_index, upgrade, shift_def` (= `ShiftPlan.build(Net.settings, ...)`), `map(id), map_ids(include_dev), surfaces_bounds, surfaces_contain` | balance owner |
| Data (`data/tuning.gd`, `data/game_data.gd`) | every tunable; items, stations, recipes, shifts, upgrades | constants; `GameData.item, kind_index, upgrade, shift_def, transform_station, route` | balance owner |
| Sfx (`audio/sfx.gd`, autoload) | synthesized sounds | `play` | it |
| UI (`ui/*.gd`) | HUD, menu, lobby, end screens, pause, theme + kit widgets | `Hud.toggle_help, EndScreens.show_phase, PauseMenu.open/close, UITheme.build, UIKit.*` | `ui/**` (reads `world.shift/orders/items/camera/hint_text`, writes `world.input_blocked`) |
| Dev galleries (`dev/*.gd`) | model + UI review scenes | none | them |
| Agent tools (`game/tools/*.gd`) | `--shot`, `--key`, `--mouse`, `--click` autoloads, project check | none | tooling owner |
