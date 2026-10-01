# Tiny Chefs: how to play (prototype)

Co-op kitchen chaos for 1 to 4 players on separate PCs. You are a 1 m tall chef on a giant
kitchen counter. The food is bigger than you are: heavy food moves faster when more chefs carry it.

## Start

- Built game: `build\windows\godot-game.exe` (single file). Rebuild it with
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\export-windows.ps1`.
- From source: `godot --path game` (Godot 4.7.2).

Title screen: type your name, then **Host a kitchen** (solo or LAN), or type the host's IP and **Join**.
Solo is just hosting with nobody else. In the lobby the host presses **Start the shift**.

## LAN

- The host's lobby lists its LAN IPv4 address(es). The most likely one (192.168.x.x) is listed first;
  172.x addresses are usually virtual adapters (WSL, Hyper-V, VPN).
- Game traffic: **UDP port 7777** on the host. The first time you host, Windows Firewall may ask
  whether to allow the game: allow it on **private** networks. If friends cannot connect, check
  that prompt/rule (Windows Security > Firewall > Allow an app) and that everyone is on the same network.
- Up to 4 chefs. People can join or leave in the middle of a shift. A leaving chef drops what it carried.
  If the host leaves, everyone returns to the title screen.

## Try it alone with two windows

Start the exe twice. Window 1: Host. Window 2: keep IP `127.0.0.1` and Join. Only the focused window
reads the keyboard, mouse and gamepad, so click a window to control that chef.
Shortcut from a terminal:

```
build\windows\godot-game.exe -- --host --name=Me
build\windows\godot-game.exe -- --join=127.0.0.1 --name=Friend
```

Add `--bot` to either one to have a bot play that chef.

## Controls

| action | keyboard / mouse | gamepad |
|---|---|---|
| move | WASD or arrows | left stick |
| look (aim) | mouse cursor | right stick |
| grab / let go (toggle) | left click or E | A |
| work (hold): dispense, chop, ring the bell | right click or F | X |
| punch (needs Boxing Gloves) | Space or Q | B |
| ping a spot (everyone sees it for 3 s) | middle click | Y |
| pause menu (Leave, Quit) | Esc | Start |
| hide the controls help | H | Back |

Your chef looks at the mouse cursor (or where the right stick points) while its hands are free, so
punches go that way; without aim it faces where it walks. Clicks on menu buttons never reach the game.
The yellow ring shows the food you would grab, the blue ring the station you would work, and the
bottom line says what a click / E / F will do.

## How a shift works

- Orders appear at the top: dish, ingredients (coloured shapes plus text) and a patience bar.
  An expired order costs coins. At most 4 are open.
- Dispensers (back row): stand next to one and hold F to get its food.
- Griddle: drop raw patties / sausages on it. About 8 s to cooked (green bar), then about 10 s to burnt
  (the bar turns red). Drag them off in time.
- Cutting board: drop a tomato on it and hold F next to the board. More chefs chop faster. You get 3 slices.
- Plate: drop finished food on it and it stacks up (any order). Raw, burnt or whole food bounces off.
- Bell (next to the plate): press F to serve. A plate that matches an open order pays its price plus a
  bonus for time left. A wrong plate is cleared with a small penalty.
- Trash drain: drag food onto it to delete it. Fall off the counter and you respawn after 2 s.
- Carrying: grab food with E. Heavy food (patty, sausage: weight 3; buns, tomato: weight 2) is slow alone.
  Several chefs can hold the same item; it moves in the AVERAGE direction of their inputs, so pulling in
  opposite directions gets you nowhere.
- Shift end: results (served, failed, coins vs target), then the shop, then the host starts the next
  shift. Missed target: the same shift is retried.

Recipes: Cheeseburger (bun bottom, cooked patty, cheese, bun top), Garden Salad (2 lettuce, 2 tomato
slices), Double Beef Cheeseburger (shift 2+), Hot Dog (shift 3+). After shift 3 shifts keep getting harder.

Shop (shared team wallet, lasts for the run): Boxing Gloves (punch food across the counter, shove
friends, knock food out of hands), Sharp Knife (2x chopping), Running Shoes (+20% speed), Second Plate
(opens the closed second plate + bell on kitchens that have one; the Diner does), Oven Mitts (food takes
50% longer to burn), Hot Griddle (griddle and fryer cook 30% faster), Long Tongs (grab from 50% further).

## What is in this prototype, and what is not

In: everything above, LAN co-op 1 to 4 players, bots, procedural sound blips.
Not yet: real art (coloured placeholder shapes are used until the .glb models are merged: they swap in
automatically), a second plate, music, settings, client-side prediction (fine on a LAN, laggy over the internet).

## Automation (for agents)

User args after `--`: `--host`, `--join=<ip>`, `--name=<x>`, `--autostart` (host starts once `--players=<n>`
have joined, default 1, and auto-advances results/shop), `--bot`, `--bot-log`, `--bind=<ip>`,
`--shift-seconds=<s>`, `--upgrades=gloves,knife,shoes`, `--test-report=<json>`, `--quit-after=<s>`,
`--quit-after-shift`. Screenshots: `--shot=<seconds>@<png>`. Keys: `--key=<start>@<key>@<hold seconds>`.
Mouse: `--mouse=<start>@<x>,<y>` (window pixels), `--click=<start>@<left|right|middle>@<hold seconds>`
(at the last `--mouse` spot). `--input-log` prints counted presses and every chef's aim/facing (host).
Test: `tools\test-multiplayer.ps1` (host + client bots) and `tools\test-multiplayer.ps1 -Solo`.
