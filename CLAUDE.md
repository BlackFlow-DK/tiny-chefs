# Godot game repo: agent guide

Tooling only: Godot 4.7.2 (GDScript, Forward+) + Blender 5.2.1. Everything runs from the CLI; never open the editor/GUI.
Run tools from anywhere; they resolve paths from the repo root. Never hardcode absolute paths in project files.

## Executables (override with env vars)
- Godot: `GODOT_BIN`, else `%LOCALAPPDATA%\Microsoft\WinGet\Links\godot_console.exe`, else PATH. Use the `_console` variant (it prints to stdout).
- Blender: `BLENDER_BIN`, else `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, else PATH.
- Export templates: `%APPDATA%\Godot\export_templates\4.7.2.stable\` (installed).

## Tools (PowerShell 5.1; all exit non-zero on failure)
Call as `powershell -NoProfile -ExecutionPolicy Bypass -File tools\<name>.ps1 ...`
- `blender-run.ps1 art\scripts\x.py [args]` runs a Blender script headless (`--factory-startup --python-exit-code 1`). Fails if the script raises.
- `godot-import.ps1` headless import. Run after adding/changing any asset (.glb, textures, audio).
- `godot-check.ps1` parses every `.gd` and loads every `.tscn/.scn` (via `game/tools/check_project.gd`). Catches parse, type and undefined-identifier errors and broken scene references. Imports first if `.godot/` is missing.
- `godot-screenshot.ps1 [-Scene res://scenes/x.tscn] [-Out build\screenshots\x.png] [-Frames 60] [-Resolution 1280x720] [-TimeoutSec 60]` runs the game in a real window, saves the viewport PNG after N frames, quits. Default scene: main scene; default out: `build\screenshots\<scene>.png`. Fails on timeout, missing PNG, or any `SCRIPT ERROR`/`ERROR` line.
- `export-windows.ps1 [-DebugBuild]` exports `build\windows\<repo-folder>.exe` (PCK embedded, single file, ~105 MB).
- Single script check without the wrapper: `godot_console --headless --path game --check-only --script res://path.gd`.

- `test-multiplayer.ps1 [-Solo] [-ShiftSeconds 100] [-Windowed] [-ShotDir build\screenshots -ShotAt 45] [-BotLog] [-Port 7777]` runs Tiny Chefs host + client bots on 127.0.0.1 (headless by default), one short shift, checks their JSON reports (connected, both chefs everywhere, order served, duo patty carry faster than solo, clean exits, no ERROR lines). Logs: `build\test-mp\` (`build\test-mp-<port>\` if `-Port` differs; use distinct ports for parallel runs).
- `balance.ps1 [-Players 1,2,3,4] [-Shifts 0,1,2] [-Maps m] [-Difficulty d] [-ShiftSeconds 210] [-Runs 1] [-Port 7905] [-Out build\balance\<ts>]` balance harness: host + (n-1) client bots per combo (`--start-shift=<n>` starts at shift n), then `balance_summary.py` writes `summary.md`/`summary.csv` (served, expired, coins, target, met, coins/min, coins/target). Non-zero exit on timeout or missing report.

## Tiny Chefs (the game in game/)
- Tunables: `game/scripts/data/tuning.gd` (speeds, timings, penalties, camera, net). Content: `game/scripts/data/game_data.gd` (item sizes/weights/colours from `docs/asset-contract.md`, station layout, recipes, shifts, upgrade prices).
- Models: `Models.make()` loads `res://assets/models/<name>.glb` if present, else a coloured primitive. Colliders always come from the data sizes. New .glb: `godot-import`, nothing else.
- Net: host-authoritative ENet (UDP 7777). ALL RPCs live in the `Net` autoload (`scripts/net/net.gd`) and forward to `World`; clients send `PlayerInput`, host sends 30 Hz snapshots. Never name an RPC after a Node virtual (`_input` clashed).
- User args (after `--`): `--host --join=<ip> --name= --autostart --players=<n> --bot --bot-log --bind=<ip> --port=<n> (default 7777) --shift-seconds= --upgrades=gloves,knife,shoes --test-report=<json> --quit-after=<s> --quit-after-shift`. Agent helpers: `--shot=<s>@<png>` (non-quitting screenshot), `--key=<s>@<key>@<hold s>`, `--mouse=<s>@<x>,<y>`, `--click=<s>@<left|right|middle>@<hold s>` (real key/mouse events via `tools/input_script.gd`; injected input skips the focus check), `--input-log` (presses + host view of every chef's aim/facing), `--carry-log` (host: every carried item's mode, swing deg/s, carrier inside scenery), `--carry-spawn=<kind>:<x>:<z>[,...]` (drop food on the counter when play starts), `--map=<id>` (host: map from `GameData.MAPS`, default `diner`; clients follow the host; dev map `test_islands`), `--map-log` (map built, chef falls/respawns, food removed after a fall).
- User args (after `--`): `--host --join=<ip> --name= --autostart --players=<n> --bot --bot-log --bind=<ip> --port=<n> (default 7777) --shift-seconds= --upgrades=gloves,knife,shoes --test-report=<json> --quit-after=<s> --quit-after-shift`. Agent helpers: `--shot=<s>@<png>` (non-quitting screenshot), `--key=<s>@<key>@<hold s>`, `--mouse=<s>@<x>,<y>`, `--click=<s>@<left|right|middle>@<hold s>` (real key/mouse events via `tools/input_script.gd`; injected input skips the focus check), `--input-log` (presses + host view of every chef's aim/facing), `--carry-log` (host: every carried item's mode, swing deg/s, carrier inside scenery), `--carry-spawn=<kind>:<x>:<z>[,...]` (drop food on the counter when play starts), `--recipes=<id>[,...]` (host: every shift orders only these recipes, first one first). Host logs `content: ...` lines for every griddle/fryer/board transform, plate stack and serve.
- Controls: move WASD/arrows/left stick; grab LMB/E/pad A; work (hold) RMB/F/pad X; punch Space/Q/pad B; ping MMB/pad Y (3 s marker everyone sees). Chef faces the cursor (`PlayerInput.aim_point/has_aim`) when not carrying; a lone carrier holds the food in front and swings it towards the cursor (else the move direction), slower the heavier it is; group carriers face the food.
- Game settings args (host, applied before `--autostart`): `--mode=campaign|endless|custom --map=<id> --difficulty=easy|normal|hard|chaos --modifiers=a,b --mission=<n>`. Host and client log `net: settings ...` and `shift: host|client def ...`. `test-multiplayer.ps1 -HostExtra "<args>" -ClientExtra "<args>"` passes extra user args.
- Shift events (host): `--events=vip,inspector,cat_paw` forces those events on in endless/custom (campaign missions and endless shift 2+ enable them anyway; cat_paw needs the map hazard), `--event-fast` fires the first one 6 s into the shift (then 15 s gaps). Host logs `events: ...`; test report `events` counters.
- Relative `--test-report` paths resolve against `game/`; pass absolute paths.
- New `class_name` scripts need `godot-import` before `godot-check` (global class cache).
- Player guide: `docs/PLAYING.md`.

## Done means
Before reporting any change as done: `godot-import` (if assets changed) -> `godot-check` -> `godot-screenshot`, then Read the PNG and confirm with your own eyes that the change is visible and correct. Report the PNG path.

## Layout
- `game/` Godot project root (`res://`). `scenes/` .tscn, `scripts/` gameplay .gd, `assets/models/` .glb from Blender, `tools/` agent helpers (do not delete: `screenshot.gd` and `input_script.gd` are autoloads, inert without their args).
- `art/scripts/` Blender Python generators, one script per asset (or family), using `artlib.py`. `art/blend/` optional hand-made .blend sources.
- `tools/` PowerShell wrappers. `build/` exports + screenshots (gitignored).

## Asset conventions
- Units metres, real-world scale. Author in Blender Z-up; exporter writes glTF +Y up (Godot's up).
- Model front faces Blender -Y, which lands on Godot +Z (`Vector3.MODEL_FRONT`).
- Origin at the base centre (object stands on y=0 in Godot). Build around the world origin with the bottom at z=0, then `artlib.join()` applies all transforms.
- Names: snake_case files (`test_prop.py` -> `game/assets/models/test_prop.glb`); PascalCase object/material names.
- Export only through `artlib.export_glb(name)`: GLB, +Y up, apply modifiers, materials on, no cameras/lights, whole scene.
- Colours: `artlib.material(name, "#rrggbb")` takes sRGB hex and converts to linear for Principled BSDF. Base colour, roughness, metallic survive to Godot; flat colours need no textures.
- Commit the `.glb` AND its `.glb.import`, plus Godot's `*.gd.uid` files. Never commit `.godot/` or `build/`.
- Regenerate a model: `blender-run` -> `godot-import`. Instance a .glb in a scene as a PackedScene (`instance=ExtResource(...)`).

## Gotchas (hit while setting this up)
- Blender exits 0 when a `--python` script raises unless `--python-exit-code 1` (the wrapper sets it).
- Blender 5.x: materials always have a node tree (`use_nodes` is deprecated, do not set it); `Principled BSDF` exists by default.
- Godot colours its output with ANSI codes even when redirected; the wrappers strip them before matching `ERROR`.
- `--headless` uses a dummy renderer: it cannot screenshot. The screenshot tool opens a real window briefly.
- Loading the currently running `--script` file with `CACHE_MODE_IGNORE` segfaults Godot 4.7.2 (check_project.gd skips itself).
- Exported release builds also honour `-- --screenshot=<png>` (handy to verify an export actually renders).
- Hand-written .tscn: omit `uid=` and `load_steps`; Godot accepts it. `rotation`/`position` can be set directly instead of a `transform`.
- Export preset sets `application/modify_resources=false` (no rcedit, so no custom exe icon/metadata).
