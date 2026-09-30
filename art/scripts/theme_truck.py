"""Theme props for the food-truck map (theme "truck").

Run: tools/blender-run.ps1 art/scripts/theme_truck.py [-- model_name ...]
Blender Z-up, front = -Y, origin = base centre. Sizes are Godot X x Y(up) x Z.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mathutils import Vector  # noqa: E402

import theme_parts as tp  # noqa: E402
from theme_parts import (M, ball, bezier, cyl, fillet, heart_pts, lathe, prism_xz, rbox, rod, star_pts, sweep,  # noqa: E402
                         torus)


# ---------------------------------------------------------------------------
def truck_menu_board():
    wood = M("BoardWood", "#9a6238", 0.7)
    wood_d = M("BoardWoodDark", "#6f4424", 0.75)
    slate = M("BoardSlate", "#27332f", 0.95)
    chalk = M("Chalk", "#f4f0e2", 1.0)
    red = M("ChalkRed", "#f0605a", 1.0)
    yellow = M("ChalkYellow", "#ffd94f", 1.0)
    teal = M("ChalkTeal", "#58d2c0", 1.0)
    orange = M("ChalkOrange", "#ff9a42", 1.0)
    green = M("ChalkGreen", "#7fd66a", 1.0)
    brown = M("ChalkBrown", "#c98a52", 1.0)
    tan = M("ChalkTan", "#f0c27c", 1.0)
    dark = M("ChalkHole", "#1a211e", 1.0)
    metal = M("BoardScrew", "#b8bfc6", 0.4, 0.6)
    parts = []
    YB = -0.1  # slate front face

    parts.append(rbox(slate, (13.2, 0.3, 8.2), (0, 0.05, 4.5), r=0.04, seg=1))
    # wooden frame with a mitred look: long rails on top of short rails
    parts.append(rbox(wood, (14, 0.6, 0.6), (0, 0, 0.3), r=0.14))
    parts.append(rbox(wood, (14, 0.6, 0.6), (0, 0, 8.7), r=0.14))
    parts.append(rbox(wood_d, (0.6, 0.56, 8.0), (-6.7, 0, 4.5), r=0.12))
    parts.append(rbox(wood_d, (0.6, 0.56, 8.0), (6.7, 0, 4.5), r=0.12))
    for sx in (-1, 1):
        for z in (0.3, 8.7):
            parts.append(ball(metal, (0.12, 0.05, 0.12), (sx * 6.7, -0.28, z), seg=8, rings=4))

    def prism(mat, pts, thick=0.07, lift=0.0):
        y0 = YB - 0.02 - lift - thick
        return prism_xz(mat, pts, y0, YB + 0.02 - lift)

    def disc(mat, cx, cz, rx, rz=None, lift=0.0, thick=0.07):
        return ball(mat, (rx, thick, rz or rx), (cx, YB - lift - thick * 0.4, cz), seg=12, rings=5)

    def bar(mat, cx, cz, w, h=0.14, lift=0.0):
        return rbox(mat, (w, 0.08, h), (cx, YB - 0.04 - lift, cz), r=0.035, seg=1)

    # header ribbon with stars
    rib = [(-5.6, 7.15), (5.6, 7.15), (5.0, 7.7), (5.6, 8.25), (-5.6, 8.25), (-5.0, 7.7)]
    parts.append(prism(red, rib, 0.1))
    for i, x in enumerate((-3.6, -1.8, 0, 1.8, 3.6)):
        parts.append(prism(yellow if i % 2 == 0 else chalk, star_pts(x, 7.7, 0.36, 0.16), 0.06, lift=0.1))
    parts.append(bar(chalk, -4.9, 7.7, 0.2, 0.2, lift=0.1))
    parts.append(bar(chalk, 4.9, 7.7, 0.2, 0.2, lift=0.1))

    # column dividers: dashed chalk lines
    for x in (-2.3, 2.3):
        for k in range(6):
            parts.append(bar(chalk, x, 1.2 + k * 1.0, 0.1, 0.5))

    # --- burger doodle
    bx, bz = -4.5, 4.8
    parts.append(disc(tan, bx, bz - 0.85, 1.25, 0.42, 0.0))
    parts.append(rbox(brown, (2.3, 0.12, 0.45), (bx, YB - 0.1, bz - 0.4), r=0.15, seg=2))
    parts.append(rbox(yellow, (2.1, 0.1, 0.22), (bx, YB - 0.14, bz - 0.05), r=0.05, seg=1))
    for k in range(6):
        parts.append(ball(green, (0.24, 0.07, 0.2), (bx - 1.05 + k * 0.42, YB - 0.14, bz + 0.2), seg=8, rings=4))
    parts.append(rbox(red, (1.9, 0.1, 0.22), (bx, YB - 0.16, bz + 0.05 - 0.05), r=0.05, seg=1))
    parts.append(ball(tan, (1.25, 0.11, 0.78), (bx, YB - 0.1, bz + 0.72), seg=14, rings=6))
    for sx, sz in ((-0.6, 0.95), (0.0, 1.2), (0.6, 0.9), (-0.25, 0.65), (0.35, 0.62)):
        parts.append(ball(chalk, (0.1, 0.05, 0.05), (bx + sx, YB - 0.22, bz + sz), rot=(0, 0.4, 0), seg=6, rings=4))

    # --- hot dog doodle (tilted)
    hx, hz = 0.0, 4.9
    parts.append(ball(tan, (1.9, 0.11, 0.6), (hx, YB - 0.1, hz - 0.15), rot=(0, 0.12, 0), seg=14, rings=6))
    parts.append(ball(red, (2.15, 0.14, 0.36), (hx, YB - 0.16, hz - 0.02), rot=(0, 0.12, 0), seg=14, rings=6))
    zig = [(hx - 1.7 + 0.34 * i, YB - 0.3, hz + 0.1 + (0.12 if i % 2 else -0.06)) for i in range(11)]
    parts.append(sweep(yellow, zig, 0.055, sides=5))
    parts.append(ball(tan, (1.9, 0.11, 0.45), (hx, YB - 0.2, hz - 0.45), rot=(0, 0.12, 0), seg=14, rings=6))
    # little steam curls
    for x in (-0.8, 0.1, 1.0):
        pts = [(x + 0.18 * math.sin(i * 0.9), YB - 0.05, hz + 0.75 + i * 0.22) for i in range(6)]
        parts.append(sweep(chalk, pts, 0.04, sides=4))

    # --- fries + soda doodle
    fx, fz = 4.0, 4.7
    for i, (dx, hh, rt) in enumerate(((-0.65, 1.55, 0.18), (-0.3, 1.9, 0.05), (0.05, 1.7, -0.08), (-0.9, 1.3, 0.3), (0.3, 1.5, -0.2))):
        parts.append(rbox(yellow, (0.22, 0.09, hh), (fx + dx - 0.6, YB - 0.1, fz + 0.15 + hh / 2), rot=(0, rt, 0), r=0.04, seg=1))
    parts.append(prism(red, [(fx - 1.45, fz - 0.15 + 0.35), (fx + 0.3, fz - 0.15 + 0.35), (fx + 0.15, fz - 1.1), (fx - 1.3, fz - 1.1)], 0.1, lift=0.1))
    parts.append(ball(chalk, (0.3, 0.05, 0.3), (fx - 0.6, YB - 0.22, fz - 0.6), seg=8, rings=4))
    # cup
    cup = [(fx + 0.85, fz - 1.15), (fx + 2.05, fz - 1.15), (fx + 2.3, fz + 0.65), (fx + 0.6, fz + 0.65)]
    parts.append(prism(chalk, cup, 0.1))
    parts.append(prism(red, [(fx + 0.73, fz - 0.15), (fx + 2.17, fz - 0.15), (fx + 2.23, fz + 0.2), (fx + 0.67, fz + 0.2)], 0.06, lift=0.1))
    parts.append(rbox(red, (1.9, 0.12, 0.14), (fx + 1.45, YB - 0.1, fz + 0.72), r=0.05, seg=1))
    parts.append(rod(teal, (fx + 1.6, YB - 0.14, fz + 0.65), (fx + 1.95, YB - 0.14, fz + 1.65), 0.07, verts=6))

    # --- price tags
    for x, mat in ((-4.5, red), (0.0, yellow), (4.0, teal)):
        z = 2.35
        tag = [(x - 1.35, z), (x - 0.85, z + 0.5), (x + 1.35, z + 0.5), (x + 1.35, z - 0.5), (x - 0.85, z - 0.5)]
        parts.append(prism(mat, tag, 0.1))
        parts.append(ball(dark, (0.11, 0.05, 0.11), (x - 0.92, YB - 0.14, z), seg=8, rings=4))
        parts.append(bar(dark if mat is yellow else chalk, x + 0.2, z, 0.7, 0.2, lift=0.1))
        parts.append(ball(dark if mat is yellow else chalk, (0.1, 0.04, 0.1), (x + 0.68, YB - 0.2, z - 0.12), seg=8, rings=4))
        parts.append(bar(dark if mat is yellow else chalk, x + 0.98, z, 0.3, 0.2, lift=0.1))
        # two description squiggles
        parts.append(bar(chalk, x - 0.25, 1.3, 1.9))
        parts.append(bar(chalk, x - 0.6, 0.95, 1.2))
    # combo starburst, top-right
    parts.append(prism(orange, star_pts(5.4, 5.9, 1.05, 0.68, 9, 100), 0.1))
    parts.append(prism(yellow, star_pts(5.4, 5.9, 0.68, 0.45, 9, 100), 0.06, lift=0.1))
    parts.append(prism(red, tp.heart_pts(0.6, 0.55, 20, 5.4, 5.75), 0.05, lift=0.16))
    # bottom flourishes: wavy line, sparkle, heart
    wav = [(-6.0 + 0.3 * i, YB - 0.05, 0.98 + 0.08 * math.sin(i * 0.9)) for i in range(41)]
    parts.append(sweep(chalk, wav, 0.04, sides=4))
    parts.append(prism(teal, star_pts(-5.9, 6.4, 0.42, 0.14, 4, 90), 0.05))
    parts.append(prism(green, star_pts(-5.75, 3.4, 0.3, 0.1, 4, 90), 0.05))
    parts.append(prism(red, heart_pts(0.5, 0.5, 18, 6.0, 0.72), 0.05))
    tp.squash_front(parts[13:], YB, 0.5)
    return parts, (14, 9, 0.6)


# ---------------------------------------------------------------------------
def truck_string_lights():
    wire_m = M("LightWire", "#22252a", 0.6)
    socket_m = M("LightSocket", "#34383f", 0.5, 0.3)
    glow = [M("BulbWarm", "#ffd27a", 0.2, emission="#ffb84a", emission_strength=5.0),
            M("BulbAmber", "#ffb44a", 0.2, emission="#ff9a2a", emission_strength=5.0),
            M("BulbCream", "#fff0c4", 0.2, emission="#ffe2a0", emission_strength=5.0)]

    def wz(x):
        return 0.77 + 0.34 * (x / 14.7) ** 2

    xs = [-14.7 + 29.4 * i / 40 for i in range(41)]
    path = [(x, 0, wz(x)) for x in xs]
    parts = [sweep(wire_m, path, 0.045, sides=5)]
    for sx in (-1, 1):
        parts.append(torus(wire_m, 0.22, 0.04, (sx * 14.75, 0, 0.98), rot=(math.pi / 2, 0, 0), seg=12, sides=5))
    n = 13
    for i in range(n):
        x = -13.2 + 26.4 * i / (n - 1)
        z = wz(x)
        slope = 2 * 0.34 * x / 14.7 ** 2
        parts.append(cyl(socket_m, 0.11, 0.2, (x, 0, z - 0.1), verts=8))
        parts.append(cyl(socket_m, 0.14, 0.05, (x, 0, z - 0.2), verts=8))
        parts.append(ball(glow[i % 3 if i % 4 else 1], (0.25, 0.25, 0.3), (x, 0, z - 0.47), seg=12, rings=8))
        # little zig of wire loop at the socket
        parts.append(torus(wire_m, 0.09, 0.025, (x, 0, z + 0.02), rot=(math.pi / 2, 0, 0), seg=8, sides=4))
    return parts, (30, 1.2, 0.5)


# ---------------------------------------------------------------------------
def truck_napkin_dispenser():
    chrome = M("NapChrome", "#d5dce3", 0.18, 0.75)
    shine = M("NapShine", "#ffffff", 0.1, 0.3)
    dark = M("NapDark", "#3a4047", 0.5, 0.4)
    paper = [M("NapkinWhite", "#fbf9f2", 0.95), M("NapkinCream", "#eee8d6", 0.95)]
    red = M("NapRed", "#d8382f", 0.4)
    parts = []
    parts.append(rbox(chrome, (3.0, 3.0, 0.28), (0, 0, 0.14), r=0.1))
    parts.append(rbox(chrome, (3.0, 0.16, 4.0), (0, 1.42, 2.0), r=0.08))
    for sx in (-1, 1):
        parts.append(rbox(chrome, (0.16, 3.0, 3.4), (sx * 1.42, 0, 1.98), r=0.08))
        parts.append(rbox(shine, (0.04, 2.3, 0.1), (sx * 1.52, 0, 2.9), r=0.02, seg=1))
    # front bottom lip + spring bar
    parts.append(rbox(chrome, (3.0, 0.16, 0.6), (0, -1.42, 0.5), r=0.06))
    parts.append(rod(dark, (-1.4, -1.36, 3.05), (1.4, -1.36, 3.05), 0.05, verts=6))
    # napkin stack
    rnd = random.Random(7)
    z = 0.28
    for i in range(15):
        h = 0.2
        parts.append(rbox(paper[i % 2], (2.66, 2.5, h - 0.012), (rnd.uniform(-0.03, 0.03), -0.07 + rnd.uniform(-0.03, 0.03), z + h / 2),
                          r=0.03, seg=1))
        z += h
    # top napkin tilted, corner lifting
    parts.append(rbox(paper[0], (2.6, 2.4, 0.06), (0.0, -0.1, z + 0.05), rot=(0.06, 0.04, 0.0), r=0.02, seg=1))
    # pulled napkin sheet peeking over the front lip, corner folded
    parts.append(rbox(paper[0], (1.5, 0.9, 0.035), (0.45, -1.1, 1.78), rot=(0.42, 0.0, 0.08), r=0.012, seg=1))
    parts.append(rbox(paper[1], (0.4, 0.4, 0.03), (0.98, -1.4, 1.55), rot=(0.42, 0.0, 0.7), r=0.01, seg=1))
    # pusher plate + handle
    parts.append(rbox(chrome, (2.74, 2.6, 0.14), (0, -0.05, z + 0.2), r=0.05))
    parts.append(cyl(red, 0.55, 0.05, (0, -0.05, z + 0.29), verts=16))
    hp = [(0.0 + 0.62 * math.cos(math.radians(a)), 0.2, z + 0.27 + 0.6 * math.sin(math.radians(a))) for a in range(0, 181, 15)]
    parts.append(sweep(chrome, hp, 0.06, sides=6))
    return parts, (3, 4, 3)


# ---------------------------------------------------------------------------
def truck_sauce_bottles():
    caddy = M("CaddyTin", "#c9d0d6", 0.35, 0.6)
    caddy_in = M("CaddyInner", "#8a929a", 0.5, 0.4)
    red = M("SauceRed", "#dc2f27", 0.35)
    yellow = M("SauceYellow", "#f4c818", 0.35)
    white = M("SauceWhite", "#f5f2e8", 0.35)
    tipred = M("TipRed", "#9e1a15", 0.4)
    tipyel = M("TipYellow", "#c79a0c", 0.4)
    tipwhi = M("TipWhite", "#cfc9b8", 0.4)
    shine = M("SauceShine", "#ffffff", 0.15)
    label = M("SauceLabel", "#fff7dc", 0.5)
    parts = []
    # tray with low walls
    parts.append(rbox(caddy, (5.0, 2.5, 0.35), (0, 0, 0.175), r=0.08))
    for sy in (-1, 1):
        parts.append(rbox(caddy, (5.0, 0.12, 0.85), (0, sy * 1.19, 0.45), r=0.05))
    for sx in (-1, 1):
        parts.append(rbox(caddy, (0.12, 2.5, 0.85), (sx * 2.44, 0, 0.45), r=0.05))
    parts.append(rbox(caddy_in, (4.8, 2.3, 0.05), (0, 0, 0.37), r=0.01, seg=1))
    bottles = ((-1.6, red, tipred, 4.65), (0.0, yellow, tipyel, 4.65), (1.6, white, tipwhi, 4.65))
    for x, body, tip, top in bottles:
        z0 = 0.36
        prof = fillet([(0, 0), (0.68, 0), (0.72, 0.1), (0.74, 1.6), (0.66, 2.35), (0.42, 3.05), (0.3, 3.35), (0.3, 3.55), (0, 3.55)],
                      r=0.25, n=3, radii={1: 0.1})
        parts.append(lathe(body, prof, verts=20, loc=(x, 0, z0)))
        parts[-1].scale = (1, 1, 1.08)
        # cap ring + nozzle cone
        parts.append(lathe(tip, [(0, 3.45), (0.4, 3.45), (0.4, 3.75), (0.31, 3.8), (0.24, 4.05), (0.1, 4.28), (0, 4.29)],
                           verts=14, loc=(x, 0, z0)))
        parts[-1].scale = (1, 1, 1.08)
        # label band
        parts.append(tp.sp.ring_band(label, [(0.68, 0), (0.72, 0.1), (0.74, 1.6), (0.66, 2.35)], 0.6, 1.7, off=0.02, thick=0.05, verts=20))
        parts[-1].location = (x, 0, z0)
        parts.append(ball(body, (0.2, 0.06, 0.28), (x, -0.78, z0 + 1.15), seg=10, rings=6))  # drop icon
        parts.append(rod(shine, (x - 0.33, -0.55, z0 + 1.9), (x - 0.4, -0.45, z0 + 2.7), 0.06, verts=5))
    return parts, (5, 5, 2.5)


# ---------------------------------------------------------------------------
def truck_order_bell_sign():
    red = M("SignRed", "#cf3b30", 0.45)
    cream = M("SignCream", "#fff1cd", 0.6)
    gold = M("SignGold", "#f0a81c", 0.3, 0.3)
    gold_d = M("SignGoldDark", "#b9770e", 0.35, 0.3)
    arrow_m = M("SignArrow", "#e4352a", 0.4)
    white = M("SignWhite", "#ffffff", 0.3)
    chain = M("SignChain", "#9ea6ad", 0.35, 0.7)
    teal = M("SignTeal", "#1fa79a", 0.4)
    parts = [rbox(red, (6.0, 0.25, 2.9), (0, 0.075, 1.6), r=0.22, seg=3),
             rbox(cream, (5.4, 0.12, 2.3), (0, -0.05, 1.6), r=0.16, seg=2)]
    # arrow: white outline behind, red on top
    def arrow(d, mat, lift):
        pts = [(-0.45 - d, 1.15 + 0 - d), (1.55, 1.15 - d), (1.55, 0.52 - d), (2.6 + d * 1.6, 1.6), (1.55, 2.68 + d), (1.55, 2.05 + d), (-0.45 - d, 2.05 + d)]
        pts = [(-0.45 - d, 1.25 - d), (1.5, 1.25 - d), (1.5, 0.75 - d * 1.4), (2.6 + d * 1.6, 1.6), (1.5, 2.45 + d * 1.4), (1.5, 1.95 + d), (-0.45 - d, 1.95 + d)]
        return prism_xz(mat, pts, -0.11 - lift - 0.05, -0.1 - lift + 0.01)
    parts.append(arrow(0.08, white, 0.0))
    parts.append(arrow(0.0, arrow_m, 0.05))
    # stripes on the arrow shaft
    for x in (-0.05, 0.45, 0.95):
        parts.append(rbox(white, (0.18, 0.04, 0.5), (x, -0.205, 1.6), rot=(0, 0.35, 0), r=0.02, seg=1))
    # bell icon (flattened lathe) on the left
    bp = fillet([(0, 0.0), (0.88, 0.0), (0.92, 0.1), (0.72, 0.5), (0.58, 0.95), (0.4, 1.3), (0.2, 1.45), (0, 1.45)], r=0.3, n=4,
                radii={1: 0.04, 2: 0.15})
    bell = lathe(gold, bp, verts=20, loc=(-1.75, -0.14, 0.78))
    bell.scale = (0.92, 0.18, 0.95)
    parts.append(bell)
    knob = ball(gold_d, (0.15, 0.06, 0.15), (-1.75, -0.16, 2.3), seg=8, rings=5)
    parts.append(knob)
    parts.append(ball(gold_d, (0.2, 0.08, 0.2), (-1.75, -0.16, 0.72), seg=8, rings=5))
    parts.append(rbox(white, (0.1, 0.04, 0.8), (-2.15, -0.3, 1.45), rot=(0, 0.15, 0), r=0.03, seg=1))
    # ding lines
    for sx in (-1, 1):
        for k, (r, ang) in enumerate(((1.25, 25), (1.45, 25))):
            pass
    parts.append(rod(teal, (-2.95, -0.2, 2.25), (-2.7, -0.2, 2.45), 0.05, verts=5))
    parts.append(rod(teal, (-0.8, -0.2, 2.25), (-1.05, -0.2, 2.45), 0.05, verts=5))
    parts.append(rod(teal, (-0.65, -0.2, 1.6), (-0.9, -0.2, 1.6), 0.05, verts=5))
    parts.append(rod(teal, (-3.0, -0.2, 1.75), (-2.75, -0.2, 1.75), 0.05, verts=5))
    # chains + hooks
    for sx in (-1, 1):
        x = sx * 2.3
        parts.append(ball(chain, 0.12, (x, 0.1, 3.06), seg=8, rings=4))
        for i in range(5):
            z = 3.22 + i * 0.165
            rot = (math.pi / 2, 0, 0) if i % 2 == 0 else (math.pi / 2, 0, math.pi / 2)
            parts.append(torus(chain, 0.11, 0.028, (x, 0.1, z), rot=rot, seg=8, sides=4))
            parts[-1].scale = (1, 1, 1.0)
        parts.append(torus(chain, 0.14, 0.04, (x, 0.1, 3.93), rot=(math.pi / 2, 0, 0), seg=10, sides=4))
    return parts, (6, 4, 0.5)


# ---------------------------------------------------------------------------
def truck_tip_jar():
    glass = M("JarGlass", "#bfe4ee", 0.05, alpha=0.3)
    lid = M("JarLid", "#e0b23a", 0.3, 0.7)
    lid_d = M("JarLidSlot", "#3a2a0c", 0.6)
    coin_g = M("CoinGold", "#f2c84a", 0.3, 0.3, emission="#f2c84a", emission_strength=0.45)
    coin_s = M("CoinSilver", "#d6dde3", 0.3, 0.3, emission="#d6dde3", emission_strength=0.4)
    coin_c = M("CoinCopper", "#c97d44", 0.3, 0.3, emission="#c97d44", emission_strength=0.45)
    bill = M("TipBill", "#7fbf7a", 0.7, emission="#7fbf7a", emission_strength=0.7)
    heart_bg = M("StickerWhite", "#fff9ee", 0.5)
    heart = M("StickerHeart", "#e8353f", 0.4)
    parts = []
    # coins and a curled bill inside first (opaque), glass last
    rnd = random.Random(11)
    mats = [coin_g, coin_s, coin_c, coin_g]
    for i in range(46):
        rr = 0.78 * math.sqrt(rnd.random())
        a = rnd.uniform(0, 2 * math.pi)
        height = 0.26 + 0.9 * max(0.0, 1.0 - rr / 0.9) ** 0.8 * rnd.uniform(0.35, 1.0) + 0.05 * rnd.random()
        parts.append(cyl(mats[i % 4], 0.33, 0.075, (rr * math.cos(a), rr * math.sin(a), height),
                         rot=(rnd.uniform(-0.55, 0.55), rnd.uniform(-0.55, 0.55), a), verts=12))
    parts.append(rbox(bill, (0.75, 0.4, 0.05), (-0.25, 0.3, 1.0), rot=(0.25, 0.3, 0.6), r=0.02, seg=1))
    parts.append(rbox(bill, (0.75, 0.4, 0.05), (0.3, -0.05, 1.1), rot=(-0.2, 0.25, -0.4), r=0.02, seg=1))
    # metal screw lid with coin slot
    parts.append(lathe(lid, [(0, 3.05), (1.0, 3.05), (1.04, 3.12), (1.04, 3.42), (0.96, 3.5), (0, 3.5)], verts=20))
    parts.append(rbox(lid_d, (0.78, 0.13, 0.05), (0, 0, 3.5), r=0.02, seg=1))
    # sticker: white disc + heart, stuck to the front wall
    parts.append(prism_xz(heart_bg, tp.circle_pts(0, 1.55, 0.6, 18), -1.3, -1.15))
    parts.append(prism_xz(heart, heart_pts(0.78, 0.72, 24, 0, 1.52), -1.36, -1.2))
    # glass jar (hollow shell)
    outer = [(0, 0), (1.0, 0), (1.15, 0.08), (1.22, 0.3), (1.25, 1.2), (1.2, 2.3), (1.05, 2.8), (1.0, 3.05)]
    prof = tp.glass_profile(outer, 0.09, 0.14)
    parts.append(lathe(glass, prof, verts=28))
    return parts, (2.5, 3.5, 2.5)


# ---------------------------------------------------------------------------
def truck_cash_register():
    body_m = M("RegBody", "#35a59c", 0.4)
    trim = M("RegTrim", "#f0e6cf", 0.45)
    brass = M("RegBrass", "#e5b43c", 0.3, 0.8)
    key_w = M("RegKeyWhite", "#f7f2e4", 0.35)
    key_r = M("RegKeyRed", "#dc3a30", 0.35)
    key_y = M("RegKeyYellow", "#f2c633", 0.35)
    key_g = M("RegKeyGreen", "#4cae57", 0.35)
    key_b = M("RegKeyBlue", "#3b7fd6", 0.35)
    screen = M("RegScreen", "#ffbf4a", 0.3, emission="#ff9a1e", emission_strength=2.5)
    dark = M("RegDark", "#22282d", 0.6)
    paper = M("RegPaper", "#fdfcf6", 0.9)
    ink = M("RegInk", "#6f7a84", 0.9)
    drawer_m = M("RegDrawer", "#d8dde2", 0.3, 0.5)
    bill = M("RegBill", "#79b872", 0.7)
    coin_g = M("RegCoinGold", "#f2c84a", 0.25, 0.8)
    coin_s = M("RegCoinSilver", "#d6dde3", 0.25, 0.8)
    parts = []
    # plinth + main body
    parts.append(rbox(dark, (6.0, 4.3, 0.3), (0, 0.4, 0.15), r=0.08))
    parts.append(rbox(body_m, (5.9, 4.1, 2.0), (0, 0.45, 1.3), r=0.22))
    parts.append(rbox(trim, (6.0, 4.2, 0.12), (0, 0.45, 2.33), r=0.05, seg=1))
    # drawer (open a little): tray, dividers, money
    parts.append(rbox(drawer_m, (5.2, 1.0, 0.14), (0, -2.05, 0.6), r=0.04, seg=1))
    for sx in (-1, 1):
        parts.append(rbox(drawer_m, (0.14, 1.0, 0.8), (sx * 2.53, -2.05, 0.95), r=0.04, seg=1))
    parts.append(rbox(trim, (5.4, 0.22, 1.6), (0, -2.4, 1.3), r=0.1))
    parts.append(rbox(brass, (1.3, 0.12, 0.22), (0, -2.56, 1.3), r=0.05))
    for x in (-1.3, 0.0, 1.3):
        parts.append(rbox(drawer_m, (0.07, 0.8, 0.45), (x, -2.0, 0.85), r=0.02, seg=1))
    for i in range(4):
        parts.append(cyl(coin_g if i % 2 else coin_s, 0.22, 0.06, (-2.0 + 0.04 * i, -2.0, 0.72 + 0.07 * i), verts=10))
    for i in range(3):
        parts.append(cyl(coin_s, 0.2, 0.06, (-0.65, -2.05, 0.72 + 0.07 * i), verts=10))
    parts.append(rbox(bill, (1.0, 0.5, 0.06), (0.65, -2.0, 0.72), rot=(0, 0, 0.1), r=0.02, seg=1))
    parts.append(rbox(bill, (1.0, 0.5, 0.06), (0.7, -2.0, 0.8), rot=(0, 0, -0.1), r=0.02, seg=1))
    parts.append(rbox(bill, (0.9, 0.5, 0.06), (2.0, -2.0, 0.72), rot=(0, 0, 0.2), r=0.02, seg=1))
    # key deck (tilted slab) with brass rim
    th = math.radians(16)
    c = Vector((0, 0.15, 2.72))
    deck = rbox(body_m, (5.7, 3.6, 0.3), tuple(c), rot=(th, 0, 0), r=0.12)
    parts.append(deck)
    n = Vector((0, -math.sin(th), math.cos(th)))
    v_dir = Vector((0, math.cos(th), math.sin(th)))

    def key(mat, u, v, r=0.27, h=0.16, tall=False):
        p = c + Vector((u, 0, 0)) + v_dir * v + n * (0.15 + h / 2)
        o = cyl(mat, r, h, (0, 0, 0), verts=12)
        return tp.sp.oriented(o, tuple(p), tuple(n), hint=(1, 0, 0))

    cols = [-0.15, 0.55, 1.25]
    rows = [-1.2, -0.55, 0.1, 0.75]
    kmats = [[key_w, key_w, key_w], [key_w, key_y, key_w], [key_w, key_w, key_w], [key_b, key_w, key_g]]
    for ri, v in enumerate(rows):
        for ci, u in enumerate(cols):
            parts.append(key(kmats[ri][ci], u, v))
    # big red "total" key and right-hand column of department keys
    for ri, v in enumerate(rows):
        parts.append(key((key_r, key_y, key_r, key_y)[ri], 2.15, v, 0.27))
    p = c + Vector((-2.0, 0, 0)) + v_dir * (-0.9) + n * 0.35
    big = tp.sp.oriented(cyl(key_r, 0.42, 0.2, (0, 0, 0), verts=14), tuple(p), tuple(n), hint=(1, 0, 0))
    parts.append(big)
    p = c + Vector((-2.0, 0, 0)) + v_dir * (-0.1) + n * 0.33
    parts.append(tp.sp.oriented(cyl(key_g, 0.36, 0.17, (0, 0, 0), verts=14), tuple(p), tuple(n), hint=(1, 0, 0)))
    # rear housing + display head
    parts.append(rbox(body_m, (5.3, 1.5, 2.7), (0, 1.75, 3.6), r=0.22))
    parts.append(rbox(trim, (4.9, 1.6, 0.14), (0, 1.75, 4.95), r=0.05, seg=1))
    tilt = -0.2
    parts.append(rbox(trim, (4.9, 1.6, 1.25), (0, 1.75, 5.3), rot=(tilt, 0, 0), r=0.18))
    parts.append(rbox(dark, (3.9, 0.12, 0.95), (0, 0.93, 5.27), rot=(tilt, 0, 0), r=0.06, seg=1))
    parts.append(rbox(screen, (3.6, 0.1, 0.72), (0, 0.86, 5.29), rot=(tilt, 0, 0), r=0.05, seg=1))
    # display glyphs (abstract bars)
    for i in range(5):
        parts.append(rbox(dark, (0.26, 0.04, 0.46), (-1.3 + i * 0.52, 0.8, 5.31), rot=(tilt, 0, 0), r=0.03, seg=1))
    # brass arched top
    parts.append(rbox(brass, (5.0, 1.7, 0.22), (0, 1.75, 5.95), rot=(tilt * 0.6, 0, 0), r=0.1))
    # receipt tape curling out of the top and dropping in front on the left
    path = bezier((-2.4, 2.0, 5.95), (-2.4, 0.6, 6.4), (-2.4, -1.0, 5.6), (-2.4, -1.0, 4.35), 14)
    path += bezier((-2.4, -1.0, 4.35), (-2.4, -1.0, 3.6), (-2.4, -1.3, 3.5), (-2.4, -1.0, 3.2), 6)[1:]
    parts.append(sweep(paper, [tuple(p) for p in path], (0.42, 0.02), sides=4, rect=True, up=(1, 0, 0)))
    for k in (0.35, 0.6, 0.8):
        i = int(len(path) * k)
        parts.append(rbox(ink, (0.55, 0.06, 0.08), tuple(path[i] + Vector((0, -0.03, 0))), r=0.02, seg=1))
    # lower screws on trim
    for sx in (-1, 1):
        parts.append(ball(brass, 0.12, (sx * 2.7, -1.62, 1.85), seg=8, rings=4))
    return parts, (6, 6, 5)


JOBS = (("truck_menu_board", truck_menu_board), ("truck_string_lights", truck_string_lights),
        ("truck_napkin_dispenser", truck_napkin_dispenser), ("truck_sauce_bottles", truck_sauce_bottles),
        ("truck_order_bell_sign", truck_order_bell_sign), ("truck_tip_jar", truck_tip_jar),
        ("truck_cash_register", truck_cash_register))

tp.sp.run(JOBS)
