# Balance pass 1 (bot harness)

Numbers from `tools\balance.ps1` (headless bot teams), October 2026. Raw tables: `build\balance\before-all.md`,
`build\balance\after-all.md` (and one folder per run). Movement, carry speeds, weights and camera were not touched.

## Method

- Every run is a real shift played by bots (`--bot`), one host + (n-1) clients, `-ShiftSeconds 150`. Coins are
  scaled linearly to the real shift length (endless 210 s, campaign: the mission's duration); this slightly
  undercounts (the first ~20 s earn nothing), so real ratios are a little higher than shown.
- **ratio** = scaled coins / target. The goal (design doc section 11): a bot team meets the target at 70 to 80 %
  of its throughput on normal, i.e. ratio 1.25 to 1.43 for shifts 1 and 2; shift 0 at 60 to 70 % (ratio 1.43 to
  1.67). Humans are faster than bots, so bots passing with that margin leaves room.
- Bots are throughput-limited, not order-limited: when no order is open the next one comes within 4 s.
- Single runs are noisy (about +-15 %): the one VIP per shift pays 3x a random recipe (a VIP Double is worth
  ~290 coins, a VIP Salad ~140). Rows that drive a decision were run 2 to 4 times.
- `balance.ps1` gained `-HostExtra '<host args>'` and `-Tag <name>` for campaign (`--mode=campaign
  --mission=n`) and `--recipes=` runs. Runs were made from a clean worktree of `main` so in-progress UI edits
  could not break the build mid-run.

## Before / after (key rows)

Before = the data as it was (VIP 3x every ~70 s). After = final values unless marked. 150 s runs, coins scaled.

| row | before served / coins / target / ratio | after served / coins / target / ratio |
|---|---|---|
| diner 1p shift 0 | 4 / 280 / 80 / 3.50 | 4 / 294 / 190 / 1.55 |
| diner 1p shift 1 | 3 / 424 / 120 / 3.53 | 4 / 319 / 300 / 1.06 ; 3 / 571 / 300 / 1.90 (mean 1.48) |
| diner 1p shift 2 | 4 / 381 / 160 / 2.38 | 4 / 559 / 310 / 1.80 |
| diner 2p shift 0 | 6 / 451 / 120 / 3.76 ; 7 / 505 / 120 / 4.21 | 7 / 546 / 333 / 1.64 |
| diner 2p shift 1 | 5 / 714 / 180 / 3.97 | 6 / 703 / 525 / 1.34 ; 6 / 704 / 525 / 1.34 |
| diner 3p shift 0 | 7 / 491 / 160 / 3.07 | 7 / 466 / 361* / 1.29 |
| diner 3p shift 1 | 8 / 1054 / 240 / 4.39 | 6 / 738 / 570* / 1.29 ; 7 / 715 / 570 / 1.25 |
| diner 3p shift 2 | 5 / 865 / 320 / 2.70 | 6 / 916 / 589* / 1.56 |
| diner 4p shift 0 / 1 / 2 | 2.11 / 2.48 / 1.62 | 1.52 / 1.31 / 1.10 |
| picnic 2p shift 0 | 5 / 353 / 120 / 2.94 | 5 / 403 / 266 / 1.52 |
| picnic 2p shift 1 | 4 / 563 / 180 / 3.13 | 4 / 643 / 420 / 1.53 ; 5 / 515 / 420 / 1.23 |
| twin_islands 2p shift 1 | 1 / 56 / 180 / 0.31 | 2 / 134 / 341 / 0.39 (bots stall, see below) |
| endless 2p shift 3 | 6 / 626 / 315 / 1.99 | 6 / 739 / 564 / 1.31 |
| endless 2p shift 4 | - | 6 / 644 / 586 / 1.10 |
| endless 2p shift 5 | 6 / 542 / 465 / 1.17 | 5 / 533 / 607 / 0.88 ; 6 / 729 / 607 / 1.20 (mean 1.04) |
| endless 2p shift 6 | - | 6 / 449 / 630 / 0.71 |
| endless 2p shift 8 | 6 / 455 / 690 / 0.66 | 6 / 531 / 672 / 0.79 ; 5 / 283 / 672 / 0.42 |
| easy 2p shift 1 | 5 / 788 / 180 / 4.38 | 5 / 711 / 368 / 1.93 |
| normal 2p shift 1 | 6 / 687 / 180 / 3.82 | 6 / 704 / 525 / 1.34 |
| hard 2p shift 1 | 6 / 633 / 234 / 2.70 | 6 / 725 / 761 / 0.95 (4 runs at x1.3 recomputed for x1.45: 0.90 / 0.97 / 0.91 / 1.07) |
| chaos 2p shift 1 | 5 / 403 / 288 / 1.40 | 6 / 613 / 840 / 0.73 (4 runs at x1.4 recomputed for x1.6: 0.90 / 0.58 / 0.78 / 0.55) |
| campaign m0 (2p) | 6 / 418 / 42 / 9.94 | 6 / 454 / 123 / 3.69 |
| campaign m4 (2p) | 4 / 402 / 255 / 1.58 | 5 / 410 / 289 / 1.42 |
| campaign m8 (2p) | 3 / 198 / 429 / 0.46 | 3 / 234 / 228 / 1.02 (target unchanged by the later hard x1.45 rebase) |
| campaign m11 (2p) | 0 / -99 / 672 / -0.15 | 0 / -126 / 331 / n/a (bots stall on twin_islands) |

\* 3p rows marked were run with the 3-player factor 2.0; the target shown is the final one (factor 1.9), the
coins are the same (a target change does not change what bots do).

Campaign before, all missions (2p, one run each): m0 9.94, m1 5.72, m2 2.09, m3 2.00, m4 1.58, m5 1.60, m6 1.80,
m7 0.77, m8 0.46, m9 0.36, m10 -0.11, m11 -0.15. Missions 3 to 5 name `food_truck`, which is not in the game
yet: they ran on the diner fallback.

## What changed and why

**Targets were 2.4x to 4x too low**: a lone bot cleared shift 0 at 3.5x the target. Endless shift targets now
sit at the goal band.

| value | old | new | why |
|---|---|---|---|
| `SHIFTS` targets (1p) | 80 / 120 / 160 | 190 / 300 / 310 | 1p bot ~295 / ~420 / ~400 coins at 210 s (shift 1+ includes about one VIP) |
| `Tuning.SCALE_TARGET_PER_PLAYER` 0.5 (linear) | 1 / 1.5 / 2 / 2.5 | `SCALE_TARGET_BY_PLAYERS` 1 / 1.75 / 1.9 / 2.05 | bot teams earn ~1.75x / ~1.9x / ~1.8x one bot (one plate is the bottleneck); a linear factor cannot fit that. `Tuning.target_players_scale(n)` is used by ShiftPlan and the campaign "earn" objective |
| `Tuning.EXPIRE_PENALTY` | 10 | 15 | about a quarter of an average order; 2 to 4 expiries in chaos / Overtime cost 30 to 60, not the run |
| `Tuning.VIP_PERIOD` | 70 s | 100 s | one VIP per shift instead of two: at 3x pay two VIPs were up to 40 % of a shift's coins and swung the result more than play did. VIP pay stays 3x (the HUD says "triple pay") |
| `Tuning.INSPECTOR_FINE` | 25 | 25 (kept) | now ~13 % of a 1p target per burnt item (it was 31 %): meaningful, not run-ending |
| endless Overtime target | +50 per step | x(1 + 0.04 k) (`ShiftPlan.OVERTIME_TARGET_STEP`) | interval x0.88 and patience x0.94 per step already drown bots; a small target step puts "just barely" at shift 5 and a clear fail at 6 to 8 |
| `Difficulty` hard target | x1.3 | x1.45 | bots earn as much on hard as on normal (more orders, no fewer serves): x1.3 left them at 1.07 |
| `Difficulty` chaos target | x1.6 | x1.6 (kept; x1.4 was tried and bots reached 0.80) | chaos at 0.55 to 0.9, mean ~0.7: clearly failed |

Recipe prices (price / bonus): effort = carries weighted by item weight (solo carry time is proportional to
weight) + station work + cook waits, from `GameData.route`, blended 50/50 with measured bot seconds per order
(1 bot, diner, `--recipes=<one>`).

| recipe | bot s/order | effort (cheeseburger = 1) | old | new |
|---|---|---|---|---|
| Onion Rings | ~20 | 0.53 | 25/10 | 25/10 |
| Fries | 22 | 0.65 | 20/10 | 30/10 |
| Garden Salad | 29 | 0.79 | 35/15 | 35/15 |
| Hot Dog | 37 | 0.92 | 35/15 | 40/15 |
| Cheeseburger | 33 | 1.00 | 40/20 | 45/20 |
| Loaded Hot Dog | 46 | 1.15 | 45/20 | 50/20 |
| Chicken Salad | 50 | 1.25 | 55/20 | 55/20 |
| Bacon Cheeseburger | 44 | 1.33 | 55/25 | 60/25 |
| Crispy Chicken Burger | 58 | 1.37 | 50/20 | 60/25 |
| Breakfast Burger | 48 | 1.46 | 60/25 | 65/25 |
| Pickle Burger | 57 | 1.48 | 50/20 | 60/25 |
| Double Beef | 56 | 1.65 | 75/30 | 75/30 |
| Hot Dog Meal | 70 | 1.83 | 75/30 | 80/30 |
| Burger Meal | 68 | 1.94 | 85/35 | 90/35 |
| The Works | ~105 | 2.7 | 110/40 | 120/45 |

Chicken and pickle bot times are inflated by the diner layout (those dispensers sit at the far ends), hence
60 rather than the blend's 62 / 67. Burger Meal now pays 2x a Cheeseburger, The Works 2.7x.

Campaign mission targets (base, 1 player at normal; the preset and player factor apply on top): set from the
measured bot coins (or the recipe-time model where bots cannot play the map) so the 2p bot ratio ramps
3.7, 2.3, 1.75, 1.6, 1.5, 1.45, 1.4, 1.25, 1.15, ~1.05, ~1.0, ~0.9 from mission 0 to 11.

| mission | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| old target | 40 | 80 | 150 | 130 | 170 | 210 | 150 | 190 | 220 | 200 | 250 | 280 |
| new target | 100 | 180 | 160 | 155 | 165 | 210 | 165 | 110 | 90 | 110 | 110 | 120 |
| preset | easy | easy | normal | normal | normal | normal | normal | hard | hard | hard | hard | chaos |
| 1p target in game | 70 | 126 | 160 | 155 | 165 | 210 | 165 | 160 | 131 | 160 | 160 | 192 |

The late missions' base numbers drop because hard (x1.45) and chaos (x1.6) multiply them and their modifiers
(slippery, heavy hands, mystery orders, lights out, rush hour) are the difficulty: bots earned only 55 to 60 % of
the recipe-model throughput on picnic-hard. "earn" objectives: m5 250 -> 280, m10 300 -> 150 (300 at hard x
players was out of reach of any team; both now sit ~1.35x the mission target).

Upgrades (shared wallet, not scaled by players): 1p earns ~250 to 300 in a good shift 0, 2p ~500.

| upgrade | old | new |
|---|---|---|
| Boxing Gloves, Sharp Knife, Long Tongs | 60 / 50 / 60 | 200 each |
| Oven Mitts | 70 | 250 |
| Running Shoes, Second Plate, Hot Griddle | 80 / 90 / 90 | 300 each |

So a solo chef buys a cheap upgrade after a good first shift and a second one after shift 2; a pair buys one
premium upgrade after shift 0 and a second after shift 1.

## Per-map target scale

`MapDef.target_scale` (default 1.0), applied by `ShiftPlan` to **endless** targets only (a campaign mission's
target already prices in its map; custom shifts use the host's number).

| map | target_scale | evidence |
|---|---|---|
| diner | 1.0 | reference |
| picnic | 0.8 | bot coins 0.70 to 0.88 of the diner (1p, 2p, 3p, shifts 0 and 1); after: 2p ratio 1.52 / 1.53 / 1.23 |
| twin_islands | 0.65 | **estimate**: the bots stall here (see below), so this is the haul maths (every raw item crosses the plank, a solo patty moves at 2.3 m/s) |

## Not measured / known limits

- **Bots cannot play twin_islands**: 1 to 3 orders per 150 s at any team size, and 0 on missions 10 and 11
  (The Works first). After the first burger they stall (logs show no new plate work). Islands numbers (0.65
  scale, missions 9 to 11) are estimates; fix the bot's plank routing, then re-run
  `balance.ps1 -Maps twin_islands` and `-HostExtra '--mode=campaign --mission=9'` (10, 11).
- `food_truck` does not exist yet; missions 3 to 5 were measured on the diner. Re-measure when it lands.
- 4 bots crowd the single plate (they earn about what 2 bots earn); humans with the Second Plate should do
  better, so 4p targets may be easy for people. The bots never buy upgrades, so upgrade effects are unmeasured.
- Every row is 1 to 4 runs; treat single numbers as +-15 %.
- `tools\test-multiplayer.ps1 -Port 7942` and `-Solo -Port 7942` pass with these values (no shift-seconds change
  needed; the tests check serves, not targets).
