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
| World (`world/world.gd`) | shared state (chefs, items, inputs, stations, shift, orders, camera, hint_text), system creation, tick order, item spawn/remove, toast cooldown | Net targets above; `start_shift, input_of, grab_candidate, release, detach_all, spawn_item, remove_item, dispense, change_kind, chop, refuse_from_plate, toast, note_orders_changed, my_chef` | tick order / new world-level forwarders only (coordinate) |
| Carry (`systems/carry_system.gd`) | grab/release, carrier offsets, averaged-input carry movement, speed by weight, patty speed metrics | `grab_candidate, on_grab_pressed, release, detach_all, forget_item, move_carried` | it, `world/item.gd` carry section |
| Punch (`systems/punch_system.gd`) | gloves gate, cooldown, target pick, launch food / shove chef | `on_punch_pressed` | it |
| Bounds (`systems/bounds_system.gd`) | carried food over the counter edge is let go; fallen food removed | `drop_over_edge, remove_fallen` | it (chef fall/respawn: `world/chef.gd host_move/respawn`) |
| Dispenser (`systems/dispenser_system.gd` + `world/stations/dispenser.gd`) | hold timer (station), loose-food cap and batch spawn (system) | `dispense`; `Dispenser.output_spots, stand_spot` | both |
| Griddle (`systems/griddle_system.gd` + `world/stations/griddle.gd`) | slots, cook/burn timers, bars (station); kind change + ding/burnt events (system) | `change_kind`; `Griddle.reset` | both |
| Cutting board (`systems/cutting_board_system.gd` + `world/stations/cutting_board.gd`) | chop progress, workers, knife anim, state (station); whole -> slices (system) | `chop`; `CuttingBoard.reset, state, apply_state, has_tomato` | both |
| Plate + bell (`systems/plate_system.gd` + `world/stations/plate.gd`, `bell.gd`) | stack snapping (station); serve at bell, pay/penalty, raw/burnt/whole refusal, refuse cooldown (system) | `on_work_pressed, refuse_from_plate, tick`; `Plate.stack, clear_stack, state`; `Bell.ring` | all three |
| Trash (`world/stations/trash.gd`) | food on the drain disappears (no system file needed) | `host_update` | it |
| Shift (`systems/shift_system.gd`) | shift start/end, clock, order expiry + "new order" events, shop buy, --upgrades, --quit-after-shift | `start_shift, tick, sync_order_count, try_buy, apply_test_upgrades, process_quit` | it, `game/shift_manager.gd`, `game/order_manager.gd` |
| Roster (`systems/roster_system.gd`) | host adds/removes chefs + input slots on join/leave; client name refresh | `sync` | it |
| Snapshot (`systems/snapshot_system.gd`) | replicated wire format: build (host), apply (client) | `build, apply` | it + matching `state()/apply_state()`; format change needs both peers |
| Input (`systems/input_system.gd`) | local keyboard/pad or `--bot` into `world.local_input` | `collect` | it, `game/controls.gd` |
| Camera (`systems/camera_system.gd`) | creates and follows `world.camera` | `update` | it |
| Hint (`systems/hint_system.gd`) | grab/work rings, `hint_text`, `grab_target/work_target` | `update` | it |
| Station base (`world/stations/station.gd`) | setup, footprint helpers, `workers()`, state hooks | `contains_xz, footprint_distance, centre_distance, workers, host_update, state, apply_state, work_hint` | shared: coordinate |
| Chef (`world/chef.gd`) | chef body, walk, fall/respawn, puppet easing, animation | `setup, host_move, face, respawn, host_flags, set_target, set_gloves, set_player_name` | it |
| Item (`world/item.gd`) | food body, kind, carry attach/detach, puppet easing, bars | `setup, set_kind, weight, attach, detach, carry_step, set_target, set_cooking` | it |
| Kitchen / Models (`world/kitchen.gd`, `world/models.gd`) | static scenery; .glb-or-primitive factory | `Kitchen.build`; `Models.make, load_model, mesh_node, label` | them |

## Everything else

| System | Owns | Public API | May edit |
|---|---|---|---|
| Net (`net/net.gd`, autoload) | ENet session, players, phases, args, ALL RPCs, metrics, test report | signals `players_changed, phase_changed, session_ended, event_received`; `host, join, leave, set_phase, event, send_snapshot, send_input, buy, arg_*, metric_max, finish_test` | it (RPC names are wire format) |
| Main (`main.gd`) | root: UI screens, creates/frees World per phase, --autostart/--join | none | it |
| Bot (`game/bot.gd`) | `--bot` player: reads world view, writes PlayerInput | `update` | it |
| PlayerInput / Controls (`game/player_input.gd`, `game/controls.gd`) | input packet shape; input map | `copy_from, move3`; `Controls.setup` | them (packet shape = wire format) |
| Shift/Order data (`game/shift_manager.gd`, `game/order_manager.gd`) | wallet, clock, upgrades; open orders (replicated as meta) | `begin, add_coins, has_upgrade, to_meta/from_meta`; `reset, update, match_plate` | Shift owner |
| Data (`data/tuning.gd`, `data/game_data.gd`) | every tunable; items, stations, recipes, shifts, upgrades | constants; `GameData.item, kind_index, upgrade, shift_def` | balance owner |
| Sfx (`audio/sfx.gd`, autoload) | synthesized sounds | `play` | it |
| UI (`ui/*.gd`) | HUD, menu, lobby, end screens, pause, theme + kit widgets | `Hud.toggle_help, EndScreens.show_phase, PauseMenu.open/close, UITheme.build, UIKit.*` | `ui/**` (reads `world.shift/orders/items/camera/hint_text`, writes `world.input_blocked`) |
| Dev galleries (`dev/*.gd`) | model + UI review scenes | none | them |
| Agent tools (`game/tools/*.gd`) | `--shot`, `--key` autoloads, project check | none | tooling owner |
