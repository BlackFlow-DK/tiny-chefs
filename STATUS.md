# Tiny Chefs: status

Last updated: 2026-10-05, at the end of the session that built v0.1 to v0.4.1.
A new session reads this file and `PLAN.md` first, then `CLAUDE.md` (tools and conventions).
Keep this file to *what is true now*; history lives in git and the release notes.

## What this is
LAN co-op kitchen chaos for 2 to 4 players on separate PCs (some laptops). 1 m chefs on a giant counter
carry oversized ingredients together, cook, stack plates, serve orders, earn coins, buy upgrades.
Sander designs by talking and playtests. He does no coding or modelling and pays for nothing beyond his
Claude subscription, so everything is built with free tools by subagents.

## Where things are
- Repo: `C:\Users\Sander\games\godot-game`, branch `main`, clean and in sync with
  `origin` = https://github.com/BlackFlow-DK/tiny-chefs (public for now; Sander may make it private later).
- Latest release: **v0.4.1** (GitHub release with the exe attached). Local build:
  `build\windows\TinyChefs.exe` (about 127 MB, gitignored).
- Godot project in `game/`, Blender scripts in `art/scripts/`, wrappers in `tools/`.
- Godot 4.7.2 and Blender 5.2.1, CLI only. Other sessions on this PC use other versions for other games:
  check the paths in `CLAUDE.md` still resolve before starting work.

## What is in the game (v0.4.1)
- **Maps (4):** Diner, Food Truck (lurch hazard), Picnic (wind hazard), Twin Islands (plank bridge).
- **Food:** 15 dishes; griddle, fryer, chopping board, soda fountain, dispensers, plate + bell.
  Food physics, tidy/messy plate rule with a small penalty for wrong stacking order, take an item off a
  plate, scrape a plate into the bin.
- **Modes:** campaign missions with 1 to 3 stars, endless, custom shifts. Difficulty presets
  (easy/normal/hard/chaos), modifiers, events (VIP ticket, health inspector, cat paw).
- **Economy:** coins per shift; tiered upgrade tree (16 lines, 41 levels) in the shop; economy pass 2 done
  (`docs/balance.md`, `docs/upgrades.md`).
- **Chefs:** rig with arms and body shapes, procedural animation, Wardrobe with 65 cosmetics (hats, beards,
  face items, outfits, back items, body shapes) bought with persistent tokens (`docs/design/cosmetics.md`).
- **UI:** main menu, lobby with settings and the new 2 x 2 map picker (four render pictures per map,
  crossfading every 10 s), HUD with thumbnail order tickets, shop, wardrobe, results/stats, settings.
  Style guide: `docs/ui-style.md`.
- **Multiplayer:** host-authoritative ENet on UDP 7777; bots (`--bot`) for testing.
- **Performance:** quality presets auto/low/medium/high for laptops (`docs/performance.md`).
- Player-facing guide: `docs/PLAYING.md`. System map and file ownership: `docs/systems.md`.

## Verified, and not
- Verified by agents: `godot-check`, the bot-driven `tools\test-multiplayer.ps1`, the balance harness,
  screenshots read by the agent that made the change. All passed on the v0.4.1 build.
- **Not verified: any human play.** Nobody has played a full shift with friends yet. Feel, fun, difficulty
  and LAN joining on school laptops are all untested by people.

## Known caveats (none are being worked on)
- Food Truck and Twin Islands balance targets are estimates from bot runs.
- Bots show no measurable gain from the cheap speed upgrades, so those prices are judgement calls.
- Gamepad is untested.
- Arms stretch on long reaches; a few VFX were only checked in a demo scene.
- `dispenser_patties` model is heavy (31k faces).
- Map picker: at 1280 x 720 only the top row of the 2 x 2 grid fits without scrolling. Two Diner pictures
  look alike; one Food Truck picture has very small chefs; one Picnic picture shows no chefs.
- 33 old local branches from merged agent work are still around; safe to delete, nobody has asked.

## Sander's taste, learned so far
- The UI style is liked as it is. UI quality is a main focus: keep it, extend it, do not restyle it.
- Movement and carry feel is good. **Do not change it.**
- He wants lots of polish, animation, customisation and a long upgrade progression.
- Renders of the real game beat drawn art for map pictures.
- "A small change" means small: confirm which thing he means, show one sample in chat, then roll out.
