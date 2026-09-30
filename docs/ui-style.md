# Tiny Chefs UI style ("order tickets on a diner rail")

Warm, chunky, high contrast. Cream paper cards, thick ink outline, hard offset shadow, one rounded font (Fredoka, wght 600/700).
Files: `scripts/ui/ui_theme.gd` (`UITheme`: tokens + `build()`), `ui_kit.gd` (`UIKit`: blocks + motion), `ui_progress.gd`, `ui_coin_chip.gd`, `ui_order_ticket.gd`. `UI.theme()` returns `UITheme.build()`; `main.gd` applies it to the UI root, so every child inherits it. Look at `scenes/dev/ui_gallery.tscn`.

## Tokens (UITheme; never hardcode colours or sizes)
- Surfaces: `CREAM` #FFF6E0 (cards), `CREAM_HI` (inputs), `INK` #2B2233 (outline, text, dark surface), `INK_SOFT` (muted text).
- Accents: `TOMATO` (primary, danger, urgent), `MUSTARD` (coins, titles), `LETTUCE` (success), `SKY` (info, focus ring). `PLAYER_COLORS` = blue, red, green, yellow.
- Sizes (only these): `S_CAPTION` 16, `S_BODY` 20, `S_HEADING` 28, `S_TITLE` 44, `S_HERO` 72. Spacing: `GAP` 12, `PAD` 20. Outline 3 (controls) / 4 (cards). Radius 12-16.
- `UITheme.box(fill, border, radius, bw, shadow_depth, lift)` makes a hard-shadow StyleBoxFlat for custom pieces.

## API (all return an unparented node; you add it)
- Text: `UIKit.title(text, size=S_TITLE)` (mustard, ink outline; use `S_HERO` for the logo), `heading/body/caption(text, on)`, `number(text, on, color)`. `on` = `"card"` ink on cream (default), `"dark"` cream on aubergine, `"world"` cream with ink outline for text over the 3D scene.
- Surfaces: `UIKit.card(sep, dark=false)` -> `[PanelContainer, VBoxContainer]`; `UIKit.backdrop(alpha)` aubergine dimmer for overlays; plain `PanelContainer` already renders as a card; `theme_type_variation` "DarkPanel", "ChipPanel", "DarkChipPanel".
- Buttons: `UIKit.button(text, cb, kind, min_width)`; kind `"primary"` (tomato), `"accent"` (mustard), `"secondary"` (cream), `"danger"` (dark red), `"go"` (green). Squash on press built in; states hover/pressed/disabled/focus come from the theme. Any raw `Button` is primary.
- Meters: `UIKit.progress(fraction, w, h, ramp)` -> `UIProgress` (`set_fraction(f)`, `pulse_when_low`); `UIKit.ramp_color(f)`; `UIKit.coin_chip(n, dark)` -> `UICoinChip` (`set_amount(n)` pops); `UIKit.key_hint("E", "Grab", on)`.
- Game bits: `UIKit.order_ticket(dish, [colors], patience, "#1")` -> `UIOrderTicket` (`set_patience(f)`, pulses under 20%); `UIKit.player_badge(name, colorOrIndex, dark)`; `UIKit.dot(color, px)`; `UIKit.chip_swatch(color, px)`; `UIKit.player_color(i)`.
- Feedback: `UIKit.toast(host, text, kind, seconds)` (info/success/warn/error; host = full-screen Control).
- Motion: `pop_in(c, delay, dur)` on every panel/screen you show; `pop_out(c, free_after)`; `punch(c)` one-shot bump; `pulse(c, amount, period)` returns the Tween (kill it to stop, reset `scale`); `shake(c)` for "no"; `attach_press_squash(button)`.
- Legacy `UI.*` (`label`, `button`, `panel`, `centred`, `full_rect`, `swatch`, `time_text`, `controls_text`, colour consts) still work and are themed; prefer `UIKit` in new code. Containers: use `UI.centred`, `UI.full_rect`.

## Do
- Put text on a cream card or use `on="world"`. Keep one primary button per screen; secondary for back/cancel, danger for leave/quit.
- Leave 12 px between stacked buttons (shadows hang 5 px below). Keep VBox/HBox default separation (theme sets 12).
- Give every screen a keyboard/gamepad start focus: `button.grab_focus.call_deferred()`. Focus ring is sky blue.
- Use the ramp colours for anything draining (patience, timer). Pulse only truly urgent things.

## Don't
- No bare white text over the scene; no new font sizes, colours, or blur shadows; no default grey controls.
- Do not scale a container child every frame (it fights layout); tween `scale` for effects only, after `pop_in`/`pulse` set the pivot.

## Screenshot a screen
Add `UI_GALLERY_PAGE=2` env for the gallery's context page. Otherwise:
`powershell -NoProfile -ExecutionPolicy Bypass -File tools\godot-screenshot.ps1 -Scene res://scenes/dev/ui_gallery.tscn -Out build\screenshots\ui.png [-Resolution 1920x1080]`
then Read the PNG. Default scene = the real menu. Run `godot-check` first. Design at 1280x720 (stretch is canvas_items, expand).
