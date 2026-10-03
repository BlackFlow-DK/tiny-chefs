# Tiny Chefs: how to play

Tiny Chefs is a co-op kitchen game for 1 to 4 players on a local network. You are a tiny chef on a giant
kitchen counter, and the food is bigger than you are. Heavy food is slow to carry alone, so you carry it together. Cook, stack, ring the bell, and keep the orders from expiring.

## Download

1. Open the **Releases** page of the repo (https://github.com/BlackFlow-DK/tiny-chefs/releases) and download the exe.
   It is a single file, no installer.
2. Windows may warn that the app is unrecognised. Click **More info**, then **Run anyway**.

## Host and join on a LAN

- One player picks **Host a kitchen**. The lobby shows the host's LAN IP address (the likeliest one,
  usually 192.168.x.x, is listed first; 172.x addresses are often virtual adapters).
- Everyone else types that IP on the title screen and clicks **Join**.
- Game traffic uses **UDP port 7777** on the host. The first time you host, Windows Firewall asks if the
  game may talk to the network: allow it on **private** networks.
- If a school or work network blocks it, share a phone hotspot or use Tailscale and join with the host's
  Tailscale IP.
- Up to 4 chefs. You can join or leave mid-shift (a leaving chef drops what it carried). If the host
  leaves, everyone returns to the title screen. Solo is just hosting alone.

## Controls

| action | keyboard / mouse | gamepad |
|---|---|---|
| move | WASD or arrows | left stick |
| aim | mouse cursor | right stick |
| grab / let go | left click or E | A |
| work (hold) | right click or F | X |
| punch (needs Boxing Gloves) | Space or Q | B |
| ping a spot (everyone sees it for 3 s) | middle click | Y |
| pause menu | Esc | Start |
| hide the controls help | H | Back |

Your chef faces the mouse cursor while its hands are free. The yellow ring shows the food you would grab,
the blue ring the station you would work, and the bottom line says what a click will do.

## How a shift works

Orders appear at the top: the dish, its ingredients and a patience bar. An order that runs out of patience
costs coins. Build the dish on a **plate**, then press work at the **bell** next to it. A correct plate pays
its price plus a bonus for patience left; a wrong plate is cleared with a small penalty. When the clock runs
out you see the results, then the shop (unless the host turned it off), then the next shift. Miss the coin
target and you retry the shift.

## Stations

- **Dispensers**: stand next to one and hold work to get raw food (patties, buns, cheese, lettuce, tomatoes,
  sausages, hot dog buns, bacon, eggs, onions, pickles, potatoes, chicken).
- **Griddle**: drop patties, sausages, bacon or eggs on it. They cook (green bar), then burn (red bar)
  if you leave them. Pull them off in time.
- **Fryer**: chicken, cut potatoes and onion slices go in. Same cook-then-burn rhythm.
- **Cutting board**: drop a tomato, onion or potato and hold work. More chefs chop faster.
- **Soda fountain**: hold work to fill a cup.
- **Plate**: drop finished food on it. Raw, burnt or uncut food bounces off. Stack it tidily: the bun (or the
  dish's first item) first and the bun top last; a messy dish still counts but pays 15% less, and a yellow
  "Wrong order" sign warns you early. Aim at the plate and grab to take the top item back off; hold work on
  it (away from the bell) to scrape the whole plate into the bin.
- **Bell**: work it to serve the nearest plate.
- **Trash drain**: drag food onto it to throw it away.
- Fall off the counter and you respawn after a couple of seconds.

## The dishes

| dish | what goes on the plate |
|---|---|
| Cheeseburger | bun bottom, cooked patty, cheese, bun top |
| Double Beef Cheeseburger | bun bottom, 2 cooked patties, 2 cheese, bun top |
| Bacon Cheeseburger | bun bottom, cooked patty, cheese, cooked bacon, bun top |
| Breakfast Burger | bun bottom, cooked patty, fried egg, cooked bacon, bun top |
| Crispy Chicken Burger | bun bottom, crispy chicken, lettuce, bun top |
| Pickle Burger | bun bottom, cooked patty, cheese, 2 pickles, bun top |
| The Works | bun bottom, 2 cooked patties, cheese, cooked bacon, onion slice, tomato slice, lettuce, bun top |
| Garden Salad | 2 lettuce, 2 tomato slices |
| Chicken Salad | 2 lettuce, crispy chicken, tomato slice |
| Hot Dog | hot dog bun, cooked sausage |
| Loaded Hot Dog | hot dog bun, cooked sausage, onion slice |
| Fries | fries (potato: chop, then fryer) |
| Onion Rings | onion rings (onion: chop into slices, then fryer) |
| Burger Meal | cheeseburger plus fries plus soda |
| Hot Dog Meal | hot dog plus fries plus soda |

## Carrying together

Every item has a weight (cheese, lettuce and slices 1; buns and whole tomatoes 2; patties, sausages and
chicken 3). Alone you carry heavy food slowly; more chefs holding the same item make it faster. A shared item
moves in the average of everyone's direction, so pulling opposite ways gets you nowhere. Boxing Gloves let you
punch food across the counter or shove friends.

## Game modes

The host chooses in the lobby.

- **Campaign**: 12 missions on the diner, picnic and islands (and the food truck, see below). Each mission
  has a coin target and up to two bonus goals (no burnt food, no expired orders, serve N of a dish, earn N
  coins). Reach the target for 1 star, each bonus goal adds one. Progress is saved on your PC.
- **Endless**: shifts keep getting harder, on the map, difficulty and modifiers the host picks.
- **Custom**: the host sets shift length, dishes offered, target, order speed and patience, and which events
  can happen.

Host settings: **map**; **difficulty** (Easy, Normal, Hard, Chaos: they change order speed, patience, targets
and how fast food burns); **modifiers** (Rush Hour, Heavy Hands, Slippery Floor, Mystery Orders, No Shop,
Lights Out); **events** (below).

## Maps and hazards

- **The Diner**: the classic kitchen island, everything within a few steps. Hazard: the cat paw.
- **The Picnic**: a picnic table in the park. Hazards: gusts of wind that blow loose light food away
  (carried food is safe), and the cat paw.
- **Twin Islands**: two islands joined by one narrow plank over the sink. Haul raw food across and cook on the
  far side. Falling into the gap is the usual fall.
- **The Food Truck**: coming soon. Campaign missions 4 to 6 are set there.

## Upgrades

Bought in the shop between shifts with the team's shared coins, and they last for the run.

- Boxing Gloves (60): punch food and friends.
- Sharp Knife (50): chopping twice as fast.
- Running Shoes (80): +20% move and carry speed.
- Second Plate (90): opens a second plate and bell on kitchens that have one.
- Oven Mitts (70): food takes 50% longer to burn.
- Hot Griddle (90): griddle and fryer cook 30% faster.
- Long Tongs (60): grab food from 50% further away.

## Events

- **VIP**: a gold ticket worth triple, but with less patience.
- **Health inspector**: a warning banner, then every burnt item left on the counter costs coins.
- **Cat paw**: a giant paw sweeps across a lane and knocks loose food aside. It is telegraphed first.

## Customise your chef

In the lobby pick a colour, a hat (Toque, Beanie, Paper hat, Bandana) and an accessory (None, Glasses,
Moustache).

## Stats

The results screen shows served, failed and coins, plus MVP cards: Top server (rang the bell), Pack mule
(carried the most), Team player (carried together) and Butterfingers (dropped the most).

## Tips for a first playtest

- Start with the Campaign: mission 1 Training is slow and forgiving.
- Split jobs: one on the griddle, one on the plate and bell, the rest fetching.
- Aim with the mouse before you grab. Ping with middle click to say "this one".
- Put patties on the griddle first, they take longest.
- Do not leave food on the griddle while you talk. The inspector is watching.
- Try the two-window test alone: start the exe twice, host in one, join `127.0.0.1` in the other.
  Only the focused window reads your input.
