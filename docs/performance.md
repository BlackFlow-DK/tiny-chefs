# Performance: quality presets for laptops

Tiny Chefs was tuned on an RTX 3060 Ti (soft 4-cascade shadows, SSAO, SSIL, glow, depth haze, far depth of field,
4x MSAA). Friends play on school laptops with built-in graphics, so the game now has graphics presets (Low / Medium /
High / Auto), a Settings card, an FPS counter and an optional Mobile-renderer relaunch.

Code: `game/scripts/data/quality.gd` (`Quality`: presets, settings in `user://settings.cfg`, the Auto rule, relaunch),
`game/scripts/world/env/quality_apply.gd` (`QualityApply`: the one place a preset reaches the renderer, plus the Auto
probe), `game/scripts/ui/settings_view.gd`, `game/scripts/ui/fps_counter.gd`. Measuring: `game/scripts/dev/bench.gd`
(`--bench`), `game/scripts/dev/prof.gd` (`--profile`), `tools/bench.ps1`, `tools/profile.ps1`, `tools/perf-shots.ps1`.

## The presets

High is exactly the look from before (verified: a fixed-fps screenshot of diner and picnic is pixel-identical to the
pre-preset build). Each map's env builder still sets its own look; `QualityApply.scene()` only switches things off or
down, and remembers every original value in node meta so going back to High restores it.

| | Low | Medium | High (today) |
|---|---|---|---|
| SSAO | off | on, quality Low | on (project quality) |
| SSIL | off | off | on |
| Glow | off | on | on |
| Far depth of field | off | off | on |
| Depth haze (fog) | on (cheap) | on | on |
| Sun shadow | 1 cascade (orthogonal), 1024 atlas, hard PCF, max 50 m | 2 cascades, 2048 atlas, soft | 4 cascades, 4096 atlas, soft |
| Render scale | 75 %, FSR1 upscale (bilinear on Mobile) | 100 % | 100 % |
| Anti-aliasing | FXAA, no MSAA | MSAA 2x | MSAA 4x |
| Mesh LOD threshold | 2.0 (coarser auto-LODs) | 1.0 | 1.0 |
| Particles (sizzle, fryer bubbles) | half | full | full |
| Picnic grass blades | 35 % | 70 % | 100 % |
| Picnic bee / ants / leaves | 30 Hz, no drifting leaves | full | full |
| Menu/lobby backdrop | 50 % scale (FSR1 + FXAA), 30 fps, no blur | full, shallow focus | full, shallow focus |

Why Low keeps a sun shadow: a shadowless Low with a blob decal under each chef was built and measured first. It saved
only ~0.4 ms GPU under stress, and stations and food looked like they float above the counter. One hard 1024
cascade keeps chefs, stations and food grounded. Two cascades at 1024 showed shadow acne, so Low uses one.

Auto: `Quality.detect_for(adapter name, device type, OS name, CPU arch)`:
- macOS on arm64 (Apple Silicon; Metal reports every Apple GPU as integrated) -> **Medium**;
- integrated or CPU device type, a software rasteriser (llvmpipe, SwiftShader, Microsoft Basic Render), any Intel
  GPU except Arc, an AMD APU ("Radeon(TM) Graphics", "Vega N" without an RX/R9/Pro model) -> **Low**;
- a laptop discrete GPU by name ("Laptop", "Max-Q", "Mobile", "MX450", "RX 6600M") -> **Medium**;
- anything else -> **High**.

Then, on the first launch on that GPU, a probe skips 90 frames (startup pipeline compiles), averages the frame rate
over 2 s on the title screen at the detected preset, and steps down one level if it is under 50 fps. The verdict
and adapter name are saved (`auto_level`, `auto_adapter`), so it runs again only on a new GPU. Agent, bot and bench
runs never probe, relaunch or write the settings file.

Settings card (title screen "Settings", pause menu "Settings"): preset with a one-line description (Auto says what
it picked and for which GPU), resolution slider 50 to 100 % (a new preset resets it to the preset's own), frame
cap 60/120/uncapped, fullscreen, vsync, show FPS (a small chip top-right), and the lightweight renderer. Everything
applies live (`QualityApply.apply_all`) except the renderer, which needs a restart ("Restart now" on the title screen).

Args: `--quality=auto|low|medium|high` (this run only, not saved), `--render-scale=0.5..1`, `--show-fps`,
`--quality-set=key:value,...` (A/B a single preset entry, e.g. `shadow_splits:0`), `--env-off=ssao,ssil,glow,fog,dof`.

## Benchmark

`tools\bench.ps1` runs a solo bot shift (host, endless mode, `--bot`) per preset x map in a 1920x1080 borderless
window with vsync and the frame cap off. After the shift starts plus 4 s of warm-up it records 20 s of frames and
prints one JSON line (`bench: {...}`): wall-clock frame time (avg and 1% low = mean of the slowest 1 %), GPU time
of the main viewport (`viewport_get_measured_render_time_gpu`), CPU render time, draw calls. **Stress** (`--bench-stress`)
doubles the 3D render scale (High 2.0 = 3840x2160 internal, Low 0.75 x 2 = 1.5) to amplify fill-rate cost and
stand in for a weak GPU. Machine: RTX 3060 Ti, Ryzen 5 3600. Other sessions' Godot processes were running on the same
box, so expect a few % noise (the "before" picnic normal run was CPU-starved by them).

### Before (today's look, the High preset before this change)

| map | stress | fps | avg ms | 1% low ms | GPU ms | GPU 1% low ms | CPU render ms |
|---|---|---|---|---|---|---|---|
| diner | - | 203.0 | 4.93 | 8.30 | 4.24 | 6.31 | 1.69 |
| diner | x2 | 56.2 | 17.79 | 26.85 | **17.26** | 23.99 | 2.05 |
| picnic | - | 148.7 | 6.72 | 13.58 | 3.93 | 5.34 | 2.21 |
| picnic | x2 | 63.0 | 15.88 | 29.53 | **15.35** | 26.90 | 1.79 |

### After, Forward+ (default renderer)

| map | preset | stress | scale | fps | avg ms | 1% low ms | GPU ms | GPU 1% low ms | CPU render ms |
|---|---|---|---|---|---|---|---|---|---|
| diner | low | - | 0.75 | 409.5 | 2.44 | 4.69 | 0.98 | 1.57 | 0.80 |
| diner | low | x2 | 1.5 | 313.0 | 3.20 | 5.72 | **2.71** | 4.38 | 0.82 |
| diner | medium | - | 1.0 | 269.1 | 3.72 | 8.74 | 2.99 | 6.50 | 1.08 |
| diner | medium | x2 | 2.0 | 108.7 | 9.20 | 12.91 | 8.75 | 10.00 | 1.16 |
| diner | high | - | 1.0 | 207.0 | 4.83 | 7.81 | 4.33 | 6.01 | 1.39 |
| diner | high | x2 | 2.0 | 62.8 | 15.91 | 19.88 | **15.46** | 16.30 | 1.49 |
| picnic | low | - | 0.75 | 472.3 | 2.12 | 4.61 | 0.90 | 1.31 | 0.64 |
| picnic | low | x2 | 1.5 | 347.8 | 2.88 | 5.04 | **2.34** | 2.84 | 0.72 |
| picnic | medium | - | 1.0 | 329.7 | 3.03 | 5.12 | 2.47 | 2.93 | 0.86 |
| picnic | medium | x2 | 2.0 | 120.8 | 8.27 | 11.10 | 7.82 | 8.50 | 1.01 |
| picnic | high | - | 1.0 | 216.7 | 4.62 | 6.62 | 4.15 | 4.69 | 1.10 |
| picnic | high | x2 | 2.0 | 68.9 | 14.52 | 18.14 | **14.07** | 15.39 | 1.23 |

GPU time under stress, Low vs High: diner 2.71 vs 15.46 ms (**5.7x cheaper**), picnic 2.34 vs 14.07 ms (**6.0x**).
Against the pre-change numbers: 6.4x (diner) and 6.6x (picnic). Medium is about 1.8x cheaper than High under stress.
Draw calls also drop: diner 774 (High) to 439 (Low), picnic 595 to 359 (shadow cascades are separate passes).

### After, Mobile renderer (`--rendering-method mobile`, the "Lightweight renderer" toggle)

| map | preset | stress | fps | avg ms | 1% low ms | GPU ms | CPU render ms |
|---|---|---|---|---|---|---|---|
| diner | low | - | 463.9 | 2.16 | 4.25 | 0.81 | 0.66 |
| diner | low | x2 | 293.8 | 3.40 | 5.42 | 2.96 | 0.69 |
| diner | medium | x2 | 144.0 | 6.95 | 10.22 | 6.48 | 0.90 |
| diner | high | - | 329.4 | 3.04 | 4.96 | 2.54 | 0.96 |
| diner | high | x2 | 111.2 | 8.99 | 12.48 | 8.55 | 1.01 |
| picnic | low | - | 523.9 | 1.91 | 3.90 | 0.83 | 0.54 |
| picnic | low | x2 | 292.0 | 3.42 | 5.53 | 2.97 | 0.59 |
| picnic | high | x2 | 113.7 | 8.80 | 11.98 | 8.35 | 0.95 |

Mobile has no SSAO, SSIL or FSR1. The env builders leave SSAO/SSIL off there (`EnvLook._debug_off`) and render
scaling falls back to bilinear, so it runs without warnings. Glow, fog, shadows and DOF work. High on Mobile costs
about half of High on Forward+ (it lacks the two most expensive effects). Low on Mobile has slightly lower frame
time and CPU render time than Low on Forward+, but about the same or slightly more GPU time (2.96 vs 2.71 ms under
stress). On this desktop GPU it is **not clearly better**, so Auto-Low does not switch renderer by itself. It stays a
player toggle, and is the next thing to try on a laptop where Low still stutters. A relaunch passes the user args
through and adds `--relaunched` (no relaunch loops). Editor-binary runs get `--path` back; an exported exe needs nothing.

### What each effect costs (diner, High, stress, GPU ms; `--env-off`)

| off | GPU ms | saved |
|---|---|---|
| nothing (High) | 17.26 | - |
| SSIL | 12.69 | 4.6 |
| depth of field | 14.45 | 2.8 |
| glow | 15.11 | 2.2 |
| SSAO | 15.23 | 2.0 |
| all four | 7.71 | 9.6 |

Low sun-shadow options (diner, Low, GPU ms normal / stress): no sun shadow 0.87 / 2.29, 1 hard cascade at 1024
0.98 / 2.70 (chosen), the same with soft PCF 1.04 / 2.86.

## CPU

`tools\profile.ps1` runs a windowed host capped at 60 fps (like a vsync'd laptop) plus 3 headless client bots, 4 chefs,
for 60 s. `--profile` times sections with `Time.get_ticks_usec` (`Prof.t0()` / `Prof.add()`, one static bool check
when off) and prints ms per rendered frame, slowest first.

4-bot host, diner, High, ms per frame (60 s): indicators 0.31 to 0.35, HUD 0.22 to 0.25, stations tick 0.18,
chefs tick 0.17, input + bot 0.14 to 0.16, world presentation (hints, modifiers, events) 0.10, snapshot send 0.09 +
build 0.04, carry 0.09, chef `_process` x4 0.07, events/mods/shift 0.06, camera 0.03. All `_process` scripts 0.88 ms,
all `_physics_process` scripts 0.81 ms: **about 1.7 ms of script per frame in total**. Picnic: 0.95 + 0.67 ms.
No section is anywhere near the 2 ms-per-frame threshold, so no per-frame code was changed.

One real hitch: the picnic's **first wind gust** built 54 leaf models, 18 streak quads with a runtime-compiled
shader, and a full UI `Theme` on the spot, a single **84 ms** frame (`tick.events+mods+shift` max). `WindHazard` now
builds these hidden at setup (map load). Same 60 s picnic run afterwards: max 1.0 ms. Behaviour is unchanged.

Remaining spikes are bot-only (`tick.input+bot` max ~25 to 33 ms: planner replans; players have no bot) and
occasional 5 to 10 ms maxima in stations/chefs that also show in otherwise idle sections, which points at OS
preemption from the other processes on this machine.

(Godot's `Performance.TIME_PROCESS` includes the wait for the render thread, so it reads 4 to 6 ms even when
scripts take 1 ms. The reports leave it out.)

## How to test on a laptop

1. Export: `tools\export-windows.ps1` -> `build\windows\godot-game.exe`. Copy it to the laptop.
2. Start it normally. On the first start Auto picks a preset and probes 2 s at the title screen. Open **Settings**:
   the description line says what Auto picked and for which GPU. Turn on **Show FPS**.
3. Host a kitchen, play a shift on the diner and on the picnic. Aim for a steady 60 with vsync on. If it dips, try Low,
   then the resolution slider (60 to 70 %), then **Lightweight renderer** -> **Restart now**.
4. Numbers: run the exe from a terminal with
   `godot-game.exe --resolution 1920x1080 -- --host --bot --autostart --mode=endless --map=diner --port=7971 --bench=low --quality=low`
   (add `--bench-stress` for the stress variant, `--rendering-method mobile` before `--` for Mobile). The game quits
   after ~30 s. The `bench: {...}` line is in `%APPDATA%\Godot\app_userdata\Tiny Chefs\logs\godot.log` (a release exe
   has no console).
5. Settings live in `%APPDATA%\Godot\app_userdata\Tiny Chefs\settings.cfg` (`[graphics]`). Delete it to re-run Auto.

Screenshots of every preset: `tools\perf-shots.ps1 [-Extra "--rendering-method mobile" -Suffix -mobile]` ->
`build\screenshots\perf\<map>-<preset>.png`.
