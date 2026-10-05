# Tiny Chefs: plan

Last updated: 2026-10-05. Read `STATUS.md` first. This file says how the work is run and what is next.

## Next up
**Nothing is in progress.** The last task (lobby map picker pictures) is merged and released as v0.4.1.
Sander has new ideas and will bring them to the next session. Start by listening: do not pick work from
the backlog below without him asking for it.

When he gives the ideas:
1. Restate them back in a few lines and confirm scope before launching anything, especially if he calls
   something small.
2. Write the round's contract in `docs/design/<round>.md` (data shapes, names, sizes, who owns which file),
   the way `overnight-1.md`, `polish-2.md` and `cosmetics.md` did.
3. Split into one agent per system or model family and launch the independent ones together.
4. Replace this section with the round's task list, and tick items off as branches merge.

## How a round is run
The main session orchestrates: decides, writes contracts and briefs, reviews, merges, talks to Sander.
Subagents write all code and all Blender scripts.

- **One agent per small task.** Each system (`game/scripts/world/systems/*.gd`), each station, each screen,
  each model family gets its own agent. Never one builder for the whole thing.
- **Models:** Opus for game code and reviews, Sonnet for visuals (Blender models, VFX, scenery, pictures)
  and docs.
- **Isolation:** each agent works in its own git worktree and branch next to the repo
  (`C:\Users\Sander\games\tc<N>-<task>`), and hosts test games on its own port (79xx to 81xx) so parallel
  agents never collide. Remove the worktree after merging, but only after any screenshots Sander should see
  have been copied out or sent.
- **Every brief says:** read `CLAUDE.md` first; the goal; the contract doc; which files it owns and which
  it must not touch (always: movement and carry feel, UI style); how to verify; the exact report shape.
- **Verification an agent must do before reporting:** `tools\godot-check.ps1`; for gameplay,
  `tools\test-multiplayer.ps1 -Port <own port>`; for anything visual, take screenshots and actually look at
  them. Balance changes go through `tools\balance.ps1`.
- **Merge:** into `main` one branch at a time. Simple conflicts (both sides added lines) are resolved by
  keeping both; conflicts in logic go to an Opus merge agent. Never stash or reset a tree an agent is
  still working in.
- **After the last merge:** import, check, multiplayer test, then an Opus reviewer over the round's diff,
  one fix round, `tools\export-windows.ps1`, push, `gh release create`, update `STATUS.md` and this file.
- **Stalls:** agents can freeze silently. If an agent has produced no file activity for an hour, stop it
  and launch a finisher on its uncommitted work instead of waiting.
- **Disk:** C: has filled up once. Worktrees and exports are large; clean up merged worktrees promptly.
- **Tell Sander** when long work finishes (phone notification; the topic is in the session memory, not in
  this public repo).

## Backlog: candidates, not commitments
Nothing here is approved. It is a list to choose from once his ideas are in.

Most valuable first step, and it needs no agents:
- **A human playtest** with 2 to 4 friends on the LAN. Everything below is guesswork until this happens.
  Things to watch: can friends join on school laptops (firewall, UDP 7777), is the first mission
  understandable, which upgrades feel worth buying, frame rate on the weakest laptop.

From the caveats in `STATUS.md`:
- Rebalance Food Truck and Twin Islands after real play.
- Gamepad pass.
- Arm reach limits so arms do not stretch.
- Lighter `dispenser_patties` model.
- Map picker: fit all four cards at 720p; retake the weak pictures.
- Delete the merged local branches.

Ideas raised earlier and never built:
- More maps and more dishes beyond the current four and fifteen.
- Drawn art for the maps was tried once (Twin Islands) and renders were preferred.
